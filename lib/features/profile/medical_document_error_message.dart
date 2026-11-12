import '../../core/network/api_exception.dart';
import '../../core/network/api_failure.dart';
import '../../core/network/api_failure_message.dart';
import '../../l10n/omni_localizations.dart';

/// The French text for a failed document operation (list, upload, recovery,
/// status stream, delete). Chosen from the error code — the app's own local
/// codes first, then the backend's — and never from an error's text.
String documentErrorMessage(Object error, OmniLocalizations l10n) {
  final failure = ApiFailure.from(error);
  // A local code (session refresh, local cancel…) replaces the server's code
  // on the exception itself, so read it there first.
  final code = error is ApiException ? error.code : failure.code;
  return switch (code) {
    'PROFILE_NOT_READY' => l10n.documentProfileNotReady,
    'OPERATION_IN_PROGRESS' => l10n.documentOperationInProgress,
    'EMPTY_FILE' => l10n.documentFileEmpty,
    'FILE_TOO_LARGE' => l10n.documentFileTooLarge,
    'FILE_SOURCE_INVALID' || 'FILE_READ_FAILED' => l10n.documentFileUnreadable,
    'FILE_SIZE_MISMATCH' => l10n.documentFileChanged,
    'UNSUPPORTED_FILE_TYPE' => l10n.documentFileTypeUnsupported,
    'UPLOAD_OWNER_CHANGED' => l10n.documentAccountChanged,
    'UPLOAD_OWNER_UNAVAILABLE' ||
    'UPLOAD_RECOVERY_IDENTITY_INVALID' => l10n.documentOwnerUnavailable,
    'UPLOAD_RECEIPT_STORAGE_FAILED' => l10n.documentUploadNotStarted,
    'DOCUMENT_UPLOAD_RECOVERY_NOT_FOUND' ||
    'DOCUMENT_UPLOAD_RECOVERY_EXPIRED' => l10n.documentRecoveryGone,
    'DOCUMENT_UPLOAD_FAILED' => l10n.documentUploadFailed,
    'UPLOAD_RECOVERY_REQUIRED' => l10n.documentRecoveryRequired,
    'DOCUMENT_UPLOAD_COMMAND_IN_PROGRESS' => l10n.documentUploadInProgress,
    'DOCUMENT_UPLOAD_IDEMPOTENCY_CONFLICT' ||
    'IDEMPOTENCY_KEY_REUSED' ||
    'CONFLICT' => l10n.documentConflict,
    'UPLOAD_CANCELLED_LOCAL' => l10n.documentTransferStopped,
    'AUTH_REFRESH_TEMPORARILY_UNAVAILABLE' => l10n.documentSessionRefreshFailed,
    'AUTH_REPLAY_REQUIRED' => l10n.documentRetryAfterRefresh,
    'MRS_UNAVAILABLE' ||
    'OBJECT_STORAGE_UNAVAILABLE' => l10n.documentProcessingUnavailable,
    'INVALID_INPUT' || 'VALIDATION_ERROR' => l10n.documentNotAccepted,
    'MALFORMED_RESPONSE' => l10n.documentResponseInvalid,
    'SSE_CONNECTION_LOST' => l10n.documentStatusInterrupted,
    'UNAUTHORIZED' ||
    'AUTH_SESSION_EXPIRED' ||
    'AUTH_SESSION_INVALID' => l10n.apiErrorUnauthorized,
    'FORBIDDEN' => l10n.documentForbidden,
    _ when failure.kind == ApiFailureKind.forbidden => l10n.documentForbidden,
    _ => apiFailureMessage(
      failure,
      l10n,
      fallback: l10n.documentOperationFailed,
    ),
  };
}
