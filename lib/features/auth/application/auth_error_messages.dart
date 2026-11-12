import '../../../core/network/api_exception.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/api_failure_message.dart';
import '../../../l10n/omni_localizations.dart';
import 'auth_flow_models.dart';
import 'tunisian_phone_number.dart';

/// What the auth flow keeps about a failure: the error, its code and the
/// rejected fields' kinds. The French text is chosen at display time with
/// [AuthErrorMessages.message]; no server text is kept.
class AuthErrorPresentation {
  const AuthErrorPresentation({
    this.error,
    this.code,
    this.fieldErrors = const {},
  });

  final Object? error;
  final String? code;
  final Map<String, ApiFieldErrorKind> fieldErrors;
}

class AuthErrorMessages {
  const AuthErrorMessages._();

  static AuthErrorPresentation fromObject(Object error) {
    if (error is PhoneNumberFormatException || error is AuthFlowException) {
      return AuthErrorPresentation(error: error);
    }
    final failure = ApiFailure.from(error);
    return AuthErrorPresentation(
      error: error,
      code: _codeOf(error, failure),
      fieldErrors: failure.fieldErrors,
    );
  }

  /// French text for [error]: the auth meaning of its code when there is
  /// one, otherwise the shared text of its kind (no network, too slow…).
  static String message(Object error, OmniLocalizations l10n) {
    // Local checks carry the app's own text, never the server's.
    if (error is PhoneNumberFormatException) return error.message;
    if (error is AuthFlowException) return error.message;
    final failure = ApiFailure.from(error);
    return fromCode(_codeOf(error, failure), l10n) ??
        apiFailureMessage(failure, l10n);
  }

  /// The auth flow's own wording for a backend or local code; null when the
  /// code has no auth-specific meaning.
  static String? fromCode(String? code, OmniLocalizations l10n) =>
      switch (code) {
        'AUTH_INVALID_OTP' => l10n.authInvalidOtp,
        'AUTH_REFRESH_TOKEN_INVALID' ||
        'AUTH_SESSION_INVALID' => l10n.authSessionExpired,
        'AUTH_ACCOUNT_NOT_ALLOWED' => l10n.authAccountNotAllowed,
        'OTP_NOT_VERIFIED' => l10n.authOtpNotVerified,
        'USER_NOT_FOUND' => l10n.authUserNotFound,
        'TOO_MANY_REQUESTS' => l10n.authTooManyAttempts,
        'VALIDATION_ERROR' => l10n.authCheckDetails,
        'AUTH_PHONE_ALREADY_USED' => l10n.authPhoneAlreadyUsed,
        'AUTH_EMAIL_ALREADY_USED' => l10n.authEmailAlreadyUsed,
        'AUTH_PASSWORD_COMPROMISED' => l10n.apiCodePasswordCompromised,
        'INVALID_INPUT' => l10n.authChooseDifferentPassword,
        'AUTH_GOOGLE_SIGNUP_EXPIRED' => l10n.authGoogleSignupExpired,
        'AUTH_GOOGLE_SIGNUP_INVALID' => l10n.authGoogleSignupInvalid,
        'AUTH_GOOGLE_LINK_EXPIRED' => l10n.authGoogleLinkExpired,
        'AUTH_GOOGLE_LINK_INVALID' => l10n.authGoogleLinkInvalid,
        'AUTH_GOOGLE_LINK_PASSWORD_INVALID' =>
          l10n.authGoogleLinkPasswordInvalid,
        'AUTH_GOOGLE_LINK_PASSWORD_UNAVAILABLE' =>
          l10n.authGoogleLinkPasswordUnavailable,
        'AUTH_GOOGLE_IDENTITY_CONFLICT' => l10n.authGoogleIdentityConflict,
        'DUPLICATE_IDENTITY' => l10n.authDuplicateIdentity,
        'MALFORMED_RESPONSE' => l10n.authMalformedResponse,
        'UNSUPPORTED_ROLE' => l10n.authUnsupportedRole,
        _ => null,
      };

  /// A local code set on the exception (refresh, replay…) wins over the
  /// parsed server code.
  static String? _codeOf(Object error, ApiFailure failure) =>
      error is ApiException ? error.code : failure.code;
}
