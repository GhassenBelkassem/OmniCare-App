import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../core/api/account_api.dart';
import '../core/auth/token_storage.dart';
import '../core/models/account_models.dart';
import '../core/utils/console_log.dart';

class UserProvider extends ChangeNotifier {
  final AccountApi _api;

  UserProvider({AccountApi? api}) : _api = api ?? AccountApi();

  AccountFullProfile? _profile;
  bool _loading = false;
  String? _error;
  Future<void>? _refreshFuture;

  AccountFullProfile? get profile => _profile;
  AccountUser? get user => _profile?.user;
  List<AccountFamilyMember> get familyMembers =>
      _profile?.familyMembers ?? const [];

  bool get isLoading => _loading;
  String? get error => _error;

  Future<void> loadIfLoggedIn() async {
    consoleLog('[UserProvider] loadIfLoggedIn() called');
    final jwt = await TokenStorage.readJwt();
    consoleLog('[UserProvider] JWT present: ${jwt != null && jwt.isNotEmpty}');
    if (jwt == null || jwt.isEmpty) {
      consoleLog('[UserProvider] No JWT found. Clearing profile.');
      _profile = null;
      notifyListeners();
      return;
    }
    consoleLog('[UserProvider] JWT found. Calling refresh().');
    await refresh();
  }

  Future<void> refresh() async {
    if (_refreshFuture != null) {
      consoleLog('[UserProvider] refresh() dedup: awaiting in-flight refresh');
      return _refreshFuture;
    }

    _refreshFuture = _refreshImpl();
    try {
      await _refreshFuture;
    } finally {
      _refreshFuture = null;
    }
  }

  Future<void> _refreshImpl() async {
    consoleLog('[UserProvider] refresh() start');
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      consoleLog('[UserProvider] Fetching full profile from backend...');
      _profile = await _api.getFullProfile();

      consoleLog('[UserProvider] Full profile loaded successfully');
      consoleLog('[UserProvider] user == null: ${user == null}');
      if (user != null) {
        consoleLog(
          '[UserProvider] user.email="${user!.email}" providerType="${user!.providerType}" providerId="${user!.providerId}"',
        );
        consoleLog('[UserProvider] user.displayName: "${user!.displayName}"');
        consoleLog(
          '[UserProvider] user.derivedFirstName: "${user!.derivedFirstName}"',
        );
        consoleLog(
          '[UserProvider] user.derivedLastName: "${user!.derivedLastName}"',
        );
      }
      consoleLog('[UserProvider] familyMembers count: ${familyMembers.length}');
      consoleLog(
        '[UserProvider] documents count: ${_profile?.documents.length ?? 0}',
      );
    } catch (e, st) {
      _error = e.toString();
      consoleLog('[UserProvider] refresh() ERROR: $_error');
      consoleLog('[UserProvider] refresh() STACKTRACE: $st');
      rethrow;
    } finally {
      _loading = false;
      consoleLog(
        '[UserProvider] refresh() end. loading=$_loading error=$_error',
      );
      notifyListeners();
    }
  }

  Future<void> logout() async {
    consoleLog('[UserProvider] logout() called');
    await TokenStorage.clearJwt();
    _profile = null;
    _error = null;
    consoleLog('[UserProvider] logout() completed. Profile cleared.');
    notifyListeners();
  }
}
