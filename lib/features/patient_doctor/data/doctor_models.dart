import 'doctor_directory_models.dart';

/// Patient-facing model backed only by Doctor search/detail response fields.
class DoctorListItem {
  const DoctorListItem({
    required this.id,
    required this.name,
    this.specialty,
    this.photoUrl,
    this.consultationPriceTnd,
    this.experienceYears,
    this.verified = false,
    this.acceptingNewPatients = true,
    this.careCapabilities = const [],
    this.distanceKm,
    this.matchingPracticeLocation,
    this.subSpecialties = const [],
    this.consultationTypes = const [],
    this.languages = const [],
    this.visitReasons = const [],
  });

  final String id;
  final String name;
  final String? specialty;
  final String? photoUrl;
  final double? consultationPriceTnd;
  final int? experienceYears;
  final bool verified;
  final bool acceptingNewPatients;
  final List<DoctorCareCapability> careCapabilities;
  final double? distanceKm;
  final DoctorMatchingPracticeLocation? matchingPracticeLocation;

  // Detail-only fields remain empty on lightweight directory cards.
  final List<String> subSpecialties;
  final List<String> consultationTypes;
  final List<String> languages;
  final List<String> visitReasons;

  String get displayName => name;
  String get displaySpecialty => specialty ?? 'Spécialité non renseignée';

  String get experienceLabel {
    final years = experienceYears;
    if (years == null || years <= 0) return '';
    return '$years ans d\'expérience';
  }
}
