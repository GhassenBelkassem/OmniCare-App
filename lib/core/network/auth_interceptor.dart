import 'package:dio/dio.dart';

import '../storage/secure_token_store.dart';
import 'auth_refresh_coordinator.dart';
import 'request_replay_policy.dart';

class AuthInterceptor extends Interceptor {
  static const retriedKey = 'omnicare_auth_retry';

  AuthInterceptor({
    required Dio dio,
    required SecureTokenStore tokenStore,
    required AuthRefreshCoordinator refreshCoordinator,
  }) : _dio = dio,
       _tokenStore = tokenStore,
       _refreshCoordinator = refreshCoordinator;

  final Dio _dio;
  final SecureTokenStore _tokenStore;
  final AuthRefreshCoordinator _refreshCoordinator;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (_shouldAttachBearer(options)) {
      final session = await _tokenStore.readSession();
      if (session != null) {
        options.headers['Authorization'] = 'Bearer ${session.accessToken}';
      }
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final response = err.response;
    final request = err.requestOptions;
    final alreadyRetried = request.extra[retriedKey] == true;

    if (response?.statusCode != 401 || !_isRefreshEligible(request)) {
      handler.next(err);
      return;
    }

    if (alreadyRetried) {
      if (_hasAuthoritativeSessionError(response?.data)) {
        await _refreshCoordinator.invalidateSession();
      }
      handler.next(err);
      return;
    }

    try {
      final result = await _refreshCoordinator.refreshSession();
      if (request.cancelToken?.isCancelled ?? false) {
        handler.next(request.cancelToken!.cancelError!);
        return;
      }
      final refreshed = result.session;
      if (!result.succeeded || refreshed == null) {
        if (result.sessionInvalidated ||
            result.status == AuthRefreshStatus.sessionEnded) {
          handler.next(err);
        } else {
          handler.next(
            DioException(
              requestOptions: request,
              type: DioExceptionType.unknown,
              error: AuthRefreshUnavailableException(
                result.status,
                cause: result.cause,
              ),
            ),
          );
        }
        return;
      }

      if (!isRequestReplayable(request)) {
        handler.next(
          DioException(
            requestOptions: request,
            type: DioExceptionType.badResponse,
            error: const AuthReplayRequiredException(),
          ),
        );
        return;
      }

      final retryResponse = await _dio.fetch<dynamic>(
        _copyForRetry(request, refreshed.accessToken),
      );
      handler.resolve(retryResponse);
    } on DioException catch (error) {
      handler.next(error);
    } catch (error) {
      handler.next(
        DioException(
          requestOptions: request,
          type: DioExceptionType.unknown,
          error: error,
        ),
      );
    }
  }

  bool _shouldAttachBearer(RequestOptions options) {
    return !isPublicAuthPath(options.uri.path);
  }

  bool _isRefreshEligible(RequestOptions options) {
    return !isNoRefreshPath(options.uri.path);
  }

  RequestOptions _copyForRetry(RequestOptions request, String accessToken) {
    return request.copyWith(
      headers: {...request.headers, 'Authorization': 'Bearer $accessToken'},
      extra: {...request.extra, retriedKey: true},
    );
  }
}

class AuthReplayRequiredException implements Exception {
  const AuthReplayRequiredException();

  @override
  String toString() =>
      'The authenticated request body cannot be replayed safely.';
}

class AuthRefreshUnavailableException implements Exception {
  const AuthRefreshUnavailableException(this.status, {this.cause});

  final AuthRefreshStatus status;
  final Object? cause;

  @override
  String toString() => 'Session refresh failed with status $status.';
}

bool _hasAuthoritativeSessionError(Object? data) {
  if (data is! Map) return false;
  final code = (data['code'] ?? data['errorCode'])?.toString();
  return code == 'AUTH_REFRESH_TOKEN_INVALID' ||
      code == 'AUTH_SESSION_INVALID' ||
      code == 'AUTH_SESSION_EXPIRED';
}

bool isPublicAuthPath(String path) {
  final normalized = normalizeApiPath(path);
  return normalized.startsWith('/api/v1/auth/signup/') ||
      normalized.startsWith('/api/v1/auth/login/') ||
      normalized.startsWith('/api/v1/auth/google/') ||
      normalized == '/api/v1/professional-access-requests' ||
      normalized == '/api/v1/auth/refresh';
}

bool isNoRefreshPath(String path) {
  final normalized = normalizeApiPath(path);
  return isPublicAuthPath(normalized);
}

String normalizeApiPath(String path) {
  final parsed = Uri.tryParse(path);
  final rawPath = parsed?.path ?? path;
  final withLeadingSlash = rawPath.startsWith('/') ? rawPath : '/$rawPath';
  if (withLeadingSlash.startsWith('/api/v1/')) return withLeadingSlash;
  return '/api/v1${withLeadingSlash == '/' ? '' : withLeadingSlash}';
}
