/// Presentation-only doctor model for the patient doctor directory.
///
/// This wraps the mock doctor data into a typed model. No backend API is used;
/// all data comes from [createMockDoctors].
class DoctorListItem {
  const DoctorListItem({
    required this.id,
    required this.name,
    required this.specialty,
    required this.rating,
    required this.totalReviews,
    required this.officeConsultationFee,
    required this.experienceYears,
    required this.isOnline,
    required this.providerId,
    this.address,
    this.phoneNumber,
    this.latitude,
    this.longitude,
    this.imageAssetPath,
    this.subSpecialties = const [],
    this.distanceKm,
    this.acceptingNewPatients = true,
    this.patientAgeGroup,
    this.consultationTypes = const [],
    this.gender,
    this.languages = const [],
    this.visitReasons = const [],
    this.insuranceAccepted = const [],
    this.practiceLocationType,
    this.timeOfDay,
    this.availableSaturday = false,
    this.homeVisitAvailable = false,
    this.dutyService = false,
  });

  final String id;
  final String name;
  final String specialty;
  final double rating;
  final int totalReviews;
  final double officeConsultationFee;
  final int experienceYears;
  final bool isOnline;
  final String providerId;
  final String? address;
  final String? phoneNumber;
  final double? latitude;
  final double? longitude;

  /// Optional local asset path for the doctor's photo.
  /// Falls back to initials when null or empty.
  final String? imageAssetPath;

  /// Sub-specialties / expertise areas (e.g. "Cardiologie interventionnelle").
  final List<String> subSpecialties;

  /// Distance from the user in km (mock value).
  final double? distanceKm;

  /// Whether the doctor is accepting new patients.
  final bool acceptingNewPatients;

  /// Patient age group: 'Enfants', 'Adultes', 'Personnes âgées'.
  final String? patientAgeGroup;

  /// Available consultation types (e.g. 'En cabinet', 'Téléconsultation').
  final List<String> consultationTypes;

  /// Doctor gender: 'Femme', 'Homme'.
  final String? gender;

  /// Languages spoken.
  final List<String> languages;

  /// Common reasons for visit / expertise areas.
  final List<String> visitReasons;

  /// Insurance / coverage accepted.
  final List<String> insuranceAccepted;

  /// Practice location type: 'Cabinet privé', 'Clinique', 'Hôpital'.
  final String? practiceLocationType;

  /// Available time of day: 'Matin', 'Après-midi', 'Soir'.
  final String? timeOfDay;

  /// Whether the doctor is available on Saturday.
  final bool availableSaturday;

  /// Whether home visits are available.
  final bool homeVisitAvailable;

  /// Whether the doctor offers 24/7 / duty service.
  final bool dutyService;

  factory DoctorListItem.fromMap(Map<String, dynamic> map) {
    return DoctorListItem(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      specialty: map['specialty'] as String? ?? '',
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      totalReviews: (map['totalReviews'] as num?)?.toInt() ?? 0,
      officeConsultationFee:
          (map['officeConsultationFee'] as num?)?.toDouble() ?? 0.0,
      experienceYears: (map['experienceYears'] as num?)?.toInt() ?? 0,
      isOnline: map['isOnline'] as bool? ?? false,
      providerId: map['providerId'] as String? ?? '',
      address: map['address'] as String?,
      phoneNumber: map['phoneNumber'] as String?,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
    );
  }

  String get displayName => name;

  String get experienceLabel {
    if (experienceYears == 0) return '';
    return '$experienceYears years exp.';
  }
}
