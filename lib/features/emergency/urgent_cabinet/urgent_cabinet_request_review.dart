import 'package:flutter/foundation.dart';

import 'urgent_cabinet_care_subject.dart';
import 'urgent_cabinet_doctor_detail.dart';
import 'urgent_cabinet_doctor_list_item.dart';

enum UrgentCabinetFeeProvenance { developmentFixture, service }

/// P4-only monetary quote for one urgent doctor/cabinet pair.
///
/// Amounts are stored in thousandths of a Tunisian dinar. No floating-point
/// money or scheduled-care price model enters the urgent CABINET flow.
@immutable
class UrgentCabinetFeeQuote {
  const UrgentCabinetFeeQuote({
    required this.doctorId,
    required this.cabinetId,
    required this.amountMilliTnd,
    required this.currencyCode,
    required this.provenance,
    this.quotedAt,
    this.expiresAt,
    this.configurationRevision,
    this.runtimeRevision,
    this.practiceLocationVersion,
  });

  final String doctorId;
  final String cabinetId;
  final int amountMilliTnd;
  final String currencyCode;
  final UrgentCabinetFeeProvenance provenance;
  final DateTime? quotedAt;
  final DateTime? expiresAt;
  final int? configurationRevision;
  final int? runtimeRevision;
  final int? practiceLocationVersion;

  bool get isDevelopmentFixture =>
      provenance == UrgentCabinetFeeProvenance.developmentFixture;

  bool isStructurallyValid() {
    return doctorId.trim().isNotEmpty &&
        cabinetId.trim().isNotEmpty &&
        amountMilliTnd >= 0 &&
        currencyCode == 'TND' &&
        (configurationRevision == null || configurationRevision! >= 0) &&
        (runtimeRevision == null || runtimeRevision! >= 0) &&
        (practiceLocationVersion == null || practiceLocationVersion! >= 0);
  }

  bool get hasCompleteAuthority =>
      configurationRevision != null &&
      runtimeRevision != null &&
      practiceLocationVersion != null;

  bool matchesDetail(UrgentCabinetDoctorDetail detail) {
    return doctorId == detail.doctorId &&
        amountMilliTnd == detail.urgentCabinetFeeMilliTnd &&
        configurationRevision == detail.configurationRevision &&
        runtimeRevision == detail.runtimeRevision &&
        practiceLocationVersion == detail.practiceLocationVersion;
  }

  bool isExpiredAt(DateTime instant) {
    final expiry = expiresAt;
    return expiry != null && !instant.isBefore(expiry);
  }
}

enum UrgentCabinetReviewProvenance { developmentFixture, service }

/// Immutable, display-ready snapshot for the P4 confirmation page.
@immutable
class UrgentCabinetRequestReview {
  const UrgentCabinetRequestReview._({
    required this.careSubject,
    required this.patientDisplayName,
    required this.doctorId,
    required this.doctorDisplayName,
    required this.specialty,
    required this.cabinetId,
    required this.cabinetName,
    required this.cabinetLocality,
    required this.cabinetCity,
    required this.cabinetGovernorate,
    required this.cabinetAddress,
    required this.cabinetLatitude,
    required this.cabinetLongitude,
    required this.eligibility,
    required this.availability,
    required this.feeQuote,
    required this.provenance,
  });

  /// Builds the immutable presentation projection returned by the urgent
  /// CABINET request authority. This deliberately bypasses discovery-time
  /// availability checks: after submission, the request snapshot is the
  /// authority for the selected Doctor, Cabinet and fee.
  factory UrgentCabinetRequestReview.authoritative({
    required UrgentCabinetCareSubject careSubject,
    required String patientDisplayName,
    required String doctorId,
    required String doctorDisplayName,
    required String specialty,
    required String cabinetId,
    required String cabinetName,
    required String cabinetCity,
    required String cabinetGovernorate,
    required String cabinetAddress,
    required double? cabinetLatitude,
    required double? cabinetLongitude,
    required int amountMilliTnd,
    required DateTime evaluatedAt,
    required int configurationRevision,
    required int runtimeRevision,
    required int practiceLocationVersion,
  }) {
    final patient = patientDisplayName.trim();
    if (patient.isEmpty) {
      throw ArgumentError('Patient display name is required.');
    }
    return UrgentCabinetRequestReview._(
      careSubject: careSubject,
      patientDisplayName: patient,
      doctorId: doctorId,
      doctorDisplayName: doctorDisplayName,
      specialty: specialty,
      cabinetId: cabinetId,
      cabinetName: cabinetName,
      cabinetLocality: '',
      cabinetCity: cabinetCity,
      cabinetGovernorate: cabinetGovernorate,
      cabinetAddress: cabinetAddress,
      cabinetLatitude: cabinetLatitude,
      cabinetLongitude: cabinetLongitude,
      eligibility: UrgentCabinetEligibility.eligible,
      availability: UrgentCabinetAvailability.availableNow,
      feeQuote: UrgentCabinetFeeQuote(
        doctorId: doctorId,
        cabinetId: cabinetId,
        amountMilliTnd: amountMilliTnd,
        currencyCode: 'TND',
        provenance: UrgentCabinetFeeProvenance.service,
        quotedAt: evaluatedAt,
        configurationRevision: configurationRevision,
        runtimeRevision: runtimeRevision,
        practiceLocationVersion: practiceLocationVersion,
      ),
      provenance: UrgentCabinetReviewProvenance.service,
    );
  }

  final UrgentCabinetCareSubject careSubject;
  final String patientDisplayName;
  final String doctorId;
  final String doctorDisplayName;
  final String specialty;
  final String cabinetId;
  final String cabinetName;
  final String cabinetLocality;
  final String cabinetCity;
  final String cabinetGovernorate;
  final String? cabinetAddress;
  final double? cabinetLatitude;
  final double? cabinetLongitude;
  final UrgentCabinetEligibility eligibility;
  final UrgentCabinetAvailability availability;
  final UrgentCabinetFeeQuote feeQuote;
  final UrgentCabinetReviewProvenance provenance;

  bool get isDevelopmentFixture =>
      provenance == UrgentCabinetReviewProvenance.developmentFixture;
}

enum UrgentCabinetReviewIssue {
  missingCareSubject,
  missingPatient,
  missingDoctor,
  doctorMismatch,
  missingCabinet,
  cabinetMismatch,
  doctorIneligible,
  doctorUnavailable,
  missingFee,
  feeDoctorMismatch,
  feeCabinetMismatch,
  invalidFee,
  incompleteFeeAuthority,
  expiredFee,
  provenanceMismatch,
  developmentFixtureUnavailable,
  missingClinicalIntake,
}

@immutable
class UrgentCabinetReviewValidation {
  const UrgentCabinetReviewValidation.valid(this.review) : issue = null;

  const UrgentCabinetReviewValidation.invalid(this.issue) : review = null;

  final UrgentCabinetRequestReview? review;
  final UrgentCabinetReviewIssue? issue;

  bool get isValid => review != null && issue == null;
}

UrgentCabinetReviewValidation validateUrgentCabinetRequestReview({
  required UrgentCabinetCareSubject? careSubject,
  required String? patientDisplayName,
  required String? selectedDoctorId,
  required String? selectedCabinetId,
  required UrgentCabinetDoctorDetail? doctor,
  required UrgentCabinetLocationDetail? cabinet,
  required UrgentCabinetFeeQuote? feeQuote,
  required bool developmentFixturesEnabled,
  bool clinicalIntakeReady = true,
  DateTime? now,
}) {
  if (!clinicalIntakeReady) {
    return const UrgentCabinetReviewValidation.invalid(
      UrgentCabinetReviewIssue.missingClinicalIntake,
    );
  }
  if (careSubject == null) {
    return const UrgentCabinetReviewValidation.invalid(
      UrgentCabinetReviewIssue.missingCareSubject,
    );
  }
  final normalizedPatientName = patientDisplayName?.trim();
  if (normalizedPatientName == null || normalizedPatientName.isEmpty) {
    return const UrgentCabinetReviewValidation.invalid(
      UrgentCabinetReviewIssue.missingPatient,
    );
  }
  final normalizedDoctorId = selectedDoctorId?.trim();
  if (normalizedDoctorId == null ||
      normalizedDoctorId.isEmpty ||
      doctor == null) {
    return const UrgentCabinetReviewValidation.invalid(
      UrgentCabinetReviewIssue.missingDoctor,
    );
  }
  if (doctor.doctorId != normalizedDoctorId) {
    return const UrgentCabinetReviewValidation.invalid(
      UrgentCabinetReviewIssue.doctorMismatch,
    );
  }
  final normalizedCabinetId = selectedCabinetId?.trim();
  if (normalizedCabinetId == null ||
      normalizedCabinetId.isEmpty ||
      cabinet == null) {
    return const UrgentCabinetReviewValidation.invalid(
      UrgentCabinetReviewIssue.missingCabinet,
    );
  }
  final doctorCabinet = doctor.cabinetById(normalizedCabinetId);
  if (doctorCabinet == null || cabinet.cabinetId != normalizedCabinetId) {
    return const UrgentCabinetReviewValidation.invalid(
      UrgentCabinetReviewIssue.cabinetMismatch,
    );
  }
  if (doctor.eligibility != UrgentCabinetEligibility.eligible) {
    return const UrgentCabinetReviewValidation.invalid(
      UrgentCabinetReviewIssue.doctorIneligible,
    );
  }
  if (doctor.availability != UrgentCabinetAvailability.availableNow) {
    return const UrgentCabinetReviewValidation.invalid(
      UrgentCabinetReviewIssue.doctorUnavailable,
    );
  }
  if (feeQuote == null) {
    return const UrgentCabinetReviewValidation.invalid(
      UrgentCabinetReviewIssue.missingFee,
    );
  }
  if (feeQuote.doctorId != normalizedDoctorId) {
    return const UrgentCabinetReviewValidation.invalid(
      UrgentCabinetReviewIssue.feeDoctorMismatch,
    );
  }
  if (feeQuote.cabinetId != normalizedCabinetId) {
    return const UrgentCabinetReviewValidation.invalid(
      UrgentCabinetReviewIssue.feeCabinetMismatch,
    );
  }
  if (!feeQuote.isStructurallyValid()) {
    return const UrgentCabinetReviewValidation.invalid(
      UrgentCabinetReviewIssue.invalidFee,
    );
  }
  if (feeQuote.isExpiredAt(now ?? DateTime.now())) {
    return const UrgentCabinetReviewValidation.invalid(
      UrgentCabinetReviewIssue.expiredFee,
    );
  }
  if (!feeQuote.hasCompleteAuthority) {
    return const UrgentCabinetReviewValidation.invalid(
      UrgentCabinetReviewIssue.incompleteFeeAuthority,
    );
  }

  final detailIsDevelopment = doctor.isDevelopmentFixture;
  if (detailIsDevelopment != feeQuote.isDevelopmentFixture) {
    return const UrgentCabinetReviewValidation.invalid(
      UrgentCabinetReviewIssue.provenanceMismatch,
    );
  }
  if (detailIsDevelopment && !developmentFixturesEnabled) {
    return const UrgentCabinetReviewValidation.invalid(
      UrgentCabinetReviewIssue.developmentFixtureUnavailable,
    );
  }

  return UrgentCabinetReviewValidation.valid(
    UrgentCabinetRequestReview._(
      careSubject: careSubject,
      patientDisplayName: normalizedPatientName,
      doctorId: doctor.doctorId,
      doctorDisplayName: doctor.displayName,
      specialty: doctor.specialty,
      cabinetId: doctorCabinet.cabinetId,
      cabinetName: doctorCabinet.name,
      cabinetLocality: doctorCabinet.locality,
      cabinetCity: doctorCabinet.city,
      cabinetGovernorate: doctorCabinet.governorate,
      cabinetAddress: doctorCabinet.address,
      cabinetLatitude: doctorCabinet.latitude,
      cabinetLongitude: doctorCabinet.longitude,
      eligibility: doctor.eligibility,
      availability: doctor.availability,
      feeQuote: feeQuote,
      provenance: detailIsDevelopment
          ? UrgentCabinetReviewProvenance.developmentFixture
          : UrgentCabinetReviewProvenance.service,
    ),
  );
}

String formatUrgentCabinetFee(UrgentCabinetFeeQuote quote) {
  final amount = quote.amountMilliTnd;
  final sign = amount < 0 ? '-' : '';
  final absolute = amount.abs();
  final whole = absolute ~/ 1000;
  final fraction = (absolute % 1000).toString().padLeft(3, '0');
  final groupedWhole = _groupThousands(whole.toString());
  final currency = quote.currencyCode == 'TND' ? 'DT' : quote.currencyCode;
  return '$sign$groupedWhole,$fraction $currency';
}

String _groupThousands(String digits) {
  final buffer = StringBuffer();
  for (var index = 0; index < digits.length; index++) {
    if (index > 0 && (digits.length - index) % 3 == 0) buffer.write(' ');
    buffer.write(digits[index]);
  }
  return buffer.toString();
}
