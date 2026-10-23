import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:omnicare_mobile/core/theme/omni_theme.dart';
import 'package:omnicare_mobile/features/doctor/agenda/doctor_agenda_controller.dart';
import 'package:omnicare_mobile/features/doctor/agenda/doctor_agenda_screen.dart';
import 'package:omnicare_mobile/features/doctor/scheduled_care/data/doctor_scheduled_care_repository.dart';
import 'package:omnicare_mobile/features/doctor/scheduled_care/domain/doctor_scheduled_care_models.dart';
import 'package:omnicare_mobile/features/scheduled_care/domain/patient_scheduled_care_models.dart';
import 'package:omnicare_mobile/features/scheduled_care/domain/scheduled_care_models.dart';

Widget _agenda(
  DoctorAgendaController controller, {
  ValueChanged<String>? onRequest,
  ValueChanged<String>? onAppointment,
}) => MaterialApp(
  theme: buildOmniTheme(),
  locale: const Locale('fr'),
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  supportedLocales: const [Locale('fr')],
  home: Scaffold(
    body: DoctorAgendaScreen(
      controller: controller,
      onOpenBookingRequest: onRequest,
      onOpenAppointment: onAppointment,
    ),
  ),
);

void main() {
  setUpAll(() async => initializeDateFormatting('fr_FR'));

  test('visible month uses the smallest truthful Africa/Tunis range', () async {
    final repository = _AgendaRepository(results: [_snapshot([])]);
    final controller = DoctorAgendaController(
      repository: repository,
      now: DateTime.utc(2026, 10, 11, 12),
    );

    await controller.load();

    expect(repository.ranges, hasLength(1));
    expect(repository.ranges.single.from, DateTime.utc(2026, 9, 30, 23));
    expect(repository.ranges.single.to, DateTime.utc(2026, 10, 31, 23));
    expect(
      repository.ranges.single.to.difference(repository.ranges.single.from),
      lessThanOrEqualTo(const Duration(days: 62)),
    );
  });

  test(
    'Agenda preserves backend ordering and typed resource identity',
    () async {
      final items = [
        _item(
          type: 'BOOKING_REQUEST',
          id: 'request-1',
          status: 'PENDING_DOCTOR',
        ),
        _item(type: 'APPOINTMENT', id: 'appointment-1', status: 'CONFIRMED'),
      ];
      final controller = DoctorAgendaController(
        repository: _AgendaRepository(results: [_snapshot(items)]),
        now: DateTime.utc(2026, 10, 11),
      );

      await controller.load();

      expect(controller.items.map((item) => item.identityKey), [
        'BOOKING_REQUEST:request-1',
        'APPOINTMENT:appointment-1',
      ]);
      expect(controller.items.first.requestId, 'request-1');
      expect(controller.items.first.appointmentId, isNull);
      expect(controller.items.last.appointmentId, 'appointment-1');
      expect(controller.items.last.requestId, isNull);
    },
  );

  test(
    'late prior-month response cannot overwrite the current month',
    () async {
      final october = Completer<DoctorAgendaSnapshot>();
      final november = Completer<DoctorAgendaSnapshot>();
      final repository = _AgendaRepository(
        results: [october.future, november.future],
      );
      final controller = DoctorAgendaController(
        repository: repository,
        now: DateTime.utc(2026, 10, 11),
      );

      final first = controller.load();
      controller.focusMonth(DateTime(2026, 11));
      await Future<void>.delayed(Duration.zero);
      november.complete(
        _snapshotForRange(repository.ranges[1], [
          _item(type: 'APPOINTMENT', id: 'november', status: 'CONFIRMED'),
        ]),
      );
      await Future<void>.delayed(Duration.zero);
      october.complete(
        _snapshotForRange(repository.ranges[0], [
          _item(type: 'APPOINTMENT', id: 'october', status: 'CONFIRMED'),
        ]),
      );
      await first;

      expect(controller.items.single.appointmentId, 'november');
      expect(controller.focusedDate, DateTime(2026, 11));
    },
  );

  test('clear rejects an in-flight prior-session response', () async {
    final pending = Completer<DoctorAgendaSnapshot>();
    final repository = _AgendaRepository(results: [pending.future]);
    final controller = DoctorAgendaController(
      repository: repository,
      now: DateTime.utc(2026, 10, 11),
    );

    final load = controller.load();
    await Future<void>.delayed(Duration.zero);
    controller.clear();
    pending.complete(
      _snapshotForRange(repository.ranges.single, [
        _item(type: 'APPOINTMENT', id: 'old-doctor', status: 'CONFIRMED'),
      ]),
    );
    await load;

    expect(controller.state, DoctorAgendaLoadState.initial);
    expect(controller.items, isEmpty);
    expect(controller.visibleRange, isNull);
  });

  testWidgets('request and appointment stay distinct and open typed IDs', (
    tester,
  ) async {
    String? openedRequest;
    String? openedAppointment;
    final controller = DoctorAgendaController.preview(
      now: DateTime.utc(2026, 10, 11),
      items: [
        PatientScheduledCareItem.fromJson(
          _item(
            type: 'BOOKING_REQUEST',
            id: 'request-1',
            status: 'PENDING_DOCTOR',
          ),
        ),
        PatientScheduledCareItem.fromJson(
          _item(type: 'APPOINTMENT', id: 'appointment-1', status: 'CONFIRMED'),
        ),
      ],
    );
    await tester.pumpWidget(
      _agenda(
        controller,
        onRequest: (id) => openedRequest = id,
        onAppointment: (id) => openedAppointment = id,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Demande de rendez-vous'), findsOneWidget);
    expect(find.text('Rendez-vous'), findsOneWidget);
    await tester.tap(
      find.byKey(
        const ValueKey('doctor-agenda-item-BOOKING_REQUEST:request-1'),
      ),
    );
    await tester.ensureVisible(
      find.byKey(
        const ValueKey('doctor-agenda-item-APPOINTMENT:appointment-1'),
      ),
    );
    await tester.tap(
      find.byKey(
        const ValueKey('doctor-agenda-item-APPOINTMENT:appointment-1'),
      ),
    );
    expect(openedRequest, 'request-1');
    expect(openedAppointment, 'appointment-1');
  });

  testWidgets('empty response stays empty without fixture fallback', (
    tester,
  ) async {
    final controller = DoctorAgendaController(
      repository: _AgendaRepository(results: [_snapshot([])]),
      now: DateTime.utc(2026, 10, 11),
    );
    await tester.pumpWidget(_agenda(controller));
    await tester.pumpAndSettle();

    expect(find.text('Aucun élément prévu'), findsOneWidget);
    expect(controller.items, isEmpty);
  });

  testWidgets('network error exposes retry and successful recovery', (
    tester,
  ) async {
    final repository = _AgendaRepository(
      results: [
        DioException(
          requestOptions: RequestOptions(path: '/doctor/scheduled-care'),
          type: DioExceptionType.connectionError,
        ),
        _snapshot([
          _item(type: 'APPOINTMENT', id: 'recovered', status: 'CONFIRMED'),
        ]),
      ],
    );
    final controller = DoctorAgendaController(
      repository: repository,
      now: DateTime.utc(2026, 10, 11),
    );
    await tester.pumpWidget(_agenda(controller));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('doctor-agenda-retry')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('doctor-agenda-retry')));
    await tester.pumpAndSettle();
    expect(find.text('Patient test'), findsOneWidget);
    expect(repository.ranges, hasLength(2));
  });

  testWidgets('production Agenda has no arrival, QR, or reschedule action', (
    tester,
  ) async {
    final controller = DoctorAgendaController.preview(
      now: DateTime.utc(2026, 10, 11),
      items: [
        PatientScheduledCareItem.fromJson(
          _item(type: 'APPOINTMENT', id: 'appointment-1', status: 'CONFIRMED'),
        ),
      ],
    );
    await tester.pumpWidget(_agenda(controller));
    await tester.pumpAndSettle();

    expect(find.textContaining('Patient arrivé'), findsNothing);
    expect(find.textContaining('Scanner le QR'), findsNothing);
    expect(find.textContaining('Proposer un autre horaire'), findsNothing);
    expect(find.textContaining('Reprogrammer'), findsNothing);
  });

  testWidgets('Agenda fits supported small-phone dimensions', (tester) async {
    const sizes = [Size(360, 568), Size(390, 844), Size(430, 932)];
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final size in sizes) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        _agenda(
          DoctorAgendaController.preview(now: DateTime.utc(2026, 10, 11)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Agenda'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'size: $size');
    }
  });
}

Map<String, dynamic> _item({
  required String type,
  required String id,
  required String status,
}) => {
  'resourceType': type,
  if (type == 'BOOKING_REQUEST') 'requestId': id else 'appointmentId': id,
  'sourceBookingRequestId': type == 'APPOINTMENT' ? 'source-$id' : null,
  'version': 4,
  'status': status,
  'doctor': {'displayName': 'Dr Test', 'specialty': 'Médecine générale'},
  'subject': {
    'subjectType': 'SELF',
    'displayName': 'Patient test',
    'relationship': null,
  },
  'cabinet': {
    'name': 'Cabinet Tunis',
    'address': '1 rue test',
    'city': 'Tunis',
    'governorate': 'Tunis',
    'timezone': 'Africa/Tunis',
  },
  'start': '2026-10-11T08:00:00Z',
  'end': '2026-10-11T08:30:00Z',
  'timezone': 'Africa/Tunis',
  'responseDeadline': type == 'BOOKING_REQUEST' ? '2026-10-12T08:00:00Z' : null,
  'cancellation': null,
  'intakeStatus': type == 'APPOINTMENT' ? 'NOT_STARTED' : null,
  'availableActions': type == 'APPOINTMENT'
      ? ['CANCEL_APPOINTMENT']
      : ['ACCEPT_REQUEST'],
  'sortAt': '2026-10-11T08:00:00Z',
  'updatedAt': '2026-10-10T08:00:00Z',
};

DoctorAgendaSnapshot _snapshot(List<Map<String, dynamic>> items) =>
    DoctorAgendaSnapshot.fromJson({
      'generatedAt': '2026-10-11T07:00:00Z',
      'from': '2026-09-30T23:00:00Z',
      'to': '2026-10-31T23:00:00Z',
      'items': items,
    });

DoctorAgendaSnapshot _snapshotForRange(
  DoctorAgendaRange range,
  List<Map<String, dynamic>> items,
) => DoctorAgendaSnapshot.fromJson({
  'generatedAt': '2026-10-11T07:00:00Z',
  'from': range.from.toUtc().toIso8601String(),
  'to': range.to.toUtc().toIso8601String(),
  'items': items,
});

class _AgendaRepository implements DoctorScheduledCareRepositoryContract {
  _AgendaRepository({required this.results});
  final List<Object> results;
  final ranges = <DoctorAgendaRange>[];
  int _index = 0;

  @override
  Future<DoctorAgendaSnapshot> getAgenda(
    DoctorAgendaRange range, {
    CancelToken? cancelToken,
  }) async {
    ranges.add(range);
    final result = results[_index++];
    if (result is Future<DoctorAgendaSnapshot>) return result;
    if (result is DoctorAgendaSnapshot) {
      return _snapshotForRange(range, [
        for (final item in result.items) _itemToJson(item),
      ]);
    }
    throw result;
  }

  @override
  Future<DoctorHomeSummary> getHomeSummary({CancelToken? cancelToken}) =>
      throw UnimplementedError();
  @override
  Future<DoctorBookingRequestDetail> getBookingRequest(
    String requestId, {
    CancelToken? cancelToken,
  }) => throw UnimplementedError();
  @override
  Future<ConfirmedScheduledAppointment> getAppointment(
    String appointmentId, {
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
  @override
  Future<DoctorAppointmentMutationResult> cancelAppointmentOrReconcile(
    DoctorCancelAppointmentCommand command, {
    CancelToken? cancelToken,
  }) => throw UnimplementedError();
}

Map<String, dynamic> _itemToJson(PatientScheduledCareItem item) => _item(
  type: item.resourceType.wireValue,
  id: item.identity.value,
  status: item.status,
);
