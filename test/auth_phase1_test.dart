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
import 'package:omnicare_mobile/core/network/app_http_client.dart';
import 'package:omnicare_mobile/core/network/auth_interceptor.dart';
import 'package:omnicare_mobile/core/models/patient_profile.dart';
import 'package:omnicare_mobile/core/storage/secure_token_store.dart';
import 'package:omnicare_mobile/features/auth/application/auth_controller.dart';
import 'package:omnicare_mobile/features/auth/application/auth_error_messages.dart';
import 'package:omnicare_mobile/features/auth/application/auth_flow_models.dart';
import 'package:omnicare_mobile/features/auth/splash_screen.dart';
import 'package:omnicare_mobile/features/auth/data/auth_api.dart';
import 'package:omnicare_mobile/features/auth/data/auth_repository.dart';
import 'package:omnicare_mobile/features/auth/data/models/auth_dtos.dart';
import 'package:omnicare_mobile/main.dart';
import 'package:omnicare_mobile/providers/user_provider.dart';

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
  int googleInitiateCalls = 0;
  int googlePhoneInitiateCalls = 0;
  int googlePhoneVerifyCalls = 0;
  int googleCompleteCalls = 0;
  int changePasswordCalls = 0;
  int logoutCalls = 0;
  AuthenticatedPatientSession? restoreResult;
  AuthenticatedPatientSession? loginResult;
  AuthenticatedPatientSession? signupResult;
  EmailPasswordLoginResult? emailPasswordLoginResult;
  GoogleAuthResult? googleResult;
  Object? error;
  Completer<void>? restoreGate;
  Completer<void>? loginInitiateGate;
  Completer<void>? signupVerifyGate;

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
    bool rememberDevice = false,
  }) async {
    googleCompleteCalls += 1;
    if (error != null) throw error!;
    return signupResult ?? _authenticated(onboardingCompleted: false);
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
}) {
  return StoredSession(
    accessToken: accessToken,
    refreshToken: refreshToken,
    accessTokenExpiresAt: accessExpiresAt ?? DateTime.utc(2026, 7, 18, 12),
    refreshTokenExpiresAt: refreshExpiresAt ?? DateTime.utc(2026, 8, 18, 12),
    userId: 'user-1',
    userRole: 'PATIENT',
    sessionId: 'session-1',
  );
}

Map<String, dynamic> _loginJson({
  String accessToken = 'new-access-token',
  String refreshToken = 'new-refresh-token',
}) {
  return {
    'accessToken': accessToken,
    'tokenType': 'Bearer',
    'expiresAt': '2026-07-17T18:30:00Z',
    'refreshToken': refreshToken,
    'refreshExpiresAt': '2026-08-16T18:00:00Z',
    'user': {'id': 'user-1', 'role': 'PATIENT', 'mustChangePassword': false},
  };
}

Map<String, dynamic> _emailPasswordLoginJson({
  String accessToken = 'new-access-token',
  String refreshToken = 'new-refresh-token',
}) {
  return {
    'status': 'AUTHENTICATED',
    'session': _loginJson(accessToken: accessToken, refreshToken: refreshToken),
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

void main() {
  group('DTOs', () {
    test('parse login/profile/error responses and redact tokens', () {
      final login = LoginResponseDto.fromJson(_loginJson());
      final current = CurrentUserDto.fromJson({
        'id': 'user-1',
        'role': 'PATIENT',
        'sessionId': 'session-1',
        'mustChangePassword': true,
      });
      final profile = PatientProfile.fromJson(
        _profileJson(onboardingCompleted: false),
      );
      final error = ApiErrorResponse.fromJson({
        'code': 'AUTH_INVALID_OTP',
        'message': 'Invalid or expired OTP',
        'timestamp': '2026-07-17T18:00:00Z',
        'fieldErrors': {'otp': 'invalid'},
      });

      expect(login.expiresAt, DateTime.utc(2026, 7, 17, 18, 30));
      expect(login.user.mustChangePassword, isFalse);
      expect(current.mustChangePassword, isTrue);
      expect(login.toString(), isNot(contains('new-access-token')));
      expect(login.toString(), contains('<redacted>'));
      expect(profile.dateOfBirth, DateTime.utc(1998, 4, 20));
      expect(profile.onboardingCompleted, isFalse);
      expect(error.code, 'AUTH_INVALID_OTP');
      expect(error.fieldErrors['otp'], 'invalid');
    });

    test('missing required token fields are rejected', () {
      final json = _loginJson()..remove('accessToken');
      expect(() => LoginResponseDto.fromJson(json), throwsFormatException);
    });
  });

  group('AuthErrorMessages', () {
    test('maps signup and OTP backend errors to specific messages', () {
      expect(
        AuthErrorMessages.fromCode('AUTH_PHONE_ALREADY_USED'),
        'Ce numéro est déjà utilisé.',
      );
      expect(
        AuthErrorMessages.fromCode('AUTH_EMAIL_ALREADY_USED'),
        'Cette adresse e-mail est déjà utilisée.',
      );
      expect(
        AuthErrorMessages.fromCode('DUPLICATE_IDENTITY'),
        'Un compte existe déjà avec ces informations.',
      );
      expect(
        AuthErrorMessages.fromCode('AUTH_INVALID_OTP'),
        'Code invalide ou expiré.',
      );
      expect(
        AuthErrorMessages.fromCode('TOO_MANY_REQUESTS'),
        'Trop de tentatives. Réessayez plus tard.',
      );
      expect(
        AuthErrorMessages.fromCode('AUTH_PROVIDER_UNAVAILABLE'),
        'Service de vérification temporairement indisponible. Réessayez plus tard.',
      );
      expect(
        AuthErrorMessages.fromCode('AUTH_GOOGLE_SIGNUP_EXPIRED'),
        'Session Google expirée. Recommencez avec Google.',
      );
      expect(
        AuthErrorMessages.fromCode('AUTH_GOOGLE_SIGNUP_INVALID'),
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
      expect(await store.readSession(), isNull);
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
            deviceFingerprint: 'installation-id',
            platform: ClientPlatform.web,
            deviceLabel: 'Web browser',
            sharedDevice: false,
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

    test('concurrent 401 responses share one refresh future', () async {
      final store = SecureTokenStore(backend: FakeSecureTokenStorageBackend());
      await store.saveSession(_session());
      final refreshCompleter = Completer<ResponseBody>();
      final adapter = FakeHttpAdapter({
        'GET /api/v1/profile': (_, count) => count <= 2
            ? _json({'code': 'AUTH_SESSION_INVALID', 'message': 'expired'}, 401)
            : _json(_profileJson(onboardingCompleted: true), 200),
        'POST /api/v1/auth/refresh': (_, _) => refreshCompleter.future,
      });
      final client = _client(store, adapter);
      final api = AuthApi(client);

      final first = api.getPatientProfile();
      final second = api.getPatientProfile();
      await Future<void>.delayed(Duration.zero);
      refreshCompleter.complete(_json(_loginJson(), 200));

      await Future.wait([first, second]);
      expect(adapter.counts['POST /api/v1/auth/refresh'], 1);
    });

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
      'logout 401 refreshes once, retries logout, and clears session',
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
        expect(adapter.counts['POST /api/v1/auth/logout'], 2);
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
        final session = await repository.completeGoogleSignup();

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
          containsPair('signupToken', 'opaque-signup-token'),
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

    test('phone login state progression and duplicate submit guard', () async {
      final repo = FakeAuthRepository()
        ..loginResult = _authenticated(onboardingCompleted: true);
      final controller = AuthController(repository: repo);

      expect(await controller.startPhoneLogin('12 345 678'), isTrue);
      expect(controller.status, AuthStatus.otpRequired);
      expect(await controller.verifyPhoneLoginOtp('123456'), isTrue);
      expect(controller.nextRoute, '/home');
      expect(repo.loginInitiateCalls, 1);
      expect(repo.loginVerifyCalls, 1);
    });

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

    test('email password login can require phone OTP before session', () async {
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
        isTrue,
      );

      expect(repo.emailPasswordLoginCalls, 1);
      expect(controller.status, AuthStatus.otpRequired);
      expect(controller.pendingFlow, AuthFlowMode.login);
      expect(controller.pendingPhone, '+21612345678');
      expect(controller.currentUser, isNull);
      expect(controller.nextRoute, isNull);
    });

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

    test('in-flight phone submit ignores fast second tap', () async {
      final gate = Completer<void>();
      final repo = FakeAuthRepository()..loginInitiateGate = gate;
      final controller = AuthController(repository: repo);

      final first = controller.startPhoneLogin('12 345 678');
      final second = await controller.startPhoneLogin('12 345 678');
      gate.complete();

      expect(second, isFalse);
      expect(await first, isTrue);
      expect(repo.loginInitiateCalls, 1);
      expect(controller.status, AuthStatus.otpRequired);
    });

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
        expect(controller.status, AuthStatus.otpRequired);
        expect(await controller.verifyPhoneSignupOtp('123456'), isTrue);
        expect(controller.nextRoute, '/conversational-onboarding');
        expect(repo.signupInitiateCalls, 1);
        expect(repo.signupVerifyCalls, 1);
      },
    );

    test('in-flight OTP verification ignores fast second tap', () async {
      final gate = Completer<void>();
      final repo = FakeAuthRepository()
        ..signupResult = _authenticated(onboardingCompleted: false)
        ..signupVerifyGate = gate;
      final controller = AuthController(repository: repo);
      final draft = PhoneSignupDraft(
        email: 'patient@example.test',
        password: 'VeryStrongPass123',
        firstName: 'Ahmed',
        lastName: 'Ben Ali',
        dateOfBirth: DateTime.utc(1998, 4, 20),
        gender: 'M',
      );
      await controller.startPhoneSignup(draft, '12345678');

      final first = controller.verifyPhoneSignupOtp('123456');
      final second = await controller.verifyPhoneSignupOtp('123456');
      gate.complete();

      expect(second, isFalse);
      expect(await first, isTrue);
      expect(repo.signupVerifyCalls, 1);
      expect(controller.status, AuthStatus.authenticated);
    });

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
      expect(controller.errorMessage, 'Ce numéro est déjà utilisé.');
      expect(repo.signupInitiateCalls, 1);
    });

    test(
      'google signup verifies phone and creates an authenticated session',
      () async {
        final repo = FakeAuthRepository()
          ..signupResult = _authenticated(onboardingCompleted: false);
        final controller = AuthController(repository: repo);

        expect(await controller.startGoogleAuth('google-id-token'), isTrue);
        expect(controller.status, AuthStatus.otpRequired);
        expect(controller.hasPendingGoogleSignup, isTrue);
        expect(await controller.startGooglePhoneSignup('27 545 726'), isTrue);
        expect(controller.pendingPhone, '+21627545726');
        expect(await controller.verifyPhoneSignupOtp('123456'), isTrue);

        expect(controller.status, AuthStatus.authenticated);
        expect(controller.hasPendingGoogleSignup, isFalse);
        expect(controller.nextRoute, '/conversational-onboarding');
        expect(repo.googleInitiateCalls, 1);
        expect(repo.googlePhoneInitiateCalls, 1);
        expect(repo.googlePhoneVerifyCalls, 1);
        expect(repo.googleCompleteCalls, 1);
        expect(repo.signupInitiateCalls, 0);
        expect(repo.signupVerifyCalls, 0);
      },
    );

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
        expect(controller.errorMessage, 'Ce numéro est déjà utilisé.');
        expect(repo.googleInitiateCalls, 1);
        expect(repo.googlePhoneInitiateCalls, 1);
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

      expect(await controller.startPhoneLogin('12345678'), isFalse);
      expect(controller.errorCode, 'AUTH_INVALID_OTP');
      expect(controller.errorMessage, 'Code invalide ou expiré.');

      repo.error = null;
      await controller.logout();
      expect(controller.status, AuthStatus.unauthenticated);
      expect(controller.patientProfile, isNull);
      expect(repo.logoutCalls, 1);
    });
  });

  group('startup routing', () {
    testWidgets('unauthenticated splash routes to language selection', (
      tester,
    ) async {
      final controller = AuthController(repository: FakeAuthRepository());
      await controller.initialize();

      await tester.pumpWidget(OmniCareApp(authController: controller));
      await tester.pumpAndSettle();

      expect(find.text('Choose Your Language'), findsOneWidget);
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
  });
}
