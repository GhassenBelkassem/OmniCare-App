/// ABO/Rh blood type, as accepted by the backend medical record
/// (`MrsMedicalDataService.ALLOWED_BLOOD_TYPES` plus `unknown`).
///
/// "Not provided" is not a value of this type: it is the absence of a
/// [BloodType] (`null`), and it is never sent to the server. On the backend,
/// an absent field keeps the stored value, while [unknown] clears it.
enum BloodType {
  aPositive('A+'),
  aNegative('A-'),
  bPositive('B+'),
  bNegative('B-'),
  abPositive('AB+'),
  abNegative('AB-'),
  oPositive('O+'),
  oNegative('O-'),
  unknown('unknown');

  const BloodType(this.wireValue);

  /// The exact value the backend accepts in `bloodType`.
  final String wireValue;

  static const String _legacyNotProvided = '-';

  /// The label for a known type is its wire value (« A+ »…); [unknown] has
  /// a French label (`BloodTypeLabel.label` in `core/l10n`).
  bool get isKnown => this != BloodType.unknown;

  /// Parses a server (or locally stored wire) value.
  ///
  /// Returns `null` for a missing, blank or legacy "-" value (not provided).
  /// Any other value the app does not recognise maps to [unknown], never to
  /// an error.
  static BloodType? fromWire(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty || value == _legacyNotProvided) {
      return null;
    }
    final normalized = value.toUpperCase();
    for (final type in values) {
      if (type.wireValue.toUpperCase() == normalized) return type;
    }
    return BloodType.unknown;
  }
}
