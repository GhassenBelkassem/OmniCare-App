import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../scheduled_care/realtime/scheduled_care_event.dart';
import '../../scheduled_care/realtime/scheduled_care_realtime_coordinator.dart';
import 'doctor_active_consultation.dart';
import 'doctor_active_consultation_api.dart';

enum DoctorActiveConsultationLoadState { detached, loading, ready, failure }

class DoctorActiveConsultationController extends ChangeNotifier {
  DoctorActiveConsultationController({
    required DoctorActiveConsultationApiContract api,
  }) : _api = api;

  final DoctorActiveConsultationApiContract _api;
  DoctorActiveConsultation? _active;
  DoctorActiveConsultationLoadState _state =
      DoctorActiveConsultationLoadState.detached;
  String? _doctorId;
  String? _errorMessage;
  Future<void>? _refreshFuture;
  bool _refreshPending = false;
  int _generation = 0;
  bool _disposed = false;

  DoctorActiveConsultation? get active => _active;
  DoctorActiveConsultationLoadState get state => _state;
  String? get doctorId => _doctorId;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _state == DoctorActiveConsultationLoadState.loading;

  Future<void> attachDoctor(String doctorId) async {
    final normalized = doctorId.trim();
    if (normalized.isEmpty) {
      clear();
      return;
    }
    if (_doctorId != normalized) {
      _generation++;
      _doctorId = normalized;
      _active = null;
      _errorMessage = null;
      _state = DoctorActiveConsultationLoadState.ready;
      _notify();
    }
    await refresh();
  }

  Future<void> refresh() {
    if (_disposed || _doctorId == null) return Future<void>.value();
    final current = _refreshFuture;
    if (current != null) {
      _refreshPending = true;
      return current;
    }
    final generation = _generation;
    _state = DoctorActiveConsultationLoadState.loading;
    _errorMessage = null;
    _notify();
    final started = _load(generation);
    _refreshFuture = started;
    return started.whenComplete(() {
      if (identical(_refreshFuture, started)) _refreshFuture = null;
      if (_refreshPending && !_disposed && generation == _generation) {
        _refreshPending = false;
        unawaited(refresh());
      }
    });
  }

  Future<void> _load(int generation) async {
    try {
      final result = await _api.getActive();
      if (_disposed || generation != _generation) return;
      _active = result;
      _state = DoctorActiveConsultationLoadState.ready;
      _errorMessage = null;
      _notify();
    } catch (_) {
      if (_disposed || generation != _generation) return;
      _state = DoctorActiveConsultationLoadState.failure;
      _errorMessage = 'Synchronisation temporairement indisponible.';
      _notify();
    }
  }

  void clear() {
    _generation++;
    _doctorId = null;
    _active = null;
    _errorMessage = null;
    _refreshPending = false;
    _state = DoctorActiveConsultationLoadState.detached;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _active = null;
    super.dispose();
  }
}

class DoctorActiveConsultationRealtimeTarget
    implements ScheduledCareRealtimeTarget {
  DoctorActiveConsultationRealtimeTarget(this.controller);

  final DoctorActiveConsultationController controller;
  bool _active = false;

  @override
  String get role => 'DOCTOR';

  @override
  void activate() => _active = true;

  @override
  void deactivate() => _active = false;

  @override
  Future<void> invalidate(ScheduledCareInvalidationEvent event) {
    if (!_active ||
        event.resourceType != ScheduledCareResourceType.consultation ||
        !_isConsultationEvent(event.type)) {
      return Future<void>.value();
    }
    final current = controller.active;
    if (current != null &&
        current.consultationId.toLowerCase() == event.resourceId &&
        current.version >= event.version) {
      return Future<void>.value();
    }
    return controller.refresh();
  }

  @override
  Future<void> resync() =>
      _active ? controller.refresh() : Future<void>.value();

  @override
  void dispose() => deactivate();

  static bool _isConsultationEvent(ScheduledCareEventType type) =>
      switch (type) {
        ScheduledCareEventType.consultationActivated ||
        ScheduledCareEventType.consultationUpdated ||
        ScheduledCareEventType.clinicalAccessChanged => true,
        _ => false,
      };
}
