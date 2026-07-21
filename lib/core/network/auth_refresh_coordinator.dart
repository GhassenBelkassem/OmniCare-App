import 'package:dio/dio.dart';

import '../storage/secure_token_store.dart';

typedef SessionInvalidatedCallback = Future<void> Function();

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

  Future<StoredSession?>? _refreshInFlight;
  Future<void>? _invalidationInFlight;

  Future<StoredSession?> refreshSession() {
    final current = _refreshInFlight;
    if (current != null) return current;

    final started = _performRefresh();
    _refreshInFlight = started;
    return started.whenComplete(() {
      _refreshInFlight = null;
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

  Future<StoredSession?> _performRefresh() async {
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
      await _tokenStore.saveSession(refreshed);
      return refreshed;
    } catch (_) {
      await invalidateSession();
      return null;
    }
  }

  Future<void> _clearAndNotify() async {
    await _tokenStore.clearSession();
    await _onSessionInvalidated?.call();
  }
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) return value;
  throw FormatException('Missing required string field "$key".');
}
