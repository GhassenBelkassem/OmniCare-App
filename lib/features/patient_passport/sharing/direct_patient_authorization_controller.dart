import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/utils/uuid_v4.dart';
import 'direct_patient_authorization.dart';
import 'direct_patient_authorization_api.dart';
import 'medical_sharing_models.dart';

class DirectPatientAuthorizationController extends ChangeNotifier {
  DirectPatientAuthorizationController(this._api);

  final DirectPatientAuthorizationApiContract _api;
  List<DirectAuthorizationContext> _contexts = const [];
  DirectAuthorizationContext? _selected;
  PatientMedicalAccess? _access;
  bool _loading = false;
  bool _mutating = false;
  String? _error;
  int _generation = 0;

  List<DirectAuthorizationContext> get contexts => _contexts;
  DirectAuthorizationContext? get selected => _selected;
  PatientMedicalAccess? get access => _access;
  bool get isLoading => _loading;
  bool get isMutating => _mutating;
  String? get error => _error;

  Future<void> load(MedicalSharingSubject subject) async {
    final generation = ++_generation;
    _loading = true;
    _error = null;
    _access = null;
    notifyListeners();
    try {
      _contexts = await _api.activeContexts(subject);
      if (generation != _generation) return;
      _selected = _contexts.length == 1 ? _contexts.single : null;
      if (_selected != null) {
        _access = await _api.readAccess(_selected!.consultationId);
      }
    } catch (error) {
      if (generation == _generation) _error = _message(error);
    } finally {
      if (generation == _generation) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> select(DirectAuthorizationContext context) async {
    if (!_contexts.any(
      (value) => value.consultationId == context.consultationId,
    )) {
      return;
    }
    final generation = ++_generation;
    _selected = context;
    _loading = true;
    _error = null;
    _access = null;
    notifyListeners();
    try {
      _access = await _api.readAccess(context.consultationId);
    } catch (error) {
      if (generation == _generation) _error = _message(error);
    } finally {
      if (generation == _generation) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> approve() => _mutate(true);
  Future<void> revoke() => _mutate(false);

  Future<void> _mutate(bool approve) async {
    final context = _selected;
    if (context == null || _mutating) return;
    final generation = _generation;
    _mutating = true;
    _error = null;
    notifyListeners();
    try {
      _access = approve
          ? await _api.approve(
              context.consultationId,
              idempotencyKey: generateUuidV4(),
            )
          : await _api.revoke(
              context.consultationId,
              idempotencyKey: generateUuidV4(),
            );
    } catch (error) {
      if (generation == _generation) _error = _message(error);
    } finally {
      if (generation == _generation) {
        _mutating = false;
        notifyListeners();
      }
    }
  }

  void clear() {
    _generation++;
    _contexts = const [];
    _selected = null;
    _access = null;
    _loading = false;
    _mutating = false;
    _error = null;
    notifyListeners();
  }

  static String _message(Object error) {
    if (error is ApiException) {
      return switch (error.code) {
        'RESOURCE_NOT_FOUND' => 'Cette Consultation n’est plus active.',
        'PROFESSIONAL_NOT_ELIGIBLE' =>
          'Ce médecin ne peut pas recevoir cet accès actuellement.',
        'MRS_UNAVAILABLE' =>
          'Le service médical est temporairement indisponible.',
        _ => error.message,
      };
    }
    return 'Impossible de charger l’autorisation médicale.';
  }
}
