import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_exception.dart';
import '../../scheduled_care/realtime/scheduled_care_event.dart';
import '../../scheduled_care/realtime/scheduled_care_realtime_coordinator.dart';
import '../active_consultation/doctor_active_consultation.dart';
import 'doctor_medical_record_api.dart';
import 'doctor_medical_record_workspace.dart';

enum DoctorMedicalRecordState {
  detached,
  loading,
  ready,
  accessRequired,
  expired,
  revoked,
  unavailable,
}

class DoctorMedicalRecordController extends ChangeNotifier {
  DoctorMedicalRecordController({required DoctorMedicalRecordApiContract api})
    : _api = api;

  final DoctorMedicalRecordApiContract _api;
  DoctorMedicalRecordWorkspace? _workspace;
  DoctorMedicalRecordState _state = DoctorMedicalRecordState.detached;
  String? _consultationId;
  Future<void>? _refreshFuture;
  bool _pending = false;
  int _generation = 0;
  bool _disposed = false;

  DoctorMedicalRecordWorkspace? get workspace => _workspace;
  DoctorMedicalRecordState get state => _state;
  String? get consultationId => _consultationId;

  void synchronize(DoctorActiveConsultation? consultation) {
    if (consultation == null) {
      clear();
      return;
    }
    synchronizeAccess(
      consultationId: consultation.consultationId,
      accessStatus: consultation.medicalAccessStatus,
    );
  }

  void synchronizeAccess({
    required String consultationId,
    required DoctorConsultationMedicalAccessStatus accessStatus,
  }) {
    final changed = _consultationId != consultationId;
    if (changed) {
      _generation++;
      _consultationId = consultationId;
      _workspace = null;
    }
    switch (accessStatus) {
      case DoctorConsultationMedicalAccessStatus.none:
        _setDenied(DoctorMedicalRecordState.accessRequired);
      case DoctorConsultationMedicalAccessStatus.expired:
        _setDenied(DoctorMedicalRecordState.expired);
      case DoctorConsultationMedicalAccessStatus.revoked:
        _setDenied(DoctorMedicalRecordState.revoked);
      case DoctorConsultationMedicalAccessStatus.unavailable:
        _setDenied(DoctorMedicalRecordState.unavailable);
      case DoctorConsultationMedicalAccessStatus.active:
        if (changed || _state == DoctorMedicalRecordState.detached) {
          unawaited(refresh());
        }
    }
  }

  Future<void> refresh() {
    final id = _consultationId;
    if (_disposed || id == null) return Future<void>.value();
    if (_refreshFuture != null) {
      _pending = true;
      return _refreshFuture!;
    }
    final generation = _generation;
    _state = DoctorMedicalRecordState.loading;
    _notify();
    final started = _load(id, generation);
    _refreshFuture = started;
    return started.whenComplete(() {
      if (identical(_refreshFuture, started)) _refreshFuture = null;
      if (_pending && !_disposed && generation == _generation) {
        _pending = false;
        unawaited(refresh());
      }
    });
  }

  Future<void> _load(String id, int generation) async {
    try {
      final result = await _api.read(id);
      if (_disposed || generation != _generation || _consultationId != id) {
        return;
      }
      _workspace = result;
      _state = DoctorMedicalRecordState.ready;
      _notify();
    } on ApiException catch (error) {
      if (_disposed || generation != _generation || _consultationId != id) {
        return;
      }
      _workspace = null;
      _state = switch (error.code) {
        'CLINICAL_ACCESS_REQUIRED' => DoctorMedicalRecordState.accessRequired,
        'CLINICAL_ACCESS_EXPIRED' => DoctorMedicalRecordState.expired,
        'CLINICAL_ACCESS_REVOKED' => DoctorMedicalRecordState.revoked,
        _ => DoctorMedicalRecordState.unavailable,
      };
      _notify();
    } catch (_) {
      if (_disposed || generation != _generation || _consultationId != id) {
        return;
      }
      _workspace = null;
      _state = DoctorMedicalRecordState.unavailable;
      _notify();
    }
  }

  Future<void> invalidate() {
    if (_consultationId == null) return Future<void>.value();
    _workspace = null;
    _state = DoctorMedicalRecordState.loading;
    _notify();
    return refresh();
  }

  void _setDenied(DoctorMedicalRecordState state) {
    _generation++;
    _workspace = null;
    _state = state;
    _notify();
  }

  void clear() {
    _generation++;
    _consultationId = null;
    _workspace = null;
    _state = DoctorMedicalRecordState.detached;
    _pending = false;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _workspace = null;
    super.dispose();
  }
}

class DoctorMedicalRecordRealtimeTarget implements ScheduledCareRealtimeTarget {
  DoctorMedicalRecordRealtimeTarget(this.controller);

  final DoctorMedicalRecordController controller;
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
        event.type != ScheduledCareEventType.clinicalAccessChanged ||
        event.resourceType != ScheduledCareResourceType.consultation ||
        event.resourceId != controller.consultationId?.toLowerCase()) {
      return Future<void>.value();
    }
    return controller.invalidate();
  }

  @override
  Future<void> resync() => _active && controller.consultationId != null
      ? controller.refresh()
      : Future<void>.value();
  @override
  void dispose() => deactivate();
}
