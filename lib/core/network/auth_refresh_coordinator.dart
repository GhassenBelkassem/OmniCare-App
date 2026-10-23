import 'package:dio/dio.dart';

import '../storage/secure_token_store.dart';

typedef SessionInvalidatedCallback = Future<void> Function();
typedef SessionRefreshedCallback = Future<void> Function(StoredSession session);

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

  Future<StoredSession?>? _refreshInFlight;
  Future<void>? _invalidationInFlight;
  Future<void>? _sessionEndInFlight;
  bool _sessionEndStarted = false;
  int _sessionGeneration = 0;

  Future<StoredSession?> refreshSession() {
    if (_sessionEndStarted) return Future<StoredSession?>.value();
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

  Future<StoredSession?> _performRefresh(int generation) async {
    final existing = await _tokenStore.readSession();
    if (existing == null ||
        !existing.refreshTokenExpiresAt.toUtc().isAfter(
          DateTime.now().toUtc(),
        )) {
      await invalidateSession();
      return null;
    }

    try {
      final response = await _refreshDio.post<dynamic>(
        '/auth/refresh',
        data: {'refreshToken': existing.refreshToken},
      );
      final data = response.data;
      if (data is! Map) {
        await invalidateSession();
        return null;
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
        await invalidateSession();
        return null;
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
      if (_sessionEndStarted || generation != _sessionGeneration) return null;
      await _tokenStore.saveSession(refreshed);
      if (_sessionEndStarted || generation != _sessionGeneration) return null;
      await onSessionRefreshed?.call(refreshed);
      return refreshed;
    } catch (_) {
      await invalidateSession();
      return null;
    }
  }

  Future<void> _drainRefreshAndClear(
    Future<StoredSession?>? refreshToDrain,
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

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) return value;
  throw FormatException('Missing required string field "$key".');
}
