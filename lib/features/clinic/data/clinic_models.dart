/// Strictly parsed clinic contract models for Phase 1.
///
/// Every factory validates the identifiers and enumerations it depends on and
/// throws [ClinicContractException] when the payload cannot be trusted. Nothing
/// here is guessed: an unknown professional role, a missing identifier or a
/// malformed object fails instead of degrading into a partially valid state.
library;

import 'package:intl/intl.dart';

class ClinicContractException implements Exception {
  const ClinicContractException(this.reason);

  /// Developer-facing reason. Never rendered to the user.
  final String reason;

  @override
  String toString() => 'ClinicContractException: $reason';
}

/// Access family resolved by `GET /me/access`.
enum ClinicAccessFamily {
  admin('ADMIN'),
  doctor('DOCTOR'),
  clinic('CLINIC');

  const ClinicAccessFamily(this.wireValue);

  final String wireValue;

  static ClinicAccessFamily parse(String? value) {
    final normalized = value?.trim().toUpperCase();
    for (final family in ClinicAccessFamily.values) {
      if (family.wireValue == normalized) return family;
    }
    throw const ClinicContractException('Unsupported access family.');
  }
}

/// Professional role inside a clinic membership.
enum ClinicProfessionalRole {
  admin('CLINIC_ADMIN', 'Clinic administrator'),
  medecin('CLINIC_MEDECIN', 'Physician'),
  infirmiere('CLINIC_INFIRMIERE', 'Nurse'),
  kine('CLINIC_KINE', 'Physiotherapist'),
  assistant('CLINIC_ASSISTANT', 'Clinic assistant');

  const ClinicProfessionalRole(this.wireValue, this.label);

  final String wireValue;
  final String label;

  /// Roles whose day-to-day work happens on the professional mobile app.
  bool get isMobileOperational =>
      this == medecin || this == infirmiere || this == kine;

  /// Roles whose operational workspace lives on the web portal.
  bool get isWebFirst => this == admin || this == assistant;

  static ClinicProfessionalRole? tryParse(String? value) {
    final normalized = value?.trim().toUpperCase();
    if (normalized == null || normalized.isEmpty) return null;
    for (final role in ClinicProfessionalRole.values) {
      if (role.wireValue == normalized) return role;
    }
    return null;
  }

  static ClinicProfessionalRole parse(String? value) {
    final role = tryParse(value);
    if (role == null) {
      throw const ClinicContractException('Unsupported professional role.');
    }
    return role;
  }
}

/// Lifecycle status values the mobile app reasons about. Unknown values are
/// tolerated as [unknown] so a new backend status never crashes the app, while
/// still being treated as "not active".
enum ClinicLifecycleStatus {
  active('ACTIVE', 'Active'),
  pending('PENDING', 'Pending'),
  suspended('SUSPENDED', 'Suspended'),
  ended('ENDED', 'Ended'),
  inactive('INACTIVE', 'Inactive'),
  unknown('UNKNOWN', 'Unavailable');

  const ClinicLifecycleStatus(this.wireValue, this.label);

  final String wireValue;
  final String label;

  bool get isActive => this == active;

  static ClinicLifecycleStatus parse(String? value) {
    final normalized = value?.trim().toUpperCase();
    if (normalized == null || normalized.isEmpty) {
      throw const ClinicContractException('Missing status value.');
    }
    for (final status in ClinicLifecycleStatus.values) {
      if (status.wireValue == normalized) return status;
    }
    return ClinicLifecycleStatus.unknown;
  }
}

/// Reasons a membership can be unavailable, mapped to safe user-facing text.
enum ClinicUnavailabilityReason {
  membershipSuspended(
    'CLINIC_MEMBERSHIP_SUSPENDED',
    'Access to this clinic is currently suspended.',
  ),
  membershipEnded(
    'CLINIC_MEMBERSHIP_ENDED',
    'Your membership in this clinic has ended.',
  ),
  membershipRequired(
    'CLINIC_MEMBERSHIP_REQUIRED',
    'You are not a member of this clinic.',
  ),
  clinicNotActive('CLINIC_NOT_ACTIVE', 'This clinic is not active.'),
  roleInvalid(
    'CLINIC_PROFESSIONAL_ROLE_INVALID',
    'This role is not available on mobile.',
  ),
  unknown('UNKNOWN', 'This clinic is unavailable right now.');

  const ClinicUnavailabilityReason(this.wireValue, this.message);

  final String wireValue;

  /// Safe message. Never contains backend detail, identifiers or request IDs.
  final String message;

  static ClinicUnavailabilityReason parse(String? value) {
    final normalized = value?.trim().toUpperCase();
    if (normalized == null || normalized.isEmpty) {
      return ClinicUnavailabilityReason.unknown;
    }
    for (final reason in ClinicUnavailabilityReason.values) {
      if (reason.wireValue == normalized) return reason;
    }
    return ClinicUnavailabilityReason.unknown;
  }
}

/// Clinic feature modules planned for later phases. Phase 1 ships all of them
/// disabled; a flag that is missing or false must never enable an action.
enum ClinicFeatureModule {
  requests('CLINIC_REQUESTS_ENABLED', 'Care requests'),
  hospitalization('CLINIC_HOSPITALIZATION_ENABLED', 'Hospitalization'),
  surgery('CLINIC_SURGERY_ENABLED', 'Surgery'),
  urgent('CLINIC_URGENT_ENABLED', 'Urgent care'),
  mobileTasks('CLINIC_MOBILE_TASKS_ENABLED', 'Mobile tasks'),
  partnership('CLINIC_PARTNERSHIP_ENABLED', 'Partnerships');

  const ClinicFeatureModule(this.flagKey, this.label);

  final String flagKey;
  final String label;
}

/// Backend capability vocabulary used by the mobile access boundary.
enum ClinicCapability {
  overviewRead('CLINIC_OVERVIEW_READ', 'Clinic overview (read-only)'),
  profileRead('CLINIC_PROFILE_READ', 'Clinic profile (read-only)'),
  membershipSelfRead(
    'CLINIC_MEMBERSHIP_SELF_READ',
    'My membership (read-only)',
  ),
  caseIntakeRead('CLINIC_CASE_INTAKE_READ', 'Case intake (read-only)'),
  caseIntakeReview('CLINIC_CASE_INTAKE_REVIEW', 'Case intake review'),
  taskRead('CLINIC_TASK_READ', 'Operational tasks (read-only)'),
  taskHandover('CLINIC_TASK_HANDOVER', 'Task handovers'),
  taskReassign('CLINIC_TASK_REASSIGN', 'Task reassignment'),
  routingIncidentRead(
    'CLINIC_ROUTING_INCIDENT_READ',
    'Routing incidents (read-only)',
  ),
  routingIncidentRetry(
    'CLINIC_ROUTING_INCIDENT_RETRY',
    'Routing incident retry',
  ),
  staffRead('CLINIC_STAFF_READ', 'Staff (read-only)'),
  staffInvite('CLINIC_STAFF_INVITE', 'Staff invitations'),
  staffSuspend('CLINIC_STAFF_SUSPEND', 'Staff suspension'),
  staffReactivate('CLINIC_STAFF_REACTIVATE', 'Staff reactivation'),
  staffEnd('CLINIC_STAFF_END', 'Staff ending'),
  positionRead('CLINIC_POSITION_READ', 'Positions (read-only)'),
  positionManage('CLINIC_POSITION_MANAGE', 'Position management'),
  positionAssignmentRead(
    'CLINIC_POSITION_ASSIGNMENT_READ',
    'Position assignments (read-only)',
  ),
  positionAssignmentManage(
    'CLINIC_POSITION_ASSIGNMENT_MANAGE',
    'Position assignment management',
  ),
  responsibilityRead(
    'CLINIC_RESPONSIBILITY_READ',
    'Responsibilities (read-only)',
  ),
  responsibilityManage(
    'CLINIC_RESPONSIBILITY_MANAGE',
    'Responsibility management',
  );

  const ClinicCapability(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static ClinicCapability? tryParse(String? value) {
    final normalized = value?.trim().toUpperCase();
    if (normalized == null || normalized.isEmpty) return null;
    for (final capability in ClinicCapability.values) {
      if (capability.wireValue == normalized) return capability;
    }
    return null;
  }

  static ClinicCapability parse(String? value) {
    final capability = tryParse(value);
    if (capability == null) {
      throw const ClinicContractException('Unsupported clinic capability.');
    }
    return capability;
  }
}

class ClinicAccessResult {
  const ClinicAccessResult({required this.accessFamily});

  final ClinicAccessFamily accessFamily;

  factory ClinicAccessResult.fromJson(Map<String, dynamic> json) {
    return ClinicAccessResult(
      accessFamily: ClinicAccessFamily.parse(
        _optionalString(json['accessFamily']),
      ),
    );
  }
}

class ClinicMembershipSummary {
  const ClinicMembershipSummary({
    required this.clinicId,
    required this.clinicName,
    required this.membershipId,
    required this.professionalRole,
    required this.membershipStatus,
    required this.clinicStatus,
    required this.version,
    this.unavailabilityReason,
  });

  final String clinicId;
  final String clinicName;

  /// Internal identifier. Never rendered.
  final String membershipId;
  final ClinicProfessionalRole professionalRole;
  final ClinicLifecycleStatus membershipStatus;
  final ClinicLifecycleStatus clinicStatus;
  final int version;
  final ClinicUnavailabilityReason? unavailabilityReason;

  bool get isSelectable =>
      membershipStatus.isActive &&
      clinicStatus.isActive &&
      unavailabilityReason == null;

  factory ClinicMembershipSummary.fromJson(Map<String, dynamic> json) {
    return ClinicMembershipSummary(
      clinicId: _requiredString(json, 'clinicId'),
      clinicName: _requiredString(json, 'clinicName'),
      membershipId: _requiredString(json, 'membershipId'),
      professionalRole: ClinicProfessionalRole.parse(
        _optionalString(json['professionalRole']),
      ),
      membershipStatus: ClinicLifecycleStatus.parse(
        _optionalString(json['membershipStatus']),
      ),
      clinicStatus: ClinicLifecycleStatus.parse(
        _optionalString(json['clinicStatus']),
      ),
      version: _requiredInt(json, 'version'),
      unavailabilityReason: json['unavailabilityCode'] == null
          ? null
          : ClinicUnavailabilityReason.parse(
              _optionalString(json['unavailabilityCode']),
            ),
    );
  }
}

class ClinicMembershipDirectory {
  const ClinicMembershipDirectory({
    required this.activeMemberships,
    required this.unavailableMemberships,
  });

  final List<ClinicMembershipSummary> activeMemberships;
  final List<ClinicMembershipSummary> unavailableMemberships;

  bool get hasActiveMemberships => activeMemberships.isNotEmpty;

  ClinicMembershipSummary? findActive(String? clinicId) {
    if (clinicId == null || clinicId.trim().isEmpty) return null;
    for (final membership in activeMemberships) {
      if (membership.clinicId == clinicId.trim()) return membership;
    }
    return null;
  }

  factory ClinicMembershipDirectory.fromJson(Map<String, dynamic> json) {
    final active = _parseMemberships(json['activeMemberships'])
        // A membership listed as active must genuinely be usable.
        .where((membership) => membership.isSelectable)
        .toList(growable: false);
    final unavailable = _parseMemberships(json['unavailableMemberships']);
    return ClinicMembershipDirectory(
      activeMemberships: active,
      unavailableMemberships: unavailable,
    );
  }

  static List<ClinicMembershipSummary> _parseMemberships(Object? value) {
    if (value == null) return const [];
    if (value is! List) {
      throw const ClinicContractException('Membership list is malformed.');
    }
    final parsed = <ClinicMembershipSummary>[];
    for (final item in value) {
      if (item is! Map) {
        throw const ClinicContractException('Membership entry is malformed.');
      }
      parsed.add(
        ClinicMembershipSummary.fromJson(item.cast<String, dynamic>()),
      );
    }
    return List.unmodifiable(parsed);
  }
}

class ClinicIdentity {
  const ClinicIdentity({
    required this.clinicId,
    required this.clinicName,
    required this.clinicStatus,
  });

  final String clinicId;
  final String clinicName;
  final ClinicLifecycleStatus clinicStatus;

  factory ClinicIdentity.fromJson(Map<String, dynamic> json) {
    return ClinicIdentity(
      clinicId: _requiredString(json, 'clinicId'),
      clinicName: _requiredString(json, 'clinicName'),
      clinicStatus: ClinicLifecycleStatus.parse(
        _optionalString(json['clinicStatus']),
      ),
    );
  }
}

class ClinicMembershipIdentity {
  const ClinicMembershipIdentity({
    required this.membershipId,
    required this.membershipStatus,
    required this.professionalRole,
    required this.version,
  });

  /// Internal identifier. Never rendered.
  final String membershipId;
  final ClinicLifecycleStatus membershipStatus;
  final ClinicProfessionalRole professionalRole;
  final int version;

  factory ClinicMembershipIdentity.fromJson(Map<String, dynamic> json) {
    return ClinicMembershipIdentity(
      membershipId: _requiredString(json, 'membershipId'),
      membershipStatus: ClinicLifecycleStatus.parse(
        _optionalString(json['membershipStatus']),
      ),
      professionalRole: ClinicProfessionalRole.parse(
        _optionalString(json['professionalRole']),
      ),
      version: _requiredInt(json, 'version'),
    );
  }
}

class ClinicBootstrap {
  const ClinicBootstrap({
    required this.clinic,
    required this.membership,
    required this.capabilities,
    required this.featureFlags,
  });

  final ClinicIdentity clinic;
  final ClinicMembershipIdentity membership;
  final List<ClinicCapability> capabilities;
  final Map<ClinicFeatureModule, bool> featureFlags;

  bool isModuleEnabled(ClinicFeatureModule module) =>
      featureFlags[module] == true;

  bool hasCapability(ClinicCapability capability) =>
      capabilities.contains(capability);

  bool get canReadTasks => hasCapability(ClinicCapability.taskRead);

  bool get canReviewCases => hasCapability(ClinicCapability.caseIntakeReview);

  bool get canReadHandovers => hasCapability(ClinicCapability.taskHandover);

  bool get hasAnyEnabledModule =>
      ClinicFeatureModule.values.any(isModuleEnabled);

  factory ClinicBootstrap.fromJson(Map<String, dynamic> json) {
    final clinicJson = json['clinic'];
    final membershipJson = json['membership'];
    if (clinicJson is! Map || membershipJson is! Map) {
      throw const ClinicContractException('Bootstrap payload is malformed.');
    }

    final rawCapabilities = json['capabilities'];
    if (rawCapabilities != null && rawCapabilities is! List) {
      throw const ClinicContractException('Capability list is malformed.');
    }
    final capabilities = <ClinicCapability>[];
    for (final item in (rawCapabilities as List? ?? const [])) {
      final capability = ClinicCapability.tryParse(_optionalString(item));
      // Unknown capabilities are ignored: they can never grant mobile access.
      if (capability != null && !capabilities.contains(capability)) {
        capabilities.add(capability);
      }
    }

    final rawFlags = json['featureFlags'];
    if (rawFlags != null && rawFlags is! Map) {
      throw const ClinicContractException('Feature flag map is malformed.');
    }
    final flagMap = (rawFlags as Map?)?.cast<String, dynamic>() ?? const {};
    final featureFlags = <ClinicFeatureModule, bool>{
      for (final module in ClinicFeatureModule.values)
        module: flagMap[module.flagKey] == true,
    };

    return ClinicBootstrap(
      clinic: ClinicIdentity.fromJson(clinicJson.cast<String, dynamic>()),
      membership: ClinicMembershipIdentity.fromJson(
        membershipJson.cast<String, dynamic>(),
      ),
      capabilities: List.unmodifiable(capabilities),
      featureFlags: Map.unmodifiable(featureFlags),
    );
  }
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) return value.trim();
  throw ClinicContractException('Missing required field "$key".');
}

String? _optionalString(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  if (value is num) return value.toInt();
  final parsed = int.tryParse(value?.toString().trim() ?? '');
  if (parsed != null) return parsed;
  throw ClinicContractException('Missing required numeric field "$key".');
}

/// Operational task status returned by the Clinic task read contract.
enum ClinicTaskStatus {
  created('CREATED', 'Created'),
  assigned('ASSIGNED', 'Awaiting acknowledgement'),
  acknowledged('ACKNOWLEDGED', 'Ready to start'),
  inProgress('IN_PROGRESS', 'In progress'),
  blocked('BLOCKED', 'Blocked'),
  completed('COMPLETED', 'Completed'),
  cancelled('CANCELLED', 'Cancelled'),
  unknown('UNKNOWN', 'Unavailable');

  const ClinicTaskStatus(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static ClinicTaskStatus parse(Object? value) => _parseEnum(
    value,
    ClinicTaskStatus.values,
    (item) => item.wireValue,
    ClinicTaskStatus.unknown,
  );
}

enum ClinicTaskType {
  administrativeReview('ADMINISTRATIVE_REVIEW', 'Administrative review'),
  requestCoordination('REQUEST_COORDINATION', 'Request coordination'),
  unknown('UNKNOWN', 'Operational task');

  const ClinicTaskType(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static ClinicTaskType parse(Object? value) => _parseEnum(
    value,
    ClinicTaskType.values,
    (item) => item.wireValue,
    ClinicTaskType.unknown,
  );
}

enum ClinicTaskBlockedReason {
  waitingForPatientInformation(
    'WAITING_FOR_PATIENT_INFORMATION',
    'Waiting for patient information',
  ),
  waitingForInternalCoordination(
    'WAITING_FOR_INTERNAL_COORDINATION',
    'Waiting for internal coordination',
  ),
  waitingForExternalNonPatientResponse(
    'WAITING_FOR_EXTERNAL_NON_PATIENT_RESPONSE',
    'Waiting for an external non-patient response',
  ),
  waitingForResourceAvailability(
    'WAITING_FOR_RESOURCE_AVAILABILITY',
    'Waiting for resource availability',
  ),
  unknown('UNKNOWN', 'Blocked');

  const ClinicTaskBlockedReason(this.wireValue, this.label);

  final String wireValue;
  final String label;

  bool get isGeneric =>
      this == waitingForInternalCoordination ||
      this == waitingForExternalNonPatientResponse ||
      this == waitingForResourceAvailability;

  static List<ClinicTaskBlockedReason> get genericReasons => const [
    waitingForInternalCoordination,
    waitingForExternalNonPatientResponse,
    waitingForResourceAvailability,
  ];

  static ClinicTaskBlockedReason parse(Object? value) => _parseEnum(
    value,
    ClinicTaskBlockedReason.values,
    (item) => item.wireValue,
    ClinicTaskBlockedReason.unknown,
  );
}

enum ClinicOperationalPriority {
  low('LOW', 'Low'),
  normal('NORMAL', 'Normal'),
  high('HIGH', 'High'),
  critical('CRITICAL', 'Critical'),
  unknown('UNKNOWN', 'Priority unavailable');

  const ClinicOperationalPriority(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static ClinicOperationalPriority parse(Object? value) => _parseEnum(
    value,
    ClinicOperationalPriority.values,
    (item) => item.wireValue,
    ClinicOperationalPriority.unknown,
  );
}

enum ClinicResponsibilityType {
  admissions('ADMISSIONS', 'Admissions'),
  requestCoordination('REQUEST_COORDINATION', 'Request coordination'),
  medicalCoordination('MEDICAL_COORDINATION', 'Medical coordination'),
  careCoordination('CARE_COORDINATION', 'Care coordination'),
  unitSupervision('UNIT_SUPERVISION', 'Unit supervision'),
  orCoordination('OR_COORDINATION', 'Operating room coordination'),
  clinicConfiguration('CLINIC_CONFIGURATION', 'Clinic configuration'),
  partnershipFinance('PARTNERSHIP_FINANCE', 'Partnership finance'),
  unknown('UNKNOWN', 'Responsibility unavailable');

  const ClinicResponsibilityType(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static ClinicResponsibilityType parse(Object? value) => _parseEnum(
    value,
    ClinicResponsibilityType.values,
    (item) => item.wireValue,
    ClinicResponsibilityType.unknown,
  );
}

/// Request situation is operational context and is deliberately separate from
/// task priority. It is never used to derive a priority or a workflow action.
enum ClinicRequestSituation {
  appointment('APPOINTMENT', 'Appointment'),
  urgent('URGENT', 'Urgent request'),
  ambulance('AMBULANCE', 'Ambulance request'),
  unknown('UNKNOWN', 'Situation unavailable');

  const ClinicRequestSituation(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static ClinicRequestSituation parse(Object? value) => _parseEnum(
    value,
    ClinicRequestSituation.values,
    (item) => item.wireValue,
    ClinicRequestSituation.unknown,
  );
}

enum ClinicCaseStatus {
  received('RECEIVED', 'Received'),
  underAdminReview('UNDER_ADMIN_REVIEW', 'Under administrative review'),
  informationRequired('INFORMATION_REQUIRED', 'Information required'),
  readyForPlanning('READY_FOR_PLANNING', 'Ready for planning'),
  declined('DECLINED', 'Declined'),
  cancelled('CANCELLED', 'Cancelled'),
  unknown('UNKNOWN', 'Status unavailable');

  const ClinicCaseStatus(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static ClinicCaseStatus parse(Object? value) => _parseEnum(
    value,
    ClinicCaseStatus.values,
    (item) => item.wireValue,
    ClinicCaseStatus.unknown,
  );
}

enum ClinicCaseAction {
  startReview('START_REVIEW', 'Start review'),
  requestInformation('REQUEST_INFORMATION', 'Request information'),
  readyForPlanning('READY_FOR_PLANNING', 'Ready for planning'),
  decline('DECLINE', 'Decline request'),
  unknown('UNKNOWN', 'Unavailable');

  const ClinicCaseAction(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static ClinicCaseAction parse(Object? value) => _parseEnum(
    value,
    ClinicCaseAction.values,
    (item) => item.wireValue,
    ClinicCaseAction.unknown,
  );
}

enum ClinicInformationRequestReason {
  contactInformation('CONTACT_INFORMATION', 'Contact information'),
  patientIdentityInformation(
    'PATIENT_IDENTITY_INFORMATION',
    'Patient identity information',
  ),
  familyMemberInformation(
    'FAMILY_MEMBER_INFORMATION',
    'Family member information',
  ),
  requestAdministrativeDetails(
    'REQUEST_ADMINISTRATIVE_DETAILS',
    'Request administrative details',
  ),
  availabilityInformation(
    'AVAILABILITY_INFORMATION',
    'Availability information',
  ),
  otherAdministrative('OTHER_ADMINISTRATIVE', 'Other administrative'),
  unknown('UNKNOWN', 'Information request');

  const ClinicInformationRequestReason(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static List<ClinicInformationRequestReason> get controlledReasons => const [
    contactInformation,
    patientIdentityInformation,
    familyMemberInformation,
    requestAdministrativeDetails,
    availabilityInformation,
    otherAdministrative,
  ];

  static ClinicInformationRequestReason parse(Object? value) => _parseEnum(
    value,
    ClinicInformationRequestReason.values,
    (item) => item.wireValue,
    ClinicInformationRequestReason.unknown,
  );
}

enum ClinicCaseDeclineReason {
  noCapacity('NO_CAPACITY', 'No capacity'),
  serviceUnavailable('SERVICE_UNAVAILABLE', 'Service unavailable'),
  requestNotSupported('REQUEST_NOT_SUPPORTED', 'Request not supported'),
  duplicateOrInvalidRequest(
    'DUPLICATE_OR_INVALID_REQUEST',
    'Duplicate or invalid request',
  ),
  otherAdministrative('OTHER_ADMINISTRATIVE', 'Other administrative'),
  unknown('UNKNOWN', 'Decline reason');

  const ClinicCaseDeclineReason(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static List<ClinicCaseDeclineReason> get controlledReasons => const [
    noCapacity,
    serviceUnavailable,
    requestNotSupported,
    duplicateOrInvalidRequest,
    otherAdministrative,
  ];

  static ClinicCaseDeclineReason parse(Object? value) => _parseEnum(
    value,
    ClinicCaseDeclineReason.values,
    (item) => item.wireValue,
    ClinicCaseDeclineReason.unknown,
  );
}

enum ClinicInformationRequestStatus {
  open('OPEN', 'Open'),
  responded('RESPONDED', 'Responded'),
  cancelled('CANCELLED', 'Cancelled'),
  unknown('UNKNOWN', 'Status unavailable');

  const ClinicInformationRequestStatus(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static ClinicInformationRequestStatus parse(Object? value) => _parseEnum(
    value,
    ClinicInformationRequestStatus.values,
    (item) => item.wireValue,
    ClinicInformationRequestStatus.unknown,
  );
}

enum ClinicHandoverStatus {
  pending('PENDING', 'Pending'),
  accepted('ACCEPTED', 'Accepted'),
  declined('DECLINED', 'Declined'),
  cancelled('CANCELLED', 'Cancelled'),
  invalidated('INVALIDATED', 'Invalidated'),
  unknown('UNKNOWN', 'Unavailable');

  const ClinicHandoverStatus(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static ClinicHandoverStatus parse(Object? value) => _parseEnum(
    value,
    ClinicHandoverStatus.values,
    (item) => item.wireValue,
    ClinicHandoverStatus.unknown,
  );
}

enum ClinicHandoverReason {
  shiftChange('SHIFT_CHANGE', 'Shift change'),
  breakCoverage('BREAK_COVERAGE', 'Break coverage'),
  workloadTransfer('WORKLOAD_TRANSFER', 'Workload transfer'),
  otherOperational('OTHER_OPERATIONAL', 'Other operational'),
  unknown('UNKNOWN', 'Operational handover');

  const ClinicHandoverReason(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static List<ClinicHandoverReason> get controlledReasons => const [
    shiftChange,
    breakCoverage,
    workloadTransfer,
    otherOperational,
  ];

  static ClinicHandoverReason parse(Object? value) => _parseEnum(
    value,
    ClinicHandoverReason.values,
    (item) => item.wireValue,
    ClinicHandoverReason.unknown,
  );
}

enum ClinicHandoverInvalidationReason {
  taskTerminal('TASK_TERMINAL', 'Task was completed or cancelled'),
  taskReassigned('TASK_REASSIGNED', 'Task ownership changed'),
  sourceLostOwnership('SOURCE_LOST_OWNERSHIP', 'Source owner changed'),
  targetIneligible('TARGET_INELIGIBLE', 'Target is no longer eligible'),
  unknown('UNKNOWN', 'Handover is no longer available');

  const ClinicHandoverInvalidationReason(this.wireValue, this.label);

  final String wireValue;
  final String label;

  static ClinicHandoverInvalidationReason parse(Object? value) => _parseEnum(
    value,
    ClinicHandoverInvalidationReason.values,
    (item) => item.wireValue,
    ClinicHandoverInvalidationReason.unknown,
  );
}

class ClinicTaskCaseContext {
  const ClinicTaskCaseContext({
    required this.caseId,
    required this.sourceRequestId,
    required this.intakeStatus,
    required this.situation,
    required this.priority,
    required this.currentStepKey,
    required this.submittedAt,
    required this.hasOpenRoutingIncident,
  });

  final String caseId;
  final String sourceRequestId;
  final String intakeStatus;
  final ClinicRequestSituation situation;
  final ClinicOperationalPriority priority;
  final String currentStepKey;
  final DateTime? submittedAt;
  final bool hasOpenRoutingIncident;

  String get intakeStatusLabel => ClinicCaseStatus.parse(intakeStatus).label;

  String get currentStepLabel => ClinicTaskType.parse(currentStepKey).label;

  factory ClinicTaskCaseContext.fromJson(Map<String, dynamic> json) {
    return ClinicTaskCaseContext(
      caseId: _requiredString(json, 'caseId'),
      sourceRequestId: _requiredString(json, 'sourceRequestId'),
      intakeStatus: _requiredString(json, 'intakeStatus'),
      situation: ClinicRequestSituation.parse(json['situation']),
      priority: ClinicOperationalPriority.parse(json['priority']),
      currentStepKey: _requiredString(json, 'currentStepKey'),
      submittedAt: _optionalDateTime(json['submittedAt']),
      hasOpenRoutingIncident: json['hasOpenRoutingIncident'] == true,
    );
  }
}

class ClinicTaskSummary {
  const ClinicTaskSummary({
    required this.taskId,
    required this.caseId,
    required this.taskType,
    required this.responsibilityType,
    required this.status,
    required this.priority,
    required this.blocking,
    required this.acknowledgementRequired,
    required this.acknowledgementDueAt,
    required this.dueAt,
    required this.assignedPositionId,
    required this.assignedMembershipId,
    required this.createdAt,
    required this.updatedAt,
    required this.version,
    required this.caseContext,
  });

  final String taskId;
  final String caseId;
  final ClinicTaskType taskType;
  final ClinicResponsibilityType responsibilityType;
  final ClinicTaskStatus status;
  final ClinicOperationalPriority priority;
  final bool blocking;
  final bool acknowledgementRequired;
  final DateTime? acknowledgementDueAt;
  final DateTime? dueAt;
  final String? assignedPositionId;
  final String? assignedMembershipId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;
  final ClinicTaskCaseContext caseContext;

  factory ClinicTaskSummary.fromJson(Map<String, dynamic> json) {
    final context = json['caseContext'];
    if (context is! Map) {
      throw const ClinicContractException('Task case context is malformed.');
    }
    return ClinicTaskSummary(
      taskId: _requiredString(json, 'taskId'),
      caseId: _requiredString(json, 'caseId'),
      taskType: ClinicTaskType.parse(json['taskType']),
      responsibilityType: ClinicResponsibilityType.parse(
        json['responsibilityType'],
      ),
      status: ClinicTaskStatus.parse(json['status']),
      priority: ClinicOperationalPriority.parse(json['priority']),
      blocking: json['blocking'] == true,
      acknowledgementRequired: json['acknowledgementRequired'] == true,
      acknowledgementDueAt: _optionalDateTime(json['acknowledgementDueAt']),
      dueAt: _optionalDateTime(json['dueAt']),
      assignedPositionId: _optionalString(json['assignedPositionId']),
      assignedMembershipId: _optionalString(json['assignedMembershipId']),
      createdAt: _requiredDateTime(json, 'createdAt'),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
      version: _requiredInt(json, 'version'),
      caseContext: ClinicTaskCaseContext.fromJson(
        context.cast<String, dynamic>(),
      ),
    );
  }
}

class ClinicTaskDetail extends ClinicTaskSummary {
  const ClinicTaskDetail({
    required super.taskId,
    required super.caseId,
    required super.taskType,
    required super.responsibilityType,
    required super.status,
    required super.priority,
    required super.blocking,
    required super.acknowledgementRequired,
    required super.acknowledgementDueAt,
    required super.dueAt,
    required super.assignedPositionId,
    required super.assignedMembershipId,
    required super.createdAt,
    required super.updatedAt,
    required super.version,
    required super.caseContext,
    required this.blockedReasonCode,
    required this.acknowledgedAt,
    required this.startedAt,
    required this.completedAt,
  });

  final String? blockedReasonCode;
  final DateTime? acknowledgedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;

  ClinicTaskBlockedReason get blockedReason =>
      ClinicTaskBlockedReason.parse(blockedReasonCode);

  bool get isPatientInformationBlocked =>
      status == ClinicTaskStatus.blocked &&
      blockedReason == ClinicTaskBlockedReason.waitingForPatientInformation;

  bool get isGenericBlocked =>
      status == ClinicTaskStatus.blocked && blockedReason.isGeneric;

  factory ClinicTaskDetail.fromJson(Map<String, dynamic> json) {
    final summary = ClinicTaskSummary.fromJson(json);
    return ClinicTaskDetail(
      taskId: summary.taskId,
      caseId: summary.caseId,
      taskType: summary.taskType,
      responsibilityType: summary.responsibilityType,
      status: summary.status,
      priority: summary.priority,
      blocking: summary.blocking,
      acknowledgementRequired: summary.acknowledgementRequired,
      acknowledgementDueAt: summary.acknowledgementDueAt,
      dueAt: summary.dueAt,
      assignedPositionId: summary.assignedPositionId,
      assignedMembershipId: summary.assignedMembershipId,
      createdAt: summary.createdAt,
      updatedAt: summary.updatedAt,
      version: summary.version,
      caseContext: summary.caseContext,
      blockedReasonCode: _optionalString(json['blockedReasonCode']),
      acknowledgedAt: _optionalDateTime(json['acknowledgedAt']),
      startedAt: _optionalDateTime(json['startedAt']),
      completedAt: _optionalDateTime(json['completedAt']),
    );
  }
}

class ClinicCaseInformationRequest {
  const ClinicCaseInformationRequest({
    required this.reason,
    required this.patientInstruction,
    required this.responseType,
    required this.status,
    required this.responseSummary,
  });

  final ClinicInformationRequestReason reason;
  final String? patientInstruction;
  final String? responseType;
  final ClinicInformationRequestStatus status;
  final String? responseSummary;

  factory ClinicCaseInformationRequest.fromJson(Map<String, dynamic> json) {
    return ClinicCaseInformationRequest(
      reason: ClinicInformationRequestReason.parse(json['reasonCode']),
      patientInstruction: _optionalString(json['patientInstruction']),
      responseType: _optionalString(json['responseType']),
      status: ClinicInformationRequestStatus.parse(json['status']),
      responseSummary: _optionalString(json['responseSummary']),
    );
  }
}

class ClinicCaseDetail {
  const ClinicCaseDetail({
    required this.clinicCaseId,
    required this.patientDisplayName,
    required this.subjectType,
    required this.relationship,
    required this.situation,
    required this.administrativeStatus,
    required this.submittedAt,
    required this.version,
    required this.priority,
    required this.currentStepKey,
    required this.availableActions,
    required this.informationRequest,
  });

  final String clinicCaseId;
  final String patientDisplayName;
  final String? subjectType;
  final String? relationship;
  final ClinicRequestSituation situation;
  final ClinicCaseStatus administrativeStatus;
  final DateTime submittedAt;
  final int version;
  final ClinicOperationalPriority priority;
  final String currentStepKey;
  final List<ClinicCaseAction> availableActions;
  final ClinicCaseInformationRequest? informationRequest;

  bool allows(ClinicCaseAction action) => availableActions.contains(action);

  String get currentStepLabel => ClinicTaskType.parse(currentStepKey).label;

  factory ClinicCaseDetail.fromJson(Map<String, dynamic> json) {
    final actions = json['availableActions'];
    if (actions is! List) {
      throw const ClinicContractException('Case action list is malformed.');
    }
    final information = json['informationRequest'];
    if (information != null && information is! Map) {
      throw const ClinicContractException(
        'Information request context is malformed.',
      );
    }
    return ClinicCaseDetail(
      clinicCaseId: _requiredString(json, 'clinicCaseId'),
      patientDisplayName: _requiredString(json, 'patientDisplayName'),
      subjectType: _optionalString(json['subjectType']),
      relationship: _optionalString(json['relationship']),
      situation: ClinicRequestSituation.parse(json['situation']),
      administrativeStatus: ClinicCaseStatus.parse(
        json['administrativeStatus'],
      ),
      submittedAt: _requiredDateTime(json, 'submittedAt'),
      version: _requiredInt(json, 'version'),
      priority: ClinicOperationalPriority.parse(json['priority']),
      currentStepKey: _requiredString(json, 'currentStepKey'),
      availableActions: List.unmodifiable(
        actions
            .map(ClinicCaseAction.parse)
            .where((action) => action != ClinicCaseAction.unknown),
      ),
      informationRequest: information == null
          ? null
          : ClinicCaseInformationRequest.fromJson(
              information.cast<String, dynamic>(),
            ),
    );
  }
}

class ClinicHandoverSummary {
  const ClinicHandoverSummary({
    required this.handoverId,
    required this.taskId,
    required this.status,
    required this.reason,
    required this.fromMembershipId,
    required this.toMembershipId,
    required this.taskType,
    required this.priority,
    required this.initiatedAt,
    required this.acceptedAt,
    required this.declinedAt,
    required this.cancelledAt,
    required this.invalidatedAt,
    required this.invalidationReason,
  });

  final String handoverId;
  final String taskId;
  final ClinicHandoverStatus status;
  final ClinicHandoverReason reason;
  final String fromMembershipId;
  final String toMembershipId;
  final ClinicTaskType taskType;
  final ClinicOperationalPriority priority;
  final DateTime initiatedAt;
  final DateTime? acceptedAt;
  final DateTime? declinedAt;
  final DateTime? cancelledAt;
  final DateTime? invalidatedAt;
  final ClinicHandoverInvalidationReason invalidationReason;

  bool get isPending => status == ClinicHandoverStatus.pending;
  bool get isTerminal =>
      status == ClinicHandoverStatus.accepted ||
      status == ClinicHandoverStatus.declined ||
      status == ClinicHandoverStatus.cancelled ||
      status == ClinicHandoverStatus.invalidated;

  factory ClinicHandoverSummary.fromJson(Map<String, dynamic> json) {
    return ClinicHandoverSummary(
      handoverId: _requiredString(json, 'handoverId'),
      taskId: _requiredString(json, 'taskId'),
      status: ClinicHandoverStatus.parse(json['status']),
      reason: ClinicHandoverReason.parse(json['reasonCode']),
      fromMembershipId: _requiredString(json, 'fromMembershipId'),
      toMembershipId: _requiredString(json, 'toMembershipId'),
      taskType: ClinicTaskType.parse(json['taskType']),
      priority: ClinicOperationalPriority.parse(json['priority']),
      initiatedAt: _requiredDateTime(json, 'initiatedAt'),
      acceptedAt: _optionalDateTime(json['acceptedAt']),
      declinedAt: _optionalDateTime(json['declinedAt']),
      cancelledAt: _optionalDateTime(json['cancelledAt']),
      invalidatedAt: _optionalDateTime(json['invalidatedAt']),
      invalidationReason: json['invalidationReason'] == null
          ? ClinicHandoverInvalidationReason.unknown
          : ClinicHandoverInvalidationReason.parse(json['invalidationReason']),
    );
  }
}

class ClinicHandoverTarget {
  const ClinicHandoverTarget({
    required this.membershipId,
    required this.displayName,
    required this.positionId,
    required this.positionName,
  });

  final String membershipId;
  final String displayName;
  final String positionId;
  final String positionName;

  String get label => '$displayName · $positionName';

  factory ClinicHandoverTarget.fromJson(Map<String, dynamic> json) {
    return ClinicHandoverTarget(
      membershipId: _requiredString(json, 'membershipId'),
      displayName: _requiredString(json, 'displayName'),
      positionId: _requiredString(json, 'positionId'),
      positionName: _requiredString(json, 'positionName'),
    );
  }
}

class ClinicSlice<T> {
  const ClinicSlice({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.hasNext,
    required this.generatedAt,
    this.contractVersion,
  });

  final List<T> items;
  final int page;
  final int pageSize;
  final bool hasNext;
  final DateTime generatedAt;
  final String? contractVersion;

  bool get isEmpty => items.isEmpty;
}

class ClinicDeadlineSemantics {
  const ClinicDeadlineSemantics._();

  static bool isAcknowledgementOverdue({
    required DateTime acknowledgementDueAt,
    required DateTime? acknowledgedAt,
    required DateTime now,
  }) {
    final due = acknowledgementDueAt.toUtc();
    final reference = acknowledgedAt?.toUtc();
    return (reference ?? now.toUtc()).isAfter(due);
  }
}

class ClinicDateTimeFormatter {
  const ClinicDateTimeFormatter._();

  static String format(DateTime? value, {String fallback = 'Not available'}) {
    if (value == null) return fallback;
    return DateFormat('d MMM, HH:mm').format(value.toLocal());
  }
}

class ClinicReferenceFormatter {
  const ClinicReferenceFormatter._();

  static String requestReference(String? value) =>
      _compact(value, fallback: 'Request reference unavailable');

  static String caseReference(String? value) =>
      _compact(value, fallback: 'Case reference unavailable');

  static String _compact(String? value, {required String fallback}) {
    final text = value?.trim();
    if (text == null || text.isEmpty) return fallback;
    final normalized = text.replaceAll('-', '');
    if (normalized.length <= 8) return text;
    return 'Ref ${normalized.substring(normalized.length - 8).toUpperCase()}';
  }
}

T _parseEnum<T>(
  Object? value,
  Iterable<T> values,
  String Function(T) wireValue,
  T fallback,
) {
  final normalized = value?.toString().trim().toUpperCase();
  if (normalized != null && normalized.isNotEmpty) {
    for (final item in values) {
      if (wireValue(item) == normalized) return item;
    }
  }
  return fallback;
}

DateTime _requiredDateTime(Map<String, dynamic> json, String key) {
  final value = _optionalDateTime(json[key]);
  if (value != null) return value;
  throw ClinicContractException('Missing required timestamp "$key".');
}

DateTime? _optionalDateTime(Object? value) {
  if (value is DateTime) return value.toUtc();
  if (value is String && value.trim().isNotEmpty) {
    return DateTime.tryParse(value)?.toUtc();
  }
  return null;
}
