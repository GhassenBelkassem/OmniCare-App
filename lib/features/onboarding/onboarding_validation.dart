import '../../core/network/api_failure.dart';
import '../../l10n/omni_localizations.dart';
import '../patient_passport/application/medical_data_editor_draft.dart';
import '../patient_passport/presentation/medical_record_messages.dart';

/// The onboarding page checks (G2.1-A3), in French, mirroring the server's
/// limits (SB1 §4a) so a refusal shows on the page at once. The server stays
/// the authority. Each returns the first message, or null when the page can
/// be saved.

/// Body page: both measurements are asked; height 30–300 cm, weight above 0
/// and at most 500 kg (the record's ranges).
String? onboardingMeasurementsError({
  required String rawHeight,
  required String rawWeight,
  required num? heightCm,
  required num? weightKg,
  required OmniLocalizations l10n,
}) {
  if (rawHeight.trim().isEmpty) return l10n.onboardingErrorHeight;
  if (rawWeight.trim().isEmpty) return l10n.onboardingErrorWeight;
  if (heightCm == null || heightCm < minHeightCm || heightCm > maxHeightCm) {
    return l10n.recordFieldHeightRange;
  }
  if (weightKg == null || weightKg <= 0 || weightKg > maxWeightKg) {
    return l10n.recordFieldWeightRange;
  }
  return null;
}

/// One allergy row as typed: its name and severity, and the « risque vital »
/// switch.
typedef OnboardingAllergyRow = ({
  String name,
  String severity,
  bool lifeSafety,
});

/// Allergies page. « Oui » ([answer] true) needs at least one named allergy;
/// each name follows the record's label rules; a named allergy needs its
/// severity.
String? onboardingAllergiesError({
  required bool? answer,
  required List<OnboardingAllergyRow> rows,
  required OmniLocalizations l10n,
}) {
  final names = <String>[];
  for (final row in rows) {
    final name = row.name.trim();
    if (name.isEmpty && row.lifeSafety) return l10n.onboardingErrorAllergyName;
    if (name.isNotEmpty && row.severity.trim().isEmpty) {
      return l10n.onboardingErrorAllergySeverity;
    }
    if (name.isNotEmpty) names.add(name);
  }
  if (answer == true && names.isEmpty) return l10n.onboardingErrorAllergyName;
  return _labelsError(names, l10n);
}

/// Conditions page. « Oui » needs at least one condition (otherwise the
/// answer would be saved as « none »).
String? onboardingConditionsError({
  required bool? answer,
  required List<String> conditions,
  required OmniLocalizations l10n,
}) {
  if (answer == true && conditions.isEmpty) {
    return l10n.onboardingErrorConditionRequired;
  }
  return _labelsError(conditions, l10n);
}

/// The record's label rules: at most [maxLabelLength] characters, no control
/// or direction character, no duplicate (any case), at most [maxListItems].
String? _labelsError(List<String> labels, OmniLocalizations l10n) {
  if (labels.length > maxListItems) {
    return recordFieldMessage('items', ApiFieldErrorKind.tooLong, l10n);
  }
  final seen = <String>{};
  for (final label in labels) {
    final kind = switch (label.trim()) {
      final text when text.runes.length > maxLabelLength =>
        ApiFieldErrorKind.tooLong,
      final text when hasForbiddenCharacter(text) => ApiFieldErrorKind.invalid,
      final text when !seen.add(labelKey(text)) => ApiFieldErrorKind.duplicate,
      _ => null,
    };
    if (kind != null) return recordFieldMessage('label', kind, l10n);
  }
  return null;
}
