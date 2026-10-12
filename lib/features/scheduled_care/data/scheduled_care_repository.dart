import 'package:dio/dio.dart';

import '../domain/scheduled_care_models.dart';
import '../domain/patient_scheduled_care_models.dart';
import 'scheduled_care_api.dart';
import 'scheduled_care_failure.dart';

abstract interface class ScheduledCareRepositoryContract {
  Future<PatientBookingRequestDetail> createOrReconcile(
    CreateBookingRequestCommand command, {
    CancelToken? cancelToken,
  });
}

abstract interface class ScheduledCareLifecycleRepositoryContract {
  Future<PatientBookingRequestDetail> getBookingRequest(
    String requestId, {
    CancelToken? cancelToken,
  });

  Future<BookingMutationResult> cancelOrReconcile(
    CancelBookingRequestCommand command, {
    CancelToken? cancelToken,
  });

  Future<BookingMutationResult> acceptProposalOrReconcile(
    AcceptBookingProposalCommand command, {
    CancelToken? cancelToken,
  });

  Future<BookingMutationResult> declineProposalOrReconcile(
    DeclineBookingProposalCommand command, {
    CancelToken? cancelToken,
  });

  Future<ConfirmedScheduledAppointment> getAppointment(
    String appointmentId, {
    CancelToken? cancelToken,
  });
}

abstract interface class PatientScheduledCareRepositoryContract {
  Future<PatientScheduledCarePage> getPatientScheduledCare(
    PatientScheduledCareQuery query, {
    CancelToken? cancelToken,
  });
}

abstract interface class ScheduledAppointmentRepositoryContract {
  Future<AppointmentMutationResult> cancelAppointmentOrReconcile(
    CancelScheduledAppointmentCommand command, {
    CancelToken? cancelToken,
  });
}

/// Owns creation recovery semantics. A transport failure after POST is first
/// reconciled by requestId; only an authoritative 404 permits replaying the
/// exact same body and requestId.
class ScheduledCareRepository
    implements
        ScheduledCareRepositoryContract,
        ScheduledCareLifecycleRepositoryContract,
        PatientScheduledCareRepositoryContract,
        ScheduledAppointmentRepositoryContract {
  const ScheduledCareRepository(
    this._api, {
    PatientScheduledCareApiContract? patientScheduledCareApi,
    ScheduledAppointmentCancellationApiContract? appointmentCancellationApi,
  }) : _patientScheduledCareApi = patientScheduledCareApi,
       _appointmentCancellationApi = appointmentCancellationApi;

  final ScheduledCareApi _api;
  final PatientScheduledCareApiContract? _patientScheduledCareApi;
  final ScheduledAppointmentCancellationApiContract?
  _appointmentCancellationApi;

  @override
  Future<PatientScheduledCarePage> getPatientScheduledCare(
    PatientScheduledCareQuery query, {
    CancelToken? cancelToken,
  }) async {
    try {
      final api = _patientScheduledCareApi;
      if (api == null) {
        throw const ScheduledCareContractException(
          'Patient scheduled-care API is unavailable.',
        );
      }
      return await api.getPatientScheduledCare(query, cancelToken: cancelToken);
    } catch (error) {
      throw ScheduledCareFailure.from(error);
    }
  }

  @override
  Future<PatientBookingRequestDetail> createOrReconcile(
    CreateBookingRequestCommand command, {
    CancelToken? cancelToken,
  }) async {
    try {
      return await _api.createBookingRequest(command, cancelToken: cancelToken);
    } on DioException catch (error) {
      if (!ScheduledCareFailure.hasUnknownHttpOutcome(error)) {
        throw ScheduledCareFailure.from(error);
      }

      try {
        return await _api.getBookingRequest(
          command.requestId,
          cancelToken: cancelToken,
        );
      } catch (reconcileError) {
        if (!ScheduledCareFailure.isNotFoundResponse(reconcileError)) {
          throw ScheduledCareFailure.from(reconcileError);
        }
      }

      try {
        return await _api.createBookingRequest(
          command,
          cancelToken: cancelToken,
        );
      } catch (retryError) {
        throw ScheduledCareFailure.from(retryError);
      }
    } catch (error) {
      throw ScheduledCareFailure.from(error);
    }
  }

  @override
  Future<PatientBookingRequestDetail> getBookingRequest(
    String requestId, {
    CancelToken? cancelToken,
  }) async {
    try {
      return await _api.getBookingRequest(requestId, cancelToken: cancelToken);
    } catch (error) {
      throw ScheduledCareFailure.from(error);
    }
  }

  @override
  Future<BookingMutationResult> cancelOrReconcile(
    CancelBookingRequestCommand command, {
    CancelToken? cancelToken,
  }) async {
    try {
      final request = await _api.cancelBookingRequest(
        command,
        cancelToken: cancelToken,
      );
      return _completedRequestMutation(
        request,
        BookingRequestStatus.cancelledByPatient,
      );
    } on DioException catch (error) {
      if (!ScheduledCareFailure.hasUnknownHttpOutcome(error)) {
        throw ScheduledCareFailure.from(error);
      }
      return _reconcileRequestMutation(
        requestId: command.requestId,
        expectedVersion: command.expectedVersion,
        intendedStatus: BookingRequestStatus.cancelledByPatient,
        requiredAction: AvailableAction.cancelRequest,
        retry: () =>
            _api.cancelBookingRequest(command, cancelToken: cancelToken),
        cancelToken: cancelToken,
      );
    } catch (error) {
      throw ScheduledCareFailure.from(error);
    }
  }

  @override
  Future<BookingMutationResult> declineProposalOrReconcile(
    DeclineBookingProposalCommand command, {
    CancelToken? cancelToken,
  }) async {
    try {
      final request = await _api.declineProposal(
        command,
        cancelToken: cancelToken,
      );
      return _completedRequestMutation(
        request,
        BookingRequestStatus.cancelledByPatient,
      );
    } on DioException catch (error) {
      if (!ScheduledCareFailure.hasUnknownHttpOutcome(error)) {
        throw ScheduledCareFailure.from(error);
      }
      return _reconcileRequestMutation(
        requestId: command.requestId,
        expectedVersion: command.expectedVersion,
        intendedStatus: BookingRequestStatus.cancelledByPatient,
        requiredAction: AvailableAction.declineProposedTime,
        proposalId: command.proposalId,
        retry: () => _api.declineProposal(command, cancelToken: cancelToken),
        cancelToken: cancelToken,
      );
    } catch (error) {
      throw ScheduledCareFailure.from(error);
    }
  }

  @override
  Future<BookingMutationResult> acceptProposalOrReconcile(
    AcceptBookingProposalCommand command, {
    CancelToken? cancelToken,
  }) async {
    try {
      final response = await _api.acceptProposal(
        command,
        cancelToken: cancelToken,
      );
      return BookingMutationResult(
        request: response.request,
        appointment: response.appointment,
        intentCompleted: true,
      );
    } on DioException catch (error) {
      if (!ScheduledCareFailure.hasUnknownHttpOutcome(error)) {
        throw ScheduledCareFailure.from(error);
      }
      return _reconcileProposalAcceptance(command, cancelToken: cancelToken);
    } catch (error) {
      throw ScheduledCareFailure.from(error);
    }
  }

  @override
  Future<ConfirmedScheduledAppointment> getAppointment(
    String appointmentId, {
    CancelToken? cancelToken,
  }) async {
    try {
      return await _api.getAppointment(appointmentId, cancelToken: cancelToken);
    } catch (error) {
      throw ScheduledCareFailure.from(error);
    }
  }

  @override
  Future<AppointmentMutationResult> cancelAppointmentOrReconcile(
    CancelScheduledAppointmentCommand command, {
    CancelToken? cancelToken,
  }) async {
    final cancellationApi = _appointmentCancellationApi;
    if (cancellationApi == null) {
      throw const ScheduledCareFailure(
        kind: ScheduledCareFailureKind.contract,
        message: 'L’annulation est momentanément indisponible.',
        diagnosticCode: 'APPOINTMENT_CANCELLATION_UNAVAILABLE',
      );
    }
    try {
      final appointment = await cancellationApi.cancelAppointment(
        command,
        cancelToken: cancelToken,
      );
      return _completedAppointmentCancellation(appointment);
    } on DioException catch (error) {
      if (!ScheduledCareFailure.hasUnknownHttpOutcome(error)) {
        throw ScheduledCareFailure.from(error);
      }
      try {
        final current = await _api.getAppointment(
          command.appointmentId,
          cancelToken: cancelToken,
        );
        if (current.status == ScheduledAppointmentStatus.cancelled) {
          return AppointmentMutationResult(
            appointment: current,
            intentCompleted: true,
          );
        }
        final mayReplay =
            current.version == command.expectedVersion &&
            current.availableActions.contains(
              ScheduledAppointmentAction.cancelAppointment,
            );
        if (!mayReplay) {
          return AppointmentMutationResult(
            appointment: current,
            intentCompleted: false,
          );
        }
        final retried = await cancellationApi.cancelAppointment(
          command,
          cancelToken: cancelToken,
        );
        return _completedAppointmentCancellation(retried);
      } catch (reconcileError) {
        throw ScheduledCareFailure.from(reconcileError);
      }
    } catch (error) {
      throw ScheduledCareFailure.from(error);
    }
  }

  Future<BookingMutationResult> _reconcileRequestMutation({
    required String requestId,
    required int expectedVersion,
    required BookingRequestStatus intendedStatus,
    required AvailableAction requiredAction,
    String? proposalId,
    required Future<PatientBookingRequestDetail> Function() retry,
    CancelToken? cancelToken,
  }) async {
    try {
      final current = await _api.getBookingRequest(
        requestId,
        cancelToken: cancelToken,
      );
      if (current.status == intendedStatus) {
        return BookingMutationResult(request: current, intentCompleted: true);
      }
      final sameProposal =
          proposalId == null || current.proposedSlot?.proposalId == proposalId;
      final mayReplay =
          current.version == expectedVersion &&
          sameProposal &&
          current.availableActions.contains(requiredAction);
      if (!mayReplay) {
        return BookingMutationResult(request: current, intentCompleted: false);
      }
      final retried = await retry();
      return _completedRequestMutation(retried, intendedStatus);
    } catch (error) {
      throw ScheduledCareFailure.from(error);
    }
  }

  Future<BookingMutationResult> _reconcileProposalAcceptance(
    AcceptBookingProposalCommand command, {
    CancelToken? cancelToken,
  }) async {
    try {
      final current = await _api.getBookingRequest(
        command.requestId,
        cancelToken: cancelToken,
      );
      if (current.status == BookingRequestStatus.fulfilled &&
          current.confirmedAppointmentId != null) {
        ConfirmedScheduledAppointment? appointment;
        try {
          appointment = await _api.getAppointment(
            current.confirmedAppointmentId!,
            cancelToken: cancelToken,
          );
          ProposalAcceptanceResult.validated(current, appointment);
        } on ScheduledCareContractException {
          rethrow;
        } catch (_) {
          // The request transition is conclusive. Appointment detail remains
          // independently retryable and must not cause the proposal POST to be
          // submitted again.
          appointment = null;
        }
        return BookingMutationResult(
          request: current,
          appointment: appointment,
          intentCompleted: true,
        );
      }
      final mayReplay =
          current.version == command.expectedVersion &&
          current.proposedSlot?.proposalId == command.proposalId &&
          current.availableActions.contains(AvailableAction.acceptProposedTime);
      if (!mayReplay) {
        return BookingMutationResult(request: current, intentCompleted: false);
      }
      final retried = await _api.acceptProposal(
        command,
        cancelToken: cancelToken,
      );
      return BookingMutationResult(
        request: retried.request,
        appointment: retried.appointment,
        intentCompleted: true,
      );
    } catch (error) {
      throw ScheduledCareFailure.from(error);
    }
  }

  static BookingMutationResult _completedRequestMutation(
    PatientBookingRequestDetail request,
    BookingRequestStatus expectedStatus,
  ) {
    if (request.status != expectedStatus) {
      throw const ScheduledCareContractException(
        'Mutation response has an unexpected request state.',
      );
    }
    return BookingMutationResult(request: request, intentCompleted: true);
  }

  static AppointmentMutationResult _completedAppointmentCancellation(
    ConfirmedScheduledAppointment appointment,
  ) {
    if (appointment.status != ScheduledAppointmentStatus.cancelled) {
      throw const ScheduledCareContractException(
        'Cancellation response has an unexpected appointment state.',
      );
    }
    return AppointmentMutationResult(
      appointment: appointment,
      intentCompleted: true,
    );
  }
}
