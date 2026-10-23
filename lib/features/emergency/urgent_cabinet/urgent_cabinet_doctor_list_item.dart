import 'package:flutter/foundation.dart';

enum UrgentCabinetEligibility { eligible, ineligible }

enum UrgentCabinetAvailability { availableNow, unavailable }

/// The lifecycle of this doctor's response to one particular urgent request.
///
/// Directory fixtures always use [notRequested]. Eligibility and current
/// availability do not imply that a doctor has accepted a future request.
enum UrgentCabinetRequestDecision { notRequested, pending, accepted, declined }

/// P4-only domain/presentation model for an urgent CABINET search result.
///
/// This is intentionally not a backend DTO. A future repository can populate
/// the same model once an approved P4 API contract exists.
@immutable
class UrgentCabinetDoctorListItem {
  const UrgentCabinetDoctorListItem({
    required this.doctorId,
    required this.displayName,
    required this.specialty,
    required this.eligibility,
    required this.availability,
    required this.activeCabinetId,
    required this.cabinetName,
    required this.cabinetLocality,
    required this.cabinetGovernorate,
    required this.cabinetCity,
    this.cabinetAddress,
    this.distanceKm,
    this.distanceIsStraightLine = false,
    this.urgentCabinetFeeMilliTnd,
    this.configurationRevision,
    this.runtimeRevision,
    this.practiceLocationVersion,
    this.latitude,
    this.longitude,
    this.imageAssetPath,
    this.requestDecision = UrgentCabinetRequestDecision.notRequested,
  });

  final String doctorId;
  final String displayName;
  final String specialty;
  final UrgentCabinetEligibility eligibility;
  final UrgentCabinetAvailability availability;
  final String activeCabinetId;
  final String cabinetName;
  final String cabinetLocality;
  final String cabinetGovernorate;
  final String cabinetCity;
  final String? cabinetAddress;
  final double? distanceKm;
  final bool distanceIsStraightLine;
  final int? urgentCabinetFeeMilliTnd;
  final int? configurationRevision;
  final int? runtimeRevision;
  final int? practiceLocationVersion;
  final double? latitude;
  final double? longitude;
  final String? imageAssetPath;
  final UrgentCabinetRequestDecision requestDecision;

  bool get canReceiveUrgentRequest =>
      eligibility == UrgentCabinetEligibility.eligible &&
      availability == UrgentCabinetAvailability.availableNow &&
      requestDecision == UrgentCabinetRequestDecision.notRequested;

  String get locationLabel => '$cabinetName · $cabinetLocality';
}
