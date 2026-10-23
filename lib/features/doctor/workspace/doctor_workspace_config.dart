enum DoctorPracticeMode {
  cabinet,
  clinic,
  homeVisit,
  urgentHome,
  teleconsultation;

  String get label => switch (this) {
    DoctorPracticeMode.cabinet => 'Cabinet',
    DoctorPracticeMode.clinic => 'Clinique',
    DoctorPracticeMode.homeVisit => 'Visites à domicile',
    DoctorPracticeMode.urgentHome => 'Urgences à domicile',
    DoctorPracticeMode.teleconsultation => 'Téléconsultation',
  };
}

enum DoctorWorkspaceService {
  cabinetConsultations,
  urgentCabinetConsultations,
  patientFollowUp,
  appointments,
  homeVisits,
  urgentHomeVisits,
  clinicWorkspace,
  teleconsultationPreparation;

  String get label => switch (this) {
    DoctorWorkspaceService.cabinetConsultations => 'Consultations au cabinet',
    DoctorWorkspaceService.urgentCabinetConsultations =>
      'Consultations urgentes au cabinet',
    DoctorWorkspaceService.patientFollowUp => 'Suivi patient',
    DoctorWorkspaceService.appointments => 'Rendez-vous',
    DoctorWorkspaceService.homeVisits => 'Visites à domicile',
    DoctorWorkspaceService.urgentHomeVisits => 'Urgences à domicile',
    DoctorWorkspaceService.clinicWorkspace => 'Accès à l’espace clinique',
    DoctorWorkspaceService.teleconsultationPreparation =>
      'Préparer la téléconsultation',
  };
}

enum DoctorCapability {
  agenda,

  /// Legacy HOME-urgent capability retained for existing HOME presentation.
  urgentRequests,
  urgentHomeRequests,
  urgentCabinetRequests,
  urgentWorkspace,
  patientManagement,
  workQueue,
  followUp,
  homeVisits,
  cabinetAppointments,
  clinicWorkspace,
}

enum DoctorWorkingDay {
  monday,
  tuesday,
  wednesday,
  thursday,
  friday,
  saturday,
  sunday;

  String get shortLabel => switch (this) {
    DoctorWorkingDay.monday => 'Lun',
    DoctorWorkingDay.tuesday => 'Mar',
    DoctorWorkingDay.wednesday => 'Mer',
    DoctorWorkingDay.thursday => 'Jeu',
    DoctorWorkingDay.friday => 'Ven',
    DoctorWorkingDay.saturday => 'Sam',
    DoctorWorkingDay.sunday => 'Dim',
  };
}

class DoctorCabinetConfig {
  const DoctorCabinetConfig({
    required this.name,
    required this.governorate,
    required this.city,
    required this.address,
  });

  final String name;
  final String governorate;
  final String city;
  final String address;

  Map<String, dynamic> toJson() => {
    'name': name,
    'governorate': governorate,
    'city': city,
    'address': address,
  };

  factory DoctorCabinetConfig.fromJson(Map<String, dynamic> json) {
    return DoctorCabinetConfig(
      name: _requiredString(json, 'name'),
      governorate: _requiredString(json, 'governorate'),
      city: _requiredString(json, 'city'),
      address: _requiredString(json, 'address'),
    );
  }
}

class DoctorClinicAffiliation {
  const DoctorClinicAffiliation({required this.id, required this.name});

  final String id;
  final String name;

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  factory DoctorClinicAffiliation.fromJson(Map<String, dynamic> json) {
    return DoctorClinicAffiliation(
      id: _requiredString(json, 'id'),
      name: _requiredString(json, 'name'),
    );
  }
}

class DoctorHomeVisitConfig {
  const DoctorHomeVisitConfig({
    required this.governorate,
    this.maxDistanceKm,
    required this.availableForHomeVisits,
  });

  final String governorate;
  final int? maxDistanceKm;
  final bool availableForHomeVisits;

  Map<String, dynamic> toJson() => {
    'governorate': governorate,
    'maxDistanceKm': maxDistanceKm,
    'availableForHomeVisits': availableForHomeVisits,
  };

  factory DoctorHomeVisitConfig.fromJson(Map<String, dynamic> json) {
    final distance = json['maxDistanceKm'];
    if (distance != null && distance is! int) {
      throw const FormatException('Invalid home visit radius.');
    }
    final available = json['availableForHomeVisits'];
    if (available is! bool) {
      throw const FormatException('Invalid home visit availability.');
    }
    return DoctorHomeVisitConfig(
      governorate: _requiredString(json, 'governorate'),
      maxDistanceKm: distance as int?,
      availableForHomeVisits: available,
    );
  }
}

class DoctorAvailability {
  const DoctorAvailability({
    required this.workingDays,
    required this.startTime,
    required this.endTime,
  });

  final Set<DoctorWorkingDay> workingDays;
  final String startTime;
  final String endTime;

  Map<String, dynamic> toJson() => {
    'workingDays': workingDays.map((day) => day.name).toList(),
    'startTime': startTime,
    'endTime': endTime,
  };

  factory DoctorAvailability.fromJson(Map<String, dynamic> json) {
    return DoctorAvailability(
      workingDays: _enumSet<DoctorWorkingDay>(
        json['workingDays'],
        DoctorWorkingDay.values,
      ),
      startTime: _requiredString(json, 'startTime'),
      endTime: _requiredString(json, 'endTime'),
    );
  }
}

/// Small, versioned D1 workspace record. It intentionally models only the
/// local choices that later Doctor phases need to interpret.
class DoctorWorkspaceConfig {
  const DoctorWorkspaceConfig({
    required this.doctorId,
    required this.onboardingCompleted,
    required this.practiceModes,
    required this.services,
    required this.clinics,
    required this.availability,
    this.cabinet,
    this.homeVisit,
  });

  static const schemaVersion = 1;

  final String doctorId;
  final bool onboardingCompleted;
  final Set<DoctorPracticeMode> practiceModes;
  final Set<DoctorWorkspaceService> services;
  final DoctorCabinetConfig? cabinet;
  final List<DoctorClinicAffiliation> clinics;
  final DoctorHomeVisitConfig? homeVisit;
  final DoctorAvailability availability;

  bool get hasHomeActivity =>
      practiceModes.contains(DoctorPracticeMode.homeVisit) ||
      practiceModes.contains(DoctorPracticeMode.urgentHome);

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'doctorId': doctorId,
    'onboardingCompleted': onboardingCompleted,
    'practiceModes': practiceModes.map((mode) => mode.name).toList(),
    'services': services.map((service) => service.name).toList(),
    'cabinet': cabinet?.toJson(),
    'clinics': clinics.map((clinic) => clinic.toJson()).toList(),
    'homeVisit': homeVisit?.toJson(),
    'availability': availability.toJson(),
  };

  factory DoctorWorkspaceConfig.fromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != schemaVersion) {
      throw const FormatException('Unsupported Doctor workspace schema.');
    }
    final completed = json['onboardingCompleted'];
    if (completed is! bool) {
      throw const FormatException('Invalid Doctor onboarding state.');
    }
    final cabinetJson = json['cabinet'];
    final homeJson = json['homeVisit'];
    final availabilityJson = json['availability'];
    final clinicsJson = json['clinics'];
    if (cabinetJson != null && cabinetJson is! Map) {
      throw const FormatException('Invalid cabinet configuration.');
    }
    if (homeJson != null && homeJson is! Map) {
      throw const FormatException('Invalid home visit configuration.');
    }
    if (availabilityJson is! Map || clinicsJson is! List) {
      throw const FormatException('Invalid Doctor workspace configuration.');
    }
    return DoctorWorkspaceConfig(
      doctorId: _requiredString(json, 'doctorId'),
      onboardingCompleted: completed,
      practiceModes: _enumSet<DoctorPracticeMode>(
        json['practiceModes'],
        DoctorPracticeMode.values,
      ),
      services: _enumSet<DoctorWorkspaceService>(
        json['services'],
        DoctorWorkspaceService.values,
      ),
      cabinet: cabinetJson == null
          ? null
          : DoctorCabinetConfig.fromJson(
              Map<String, dynamic>.from(cabinetJson),
            ),
      clinics: clinicsJson
          .map((clinic) {
            if (clinic is! Map) {
              throw const FormatException('Invalid clinic affiliation.');
            }
            return DoctorClinicAffiliation.fromJson(
              Map<String, dynamic>.from(clinic),
            );
          })
          .toList(growable: false),
      homeVisit: homeJson == null
          ? null
          : DoctorHomeVisitConfig.fromJson(Map<String, dynamic>.from(homeJson)),
      availability: DoctorAvailability.fromJson(
        Map<String, dynamic>.from(availabilityJson),
      ),
    );
  }
}

/// Single D1 interpretation point. D2 can consume this set without embedding
/// practice-mode checks throughout navigation and feature widgets.
Set<DoctorCapability> deriveDoctorCapabilities(DoctorWorkspaceConfig config) {
  final capabilities = <DoctorCapability>{};
  final modes = config.practiceModes;
  final services = config.services;

  if (modes.contains(DoctorPracticeMode.cabinet)) {
    capabilities.addAll({
      DoctorCapability.agenda,
      DoctorCapability.patientManagement,
      DoctorCapability.workQueue,
      DoctorCapability.followUp,
    });
  }
  if (modes.contains(DoctorPracticeMode.cabinet) ||
      services.contains(DoctorWorkspaceService.cabinetConsultations) ||
      services.contains(DoctorWorkspaceService.appointments)) {
    capabilities.add(DoctorCapability.cabinetAppointments);
  }
  if (modes.contains(DoctorPracticeMode.clinic) ||
      services.contains(DoctorWorkspaceService.clinicWorkspace)) {
    capabilities.add(DoctorCapability.clinicWorkspace);
  }
  if (modes.contains(DoctorPracticeMode.homeVisit) ||
      modes.contains(DoctorPracticeMode.urgentHome) ||
      services.contains(DoctorWorkspaceService.homeVisits)) {
    capabilities.addAll({
      DoctorCapability.homeVisits,
      DoctorCapability.patientManagement,
      DoctorCapability.workQueue,
      DoctorCapability.followUp,
    });
  }
  final hasUrgentHome =
      modes.contains(DoctorPracticeMode.urgentHome) ||
      services.contains(DoctorWorkspaceService.urgentHomeVisits);
  final hasUrgentCabinet = services.contains(
    DoctorWorkspaceService.urgentCabinetConsultations,
  );
  if (hasUrgentHome) {
    capabilities.addAll({
      DoctorCapability.urgentRequests,
      DoctorCapability.urgentHomeRequests,
      DoctorCapability.urgentWorkspace,
      DoctorCapability.patientManagement,
      DoctorCapability.workQueue,
    });
  }
  if (hasUrgentCabinet) {
    capabilities.addAll({
      DoctorCapability.urgentCabinetRequests,
      DoctorCapability.urgentWorkspace,
    });
  }
  if (services.contains(DoctorWorkspaceService.patientFollowUp)) {
    capabilities.add(DoctorCapability.followUp);
  }
  return capabilities;
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Missing Doctor workspace field: $key.');
  }
  return value.trim();
}

Set<T> _enumSet<T extends Enum>(Object? source, List<T> values) {
  if (source is! List) {
    throw const FormatException('Invalid Doctor workspace enum list.');
  }
  final result = <T>{};
  for (final value in source) {
    if (value is! String) {
      throw const FormatException('Invalid Doctor workspace enum value.');
    }
    final match = values.where((candidate) => candidate.name == value);
    if (match.isEmpty) {
      throw const FormatException('Unknown Doctor workspace enum value.');
    }
    result.add(match.first);
  }
  return result;
}
