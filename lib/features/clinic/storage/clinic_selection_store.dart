import 'dart:convert';

import '../../../core/storage/secure_token_store.dart';

/// Independently clearable secure store for the *hint* of the last clinic the
/// professional used.
///
/// It stores nothing but a versioned clinic identifier. No tokens, no
/// capabilities, no professional role, no membership, no bootstrap, no clinic
/// name, no feature flags and no medical data are persisted. The hint is never
/// authorization: it is always revalidated against `GET /me/clinics`.
class ClinicSelectionStore {
  ClinicSelectionStore({SecureTokenStorageBackend? backend})
    : _backend = backend ?? const FlutterSecureTokenStorageBackend();

  static const String storageKey = 'omnicare_clinic_selected_v1';
  static const int schemaVersion = 1;

  final SecureTokenStorageBackend _backend;

  /// Returns the stored clinic-id hint, or `null` when absent, unreadable or
  /// invalid. Invalid records are deleted. The value is never logged.
  Future<String?> readSelectedClinicId() async {
    String? raw;
    try {
      raw = await _backend.read(key: storageKey);
    } catch (_) {
      return null;
    }

    if (raw == null || raw.trim().isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        await clear();
        return null;
      }
      if (decoded['schemaVersion'] != schemaVersion) {
        await clear();
        return null;
      }
      final clinicId = decoded['clinicId'];
      if (clinicId is! String || clinicId.trim().isEmpty) {
        await clear();
        return null;
      }
      return clinicId.trim();
    } catch (_) {
      await clear();
      return null;
    }
  }

  /// Persists the hint. Storage failures are tolerated: the hint is optional.
  Future<void> saveSelectedClinicId(String clinicId) async {
    final value = clinicId.trim();
    if (value.isEmpty) {
      await clear();
      return;
    }
    try {
      await _backend.write(
        key: storageKey,
        value: jsonEncode({'schemaVersion': schemaVersion, 'clinicId': value}),
      );
    } catch (_) {
      // A missing hint only costs one extra selection step.
    }
  }

  Future<void> clear() async {
    try {
      await _backend.delete(key: storageKey);
    } catch (_) {
      // Nothing else can be done safely here.
    }
  }
}
