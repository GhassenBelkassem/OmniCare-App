import 'package:google_sign_in/google_sign_in.dart';

import 'google_sign_in_session_contract.dart';

GoogleSignInSession createGoogleSignInSession() => _NativeGoogleSignInSession();

class _NativeGoogleSignInSession implements GoogleSignInSession {
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: const ['email']);
  Future<String?>? _signInInFlight;
  Future<void>? _signOutInFlight;

  @override
  Future<String?> signInIdToken() {
    final current = _signInInFlight;
    if (current != null) return current;

    final started = _signIn();
    _signInInFlight = started;
    return started.whenComplete(() {
      if (identical(_signInInFlight, started)) _signInInFlight = null;
    });
  }

  Future<String?> _signIn() async {
    final account = await _googleSignIn.signIn();
    return (await account?.authentication)?.idToken;
  }

  @override
  Future<void> signOut() {
    final current = _signOutInFlight;
    if (current != null) return current;

    final started = _googleSignIn.signOut().then<void>((_) {});
    _signOutInFlight = started;
    return started.whenComplete(() {
      if (identical(_signOutInFlight, started)) _signOutInFlight = null;
    });
  }
}
