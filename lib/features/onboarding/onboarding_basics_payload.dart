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

/// The record's value for [bloodType] (`PUT …/life-safety/blood-type`):
/// « Je ne sais pas » is `UNKNOWN`, a group is its wire value.
String recordBloodTypeValue(BloodType bloodType) =>
    bloodType == BloodType.unknown ? 'UNKNOWN' : bloodType.wireValue;

/// Body of `POST /profile/onboarding/step/1` (identity page).
///
/// Blood type, height and weight are saved by the next page through the
/// record's section saves (G2.1-A3, the same path as the record editor).
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

/// Body of `POST /profile/onboarding/step/2`: the allergies as typed, or
/// « Non » → none. « Oui » with no allergy is refused before this (the page
/// shows a message), so an empty list always means « Non ».
Map<String, dynamic> onboardingStep2Body(List<AllergyEntry> allergies) => {
  if (allergies.isEmpty) 'noKnownAllergies': true,
  if (allergies.isNotEmpty)
    'allergies': allergies.map((a) => a.toJson()).toList(),
};

/// Body of `POST /profile/onboarding/step/3`: the condition names as the
/// patient chose them (French labels, G2.1-A3), or « Non » → none. Never
/// critical (ADR-012 D6): the server stores them as not critical.
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

/// Body of `POST /profile/onboarding/step/4`, which completes onboarding.
/// The page has no medication fields (V1, CTO 2026-11-13):
/// - « Non » → `noKnownMedications` (« Aucun »);
/// - « Oui » (or no answer) → an empty body: nothing is written, so the list
///   stays « Non renseigné » and never reads as a false « Aucun ». The
///   patient adds medications in « Dossier médical ».
/// Nothing is invented: no frequency and no start date (G2.1-A3).
Map<String, dynamic> onboardingStep4Body(bool? takesMedications) =>
    takesMedications == false
    ? const {'noKnownMedications': true}
    : const <String, dynamic>{};
