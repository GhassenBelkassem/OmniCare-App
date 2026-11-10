import 'package:dio/dio.dart';

import '../domain/request_vocabulary.dart';

/// How a Module 05 operation failed, expressed in terms the UI can act on.
enum RequestFailureKind {
  /// No usable connection. Always retryable with the same operation id.
  network,

  /// The call exceeded a timeout. The submission may or may not have landed —
  /// which is exactly why the operation id must be reused.
  timeout,

  /// The response could not be trusted (malformed payload).
  contract,

  /// The subject could not be resolved for this account (`403`).
  subjectForbidden,

  /// The clinic cannot receive requests right now (`422`).
  targetUnavailable,

  /// The command was rejected as structurally invalid (`400`).
  invalid,

  /// Optimistic-lock precondition failed (`409`). Re-read before acting.
  versionConflict,

  /// The lifecycle does not allow this change (`409`).
  transitionInvalid,

  /// The operation id was already used for a materially different submission,
  /// or belongs to another account (`409`). Terminal for that operation id.
  idempotencyConflict,

  /// No such request for this account (`404`).
  notFound,

  /// The authentication session is gone. Owned by the auth pipeline.
  sessionExpired,

  /// The call was superseded and cancelled locally.
  cancelled,

  /// Server-side error (`5xx`).
  server,

  /// Anything else.
  unexpected,
}

/// A safe, patient-presentable failure.
///
/// [message] is chosen from this file's constants. It never contains the
/// backend `detail`, `title`, `instance`, correlation `requestId`, a SQL or
/// framework message, or any clinic / patient / family identifier — and it is
/// never `error.toString()`.
///
/// [diagnosticCode] is our own stable constant for branching and tests. It is
/// not the backend correlation id and must never be rendered.
class RequestFailure implements Exception {
  const RequestFailure({
    required this.kind,
    required this.message,
    required this.retryable,
    required this.diagnosticCode,
  });

  final RequestFailureKind kind;
  final String message;

  /// True only when retrying **the same operation id** is safe and useful.
  ///
  /// Notably false for [RequestFailureKind.idempotencyConflict]: that id is
  /// burned, and the caller must explicitly start a new logical request.
  final bool retryable;

  final String diagnosticCode;

  /// A conflict the patient cannot resolve by pressing "try again"; the UI
  /// must re-read server state instead.
  bool get requiresRefresh =>
      kind == RequestFailureKind.versionConflict ||
      kind == RequestFailureKind.transitionInvalid;

  /// This operation identity can never succeed again.
  bool get isOperationTerminal =>
      kind == RequestFailureKind.idempotencyConflict;

  static const RequestFailure networkUnavailable = RequestFailure(
    kind: RequestFailureKind.network,
    message: 'Connection unavailable. Check your network and try again.',
    retryable: true,
    diagnosticCode: 'REQUEST_NETWORK_UNAVAILABLE',
  );

  static const RequestFailure timedOut = RequestFailure(
    kind: RequestFailureKind.timeout,
    message: 'The request is taking too long. Please try again.',
    retryable: true,
    diagnosticCode: 'REQUEST_TIMEOUT',
  );

  /// A submission that was in flight when the process died. Its outcome is
  /// genuinely unknown, which is precisely why it must be retried under the
  /// original operation id rather than resent as a new request.
  static const RequestFailure interrupted = RequestFailure(
    kind: RequestFailureKind.network,
    message: 'Your last request was interrupted. Please try again.',
    retryable: true,
    diagnosticCode: 'REQUEST_INTERRUPTED',
  );

  static const RequestFailure invalidResponse = RequestFailure(
    kind: RequestFailureKind.contract,
    message: 'Your request could not be read safely. Please try again.',
    retryable: true,
    diagnosticCode: 'REQUEST_RESPONSE_INVALID',
  );

  static const RequestFailure sessionExpired = RequestFailure(
    kind: RequestFailureKind.sessionExpired,
    message: 'Your session has expired. Please sign in again.',
    retryable: false,
    diagnosticCode: 'REQUEST_SESSION_EXPIRED',
  );

  static const RequestFailure cancelled = RequestFailure(
    kind: RequestFailureKind.cancelled,
    message: 'The request was interrupted. Please try again.',
    retryable: false,
    diagnosticCode: 'REQUEST_CANCELLED',
  );

  static const RequestFailure serverUnavailable = RequestFailure(
    kind: RequestFailureKind.server,
    message: 'Care requests are temporarily unavailable. Please try again.',
    retryable: true,
    diagnosticCode: 'REQUEST_SERVER_ERROR',
  );

  static const RequestFailure unexpected = RequestFailure(
    kind: RequestFailureKind.unexpected,
    message: 'Something went wrong. Please try again.',
    retryable: true,
    diagnosticCode: 'REQUEST_UNEXPECTED',
  );

  static const RequestFailure subjectForbidden = RequestFailure(
    kind: RequestFailureKind.subjectForbidden,
    message: 'This request cannot be sent for the selected person.',
    retryable: false,
    diagnosticCode: 'REQUEST_SUBJECT_FORBIDDEN',
  );

  static const RequestFailure targetUnavailable = RequestFailure(
    kind: RequestFailureKind.targetUnavailable,
    message: 'This clinic cannot receive requests right now.',
    retryable: false,
    diagnosticCode: 'REQUEST_TARGET_UNAVAILABLE',
  );

  static const RequestFailure invalidRequest = RequestFailure(
    kind: RequestFailureKind.invalid,
    message: 'Some of the details are not valid. Please review and try again.',
    retryable: false,
    diagnosticCode: 'REQUEST_INVALID',
  );

  static const RequestFailure versionConflict = RequestFailure(
    kind: RequestFailureKind.versionConflict,
    message: 'This request has changed. Refresh to see the latest status.',
    retryable: false,
    diagnosticCode: 'REQUEST_VERSION_CONFLICT',
  );

  static const RequestFailure transitionInvalid = RequestFailure(
    kind: RequestFailureKind.transitionInvalid,
    message: 'This change is no longer possible for this request.',
    retryable: false,
    diagnosticCode: 'REQUEST_TRANSITION_INVALID',
  );

  static const RequestFailure idempotencyConflict = RequestFailure(
    kind: RequestFailureKind.idempotencyConflict,
    message:
        'This request was already used for a different submission. '
        'Please start a new request.',
    retryable: false,
    diagnosticCode: 'REQUEST_IDEMPOTENCY_CONFLICT',
  );

  static const RequestFailure notFound = RequestFailure(
    kind: RequestFailureKind.notFound,
    message: 'This request is no longer available.',
    retryable: false,
    diagnosticCode: 'REQUEST_NOT_FOUND',
  );

  /// The local guard for a submission that is not fully described yet. Never
  /// reaches the network.
  static const RequestFailure intentIncomplete = RequestFailure(
    kind: RequestFailureKind.invalid,
    message: 'Choose a clinic before sending your request.',
    retryable: false,
    diagnosticCode: 'REQUEST_INTENT_INCOMPLETE',
  );

  static const RequestFailure recoveryIdentityUnavailable = RequestFailure(
    kind: RequestFailureKind.invalid,
    message: 'Please sign in again before sending this request.',
    retryable: false,
    diagnosticCode: 'REQUEST_ACCOUNT_SCOPE_UNAVAILABLE',
  );

  static const RequestFailure recoveryPersistenceUnavailable = RequestFailure(
    kind: RequestFailureKind.unexpected,
    message: 'This request cannot be sent safely right now. Please try again.',
    retryable: true,
    diagnosticCode: 'REQUEST_RECOVERY_PERSISTENCE_UNAVAILABLE',
  );

  /// Maps any thrown object into a safe failure.
  static RequestFailure from(Object error) {
    if (error is RequestFailure) return error;
    if (error is RequestContractException) return invalidResponse;
    if (error is FormatException) return invalidResponse;
    if (error is DioException) return _fromDio(error);
    return unexpected;
  }

  static RequestFailure _fromDio(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return timedOut;
      case DioExceptionType.connectionError:
        return networkUnavailable;
      case DioExceptionType.cancel:
        return cancelled;
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        if (error.response == null) return networkUnavailable;
      case DioExceptionType.badResponse:
        break;
    }

    final response = error.response;
    if (response == null) return networkUnavailable;

    final status = response.statusCode ?? 0;
    if (status == 401) return sessionExpired;

    // RFC 9457: only `errorCode` is read. `detail`, `title`, `instance`,
    // `type`, `timestamp` and the correlation `requestId` are ignored on
    // purpose — none of them may reach a patient-visible string.
    final mapped = _fromProblemCode(_problemErrorCode(response.data));
    if (mapped != null) return mapped;

    if (status >= 500) return serverUnavailable;
    return switch (status) {
      400 => invalidRequest,
      403 => subjectForbidden,
      404 => notFound,
      409 => versionConflict,
      422 => targetUnavailable,
      _ => unexpected,
    };
  }

  static RequestFailure? _fromProblemCode(String? errorCode) {
    return switch (errorCode) {
      'REQUEST_SUBJECT_FORBIDDEN' => subjectForbidden,
      'REQUEST_TARGET_UNAVAILABLE' => targetUnavailable,
      'REQUEST_INVALID' => invalidRequest,
      'REQUEST_VERSION_CONFLICT' => versionConflict,
      'REQUEST_TRANSITION_INVALID' => transitionInvalid,
      'REQUEST_IDEMPOTENCY_CONFLICT' => idempotencyConflict,
      'REQUEST_NOT_FOUND' => notFound,
      _ => null,
    };
  }

  static String? _problemErrorCode(Object? data) {
    if (data is! Map) return null;
    final value = data['errorCode'];
    if (value is! String) return null;
    final normalized = value.trim().toUpperCase();
    return normalized.isEmpty ? null : normalized;
  }

  /// Renders only our own kind and diagnostic constant.
  @override
  String toString() => 'RequestFailure(${kind.name}, $diagnosticCode)';
}
