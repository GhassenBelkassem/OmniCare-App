import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../workspace/doctor_workspace_bootstrap.dart';
import 'doctor_urgent_runtime_repository.dart';

enum DoctorUrgentRuntimeMode { home, cabinet }

enum DoctorUrgentRuntimeState { detached, loading, ready, unavailable, failure }

class DoctorUrgentRuntimeController extends ChangeNotifier {
  DoctorUrgentRuntimeController({
    required DoctorUrgentRuntimeRepositoryContract repository,
    this.onSessionRejected,
  }) : _repository = repository;

  final DoctorUrgentRuntimeRepositoryContract _repository;
  final VoidCallback? onSessionRejected;

  DoctorUrgentRuntimeState _state = DoctorUrgentRuntimeState.detached;
  DoctorWorkspaceBootstrap? _workspace;
  DoctorUrgentRuntimeSnapshot? _snapshot;
  DoctorUrgentRuntimeMode? _savingMode;
  CancelToken? _refreshToken;
  String? _feedback;
  int _generation = 0;
  bool _disposed = false;

  DoctorUrgentRuntimeState get state => _state;
  DoctorUrgentRuntimeSnapshot? get snapshot => _snapshot;
  DoctorUrgentRuntimeMode? get savingMode => _savingMode;
  String? get feedback => _feedback;
  bool get hasAuthoritativeState =>
      _state == DoctorUrgentRuntimeState.ready && _snapshot != null;

  void attachWorkspace(DoctorWorkspaceBootstrap workspace) {
    final doctorChanged = _workspace?.doctorId != workspace.doctorId;
    if (doctorChanged) {
      _generation++;
      _refreshToken?.cancel('Doctor runtime account replaced.');
      _refreshToken = null;
      _snapshot = null;
      _savingMode = null;
      _feedback = null;
      _state = DoctorUrgentRuntimeState.loading;
    }
    _workspace = workspace;

    if (workspace.runtimeAccess ==
        DoctorUrgentRuntimeBootstrapAccess.rolloutUnavailable) {
      _generation++;
      _refreshToken?.cancel('Doctor runtime rollout is unavailable.');
      _refreshToken = null;
      _snapshot = null;
      _savingMode = null;
      _state = DoctorUrgentRuntimeState.unavailable;
      _feedback =
          'La disponibilité urgente n’est pas activée sur cet environnement.';
      _notify();
      return;
    }

    final incoming = workspace.runtime;
    if (incoming != null &&
        (_snapshot == null || incoming.revision >= _snapshot!.revision)) {
      _snapshot = incoming;
      _state = DoctorUrgentRuntimeState.ready;
      _feedback = null;
      _notify();
      return;
    }
    if (incoming != null && _snapshot != null) {
      _state = DoctorUrgentRuntimeState.ready;
      _notify();
      return;
    }
    if (_savingMode != null) return;
    // A failed optional bootstrap read must never leave a prior runtime value
    // acting as authority. Resolve the gate explicitly through the runtime API.
    _snapshot = null;
    _state = DoctorUrgentRuntimeState.loading;
    _notify();
    unawaited(refresh());
  }

  bool isEnabled(DoctorUrgentRuntimeMode mode) => switch (mode) {
    DoctorUrgentRuntimeMode.home => _snapshot?.homeEnabled ?? false,
    DoctorUrgentRuntimeMode.cabinet => _snapshot?.cabinetEnabled ?? false,
  };

  bool isSaving(DoctorUrgentRuntimeMode mode) => _savingMode == mode;

  bool canChange(DoctorUrgentRuntimeMode mode) {
    final workspace = _workspace;
    if (!hasAuthoritativeState || workspace == null || _savingMode != null) {
      return false;
    }
    final authorized = switch (mode) {
      DoctorUrgentRuntimeMode.home => workspace.hasUrgentHome,
      DoctorUrgentRuntimeMode.cabinet => workspace.hasUrgentCabinet,
    };
    if (!authorized) return false;
    if (isEnabled(mode)) return true;
    final readiness = switch (mode) {
      DoctorUrgentRuntimeMode.home => workspace.readiness.home,
      DoctorUrgentRuntimeMode.cabinet => workspace.readiness.cabinet,
    };
    return workspace.readiness.professionalEligible &&
        readiness.capabilityEnabled &&
        readiness.configurationReady;
  }

  DoctorUrgentRuntimeModeStatus? modeStatus(DoctorUrgentRuntimeMode mode) =>
      switch (mode) {
        DoctorUrgentRuntimeMode.home => _snapshot?.home,
        DoctorUrgentRuntimeMode.cabinet => _snapshot?.cabinet,
      };

  String modeMessage(DoctorUrgentRuntimeMode mode) {
    if (_state == DoctorUrgentRuntimeState.unavailable) {
      return _feedback ??
          'La disponibilité urgente n’est pas activée sur cet environnement.';
    }
    if (_state == DoctorUrgentRuntimeState.failure || _snapshot == null) {
      return _feedback ??
          'Impossible de vérifier la disponibilité urgente auprès du serveur.';
    }
    final status = modeStatus(mode);
    final reasons =
        status?.blockingReasons ?? _baseReadiness(mode).blockingReasons;
    final filtered = reasons.where(
      (reason) =>
          reason != DoctorUrgentReadinessReason.runtimeHomeIntentDisabled &&
          reason != DoctorUrgentReadinessReason.runtimeCabinetIntentDisabled &&
          reason !=
              DoctorUrgentReadinessReason
                  .requestSpecificEligibilityNotEvaluated,
    );
    final reasonText = filtered
        .map((reason) => reason.frenchLabel)
        .toSet()
        .join(' ');
    if (!isEnabled(mode)) {
      if (reasonText.isNotEmpty) return reasonText;
      return 'Intention désactivée. Aucune activation automatique ne sera effectuée.';
    }
    if (mode == DoctorUrgentRuntimeMode.home &&
        status?.operationalPresenceReady == false) {
      return reasonText.isNotEmpty
          ? 'Intention HOME activée. $reasonText Vous n’êtes pas géographiquement admissible.'
          : 'Intention HOME activée, mais la position GPS Flutter requise n’est pas disponible. Vous n’êtes pas géographiquement admissible.';
    }
    if (reasonText.isNotEmpty) {
      return 'Intention activée. $reasonText';
    }
    return 'Intention activée. L’admissibilité finale reste vérifiée par le serveur pour chaque demande.';
  }

  DoctorUrgentModeReadiness _baseReadiness(DoctorUrgentRuntimeMode mode) =>
      switch (mode) {
        DoctorUrgentRuntimeMode.home => _workspace!.readiness.home,
        DoctorUrgentRuntimeMode.cabinet => _workspace!.readiness.cabinet,
      };

  Future<void> setEnabled(DoctorUrgentRuntimeMode mode, bool enabled) async {
    final workspace = _workspace;
    final current = _snapshot;
    if (workspace == null || current == null || _savingMode != null) return;
    if (isEnabled(mode) == enabled) return;
    if (enabled && !canChange(mode)) {
      _feedback = modeMessage(mode);
      _notify();
      return;
    }

    final generation = ++_generation;
    final doctorId = workspace.doctorId;
    _refreshToken?.cancel('Runtime refresh replaced by a command.');
    _refreshToken = null;
    _savingMode = mode;
    _feedback = null;
    _notify();

    final homeEnabled = mode == DoctorUrgentRuntimeMode.home
        ? enabled
        : current.homeEnabled;
    final cabinetEnabled = mode == DoctorUrgentRuntimeMode.cabinet
        ? enabled
        : current.cabinetEnabled;
    try {
      final result = await _repository.replace(
        expectedRevision: current.revision,
        homeEnabled: homeEnabled,
        cabinetEnabled: cabinetEnabled,
      );
      if (!_isCurrent(generation, doctorId)) return;
      if (result.revision < (_snapshot?.revision ?? 0)) {
        await _reconcile(generation, doctorId);
        return;
      }
      _snapshot = result;
      _state = DoctorUrgentRuntimeState.ready;
      _feedback = enabled
          ? 'Intention enregistrée par le serveur.'
          : 'Indisponibilité enregistrée par le serveur.';
    } catch (error) {
      if (!_isCurrent(generation, doctorId)) return;
      final failure = DoctorUrgentRuntimeFailure.from(error);
      if (failure.kind == DoctorUrgentRuntimeFailureKind.unavailable) {
        _snapshot = null;
        _state = DoctorUrgentRuntimeState.unavailable;
        _feedback = failure.message;
      } else if (failure.kind ==
          DoctorUrgentRuntimeFailureKind.sessionRejected) {
        _state = DoctorUrgentRuntimeState.failure;
        _feedback = failure.message;
        onSessionRejected?.call();
      } else {
        final reconciled = await _reconcile(generation, doctorId);
        if (_isCurrent(generation, doctorId)) {
          _feedback = failure.message;
          if (!reconciled) _state = DoctorUrgentRuntimeState.failure;
        }
      }
    } finally {
      if (_isCurrent(generation, doctorId)) {
        _savingMode = null;
        _notify();
      }
    }
  }

  Future<void> refresh() async {
    final workspace = _workspace;
    if (workspace == null || _savingMode != null) return;
    final generation = ++_generation;
    final doctorId = workspace.doctorId;
    _refreshToken?.cancel('Doctor runtime refresh replaced.');
    final token = _refreshToken = CancelToken();
    if (_snapshot == null) _state = DoctorUrgentRuntimeState.loading;
    _feedback = null;
    _notify();
    try {
      final result = await _repository.get(cancelToken: token);
      if (!_isCurrent(generation, doctorId) || token.isCancelled) return;
      if (_snapshot == null || result.revision >= _snapshot!.revision) {
        _snapshot = result;
      }
      _state = DoctorUrgentRuntimeState.ready;
    } catch (error) {
      if (!_isCurrent(generation, doctorId) ||
          (error is DioException && CancelToken.isCancel(error))) {
        return;
      }
      final failure = DoctorUrgentRuntimeFailure.from(error);
      _feedback = failure.message;
      if (failure.kind == DoctorUrgentRuntimeFailureKind.unavailable) {
        _snapshot = null;
        _state = DoctorUrgentRuntimeState.unavailable;
      } else if (failure.kind ==
          DoctorUrgentRuntimeFailureKind.sessionRejected) {
        _snapshot = null;
        _state = DoctorUrgentRuntimeState.failure;
        onSessionRejected?.call();
      } else if (_snapshot == null) {
        _state = DoctorUrgentRuntimeState.failure;
      }
    } finally {
      if (_isCurrent(generation, doctorId)) {
        _refreshToken = null;
        _notify();
      }
    }
  }

  Future<bool> _reconcile(int generation, String doctorId) async {
    try {
      final result = await _repository.get();
      if (!_isCurrent(generation, doctorId)) return false;
      if (_snapshot == null || result.revision >= _snapshot!.revision) {
        _snapshot = result;
      }
      _state = DoctorUrgentRuntimeState.ready;
      return true;
    } catch (_) {
      return false;
    }
  }

  void clear() {
    _generation++;
    _refreshToken?.cancel('Doctor runtime cleared.');
    _refreshToken = null;
    _workspace = null;
    _snapshot = null;
    _savingMode = null;
    _feedback = null;
    _state = DoctorUrgentRuntimeState.detached;
    _notify();
  }

  bool _isCurrent(int generation, String doctorId) =>
      !_disposed &&
      generation == _generation &&
      _workspace?.doctorId == doctorId;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _refreshToken?.cancel('Doctor runtime controller disposed.');
    _refreshToken = null;
    _workspace = null;
    _snapshot = null;
    super.dispose();
  }
}
