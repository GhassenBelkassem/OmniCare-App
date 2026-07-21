import 'package:dio/dio.dart';

import '../config/app_environment.dart';
import '../storage/secure_token_store.dart';
import 'auth_interceptor.dart';
import 'auth_refresh_coordinator.dart';

class AppHttpClient {
  AppHttpClient({
    required SecureTokenStore tokenStore,
    String? baseUrl,
    Dio? dio,
    Dio? refreshDio,
    SessionInvalidatedCallback? onSessionInvalidated,
  }) : _dio = dio ?? Dio(_baseOptions(baseUrl)),
       _refreshDio = refreshDio ?? Dio(_baseOptions(baseUrl)) {
    _dio.options = _baseOptions(baseUrl);
    _refreshDio.options = _baseOptions(baseUrl);
    _refreshCoordinator = AuthRefreshCoordinator(
      refreshDio: _refreshDio,
      tokenStore: tokenStore,
      onSessionInvalidated: () async {
        await onSessionInvalidated?.call();
        await this.onSessionInvalidated?.call();
      },
    );
    _dio.interceptors.add(
      AuthInterceptor(
        dio: _dio,
        tokenStore: tokenStore,
        refreshCoordinator: _refreshCoordinator,
      ),
    );
  }

  final Dio _dio;
  final Dio _refreshDio;
  late final AuthRefreshCoordinator _refreshCoordinator;
  SessionInvalidatedCallback? onSessionInvalidated;

  Dio get dio => _dio;

  Dio get publicDio => _refreshDio;

  AuthRefreshCoordinator get refreshCoordinator => _refreshCoordinator;

  static BaseOptions _baseOptions(String? baseUrl) {
    return BaseOptions(
      baseUrl: _apiV1BaseUrl(baseUrl),
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
      headers: const {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    );
  }

  static String _apiV1BaseUrl(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppEnvironment.apiV1BaseUrl;
    }
    final normalized = AppEnvironment.normalizeBaseUrl(value);
    if (normalized.endsWith('/api/v1')) return normalized;
    return '$normalized/api/v1';
  }

  void close({bool force = false}) {
    _dio.close(force: force);
    _refreshDio.close(force: force);
  }
}
