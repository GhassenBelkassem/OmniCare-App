import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/network/api_failure.dart';
import '../../core/network/api_failure_message.dart';
import '../../l10n/omni_localizations.dart';
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
  Object? _error;
  List<AccountDevice> _devices = const [];
  PhoneChangeStatus? _phoneChangeStatus;
  bool _isPhoneActionBusy = false;
  Object? _phoneError;
  List<AuthHistoryEvent> _history = const [];
  bool _isHistoryLoading = false;
  bool _historyHasNext = false;
  int _historyPage = 0;
  Object? _historyError;
  String? _reportingEventId;

  bool get hasPassword => _hasPassword;
  bool get isLoading => _isLoading;
  bool get isSavingPassword => _isSavingPassword;
  bool get isRevokingOthers => _isRevokingOthers;
  String? get revokingDeviceId => _revokingDeviceId;
  bool get hasError => _error != null;

  /// French text for the last device/password error; never server text.
  String? errorMessage(OmniLocalizations l10n) => _textOf(_error, l10n);
  List<AccountDevice> get devices => List.unmodifiable(_devices);
  PhoneChangeStatus? get phoneChangeStatus => _phoneChangeStatus;
  bool get isPhoneActionBusy => _isPhoneActionBusy;
  bool get hasPhoneError => _phoneError != null;
  String? phoneErrorMessage(OmniLocalizations l10n) =>
      _textOf(_phoneError, l10n);
  List<AuthHistoryEvent> get history => List.unmodifiable(_history);
  bool get isHistoryLoading => _isHistoryLoading;
  bool get historyHasNext => _historyHasNext;
  bool get hasHistoryError => _historyError != null;
  String? historyErrorMessage(OmniLocalizations l10n) =>
      _textOf(_historyError, l10n);
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
      _error = _capture(error);
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
            throw const SecurityLocalException(
              SecurityLocalError.googleUseWebButton,
            );
          }
          final account = await GoogleSignIn(scopes: const ['email']).signIn();
          if (account == null) {
            throw const SecurityLocalException(
              SecurityLocalError.googleCancelled,
            );
          }
          idToken = (await account.authentication).idToken;
        }
        if (idToken == null || idToken.trim().isEmpty) {
          throw const SecurityLocalException(SecurityLocalError.googleNoProof);
        }
        await _api.setPassword(idToken.trim(), newPassword);
        _hasPassword = true;
      }
      _devices = await _api.loadDevices();
    } catch (error) {
      _error = _capture(error);
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
      _error = _capture(error);
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
      _error = _capture(error);
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
      _phoneError = _capture(error);
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
      _phoneError = _capture(error);
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
      _historyError = _capture(error);
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
      _historyError = _capture(error);
      rethrow;
    } finally {
      _reportingEventId = null;
      notifyListeners();
    }
  }

  Future<T> _runPhoneAction<T>(Future<T> Function() action) async {
    if (_isPhoneActionBusy) {
      throw const SecurityLocalException(SecurityLocalError.actionInProgress);
    }
    _isPhoneActionBusy = true;
    _phoneError = null;
    notifyListeners();
    try {
      return await action();
    } catch (error) {
      _phoneError = _capture(error);
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

  /// Keeps a local reason as is; anything else becomes a parsed
  /// [ApiFailure] (no server text, no raw response kept).
  static Object _capture(Object error) =>
      error is SecurityLocalException ? error : ApiFailure.from(error);

  static String? _textOf(Object? error, OmniLocalizations l10n) =>
      error == null ? null : securityErrorMessage(error, l10n);
}

/// Errors raised by the app itself on the security screens.
enum SecurityLocalError {
  googleUseWebButton,
  googleCancelled,
  googleNoProof,
  actionInProgress,
}

class SecurityLocalException implements Exception {
  const SecurityLocalException(this.reason);
  final SecurityLocalError reason;

  @override
  String toString() => 'SecurityLocalException(${reason.name})';
}

/// French text for a security-screen error: a local reason, a code with a
/// security-specific wording, or the shared mapping. Never server text.
String securityErrorMessage(Object error, OmniLocalizations l10n) {
  if (error is SecurityLocalException) {
    return switch (error.reason) {
      SecurityLocalError.googleUseWebButton => l10n.securityGoogleUseWebButton,
      SecurityLocalError.googleCancelled => l10n.securityGoogleCancelled,
      SecurityLocalError.googleNoProof => l10n.securityGoogleNoProof,
      SecurityLocalError.actionInProgress => l10n.securityActionInProgress,
    };
  }
  final failure = ApiFailure.from(error);
  return switch (failure.code) {
    'AUTH_INVALID_OTP' => l10n.securityInvalidOtp,
    'AUTH_PHONE_ALREADY_USED' => l10n.securityPhoneAlreadyUsed,
    'CONFLICT' => l10n.securityPhoneChangeInProgress,
    'INVALID_STATE' => l10n.securityStepExpired,
    'AUTH_INVALID_TOKEN' => l10n.securityLinkInvalid,
    _ => apiFailureMessage(failure, l10n),
  };
}
