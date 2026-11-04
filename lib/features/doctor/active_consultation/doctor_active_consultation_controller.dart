import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';

import '../../../core/utils/uuid_v4.dart';
import '../../scheduled_care/realtime/scheduled_care_event.dart';
import '../../scheduled_care/realtime/scheduled_care_realtime_coordinator.dart';
import 'doctor_active_consultation.dart';
import 'doctor_active_consultation_api.dart';

enum DoctorActiveConsultationLoadState { detached, loading, ready, failure }

enum DoctorConsultationStartOutcome {
  started,
  recovered,
  activeConflict,
  failed,
}

class _ConsultationStartIdentity {
  const _ConsultationStartIdentity({
    required this.sourceType,
    required this.sourceId,
    required this.version,
    required this.key,
  });

  final DoctorConsultationSourceType sourceType;
  final String sourceId;
  final int version;
  final String key;

  bool matches(
    DoctorConsultationSourceType type,
    String id,
    int expectedVersion,
  ) => sourceType == type && sourceId == id && version == expectedVersion;
}

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
  bool _isStarting = false;
  _ConsultationStartIdentity? _startIdentity;
  Future<DoctorConsultationStartOutcome>? _startFuture;
  String? _startErrorMessage;

  DoctorActiveConsultation? get active => _active;
  DoctorActiveConsultationLoadState get state => _state;
  String? get doctorId => _doctorId;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _state == DoctorActiveConsultationLoadState.loading;
  bool get isStarting => _isStarting;
  String? get startErrorMessage => _startErrorMessage;
  String? get pendingStartIdempotencyKey => _startIdentity?.key;

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

  /// Applies the authoritative Finish result immediately, then reconciles the
  /// server's active-Consultation projection. This never creates a successor.
  Future<void> reconcileCompleted(String consultationId) async {
    if (_disposed || _doctorId == null) return;
    final normalized = consultationId.trim().toLowerCase();
    if (_active?.consultationId.toLowerCase() == normalized) {
      _active = null;
      _state = DoctorActiveConsultationLoadState.ready;
      _errorMessage = null;
      _notify();
    }
    await refresh();
  }

  Future<DoctorConsultationStartOutcome> startScheduled(
    String appointmentId,
    int expectedAppointmentVersion, {
    String Function() idempotencyKeyFactory = generateUuidV4,
  }) => _startCanonical(
    DoctorConsultationSourceType.scheduledAppointment,
    appointmentId,
    expectedAppointmentVersion,
    idempotencyKeyFactory: idempotencyKeyFactory,
  );

  Future<DoctorConsultationStartOutcome> startUrgentCabinet(
    String commitmentId,
    int expectedCommitmentRevision, {
    String Function() idempotencyKeyFactory = generateUuidV4,
  }) => _startCanonical(
    DoctorConsultationSourceType.urgentCabinet,
    commitmentId,
    expectedCommitmentRevision,
    idempotencyKeyFactory: idempotencyKeyFactory,
  );

  Future<DoctorConsultationStartOutcome> _startCanonical(
    DoctorConsultationSourceType sourceType,
    String sourceId,
    int expectedSourceVersion, {
    required String Function() idempotencyKeyFactory,
  }) {
    final normalizedId = sourceId.trim();
    if (_disposed ||
        _doctorId == null ||
        normalizedId.isEmpty ||
        expectedSourceVersion < 0) {
      return Future<DoctorConsultationStartOutcome>.value(
        DoctorConsultationStartOutcome.failed,
      );
    }
    final inFlight = _startFuture;
    if (inFlight != null) return inFlight;
    final currentIdentity = _startIdentity;
    final identity =
        currentIdentity?.matches(
              sourceType,
              normalizedId,
              expectedSourceVersion,
            ) ==
            true
        ? currentIdentity!
        : _ConsultationStartIdentity(
            sourceType: sourceType,
            sourceId: normalizedId,
            version: expectedSourceVersion,
            key: _startKey(idempotencyKeyFactory),
          );
    _startIdentity = identity;
    _isStarting = true;
    _startErrorMessage = null;
    _notify();
    final generation = _generation;
    final started = _start(identity, generation);
    _startFuture = started;
    return started.whenComplete(() {
      if (identical(_startFuture, started)) _startFuture = null;
      if (!_disposed && generation == _generation) {
        _isStarting = false;
        _notify();
      }
    });
  }

  Future<DoctorConsultationStartOutcome> _start(
    _ConsultationStartIdentity identity,
    int generation,
  ) async {
    try {
      final consultation =
          identity.sourceType ==
              DoctorConsultationSourceType.scheduledAppointment
          ? await _api.startScheduled(
              appointmentId: identity.sourceId,
              expectedAppointmentVersion: identity.version,
              idempotencyKey: identity.key,
            )
          : await (_api as DoctorCanonicalConsultationStartApiContract)
                .startCanonical(
                  sourceType: identity.sourceType,
                  sourceId: identity.sourceId,
                  expectedSourceVersion: identity.version,
                  idempotencyKey: identity.key,
                );
      if (_disposed || generation != _generation) {
        return DoctorConsultationStartOutcome.failed;
      }
      _active = consultation;
      _state = DoctorActiveConsultationLoadState.ready;
      _startIdentity = null;
      return DoctorConsultationStartOutcome.started;
    } catch (error) {
      try {
        final active = await _api.getActive();
        if (_disposed || generation != _generation) {
          return DoctorConsultationStartOutcome.failed;
        }
        _active = active;
        _state = DoctorActiveConsultationLoadState.ready;
        if (_matchesSource(active, identity.sourceType, identity.sourceId)) {
          _startIdentity = null;
          return DoctorConsultationStartOutcome.recovered;
        }
        if (active != null) {
          _startIdentity = null;
          _startErrorMessage = 'Une consultation est déjà en cours.';
          return DoctorConsultationStartOutcome.activeConflict;
        }
      } catch (_) {
        // Keep the safe Start failure below when authority cannot be refreshed.
      }
      if (!_isAmbiguous(error)) _startIdentity = null;
      _startErrorMessage =
          'Impossible de démarrer la consultation. Veuillez réessayer.';
      return DoctorConsultationStartOutcome.failed;
    }
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
    _isStarting = false;
    _startIdentity = null;
    _startFuture = null;
    _startErrorMessage = null;
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

String _startKey(String Function() factory) {
  var suffix = factory().trim();
  if (suffix.isEmpty) suffix = generateUuidV4();
  var key = 'doctor-start-consultation-$suffix';
  if (key.length > 128) key = key.substring(0, 128);
  return key;
}

bool _matchesSource(
  DoctorActiveConsultation? value,
  DoctorConsultationSourceType sourceType,
  String sourceId,
) => value?.sourceType == sourceType && value?.sourceId == sourceId;

bool _isAmbiguous(Object error) {
  if (error is! DioException) return false;
  if (error.response?.statusCode case final status? when status >= 500) {
    return true;
  }
  return error.response == null;
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
        ScheduledCareEventType.clinicalAccessChanged ||
        ScheduledCareEventType.consultationCompleted => true,
        _ => false,
      };
}
