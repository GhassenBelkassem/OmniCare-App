import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/network/api_failure_message.dart';
import '../../../l10n/omni_localizations.dart';
import '../application/medical_documents_view_model.dart';
import '../application/medical_record_view_model.dart';
import '../data/medical_record_models.dart';
import '../models/patient_passport_view_models.dart';
import 'widgets/passport_card_status.dart';

/// Pure mapping from the record to the texts the existing cards show
/// (G2-FT-3). Every missing value has an honest French text; nothing falls
/// back to a number or an empty list.

/// Africa/Tunis is UTC+01:00 all year (no daylight saving), the same rule as
/// the booking screens' `schedulingWallClock`.
const Duration _tunisOffset = Duration(hours: 1);

/// V1 is French only (roadmap G-2 §4.1 Q10); dates follow the ARB template.
const String _dateLocale = 'fr';

DateTime tunisWallClock(DateTime instant) => instant.toUtc().add(_tunisOffset);

String bloodTypeText(MedicalDataRecord record, OmniLocalizations l10n) =>
    record.bloodType ?? l10n.medicalRecordNotRecorded;

String allergiesText(MedicalDataRecord record, OmniLocalizations l10n) =>
    switch (record.allergiesStatus) {
      RecordListStatus.unknown => l10n.medicalRecordNotRecorded,
      RecordListStatus.noneKnown => l10n.passportAllergiesNoneKnown,
      RecordListStatus.list =>
        record.allergies.isEmpty
            ? l10n.medicalRecordNotRecorded
            : record.allergies.join(', '),
    };

/// The text shown in place of the condition chips, or null to show the
/// chips ([conditionChips]).
String? conditionsText(MedicalDataRecord record, OmniLocalizations l10n) =>
    switch (record.conditionsStatus) {
      RecordListStatus.unknown => l10n.medicalRecordNotRecorded,
      RecordListStatus.noneKnown => l10n.passportConditionsNoneKnown,
      RecordListStatus.list =>
        record.conditions.isEmpty ? l10n.medicalRecordNotRecorded : null,
    };

List<String> conditionChips(MedicalDataRecord record) =>
    record.conditionsStatus == RecordListStatus.list
    ? record.conditions
    : const [];

/// The text of an empty treatments tab. A current list never recorded
/// (`listStatus` UNKNOWN: no answer, or onboarding « Oui » with nothing
/// added, G2.1-A3b) reads « Non renseigné », never « Aucun traitement ».
String medicationsEmptyText({
  required bool current,
  required OmniLocalizations l10n,
  RecordListStatus? listStatus,
}) => current
    ? (listStatus == RecordListStatus.unknown
          ? l10n.medicalRecordNotRecorded
          : l10n.passportNoCurrentMedications)
    : l10n.passportNoPastMedications;

PassportMedication passportMedication(
  MedicationRecord medication, {
  required bool current,
  required OmniLocalizations l10n,
}) {
  final timesPerDay = medication.timesPerDay;
  return PassportMedication(
    name: medication.name ?? l10n.medicalRecordNotRecorded,
    dosage:
        medication.strength ??
        medication.dosageText ??
        _doseText(medication) ??
        '',
    frequency:
        medication.frequencyText ??
        (timesPerDay == null ? '' : l10n.passportTimesPerDay(timesPerDay)),
    isCurrent: current,
    declaredLabel: medication.source == MedicationSource.patientDeclared
        ? l10n.passportDeclaredByPatient
        : null,
  );
}

PassportConsultation passportConsultation(
  ConsultationRecord consultation,
  OmniLocalizations l10n,
) {
  final notRecorded = l10n.medicalRecordNotRecorded;
  final doctor = [
    consultation.doctorFirstName,
    consultation.doctorLastName,
  ].whereType<String>().join(' ');
  final specialty = consultation.specialty ?? notRecorded;
  return PassportConsultation(
    consultationId: consultation.id,
    date: DateFormat(
      'd MMM y',
      _dateLocale,
    ).format(tunisWallClock(consultation.completedAt)),
    doctor: doctor.isEmpty ? notRecorded : l10n.passportDoctorName(doctor),
    doctorType: specialty,
    // Free text entered by the professional (no code set exists, G2-FT-3).
    specialty: specialty,
    reason: consultation.reason ?? notRecorded,
    diagnosis: '',
    status: PassportConsultationStatus.completed,
    isShareable: consultation.isShareable,
    sharingVersion: consultation.sharingVersion,
  );
}

/// The French text of a failed card: the failure's own message when it says
/// more (no network, service down, MRS_UNAVAILABLE), else the card fallback.
String sectionFailureMessage(ApiFailure failure, OmniLocalizations l10n) =>
    apiFailureMessage(failure, l10n, fallback: l10n.passportSectionLoadFailed);

/// What a card shows for [state]: loading (also before the first request),
/// the failure with a retry of this card, or null to show the content.
PassportCardStatus? cardStatus<T>(
  SectionState<T> state,
  OmniLocalizations l10n,
  VoidCallback onRetry,
) => switch (state) {
  SectionIdle() || SectionLoading() => const PassportCardLoading(),
  SectionFailed(:final failure) => PassportCardFailed(
    message: sectionFailureMessage(failure, l10n),
    onRetry: onRetry,
  ),
  SectionReady() => null,
};

String? _doseText(MedicationRecord medication) {
  final amount = medication.doseAmount;
  final unit = medication.doseUnit;
  if (amount == null) return null;
  final number = amount == amount.roundToDouble()
      ? amount.toInt().toString()
      : amount.toString();
  return unit == null ? number : '$number $unit';
}

/// « N documents enregistrés », only when true (G2.1-A4): the server gives no
/// total, so with a next page it reads « 20+ »; before the list is read it
/// is empty (never « 0 » by default).
String documentsCountText(DocumentsCount? count, OmniLocalizations l10n) =>
    switch (count) {
      null => '',
      (loaded: final n, more: true) => l10n.passportDocumentsCountMore(n),
      (loaded: final n, more: false) => l10n.passportDocumentsCount(n),
    };
