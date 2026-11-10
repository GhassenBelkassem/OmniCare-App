import 'package:dio/dio.dart';

import '../storage/secure_token_store.dart';

typedef SessionInvalidatedCallback = Future<void> Function();
typedef SessionRefreshedCallback = Future<void> Function(StoredSession session);

enum AuthRefreshStatus {
  refreshed,
  noSession,
  credentialsRejected,
  temporarilyUnavailable,
  malformedResponse,
  sessionEnded,
}

class AuthRefreshResult {
  const AuthRefreshResult._(this.status, {this.session, this.cause});

  const AuthRefreshResult.refreshed(StoredSession session)
    : this._(AuthRefreshStatus.refreshed, session: session);

  const AuthRefreshResult.failure(AuthRefreshStatus status, {Object? cause})
    : this._(status, cause: cause);

  final AuthRefreshStatus status;
  final StoredSession? session;
  final Object? cause;

  bool get succeeded => status == AuthRefreshStatus.refreshed;
  bool get sessionInvalidated =>
      status == AuthRefreshStatus.noSession ||
      status == AuthRefreshStatus.credentialsRejected;
}

class AuthRefreshCoordinator {
  AuthRefreshCoordinator({
    required Dio refreshDio,
    required SecureTokenStore tokenStore,
    SessionInvalidatedCallback? onSessionInvalidated,
  }) : _refreshDio = refreshDio,
       _tokenStore = tokenStore,
       _onSessionInvalidated = onSessionInvalidated;

  final Dio _refreshDio;
  final SecureTokenStore _tokenStore;
  final SessionInvalidatedCallback? _onSessionInvalidated;
  SessionRefreshedCallback? onSessionRefreshed;

  Future<AuthRefreshResult>? _refreshInFlight;
  Future<void>? _invalidationInFlight;
  Future<void>? _sessionEndInFlight;
  bool _sessionEndStarted = false;
  int _sessionGeneration = 0;

  Future<AuthRefreshResult> refreshSession() {
    if (_sessionEndStarted) {
      return Future<AuthRefreshResult>.value(
        const AuthRefreshResult.failure(AuthRefreshStatus.sessionEnded),
      );
    }
    final current = _refreshInFlight;
    if (current != null) return current;

    final started = _performRefresh(_sessionGeneration);
    _refreshInFlight = started;
    return started.whenComplete(() {
      _refreshInFlight = null;
    });
  }

  /// Fences any refresh already in progress, waits for it to drain, and then
  /// clears local credentials. New login sessions may start after completion.
  Future<void> endSession() {
    final current = _sessionEndInFlight;
    if (current != null) return current;

    _sessionEndStarted = true;
    _sessionGeneration += 1;
    final refreshToDrain = _refreshInFlight;
    final started = _drainRefreshAndClear(refreshToDrain);
    _sessionEndInFlight = started;
    return started.whenComplete(() {
      if (identical(_sessionEndInFlight, started)) {
        _sessionEndInFlight = null;
        _sessionEndStarted = false;
      }
    });
  }

  Future<void> invalidateSession() {
    final current = _invalidationInFlight;
    if (current != null) return current;

    final started = _clearAndNotify();
    _invalidationInFlight = started;
    return started.whenComplete(() {
      _invalidationInFlight = null;
    });
  }

  Future<AuthRefreshResult> _performRefresh(int generation) async {
    try {
      final existing = await _tokenStore.readSession();
      if (existing == null ||
          !existing.refreshTokenExpiresAt.toUtc().isAfter(
            DateTime.now().toUtc(),
          )) {
        await invalidateSession();
        return const AuthRefreshResult.failure(AuthRefreshStatus.noSession);
      }

      final response = await _refreshDio.post<dynamic>(
        '/auth/refresh',
        data: {'refreshToken': existing.refreshToken},
      );
      final data = response.data;
      if (data is! Map) {
        return const AuthRefreshResult.failure(
          AuthRefreshStatus.malformedResponse,
        );
      }

      final json = data.cast<String, dynamic>();
      final user = (json['user'] as Map?)?.cast<String, dynamic>();
      final accessToken = _requiredString(json, 'accessToken');
      final refreshToken = _requiredString(json, 'refreshToken');
      final expiresAt = DateTime.tryParse(_requiredString(json, 'expiresAt'));
      final refreshExpiresAt = DateTime.tryParse(
        _requiredString(json, 'refreshExpiresAt'),
      );
      final userId = _requiredString(user ?? const {}, 'id');
      final userRole = _requiredString(user ?? const {}, 'role');
      if (expiresAt == null || refreshExpiresAt == null) {
        return const AuthRefreshResult.failure(
          AuthRefreshStatus.malformedResponse,
        );
      }

      final refreshed = StoredSession(
        accessToken: accessToken,
        refreshToken: refreshToken,
        accessTokenExpiresAt: expiresAt.toUtc(),
        refreshTokenExpiresAt: refreshExpiresAt.toUtc(),
        userId: userId,
        userRole: userRole,
        sessionId: existing.sessionId,
      );
      if (_sessionEndStarted || generation != _sessionGeneration) {
        return const AuthRefreshResult.failure(AuthRefreshStatus.sessionEnded);
      }
      await _tokenStore.saveSession(refreshed);
      if (_sessionEndStarted || generation != _sessionGeneration) {
        return const AuthRefreshResult.failure(AuthRefreshStatus.sessionEnded);
      }
      await onSessionRefreshed?.call(refreshed);
      return AuthRefreshResult.refreshed(refreshed);
    } on FormatException catch (error) {
      return AuthRefreshResult.failure(
        AuthRefreshStatus.malformedResponse,
        cause: error,
      );
    } on DioException catch (error) {
      if (_isAuthoritativeCredentialRejection(error)) {
        await invalidateSession();
        return AuthRefreshResult.failure(
          AuthRefreshStatus.credentialsRejected,
          cause: error,
        );
      }
      return AuthRefreshResult.failure(
        AuthRefreshStatus.temporarilyUnavailable,
        cause: error,
      );
    } catch (error) {
      return AuthRefreshResult.failure(
        AuthRefreshStatus.temporarilyUnavailable,
        cause: error,
      );
    }
  }

  Future<void> _drainRefreshAndClear(
    Future<AuthRefreshResult>? refreshToDrain,
  ) async {
    if (refreshToDrain != null) {
      try {
        await refreshToDrain;
      } catch (_) {
        // Logout still owns local clearing when an in-flight refresh fails.
      }
    }
    await _tokenStore.clearSession();
  }

  Future<void> _clearAndNotify() async {
    _sessionGeneration += 1;
    await _tokenStore.clearSession();
    await _onSessionInvalidated?.call();
  }
}

bool _isAuthoritativeCredentialRejection(DioException error) {
  final data = error.response?.data;
  if (data is! Map) return false;

  final code = (data['code'] ?? data['errorCode'])?.toString();
  return code == 'AUTH_REFRESH_TOKEN_INVALID' ||
      code == 'AUTH_SESSION_INVALID' ||
      code == 'AUTH_SESSION_EXPIRED';
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) return value;
  throw FormatException('Missing required string field "$key".');
}
