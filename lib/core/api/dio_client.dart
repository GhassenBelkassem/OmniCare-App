import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../auth/token_storage.dart';
import '../utils/console_log.dart';

class DioClient {
  DioClient._internal() {
    const fallbackBaseUrl = 'http://192.168.100.83:8080/api';
    final definedBaseUrl = const String.fromEnvironment('API_BASE_URL').trim();
    final envBaseUrl = dotenv.env['API_BASE_URL']?.trim();
    final baseUrl = definedBaseUrl.isNotEmpty
        ? definedBaseUrl
        : ((envBaseUrl == null || envBaseUrl.isEmpty)
              ? fallbackBaseUrl
              : envBaseUrl);

    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          if (kIsWeb && options.data == null) {
            options.sendTimeout = null;
            options.connectTimeout = null;
          }

          final isAuthEndpoint =
              options.path.startsWith('/auth') ||
              options.path.startsWith('/api/auth') ||
              options.path.startsWith('/v1/auth');
          if (!isAuthEndpoint) {
            final token = await TokenStorage.readJwt();
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          } else {
            options.headers.remove('Authorization');
          }
          if (kDebugMode) {
            consoleLog(
              '🚀 API authHeader=${options.headers.containsKey('Authorization')}',
            );
            consoleLog(
              '🚀 API ${options.method} ${options.baseUrl}${options.path}',
            );
            if (options.queryParameters.isNotEmpty) {
              consoleLog('🚀 API query=${options.queryParameters}');
            }
          }
          handler.next(options);
        },
        onResponse: (response, handler) {
          if (kDebugMode) {
            consoleLog(
              '✅ API ${response.statusCode} ${response.requestOptions.method} ${response.requestOptions.baseUrl}${response.requestOptions.path}',
            );
            final data = response.data;
            if (data is List) {
              consoleLog('✅ API Body: [List of ${data.length} items]');
            }
          }
          handler.next(response);
        },
        onError: (e, handler) {
          final r = e.response;
          if (kDebugMode) {
            consoleLog(
              '❌ API error ${r?.statusCode ?? '-'} ${e.requestOptions.method} ${e.requestOptions.baseUrl}${e.requestOptions.path} :: ${e.toString()}',
            );
          }
          handler.next(e);
        },
      ),
    );
  }

  static final DioClient instance = DioClient._internal();

  late final Dio _dio;

  Dio get dio => _dio;
}
