class PhoneNumberFormatException implements Exception {
  final String message;

  const PhoneNumberFormatException(this.message);

  @override
  String toString() => message;
}

class TunisianPhoneNumber {
  const TunisianPhoneNumber._();

  static String normalize(String raw) {
    final compact = raw.replaceAll(RegExp(r'[\s\-.()]+'), '');
    final local = compact.startsWith('+216')
        ? compact.substring(4)
        : compact.startsWith('216')
        ? compact.substring(3)
        : compact;

    if (!RegExp(r'^\d{8}$').hasMatch(local)) {
      throw const PhoneNumberFormatException(
        'Enter exactly eight Tunisian phone digits.',
      );
    }

    return '+216$local';
  }

  static String localDigits(String raw) {
    return normalize(raw).substring(4);
  }
}
