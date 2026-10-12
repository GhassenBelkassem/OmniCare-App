import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/core/network/app_http_client.dart';
import 'package:omnicare_mobile/core/storage/secure_token_store.dart';
import 'package:omnicare_mobile/core/theme/omni_theme.dart';
import 'package:omnicare_mobile/features/doctor/home/doctor_home_screen.dart';
import 'package:omnicare_mobile/features/doctor/profile/doctor_display_profile.dart';
import 'package:omnicare_mobile/features/doctor/scheduled_care/application/doctor_booking_request_controller.dart';
import 'package:omnicare_mobile/features/doctor/scheduled_care/application/doctor_home_controller.dart';
import 'package:omnicare_mobile/features/doctor/scheduled_care/data/doctor_scheduled_care_api.dart';
import 'package:omnicare_mobile/features/doctor/scheduled_care/data/doctor_scheduled_care_repository.dart';
import 'package:omnicare_mobile/features/doctor/scheduled_care/domain/doctor_scheduled_care_models.dart';
import 'package:omnicare_mobile/features/doctor/scheduled_care/presentation/doctor_booking_request_screen.dart';
import 'package:omnicare_mobile/features/doctor/workspace/doctor_workspace_config.dart';
import 'package:omnicare_mobile/features/scheduled_care/data/scheduled_care_failure.dart';
import 'package:omnicare_mobile/features/scheduled_care/domain/scheduled_care_models.dart';

void main() {
  group('Doctor scheduled-care contract', () {
    test('home parses independent nullable resources and pending count', () {
      final full = DoctorHomeSummary.fromJson(_homeJson());
      expect(full.pendingRequestCount, 4);
      expect(full.nextPendingRequest?.requestId, 'request-1');
      expect(full.nextConfirmedAppointment?.appointmentId, 'appointment-1');

      final empty = DoctorHomeSummary.fromJson(
        _homeJson(request: null, appointment: null, count: 0),
      );
      expect(empty.pendingRequestCount, 0);
      expect(empty.nextPendingRequest, isNull);
      expect(empty.nextConfirmedAppointment, isNull);
    });

    test('home rejects mismatched resource discriminators', () {
      expect(
        () => DoctorHomeSummary.fromJson(
          _homeJson(request: _summaryJson(type: 'APPOINTMENT')),
        ),
        throwsA(isA<ScheduledCareContractException>()),
      );
    });

    for (final status in const [
      'PENDING_DOCTOR',
      'PENDING_PATIENT_TIME_CONFIRMATION',
      'FULFILLED',
      'CANCELLED_BY_PATIENT',
      'CANCELLED_BY_DOCTOR',
      'EXPIRED',
    ]) {
      test('request detail preserves $status', () {
        final detail = DoctorBookingRequestDetail.fromJson(
          _detailJson(status: status),
        );
        expect(detail.rawStatus, status);
        expect(detail.status, isNot(BookingRequestStatus.unknown));
        expect(detail.version, 7);
        expect(detail.subject.displayName, 'Nadia Ben Ali');
        expect(detail.cabinet.name, 'Cabinet du Lac');
        expect(detail.originalRequestedSlot.durationMinutes, 30);
        expect(detail.patientResponseDeadline, isNotNull);
      });
    }

    test('unknown status and action stay unknown-safe', () {
      final detail = DoctorBookingRequestDetail.fromJson(
        _detailJson(status: 'SERVER_FUTURE_STATE', actions: ['FUTURE_ACTION']),
      );
      expect(detail.status, BookingRequestStatus.unknown);
      expect(detail.availableActions, [DoctorBookingAction.unknown]);
      expect(detail.canAccept, isFalse);
      expect(detail.canDecline, isFalse);
    });

    test('accept validates request and appointment identity/state', () {
      final result = DoctorAcceptResult.fromJson(_acceptJson());
      expect(result.request.requestId, 'request-1');
      expect(result.appointment.appointmentId, 'appointment-1');
      expect(result.appointment.sourceBookingRequestId, 'request-1');
      expect(
        () => DoctorAcceptResult.fromJson(
          _acceptJson(appointment: _appointmentJson(id: 'request-1')),
        ),
        throwsA(isA<ScheduledCareContractException>()),
      );
    });

    test('decline reasons serialize only exact backend enums', () {
      expect(DoctorDeclineReason.values.map((value) => value.wireValue), [
        'CABINET_UNAVAILABLE',
        'DOCTOR_UNAVAILABLE',
        'SCHEDULE_CONFLICT',
      ]);
      expect(
        const DoctorDeclineCommand(
          requestId: 'request-1',
          expectedVersion: 7,
          idempotencyKey: 'key',
          reason: DoctorDeclineReason.scheduleConflict,
        ).toJson(),
        {'expectedVersion': 7, 'reasonCode': 'SCHEDULE_CONFLICT'},
      );
    });
  });

  group('Doctor scheduled-care transport', () {
    test('uses exact home/detail routes and mutation headers/bodies', () async {
      final adapter = _QueueAdapter([
        _homeJson(),
        _detailJson(),
        _acceptJson(),
        _detailJson(status: 'CANCELLED_BY_DOCTOR', actions: const []),
      ]);
      final api = DoctorScheduledCareApi(_client(adapter));
      await api.getHomeSummary();
      await api.getBookingRequest('request-1');
      await api.accept(
        const DoctorAcceptCommand(
          requestId: 'request-1',
          expectedVersion: 7,
          idempotencyKey: 'accept-key',
        ),
      );
      await api.decline(
        const DoctorDeclineCommand(
          requestId: 'request-1',
          expectedVersion: 7,
          idempotencyKey: 'decline-key',
          reason: DoctorDeclineReason.doctorUnavailable,
        ),
      );

      expect(adapter.requests[0].path, '/doctor/scheduled-care/home-summary');
      expect(adapter.requests[1].path, '/doctor/booking-requests/request-1');
      expect(
        adapter.requests[2].path,
        '/doctor/booking-requests/request-1/accept',
      );
      expect(adapter.requests[2].headers['Idempotency-Key'], 'accept-key');
      expect(adapter.bodies[2], {'expectedVersion': 7});
      expect(
        adapter.requests[3].path,
        '/doctor/booking-requests/request-1/decline',
      );
      expect(adapter.requests[3].headers['Idempotency-Key'], 'decline-key');
      expect(adapter.bodies[3], {
        'expectedVersion': 7,
        'reasonCode': 'DOCTOR_UNAVAILABLE',
      });
    });
  });

  group('Unknown-outcome recovery', () {
    test('fulfilled accept GETs appointment and never reposts', () async {
      final api = _FakeApi(
        acceptResults: [_connectionFailure()],
        detailResults: [
          _detail(status: 'FULFILLED', confirmedAppointmentId: 'appointment-1'),
        ],
      );
      final result = await DoctorScheduledCareRepository(api).acceptOrReconcile(
        const DoctorAcceptCommand(
          requestId: 'request-1',
          expectedVersion: 7,
          idempotencyKey: 'stable-key',
        ),
      );
      expect(result.intentCompleted, isTrue);
      expect(api.acceptCommands, hasLength(1));
      expect(api.appointmentGets, ['appointment-1']);
    });

    test('actionable accept retries once with exact command', () async {
      final api = _FakeApi(
        acceptResults: [
          _connectionFailure(),
          DoctorAcceptResult.fromJson(_acceptJson()),
        ],
        detailResults: [_detail()],
      );
      await DoctorScheduledCareRepository(api).acceptOrReconcile(
        const DoctorAcceptCommand(
          requestId: 'request-1',
          expectedVersion: 7,
          idempotencyKey: 'same-key',
        ),
      );
      expect(api.acceptCommands, hasLength(2));
      expect(identical(api.acceptCommands[0], api.acceptCommands[1]), isTrue);
    });

    test('cancelled decline is recovered without replay', () async {
      final api = _FakeApi(
        declineResults: [_connectionFailure()],
        detailResults: [
          _detail(status: 'CANCELLED_BY_DOCTOR', actions: const []),
        ],
      );
      final result = await DoctorScheduledCareRepository(api)
          .declineOrReconcile(
            const DoctorDeclineCommand(
              requestId: 'request-1',
              expectedVersion: 7,
              idempotencyKey: 'stable-key',
              reason: DoctorDeclineReason.cabinetUnavailable,
            ),
          );
      expect(result.intentCompleted, isTrue);
      expect(api.declineCommands, hasLength(1));
    });

    test('actionable decline retries only once with same key/body', () async {
      final api = _FakeApi(
        declineResults: [
          _connectionFailure(),
          _detail(status: 'CANCELLED_BY_DOCTOR', actions: const []),
        ],
        detailResults: [_detail()],
      );
      await DoctorScheduledCareRepository(api).declineOrReconcile(
        const DoctorDeclineCommand(
          requestId: 'request-1',
          expectedVersion: 7,
          idempotencyKey: 'same-key',
          reason: DoctorDeclineReason.scheduleConflict,
        ),
      );
      expect(api.declineCommands, hasLength(2));
      expect(identical(api.declineCommands[0], api.declineCommands[1]), isTrue);
    });
  });

  group('Controllers and session isolation', () {
    test('Home ignores late response after clear', () async {
      final pending = Completer<DoctorHomeSummary>();
      final repository = _FakeRepository(homeHandler: (_) => pending.future);
      final controller = DoctorHomeController(repository: repository);
      addTearDown(controller.dispose);
      final load = controller.load();
      controller.clear();
      pending.complete(DoctorHomeSummary.fromJson(_homeJson()));
      await load;
      expect(controller.summary, isNull);
      expect(controller.state, DoctorHomeLoadState.initial);
    });

    test(
      'request clear removes detail/action key and ignores late detail',
      () async {
        final pending = Completer<DoctorBookingRequestDetail>();
        final repository = _FakeRepository(
          detailHandler: (_, _) => pending.future,
        );
        final controller = DoctorBookingRequestController(
          repository: repository,
          refreshHome: () async {},
          idempotencyKeyFactory: () => 'fixture',
        );
        addTearDown(controller.dispose);
        final open = controller.open('request-1');
        controller.clear();
        pending.complete(_detail());
        await open;
        expect(controller.request, isNull);
        expect(controller.pendingIdempotencyKey, isNull);
      },
    );

    test('accept gates by availableActions and refreshes Home', () async {
      var refreshes = 0;
      final repository = _FakeRepository(
        detailHandler: (_, _) async => _detail(),
        acceptHandler: (command, _) async {
          expect(command.expectedVersion, 7);
          expect(command.idempotencyKey, 'doctor-accept-stable');
          return DoctorMutationResult(
            request: _detail(
              status: 'FULFILLED',
              actions: const [],
              confirmedAppointmentId: 'appointment-1',
            ),
            appointment: _appointment(),
            intentCompleted: true,
          );
        },
      );
      final controller = DoctorBookingRequestController(
        repository: repository,
        refreshHome: () async => refreshes++,
        idempotencyKeyFactory: () => 'stable',
      );
      addTearDown(controller.dispose);
      await controller.open('request-1');
      expect(controller.canAccept, isTrue);
      await controller.accept();
      expect(controller.request?.status, BookingRequestStatus.fulfilled);
      expect(controller.appointment?.appointmentId, 'appointment-1');
      expect(refreshes, 1);
    });

    test(
      'decline sends controlled reason/version and refreshes Home',
      () async {
        var refreshes = 0;
        final repository = _FakeRepository(
          detailHandler: (_, _) async => _detail(),
          declineHandler: (command, _) async {
            expect(command.expectedVersion, 7);
            expect(command.reason, DoctorDeclineReason.scheduleConflict);
            expect(command.idempotencyKey, 'doctor-decline-stable');
            return DoctorMutationResult(
              request: _detail(
                status: 'CANCELLED_BY_DOCTOR',
                actions: const [],
              ),
              intentCompleted: true,
            );
          },
        );
        final controller = DoctorBookingRequestController(
          repository: repository,
          refreshHome: () async => refreshes++,
          idempotencyKeyFactory: () => 'stable',
        );
        addTearDown(controller.dispose);
        await controller.open('request-1');
        await controller.decline(DoctorDeclineReason.scheduleConflict);
        expect(
          controller.request?.status,
          BookingRequestStatus.cancelledByDoctor,
        );
        expect(controller.appointment, isNull);
        expect(refreshes, 1);
      },
    );

    test(
      'version conflict refetches and does not replay stale command',
      () async {
        var gets = 0;
        final repository = _FakeRepository(
          detailHandler: (_, _) async {
            gets++;
            return _detail(
              version: gets == 1 ? 7 : 8,
              actions: gets == 1 ? const ['ACCEPT_REQUEST'] : const [],
            );
          },
          acceptHandler: (_, _) async => throw const ScheduledCareFailure(
            kind: ScheduledCareFailureKind.versionConflict,
            message: 'changed',
            diagnosticCode: 'VERSION_CONFLICT',
          ),
        );
        final controller = DoctorBookingRequestController(
          repository: repository,
          refreshHome: () async {},
        );
        addTearDown(controller.dispose);
        await controller.open('request-1');
        await controller.accept();
        expect(repository.acceptCommands, hasLength(1));
        expect(controller.request?.version, 8);
        expect(controller.canAccept, isFalse);
      },
    );

    test('deadline passage only refetches authority', () async {
      var gets = 0;
      final repository = _FakeRepository(
        detailHandler: (_, _) async {
          gets++;
          return _detail(
            responseDeadline: '2026-01-01T00:00:00Z',
            status: gets == 1 ? 'PENDING_DOCTOR' : 'EXPIRED',
            actions: gets == 1 ? const ['ACCEPT_REQUEST'] : const [],
          );
        },
      );
      final controller = DoctorBookingRequestController(
        repository: repository,
        refreshHome: () async {},
      );
      addTearDown(controller.dispose);
      await controller.open('request-1');
      await controller.refreshIfDeadlinePassed(now: DateTime.utc(2026, 1, 2));
      expect(gets, 2);
      expect(controller.request?.status, BookingRequestStatus.expired);
    });

    test('clear ignores a late accept response', () async {
      final pending = Completer<DoctorMutationResult>();
      final repository = _FakeRepository(
        detailHandler: (_, _) async => _detail(),
        acceptHandler: (_, _) => pending.future,
      );
      final controller = DoctorBookingRequestController(
        repository: repository,
        refreshHome: () async {},
      );
      addTearDown(controller.dispose);
      await controller.open('request-1');
      final mutation = controller.accept();
      controller.clear();
      pending.complete(
        DoctorMutationResult(
          request: _detail(
            status: 'FULFILLED',
            actions: const [],
            confirmedAppointmentId: 'appointment-1',
          ),
          appointment: _appointment(),
          intentCompleted: true,
        ),
      );
      await mutation;
      expect(controller.request, isNull);
      expect(controller.appointment, isNull);
    });
  });

  group('Doctor presentation', () {
    testWidgets('real Home renders server data and navigates with requestId', (
      tester,
    ) async {
      String? opened;
      final controller = DoctorHomeController(
        repository: _FakeRepository(
          homeHandler: (_) async => DoctorHomeSummary.fromJson(_homeJson()),
        ),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildOmniTheme(),
          home: Scaffold(
            body: DoctorHomeScreen(
              profile: AuthenticatedDoctorDisplayProfile(
                now: DateTime(2026, 10, 11),
              ),
              capabilities: const {DoctorCapability.agenda},
              homeController: controller,
              onOpenBookingRequest: (value) => opened = value,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('4'), findsOneWidget);
      expect(find.text('Nadia Ben Ali'), findsNWidgets(2));
      expect(find.text('Sami Ben Ali'), findsNothing);
      await tester.tap(
        find.byKey(const ValueKey('doctor-next-pending-request')),
      );
      expect(opened, 'request-1');
    });

    testWidgets('Home error has explicit retry and no fixture fallback', (
      tester,
    ) async {
      final controller = DoctorHomeController(
        repository: _FakeRepository(
          homeHandler: (_) async => throw const ScheduledCareFailure(
            kind: ScheduledCareFailureKind.network,
            message: 'Connexion indisponible.',
            diagnosticCode: 'NETWORK',
          ),
        ),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DoctorHomeScreen(
              profile: AuthenticatedDoctorDisplayProfile(),
              capabilities: const {},
              homeController: controller,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('doctor-home-retry')), findsOneWidget);
      expect(find.text('Mohamed Trabelsi'), findsNothing);
    });

    testWidgets('detail gates actions and proposal needs an injected flow', (
      tester,
    ) async {
      final repository = _FakeRepository(
        detailHandler: (_, _) async => _detail(
          actions: const [
            'ACCEPT_REQUEST',
            'PROPOSE_NEW_TIME',
            'DECLINE_REQUEST',
          ],
        ),
      );
      final controller = DoctorBookingRequestController(
        repository: repository,
        refreshHome: () async {},
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: buildOmniTheme(),
          home: DoctorBookingRequestScreen(
            requestId: 'request-1',
            controller: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('doctor-accept-request')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('doctor-decline-request')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('doctor-propose-new-time')),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsNothing);
    });
  });
}

Map<String, dynamic> _homeJson({
  Object? request = _sentinel,
  Object? appointment = _sentinel,
  int count = 4,
}) => {
  'generatedAt': '2026-10-11T12:00:00Z',
  'pendingRequestCount': count,
  'nextPendingRequest': identical(request, _sentinel)
      ? _summaryJson()
      : request,
  'nextConfirmedAppointment': identical(appointment, _sentinel)
      ? _summaryJson(type: 'APPOINTMENT', id: 'appointment-1')
      : appointment,
};

const _sentinel = Object();

Map<String, dynamic> _summaryJson({
  String type = 'BOOKING_REQUEST',
  String id = 'request-1',
}) => {
  'resourceType': type,
  'requestId': type == 'BOOKING_REQUEST' ? id : null,
  'appointmentId': type == 'APPOINTMENT' ? id : null,
  'sourceBookingRequestId': type == 'APPOINTMENT' ? 'request-1' : null,
  'version': 7,
  'status': type == 'APPOINTMENT' ? 'CONFIRMED' : 'PENDING_DOCTOR',
  'doctor': {'displayName': 'Dr Test', 'specialty': 'Généraliste'},
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
      ? ['ACCEPT_REQUEST', 'DECLINE_REQUEST']
      : const [],
  'sortAt': '2026-10-20T08:00:00Z',
  'updatedAt': '2026-10-11T12:00:00Z',
};

Map<String, dynamic> _detailJson({
  String status = 'PENDING_DOCTOR',
  int version = 7,
  List<String> actions = const ['ACCEPT_REQUEST', 'DECLINE_REQUEST'],
  String? confirmedAppointmentId,
  String responseDeadline = '2026-10-19T08:00:00Z',
}) => {
  'requestId': 'request-1',
  'version': version,
  'status': status,
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
  'originalRequestedSlot': {
    'start': '2026-10-20T08:00:00Z',
    'end': '2026-10-20T08:30:00Z',
  },
  'proposedSlot': null,
  'activeSlot': {
    'start': '2026-10-20T08:00:00Z',
    'end': '2026-10-20T08:30:00Z',
    'durationMinutes': 30,
  },
  'createdAt': '2026-10-11T08:00:00Z',
  'responseDeadline': responseDeadline,
  'patientResponseDeadline': '2026-10-18T08:00:00Z',
  'confirmedAppointmentId': confirmedAppointmentId,
  'cancellation': status == 'CANCELLED_BY_DOCTOR'
      ? {
          'actor': 'DOCTOR',
          'reasonCode': 'DOCTOR_UNAVAILABLE',
          'cancelledAt': '2026-10-12T08:00:00Z',
        }
      : null,
  'expiredAt': status == 'EXPIRED' ? '2026-10-19T08:00:01Z' : null,
  'expiryReason': status == 'EXPIRED' ? 'DOCTOR_RESPONSE_DEADLINE' : null,
  'slotReleased': status == 'CANCELLED_BY_DOCTOR' || status == 'EXPIRED',
  'availableActions': actions,
  'updatedAt': '2026-10-12T08:00:00Z',
};

DoctorBookingRequestDetail _detail({
  String status = 'PENDING_DOCTOR',
  int version = 7,
  List<String> actions = const ['ACCEPT_REQUEST', 'DECLINE_REQUEST'],
  String? confirmedAppointmentId,
  String responseDeadline = '2026-10-19T08:00:00Z',
}) => DoctorBookingRequestDetail.fromJson(
  _detailJson(
    status: status,
    version: version,
    actions: actions,
    confirmedAppointmentId: confirmedAppointmentId,
    responseDeadline: responseDeadline,
  ),
);

Map<String, dynamic> _appointmentJson({String id = 'appointment-1'}) => {
  'appointmentId': id,
  'sourceBookingRequestId': 'request-1',
  'version': 0,
  'status': 'CONFIRMED',
  'doctor': {
    'doctorId': 'doctor-1',
    'displayName': 'Dr Test',
    'specialty': 'Généraliste',
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
  'quotedPrice': null,
  'confirmedAt': '2026-10-12T08:00:00Z',
  'createdAt': '2026-10-11T08:00:00Z',
  'updatedAt': '2026-10-12T08:00:00Z',
  'cancellation': null,
  'intakeStatus': 'NOT_STARTED',
  'availableActions': ['CANCEL_APPOINTMENT'],
};

ConfirmedScheduledAppointment _appointment() =>
    ConfirmedScheduledAppointment.fromJson(_appointmentJson());

Map<String, dynamic> _acceptJson({Map<String, dynamic>? appointment}) => {
  'request': _detailJson(
    status: 'FULFILLED',
    actions: const [],
    confirmedAppointmentId: 'appointment-1',
  ),
  'appointment': appointment ?? _appointmentJson(),
};

class _FakeRepository implements DoctorScheduledCareRepositoryContract {
  _FakeRepository({
    this.homeHandler,
    this.detailHandler,
    this.acceptHandler,
    this.declineHandler,
  });

  final Future<DoctorHomeSummary> Function(CancelToken?)? homeHandler;
  final Future<DoctorBookingRequestDetail> Function(String, CancelToken?)?
  detailHandler;
  final Future<DoctorMutationResult> Function(
    DoctorAcceptCommand,
    CancelToken?,
  )?
  acceptHandler;
  final Future<DoctorMutationResult> Function(
    DoctorDeclineCommand,
    CancelToken?,
  )?
  declineHandler;
  final acceptCommands = <DoctorAcceptCommand>[];

  @override
  Future<DoctorAgendaSnapshot> getAgenda(
    DoctorAgendaRange range, {
    CancelToken? cancelToken,
  }) => throw UnimplementedError();

  @override
  Future<ConfirmedScheduledAppointment> getAppointment(
    String appointmentId, {
    CancelToken? cancelToken,
  }) => throw UnimplementedError();

  @override
  Future<DoctorAppointmentMutationResult> cancelAppointmentOrReconcile(
    DoctorCancelAppointmentCommand command, {
    CancelToken? cancelToken,
  }) => throw UnimplementedError();

  @override
  Future<DoctorHomeSummary> getHomeSummary({CancelToken? cancelToken}) =>
      homeHandler!(cancelToken);

  @override
  Future<DoctorBookingRequestDetail> getBookingRequest(
    String requestId, {
    CancelToken? cancelToken,
  }) => detailHandler!(requestId, cancelToken);

  @override
  Future<DoctorMutationResult> acceptOrReconcile(
    DoctorAcceptCommand command, {
    CancelToken? cancelToken,
  }) {
    acceptCommands.add(command);
    return acceptHandler!(command, cancelToken);
  }

  @override
  Future<DoctorMutationResult> declineOrReconcile(
    DoctorDeclineCommand command, {
    CancelToken? cancelToken,
  }) => declineHandler!(command, cancelToken);

  @override
  Future<DoctorMutationResult> proposeOrReconcile(
    DoctorProposalCommand command, {
    CancelToken? cancelToken,
  }) => throw UnimplementedError();
}

class _FakeApi implements DoctorScheduledCareApiContract {
  _FakeApi({
    this.acceptResults = const [],
    this.declineResults = const [],
    this.detailResults = const [],
  });

  final List<Object> acceptResults;
  final List<Object> declineResults;
  final List<Object> detailResults;
  final acceptCommands = <DoctorAcceptCommand>[];
  final declineCommands = <DoctorDeclineCommand>[];
  final appointmentGets = <String>[];
  int _acceptIndex = 0;
  int _declineIndex = 0;
  int _detailIndex = 0;

  @override
  Future<DoctorAgendaSnapshot> getAgenda(
    DoctorAgendaRange range, {
    CancelToken? cancelToken,
  }) => throw UnimplementedError();

  @override
  Future<ConfirmedScheduledAppointment> cancelAppointment(
    DoctorCancelAppointmentCommand command, {
    CancelToken? cancelToken,
  }) => throw UnimplementedError();

  @override
  Future<DoctorAcceptResult> accept(
    DoctorAcceptCommand command, {
    CancelToken? cancelToken,
  }) async {
    acceptCommands.add(command);
    return _result(acceptResults[_acceptIndex++]);
  }

  @override
  Future<DoctorBookingRequestDetail> decline(
    DoctorDeclineCommand command, {
    CancelToken? cancelToken,
  }) async {
    declineCommands.add(command);
    return _result(declineResults[_declineIndex++]);
  }

  @override
  Future<DoctorBookingRequestDetail> propose(
    DoctorProposalCommand command, {
    CancelToken? cancelToken,
  }) => throw UnimplementedError();

  @override
  Future<DoctorBookingRequestDetail> getBookingRequest(
    String requestId, {
    CancelToken? cancelToken,
  }) async => _result(detailResults[_detailIndex++]);

  @override
  Future<ConfirmedScheduledAppointment> getAppointment(
    String appointmentId, {
    CancelToken? cancelToken,
  }) async {
    appointmentGets.add(appointmentId);
    return _appointment();
  }

  @override
  Future<DoctorHomeSummary> getHomeSummary({CancelToken? cancelToken}) =>
      throw UnimplementedError();
}

T _result<T>(Object value) {
  if (value is T) return value as T;
  throw value;
}

DioException _connectionFailure() => DioException(
  requestOptions: RequestOptions(path: '/doctor/booking-requests/request-1'),
  type: DioExceptionType.connectionError,
);

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
