import '../domain/scheduled_care_models.dart';
import 'scheduled_care_api.dart';
import 'scheduled_care_failure.dart';

class ScheduledCareRepository {
  const ScheduledCareRepository(this._api);
  final ScheduledCareApi _api;

  Future<T> read<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } catch (error) {
      throw ScheduledCareFailure.from(error);
    }
  }

  Future<T> command<T>(Future<T> Function() operation) async {
    try {
      return await operation();
    } catch (error) {
      throw ScheduledCareFailure.from(error, command: true);
    }
  }

  Future<AvailabilityWindow> getAvailability({
    required String doctorId,
    required String practiceLocationId,
    required DateTime from,
    required DateTime to,
  }) => read(
    () => _api.getAvailability(
      doctorId: doctorId,
      practiceLocationId: practiceLocationId,
      from: from,
      to: to,
    ),
  );

  Future<PatientBookingRequest> createRequest({
    required String requestId,
    required String doctorId,
    required String practiceLocationId,
    required CareSubject subject,
    required ScheduledCareSlot slot,
  }) => command(
    () => _api.createRequest(
      requestId: requestId,
      doctorId: doctorId,
      practiceLocationId: practiceLocationId,
      subject: subject,
      slot: slot,
    ),
  );

  Future<PatientBookingRequest> getRequest(String id) =>
      read(() => _api.getRequest(id));

  Future<ScheduledCarePage> list({
    required ScheduledCareBucket bucket,
    String? cursor,
    String? query,
    DateTime? from,
    DateTime? to,
    CareSubjectType? subjectType,
    String? familyMemberId,
    String? city,
  }) => read(
    () => _api.list(
      bucket: bucket,
      cursor: cursor,
      query: query,
      from: from,
      to: to,
      subjectType: subjectType,
      familyMemberId: familyMemberId,
      city: city,
    ),
  );

  Future<ConfirmedScheduledAppointment> getAppointment(String id) =>
      read(() => _api.getAppointment(id));

  Future<PatientBookingRequest> cancelRequest({
    required String requestId,
    required int expectedVersion,
    required String reasonCode,
    required String idempotencyKey,
  }) => command(
    () => _api.cancelRequest(
      requestId: requestId,
      expectedVersion: expectedVersion,
      reasonCode: reasonCode,
      idempotencyKey: idempotencyKey,
    ),
  );

  Future<ProposalAcceptance> acceptProposal({
    required String requestId,
    required String proposalId,
    required int expectedVersion,
    required String idempotencyKey,
  }) => command(
    () => _api.acceptProposal(
      requestId: requestId,
      proposalId: proposalId,
      expectedVersion: expectedVersion,
      idempotencyKey: idempotencyKey,
    ),
  );

  Future<PatientBookingRequest> declineProposal({
    required String requestId,
    required String proposalId,
    required int expectedVersion,
    required String reasonCode,
    required String idempotencyKey,
  }) => command(
    () => _api.declineProposal(
      requestId: requestId,
      proposalId: proposalId,
      expectedVersion: expectedVersion,
      reasonCode: reasonCode,
      idempotencyKey: idempotencyKey,
    ),
  );

  Future<ConfirmedScheduledAppointment> cancelAppointment({
    required String appointmentId,
    required int expectedVersion,
    required String reasonCode,
    required String idempotencyKey,
  }) => command(
    () => _api.cancelAppointment(
      appointmentId: appointmentId,
      expectedVersion: expectedVersion,
      reasonCode: reasonCode,
      idempotencyKey: idempotencyKey,
    ),
  );
}
