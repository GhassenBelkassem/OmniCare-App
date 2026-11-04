import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'doctor_home_commitment.dart';
import 'doctor_home_commitment_repository.dart';

enum DoctorHomeCommitmentState {
  initial,
  loading,
  noActiveCommitment,
  activeCommitment,
  terminalCommitment,
  unavailable,
  failure,
}

class DoctorHomeCommitmentController extends ChangeNotifier {
  DoctorHomeCommitmentController({
    required DoctorHomeCommitmentRepositoryContract repository,
    this.onSessionRejected,
  }) : _repository = repository;

  final DoctorHomeCommitmentRepositoryContract _repository;
  final VoidCallback? onSessionRejected;

  DoctorHomeCommitmentState _state = DoctorHomeCommitmentState.initial;
  DoctorHomeCommitment? _commitment;
  String? _doctorId;
  String? _message;
  int _generation = 0;
  bool _disposed = false;
  bool _rolloutAvailable = true;
  CancelToken? _activeToken;
  CancelToken? _detailToken;

  DoctorHomeCommitmentState get state => _state;
  DoctorHomeCommitment? get commitment => _commitment;
  String? get message => _message;
  bool get isLoading => _state == DoctorHomeCommitmentState.loading;

  bool get hasVisibleResponsibility =>
      _commitment != null &&
      (_state == DoctorHomeCommitmentState.activeCommitment ||
          _state == DoctorHomeCommitmentState.terminalCommitment ||
          _state == DoctorHomeCommitmentState.loading ||
          _state == DoctorHomeCommitmentState.unavailable ||
          _state == DoctorHomeCommitmentState.failure);

  Future<void> load(String doctorId) async {
    attachDoctor(doctorId);
    await refresh();
  }

  void attachDoctor(String doctorId) {
    final normalized = doctorId.trim();
    if (normalized.isEmpty) throw ArgumentError.value(doctorId, 'doctorId');
    if (_doctorId == normalized) return;
    _cancelRequests('Doctor HOME commitment owner changed.');
    _doctorId = normalized;
    _commitment = null;
    _message = null;
    _state = DoctorHomeCommitmentState.initial;
    _notify();
  }

  void synchronizeRolloutAccess({required bool available}) {
    if (_rolloutAvailable == available) return;
    _rolloutAvailable = available;
    if (!available) {
      _cancelRequests('HOME commitment rollout is unavailable.');
      _message =
          'La responsabilité HOME n’est pas activée sur cet environnement.';
      if (_commitment == null) {
        _state = DoctorHomeCommitmentState.unavailable;
      }
      _notify();
      return;
    }
    if (_doctorId != null) {
      _message = null;
      if (_commitment == null) _state = DoctorHomeCommitmentState.initial;
      _notify();
    }
  }

  Future<void> refresh() async {
    final doctorId = _doctorId;
    if (_disposed || doctorId == null || !_rolloutAvailable) return;
    final knownCommitmentId = _commitment?.commitmentId;
    final generation = ++_generation;
    _activeToken?.cancel('HOME commitment refresh replaced.');
    _detailToken?.cancel('HOME commitment detail refresh replaced.');
    _detailToken = null;
    final token = _activeToken = CancelToken();
    _message = null;
    _state = DoctorHomeCommitmentState.loading;
    _notify();
    try {
      final active = await _repository.findActive(cancelToken: token);
      if (!_isCurrentActive(generation, doctorId, token)) return;
      if (active.result == DoctorHomeActiveCommitmentResult.activeCommitment) {
        _commitment = active.commitment;
        _state = DoctorHomeCommitmentState.activeCommitment;
        return;
      }
      if (knownCommitmentId == null) {
        _commitment = null;
        _state = DoctorHomeCommitmentState.noActiveCommitment;
        return;
      }
      _activeToken = null;
      await _reconcileKnownDetail(knownCommitmentId, generation, doctorId);
    } catch (error) {
      if (!_isCurrentActive(generation, doctorId, token) ||
          _isCancellation(error)) {
        return;
      }
      _applyFailure(DoctorHomeCommitmentFailure.from(error));
    } finally {
      if (_isCurrentActive(generation, doctorId, token)) {
        _activeToken = null;
        _notify();
      } else if (!_disposed &&
          generation == _generation &&
          _doctorId == doctorId) {
        _notify();
      }
    }
  }

  Future<void> refreshFromInvalidationHint() => refresh();

  Future<void> _reconcileKnownDetail(
    String commitmentId,
    int generation,
    String doctorId,
  ) async {
    final token = _detailToken = CancelToken();
    try {
      final detail = await _repository.get(commitmentId, cancelToken: token);
      if (!_isCurrentDetail(generation, doctorId, token)) return;
      _commitment = detail;
      _state = detail.isActive
          ? DoctorHomeCommitmentState.activeCommitment
          : DoctorHomeCommitmentState.terminalCommitment;
    } catch (error) {
      if (!_isCurrentDetail(generation, doctorId, token) ||
          _isCancellation(error)) {
        return;
      }
      final failure = DoctorHomeCommitmentFailure.from(error);
      if (failure.kind == DoctorHomeCommitmentFailureKind.notFound) {
        _commitment = null;
        _message = null;
        _state = DoctorHomeCommitmentState.noActiveCommitment;
      } else {
        _applyFailure(failure);
      }
    } finally {
      if (_isCurrentDetail(generation, doctorId, token)) {
        _detailToken = null;
      }
    }
  }

  void _applyFailure(DoctorHomeCommitmentFailure failure) {
    _message = failure.message;
    if (failure.kind == DoctorHomeCommitmentFailureKind.sessionRejected) {
      _state = DoctorHomeCommitmentState.failure;
      onSessionRejected?.call();
    } else if (failure.kind == DoctorHomeCommitmentFailureKind.unavailable) {
      _state = DoctorHomeCommitmentState.unavailable;
    } else {
      _state = DoctorHomeCommitmentState.failure;
    }
  }

  void clear() {
    _cancelRequests('Doctor HOME commitment session cleared.');
    _doctorId = null;
    _rolloutAvailable = true;
    _commitment = null;
    _message = null;
    _state = DoctorHomeCommitmentState.initial;
    _notify();
  }

  void _cancelRequests(String reason) {
    _generation++;
    _activeToken?.cancel(reason);
    _detailToken?.cancel(reason);
    _activeToken = null;
    _detailToken = null;
  }

  bool _isCurrentActive(int generation, String doctorId, CancelToken token) =>
      !_disposed &&
      generation == _generation &&
      identical(_activeToken, token) &&
      !token.isCancelled &&
      _doctorId == doctorId;

  bool _isCurrentDetail(int generation, String doctorId, CancelToken token) =>
      !_disposed &&
      generation == _generation &&
      identical(_detailToken, token) &&
      !token.isCancelled &&
      _doctorId == doctorId;

  static bool _isCancellation(Object error) =>
      error is DioException && CancelToken.isCancel(error);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _cancelRequests('Doctor HOME commitment controller disposed.');
    _commitment = null;
    super.dispose();
  }
}
