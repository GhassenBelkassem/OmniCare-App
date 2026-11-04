import '../../auth/application/auth_role_family.dart';
import '../domain/notification_models.dart';

enum NotificationNavigationResource {
  bookingRequest,
  appointment,
  urgentCabinetRequest,
}

enum NotificationNavigationStatus { target, noDestination, unavailable }

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
