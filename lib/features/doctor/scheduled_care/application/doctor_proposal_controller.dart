import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/utils/uuid_v4.dart';
import '../../../patient_doctor/application/doctor_directory_controller.dart';
import '../../../patient_doctor/data/doctor_detail_models.dart';
import '../../../patient_doctor/data/doctor_directory_failure.dart';
import '../../../patient_doctor/data/doctor_directory_mapper.dart';
import '../../../patient_doctor/data/doctor_directory_models.dart';
import '../../../scheduled_care/data/scheduled_care_failure.dart';
import '../data/doctor_proposal_availability_repository.dart';
import '../data/doctor_scheduled_care_repository.dart';
import '../domain/doctor_scheduled_care_models.dart';

enum DoctorProposalAvailabilityState { initial, loading, ready, failed }

class _ProposalIdentity {
  const _ProposalIdentity({
    required this.requestId,
    required this.version,
    required this.cabinetId,
    required this.start,
    required this.end,
    required this.key,
  });

  final String requestId;
  final int version;
  final String cabinetId;
  final String start;
  final String end;
  final String key;

  bool matches(
    DoctorBookingRequestDetail request,
    DoctorAvailabilitySlot slot,
  ) =>
      requestId == request.requestId &&
      version == request.version &&
      cabinetId == request.cabinet.practiceLocationId &&
      start == slot.startIso &&
      end == slot.endIso;
}

class DoctorProposalController extends ChangeNotifier {
  DoctorProposalController({
    required String authenticatedDoctorId,
    required DoctorScheduledCareRepositoryContract scheduledCareRepository,
    required DoctorProposalAvailabilityRepositoryContract
    availabilityRepository,
    required ValueChanged<DoctorBookingRequestDetail> onRequestChanged,
    required Future<void> Function() refreshHome,
    String Function() idempotencyKeyFactory = generateUuidV4,
    VoidCallback? onForbidden,
  }) : _doctorId = authenticatedDoctorId.trim(),
       _scheduledCareRepository = scheduledCareRepository,
       _availabilityRepository = availabilityRepository,
       _onRequestChanged = onRequestChanged,
       _refreshHome = refreshHome,
       _idempotencyKeyFactory = idempotencyKeyFactory,
       _onForbidden = onForbidden {
    if (_doctorId.isEmpty) {
      throw ArgumentError.value(authenticatedDoctorId, 'authenticatedDoctorId');
    }
  }

  final String _doctorId;
  final DoctorScheduledCareRepositoryContract _scheduledCareRepository;
  final DoctorProposalAvailabilityRepositoryContract _availabilityRepository;
  final ValueChanged<DoctorBookingRequestDetail> _onRequestChanged;
  final Future<void> Function() _refreshHome;
  final String Function() _idempotencyKeyFactory;
  final VoidCallback? _onForbidden;

  DoctorBookingRequestDetail? _request;
  DateTime? _month;
  List<DoctorDayAvailability> _days = const [];
  String? _timezone;
  DoctorAvailabilitySlot? _selectedSlot;
  DoctorDirectoryFailure? _availabilityFailure;
  ScheduledCareFailure? _submissionFailure;
  DoctorProposalAvailabilityState _availabilityState =
      DoctorProposalAvailabilityState.initial;
  bool _isSubmitting = false;
  bool _proposalCompleted = false;
  CancelToken? _availabilityToken;
  CancelToken? _submissionToken;
  int _generation = 0;
  int _availabilityGeneration = 0;
  _ProposalIdentity? _proposalIdentity;
  bool _disposed = false;

  String get authenticatedDoctorId => _doctorId;
  DoctorBookingRequestDetail? get request => _request;
  DateTime? get month => _month;
  List<DoctorDayAvailability> get days => _days;
  String? get timezone => _timezone;
  DoctorAvailabilitySlot? get selectedSlot => _selectedSlot;
  DoctorDirectoryFailure? get availabilityFailure => _availabilityFailure;
  ScheduledCareFailure? get submissionFailure => _submissionFailure;
  DoctorProposalAvailabilityState get availabilityState => _availabilityState;
  bool get isSubmitting => _isSubmitting;
  bool get proposalCompleted => _proposalCompleted;
  String? get pendingIdempotencyKey => _proposalIdentity?.key;
  bool get canPropose => !_isSubmitting && (_request?.canPropose ?? false);
  bool get canSubmit =>
      canPropose && _selectedSlot != null && !_isOriginal(_selectedSlot!);

  Future<void> begin(
    DoctorBookingRequestDetail request, {
    DateTime? now,
  }) async {
    if (_disposed) return;
    clear(notify: false);
    _request = request;
    _generation++;
    if (!request.canPropose) {
      _availabilityState = DoctorProposalAvailabilityState.ready;
      _notify();
      return;
    }
    await loadMonth(tunisCalendarMonth(now ?? DateTime.now()), now: now);
  }

  Future<void> loadMonth(DateTime value, {DateTime? now}) async {
    final request = _request;
    if (_disposed || request == null || !request.canPropose) return;
    final requestedMonth = DateTime(value.year, value.month);
    AvailabilityRange range;
    try {
      range = availabilityRangeForMonth(
        requestedMonth,
        now: (now ?? DateTime.now()).toUtc(),
      );
    } catch (error) {
      _availabilityFailure = DoctorDirectoryFailure.from(error);
      _availabilityState = DoctorProposalAvailabilityState.failed;
      _notify();
      return;
    }
    final generation = _generation;
    final availabilityGeneration = ++_availabilityGeneration;
    _availabilityToken?.cancel('doctor-proposal-availability-replaced');
    final token = _availabilityToken = CancelToken();
    _month = requestedMonth;
    _selectedSlot = null;
    _availabilityFailure = null;
    _submissionFailure = null;
    _availabilityState = DoctorProposalAvailabilityState.loading;
    _notify();
    try {
      final response = await _availabilityRepository.getSlots(
        doctorId: _doctorId,
        practiceLocationId: request.cabinet.practiceLocationId,
        from: range.from,
        to: range.to,
        cancelToken: token,
      );
      if (!_isAvailabilityCurrent(generation, availabilityGeneration, token)) {
        return;
      }
      if (response.doctorId != _doctorId ||
          response.practiceLocationId != request.cabinet.practiceLocationId ||
          response.timezone != request.cabinet.timezone) {
        throw const DoctorContractException(
          'Proposal availability context does not match the request.',
        );
      }
      final candidates = response.slots
          .where((slot) {
            final start = DateTime.tryParse(slot.start);
            final end = DateTime.tryParse(slot.end);
            return start == null ||
                end == null ||
                start.toUtc() != request.originalRequestedSlot.start.toUtc() ||
                end.toUtc() != request.originalRequestedSlot.end.toUtc();
          })
          .toList(growable: false);
      _days = groupAvailabilitySlots(candidates);
      _timezone = response.timezone;
      _availabilityState = DoctorProposalAvailabilityState.ready;
    } catch (error) {
      if (!_isAvailabilityCurrent(generation, availabilityGeneration, token)) {
        return;
      }
      _days = const [];
      _timezone = null;
      _availabilityFailure = DoctorDirectoryFailure.from(error);
      _availabilityState = DoctorProposalAvailabilityState.failed;
    }
    if (_isAvailabilityCurrent(generation, availabilityGeneration, token)) {
      _notify();
    }
  }

  Future<void> retryAvailability() async {
    final current = _month;
    if (current != null) await loadMonth(current);
  }

  void selectSlot(DoctorAvailabilitySlot slot) {
    if (_disposed || !canPropose || _isOriginal(slot)) return;
    final isAuthoritative = _days.any(
      (day) => day.slots.any(
        (candidate) =>
            candidate.startIso == slot.startIso &&
            candidate.endIso == slot.endIso,
      ),
    );
    if (!isAuthoritative) return;
    if (_selectedSlot?.startIso != slot.startIso ||
        _selectedSlot?.endIso != slot.endIso) {
      _proposalIdentity = null;
    }
    _selectedSlot = slot;
    _submissionFailure = null;
    _notify();
  }

  void clearSelection() {
    if (_disposed || _isSubmitting || _selectedSlot == null) return;
    _selectedSlot = null;
    _proposalIdentity = null;
    _submissionFailure = null;
    _notify();
  }

  Future<bool> submit() async {
    final request = _request;
    final slot = _selectedSlot;
    if (_disposed || request == null || slot == null || !canSubmit) {
      return false;
    }
    final identity = _identityFor(request, slot);
    final generation = _generation;
    _submissionToken?.cancel('doctor-proposal-submission-replaced');
    final token = _submissionToken = CancelToken();
    _isSubmitting = true;
    _submissionFailure = null;
    _proposalCompleted = false;
    _notify();
    try {
      final result = await _scheduledCareRepository.proposeOrReconcile(
        DoctorProposalCommand(
          requestId: request.requestId,
          expectedVersion: request.version,
          practiceLocationId: request.cabinet.practiceLocationId,
          proposedStart: slot.startIso,
          proposedEnd: slot.endIso,
          idempotencyKey: identity.key,
        ),
        cancelToken: token,
      );
      if (!_isSubmissionCurrent(generation, token)) return false;
      _request = result.request;
      _onRequestChanged(result.request);
      _proposalIdentity = null;
      if (result.intentCompleted) {
        _proposalCompleted = true;
        await _refreshHome();
        return _isSubmissionCurrent(generation, token);
      }
      _selectedSlot = null;
      _submissionFailure = const ScheduledCareFailure(
        kind: ScheduledCareFailureKind.requestStateConflict,
        message: 'La demande a changé. Vérifiez son nouvel état.',
        diagnosticCode: 'PROPOSAL_STATE_CHANGED',
      );
    } catch (error) {
      if (!_isSubmissionCurrent(generation, token)) return false;
      final failure = ScheduledCareFailure.from(error);
      if (failure.kind == ScheduledCareFailureKind.slotNoLongerAvailable) {
        _selectedSlot = null;
        _proposalIdentity = null;
        final selectedMonth = _month;
        if (selectedMonth != null) await loadMonth(selectedMonth);
        if (!_isSubmissionCurrent(generation, token)) return false;
        _submissionFailure = failure;
      } else if (failure.requiresAuthoritativeRefresh) {
        await _refreshRequestAfterConflict(
          request.requestId,
          generation,
          token,
        );
      } else {
        _submissionFailure = failure;
        if (failure.kind == ScheduledCareFailureKind.forbidden) {
          _onForbidden?.call();
        }
      }
    } finally {
      if (_isSubmissionCurrent(generation, token)) {
        _isSubmitting = false;
        _notify();
      }
    }
    return false;
  }

  Future<void> _refreshRequestAfterConflict(
    String requestId,
    int generation,
    CancelToken token,
  ) async {
    try {
      final current = await _scheduledCareRepository.getBookingRequest(
        requestId,
        cancelToken: token,
      );
      if (!_isSubmissionCurrent(generation, token)) return;
      _request = current;
      _selectedSlot = null;
      _proposalIdentity = null;
      _onRequestChanged(current);
      _submissionFailure = current.canPropose
          ? const ScheduledCareFailure(
              kind: ScheduledCareFailureKind.versionConflict,
              message: 'La demande a changé. Choisissez à nouveau un créneau.',
              diagnosticCode: 'PROPOSAL_REQUEST_REFRESHED',
            )
          : null;
      await _refreshHome();
    } catch (error) {
      if (_isSubmissionCurrent(generation, token)) {
        _submissionFailure = ScheduledCareFailure.from(error);
        if (_submissionFailure?.kind == ScheduledCareFailureKind.forbidden) {
          _onForbidden?.call();
        }
      }
    }
  }

  _ProposalIdentity _identityFor(
    DoctorBookingRequestDetail request,
    DoctorAvailabilitySlot slot,
  ) {
    final current = _proposalIdentity;
    if (current?.matches(request, slot) ?? false) return current!;
    var suffix = _idempotencyKeyFactory().trim();
    if (suffix.isEmpty) suffix = generateUuidV4();
    var key = 'doctor-proposal-$suffix';
    if (key.length > 128) key = key.substring(0, 128);
    return _proposalIdentity = _ProposalIdentity(
      requestId: request.requestId,
      version: request.version,
      cabinetId: request.cabinet.practiceLocationId,
      start: slot.startIso,
      end: slot.endIso,
      key: key,
    );
  }

  bool _isOriginal(DoctorAvailabilitySlot slot) {
    final original = _request?.originalRequestedSlot;
    if (original == null) return false;
    return slot.start.toUtc() == original.start.toUtc() &&
        slot.end.toUtc() == original.end.toUtc();
  }

  bool _isAvailabilityCurrent(
    int generation,
    int availabilityGeneration,
    CancelToken token,
  ) =>
      !_disposed &&
      !token.isCancelled &&
      generation == _generation &&
      availabilityGeneration == _availabilityGeneration &&
      identical(token, _availabilityToken);

  bool _isSubmissionCurrent(int generation, CancelToken token) =>
      !_disposed &&
      !token.isCancelled &&
      generation == _generation &&
      identical(token, _submissionToken);

  void clear({bool notify = true}) {
    if (_disposed) return;
    _availabilityToken?.cancel('doctor-proposal-session-cleared');
    _submissionToken?.cancel('doctor-proposal-session-cleared');
    _generation++;
    _availabilityGeneration++;
    _request = null;
    _month = null;
    _days = const [];
    _timezone = null;
    _selectedSlot = null;
    _availabilityFailure = null;
    _submissionFailure = null;
    _availabilityState = DoctorProposalAvailabilityState.initial;
    _isSubmitting = false;
    _proposalCompleted = false;
    _proposalIdentity = null;
    if (notify) _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _availabilityToken?.cancel('doctor-proposal-controller-disposed');
    _submissionToken?.cancel('doctor-proposal-controller-disposed');
    super.dispose();
  }
}
