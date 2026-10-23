import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

const Object _notSet = Object();

abstract class SecureTokenStorageBackend {
  Future<String?> read({required String key});
  Future<void> write({required String key, required String value});
  Future<void> delete({required String key});
}

class FlutterSecureTokenStorageBackend implements SecureTokenStorageBackend {
  const FlutterSecureTokenStorageBackend([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read({required String key}) => _storage.read(key: key);

  @override
  Future<void> write({required String key, required String value}) {
    return _storage.write(key: key, value: value);
  }

  @override
  Future<void> delete({required String key}) => _storage.delete(key: key);
}

class StoredSession {
  final String accessToken;
  final String refreshToken;
  final DateTime accessTokenExpiresAt;
  final DateTime refreshTokenExpiresAt;
  final String userId;
  final String userRole;
  final String? sessionId;

  const StoredSession({
    required this.accessToken,
    required this.refreshToken,
    required this.accessTokenExpiresAt,
    required this.refreshTokenExpiresAt,
    required this.userId,
    required this.userRole,
    this.sessionId,
  });

  bool get hasRequiredValues {
    return accessToken.trim().isNotEmpty &&
        refreshToken.trim().isNotEmpty &&
        userId.trim().isNotEmpty &&
        userRole.trim().isNotEmpty;
  }

  StoredSession copyWith({
    String? accessToken,
    String? refreshToken,
    DateTime? accessTokenExpiresAt,
    DateTime? refreshTokenExpiresAt,
    String? userId,
    String? userRole,
    Object? sessionId = _notSet,
  }) {
    return StoredSession(
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      accessTokenExpiresAt: accessTokenExpiresAt ?? this.accessTokenExpiresAt,
      refreshTokenExpiresAt:
          refreshTokenExpiresAt ?? this.refreshTokenExpiresAt,
      userId: userId ?? this.userId,
      userRole: userRole ?? this.userRole,
      sessionId: identical(sessionId, _notSet)
          ? this.sessionId
          : sessionId as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'schemaVersion': SecureTokenStore.sessionSchemaVersion,
      'accessToken': accessToken.trim(),
      'refreshToken': refreshToken.trim(),
      'accessTokenExpiresAt': accessTokenExpiresAt.toUtc().toIso8601String(),
      'refreshTokenExpiresAt': refreshTokenExpiresAt.toUtc().toIso8601String(),
      'userId': userId.trim(),
      'role': userRole.trim(),
      'sessionId': (sessionId ?? '').trim().isEmpty ? null : sessionId!.trim(),
    };
  }

  @override
  String toString() {
    return 'StoredSession(userId: $userId, userRole: $userRole, '
        'sessionId: ${sessionId ?? '<pending>'}, accessToken: <redacted>, '
        'refreshToken: <redacted>, '
        'accessTokenExpiresAt: ${accessTokenExpiresAt.toUtc().toIso8601String()}, '
        'refreshTokenExpiresAt: ${refreshTokenExpiresAt.toUtc().toIso8601String()})';
  }
}

class SecureTokenStore {
  static const sessionRecordKey = 'omnicare_auth_session_v1';
  static const sessionSchemaVersion = 1;
  static const deviceInstallationIdKey = 'device_installation_id';

  static const accessTokenKey = 'access_token';
  static const refreshTokenKey = 'refresh_token';
  static const accessTokenExpiresAtKey = 'access_token_expires_at';
  static const refreshTokenExpiresAtKey = 'refresh_token_expires_at';
  static const userIdKey = 'user_id';
  static const userRoleKey = 'user_role';
  static const sessionIdKey = 'session_id';

  static const _legacyRequiredSessionKeys = <String>[
    accessTokenKey,
    refreshTokenKey,
    accessTokenExpiresAtKey,
    refreshTokenExpiresAtKey,
    userIdKey,
    userRoleKey,
  ];

  static const _legacySessionKeys = <String>[
    ..._legacyRequiredSessionKeys,
    sessionIdKey,
  ];

  SecureTokenStore({SecureTokenStorageBackend? backend})
    : _backend = backend ?? const FlutterSecureTokenStorageBackend();

  final SecureTokenStorageBackend _backend;
  StoredSession? _cachedSession;
  bool _sessionCacheLoaded = false;

  Future<void> saveSession(StoredSession session) async {
    if (!session.hasRequiredValues) {
      throw ArgumentError('StoredSession is missing required values.');
    }

    final jsonRecord = jsonEncode(session.toJson());
    try {
      await _backend.write(key: sessionRecordKey, value: jsonRecord);
      await _clearLegacySession();
      _cachedSession = session;
      _sessionCacheLoaded = true;
    } catch (_) {
      await clearSession();
      rethrow;
    }
  }

  Future<StoredSession?> readSession() async {
    if (_sessionCacheLoaded) return _cachedSession;
    final raw = await _backend.read(key: sessionRecordKey);
    if (raw == null || raw.trim().isEmpty) {
      final migrated = await _readAndMigrateLegacySession();
      _cachedSession = migrated;
      _sessionCacheLoaded = true;
      return migrated;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        await clearSession();
        return null;
      }

      final session = _sessionFromJson(decoded.cast<String, dynamic>());
      _cachedSession = session;
      _sessionCacheLoaded = true;
      return session;
    } catch (_) {
      await clearSession();
      return null;
    }
  }

  Future<bool> hasCompleteSession() async => (await readSession()) != null;

  Future<void> clearSession() async {
    // Clear memory before awaiting storage so a concurrent request cannot use
    // a session that is being logged out or invalidated.
    _cachedSession = null;
    _sessionCacheLoaded = true;
    await _backend.delete(key: sessionRecordKey);
    await _clearLegacySession();
  }

  Future<String?> readDeviceInstallationId() {
    return _backend.read(key: deviceInstallationIdKey);
  }

  Future<void> saveDeviceInstallationId(String installationId) {
    final value = installationId.trim();
    if (value.isEmpty) {
      throw ArgumentError('Device installation ID cannot be empty.');
    }
    return _backend.write(key: deviceInstallationIdKey, value: value);
  }

  Future<StoredSession?> _readAndMigrateLegacySession() async {
    final values = <String, String?>{};
    for (final key in _legacySessionKeys) {
      values[key] = await _backend.read(key: key);
    }

    final hasAnyLegacyValue = values.values.any(
      (value) => value != null && value.trim().isNotEmpty,
    );
    if (!hasAnyLegacyValue) return null;

    final missingRequired = _legacyRequiredSessionKeys.any((key) {
      final value = values[key];
      return value == null || value.trim().isEmpty;
    });
    if (missingRequired) {
      await clearSession();
      return null;
    }

    final accessExpiresAt = DateTime.tryParse(
      values[accessTokenExpiresAtKey]!.trim(),
    );
    final refreshExpiresAt = DateTime.tryParse(
      values[refreshTokenExpiresAtKey]!.trim(),
    );
    if (accessExpiresAt == null || refreshExpiresAt == null) {
      await clearSession();
      return null;
    }

    final session = StoredSession(
      accessToken: values[accessTokenKey]!.trim(),
      refreshToken: values[refreshTokenKey]!.trim(),
      accessTokenExpiresAt: accessExpiresAt.toUtc(),
      refreshTokenExpiresAt: refreshExpiresAt.toUtc(),
      userId: values[userIdKey]!.trim(),
      userRole: values[userRoleKey]!.trim(),
      sessionId: _nullableString(values[sessionIdKey]),
    );
    await saveSession(session);
    return session;
  }

  StoredSession _sessionFromJson(Map<String, dynamic> json) {
    if (json['schemaVersion'] != sessionSchemaVersion) {
      throw const FormatException('Unsupported session schema version.');
    }

    final accessExpiresAt = DateTime.tryParse(
      _requiredString(json, 'accessTokenExpiresAt'),
    );
    final refreshExpiresAt = DateTime.tryParse(
      _requiredString(json, 'refreshTokenExpiresAt'),
    );
    if (accessExpiresAt == null || refreshExpiresAt == null) {
      throw const FormatException('Invalid session timestamp.');
    }

    final session = StoredSession(
      accessToken: _requiredString(json, 'accessToken'),
      refreshToken: _requiredString(json, 'refreshToken'),
      accessTokenExpiresAt: accessExpiresAt.toUtc(),
      refreshTokenExpiresAt: refreshExpiresAt.toUtc(),
      userId: _requiredString(json, 'userId'),
      userRole: _requiredString(json, 'role'),
      sessionId: _nullableString(json['sessionId']),
    );

    if (!session.hasRequiredValues) {
      throw const FormatException('Stored session is incomplete.');
    }
    return session;
  }

  Future<void> _clearLegacySession() async {
    for (final key in _legacySessionKeys) {
      await _backend.delete(key: key);
    }
  }
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) return value.trim();
  throw FormatException('Missing required string field "$key".');
}

String? _nullableString(Object? value) {
  if (value == null) return null;
  final stringValue = value.toString().trim();
  return stringValue.isEmpty ? null : stringValue;
}
