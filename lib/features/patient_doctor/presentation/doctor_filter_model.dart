import '../data/doctor_models.dart';

/// Sort orders for the doctor directory.
enum DoctorSortOrder {
  defaultOrder,
  alphabetical,
  ratingDesc;

  String get label => switch (this) {
    DoctorSortOrder.defaultOrder => 'Par défaut',
    DoctorSortOrder.alphabetical => 'A–Z',
    DoctorSortOrder.ratingDesc => 'Mieux notés',
  };
}

/// Immutable local filter state for the doctor directory.
///
/// Filters are presentation-only and applied to the currently loaded doctors.
/// They never become backend query parameters.
class DoctorFilterSnapshot {
  const DoctorFilterSnapshot({
    this.specialties = const {},
    this.distance,
    this.availability,
    this.acceptingNewPatients,
    this.patientAgeGroup,
    this.consultationTypes = const {},
    this.gender,
    this.languages = const {},
    this.visitReasons = const {},
    this.insuranceAccepted = const {},
    this.experience,
    this.practiceLocationType,
    this.timeOfDay,
    this.availableSaturday,
    this.homeVisitAvailable,
    this.dutyService,
    this.sortOrder = DoctorSortOrder.defaultOrder,
  });

  static const DoctorFilterSnapshot none = DoctorFilterSnapshot();

  final Set<String> specialties;
  final String? distance;
  final String? availability;
  final bool? acceptingNewPatients;
  final String? patientAgeGroup;
  final Set<String> consultationTypes;
  final String? gender;
  final Set<String> languages;
  final Set<String> visitReasons;
  final Set<String> insuranceAccepted;
  final String? experience;
  final String? practiceLocationType;
  final String? timeOfDay;
  final bool? availableSaturday;
  final bool? homeVisitAvailable;
  final bool? dutyService;
  final DoctorSortOrder sortOrder;

  bool get isActive => activeGroupCount > 0;

  int get activeGroupCount {
    var count = 0;
    if (specialties.isNotEmpty) count++;
    if (distance != null) count++;
    if (availability != null) count++;
    if (acceptingNewPatients != null) count++;
    if (patientAgeGroup != null) count++;
    if (consultationTypes.isNotEmpty) count++;
    if (gender != null) count++;
    if (languages.isNotEmpty) count++;
    if (visitReasons.isNotEmpty) count++;
    if (insuranceAccepted.isNotEmpty) count++;
    if (experience != null) count++;
    if (practiceLocationType != null) count++;
    if (timeOfDay != null) count++;
    if (availableSaturday == true) count++;
    if (homeVisitAvailable == true) count++;
    if (dutyService == true) count++;
    if (sortOrder != DoctorSortOrder.defaultOrder) count++;
    return count;
  }

  DoctorFilterSnapshot copyWith({
    Set<String>? specialties,
    String? distance,
    bool clearDistance = false,
    String? availability,
    bool clearAvailability = false,
    bool? acceptingNewPatients,
    bool clearAcceptingNewPatients = false,
    String? patientAgeGroup,
    bool clearPatientAgeGroup = false,
    Set<String>? consultationTypes,
    String? gender,
    bool clearGender = false,
    Set<String>? languages,
    Set<String>? visitReasons,
    Set<String>? insuranceAccepted,
    String? experience,
    bool clearExperience = false,
    String? practiceLocationType,
    bool clearPracticeLocationType = false,
    String? timeOfDay,
    bool clearTimeOfDay = false,
    bool? availableSaturday,
    bool clearAvailableSaturday = false,
    bool? homeVisitAvailable,
    bool clearHomeVisitAvailable = false,
    bool? dutyService,
    bool clearDutyService = false,
    DoctorSortOrder? sortOrder,
  }) {
    return DoctorFilterSnapshot(
      specialties: specialties ?? this.specialties,
      distance: clearDistance ? null : (distance ?? this.distance),
      availability: clearAvailability
          ? null
          : (availability ?? this.availability),
      acceptingNewPatients: clearAcceptingNewPatients
          ? null
          : (acceptingNewPatients ?? this.acceptingNewPatients),
      patientAgeGroup: clearPatientAgeGroup
          ? null
          : (patientAgeGroup ?? this.patientAgeGroup),
      consultationTypes: consultationTypes ?? this.consultationTypes,
      gender: clearGender ? null : (gender ?? this.gender),
      languages: languages ?? this.languages,
      visitReasons: visitReasons ?? this.visitReasons,
      insuranceAccepted: insuranceAccepted ?? this.insuranceAccepted,
      experience: clearExperience ? null : (experience ?? this.experience),
      practiceLocationType: clearPracticeLocationType
          ? null
          : (practiceLocationType ?? this.practiceLocationType),
      timeOfDay: clearTimeOfDay ? null : (timeOfDay ?? this.timeOfDay),
      availableSaturday: clearAvailableSaturday
          ? null
          : (availableSaturday ?? this.availableSaturday),
      homeVisitAvailable: clearHomeVisitAvailable
          ? null
          : (homeVisitAvailable ?? this.homeVisitAvailable),
      dutyService: clearDutyService ? null : (dutyService ?? this.dutyService),
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }

  @override
  bool operator ==(Object other) {
    if (other is! DoctorFilterSnapshot) return false;
    return _setEquals(specialties, other.specialties) &&
        distance == other.distance &&
        availability == other.availability &&
        acceptingNewPatients == other.acceptingNewPatients &&
        patientAgeGroup == other.patientAgeGroup &&
        _setEquals(consultationTypes, other.consultationTypes) &&
        gender == other.gender &&
        _setEquals(languages, other.languages) &&
        _setEquals(visitReasons, other.visitReasons) &&
        _setEquals(insuranceAccepted, other.insuranceAccepted) &&
        experience == other.experience &&
        practiceLocationType == other.practiceLocationType &&
        timeOfDay == other.timeOfDay &&
        availableSaturday == other.availableSaturday &&
        homeVisitAvailable == other.homeVisitAvailable &&
        dutyService == other.dutyService &&
        sortOrder == other.sortOrder;
  }

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(specialties),
    distance,
    availability,
    acceptingNewPatients,
    patientAgeGroup,
    Object.hashAllUnordered(consultationTypes),
    gender,
    Object.hashAllUnordered(languages),
    Object.hashAllUnordered(visitReasons),
    Object.hashAllUnordered(insuranceAccepted),
    experience,
    practiceLocationType,
    timeOfDay,
    availableSaturday,
    homeVisitAvailable,
    dutyService,
    sortOrder,
  );
}

/// The option vocabulary shown in the doctor filter bottom sheet.
class DoctorFilterOptions {
  const DoctorFilterOptions({
    this.specialties = const [],
    this.languages = const [],
    this.visitReasons = const [],
    this.insuranceOptions = const [],
    this.distanceOptions = const [
      '2 km',
      '5 km',
      '10 km',
      '25 km',
      'Toutes distances',
    ],
    this.availabilityOptions = const [
      "Aujourd'hui",
      'Demain',
      '3 prochains jours',
      '7 prochains jours',
    ],
    this.patientAgeGroupOptions = const [
      'Enfants',
      'Adultes',
      'Personnes âgées',
    ],
    this.consultationTypeOptions = const [
      'En cabinet',
      'Téléconsultation',
      'Visite à domicile',
    ],
    this.genderOptions = const ['Femme', 'Homme', 'Peu importe'],
    this.experienceOptions = const ['5+ ans', '10+ ans', '15+ ans'],
    this.practiceLocationOptions = const [
      'Cabinet privé',
      'Clinique',
      'Hôpital',
    ],
    this.timeOfDayOptions = const ['Matin', 'Après-midi', 'Soir'],
  });

  final List<String> specialties;
  final List<String> languages;
  final List<String> visitReasons;
  final List<String> insuranceOptions;
  final List<String> distanceOptions;
  final List<String> availabilityOptions;
  final List<String> patientAgeGroupOptions;
  final List<String> consultationTypeOptions;
  final List<String> genderOptions;
  final List<String> experienceOptions;
  final List<String> practiceLocationOptions;
  final List<String> timeOfDayOptions;
}

/// Builds the filter option vocabulary from the currently loaded doctors.
DoctorFilterOptions buildDoctorFilterOptions(Iterable<DoctorListItem> doctors) {
  final specialties = <String>{};
  final languages = <String>{};
  final visitReasons = <String>{};
  final insurance = <String>{};

  for (final doctor in doctors) {
    if (doctor.specialty.trim().isNotEmpty) {
      specialties.add(doctor.specialty);
    }
    languages.addAll(doctor.languages);
    visitReasons.addAll(doctor.visitReasons);
    insurance.addAll(doctor.insuranceAccepted);
  }

  List<String> sorted(Set<String> values) => values.toList()..sort();
  return DoctorFilterOptions(
    specialties: List.unmodifiable(sorted(specialties)),
    languages: List.unmodifiable(sorted(languages)),
    visitReasons: List.unmodifiable(sorted(visitReasons)),
    insuranceOptions: List.unmodifiable(sorted(insurance)),
  );
}

/// Applies the local filters to the currently loaded doctors.
List<DoctorListItem> applyDoctorFilters({
  required List<DoctorListItem> items,
  required DoctorFilterSnapshot filters,
}) {
  final filtered = <DoctorListItem>[];
  for (final doctor in items) {
    if (_matches(doctor, filters)) filtered.add(doctor);
  }

  if (filters.sortOrder == DoctorSortOrder.defaultOrder || filtered.isEmpty) {
    return filtered;
  }

  final indexed = <(int, DoctorListItem)>[
    for (var index = 0; index < filtered.length; index++)
      (index, filtered[index]),
  ];

  switch (filters.sortOrder) {
    case DoctorSortOrder.alphabetical:
      indexed.sort((a, b) {
        final byName = a.$2.name.toLowerCase().compareTo(
          b.$2.name.toLowerCase(),
        );
        return byName != 0 ? byName : a.$1.compareTo(b.$1);
      });
    case DoctorSortOrder.ratingDesc:
      indexed.sort((a, b) {
        final byRating = b.$2.rating.compareTo(a.$2.rating);
        return byRating != 0 ? byRating : a.$1.compareTo(b.$1);
      });
    case DoctorSortOrder.defaultOrder:
      break;
  }

  return [for (final entry in indexed) entry.$2];
}

bool _matches(DoctorListItem doctor, DoctorFilterSnapshot filters) {
  if (filters.specialties.isNotEmpty &&
      !filters.specialties.contains(doctor.specialty)) {
    return false;
  }

  if (filters.distance != null && doctor.distanceKm != null) {
    final maxKm = _parseDistanceKm(filters.distance!);
    if (maxKm != null && doctor.distanceKm! > maxKm) return false;
  }

  if (filters.acceptingNewPatients == true && !doctor.acceptingNewPatients) {
    return false;
  }

  if (filters.patientAgeGroup != null &&
      doctor.patientAgeGroup != filters.patientAgeGroup) {
    return false;
  }

  if (filters.consultationTypes.isNotEmpty) {
    final hasOverlap = filters.consultationTypes.any(
      (t) => doctor.consultationTypes.contains(t),
    );
    if (!hasOverlap) return false;
  }

  if (filters.gender != null &&
      filters.gender != 'Peu importe' &&
      doctor.gender != filters.gender) {
    return false;
  }

  if (filters.languages.isNotEmpty) {
    final hasOverlap = filters.languages.any(
      (l) => doctor.languages.contains(l),
    );
    if (!hasOverlap) return false;
  }

  if (filters.visitReasons.isNotEmpty) {
    final hasOverlap = filters.visitReasons.any(
      (r) => doctor.visitReasons.contains(r),
    );
    if (!hasOverlap) return false;
  }

  if (filters.insuranceAccepted.isNotEmpty) {
    final hasOverlap = filters.insuranceAccepted.any(
      (i) => doctor.insuranceAccepted.contains(i),
    );
    if (!hasOverlap) return false;
  }

  if (filters.experience != null) {
    final minYears = _parseExperience(filters.experience!);
    if (minYears != null && doctor.experienceYears < minYears) return false;
  }

  if (filters.practiceLocationType != null &&
      doctor.practiceLocationType != filters.practiceLocationType) {
    return false;
  }

  if (filters.timeOfDay != null && doctor.timeOfDay != filters.timeOfDay) {
    return false;
  }

  if (filters.availableSaturday == true && !doctor.availableSaturday) {
    return false;
  }

  if (filters.homeVisitAvailable == true && !doctor.homeVisitAvailable) {
    return false;
  }

  if (filters.dutyService == true && !doctor.dutyService) {
    return false;
  }

  return true;
}

double? _parseDistanceKm(String label) {
  return switch (label) {
    '2 km' => 2.0,
    '5 km' => 5.0,
    '10 km' => 10.0,
    '25 km' => 25.0,
    'Toutes distances' => null,
    _ => null,
  };
}

int? _parseExperience(String label) {
  return switch (label) {
    '5+ ans' => 5,
    '10+ ans' => 10,
    '15+ ans' => 15,
    _ => null,
  };
}

bool _setEquals(Set<String> a, Set<String> b) {
  if (a.length != b.length) return false;
  return a.containsAll(b);
}
