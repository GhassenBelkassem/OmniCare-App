import 'package:dio/dio.dart';

import '../utils/logger.dart';
import 'dio_client.dart';
import '../auth/token_storage.dart';

class AuthLoginResult {
  final String accessToken;
  final String email;
  final String? phoneNumber;
  final bool emailVerified;
  final bool phoneVerified;
  final bool onboardingComplete;

  AuthLoginResult({
    required this.accessToken,
    required this.email,
    required this.phoneNumber,
    required this.emailVerified,
    required this.phoneVerified,
    required this.onboardingComplete,
  });
}

class AuthApi {
  final Dio _dio;

  AuthApi({Dio? dio}) : _dio = dio ?? DioClient.instance.dio;

  Future<void> register({
    required String email,
    required String password,
    String? name,
  }) async {
    final payload = {
      'email': email,
      'password': password,
      if (name != null) 'name': name,
    };

    AppLogger.api('register payload=$payload');
    await _dio.post('/auth/register', data: payload);
  }

  Future<void> verifyEmailOtp({
    required String email,
    required String code,
  }) async {
    final payload = {
      'email': email,
      'code': code,
    };

    AppLogger.api('verifyEmailOtp payload=$payload');
    await _dio.post('/auth/verify-email-otp', data: payload);
  }

  Future<void> setPhone({
    required String email,
    required String phoneNumber,
  }) async {
    final payload = {
      'email': email,
      'phoneNumber': phoneNumber,
    };

    AppLogger.api('setPhone payload=$payload');
    await _dio.post('/auth/set-phone', data: payload);
  }

  Future<String?> requestPhoneOtp({
    required String phoneNumber,
  }) async {
    final payload = {
      'phoneNumber': phoneNumber,
    };

    AppLogger.api('requestPhoneOtp payload=$payload');
    final res = await _dio.post('/auth/request-phone-otp', data: payload);

    final data = res.data;
    if (data is Map) {
      final otp = data['otp']?.toString();
      if (otp != null && otp.isNotEmpty) {
        return otp;
      }
    }
    return null;
  }

  Future<void> verifyPhoneOtp({
    required String phoneNumber,
    required String otp,
  }) async {
    final payload = {
      'phoneNumber': phoneNumber,
      'otp': otp,
    };

    AppLogger.api('verifyPhoneOtp payload=$payload');
    await _dio.post('/auth/verify-phone-otp', data: payload);
  }

  Future<String> login({
    required String email,
    required String password,
  }) async {
    final payload = {
      'email': email,
      'password': password,
    };

    AppLogger.api('login payload=$payload');
    final res = await _dio.post('/auth/login', data: payload);

    final data = res.data;
    if (data is Map<String, dynamic>) {
      final wrappedToken = (data['data'] is Map)
          ? ((data['data'] as Map)['accessToken']?.toString())
          : null;
      final legacyToken = data['token']?.toString();
      final token = (wrappedToken != null && wrappedToken.isNotEmpty)
          ? wrappedToken
          : (legacyToken ?? '');

      if (token.isNotEmpty) {
        await TokenStorage.saveJwt(token);
        return token;
      }
    }

    throw StateError('Unexpected /auth/login response: ${res.data}');
  }

  Future<AuthLoginResult> loginWithStatus({
    required String email,
    required String password,
  }) async {
    final payload = {
      'email': email,
      'password': password,
    };

    AppLogger.api('login payload=$payload');
    final res = await _dio.post('/auth/login', data: payload);

    final data = res.data;
    if (data is Map<String, dynamic> && data['data'] is Map) {
      final wrapped = data['data'] as Map;
      final accessToken = wrapped['accessToken']?.toString() ?? '';
      if (accessToken.isEmpty) {
        throw StateError('Unexpected /auth/login response: ${res.data}');
      }

      await TokenStorage.saveJwt(accessToken);

      final user = (wrapped['user'] is Map) ? (wrapped['user'] as Map) : const {};
      return AuthLoginResult(
        accessToken: accessToken,
        email: user['email']?.toString() ?? email,
        phoneNumber: user['phoneNumber']?.toString(),
        emailVerified: user['emailVerified'] == true,
        phoneVerified: user['phoneVerified'] == true,
        onboardingComplete: user['onboardingComplete'] == true,
      );
    }

    throw StateError('Unexpected /auth/login response: ${res.data}');
  }

  Future<String> googleLogin({
    required String idToken,
  }) async {
    final payload = {
      'idToken': idToken,
    };

    AppLogger.api('googleLogin payload=[idToken redacted]');
    final res = await _dio.post('/auth/google', data: payload);

    final data = res.data;
    if (data is Map<String, dynamic>) {
      final wrappedToken = (data['data'] is Map)
          ? ((data['data'] as Map)['accessToken']?.toString())
          : null;
      final legacyToken = data['token']?.toString();
      final token = (wrappedToken != null && wrappedToken.isNotEmpty)
          ? wrappedToken
          : (legacyToken ?? '');

      if (token.isNotEmpty) {
        await TokenStorage.saveJwt(token);
        return token;
      }
    }

    throw StateError('Unexpected /auth/google response: ${res.data}');
  }

  Future<AuthLoginResult> googleLoginWithStatus({
    required String idToken,
  }) async {
    final payload = {
      'idToken': idToken,
    };

    AppLogger.api('googleLogin payload=[idToken redacted]');
    final res = await _dio.post('/auth/google', data: payload);

    final data = res.data;
    if (data is Map<String, dynamic> && data['data'] is Map) {
      final wrapped = data['data'] as Map;
      final accessToken = wrapped['accessToken']?.toString() ?? '';
      if (accessToken.isEmpty) {
        throw StateError('Unexpected /auth/google response: ${res.data}');
      }

      await TokenStorage.saveJwt(accessToken);

      final user = (wrapped['user'] is Map) ? (wrapped['user'] as Map) : const {};
      return AuthLoginResult(
        accessToken: accessToken,
        email: user['email']?.toString() ?? '',
        phoneNumber: user['phoneNumber']?.toString(),
        emailVerified: user['emailVerified'] == true,
        phoneVerified: user['phoneVerified'] == true,
        onboardingComplete: user['onboardingComplete'] == true,
      );
    }

    throw StateError('Unexpected /auth/google response: ${res.data}');
  }
}
