import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:omnicare_mobile/core/device/device_identity_service.dart';
import 'package:omnicare_mobile/core/config/app_environment.dart';
import 'package:omnicare_mobile/core/network/api_exception.dart';
import 'package:omnicare_mobile/core/network/api_failure.dart';
import 'package:omnicare_mobile/core/network/app_http_client.dart';
import 'package:omnicare_mobile/core/network/auth_interceptor.dart';
import 'package:omnicare_mobile/core/network/request_replay_policy.dart';
import 'package:omnicare_mobile/core/models/patient_profile.dart';
import 'package:omnicare_mobile/core/storage/secure_token_store.dart';
import 'package:omnicare_mobile/core/theme/omni_theme.dart';
import 'package:omnicare_mobile/features/auth/application/auth_controller.dart';
import 'package:omnicare_mobile/features/auth/application/auth_error_messages.dart';
import 'package:omnicare_mobile/features/auth/application/auth_flow_models.dart';
import 'package:omnicare_mobile/features/auth/application/auth_role_family.dart';
import 'package:omnicare_mobile/features/auth/application/google_sign_in_session_contract.dart';
import 'package:omnicare_mobile/features/auth/login_screen.dart';
import 'package:omnicare_mobile/features/auth/google_account_link_sheet.dart';
import 'package:omnicare_mobile/features/auth/professional_access_request_screen.dart';
import 'package:omnicare_mobile/features/auth/reset_password_screen.dart';
import 'package:omnicare_mobile/features/auth/signup_screen.dart';
import 'package:omnicare_mobile/features/auth/splash_screen.dart';
import 'package:omnicare_mobile/features/auth/data/auth_api.dart';
import 'package:omnicare_mobile/features/auth/data/auth_repository.dart';
import 'package:omnicare_mobile/features/auth/data/models/auth_dtos.dart';
import 'package:omnicare_mobile/features/auth/data/professional_access_request_api.dart';
import 'package:omnicare_mobile/main.dart';
import 'package:omnicare_mobile/providers/user_provider.dart';
import 'package:omnicare_mobile/features/doctor/doctor_auth_shell_screen.dart';
import 'package:omnicare_mobile/l10n/omni_localizations.dart';

class FakeSecureTokenStorageBackend implements SecureTokenStorageBackend {
  final Map<String, String> values = <String, String>{};
  bool failWrites = false;

  @override
  Future<String?> read({required String key}) async => values[key];

  @override
  Future<void> write({required String key, required String value}) async {
    if (failWrites) throw StateError('write failed');
    values[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    values.remove(key);
  }
}

class RecordedRequest {
  final String method;
  final String path;
  final Object? data;
  final Map<String, dynamic> headers;

  RecordedRequest({
    required this.method,
    required this.path,
    required this.data,
    required this.headers,
  });
}

typedef FakeResponder =
    FutureOr<ResponseBody> Function(RequestOptions options, int count);

class FakeHttpAdapter implements HttpClientAdapter {
  final Map<String, FakeResponder> routes;
  final List<RecordedRequest> requests = [];
  final Map<String, int> counts = {};

  FakeHttpAdapter(this.routes);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    final key = '${options.method} $path';
    final count = (counts[key] ?? 0) + 1;
    counts[key] = count;
    requests.add(
      RecordedRequest(
        method: options.method,
        path: path,
        data: options.data,
        headers: Map<String, dynamic>.from(options.headers),
      ),
    );

    final responder = routes[key];
    if (responder == null) {
      return _json({'code': 'NOT_FOUND', 'message': key}, 404);
    }
    return responder(options, count);
  }

  @override
  void close({bool force = false}) {}
}

class FakeAuthRepository implements AuthRepositoryContract {
  int restoreCalls = 0;
  int loginInitiateCalls = 0;
  int loginVerifyCalls = 0;
  int emailPasswordLoginCalls = 0;
  int signupInitiateCalls = 0;
  int signupVerifyCalls = 0;
  int signupCompleteCalls = 0;
  int googleInitiateCalls = 0;
  int googlePhoneInitiateCalls = 0;
  int googlePhoneVerifyCalls = 0;
  int googleCompleteCalls = 0;
  int googleLinkCalls = 0;
  int googleLinkCancelCalls = 0;
  String? lastGoogleCompletePhone;
  int changePasswordCalls = 0;
  int logoutCalls = 0;
  AuthenticatedPatientSession? restoreResult;
  AuthenticatedPatientSession? loginResult;
  AuthenticatedPatientSession? signupResult;
  EmailPasswordLoginResult? emailPasswordLoginResult;
  GoogleAuthResult? googleResult;
  AuthenticatedPatientSession? googleLinkResult;
  Object? googleLinkError;
  Object? error;
  Completer<void>? restoreGate;
  Completer<void>? loginInitiateGate;
  Completer<void>? signupVerifyGate;
  Completer<void>? logoutGate;
  Object? logoutError;

  @override
  Future<GoogleAuthResult> initiateGoogle(
    String idToken, {
    bool rememberDevice = false,
  }) async {
    googleInitiateCalls += 1;
    if (error != null) throw error!;
    return googleResult ?? const GoogleAuthResult.requiresPhone();
  }

  @override
  Future<void> initiateGooglePhoneSignup(String phone) async {
    googlePhoneInitiateCalls += 1;
    if (error != null) throw error!;
  }

  @override
  Future<void> verifyGooglePhoneSignupOtp(String phone, String otp) async {
    googlePhoneVerifyCalls += 1;
    if (error != null) throw error!;
  }

  @override
  Future<AuthenticatedPatientSession> completeGoogleSignup({
    String? phone,
    bool rememberDevice = false,
  }) async {
    googleCompleteCalls += 1;
    lastGoogleCompletePhone = phone;
    if (error != null) throw error!;
    return signupResult ?? _authenticated(onboardingCompleted: false);
  }

  @override
  Future<AuthenticatedPatientSession> linkGoogleAccount(String password) async {
    googleLinkCalls += 1;
    if (googleLinkError != null) throw googleLinkError!;
    return googleLinkResult ?? _authenticated(onboardingCompleted: true);
  }

  @override
  void cancelGoogleAccountLink() {
    googleLinkCancelCalls += 1;
  }

  @override
  Future<void> initiatePhoneLogin(String phone) async {
    loginInitiateCalls += 1;
    await loginInitiateGate?.future;
    if (error != null) throw error!;
  }

  @override
  Future<void> initiatePhoneSignup(String phone) async {
    signupInitiateCalls += 1;
    if (error != null) throw error!;
  }

  @override
  Future<EmailPasswordLoginResult> loginWithEmailPassword(
    String email,
    String password, {
    bool rememberDevice = false,
  }) async {
    emailPasswordLoginCalls += 1;
    if (error != null) throw error!;
    return emailPasswordLoginResult ??
        EmailPasswordLoginResult.authenticated(
          loginResult ?? _authenticated(onboardingCompleted: true),
        );
  }

  @override
  Future<AuthenticatedPatientSession?> restoreSession() async {
    restoreCalls += 1;
    await restoreGate?.future;
    if (error != null) throw error!;
    return restoreResult;
  }

  @override
  Future<AuthenticatedPatientSession> verifyPhoneLoginOtp(
    String phone,
    String otp, {
    bool rememberDevice = false,
  }) async {
    loginVerifyCalls += 1;
    if (error != null) throw error!;
    return loginResult ?? _authenticated(onboardingCompleted: true);
  }

  @override
  Future<void> verifyPhoneSignupOtp(String phone, String otp) async {
    signupVerifyCalls += 1;
    await signupVerifyGate?.future;
    if (error != null) throw error!;
  }

  @override
  Future<AuthenticatedPatientSession> completePhoneSignup(
    PhoneSignupDraft draft,
    String phone, {
    bool rememberDevice = false,
  }) async {
    signupCompleteCalls += 1;
    if (error != null) throw error!;
    return signupResult ?? _authenticated(onboardingCompleted: false);
  }

  @override
  Future<AuthenticatedPatientSession> loadCurrentProfile() async {
    if (error != null) throw error!;
    return restoreResult ?? _authenticated(onboardingCompleted: true);
  }

  @override
  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    changePasswordCalls += 1;
    if (error != null) throw error!;
  }

  @override
  Future<void> logout() async {
    logoutCalls += 1;
    await logoutGate?.future;
    if (logoutError != null) throw logoutError!;
  }
}

class FakeGoogleSignInSession implements GoogleSignInSession {
  int signInCalls = 0;
  int signOutCalls = 0;
  String? idToken = 'google-id-token';
  Completer<void>? signOutGate;
  Object? signOutError;

  @override
  Future<String?> signInIdToken() async {
    signInCalls += 1;
    return idToken;
  }

  @override
  Future<void> signOut() async {
    signOutCalls += 1;
    await signOutGate?.future;
    if (signOutError != null) throw signOutError!;
  }
}

class CountingNavigatorObserver extends NavigatorObserver {
  final List<String?> pushedRouteNames = [];

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    pushedRouteNames.add(route.settings.name);
    super.didPush(route, previousRoute);
  }
}

StoredSession _session({
  String accessToken = 'access-token-value',
  String refreshToken = 'refresh-token-value',
  DateTime? accessExpiresAt,
  DateTime? refreshExpiresAt,
  String role = 'PATIENT',
}) {
  final now = DateTime.now().toUtc();
  return StoredSession(
    accessToken: accessToken,
    refreshToken: refreshToken,
    accessTokenExpiresAt: accessExpiresAt ?? now.add(const Duration(hours: 1)),
    refreshTokenExpiresAt:
        refreshExpiresAt ?? now.add(const Duration(days: 14)),
    userId: 'user-1',
    userRole: role,
    sessionId: 'session-1',
  );
}

Map<String, dynamic> _loginJson({
  String accessToken = 'new-access-token',
  String refreshToken = 'new-refresh-token',
  String role = 'PATIENT',
  bool mustChangePassword = false,
}) {
  final now = DateTime.now().toUtc();
  return {
    'accessToken': accessToken,
    'tokenType': 'Bearer',
    'expiresAt': now.add(const Duration(hours: 1)).toIso8601String(),
    'refreshToken': refreshToken,
    'refreshExpiresAt': now.add(const Duration(days: 14)).toIso8601String(),
    'user': {
      'id': 'user-1',
      'role': role,
      'mustChangePassword': mustChangePassword,
    },
  };
}

Map<String, dynamic> _emailPasswordLoginJson({
  String accessToken = 'new-access-token',
  String refreshToken = 'new-refresh-token',
  String role = 'PATIENT',
  bool mustChangePassword = false,
}) {
  return {
    'status': 'AUTHENTICATED',
    'session': _loginJson(
      accessToken: accessToken,
      refreshToken: refreshToken,
      role: role,
      mustChangePassword: mustChangePassword,
    ),
    'phone': null,
  };
}

Map<String, dynamic> _emailPasswordLoginRequiresOtpJson({
  String phone = '+21612345678',
}) {
  return {'status': 'REQUIRES_PHONE_OTP', 'session': null, 'phone': phone};
}

Map<String, dynamic> _profileJson({required bool onboardingCompleted}) {
  return {
    'userId': 'user-1',
    'firstName': 'Ahmed',
    'lastName': 'Ben Ali',
    'displayName': 'Ahmed Ben Ali',
    'dateOfBirth': '1998-04-20',
    'gender': 'M',
    'photoUrl': null,
    'primaryPhone': {'value': '+21698123456', 'verified': true},
    'primaryEmail': {'value': 'ahmed@example.tn', 'verified': true},
    'onboardingCompleted': onboardingCompleted,
    'onboardingStep': 1,
    'preferredLanguage': 'fr',
    'notificationMedications': true,
    'notificationAppointments': true,
    'notificationPassport': true,
    'updatedAt': '2026-08-04T10:15:30Z',
  };
}

AuthenticatedPatientSession _authenticated({
  required bool onboardingCompleted,
  bool mustChangePassword = false,
}) {
  return AuthenticatedPatientSession(
    user: CurrentUserDto(
      id: 'user-1',
      role: 'PATIENT',
      sessionId: 'session-1',
      mustChangePassword: mustChangePassword,
    ),
    profile: PatientProfile.fromJson(
      _profileJson(onboardingCompleted: onboardingCompleted),
    ),
  );
}

AuthenticatedPatientSession _doctorSession({bool mustChangePassword = false}) {
  return AuthenticatedPatientSession(
    user: CurrentUserDto(
      id: 'user-1',
      role: 'DOCTOR',
      sessionId: 'session-1',
      mustChangePassword: mustChangePassword,
    ),
    profile: null,
  );
}

Widget _entryApp(AuthController auth) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthController>.value(value: auth),
      ChangeNotifierProvider(create: (_) => UserProvider()),
    ],
    child: MaterialApp(
      localizationsDelegates: OmniLocalizations.localizationsDelegates,
      supportedLocales: OmniLocalizations.supportedLocales,
      home: const LoginScreen(),
      routes: {
        '/auth-entry': (_) => const LoginScreen(),
        '/professional-login': (_) => const LoginScreen(),
        '/login': (_) => const LoginScreen(),
        '/professional-access-request': (_) =>
            const Scaffold(body: Text('professional request form')),
        '/doctor-dashboard': (_) => const DoctorAuthShellScreen(),
        '/home': (_) => const Text('patient home'),
        '/conversational-onboarding': (_) => const Text('patient onboarding'),
        '/change-password-required': (_) => const ResetPasswordScreen(),
      },
    ),
  );
}

ResponseBody _json(Map<String, dynamic> body, int statusCode) {
  return ResponseBody.fromString(
    jsonEncode(body),
    statusCode,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );
}

ResponseBody _empty(int statusCode) {
  return ResponseBody.fromString('', statusCode);
}

AppHttpClient _client(
  SecureTokenStore store,
  FakeHttpAdapter adapter, {
  Future<void> Function()? onSessionInvalidated,
}) {
  final dio = Dio();
  final refreshDio = Dio();
  final client = AppHttpClient(
    tokenStore: store,
    baseUrl: 'http://api.test',
    dio: dio,
    refreshDio: refreshDio,
    onSessionInvalidated: onSessionInvalidated,
  );
  client.dio.httpClientAdapter = adapter;
  client.publicDio.httpClientAdapter = adapter;
  return client;
}

final _fr = lookupOmniLocalizations(const Locale('fr'));

void main() {
  group('DTOs', () {
    test('parse login/profile/error responses and redact tokens', () {
      final loginJson = _loginJson();
      final login = LoginResponseDto.fromJson(loginJson);
      final current = CurrentUserDto.fromJson({
        'id': 'user-1',
        'role': 'PATIENT',
        'sessionId': 'session-1',
        'mustChangePassword': true,
      });
      final profile = PatientProfile.fromJson(
        _profileJson(onboardingCompleted: false),
      );
      // G2-1b-2c: the auth error body is read by the single parser only.
      final error = ApiFailure.fromResponse(
        statusCode: 400,
        body: {
          'code': 'AUTH_INVALID_OTP',
          'message': 'Invalid or expired OTP',
          'timestamp': '2026-07-17T18:00:00Z',
          'fieldErrors': {'otp': 'invalid'},
        },
      );

      expect(login.expiresAt, DateTime.parse(loginJson['expiresAt'] as String));
      expect(login.user.mustChangePassword, isFalse);
      expect(current.mustChangePassword, isTrue);
      expect(login.toString(), isNot(contains('new-access-token')));
      expect(login.toString(), contains('<redacted>'));
      expect(profile.dateOfBirth, DateTime.utc(1998, 4, 20));
      expect(profile.onboardingCompleted, isFalse);
      expect(error.code, 'AUTH_INVALID_OTP');
      expect(error.fieldErrors['otp'], ApiFieldErrorKind.invalid);
      expect(error.toString(), isNot(contains('Invalid or expired OTP')));
    });

    test('missing required token fields are rejected', () {
      final json = _loginJson()..remove('accessToken');
      expect(() => LoginResponseDto.fromJson(json), throwsFormatException);
    });
  });

  group('AuthErrorMessages', () {
    test('maps signup and OTP backend errors to specific messages', () {
      expect(
        AuthErrorMessages.fromCode('AUTH_PHONE_ALREADY_USED', _fr),
        'Ce numéro est déjà utilisé.',
      );
      expect(
        AuthErrorMessages.fromCode('AUTH_EMAIL_ALREADY_USED', _fr),
        'Un compte OmniCare existe déjà avec cette adresse. Connectez-vous avec votre mot de passe.',
      );
      expect(
        AuthErrorMessages.fromCode('DUPLICATE_IDENTITY', _fr),
        'Un compte existe déjà avec ces informations.',
      );
      expect(
        AuthErrorMessages.fromCode('AUTH_INVALID_OTP', _fr),
        'Code invalide ou expiré.',
      );
      expect(
        AuthErrorMessages.fromCode('TOO_MANY_REQUESTS', _fr),
        'Trop de tentatives. Réessayez plus tard.',
      );
      // G2-1b-2c: one wording for the provider outage, on every screen.
      expect(
        AuthErrorMessages.message(
          const ApiFailure(
            kind: ApiFailureKind.server,
            code: 'AUTH_PROVIDER_UNAVAILABLE',
            statusCode: 503,
          ),
          _fr,
        ),
        'Service de connexion momentanément indisponible. Réessayez plus tard.',
      );
      expect(
        AuthErrorMessages.fromCode('AUTH_GOOGLE_SIGNUP_EXPIRED', _fr),
        'Session Google expirée. Recommencez avec Google.',
      );
      expect(
        AuthErrorMessages.fromCode('AUTH_GOOGLE_SIGNUP_INVALID', _fr),
        'Session Google invalide. Recommencez avec Google.',
      );
    });
  });

  group('Base URL and path classification', () {
    test('normalizes explicit host URLs with exactly one api prefix', () {
      final store = SecureTokenStore(backend: FakeSecureTokenStorageBackend());
      final client = AppHttpClient(
        tokenStore: store,
        baseUrl: 'http://host:8080///',
      );
      final prefixedClient = AppHttpClient(
        tokenStore: store,
        baseUrl: 'http://host:8080/api/v1/',
      );
      final webClient = AppHttpClient(
        tokenStore: store,
        baseUrl: 'http://localhost:8080',
      );

      expect(client.dio.options.baseUrl, 'http://host:8080/api/v1');
      expect(prefixedClient.dio.options.baseUrl, 'http://host:8080/api/v1');
      expect(webClient.dio.options.baseUrl, 'http://localhost:8080/api/v1');
    });

    test('debug platform fallbacks are Android and iOS local URLs', () {
      addTearDown(() {
        debugDefaultTargetPlatformOverride = null;
      });

      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(AppEnvironment.apiBaseUrl, 'http://10.0.2.2:8080');
      expect(AppEnvironment.apiV1BaseUrl, 'http://10.0.2.2:8080/api/v1');

      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(AppEnvironment.apiBaseUrl, 'http://localhost:8080');
      expect(AppEnvironment.apiV1BaseUrl, 'http://localhost:8080/api/v1');
    });

    test('blank and malformed explicit base URLs are rejected', () {
      expect(
        () => AppEnvironment.normalizeBaseUrl(' '),
        throwsA(isA<AppEnvironmentException>()),
      );
      expect(
        () => AppEnvironment.normalizeBaseUrl('not-a-url'),
        throwsA(isA<AppEnvironmentException>()),
      );
    });

    test('shared clients enforce a bounded send timeout', () {
      final client = AppHttpClient(
        tokenStore: SecureTokenStore(backend: FakeSecureTokenStorageBackend()),
        baseUrl: 'http://api.test',
      );

      expect(client.dio.options.sendTimeout, const Duration(seconds: 30));
      expect(client.publicDio.options.sendTimeout, const Duration(seconds: 30));
    });

    test('classifies production auth paths independent of query string', () {
      expect(isPublicAuthPath('/api/v1/auth/login/phone/initiate?x=1'), isTrue);
      expect(isPublicAuthPath('/api/v1/auth/signup/complete'), isTrue);
      expect(isPublicAuthPath('/api/v1/auth/google/mobile'), isTrue);
      expect(isPublicAuthPath('/api/v1/auth/refresh?retry=false'), isTrue);
      expect(isNoRefreshPath('/api/v1/auth/logout?from=app'), isFalse);
      expect(isNoRefreshPath('/api/v1/profile?tab=summary'), isFalse);
      expect(normalizeApiPath('/auth/me'), '/api/v1/auth/me');
      expect(normalizeApiPath('/api/v1/auth/me'), '/api/v1/auth/me');
    });
  });

  group('SecureTokenStore', () {
    test('saves and reads one complete JSON session record', () async {
      final backend = FakeSecureTokenStorageBackend();
      final store = SecureTokenStore(backend: backend);

      await store.saveSession(_session());

      expect(backend.values, contains(SecureTokenStore.sessionRecordKey));
      expect(backend.values, isNot(contains(SecureTokenStore.accessTokenKey)));
      final restored = await store.readSession();
      expect(restored!.accessToken, 'access-token-value');
      expect(restored.refreshToken, 'refresh-token-value');
      expect(restored.sessionId, 'session-1');
    });

    test(
      'session replacement after refresh requires one record write',
      () async {
        final backend = FakeSecureTokenStorageBackend();
        final store = SecureTokenStore(backend: backend);
        await store.saveSession(_session());
        await store.saveSession(
          _session(
            accessToken: 'rotated-access-token',
            refreshToken: 'rotated-refresh-token',
          ),
        );

        final restored = await store.readSession();
        expect(restored!.accessToken, 'rotated-access-token');
        expect(restored.refreshToken, 'rotated-refresh-token');
        expect(
          backend.values.keys.where((key) => key.contains('token')),
          isEmpty,
        );
      },
    );

    test('malformed and unsupported JSON records are cleared', () async {
      final backend = FakeSecureTokenStorageBackend();
      final store = SecureTokenStore(backend: backend);

      backend.values[SecureTokenStore.sessionRecordKey] = '{not-json';
      expect(await store.readSession(), isNull);
      expect(backend.values, isEmpty);

      backend.values[SecureTokenStore.sessionRecordKey] = jsonEncode({
        'schemaVersion': 999,
        'accessToken': 'access-token-value',
        'refreshToken': 'refresh-token-value',
      });
      final reloadedStore = SecureTokenStore(backend: backend);
      expect(await reloadedStore.readSession(), isNull);
      expect(backend.values, isEmpty);
    });

    test('missing required JSON fields are cleared', () async {
      final backend = FakeSecureTokenStorageBackend();
      final store = SecureTokenStore(backend: backend);

      backend.values[SecureTokenStore.sessionRecordKey] = jsonEncode({
        'schemaVersion': 1,
        'accessToken': 'access-token-value',
        'refreshToken': 'refresh-token-value',
        'accessTokenExpiresAt': '2026-07-17T18:30:00Z',
        'refreshTokenExpiresAt': '2026-08-16T18:00:00Z',
        'role': 'PATIENT',
      });

      expect(await store.readSession(), isNull);
      expect(backend.values, isEmpty);
    });

    test('nullable sessionId is accepted and can be updated', () async {
      final store = SecureTokenStore(backend: FakeSecureTokenStorageBackend());
      await store.saveSession(_session().copyWith(sessionId: null));

      expect((await store.readSession())!.sessionId, isNull);

      final restored = await store.readSession();
      await store.saveSession(
        restored!.copyWith(sessionId: 'session-after-me'),
      );
      final updated = await store.readSession();
      expect(updated!.accessToken, restored.accessToken);
      expect(updated.refreshToken, restored.refreshToken);
      expect(updated.sessionId, 'session-after-me');
    });

    test('logout clears session but preserves installation ID', () async {
      final store = SecureTokenStore(backend: FakeSecureTokenStorageBackend());
      await store.saveDeviceInstallationId('installation-id');
      await store.saveSession(_session());

      await store.clearSession();

      expect(await store.readSession(), isNull);
      expect(await store.readDeviceInstallationId(), 'installation-id');
    });

    test(
      'legacy multi-key session is migrated once and legacy keys removed',
      () async {
        final backend = FakeSecureTokenStorageBackend()
          ..values[SecureTokenStore.accessTokenKey] = 'legacy-access-token'
          ..values[SecureTokenStore.refreshTokenKey] = 'legacy-refresh-token'
          ..values[SecureTokenStore.accessTokenExpiresAtKey] =
              '2026-07-17T18:30:00Z'
          ..values[SecureTokenStore.refreshTokenExpiresAtKey] =
              '2026-08-16T18:00:00Z'
          ..values[SecureTokenStore.userIdKey] = 'user-1'
          ..values[SecureTokenStore.userRoleKey] = 'PATIENT';
        final store = SecureTokenStore(backend: backend);

        final migrated = await store.readSession();

        expect(migrated!.accessToken, 'legacy-access-token');
        expect(migrated.sessionId, isNull);
        expect(backend.values, contains(SecureTokenStore.sessionRecordKey));
        expect(
          backend.values,
          isNot(contains(SecureTokenStore.accessTokenKey)),
        );
      },
    );

    test(
      'partial legacy storage is invalid and token toString is redacted',
      () async {
        final backend = FakeSecureTokenStorageBackend()
          ..values[SecureTokenStore.accessTokenKey] = 'access-token-value';
        final store = SecureTokenStore(backend: backend);

        expect(await store.readSession(), isNull);
        expect(backend.values, isEmpty);
        expect(_session().toString(), isNot(contains('refresh-token-value')));
      },
    );
  });

  group('DeviceIdentityService', () {
    test('installation ID is generated once and reused', () async {
      var next = 0;
      final store = SecureTokenStore(backend: FakeSecureTokenStorageBackend());
      final service = DeviceIdentityService(
        tokenStore: store,
        platformResolver: () => TargetPlatform.android,
        randomByteGenerator: (_) => next++,
      );

      final first = await service.getDeviceIdentity();
      final second = await service.getDeviceIdentity();

      expect(first.deviceFingerprint, second.deviceFingerprint);
      expect(first.platform, ClientPlatform.android);
      expect(first.platform.value, 'ANDROID');
      expect(first.deviceLabel, 'Android device');
    });

    test('iOS platform uses canonical value', () async {
      final service = DeviceIdentityService(
        tokenStore: SecureTokenStore(backend: FakeSecureTokenStorageBackend()),
        platformResolver: () => TargetPlatform.iOS,
        randomByteGenerator: (_) => 7,
      );

      final identity = await service.getDeviceIdentity();

      expect(identity.platform, ClientPlatform.ios);
      expect(identity.platform.value, 'IOS');
      expect(identity.sharedDevice, isFalse);
    });

    test('web platform uses canonical value and non-sensitive label', () async {
      var next = 0;
      final store = SecureTokenStore(backend: FakeSecureTokenStorageBackend());
      final service = DeviceIdentityService(
        tokenStore: store,
        webPlatformResolver: () => true,
        platformResolver: () =>
            throw StateError('native platform resolver must not run for web'),
        randomByteGenerator: (_) => next++,
      );

      final first = await service.getDeviceIdentity();
      final second = await service.getDeviceIdentity();

      expect(first.deviceFingerprint, second.deviceFingerprint);
      expect(first.platform, ClientPlatform.web);
      expect(first.platform.value, 'WEB');
      expect(first.deviceLabel, 'Web browser');
      expect(first.deviceLabel, isNot(contains('Mozilla')));
      expect(first.deviceLabel, isNot(contains('Chrome')));
      expect(first.sharedDevice, isFalse);
    });
  });

  group('AuthApi', () {
    test(
      'calls phone auth endpoints, /auth/me, /profile, and logout',
      () async {
        final adapter = FakeHttpAdapter({
          'POST /api/v1/auth/signup/phone/initiate': (_, _) => _empty(200),
          'POST /api/v1/auth/signup/phone/verify': (_, _) => _empty(200),
          'POST /api/v1/auth/signup/complete': (_, _) =>
              _json(_loginJson(), 201),
          'POST /api/v1/auth/login/phone/initiate': (_, _) => _empty(200),
          'POST /api/v1/auth/login': (_, _) =>
              _json(_emailPasswordLoginJson(), 200),
          'POST /api/v1/auth/login/phone/verify': (_, _) =>
              _json(_loginJson(), 200),
          'POST /api/v1/auth/google/initiate': (_, _) => _json({
            'status': 'REQUIRES_PHONE',
            'session': null,
            'signupToken': 'opaque-signup-token',
          }, 200),
          'POST /api/v1/auth/google/phone/initiate': (_, _) => _empty(200),
          'POST /api/v1/auth/google/phone/verify': (_, _) => _empty(200),
          'POST /api/v1/auth/google/complete': (_, _) =>
              _json(_loginJson(), 200),
          'POST /api/v1/auth/google/link': (_, _) => _json(_loginJson(), 200),
          'POST /api/v1/auth/refresh': (_, _) => _json(_loginJson(), 200),
          'POST /api/v1/auth/password/change': (_, _) => _empty(204),
          'GET /api/v1/auth/me': (_, _) => _json({
            'id': 'user-1',
            'role': 'PATIENT',
            'sessionId': 'session-1',
            'mustChangePassword': false,
          }, 200),
          'GET /api/v1/profile': (_, _) =>
              _json(_profileJson(onboardingCompleted: false), 200),
          'POST /api/v1/auth/logout': (_, _) => _empty(204),
        });
        final store = SecureTokenStore(
          backend: FakeSecureTokenStorageBackend(),
        );
        await store.saveSession(_session(refreshToken: 'refresh-token'));
        final client = _client(store, adapter);
        final api = AuthApi(client);

        await api.initiatePhoneSignup(
          const PhoneRequestDto(phone: '+21612345678'),
        );
        await api.verifyPhoneSignupOtp(
          const OtpRequestDto(phone: '+21612345678', otp: '123456'),
        );
        await api.completePhoneSignup(
          const PhoneSignupCompleteRequestDto(
            phone: '+21612345678',
            email: 'patient@example.test',
            password: 'VeryStrongPass123',
            firstName: 'Ahmed',
            lastName: 'Ben Ali',
            dateOfBirth: '1998-04-20',
            gender: 'M',
            deviceFingerprint: 'installation-id',
            platform: ClientPlatform.android,
            deviceLabel: 'Android device',
            sharedDevice: false,
          ),
        );
        await api.initiatePhoneLogin(
          const PhoneRequestDto(phone: '+21612345678'),
        );
        await api.loginWithEmailPassword(
          const EmailPasswordLoginRequestDto(
            identifier: 'patient@example.test',
            password: 'VeryStrongPass123',
            deviceFingerprint: 'installation-id',
            platform: ClientPlatform.web,
            deviceLabel: 'Web browser',
            sharedDevice: false,
          ),
        );
        await api.verifyPhoneLoginOtp(
          const PhoneLoginVerifyRequestDto(
            phone: '+21612345678',
            otp: '123456',
            deviceFingerprint: 'installation-id',
            platform: ClientPlatform.ios,
            deviceLabel: 'iPhone',
            sharedDevice: false,
          ),
        );
        await api.initiateGoogle(
          const GoogleInitiateRequestDto(
            idToken: 'google-id-token',
            deviceFingerprint: 'installation-id',
            platform: ClientPlatform.web,
            deviceLabel: 'Web browser',
            sharedDevice: false,
          ),
        );
        await api.initiateGooglePhoneSignup(
          const GooglePhoneInitiateRequestDto(
            signupToken: 'opaque-signup-token',
            phone: '+21612345678',
          ),
        );
        await api.verifyGooglePhoneSignupOtp(
          const GooglePhoneVerifyRequestDto(
            signupToken: 'opaque-signup-token',
            phone: '+21612345678',
            otp: '123456',
          ),
        );
        await api.completeGoogleSignup(
          const GoogleCompleteRequestDto(
            signupToken: 'opaque-signup-token',
            phone: '+21612345678',
            deviceFingerprint: 'installation-id',
            platform: ClientPlatform.web,
            deviceLabel: 'Web browser',
            sharedDevice: false,
          ),
        );
        await api.linkGoogleAccount(
          const GoogleLinkRequestDto(
            linkChallenge: 'opaque-link-challenge',
            password: 'correct-password',
          ),
        );
        await api.refreshSession();
        expect((await api.getCurrentUser()).role, 'PATIENT');
        expect((await api.getPatientProfile()).onboardingCompleted, isFalse);
        await api.changePassword(
          const ChangePasswordRequestDto(
            currentPassword: 'OldPassword123!',
            newPassword: 'NewPassword123!',
          ),
        );
        await api.logout();

        expect(adapter.counts['POST /api/v1/auth/signup/phone/initiate'], 1);
        expect(adapter.counts['POST /api/v1/auth/login/phone/verify'], 1);
        expect(adapter.counts['POST /api/v1/auth/google/initiate'], 1);
        expect(adapter.counts['POST /api/v1/auth/google/complete'], 1);
        expect(adapter.counts['POST /api/v1/auth/google/link'], 1);
        expect(adapter.counts['POST /api/v1/auth/password/change'], 1);
        expect(adapter.counts['POST /api/v1/auth/logout'], 1);
        expect(
          adapter.requests
              .singleWhere(
                (request) =>
                    request.path == '/api/v1/auth/signup/phone/initiate',
              )
              .data,
          {'phone': '+21612345678'},
        );
        expect(
          adapter.requests
              .singleWhere(
                (request) => request.path == '/api/v1/auth/signup/phone/verify',
              )
              .data,
          {'phone': '+21612345678', 'otp': '123456', 'rememberDevice': false},
        );
        expect(
          adapter.requests
              .singleWhere(
                (request) => request.path == '/api/v1/auth/signup/complete',
              )
              .data,
          containsPair('platform', 'ANDROID'),
        );
        expect(
          adapter.requests
              .singleWhere(
                (request) => request.path == '/api/v1/auth/login/phone/verify',
              )
              .data,
          containsPair('platform', 'IOS'),
        );
        expect(
          adapter.requests
              .singleWhere(
                (request) => request.path == '/api/v1/auth/google/initiate',
              )
              .data,
          containsPair('idToken', 'google-id-token'),
        );
        expect(
          adapter.requests
              .singleWhere(
                (request) =>
                    request.path == '/api/v1/auth/google/phone/initiate',
              )
              .data,
          {'signupToken': 'opaque-signup-token', 'phone': '+21612345678'},
        );
        expect(
          adapter.requests
              .singleWhere(
                (request) => request.path == '/api/v1/auth/google/complete',
              )
              .data,
          containsPair('platform', 'WEB'),
        );
        expect(
          adapter.requests
              .singleWhere(
                (request) => request.path == '/api/v1/auth/google/link',
              )
              .data,
          {
            'linkChallenge': 'opaque-link-challenge',
            'password': 'correct-password',
          },
        );
        expect(
          adapter.requests
              .singleWhere(
                (request) => request.path == '/api/v1/auth/google/complete',
              )
              .data,
          containsPair('phone', '+21612345678'),
        );
        expect(
          adapter.requests
              .singleWhere((request) => request.path == '/api/v1/auth/refresh')
              .data,
          {'refreshToken': 'refresh-token'},
        );
        expect(
          adapter.requests
              .where(
                (request) =>
                    request.path == '/api/v1/auth/login/phone/initiate',
              )
              .single
              .headers['Authorization'],
          isNull,
        );
        expect(
          adapter.requests
              .singleWhere((request) => request.path == '/api/v1/auth/me')
              .headers['Authorization'],
          startsWith('Bearer '),
        );
      },
    );

    test('parses backend error codes and field errors', () async {
      final adapter = FakeHttpAdapter({
        'POST /api/v1/auth/login/phone/verify': (_, _) => _json({
          'code': 'AUTH_INVALID_OTP',
          'message': 'Invalid or expired OTP',
          'timestamp': '2026-07-17T18:00:00Z',
          'fieldErrors': {'otp': 'invalid'},
        }, 400),
      });
      final api = AuthApi(
        _client(
          SecureTokenStore(backend: FakeSecureTokenStorageBackend()),
          adapter,
        ),
      );

      expect(
        () => api.verifyPhoneLoginOtp(
          const PhoneLoginVerifyRequestDto(
            phone: '+21612345678',
            otp: '000000',
            deviceFingerprint: 'installation-id',
            platform: ClientPlatform.android,
            deviceLabel: 'Android device',
            sharedDevice: false,
          ),
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', 'AUTH_INVALID_OTP')
              .having((e) => e.fieldErrors['otp'], 'otp', 'invalid'),
        ),
      );
    });

    test('parses email password login phone OTP challenge', () async {
      final adapter = FakeHttpAdapter({
        'POST /api/v1/auth/login': (_, _) =>
            _json(_emailPasswordLoginRequiresOtpJson(), 200),
      });
      final api = AuthApi(
        _client(
          SecureTokenStore(backend: FakeSecureTokenStorageBackend()),
          adapter,
        ),
      );

      final response = await api.loginWithEmailPassword(
        const EmailPasswordLoginRequestDto(
          identifier: 'patient@example.test',
          password: 'VeryStrongPass123',
          deviceFingerprint: 'installation-id',
          platform: ClientPlatform.web,
          deviceLabel: 'Web browser',
          sharedDevice: false,
          rememberDevice: true,
        ),
      );

      expect(response.status, EmailPasswordLoginStatus.requiresPhoneOtp);
      expect(response.session, isNull);
      expect(response.phone, '+21612345678');
      expect(
        adapter.requests.single.data,
        containsPair('rememberDevice', true),
      );
    });

    test('web phone auth requests contain canonical device metadata', () async {
      final store = SecureTokenStore(backend: FakeSecureTokenStorageBackend());
      final adapter = FakeHttpAdapter({
        'POST /api/v1/auth/signup/complete': (_, _) => _json(_loginJson(), 201),
        'GET /api/v1/auth/me': (_, _) => _json({
          'id': 'user-1',
          'role': 'PATIENT',
          'sessionId': 'session-1',
        }, 200),
        'GET /api/v1/profile': (_, _) =>
            _json(_profileJson(onboardingCompleted: false), 200),
        'POST /api/v1/auth/login/phone/verify': (_, _) =>
            _json(_loginJson(), 200),
      });
      final client = _client(store, adapter);
      final repository = AuthRepository(
        api: AuthApi(client),
        tokenStore: store,
        deviceIdentityService: DeviceIdentityService(
          tokenStore: store,
          webPlatformResolver: () => true,
          platformResolver: () =>
              throw StateError('native platform resolver must not run for web'),
          randomByteGenerator: (_) => 3,
        ),
        refreshCoordinator: client.refreshCoordinator,
      );

      await repository.completePhoneSignup(
        PhoneSignupDraft(
          email: 'patient@example.test',
          password: 'VeryStrongPass123',
          firstName: 'Ahmed',
          lastName: 'Ben Ali',
          dateOfBirth: DateTime.utc(1998, 4, 20),
          gender: 'M',
        ),
        '+21612345678',
      );
      await repository.verifyPhoneLoginOtp('+21612345678', '123456');

      final signupData =
          adapter.requests
                  .firstWhere(
                    (request) => request.path == '/api/v1/auth/signup/complete',
                  )
                  .data
              as Map<String, dynamic>;
      final loginData =
          adapter.requests
                  .firstWhere(
                    (request) =>
                        request.path == '/api/v1/auth/login/phone/verify',
                  )
                  .data
              as Map<String, dynamic>;

      expect(signupData['phone'], '+21612345678');
      expect(signupData['email'], 'patient@example.test');
      expect(signupData['password'], 'VeryStrongPass123');
      expect(signupData['firstName'], 'Ahmed');
      expect(signupData['lastName'], 'Ben Ali');
      expect(signupData['dateOfBirth'], '1998-04-20');
      expect(signupData['gender'], 'M');
      expect(signupData['deviceFingerprint'], isA<String>());
      expect(signupData['platform'], 'WEB');
      expect(signupData['deviceLabel'], 'Web browser');
      expect(signupData['sharedDevice'], isFalse);
      expect(loginData['phone'], '+21612345678');
      expect(loginData['otp'], '123456');
      expect(loginData['deviceFingerprint'], signupData['deviceFingerprint']);
      expect(loginData['platform'], 'WEB');
      expect(loginData['deviceLabel'], 'Web browser');
      expect(loginData['sharedDevice'], isFalse);
    });
  });

  group('Refresh interceptor', () {
    test(
      'attaches bearer to protected calls and not public auth calls',
      () async {
        final backend = FakeSecureTokenStorageBackend();
        final store = SecureTokenStore(backend: backend);
        await store.saveSession(_session());
        final adapter = FakeHttpAdapter({
          'GET /api/v1/profile': (_, _) =>
              _json(_profileJson(onboardingCompleted: true), 200),
          'POST /api/v1/auth/login/phone/initiate': (_, _) => _empty(200),
        });
        final client = _client(store, adapter);
        final api = AuthApi(client);

        await api.getPatientProfile();
        await api.initiatePhoneLogin(
          const PhoneRequestDto(phone: '+21612345678'),
        );

        expect(
          adapter.requests[0].headers['Authorization'],
          startsWith('Bearer '),
        );
        expect(adapter.requests[1].headers['Authorization'], isNull);
      },
    );

    test(
      '401 refreshes once, stores rotated tokens, and retries request',
      () async {
        final backend = FakeSecureTokenStorageBackend();
        final store = SecureTokenStore(backend: backend);
        await store.saveSession(_session());
        var invalidated = false;
        final adapter = FakeHttpAdapter({
          'GET /api/v1/profile': (_, count) => count == 1
              ? _json({
                  'code': 'AUTH_SESSION_INVALID',
                  'message': 'expired',
                }, 401)
              : _json(_profileJson(onboardingCompleted: true), 200),
          'POST /api/v1/auth/refresh': (_, _) => _json(
            _loginJson(
              accessToken: 'rotated-access-token',
              refreshToken: 'rotated-refresh-token',
            ),
            200,
          ),
        });
        final api = AuthApi(
          _client(
            store,
            adapter,
            onSessionInvalidated: () async {
              invalidated = true;
            },
          ),
        );

        final profile = await api.getPatientProfile();
        final session = await store.readSession();

        expect(profile.onboardingCompleted, isTrue);
        expect(adapter.counts['POST /api/v1/auth/refresh'], 1);
        expect(adapter.counts['GET /api/v1/profile'], 2);
        expect(session!.accessToken, 'rotated-access-token');
        expect(session.refreshToken, 'rotated-refresh-token');
        expect(invalidated, isFalse);
      },
    );

    test('ten concurrent 401 responses share one refresh future', () async {
      final store = SecureTokenStore(backend: FakeSecureTokenStorageBackend());
      await store.saveSession(_session());
      final refreshCompleter = Completer<ResponseBody>();
      final adapter = FakeHttpAdapter({
        'GET /api/v1/profile': (_, count) => count <= 10
            ? _json({'code': 'AUTH_SESSION_INVALID', 'message': 'expired'}, 401)
            : _json(_profileJson(onboardingCompleted: true), 200),
        'POST /api/v1/auth/refresh': (_, _) => refreshCompleter.future,
      });
      final client = _client(store, adapter);
      final api = AuthApi(client);

      final requests = List.generate(10, (_) => api.getPatientProfile());
      await Future<void>.delayed(Duration.zero);
      refreshCompleter.complete(_json(_loginJson(), 200));

      await Future.wait(requests);
      expect(adapter.counts['POST /api/v1/auth/refresh'], 1);
      expect(adapter.counts['GET /api/v1/profile'], 20);
    });

    test(
      'refresh 5xx preserves the stored session and does not invalidate',
      () async {
        final store = SecureTokenStore(
          backend: FakeSecureTokenStorageBackend(),
        );
        await store.saveSession(_session());
        var invalidations = 0;
        final adapter = FakeHttpAdapter({
          'GET /api/v1/profile': (_, _) => _json({
            'code': 'AUTH_SESSION_INVALID',
            'message': 'expired',
          }, 401),
          'POST /api/v1/auth/refresh': (_, _) =>
              _json({'code': 'SERVICE_UNAVAILABLE', 'message': 'retry'}, 503),
        });
        final api = AuthApi(
          _client(
            store,
            adapter,
            onSessionInvalidated: () async => invalidations += 1,
          ),
        );

        await expectLater(
          api.getPatientProfile(),
          throwsA(
            isA<ApiException>().having(
              (error) => error.code,
              'code',
              'AUTH_REFRESH_TEMPORARILY_UNAVAILABLE',
            ),
          ),
        );

        expect(await store.readSession(), isNotNull);
        expect(invalidations, 0);
        expect(adapter.counts['POST /api/v1/auth/refresh'], 1);
      },
    );

    test('refresh transport failure preserves the stored session', () async {
      final store = SecureTokenStore(backend: FakeSecureTokenStorageBackend());
      await store.saveSession(_session());
      final adapter = FakeHttpAdapter({
        'GET /api/v1/profile': (_, _) =>
            _json({'code': 'AUTH_SESSION_INVALID', 'message': 'expired'}, 401),
        'POST /api/v1/auth/refresh': (options, _) => throw DioException(
          requestOptions: options,
          type: DioExceptionType.connectionError,
          error: StateError('offline'),
        ),
      });

      await expectLater(
        AuthApi(_client(store, adapter)).getPatientProfile(),
        throwsA(
          isA<ApiException>().having(
            (error) => error.code,
            'code',
            'AUTH_REFRESH_TEMPORARILY_UNAVAILABLE',
          ),
        ),
      );

      expect(await store.readSession(), isNotNull);
    });

    test('malformed successful refresh preserves the stored session', () async {
      final store = SecureTokenStore(backend: FakeSecureTokenStorageBackend());
      await store.saveSession(_session());
      final adapter = FakeHttpAdapter({
        'GET /api/v1/profile': (_, _) =>
            _json({'code': 'AUTH_SESSION_INVALID', 'message': 'expired'}, 401),
        'POST /api/v1/auth/refresh': (_, _) => _json({'unexpected': true}, 200),
      });

      await expectLater(
        AuthApi(_client(store, adapter)).getPatientProfile(),
        throwsA(
          isA<ApiException>().having(
            (error) => error.code,
            'code',
            'AUTH_REFRESH_MALFORMED_RESPONSE',
          ),
        ),
      );

      expect(await store.readSession(), isNotNull);
    });

    test(
      'generic refresh 400, 401, 403 and 429 preserve credentials',
      () async {
        for (final status in const [400, 401, 403, 429]) {
          final store = SecureTokenStore(
            backend: FakeSecureTokenStorageBackend(),
          );
          await store.saveSession(_session());
          var invalidations = 0;
          final adapter = FakeHttpAdapter({
            'GET /api/v1/profile': (_, _) => _json({
              'code': 'AUTH_SESSION_INVALID',
              'message': 'expired access token',
            }, 401),
            'POST /api/v1/auth/refresh': (_, _) => _json({
              'code': 'NON_TERMINAL_REFRESH_FAILURE',
              'message': 'not credential authority',
            }, status),
          });

          await expectLater(
            AuthApi(
              _client(
                store,
                adapter,
                onSessionInvalidated: () async => invalidations += 1,
              ),
            ).getPatientProfile(),
            throwsA(isA<ApiException>()),
          );

          expect(
            await store.readSession(),
            isNotNull,
            reason: 'status $status must preserve credentials',
          );
          expect(invalidations, 0, reason: 'status $status is not authority');
        }
      },
    );

    test(
      'all authoritative terminal refresh codes clear credentials',
      () async {
        for (final code in const [
          'AUTH_REFRESH_TOKEN_INVALID',
          'AUTH_SESSION_INVALID',
          'AUTH_SESSION_EXPIRED',
        ]) {
          final store = SecureTokenStore(
            backend: FakeSecureTokenStorageBackend(),
          );
          await store.saveSession(_session());
          var invalidations = 0;
          final adapter = FakeHttpAdapter({
            'GET /api/v1/profile': (_, _) => _json({
              'code': 'AUTH_SESSION_INVALID',
              'message': 'expired access token',
            }, 401),
            'POST /api/v1/auth/refresh': (_, _) => _json({
              'code': code,
              'message': 'terminal credential evidence',
            }, 401),
          });

          await expectLater(
            AuthApi(
              _client(
                store,
                adapter,
                onSessionInvalidated: () async => invalidations += 1,
              ),
            ).getPatientProfile(),
            throwsA(isA<ApiException>()),
          );

          expect(await store.readSession(), isNull, reason: code);
          expect(invalidations, 1, reason: code);
        }
      },
    );

    test(
      'refresh timeout, TLS, DNS and temporary server outcomes preserve credentials',
      () async {
        final outcomes = <String, FakeResponder>{
          'connect timeout': (options, _) => throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionTimeout,
          ),
          'send timeout': (options, _) => throw DioException(
            requestOptions: options,
            type: DioExceptionType.sendTimeout,
          ),
          'receive timeout': (options, _) => throw DioException(
            requestOptions: options,
            type: DioExceptionType.receiveTimeout,
          ),
          'dns': (options, _) => throw DioException(
            requestOptions: options,
            type: DioExceptionType.connectionError,
            error: Exception('Failed host lookup'),
          ),
          'tls': (options, _) => throw DioException(
            requestOptions: options,
            type: DioExceptionType.badCertificate,
          ),
          '500': (_, _) => _json({'code': 'TEMPORARY'}, 500),
          '502': (_, _) => _json({'code': 'TEMPORARY'}, 502),
          '503': (_, _) => _json({'code': 'TEMPORARY'}, 503),
        };

        for (final outcome in outcomes.entries) {
          final store = SecureTokenStore(
            backend: FakeSecureTokenStorageBackend(),
          );
          await store.saveSession(_session());
          final adapter = FakeHttpAdapter({
            'GET /api/v1/profile': (_, _) => _json({
              'code': 'AUTH_SESSION_INVALID',
              'message': 'expired access token',
            }, 401),
            'POST /api/v1/auth/refresh': outcome.value,
          });

          await expectLater(
            AuthApi(_client(store, adapter)).getPatientProfile(),
            throwsA(
              isA<ApiException>().having(
                (error) => error.code,
                'code',
                'AUTH_REFRESH_TEMPORARILY_UNAVAILABLE',
              ),
            ),
          );
          expect(await store.readSession(), isNotNull, reason: outcome.key);
        }
      },
    );

    test(
      'idempotent JSON write is rebuilt and retried after refresh',
      () async {
        final store = SecureTokenStore(
          backend: FakeSecureTokenStorageBackend(),
        );
        await store.saveSession(_session());
        final adapter = FakeHttpAdapter({
          'POST /api/v1/test-command': (_, count) => count == 1
              ? _json({
                  'code': 'AUTH_SESSION_INVALID',
                  'message': 'expired',
                }, 401)
              : _json({'status': 'accepted'}, 200),
          'POST /api/v1/auth/refresh': (_, _) => _json(_loginJson(), 200),
        });
        final client = _client(store, adapter);

        await client.dio.post<dynamic>(
          '/test-command',
          data: {'value': 1},
          options: Options(
            headers: {'Idempotency-Key': 'operation-1'},
            extra: requestReplayExtra(
              RequestReplayPolicy.declaredIdempotentWrite,
            ),
          ),
        );

        expect(adapter.counts['POST /api/v1/test-command'], 2);
        expect(adapter.counts['POST /api/v1/auth/refresh'], 1);
      },
    );

    test('idempotency header alone does not authorize JSON replay', () async {
      final store = SecureTokenStore(backend: FakeSecureTokenStorageBackend());
      await store.saveSession(_session());
      final adapter = FakeHttpAdapter({
        'POST /api/v1/test-command': (_, _) =>
            _json({'code': 'AUTH_SESSION_INVALID', 'message': 'expired'}, 401),
        'POST /api/v1/auth/refresh': (_, _) => _json(_loginJson(), 200),
      });
      final client = _client(store, adapter);

      await expectLater(
        client.dio.post<dynamic>(
          '/test-command',
          data: {'value': 1},
          options: Options(headers: {'Idempotency-Key': 'operation-1'}),
        ),
        throwsA(
          isA<DioException>().having(
            (error) => error.error,
            'safe replay marker',
            isA<AuthReplayRequiredException>(),
          ),
        ),
      );

      expect(adapter.counts['POST /api/v1/test-command'], 1);
      expect(adapter.counts['POST /api/v1/auth/refresh'], 1);
    });

    test('HEAD and OPTIONS are automatic safe reads', () async {
      for (final method in const ['HEAD', 'OPTIONS']) {
        final store = SecureTokenStore(
          backend: FakeSecureTokenStorageBackend(),
        );
        await store.saveSession(_session());
        final adapter = FakeHttpAdapter({
          '$method /api/v1/read-contract': (_, count) => count == 1
              ? _json({
                  'code': 'AUTH_SESSION_INVALID',
                  'message': 'expired',
                }, 401)
              : _json({'ok': true}, 200),
          'POST /api/v1/auth/refresh': (_, _) => _json(_loginJson(), 200),
        });
        final client = _client(store, adapter);

        await client.dio.request<dynamic>(
          '/read-contract',
          options: Options(method: method),
        );

        expect(adapter.counts['$method /api/v1/read-contract'], 2);
        expect(adapter.counts['POST /api/v1/auth/refresh'], 1);
      }
    });

    test(
      'declared JSON PUT and PATCH replay, but DELETE defaults to never',
      () async {
        for (final method in const ['PUT', 'PATCH']) {
          final store = SecureTokenStore(
            backend: FakeSecureTokenStorageBackend(),
          );
          await store.saveSession(_session());
          final adapter = FakeHttpAdapter({
            '$method /api/v1/certified-write': (_, count) => count == 1
                ? _json({
                    'code': 'AUTH_SESSION_INVALID',
                    'message': 'expired',
                  }, 401)
                : _json({'ok': true}, 200),
            'POST /api/v1/auth/refresh': (_, _) => _json(_loginJson(), 200),
          });
          final client = _client(store, adapter);

          await client.dio.request<dynamic>(
            '/certified-write',
            data: {'value': 1},
            options: Options(
              method: method,
              headers: {'Idempotency-Key': 'operation-$method'},
              extra: requestReplayExtra(
                RequestReplayPolicy.declaredIdempotentWrite,
              ),
            ),
          );

          expect(adapter.counts['$method /api/v1/certified-write'], 2);
        }

        final store = SecureTokenStore(
          backend: FakeSecureTokenStorageBackend(),
        );
        await store.saveSession(_session());
        final adapter = FakeHttpAdapter({
          'DELETE /api/v1/uncertified-delete': (_, _) => _json({
            'code': 'AUTH_SESSION_INVALID',
            'message': 'expired',
          }, 401),
          'POST /api/v1/auth/refresh': (_, _) => _json(_loginJson(), 200),
        });
        final client = _client(store, adapter);

        await expectLater(
          client.dio.delete<dynamic>(
            '/uncertified-delete',
            options: Options(headers: {'Idempotency-Key': 'delete-1'}),
          ),
          throwsA(
            isA<DioException>().having(
              (error) => error.error,
              'safe replay marker',
              isA<AuthReplayRequiredException>(),
            ),
          ),
        );
        expect(adapter.counts['DELETE /api/v1/uncertified-delete'], 1);
      },
    );

    test('MultipartFile and Stream bodies are never interceptor-replayed', () {
      for (final body in <Object>[
        MultipartFile.fromBytes([1, 2, 3], filename: 'file.bin'),
        Stream<List<int>>.fromIterable(const [
          <int>[1, 2, 3],
        ]),
      ]) {
        expect(
          isRequestReplayable(
            RequestOptions(
              path: '/unsafe-body',
              method: 'POST',
              data: body,
              headers: {'Idempotency-Key': 'unsafe-1'},
              extra: requestReplayExtra(
                RequestReplayPolicy.declaredIdempotentWrite,
              ),
            ),
          ),
          isFalse,
        );
      }
    });

    test(
      'cancelling one caller during shared refresh prevents its replay',
      () async {
        final store = SecureTokenStore(
          backend: FakeSecureTokenStorageBackend(),
        );
        await store.saveSession(_session());
        final refreshCompleter = Completer<ResponseBody>();
        final refreshStarted = Completer<void>();
        final adapter = FakeHttpAdapter({
          'GET /api/v1/cancelled-read': (_, _) => _json({
            'code': 'AUTH_SESSION_INVALID',
            'message': 'expired',
          }, 401),
          'POST /api/v1/auth/refresh': (_, _) {
            refreshStarted.complete();
            return refreshCompleter.future;
          },
        });
        final client = _client(store, adapter);
        final cancelToken = CancelToken();

        final request = client.dio.get<dynamic>(
          '/cancelled-read',
          cancelToken: cancelToken,
        );
        await refreshStarted.future;
        cancelToken.cancel('caller left');
        refreshCompleter.complete(_json(_loginJson(), 200));

        await expectLater(
          request,
          throwsA(
            isA<DioException>().having(
              CancelToken.isCancel,
              'cancelled',
              isTrue,
            ),
          ),
        );
        expect(adapter.counts['POST /api/v1/auth/refresh'], 1);
        expect(adapter.counts['GET /api/v1/cancelled-read'], 1);
        expect(await store.readSession(), isNotNull);
      },
    );

    test(
      'one cancelled caller does not cancel refresh for another caller',
      () async {
        final store = SecureTokenStore(
          backend: FakeSecureTokenStorageBackend(),
        );
        await store.saveSession(_session());
        final refreshCompleter = Completer<ResponseBody>();
        final refreshStarted = Completer<void>();
        final adapter = FakeHttpAdapter({
          'GET /api/v1/shared-read': (_, count) => count <= 2
              ? _json({
                  'code': 'AUTH_SESSION_INVALID',
                  'message': 'expired',
                }, 401)
              : _json({'ok': true}, 200),
          'POST /api/v1/auth/refresh': (_, _) {
            refreshStarted.complete();
            return refreshCompleter.future;
          },
        });
        final client = _client(store, adapter);
        final cancelledToken = CancelToken();

        final cancelled = client.dio.get<dynamic>(
          '/shared-read',
          cancelToken: cancelledToken,
        );
        final survivor = client.dio.get<dynamic>('/shared-read');
        await refreshStarted.future;
        cancelledToken.cancel('caller left');
        refreshCompleter.complete(_json(_loginJson(), 200));

        await expectLater(cancelled, throwsA(isA<DioException>()));
        expect((await survivor).data, {'ok': true});
        expect(adapter.counts['POST /api/v1/auth/refresh'], 1);
        expect(adapter.counts['GET /api/v1/shared-read'], 3);
      },
    );

    test(
      'retry transport failure is not rewritten as session invalid',
      () async {
        final store = SecureTokenStore(
          backend: FakeSecureTokenStorageBackend(),
        );
        await store.saveSession(_session());
        final adapter = FakeHttpAdapter({
          'GET /api/v1/profile': (options, count) {
            if (count == 1) {
              return _json({
                'code': 'AUTH_SESSION_INVALID',
                'message': 'expired',
              }, 401);
            }
            throw DioException(
              requestOptions: options,
              type: DioExceptionType.connectionError,
              error: StateError('handoff interrupted'),
            );
          },
          'POST /api/v1/auth/refresh': (_, _) =>
              _json(_loginJson(accessToken: 'rotated-access-token'), 200),
        });

        await expectLater(
          AuthApi(_client(store, adapter)).getPatientProfile(),
          throwsA(
            // G2-1b-2c: a transport failure is the `network` kind of the
            // single parser (no session code), not a session invalidation.
            isA<ApiException>()
                .having(
                  (error) => ApiFailure.from(error).kind,
                  'kind',
                  ApiFailureKind.network,
                )
                .having((error) => error.code, 'code', isNull),
          ),
        );

        expect(await store.readSession(), isNotNull);
        expect(
          (await store.readSession())!.accessToken,
          'rotated-access-token',
        );
      },
    );

    test('multipart body is never replayed by the auth interceptor', () async {
      final store = SecureTokenStore(backend: FakeSecureTokenStorageBackend());
      await store.saveSession(_session());
      final adapter = FakeHttpAdapter({
        'POST /api/v1/documents': (_, _) =>
            _json({'code': 'AUTH_SESSION_INVALID', 'message': 'expired'}, 401),
        'POST /api/v1/auth/refresh': (_, _) =>
            _json(_loginJson(accessToken: 'rotated-access-token'), 200),
      });
      final client = _client(store, adapter);

      await expectLater(
        client.dio.post<dynamic>(
          '/documents',
          data: FormData.fromMap({
            'file': MultipartFile.fromBytes([1, 2, 3], filename: 'test.pdf'),
          }),
          options: Options(headers: {'Idempotency-Key': 'upload-1'}),
        ),
        throwsA(
          isA<DioException>().having(
            (error) => error.error,
            'safe replay marker',
            isA<AuthReplayRequiredException>(),
          ),
        ),
      );

      expect(adapter.counts['POST /api/v1/documents'], 1);
      expect(adapter.counts['POST /api/v1/auth/refresh'], 1);
      expect((await store.readSession())!.accessToken, 'rotated-access-token');
    });

    test(
      'non-idempotent JSON write requires an explicit caller retry',
      () async {
        final store = SecureTokenStore(
          backend: FakeSecureTokenStorageBackend(),
        );
        await store.saveSession(_session());
        final adapter = FakeHttpAdapter({
          'POST /api/v1/auth/password/change': (_, _) => _json({
            'code': 'AUTH_SESSION_INVALID',
            'message': 'expired',
          }, 401),
          'POST /api/v1/auth/refresh': (_, _) =>
              _json(_loginJson(accessToken: 'rotated-access-token'), 200),
        });
        final client = _client(store, adapter);

        await expectLater(
          AuthApi(client).changePassword(
            const ChangePasswordRequestDto(
              currentPassword: 'OldPassword123!',
              newPassword: 'NewPassword123!',
            ),
          ),
          throwsA(
            isA<ApiException>().having(
              (error) => error.code,
              'code',
              'AUTH_REPLAY_REQUIRED',
            ),
          ),
        );

        expect(adapter.counts['POST /api/v1/auth/password/change'], 1);
        expect(adapter.counts['POST /api/v1/auth/refresh'], 1);
        expect(
          (await store.readSession())!.accessToken,
          'rotated-access-token',
        );
      },
    );

    test(
      'refresh failure clears session and calls invalidation callback',
      () async {
        final store = SecureTokenStore(
          backend: FakeSecureTokenStorageBackend(),
        );
        await store.saveSession(_session());
        var invalidations = 0;
        final adapter = FakeHttpAdapter({
          'GET /api/v1/profile': (_, _) => _json({
            'code': 'AUTH_SESSION_INVALID',
            'message': 'expired',
          }, 401),
          'POST /api/v1/auth/refresh': (_, _) => _json({
            'code': 'AUTH_REFRESH_TOKEN_INVALID',
            'message': 'invalid refresh',
          }, 401),
        });
        final api = AuthApi(
          _client(
            store,
            adapter,
            onSessionInvalidated: () async {
              invalidations += 1;
            },
          ),
        );

        await expectLater(
          api.getPatientProfile(),
          throwsA(isA<ApiException>()),
        );
        expect(await store.readSession(), isNull);
        expect(invalidations, 1);
        expect(adapter.counts['POST /api/v1/auth/refresh'], 1);
      },
    );

    test(
      'logout 401 refreshes but does not replay a non-idempotent body',
      () async {
        final store = SecureTokenStore(
          backend: FakeSecureTokenStorageBackend(),
        );
        await store.saveSession(_session());
        final adapter = FakeHttpAdapter({
          'POST /api/v1/auth/logout': (_, count) => count == 1
              ? _json({
                  'code': 'AUTH_SESSION_INVALID',
                  'message': 'expired',
                }, 401)
              : _empty(204),
          'POST /api/v1/auth/refresh': (_, _) =>
              _json(_loginJson(refreshToken: 'rotated-refresh-token'), 200),
        });
        final client = _client(store, adapter);
        final api = AuthApi(client);

        final repository = AuthRepository(
          api: api,
          tokenStore: store,
          deviceIdentityService: DeviceIdentityService(tokenStore: store),
          refreshCoordinator: client.refreshCoordinator,
        );

        await repository.logout();

        expect(adapter.counts['POST /api/v1/auth/refresh'], 1);
        expect(adapter.counts['POST /api/v1/auth/logout'], 1);
        expect(await store.readSession(), isNull);
      },
    );

    test(
      'change password posts new credentials and clears local session',
      () async {
        final store = SecureTokenStore(
          backend: FakeSecureTokenStorageBackend(),
        );
        await store.saveSession(_session());
        final adapter = FakeHttpAdapter({
          'POST /api/v1/auth/password/change': (_, _) => _empty(204),
        });
        final client = _client(store, adapter);
        final repository = AuthRepository(
          api: AuthApi(client),
          tokenStore: store,
          deviceIdentityService: DeviceIdentityService(tokenStore: store),
          refreshCoordinator: client.refreshCoordinator,
        );

        await repository.changePassword('OldPassword123!', 'NewPassword123!');

        expect(adapter.counts['POST /api/v1/auth/password/change'], 1);
        expect(
          adapter.requests
              .singleWhere(
                (request) => request.path == '/api/v1/auth/password/change',
              )
              .data,
          {
            'currentPassword': 'OldPassword123!',
            'newPassword': 'NewPassword123!',
          },
        );
        expect(await store.readSession(), isNull);
      },
    );

    test(
      'refresh future clears after success and later uses rotated token',
      () async {
        final store = SecureTokenStore(
          backend: FakeSecureTokenStorageBackend(),
        );
        await store.saveSession(_session(refreshToken: 'first-refresh-token'));
        final adapter = FakeHttpAdapter({
          'GET /api/v1/profile': (_, count) => count == 1 || count == 3
              ? _json({
                  'code': 'AUTH_SESSION_INVALID',
                  'message': 'expired',
                }, 401)
              : _json(_profileJson(onboardingCompleted: true), 200),
          'POST /api/v1/auth/refresh': (_, count) => _json(
            _loginJson(
              accessToken: 'access-token-$count',
              refreshToken: 'refresh-token-$count',
            ),
            200,
          ),
        });
        final api = AuthApi(_client(store, adapter));

        await api.getPatientProfile();
        await api.getPatientProfile();

        final refreshRequests = adapter.requests
            .where((request) => request.path == '/api/v1/auth/refresh')
            .toList();
        expect(refreshRequests, hasLength(2));
        expect(refreshRequests.first.data, {
          'refreshToken': 'first-refresh-token',
        });
        expect(refreshRequests.last.data, {'refreshToken': 'refresh-token-1'});
        expect((await store.readSession())!.refreshToken, 'refresh-token-2');
      },
    );

    test(
      'refresh future clears after failure and later session can refresh',
      () async {
        final store = SecureTokenStore(
          backend: FakeSecureTokenStorageBackend(),
        );
        await store.saveSession(_session(refreshToken: 'bad-refresh-token'));
        var invalidations = 0;
        final adapter = FakeHttpAdapter({
          'GET /api/v1/profile': (_, count) => count == 1 || count == 2
              ? _json({
                  'code': 'AUTH_SESSION_INVALID',
                  'message': 'expired',
                }, 401)
              : _json(_profileJson(onboardingCompleted: true), 200),
          'POST /api/v1/auth/refresh': (_, count) => count == 1
              ? _json({
                  'code': 'AUTH_REFRESH_TOKEN_INVALID',
                  'message': 'bad',
                }, 401)
              : _json(_loginJson(accessToken: 'later-access-token'), 200),
        });
        final api = AuthApi(
          _client(
            store,
            adapter,
            onSessionInvalidated: () async {
              invalidations += 1;
            },
          ),
        );

        await expectLater(
          api.getPatientProfile(),
          throwsA(isA<ApiException>()),
        );
        await store.saveSession(_session(refreshToken: 'later-refresh-token'));
        final profile = await api.getPatientProfile();

        expect(profile.onboardingCompleted, isTrue);
        expect(adapter.counts['POST /api/v1/auth/refresh'], 2);
        expect(invalidations, 1);
      },
    );

    test(
      'repeated 401 after retry invalidates and does not retry again',
      () async {
        final store = SecureTokenStore(
          backend: FakeSecureTokenStorageBackend(),
        );
        await store.saveSession(_session());
        var invalidations = 0;
        final adapter = FakeHttpAdapter({
          'GET /api/v1/profile': (_, _) => _json({
            'code': 'AUTH_SESSION_INVALID',
            'message': 'expired',
          }, 401),
          'POST /api/v1/auth/refresh': (_, _) => _json(_loginJson(), 200),
        });
        final api = AuthApi(
          _client(
            store,
            adapter,
            onSessionInvalidated: () async {
              invalidations += 1;
            },
          ),
        );

        await expectLater(
          api.getPatientProfile(),
          throwsA(isA<ApiException>()),
        );

        expect(adapter.counts['GET /api/v1/profile'], 2);
        expect(adapter.counts['POST /api/v1/auth/refresh'], 1);
        expect(await store.readSession(), isNull);
        expect(invalidations, 1);
      },
    );

    test(
      'generic repeated 401 after retry preserves the rotated session',
      () async {
        final store = SecureTokenStore(
          backend: FakeSecureTokenStorageBackend(),
        );
        await store.saveSession(_session());
        var invalidations = 0;
        final adapter = FakeHttpAdapter({
          'GET /api/v1/profile': (_, count) => count == 1
              ? _json({
                  'code': 'AUTH_SESSION_INVALID',
                  'message': 'expired access token',
                }, 401)
              : _json({
                  'code': 'UNKNOWN_AUTH_FAILURE',
                  'message': 'not terminal credential evidence',
                }, 401),
          'POST /api/v1/auth/refresh': (_, _) =>
              _json(_loginJson(accessToken: 'rotated-access-token'), 200),
        });

        await expectLater(
          AuthApi(
            _client(
              store,
              adapter,
              onSessionInvalidated: () async => invalidations += 1,
            ),
          ).getPatientProfile(),
          throwsA(isA<ApiException>()),
        );

        expect(adapter.counts['GET /api/v1/profile'], 2);
        expect(adapter.counts['POST /api/v1/auth/refresh'], 1);
        expect(
          (await store.readSession())!.accessToken,
          'rotated-access-token',
        );
        expect(invalidations, 0);
      },
    );
  });

  group('AuthRepository', () {
    test('successful login persists session and loads profile', () async {
      final store = SecureTokenStore(backend: FakeSecureTokenStorageBackend());
      final adapter = FakeHttpAdapter({
        'POST /api/v1/auth/login/phone/verify': (_, _) =>
            _json(_loginJson(), 200),
        'GET /api/v1/auth/me': (_, _) => _json({
          'id': 'user-1',
          'role': 'PATIENT',
          'sessionId': 'session-1',
        }, 200),
        'GET /api/v1/profile': (_, _) =>
            _json(_profileJson(onboardingCompleted: true), 200),
      });
      final client = _client(store, adapter);
      final repository = AuthRepository(
        api: AuthApi(client),
        tokenStore: store,
        deviceIdentityService: DeviceIdentityService(
          tokenStore: store,
          platformResolver: () => TargetPlatform.android,
          randomByteGenerator: (_) => 1,
        ),
        refreshCoordinator: client.refreshCoordinator,
      );

      final result = await repository.verifyPhoneLoginOtp(
        '+21612345678',
        '123456',
      );

      expect(result.routeDecision, AuthRouteDecision.home);
      expect((await store.readSession())!.sessionId, 'session-1');
    });

    test(
      'email password login OTP challenge does not persist a session',
      () async {
        final store = SecureTokenStore(
          backend: FakeSecureTokenStorageBackend(),
        );
        final adapter = FakeHttpAdapter({
          'POST /api/v1/auth/login': (_, _) =>
              _json(_emailPasswordLoginRequiresOtpJson(), 200),
          'GET /api/v1/auth/me': (_, _) => _json({
            'id': 'user-1',
            'role': 'PATIENT',
            'sessionId': 'session-1',
          }, 200),
          'GET /api/v1/profile': (_, _) =>
              _json(_profileJson(onboardingCompleted: true), 200),
        });
        final client = _client(store, adapter);
        final repository = AuthRepository(
          api: AuthApi(client),
          tokenStore: store,
          deviceIdentityService: DeviceIdentityService(
            tokenStore: store,
            webPlatformResolver: () => true,
            platformResolver: () => throw StateError(
              'native platform resolver must not run for web',
            ),
            randomByteGenerator: (_) => 2,
          ),
          refreshCoordinator: client.refreshCoordinator,
        );

        final result = await repository.loginWithEmailPassword(
          'PATIENT@EXAMPLE.TEST ',
          'VeryStrongPass123',
          rememberDevice: true,
        );

        expect(result.outcome, EmailPasswordLoginOutcome.requiresPhoneOtp);
        expect(result.phone, '+21612345678');
        expect(result.session, isNull);
        expect(await store.readSession(), isNull);
        expect(adapter.counts['GET /api/v1/auth/me'], isNull);
        expect(adapter.counts['GET /api/v1/profile'], isNull);
        expect(
          adapter.requests.single.data,
          containsPair('identifier', 'patient@example.test'),
        );
      },
    );

    test('storage failure does not report authenticated', () async {
      final backend = FakeSecureTokenStorageBackend()..failWrites = true;
      final store = SecureTokenStore(backend: backend);
      final adapter = FakeHttpAdapter({
        'POST /api/v1/auth/login/phone/verify': (_, _) =>
            _json(_loginJson(), 200),
      });
      final client = _client(store, adapter);
      final repository = AuthRepository(
        api: AuthApi(client),
        tokenStore: store,
        deviceIdentityService: DeviceIdentityService(
          tokenStore: store,
          platformResolver: () => TargetPlatform.android,
          randomByteGenerator: (_) => 1,
        ),
        refreshCoordinator: client.refreshCoordinator,
      );

      await expectLater(
        repository.verifyPhoneLoginOtp('+21612345678', '123456'),
        throwsA(isA<StateError>()),
      );
    });

    test('invalid restore clears session', () async {
      final store = SecureTokenStore(backend: FakeSecureTokenStorageBackend());
      await store.saveSession(
        _session(refreshExpiresAt: DateTime.utc(2020, 1, 1)),
      );
      final adapter = FakeHttpAdapter({});
      final client = _client(store, adapter);
      final repository = AuthRepository(
        api: AuthApi(client),
        tokenStore: store,
        deviceIdentityService: DeviceIdentityService(tokenStore: store),
        refreshCoordinator: client.refreshCoordinator,
      );

      expect(await repository.restoreSession(), isNull);
      expect(await store.readSession(), isNull);
      expect(adapter.counts['POST /api/v1/auth/refresh'], isNull);
    });

    test('expired startup access token triggers one shared refresh', () async {
      final store = SecureTokenStore(backend: FakeSecureTokenStorageBackend());
      await store.saveSession(
        _session(
          accessExpiresAt: DateTime.now().toUtc().subtract(
            const Duration(minutes: 1),
          ),
        ),
      );
      final adapter = FakeHttpAdapter({
        'POST /api/v1/auth/refresh': (_, _) => _json(_loginJson(), 200),
        'GET /api/v1/auth/me': (_, _) => _json({
          'id': 'user-1',
          'role': 'PATIENT',
          'sessionId': 'session-after-me',
        }, 200),
        'GET /api/v1/profile': (_, _) =>
            _json(_profileJson(onboardingCompleted: false), 200),
      });
      final client = _client(store, adapter);
      final repository = AuthRepository(
        api: AuthApi(client),
        tokenStore: store,
        deviceIdentityService: DeviceIdentityService(tokenStore: store),
        refreshCoordinator: client.refreshCoordinator,
      );

      final restored = await repository.restoreSession();

      expect(restored!.routeDecision, AuthRouteDecision.onboarding);
      expect(adapter.counts['POST /api/v1/auth/refresh'], 1);
      expect(adapter.counts['GET /api/v1/auth/me'], 1);
      expect((await store.readSession())!.sessionId, 'session-after-me');
    });

    test(
      'startup refresh outage is recoverable and preserves session',
      () async {
        final store = SecureTokenStore(
          backend: FakeSecureTokenStorageBackend(),
        );
        await store.saveSession(
          _session(
            accessExpiresAt: DateTime.now().toUtc().subtract(
              const Duration(minutes: 1),
            ),
          ),
        );
        final adapter = FakeHttpAdapter({
          'POST /api/v1/auth/refresh': (_, _) =>
              _json({'code': 'SERVICE_UNAVAILABLE', 'message': 'retry'}, 503),
        });
        final client = _client(store, adapter);
        final repository = AuthRepository(
          api: AuthApi(client),
          tokenStore: store,
          deviceIdentityService: DeviceIdentityService(tokenStore: store),
          refreshCoordinator: client.refreshCoordinator,
        );

        await expectLater(
          repository.restoreSession(),
          throwsA(
            isA<ApiException>().having(
              (error) => error.code,
              'code',
              'AUTH_REFRESH_TEMPORARILY_UNAVAILABLE',
            ),
          ),
        );

        expect(await store.readSession(), isNotNull);
        expect(adapter.counts['GET /api/v1/auth/me'], isNull);
      },
    );

    test(
      'auth me 401 plus refresh outage does not clear a valid stored session',
      () async {
        final store = SecureTokenStore(
          backend: FakeSecureTokenStorageBackend(),
        );
        await store.saveSession(_session());
        final adapter = FakeHttpAdapter({
          'GET /api/v1/auth/me': (_, _) => _json({
            'code': 'AUTH_SESSION_INVALID',
            'message': 'access token expired',
          }, 401),
          'POST /api/v1/auth/refresh': (_, _) =>
              _json({'code': 'SERVICE_UNAVAILABLE', 'message': 'retry'}, 503),
        });
        final client = _client(store, adapter);
        final repository = AuthRepository(
          api: AuthApi(client),
          tokenStore: store,
          deviceIdentityService: DeviceIdentityService(tokenStore: store),
          refreshCoordinator: client.refreshCoordinator,
        );

        await expectLater(
          repository.restoreSession(),
          throwsA(
            isA<ApiException>().having(
              (error) => error.code,
              'code',
              'AUTH_REFRESH_TEMPORARILY_UNAVAILABLE',
            ),
          ),
        );

        expect(await store.readSession(), isNotNull);
        expect(adapter.counts['POST /api/v1/auth/refresh'], 1);
      },
    );

    test(
      'valid access still validates with auth me and can refresh on 401',
      () async {
        final store = SecureTokenStore(
          backend: FakeSecureTokenStorageBackend(),
        );
        await store.saveSession(
          _session(
            accessExpiresAt: DateTime.now().toUtc().add(
              const Duration(hours: 1),
            ),
          ),
        );
        final adapter = FakeHttpAdapter({
          'GET /api/v1/auth/me': (_, count) => count == 1
              ? _json({
                  'code': 'AUTH_SESSION_INVALID',
                  'message': 'expired',
                }, 401)
              : _json({
                  'id': 'user-1',
                  'role': 'PATIENT',
                  'sessionId': 'session-after-refresh',
                }, 200),
          'POST /api/v1/auth/refresh': (_, _) => _json(_loginJson(), 200),
          'GET /api/v1/profile': (_, _) =>
              _json(_profileJson(onboardingCompleted: true), 200),
        });
        final client = _client(store, adapter);
        final repository = AuthRepository(
          api: AuthApi(client),
          tokenStore: store,
          deviceIdentityService: DeviceIdentityService(tokenStore: store),
          refreshCoordinator: client.refreshCoordinator,
        );

        final restored = await repository.restoreSession();

        expect(restored!.routeDecision, AuthRouteDecision.home);
        expect(adapter.counts['POST /api/v1/auth/refresh'], 1);
        expect(adapter.counts['GET /api/v1/auth/me'], 2);
        expect(adapter.counts['GET /api/v1/profile'], 1);
      },
    );

    test('identity mismatch clears session and skips profile', () async {
      final store = SecureTokenStore(backend: FakeSecureTokenStorageBackend());
      await store.saveSession(_session());
      final adapter = FakeHttpAdapter({
        'GET /api/v1/auth/me': (_, _) => _json({
          'id': 'different-user',
          'role': 'PATIENT',
          'sessionId': 'session-1',
        }, 200),
        'GET /api/v1/profile': (_, _) =>
            _json(_profileJson(onboardingCompleted: true), 200),
      });
      final client = _client(store, adapter);
      final repository = AuthRepository(
        api: AuthApi(client),
        tokenStore: store,
        deviceIdentityService: DeviceIdentityService(tokenStore: store),
        refreshCoordinator: client.refreshCoordinator,
      );

      await expectLater(
        repository.loadCurrentProfile(),
        throwsA(isA<ApiException>()),
      );
      expect(await store.readSession(), isNull);
      expect(adapter.counts['GET /api/v1/profile'], isNull);
    });

    test('unsupported role clears session and skips profile', () async {
      final store = SecureTokenStore(backend: FakeSecureTokenStorageBackend());
      await store.saveSession(_session());
      final adapter = FakeHttpAdapter({
        'GET /api/v1/auth/me': (_, _) => _json({
          'id': 'user-1',
          'role': 'SUPPORT_AGENT',
          'sessionId': 'session-1',
        }, 200),
        'GET /api/v1/profile': (_, _) =>
            _json(_profileJson(onboardingCompleted: true), 200),
      });
      final client = _client(store, adapter);
      final repository = AuthRepository(
        api: AuthApi(client),
        tokenStore: store,
        deviceIdentityService: DeviceIdentityService(tokenStore: store),
        refreshCoordinator: client.refreshCoordinator,
      );

      await expectLater(
        repository.loadCurrentProfile(),
        throwsA(isA<ApiException>()),
      );
      expect(await store.readSession(), isNull);
      expect(adapter.counts['GET /api/v1/profile'], isNull);
    });

    test(
      'google pending signup token is used for phone OTP completion',
      () async {
        final store = SecureTokenStore(
          backend: FakeSecureTokenStorageBackend(),
        );
        final adapter = FakeHttpAdapter({
          'POST /api/v1/auth/google/initiate': (_, _) => _json({
            'status': 'REQUIRES_PHONE',
            'session': null,
            'signupToken': 'opaque-signup-token',
          }, 200),
          'POST /api/v1/auth/google/phone/initiate': (_, _) => _empty(200),
          'POST /api/v1/auth/google/phone/verify': (_, _) => _empty(200),
          'POST /api/v1/auth/google/complete': (_, _) =>
              _json(_loginJson(), 200),
          'GET /api/v1/auth/me': (_, _) => _json({
            'id': 'user-1',
            'role': 'PATIENT',
            'sessionId': 'session-1',
          }, 200),
          'GET /api/v1/profile': (_, _) =>
              _json(_profileJson(onboardingCompleted: false), 200),
        });
        final client = _client(store, adapter);
        final repository = AuthRepository(
          api: AuthApi(client),
          tokenStore: store,
          deviceIdentityService: DeviceIdentityService(
            tokenStore: store,
            webPlatformResolver: () => true,
            platformResolver: () => throw StateError(
              'native platform resolver must not run for web',
            ),
            randomByteGenerator: (_) => 4,
          ),
          refreshCoordinator: client.refreshCoordinator,
        );

        final initiateResult = await repository.initiateGoogle(
          ' google-id-token ',
        );
        await repository.initiateGooglePhoneSignup('27 545 726');
        await repository.verifyGooglePhoneSignupOtp('27 545 726', ' 123456 ');
        final session = await repository.completeGoogleSignup(
          phone: '+21627545726',
        );

        expect(initiateResult.outcome, GoogleAuthOutcome.requiresPhone);
        expect(session.routeDecision, AuthRouteDecision.onboarding);
        expect((await store.readSession())!.userId, 'user-1');
        expect(
          adapter.requests
              .singleWhere(
                (request) => request.path == '/api/v1/auth/google/initiate',
              )
              .data,
          containsPair('idToken', 'google-id-token'),
        );
        expect(
          adapter.requests
              .singleWhere(
                (request) =>
                    request.path == '/api/v1/auth/google/phone/initiate',
              )
              .data,
          {'signupToken': 'opaque-signup-token', 'phone': '+21627545726'},
        );
        expect(
          adapter.requests
              .singleWhere(
                (request) => request.path == '/api/v1/auth/google/phone/verify',
              )
              .data,
          {
            'signupToken': 'opaque-signup-token',
            'phone': '+21627545726',
            'otp': '123456',
          },
        );
        expect(
          adapter.requests
              .singleWhere(
                (request) => request.path == '/api/v1/auth/google/complete',
              )
              .data,
          allOf(
            containsPair('signupToken', 'opaque-signup-token'),
            containsPair('phone', '+21627545726'),
          ),
        );
      },
    );

    test(
      'google account link stores session then reloads authoritative Doctor',
      () async {
        final store = SecureTokenStore(
          backend: FakeSecureTokenStorageBackend(),
        );
        final adapter = FakeHttpAdapter({
          'POST /api/v1/auth/google/initiate': (_, _) => _json({
            'status': 'REQUIRES_ACCOUNT_LINK',
            'session': null,
            'signupToken': null,
            'linkChallenge': 'opaque-link-challenge',
            'emailHint': 'd***@gmail.com',
          }, 200),
          'POST /api/v1/auth/google/link': (_, _) =>
              _json(_loginJson(role: 'DOCTOR'), 200),
          'GET /api/v1/auth/me': (_, _) => _json({
            'id': 'user-1',
            'role': 'DOCTOR',
            'sessionId': 'session-1',
            'mustChangePassword': false,
          }, 200),
        });
        final client = _client(store, adapter);
        final repository = AuthRepository(
          api: AuthApi(client),
          tokenStore: store,
          deviceIdentityService: DeviceIdentityService(
            tokenStore: store,
            webPlatformResolver: () => true,
            randomByteGenerator: (_) => 7,
          ),
          refreshCoordinator: client.refreshCoordinator,
        );

        final initiate = await repository.initiateGoogle('google-id-token');
        final linked = await repository.linkGoogleAccount('correct-password');

        expect(initiate.outcome, GoogleAuthOutcome.requiresAccountLink);
        expect(initiate.emailHint, 'd***@gmail.com');
        expect(linked.user.role, 'DOCTOR');
        expect(linked.profile, isNull);
        expect(linked.routeDecision, AuthRouteDecision.doctorWorkspace);
        expect(adapter.counts['GET /api/v1/auth/me'], 1);
        expect(adapter.counts['GET /api/v1/profile'], isNull);
        expect(
          adapter.requests
              .singleWhere(
                (request) => request.path == '/api/v1/auth/google/link',
              )
              .data,
          {
            'linkChallenge': 'opaque-link-challenge',
            'password': 'correct-password',
          },
        );
      },
    );
  });

  group('AuthController', () {
    test('no stored server session becomes unauthenticated', () async {
      final repo = FakeAuthRepository();
      final controller = AuthController(repository: repo);

      await controller.initialize();

      expect(controller.status, AuthStatus.unauthenticated);
      expect(repo.restoreCalls, 1);
    });

    test('initialize cannot run twice concurrently', () async {
      final gate = Completer<void>();
      final repo = FakeAuthRepository()..restoreGate = gate;
      final controller = AuthController(repository: repo);

      final first = controller.initialize();
      final second = controller.initialize();
      gate.complete();
      await Future.wait([first, second]);

      expect(repo.restoreCalls, 1);
    });

    test('valid session selects onboarding route from profile', () async {
      final repo = FakeAuthRepository()
        ..restoreResult = _authenticated(onboardingCompleted: false);
      final controller = AuthController(repository: repo);

      await controller.initialize();

      expect(controller.status, AuthStatus.authenticated);
      expect(controller.nextRoute, '/conversational-onboarding');
    });

    test(
      'required password change takes priority over normal app routes',
      () async {
        final repo = FakeAuthRepository()
          ..restoreResult = _authenticated(
            onboardingCompleted: true,
            mustChangePassword: true,
          );
        final controller = AuthController(repository: repo);

        await controller.initialize();

        expect(controller.status, AuthStatus.authenticated);
        expect(controller.nextRoute, '/change-password-required');
      },
    );

    test(
      'phone-only login is unavailable while verification is disabled',
      () async {
        final repo = FakeAuthRepository()
          ..loginResult = _authenticated(onboardingCompleted: true);
        final controller = AuthController(repository: repo);

        expect(await controller.startPhoneLogin('12 345 678'), isFalse);
        expect(controller.status, AuthStatus.failure);
        expect(
          controller.errorMessage(_fr),
          contains('temporarily unavailable'),
        );
        expect(repo.loginInitiateCalls, 0);
        expect(repo.loginVerifyCalls, 0);
      },
    );

    test('email password login authenticates and selects home route', () async {
      final repo = FakeAuthRepository()
        ..loginResult = _authenticated(onboardingCompleted: true);
      final controller = AuthController(repository: repo);

      expect(
        await controller.loginWithEmailPassword(
          'patient@example.test',
          'VeryStrongPass123',
        ),
        isTrue,
      );

      expect(repo.emailPasswordLoginCalls, 1);
      expect(controller.status, AuthStatus.authenticated);
      expect(controller.nextRoute, '/home');
    });

    test(
      'email password login rejects a server OTP configuration mismatch',
      () async {
        final repo = FakeAuthRepository()
          ..emailPasswordLoginResult =
              const EmailPasswordLoginResult.requiresPhoneOtp('+21612345678');
        final controller = AuthController(repository: repo);

        expect(
          await controller.loginWithEmailPassword(
            'patient@example.test',
            'VeryStrongPass123',
            rememberDevice: true,
          ),
          isFalse,
        );

        expect(repo.emailPasswordLoginCalls, 1);
        expect(controller.status, AuthStatus.failure);
        expect(controller.pendingFlow, isNull);
        expect(controller.pendingPhone, isNull);
        expect(
          controller.errorMessage(_fr),
          contains('server requested an OTP'),
        );
        expect(controller.currentUser, isNull);
        expect(controller.nextRoute, isNull);
      },
    );

    test(
      'changing required password clears auth state after backend success',
      () async {
        final repo = FakeAuthRepository()
          ..restoreResult = _authenticated(
            onboardingCompleted: true,
            mustChangePassword: true,
          );
        final controller = AuthController(repository: repo);
        await controller.initialize();

        expect(
          await controller.changeRequiredPassword(
            'OldPassword123!',
            'NewPassword123!',
          ),
          isTrue,
        );

        expect(repo.changePasswordCalls, 1);
        expect(controller.status, AuthStatus.unauthenticated);
        expect(controller.currentUser, isNull);
        expect(controller.nextRoute, isNull);
      },
    );

    test(
      'repeated phone-only login attempts never call the repository',
      () async {
        final repo = FakeAuthRepository();
        final controller = AuthController(repository: repo);

        final first = await controller.startPhoneLogin('12 345 678');
        final second = await controller.startPhoneLogin('12 345 678');

        expect(first, isFalse);
        expect(second, isFalse);
        expect(repo.loginInitiateCalls, 0);
        expect(controller.status, AuthStatus.failure);
      },
    );

    test(
      'phone signup state progression exposes incomplete onboarding route',
      () async {
        final repo = FakeAuthRepository()
          ..signupResult = _authenticated(onboardingCompleted: false);
        final controller = AuthController(repository: repo);
        final draft = PhoneSignupDraft(
          email: 'patient@example.test',
          password: 'VeryStrongPass123',
          firstName: 'Ahmed',
          lastName: 'Ben Ali',
          dateOfBirth: DateTime.utc(1998, 4, 20),
          gender: 'M',
        );

        expect(await controller.startPhoneSignup(draft, '12345678'), isTrue);
        expect(controller.status, AuthStatus.authenticated);
        expect(controller.nextRoute, '/conversational-onboarding');
        expect(repo.signupInitiateCalls, 0);
        expect(repo.signupVerifyCalls, 0);
        expect(repo.signupCompleteCalls, 1);
      },
    );

    test(
      'OTP verification is unavailable while the feature is disabled',
      () async {
        final repo = FakeAuthRepository();
        final controller = AuthController(repository: repo);

        expect(await controller.verifyPhoneSignupOtp('123456'), isFalse);
        expect(repo.signupVerifyCalls, 0);
        expect(controller.status, AuthStatus.failure);
      },
    );

    test('duplicate phone signup exposes conflict message', () async {
      final repo = FakeAuthRepository()
        ..error = const ApiException(
          'This phone number is already linked to another account.',
          code: 'AUTH_PHONE_ALREADY_USED',
          statusCode: 409,
        );
      final controller = AuthController(repository: repo);
      final draft = PhoneSignupDraft(
        email: 'patient@example.test',
        password: 'VeryStrongPass123',
        firstName: 'Ahmed',
        lastName: 'Ben Ali',
        dateOfBirth: DateTime.utc(1998, 4, 20),
        gender: 'M',
      );

      expect(await controller.startPhoneSignup(draft, '12345678'), isFalse);

      expect(controller.status, AuthStatus.failure);
      expect(controller.errorCode, 'AUTH_PHONE_ALREADY_USED');
      expect(controller.errorMessage(_fr), 'Ce numéro est déjà utilisé.');
      expect(repo.signupInitiateCalls, 0);
      expect(repo.signupCompleteCalls, 1);
    });

    test(
      'google signup records phone and creates a session without OTP',
      () async {
        final repo = FakeAuthRepository()
          ..signupResult = _authenticated(onboardingCompleted: false);
        final controller = AuthController(repository: repo);

        expect(await controller.startGoogleAuth('google-id-token'), isTrue);
        expect(controller.status, AuthStatus.phoneRequired);
        expect(controller.hasPendingGoogleSignup, isTrue);
        expect(await controller.startGooglePhoneSignup('27 545 726'), isTrue);

        expect(controller.status, AuthStatus.authenticated);
        expect(controller.hasPendingGoogleSignup, isFalse);
        expect(controller.nextRoute, '/conversational-onboarding');
        expect(repo.googleInitiateCalls, 1);
        expect(repo.googlePhoneInitiateCalls, 0);
        expect(repo.googlePhoneVerifyCalls, 0);
        expect(repo.googleCompleteCalls, 1);
        expect(repo.lastGoogleCompletePhone, '+21627545726');
        expect(repo.signupInitiateCalls, 0);
        expect(repo.signupVerifyCalls, 0);
      },
    );

    test(
      'google existing email requires password link and preserves Doctor route',
      () async {
        final repo = FakeAuthRepository()
          ..googleResult = const GoogleAuthResult.requiresAccountLink(
            'd***@gmail.com',
          )
          ..googleLinkResult = _doctorSession();
        final controller = AuthController(repository: repo);

        expect(await controller.startGoogleAuth('google-id-token'), isTrue);
        expect(controller.status, AuthStatus.accountLinkRequired);
        expect(controller.hasPendingGoogleAccountLink, isTrue);
        expect(controller.pendingGoogleEmailHint, 'd***@gmail.com');

        expect(await controller.linkGoogleAccount('correct-password'), isTrue);
        expect(controller.status, AuthStatus.authenticated);
        expect(controller.nextRoute, '/doctor-dashboard');
        expect(controller.hasPendingGoogleAccountLink, isFalse);
        expect(repo.googleLinkCalls, 1);
      },
    );

    test('wrong Google link password retains the pending link state', () async {
      final repo = FakeAuthRepository()
        ..googleResult = const GoogleAuthResult.requiresAccountLink(
          'd***@gmail.com',
        )
        ..googleLinkError = const ApiException(
          'Incorrect password.',
          code: 'AUTH_GOOGLE_LINK_PASSWORD_INVALID',
          statusCode: 401,
        );
      final controller = AuthController(repository: repo);
      await controller.startGoogleAuth('google-id-token');

      expect(await controller.linkGoogleAccount('wrong-password'), isFalse);
      expect(controller.errorMessage(_fr), 'Mot de passe incorrect.');
      expect(controller.hasPendingGoogleAccountLink, isTrue);

      controller.cancelGoogleAccountLink();
      expect(controller.status, AuthStatus.unauthenticated);
      expect(controller.hasPendingGoogleAccountLink, isFalse);
      expect(repo.googleLinkCancelCalls, 1);
    });

    test('already-linked Google authenticates without link state', () async {
      final repo = FakeAuthRepository()
        ..googleResult = GoogleAuthResult.authenticated(_doctorSession());
      final controller = AuthController(repository: repo);

      expect(await controller.startGoogleAuth('google-id-token'), isTrue);
      expect(controller.isAuthenticated, isTrue);
      expect(controller.hasPendingGoogleAccountLink, isFalse);
      expect(repo.googleLinkCalls, 0);
    });

    test(
      'google phone signup duplicate phone exposes conflict message',
      () async {
        final repo = FakeAuthRepository();
        final controller = AuthController(repository: repo);

        expect(await controller.startGoogleAuth('google-id-token'), isTrue);
        repo.error = const ApiException(
          'This phone number is already linked to another account.',
          code: 'AUTH_PHONE_ALREADY_USED',
          statusCode: 409,
        );

        expect(await controller.startGooglePhoneSignup('27 545 726'), isFalse);

        expect(controller.status, AuthStatus.failure);
        expect(controller.errorCode, 'AUTH_PHONE_ALREADY_USED');
        expect(controller.errorMessage(_fr), 'Ce numéro est déjà utilisé.');
        expect(repo.googleInitiateCalls, 1);
        expect(repo.googlePhoneInitiateCalls, 0);
        expect(repo.googleCompleteCalls, 1);
      },
    );

    test('backend errors are exposed safely and logout clears state', () async {
      final repo = FakeAuthRepository()
        ..restoreResult = _authenticated(onboardingCompleted: true);
      final controller = AuthController(repository: repo);
      await controller.initialize();
      repo.error = const ApiException(
        'Invalid or expired OTP',
        code: 'AUTH_INVALID_OTP',
      );

      expect(
        await controller.loginWithEmailPassword(
          'patient@example.test',
          'VeryStrongPass123',
        ),
        isFalse,
      );
      expect(controller.errorCode, 'AUTH_INVALID_OTP');
      expect(controller.errorMessage(_fr), 'Code invalide ou expiré.');

      repo.error = null;
      await controller.logout();
      expect(controller.status, AuthStatus.unauthenticated);
      expect(controller.patientProfile, isNull);
      expect(repo.logoutCalls, 1);
    });
  });

  group('logout lifecycle ownership', () {
    test('Google token requests use the injected app-owned session', () async {
      final google = FakeGoogleSignInSession();
      final controller = AuthController(
        repository: FakeAuthRepository(),
        googleSignInSession: google,
      );

      expect(await controller.requestGoogleIdToken(), 'google-id-token');
      expect(google.signInCalls, 1);
    });

    test(
      'concurrent logout callers share one authoritative operation',
      () async {
        final repository = FakeAuthRepository()
          ..restoreResult = _doctorSession()
          ..logoutGate = Completer<void>();
        final google = FakeGoogleSignInSession()
          ..signOutGate = Completer<void>();
        final controller = AuthController(
          repository: repository,
          googleSignInSession: google,
        );
        await controller.initialize();

        final first = controller.logout();
        final second = controller.logout();

        expect(identical(first, second), isTrue);
        expect(repository.logoutCalls, 1);
        repository.logoutGate!.complete();
        await Future<void>.delayed(Duration.zero);

        expect(controller.status, AuthStatus.unauthenticated);
        expect(controller.currentUser, isNull);
        expect(controller.patientProfile, isNull);
        expect(google.signOutCalls, 1);

        google.signOutGate!.complete();
        await Future.wait([first, second]);
      },
    );

    test('provider sign-out failure cannot preserve OmniCare auth', () async {
      final repository = FakeAuthRepository()..restoreResult = _doctorSession();
      final google = FakeGoogleSignInSession()
        ..signOutError = StateError('provider unavailable');
      final controller = AuthController(
        repository: repository,
        googleSignInSession: google,
      );
      await controller.initialize();

      await controller.logout();

      expect(repository.logoutCalls, 1);
      expect(google.signOutCalls, 1);
      expect(controller.status, AuthStatus.unauthenticated);
      expect(controller.currentUser, isNull);
    });

    test('Doctor to Patient switch does not retain the prior role', () async {
      final repository = FakeAuthRepository()..restoreResult = _doctorSession();
      final google = FakeGoogleSignInSession();
      final controller = AuthController(
        repository: repository,
        googleSignInSession: google,
      );
      await controller.initialize();
      expect(controller.roleFamily, AuthRoleFamily.doctor);

      await controller.logout();
      repository.emailPasswordLoginResult =
          EmailPasswordLoginResult.authenticated(
            _authenticated(onboardingCompleted: true),
          );

      expect(
        await controller.loginWithEmailPassword(
          'patient@example.test',
          'VeryStrongPass123',
        ),
        isTrue,
      );
      expect(controller.roleFamily, AuthRoleFamily.patient);
      expect(controller.currentUser?.role, 'PATIENT');
      expect(google.signOutCalls, 1);
    });

    test(
      'logout drains and fences a concurrent refresh before local clear',
      () async {
        final store = SecureTokenStore(
          backend: FakeSecureTokenStorageBackend(),
        );
        await store.saveSession(_session());
        final refreshGate = Completer<void>();
        final adapter = FakeHttpAdapter({
          'POST /api/v1/auth/refresh': (_, _) async {
            await refreshGate.future;
            return _json(_loginJson(refreshToken: 'stale-refresh-token'), 200);
          },
          'POST /api/v1/auth/logout': (_, _) => _empty(204),
        });
        final client = _client(store, adapter);
        final repository = AuthRepository(
          api: AuthApi(client),
          tokenStore: store,
          deviceIdentityService: DeviceIdentityService(tokenStore: store),
          refreshCoordinator: client.refreshCoordinator,
        );

        final refresh = client.refreshCoordinator.refreshSession();
        for (var attempt = 0; attempt < 20; attempt += 1) {
          if (adapter.counts['POST /api/v1/auth/refresh'] == 1) break;
          await Future<void>.delayed(const Duration(milliseconds: 1));
        }
        final logout = repository.logout();

        expect(adapter.counts['POST /api/v1/auth/refresh'], 1);
        refreshGate.complete();

        await refresh;
        await logout;
        expect(adapter.counts['POST /api/v1/auth/logout'], 1);
        expect(await store.readSession(), isNull);
      },
    );
  });

  group('professional authentication milestone', () {
    testWidgets('patient choice opens the existing language entry', (
      tester,
    ) async {
      final auth = AuthController(repository: FakeAuthRepository());
      await tester.pumpWidget(_entryApp(auth));

      await tester.tap(find.text('Je suis patient'));
      await tester.pumpAndSettle();

      expect(find.text('Choose Your Language'), findsOneWidget);
    }, skip: true);

    testWidgets('professional choice opens credential form and back works', (
      tester,
    ) async {
      final auth = AuthController(repository: FakeAuthRepository());
      await tester.pumpWidget(_entryApp(auth));

      await tester.tap(find.text('Je suis professionnel de santé'));
      await tester.pumpAndSettle();
      expect(find.text('Connexion professionnelle'), findsOneWidget);
      expect(find.text('Adresse e-mail'), findsOneWidget);
      expect(find.text('Mot de passe'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2));
      final passwordInput = find.descendant(
        of: find.byType(TextFormField).at(1),
        matching: find.byType(EditableText),
      );
      expect(tester.widget<EditableText>(passwordInput).obscureText, isTrue);
      await tester.tap(find.byTooltip('Afficher le mot de passe'));
      await tester.pump();
      expect(tester.widget<EditableText>(passwordInput).obscureText, isFalse);

      await tester.tap(find.text('Retour').last);
      await tester.pumpAndSettle();
      expect(find.text('Bienvenue sur OmniCare'), findsOneWidget);
    }, skip: true);

    testWidgets('professional form shows validation and login errors inline', (
      tester,
    ) async {
      final repo = FakeAuthRepository()
        ..error = const ApiException(
          'Invalid login',
          code: 'AUTH_INVALID_CREDENTIALS',
        );
      final auth = AuthController(repository: repo);
      await tester.pumpWidget(_entryApp(auth));
      await tester.tap(find.text('Je suis professionnel de santé'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Se connecter'));
      await tester.pump();
      expect(find.text('Adresse e-mail requise'), findsOneWidget);
      expect(find.text('Mot de passe requis'), findsOneWidget);
      expect(repo.emailPasswordLoginCalls, 0);

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'doctor@example.test',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'Password123!');
      await tester.tap(find.text('Se connecter'));
      await tester.pumpAndSettle();
      expect(repo.emailPasswordLoginCalls, 1);
      expect(
        find.text('Une erreur est survenue. Veuillez réessayer.'),
        findsOneWidget,
      );
    }, skip: true);

    testWidgets('professional credential form uses backend role for Doctor', (
      tester,
    ) async {
      final repo = FakeAuthRepository()..loginResult = _doctorSession();
      final auth = AuthController(repository: repo);
      await tester.pumpWidget(_entryApp(auth));
      await tester.tap(find.text('Je suis professionnel de santé'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byType(TextFormField).at(0),
        'doctor@example.test',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'Password123!');
      await tester.tap(find.text('Se connecter'));
      await tester.pumpAndSettle();

      expect(repo.emailPasswordLoginCalls, 1);
      expect(auth.roleFamily, AuthRoleFamily.doctor);
      expect(auth.patientProfile, isNull);
      expect(find.text('Bonjour Docteur'), findsOneWidget);

      await tester.tap(find.text('Se déconnecter'));
      await tester.pumpAndSettle();
      expect(repo.logoutCalls, 1);
      expect(find.text('Bienvenue sur OmniCare'), findsOneWidget);
    }, skip: true);

    testWidgets('professional choice cannot turn a Patient into Doctor', (
      tester,
    ) async {
      final repo = FakeAuthRepository()
        ..loginResult = _authenticated(onboardingCompleted: true);
      final auth = AuthController(repository: repo);
      await tester.pumpWidget(_entryApp(auth));
      await tester.tap(find.text('Je suis professionnel de santé'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'patient@example.test',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'Password123!');
      await tester.tap(find.text('Se connecter'));
      await tester.pumpAndSettle();

      expect(auth.roleFamily, AuthRoleFamily.patient);
      expect(find.text('patient home'), findsOneWidget);
      expect(find.text('Bonjour Docteur'), findsNothing);
    }, skip: true);

    testWidgets('Doctor password-change requirement blocks the workspace', (
      tester,
    ) async {
      final repo = FakeAuthRepository()
        ..loginResult = _doctorSession(mustChangePassword: true);
      final auth = AuthController(repository: repo);
      await tester.pumpWidget(_entryApp(auth));
      await tester.tap(find.text('Je suis professionnel de santé'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'doctor@example.test',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'Password123!');
      await tester.tap(find.text('Se connecter'));
      await tester.pumpAndSettle();

      expect(auth.nextRoute, '/change-password-required');
      expect(find.text('Changer le mot de passe'), findsOneWidget);
      expect(find.text('Bonjour Docteur'), findsNothing);
    }, skip: true);

    testWidgets('unsupported professional role shows a sign-out state', (
      tester,
    ) async {
      final repo = FakeAuthRepository()
        ..error = const ApiException('Unsupported', code: 'UNSUPPORTED_ROLE');
      final auth = AuthController(repository: repo);
      await tester.pumpWidget(_entryApp(auth));
      await tester.tap(find.text('Je suis professionnel de santé'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'nurse@example.test',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'Password123!');
      await tester.tap(find.text('Se connecter'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          "Cet espace professionnel n'est pas encore disponible sur mobile.",
        ),
        findsOneWidget,
      );
      expect(find.text('Bonjour Docteur'), findsNothing);
      repo.error = null;
      await tester.tap(find.text('Se déconnecter'));
      await tester.pumpAndSettle();
      expect(repo.logoutCalls, 1);
      expect(find.text('Bienvenue sur OmniCare'), findsOneWidget);
    }, skip: true);

    test(
      'credentialed Doctor login, cold restore, and logout avoid profile',
      () async {
        final store = SecureTokenStore(
          backend: FakeSecureTokenStorageBackend(),
        );
        final adapter = FakeHttpAdapter({
          'POST /api/v1/auth/login': (_, _) =>
              _json(_emailPasswordLoginJson(role: 'DOCTOR'), 200),
          'GET /api/v1/auth/me': (_, _) => _json({
            'id': 'user-1',
            'role': 'DOCTOR',
            'sessionId': 'doctor-session',
            'mustChangePassword': false,
          }, 200),
          'POST /api/v1/auth/logout': (_, _) => _empty(204),
        });
        final client = _client(store, adapter);
        final repository = AuthRepository(
          api: AuthApi(client),
          tokenStore: store,
          deviceIdentityService: DeviceIdentityService(
            tokenStore: store,
            platformResolver: () => TargetPlatform.android,
            randomByteGenerator: (_) => 1,
          ),
          refreshCoordinator: client.refreshCoordinator,
        );
        final auth = AuthController(repository: repository);

        expect(
          await auth.loginWithEmailPassword('doctor@example.test', 'pass'),
          isTrue,
        );
        expect(auth.nextRoute, '/doctor-dashboard');
        expect(auth.patientProfile, isNull);
        expect((await store.readSession())!.userRole, 'DOCTOR');
        final restored = AuthController(repository: repository);
        await restored.initialize();
        expect(restored.nextRoute, '/doctor-dashboard');
        expect(adapter.counts['GET /api/v1/auth/me'], 2);
        expect(adapter.counts['GET /api/v1/profile'], isNull);

        await restored.logout();
        expect(adapter.counts['POST /api/v1/auth/logout'], 1);
        expect(await store.readSession(), isNull);
      },
    );

    test('Patient email login still loads profile and restores home', () async {
      final store = SecureTokenStore(backend: FakeSecureTokenStorageBackend());
      final adapter = FakeHttpAdapter({
        'POST /api/v1/auth/login': (_, _) =>
            _json(_emailPasswordLoginJson(), 200),
        'GET /api/v1/auth/me': (_, _) => _json({
          'id': 'user-1',
          'role': 'PATIENT',
          'sessionId': 'patient-session',
        }, 200),
        'GET /api/v1/profile': (_, _) =>
            _json(_profileJson(onboardingCompleted: true), 200),
      });
      final client = _client(store, adapter);
      final repository = AuthRepository(
        api: AuthApi(client),
        tokenStore: store,
        deviceIdentityService: DeviceIdentityService(
          tokenStore: store,
          platformResolver: () => TargetPlatform.android,
          randomByteGenerator: (_) => 1,
        ),
        refreshCoordinator: client.refreshCoordinator,
      );
      final auth = AuthController(repository: repository);

      expect(
        await auth.loginWithEmailPassword('patient@example.test', 'pass'),
        isTrue,
      );
      expect(auth.nextRoute, '/home');
      expect(adapter.counts['GET /api/v1/profile'], 1);
      final restored = AuthController(repository: repository);
      await restored.initialize();
      expect(restored.nextRoute, '/home');
      expect(adapter.counts['GET /api/v1/profile'], 2);
    });

    test(
      'login payload role cannot override Patient role from /auth/me',
      () async {
        final store = SecureTokenStore(
          backend: FakeSecureTokenStorageBackend(),
        );
        final adapter = FakeHttpAdapter({
          'POST /api/v1/auth/login': (_, _) =>
              _json(_emailPasswordLoginJson(role: 'DOCTOR'), 200),
          'GET /api/v1/auth/me': (_, _) => _json({
            'id': 'user-1',
            'role': 'PATIENT',
            'sessionId': 'patient-session',
          }, 200),
          'GET /api/v1/profile': (_, _) =>
              _json(_profileJson(onboardingCompleted: false), 200),
        });
        final client = _client(store, adapter);
        final auth = AuthController(
          repository: AuthRepository(
            api: AuthApi(client),
            tokenStore: store,
            deviceIdentityService: DeviceIdentityService(
              tokenStore: store,
              platformResolver: () => TargetPlatform.android,
              randomByteGenerator: (_) => 1,
            ),
            refreshCoordinator: client.refreshCoordinator,
          ),
        );

        expect(
          await auth.loginWithEmailPassword('patient@example.test', 'pass'),
          isTrue,
        );
        expect(auth.nextRoute, '/conversational-onboarding');
        expect((await store.readSession())!.userRole, 'PATIENT');
        expect(adapter.counts['GET /api/v1/profile'], 1);
      },
    );

    test(
      'Doctor expired access refreshes then restores authoritative role',
      () async {
        final store = SecureTokenStore(
          backend: FakeSecureTokenStorageBackend(),
        );
        await store.saveSession(
          _session(
            role: 'DOCTOR',
            accessExpiresAt: DateTime.now().toUtc().subtract(
              const Duration(minutes: 1),
            ),
          ),
        );
        final adapter = FakeHttpAdapter({
          'POST /api/v1/auth/refresh': (_, _) => _json(
            _loginJson(
              role: 'DOCTOR',
              accessToken: 'rotated-doctor-access',
              refreshToken: 'rotated-doctor-refresh',
            ),
            200,
          ),
          'GET /api/v1/auth/me': (_, _) => _json({
            'id': 'user-1',
            'role': 'DOCTOR',
            'sessionId': 'doctor-session',
          }, 200),
        });
        final client = _client(store, adapter);
        final auth = AuthController(
          repository: AuthRepository(
            api: AuthApi(client),
            tokenStore: store,
            deviceIdentityService: DeviceIdentityService(tokenStore: store),
            refreshCoordinator: client.refreshCoordinator,
          ),
        );

        await auth.initialize();
        expect(auth.nextRoute, '/doctor-dashboard');
        expect(
          (await store.readSession())!.refreshToken,
          'rotated-doctor-refresh',
        );
        expect(adapter.counts['POST /api/v1/auth/refresh'], 1);
        expect(adapter.counts['GET /api/v1/profile'], isNull);
      },
    );

    test('Doctor refresh failure clears session', () async {
      final store = SecureTokenStore(backend: FakeSecureTokenStorageBackend());
      await store.saveSession(
        _session(
          role: 'DOCTOR',
          accessExpiresAt: DateTime.now().toUtc().subtract(
            const Duration(minutes: 1),
          ),
        ),
      );
      final adapter = FakeHttpAdapter({
        'POST /api/v1/auth/refresh': (_, _) => _json({
          'code': 'AUTH_REFRESH_TOKEN_INVALID',
          'message': 'Invalid refresh',
        }, 401),
      });
      final client = _client(store, adapter);
      final auth = AuthController(
        repository: AuthRepository(
          api: AuthApi(client),
          tokenStore: store,
          deviceIdentityService: DeviceIdentityService(tokenStore: store),
          refreshCoordinator: client.refreshCoordinator,
        ),
      );

      await auth.initialize();
      expect(auth.isAuthenticated, isFalse);
      expect(auth.nextRoute, isNull);
      expect(await store.readSession(), isNull);
    });

    test('Doctor forced password change keeps the existing gate', () async {
      final repo = FakeAuthRepository()
        ..loginResult = _doctorSession(mustChangePassword: true);
      final auth = AuthController(repository: repo);

      expect(
        await auth.loginWithEmailPassword('doctor@example.test', 'pass'),
        isTrue,
      );
      expect(auth.nextRoute, '/change-password-required');
      expect(await auth.changeRequiredPassword('old', 'new'), isTrue);
      expect(auth.isAuthenticated, isFalse);
      expect(repo.changePasswordCalls, 1);
    });
  });

  group('startup routing', () {
    testWidgets('transient restore failure stays recoverable on splash', (
      tester,
    ) async {
      final repo = FakeAuthRepository()
        ..error = const ApiException(
          'Network unavailable.',
          code: 'AUTH_REFRESH_TEMPORARILY_UNAVAILABLE',
        );
      final controller = AuthController(repository: repo);
      await controller.initialize();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthController>.value(value: controller),
            ChangeNotifierProvider(create: (_) => UserProvider()),
          ],
          child: MaterialApp(
            localizationsDelegates: OmniLocalizations.localizationsDelegates,
            supportedLocales: OmniLocalizations.supportedLocales,
            home: const SplashScreen(),
            routes: {
              '/login': (_) => const Text('login route'),
              '/home': (_) => const Text('home route'),
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('splash-retry-session')), findsOneWidget);
      expect(find.text('login route'), findsNothing);

      repo
        ..error = null
        ..restoreResult = _authenticated(onboardingCompleted: true);
      await tester.tap(find.byKey(const Key('splash-retry-session')));
      await tester.pumpAndSettle();

      expect(find.text('home route'), findsOneWidget);
      expect(repo.restoreCalls, 2);
    });

    testWidgets('unauthenticated splash routes to the unified login', (
      tester,
    ) async {
      final controller = AuthController(repository: FakeAuthRepository());
      await controller.initialize();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthController>.value(value: controller),
            ChangeNotifierProvider(create: (_) => UserProvider()),
          ],
          child: MaterialApp(
            localizationsDelegates: OmniLocalizations.localizationsDelegates,
            supportedLocales: OmniLocalizations.supportedLocales,
            home: const SplashScreen(),
            routes: {
              '/login': (_) => const Text('unified login route'),
              '/auth-entry': (_) => const Text('legacy auth entry route'),
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('unified login route'), findsOneWidget);
      expect(find.text('legacy auth entry route'), findsNothing);
    });

    testWidgets('unified login opens the professional request action', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: OmniLocalizations.localizationsDelegates,
          supportedLocales: OmniLocalizations.supportedLocales,
          home: const LoginScreen(),
          routes: {
            '/professional-access-request': (_) =>
                const Scaffold(body: Text('professional request form')),
          },
        ),
      );
      await tester.pump();
      final professionalRequestLink = find.text(
        'Professionnel de santé ? Demander à rejoindre OmniCare',
        findRichText: true,
      );
      await tester.ensureVisible(professionalRequestLink);
      await tester.tap(professionalRequestLink);
      await tester.pumpAndSettle();

      expect(find.text('professional request form'), findsOneWidget);
    });

    testWidgets('Google existing-email state shows compact account-link UI', (
      tester,
    ) async {
      final repo = FakeAuthRepository()
        ..googleResult = const GoogleAuthResult.requiresAccountLink(
          'd***@gmail.com',
        );
      final controller = AuthController(repository: repo);
      await controller.startGoogleAuth('google-id-token');

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthController>.value(
          value: controller,
          child: const MaterialApp(
            localizationsDelegates: OmniLocalizations.localizationsDelegates,
            supportedLocales: OmniLocalizations.supportedLocales,
            home: Scaffold(body: GoogleAccountLinkSheet()),
          ),
        ),
      );

      expect(find.text('Associer votre compte Google'), findsOneWidget);
      expect(find.byKey(const Key('google-link-email-hint')), findsOneWidget);
      expect(find.text('d***@gmail.com'), findsOneWidget);
      expect(find.text('Associer et continuer'), findsOneWidget);
      expect(find.text('Annuler'), findsOneWidget);
    });

    testWidgets('wrong Google link password stays in UI and cancel clears it', (
      tester,
    ) async {
      final repo = FakeAuthRepository()
        ..googleResult = const GoogleAuthResult.requiresAccountLink(
          'd***@gmail.com',
        )
        ..googleLinkError = const ApiException(
          'Incorrect password.',
          code: 'AUTH_GOOGLE_LINK_PASSWORD_INVALID',
          statusCode: 401,
        );
      final controller = AuthController(repository: repo);
      await controller.startGoogleAuth('google-id-token');

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthController>.value(
          value: controller,
          child: const MaterialApp(
            localizationsDelegates: OmniLocalizations.localizationsDelegates,
            supportedLocales: OmniLocalizations.supportedLocales,
            home: Scaffold(body: GoogleAccountLinkSheet()),
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const Key('google-link-password')),
        'wrong-password',
      );
      await tester.tap(find.byKey(const Key('google-link-submit')));
      await tester.pumpAndSettle();

      expect(find.text('Mot de passe incorrect.'), findsOneWidget);
      expect(controller.hasPendingGoogleAccountLink, isTrue);

      await tester.tap(find.byKey(const Key('google-link-cancel')));
      await tester.pumpAndSettle();
      expect(controller.status, AuthStatus.unauthenticated);
      expect(repo.googleLinkCancelCalls, 1);
    });

    testWidgets('expired Google link challenge offers explicit Google retry', (
      tester,
    ) async {
      final repo = FakeAuthRepository()
        ..googleResult = const GoogleAuthResult.requiresAccountLink(
          'd***@gmail.com',
        )
        ..googleLinkError = const ApiException(
          'Expired.',
          code: 'AUTH_GOOGLE_LINK_EXPIRED',
          statusCode: 401,
        );
      final controller = AuthController(repository: repo);
      await controller.startGoogleAuth('google-id-token');

      await tester.pumpWidget(
        ChangeNotifierProvider<AuthController>.value(
          value: controller,
          child: const MaterialApp(
            localizationsDelegates: OmniLocalizations.localizationsDelegates,
            supportedLocales: OmniLocalizations.supportedLocales,
            home: Scaffold(body: GoogleAccountLinkSheet()),
          ),
        ),
      );
      await tester.enterText(
        find.byKey(const Key('google-link-password')),
        'password',
      );
      await tester.tap(find.byKey(const Key('google-link-submit')));
      await tester.pumpAndSettle();

      expect(
        find.text('Cette tentative d’association a expiré.'),
        findsOneWidget,
      );
      expect(find.text('Réessayer avec Google'), findsOneWidget);
      await tester.tap(find.byKey(const Key('google-link-retry')));
      await tester.pumpAndSettle();
      expect(controller.status, AuthStatus.unauthenticated);
      expect(controller.hasPendingGoogleAccountLink, isFalse);
      expect(repo.googleLinkCancelCalls, 1);
    });

    testWidgets('professional request submission shows the success UX', (
      tester,
    ) async {
      final api = ProfessionalAccessRequestApi(
        _client(
          SecureTokenStore(backend: FakeSecureTokenStorageBackend()),
          FakeHttpAdapter({
            'POST /api/v1/professional-access-requests': (options, count) =>
                _json({
                  'requestId': 'request-1',
                  'status': 'PENDING',
                  'submittedAt': '2026-09-23T10:00:00Z',
                }, 201),
          }),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: OmniLocalizations.localizationsDelegates,
          supportedLocales: OmniLocalizations.supportedLocales,
          routes: {'/login': (_) => const Text('unified login')},
          home: ProfessionalAccessRequestScreen(api: api),
        ),
      );

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'Médecin');
      await tester.enterText(fields.at(1), 'Amina');
      await tester.enterText(fields.at(2), 'Ben Salem');
      await tester.enterText(fields.at(3), 'amina@example.test');
      await tester.enterText(fields.at(4), '+21612345678');
      await tester.enterText(fields.at(5), 'MED-123');
      await tester.ensureVisible(find.text('Envoyer ma demande'));
      await tester.tap(find.text('Envoyer ma demande'));
      await tester.pumpAndSettle();

      expect(find.text('Demande envoyée'), findsOneWidget);
      expect(find.text('Retour à la connexion'), findsOneWidget);
      await tester.tap(find.text('Retour à la connexion'));
      await tester.pumpAndSettle();
      expect(find.text('unified login'), findsOneWidget);
    });

    testWidgets('/login is registered', (tester) async {
      final controller = AuthController(repository: FakeAuthRepository());
      await controller.initialize();

      await tester.pumpWidget(OmniCareApp(authController: controller));

      final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(app.routes, containsPair('/login', isA<WidgetBuilder>()));
    });

    testWidgets('validated home route is pushed once across rebuilds', (
      tester,
    ) async {
      final repo = FakeAuthRepository()
        ..restoreResult = _authenticated(onboardingCompleted: true);
      final controller = AuthController(repository: repo);
      await controller.initialize();
      final observer = CountingNavigatorObserver();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthController>.value(value: controller),
            ChangeNotifierProvider(create: (_) => UserProvider()),
          ],
          child: MaterialApp(
            localizationsDelegates: OmniLocalizations.localizationsDelegates,
            supportedLocales: OmniLocalizations.supportedLocales,
            navigatorObservers: [observer],
            home: const SplashScreen(),
            routes: {
              '/home': (_) => const Text('home route'),
              '/conversational-onboarding': (_) =>
                  const Text('onboarding route'),
              '/login': (_) => const Text('login route'),
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump();
      await tester.pump();

      expect(find.text('home route'), findsOneWidget);
      expect(
        observer.pushedRouteNames.where((name) => name == '/home'),
        hasLength(1),
      );
    });

    testWidgets('validated incomplete profile routes to onboarding once', (
      tester,
    ) async {
      final repo = FakeAuthRepository()
        ..restoreResult = _authenticated(onboardingCompleted: false);
      final controller = AuthController(repository: repo);
      await controller.initialize();
      final observer = CountingNavigatorObserver();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthController>.value(value: controller),
            ChangeNotifierProvider(create: (_) => UserProvider()),
          ],
          child: MaterialApp(
            localizationsDelegates: OmniLocalizations.localizationsDelegates,
            supportedLocales: OmniLocalizations.supportedLocales,
            navigatorObservers: [observer],
            home: const SplashScreen(),
            routes: {
              '/home': (_) => const Text('home route'),
              '/conversational-onboarding': (_) =>
                  const Text('onboarding route'),
              '/login': (_) => const Text('login route'),
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump();

      expect(find.text('onboarding route'), findsOneWidget);
      expect(
        observer.pushedRouteNames.where(
          (name) => name == '/conversational-onboarding',
        ),
        hasLength(1),
      );
    });

    testWidgets('auth entry remains scrollable at supported phone widths', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      final controller = AuthController(repository: FakeAuthRepository());
      const sizes = [Size(360, 520), Size(390, 640), Size(430, 720)];

      for (final size in sizes) {
        tester.view.physicalSize = size;
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<AuthController>.value(value: controller),
              ChangeNotifierProvider(create: (_) => UserProvider()),
            ],
            child: MaterialApp(
              localizationsDelegates: OmniLocalizations.localizationsDelegates,
              supportedLocales: OmniLocalizations.supportedLocales,
              theme: buildOmniTheme(),
              routes: {
                '/professional-access-request': (_) => const Text('request'),
              },
              home: const LoginScreen(),
            ),
          ),
        );

        final professionalAction = find.byWidgetPredicate(
          (widget) =>
              widget is RichText &&
              widget.text.toPlainText().contains(
                'Demander à rejoindre OmniCare',
              ),
        );
        await tester.ensureVisible(professionalAction);
        await tester.pumpAndSettle();
        expect(professionalAction, findsOneWidget);
      }
    });

    testWidgets('patient signup CTA remains reachable on a small phone', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 520);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      final controller = AuthController(repository: FakeAuthRepository());
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<AuthController>.value(value: controller),
            ChangeNotifierProvider(create: (_) => UserProvider()),
          ],
          child: MaterialApp(
            localizationsDelegates: OmniLocalizations.localizationsDelegates,
            supportedLocales: OmniLocalizations.supportedLocales,
            theme: buildOmniTheme(),
            home: const SignupScreen(),
          ),
        ),
      );

      // G3-P2b: sign-up runs in steps; exactly one primary action is
      // visible on the current step (the pinned « Continuer »).
      final cta = find.byType(ElevatedButton).hitTestable();
      await tester.ensureVisible(cta);
      await tester.pumpAndSettle();
      expect(cta, findsOneWidget);
      expect(tester.getSize(cta).width, greaterThan(300));
    });
  });
}
