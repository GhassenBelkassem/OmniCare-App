import '../../../core/auth/google_web_sign_in_button.dart';
import 'google_sign_in_session_contract.dart';

GoogleSignInSession createGoogleSignInSession() => _WebGoogleSignInSession();

class _WebGoogleSignInSession implements GoogleSignInSession {
  @override
  Future<String?> signInIdToken() {
    throw UnsupportedError(
      'Google sign-in on Web must be initiated by the Google-rendered button.',
    );
  }

  @override
  Future<void> signOut() async {
    clearGoogleWebProviderSession();
  }
}
