import 'package:flutter/foundation.dart';

import '../../scheduled_care/data/scheduled_care_failure.dart';
import 'doctor_scheduled_care_models.dart';
import 'doctor_scheduled_care_repository.dart';

class DoctorHomeScheduledCareController extends ChangeNotifier {
  DoctorHomeScheduledCareController({
    required DoctorScheduledCareRepository repository,
  }) : _repository = repository;

  final DoctorScheduledCareRepository _repository;
  DoctorHomeSummary? _summary;
  ScheduledCareFailure? _failure;
  bool _loading = false;
  bool _disposed = false;
  int _generation = 0;

  DoctorHomeSummary? get summary => _summary;
  ScheduledCareFailure? get failure => _failure;
  bool get isLoading => _loading;

  Future<void> load() async {
    final generation = ++_generation;
    _loading = true;
    _failure = null;
    _notify();
    try {
      final result = await _repository.getHomeSummary();
      if (generation == _generation) _summary = result;
    } on ScheduledCareFailure catch (failure) {
      if (generation == _generation) _failure = failure;
    } finally {
      if (generation == _generation) {
        _loading = false;
        _notify();
      }
    }
  }

  void clearSessionState() {
    _generation++;
    _summary = null;
    _failure = null;
    _loading = false;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
