import '../../auth/application/auth_role_family.dart';
import '../domain/notification_models.dart';

enum NotificationNavigationResource {
  bookingRequest,
  appointment,
  urgentCabinetRequest,
  // G-1 D2 / D4 (patient): answered in « Mes rendez-vous » or the window.
  accessRequest,
  followUpProposal,
  followUpWithdrawn,
}

/// G-1 D2 / D4 patient destinations (« Mes rendez-vous » / access window).
bool isPendingAnswerResource(NotificationNavigationResource? resource) =>
    resource == NotificationNavigationResource.accessRequest ||
    resource == NotificationNavigationResource.followUpProposal ||
    resource == NotificationNavigationResource.followUpWithdrawn;

enum NotificationNavigationStatus { target, noDestination, unavailable }

class PendingNotificationOpenIdentity {
  const PendingNotificationOpenIdentity({
    required this.type,
    required this.resourceId,
    required this.createdAt,
    this.accountScope,
    this.expiresAt,
  });

  final String type;
  final String resourceId;
  final DateTime createdAt;
  final String? accountScope;
  final DateTime? expiresAt;

  bool get isExpired =>
      expiresAt != null && !expiresAt!.isAfter(DateTime.now().toUtc());

  @override
  String toString() => 'PendingNotificationOpenIdentity($type)';
}

class NotificationNavigationResolution {
  const NotificationNavigationResolution._({
    required this.status,
    this.resource,
    this.resourceId,
  });

  const NotificationNavigationResolution.target(
    NotificationNavigationResource resource,
    String resourceId,
  ) : this._(
        status: NotificationNavigationStatus.target,
        resource: resource,
        resourceId: resourceId,
      );

  static const noDestination = NotificationNavigationResolution._(
    status: NotificationNavigationStatus.noDestination,
  );
  static const unavailable = NotificationNavigationResolution._(
    status: NotificationNavigationStatus.unavailable,
  );

  final NotificationNavigationStatus status;
  final NotificationNavigationResource? resource;
  final String? resourceId;
}

class NotificationNavigationResolver {
  const NotificationNavigationResolver._();

  static NotificationNavigationResolution resolve(
    InboxNotification notification,
    AuthRoleFamily role,
  ) {
    final rule = _rules[notification.type];
    if (rule == null) return NotificationNavigationResolution.noDestination;
    // A targeted CABINET alert may outlive its five-minute decision window.
    // Its UUID remains only a lookup reference: the Doctor detail endpoint
    // reconciles and returns the authoritative terminal state with no actions.
    if (notification.isExpired &&
        notification.type != 'URGENT_CABINET_REQUEST_TARGETED') {
      return NotificationNavigationResolution.unavailable;
    }
    if (rule.role != role) {
      return NotificationNavigationResolution.noDestination;
    }
    final rawId = notification.deepLinkPayload[rule.idKey];
    if (rawId is! String || !isUuid(rawId)) {
      return NotificationNavigationResolution.unavailable;
    }
    return NotificationNavigationResolution.target(
      rule.resource,
      rawId.toLowerCase(),
    );
  }

  /// Validates only the opaque navigation identity from push/local payloads.
  /// Title, body, status, and all other business fields are intentionally
  /// ignored and never retained for cold-entry recovery.
  static PendingNotificationOpenIdentity? parsePendingPayload(
    Map<String, dynamic> payload, {
    String? accountScope,
    DateTime? now,
  }) {
    var type = payload['type']?.toString().trim() ?? '';
    _NotificationNavigationRule? rule = _rules[type];
    if (rule == null && payload['destination'] == 'URGENT_CABINET_REQUEST') {
      type = _legacyUrgentCabinetType;
      rule = _legacyUrgentCabinetRule;
    }
    if (rule == null) return null;
    final rawId = payload[rule.idKey];
    if (rawId is! String || !isUuid(rawId)) return null;
    final expiresAt = _optionalInstant(
      payload['expiresAt'] ?? payload['expires_at'],
    );
    final owner = accountScope?.trim();
    final identity = PendingNotificationOpenIdentity(
      type: type,
      resourceId: rawId.toLowerCase(),
      accountScope: owner == null || owner.isEmpty ? null : owner,
      createdAt: (now ?? DateTime.now()).toUtc(),
      expiresAt: expiresAt,
    );
    return identity.isExpired ? null : identity;
  }

  static NotificationNavigationResolution resolvePending(
    PendingNotificationOpenIdentity identity,
    AuthRoleFamily role, {
    required String accountScope,
  }) {
    if (identity.isExpired) return NotificationNavigationResolution.unavailable;
    final owner = identity.accountScope;
    if (owner != null && owner != accountScope.trim()) {
      return NotificationNavigationResolution.unavailable;
    }
    if (identity.type == _legacyUrgentCabinetType) {
      if (role != AuthRoleFamily.patient && role != AuthRoleFamily.doctor) {
        return NotificationNavigationResolution.noDestination;
      }
      return NotificationNavigationResolution.target(
        NotificationNavigationResource.urgentCabinetRequest,
        identity.resourceId,
      );
    }
    final rule = _rules[identity.type];
    if (rule == null || rule.role != role) {
      return NotificationNavigationResolution.noDestination;
    }
    return NotificationNavigationResolution.target(
      rule.resource,
      identity.resourceId,
    );
  }

  static DateTime? _optionalInstant(Object? raw) {
    if (raw is! String || raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw)?.toUtc();
  }

  static const _legacyUrgentCabinetType = '_URGENT_CABINET_OPEN';
  static const _legacyUrgentCabinetRule = _NotificationNavigationRule(
    role: AuthRoleFamily.unsupported,
    resource: NotificationNavigationResource.urgentCabinetRequest,
    idKey: 'request_id',
  );

  static const Map<String, _NotificationNavigationRule> _rules = {
    'DOCTOR_BOOKING_REQUEST_CREATED': _NotificationNavigationRule(
      role: AuthRoleFamily.doctor,
      resource: NotificationNavigationResource.bookingRequest,
      idKey: 'request_id',
    ),
    'DOCTOR_BOOKING_TIME_PROPOSED': _NotificationNavigationRule(
      role: AuthRoleFamily.patient,
      resource: NotificationNavigationResource.bookingRequest,
      idKey: 'request_id',
    ),
    'DOCTOR_BOOKING_REQUEST_DECLINED': _NotificationNavigationRule(
      role: AuthRoleFamily.patient,
      resource: NotificationNavigationResource.bookingRequest,
      idKey: 'request_id',
    ),
    'DOCTOR_BOOKING_REQUEST_CANCELLED_BY_PATIENT': _NotificationNavigationRule(
      role: AuthRoleFamily.doctor,
      resource: NotificationNavigationResource.bookingRequest,
      idKey: 'request_id',
    ),
    'DOCTOR_BOOKING_PROPOSAL_ACCEPTED': _NotificationNavigationRule(
      role: AuthRoleFamily.doctor,
      resource: NotificationNavigationResource.appointment,
      idKey: 'appointment_id',
    ),
    'DOCTOR_BOOKING_PROPOSAL_DECLINED': _NotificationNavigationRule(
      role: AuthRoleFamily.doctor,
      resource: NotificationNavigationResource.bookingRequest,
      idKey: 'request_id',
    ),
    'DOCTOR_BOOKING_REQUEST_EXPIRED': _NotificationNavigationRule(
      role: AuthRoleFamily.patient,
      resource: NotificationNavigationResource.bookingRequest,
      idKey: 'request_id',
    ),
    'DOCTOR_BOOKING_PROPOSAL_EXPIRED': _NotificationNavigationRule(
      role: AuthRoleFamily.doctor,
      resource: NotificationNavigationResource.bookingRequest,
      idKey: 'request_id',
    ),
    'APPOINTMENT_CONFIRMED': _NotificationNavigationRule(
      role: AuthRoleFamily.patient,
      resource: NotificationNavigationResource.appointment,
      idKey: 'appointment_id',
    ),
    'APPOINTMENT_CANCELLED_BY_PATIENT': _NotificationNavigationRule(
      role: AuthRoleFamily.doctor,
      resource: NotificationNavigationResource.appointment,
      idKey: 'appointment_id',
    ),
    'APPOINTMENT_CANCELLED_BY_PROFESSIONAL': _NotificationNavigationRule(
      role: AuthRoleFamily.patient,
      resource: NotificationNavigationResource.appointment,
      idKey: 'appointment_id',
    ),
    'URGENT_CABINET_REQUEST_TARGETED': _NotificationNavigationRule(
      role: AuthRoleFamily.doctor,
      resource: NotificationNavigationResource.urgentCabinetRequest,
      idKey: 'request_id',
    ),
    'URGENT_CABINET_REQUEST_ACCEPTED': _NotificationNavigationRule(
      role: AuthRoleFamily.patient,
      resource: NotificationNavigationResource.urgentCabinetRequest,
      idKey: 'request_id',
    ),
    'URGENT_CABINET_REQUEST_DECLINED': _NotificationNavigationRule(
      role: AuthRoleFamily.patient,
      resource: NotificationNavigationResource.urgentCabinetRequest,
      idKey: 'request_id',
    ),
    'URGENT_CABINET_REQUEST_EXPIRED': _NotificationNavigationRule(
      role: AuthRoleFamily.patient,
      resource: NotificationNavigationResource.urgentCabinetRequest,
      idKey: 'request_id',
    ),
    'URGENT_CABINET_REQUEST_CANCELLED': _NotificationNavigationRule(
      role: AuthRoleFamily.patient,
      resource: NotificationNavigationResource.urgentCabinetRequest,
      idKey: 'request_id',
    ),
    // G-1 D2 / D4: payloads carry the id only (request_id / appointment_id).
    'ACCESS_REQUESTED': _NotificationNavigationRule(
      role: AuthRoleFamily.patient,
      resource: NotificationNavigationResource.accessRequest,
      idKey: 'request_id',
    ),
    'FOLLOW_UP_PROPOSED': _NotificationNavigationRule(
      role: AuthRoleFamily.patient,
      resource: NotificationNavigationResource.followUpProposal,
      idKey: 'appointment_id',
    ),
    'FOLLOW_UP_WITHDRAWN': _NotificationNavigationRule(
      role: AuthRoleFamily.patient,
      resource: NotificationNavigationResource.followUpWithdrawn,
      idKey: 'appointment_id',
    ),
    'URGENT_CABINET_COMMITMENT_WITHDRAWN': _NotificationNavigationRule(
      // P4 withdrawal invalidates the accepted Doctor responsibility. The
      // Patient initiated the command, but the notification recipient and
      // navigation authority are the exact commitment Doctor.
      role: AuthRoleFamily.doctor,
      resource: NotificationNavigationResource.urgentCabinetRequest,
      idKey: 'request_id',
    ),
  };
}

class _NotificationNavigationRule {
  const _NotificationNavigationRule({
    required this.role,
    required this.resource,
    required this.idKey,
  });

  final AuthRoleFamily role;
  final NotificationNavigationResource resource;
  final String idKey;
}
