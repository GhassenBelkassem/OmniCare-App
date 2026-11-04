import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'doctor_home_commitment.dart';
import 'doctor_home_commitment_controller.dart';
import 'doctor_home_dispatch_context.dart';
import 'doctor_home_dispatch_context_repository.dart';

enum DoctorHomeDispatchContextState {
  initial,
  loading,
  available,
  notFound,
  unavailable,
  failure,
}

class DoctorHomeDispatchContextController extends ChangeNotifier {
  DoctorHomeDispatchContextController({
    required DoctorHomeDispatchContextRepositoryContract repository,
    this.onSessionRejected,
  }) : _repository = repository;

  final DoctorHomeDispatchContextRepositoryContract _repository;
  final VoidCallback? onSessionRejected;

  DoctorHomeDispatchContextState _state =
      DoctorHomeDispatchContextState.initial;
  DoctorHomeDispatchContext? _context;
  String? _doctorId;
  String? _attachedCommitmentId;
  int? _attachedCommitmentRevision;
  String? _message;
  int _generation = 0;
  bool _disposed = false;
  CancelToken? _requestToken;

  DoctorHomeDispatchContextState get state => _state;
  DoctorHomeDispatchContext? get dispatchContext => _context;
  String? get message => _message;
  bool get isLoading => _state == DoctorHomeDispatchContextState.loading;

  void attachDoctor(String doctorId) {
    final normalized = doctorId.trim();
    if (normalized.isEmpty) throw ArgumentError.value(doctorId, 'doctorId');
    if (_doctorId == normalized) return;
    _invalidate('Doctor HOME dispatch-context owner changed.');
    _doctorId = normalized;
    _resetPresentation();
    _notify();
  }

  Future<void> synchronizeCommitment({
    required DoctorHomeCommitmentState commitmentState,
    required DoctorHomeCommitment? commitment,
  }) async {
    if (_disposed || _doctorId == null) return;
    if (commitmentState != DoctorHomeCommitmentState.activeCommitment ||
        commitment == null ||
        !commitment.isActive) {
      _invalidate('Active HOME commitment authority is not available.');
      _resetPresentation();
      _notify();
      return;
    }
    await _loadFor(commitment);
  }

  Future<void> _loadFor(DoctorHomeCommitment commitment) async {
    final doctorId = _doctorId;
    if (_disposed || doctorId == null) return;
    final sameAuthority =
        _attachedCommitmentId == commitment.commitmentId &&
        _attachedCommitmentRevision == commitment.revision;
    if (sameAuthority &&
        (_state == DoctorHomeDispatchContextState.loading ||
            _state == DoctorHomeDispatchContextState.available)) {
      return;
    }

    final generation = ++_generation;
    _requestToken?.cancel('HOME dispatch-context request replaced.');
    final token = _requestToken = CancelToken();
    _attachedCommitmentId = commitment.commitmentId;
    _attachedCommitmentRevision = commitment.revision;
    _context = null;
    _message = null;
    _state = DoctorHomeDispatchContextState.loading;
    _notify();
    try {
      final result = await _repository.get(
        commitment.commitmentId,
        cancelToken: token,
      );
      if (!_isCurrent(generation, doctorId, token)) return;
      if (result.commitmentId != commitment.commitmentId ||
          result.commitmentRevision != commitment.revision) {
        throw const FormatException(
          'Stale HOME dispatch-context commitment binding.',
        );
      }
      _context = result;
      _state = DoctorHomeDispatchContextState.available;
    } catch (error) {
      if (!_isCurrent(generation, doctorId, token) || _isCancellation(error)) {
        return;
      }
      _context = null;
      final failure = DoctorHomeDispatchContextFailure.from(error);
      _message = failure.message;
      _state = switch (failure.kind) {
        DoctorHomeDispatchContextFailureKind.notFound =>
          DoctorHomeDispatchContextState.notFound,
        DoctorHomeDispatchContextFailureKind.unavailable =>
          DoctorHomeDispatchContextState.unavailable,
        _ => DoctorHomeDispatchContextState.failure,
      };
      if (failure.kind ==
          DoctorHomeDispatchContextFailureKind.sessionRejected) {
        onSessionRejected?.call();
      }
    } finally {
      if (_isCurrent(generation, doctorId, token)) {
        _requestToken = null;
        _notify();
      }
    }
  }

  void clear() {
    _invalidate('Doctor HOME dispatch-context session cleared.');
    _doctorId = null;
    _resetPresentation();
    _notify();
  }

  void _resetPresentation() {
    _context = null;
    _attachedCommitmentId = null;
    _attachedCommitmentRevision = null;
    _message = null;
    _state = DoctorHomeDispatchContextState.initial;
  }

  void _invalidate(String reason) {
    _generation++;
    _requestToken?.cancel(reason);
    _requestToken = null;
  }

  bool _isCurrent(int generation, String doctorId, CancelToken token) =>
      !_disposed &&
      generation == _generation &&
      identical(_requestToken, token) &&
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
    _invalidate('Doctor HOME dispatch-context controller disposed.');
    _context = null;
    super.dispose();
  }
}
