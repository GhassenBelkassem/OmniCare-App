import 'package:flutter/foundation.dart';

import '../../../core/models/patient_profile.dart';
import '../../clinic/clinic_routes.dart';
import '../data/auth_repository.dart';
import '../data/models/auth_dtos.dart';
import 'auth_error_messages.dart';
import 'auth_flow_models.dart';
import 'auth_role_family.dart';
import 'tunisian_phone_number.dart';

enum AuthStatus {
  initializing,
  unauthenticated,
  submitting,
  otpRequired,
  authenticated,
  failure,
}

class AuthController extends ChangeNotifier {
  AuthController({required AuthRepositoryContract repository})
    : _repository = repository;

  final AuthRepositoryContract _repository;

  AuthStatus _status = AuthStatus.initializing;
  CurrentUserDto? _currentUser;
  PatientProfile? _patientProfile;
  AuthRouteDecision? _routeDecision;
  AuthFlowMode? _pendingFlow;
  String? _pendingPhone;
  PhoneSignupDraft? _pendingSignupDraft;
  bool _pendingGoogleSignup = false;
  bool _pendingRememberDevice = false;
  String? _errorCode;
  String? _errorMessage;
  Map<String, String> _fieldErrors = const {};
  bool _initializationCompleted = false;
  bool _submitting = false;
  bool _disposed = false;
  Future<void>? _initializationFuture;

  AuthStatus get status => _status;
  CurrentUserDto? get currentUser => _currentUser;
  PatientProfile? get patientProfile => _patientProfile;
  AuthRouteDecision? get routeDecision => _routeDecision;
  AuthFlowMode? get pendingFlow => _pendingFlow;
  String? get pendingPhone => _pendingPhone;
  bool get hasPendingGoogleSignup => _pendingGoogleSignup;
  String? get errorCode => _errorCode;
  String? get errorMessage => _errorMessage;
  Map<String, String> get fieldErrors => _fieldErrors;
  bool get initializationCompleted => _initializationCompleted;
  bool get isAuthenticated => _status == AuthStatus.authenticated;
  bool get isSubmitting => _submitting;

  /// Authoritative global role of the authenticated account, as returned by
  /// `GET /auth/me`. Null while unauthenticated.
  String? get globalRole => AuthRoles.normalize(_currentUser?.role);

  /// Destination family the authenticated account belongs to.
  AuthRoleFamily get roleFamily => AuthRoles.familyOf(_currentUser?.role);

  String? get nextRoute {
    return switch (_routeDecision) {
      AuthRouteDecision.home => '/home',
      AuthRouteDecision.onboarding => '/conversational-onboarding',
      AuthRouteDecision.passwordChangeRequired => '/change-password-required',
      AuthRouteDecision.doctorWorkspace => '/doctor-dashboard',
      AuthRouteDecision.clinicWorkspace => ClinicRoutes.entry,
      AuthRouteDecision.unsupportedRole => null,
      null => null,
    };
  }

  Future<void> initialize() {
    final current = _initializationFuture;
    if (current != null) return current;

    final started = _initialize();
    _initializationFuture = started;
    return started.whenComplete(() {
      _initializationFuture = null;
    });
  }

  Future<void> _initialize() async {
    _setInitializing();
    try {
      final restored = await _repository.restoreSession();
      if (restored == null) {
        _setUnauthenticated();
      } else {
        _setAuthenticated(restored);
      }
    } catch (e) {
      _setFailure(e);
    } finally {
      _initializationCompleted = true;
      _notify();
    }
  }

  Future<bool> startPhoneLogin(
    String phone, {
    bool rememberDevice = false,
  }) async {
    if (_submitting) return false;
    return _runSubmitting(() async {
      final normalized = TunisianPhoneNumber.normalize(phone);
      await _repository.initiatePhoneLogin(normalized);
      _pendingPhone = normalized;
      _pendingFlow = AuthFlowMode.login;
      _pendingSignupDraft = null;
      _pendingGoogleSignup = false;
      _pendingRememberDevice = rememberDevice;
      _status = AuthStatus.otpRequired;
      return true;
    });
  }

  Future<bool> loginWithEmailPassword(
    String email,
    String password, {
    bool rememberDevice = false,
  }) async {
    if (_submitting) return false;
    return _runSubmitting(() async {
      final result = await _repository.loginWithEmailPassword(
        email,
        password,
        rememberDevice: rememberDevice,
      );
      switch (result.outcome) {
        case EmailPasswordLoginOutcome.authenticated:
          final session = result.session;
          if (session == null) {
            throw const AuthFlowException('Login session was not returned.');
          }
          _setAuthenticated(session);
          return true;
        case EmailPasswordLoginOutcome.requiresPhoneOtp:
          final phone = result.phone;
          if (phone == null || phone.trim().isEmpty) {
            throw const AuthFlowException('Login phone was not returned.');
          }
          _pendingPhone = phone.trim();
          _pendingFlow = AuthFlowMode.login;
          _pendingSignupDraft = null;
          _pendingGoogleSignup = false;
          _pendingRememberDevice = rememberDevice;
          _status = AuthStatus.otpRequired;
          return true;
      }
    });
  }

  Future<bool> startGoogleAuth(
    String idToken, {
    bool rememberDevice = false,
  }) async {
    if (_submitting) return false;
    return _runSubmitting(() async {
      final result = await _repository.initiateGoogle(
        idToken,
        rememberDevice: rememberDevice,
      );
      switch (result.outcome) {
        case GoogleAuthOutcome.authenticated:
          final session = result.session;
          if (session == null) {
            throw const AuthFlowException('Google session was not returned.');
          }
          _setAuthenticated(session);
          return true;
        case GoogleAuthOutcome.requiresPhone:
          _pendingGoogleSignup = true;
          _pendingPhone = null;
          _pendingFlow = AuthFlowMode.signup;
          _pendingSignupDraft = null;
          _pendingRememberDevice = rememberDevice;
          _status = AuthStatus.otpRequired;
          return true;
      }
    });
  }

  Future<bool> verifyPhoneLoginOtp(String otp) async {
    if (_submitting) return false;
    final phone = _pendingPhone;
    if (phone == null || _pendingFlow != AuthFlowMode.login) {
      _setFailure(
        const AuthFlowException('Login verification was not started.'),
      );
      return false;
    }

    return _runSubmitting(() async {
      final session = await _repository.verifyPhoneLoginOtp(
        phone,
        otp,
        rememberDevice: _pendingRememberDevice,
      );
      _setAuthenticated(session);
      return true;
    });
  }

  Future<bool> startGooglePhoneSignup(String phone) async {
    if (_submitting) return false;
    if (!_pendingGoogleSignup) {
      _setFailure(const AuthFlowException('Google signup was not started.'));
      return false;
    }

    return _runSubmitting(() async {
      final normalized = TunisianPhoneNumber.normalize(phone);
      await _repository.initiateGooglePhoneSignup(normalized);
      _pendingPhone = normalized;
      _pendingFlow = AuthFlowMode.signup;
      _pendingSignupDraft = null;
      _status = AuthStatus.otpRequired;
      return true;
    });
  }

  Future<bool> startPhoneSignup(
    PhoneSignupDraft draft,
    String phone, {
    bool rememberDevice = false,
  }) async {
    if (_submitting) return false;
    return _runSubmitting(() async {
      final normalized = TunisianPhoneNumber.normalize(phone);
      await _repository.initiatePhoneSignup(normalized);
      _pendingPhone = normalized;
      _pendingFlow = AuthFlowMode.signup;
      _pendingSignupDraft = draft;
      _pendingGoogleSignup = false;
      _pendingRememberDevice = rememberDevice;
      _status = AuthStatus.otpRequired;
      return true;
    });
  }

  Future<bool> verifyPhoneSignupOtp(String otp) async {
    if (_submitting) return false;
    final phone = _pendingPhone;
    final draft = _pendingSignupDraft;
    if (phone == null || _pendingFlow != AuthFlowMode.signup) {
      _setFailure(
        const AuthFlowException('Signup verification was not started.'),
      );
      return false;
    }

    return _runSubmitting(() async {
      late final AuthenticatedPatientSession session;
      if (_pendingGoogleSignup) {
        await _repository.verifyGooglePhoneSignupOtp(phone, otp);
        session = await _repository.completeGoogleSignup(
          rememberDevice: _pendingRememberDevice,
        );
      } else {
        if (draft == null) {
          throw const AuthFlowException('Signup details are missing.');
        }
        await _repository.verifyPhoneSignupOtp(phone, otp);
        session = await _repository.completePhoneSignup(
          draft,
          phone,
          rememberDevice: _pendingRememberDevice,
        );
      }
      _setAuthenticated(session);
      return true;
    });
  }

  Future<bool> resendOtp() async {
    if (_submitting) return false;
    final phone = _pendingPhone;
    final flow = _pendingFlow;
    if (phone == null || flow == null) return false;

    return _runSubmitting(() async {
      if (flow == AuthFlowMode.login) {
        await _repository.initiatePhoneLogin(phone);
      } else if (_pendingGoogleSignup) {
        await _repository.initiateGooglePhoneSignup(phone);
      } else {
        await _repository.initiatePhoneSignup(phone);
      }
      _status = AuthStatus.otpRequired;
      return true;
    });
  }

  Future<void> logout() async {
    if (_submitting) return;
    _submitting = true;
    _notify();
    try {
      await _repository.logout();
    } finally {
      _clearAuthState();
      _submitting = false;
      _status = AuthStatus.unauthenticated;
      _initializationCompleted = true;
      _notify();
    }
  }

  Future<bool> changeRequiredPassword(
    String currentPassword,
    String newPassword,
  ) async {
    if (_submitting) return false;
    return _runSubmitting(() async {
      await _repository.changePassword(currentPassword, newPassword);
      _clearAuthState();
      _status = AuthStatus.unauthenticated;
      _initializationCompleted = true;
      return true;
    });
  }

  Future<void> handleSessionInvalidated() async {
    if (_status == AuthStatus.unauthenticated &&
        _errorCode == 'AUTH_SESSION_INVALID') {
      return;
    }
    _clearAuthState();
    _status = AuthStatus.unauthenticated;
    _initializationCompleted = true;
    _errorCode = 'AUTH_SESSION_INVALID';
    _errorMessage = AuthErrorMessages.fromCode(_errorCode);
    _notify();
  }

  void clearError() {
    _errorCode = null;
    _errorMessage = null;
    _fieldErrors = const {};
    _notify();
  }

  void cancelPendingFlow() {
    if (_submitting || _status == AuthStatus.authenticated) return;
    _pendingFlow = null;
    _pendingPhone = null;
    _pendingSignupDraft = null;
    _pendingGoogleSignup = false;
    _pendingRememberDevice = false;
    if (_status == AuthStatus.otpRequired) {
      _status = AuthStatus.unauthenticated;
    }
    _notify();
  }

  void _setInitializing() {
    _status = AuthStatus.initializing;
    _initializationCompleted = false;
    _submitting = false;
    _errorCode = null;
    _errorMessage = null;
    _fieldErrors = const {};
    _notify();
  }

  void _setUnauthenticated() {
    _clearAuthState();
    _status = AuthStatus.unauthenticated;
  }

  void _setAuthenticated(AuthenticatedPatientSession session) {
    _currentUser = session.user;
    _patientProfile = session.profile;
    _routeDecision = session.routeDecision;
    _pendingFlow = null;
    _pendingPhone = null;
    _pendingSignupDraft = null;
    _pendingGoogleSignup = false;
    _pendingRememberDevice = false;
    _errorCode = null;
    _errorMessage = null;
    _fieldErrors = const {};
    _status = AuthStatus.authenticated;
  }

  void _setFailure(Object error) {
    final presentation = AuthErrorMessages.fromObject(error);
    _errorCode = presentation.code;
    _errorMessage = presentation.message;
    _fieldErrors = presentation.fieldErrors;
    _status = AuthStatus.failure;
  }

  Future<bool> _runSubmitting(Future<bool> Function() action) async {
    _submitting = true;
    _status = AuthStatus.submitting;
    _errorCode = null;
    _errorMessage = null;
    _fieldErrors = const {};
    _notify();

    try {
      return await action();
    } catch (e) {
      _setFailure(e);
      return false;
    } finally {
      _submitting = false;
      _notify();
    }
  }

  void _clearAuthState() {
    _currentUser = null;
    _patientProfile = null;
    _routeDecision = null;
    _pendingFlow = null;
    _pendingPhone = null;
    _pendingSignupDraft = null;
    _pendingGoogleSignup = false;
    _pendingRememberDevice = false;
    _errorCode = null;
    _errorMessage = null;
    _fieldErrors = const {};
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class AuthFlowException implements Exception {
  final String message;

  const AuthFlowException(this.message);

  @override
  String toString() => message;
}
