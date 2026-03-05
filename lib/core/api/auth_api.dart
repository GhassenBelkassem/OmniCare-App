import 'package:dio/dio.dart';

import '../utils/logger.dart';
import 'dio_client.dart';
import '../auth/token_storage.dart';

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
}
