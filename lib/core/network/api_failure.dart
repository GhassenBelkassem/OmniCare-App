import 'dart:convert';

import 'package:dio/dio.dart';

import 'api_exception.dart';
import 'transport_failure.dart';

/// What went wrong, as far as a patient screen needs to know.
enum ApiFailureKind {
  network,
  timeout,
  unauthorized,
  forbidden,
  notFound,
  conflict,
  validation,
  rateLimited,
  server,

  /// The app has no real data source for this feature yet (G-2 1b-3): it
  /// was mock-backed and is cut off until its phase wires it. Never sent by
  /// the backend.
  featureUnavailable,
  unknown,
}

/// Why the server rejected one field. Read from a field code, never from the
/// server's sentence.
enum ApiFieldErrorKind {
  required,
  tooLong,
  tooShort,
  invalidLength,
  invalidFormat,
  outOfRange,
  invalid,

  /// The same value twice in one list (G2.1-SB1 `DUPLICATE`).
  duplicate,
}

/// A failed backend call, parsed once from any of the five backend error
/// shapes (G-2 P0 §f.1):
///
/// 1. `ErrorResponse {code, message, timestamp, fieldErrors, requestId?,
///    fieldErrorCodes?}`;
/// 2. the session-limit map `{code, message, timestamp, activeSessions}`;
/// 3. RFC 9457 ProblemDetail with an `errorCode` property;
/// 4. ProblemDetail with a `code` property;
/// 5. the security problem map `{type, title, status, detail, instance,
///    code, requestId, timestamp}`.
///
/// It keeps **no server text**: `message`, `detail` and `title` are never
/// read, so they cannot reach a screen or a log.
class ApiFailure implements Exception {
  const ApiFailure({
    required this.kind,
    this.code,
    this.statusCode,
    this.fieldErrors = const {},
    this.requestId,
    this.retryAfter,
  });

  final ApiFailureKind kind;

  /// Backend error code (`errorCode ?? code`), when the body had one.
  final String? code;
  final int? statusCode;

  /// Field path → why it was rejected.
  final Map<String, ApiFieldErrorKind> fieldErrors;
  final String? requestId;
  final Duration? retryAfter;

  /// A feature that has no real data source yet (formerly mock-backed).
  /// Screens show their existing error / « indisponible » state for it.
  static const featureUnavailable = ApiFailure(
    kind: ApiFailureKind.featureUnavailable,
    code: featureUnavailableCode,
  );

  /// Local code of [featureUnavailable]; not a backend code.
  static const featureUnavailableCode = 'FEATURE_UNAVAILABLE';

  bool get isFeatureUnavailable => kind == ApiFailureKind.featureUnavailable;

  /// Any error a backend call can raise → a failure. Never throws.
  static ApiFailure from(Object? error) {
    try {
      return switch (error) {
        final ApiFailure failure => failure,
        final DioException dio => fromDio(dio),
        final ApiException legacy => _fromLegacy(legacy),
        final TransportFailure transport => _fromTransport(transport),
        _ => const ApiFailure(kind: ApiFailureKind.unknown),
      };
    } catch (_) {
      return const ApiFailure(kind: ApiFailureKind.unknown);
    }
  }

  /// A Dio error: transport problems by type, HTTP errors by body + status.
  static ApiFailure fromDio(DioException error) {
    final response = error.response;
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout => const ApiFailure(
        kind: ApiFailureKind.timeout,
      ),
      DioExceptionType.connectionError || DioExceptionType.badCertificate =>
        const ApiFailure(kind: ApiFailureKind.network),
      DioExceptionType.cancel => const ApiFailure(kind: ApiFailureKind.unknown),
      DioExceptionType.badResponse || DioExceptionType.unknown =>
        response == null
            ? const ApiFailure(kind: ApiFailureKind.network)
            : fromResponse(
                statusCode: response.statusCode,
                body: response.data,
                retryAfterHeader: response.headers.value('retry-after'),
              ),
    };
  }

  /// An HTTP error response. An unreadable body (HTML, text, empty, wrong
  /// JSON) gives the kind of the status and no code. Never throws.
  static ApiFailure fromResponse({
    required int? statusCode,
    required Object? body,
    String? retryAfterHeader,
  }) {
    final json = _asJsonObject(body);
    final code = _code(json);
    final fieldErrors = _fieldErrors(json);
    return ApiFailure(
      kind: _kindOf(statusCode),
      code: code,
      statusCode: statusCode,
      fieldErrors: fieldErrors,
      requestId: _string(json?['requestId']),
      retryAfter: _retryAfter(retryAfterHeader),
    );
  }

  /// What may be logged: no body, no name, no medical content.
  String get logSummary =>
      'kind=${kind.name} status=${statusCode ?? '-'} code=${code ?? '-'} '
      'requestId=${requestId ?? '-'}';

  @override
  String toString() => 'ApiFailure($logSummary)';
}

/// The status decides the kind; the code only refines the message.
ApiFailureKind _kindOf(int? status) {
  if (status == null) return ApiFailureKind.unknown;
  return switch (status) {
    400 || 422 => ApiFailureKind.validation,
    401 => ApiFailureKind.unauthorized,
    403 => ApiFailureKind.forbidden,
    404 || 410 => ApiFailureKind.notFound,
    408 => ApiFailureKind.timeout,
    409 || 412 => ApiFailureKind.conflict,
    429 => ApiFailureKind.rateLimited,
    >= 500 && < 600 => ApiFailureKind.server,
    _ => ApiFailureKind.unknown,
  };
}

Map<String, dynamic>? _asJsonObject(Object? body) {
  if (body is Map) {
    final result = <String, dynamic>{};
    body.forEach((key, value) => result[key.toString()] = value);
    return result;
  }
  if (body is String) {
    final text = body.trim();
    if (!text.startsWith('{')) return null;
    try {
      final decoded = jsonDecode(text);
      return decoded is Map ? _asJsonObject(decoded) : null;
    } on FormatException {
      return null;
    }
  }
  return null;
}

/// The backend error code of a response body (`errorCode ?? code`), for
/// code-only decisions such as the session refresh. Never throws.
String? apiErrorCodeOf(Object? body) => _code(_asJsonObject(body));

/// `errorCode` (shape 3) wins over `code` (shapes 1, 2, 4, 5).
String? _code(Map<String, dynamic>? json) =>
    _string(json?['errorCode']) ?? _string(json?['code']);

String? _string(Object? value) {
  if (value is! String) return null;
  final text = value.trim();
  return text.isEmpty ? null : text;
}

/// Field paths from `fieldErrors` (path → server sentence, ignored) and
/// their kinds from `fieldErrorCodes` (path → stable code) when present.
/// A ProblemDetail may carry the same two maps as properties.
Map<String, ApiFieldErrorKind> _fieldErrors(Map<String, dynamic>? json) {
  if (json == null) return const {};
  final fields = <String, ApiFieldErrorKind>{};
  final sentences = json['fieldErrors'];
  if (sentences is Map) {
    for (final key in sentences.keys) {
      fields[key.toString()] = ApiFieldErrorKind.invalid;
    }
  }
  final codes = json['fieldErrorCodes'];
  if (codes is Map) {
    codes.forEach((key, value) {
      fields[key.toString()] = fieldErrorKindOf(_string(value));
    });
  }
  return Map.unmodifiable(fields);
}

/// Bean Validation constraint names (`NotBlank`, `Size`…) and the stable
/// upper-case codes (`REQUIRED`, `TOO_LONG`…) → kind.
ApiFieldErrorKind fieldErrorKindOf(String? code) =>
    switch (code?.toUpperCase().replaceAll('_', '')) {
      'NOTBLANK' ||
      'NOTNULL' ||
      'NOTEMPTY' ||
      'REQUIRED' ||
      'MISSING' => ApiFieldErrorKind.required,
      'TOOLONG' || 'MAXLENGTH' => ApiFieldErrorKind.tooLong,
      'TOOSHORT' || 'MINLENGTH' => ApiFieldErrorKind.tooShort,
      'SIZE' || 'LENGTH' => ApiFieldErrorKind.invalidLength,
      'PATTERN' ||
      'EMAIL' ||
      'INVALIDFORMAT' ||
      'FORMAT' => ApiFieldErrorKind.invalidFormat,
      'MIN' ||
      'MAX' ||
      'DECIMALMIN' ||
      'DECIMALMAX' ||
      'POSITIVE' ||
      'POSITIVEORZERO' ||
      'NEGATIVE' ||
      'NEGATIVEORZERO' ||
      'PAST' ||
      'PASTORPRESENT' ||
      'FUTURE' ||
      'FUTUREORPRESENT' ||
      'RANGE' ||
      'OUTOFRANGE' => ApiFieldErrorKind.outOfRange,
      'DUPLICATE' => ApiFieldErrorKind.duplicate,
      _ => ApiFieldErrorKind.invalid,
    };

Duration? _retryAfter(String? header) {
  final seconds = int.tryParse(header?.trim() ?? '');
  if (seconds == null || seconds < 0) return null;
  return Duration(seconds: seconds);
}

/// Legacy [ApiException]: its own failure if it has one, else what its code
/// and status say. Its message is never read.
ApiFailure _fromLegacy(ApiException error) {
  final attached = error.failure;
  if (attached != null) return attached;
  final status = error.statusCode;
  final fields = {
    for (final key in error.fieldErrors.keys) key: ApiFieldErrorKind.invalid,
  };
  final kind = switch (error.code) {
    'NETWORK_REQUEST_FAILED' when status == null => ApiFailureKind.network,
    _ when status == null => ApiFailureKind.unknown,
    _ => _kindOf(status),
  };
  return ApiFailure(
    kind: kind,
    code: error.code,
    statusCode: status,
    fieldErrors: Map.unmodifiable(fields),
    retryAfter: error.retryAfter,
  );
}

ApiFailure _fromTransport(TransportFailure error) => ApiFailure(
  kind: switch (error.kind) {
    TransportFailureKind.timeout => ApiFailureKind.timeout,
    TransportFailureKind.noConnection ||
    TransportFailureKind.dns ||
    TransportFailureKind.tls => ApiFailureKind.network,
    TransportFailureKind.rateLimited => ApiFailureKind.rateLimited,
    TransportFailureKind.serverUnavailable => ApiFailureKind.server,
    TransportFailureKind.unauthorized => ApiFailureKind.unauthorized,
    TransportFailureKind.forbidden => ApiFailureKind.forbidden,
    TransportFailureKind.conflict => ApiFailureKind.conflict,
    TransportFailureKind.notFound => ApiFailureKind.notFound,
    TransportFailureKind.cancelled ||
    TransportFailureKind.invalidResponse ||
    TransportFailureKind.unknown => ApiFailureKind.unknown,
  },
  code: error.problemCode,
  statusCode: error.statusCode,
  retryAfter: error.retryAfter,
);
