import '../../../core/network/api_failure.dart';

/// What a failed answer means for the patient. Pure mapping, no server text.
enum PendingAnswerProblem {
  /// 409 VERSION_CONFLICT: reload silently and show the fresh state.
  versionConflict,

  /// *_NOT_PENDING, *_EXPIRED, *_NOT_FOUND / 404: « Cette demande n'est plus active. »
  notActive,

  /// 503 / 5xx: « Service momentanément indisponible. Réessayez dans un instant. »
  unavailable,

  /// No network or too slow: the app's existing offline message.
  network,

  /// Anything else: a generic French message.
  other,
}

const String notActiveMessage = 'Cette demande n’est plus active.';
const String unavailableMessage =
    'Service momentanément indisponible. Réessayez dans un instant.';
const String otherProblemMessage =
    'Votre réponse n’a pas pu être envoyée. Réessayez.';

PendingAnswerProblem pendingAnswerProblemOf(ApiFailure failure) {
  final code = failure.code ?? '';
  if (code == 'VERSION_CONFLICT') return PendingAnswerProblem.versionConflict;
  if (code.endsWith('_NOT_PENDING') ||
      code.endsWith('_EXPIRED') ||
      code.endsWith('_NOT_FOUND') ||
      failure.kind == ApiFailureKind.notFound) {
    return PendingAnswerProblem.notActive;
  }
  if (code == 'MRS_UNAVAILABLE' ||
      failure.statusCode == 503 ||
      failure.kind == ApiFailureKind.server) {
    return PendingAnswerProblem.unavailable;
  }
  if (failure.kind == ApiFailureKind.network ||
      failure.kind == ApiFailureKind.timeout) {
    return PendingAnswerProblem.network;
  }
  return PendingAnswerProblem.other;
}

/// The command may or may not have reached the server: the retry must send
/// the same Idempotency-Key.
bool isAmbiguousFailure(ApiFailure failure) =>
    failure.kind == ApiFailureKind.network ||
    failure.kind == ApiFailureKind.timeout ||
    failure.kind == ApiFailureKind.server ||
    (failure.kind == ApiFailureKind.unknown && failure.statusCode == null);
