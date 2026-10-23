import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../scheduled_care/data/scheduled_care_failure.dart';
import '../data/doctor_scheduled_care_repository.dart';
import '../domain/doctor_scheduled_care_models.dart';

enum DoctorHomeLoadState { initial, loading, ready, failed }

class DoctorHomeController extends ChangeNotifier {
  DoctorHomeController({
    required DoctorScheduledCareRepositoryContract repository,
    VoidCallback? onForbidden,
  }) : _repository = repository,
       _onForbidden = onForbidden;

  final DoctorScheduledCareRepositoryContract _repository;
  final VoidCallback? _onForbidden;
  DoctorHomeSummary? _summary;
  ScheduledCareFailure? _failure;
  DoctorHomeLoadState _state = DoctorHomeLoadState.initial;
  CancelToken? _token;
  int _generation = 0;
  bool _disposed = false;
  bool _realtimeActive = false;

  DoctorHomeSummary? get summary => _summary;
  ScheduledCareFailure? get failure => _failure;
  DoctorHomeLoadState get state => _state;
  bool get isLoading => _state == DoctorHomeLoadState.loading;
  bool get hasLoaded => _state != DoctorHomeLoadState.initial;
  bool get realtimeActive => _realtimeActive;

  void setRealtimeActive(bool value) {
    if (!_disposed) _realtimeActive = value;
  }

  Future<void> load() => refresh();

  Future<void> refresh() async {
    if (_disposed) return;
    final generation = ++_generation;
    _token?.cancel('doctor-home-request-replaced');
    final token = _token = CancelToken();
    _failure = null;
    _state = DoctorHomeLoadState.loading;
    _notify();
    try {
      final summary = await _repository.getHomeSummary(cancelToken: token);
      if (!_isCurrent(generation, token)) return;
      _summary = summary;
      _state = DoctorHomeLoadState.ready;
    } catch (error) {
      if (!_isCurrent(generation, token)) return;
      _failure = ScheduledCareFailure.from(error);
      _state = DoctorHomeLoadState.failed;
      if (_failure?.kind == ScheduledCareFailureKind.forbidden) {
        _onForbidden?.call();
      }
    }
    if (_isCurrent(generation, token)) _notify();
  }

  void clear() {
    if (_disposed) return;
    _token?.cancel('doctor-home-session-cleared');
    _generation++;
    _summary = null;
    _failure = null;
    _state = DoctorHomeLoadState.initial;
    _realtimeActive = false;
    _notify();
  }

  bool _isCurrent(int generation, CancelToken token) =>
      !_disposed && !token.isCancelled && generation == _generation;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _token?.cancel('doctor-home-controller-disposed');
    super.dispose();
  }
}
