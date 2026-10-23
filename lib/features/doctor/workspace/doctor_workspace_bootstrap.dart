import 'package:flutter/foundation.dart';

import 'doctor_workspace_config.dart';

enum DoctorServerCareCapability {
  cabinet,
  homeVisit,
  urgentHome,
  urgentCabinet;

  static DoctorServerCareCapability parse(String value) => switch (value) {
    'CABINET' => DoctorServerCareCapability.cabinet,
    'HOME_VISIT' => DoctorServerCareCapability.homeVisit,
    'URGENT_HOME' => DoctorServerCareCapability.urgentHome,
    'URGENT_CABINET' => DoctorServerCareCapability.urgentCabinet,
    _ => throw FormatException('Unknown Doctor care capability: $value.'),
  };
}

enum DoctorUrgentReadinessReason {
  capabilityDisabled,
  homeFeeNotConfigured,
  homeTravelDistanceNotConfigured,
  cabinetFeeNotConfigured,
  noActiveCabinet,
  professionalNotEligible,
  runtimeHomeIntentDisabled,
  runtimeCabinetIntentDisabled,
  clinicalBusy,
  activeUrgentCapacityClaim,
  postHandoffUnavailable,
  locationMissing,
  locationStale,
  locationAccuracyInsufficient,
  locationPresenceUnavailable,
  requestSpecificEligibilityNotEvaluated;

  static DoctorUrgentReadinessReason parse(String value) => switch (value) {
    'CAPABILITY_DISABLED' => capabilityDisabled,
    'HOME_FEE_NOT_CONFIGURED' => homeFeeNotConfigured,
    'HOME_TRAVEL_DISTANCE_NOT_CONFIGURED' => homeTravelDistanceNotConfigured,
    'CABINET_FEE_NOT_CONFIGURED' => cabinetFeeNotConfigured,
    'NO_ACTIVE_CABINET' => noActiveCabinet,
    'PROFESSIONAL_NOT_ELIGIBLE' => professionalNotEligible,
    'RUNTIME_HOME_INTENT_DISABLED' => runtimeHomeIntentDisabled,
    'RUNTIME_CABINET_INTENT_DISABLED' => runtimeCabinetIntentDisabled,
    'CLINICAL_BUSY' => clinicalBusy,
    'ACTIVE_URGENT_CAPACITY_CLAIM' => activeUrgentCapacityClaim,
    'POST_HANDOFF_UNAVAILABLE' => postHandoffUnavailable,
    'LOCATION_MISSING' => locationMissing,
    'LOCATION_STALE' => locationStale,
    'LOCATION_ACCURACY_INSUFFICIENT' => locationAccuracyInsufficient,
    'LOCATION_PRESENCE_UNAVAILABLE' => locationPresenceUnavailable,
    'REQUEST_SPECIFIC_ELIGIBILITY_NOT_EVALUATED' =>
      requestSpecificEligibilityNotEvaluated,
    _ => throw FormatException('Unknown urgent readiness reason: $value.'),
  };

  String get frenchLabel => switch (this) {
    capabilityDisabled => 'Ce mode n’est pas configuré.',
    homeFeeNotConfigured => 'Le tarif HOME doit être configuré.',
    homeTravelDistanceNotConfigured =>
      'La distance routière maximale HOME doit être configurée.',
    cabinetFeeNotConfigured =>
      'Le tarif des urgences au cabinet doit être configuré.',
    noActiveCabinet => 'Aucun cabinet actif admissible n’est configuré.',
    professionalNotEligible =>
      'Le profil professionnel n’est pas actuellement admissible.',
    runtimeHomeIntentDisabled =>
      'La disponibilité HOME est désactivée côté serveur.',
    runtimeCabinetIntentDisabled =>
      'La disponibilité urgente au cabinet est désactivée côté serveur.',
    clinicalBusy => 'Une activité clinique incompatible est en cours.',
    activeUrgentCapacityClaim =>
      'Une autre responsabilité urgente est déjà active.',
    postHandoffUnavailable =>
      'Le médecin reste indisponible après le transfert clinique.',
    locationMissing => 'La position GPS Flutter requise pour HOME est absente.',
    locationStale =>
      'La position GPS Flutter requise pour HOME est trop ancienne.',
    locationAccuracyInsufficient =>
      'La précision GPS Flutter est insuffisante pour HOME.',
    locationPresenceUnavailable =>
      'Le service de présence GPS Flutter est indisponible.',
    requestSpecificEligibilityNotEvaluated =>
      'L’admissibilité dépendante d’une demande n’est pas encore évaluée.',
  };
}

@immutable
class DoctorUrgentConfigurationSnapshot {
  const DoctorUrgentConfigurationSnapshot({
    required this.revision,
    required this.homeFeeConfigured,
    required this.homeTravelDistanceConfigured,
    required this.cabinetFeeConfigured,
  });

  final int revision;
  final bool homeFeeConfigured;
  final bool homeTravelDistanceConfigured;
  final bool cabinetFeeConfigured;
}

@immutable
class DoctorUrgentModeReadiness {
  const DoctorUrgentModeReadiness({
    required this.capabilityEnabled,
    required this.configurationReady,
    required this.runtimeAvailabilityIntent,
    required this.effectiveCurrentEligibility,
    required this.blockingReasons,
  });

  final bool capabilityEnabled;
  final bool configurationReady;
  final bool runtimeAvailabilityIntent;
  final bool effectiveCurrentEligibility;
  final List<DoctorUrgentReadinessReason> blockingReasons;
}

@immutable
class DoctorUrgentReadinessSnapshot {
  const DoctorUrgentReadinessSnapshot({
    required this.revision,
    required this.professionalEligible,
    required this.home,
    required this.cabinet,
    required this.completeLiveMatchingEligibilityEvaluated,
    required this.evaluatedAt,
  });

  final int revision;
  final bool professionalEligible;
  final DoctorUrgentModeReadiness home;
  final DoctorUrgentModeReadiness cabinet;
  final bool completeLiveMatchingEligibilityEvaluated;
  final DateTime evaluatedAt;
}

@immutable
class DoctorPracticeLocationSnapshot {
  const DoctorPracticeLocationSnapshot({
    required this.id,
    required this.name,
    required this.governorate,
    required this.city,
    required this.address,
    required this.active,
    required this.primary,
  });

  final String id;
  final String name;
  final String governorate;
  final String city;
  final String address;
  final bool active;
  final bool primary;

  DoctorCabinetConfig toPresentationConfig() => DoctorCabinetConfig(
    name: name,
    governorate: governorate,
    city: city,
    address: address,
  );
}

@immutable
class DoctorUrgentRuntimeSnapshot {
  const DoctorUrgentRuntimeSnapshot({
    required this.revision,
    required this.homeEnabled,
    required this.cabinetEnabled,
    this.capacityState = DoctorUrgentCapacityState.free,
    this.home,
    this.cabinet,
    this.homeLocationPresence,
    this.completeRequestSpecificEligibilityEvaluated = false,
    this.evaluatedAt,
  });

  final int revision;
  final bool homeEnabled;
  final bool cabinetEnabled;
  final DoctorUrgentCapacityState capacityState;
  final DoctorUrgentRuntimeModeStatus? home;
  final DoctorUrgentRuntimeModeStatus? cabinet;
  final DoctorHomeLocationPresence? homeLocationPresence;
  final bool completeRequestSpecificEligibilityEvaluated;
  final DateTime? evaluatedAt;
}

enum DoctorUrgentCapacityState {
  free,
  clinicalBusy,
  homeHold,
  homeCommitment,
  cabinetCommitment,
  postHandoffUnavailable;

  static DoctorUrgentCapacityState parse(String value) => switch (value) {
    'FREE' => DoctorUrgentCapacityState.free,
    'CLINICAL_BUSY' => DoctorUrgentCapacityState.clinicalBusy,
    'HOME_HOLD' => DoctorUrgentCapacityState.homeHold,
    'HOME_COMMITMENT' => DoctorUrgentCapacityState.homeCommitment,
    'CABINET_COMMITMENT' => DoctorUrgentCapacityState.cabinetCommitment,
    'POST_HANDOFF_UNAVAILABLE' =>
      DoctorUrgentCapacityState.postHandoffUnavailable,
    _ => throw FormatException('Unknown Doctor capacity state: $value.'),
  };
}

@immutable
class DoctorUrgentRuntimeModeStatus {
  const DoctorUrgentRuntimeModeStatus({
    required this.runtimeIntentEnabled,
    required this.activationPrerequisitesSatisfied,
    required this.capacityAvailable,
    required this.operationalPresenceReady,
    required this.runtimeFoundationReady,
    required this.requestSpecificEligibilityEvaluated,
    required this.effectiveCurrentEligibility,
    required this.blockingReasons,
  });

  final bool runtimeIntentEnabled;
  final bool activationPrerequisitesSatisfied;
  final bool capacityAvailable;
  final bool operationalPresenceReady;
  final bool runtimeFoundationReady;
  final bool requestSpecificEligibilityEvaluated;
  final bool effectiveCurrentEligibility;
  final List<DoctorUrgentReadinessReason> blockingReasons;
}

enum DoctorLocationPresenceStatus {
  available,
  missing,
  stale,
  qualityInsufficient,
  unavailable;

  static DoctorLocationPresenceStatus parse(String value) => switch (value) {
    'AVAILABLE' => DoctorLocationPresenceStatus.available,
    'MISSING' => DoctorLocationPresenceStatus.missing,
    'STALE' => DoctorLocationPresenceStatus.stale,
    'QUALITY_INSUFFICIENT' => DoctorLocationPresenceStatus.qualityInsufficient,
    'UNAVAILABLE' => DoctorLocationPresenceStatus.unavailable,
    _ => throw FormatException('Unknown location presence state: $value.'),
  };
}

@immutable
class DoctorHomeLocationPresence {
  const DoctorHomeLocationPresence({
    required this.status,
    this.updateId,
    this.observedAt,
    this.receivedAt,
    this.expiresAt,
  });

  final DoctorLocationPresenceStatus status;
  final String? updateId;
  final DateTime? observedAt;
  final DateTime? receivedAt;
  final DateTime? expiresAt;
}

enum DoctorUrgentRuntimeBootstrapAccess {
  available,
  rolloutUnavailable,
  unresolved,
}

@immutable
class DoctorWorkspaceBootstrap {
  DoctorWorkspaceBootstrap({
    required this.doctorId,
    required Set<DoctorServerCareCapability> serverCapabilities,
    required this.capabilityRevision,
    required this.configuration,
    required this.readiness,
    required List<DoctorPracticeLocationSnapshot> activeCabinets,
    required this.runtime,
    DoctorUrgentRuntimeBootstrapAccess? runtimeAccess,
  }) : serverCapabilities = Set.unmodifiable(serverCapabilities),
       activeCabinets = List.unmodifiable(activeCabinets),
       runtimeAccess =
           runtimeAccess ??
           (runtime == null
               ? DoctorUrgentRuntimeBootstrapAccess.unresolved
               : DoctorUrgentRuntimeBootstrapAccess.available);

  final String doctorId;
  final Set<DoctorServerCareCapability> serverCapabilities;
  final int capabilityRevision;
  final DoctorUrgentConfigurationSnapshot configuration;
  final DoctorUrgentReadinessSnapshot readiness;
  final List<DoctorPracticeLocationSnapshot> activeCabinets;
  final DoctorUrgentRuntimeSnapshot? runtime;
  final DoctorUrgentRuntimeBootstrapAccess runtimeAccess;

  bool get hasCabinet =>
      serverCapabilities.contains(DoctorServerCareCapability.cabinet);
  bool get hasUrgentHome =>
      serverCapabilities.contains(DoctorServerCareCapability.urgentHome);
  bool get hasUrgentCabinet =>
      serverCapabilities.contains(DoctorServerCareCapability.urgentCabinet);

  /// HOME_VISIT is intentionally excluded from the V1 presentation mapping.
  Set<DoctorCapability> get navigationCapabilities {
    final result = <DoctorCapability>{};
    if (hasCabinet) {
      result.addAll({
        DoctorCapability.agenda,
        DoctorCapability.cabinetAppointments,
        DoctorCapability.patientManagement,
        DoctorCapability.workQueue,
        DoctorCapability.followUp,
      });
    }
    if (hasUrgentHome) {
      result.addAll({
        DoctorCapability.urgentRequests,
        DoctorCapability.urgentHomeRequests,
        DoctorCapability.urgentWorkspace,
        DoctorCapability.patientManagement,
        DoctorCapability.workQueue,
      });
    }
    if (hasUrgentCabinet) {
      result.addAll({
        DoctorCapability.urgentCabinetRequests,
        DoctorCapability.urgentWorkspace,
      });
    }
    return Set.unmodifiable(result);
  }

  DoctorWorkspaceConfig get presentationConfig {
    final modes = <DoctorPracticeMode>{};
    final services = <DoctorWorkspaceService>{};
    if (hasCabinet) {
      modes.add(DoctorPracticeMode.cabinet);
      services.addAll({
        DoctorWorkspaceService.cabinetConsultations,
        DoctorWorkspaceService.appointments,
      });
    }
    if (hasUrgentHome) {
      modes.add(DoctorPracticeMode.urgentHome);
      services.add(DoctorWorkspaceService.urgentHomeVisits);
    }
    if (hasUrgentCabinet) {
      services.add(DoctorWorkspaceService.urgentCabinetConsultations);
    }
    final cabinet = activeCabinets.isEmpty
        ? null
        : activeCabinets.first.toPresentationConfig();
    return DoctorWorkspaceConfig(
      doctorId: doctorId,
      onboardingCompleted: true,
      practiceModes: Set.unmodifiable(modes),
      services: Set.unmodifiable(services),
      cabinet: cabinet,
      clinics: const [],
      availability: const DoctorAvailability(
        workingDays: {},
        startTime: '00:00',
        endTime: '00:00',
      ),
    );
  }

  String get homeOperationalMessage => _operationalMessage(
    readiness.home,
    runtimeKnownEnabled: runtime?.homeEnabled,
    fallback:
        'Les actions urgentes HOME restent désactivées dans cette version Flutter.',
  );

  String? get cabinetOperationalMessage {
    final mode = readiness.cabinet;
    if (mode.blockingReasons.isNotEmpty) {
      return mode.blockingReasons.map((reason) => reason.frenchLabel).join(' ');
    }
    if (runtime?.cabinetEnabled != true || !mode.runtimeAvailabilityIntent) {
      return 'La disponibilité opérationnelle est désactivée côté serveur.';
    }
    if (!mode.capabilityEnabled || !mode.configurationReady) {
      return 'Les actions urgentes au cabinet restent désactivées dans cette version Flutter.';
    }
    return null;
  }

  String _operationalMessage(
    DoctorUrgentModeReadiness mode, {
    required bool? runtimeKnownEnabled,
    required String fallback,
  }) {
    if (mode.blockingReasons.isNotEmpty) {
      return mode.blockingReasons.map((reason) => reason.frenchLabel).join(' ');
    }
    if (runtimeKnownEnabled == false || !mode.runtimeAvailabilityIntent) {
      return 'La disponibilité opérationnelle est désactivée côté serveur.';
    }
    return fallback;
  }
}
