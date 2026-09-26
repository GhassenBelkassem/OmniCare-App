import '../../../core/device/device_identity_service.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/network/auth_refresh_coordinator.dart';
import '../../../core/storage/secure_token_store.dart';
import '../application/auth_flow_models.dart';
import '../application/auth_role_family.dart';
import '../application/tunisian_phone_number.dart';
import 'auth_api.dart';
import 'models/auth_dtos.dart';

abstract class AuthRepositoryContract {
  Future<GoogleAuthResult> initiateGoogle(
    String idToken, {
    bool rememberDevice = false,
  });
  Future<void> initiateGooglePhoneSignup(String phone);
  Future<void> verifyGooglePhoneSignupOtp(String phone, String otp);
  Future<AuthenticatedPatientSession> completeGoogleSignup({
    String? phone,
    bool rememberDevice = false,
  });
  Future<AuthenticatedPatientSession> linkGoogleAccount(String password);
  void cancelGoogleAccountLink();
  Future<void> initiatePhoneSignup(String phone);
  Future<void> verifyPhoneSignupOtp(String phone, String otp);
  Future<AuthenticatedPatientSession> completePhoneSignup(
    PhoneSignupDraft draft,
    String phone, {
    bool rememberDevice = false,
  });
  Future<void> initiatePhoneLogin(String phone);
  Future<EmailPasswordLoginResult> loginWithEmailPassword(
    String email,
    String password, {
    bool rememberDevice = false,
  });
  Future<AuthenticatedPatientSession> verifyPhoneLoginOtp(
    String phone,
    String otp, {
    bool rememberDevice = false,
  });
  Future<AuthenticatedPatientSession?> restoreSession();
  Future<AuthenticatedPatientSession> loadCurrentProfile();
  Future<void> changePassword(String currentPassword, String newPassword);
  Future<void> logout();
}

class AuthRepository implements AuthRepositoryContract {
  AuthRepository({
    required AuthApi api,
    required SecureTokenStore tokenStore,
    required DeviceIdentityService deviceIdentityService,
    required AuthRefreshCoordinator refreshCoordinator,
  }) : _api = api,
       _tokenStore = tokenStore,
       _deviceIdentityService = deviceIdentityService,
       _refreshCoordinator = refreshCoordinator;

  final AuthApi _api;
  final SecureTokenStore _tokenStore;
  final DeviceIdentityService _deviceIdentityService;
  final AuthRefreshCoordinator _refreshCoordinator;
  String? _pendingGoogleSignupToken;
  String? _pendingGoogleLinkChallenge;

  @override
  Future<GoogleAuthResult> initiateGoogle(
    String idToken, {
    bool rememberDevice = false,
  }) async {
    final identity = await _deviceIdentityService.getDeviceIdentity();
    final response = await _api.initiateGoogle(
      GoogleInitiateRequestDto(
        idToken: idToken.trim(),
        deviceFingerprint: identity.deviceFingerprint,
        platform: identity.platform,
        deviceLabel: identity.deviceLabel,
        sharedDevice: identity.sharedDevice,
        rememberDevice: rememberDevice,
      ),
    );

    switch (response.status) {
      case GoogleAuthStatus.authenticated:
        final login = response.session;
        if (login == null) {
          throw const ApiException(
            'Malformed server response.',
            code: 'MALFORMED_RESPONSE',
          );
        }
        _pendingGoogleSignupToken = null;
        _pendingGoogleLinkChallenge = null;
        await _saveLoginResponse(login);
        return GoogleAuthResult.authenticated(await loadCurrentProfile());
      case GoogleAuthStatus.requiresPhone:
        final signupToken = response.signupToken;
        if (signupToken == null || signupToken.trim().isEmpty) {
          throw const ApiException(
            'Malformed server response.',
            code: 'MALFORMED_RESPONSE',
          );
        }
        _pendingGoogleSignupToken = signupToken.trim();
        _pendingGoogleLinkChallenge = null;
        return const GoogleAuthResult.requiresPhone();
      case GoogleAuthStatus.requiresAccountLink:
        final challenge = response.linkChallenge;
        final emailHint = response.emailHint;
        if (challenge == null ||
            challenge.trim().isEmpty ||
            emailHint == null ||
            emailHint.trim().isEmpty) {
          throw const ApiException(
            'Malformed server response.',
            code: 'MALFORMED_RESPONSE',
          );
        }
        _pendingGoogleSignupToken = null;
        _pendingGoogleLinkChallenge = challenge.trim();
        return GoogleAuthResult.requiresAccountLink(emailHint.trim());
    }
  }

  @override
  Future<AuthenticatedPatientSession> linkGoogleAccount(String password) async {
    final challenge = _pendingGoogleLinkChallenge;
    if (challenge == null || challenge.isEmpty) {
      throw const ApiException(
        'Google account linking was not started.',
        code: 'AUTH_GOOGLE_LINK_INVALID',
      );
    }
    final response = await _api.linkGoogleAccount(
      GoogleLinkRequestDto(linkChallenge: challenge, password: password),
    );
    _pendingGoogleLinkChallenge = null;
    await _saveLoginResponse(response);
    return loadCurrentProfile();
  }

  @override
  void cancelGoogleAccountLink() {
    _pendingGoogleLinkChallenge = null;
  }

  @override
  Future<void> initiateGooglePhoneSignup(String phone) {
    final signupToken = _requirePendingGoogleSignupToken();
    final normalized = TunisianPhoneNumber.normalize(phone);
    return _api.initiateGooglePhoneSignup(
      GooglePhoneInitiateRequestDto(
        signupToken: signupToken,
        phone: normalized,
      ),
    );
  }

  @override
  Future<void> verifyGooglePhoneSignupOtp(String phone, String otp) {
    final signupToken = _requirePendingGoogleSignupToken();
    final normalized = TunisianPhoneNumber.normalize(phone);
    return _api.verifyGooglePhoneSignupOtp(
      GooglePhoneVerifyRequestDto(
        signupToken: signupToken,
        phone: normalized,
        otp: _normalizeOtp(otp),
      ),
    );
  }

  @override
  Future<AuthenticatedPatientSession> completeGoogleSignup({
    String? phone,
    bool rememberDevice = false,
  }) async {
    final signupToken = _requirePendingGoogleSignupToken();
    final identity = await _deviceIdentityService.getDeviceIdentity();
    final response = await _api.completeGoogleSignup(
      GoogleCompleteRequestDto(
        signupToken: signupToken,
        phone: phone,
        deviceFingerprint: identity.deviceFingerprint,
        platform: identity.platform,
        deviceLabel: identity.deviceLabel,
        sharedDevice: identity.sharedDevice,
        rememberDevice: rememberDevice,
      ),
    );
    _pendingGoogleSignupToken = null;
    await _saveLoginResponse(response);
    return loadCurrentProfile();
  }

  @override
  Future<void> initiatePhoneSignup(String phone) {
    final normalized = TunisianPhoneNumber.normalize(phone);
    return _api.initiatePhoneSignup(PhoneRequestDto(phone: normalized));
  }

  @override
  Future<void> verifyPhoneSignupOtp(String phone, String otp) {
    final normalized = TunisianPhoneNumber.normalize(phone);
    return _api.verifyPhoneSignupOtp(
      OtpRequestDto(phone: normalized, otp: _normalizeOtp(otp)),
    );
  }

  @override
  Future<AuthenticatedPatientSession> completePhoneSignup(
    PhoneSignupDraft draft,
    String phone, {
    bool rememberDevice = false,
  }) async {
    final normalized = TunisianPhoneNumber.normalize(phone);
    final identity = await _deviceIdentityService.getDeviceIdentity();
    final response = await _api.completePhoneSignup(
      PhoneSignupCompleteRequestDto(
        phone: normalized,
        email: draft.email.trim(),
        password: draft.password,
        firstName: draft.firstName.trim(),
        lastName: draft.lastName.trim(),
        dateOfBirth: draft.dateOfBirthIso,
        gender: draft.gender,
        deviceFingerprint: identity.deviceFingerprint,
        platform: identity.platform,
        deviceLabel: identity.deviceLabel,
        sharedDevice: identity.sharedDevice,
        rememberDevice: rememberDevice,
      ),
    );
    await _saveLoginResponse(response);
    return loadCurrentProfile();
  }

  @override
  Future<void> initiatePhoneLogin(String phone) {
    final normalized = TunisianPhoneNumber.normalize(phone);
    return _api.initiatePhoneLogin(PhoneRequestDto(phone: normalized));
  }

  @override
  Future<EmailPasswordLoginResult> loginWithEmailPassword(
    String email,
    String password, {
    bool rememberDevice = false,
  }) async {
    final identity = await _deviceIdentityService.getDeviceIdentity();
    final response = await _api.loginWithEmailPassword(
      EmailPasswordLoginRequestDto(
        identifier: email.trim().toLowerCase(),
        password: password,
        deviceFingerprint: identity.deviceFingerprint,
        platform: identity.platform,
        deviceLabel: identity.deviceLabel,
        sharedDevice: identity.sharedDevice,
        rememberDevice: rememberDevice,
      ),
    );
    switch (response.status) {
      case EmailPasswordLoginStatus.authenticated:
        final session = response.session;
        if (session == null) {
          throw const ApiException(
            'Malformed server response.',
            code: 'MALFORMED_RESPONSE',
          );
        }
        await _saveLoginResponse(session);
        return EmailPasswordLoginResult.authenticated(
          await loadCurrentProfile(),
        );
      case EmailPasswordLoginStatus.requiresPhoneOtp:
        final phone = response.phone;
        if (phone == null || phone.trim().isEmpty) {
          throw const ApiException(
            'Malformed server response.',
            code: 'MALFORMED_RESPONSE',
          );
        }
        return EmailPasswordLoginResult.requiresPhoneOtp(phone.trim());
    }
  }

  @override
  Future<AuthenticatedPatientSession> verifyPhoneLoginOtp(
    String phone,
    String otp, {
    bool rememberDevice = false,
  }) async {
    final normalized = TunisianPhoneNumber.normalize(phone);
    final identity = await _deviceIdentityService.getDeviceIdentity();
    final response = await _api.verifyPhoneLoginOtp(
      PhoneLoginVerifyRequestDto(
        phone: normalized,
        otp: _normalizeOtp(otp),
        deviceFingerprint: identity.deviceFingerprint,
        platform: identity.platform,
        deviceLabel: identity.deviceLabel,
        sharedDevice: identity.sharedDevice,
        rememberDevice: rememberDevice,
      ),
    );
    await _saveLoginResponse(response);
    return loadCurrentProfile();
  }

  @override
  Future<AuthenticatedPatientSession?> restoreSession() async {
    final stored = await _tokenStore.readSession();
    if (stored == null) return null;

    if (!stored.refreshTokenExpiresAt.toUtc().isAfter(DateTime.now().toUtc())) {
      await _tokenStore.clearSession();
      return null;
    }

    if (!stored.accessTokenExpiresAt.toUtc().isAfter(DateTime.now().toUtc())) {
      final refreshed = await _refreshCoordinator.refreshSession();
      if (refreshed == null) return null;
    }

    try {
      return await loadCurrentProfile();
    } on ApiException catch (e) {
      if (e.statusCode == 401 ||
          e.code == 'AUTH_SESSION_INVALID' ||
          e.code == 'AUTH_REFRESH_TOKEN_INVALID') {
        await _tokenStore.clearSession();
        return null;
      }
      rethrow;
    }
  }

  @override
  Future<AuthenticatedPatientSession> loadCurrentProfile() async {
    final current = await _api.getCurrentUser();
    final stored = await _tokenStore.readSession();
    if (stored == null) {
      throw const ApiException(
        'Session storage is unavailable.',
        code: 'AUTH_SESSION_INVALID',
      );
    }

    if (current.id != stored.userId) {
      await _tokenStore.clearSession();
      throw const ApiException(
        'Authenticated user identity changed.',
        code: 'AUTH_SESSION_INVALID',
      );
    }

    final roleFamily = AuthRoles.familyOf(current.role);
    if (roleFamily == AuthRoleFamily.unsupported) {
      await _tokenStore.clearSession();
      throw const ApiException(
        'Unsupported account role.',
        code: 'UNSUPPORTED_ROLE',
      );
    }

    await _tokenStore.saveSession(
      stored.copyWith(
        userId: current.id,
        userRole: current.role,
        sessionId: current.sessionId,
      ),
    );

    // Only patient accounts own a patient profile. Professional accounts
    // (doctor and clinic roles) resolve their workspace after authentication.
    final profile = roleFamily == AuthRoleFamily.patient
        ? await _api.getPatientProfile()
        : null;
    return AuthenticatedPatientSession(user: current, profile: profile);
  }

  @override
  Future<void> logout() async {
    final stored = await _tokenStore.readSession();
    try {
      if (stored != null) {
        await _api.logout();
      }
    } catch (_) {
      // Local sensitive state must be cleared even when backend logout fails.
    } finally {
      await _tokenStore.clearSession();
    }
  }

  @override
  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    await _api.changePassword(
      ChangePasswordRequestDto(
        currentPassword: currentPassword,
        newPassword: newPassword,
      ),
    );
    await _tokenStore.clearSession();
  }

  Future<void> _saveLoginResponse(
    LoginResponseDto response, {
    String? sessionId,
  }) {
    return _tokenStore.saveSession(
      response.toStoredSession(sessionId: sessionId),
    );
  }

  String _requirePendingGoogleSignupToken() {
    final signupToken = _pendingGoogleSignupToken;
    if (signupToken == null || signupToken.trim().isEmpty) {
      throw const ApiException(
        'Google signup was not started.',
        code: 'AUTH_GOOGLE_SIGNUP_INVALID',
      );
    }
    return signupToken.trim();
  }

  String _normalizeOtp(String otp) {
    final value = otp.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(value)) {
      throw const ApiException('Invalid OTP format.', code: 'VALIDATION_ERROR');
    }
    return value;
  }
}
