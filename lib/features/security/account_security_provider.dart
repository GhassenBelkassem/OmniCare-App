import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/network/api_exception.dart';
import 'account_security_api.dart';

class AccountSecurityProvider extends ChangeNotifier {
  AccountSecurityProvider({
    required AccountSecurityApi api,
    required Future<void> Function() forceLocalLogout,
    required Future<void> Function() onProfileChanged,
  }) : _api = api,
       _forceLocalLogout = forceLocalLogout,
       _onProfileChanged = onProfileChanged;

  final AccountSecurityApi _api;
  final Future<void> Function() _forceLocalLogout;
  final Future<void> Function() _onProfileChanged;

  bool _hasPassword = true;
  bool _hasLoadedSnapshot = false;
  bool _isLoading = false;
  bool _isSavingPassword = false;
  bool _isRevokingOthers = false;
  String? _revokingDeviceId;
  String? _error;
  List<AccountDevice> _devices = const [];
  PhoneChangeStatus? _phoneChangeStatus;
  bool _isPhoneActionBusy = false;
  String? _phoneError;
  List<AuthHistoryEvent> _history = const [];
  bool _isHistoryLoading = false;
  bool _historyHasNext = false;
  int _historyPage = 0;
  String? _historyError;
  String? _reportingEventId;

  bool get hasPassword => _hasPassword;
  bool get isLoading => _isLoading;
  bool get isSavingPassword => _isSavingPassword;
  bool get isRevokingOthers => _isRevokingOthers;
  String? get revokingDeviceId => _revokingDeviceId;
  String? get error => _error;
  List<AccountDevice> get devices => List.unmodifiable(_devices);
  PhoneChangeStatus? get phoneChangeStatus => _phoneChangeStatus;
  bool get isPhoneActionBusy => _isPhoneActionBusy;
  String? get phoneError => _phoneError;
  List<AuthHistoryEvent> get history => List.unmodifiable(_history);
  bool get isHistoryLoading => _isHistoryLoading;
  bool get historyHasNext => _historyHasNext;
  String? get historyError => _historyError;
  String? get reportingEventId => _reportingEventId;

  Future<void> load({bool devicesOnly = false}) async {
    if (_isLoading) return;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      if (devicesOnly) {
        _devices = await _api.loadDevices();
      } else {
        final results = await Future.wait<Object>([
          _api.loadSnapshot(),
          _api.loadDevices(),
          _api.loadPhoneChangeStatus(),
        ]);
        _hasPassword = (results[0] as AccountSecuritySnapshot).hasPassword;
        _hasLoadedSnapshot = true;
        _devices = results[1] as List<AccountDevice>;
        _phoneChangeStatus = results[2] as PhoneChangeStatus;
      }
    } catch (error) {
      _error = _message(error);
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> savePassword({
    String? currentPassword,
    required String newPassword,
    String? googleIdToken,
  }) async {
    if (_isSavingPassword) return;
    _isSavingPassword = true;
    _error = null;
    notifyListeners();
    try {
      if (_hasPassword) {
        await _api.changePassword(currentPassword ?? '', newPassword);
      } else {
        String? idToken = googleIdToken?.trim();
        if ((idToken ?? '').isEmpty) {
          if (kIsWeb) {
            throw const ApiException(
              'Utilisez le bouton Google affiché pour confirmer votre identité.',
            );
          }
          final account = await GoogleSignIn(scopes: const ['email']).signIn();
          if (account == null) {
            throw const ApiException('Réauthentification Google annulée.');
          }
          idToken = (await account.authentication).idToken;
        }
        if (idToken == null || idToken.trim().isEmpty) {
          throw const ApiException(
            'Google n’a pas fourni de preuve de réauthentification.',
          );
        }
        await _api.setPassword(idToken.trim(), newPassword);
        _hasPassword = true;
      }
      _devices = await _api.loadDevices();
    } catch (error) {
      _error = _message(error);
      rethrow;
    } finally {
      _isSavingPassword = false;
      notifyListeners();
    }
  }

  Future<void> revokeDevice(AccountDevice device) async {
    if (_revokingDeviceId != null) return;
    _revokingDeviceId = device.id;
    _error = null;
    notifyListeners();
    try {
      await _api.revokeDevice(device.id);
      if (device.current) {
        await _forceLocalLogout();
      } else {
        _devices = await _api.loadDevices();
      }
    } catch (error) {
      _error = _message(error);
      rethrow;
    } finally {
      _revokingDeviceId = null;
      notifyListeners();
    }
  }

  Future<void> revokeOtherDevices() async {
    if (_isRevokingOthers) return;
    _isRevokingOthers = true;
    _error = null;
    notifyListeners();
    try {
      await _api.revokeOtherDevices();
      _devices = await _api.loadDevices();
    } catch (error) {
      _error = _message(error);
      rethrow;
    } finally {
      _isRevokingOthers = false;
      notifyListeners();
    }
  }

  Future<void> logoutAll() async {
    await _api.logoutAll();
    await _forceLocalLogout();
  }

  Future<void> loadPhoneChangeStatus() async {
    if (_isPhoneActionBusy) return;
    _isPhoneActionBusy = true;
    _phoneError = null;
    notifyListeners();
    try {
      _phoneChangeStatus = await _api.loadPhoneChangeStatus();
    } catch (error) {
      _phoneError = _message(error);
      rethrow;
    } finally {
      _isPhoneActionBusy = false;
      notifyListeners();
    }
  }

  Future<PhoneChangeChallenge> initiateCurrentPhoneVerification() {
    return _runPhoneAction(_api.initiateCurrentPhoneVerification);
  }

  Future<PhoneChangeChallenge> verifyCurrentPhone(String otp) {
    return _runPhoneAction(() => _api.verifyCurrentPhone(otp));
  }

  Future<PhoneChangeChallenge> initiateNewPhone(String newPhone) {
    return _runPhoneAction(() => _api.initiateNewPhone(newPhone));
  }

  Future<PhoneChangeStatus> verifyNewPhone(String otp) async {
    final status = await _runPhoneAction(() => _api.verifyNewPhone(otp));
    _phoneChangeStatus = status;
    try {
      await _onProfileChanged();
    } catch (_) {
      // The transition succeeded; profile refresh can be retried independently.
    }
    notifyListeners();
    return status;
  }

  Future<void> reversePhoneChange() async {
    if (_isPhoneActionBusy) return;
    _isPhoneActionBusy = true;
    _phoneError = null;
    notifyListeners();
    try {
      _phoneChangeStatus = await _api.reversePhoneChange();
      await _forceLocalLogout();
    } catch (error) {
      _phoneError = _message(error);
      rethrow;
    } finally {
      _isPhoneActionBusy = false;
      notifyListeners();
    }
  }

  Future<PhoneChangeStatus> reversePhoneChangeWithToken(String token) async {
    final status = await _runPhoneAction(
      () => _api.reversePhoneChangeWithToken(token),
    );
    _phoneChangeStatus = status;
    await _forceLocalLogout();
    return status;
  }

  Future<void> loadHistory({bool refresh = true}) async {
    if (_isHistoryLoading) return;
    _isHistoryLoading = true;
    _historyError = null;
    if (refresh) {
      _historyPage = 0;
      _historyHasNext = false;
    }
    notifyListeners();
    try {
      late AuthHistoryPage page;
      if (refresh && !_hasLoadedSnapshot) {
        final results = await Future.wait<Object>([
          _api.loadHistory(),
          _api.loadSnapshot(),
        ]);
        page = results[0] as AuthHistoryPage;
        _hasPassword = (results[1] as AccountSecuritySnapshot).hasPassword;
        _hasLoadedSnapshot = true;
      } else {
        page = await _api.loadHistory(page: refresh ? 0 : _historyPage + 1);
      }
      _history = refresh ? page.items : [..._history, ...page.items];
      _historyPage = page.page;
      _historyHasNext = page.hasNext;
    } catch (error) {
      _historyError = _message(error);
      rethrow;
    } finally {
      _isHistoryLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreHistory() async {
    if (!_historyHasNext) return;
    await loadHistory(refresh: false);
  }

  Future<void> reportHistoryEvent(AuthHistoryEvent event) async {
    if (_reportingEventId != null || !event.reportable) return;
    _reportingEventId = event.id;
    _historyError = null;
    notifyListeners();
    try {
      await _api.reportHistoryEvent(event.id);
      await _forceLocalLogout();
    } catch (error) {
      _historyError = _message(error);
      rethrow;
    } finally {
      _reportingEventId = null;
      notifyListeners();
    }
  }

  Future<T> _runPhoneAction<T>(Future<T> Function() action) async {
    if (_isPhoneActionBusy) {
      throw const ApiException('Une opération est déjà en cours.');
    }
    _isPhoneActionBusy = true;
    _phoneError = null;
    notifyListeners();
    try {
      return await action();
    } catch (error) {
      _phoneError = _message(error);
      rethrow;
    } finally {
      _isPhoneActionBusy = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void clearPhoneError() {
    _phoneError = null;
    notifyListeners();
  }

  String _message(Object error) {
    if (error is ApiException) {
      final localized = switch (error.code) {
        'AUTH_INVALID_OTP' => 'Le code est incorrect ou a expiré.',
        'AUTH_PHONE_ALREADY_USED' =>
          'Ce numéro est déjà associé à un autre compte.',
        'AUTH_PROVIDER_UNAVAILABLE' =>
          'Le service SMS est temporairement indisponible.',
        'TOO_MANY_REQUESTS' =>
          'Trop de tentatives. Patientez avant de réessayer.',
        'CONFLICT' => 'Un changement de numéro est déjà en cours.',
        'INVALID_STATE' => 'Cette étape a expiré. Recommencez la vérification.',
        'AUTH_INVALID_TOKEN' =>
          'Ce lien est invalide, expiré ou a déjà été utilisé.',
        _ => null,
      };
      if (localized != null) return localized;
      if (error.message.trim().isNotEmpty) return error.message.trim();
    }
    return 'Une erreur est survenue. Réessayez.';
  }
}
