import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../auth/token_storage.dart';
import '../utils/console_log.dart';

class DioClient {
  DioClient._internal() {
    final baseUrl = dotenv.env['API_BASE_URL']?.trim();
    if (baseUrl == null || baseUrl.isEmpty) {
      throw StateError('API_BASE_URL is not set. Make sure .env is present and loaded.');
    }

    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final isAuthEndpoint = options.path.startsWith('/api/auth') || options.path.startsWith('/v1/auth');
          if (!isAuthEndpoint) {
            final token = await TokenStorage.readJwt();
            if (token != null && token.isNotEmpty) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          } else {
            options.headers.remove('Authorization');
          }
          consoleLog('🚀 API authHeader=${options.headers.containsKey('Authorization')}');
          consoleLog('🚀 API ${options.method} ${options.baseUrl}${options.path}');
          if (options.queryParameters.isNotEmpty) {
            consoleLog('🚀 API query=${options.queryParameters}');
          }
          if (options.data != null) {
            consoleLog('🚀 API 📦 ${options.data}');
          }
          handler.next(options);
        },
        onResponse: (response, handler) {
          consoleLog(
            '✅ API ${response.statusCode} ${response.requestOptions.method} ${response.requestOptions.baseUrl}${response.requestOptions.path}',
          );
          if (response.data != null) {
            consoleLog('✅ API 📦 ${response.data}');
          }
          handler.next(response);
        },
        onError: (e, handler) {
          final r = e.response;
          consoleLog(
            '❌ API error ${r?.statusCode ?? '-'} ${e.requestOptions.method} ${e.requestOptions.baseUrl}${e.requestOptions.path} :: ${e.toString()}',
          );
          if (r?.data != null) {
            consoleLog('❌ API 📦 ${r?.data}');
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
