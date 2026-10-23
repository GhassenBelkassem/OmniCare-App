import 'package:flutter/foundation.dart';

import '../emergency_symptom_intake_value.dart';
import 'urgent_cabinet_care_subject.dart';

enum UrgentCabinetClinicalIntakeIssue {
  missingAnatomicalRegion,
  invalidAnatomicalRegion,
  invalidPainScore,
  missingDescription,
  descriptionTooLong,
}

/// Route-scoped raw clinical intake for one exact urgent CABINET target.
///
/// This model is intentionally not a backend DTO. In particular, it exposes no
/// `bodyAreaCodes` transformation while anatomical mapping is under review.
@immutable
class UrgentCabinetClinicalIntakeDraft {
  static const int maxDescriptionCharacters = 500;

  UrgentCabinetClinicalIntakeDraft({
    required this.careSubject,
    required String doctorId,
    required String cabinetId,
    required Iterable<String> rawAnatomicalRegionIds,
    required this.painScore,
    required String shortDescription,
  }) : doctorId = doctorId.trim(),
       cabinetId = cabinetId.trim(),
       rawAnatomicalRegionIds = List.unmodifiable(rawAnatomicalRegionIds),
       shortDescription = shortDescription.trim();

  factory UrgentCabinetClinicalIntakeDraft.fromPresentation({
    required UrgentCabinetCareSubject careSubject,
    required String doctorId,
    required String cabinetId,
    required EmergencySymptomIntakeValue value,
  }) {
    return UrgentCabinetClinicalIntakeDraft(
      careSubject: careSubject,
      doctorId: doctorId,
      cabinetId: cabinetId,
      rawAnatomicalRegionIds: value.rawAnatomicalRegionIds,
      painScore: value.painScore,
      shortDescription: value.shortDescription,
    );
  }

  final UrgentCabinetCareSubject careSubject;
  final String doctorId;
  final String cabinetId;
  final List<String> rawAnatomicalRegionIds;
  final int painScore;
  final String shortDescription;

  UrgentCabinetClinicalIntakeIssue? get validationIssue {
    if (rawAnatomicalRegionIds.isEmpty) {
      return UrgentCabinetClinicalIntakeIssue.missingAnatomicalRegion;
    }
    if (rawAnatomicalRegionIds.any((identifier) => identifier.trim().isEmpty)) {
      return UrgentCabinetClinicalIntakeIssue.invalidAnatomicalRegion;
    }
    if (painScore < 0 || painScore > 10) {
      return UrgentCabinetClinicalIntakeIssue.invalidPainScore;
    }
    if (shortDescription.isEmpty) {
      return UrgentCabinetClinicalIntakeIssue.missingDescription;
    }
    if (shortDescription.runes.length > maxDescriptionCharacters) {
      return UrgentCabinetClinicalIntakeIssue.descriptionTooLong;
    }
    return null;
  }

  bool get isValid => validationIssue == null;

  bool belongsTo({
    required UrgentCabinetCareSubject? subject,
    required String? selectedDoctorId,
    required String? selectedCabinetId,
  }) {
    return careSubject == subject &&
        doctorId == selectedDoctorId &&
        cabinetId == selectedCabinetId;
  }
}
