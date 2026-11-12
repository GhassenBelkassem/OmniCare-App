import '../../core/models/blood_type.dart';
import '../../providers/user_onboarding_provider.dart';

/// What the app knows about the blood type stored on the server.
sealed class StoredBloodType {
  const StoredBloodType();
}

/// The server answered. [value] is null when no blood type is stored.
final class StoredBloodTypeKnown extends StoredBloodType {
  const StoredBloodTypeKnown(this.value);

  final BloodType? value;
}

/// Not read yet, or the read failed: a value may be stored.
final class StoredBloodTypeUnavailable extends StoredBloodType {
  const StoredBloodTypeUnavailable();
}

/// The stored blood type to pre-select on onboarding resume, if any.
BloodType? bloodTypeToPreselect(StoredBloodType stored) => switch (stored) {
  StoredBloodTypeKnown(:final value) => value,
  StoredBloodTypeUnavailable() => null,
};

/// The blood type to send for the patient's [chosen] tile, or null to omit
/// it (the backend then keeps the stored value).
///
/// « Je ne sais pas » ([BloodType.unknown]) never erases a stored value: it
/// is sent only when the server confirmed nothing is stored, where it is a
/// no-op. Re-sending the stored value is also skipped.
BloodType? bloodTypeToSend({
  required BloodType? chosen,
  required StoredBloodType stored,
}) {
  if (chosen == null) return null;
  final (mayHaveStoredValue, storedValue) = switch (stored) {
    StoredBloodTypeKnown(:final value) => (value != null, value),
    StoredBloodTypeUnavailable() => (true, null),
  };
  if (chosen == BloodType.unknown) {
    return mayHaveStoredValue ? null : BloodType.unknown;
  }
  return chosen == storedValue ? null : chosen;
}

/// Body of `POST /profile/onboarding/step/1` (identity page).
///
/// Blood type, height and weight are saved by the next page through
/// `PATCH /profile/passport`, which writes the same MRS record.
Map<String, dynamic> onboardingStep1Body({
  required String firstName,
  required String lastName,
  required String dateOfBirth,
  required String gender,
}) => {
  'firstName': firstName,
  'lastName': lastName,
  'dateOfBirth': dateOfBirth,
  'gender': gender,
};

/// Body of `POST /profile/onboarding/step/2` (unchanged content).
Map<String, dynamic> onboardingStep2Body(List<AllergyEntry> allergies) => {
  if (allergies.isEmpty) 'noKnownAllergies': true,
  if (allergies.isNotEmpty)
    'allergies': allergies.map((a) => a.toJson()).toList(),
};

/// Body of `POST /profile/onboarding/step/3` (unchanged content).
Map<String, dynamic> onboardingStep3Body(List<String> conditions) {
  final named = conditions
      .map((condition) => condition.trim())
      .where((condition) => condition.isNotEmpty)
      .map((condition) => {'name': condition, 'criticalOptIn': false})
      .toList();
  return {
    if (named.isEmpty) 'noKnownConditions': true,
    if (named.isNotEmpty) 'conditions': named,
  };
}

/// Body of `POST /profile/onboarding/step/4` (unchanged content).
Map<String, dynamic> onboardingStep4Body(
  List<MedicationEntry> medications, {
  required String startDate,
}) {
  final entries = medications
      .where((m) => m.name.trim().isNotEmpty)
      .map(
        (m) => {
          'drugName': m.name.trim(),
          'dosage': m.dosage.trim().isEmpty ? null : m.dosage.trim(),
          'frequency': m.frequency.trim().isEmpty ? null : m.frequency.trim(),
          'startDate': startDate,
        },
      )
      .toList();
  return {
    if (entries.isEmpty) 'noKnownMedications': true,
    if (entries.isNotEmpty) 'medications': entries,
  };
}
