import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/core/network/app_http_client.dart';
import 'package:omnicare_mobile/core/storage/secure_token_store.dart';
import 'package:omnicare_mobile/features/doctor/agenda/doctor_agenda_controller.dart';
import 'package:omnicare_mobile/features/doctor/scheduled_care/doctor_scheduled_care_api.dart';
import 'package:omnicare_mobile/features/doctor/scheduled_care/doctor_scheduled_care_coordinator.dart';
import 'package:omnicare_mobile/features/doctor/scheduled_care/doctor_scheduled_care_models.dart';
import 'package:omnicare_mobile/features/scheduled_care/data/scheduled_care_failure.dart';
import 'package:omnicare_mobile/features/scheduled_care/domain/scheduled_care_models.dart';
import 'package:omnicare_mobile/features/scheduled_care/realtime/scheduled_care_realtime.dart';

import 'support/doctor_scheduled_care_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('doctor DTOs keep request and appointment lifecycles strict', () {
    final request = DoctorScheduledCareItem.fromAgendaJson(_requestAgendaJson);
    final appointment = DoctorScheduledCareItem.fromAgendaJson(
      _appointmentAgendaJson,
    );

    expect(request.requestId, 'request-1');
    expect(request.appointmentId, isNull);
    expect(request.bookingRequestStatus, BookingRequestStatus.pendingDoctor);
    expect(request.can(ScheduledCareAction.acceptRequest), isTrue);
    expect(appointment.appointmentId, 'appointment-1');
    expect(appointment.requestId, isNull);
    expect(appointment.appointmentStatus, ScheduledAppointmentStatus.confirmed);
    expect(
      () => DoctorScheduledCareItem.fromAgendaJson({
        ..._requestAgendaJson,
        'appointmentId': 'must-not-exist',
      }),
      throwsFormatException,
    );
    expect(
      () => DoctorScheduledCareItem.fromAgendaJson({
        ..._requestAgendaJson,
        'status': 'FUTURE_STATUS',
      }),
      throwsFormatException,
    );
    expect(
      () => DoctorScheduledCareItem.fromAgendaJson({
        ..._requestAgendaJson,
        'availableActions': ['FUTURE_ACTION'],
      }),
      throwsFormatException,
    );
    for (final status in BookingRequestStatus.values) {
      final parsed = DoctorScheduledCareItem.fromAgendaJson({
        ..._requestAgendaJson,
        'status': status.wireName,
        'availableActions': <String>[],
      });
      expect(parsed.bookingRequestStatus, status);
    }
    for (final status in ScheduledAppointmentStatus.values) {
      final parsed = DoctorScheduledCareItem.fromAgendaJson({
        ..._appointmentAgendaJson,
        'status': status.wireName,
        'availableActions': <String>[],
      });
      expect(parsed.appointmentStatus, status);
    }
  });

  test('Doctor API uses every certified route and command contract', () async {
    final adapter = _DoctorAdapter();
    final api = DoctorScheduledCareApi(_client(adapter));

    final home = await api.getHomeSummary();
    final agenda = await api.getAgenda(
      from: DateTime.utc(2026, 10, 1),
      to: DateTime.utc(2026, 11, 1),
    );
    final request = await api.getRequest('request-1');
    final accepted = await api.acceptRequest(
      requestId: 'request-1',
      expectedVersion: 3,
      idempotencyKey: 'accept-key',
    );
    final availability = await api.getProposalAvailability(
      doctorId: 'doctor-1',
      practiceLocationId: 'cabinet-1',
      from: DateTime.utc(2026, 10, 8),
      to: DateTime.utc(2026, 10, 29),
    );
    await api.proposeNewTime(
      requestId: 'request-1',
      expectedVersion: 3,
      practiceLocationId: 'cabinet-1',
      proposedSlot: availability.slots.single,
      idempotencyKey: 'proposal-key',
    );
    await api.declineRequest(
      requestId: 'request-1',
      expectedVersion: 3,
      reasonCode: 'CABINET_UNAVAILABLE',
      idempotencyKey: 'decline-key',
    );
    final appointment = await api.getAppointment('appointment-1');
    await api.cancelAppointment(
      appointmentId: 'appointment-1',
      expectedVersion: 4,
      reasonCode: 'SCHEDULE_CONFLICT',
      idempotencyKey: 'cancel-key',
    );

    expect(home.pendingRequestCount, 1);
    expect(agenda.items, hasLength(2));
    expect(request.version, 3);
    expect(accepted.appointment.appointmentId, 'appointment-1');
    expect(appointment.appointmentId, 'appointment-1');
    expect(
      adapter.paths,
      containsAll(<String>[
        '/api/v1/doctor/scheduled-care/home-summary',
        '/api/v1/doctor/scheduled-care',
        '/api/v1/doctor/booking-requests/request-1',
        '/api/v1/doctor/booking-requests/request-1/accept',
        '/api/v1/appointments/availability/slots',
        '/api/v1/doctor/booking-requests/request-1/proposals',
        '/api/v1/doctor/booking-requests/request-1/decline',
        '/api/v1/appointments/appointment-1',
        '/api/v1/appointments/appointment-1/cancel',
      ]),
    );
    expect(
      adapter.requestFor('/api/v1/doctor/scheduled-care').query['from'],
      '2026-10-01T00:00:00.000Z',
    );
    expect(
      adapter
          .requestFor('/api/v1/doctor/booking-requests/request-1/accept')
          .headers['Idempotency-Key'],
      'accept-key',
    );
    expect(
      adapter
          .requestFor('/api/v1/doctor/booking-requests/request-1/proposals')
          .body,
      {
        'expectedVersion': 3,
        'practiceLocationId': 'cabinet-1',
        'proposedSlot': {
          'start': '2026-10-10T09:00:00.000Z',
          'end': '2026-10-10T09:30:00.000Z',
        },
      },
    );
    expect(
      adapter.requestFor('/api/v1/appointments/appointment-1/cancel').body,
      {'expectedVersion': 4, 'reasonCode': 'SCHEDULE_CONFLICT'},
    );
  });

  test(
    'unknown command outcome reconciles and reuses its idempotency key',
    () async {
      final repository = _UnknownOnceRepository();
      final controller = DoctorAgendaController(
        repository: repository,
        doctorId: 'doctor-test',
        initialDate: DateTime(2026, 10, 6),
        uuidFactory: () => 'stable-command-key',
      );
      addTearDown(controller.dispose);
      await controller.loadFocusedMonth();
      final request = controller.records.singleWhere(
        (item) => item.resourceType == ScheduledCareResourceType.bookingRequest,
      );

      expect(await controller.accept(request), isFalse);
      expect(repository.requestReads, greaterThan(0));
      final reconciled = controller.itemByIdentity(
        ScheduledCareResourceType.bookingRequest,
        request.resourceId,
      )!;
      expect(await controller.accept(reconciled), isTrue);
      expect(repository.keys, ['stable-command-key', 'stable-command-key']);
    },
  );

  test(
    'realtime hints are deduplicated and lifecycle resume resyncs REST',
    () async {
      final repository = FakeDoctorScheduledCareRepository();
      final realtime = _FakeRealtime();
      final coordinator = DoctorScheduledCareCoordinator(
        repository: repository,
        realtime: realtime,
        doctorId: 'doctor-test',
        initialDate: DateTime(2026, 10, 6),
      );
      addTearDown(coordinator.dispose);
      await coordinator.start();
      final initialHomeReads = repository.homeReads;
      final initialAgendaReads = repository.agendaReads;
      final event = ScheduledCareEvent(
        eventId: 'event-1',
        eventType: 'BOOKING_REQUEST_UPDATED',
        resourceType: ScheduledCareResourceType.bookingRequest,
        resourceId: 'request-mariem',
        version: 4,
        occurredAt: _instant,
      );

      realtime.emit(event);
      realtime.emit(event);
      await pumpEventQueue();
      expect(repository.homeReads, initialHomeReads + 1);
      expect(repository.agendaReads, initialAgendaReads + 1);

      realtime.reconnect();
      await pumpEventQueue();
      expect(repository.homeReads, initialHomeReads + 2);
      expect(repository.agendaReads, initialAgendaReads + 2);

      coordinator.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await pumpEventQueue();
      expect(repository.homeReads, greaterThan(initialHomeReads + 1));
      expect(repository.agendaReads, greaterThan(initialAgendaReads + 1));
    },
  );

  test(
    'proposal unknown outcome reuses key and preserves the exact slot',
    () async {
      final repository = _UnknownProposalOnceRepository();
      final controller = DoctorAgendaController(
        repository: repository,
        doctorId: 'doctor-test',
        initialDate: DateTime(2026, 10, 6),
        clock: () => testNow,
        uuidFactory: () => 'stable-proposal-key',
      );
      addTearDown(controller.dispose);
      await controller.loadFocusedMonth();
      final request = controller.records.singleWhere(
        (item) => item.resourceType == ScheduledCareResourceType.bookingRequest,
      );
      await controller.loadProposalAvailability(request);
      final slot = controller.proposalSlots.single;

      expect(await controller.propose(request, slot), isFalse);
      final reconciled = controller.itemByIdentity(
        ScheduledCareResourceType.bookingRequest,
        request.resourceId,
      )!;
      expect(await controller.propose(reconciled, slot), isTrue);
      expect(repository.keys, ['stable-proposal-key', 'stable-proposal-key']);
      expect(repository.lastSlot?.start, slot.start);
      expect(repository.lastSlot?.end, slot.end);
    },
  );

  test(
    'proposal slot race reconciles request and refreshes availability',
    () async {
      final repository = _SlotRaceRepository();
      final controller = DoctorAgendaController(
        repository: repository,
        doctorId: 'doctor-test',
        initialDate: DateTime(2026, 10, 6),
        clock: () => testNow,
      );
      addTearDown(controller.dispose);
      await controller.loadFocusedMonth();
      final request = controller.records.singleWhere(
        (item) => item.resourceType == ScheduledCareResourceType.bookingRequest,
      );
      await controller.loadProposalAvailability(request);
      final slot = controller.proposalSlots.single;

      expect(await controller.propose(request, slot), isFalse);
      expect(repository.requestReads, greaterThan(0));
      expect(repository.availabilityReads, 2);
      expect(controller.failure?.errorCode, 'SLOT_NO_LONGER_AVAILABLE');
    },
  );

  test('appointment cancellation is gated, versioned and terminal', () async {
    final repository = FakeDoctorScheduledCareRepository();
    final controller = DoctorAgendaController(
      repository: repository,
      doctorId: 'doctor-test',
      initialDate: DateTime(2026, 10, 6),
      uuidFactory: () => 'cancel-key',
    );
    addTearDown(controller.dispose);
    await controller.loadFocusedMonth();
    final appointment = controller.records.singleWhere(
      (item) => item.resourceType == ScheduledCareResourceType.appointment,
    );

    expect(
      await controller.cancel(
        appointment,
        DoctorAppointmentCancellationReason.scheduleConflict,
      ),
      isTrue,
    );
    expect(repository.appointment?.status, 'CANCELLED');
    expect(repository.appointment?.version, appointment.version + 1);
    expect(repository.lastIdempotencyKey, 'cancel-key');
    expect(
      repository.appointment?.cancellation?.reasonCode,
      'SCHEDULE_CONFLICT',
    );
    final terminal = controller.itemByIdentity(
      ScheduledCareResourceType.appointment,
      appointment.resourceId,
    )!;
    expect(terminal.availableActions, isEmpty);
  });

  test(
    'expired requests are server-owned terminal state with no actions',
    () async {
      final repository = FakeDoctorScheduledCareRepository()
        ..setRequestStatus(BookingRequestStatus.expired);
      final coordinator = DoctorScheduledCareCoordinator(
        repository: repository,
        realtime: const NoopScheduledCareRealtime(),
        doctorId: 'doctor-test',
        initialDate: DateTime(2026, 10, 6),
      );
      addTearDown(coordinator.dispose);
      await coordinator.start();
      final expired = coordinator.agenda.records.singleWhere(
        (item) => item.resourceType == ScheduledCareResourceType.bookingRequest,
      );

      expect(expired.status, DoctorScheduledCareStatus.expired);
      expect(expired.availableActions, isEmpty);
      expect(await coordinator.agenda.accept(expired), isFalse);
      expect(coordinator.home.summary?.pendingRequestCount, 0);
    },
  );

  test('session clear removes Doctor state and disconnects realtime', () async {
    final repository = FakeDoctorScheduledCareRepository();
    final realtime = _FakeRealtime();
    final coordinator = DoctorScheduledCareCoordinator(
      repository: repository,
      realtime: realtime,
      doctorId: 'doctor-test',
    );
    addTearDown(coordinator.dispose);
    await coordinator.start();
    expect(coordinator.home.summary, isNotNull);
    expect(coordinator.agenda.records, isNotEmpty);

    coordinator.clearSessionState();

    expect(coordinator.home.summary, isNull);
    expect(coordinator.agenda.records, isEmpty);
    expect(realtime.isConnected, isFalse);
  });
}

final _instant = DateTime.utc(2026, 10, 8, 8);

final Map<String, dynamic> _subject = {
  'subjectType': 'SELF',
  'familyMemberId': null,
  'displayName': 'Patient Test',
  'relationship': 'Moi-même',
};

final Map<String, dynamic> _agendaCabinet = {
  'name': 'Cabinet Test',
  'address': 'Rue 1',
  'city': 'Tunis',
  'governorate': 'Tunis',
  'timezone': 'Africa/Tunis',
};

final Map<String, dynamic> _detailCabinet = {
  ..._agendaCabinet,
  'practiceLocationId': 'cabinet-1',
};

final Map<String, dynamic> _requestAgendaJson = {
  'resourceType': 'BOOKING_REQUEST',
  'requestId': 'request-1',
  'appointmentId': null,
  'sourceBookingRequestId': null,
  'version': 3,
  'status': 'PENDING_DOCTOR',
  'subject': _subject,
  'cabinet': _agendaCabinet,
  'start': '2026-10-10T09:00:00Z',
  'end': '2026-10-10T09:30:00Z',
  'responseDeadline': '2026-10-09T08:00:00Z',
  'cancellation': null,
  'intakeStatus': null,
  'availableActions': ['ACCEPT_REQUEST', 'PROPOSE_NEW_TIME', 'DECLINE_REQUEST'],
  'sortAt': '2026-10-10T09:00:00Z',
  'updatedAt': '2026-10-08T08:00:00Z',
};

final Map<String, dynamic> _appointmentAgendaJson = {
  'resourceType': 'APPOINTMENT',
  'requestId': null,
  'appointmentId': 'appointment-1',
  'sourceBookingRequestId': 'request-1',
  'version': 4,
  'status': 'CONFIRMED',
  'subject': _subject,
  'cabinet': _agendaCabinet,
  'start': '2026-10-12T09:00:00Z',
  'end': '2026-10-12T09:30:00Z',
  'responseDeadline': null,
  'cancellation': null,
  'intakeStatus': 'NOT_SUBMITTED',
  'availableActions': ['CANCEL_APPOINTMENT', 'PREPARE_VISIT'],
  'sortAt': '2026-10-12T09:00:00Z',
  'updatedAt': '2026-10-08T08:00:00Z',
};

final Map<String, dynamic> _requestDetailJson = {
  'requestId': 'request-1',
  'version': 3,
  'status': 'PENDING_DOCTOR',
  'subject': _subject,
  'cabinet': _detailCabinet,
  'originalRequestedSlot': {
    'start': '2026-10-10T09:00:00Z',
    'end': '2026-10-10T09:30:00Z',
    'timezone': 'Africa/Tunis',
  },
  'proposedSlot': null,
  'activeSlot': {
    'start': '2026-10-10T09:00:00Z',
    'end': '2026-10-10T09:30:00Z',
    'timezone': 'Africa/Tunis',
  },
  'createdAt': '2026-10-08T08:00:00Z',
  'responseDeadline': '2026-10-09T08:00:00Z',
  'patientResponseDeadline': null,
  'confirmedAppointmentId': null,
  'cancellation': null,
  'expiredAt': null,
  'expiryReason': null,
  'slotReleased': false,
  'availableActions': ['ACCEPT_REQUEST', 'PROPOSE_NEW_TIME', 'DECLINE_REQUEST'],
  'updatedAt': '2026-10-08T08:00:00Z',
};

final Map<String, dynamic> _fulfilledRequestJson = {
  ..._requestDetailJson,
  'version': 4,
  'status': 'FULFILLED',
  'confirmedAppointmentId': 'appointment-1',
  'availableActions': <String>[],
};

final Map<String, dynamic> _appointmentDetailJson = {
  'appointmentId': 'appointment-1',
  'sourceBookingRequestId': 'request-1',
  'version': 4,
  'status': 'CONFIRMED',
  'doctor': {
    'doctorId': 'doctor-1',
    'displayName': 'Dr Test',
    'specialty': 'Médecine générale',
  },
  'subject': _subject,
  'cabinet': _detailCabinet,
  'slot': {
    'start': '2026-10-12T09:00:00Z',
    'end': '2026-10-12T09:30:00Z',
    'timezone': 'Africa/Tunis',
  },
  'confirmedAt': '2026-10-08T08:00:00Z',
  'createdAt': '2026-10-08T08:00:00Z',
  'updatedAt': '2026-10-08T08:00:00Z',
  'cancellation': null,
  'intakeStatus': 'NOT_SUBMITTED',
  'availableActions': ['CANCEL_APPOINTMENT', 'PREPARE_VISIT'],
};

class _UnknownOnceRepository extends FakeDoctorScheduledCareRepository {
  _UnknownOnceRepository() : super();

  bool fail = true;
  final List<String> keys = <String>[];

  @override
  Future<DoctorBookingAcceptance> acceptRequest({
    required String requestId,
    required int expectedVersion,
    required String idempotencyKey,
  }) {
    keys.add(idempotencyKey);
    if (fail) {
      fail = false;
      throw const ScheduledCareFailure(
        message: 'Résultat incertain.',
        unknownOutcome: true,
      );
    }
    return super.acceptRequest(
      requestId: requestId,
      expectedVersion: expectedVersion,
      idempotencyKey: idempotencyKey,
    );
  }
}

class _UnknownProposalOnceRepository extends FakeDoctorScheduledCareRepository {
  bool fail = true;
  final List<String> keys = <String>[];
  ScheduledCareSlot? lastSlot;

  @override
  Future<DoctorBookingRequest> proposeNewTime({
    required String requestId,
    required int expectedVersion,
    required String practiceLocationId,
    required ScheduledCareSlot proposedSlot,
    required String idempotencyKey,
  }) {
    keys.add(idempotencyKey);
    lastSlot = proposedSlot;
    if (fail) {
      fail = false;
      throw const ScheduledCareFailure(
        message: 'Résultat incertain.',
        unknownOutcome: true,
      );
    }
    return super.proposeNewTime(
      requestId: requestId,
      expectedVersion: expectedVersion,
      practiceLocationId: practiceLocationId,
      proposedSlot: proposedSlot,
      idempotencyKey: idempotencyKey,
    );
  }
}

class _SlotRaceRepository extends FakeDoctorScheduledCareRepository {
  @override
  Future<DoctorBookingRequest> proposeNewTime({
    required String requestId,
    required int expectedVersion,
    required String practiceLocationId,
    required ScheduledCareSlot proposedSlot,
    required String idempotencyKey,
  }) {
    throw const ScheduledCareFailure(
      message: 'Ce créneau n’est plus disponible.',
      errorCode: 'SLOT_NO_LONGER_AVAILABLE',
      statusCode: 409,
    );
  }
}

class _FakeRealtime implements ScheduledCareRealtime {
  ScheduledCareEventCallback? callback;
  void Function()? connected;

  @override
  bool get isConnected => callback != null;

  @override
  Future<void> connect(
    ScheduledCareEventCallback onEvent, {
    void Function()? onConnected,
  }) async {
    callback = onEvent;
    connected = onConnected;
  }

  void emit(ScheduledCareEvent event) => callback?.call(event);
  void reconnect() => connected?.call();

  @override
  Future<void> connectNotifications(
    NotificationInvalidationCallback onEvent, {
    void Function()? onConnected,
  }) async {}

  @override
  void disconnectNotifications() {}

  @override
  void disconnect() {
    callback = null;
    connected = null;
  }
}

class _RecordedRequest {
  const _RecordedRequest({
    required this.path,
    required this.query,
    required this.headers,
    required this.body,
  });

  final String path;
  final Map<String, dynamic> query;
  final Map<String, dynamic> headers;
  final Object? body;
}

class _DoctorAdapter implements HttpClientAdapter {
  final List<_RecordedRequest> requests = <_RecordedRequest>[];
  List<String> get paths => requests.map((item) => item.path).toList();

  _RecordedRequest requestFor(String path) =>
      requests.lastWhere((item) => item.path == path);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    requests.add(
      _RecordedRequest(
        path: path,
        query: Map<String, dynamic>.from(options.queryParameters),
        headers: Map<String, dynamic>.from(options.headers),
        body: options.data,
      ),
    );
    final Object response = switch (path) {
      '/api/v1/doctor/scheduled-care/home-summary' => {
        'generatedAt': '2026-10-08T08:00:00Z',
        'pendingRequestCount': 1,
        'nextPendingRequest': _requestAgendaJson,
        'nextConfirmedAppointment': _appointmentAgendaJson,
      },
      '/api/v1/doctor/scheduled-care' => {
        'generatedAt': '2026-10-08T08:00:00Z',
        'from': '2026-10-01T00:00:00Z',
        'to': '2026-11-01T00:00:00Z',
        'items': [_requestAgendaJson, _appointmentAgendaJson],
      },
      '/api/v1/doctor/booking-requests/request-1/accept' => {
        'request': _fulfilledRequestJson,
        'appointment': _appointmentDetailJson,
      },
      '/api/v1/appointments/availability/slots' => {
        'doctorId': 'doctor-1',
        'practiceLocationId': 'cabinet-1',
        'timezone': 'Africa/Tunis',
        'generatedAt': '2026-10-08T08:00:00Z',
        'slots': [
          {
            'start': '2026-10-10T09:00:00Z',
            'end': '2026-10-10T09:30:00Z',
            'timezone': 'Africa/Tunis',
          },
        ],
      },
      '/api/v1/doctor/booking-requests/request-1/proposals' ||
      '/api/v1/doctor/booking-requests/request-1/decline' ||
      '/api/v1/doctor/booking-requests/request-1' => _requestDetailJson,
      '/api/v1/appointments/appointment-1' ||
      '/api/v1/appointments/appointment-1/cancel' => _appointmentDetailJson,
      _ => throw StateError('Unexpected path: $path'),
    };
    return ResponseBody.fromString(
      _json(response),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

AppHttpClient _client(_DoctorAdapter adapter) {
  final dio = Dio()..httpClientAdapter = adapter;
  return AppHttpClient(
    tokenStore: SecureTokenStore(backend: _MemoryBackend()),
    baseUrl: 'https://api.omnicare.test',
    dio: dio,
    refreshDio: Dio(),
  );
}

String _json(Object? value) {
  if (value is Map) {
    final entries = value.entries.map(
      (entry) => '"${entry.key}":${_json(entry.value)}',
    );
    return '{${entries.join(',')}}';
  }
  if (value is List) return '[${value.map(_json).join(',')}]';
  if (value is String) {
    return '"${value.replaceAll('\\', '\\\\').replaceAll('"', '\\"')}"';
  }
  if (value == null) return 'null';
  return '$value';
}

class _MemoryBackend implements SecureTokenStorageBackend {
  @override
  Future<void> delete({required String key}) async {}
  @override
  Future<String?> read({required String key}) async => null;
  @override
  Future<void> write({required String key, required String value}) async {}
}
