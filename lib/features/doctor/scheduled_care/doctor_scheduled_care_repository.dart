import '../../scheduled_care/data/scheduled_care_failure.dart';
import '../../scheduled_care/domain/scheduled_care_models.dart';
import 'doctor_scheduled_care_api.dart';
import 'doctor_scheduled_care_models.dart';

abstract interface class DoctorScheduledCareRepository {
  Future<DoctorHomeSummary> getHomeSummary();

  Future<DoctorScheduledCareAgenda> getAgenda({
    required DateTime from,
    required DateTime to,
  });

  Future<DoctorBookingRequest> getRequest(String requestId);

  Future<DoctorBookingAcceptance> acceptRequest({
    required String requestId,
    required int expectedVersion,
    required String idempotencyKey,
  });

  Future<AvailabilityWindow> getProposalAvailability({
    required String doctorId,
    required String practiceLocationId,
    required DateTime from,
    required DateTime to,
  });

  Future<DoctorBookingRequest> proposeNewTime({
    required String requestId,
    required int expectedVersion,
    required String practiceLocationId,
    required ScheduledCareSlot proposedSlot,
    required String idempotencyKey,
  });

  Future<DoctorBookingRequest> declineRequest({
    required String requestId,
    required int expectedVersion,
    required String reasonCode,
    required String idempotencyKey,
  });

  Future<ConfirmedScheduledAppointment> getAppointment(String appointmentId);

  Future<ConfirmedScheduledAppointment> cancelAppointment({
    required String appointmentId,
    required int expectedVersion,
    required String reasonCode,
    required String idempotencyKey,
  });
}

class ApiDoctorScheduledCareRepository
    implements DoctorScheduledCareRepository {
  const ApiDoctorScheduledCareRepository(this._api);

  final DoctorScheduledCareApi _api;

  Future<T> _read<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } catch (error) {
      throw ScheduledCareFailure.from(error);
    }
  }

  Future<T> _command<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } catch (error) {
      throw ScheduledCareFailure.from(error, command: true);
    }
  }

  @override
  Future<DoctorHomeSummary> getHomeSummary() => _read(_api.getHomeSummary);

  @override
  Future<DoctorScheduledCareAgenda> getAgenda({
    required DateTime from,
    required DateTime to,
  }) => _read(() => _api.getAgenda(from: from, to: to));

  @override
  Future<DoctorBookingRequest> getRequest(String requestId) =>
      _read(() => _api.getRequest(requestId));

  @override
  Future<DoctorBookingAcceptance> acceptRequest({
    required String requestId,
    required int expectedVersion,
    required String idempotencyKey,
  }) => _command(
    () => _api.acceptRequest(
      requestId: requestId,
      expectedVersion: expectedVersion,
      idempotencyKey: idempotencyKey,
    ),
  );

  @override
  Future<AvailabilityWindow> getProposalAvailability({
    required String doctorId,
    required String practiceLocationId,
    required DateTime from,
    required DateTime to,
  }) => _read(
    () => _api.getProposalAvailability(
      doctorId: doctorId,
      practiceLocationId: practiceLocationId,
      from: from,
      to: to,
    ),
  );

  @override
  Future<DoctorBookingRequest> proposeNewTime({
    required String requestId,
    required int expectedVersion,
    required String practiceLocationId,
    required ScheduledCareSlot proposedSlot,
    required String idempotencyKey,
  }) => _command(
    () => _api.proposeNewTime(
      requestId: requestId,
      expectedVersion: expectedVersion,
      practiceLocationId: practiceLocationId,
      proposedSlot: proposedSlot,
      idempotencyKey: idempotencyKey,
    ),
  );

  @override
  Future<DoctorBookingRequest> declineRequest({
    required String requestId,
    required int expectedVersion,
    required String reasonCode,
    required String idempotencyKey,
  }) => _command(
    () => _api.declineRequest(
      requestId: requestId,
      expectedVersion: expectedVersion,
      reasonCode: reasonCode,
      idempotencyKey: idempotencyKey,
    ),
  );

  @override
  Future<ConfirmedScheduledAppointment> getAppointment(String appointmentId) =>
      _read(() => _api.getAppointment(appointmentId));

  @override
  Future<ConfirmedScheduledAppointment> cancelAppointment({
    required String appointmentId,
    required int expectedVersion,
    required String reasonCode,
    required String idempotencyKey,
  }) => _command(
    () => _api.cancelAppointment(
      appointmentId: appointmentId,
      expectedVersion: expectedVersion,
      reasonCode: reasonCode,
      idempotencyKey: idempotencyKey,
    ),
  );
}
