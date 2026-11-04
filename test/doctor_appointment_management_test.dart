import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/core/network/app_http_client.dart';
import 'package:omnicare_mobile/core/storage/secure_token_store.dart';
import 'package:omnicare_mobile/core/theme/omni_theme.dart';
import 'package:omnicare_mobile/features/doctor/scheduled_care/application/doctor_appointment_controller.dart';
import 'package:omnicare_mobile/features/doctor/active_consultation/doctor_active_consultation.dart';
import 'package:omnicare_mobile/features/doctor/active_consultation/doctor_active_consultation_api.dart';
import 'package:omnicare_mobile/features/doctor/active_consultation/doctor_active_consultation_controller.dart';
import 'package:omnicare_mobile/features/doctor/scheduled_care/data/doctor_scheduled_care_api.dart';
import 'package:omnicare_mobile/features/doctor/scheduled_care/data/doctor_scheduled_care_repository.dart';
import 'package:omnicare_mobile/features/doctor/scheduled_care/domain/doctor_scheduled_care_models.dart';
import 'package:omnicare_mobile/features/doctor/scheduled_care/presentation/doctor_appointment_detail_sheet.dart';
import 'package:omnicare_mobile/features/scheduled_care/data/scheduled_care_failure.dart';
import 'package:omnicare_mobile/features/scheduled_care/domain/scheduled_care_models.dart';

void main() {
  group('Doctor Agenda and appointment wire contracts', () {
    test('Agenda parses both resource types and rejects over-wide ranges', () {
      final agenda = DoctorAgendaSnapshot.fromJson(_agendaJson());
      expect(agenda.items.map((item) => item.identityKey), [
        'BOOKING_REQUEST:request-1',
        'APPOINTMENT:appointment-1',
      ]);
      expect(
        () => DoctorAgendaRange(
          from: DateTime.utc(2026, 1),
          to: DateTime.utc(2026, 4),
        ),
        throwsA(isA<ScheduledCareContractException>()),
      );
    });

    for (final status in const [
      'CONFIRMED',
      'IN_PROGRESS',
      'CANCELLED',
      'COMPLETED',
      'NO_SHOW',
    ]) {
      test('appointment detail preserves $status and its full projection', () {
        final appointment = ConfirmedScheduledAppointment.fromJson(
          _appointmentJson(status: status),
        );
        expect(appointment.appointmentId, 'appointment-1');
        expect(appointment.sourceBookingRequestId, 'request-1');
        expect(appointment.version, 7);
        expect(appointment.status, isNot(ScheduledAppointmentStatus.unknown));
        expect(appointment.doctor.doctorId, 'doctor-1');
        expect(appointment.subject.displayName, 'Nadia Ben Ali');
        expect(appointment.cabinet.practiceLocationId, 'cabinet-1');
        expect(appointment.slot.timezone, 'Africa/Tunis');
        expect(appointment.slot.durationMinutes, 30);
        expect(appointment.quotedPrice?.amount, 80);
      });
    }

    test('future appointment status stays unknown and never confirmed', () {
      final value = ConfirmedScheduledAppointment.fromJson(
        _appointmentJson(status: 'FUTURE_STATE', actions: const []),
      );
      expect(value.status, ScheduledAppointmentStatus.unknown);
      expect(value.rawStatus, 'FUTURE_STATE');
      expect(value.availableActions, isEmpty);
    });

    test('Doctor reasons are closed enums serialized as backend codes', () {
      expect(
        DoctorAppointmentCancellationReason.values.map(
          (value) => value.wireValue,
        ),
        ['CABINET_UNAVAILABLE', 'DOCTOR_UNAVAILABLE', 'SCHEDULE_CONFLICT'],
      );
      for (final reason in DoctorAppointmentCancellationReason.values) {
        expect(
          DoctorCancelAppointmentCommand(
            appointmentId: 'appointment-1',
            expectedVersion: 7,
            reason: reason,
            idempotencyKey: 'key',
          ).toJson(),
          {'expectedVersion': 7, 'reasonCode': reason.wireValue},
        );
      }
    });

    test(
      'uses exact Agenda, detail, and cancellation HTTP contracts',
      () async {
        final adapter = _QueueAdapter([
          _agendaJson(),
          _appointmentJson(),
          _appointmentJson(status: 'CANCELLED', actions: const []),
        ]);
        final api = DoctorScheduledCareApi(_client(adapter));
        final range = DoctorAgendaRange(
          from: DateTime.utc(2026, 9, 30, 23),
          to: DateTime.utc(2026, 10, 31, 23),
        );
        await api.getAgenda(range);
        await api.getAppointment('appointment-1');
        await api.cancelAppointment(
          const DoctorCancelAppointmentCommand(
            appointmentId: 'appointment-1',
            expectedVersion: 7,
            reason: DoctorAppointmentCancellationReason.scheduleConflict,
            idempotencyKey: 'stable-key',
          ),
        );

        expect(adapter.requests[0].path, '/doctor/scheduled-care');
        expect(adapter.requests[0].queryParameters, {
          'from': '2026-09-30T23:00:00.000Z',
          'to': '2026-10-31T23:00:00.000Z',
        });
        expect(adapter.requests[1].path, '/appointments/appointment-1');
        expect(adapter.requests[2].path, '/appointments/appointment-1/cancel');
        expect(adapter.requests[2].headers['Idempotency-Key'], 'stable-key');
        expect(adapter.bodies[2], {
          'expectedVersion': 7,
          'reasonCode': 'SCHEDULE_CONFLICT',
        });
      },
    );
  });

  group('Doctor cancellation recovery', () {
    test('unknown committed outcome accepts authoritative CANCELLED', () async {
      final api = _AppointmentApi(
        cancelResults: [_unknownOutcome()],
        appointmentResults: [
          _appointment(status: 'CANCELLED', actions: const []),
        ],
      );
      final result = await DoctorScheduledCareRepository(
        api,
      ).cancelAppointmentOrReconcile(_command());
      expect(result.intentCompleted, isTrue);
      expect(result.appointment.status, ScheduledAppointmentStatus.cancelled);
      expect(api.cancelCommands, hasLength(1));
      expect(api.appointmentGets, ['appointment-1']);
    });

    test(
      'unknown unchanged outcome replays once with identical intent',
      () async {
        final command = _command();
        final api = _AppointmentApi(
          cancelResults: [
            _unknownOutcome(),
            _appointment(status: 'CANCELLED', actions: const []),
          ],
          appointmentResults: [_appointment()],
        );
        final result = await DoctorScheduledCareRepository(
          api,
        ).cancelAppointmentOrReconcile(command);
        expect(result.intentCompleted, isTrue);
        expect(api.cancelCommands, hasLength(2));
        expect(identical(api.cancelCommands[0], api.cancelCommands[1]), isTrue);
        expect(api.cancelCommands[1].idempotencyKey, 'stable-key');
      },
    );

    test(
      'unknown changed version does not replay stale cancellation',
      () async {
        final api = _AppointmentApi(
          cancelResults: [_unknownOutcome()],
          appointmentResults: [_appointment(version: 8)],
        );
        final result = await DoctorScheduledCareRepository(
          api,
        ).cancelAppointmentOrReconcile(_command());
        expect(result.intentCompleted, isFalse);
        expect(result.appointment.version, 8);
        expect(api.cancelCommands, hasLength(1));
      },
    );

    test('unknown outcome never replays more than once', () async {
      final api = _AppointmentApi(
        cancelResults: [_unknownOutcome(), _unknownOutcome()],
        appointmentResults: [_appointment()],
      );
      await expectLater(
        DoctorScheduledCareRepository(
          api,
        ).cancelAppointmentOrReconcile(_command()),
        throwsA(isA<ScheduledCareFailure>()),
      );
      expect(api.cancelCommands, hasLength(2));
    });
  });

  group('Doctor appointment controller', () {
    test(
      'gates by CANCEL_APPOINTMENT and refreshes detail, Agenda, Home',
      () async {
        var agendaRefreshes = 0;
        var homeRefreshes = 0;
        final repository = _AppointmentRepository(
          appointments: [
            _appointment(),
            _appointment(status: 'CANCELLED', version: 8, actions: const []),
          ],
          cancelHandler: (command) async {
            expect(command.expectedVersion, 7);
            expect(
              command.reason,
              DoctorAppointmentCancellationReason.doctorUnavailable,
            );
            expect(command.idempotencyKey, 'doctor-cancel-appointment-fixture');
            return DoctorAppointmentMutationResult(
              appointment: _appointment(
                status: 'CANCELLED',
                version: 8,
                actions: const [],
              ),
              intentCompleted: true,
            );
          },
        );
        final controller = DoctorAppointmentController(
          repository: repository,
          refreshAgenda: () async => agendaRefreshes++,
          refreshHome: () async => homeRefreshes++,
          idempotencyKeyFactory: () => 'fixture',
        );
        addTearDown(controller.dispose);
        await controller.open('appointment-1');
        expect(controller.canCancel, isTrue);
        await controller.cancel(
          DoctorAppointmentCancellationReason.doctorUnavailable,
        );
        expect(
          controller.appointment?.status,
          ScheduledAppointmentStatus.cancelled,
        );
        expect(controller.canCancel, isFalse);
        expect(repository.appointmentGets, 2);
        expect(agendaRefreshes, 1);
        expect(homeRefreshes, 1);
      },
    );

    test(
      'same semantic retry keeps key; changed reason creates a new key',
      () async {
        var keyCounter = 0;
        final repository = _AppointmentRepository(
          appointments: [_appointment()],
          cancelHandler: (_) async => throw const ScheduledCareFailure(
            kind: ScheduledCareFailureKind.idempotencyConflict,
            message: 'stop',
            diagnosticCode: 'IDEMPOTENCY_CONFLICT',
          ),
        );
        final controller = DoctorAppointmentController(
          repository: repository,
          refreshAgenda: () async {},
          refreshHome: () async {},
          idempotencyKeyFactory: () => 'key-${++keyCounter}',
        );
        addTearDown(controller.dispose);
        await controller.open('appointment-1');
        await controller.cancel(
          DoctorAppointmentCancellationReason.cabinetUnavailable,
        );
        await controller.cancel(
          DoctorAppointmentCancellationReason.cabinetUnavailable,
        );
        await controller.cancel(
          DoctorAppointmentCancellationReason.scheduleConflict,
        );
        expect(repository.commands.map((value) => value.idempotencyKey), [
          'doctor-cancel-appointment-key-1',
          'doctor-cancel-appointment-key-1',
          'doctor-cancel-appointment-key-2',
        ]);
      },
    );

    test(
      'version conflict GETs authority and never retries stale command',
      () async {
        final repository = _AppointmentRepository(
          appointments: [
            _appointment(),
            _appointment(status: 'IN_PROGRESS', version: 8, actions: const []),
          ],
          cancelHandler: (_) async => throw const ScheduledCareFailure(
            kind: ScheduledCareFailureKind.versionConflict,
            message: 'changed',
            diagnosticCode: 'VERSION_CONFLICT',
          ),
        );
        final controller = DoctorAppointmentController(
          repository: repository,
          refreshAgenda: () async {},
          refreshHome: () async {},
        );
        addTearDown(controller.dispose);
        await controller.open('appointment-1');
        await controller.cancel(
          DoctorAppointmentCancellationReason.scheduleConflict,
        );
        expect(repository.commands, hasLength(1));
        expect(
          controller.appointment?.status,
          ScheduledAppointmentStatus.inProgress,
        );
        expect(controller.canCancel, isFalse);
      },
    );

    test('action conflict GETs authority and removes stale action', () async {
      final repository = _AppointmentRepository(
        appointments: [
          _appointment(),
          _appointment(version: 8, actions: const []),
        ],
        cancelHandler: (_) async => throw const ScheduledCareFailure(
          kind: ScheduledCareFailureKind.actionNotAllowed,
          message: 'not allowed',
          diagnosticCode: 'ACTION_NOT_ALLOWED',
        ),
      );
      final controller = DoctorAppointmentController(
        repository: repository,
        refreshAgenda: () async {},
        refreshHome: () async {},
      );
      addTearDown(controller.dispose);
      await controller.open('appointment-1');
      await controller.cancel(
        DoctorAppointmentCancellationReason.cabinetUnavailable,
      );
      expect(repository.commands, hasLength(1));
      expect(controller.appointment?.version, 8);
      expect(controller.canCancel, isFalse);
    });

    test('clear removes detail/key and rejects late-session state', () async {
      final repository = _AppointmentRepository(appointments: [_appointment()]);
      final controller = DoctorAppointmentController(
        repository: repository,
        refreshAgenda: () async {},
        refreshHome: () async {},
      );
      addTearDown(controller.dispose);
      await controller.open('appointment-1');
      controller.clear();
      expect(controller.appointment, isNull);
      expect(controller.pendingIdempotencyKey, isNull);
      expect(controller.state, DoctorAppointmentLoadState.initial);
    });

    test('clear ignores a late appointment response', () async {
      final pending = Future<ConfirmedScheduledAppointment>.delayed(
        const Duration(milliseconds: 10),
        _appointment,
      );
      final repository = _AppointmentRepository(appointments: [pending]);
      final controller = DoctorAppointmentController(
        repository: repository,
        refreshAgenda: () async {},
        refreshHome: () async {},
      );
      addTearDown(controller.dispose);
      final open = controller.open('appointment-1');
      controller.clear();
      await open;
      expect(controller.appointment, isNull);
      expect(controller.state, DoctorAppointmentLoadState.initial);
    });
  });

  for (final entry in const {
    'CONFIRMED': 'Confirmé',
    'IN_PROGRESS': 'En cours',
    'CANCELLED': 'Annulé',
    'COMPLETED': 'Terminé',
    'NO_SHOW': 'Patient absent',
    'FUTURE_STATE': 'État indisponible (FUTURE_STATE)',
  }.entries) {
    testWidgets('detail renders ${entry.key} safely', (tester) async {
      final controller = DoctorAppointmentController(
        repository: _AppointmentRepository(
          appointments: [
            _appointment(
              status: entry.key,
              actions: entry.key == 'CONFIRMED'
                  ? const ['CANCEL_APPOINTMENT']
                  : const [],
            ),
          ],
        ),
        refreshAgenda: () async {},
        refreshHome: () async {},
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DoctorAppointmentDetailSheet(
              appointmentId: 'appointment-1',
              controller: controller,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(entry.value), findsOneWidget);
    });
  }

  testWidgets('detail renders authority and only controlled cancellation UI', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = DoctorAppointmentController(
      repository: _AppointmentRepository(appointments: [_appointment()]),
      refreshAgenda: () async {},
      refreshHome: () async {},
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildOmniTheme(),
        home: Scaffold(
          body: DoctorAppointmentDetailSheet(
            appointmentId: 'appointment-1',
            controller: controller,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nadia Ben Ali'), findsOneWidget);
    expect(find.text('Confirmé'), findsOneWidget);
    expect(find.textContaining('Identifiant : appointment-1'), findsOneWidget);
    expect(find.textContaining('Demande source : request-1'), findsOneWidget);
    expect(find.textContaining('Version : 7'), findsOneWidget);
    expect(find.text('Cabinet du Lac'), findsOneWidget);
    expect(find.textContaining('Africa/Tunis'), findsOneWidget);
    expect(find.textContaining('80.00 TND'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('doctor-cancel-appointment')),
      findsOneWidget,
    );
    expect(find.textContaining('Proposer un autre horaire'), findsNothing);
    expect(find.textContaining('Patient arrivé'), findsNothing);
    expect(find.textContaining('Scanner le QR'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('doctor-cancel-appointment')));
    await tester.pumpAndSettle();
    for (final reason in DoctorAppointmentCancellationReason.values) {
      expect(find.text(reason.label), findsOneWidget);
    }
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('confirmed detail exposes canonical Start without redesign', (
    tester,
  ) async {
    final appointmentController = DoctorAppointmentController(
      repository: _AppointmentRepository(appointments: [_appointment()]),
      refreshAgenda: () async {},
      refreshHome: () async {},
    );
    final activeApi = _ActiveConsultationApi();
    final activeController = DoctorActiveConsultationController(api: activeApi);
    DoctorActiveConsultation? opened;
    addTearDown(appointmentController.dispose);
    addTearDown(activeController.dispose);
    await activeController.attachDoctor('doctor-1');

    await tester.pumpWidget(
      MaterialApp(
        theme: buildOmniTheme(),
        home: Scaffold(
          body: DoctorAppointmentDetailSheet(
            appointmentId: 'appointment-1',
            controller: appointmentController,
            activeConsultationController: activeController,
            onConsultationReady: (value) => opened = value,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(activeController.state, DoctorActiveConsultationLoadState.ready);
    expect(
      appointmentController.appointment?.status,
      ScheduledAppointmentStatus.confirmed,
    );
    await tester.drag(
      find.byKey(const ValueKey('doctor-appointment-detail')),
      const Offset(0, -1400),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('doctor-start-scheduled-consultation')),
    );
    await tester.pumpAndSettle();

    expect(activeApi.starts, [('appointment-1', 7)]);
    expect(opened?.consultationId, 'consultation-1');
  });
}

class _ActiveConsultationApi implements DoctorActiveConsultationApiContract {
  final starts = <(String, int)>[];

  @override
  Future<DoctorActiveConsultation?> getActive() async => null;

  @override
  Future<DoctorActiveConsultation> startScheduled({
    required String appointmentId,
    required int expectedAppointmentVersion,
    required String idempotencyKey,
  }) async {
    starts.add((appointmentId, expectedAppointmentVersion));
    return DoctorActiveConsultation(
      consultationId: 'consultation-1',
      sourceType: DoctorConsultationSourceType.scheduledAppointment,
      sourceId: appointmentId,
      status: DoctorConsultationStatus.inProgress,
      medicalAccessStatus: DoctorConsultationMedicalAccessStatus.none,
      version: 0,
      startedAt: DateTime.utc(2026, 10, 27, 10),
    );
  }
}

DoctorCancelAppointmentCommand _command() =>
    const DoctorCancelAppointmentCommand(
      appointmentId: 'appointment-1',
      expectedVersion: 7,
      reason: DoctorAppointmentCancellationReason.scheduleConflict,
      idempotencyKey: 'stable-key',
    );

ConfirmedScheduledAppointment _appointment({
  String status = 'CONFIRMED',
  int version = 7,
  List<String> actions = const ['CANCEL_APPOINTMENT'],
}) => ConfirmedScheduledAppointment.fromJson(
  _appointmentJson(status: status, version: version, actions: actions),
);

Map<String, dynamic> _appointmentJson({
  String status = 'CONFIRMED',
  int version = 7,
  List<String> actions = const ['CANCEL_APPOINTMENT'],
}) => {
  'appointmentId': 'appointment-1',
  'sourceBookingRequestId': 'request-1',
  'version': version,
  'status': status,
  'doctor': {
    'doctorId': 'doctor-1',
    'displayName': 'Dr Test',
    'specialty': 'Médecine générale',
  },
  'subject': {
    'subjectType': 'SELF',
    'familyMemberId': null,
    'displayName': 'Nadia Ben Ali',
    'relationship': null,
  },
  'cabinet': {
    'practiceLocationId': 'cabinet-1',
    'name': 'Cabinet du Lac',
    'address': '1 rue du Lac',
    'city': 'Tunis',
    'governorate': 'Tunis',
    'timezone': 'Africa/Tunis',
  },
  'slot': {
    'start': '2026-10-20T08:00:00Z',
    'end': '2026-10-20T08:30:00Z',
    'timezone': 'Africa/Tunis',
    'durationMinutes': 30,
  },
  'quotedPrice': {
    'amount': 80,
    'currency': 'TND',
    'quotedAt': '2026-10-11T08:00:00Z',
  },
  'confirmedAt': '2026-10-12T08:00:00Z',
  'createdAt': '2026-10-11T08:00:00Z',
  'updatedAt': '2026-10-12T08:00:00Z',
  'cancellation': status == 'CANCELLED'
      ? {
          'actor': 'DOCTOR',
          'reasonCode': 'SCHEDULE_CONFLICT',
          'cancelledAt': '2026-10-19T12:00:00Z',
          'lateCancellation': true,
        }
      : null,
  'intakeStatus': 'NOT_STARTED',
  'availableActions': actions,
};

Map<String, dynamic> _agendaItem(String type, String id) => {
  'resourceType': type,
  if (type == 'BOOKING_REQUEST') 'requestId': id else 'appointmentId': id,
  'sourceBookingRequestId': type == 'APPOINTMENT' ? 'request-1' : null,
  'version': 7,
  'status': type == 'BOOKING_REQUEST' ? 'PENDING_DOCTOR' : 'CONFIRMED',
  'doctor': {'displayName': 'Dr Test', 'specialty': 'Médecine générale'},
  'subject': {
    'subjectType': 'SELF',
    'displayName': 'Nadia Ben Ali',
    'relationship': null,
  },
  'cabinet': {
    'name': 'Cabinet du Lac',
    'address': '1 rue du Lac',
    'city': 'Tunis',
    'governorate': 'Tunis',
    'timezone': 'Africa/Tunis',
  },
  'start': '2026-10-20T08:00:00Z',
  'end': '2026-10-20T08:30:00Z',
  'timezone': 'Africa/Tunis',
  'responseDeadline': type == 'BOOKING_REQUEST' ? '2026-10-19T08:00:00Z' : null,
  'cancellation': null,
  'intakeStatus': null,
  'availableActions': type == 'BOOKING_REQUEST'
      ? ['ACCEPT_REQUEST']
      : ['CANCEL_APPOINTMENT'],
  'sortAt': '2026-10-20T08:00:00Z',
  'updatedAt': '2026-10-11T12:00:00Z',
};

Map<String, dynamic> _agendaJson() => {
  'generatedAt': '2026-10-11T12:00:00Z',
  'from': '2026-09-30T23:00:00Z',
  'to': '2026-10-31T23:00:00Z',
  'items': [
    _agendaItem('BOOKING_REQUEST', 'request-1'),
    _agendaItem('APPOINTMENT', 'appointment-1'),
  ],
};

DioException _unknownOutcome() => DioException(
  requestOptions: RequestOptions(path: '/appointments/appointment-1/cancel'),
  type: DioExceptionType.connectionError,
);

class _AppointmentApi implements DoctorScheduledCareApiContract {
  _AppointmentApi({
    required this.cancelResults,
    required this.appointmentResults,
  });
  final List<Object> cancelResults;
  final List<ConfirmedScheduledAppointment> appointmentResults;
  final cancelCommands = <DoctorCancelAppointmentCommand>[];
  final appointmentGets = <String>[];
  int _cancelIndex = 0;
  int _getIndex = 0;

  @override
  Future<ConfirmedScheduledAppointment> cancelAppointment(
    DoctorCancelAppointmentCommand command, {
    CancelToken? cancelToken,
  }) async {
    cancelCommands.add(command);
    final value = cancelResults[_cancelIndex++];
    if (value is ConfirmedScheduledAppointment) return value;
    throw value;
  }

  @override
  Future<ConfirmedScheduledAppointment> getAppointment(
    String appointmentId, {
    CancelToken? cancelToken,
  }) async {
    appointmentGets.add(appointmentId);
    return appointmentResults[_getIndex++];
  }

  @override
  Future<DoctorAgendaSnapshot> getAgenda(
    DoctorAgendaRange range, {
    CancelToken? cancelToken,
  }) => throw UnimplementedError();
  @override
  Future<DoctorHomeSummary> getHomeSummary({CancelToken? cancelToken}) =>
      throw UnimplementedError();
  @override
  Future<DoctorBookingRequestDetail> getBookingRequest(
    String requestId, {
    CancelToken? cancelToken,
  }) => throw UnimplementedError();
  @override
  Future<DoctorAcceptResult> accept(
    DoctorAcceptCommand command, {
    CancelToken? cancelToken,
  }) => throw UnimplementedError();
  @override
  Future<DoctorBookingRequestDetail> decline(
    DoctorDeclineCommand command, {
    CancelToken? cancelToken,
  }) => throw UnimplementedError();
  @override
  Future<DoctorBookingRequestDetail> propose(
    DoctorProposalCommand command, {
    CancelToken? cancelToken,
  }) => throw UnimplementedError();
}

class _AppointmentRepository implements DoctorScheduledCareRepositoryContract {
  _AppointmentRepository({required this.appointments, this.cancelHandler});
  final List<Object> appointments;
  final Future<DoctorAppointmentMutationResult> Function(
    DoctorCancelAppointmentCommand,
  )?
  cancelHandler;
  final commands = <DoctorCancelAppointmentCommand>[];
  int appointmentGets = 0;

  @override
  Future<ConfirmedScheduledAppointment> getAppointment(
    String appointmentId, {
    CancelToken? cancelToken,
  }) async {
    final value = appointments[appointmentGets++];
    if (value is Future<ConfirmedScheduledAppointment>) return value;
    return value as ConfirmedScheduledAppointment;
  }

  @override
  Future<DoctorAppointmentMutationResult> cancelAppointmentOrReconcile(
    DoctorCancelAppointmentCommand command, {
    CancelToken? cancelToken,
  }) {
    commands.add(command);
    return cancelHandler!(command);
  }

  @override
  Future<DoctorAgendaSnapshot> getAgenda(
    DoctorAgendaRange range, {
    CancelToken? cancelToken,
  }) => throw UnimplementedError();
  @override
  Future<DoctorHomeSummary> getHomeSummary({CancelToken? cancelToken}) =>
      throw UnimplementedError();
  @override
  Future<DoctorBookingRequestDetail> getBookingRequest(
    String requestId, {
    CancelToken? cancelToken,
  }) => throw UnimplementedError();
  @override
  Future<DoctorMutationResult> acceptOrReconcile(
    DoctorAcceptCommand command, {
    CancelToken? cancelToken,
  }) => throw UnimplementedError();
  @override
  Future<DoctorMutationResult> declineOrReconcile(
    DoctorDeclineCommand command, {
    CancelToken? cancelToken,
  }) => throw UnimplementedError();
  @override
  Future<DoctorMutationResult> proposeOrReconcile(
    DoctorProposalCommand command, {
    CancelToken? cancelToken,
  }) => throw UnimplementedError();
}

AppHttpClient _client(HttpClientAdapter adapter) {
  final dio = Dio()..httpClientAdapter = adapter;
  return AppHttpClient(
    tokenStore: SecureTokenStore(backend: _MemoryTokenBackend()),
    baseUrl: 'https://api.test',
    dio: dio,
    refreshDio: Dio(),
  );
}

class _QueueAdapter implements HttpClientAdapter {
  _QueueAdapter(this.responses);
  final List<Object> responses;
  final requests = <RequestOptions>[];
  final bodies = <Object?>[];
  int _index = 0;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    bodies.add(options.data);
    return ResponseBody.fromString(
      jsonEncode(responses[_index++]),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _MemoryTokenBackend implements SecureTokenStorageBackend {
  final values = <String, String>{};
  @override
  Future<void> delete({required String key}) async => values.remove(key);
  @override
  Future<String?> read({required String key}) async => values[key];
  @override
  Future<void> write({required String key, required String value}) async =>
      values[key] = value;
}
