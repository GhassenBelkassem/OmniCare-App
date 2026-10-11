enum InboxNotificationType {
  doctorBookingRequestCreated('DOCTOR_BOOKING_REQUEST_CREATED'),
  doctorBookingTimeProposed('DOCTOR_BOOKING_TIME_PROPOSED'),
  doctorBookingRequestDeclined('DOCTOR_BOOKING_REQUEST_DECLINED'),
  doctorBookingRequestCancelledByPatient(
    'DOCTOR_BOOKING_REQUEST_CANCELLED_BY_PATIENT',
  ),
  doctorBookingProposalAccepted('DOCTOR_BOOKING_PROPOSAL_ACCEPTED'),
  doctorBookingProposalDeclined('DOCTOR_BOOKING_PROPOSAL_DECLINED'),
  appointmentConfirmed('APPOINTMENT_CONFIRMED'),
  appointmentCancelledByPatient('APPOINTMENT_CANCELLED_BY_PATIENT'),
  appointmentCancelledByProfessional('APPOINTMENT_CANCELLED_BY_PROFESSIONAL'),
  doctorBookingRequestExpired('DOCTOR_BOOKING_REQUEST_EXPIRED'),
  unknown('UNKNOWN');

  const InboxNotificationType(this.wireName);
  final String wireName;

  static InboxNotificationType parse(Object? value) => values.firstWhere(
    (candidate) => candidate.wireName == value,
    orElse: () => unknown,
  );
}

enum NotificationReferenceType { bookingRequest, appointment, none }

class NotificationReference {
  const NotificationReference._(this.type, this.id);
  const NotificationReference.none()
    : this._(NotificationReferenceType.none, null);
  const NotificationReference.request(String id)
    : this._(NotificationReferenceType.bookingRequest, id);
  const NotificationReference.appointment(String id)
    : this._(NotificationReferenceType.appointment, id);

  final NotificationReferenceType type;
  final String? id;
}

class InboxNotification {
  const InboxNotification({
    required this.id,
    required this.type,
    required this.priority,
    required this.category,
    required this.titleFr,
    required this.bodyFr,
    required this.titleAr,
    required this.bodyAr,
    required this.reference,
    required this.read,
    required this.createdAt,
  });

  final String id;
  final InboxNotificationType type;
  final String priority;
  final String category;
  final String titleFr;
  final String bodyFr;
  final String? titleAr;
  final String? bodyAr;
  final NotificationReference reference;
  final bool read;
  final DateTime createdAt;

  InboxNotification copyWith({bool? read}) => InboxNotification(
    id: id,
    type: type,
    priority: priority,
    category: category,
    titleFr: titleFr,
    bodyFr: bodyFr,
    titleAr: titleAr,
    bodyAr: bodyAr,
    reference: reference,
    read: read ?? this.read,
    createdAt: createdAt,
  );

  factory InboxNotification.fromJson(Map<String, dynamic> json) {
    final type = InboxNotificationType.parse(json['type']);
    final payload = _optionalObject(json['deepLinkPayload']);
    final reference = switch (type) {
      InboxNotificationType.doctorBookingProposalAccepted =>
        _appointmentReference(payload) ?? _requestReference(payload),
      InboxNotificationType.appointmentConfirmed ||
      InboxNotificationType.appointmentCancelledByPatient ||
      InboxNotificationType.appointmentCancelledByProfessional =>
        _appointmentReference(payload),
      InboxNotificationType.doctorBookingRequestCreated ||
      InboxNotificationType.doctorBookingTimeProposed ||
      InboxNotificationType.doctorBookingRequestDeclined ||
      InboxNotificationType.doctorBookingRequestCancelledByPatient ||
      InboxNotificationType.doctorBookingProposalDeclined ||
      InboxNotificationType.doctorBookingRequestExpired => _requestReference(
        payload,
      ),
      InboxNotificationType.unknown => null,
    };
    return InboxNotification(
      id: _requiredString(json, 'id'),
      type: type,
      priority: _requiredString(json, 'priority'),
      category: _requiredString(json, 'category'),
      titleFr: _requiredString(json, 'titleFr'),
      bodyFr: _requiredString(json, 'bodyFr'),
      titleAr: _optionalString(json, 'titleAr'),
      bodyAr: _optionalString(json, 'bodyAr'),
      reference: reference ?? const NotificationReference.none(),
      read: json['read'] == true,
      createdAt: DateTime.parse(_requiredString(json, 'createdAt')).toUtc(),
    );
  }
}

class NotificationPage {
  const NotificationPage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.totalElements,
    required this.unreadCount,
  });

  final List<InboxNotification> items;
  final int page;
  final int pageSize;
  final int totalElements;
  final int unreadCount;

  factory NotificationPage.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    if (rawItems is! List) {
      throw const FormatException('Invalid notification items.');
    }
    return NotificationPage(
      items: rawItems
          .map((item) {
            if (item is! Map) {
              throw const FormatException('Invalid notification item.');
            }
            return InboxNotification.fromJson(item.cast<String, dynamic>());
          })
          .toList(growable: false),
      page: _requiredInt(json, 'page'),
      pageSize: _requiredInt(json, 'pageSize'),
      totalElements: _requiredInt(json, 'totalElements'),
      unreadCount: _requiredInt(json, 'unreadCount'),
    );
  }
}

NotificationReference? _requestReference(Map<String, Object?>? payload) {
  final id = _payloadId(payload, 'request_id');
  return id == null ? null : NotificationReference.request(id);
}

NotificationReference? _appointmentReference(Map<String, Object?>? payload) {
  final id = _payloadId(payload, 'appointment_id');
  return id == null ? null : NotificationReference.appointment(id);
}

String? _payloadId(Map<String, Object?>? payload, String key) {
  final value = payload?[key];
  if (value is! String || value.trim().isEmpty) return null;
  return value.trim();
}

Map<String, Object?>? _optionalObject(Object? value) => value is Map
    ? value.map((key, item) => MapEntry(key.toString(), item))
    : null;

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.isEmpty) throw FormatException('Missing $key.');
  return value;
}

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  return value is String && value.isNotEmpty ? value : null;
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! num) throw FormatException('Missing $key.');
  return value.toInt();
}
