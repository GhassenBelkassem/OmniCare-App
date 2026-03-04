import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import '../utils/logger.dart';
import '../auth/token_storage.dart';

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
          final token = await TokenStorage.readJwt();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          AppLogger.api('authHeader=${options.headers.containsKey('Authorization')}');
          AppLogger.api('${options.method} ${options.baseUrl}${options.path}');
          if (options.queryParameters.isNotEmpty) {
            AppLogger.api('query=${options.queryParameters}');
          }
          if (options.data != null) {
            AppLogger.api('📦 ${options.data}');
          }
          handler.next(options);
        },
        onResponse: (response, handler) {
          AppLogger.api('✅ ${response.statusCode} ${response.requestOptions.method} ${response.requestOptions.baseUrl}${response.requestOptions.path}');
          if (response.data != null) {
            AppLogger.api('📦 ${response.data}');
          }
          handler.next(response);
        },
        onError: (e, handler) {
          final r = e.response;
          AppLogger.error(
            'API error ${r?.statusCode ?? '-'} ${e.requestOptions.method} ${e.requestOptions.baseUrl}${e.requestOptions.path}',
            e,
            e.stackTrace,
          );
          if (r?.data != null) {
            AppLogger.api('📦 ${r?.data}');
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
