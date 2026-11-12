import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/utils/uuid_v4.dart';
import '../../patient_doctor/data/doctor_detail_models.dart';
import '../data/scheduled_care_failure.dart';
import '../data/scheduled_care_repository.dart';
import '../domain/patient_scheduled_care_models.dart';
import '../domain/scheduled_care_models.dart';

enum PatientBookingStatus { idle, draft, submitting, succeeded, failed }

enum PatientBookingLifecycleActivity {
  idle,
  refreshing,
  cancelling,
  acceptingProposal,
  decliningProposal,
  loadingAppointment,
  cancellingAppointment,
}

enum _MutationKind { cancel, acceptProposal, declineProposal }

class PatientBookingIntent {
  const PatientBookingIntent({
    required this.requestId,
    required this.subject,
    required this.doctor,
    required this.cabinet,
    required this.requestedSlot,
    this.preSubmitPrice,
  });

  final String requestId;
  final CareSubject subject;
  final DoctorProjection doctor;
  final PracticeLocation cabinet;
  final RequestedSlot requestedSlot;
  final PriceQuote? preSubmitPrice;

  CreateBookingRequestCommand get command => CreateBookingRequestCommand(
    requestId: requestId,
    doctorId: doctor.doctorId,
    practiceLocationId: cabinet.practiceLocationId,
    subject: subject,
    requestedSlot: requestedSlot,
  );
}

class _MutationIdentity {
  const _MutationIdentity({
    required this.kind,
    required this.requestId,
    required this.expectedVersion,
    required this.idempotencyKey,
    this.proposalId,
    this.reason,
  });

  final _MutationKind kind;
  final String requestId;
  final int expectedVersion;
  final String idempotencyKey;
  final String? proposalId;
  final PatientCancellationReason? reason;

  bool matches({
    required _MutationKind kind,
    required String requestId,
    required int expectedVersion,
    String? proposalId,
    PatientCancellationReason? reason,
  }) =>
      this.kind == kind &&
      this.requestId == requestId &&
      this.expectedVersion == expectedVersion &&
      this.proposalId == proposalId &&
      this.reason == reason;
}

class _AppointmentCancellationIdentity {
  const _AppointmentCancellationIdentity({
    required this.appointmentId,
    required this.expectedVersion,
    required this.reason,
    required this.idempotencyKey,
  });

  final String appointmentId;
  final int expectedVersion;
  final AppointmentCancellationReason? reason;
  final String idempotencyKey;

  bool matches(
    ConfirmedScheduledAppointment appointment,
    AppointmentCancellationReason? reason,
  ) =>
      appointmentId == appointment.appointmentId &&
      expectedVersion == appointment.version &&
      this.reason == reason;
}

class PatientBookingController extends ChangeNotifier {
  PatientBookingController({
    required ScheduledCareRepositoryContract repository,
    ScheduledCareLifecycleRepositoryContract? lifecycleRepository,
    ScheduledAppointmentRepositoryContract? appointmentRepository,
    String Function() requestIdFactory = generateUuidV4,
    String Function() idempotencyKeyFactory = generateUuidV4,
  }) : _repository = repository,
       _lifecycleRepository = lifecycleRepository ?? _lifecycleFrom(repository),
       _appointmentRepository =
           appointmentRepository ?? _appointmentFrom(repository),
       _requestIdFactory = requestIdFactory,
       _idempotencyKeyFactory = idempotencyKeyFactory;

  final ScheduledCareRepositoryContract _repository;
  final ScheduledCareLifecycleRepositoryContract? _lifecycleRepository;
  final ScheduledAppointmentRepositoryContract? _appointmentRepository;
  final String Function() _requestIdFactory;
  final String Function() _idempotencyKeyFactory;

  CareSubject _subject = const CareSubject.self(displayName: 'Moi');
  PatientBookingIntent? _intent;
  PatientBookingRequestDetail? _result;
  ConfirmedScheduledAppointment? _appointment;
  ScheduledCareFailure? _failure;
  PatientBookingStatus _status = PatientBookingStatus.idle;
  PatientBookingLifecycleActivity _lifecycleActivity =
      PatientBookingLifecycleActivity.idle;
  _MutationIdentity? _pendingMutation;
  _AppointmentCancellationIdentity? _pendingAppointmentCancellation;
  bool _mutationBlocked = false;
  CancelToken? _submitToken;
  CancelToken? _lifecycleToken;
  int _generation = 0;
  bool _disposed = false;
  String? _realtimeRequestId;
  String? _realtimeAppointmentId;

  CareSubject get subject => _subject;
  PatientBookingIntent? get intent => _intent;
  PatientBookingRequestDetail? get result => _result;
  ConfirmedScheduledAppointment? get appointment => _appointment;
  ScheduledCareFailure? get failure => _failure;
  PatientBookingStatus get status => _status;
  PatientBookingLifecycleActivity get lifecycleActivity => _lifecycleActivity;
  bool get isSubmitting => _status == PatientBookingStatus.submitting;
  bool get isLifecycleBusy =>
      _lifecycleActivity != PatientBookingLifecycleActivity.idle;
  String? get pendingIdempotencyKey => _pendingMutation?.idempotencyKey;
  String? get pendingAppointmentCancellationKey =>
      _pendingAppointmentCancellation?.idempotencyKey;
  String? get realtimeRequestId => _realtimeRequestId;
  String? get realtimeAppointmentId => _realtimeAppointmentId;

  void activateRealtimeRequest(String requestId) {
    if (!_disposed) _realtimeRequestId = requestId.trim();
  }

  void deactivateRealtimeRequest(String requestId) {
    if (_realtimeRequestId == requestId.trim()) _realtimeRequestId = null;
  }

  void activateRealtimeAppointment(String appointmentId) {
    if (!_disposed) _realtimeAppointmentId = appointmentId.trim();
  }

  void deactivateRealtimeAppointment(String appointmentId) {
    if (_realtimeAppointmentId == appointmentId.trim()) {
      _realtimeAppointmentId = null;
    }
  }

  bool get canCancel =>
      !isLifecycleBusy &&
      !_mutationBlocked &&
      _result?.status != BookingRequestStatus.unknown &&
      (_result?.availableActions.contains(AvailableAction.cancelRequest) ??
          false);
  bool get canAcceptProposal =>
      !isLifecycleBusy &&
      !_mutationBlocked &&
      _result?.status == BookingRequestStatus.pendingPatientTimeConfirmation &&
      _result?.proposedSlot != null &&
      (_result?.availableActions.contains(AvailableAction.acceptProposedTime) ??
          false);
  bool get canDeclineProposal =>
      !isLifecycleBusy &&
      !_mutationBlocked &&
      _result?.status == BookingRequestStatus.pendingPatientTimeConfirmation &&
      _result?.proposedSlot != null &&
      (_result?.availableActions.contains(
            AvailableAction.declineProposedTime,
          ) ??
          false);
  bool get canCancelAppointment =>
      !isLifecycleBusy &&
      !_mutationBlocked &&
      (_appointment?.availableActions.contains(
            ScheduledAppointmentAction.cancelAppointment,
          ) ??
          false);

  DateTime? get authoritativeDeadline {
    final request = _result;
    if (request == null) return null;
    if (request.status == BookingRequestStatus.pendingPatientTimeConfirmation) {
      return request.proposedSlot?.patientResponseDeadline ??
          request.responseDeadline;
    }
    if (request.status == BookingRequestStatus.pendingDoctor) {
      return request.responseDeadline;
    }
    return null;
  }

  void selectSubject(CareSubject subject) {
    if (_disposed || isSubmitting) return;
    _subject = subject;
    _clearIntent();
    _status = PatientBookingStatus.idle;
    _notify();
  }

  void prepareIntent({
    required DoctorDetail doctor,
    required PracticeLocation cabinet,
    required DoctorAvailabilitySlot slot,
  }) {
    if (_disposed || isSubmitting) return;
    if (cabinet.practiceLocationId.trim().isEmpty) {
      throw const ScheduledCareContractException(
        'A persisted practice location id is required.',
      );
    }
    final current = _intent;
    final sameSemanticIntent =
        current != null &&
        current.subject.subjectType == _subject.subjectType &&
        current.subject.familyMemberId == _subject.familyMemberId &&
        current.doctor.doctorId == doctor.id &&
        current.cabinet.practiceLocationId == cabinet.practiceLocationId &&
        current.requestedSlot.start == slot.start &&
        current.requestedSlot.end == slot.end;
    final requestId = sameSemanticIntent
        ? current.requestId
        : _requestIdFactory();
    _cancelAsync('booking-intent-replaced');
    _generation++;
    _intent = PatientBookingIntent(
      requestId: requestId,
      subject: _subject,
      doctor: DoctorProjection(
        doctorId: doctor.id,
        displayName: doctor.name,
        specialty: doctor.specialty,
      ),
      cabinet: cabinet,
      // The server instants, unchanged: the backend revalidates them against
      // its slot grid. Tunis wall clock is for display only.
      requestedSlot: RequestedSlot(
        start: slot.start,
        end: slot.end,
        durationMinutes: slot.durationMinutes,
      ),
      preSubmitPrice: doctor.consultationPriceTnd == null
          ? null
          : PriceQuote(amount: doctor.consultationPriceTnd!, currency: 'TND'),
    );
    _result = null;
    _appointment = null;
    _pendingMutation = null;
    _pendingAppointmentCancellation = null;
    _mutationBlocked = false;
    _failure = null;
    _status = PatientBookingStatus.draft;
    _lifecycleActivity = PatientBookingLifecycleActivity.idle;
    _notify();
  }

  Future<void> submit() async {
    if (_disposed ||
        isSubmitting ||
        _status == PatientBookingStatus.succeeded) {
      return;
    }
    final intent = _intent;
    if (intent == null) return;

    final generation = ++_generation;
    final token = _submitToken = CancelToken();
    _status = PatientBookingStatus.submitting;
    _failure = null;
    _notify();
    try {
      final result = await _repository.createOrReconcile(
        intent.command,
        cancelToken: token,
      );
      if (!_isCurrent(generation, token)) return;
      if (result.requestId != intent.requestId ||
          result.doctor.doctorId != intent.doctor.doctorId ||
          result.cabinet.practiceLocationId !=
              intent.cabinet.practiceLocationId ||
          result.cabinet.timezone != intent.cabinet.timezone ||
          result.subject.subjectType != intent.subject.subjectType ||
          result.subject.familyMemberId != intent.subject.familyMemberId ||
          result.originalRequestedSlot.start != intent.requestedSlot.start ||
          result.originalRequestedSlot.end != intent.requestedSlot.end) {
        throw const ScheduledCareContractException(
          'Creation response does not match the booking intent.',
        );
      }
      _applyRequest(result);
      _failure = null;
      _status = PatientBookingStatus.succeeded;
    } catch (error) {
      if (!_isCurrent(generation, token)) return;
      _failure = ScheduledCareFailure.from(error);
      _status = PatientBookingStatus.failed;
    }
    _notify();
  }

  Future<void> openRequest(String requestId) async {
    final normalized = requestId.trim();
    if (normalized.isEmpty || isLifecycleBusy || _disposed) return;
    await _refreshById(normalized);
  }

  Future<void> refresh() async {
    final requestId = _result?.requestId ?? _intent?.requestId;
    if (requestId == null || isLifecycleBusy || _disposed) return;
    await _refreshById(requestId);
  }

  Future<bool> refreshAtDeadline({DateTime? now}) async {
    final deadline = authoritativeDeadline;
    if (deadline == null ||
        (now ?? DateTime.now().toUtc()).isBefore(deadline)) {
      return false;
    }
    await refresh();
    return true;
  }

  Future<void> cancelRequest(PatientCancellationReason reason) async {
    final request = _result;
    if (request == null || !canCancel) return;
    if (reason == PatientCancellationReason.proposalDeclined) {
      throw const ScheduledCareContractException(
        'Proposal decline is not a normal cancellation reason.',
      );
    }
    final identity = _identityFor(
      kind: _MutationKind.cancel,
      request: request,
      reason: reason,
    );
    final command = CancelBookingRequestCommand(
      requestId: request.requestId,
      expectedVersion: request.version,
      idempotencyKey: identity.idempotencyKey,
      reason: reason,
    );
    await _runMutation(
      activity: PatientBookingLifecycleActivity.cancelling,
      invoke: (repository, token) =>
          repository.cancelOrReconcile(command, cancelToken: token),
    );
  }

  Future<void> acceptProposal() async {
    final request = _result;
    final proposal = request?.proposedSlot;
    if (request == null || proposal == null || !canAcceptProposal) return;
    final identity = _identityFor(
      kind: _MutationKind.acceptProposal,
      request: request,
      proposalId: proposal.proposalId,
    );
    final command = AcceptBookingProposalCommand(
      requestId: request.requestId,
      proposalId: proposal.proposalId,
      expectedVersion: request.version,
      idempotencyKey: identity.idempotencyKey,
    );
    await _runMutation(
      activity: PatientBookingLifecycleActivity.acceptingProposal,
      invoke: (repository, token) =>
          repository.acceptProposalOrReconcile(command, cancelToken: token),
    );
  }

  Future<void> declineProposal() async {
    final request = _result;
    final proposal = request?.proposedSlot;
    if (request == null || proposal == null || !canDeclineProposal) return;
    final identity = _identityFor(
      kind: _MutationKind.declineProposal,
      request: request,
      proposalId: proposal.proposalId,
      reason: PatientCancellationReason.proposalDeclined,
    );
    final command = DeclineBookingProposalCommand(
      requestId: request.requestId,
      proposalId: proposal.proposalId,
      expectedVersion: request.version,
      idempotencyKey: identity.idempotencyKey,
    );
    await _runMutation(
      activity: PatientBookingLifecycleActivity.decliningProposal,
      invoke: (repository, token) =>
          repository.declineProposalOrReconcile(command, cancelToken: token),
    );
  }

  Future<void> loadConfirmedAppointment() async {
    final request = _result;
    final appointmentId = request?.confirmedAppointmentId;
    final repository = _lifecycleRepository;
    if (request == null ||
        request.status != BookingRequestStatus.fulfilled ||
        appointmentId == null ||
        repository == null ||
        isLifecycleBusy ||
        _disposed) {
      return;
    }
    final generation = ++_generation;
    final token = _replaceLifecycleToken('appointment-detail-replaced');
    _lifecycleActivity = PatientBookingLifecycleActivity.loadingAppointment;
    _failure = null;
    _notify();
    try {
      final appointment = await repository.getAppointment(
        appointmentId,
        cancelToken: token,
      );
      if (!_isCurrent(generation, token)) return;
      ProposalAcceptanceResult.validated(request, appointment);
      _appointment = appointment;
    } catch (error) {
      if (!_isCurrent(generation, token)) return;
      _failure = ScheduledCareFailure.from(error);
    }
    if (_isCurrent(generation, token)) {
      _lifecycleActivity = PatientBookingLifecycleActivity.idle;
      _notify();
    }
  }

  /// Resolves a typed appointment identity without relying on a remembered
  /// booking request. This is the re-entry/deep-link path used by history.
  Future<void> openAppointment(String appointmentId) async {
    final normalized = appointmentId.trim();
    final repository = _lifecycleRepository;
    if (normalized.isEmpty ||
        repository == null ||
        isLifecycleBusy ||
        _disposed) {
      return;
    }
    final generation = ++_generation;
    final token = _replaceLifecycleToken('appointment-detail-replaced');
    _lifecycleActivity = PatientBookingLifecycleActivity.loadingAppointment;
    _failure = null;
    _result = null;
    _appointment = null;
    _pendingMutation = null;
    _pendingAppointmentCancellation = null;
    _mutationBlocked = false;
    _notify();
    try {
      final appointment = await repository.getAppointment(
        normalized,
        cancelToken: token,
      );
      if (!_isCurrent(generation, token)) return;
      if (appointment.appointmentId != normalized) {
        throw const ScheduledCareContractException(
          'Appointment response identity does not match the requested resource.',
        );
      }
      _appointment = appointment;
    } catch (error) {
      if (!_isCurrent(generation, token)) return;
      final failure = ScheduledCareFailure.from(error);
      _failure = failure;
      if (failure.kind == ScheduledCareFailureKind.forbidden) {
        _appointment = null;
      }
    }
    if (_isCurrent(generation, token)) {
      _lifecycleActivity = PatientBookingLifecycleActivity.idle;
      _notify();
    }
  }

  Future<void> cancelAppointment(AppointmentCancellationReason? reason) async {
    final appointment = _appointment;
    final repository = _appointmentRepository;
    if (appointment == null || repository == null || !canCancelAppointment) {
      return;
    }
    final current = _pendingAppointmentCancellation;
    final identity = current?.matches(appointment, reason) ?? false
        ? current!
        : _newAppointmentCancellationIdentity(appointment, reason);
    final command = CancelScheduledAppointmentCommand(
      appointmentId: appointment.appointmentId,
      expectedVersion: appointment.version,
      idempotencyKey: identity.idempotencyKey,
      reason: reason,
    );
    final generation = ++_generation;
    final token = _replaceLifecycleToken('appointment-cancellation-replaced');
    _lifecycleActivity = PatientBookingLifecycleActivity.cancellingAppointment;
    _failure = null;
    _notify();
    try {
      final outcome = await repository.cancelAppointmentOrReconcile(
        command,
        cancelToken: token,
      );
      if (!_isCurrent(generation, token)) return;
      _appointment = outcome.appointment;
      _pendingAppointmentCancellation = null;
      if (!outcome.intentCompleted) {
        _failure = const ScheduledCareFailure(
          kind: ScheduledCareFailureKind.requestStateConflict,
          message: 'Le rendez-vous a changé. Son état a été actualisé.',
          diagnosticCode: 'APPOINTMENT_STATE_CHANGED_DURING_RECOVERY',
        );
      }
    } catch (error) {
      if (!_isCurrent(generation, token)) return;
      final failure = ScheduledCareFailure.from(error);
      _failure = failure;
      if (failure.kind == ScheduledCareFailureKind.idempotencyConflict ||
          failure.kind == ScheduledCareFailureKind.unauthenticated ||
          failure.kind == ScheduledCareFailureKind.forbidden ||
          failure.kind == ScheduledCareFailureKind.notFound) {
        _pendingAppointmentCancellation = null;
        _mutationBlocked = true;
      }
      if (failure.requiresAuthoritativeRefresh) {
        try {
          final refreshed = await _lifecycleRepository?.getAppointment(
            appointment.appointmentId,
            cancelToken: token,
          );
          if (!_isCurrent(generation, token)) return;
          if (refreshed != null) _appointment = refreshed;
          _pendingAppointmentCancellation = null;
        } catch (_) {
          // Keep the safe failure; retrying the GET never replays the command.
        }
      }
      if (failure.kind == ScheduledCareFailureKind.forbidden) {
        _appointment = null;
      }
    }
    if (_isCurrent(generation, token)) {
      _lifecycleActivity = PatientBookingLifecycleActivity.idle;
      _notify();
    }
  }

  Future<void> _refreshById(String requestId) async {
    final repository = _lifecycleRepository;
    if (repository == null) return;
    final generation = ++_generation;
    final token = _replaceLifecycleToken('request-refresh-replaced');
    _lifecycleActivity = PatientBookingLifecycleActivity.refreshing;
    _failure = null;
    _notify();
    try {
      final request = await repository.getBookingRequest(
        requestId,
        cancelToken: token,
      );
      if (!_isCurrent(generation, token)) return;
      _applyRequest(request);
      _mutationBlocked = false;
      await _loadAppointmentForRequest(
        request,
        repository: repository,
        generation: generation,
        token: token,
      );
    } catch (error) {
      if (!_isCurrent(generation, token)) return;
      _failure = ScheduledCareFailure.from(error);
    }
    if (_isCurrent(generation, token)) {
      _lifecycleActivity = PatientBookingLifecycleActivity.idle;
      _notify();
    }
  }

  Future<void> _runMutation({
    required PatientBookingLifecycleActivity activity,
    required Future<BookingMutationResult> Function(
      ScheduledCareLifecycleRepositoryContract repository,
      CancelToken token,
    )
    invoke,
  }) async {
    final repository = _lifecycleRepository;
    final requestId = _result?.requestId;
    if (repository == null || requestId == null || isLifecycleBusy) return;
    final generation = ++_generation;
    final token = _replaceLifecycleToken('booking-mutation-replaced');
    _lifecycleActivity = activity;
    _failure = null;
    _notify();
    try {
      final outcome = await invoke(repository, token);
      if (!_isCurrent(generation, token)) return;
      _applyRequest(outcome.request);
      if (outcome.appointment != null) {
        ProposalAcceptanceResult.validated(
          outcome.request,
          outcome.appointment!,
        );
        _appointment = outcome.appointment;
      }
      if (outcome.intentCompleted) {
        _pendingMutation = null;
        if (outcome.request.status == BookingRequestStatus.fulfilled &&
            _appointment == null) {
          await _loadAppointmentForRequest(
            outcome.request,
            repository: repository,
            generation: generation,
            token: token,
          );
        }
      } else {
        _pendingMutation = null;
        _failure = const ScheduledCareFailure(
          kind: ScheduledCareFailureKind.requestStateConflict,
          message: 'La demande a changé. Son état a été actualisé.',
          diagnosticCode: 'REQUEST_STATE_CHANGED_DURING_RECOVERY',
        );
      }
    } catch (error) {
      if (!_isCurrent(generation, token)) return;
      final failure = ScheduledCareFailure.from(error);
      _failure = failure;
      if (failure.kind == ScheduledCareFailureKind.idempotencyConflict ||
          failure.kind == ScheduledCareFailureKind.unauthenticated ||
          failure.kind == ScheduledCareFailureKind.forbidden ||
          failure.kind == ScheduledCareFailureKind.notFound) {
        _mutationBlocked = true;
        _pendingMutation = null;
      }
      if (failure.requiresAuthoritativeRefresh) {
        try {
          final refreshed = await repository.getBookingRequest(
            requestId,
            cancelToken: token,
          );
          if (!_isCurrent(generation, token)) return;
          _applyRequest(refreshed);
          _pendingMutation = null;
          await _loadAppointmentForRequest(
            refreshed,
            repository: repository,
            generation: generation,
            token: token,
          );
        } catch (_) {
          // Keep the safe mutation failure. The explicit refresh control can
          // retry the authoritative GET without replaying the stale command.
        }
      }
    }
    if (_isCurrent(generation, token)) {
      _lifecycleActivity = PatientBookingLifecycleActivity.idle;
      _notify();
    }
  }

  Future<void> _loadAppointmentForRequest(
    PatientBookingRequestDetail request, {
    required ScheduledCareLifecycleRepositoryContract repository,
    required int generation,
    required CancelToken token,
  }) async {
    if (request.status != BookingRequestStatus.fulfilled) {
      _appointment = null;
      return;
    }
    final appointmentId = request.confirmedAppointmentId;
    if (appointmentId == null) {
      throw const ScheduledCareContractException(
        'Fulfilled request has no confirmed appointment id.',
      );
    }
    if (_appointment?.appointmentId == appointmentId &&
        _appointment?.sourceBookingRequestId == request.requestId) {
      return;
    }
    final appointment = await repository.getAppointment(
      appointmentId,
      cancelToken: token,
    );
    if (!_isCurrent(generation, token)) return;
    ProposalAcceptanceResult.validated(request, appointment);
    _appointment = appointment;
  }

  _MutationIdentity _identityFor({
    required _MutationKind kind,
    required PatientBookingRequestDetail request,
    String? proposalId,
    PatientCancellationReason? reason,
  }) {
    final current = _pendingMutation;
    if (current?.matches(
          kind: kind,
          requestId: request.requestId,
          expectedVersion: request.version,
          proposalId: proposalId,
          reason: reason,
        ) ??
        false) {
      return current!;
    }
    final prefix = switch (kind) {
      _MutationKind.cancel => 'patient-cancel',
      _MutationKind.acceptProposal => 'patient-proposal-accept',
      _MutationKind.declineProposal => 'patient-proposal-decline',
    };
    var suffix = _idempotencyKeyFactory().trim();
    if (suffix.isEmpty) suffix = generateUuidV4();
    var key = '$prefix-$suffix';
    if (key.length > 128) key = key.substring(0, 128);
    return _pendingMutation = _MutationIdentity(
      kind: kind,
      requestId: request.requestId,
      expectedVersion: request.version,
      proposalId: proposalId,
      reason: reason,
      idempotencyKey: key,
    );
  }

  _AppointmentCancellationIdentity _newAppointmentCancellationIdentity(
    ConfirmedScheduledAppointment appointment,
    AppointmentCancellationReason? reason,
  ) {
    var suffix = _idempotencyKeyFactory().trim();
    if (suffix.isEmpty) suffix = generateUuidV4();
    var key = 'patient-appointment-cancel-$suffix';
    if (key.length > 128) key = key.substring(0, 128);
    return _pendingAppointmentCancellation = _AppointmentCancellationIdentity(
      appointmentId: appointment.appointmentId,
      expectedVersion: appointment.version,
      reason: reason,
      idempotencyKey: key,
    );
  }

  void _applyRequest(PatientBookingRequestDetail request) {
    _result = request;
    _status = PatientBookingStatus.succeeded;
    final pending = _pendingMutation;
    if (pending == null) return;
    final intendedReached = switch (pending.kind) {
      _MutationKind.cancel || _MutationKind.declineProposal =>
        request.status == BookingRequestStatus.cancelledByPatient,
      _MutationKind.acceptProposal =>
        request.status == BookingRequestStatus.fulfilled,
    };
    final stillActionable = switch (pending.kind) {
      _MutationKind.cancel => request.availableActions.contains(
        AvailableAction.cancelRequest,
      ),
      _MutationKind.acceptProposal => request.availableActions.contains(
        AvailableAction.acceptProposedTime,
      ),
      _MutationKind.declineProposal => request.availableActions.contains(
        AvailableAction.declineProposedTime,
      ),
    };
    if (intendedReached ||
        request.version != pending.expectedVersion ||
        !stillActionable) {
      _pendingMutation = null;
    }
  }

  void abandonIntent() {
    if (_disposed || isSubmitting || isLifecycleBusy) return;
    _clearIntent();
    _status = PatientBookingStatus.idle;
    _notify();
  }

  /// Drops patient-identifying projections, command keys, and all in-flight
  /// work. Called on logout/session identity change.
  void clear() {
    if (_disposed) return;
    _clearIntent();
    _subject = const CareSubject.self(displayName: 'Moi');
    _status = PatientBookingStatus.idle;
    _lifecycleActivity = PatientBookingLifecycleActivity.idle;
    _notify();
  }

  void _clearIntent() {
    _cancelAsync('booking-state-cleared');
    _generation++;
    _intent = null;
    _result = null;
    _appointment = null;
    _pendingMutation = null;
    _pendingAppointmentCancellation = null;
    _mutationBlocked = false;
    _realtimeRequestId = null;
    _realtimeAppointmentId = null;
    _failure = null;
  }

  CancelToken _replaceLifecycleToken(String reason) {
    _lifecycleToken?.cancel(reason);
    return _lifecycleToken = CancelToken();
  }

  void _cancelAsync(String reason) {
    _submitToken?.cancel(reason);
    _lifecycleToken?.cancel(reason);
  }

  bool _isCurrent(int generation, CancelToken token) =>
      !_disposed && !token.isCancelled && generation == _generation;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  static ScheduledCareLifecycleRepositoryContract? _lifecycleFrom(
    ScheduledCareRepositoryContract repository,
  ) => repository is ScheduledCareLifecycleRepositoryContract
      ? repository as ScheduledCareLifecycleRepositoryContract
      : null;

  static ScheduledAppointmentRepositoryContract? _appointmentFrom(
    ScheduledCareRepositoryContract repository,
  ) => repository is ScheduledAppointmentRepositoryContract
      ? repository as ScheduledAppointmentRepositoryContract
      : null;

  @override
  void dispose() {
    _disposed = true;
    _cancelAsync('booking-controller-disposed');
    super.dispose();
  }
}
