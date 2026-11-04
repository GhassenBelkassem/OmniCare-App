import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/utils/uuid_v4.dart';
import 'medical_sharing_api.dart';
import 'medical_sharing_models.dart';

class MedicalSharingController extends ChangeNotifier {
  MedicalSharingController(this._api);

  final MedicalSharingApiContract _api;
  final Map<String, MedicalSharingPolicy> _policies = {};
  MedicalSharingSubject _subject = const MedicalSharingSubject.self();
  bool _loading = false;
  bool _saving = false;
  String? _error;
  String? _notice;
  int _generation = 0;

  MedicalSharingSubject get subject => _subject;
  MedicalSharingPolicy? get policy => _policies[_subject.cacheKey];
  bool get isLoading => _loading;
  bool get isSaving => _saving;
  String? get error => _error;
  String? get notice => _notice;

  Future<void> selectSubject(MedicalSharingSubject subject) async {
    _subject = subject;
    _generation++;
    notifyListeners();
    await load();
  }

  Future<void> load() async {
    final generation = _generation;
    final selected = _subject;
    _loading = true;
    _error = null;
    _notice = null;
    notifyListeners();
    try {
      final loaded = await _api.readPolicy(selected);
      if (generation != _generation || selected.cacheKey != _subject.cacheKey) {
        return;
      }
      _policies[selected.cacheKey] = loaded;
    } catch (error) {
      if (generation != _generation) return;
      _error = _message(error);
    } finally {
      if (generation == _generation) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  Future<bool> save(MedicalSharingPolicy desired) async {
    if (_saving) return false;
    final generation = _generation;
    final selected = _subject;
    _saving = true;
    _error = null;
    _notice = null;
    notifyListeners();
    try {
      final canonical = await _api.updatePolicy(
        desired,
        idempotencyKey: generateUuidV4(),
      );
      if (generation != _generation || selected.cacheKey != _subject.cacheKey) {
        return false;
      }
      _policies[selected.cacheKey] = canonical;
      _notice = 'Paramètres de partage enregistrés.';
      return true;
    } catch (error) {
      if (generation != _generation) return false;
      if (error is ApiException &&
          error.code == 'SHARING_POLICY_VERSION_CONFLICT') {
        _notice =
            'Ces paramètres ont été modifiés ailleurs. Version actualisée.';
        await _reloadAfterConflict(generation, selected);
      } else {
        _error = _message(error);
      }
      return false;
    } finally {
      if (generation == _generation) {
        _saving = false;
        notifyListeners();
      }
    }
  }

  Future<ConsultationSharingPolicy?> updateConsultationSharing({
    required String consultationId,
    required int expectedVersion,
    required ConsultationSharingState currentState,
    required ConsultationSharingState desiredState,
  }) async {
    if (_saving) return null;
    final generation = _generation;
    final selected = _subject;
    _saving = true;
    _error = null;
    _notice = null;
    notifyListeners();
    try {
      final canonical = await _api.updateConsultationPolicy(
        ConsultationSharingPolicy(
          subject: selected,
          consultationId: consultationId,
          state: currentState,
          version: expectedVersion,
          updatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        ),
        desiredState,
        idempotencyKey: generateUuidV4(),
      );
      if (generation != _generation || selected.cacheKey != _subject.cacheKey) {
        return null;
      }
      _notice = canonical.state == ConsultationSharingState.shareable
          ? 'Cette consultation est éligible au partage autorisé.'
          : 'Cette consultation reste verrouillée pour le partage normal.';
      return canonical;
    } catch (error) {
      if (generation != _generation) return null;
      if (error is ApiException &&
          error.code == 'SHARING_POLICY_VERSION_CONFLICT') {
        _notice = 'Cette consultation a été modifiée ailleurs. État actualisé.';
        try {
          return await _api.readConsultationPolicy(selected, consultationId);
        } catch (refreshError) {
          _error = _message(refreshError);
        }
      } else {
        _error = _message(error);
      }
      return null;
    } finally {
      if (generation == _generation) {
        _saving = false;
        notifyListeners();
      }
    }
  }

  Future<void> _reloadAfterConflict(
    int generation,
    MedicalSharingSubject selected,
  ) async {
    try {
      final canonical = await _api.readPolicy(selected);
      if (generation == _generation && selected.cacheKey == _subject.cacheKey) {
        _policies[selected.cacheKey] = canonical;
      }
    } catch (error) {
      if (generation == _generation) _error = _message(error);
    }
  }

  void clear() {
    _generation++;
    _policies.clear();
    _subject = const MedicalSharingSubject.self();
    _loading = false;
    _saving = false;
    _error = null;
    _notice = null;
    notifyListeners();
  }

  static String _message(Object error) {
    if (error is ApiException) {
      return switch (error.code) {
        'MRS_UNAVAILABLE' =>
          'Le service médical est temporairement indisponible. Aucun changement enregistré.',
        'AUTH_SESSION_EXPIRED' ||
        'UNAUTHORIZED' => 'Votre session a expiré. Reconnectez-vous.',
        'RESOURCE_NOT_FOUND' || 'CLINICAL_SUBJECT_UNAVAILABLE' =>
          'Ce passeport familial n’est plus disponible.',
        _ => error.message,
      };
    }
    return 'Impossible de charger les paramètres de partage.';
  }
}
