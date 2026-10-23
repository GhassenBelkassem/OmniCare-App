import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/utils/uuid_v4.dart';
import '../../../scheduled_care/data/scheduled_care_failure.dart';
import '../../../scheduled_care/domain/scheduled_care_models.dart';
import '../data/doctor_scheduled_care_repository.dart';
import '../domain/doctor_scheduled_care_models.dart';

enum DoctorAppointmentLoadState { initial, loading, ready, failed }

class _CancellationIdentity {
  const _CancellationIdentity({
    required this.appointmentId,
    required this.version,
    required this.reason,
    required this.key,
  });

  final String appointmentId;
  final int version;
  final DoctorAppointmentCancellationReason reason;
  final String key;

  bool matches(
    ConfirmedScheduledAppointment appointment,
    DoctorAppointmentCancellationReason otherReason,
  ) =>
      appointmentId == appointment.appointmentId &&
      version == appointment.version &&
      reason == otherReason;
}

class DoctorAppointmentController extends ChangeNotifier {
  DoctorAppointmentController({
    required DoctorScheduledCareRepositoryContract repository,
    required Future<void> Function() refreshAgenda,
    required Future<void> Function() refreshHome,
    String Function() idempotencyKeyFactory = generateUuidV4,
    VoidCallback? onForbidden,
  }) : _repository = repository,
       _refreshAgenda = refreshAgenda,
       _refreshHome = refreshHome,
       _idempotencyKeyFactory = idempotencyKeyFactory,
       _onForbidden = onForbidden;

  final DoctorScheduledCareRepositoryContract _repository;
  final Future<void> Function() _refreshAgenda;
  final Future<void> Function() _refreshHome;
  final String Function() _idempotencyKeyFactory;
  final VoidCallback? _onForbidden;
  ConfirmedScheduledAppointment? _appointment;
  ScheduledCareFailure? _failure;
  DoctorAppointmentLoadState _state = DoctorAppointmentLoadState.initial;
  bool _isCancelling = false;
  CancelToken? _token;
  int _generation = 0;
  _CancellationIdentity? _identity;
  bool _disposed = false;
  String? _realtimeAppointmentId;

  ConfirmedScheduledAppointment? get appointment => _appointment;
  ScheduledCareFailure? get failure => _failure;
  DoctorAppointmentLoadState get state => _state;
  bool get isCancelling => _isCancelling;
  String? get pendingIdempotencyKey => _identity?.key;
  bool get canCancel =>
      !_isCancelling &&
      (_appointment?.availableActions.contains(
            ScheduledAppointmentAction.cancelAppointment,
          ) ??
          false);
  String? get realtimeAppointmentId => _realtimeAppointmentId;

  void activateRealtime(String appointmentId) {
    if (!_disposed) _realtimeAppointmentId = appointmentId.trim();
  }

  void deactivateRealtime(String appointmentId) {
    if (_realtimeAppointmentId == appointmentId.trim()) {
      _realtimeAppointmentId = null;
    }
  }

  Future<void> open(String appointmentId) => _fetch(appointmentId.trim());

  Future<void> refresh() async {
    final id = _appointment?.appointmentId;
    if (id != null) await _fetch(id);
  }

  Future<void> cancel(DoctorAppointmentCancellationReason reason) async {
    final current = _appointment;
    if (_disposed || current == null || !canCancel) return;
    final identity = _identityFor(current, reason);
    final generation = _generation;
    _isCancelling = true;
    _failure = null;
    _notify();
    try {
      final result = await _repository.cancelAppointmentOrReconcile(
        DoctorCancelAppointmentCommand(
          appointmentId: current.appointmentId,
          expectedVersion: current.version,
          reason: reason,
          idempotencyKey: identity.key,
        ),
        cancelToken: _token,
      );
      if (!_isGenerationCurrent(generation)) return;
      _appointment = result.appointment;
      _state = DoctorAppointmentLoadState.ready;
      if (result.intentCompleted) {
        _appointment = await _repository.getAppointment(
          current.appointmentId,
          cancelToken: _token,
        );
        if (!_isGenerationCurrent(generation)) return;
        _identity = null;
        await Future.wait([_refreshAgenda(), _refreshHome()]);
      } else {
        _identity = null;
      }
    } catch (error) {
      if (!_isGenerationCurrent(generation)) return;
      final failure = ScheduledCareFailure.from(error);
      if (failure.requiresAuthoritativeRefresh) {
        await _refetchAfterConflict(current.appointmentId, generation);
      } else {
        _failure = failure;
        if (failure.kind == ScheduledCareFailureKind.forbidden) {
          _onForbidden?.call();
        }
      }
    }
    if (_isGenerationCurrent(generation)) {
      _isCancelling = false;
      _notify();
    }
  }

  Future<void> _refetchAfterConflict(
    String appointmentId,
    int generation,
  ) async {
    try {
      final current = await _repository.getAppointment(
        appointmentId,
        cancelToken: _token,
      );
      if (!_isGenerationCurrent(generation)) return;
      _appointment = current;
      _identity = null;
      _state = DoctorAppointmentLoadState.ready;
      _failure = null;
      await Future.wait([_refreshAgenda(), _refreshHome()]);
    } catch (error) {
      if (_isGenerationCurrent(generation)) {
        _failure = ScheduledCareFailure.from(error);
        if (_failure?.kind == ScheduledCareFailureKind.forbidden) {
          _onForbidden?.call();
        }
      }
    }
  }

  Future<void> _fetch(String appointmentId) async {
    if (_disposed || appointmentId.isEmpty) return;
    final generation = ++_generation;
    _token?.cancel('doctor-appointment-replaced');
    final token = _token = CancelToken();
    _state = DoctorAppointmentLoadState.loading;
    _failure = null;
    _isCancelling = false;
    _identity = null;
    _notify();
    try {
      final value = await _repository.getAppointment(
        appointmentId,
        cancelToken: token,
      );
      if (!_isCurrent(generation, token)) return;
      _appointment = value;
      _state = DoctorAppointmentLoadState.ready;
    } catch (error) {
      if (!_isCurrent(generation, token)) return;
      _appointment = null;
      _failure = ScheduledCareFailure.from(error);
      _state = DoctorAppointmentLoadState.failed;
      if (_failure?.kind == ScheduledCareFailureKind.forbidden) {
        _onForbidden?.call();
      }
    }
    if (_isCurrent(generation, token)) _notify();
  }

  _CancellationIdentity _identityFor(
    ConfirmedScheduledAppointment appointment,
    DoctorAppointmentCancellationReason reason,
  ) {
    final current = _identity;
    if (current?.matches(appointment, reason) ?? false) return current!;
    var suffix = _idempotencyKeyFactory().trim();
    if (suffix.isEmpty) suffix = generateUuidV4();
    var key = 'doctor-cancel-appointment-$suffix';
    if (key.length > 128) key = key.substring(0, 128);
    return _identity = _CancellationIdentity(
      appointmentId: appointment.appointmentId,
      version: appointment.version,
      reason: reason,
      key: key,
    );
  }

  void clear() {
    if (_disposed) return;
    _token?.cancel('doctor-appointment-session-cleared');
    _generation++;
    _appointment = null;
    _failure = null;
    _state = DoctorAppointmentLoadState.initial;
    _isCancelling = false;
    _identity = null;
    _realtimeAppointmentId = null;
    _notify();
  }

  bool _isGenerationCurrent(int generation) =>
      !_disposed && generation == _generation && !(_token?.isCancelled ?? true);
  bool _isCurrent(int generation, CancelToken token) =>
      _isGenerationCurrent(generation) && identical(token, _token);

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _token?.cancel('doctor-appointment-controller-disposed');
    super.dispose();
  }
}
