import '../patient_passport/application/medical_data_editor_draft.dart';
import '../patient_passport/application/medical_reference_values.dart';
import '../patient_passport/data/medical_record_models.dart';

/// How « Modifier Mes Données Médicales » (Ma Santé and the family-member
/// screen) maps to the record's section saves (G2.1-A3). Pure functions;
/// the save rules themselves are the record editor's ([planSections]).

/// The record keeps a number of takes per day (1–6); this screen has a free
/// « Fréquence » text (« Ex: 2x/jour »).
/// - empty → `null` (not given);
/// - a number of takes per day (« 2 », « 2x/jour », « 2× par jour »,
///   « 2 fois par jour ») → that number;
/// - anything else → 0, which the shared checks refuse with
///   « Entre 1 et 6 prises par jour. » (nothing is guessed).
int? timesPerDayOfText(String text) {
  final trimmed = text.trim().toLowerCase();
  if (trimmed.isEmpty) return null;
  final match = _frequency.firstMatch(trimmed);
  return match == null ? 0 : int.parse(match.group(1)!);
}

final _frequency = RegExp(
  r'^(\d{1,2})\s*(?:x|×|fois)?\s*(?:(?:/|par)\s*(?:j|jour|jours))?\.?$',
);

/// The « Fréquence » text of a stored number of takes per day.
String frequencyTextOf(int? timesPerDay) =>
    timesPerDay == null ? '' : '${timesPerDay}x/jour';

/// The condition chips of this screen: the presets (one constants file,
/// shared with the record editor), then the patient's own conditions that
/// are not presets, then the professional ones that are not presets. A label
/// appears once (labels match without case).
List<String> conditionChipLabels(List<RecordItem> conditions) {
  final presets = [for (final row in conditionPresetRows) ...row];
  final seen = presets.map(labelKey).toSet();
  return [
    ...presets,
    for (final item in conditions)
      if (item.author.isEditableByPatient && seen.add(labelKey(item.label)))
        item.label,
    for (final item in conditions)
      if (!item.author.isEditableByPatient && seen.add(labelKey(item.label)))
        item.label,
  ];
}

/// The labels a professional recorded: shown as chosen, never editable.
Set<String> professionalLabelKeys(List<RecordItem> items) => {
  for (final item in items)
    if (!item.author.isEditableByPatient) labelKey(item.label),
};

/// The draft this screen saves: what it edits (blood type, conditions,
/// medications), and the record's own values for what it has no field for
/// (height, weight, allergies), so those sections are never sent.
/// [bloodType]: `null` for « - » (nothing chosen).
EditorDraft editMedicalDataDraft({
  required EditorBaseline baseline,
  required String? bloodType,
  required List<String> conditions,
  required List<MedicationInput> medications,
}) {
  final untouched = EditorDraft.of(baseline);
  return EditorDraft(
    bloodType: bloodType,
    heightText: untouched.heightText,
    weightText: untouched.weightText,
    allergyLabels: untouched.allergyLabels,
    conditionLabels: List.unmodifiable(conditions),
    medications: List.unmodifiable(medications),
  );
}
