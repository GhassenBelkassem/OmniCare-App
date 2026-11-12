import 'package:dio/dio.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/network/api_failure_message.dart';
import '../../../l10n/omni_localizations.dart';
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
/// Its text comes from [message] (French, `app_fr.arb`). It never contains
/// the backend `detail`, `title`, `instance`, correlation `requestId`, a SQL
/// or framework message, or any clinic / patient / family identifier — and it
/// is never `error.toString()`.
///
/// [diagnosticCode] is our own stable constant for branching and tests. It is
/// not the backend correlation id and must never be rendered.
class RequestFailure implements Exception {
  const RequestFailure({
    required this.kind,
    required this.retryable,
    required this.diagnosticCode,
    this.api,
  });

  final RequestFailureKind kind;

  /// The parsed backend failure, when there was one (code, status, fields,
  /// request id). Never holds server text.
  final ApiFailure? api;

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
    retryable: true,
    diagnosticCode: 'REQUEST_NETWORK_UNAVAILABLE',
  );

  static const RequestFailure timedOut = RequestFailure(
    kind: RequestFailureKind.timeout,
    retryable: true,
    diagnosticCode: 'REQUEST_TIMEOUT',
  );

  /// A submission that was in flight when the process died. Its outcome is
  /// genuinely unknown, which is precisely why it must be retried under the
  /// original operation id rather than resent as a new request.
  static const RequestFailure interrupted = RequestFailure(
    kind: RequestFailureKind.network,
    retryable: true,
    diagnosticCode: 'REQUEST_INTERRUPTED',
  );

  static const RequestFailure invalidResponse = RequestFailure(
    kind: RequestFailureKind.contract,
    retryable: true,
    diagnosticCode: 'REQUEST_RESPONSE_INVALID',
  );

  static const RequestFailure sessionExpired = RequestFailure(
    kind: RequestFailureKind.sessionExpired,
    retryable: false,
    diagnosticCode: 'REQUEST_SESSION_EXPIRED',
  );

  static const RequestFailure cancelled = RequestFailure(
    kind: RequestFailureKind.cancelled,
    retryable: false,
    diagnosticCode: 'REQUEST_CANCELLED',
  );

  static const RequestFailure serverUnavailable = RequestFailure(
    kind: RequestFailureKind.server,
    retryable: true,
    diagnosticCode: 'REQUEST_SERVER_ERROR',
  );

  static const RequestFailure unexpected = RequestFailure(
    kind: RequestFailureKind.unexpected,
    retryable: true,
    diagnosticCode: 'REQUEST_UNEXPECTED',
  );

  static const RequestFailure subjectForbidden = RequestFailure(
    kind: RequestFailureKind.subjectForbidden,
    retryable: false,
    diagnosticCode: 'REQUEST_SUBJECT_FORBIDDEN',
  );

  static const RequestFailure targetUnavailable = RequestFailure(
    kind: RequestFailureKind.targetUnavailable,
    retryable: false,
    diagnosticCode: 'REQUEST_TARGET_UNAVAILABLE',
  );

  static const RequestFailure invalidRequest = RequestFailure(
    kind: RequestFailureKind.invalid,
    retryable: false,
    diagnosticCode: 'REQUEST_INVALID',
  );

  static const RequestFailure versionConflict = RequestFailure(
    kind: RequestFailureKind.versionConflict,
    retryable: false,
    diagnosticCode: 'REQUEST_VERSION_CONFLICT',
  );

  static const RequestFailure transitionInvalid = RequestFailure(
    kind: RequestFailureKind.transitionInvalid,
    retryable: false,
    diagnosticCode: 'REQUEST_TRANSITION_INVALID',
  );

  static const RequestFailure idempotencyConflict = RequestFailure(
    kind: RequestFailureKind.idempotencyConflict,
    retryable: false,
    diagnosticCode: 'REQUEST_IDEMPOTENCY_CONFLICT',
  );

  static const RequestFailure notFound = RequestFailure(
    kind: RequestFailureKind.notFound,
    retryable: false,
    diagnosticCode: 'REQUEST_NOT_FOUND',
  );

  /// The local guard for a submission that is not fully described yet. Never
  /// reaches the network.
  static const RequestFailure intentIncomplete = RequestFailure(
    kind: RequestFailureKind.invalid,
    retryable: false,
    diagnosticCode: 'REQUEST_INTENT_INCOMPLETE',
  );

  static const RequestFailure recoveryIdentityUnavailable = RequestFailure(
    kind: RequestFailureKind.invalid,
    retryable: false,
    diagnosticCode: 'REQUEST_ACCOUNT_SCOPE_UNAVAILABLE',
  );

  static const RequestFailure recoveryPersistenceUnavailable = RequestFailure(
    kind: RequestFailureKind.unexpected,
    retryable: true,
    diagnosticCode: 'REQUEST_RECOVERY_PERSISTENCE_UNAVAILABLE',
  );

  /// Maps any thrown object into a safe failure. Backend errors are read
  /// once, by [ApiFailure.fromDio]; this only gives them request meaning.
  static RequestFailure from(Object error) {
    if (error is RequestFailure) return error;
    if (error is RequestContractException) return invalidResponse;
    if (error is FormatException) return invalidResponse;
    if (error is DioException) return _fromDio(error);
    return unexpected;
  }

  static RequestFailure _fromDio(DioException error) {
    if (error.type == DioExceptionType.cancel) return cancelled;
    final api = ApiFailure.fromDio(error);
    switch (api.kind) {
      case ApiFailureKind.timeout when api.statusCode == null:
        return timedOut;
      case ApiFailureKind.network:
        return networkUnavailable;
      default:
        break;
    }
    final status = api.statusCode ?? 0;
    if (status == 401) return sessionExpired._with(api);

    final mapped = _fromProblemCode(api.code?.toUpperCase());
    if (mapped != null) return mapped._with(api);

    if (status >= 500) return serverUnavailable._with(api);
    final byStatus = switch (status) {
      400 => invalidRequest,
      403 => subjectForbidden,
      404 => notFound,
      409 => versionConflict,
      422 => targetUnavailable,
      _ => unexpected,
    };
    return byStatus._with(api);
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

  RequestFailure _with(ApiFailure api) => RequestFailure(
    kind: kind,
    retryable: retryable,
    diagnosticCode: diagnosticCode,
    api: api,
  );

  /// The French text for this failure. A failure with no request meaning
  /// gets the generic text of its backend kind (for example « Trop de
  /// tentatives… » on a 429).
  String message(OmniLocalizations l10n) => switch (diagnosticCode) {
    'REQUEST_NETWORK_UNAVAILABLE' => l10n.apiErrorNetwork,
    'REQUEST_TIMEOUT' => l10n.apiErrorTimeout,
    'REQUEST_INTERRUPTED' => l10n.requestInterrupted,
    'REQUEST_RESPONSE_INVALID' => l10n.requestResponseInvalid,
    'REQUEST_SESSION_EXPIRED' => l10n.apiErrorUnauthorized,
    'REQUEST_CANCELLED' => l10n.requestCancelled,
    'REQUEST_SERVER_ERROR' => l10n.requestServerUnavailable,
    'REQUEST_SUBJECT_FORBIDDEN' => l10n.requestSubjectForbidden,
    'REQUEST_TARGET_UNAVAILABLE' => l10n.requestTargetUnavailable,
    'REQUEST_INVALID' => l10n.requestInvalid,
    'REQUEST_VERSION_CONFLICT' => l10n.requestVersionConflict,
    'REQUEST_TRANSITION_INVALID' => l10n.requestTransitionInvalid,
    'REQUEST_IDEMPOTENCY_CONFLICT' => l10n.requestIdempotencyConflict,
    'REQUEST_NOT_FOUND' => l10n.requestNotFound,
    'REQUEST_INTENT_INCOMPLETE' => l10n.requestIntentIncomplete,
    'REQUEST_ACCOUNT_SCOPE_UNAVAILABLE' => l10n.requestSignInAgain,
    'REQUEST_RECOVERY_PERSISTENCE_UNAVAILABLE' => l10n.requestCannotSendSafely,
    _ => api == null ? l10n.apiErrorUnknown : apiFailureMessage(api!, l10n),
  };

  /// Renders only our own kind and diagnostic constant.
  @override
  String toString() => 'RequestFailure(${kind.name}, $diagnosticCode)';
}
