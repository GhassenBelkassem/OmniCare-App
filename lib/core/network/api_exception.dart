import 'api_failure.dart';

/// Legacy error type thrown by the older API classes.
///
/// When built from a backend response through [ApiException.fromFailure],
/// it carries the parsed [failure] and **no server text**: screens show
/// `apiFailureMessage(ApiFailure.from(error), l10n)`, never [message].
class ApiException implements Exception {
  final String? code;
  final String message;
  final int? statusCode;
  final Duration? retryAfter;
  final Map<String, String> fieldErrors;
  final Object? cause;
  final ApiFailure? failure;

  const ApiException(
    this.message, {
    this.code,
    this.statusCode,
    this.retryAfter,
    this.fieldErrors = const {},
    this.cause,
    this.failure,
  });

  /// Keeps the legacy fields readable for older callers (code, status,
  /// retry-after, field names). [message] is the safe [ApiFailure.logSummary];
  /// field values are field codes' kind names, never server sentences.
  factory ApiException.fromFailure(ApiFailure failure, {Object? cause}) =>
      ApiException(
        failure.logSummary,
        code: failure.code,
        statusCode: failure.statusCode,
        retryAfter: failure.retryAfter,
        fieldErrors: {
          for (final entry in failure.fieldErrors.entries)
            entry.key: entry.value.name,
        },
        cause: cause,
        failure: failure,
      );

  @override
  String toString() => message;
}
