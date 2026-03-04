import 'package:flutter/foundation.dart';

import '../core/api/account_api.dart';
import '../core/auth/token_storage.dart';
import '../core/models/account_models.dart';

class UserProvider extends ChangeNotifier {
  final AccountApi _api;

  UserProvider({AccountApi? api}) : _api = api ?? AccountApi();

  AccountFullProfile? _profile;
  bool _loading = false;
  String? _error;

  AccountFullProfile? get profile => _profile;
  AccountUser? get user => _profile?.user;
  List<AccountFamilyMember> get familyMembers => _profile?.familyMembers ?? const [];

  bool get isLoading => _loading;
  String? get error => _error;

  Future<void> loadIfLoggedIn() async {
    debugPrint('[UserProvider] loadIfLoggedIn() called');
    final jwt = await TokenStorage.readJwt();
    debugPrint('[UserProvider] JWT present: ${jwt != null && jwt.isNotEmpty}');
    if (jwt == null || jwt.isEmpty) {
      debugPrint('[UserProvider] No JWT found. Clearing profile.');
      _profile = null;
      notifyListeners();
      return;
    }
    debugPrint('[UserProvider] JWT found. Calling refresh().');
    await refresh();
  }

  Future<void> refresh() async {
    debugPrint('[UserProvider] refresh() start');
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('[UserProvider] Fetching full profile from backend...');
      _profile = await _api.getFullProfile();

      debugPrint('[UserProvider] Full profile loaded successfully');
      debugPrint('[UserProvider] user == null: ${user == null}');
      if (user != null) {
        print('Current User Data: ${user!.toJson()}');
        debugPrint('[UserProvider] user.displayName: "${user!.displayName}"');
        debugPrint('[UserProvider] user.derivedFirstName: "${user!.derivedFirstName}"');
        debugPrint('[UserProvider] user.derivedLastName: "${user!.derivedLastName}"');
      }
      debugPrint('[UserProvider] familyMembers count: ${familyMembers.length}');
      debugPrint('[UserProvider] documents count: ${_profile?.documents.length ?? 0}');
    } catch (e, st) {
      _error = e.toString();
      debugPrint('[UserProvider] refresh() ERROR: $_error');
      debugPrint('[UserProvider] refresh() STACKTRACE: $st');
      rethrow;
    } finally {
      _loading = false;
      debugPrint('[UserProvider] refresh() end. loading=$_loading error=$_error');
      notifyListeners();
    }
  }

  Future<void> logout() async {
    debugPrint('[UserProvider] logout() called');
    await TokenStorage.clearJwt();
    _profile = null;
    _error = null;
    debugPrint('[UserProvider] logout() completed. Profile cleared.');
    notifyListeners();
  }
}
