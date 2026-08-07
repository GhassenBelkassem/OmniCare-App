/// Strictly parsed clinic contract models for Phase 1.
///
/// Every factory validates the identifiers and enumerations it depends on and
/// throws [ClinicContractException] when the payload cannot be trusted. Nothing
/// here is guessed: an unknown professional role, a missing identifier or a
/// malformed object fails instead of degrading into a partially valid state.
library;

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

/// Read-only capabilities Phase 1 understands.
enum ClinicCapability {
  overviewRead('CLINIC_OVERVIEW_READ', 'Clinic overview (read-only)'),
  profileRead('CLINIC_PROFILE_READ', 'Clinic profile (read-only)'),
  membershipSelfRead(
    'CLINIC_MEMBERSHIP_SELF_READ',
    'My membership (read-only)',
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
