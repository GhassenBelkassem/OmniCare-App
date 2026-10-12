import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/core/theme/omni_theme.dart';
import 'package:omnicare_mobile/features/patient_appointments/presentation/patient_appointments_screen.dart';
import 'package:omnicare_mobile/features/scheduled_care/application/patient_booking_controller.dart';
import 'package:omnicare_mobile/features/scheduled_care/application/patient_scheduled_care_controller.dart';
import 'package:omnicare_mobile/features/scheduled_care/data/scheduled_care_api.dart';
import 'package:omnicare_mobile/features/scheduled_care/data/scheduled_care_failure.dart';
import 'package:omnicare_mobile/features/scheduled_care/data/scheduled_care_repository.dart';
import 'package:omnicare_mobile/features/scheduled_care/domain/patient_scheduled_care_models.dart';
import 'package:omnicare_mobile/features/scheduled_care/domain/scheduled_care_models.dart';
import 'package:omnicare_mobile/features/scheduled_care/presentation/confirmed_scheduled_appointment_screen.dart';
import 'package:provider/provider.dart';

Map<String, dynamic> _summaryJson({
  String type = 'APPOINTMENT',
  String id = 'appointment-1',
  String status = 'CONFIRMED',
  String? sourceRequestId = 'request-1',
  String doctor = 'Dr. Amira Ben Salem',
}) => {
  'resourceType': type,
  'requestId': type == 'BOOKING_REQUEST' ? id : null,
  'appointmentId': type == 'APPOINTMENT' ? id : null,
  'sourceBookingRequestId': sourceRequestId,
  'version': 3,
  'status': status,
  'doctor': {'displayName': doctor, 'specialty': 'Médecine générale'},
  'subject': {
    'subjectType': 'SELF',
    'displayName': 'Moi',
    'relationship': null,
  },
  'cabinet': {
    'name': 'Cabinet du Lac',
    'address': '1 rue du Lac',
    'city': 'Tunis',
    'governorate': 'Tunis',
    'timezone': 'Africa/Tunis',
  },
  'start': '2027-01-10T08:00:00Z',
  'end': '2027-01-10T08:30:00Z',
  'timezone': 'Africa/Tunis',
  'responseDeadline': type == 'BOOKING_REQUEST' ? '2027-01-09T08:00:00Z' : null,
  'cancellation': null,
  'intakeStatus': null,
  'availableActions': type == 'APPOINTMENT'
      ? ['CANCEL_APPOINTMENT']
      : ['CANCEL_REQUEST'],
  'sortAt': '2027-01-10T08:00:00Z',
  'updatedAt': '2027-01-01T08:00:00Z',
};

ConfirmedScheduledAppointment _appointment({
  String id = 'appointment-1',
  String sourceId = 'request-1',
  int version = 3,
  String status = 'CONFIRMED',
  List<String> actions = const ['CANCEL_APPOINTMENT'],
  bool late = false,
  DateTime? start,
}) => ConfirmedScheduledAppointment.fromJson({
  'appointmentId': id,
  'sourceBookingRequestId': sourceId,
  'version': version,
  'status': status,
  'doctor': {
    'doctorId': 'doctor-1',
    'displayName': 'Dr. Amira Ben Salem',
    'specialty': 'Médecine générale',
  },
  'subject': {'subjectType': 'SELF', 'displayName': 'Moi'},
  'cabinet': {
    'practiceLocationId': 'cabinet-1',
    'name': 'Cabinet du Lac',
    'address': '1 rue du Lac',
    'city': 'Tunis',
    'governorate': 'Tunis',
    'timezone': 'Africa/Tunis',
  },
  'slot': {
    'start': (start ?? DateTime.utc(2027, 1, 10, 8)).toIso8601String(),
    'end': (start ?? DateTime.utc(2027, 1, 10, 8))
        .add(const Duration(minutes: 30))
        .toIso8601String(),
    'timezone': 'Africa/Tunis',
    'durationMinutes': 30,
  },
  'quotedPrice': {
    'amount': 80,
    'currency': 'TND',
    'quotedAt': '2027-01-01T08:00:00Z',
  },
  'confirmedAt': '2027-01-01T08:00:00Z',
  'createdAt': '2027-01-01T07:00:00Z',
  'updatedAt': '2027-01-01T08:00:00Z',
  'cancellation': status == 'CANCELLED'
      ? {
          'actor': 'PATIENT',
          'reasonCode': 'CHANGE_OF_PLANS',
          'cancelledAt': '2027-01-09T12:00:00Z',
          'lateCancellation': late,
        }
      : null,
  'intakeStatus': 'NOT_STARTED',
  'availableActions': actions,
});

PatientBookingRequestDetail _request() => PatientBookingRequestDetail.fromJson({
  'requestId': 'request-1',
  'version': 7,
  'status': 'PENDING_DOCTOR',
  'subject': {
    'subjectType': 'SELF',
    'familyMemberId': null,
    'displayName': 'Moi',
    'relationship': null,
  },
  'doctor': {
    'doctorId': 'doctor-1',
    'displayName': 'Dr. Amira Ben Salem',
    'specialty': 'Médecine générale',
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
    'start': '2027-01-10T08:00:00Z',
    'end': '2027-01-10T08:30:00Z',
  },
  'proposedSlot': null,
  'activeSlot': {
    'start': '2027-01-10T08:00:00Z',
    'end': '2027-01-10T08:30:00Z',
    'durationMinutes': 30,
  },
  'priceQuote': {
    'amount': 80,
    'currency': 'TND',
    'quotedAt': '2027-01-01T08:00:00Z',
  },
  'createdAt': '2027-01-01T08:00:00Z',
  'responseDeadline': '2027-01-09T08:00:00Z',
  'confirmedAppointmentId': null,
  'cancellation': null,
  'expiredAt': null,
  'expiryReason': null,
  'slotReleased': false,
  'availableActions': ['CANCEL_REQUEST'],
  'updatedAt': '2027-01-01T08:00:00Z',
});

PatientScheduledCarePage _page(
  Iterable<PatientScheduledCareItem> items, {
  String? cursor,
}) => PatientScheduledCarePage(
  items: items.toList(growable: false),
  nextCursor: cursor,
);

PatientScheduledCareItem _item({
  String type = 'APPOINTMENT',
  String id = 'appointment-1',
  String status = 'CONFIRMED',
}) => PatientScheduledCareItem.fromJson(
  _summaryJson(type: type, id: id, status: status),
);

class _ListRepository implements PatientScheduledCareRepositoryContract {
  _ListRepository(this.handler);

  final Future<PatientScheduledCarePage> Function(
    PatientScheduledCareQuery query,
    CancelToken? token,
  )
  handler;
  final queries = <PatientScheduledCareQuery>[];

  @override
  Future<PatientScheduledCarePage> getPatientScheduledCare(
    PatientScheduledCareQuery query, {
    CancelToken? cancelToken,
  }) {
    queries.add(query);
    return handler(query, cancelToken);
  }
}

class _BookingRepository
    implements
        ScheduledCareRepositoryContract,
        ScheduledCareLifecycleRepositoryContract,
        ScheduledAppointmentRepositoryContract {
  ConfirmedScheduledAppointment appointment = _appointment();
  final appointmentGets = <String>[];
  final requestGets = <String>[];
  final cancellationCommands = <CancelScheduledAppointmentCommand>[];
  Completer<AppointmentMutationResult>? pendingCancellation;
  ScheduledCareFailure? cancellationFailure;

  @override
  Future<PatientBookingRequestDetail> createOrReconcile(
    CreateBookingRequestCommand command, {
    CancelToken? cancelToken,
  }) => throw UnimplementedError();

  @override
  Future<PatientBookingRequestDetail> getBookingRequest(
    String requestId, {
    CancelToken? cancelToken,
  }) async {
    requestGets.add(requestId);
    return _request();
  }

  @override
  Future<BookingMutationResult> cancelOrReconcile(
    CancelBookingRequestCommand command, {
    CancelToken? cancelToken,
  }) => throw UnimplementedError();

  @override
  Future<BookingMutationResult> acceptProposalOrReconcile(
    AcceptBookingProposalCommand command, {
    CancelToken? cancelToken,
  }) => throw UnimplementedError();

  @override
  Future<BookingMutationResult> declineProposalOrReconcile(
    DeclineBookingProposalCommand command, {
    CancelToken? cancelToken,
  }) => throw UnimplementedError();

  @override
  Future<ConfirmedScheduledAppointment> getAppointment(
    String appointmentId, {
    CancelToken? cancelToken,
  }) async {
    appointmentGets.add(appointmentId);
    return appointment;
  }

  @override
  Future<AppointmentMutationResult> cancelAppointmentOrReconcile(
    CancelScheduledAppointmentCommand command, {
    CancelToken? cancelToken,
  }) async {
    cancellationCommands.add(command);
    if (cancellationFailure case final failure?) throw failure;
    if (pendingCancellation case final pending?) return pending.future;
    appointment = _appointment(
      id: command.appointmentId,
      version: command.expectedVersion + 1,
      status: 'CANCELLED',
      actions: const [],
      late: true,
    );
    return AppointmentMutationResult(
      appointment: appointment,
      intentCompleted: true,
    );
  }
}

Widget _realHost(
  PatientScheduledCareController list,
  PatientBookingController booking,
) => MultiProvider(
  providers: [
    ChangeNotifierProvider.value(value: list),
    ChangeNotifierProvider.value(value: booking),
  ],
  child: MaterialApp(
    theme: buildOmniTheme(),
    home: const PatientAppointmentsScreen(),
  ),
);

void main() {
  group('scheduled-care union contract', () {
    test('parses BOOKING_REQUEST and APPOINTMENT with separate identities', () {
      final request = _item(type: 'BOOKING_REQUEST', id: 'request-7');
      final appointment = _item(id: 'appointment-7');

      expect(request.requestId, 'request-7');
      expect(request.appointmentId, isNull);
      expect(request.identityKey, 'BOOKING_REQUEST:request-7');
      expect(appointment.appointmentId, 'appointment-7');
      expect(appointment.requestId, isNull);
      expect(appointment.identityKey, 'APPOINTMENT:appointment-7');
      expect(appointment.sourceBookingRequestId, 'request-1');
      expect(
        appointment.appointmentId,
        isNot(appointment.sourceBookingRequestId),
      );
    });

    test('rejects unknown discriminator and mismatched typed ids', () {
      expect(
        () => PatientScheduledCareItem.fromJson(
          _summaryJson(type: 'LEGACY', id: 'legacy-1'),
        ),
        throwsA(isA<ScheduledCareContractException>()),
      );
      final invalid = _summaryJson(type: 'APPOINTMENT');
      invalid['requestId'] = 'request-1';
      expect(
        () => PatientScheduledCareItem.fromJson(invalid),
        throwsA(isA<ScheduledCareContractException>()),
      );
    });

    test('page parses exact list shape and opaque cursor', () {
      final page = PatientScheduledCarePage.fromJson({
        'items': [
          _summaryJson(type: 'BOOKING_REQUEST', id: 'request-1'),
          _summaryJson(id: 'appointment-1'),
        ],
        'nextCursor': 'opaque+/cursor==',
      });
      expect(page.items, hasLength(2));
      expect(page.nextCursor, 'opaque+/cursor==');
    });

    test('query maps only backend-supported filters and exact buckets', () {
      final query = PatientScheduledCareQuery(
        bucket: PatientScheduledCareBucket.cancelled,
        cursor: 'opaque',
        limit: 40,
        query: ' Amira ',
        filters: PatientScheduledCareFilters(
          from: DateTime.utc(2027),
          to: DateTime.utc(2027, 2),
          subjectType: CareSubjectType.familyMember,
          familyMemberId: 'family-1',
          city: ' Tunis ',
        ),
      ).toQueryParameters();
      expect(query, {
        'bucket': 'CANCELLED',
        'cursor': 'opaque',
        'limit': 40,
        'query': 'Amira',
        'from': '2027-01-01T00:00:00.000Z',
        'to': '2027-02-01T00:00:00.000Z',
        'subjectType': 'FAMILY_MEMBER',
        'familyMemberId': 'family-1',
        'city': 'Tunis',
      });
      expect(PatientScheduledCareApi.path, '/patient/scheduled-care');
      expect(
        ScheduledAppointmentCancellationApi.pathFor('appointment-1'),
        '/appointments/appointment-1/cancel',
      );
    });
  });

  group('list controller', () {
    test('first page, append, null cursor, and typed dedupe', () async {
      final duplicate = _item(id: 'same-id');
      final requestWithSameValue = _item(
        type: 'BOOKING_REQUEST',
        id: 'same-id',
      );
      final repository = _ListRepository((query, _) async {
        if (query.cursor == null) {
          return _page([duplicate, requestWithSameValue], cursor: 'next-1');
        }
        return _page([duplicate, _item(id: 'appointment-2')]);
      });
      final controller = PatientScheduledCareController(repository: repository);

      await controller.load();
      expect(controller.items, hasLength(2));
      expect(controller.nextCursor, 'next-1');
      await controller.loadMore();
      expect(controller.items.map((item) => item.identityKey), [
        'APPOINTMENT:same-id',
        'BOOKING_REQUEST:same-id',
        'APPOINTMENT:appointment-2',
      ]);
      expect(controller.nextCursor, isNull);
      await controller.loadMore();
      expect(repository.queries, hasLength(2));
    });

    test('double load-more is guarded', () async {
      final nextPage = Completer<PatientScheduledCarePage>();
      final repository = _ListRepository((query, _) {
        if (query.cursor == null) {
          return Future.value(_page([_item()], cursor: 'next'));
        }
        return nextPage.future;
      });
      final controller = PatientScheduledCareController(repository: repository);
      await controller.load();

      final first = controller.loadMore();
      final second = controller.loadMore();
      expect(repository.queries, hasLength(2));
      nextPage.complete(_page([_item(id: 'appointment-2')]));
      await Future.wait([first, second]);
      expect(controller.items, hasLength(2));
    });

    test('refresh and filter changes reset the cursor', () async {
      final repository = _ListRepository(
        (query, _) async => _page([_item()], cursor: 'next'),
      );
      final controller = PatientScheduledCareController(repository: repository);
      await controller.load();
      await controller.refresh();
      await controller.setBucket(PatientScheduledCareBucket.past);
      await controller.setFilters(
        const PatientScheduledCareFilters(city: 'Tunis'),
      );
      await controller.setQuery('Amira');

      expect(
        repository.queries.skip(1).every((query) => query.cursor == null),
        isTrue,
      );
      expect(repository.queries[2].bucket, PatientScheduledCareBucket.past);
      expect(repository.queries[3].filters.city, 'Tunis');
      expect(repository.queries[4].query, 'Amira');
    });

    test('late response is ignored after session clear', () async {
      final pending = Completer<PatientScheduledCarePage>();
      final repository = _ListRepository((_, _) => pending.future);
      final controller = PatientScheduledCareController(repository: repository);
      final load = controller.load();
      controller.clear();
      pending.complete(_page([_item()]));
      await load;

      expect(controller.items, isEmpty);
      expect(controller.nextCursor, isNull);
      expect(controller.state, PatientScheduledCareLoadState.initial);
      expect(controller.filters.isActive, isFalse);
    });

    testWidgets('production screen renders real list and empty/error states', (
      tester,
    ) async {
      Future<void> pumpWith(
        Future<PatientScheduledCarePage> Function() response,
      ) async {
        final controller = PatientScheduledCareController(
          repository: _ListRepository((_, _) => response()),
        );
        await tester.pumpWidget(
          ChangeNotifierProvider.value(
            value: controller,
            child: MaterialApp(
              theme: buildOmniTheme(),
              home: PatientAppointmentsScreen(key: UniqueKey()),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await pumpWith(() async => _page([_item()]));
      expect(find.text('Dr. Amira Ben Salem'), findsOneWidget);
      expect(find.text('Africa/Tunis'), findsOneWidget);

      await pumpWith(() async => _page([]));
      expect(find.text('Aucun rendez-vous à venir'), findsOneWidget);

      await pumpWith(
        () => throw const ScheduledCareFailure(
          kind: ScheduledCareFailureKind.server,
          message: 'Service indisponible.',
          diagnosticCode: 'TEST_SERVER',
        ),
      );
      expect(find.text('Service indisponible.'), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);
    });

    testWidgets('booking request item re-enters authoritative R2C detail', (
      tester,
    ) async {
      final bookingRepository = _BookingRepository();
      final booking = PatientBookingController(
        repository: bookingRepository,
        lifecycleRepository: bookingRepository,
        appointmentRepository: bookingRepository,
      );
      final list = PatientScheduledCareController(
        repository: _ListRepository(
          (_, _) async =>
              _page([_item(type: 'BOOKING_REQUEST', id: 'request-1')]),
        ),
      );
      await tester.pumpWidget(_realHost(list, booking));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Dr. Amira Ben Salem'));
      await tester.pumpAndSettle();

      expect(bookingRepository.requestGets, ['request-1']);
      expect(find.text('En attente de la réponse du médecin'), findsOneWidget);
    });

    testWidgets('appointment item re-enters authoritative scheduled detail', (
      tester,
    ) async {
      final bookingRepository = _BookingRepository();
      final booking = PatientBookingController(
        repository: bookingRepository,
        lifecycleRepository: bookingRepository,
        appointmentRepository: bookingRepository,
      );
      final list = PatientScheduledCareController(
        repository: _ListRepository(
          (_, _) async => _page([_item(id: 'appointment-1')]),
        ),
      );
      await tester.pumpWidget(_realHost(list, booking));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Dr. Amira Ben Salem'));
      await tester.pumpAndSettle();

      expect(bookingRepository.appointmentGets, ['appointment-1']);
      expect(find.text('Détails du rendez-vous'), findsOneWidget);
      expect(find.text('request-1'), findsOneWidget);
      expect(find.text('appointment-1'), findsOneWidget);
    });
  });

  group('appointment re-entry and cancellation', () {
    late _BookingRepository repository;
    late PatientBookingController controller;

    setUp(() {
      repository = _BookingRepository();
      controller = PatientBookingController(
        repository: repository,
        lifecycleRepository: repository,
        appointmentRepository: repository,
        idempotencyKeyFactory: () => 'stable-key',
      );
    });

    test(
      'appointment id resolves authoritative detail after restart',
      () async {
        await controller.openAppointment('appointment-1');
        expect(repository.appointmentGets, ['appointment-1']);
        expect(controller.appointment?.appointmentId, 'appointment-1');
        expect(controller.appointment?.sourceBookingRequestId, 'request-1');
        expect(
          controller.appointment?.appointmentId,
          isNot(controller.appointment?.sourceBookingRequestId),
        );
      },
    );

    test('cancellation gate comes only from availableActions', () async {
      repository.appointment = _appointment(actions: const []);
      await controller.openAppointment('appointment-1');
      expect(controller.canCancelAppointment, isFalse);
      await controller.cancelAppointment(
        AppointmentCancellationReason.changeOfPlans,
      );
      expect(repository.cancellationCommands, isEmpty);
    });

    test(
      'cancellation carries version, reason, stable key and late result',
      () async {
        await controller.openAppointment('appointment-1');
        await controller.cancelAppointment(
          AppointmentCancellationReason.changeOfPlans,
        );
        final command = repository.cancellationCommands.single;
        expect(command.expectedVersion, 3);
        expect(command.reason?.wireValue, 'CHANGE_OF_PLANS');
        expect(command.idempotencyKey, 'patient-appointment-cancel-stable-key');
        expect(
          controller.appointment?.status,
          ScheduledAppointmentStatus.cancelled,
        );
        expect(controller.appointment?.cancellation?.lateCancellation, isTrue);
        expect(controller.canCancelAppointment, isFalse);
      },
    );

    test(
      'unknown outcome keeps the same cancellation identity for retry',
      () async {
        await controller.openAppointment('appointment-1');
        repository.cancellationFailure = const ScheduledCareFailure(
          kind: ScheduledCareFailureKind.unknownOutcome,
          message: 'Résultat incertain.',
          diagnosticCode: 'UNKNOWN',
          retryable: true,
        );
        await controller.cancelAppointment(
          AppointmentCancellationReason.noLongerNeeded,
        );
        final firstKey = controller.pendingAppointmentCancellationKey;
        await controller.cancelAppointment(
          AppointmentCancellationReason.noLongerNeeded,
        );
        expect(repository.cancellationCommands, hasLength(2));
        expect(repository.cancellationCommands[1].idempotencyKey, firstKey);
      },
    );

    test(
      'version conflict refetches and never replays stale command',
      () async {
        await controller.openAppointment('appointment-1');
        repository.appointment = _appointment(version: 4, actions: const []);
        repository.cancellationFailure = const ScheduledCareFailure(
          kind: ScheduledCareFailureKind.versionConflict,
          message: 'État actualisé.',
          diagnosticCode: 'VERSION_CONFLICT',
        );
        await controller.cancelAppointment(
          AppointmentCancellationReason.changeOfPlans,
        );

        expect(repository.cancellationCommands, hasLength(1));
        expect(repository.appointmentGets, ['appointment-1', 'appointment-1']);
        expect(controller.appointment?.version, 4);
        expect(controller.canCancelAppointment, isFalse);
      },
    );

    test(
      'action conflict refetches and removes the unavailable action',
      () async {
        await controller.openAppointment('appointment-1');
        repository.appointment = _appointment(version: 4, actions: const []);
        repository.cancellationFailure = const ScheduledCareFailure(
          kind: ScheduledCareFailureKind.actionNotAllowed,
          message: 'Action indisponible.',
          diagnosticCode: 'ACTION_NOT_ALLOWED',
        );
        await controller.cancelAppointment(
          AppointmentCancellationReason.changeOfPlans,
        );

        expect(repository.cancellationCommands, hasLength(1));
        expect(repository.appointmentGets, ['appointment-1', 'appointment-1']);
        expect(controller.canCancelAppointment, isFalse);
      },
    );

    testWidgets('late cancellation confirmation warns without a penalty', (
      tester,
    ) async {
      repository.appointment = _appointment(
        start: DateTime.now().toUtc().add(const Duration(hours: 12)),
      );
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: controller,
          child: MaterialApp(
            theme: buildOmniTheme(),
            home: const ConfirmedScheduledAppointmentScreen(
              appointmentId: 'appointment-1',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('cancel-scheduled-appointment')),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(
        find.byKey(const ValueKey('cancel-scheduled-appointment')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Changement de programme'));
      await tester.pumpAndSettle();

      expect(find.textContaining('moins de 24 heures'), findsOneWidget);
      expect(find.textContaining('frais'), findsNothing);
      expect(find.textContaining('pénalité'), findsNothing);
    });

    test('idempotency conflict stops blind retry', () async {
      await controller.openAppointment('appointment-1');
      repository.cancellationFailure = const ScheduledCareFailure(
        kind: ScheduledCareFailureKind.idempotencyConflict,
        message: 'Conflit.',
        diagnosticCode: 'IDEMPOTENCY_CONFLICT',
      );
      await controller.cancelAppointment(
        AppointmentCancellationReason.changeOfPlans,
      );
      await controller.cancelAppointment(
        AppointmentCancellationReason.changeOfPlans,
      );
      expect(repository.cancellationCommands, hasLength(1));
      expect(controller.pendingAppointmentCancellationKey, isNull);
    });

    test(
      'session clear ignores late detail and cancellation responses',
      () async {
        final detailPending = Completer<ConfirmedScheduledAppointment>();
        final lateRepository = _DelayedBookingRepository(detailPending);
        final detailController = PatientBookingController(
          repository: lateRepository,
          lifecycleRepository: lateRepository,
          appointmentRepository: lateRepository,
        );
        final open = detailController.openAppointment('appointment-1');
        detailController.clear();
        detailPending.complete(_appointment());
        await open;
        expect(detailController.appointment, isNull);

        await controller.openAppointment('appointment-1');
        repository.pendingCancellation = Completer<AppointmentMutationResult>();
        final cancel = controller.cancelAppointment(
          AppointmentCancellationReason.changeOfPlans,
        );
        controller.clear();
        repository.pendingCancellation!.complete(
          AppointmentMutationResult(
            appointment: _appointment(status: 'CANCELLED', actions: const []),
            intentCompleted: true,
          ),
        );
        await cancel;
        expect(controller.appointment, isNull);
        expect(controller.pendingAppointmentCancellationKey, isNull);
      },
    );
  });

  group('appointment cancellation reconciliation', () {
    test(
      'unknown outcome GETs then retries once with the exact command',
      () async {
        final coreApi = _CoreApi(_appointment());
        final cancellationApi = _CancellationApi([
          DioException(
            requestOptions: RequestOptions(
              path: '/appointments/appointment-1/cancel',
            ),
            type: DioExceptionType.connectionError,
          ),
          _appointment(
            status: 'CANCELLED',
            version: 4,
            actions: const [],
            late: true,
          ),
        ]);
        final repository = ScheduledCareRepository(
          coreApi,
          appointmentCancellationApi: cancellationApi,
        );
        const command = CancelScheduledAppointmentCommand(
          appointmentId: 'appointment-1',
          expectedVersion: 3,
          idempotencyKey: 'same-key',
          reason: AppointmentCancellationReason.noLongerNeeded,
        );

        final result = await repository.cancelAppointmentOrReconcile(command);

        expect(result.intentCompleted, isTrue);
        expect(result.appointment.cancellation?.lateCancellation, isTrue);
        expect(coreApi.appointmentGets, ['appointment-1']);
        expect(cancellationApi.commands, hasLength(2));
        expect(cancellationApi.commands[0].idempotencyKey, 'same-key');
        expect(cancellationApi.commands[1].idempotencyKey, 'same-key');
        expect(cancellationApi.commands[1].expectedVersion, 3);
        expect(
          cancellationApi.commands[1].reason?.wireValue,
          'NO_LONGER_NEEDED',
        );
      },
    );

    test('authoritative CANCELLED reconciliation never replays POST', () async {
      final coreApi = _CoreApi(
        _appointment(status: 'CANCELLED', actions: const []),
      );
      final cancellationApi = _CancellationApi([
        DioException(
          requestOptions: RequestOptions(
            path: '/appointments/appointment-1/cancel',
          ),
          type: DioExceptionType.receiveTimeout,
        ),
      ]);
      final repository = ScheduledCareRepository(
        coreApi,
        appointmentCancellationApi: cancellationApi,
      );
      const command = CancelScheduledAppointmentCommand(
        appointmentId: 'appointment-1',
        expectedVersion: 3,
        idempotencyKey: 'same-key',
      );

      final result = await repository.cancelAppointmentOrReconcile(command);

      expect(result.intentCompleted, isTrue);
      expect(cancellationApi.commands, hasLength(1));
      expect(command.toJson(), {'expectedVersion': 3, 'reasonCode': null});
    });
  });
}

class _DelayedBookingRepository extends _BookingRepository {
  _DelayedBookingRepository(this.detailPending);
  final Completer<ConfirmedScheduledAppointment> detailPending;

  @override
  Future<ConfirmedScheduledAppointment> getAppointment(
    String appointmentId, {
    CancelToken? cancelToken,
  }) => detailPending.future;
}

class _CoreApi implements ScheduledCareApi {
  _CoreApi(this.appointment);

  final ConfirmedScheduledAppointment appointment;
  final appointmentGets = <String>[];

  @override
  Future<ConfirmedScheduledAppointment> getAppointment(
    String appointmentId, {
    CancelToken? cancelToken,
  }) async {
    appointmentGets.add(appointmentId);
    return appointment;
  }

  @override
  Future<PatientBookingRequestDetail> createBookingRequest(
    CreateBookingRequestCommand command, {
    CancelToken? cancelToken,
  }) => throw UnimplementedError();

  @override
  Future<PatientBookingRequestDetail> getBookingRequest(
    String requestId, {
    CancelToken? cancelToken,
  }) => throw UnimplementedError();

  @override
  Future<PatientBookingRequestDetail> cancelBookingRequest(
    CancelBookingRequestCommand command, {
    CancelToken? cancelToken,
  }) => throw UnimplementedError();

  @override
  Future<ProposalAcceptanceResult> acceptProposal(
    AcceptBookingProposalCommand command, {
    CancelToken? cancelToken,
  }) => throw UnimplementedError();

  @override
  Future<PatientBookingRequestDetail> declineProposal(
    DeclineBookingProposalCommand command, {
    CancelToken? cancelToken,
  }) => throw UnimplementedError();
}

class _CancellationApi implements ScheduledAppointmentCancellationApiContract {
  _CancellationApi(this.results);

  final List<Object> results;
  final commands = <CancelScheduledAppointmentCommand>[];

  @override
  Future<ConfirmedScheduledAppointment> cancelAppointment(
    CancelScheduledAppointmentCommand command, {
    CancelToken? cancelToken,
  }) async {
    commands.add(command);
    final result = results.removeAt(0);
    if (result is Exception) throw result;
    return result as ConfirmedScheduledAppointment;
  }
}
