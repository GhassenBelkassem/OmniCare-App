import 'package:omnicare_mobile/features/doctor/scheduled_care/doctor_scheduled_care_coordinator.dart';
import 'package:omnicare_mobile/features/doctor/scheduled_care/doctor_scheduled_care_models.dart';
import 'package:omnicare_mobile/features/doctor/scheduled_care/doctor_scheduled_care_repository.dart';
import 'package:omnicare_mobile/features/scheduled_care/domain/scheduled_care_models.dart';
import 'package:omnicare_mobile/features/scheduled_care/realtime/scheduled_care_realtime.dart';

final testNow = DateTime.utc(2026, 10, 6, 8);

class DoctorScheduledCareTestHarness {
  DoctorScheduledCareTestHarness({bool withFixtures = true})
    : repository = FakeDoctorScheduledCareRepository(
        withFixtures: withFixtures,
      ) {
    coordinator = DoctorScheduledCareCoordinator(
      repository: repository,
      realtime: const NoopScheduledCareRealtime(),
      doctorId: 'doctor-test',
      initialDate: DateTime(2026, 10, 6),
    );
  }

  final FakeDoctorScheduledCareRepository repository;
  late final DoctorScheduledCareCoordinator coordinator;

  Future<void> start() => coordinator.start();
  void dispose() => coordinator.dispose();
}

class FakeDoctorScheduledCareRepository
    implements DoctorScheduledCareRepository {
  FakeDoctorScheduledCareRepository({bool withFixtures = true}) {
    if (withFixtures) {
      request = _request();
      appointment = _appointment();
    }
  }

  DoctorBookingRequest? request;
  ConfirmedScheduledAppointment? appointment;
  int homeReads = 0;
  int agendaReads = 0;
  int requestReads = 0;
  int appointmentReads = 0;
  int availabilityReads = 0;
  String? lastIdempotencyKey;
  DateTime? lastAgendaFrom;
  DateTime? lastAgendaTo;
  DateTime? lastAvailabilityFrom;
  DateTime? lastAvailabilityTo;

  void setRequestStatus(
    BookingRequestStatus status, {
    Set<ScheduledCareAction> actions = const {},
  }) {
    final current = request!;
    request = _copyRequest(
      current,
      version: current.version + 1,
      status: status,
      actions: actions,
    );
  }

  @override
  Future<DoctorHomeSummary> getHomeSummary() async {
    homeReads++;
    final pending = request?.status == BookingRequestStatus.pendingDoctor
        ? DoctorScheduledCareItem.fromRequest(request!)
        : null;
    final nextAppointment = appointment == null
        ? null
        : DoctorScheduledCareItem.fromAppointment(appointment!);
    return DoctorHomeSummary(
      generatedAt: testNow,
      pendingRequestCount: pending == null ? 0 : 1,
      nextPendingRequest: pending,
      nextConfirmedAppointment: nextAppointment,
    );
  }

  @override
  Future<DoctorScheduledCareAgenda> getAgenda({
    required DateTime from,
    required DateTime to,
  }) async {
    agendaReads++;
    lastAgendaFrom = from;
    lastAgendaTo = to;
    final items = <DoctorScheduledCareItem>[];
    final currentRequest = request;
    if (currentRequest != null &&
        currentRequest.status != BookingRequestStatus.fulfilled) {
      items.add(DoctorScheduledCareItem.fromRequest(currentRequest));
    }
    final currentAppointment = appointment;
    if (currentAppointment != null) {
      items.add(DoctorScheduledCareItem.fromAppointment(currentAppointment));
    }
    return DoctorScheduledCareAgenda(
      generatedAt: testNow,
      from: from,
      to: to,
      items: List.unmodifiable(items),
    );
  }

  @override
  Future<DoctorBookingRequest> getRequest(String requestId) async {
    requestReads++;
    final value = request;
    if (value == null || value.requestId != requestId) {
      throw StateError('Unknown request');
    }
    return value;
  }

  @override
  Future<ConfirmedScheduledAppointment> getAppointment(
    String appointmentId,
  ) async {
    appointmentReads++;
    final value = appointment;
    if (value == null || value.appointmentId != appointmentId) {
      throw StateError('Unknown appointment');
    }
    return value;
  }

  @override
  Future<DoctorBookingAcceptance> acceptRequest({
    required String requestId,
    required int expectedVersion,
    required String idempotencyKey,
  }) async {
    lastIdempotencyKey = idempotencyKey;
    final current = await getRequest(requestId);
    request = _copyRequest(
      current,
      version: expectedVersion + 1,
      status: BookingRequestStatus.fulfilled,
      actions: const {},
      confirmedAppointmentId: 'appointment-from-request',
    );
    appointment = _appointment(
      appointmentId: 'appointment-from-request',
      subject: current.subject,
      slot: current.activeSlot,
    );
    return DoctorBookingAcceptance(
      request: request!,
      appointment: appointment!,
    );
  }

  @override
  Future<AvailabilityWindow> getProposalAvailability({
    required String doctorId,
    required String practiceLocationId,
    required DateTime from,
    required DateTime to,
  }) async {
    availabilityReads++;
    lastAvailabilityFrom = from;
    lastAvailabilityTo = to;
    return AvailabilityWindow(
      doctorId: doctorId,
      practiceLocationId: practiceLocationId,
      timezone: 'Africa/Tunis',
      generatedAt: testNow,
      slots: [
        ScheduledCareSlot(
          start: DateTime.utc(2026, 10, 8, 10),
          end: DateTime.utc(2026, 10, 8, 10, 30),
          timezone: 'Africa/Tunis',
        ),
      ],
    );
  }

  @override
  Future<DoctorBookingRequest> proposeNewTime({
    required String requestId,
    required int expectedVersion,
    required String practiceLocationId,
    required ScheduledCareSlot proposedSlot,
    required String idempotencyKey,
  }) async {
    lastIdempotencyKey = idempotencyKey;
    final current = await getRequest(requestId);
    request = _copyRequest(
      current,
      version: expectedVersion + 1,
      status: BookingRequestStatus.pendingPatientTimeConfirmation,
      activeSlot: proposedSlot,
      proposedSlot: ProposedSlot(
        proposalId: 'proposal-1',
        start: proposedSlot.start,
        end: proposedSlot.end,
        proposedAt: testNow,
        patientResponseDeadline: testNow.add(const Duration(hours: 6)),
      ),
      actions: const {},
    );
    return request!;
  }

  @override
  Future<DoctorBookingRequest> declineRequest({
    required String requestId,
    required int expectedVersion,
    required String reasonCode,
    required String idempotencyKey,
  }) async {
    lastIdempotencyKey = idempotencyKey;
    final current = await getRequest(requestId);
    request = _copyRequest(
      current,
      version: expectedVersion + 1,
      status: BookingRequestStatus.cancelledByDoctor,
      actions: const {},
      cancellation: ScheduledCareCancellation(
        actor: 'DOCTOR',
        reasonCode: reasonCode,
        cancelledAt: testNow,
      ),
    );
    return request!;
  }

  @override
  Future<ConfirmedScheduledAppointment> cancelAppointment({
    required String appointmentId,
    required int expectedVersion,
    required String reasonCode,
    required String idempotencyKey,
  }) async {
    lastIdempotencyKey = idempotencyKey;
    final current = await getAppointment(appointmentId);
    appointment = ConfirmedScheduledAppointment(
      appointmentId: current.appointmentId,
      sourceBookingRequestId: current.sourceBookingRequestId,
      version: expectedVersion + 1,
      status: 'CANCELLED',
      doctor: current.doctor,
      subject: current.subject,
      cabinet: current.cabinet,
      slot: current.slot,
      confirmedAt: current.confirmedAt,
      createdAt: current.createdAt,
      updatedAt: testNow,
      cancellation: ScheduledCareCancellation(
        actor: 'DOCTOR',
        reasonCode: reasonCode,
        cancelledAt: testNow,
      ),
      intakeStatus: current.intakeStatus,
      availableActions: const {},
    );
    return appointment!;
  }
}

DoctorBookingRequest _request() => DoctorBookingRequest(
  requestId: 'request-mariem',
  version: 3,
  status: BookingRequestStatus.pendingDoctor,
  subject: const CareSubject(
    type: CareSubjectType.familyMember,
    familyMemberId: 'family-1',
    displayName: 'Mariem Ben Amor',
    relationship: 'Enfant',
  ),
  cabinet: const DoctorScheduledCareCabinet(
    practiceLocationId: 'cabinet-lac-2',
    name: 'Cabinet Lac 2',
    address: '1 rue du Lac',
    city: 'Tunis',
    governorate: 'Tunis',
    timezone: 'Africa/Tunis',
  ),
  originalRequestedSlot: ScheduledCareSlot(
    start: DateTime.utc(2026, 10, 8, 9),
    end: DateTime.utc(2026, 10, 8, 9, 30),
    timezone: 'Africa/Tunis',
  ),
  activeSlot: ScheduledCareSlot(
    start: DateTime.utc(2026, 10, 8, 9),
    end: DateTime.utc(2026, 10, 8, 9, 30),
    timezone: 'Africa/Tunis',
  ),
  createdAt: testNow,
  responseDeadline: testNow.add(const Duration(hours: 2)),
  availableActions: const {
    ScheduledCareAction.acceptRequest,
    ScheduledCareAction.proposeNewTime,
    ScheduledCareAction.declineRequest,
  },
  updatedAt: testNow,
);

ConfirmedScheduledAppointment _appointment({
  String appointmentId = 'appointment-ahmed',
  CareSubject subject = const CareSubject(
    type: CareSubjectType.self,
    displayName: 'Ahmed Gharbi',
    relationship: 'Moi-même',
  ),
  ScheduledCareSlot? slot,
}) => ConfirmedScheduledAppointment(
  appointmentId: appointmentId,
  sourceBookingRequestId: 'source-request',
  version: 2,
  status: 'CONFIRMED',
  doctor: const ScheduledCareDoctor(
    doctorId: 'doctor-test',
    displayName: 'Dr Mansour',
    specialty: 'Médecine générale',
  ),
  subject: subject,
  cabinet: const ScheduledCareCabinet(
    practiceLocationId: 'cabinet-lac-2',
    name: 'Cabinet Lac 2',
    address: '1 rue du Lac',
    city: 'Tunis',
    governorate: 'Tunis',
    timezone: 'Africa/Tunis',
  ),
  slot:
      slot ??
      ScheduledCareSlot(
        start: DateTime.utc(2026, 10, 7, 10),
        end: DateTime.utc(2026, 10, 7, 10, 30),
        timezone: 'Africa/Tunis',
      ),
  confirmedAt: testNow,
  createdAt: testNow,
  updatedAt: testNow,
  intakeStatus: 'SUBMITTED',
  availableActions: const {'CANCEL_APPOINTMENT', 'PREPARE_VISIT'},
);

DoctorBookingRequest _copyRequest(
  DoctorBookingRequest value, {
  required int version,
  required BookingRequestStatus status,
  required Set<ScheduledCareAction> actions,
  ScheduledCareSlot? activeSlot,
  ProposedSlot? proposedSlot,
  String? confirmedAppointmentId,
  ScheduledCareCancellation? cancellation,
}) => DoctorBookingRequest(
  requestId: value.requestId,
  version: version,
  status: status,
  subject: value.subject,
  cabinet: value.cabinet,
  originalRequestedSlot: value.originalRequestedSlot,
  proposedSlot: proposedSlot,
  activeSlot: activeSlot ?? value.activeSlot,
  createdAt: value.createdAt,
  responseDeadline: value.responseDeadline,
  patientResponseDeadline: proposedSlot?.patientResponseDeadline,
  confirmedAppointmentId: confirmedAppointmentId,
  cancellation: cancellation,
  availableActions: actions,
  updatedAt: testNow,
);
