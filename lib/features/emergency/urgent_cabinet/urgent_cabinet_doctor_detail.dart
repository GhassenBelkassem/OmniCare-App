import 'package:flutter/foundation.dart';

import 'urgent_cabinet_doctor_list_item.dart';

enum UrgentCabinetDoctorDetailProvenance { developmentFixture, service }

enum UrgentCabinetDoctorImageSource { asset, network }

@immutable
class UrgentCabinetDoctorImage {
  const UrgentCabinetDoctorImage.asset(this.value)
    : source = UrgentCabinetDoctorImageSource.asset;

  const UrgentCabinetDoctorImage.network(this.value)
    : source = UrgentCabinetDoctorImageSource.network;

  final String value;
  final UrgentCabinetDoctorImageSource source;

  bool get isAsset => source == UrgentCabinetDoctorImageSource.asset;
  bool get isNetwork => source == UrgentCabinetDoctorImageSource.network;
}

@immutable
class UrgentCabinetOpeningHours {
  const UrgentCabinetOpeningHours({required this.day, required this.hours});

  final String day;
  final String hours;
}

@immutable
class UrgentCabinetLocationDetail {
  const UrgentCabinetLocationDetail({
    required this.cabinetId,
    required this.name,
    required this.locality,
    required this.city,
    required this.governorate,
    this.address,
    this.distanceKm,
    this.latitude,
    this.longitude,
    this.gallery = const [],
    this.equipment = const [],
    this.openingHours = const [],
    this.accessibility = const [],
  });

  final String cabinetId;
  final String name;
  final String locality;
  final String city;
  final String governorate;
  final String? address;
  final double? distanceKm;
  final double? latitude;
  final double? longitude;
  final List<UrgentCabinetDoctorImage> gallery;
  final List<String> equipment;
  final List<UrgentCabinetOpeningHours> openingHours;
  final List<String> accessibility;
}

/// P4-only presentation model for urgent CABINET doctor details.
///
/// This is deliberately not a backend DTO and never enters the P3 scheduled
/// booking state. [provenance] makes temporary synthetic content explicit.
@immutable
class UrgentCabinetDoctorDetail {
  const UrgentCabinetDoctorDetail({
    required this.doctorId,
    required this.displayName,
    required this.specialty,
    required this.eligibility,
    required this.availability,
    required this.provenance,
    required this.cabinets,
    this.portrait,
    this.subSpecialties = const [],
    this.experienceYears,
    this.languages = const [],
    this.biography,
    this.areasOfCare = const [],
    this.expertise = const [],
    this.visitReasons = const [],
    this.urgentCabinetFeeMilliTnd,
    this.configurationRevision,
    this.runtimeRevision,
    this.practiceLocationVersion,
    this.evaluatedAt,
  });

  final String doctorId;
  final String displayName;
  final String specialty;
  final UrgentCabinetEligibility eligibility;
  final UrgentCabinetAvailability availability;
  final UrgentCabinetDoctorDetailProvenance provenance;
  final List<UrgentCabinetLocationDetail> cabinets;
  final UrgentCabinetDoctorImage? portrait;
  final List<String> subSpecialties;
  final int? experienceYears;
  final List<String> languages;
  final String? biography;
  final List<String> areasOfCare;
  final List<String> expertise;
  final List<String> visitReasons;
  final int? urgentCabinetFeeMilliTnd;
  final int? configurationRevision;
  final int? runtimeRevision;
  final int? practiceLocationVersion;
  final DateTime? evaluatedAt;

  bool get isDevelopmentFixture =>
      provenance == UrgentCabinetDoctorDetailProvenance.developmentFixture;

  UrgentCabinetLocationDetail? cabinetById(String cabinetId) {
    final normalized = cabinetId.trim();
    for (final cabinet in cabinets) {
      if (cabinet.cabinetId == normalized) return cabinet;
    }
    return null;
  }
}
