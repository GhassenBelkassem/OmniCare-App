import 'google_sign_in_session_contract.dart';
import 'google_sign_in_session_native.dart'
    if (dart.library.html) 'google_sign_in_session_web.dart'
    as platform;

export 'google_sign_in_session_contract.dart';

GoogleSignInSession createGoogleSignInSession() {
  return platform.createGoogleSignInSession();
}
