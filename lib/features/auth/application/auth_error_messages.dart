import '../../../core/network/api_exception.dart';
import 'auth_flow_models.dart';
import 'tunisian_phone_number.dart';

class AuthErrorPresentation {
  final String message;
  final String? code;
  final Map<String, String> fieldErrors;

  const AuthErrorPresentation({
    required this.message,
    this.code,
    this.fieldErrors = const {},
  });
}

class AuthErrorMessages {
  const AuthErrorMessages._();

  static AuthErrorPresentation fromObject(Object error) {
    if (error is PhoneNumberFormatException) {
      return AuthErrorPresentation(message: error.message);
    }

    if (error is AuthFlowException) {
      return AuthErrorPresentation(message: error.message);
    }

    if (error is ApiException) {
      return AuthErrorPresentation(
        message: fromCode(error.code),
        code: error.code,
        fieldErrors: error.fieldErrors,
      );
    }

    return const AuthErrorPresentation(
      message: 'Une erreur est survenue. Veuillez réessayer.',
    );
  }

  static String fromCode(String? code) {
    return switch (code) {
      'AUTH_INVALID_OTP' => 'Code invalide ou expiré.',
      'AUTH_REFRESH_TOKEN_INVALID' =>
        'Session expirée. Veuillez vous reconnecter.',
      'AUTH_SESSION_INVALID' => 'Session expirée. Veuillez vous reconnecter.',
      'AUTH_ACCOUNT_NOT_ALLOWED' =>
        'Ce compte ne peut pas utiliser cette application.',
      'AUTH_PROVIDER_UNAVAILABLE' =>
        'Service de vérification temporairement indisponible. Réessayez plus tard.',
      'OTP_NOT_VERIFIED' =>
        'Veuillez vérifier le code envoyé avant de continuer.',
      'USER_NOT_FOUND' => 'Aucun compte patient trouvé pour ce numéro.',
      'TOO_MANY_REQUESTS' => 'Trop de tentatives. Réessayez plus tard.',
      'VALIDATION_ERROR' => 'Veuillez vérifier les informations saisies.',
      'AUTH_PHONE_ALREADY_USED' => 'Ce numéro est déjà utilisé.',
      'AUTH_EMAIL_ALREADY_USED' => 'Cette adresse e-mail est déjà utilisée.',
      'AUTH_PASSWORD_COMPROMISED' =>
        'Ce mot de passe est compromis. Choisissez-en un autre.',
      'INVALID_INPUT' => 'Veuillez choisir un nouveau mot de passe different.',
      'AUTH_GOOGLE_SIGNUP_EXPIRED' =>
        'Session Google expirée. Recommencez avec Google.',
      'AUTH_GOOGLE_SIGNUP_INVALID' =>
        'Session Google invalide. Recommencez avec Google.',
      'DUPLICATE_IDENTITY' => 'Un compte existe déjà avec ces informations.',
      'NETWORK_CONNECTION_TIMEOUT' =>
        'La connexion a expiré. Vérifiez votre réseau.',
      'NETWORK_RECEIVE_TIMEOUT' => 'Le serveur met trop de temps à répondre.',
      'NETWORK_UNAVAILABLE' => 'Connexion réseau indisponible.',
      'MALFORMED_RESPONSE' => 'Réponse serveur invalide.',
      'UNSUPPORTED_ROLE' => 'Ce compte ne correspond pas à un compte patient.',
      _ => 'Une erreur est survenue. Veuillez réessayer.',
    };
  }
}
