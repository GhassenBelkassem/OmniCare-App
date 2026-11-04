import 'dart:convert';

import '../../../core/storage/secure_token_store.dart';
import 'doctor_workspace_config.dart';

/// Debug-fixture-only storage for the retired local practice wizard.
///
/// It is not professional authority and is never read by the authenticated
/// Doctor shell. Server capabilities/configuration own production navigation.
class DoctorWorkspaceRepository {
  DoctorWorkspaceRepository({SecureTokenStorageBackend? backend})
    : _backend = backend ?? const FlutterSecureTokenStorageBackend();

  static const _keyPrefix = 'omnicare_doctor_workspace_v1:';

  final SecureTokenStorageBackend _backend;

  Future<DoctorWorkspaceConfig?> read(String doctorId) async {
    final id = _validDoctorId(doctorId);
    final key = _keyFor(id);
    try {
      final raw = await _backend.read(key: key);
      if (raw == null || raw.trim().isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        await clear(id);
        return null;
      }
      final config = DoctorWorkspaceConfig.fromJson(
        Map<String, dynamic>.from(decoded),
      );
      if (config.doctorId != id || !config.onboardingCompleted) {
        await clear(id);
        return null;
      }
      return config;
    } catch (_) {
      await clear(id);
      return null;
    }
  }

  Future<void> save(DoctorWorkspaceConfig config) async {
    final id = _validDoctorId(config.doctorId);
    if (!config.onboardingCompleted) {
      throw ArgumentError('Only completed Doctor workspace configs are saved.');
    }
    await _backend.write(key: _keyFor(id), value: jsonEncode(config.toJson()));
  }

  Future<void> clear(String doctorId) async {
    try {
      await _backend.delete(key: _keyFor(_validDoctorId(doctorId)));
    } catch (_) {
      // Clearing local demo setup is best-effort and must never crash logout.
    }
  }

  String _keyFor(String doctorId) => '$_keyPrefix$doctorId';

  String _validDoctorId(String doctorId) {
    final id = doctorId.trim();
    if (id.isEmpty) throw ArgumentError.value(doctorId, 'doctorId');
    return id;
  }
}
