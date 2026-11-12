import '../../l10n/omni_localizations.dart';
import 'api_failure.dart';

/// French text for a failed backend call. Never the server's text.
///
/// Order: a message for the backend [ApiFailure.code] when its meaning is
/// clear; then the message of kinds that say more than any screen text
/// (no network, too slow, session, too many attempts, service down); then
/// the screen's own [fallback] (e.g. « Impossible de charger le profil. »);
/// then one generic message per kind.
String apiFailureMessage(
  ApiFailure failure,
  OmniLocalizations l10n, {
  String? fallback,
}) {
  final byCode = _codeMessage(failure.code, l10n);
  if (byCode != null) return byCode;
  return switch (failure.kind) {
    ApiFailureKind.network => l10n.apiErrorNetwork,
    ApiFailureKind.timeout => l10n.apiErrorTimeout,
    ApiFailureKind.unauthorized => l10n.apiErrorUnauthorized,
    ApiFailureKind.rateLimited => l10n.apiErrorRateLimited,
    ApiFailureKind.server => l10n.apiErrorServer,
    ApiFailureKind.featureUnavailable => l10n.apiErrorFeatureUnavailable,
    ApiFailureKind.forbidden => fallback ?? l10n.apiErrorForbidden,
    ApiFailureKind.notFound => fallback ?? l10n.apiErrorNotFound,
    ApiFailureKind.conflict => fallback ?? l10n.apiErrorConflict,
    ApiFailureKind.validation => fallback ?? l10n.apiErrorValidation,
    ApiFailureKind.unknown => fallback ?? l10n.apiErrorUnknown,
  };
}

/// [apiFailureMessage] for an optional failure: [fallback] when it is null.
String apiFailureMessageOr(
  ApiFailure? failure,
  OmniLocalizations l10n, {
  required String fallback,
}) => failure == null
    ? fallback
    : apiFailureMessage(failure, l10n, fallback: fallback);

/// French text for one rejected field, from its kind (never the server's
/// sentence).
String apiFieldErrorMessage(ApiFieldErrorKind kind, OmniLocalizations l10n) =>
    switch (kind) {
      ApiFieldErrorKind.required => l10n.fieldErrorRequired,
      ApiFieldErrorKind.tooLong => l10n.fieldErrorTooLong,
      ApiFieldErrorKind.tooShort => l10n.fieldErrorTooShort,
      ApiFieldErrorKind.invalidLength => l10n.fieldErrorInvalidLength,
      ApiFieldErrorKind.invalidFormat => l10n.fieldErrorInvalidFormat,
      ApiFieldErrorKind.outOfRange => l10n.fieldErrorOutOfRange,
      ApiFieldErrorKind.invalid => l10n.fieldErrorInvalid,
    };

/// Field path → French text, for forms that show one message per field.
Map<String, String> apiFieldErrorMessages(
  Map<String, ApiFieldErrorKind> fieldErrors,
  OmniLocalizations l10n,
) => {
  for (final entry in fieldErrors.entries)
    entry.key: apiFieldErrorMessage(entry.value, l10n),
};

/// Backend codes whose meaning is clear (G2-1b-2 report §2a). Every other
/// code falls back to the message of its kind.
String? _codeMessage(String? code, OmniLocalizations l10n) => switch (code) {
  'MRS_UNAVAILABLE' => l10n.apiCodeMrsUnavailable,
  'OBJECT_STORAGE_UNAVAILABLE' => l10n.apiCodeObjectStorageUnavailable,
  'FILE_TOO_LARGE' => l10n.apiCodeFileTooLarge,
  'UNSUPPORTED_FILE_TYPE' => l10n.apiCodeUnsupportedFileType,
  'PROFESSIONAL_ACCESS_REQUEST_ALREADY_PENDING' =>
    l10n.apiCodeProfessionalAccessAlreadyPending,
  'AUTH_PASSWORD_COMPROMISED' => l10n.apiCodePasswordCompromised,
  'AUTH_INVALID_CREDENTIALS' => l10n.apiCodeInvalidCredentials,
  'AUTH_PROVIDER_UNAVAILABLE' => l10n.apiCodeAuthProviderUnavailable,
  _ => null,
};
