class ApiException implements Exception {
  final String? code;
  final String message;
  final int? statusCode;
  final Map<String, String> fieldErrors;
  final Object? cause;

  const ApiException(
    this.message, {
    this.code,
    this.statusCode,
    this.fieldErrors = const {},
    this.cause,
  });

  @override
  String toString() => message;
}
