import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/utils/uuid_v4.dart';
import '../../../scheduled_care/data/scheduled_care_failure.dart';
import '../../../scheduled_care/domain/scheduled_care_models.dart';
import '../data/doctor_scheduled_care_repository.dart';
import '../domain/doctor_scheduled_care_models.dart';

enum DoctorBookingRequestLoadState { initial, loading, ready, failed }

enum _DoctorMutationKind { accept, decline }

class _DoctorMutationIdentity {
  const _DoctorMutationIdentity({
    required this.kind,
    required this.requestId,
    required this.version,
    required this.reason,
    required this.key,
  });

  final _DoctorMutationKind kind;
  final String requestId;
  final int version;
  final DoctorDeclineReason? reason;
  final String key;

  bool matches(
    _DoctorMutationKind otherKind,
    DoctorBookingRequestDetail request,
    DoctorDeclineReason? otherReason,
  ) =>
      kind == otherKind &&
      requestId == request.requestId &&
      version == request.version &&
      reason == otherReason;
}

class DoctorBookingRequestController extends ChangeNotifier {
  DoctorBookingRequestController({
    required DoctorScheduledCareRepositoryContract repository,
    required Future<void> Function() refreshHome,
    String Function() idempotencyKeyFactory = generateUuidV4,
    VoidCallback? onForbidden,
  }) : _repository = repository,
       _refreshHome = refreshHome,
       _idempotencyKeyFactory = idempotencyKeyFactory,
       _onForbidden = onForbidden;

  final DoctorScheduledCareRepositoryContract _repository;
  final Future<void> Function() _refreshHome;
  final String Function() _idempotencyKeyFactory;
  final VoidCallback? _onForbidden;
  DoctorBookingRequestDetail? _request;
  ConfirmedScheduledAppointment? _appointment;
  ScheduledCareFailure? _failure;
  DoctorBookingRequestLoadState _state = DoctorBookingRequestLoadState.initial;
  bool _isMutating = false;
  CancelToken? _token;
  int _generation = 0;
  _DoctorMutationIdentity? _mutationIdentity;
  bool _disposed = false;
  String? _realtimeRequestId;

  DoctorBookingRequestDetail? get request => _request;
  ConfirmedScheduledAppointment? get appointment => _appointment;
  ScheduledCareFailure? get failure => _failure;
  DoctorBookingRequestLoadState get state => _state;
  bool get isMutating => _isMutating;
  String? get pendingIdempotencyKey => _mutationIdentity?.key;
  bool get canAccept => !_isMutating && (_request?.canAccept ?? false);
  bool get canDecline => !_isMutating && (_request?.canDecline ?? false);
  String? get realtimeRequestId => _realtimeRequestId;

  void activateRealtime(String requestId) {
    if (!_disposed) _realtimeRequestId = requestId.trim();
  }

  void deactivateRealtime(String requestId) {
    if (_realtimeRequestId == requestId.trim()) _realtimeRequestId = null;
  }

  Future<void> open(String requestId) => _fetch(requestId.trim());

  Future<void> refresh() async {
    final id = _request?.requestId;
    if (id != null) await _fetch(id);
  }

  Future<void> refreshIfDeadlinePassed({DateTime? now}) async {
    final current = _request;
    if (current == null ||
        !(now ?? DateTime.now()).isAfter(current.responseDeadline)) {
      return;
    }
    await _fetch(current.requestId);
  }

  /// Applies an authoritative mutation response produced by the proposal flow.
  /// This also invalidates any older detail request still in flight.
  void applyAuthoritativeRequest(DoctorBookingRequestDetail value) {
    if (_disposed ||
        (_request != null && _request!.requestId != value.requestId)) {
      return;
    }
    _token?.cancel('doctor-booking-request-updated-by-proposal');
    _generation++;
    _request = value;
    _appointment = null;
    _failure = null;
    _state = DoctorBookingRequestLoadState.ready;
    _isMutating = false;
    _mutationIdentity = null;
    _notify();
  }

  Future<void> accept() async {
    final current = _request;
    if (current == null || !canAccept) return;
    final identity = _identityFor(_DoctorMutationKind.accept, current, null);
    await _mutate(
      current,
      () => _repository.acceptOrReconcile(
        DoctorAcceptCommand(
          requestId: current.requestId,
          expectedVersion: current.version,
          idempotencyKey: identity.key,
        ),
        cancelToken: _token,
      ),
    );
  }

  Future<void> decline(DoctorDeclineReason reason) async {
    final current = _request;
    if (current == null || !canDecline) return;
    final identity = _identityFor(_DoctorMutationKind.decline, current, reason);
    await _mutate(
      current,
      () => _repository.declineOrReconcile(
        DoctorDeclineCommand(
          requestId: current.requestId,
          expectedVersion: current.version,
          idempotencyKey: identity.key,
          reason: reason,
        ),
        cancelToken: _token,
      ),
    );
  }

  Future<void> _mutate(
    DoctorBookingRequestDetail original,
    Future<DoctorMutationResult> Function() operation,
  ) async {
    if (_disposed || _isMutating) return;
    final generation = _generation;
    _isMutating = true;
    _failure = null;
    _notify();
    try {
      final result = await operation();
      if (!_isGenerationCurrent(generation)) return;
      _request = result.request;
      _appointment = result.appointment;
      _state = DoctorBookingRequestLoadState.ready;
      _mutationIdentity = null;
      if (result.intentCompleted) await _refreshHome();
    } catch (error) {
      if (!_isGenerationCurrent(generation)) return;
      final failure = ScheduledCareFailure.from(error);
      if (failure.requiresAuthoritativeRefresh) {
        await _refetchAfterConflict(original.requestId, generation);
      } else {
        _failure = failure;
        if (failure.kind == ScheduledCareFailureKind.forbidden) {
          _onForbidden?.call();
        }
      }
    }
    if (_isGenerationCurrent(generation)) {
      _isMutating = false;
      _notify();
    }
  }

  Future<void> _refetchAfterConflict(String requestId, int generation) async {
    try {
      final current = await _repository.getBookingRequest(
        requestId,
        cancelToken: _token,
      );
      if (!_isGenerationCurrent(generation)) return;
      _request = current;
      _appointment = null;
      _mutationIdentity = null;
      _state = DoctorBookingRequestLoadState.ready;
      _failure = null;
      await _refreshHome();
    } catch (error) {
      if (_isGenerationCurrent(generation)) {
        _failure = ScheduledCareFailure.from(error);
        if (_failure?.kind == ScheduledCareFailureKind.forbidden) {
          _onForbidden?.call();
        }
      }
    }
  }

  Future<void> _fetch(String requestId) async {
    if (_disposed || requestId.isEmpty) return;
    final generation = ++_generation;
    _token?.cancel('doctor-booking-request-replaced');
    final token = _token = CancelToken();
    _state = DoctorBookingRequestLoadState.loading;
    _failure = null;
    _isMutating = false;
    _mutationIdentity = null;
    _realtimeRequestId = null;
    _notify();
    try {
      final value = await _repository.getBookingRequest(
        requestId,
        cancelToken: token,
      );
      if (!_isCurrent(generation, token)) return;
      _request = value;
      _appointment = null;
      _state = DoctorBookingRequestLoadState.ready;
    } catch (error) {
      if (!_isCurrent(generation, token)) return;
      _request = null;
      _appointment = null;
      _failure = ScheduledCareFailure.from(error);
      _state = DoctorBookingRequestLoadState.failed;
      if (_failure?.kind == ScheduledCareFailureKind.forbidden) {
        _onForbidden?.call();
      }
    }
    if (_isCurrent(generation, token)) _notify();
  }

  _DoctorMutationIdentity _identityFor(
    _DoctorMutationKind kind,
    DoctorBookingRequestDetail request,
    DoctorDeclineReason? reason,
  ) {
    final current = _mutationIdentity;
    if (current?.matches(kind, request, reason) ?? false) return current!;
    var suffix = _idempotencyKeyFactory().trim();
    if (suffix.isEmpty) suffix = generateUuidV4();
    final action = kind == _DoctorMutationKind.accept ? 'accept' : 'decline';
    var key = 'doctor-$action-$suffix';
    if (key.length > 128) key = key.substring(0, 128);
    return _mutationIdentity = _DoctorMutationIdentity(
      kind: kind,
      requestId: request.requestId,
      version: request.version,
      reason: reason,
      key: key,
    );
  }

  void clear() {
    if (_disposed) return;
    _token?.cancel('doctor-booking-session-cleared');
    _generation++;
    _request = null;
    _appointment = null;
    _failure = null;
    _state = DoctorBookingRequestLoadState.initial;
    _isMutating = false;
    _mutationIdentity = null;
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
    _token?.cancel('doctor-booking-controller-disposed');
    super.dispose();
  }
}
