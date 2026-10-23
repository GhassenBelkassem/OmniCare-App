abstract interface class GoogleSignInSession {
  Future<String?> signInIdToken();

  Future<void> signOut();
}
