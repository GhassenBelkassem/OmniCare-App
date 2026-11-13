/// Medical reference values shown by the « Dossier médical » editor
/// (G2.1-A2, ADR-012 §8 D2). One place for every list and threshold.
///
/// REQUIRES MEDICAL VALIDATION: none of these values has been signed off by a
/// named doctor. They are shown as suggestions only and never block a save.
library;

/// Condition presets, by chip row as the editor lays them out.
/// REQUIRES MEDICAL VALIDATION.
const conditionPresetRows = <List<String>>[
  ['Diabète Type 2', 'Diabète Type 1'],
  ['Hypertension', 'Asthme'],
  ['Maladie Cardiaque'],
  ['Cholestérol Élevé', 'Arthrite', 'Migraine'],
  ['Thyroïde'],
];

/// Allergy presets (D2: « Allergie Pénicilline » moves here from the
/// conditions). The list holds only that entry until a doctor provides it.
/// REQUIRES MEDICAL VALIDATION.
const allergyPresetRows = <List<String>>[
  ['Allergie Pénicilline'],
];

/// Adult BMI categories. REQUIRES MEDICAL VALIDATION.
enum BmiCategory { underweight, normal, overweight, obese }

/// Lower bound (inclusive) of each category above [BmiCategory.underweight].
/// REQUIRES MEDICAL VALIDATION.
const bmiNormalFrom = 18.5;
const bmiOverweightFrom = 25.0;
const bmiObeseFrom = 30.0;

/// The BMI as shown (one decimal), so the category always matches the number
/// on screen. `null` without both measurements.
double? displayedBmi(double? heightCm, double? weightKg) {
  if (heightCm == null || weightKg == null || heightCm <= 0 || weightKg <= 0) {
    return null;
  }
  final meters = heightCm / 100;
  return (weightKg / (meters * meters) * 10).round() / 10;
}

/// The category of [bmi] (as returned by [displayedBmi]); `null` without one.
BmiCategory? bmiCategoryOf(double? bmi) {
  if (bmi == null) return null;
  if (bmi < bmiNormalFrom) return BmiCategory.underweight;
  if (bmi < bmiOverweightFrom) return BmiCategory.normal;
  if (bmi < bmiObeseFrom) return BmiCategory.overweight;
  return BmiCategory.obese;
}
