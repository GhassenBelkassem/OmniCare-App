import 'package:dio/dio.dart';

import '../../../scheduled_care/data/scheduled_care_failure.dart';
import '../../../scheduled_care/domain/scheduled_care_models.dart';
import '../domain/doctor_scheduled_care_models.dart';
import 'doctor_scheduled_care_api.dart';

abstract interface class DoctorScheduledCareRepositoryContract {
  Future<DoctorHomeSummary> getHomeSummary({CancelToken? cancelToken});
  Future<DoctorAgendaSnapshot> getAgenda(
    DoctorAgendaRange range, {
    CancelToken? cancelToken,
  });
  Future<DoctorBookingRequestDetail> getBookingRequest(
    String requestId, {
    CancelToken? cancelToken,
  });
  Future<ConfirmedScheduledAppointment> getAppointment(
    String appointmentId, {
    CancelToken? cancelToken,
  });
  Future<DoctorMutationResult> acceptOrReconcile(
    DoctorAcceptCommand command, {
    CancelToken? cancelToken,
  });
  Future<DoctorMutationResult> declineOrReconcile(
    DoctorDeclineCommand command, {
    CancelToken? cancelToken,
  });
  Future<DoctorMutationResult> proposeOrReconcile(
    DoctorProposalCommand command, {
    CancelToken? cancelToken,
  });
  Future<DoctorAppointmentMutationResult> cancelAppointmentOrReconcile(
    DoctorCancelAppointmentCommand command, {
    CancelToken? cancelToken,
  });
}

class DoctorScheduledCareRepository
    implements DoctorScheduledCareRepositoryContract {
  const DoctorScheduledCareRepository(this._api);

  final DoctorScheduledCareApiContract _api;

  @override
  Future<DoctorAgendaSnapshot> getAgenda(
    DoctorAgendaRange range, {
    CancelToken? cancelToken,
  }) async {
    try {
      return await _api.getAgenda(range, cancelToken: cancelToken);
    } catch (error) {
      throw ScheduledCareFailure.from(error);
    }
  }

  @override
  Future<DoctorHomeSummary> getHomeSummary({CancelToken? cancelToken}) async {
    try {
      return await _api.getHomeSummary(cancelToken: cancelToken);
    } catch (error) {
      throw ScheduledCareFailure.from(error);
    }
  }

  @override
  Future<DoctorBookingRequestDetail> getBookingRequest(
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
  Future<DoctorMutationResult> acceptOrReconcile(
    DoctorAcceptCommand command, {
    CancelToken? cancelToken,
  }) async {
    try {
      final result = await _api.accept(command, cancelToken: cancelToken);
      return DoctorMutationResult(
        request: result.request,
        appointment: result.appointment,
        intentCompleted: true,
      );
    } on DioException catch (error) {
      if (!ScheduledCareFailure.hasUnknownHttpOutcome(error)) {
        throw ScheduledCareFailure.from(error);
      }
      return _reconcileAccept(command, cancelToken: cancelToken);
    } catch (error) {
      throw ScheduledCareFailure.from(error);
    }
  }

  Future<DoctorMutationResult> _reconcileAccept(
    DoctorAcceptCommand command, {
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
          DoctorAcceptResult.validated(current, appointment);
        } on ScheduledCareContractException {
          rethrow;
        } catch (_) {
          // The request transition is conclusive. Appointment detail remains
          // independently retryable and must never trigger another POST.
          appointment = null;
        }
        return DoctorMutationResult(
          request: current,
          appointment: appointment,
          intentCompleted: true,
        );
      }
      if (current.version != command.expectedVersion || !current.canAccept) {
        return DoctorMutationResult(request: current, intentCompleted: false);
      }
      final retried = await _api.accept(command, cancelToken: cancelToken);
      return DoctorMutationResult(
        request: retried.request,
        appointment: retried.appointment,
        intentCompleted: true,
      );
    } catch (error) {
      throw ScheduledCareFailure.from(error);
    }
  }

  @override
  Future<DoctorMutationResult> declineOrReconcile(
    DoctorDeclineCommand command, {
    CancelToken? cancelToken,
  }) async {
    try {
      final request = await _api.decline(command, cancelToken: cancelToken);
      return _validatedDecline(request);
    } on DioException catch (error) {
      if (!ScheduledCareFailure.hasUnknownHttpOutcome(error)) {
        throw ScheduledCareFailure.from(error);
      }
      return _reconcileDecline(command, cancelToken: cancelToken);
    } catch (error) {
      throw ScheduledCareFailure.from(error);
    }
  }

  @override
  Future<DoctorMutationResult> proposeOrReconcile(
    DoctorProposalCommand command, {
    CancelToken? cancelToken,
  }) async {
    try {
      return _validatedProposal(
        await _api.propose(command, cancelToken: cancelToken),
        command,
      );
    } on DioException catch (error) {
      if (!ScheduledCareFailure.hasUnknownHttpOutcome(error)) {
        throw ScheduledCareFailure.from(error);
      }
      return _reconcileProposal(command, cancelToken: cancelToken);
    } catch (error) {
      throw ScheduledCareFailure.from(error);
    }
  }

  @override
  Future<DoctorAppointmentMutationResult> cancelAppointmentOrReconcile(
    DoctorCancelAppointmentCommand command, {
    CancelToken? cancelToken,
  }) async {
    try {
      return _validatedAppointmentCancellation(
        await _api.cancelAppointment(command, cancelToken: cancelToken),
      );
    } on DioException catch (error) {
      if (!ScheduledCareFailure.hasUnknownHttpOutcome(error)) {
        throw ScheduledCareFailure.from(error);
      }
      return _reconcileAppointmentCancellation(
        command,
        cancelToken: cancelToken,
      );
    } catch (error) {
      throw ScheduledCareFailure.from(error);
    }
  }

  Future<DoctorAppointmentMutationResult> _reconcileAppointmentCancellation(
    DoctorCancelAppointmentCommand command, {
    CancelToken? cancelToken,
  }) async {
    try {
      final current = await _api.getAppointment(
        command.appointmentId,
        cancelToken: cancelToken,
      );
      if (current.status == ScheduledAppointmentStatus.cancelled) {
        return DoctorAppointmentMutationResult(
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
        return DoctorAppointmentMutationResult(
          appointment: current,
          intentCompleted: false,
        );
      }
      return _validatedAppointmentCancellation(
        await _api.cancelAppointment(command, cancelToken: cancelToken),
      );
    } catch (error) {
      throw ScheduledCareFailure.from(error);
    }
  }

  Future<DoctorMutationResult> _reconcileProposal(
    DoctorProposalCommand command, {
    CancelToken? cancelToken,
  }) async {
    try {
      final current = await _api.getBookingRequest(
        command.requestId,
        cancelToken: cancelToken,
      );
      if (command.matches(current)) {
        return DoctorMutationResult(request: current, intentCompleted: true);
      }
      final mayReplay =
          current.version == command.expectedVersion && current.canPropose;
      if (!mayReplay) {
        return DoctorMutationResult(request: current, intentCompleted: false);
      }
      return _validatedProposal(
        await _api.propose(command, cancelToken: cancelToken),
        command,
      );
    } catch (error) {
      throw ScheduledCareFailure.from(error);
    }
  }

  Future<DoctorMutationResult> _reconcileDecline(
    DoctorDeclineCommand command, {
    CancelToken? cancelToken,
  }) async {
    try {
      final current = await _api.getBookingRequest(
        command.requestId,
        cancelToken: cancelToken,
      );
      if (current.status == BookingRequestStatus.cancelledByDoctor) {
        return DoctorMutationResult(request: current, intentCompleted: true);
      }
      if (current.version != command.expectedVersion || !current.canDecline) {
        return DoctorMutationResult(request: current, intentCompleted: false);
      }
      return _validatedDecline(
        await _api.decline(command, cancelToken: cancelToken),
      );
    } catch (error) {
      throw ScheduledCareFailure.from(error);
    }
  }

  static DoctorMutationResult _validatedDecline(
    DoctorBookingRequestDetail request,
  ) {
    if (request.status != BookingRequestStatus.cancelledByDoctor ||
        request.confirmedAppointmentId != null) {
      throw const ScheduledCareContractException(
        'Doctor decline response is not terminal or created an appointment.',
      );
    }
    return DoctorMutationResult(request: request, intentCompleted: true);
  }

  static DoctorMutationResult _validatedProposal(
    DoctorBookingRequestDetail request,
    DoctorProposalCommand command,
  ) {
    if (!command.matches(request) || request.canPropose) {
      throw const ScheduledCareContractException(
        'Doctor proposal response is not the intended waiting state.',
      );
    }
    return DoctorMutationResult(request: request, intentCompleted: true);
  }

  static DoctorAppointmentMutationResult _validatedAppointmentCancellation(
    ConfirmedScheduledAppointment appointment,
  ) {
    if (appointment.status != ScheduledAppointmentStatus.cancelled ||
        appointment.availableActions.contains(
          ScheduledAppointmentAction.cancelAppointment,
        )) {
      throw const ScheduledCareContractException(
        'Doctor cancellation response is not terminal.',
      );
    }
    return DoctorAppointmentMutationResult(
      appointment: appointment,
      intentCompleted: true,
    );
  }
}
