import '../../l10n/omni_localizations.dart';

/// French labels for values the onboarding stores unchanged (G3-ONB2).
/// Display only: the stored / sent values stay exactly as before.

/// Label of a stored gender value (`M`, `F`, `autre`); any other value is
/// shown as it is.
String onboardingGenderLabel(String? value, OmniLocalizations l10n) =>
    switch (value) {
      'M' => l10n.onboardingGenderMale,
      'F' => l10n.onboardingGenderFemale,
      'autre' => l10n.onboardingGenderOther,
      _ => value ?? '',
    };

/// French label of one of the 14 condition constants (sent in English).
/// REQUIRES MEDICAL VALIDATION (the list and its wording).
String onboardingConditionLabel(String value, OmniLocalizations l10n) =>
    switch (value) {
      'Diabetes' => l10n.onboardingConditionDiabetes,
      'Hypertension' => l10n.onboardingConditionHypertension,
      'Asthma' => l10n.onboardingConditionAsthma,
      'Heart Disease' => l10n.onboardingConditionHeartDisease,
      'Arthritis' => l10n.onboardingConditionArthritis,
      'Thyroid Disorder' => l10n.onboardingConditionThyroid,
      'Kidney Disease' => l10n.onboardingConditionKidney,
      'Liver Disease' => l10n.onboardingConditionLiver,
      'Cancer' => l10n.onboardingConditionCancer,
      'Epilepsy' => l10n.onboardingConditionEpilepsy,
      'COPD' => l10n.onboardingConditionCopd,
      'Depression' => l10n.onboardingConditionDepression,
      'Anxiety' => l10n.onboardingConditionAnxiety,
      'Migraine' => l10n.onboardingConditionMigraine,
      _ => value,
    };

/// Lower-case, accent-free form used to match a search query against a
/// French label (« diabete » finds « Diabète »).
String onboardingSearchKey(String text) {
  const from = 'àâäáãåçéèêëíìîïñóòôöõúùûüýÿœæ';
  const to = 'aaaaaaceeeeiiiinooooouuuuyyoa';
  final buffer = StringBuffer();
  for (final rune in text.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    final index = from.indexOf(char);
    buffer.write(index < 0 ? char : to[index]);
  }
  return buffer.toString();
}
