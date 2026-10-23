enum InboxNotificationPriority { critical, high, medium, low, unknown }

enum InboxNotificationCategory {
  consultation,
  appointment,
  kine,
  nurse,
  medication,
  passport,
  message,
  clinicOps,
  admin,
  unknown,
}

class NotificationContractException implements Exception {
  const NotificationContractException(this.message);

  final String message;

  @override
  String toString() => message;
}

class InboxNotification {
  const InboxNotification({
    required this.id,
    required this.type,
    required this.priority,
    required this.rawPriority,
    required this.category,
    required this.rawCategory,
    required this.titleFr,
    required this.bodyFr,
    required this.titleAr,
    required this.bodyAr,
    required this.deepLinkPayload,
    required this.isRead,
    required this.createdAt,
  });

  final String id;
  final String type;
  final InboxNotificationPriority priority;
  final String rawPriority;
  final InboxNotificationCategory category;
  final String rawCategory;
  final String titleFr;
  final String bodyFr;
  final String? titleAr;
  final String? bodyAr;
  final Map<String, dynamic> deepLinkPayload;
  final bool isRead;
  final DateTime createdAt;

  InboxNotification copyWith({bool? isRead}) => InboxNotification(
    id: id,
    type: type,
    priority: priority,
    rawPriority: rawPriority,
    category: category,
    rawCategory: rawCategory,
    titleFr: titleFr,
    bodyFr: bodyFr,
    titleAr: titleAr,
    bodyAr: bodyAr,
    deepLinkPayload: deepLinkPayload,
    isRead: isRead ?? this.isRead,
    createdAt: createdAt,
  );

  static InboxNotification fromJson(Map<String, dynamic> json) {
    final id = _requiredString(json, 'id');
    if (!isUuid(id)) {
      throw const NotificationContractException('Invalid notification id.');
    }
    final type = _requiredString(json, 'type');
    final rawPriority = _requiredString(json, 'priority').toUpperCase();
    final rawCategory = _requiredString(json, 'category').toUpperCase();
    final read = json['read'];
    if (read is! bool) {
      throw const NotificationContractException('Invalid read state.');
    }
    final createdAtRaw = _requiredString(json, 'createdAt');
    final createdAt = DateTime.tryParse(createdAtRaw);
    if (createdAt == null || !_hasInstantZone(createdAtRaw)) {
      throw const NotificationContractException('Invalid createdAt instant.');
    }
    final payload = json['deepLinkPayload'];
    if (payload != null && payload is! Map) {
      throw const NotificationContractException(
        'Invalid notification deep-link payload.',
      );
    }
    return InboxNotification(
      id: id.toLowerCase(),
      type: type,
      priority: _priority(rawPriority),
      rawPriority: rawPriority,
      category: _category(rawCategory),
      rawCategory: rawCategory,
      titleFr: _requiredString(json, 'titleFr'),
      bodyFr: _requiredString(json, 'bodyFr'),
      titleAr: _optionalString(json['titleAr']),
      bodyAr: _optionalString(json['bodyAr']),
      deepLinkPayload: Map<String, dynamic>.unmodifiable(
        payload == null ? const {} : payload.cast<String, dynamic>(),
      ),
      isRead: read,
      createdAt: createdAt.toUtc(),
    );
  }

  static InboxNotificationPriority _priority(String value) => switch (value) {
    'CRITICAL' => InboxNotificationPriority.critical,
    'HIGH' => InboxNotificationPriority.high,
    'MEDIUM' => InboxNotificationPriority.medium,
    'LOW' => InboxNotificationPriority.low,
    _ => InboxNotificationPriority.unknown,
  };

  static InboxNotificationCategory _category(String value) => switch (value) {
    'CONSULTATION' => InboxNotificationCategory.consultation,
    'APPOINTMENT' => InboxNotificationCategory.appointment,
    'KINE' => InboxNotificationCategory.kine,
    'NURSE' => InboxNotificationCategory.nurse,
    'MEDICATION' => InboxNotificationCategory.medication,
    'PASSPORT' => InboxNotificationCategory.passport,
    'MESSAGE' => InboxNotificationCategory.message,
    'CLINIC_OPS' => InboxNotificationCategory.clinicOps,
    'ADMIN' => InboxNotificationCategory.admin,
    _ => InboxNotificationCategory.unknown,
  };
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

  bool get hasMore => (page + 1) * pageSize < totalElements;

  static NotificationPage fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final page = json['page'];
    final pageSize = json['pageSize'];
    final totalElements = json['totalElements'];
    final unreadCount = json['unreadCount'];
    if (rawItems is! List ||
        page is! int ||
        page < 0 ||
        pageSize is! int ||
        pageSize <= 0 ||
        totalElements is! int ||
        totalElements < 0 ||
        unreadCount is! int ||
        unreadCount < 0) {
      throw const NotificationContractException('Invalid notification page.');
    }
    final items = <InboxNotification>[];
    for (final value in rawItems) {
      if (value is! Map) continue;
      try {
        items.add(InboxNotification.fromJson(value.cast<String, dynamic>()));
      } on NotificationContractException {
        // One malformed item must not make the durable inbox unusable.
      } on TypeError {
        // Deep-link maps with non-string keys are malformed and are skipped.
      }
    }
    return NotificationPage(
      items: List.unmodifiable(items),
      page: page,
      pageSize: pageSize,
      totalElements: totalElements,
      unreadCount: unreadCount,
    );
  }
}

class NotificationListQuery {
  const NotificationListQuery({
    this.category,
    this.unreadOnly = false,
    this.page = 0,
    this.pageSize = 20,
  });

  final String? category;
  final bool unreadOnly;
  final int page;
  final int pageSize;

  Map<String, dynamic> toQueryParameters() => <String, dynamic>{
    if (category?.trim().isNotEmpty ?? false)
      'category': category!.trim().toUpperCase(),
    if (unreadOnly) 'unreadOnly': true,
    'page': page,
    'pageSize': pageSize,
  };
}

bool isUuid(String value) => RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
).hasMatch(value);

bool _hasInstantZone(String value) =>
    RegExp(r'(?:[zZ]|[+-]\d{2}:\d{2})$').hasMatch(value);

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) return value.trim();
  throw NotificationContractException('Missing notification field: $key.');
}

String? _optionalString(Object? value) =>
    value is String && value.trim().isNotEmpty ? value.trim() : null;
