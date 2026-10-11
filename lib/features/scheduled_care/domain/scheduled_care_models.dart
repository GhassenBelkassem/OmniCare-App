library;

import 'package:timezone/timezone.dart' as tz;

enum CareSubjectType {
  self('SELF'),
  familyMember('FAMILY_MEMBER');

  const CareSubjectType(this.wireName);
  final String wireName;

  static CareSubjectType parse(Object? value) => switch (value) {
    'SELF' => self,
    'FAMILY_MEMBER' => familyMember,
    _ => throw FormatException('Unknown care subject type: $value'),
  };
}

enum ScheduledCareResourceType {
  bookingRequest('BOOKING_REQUEST'),
  appointment('APPOINTMENT');

  const ScheduledCareResourceType(this.wireName);
  final String wireName;

  static ScheduledCareResourceType parse(Object? value) => switch (value) {
    'BOOKING_REQUEST' => bookingRequest,
    'APPOINTMENT' => appointment,
    _ => throw FormatException('Unknown scheduled-care resource type: $value'),
  };
}

enum BookingRequestStatus {
  pendingDoctor('PENDING_DOCTOR'),
  pendingPatientTimeConfirmation('PENDING_PATIENT_TIME_CONFIRMATION'),
  fulfilled('FULFILLED'),
  cancelledByPatient('CANCELLED_BY_PATIENT'),
  cancelledByDoctor('CANCELLED_BY_DOCTOR'),
  expired('EXPIRED');

  const BookingRequestStatus(this.wireName);
  final String wireName;

  static BookingRequestStatus parse(Object? value) => switch (value) {
    'PENDING_DOCTOR' => pendingDoctor,
    'PENDING_PATIENT_TIME_CONFIRMATION' => pendingPatientTimeConfirmation,
    'FULFILLED' => fulfilled,
    'CANCELLED_BY_PATIENT' => cancelledByPatient,
    'CANCELLED_BY_DOCTOR' => cancelledByDoctor,
    'EXPIRED' => expired,
    _ => throw FormatException('Unknown booking-request status: $value'),
  };
}

enum ScheduledAppointmentStatus {
  confirmed('CONFIRMED'),
  inProgress('IN_PROGRESS'),
  cancelled('CANCELLED'),
  completed('COMPLETED'),
  noShow('NO_SHOW');

  const ScheduledAppointmentStatus(this.wireName);
  final String wireName;

  static ScheduledAppointmentStatus parse(Object? value) => switch (value) {
    'CONFIRMED' => confirmed,
    'IN_PROGRESS' => inProgress,
    'CANCELLED' => cancelled,
    'COMPLETED' => completed,
    'NO_SHOW' => noShow,
    _ => throw FormatException('Unknown appointment status: $value'),
  };
}

enum ScheduledCareAction {
  acceptRequest('ACCEPT_REQUEST'),
  proposeNewTime('PROPOSE_NEW_TIME'),
  declineRequest('DECLINE_REQUEST'),
  cancelRequest('CANCEL_REQUEST'),
  acceptProposedTime('ACCEPT_PROPOSED_TIME'),
  declineProposedTime('DECLINE_PROPOSED_TIME'),
  cancelAppointment('CANCEL_APPOINTMENT'),
  prepareVisit('PREPARE_VISIT');

  const ScheduledCareAction(this.wireName);
  final String wireName;

  static ScheduledCareAction parse(Object? value) => switch (value) {
    'ACCEPT_REQUEST' => acceptRequest,
    'PROPOSE_NEW_TIME' => proposeNewTime,
    'DECLINE_REQUEST' => declineRequest,
    'CANCEL_REQUEST' => cancelRequest,
    'ACCEPT_PROPOSED_TIME' => acceptProposedTime,
    'DECLINE_PROPOSED_TIME' => declineProposedTime,
    'CANCEL_APPOINTMENT' => cancelAppointment,
    'PREPARE_VISIT' => prepareVisit,
    _ => throw FormatException('Unknown scheduled-care action: $value'),
  };
}

enum ScheduledCareBucket {
  upcoming('UPCOMING'),
  past('PAST'),
  cancelled('CANCELLED');

  const ScheduledCareBucket(this.wireName);
  final String wireName;
}

class CareSubject {
  const CareSubject({
    required this.type,
    required this.displayName,
    required this.relationship,
    this.familyMemberId,
  }) : assert(
         (type == CareSubjectType.self && familyMemberId == null) ||
             (type == CareSubjectType.familyMember && familyMemberId != null),
         'SELF must not carry a family member id; FAMILY_MEMBER must carry one.',
       );

  final CareSubjectType type;
  final String? familyMemberId;
  final String displayName;
  final String relationship;

  Map<String, dynamic> toCreateJson() => {
    'subjectType': type.wireName,
    if (type == CareSubjectType.familyMember) 'familyMemberId': familyMemberId,
  };

  factory CareSubject.fromJson(Map<String, dynamic> json) {
    final type = CareSubjectType.parse(json['subjectType']);
    final familyMemberId = _optionalString(json, 'familyMemberId');
    if (type == CareSubjectType.familyMember && familyMemberId == null) {
      throw const FormatException('FAMILY_MEMBER requires familyMemberId.');
    }
    return CareSubject(
      type: type,
      familyMemberId: familyMemberId,
      displayName: _requiredString(json, 'displayName'),
      relationship:
          _optionalString(json, 'relationship') ??
          (type == CareSubjectType.self ? 'SELF' : 'FAMILY_MEMBER'),
    );
  }
}

class ScheduledCareCabinet {
  const ScheduledCareCabinet({
    required this.practiceLocationId,
    required this.name,
    required this.address,
    required this.city,
    this.governorate = '',
    this.timezone = '',
  });

  final String practiceLocationId;
  final String name;
  final String address;
  final String city;
  final String governorate;
  final String timezone;

  factory ScheduledCareCabinet.fromJson(Map<String, dynamic> json) =>
      ScheduledCareCabinet(
        practiceLocationId: _requiredString(json, 'practiceLocationId'),
        name: _requiredString(json, 'name'),
        address: _requiredString(json, 'address'),
        city: _requiredString(json, 'city'),
        governorate: _optionalString(json, 'governorate') ?? '',
        timezone: _optionalString(json, 'timezone') ?? '',
      );
}

class ScheduledCareSlot {
  const ScheduledCareSlot({
    required this.start,
    required this.end,
    this.timezone,
  });

  final DateTime start;
  final DateTime end;
  final String? timezone;
  int get durationMinutes => end.difference(start).inMinutes;

  Map<String, dynamic> toJson() => {
    // These are the exact parsed backend instants, normalized without changing
    // the instant. Never synthesize a duration or round either boundary.
    'start': start.toUtc().toIso8601String(),
    'end': end.toUtc().toIso8601String(),
  };

  factory ScheduledCareSlot.fromJson(Map<String, dynamic> json) =>
      ScheduledCareSlot(
        start: _requiredInstant(json, 'start'),
        end: _requiredInstant(json, 'end'),
        timezone: _optionalString(json, 'timezone'),
      );
}

class AvailabilityWindow {
  const AvailabilityWindow({
    required this.doctorId,
    required this.practiceLocationId,
    required this.timezone,
    required this.generatedAt,
    required this.slots,
  });

  final String doctorId;
  final String practiceLocationId;
  final String timezone;
  final DateTime generatedAt;
  final List<ScheduledCareSlot> slots;

  factory AvailabilityWindow.fromJson(Map<String, dynamic> json) =>
      AvailabilityWindow(
        doctorId: _requiredString(json, 'doctorId'),
        practiceLocationId: _requiredString(json, 'practiceLocationId'),
        timezone: _requiredString(json, 'timezone'),
        generatedAt: _requiredInstant(json, 'generatedAt'),
        slots: _mapList(json, 'slots', ScheduledCareSlot.fromJson),
      );
}

class ScheduledCareDoctor {
  const ScheduledCareDoctor({
    required this.doctorId,
    required this.displayName,
    required this.specialty,
  });

  final String doctorId;
  final String displayName;
  final String specialty;

  factory ScheduledCareDoctor.fromJson(Map<String, dynamic> json) =>
      ScheduledCareDoctor(
        doctorId: _requiredString(json, 'doctorId'),
        displayName: _requiredString(json, 'displayName'),
        specialty: _optionalString(json, 'specialty') ?? '',
      );
}

class ProposedSlot extends ScheduledCareSlot {
  const ProposedSlot({
    required this.proposalId,
    required super.start,
    required super.end,
    required this.proposedAt,
    required this.patientResponseDeadline,
  });

  final String proposalId;
  final DateTime proposedAt;
  final DateTime patientResponseDeadline;

  factory ProposedSlot.fromJson(Map<String, dynamic> json) => ProposedSlot(
    proposalId: _requiredString(json, 'proposalId'),
    start: _requiredInstant(json, 'start'),
    end: _requiredInstant(json, 'end'),
    proposedAt: _requiredInstant(json, 'proposedAt'),
    patientResponseDeadline: _requiredInstant(json, 'patientResponseDeadline'),
  );
}

class ScheduledCareCancellation {
  const ScheduledCareCancellation({
    required this.actor,
    required this.reasonCode,
    required this.cancelledAt,
    this.lateCancellation = false,
  });

  final String actor;
  final String reasonCode;
  final DateTime cancelledAt;
  final bool lateCancellation;

  factory ScheduledCareCancellation.fromJson(Map<String, dynamic> json) =>
      ScheduledCareCancellation(
        actor: _requiredString(json, 'actor'),
        reasonCode: _requiredString(json, 'reasonCode'),
        cancelledAt: _requiredInstant(json, 'cancelledAt'),
        lateCancellation: json['lateCancellation'] == true,
      );
}

class PatientBookingRequest {
  const PatientBookingRequest({
    required this.requestId,
    required this.version,
    required this.status,
    required this.subject,
    required this.doctor,
    required this.cabinet,
    required this.originalRequestedSlot,
    required this.activeSlot,
    required this.createdAt,
    required this.responseDeadline,
    required this.availableActions,
    required this.updatedAt,
    this.proposedSlot,
    this.confirmedAppointmentId,
    this.cancellation,
    this.expiredAt,
  });

  final String requestId;
  final int version;
  final String status;
  final CareSubject subject;
  final ScheduledCareDoctor doctor;
  final ScheduledCareCabinet cabinet;
  final ScheduledCareSlot originalRequestedSlot;
  final ProposedSlot? proposedSlot;
  final ScheduledCareSlot activeSlot;
  final DateTime createdAt;
  final DateTime responseDeadline;
  final String? confirmedAppointmentId;
  final ScheduledCareCancellation? cancellation;
  final DateTime? expiredAt;
  final Set<String> availableActions;
  final DateTime updatedAt;

  bool can(String action) => availableActions.contains(action);

  factory PatientBookingRequest.fromJson(Map<String, dynamic> json) {
    final original = ScheduledCareSlot.fromJson(
      _requiredMap(json, 'originalRequestedSlot'),
    );
    final proposedJson = _optionalMap(json, 'proposedSlot');
    final proposed = proposedJson == null
        ? null
        : ProposedSlot.fromJson(proposedJson);
    final activeJson = _optionalMap(json, 'activeSlot');
    return PatientBookingRequest(
      requestId: _requiredString(json, 'requestId'),
      version: _requiredInt(json, 'version'),
      status: _requiredString(json, 'status'),
      subject: CareSubject.fromJson(_requiredMap(json, 'subject')),
      doctor: ScheduledCareDoctor.fromJson(_requiredMap(json, 'doctor')),
      cabinet: ScheduledCareCabinet.fromJson(_requiredMap(json, 'cabinet')),
      originalRequestedSlot: original,
      proposedSlot: proposed,
      activeSlot: activeJson == null
          ? proposed ?? original
          : ScheduledCareSlot.fromJson(activeJson),
      createdAt: _requiredInstant(json, 'createdAt'),
      responseDeadline: _requiredInstant(json, 'responseDeadline'),
      confirmedAppointmentId: _optionalString(json, 'confirmedAppointmentId'),
      cancellation: _optionalMap(json, 'cancellation') == null
          ? null
          : ScheduledCareCancellation.fromJson(
              _optionalMap(json, 'cancellation')!,
            ),
      expiredAt: _optionalInstant(json, 'expiredAt'),
      availableActions: _stringSet(json, 'availableActions'),
      updatedAt: _requiredInstant(json, 'updatedAt'),
    );
  }
}

class ConfirmedScheduledAppointment {
  const ConfirmedScheduledAppointment({
    required this.appointmentId,
    required this.sourceBookingRequestId,
    required this.version,
    required this.status,
    required this.doctor,
    required this.subject,
    required this.cabinet,
    required this.slot,
    required this.confirmedAt,
    required this.createdAt,
    required this.updatedAt,
    required this.intakeStatus,
    required this.availableActions,
    this.cancellation,
  });

  final String appointmentId;
  final String sourceBookingRequestId;
  final int version;
  final String status;
  final ScheduledCareDoctor doctor;
  final CareSubject subject;
  final ScheduledCareCabinet cabinet;
  final ScheduledCareSlot slot;
  final DateTime confirmedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final ScheduledCareCancellation? cancellation;
  final String intakeStatus;
  final Set<String> availableActions;

  bool can(String action) => availableActions.contains(action);

  factory ConfirmedScheduledAppointment.fromJson(Map<String, dynamic> json) =>
      ConfirmedScheduledAppointment(
        appointmentId: _requiredString(json, 'appointmentId'),
        sourceBookingRequestId: _requiredString(json, 'sourceBookingRequestId'),
        version: _requiredInt(json, 'version'),
        status: _requiredString(json, 'status'),
        doctor: ScheduledCareDoctor.fromJson(_requiredMap(json, 'doctor')),
        subject: CareSubject.fromJson(_requiredMap(json, 'subject')),
        cabinet: ScheduledCareCabinet.fromJson(_requiredMap(json, 'cabinet')),
        slot: ScheduledCareSlot.fromJson(_requiredMap(json, 'slot')),
        confirmedAt: _requiredInstant(json, 'confirmedAt'),
        createdAt: _requiredInstant(json, 'createdAt'),
        updatedAt: _requiredInstant(json, 'updatedAt'),
        cancellation: _optionalMap(json, 'cancellation') == null
            ? null
            : ScheduledCareCancellation.fromJson(
                _optionalMap(json, 'cancellation')!,
              ),
        intakeStatus: _optionalString(json, 'intakeStatus') ?? 'NOT_SUBMITTED',
        availableActions: _stringSet(json, 'availableActions'),
      );
}

class ProposalAcceptance {
  const ProposalAcceptance({required this.request, required this.appointment});
  final PatientBookingRequest request;
  final ConfirmedScheduledAppointment appointment;

  factory ProposalAcceptance.fromJson(Map<String, dynamic> json) =>
      ProposalAcceptance(
        request: PatientBookingRequest.fromJson(_requiredMap(json, 'request')),
        appointment: ConfirmedScheduledAppointment.fromJson(
          _requiredMap(json, 'appointment'),
        ),
      );
}

class ScheduledCareListItem {
  const ScheduledCareListItem({
    required this.resourceType,
    required this.version,
    required this.status,
    required this.doctorName,
    required this.doctorSpecialty,
    required this.subjectType,
    required this.subjectDisplayName,
    required this.subjectRelationship,
    required this.cabinetName,
    required this.address,
    required this.city,
    required this.governorate,
    required this.timezone,
    required this.start,
    required this.end,
    required this.availableActions,
    required this.sortAt,
    required this.updatedAt,
    this.requestId,
    this.appointmentId,
    this.sourceBookingRequestId,
    this.responseDeadline,
    this.cancellation,
    this.intakeStatus,
  }) : assert(
         resourceType != ScheduledCareResourceType.bookingRequest ||
             (requestId != null && appointmentId == null),
       ),
       assert(
         resourceType != ScheduledCareResourceType.appointment ||
             appointmentId != null,
       );

  final ScheduledCareResourceType resourceType;
  final String? requestId;
  final String? appointmentId;
  final String? sourceBookingRequestId;
  final int version;
  final String status;
  final String doctorName;
  final String doctorSpecialty;
  final CareSubjectType subjectType;
  final String subjectDisplayName;
  final String subjectRelationship;
  final String cabinetName;
  final String address;
  final String city;
  final String governorate;
  final String timezone;
  final DateTime start;
  final DateTime end;
  final DateTime? responseDeadline;
  final ScheduledCareCancellation? cancellation;
  final String? intakeStatus;
  final Set<String> availableActions;
  final DateTime sortAt;
  final DateTime updatedAt;

  String get resourceId =>
      resourceType == ScheduledCareResourceType.bookingRequest
      ? requestId!
      : appointmentId!;

  factory ScheduledCareListItem.fromJson(Map<String, dynamic> json) {
    final doctor = _requiredMap(json, 'doctor');
    final subject = _requiredMap(json, 'subject');
    final cabinet = _requiredMap(json, 'cabinet');
    final resourceType = ScheduledCareResourceType.parse(json['resourceType']);
    final requestId = _optionalString(json, 'requestId');
    final appointmentId = _optionalString(json, 'appointmentId');
    if ((resourceType == ScheduledCareResourceType.bookingRequest &&
            (requestId == null || appointmentId != null)) ||
        (resourceType == ScheduledCareResourceType.appointment &&
            appointmentId == null)) {
      throw const FormatException('Scheduled-care resource ids are invalid.');
    }
    return ScheduledCareListItem(
      resourceType: resourceType,
      requestId: requestId,
      appointmentId: appointmentId,
      sourceBookingRequestId: _optionalString(json, 'sourceBookingRequestId'),
      version: _requiredInt(json, 'version'),
      status: _requiredString(json, 'status'),
      doctorName: _requiredString(doctor, 'displayName'),
      doctorSpecialty: _optionalString(doctor, 'specialty') ?? '',
      subjectType: CareSubjectType.parse(subject['subjectType']),
      subjectDisplayName: _requiredString(subject, 'displayName'),
      subjectRelationship: _optionalString(subject, 'relationship') ?? '',
      cabinetName: _requiredString(cabinet, 'name'),
      address: _optionalString(cabinet, 'address') ?? '',
      city: _optionalString(cabinet, 'city') ?? '',
      governorate: _optionalString(cabinet, 'governorate') ?? '',
      timezone: _requiredString(cabinet, 'timezone'),
      start: _requiredInstant(json, 'start'),
      end: _requiredInstant(json, 'end'),
      responseDeadline: _optionalInstant(json, 'responseDeadline'),
      cancellation: _optionalMap(json, 'cancellation') == null
          ? null
          : ScheduledCareCancellation.fromJson(
              _optionalMap(json, 'cancellation')!,
            ),
      intakeStatus: _optionalString(json, 'intakeStatus'),
      availableActions: _stringSet(json, 'availableActions'),
      sortAt: _requiredInstant(json, 'sortAt'),
      updatedAt: _requiredInstant(json, 'updatedAt'),
    );
  }
}

class ScheduledCarePage {
  const ScheduledCarePage({required this.items, this.nextCursor});
  final List<ScheduledCareListItem> items;
  final String? nextCursor;

  factory ScheduledCarePage.fromJson(Map<String, dynamic> json) =>
      ScheduledCarePage(
        items: _mapList(json, 'items', ScheduledCareListItem.fromJson),
        nextCursor: _optionalString(json, 'nextCursor'),
      );
}

class ScheduledCareEvent {
  const ScheduledCareEvent({
    required this.eventId,
    required this.eventType,
    required this.resourceType,
    required this.resourceId,
    required this.version,
    required this.occurredAt,
  });
  final String eventId;
  final String eventType;
  final ScheduledCareResourceType resourceType;
  final String resourceId;
  final int version;
  final DateTime occurredAt;

  factory ScheduledCareEvent.fromJson(Map<String, dynamic> json) =>
      ScheduledCareEvent(
        eventId: _requiredString(json, 'eventId'),
        eventType: _requiredString(json, 'eventType'),
        resourceType: ScheduledCareResourceType.parse(json['resourceType']),
        resourceId: _requiredString(json, 'resourceId'),
        version: _requiredInt(json, 'version'),
        occurredAt: _requiredInstant(json, 'occurredAt'),
      );
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Missing or invalid $key.');
  }
  return value;
}

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! String) throw FormatException('Invalid $key.');
  final normalized = value.trim();
  return normalized.isEmpty ? null : normalized;
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  if (value is num) return value.toInt();
  throw FormatException('Missing or invalid $key.');
}

DateTime _requiredInstant(Map<String, dynamic> json, String key) {
  final value = _requiredString(json, key);
  final parsed = DateTime.tryParse(value);
  if (parsed == null || !parsed.isUtc) {
    throw FormatException('$key must be an RFC 3339 UTC instant.');
  }
  return parsed;
}

DateTime? _optionalInstant(Map<String, dynamic> json, String key) {
  if (json[key] == null) return null;
  return _requiredInstant(json, key);
}

Map<String, dynamic> _requiredMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! Map) throw FormatException('Missing or invalid $key.');
  return value.cast<String, dynamic>();
}

Map<String, dynamic>? _optionalMap(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is! Map) throw FormatException('Invalid $key.');
  return value.cast<String, dynamic>();
}

List<T> _mapList<T>(
  Map<String, dynamic> json,
  String key,
  T Function(Map<String, dynamic>) parse,
) {
  final value = json[key];
  if (value is! List) throw FormatException('Missing or invalid $key.');
  return List.unmodifiable(
    value.map((item) {
      if (item is! Map) throw FormatException('Invalid $key entry.');
      return parse(item.cast<String, dynamic>());
    }),
  );
}

Set<String> _stringSet(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List || value.any((item) => item is! String)) {
    throw FormatException('Missing or invalid $key.');
  }
  return Set.unmodifiable(value.cast<String>());
}

DateTime displayInTimeZone(DateTime instant, String timezone) {
  try {
    return tz.TZDateTime.from(instant.toUtc(), tz.getLocation(timezone));
  } on Object {
    // Tests and isolated embedders can invoke presentation helpers before the
    // timezone database is initialized. The app initializes it before runApp.
    return instant.toLocal();
  }
}
