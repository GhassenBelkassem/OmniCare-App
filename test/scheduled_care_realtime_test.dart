import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/core/realtime/authenticated_realtime_transport.dart';
import 'package:omnicare_mobile/core/storage/secure_token_store.dart';
import 'package:omnicare_mobile/features/scheduled_care/realtime/coalesced_refresh.dart';
import 'package:omnicare_mobile/features/scheduled_care/realtime/recent_event_deduper.dart';
import 'package:omnicare_mobile/features/scheduled_care/realtime/scheduled_care_event.dart';
import 'package:omnicare_mobile/features/scheduled_care/realtime/scheduled_care_realtime_coordinator.dart';
import 'package:stomp_dart_client/stomp_dart_client.dart';

const _requestId = '11111111-1111-4111-8111-111111111111';
const _appointmentId = '22222222-2222-4222-8222-222222222222';

void main() {
  group('authenticated realtime transport', () {
    late _MemoryTokenBackend backend;
    late SecureTokenStore tokenStore;
    late _FakeSocketFactory socketFactory;
    late AuthenticatedRealtimeTransport transport;

    setUp(() async {
      backend = _MemoryTokenBackend();
      tokenStore = SecureTokenStore(backend: backend);
      socketFactory = _FakeSocketFactory();
      transport = AuthenticatedRealtimeTransport(
        tokenStore: tokenStore,
        socketFactory: socketFactory,
        endpoint: 'https://api.example.test/api/v1/ws',
        reconnectDelay: Duration.zero,
      );
      await tokenStore.saveSession(_session(accessToken: 'access-one'));
    });

    tearDown(() => transport.dispose());

    test(
      'uses SockJS endpoint and bearer only in STOMP CONNECT headers',
      () async {
        await transport.startSession(
          const RealtimeSessionOwner(userId: 'patient-a', role: 'PATIENT'),
        );

        final configuration = socketFactory.configurations.single;
        expect(configuration.url, 'https://api.example.test/api/v1/ws');
        expect(configuration.useSockJs, isTrue);
        expect(configuration.url, isNot(contains('access-one')));
        expect(configuration.stompConnectHeaders, {
          'Authorization': 'Bearer access-one',
        });
        expect(socketFactory.sockets.single.activated, isTrue);
        expect(transport.state, RealtimeConnectionState.connecting);
      },
    );

    test('subscribes only to private scheduled-care after connect', () async {
      final epochs = <int>[];
      transport.connectedEpochs.listen(epochs.add);
      await transport.startSession(
        const RealtimeSessionOwner(userId: 'patient-a', role: 'PATIENT'),
      );
      expect(socketFactory.sockets.single.destinations, isEmpty);

      socketFactory.configurations.single.onConnected();
      await _pumpEvents();

      expect(socketFactory.sockets.single.destinations, [
        '/user/queue/scheduled-care',
        '/user/queue/notifications',
      ]);
      expect(transport.state, RealtimeConnectionState.connected);
      expect(transport.connectionEpoch, 1);
      expect(epochs, [1]);
    });

    test('routes both private subscriptions over the same socket', () async {
      final scheduledCare = <String>[];
      final notifications = <String>[];
      transport.messages.listen(scheduledCare.add);
      transport.notificationMessages.listen(notifications.add);
      await transport.startSession(
        const RealtimeSessionOwner(userId: 'patient-a', role: 'PATIENT'),
      );
      socketFactory.configurations.single.onConnected();

      socketFactory.sockets.single.emit('{"scheduled":true}');
      socketFactory.sockets.single.emitNotification('{"notification":true}');
      await _pumpEvents();

      expect(scheduledCare, ['{"scheduled":true}']);
      expect(notifications, ['{"notification":true}']);
      expect(socketFactory.sockets, hasLength(1));
    });

    test(
      'closed-socket teardown is safe and duplicate callbacks reconnect once',
      () async {
        await transport.startSession(
          const RealtimeSessionOwner(userId: 'patient-a', role: 'PATIENT'),
        );
        final firstConfiguration = socketFactory.configurations.first;
        final firstSocket = socketFactory.sockets.first;
        firstConfiguration.onConnected();
        firstSocket.closeBeforeCleanup();

        expect(firstConfiguration.onTransportDone, returnsNormally);
        expect(transport.state, RealtimeConnectionState.disconnected);
        expect(firstSocket.unsubscribeAttempts, 2);

        firstConfiguration.onTransportError();
        firstConfiguration.onTransportDone();
        await _pumpEvents();

        expect(socketFactory.sockets, hasLength(2));
        expect(firstSocket.deactivateCalls, 1);
        socketFactory.configurations.last.onConnected();
        expect(transport.connectionEpoch, 2);
        expect(socketFactory.sockets.last.destinations, [
          '/user/queue/scheduled-care',
          '/user/queue/notifications',
        ]);

        firstConfiguration.onTransportDone();
        await _pumpEvents();
        expect(socketFactory.sockets, hasLength(2));
      },
    );

    test('dispose is idempotent and late callbacks never reconnect', () async {
      await transport.startSession(
        const RealtimeSessionOwner(userId: 'patient-a', role: 'PATIENT'),
      );
      final configuration = socketFactory.configurations.single;
      final socket = socketFactory.sockets.single;
      configuration.onConnected();
      socket.closeBeforeCleanup();

      await transport.dispose();
      await transport.dispose();
      configuration.onTransportDone();
      configuration.onTransportError();
      await _pumpEvents();

      expect(socket.deactivateCalls, 1);
      expect(socketFactory.sockets, hasLength(1));
      expect(transport.state, RealtimeConnectionState.disconnected);
    });

    test(
      'unexpected cleanup errors remain visible after reconnect is secured',
      () async {
        await transport.startSession(
          const RealtimeSessionOwner(userId: 'patient-a', role: 'PATIENT'),
        );
        final configuration = socketFactory.configurations.single;
        final socket = socketFactory.sockets.single;
        configuration.onConnected();
        socket.unsubscribeError = StateError('unexpected unsubscribe failure');

        expect(
          configuration.onTransportDone,
          throwsA(
            isA<StateError>().having(
              (error) => error.message,
              'message',
              'unexpected unsubscribe failure',
            ),
          ),
        );
        expect(transport.state, RealtimeConnectionState.disconnected);
        expect(socket.deactivated, isTrue);

        await _pumpEvents();
        expect(socketFactory.sockets, hasLength(2));
      },
    );

    test('STOMP authentication error disables automatic reconnect', () async {
      await transport.startSession(
        const RealtimeSessionOwner(userId: 'patient-a', role: 'PATIENT'),
      );
      final rejected = socketFactory.configurations.single;
      socketFactory.sockets.single.closeBeforeCleanup();
      rejected.onStompError();
      rejected.onTransportDone();
      await _pumpEvents();

      expect(transport.state, RealtimeConnectionState.authRejected);
      expect(socketFactory.sockets, hasLength(1));
      await transport.ensureConnected();
      expect(socketFactory.sockets, hasLength(1));
    });

    test(
      'a replaced credential may recover an auth-rejected connection',
      () async {
        await transport.startSession(
          const RealtimeSessionOwner(userId: 'patient-a', role: 'PATIENT'),
        );
        socketFactory.configurations.single.onStompError();
        await tokenStore.saveSession(_session(accessToken: 'access-two'));

        await transport.ensureConnected();

        expect(socketFactory.sockets, hasLength(2));
        expect(socketFactory.configurations.last.stompConnectHeaders, {
          'Authorization': 'Bearer access-two',
        });
        expect(transport.state, RealtimeConnectionState.connecting);
      },
    );

    test(
      'logout unsubscribes, disconnects, clears epoch, and ignores late data',
      () async {
        final messages = <String>[];
        transport.messages.listen(messages.add);
        await transport.startSession(
          const RealtimeSessionOwner(userId: 'patient-a', role: 'PATIENT'),
        );
        final configuration = socketFactory.configurations.single;
        final socket = socketFactory.sockets.single;
        configuration.onConnected();
        socket.emit('{}');
        await _pumpEvents();
        expect(messages, ['{}']);

        socket.closeBeforeCleanup();
        await transport.stopSession();
        socket.emit('{"late":true}');
        configuration.onTransportDone();
        await _pumpEvents();

        expect(socket.deactivated, isTrue);
        expect(socket.unsubscribed, isTrue);
        expect(socket.unsubscribeAttempts, 2);
        expect(transport.owner, isNull);
        expect(transport.connectionEpoch, 0);
        expect(messages, ['{}']);
        expect(socketFactory.sockets, hasLength(1));
      },
    );

    test(
      'token replacement tears down old socket and reconnects with current token',
      () async {
        await transport.startSession(
          const RealtimeSessionOwner(userId: 'patient-a', role: 'PATIENT'),
        );
        socketFactory.configurations.single.onConnected();
        socketFactory.sockets.single.closeBeforeCleanup();
        await tokenStore.saveSession(_session(accessToken: 'access-two'));

        await transport.ensureConnected();

        expect(socketFactory.sockets, hasLength(2));
        expect(socketFactory.sockets.first.deactivated, isTrue);
        expect(socketFactory.configurations.last.stompConnectHeaders, {
          'Authorization': 'Bearer access-two',
        });
      },
    );

    test(
      'session owner change destroys old connection before creating next',
      () async {
        final messages = <String>[];
        transport.messages.listen(messages.add);
        await transport.startSession(
          const RealtimeSessionOwner(userId: 'patient-a', role: 'PATIENT'),
        );
        socketFactory.configurations.single.onConnected();
        final oldSocket = socketFactory.sockets.single;
        oldSocket.closeBeforeCleanup();
        await tokenStore.saveSession(
          _session(
            accessToken: 'doctor-token',
            userId: 'doctor-a',
            role: 'DOCTOR',
          ),
        );

        await transport.startSession(
          const RealtimeSessionOwner(userId: 'doctor-a', role: 'DOCTOR'),
        );

        expect(oldSocket.deactivated, isTrue);
        expect(socketFactory.sockets, hasLength(2));
        expect(transport.owner?.userId, 'doctor-a');
        oldSocket.emit('{"owner":"patient-a"}');
        socketFactory.configurations.last.onConnected();
        socketFactory.sockets.last.emit('{"owner":"doctor-a"}');
        await _pumpEvents();
        expect(messages, ['{"owner":"doctor-a"}']);
      },
    );
  });

  group('event envelope', () {
    const knownTypes = <String, ScheduledCareEventType>{
      'BOOKING_REQUEST_CREATED': ScheduledCareEventType.bookingRequestCreated,
      'BOOKING_REQUEST_TIME_PROPOSED':
          ScheduledCareEventType.bookingRequestTimeProposed,
      'BOOKING_REQUEST_FULFILLED':
          ScheduledCareEventType.bookingRequestFulfilled,
      'BOOKING_REQUEST_CANCELLED':
          ScheduledCareEventType.bookingRequestCancelled,
      'BOOKING_REQUEST_EXPIRED': ScheduledCareEventType.bookingRequestExpired,
      'APPOINTMENT_CREATED': ScheduledCareEventType.appointmentCreated,
      'APPOINTMENT_CANCELLED': ScheduledCareEventType.appointmentCancelled,
      'APPOINTMENT_COMPLETED': ScheduledCareEventType.appointmentCompleted,
    };

    for (final entry in knownTypes.entries) {
      test('parses ${entry.key}', () {
        final resource = entry.key.startsWith('APPOINTMENT')
            ? 'APPOINTMENT'
            : 'BOOKING_REQUEST';
        final event = ScheduledCareInvalidationEvent.tryParse(
          _eventBody(eventType: entry.key, resourceType: resource, version: 42),
        );

        expect(event, isNotNull);
        expect(event!.type, entry.value);
        expect(event.eventId, 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
        expect(event.resourceId, _resourceIdFor(resource));
        expect(event.version, 42);
        expect(event.occurredAt, DateTime.utc(2026, 10, 12, 10, 30));
      });
    }

    test(
      'unknown future event type stays safe and preserves resource scope',
      () {
        final event = ScheduledCareInvalidationEvent.tryParse(
          _eventBody(eventType: 'BOOKING_REQUEST_REOPENED'),
        );
        expect(event?.type, ScheduledCareEventType.unknown);
        expect(event?.rawEventType, 'BOOKING_REQUEST_REOPENED');
        expect(event?.resourceType, ScheduledCareResourceType.bookingRequest);
      },
    );

    test('malformed payloads are ignored safely', () {
      for (final body in <String>[
        'not json',
        '[]',
        '{}',
        _eventBody(eventId: 'not-a-uuid'),
        _eventBody(resourceId: 'not-a-uuid'),
        _eventBody(resourceType: 'PATIENT'),
        _eventBody(version: -1),
        _eventBody(occurredAt: 'yesterday'),
      ]) {
        expect(ScheduledCareInvalidationEvent.tryParse(body), isNull);
      }
    });
  });

  group('bounded event dedupe', () {
    test('same event is accepted once and different IDs are accepted', () {
      final deduper = RecentEventDeduper(capacity: 2);
      expect(deduper.accept('a'), isTrue);
      expect(deduper.accept('a'), isFalse);
      expect(deduper.accept('b'), isTrue);
    });

    test('oldest ID is accepted again after bounded eviction', () {
      final deduper = RecentEventDeduper(capacity: 2);
      expect(deduper.accept('a'), isTrue);
      expect(deduper.accept('b'), isTrue);
      expect(deduper.accept('c'), isTrue);
      expect(deduper.length, 2);
      expect(deduper.accept('a'), isTrue);
    });

    test('clear removes session history', () {
      final deduper = RecentEventDeduper();
      expect(deduper.accept('a'), isTrue);
      deduper.clear();
      expect(deduper.accept('a'), isTrue);
    });
  });

  group('refresh coalescing', () {
    test(
      'in-flight invalidations produce exactly one eventual follow-up',
      () async {
        final coalescer = CoalescedRefresh();
        final gates = <Completer<void>>[];
        var calls = 0;
        Future<void> refresh() {
          calls++;
          final gate = Completer<void>();
          gates.add(gate);
          return gate.future;
        }

        final first = coalescer.request(refresh);
        coalescer.request(refresh);
        coalescer.request(refresh);
        expect(calls, 1);
        gates.first.complete();
        await _pumpEvents();
        expect(calls, 2);
        gates.last.complete();
        await first;
        expect(calls, 2);
      },
    );

    test('busy controller defers one refresh until it becomes idle', () async {
      final projection = _Projection(active: true, loaded: true)..busy = true;
      final binding = _binding(projection);
      binding.activate();

      await binding.invalidate();
      await binding.invalidate();
      expect(projection.refreshes, 0);
      projection.busy = false;
      projection.notify();
      await _pumpEvents();
      expect(projection.refreshes, 1);
      binding.dispose();
    });
  });

  group('coordinator and mappings', () {
    late _FakeTransport transport;
    late ScheduledCareRealtimeCoordinator coordinator;

    setUp(() {
      transport = _FakeTransport();
      coordinator = ScheduledCareRealtimeCoordinator(transport: transport);
    });

    tearDown(() => coordinator.dispose());

    test('dedupes events, scopes roles, and clears dedupe on logout', () async {
      final patient = _FakeTarget('PATIENT');
      final doctor = _FakeTarget('DOCTOR');
      coordinator.registerTarget(patient);
      coordinator.registerTarget(doctor);
      await coordinator.startSession(
        const RealtimeSessionOwner(userId: 'patient-a', role: 'PATIENT'),
      );

      final body = _eventBody();
      transport.emit(body);
      transport.emit(body);
      await _pumpEvents();
      expect(patient.invalidations, 1);
      expect(doctor.invalidations, 0);

      await coordinator.stopSession();
      transport.emit(
        _eventBody(eventId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb'),
      );
      await _pumpEvents();
      expect(patient.invalidations, 1);

      await coordinator.startSession(
        const RealtimeSessionOwner(userId: 'patient-a', role: 'PATIENT'),
      );
      transport.emit(body);
      await _pumpEvents();
      expect(patient.invalidations, 2);
    });

    test('role switch deactivates patient and activates doctor only', () async {
      final patient = _FakeTarget('PATIENT');
      final doctor = _FakeTarget('DOCTOR');
      coordinator.registerTarget(patient);
      coordinator.registerTarget(doctor);
      await coordinator.startSession(
        const RealtimeSessionOwner(userId: 'patient-a', role: 'PATIENT'),
      );
      expect(patient.active, isTrue);
      expect(doctor.active, isFalse);

      await coordinator.startSession(
        const RealtimeSessionOwner(userId: 'doctor-a', role: 'DOCTOR'),
      );
      expect(patient.active, isFalse);
      expect(doctor.active, isTrue);
    });

    test(
      'each connection epoch resyncs active projections without an event',
      () async {
        final patient = _FakeTarget('PATIENT');
        coordinator.registerTarget(patient);
        await coordinator.startSession(
          const RealtimeSessionOwner(userId: 'patient-a', role: 'PATIENT'),
        );

        transport.connect();
        await _pumpEvents();
        transport.connect();
        await _pumpEvents();

        expect(patient.resyncs, 2);
        expect(patient.invalidations, 0);
      },
    );

    test(
      'foreground ensures connection then performs one bounded REST resync',
      () async {
        final patient = _FakeTarget('PATIENT');
        coordinator.registerTarget(patient);
        await coordinator.startSession(
          const RealtimeSessionOwner(userId: 'patient-a', role: 'PATIENT'),
        );

        await coordinator.foregroundResync();

        expect(transport.ensureCalls, 1);
        expect(patient.resyncs, 1);
      },
    );

    test(
      'doctor foreground resync replaces a stale startable Home projection',
      () async {
        final home = _Projection(active: true, loaded: true)
          ..uiState = 'FINISHED_SOURCE_CONFIRMED'
          ..serverState = 'FINISHED_SOURCE_ABSENT';
        final target = DoctorScheduledCareRealtimeTarget.bindings(
          requestId: () => null,
          appointmentId: () => null,
          home: _binding(home),
          request: _binding(_Projection()),
          agenda: _binding(_Projection()),
          appointment: _binding(_Projection()),
        );
        coordinator.registerTarget(target);
        await coordinator.startSession(
          const RealtimeSessionOwner(userId: 'doctor-a', role: 'DOCTOR'),
        );

        await coordinator.foregroundResync();

        expect(transport.ensureCalls, 1);
        expect(home.refreshes, 1);
        expect(home.uiState, 'FINISHED_SOURCE_ABSENT');
      },
    );

    test(
      'patient mapping refreshes only active list and matching detail via REST',
      () async {
        final request = _Projection(active: true, loaded: true);
        final appointment = _Projection(active: true, loaded: true);
        final list = _Projection(active: true, loaded: true);
        final target = PatientScheduledCareRealtimeTarget.bindings(
          requestId: () => _requestId,
          appointmentId: () => _appointmentId,
          request: _binding(request),
          appointment: _binding(appointment),
          list: _binding(list),
        )..activate();

        await target.invalidate(_parsedEvent(resourceType: 'BOOKING_REQUEST'));
        expect(request.refreshes, 1);
        expect(appointment.refreshes, 0);
        expect(list.refreshes, 1);

        await target.invalidate(
          _parsedEvent(
            eventId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
            resourceType: 'APPOINTMENT',
          ),
        );
        expect(appointment.refreshes, 1);
        expect(list.refreshes, 2);

        appointment.serverState = 'COMPLETED';
        list.serverState = 'UPCOMING_EMPTY';
        await target.invalidate(
          _parsedEvent(
            eventId: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
            eventType: 'APPOINTMENT_COMPLETED',
            resourceType: 'APPOINTMENT',
          ),
        );
        expect(appointment.refreshes, 2);
        expect(appointment.uiState, 'COMPLETED');
        expect(list.refreshes, 3);
        expect(list.uiState, 'UPCOMING_EMPTY');
        target.dispose();
      },
    );

    test(
      'patient foreground and reconnect refetch completed Appointment authority',
      () async {
        final list = _Projection(active: true, loaded: true)
          ..uiState = 'UPCOMING_CONFIRMED'
          ..serverState = 'UPCOMING_EMPTY';
        final appointment = _Projection(active: true, loaded: true)
          ..uiState = 'CONFIRMED'
          ..serverState = 'COMPLETED';
        final target = PatientScheduledCareRealtimeTarget.bindings(
          requestId: () => null,
          appointmentId: () => _appointmentId,
          request: _binding(_Projection()),
          appointment: _binding(appointment),
          list: _binding(list),
        );
        coordinator.registerTarget(target);
        await coordinator.startSession(
          const RealtimeSessionOwner(userId: 'patient-a', role: 'PATIENT'),
        );

        await coordinator.foregroundResync();
        expect(list.uiState, 'UPCOMING_EMPTY');
        expect(appointment.uiState, 'COMPLETED');

        list.uiState = 'STALE_UPCOMING_CONFIRMED';
        appointment.uiState = 'STALE_CONFIRMED';
        transport.connect();
        await _pumpEvents();

        expect(list.uiState, 'UPCOMING_EMPTY');
        expect(appointment.uiState, 'COMPLETED');
        expect(list.refreshes, 2);
        expect(appointment.refreshes, 2);
      },
    );

    test(
      'patient event type never invents state; refresh applies REST result',
      () async {
        final request = _Projection(active: true, loaded: true)
          ..serverState = 'PENDING_PATIENT_TIME_CONFIRMATION';
        final target = PatientScheduledCareRealtimeTarget.bindings(
          requestId: () => _requestId,
          appointmentId: () => null,
          request: _binding(request),
          appointment: _binding(_Projection()),
          list: _binding(_Projection()),
        )..activate();

        await target.invalidate(
          _parsedEvent(eventType: 'BOOKING_REQUEST_CANCELLED'),
        );
        expect(request.uiState, 'PENDING_PATIENT_TIME_CONFIRMATION');

        request.serverState = 'FULFILLED';
        await target.invalidate(
          _parsedEvent(
            eventId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
            eventType: 'BOOKING_REQUEST_TIME_PROPOSED',
          ),
        );
        expect(request.uiState, 'FULFILLED');
        target.dispose();
      },
    );

    test('inactive patient projections do not fetch', () async {
      final list = _Projection(active: false, loaded: true);
      final target = PatientScheduledCareRealtimeTarget.bindings(
        requestId: () => null,
        appointmentId: () => null,
        request: _binding(_Projection()),
        appointment: _binding(_Projection()),
        list: _binding(list),
      )..activate();
      await target.invalidate(_parsedEvent());
      expect(list.refreshes, 0);
      target.dispose();
    });

    test(
      'doctor mapping refreshes Home, visible Agenda, and matching details',
      () async {
        final home = _Projection(active: true, loaded: true);
        final request = _Projection(active: true, loaded: true);
        final agenda = _Projection(active: true, loaded: true);
        final appointment = _Projection(active: true, loaded: true);
        final target = DoctorScheduledCareRealtimeTarget.bindings(
          requestId: () => _requestId,
          appointmentId: () => _appointmentId,
          home: _binding(home),
          request: _binding(request),
          agenda: _binding(agenda),
          appointment: _binding(appointment),
        )..activate();

        await target.invalidate(_parsedEvent(resourceType: 'BOOKING_REQUEST'));
        expect(home.refreshes, 1);
        expect(agenda.refreshes, 1);
        expect(request.refreshes, 1);
        expect(appointment.refreshes, 0);

        await target.invalidate(
          _parsedEvent(
            eventId: 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
            resourceType: 'APPOINTMENT',
          ),
        );
        expect(home.refreshes, 2);
        expect(agenda.refreshes, 2);
        expect(appointment.refreshes, 1);

        await target.invalidate(
          _parsedEvent(
            eventId: 'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
            eventType: 'CONSULTATION_COMPLETED',
            resourceType: 'CONSULTATION',
          ),
        );
        expect(home.refreshes, 3);
        expect(agenda.refreshes, 3);
        expect(appointment.refreshes, 2);
        expect(request.refreshes, 1);
        target.dispose();
      },
    );
  });
}

StoredSession _session({
  required String accessToken,
  String userId = 'patient-a',
  String role = 'PATIENT',
}) => StoredSession(
  accessToken: accessToken,
  refreshToken: 'refresh-token',
  accessTokenExpiresAt: DateTime.utc(2030),
  refreshTokenExpiresAt: DateTime.utc(2031),
  userId: userId,
  userRole: role,
  sessionId: '$userId-session',
);

String _eventBody({
  String eventId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  String eventType = 'BOOKING_REQUEST_CREATED',
  String resourceType = 'BOOKING_REQUEST',
  String? resourceId,
  int version = 7,
  String occurredAt = '2026-10-12T10:30:00Z',
}) => jsonEncode({
  'eventId': eventId,
  'eventType': eventType,
  'resourceType': resourceType,
  'resourceId': resourceId ?? _resourceIdFor(resourceType),
  'version': version,
  'occurredAt': occurredAt,
});

String _resourceIdFor(String resourceType) =>
    resourceType == 'APPOINTMENT' ? _appointmentId : _requestId;

ScheduledCareInvalidationEvent _parsedEvent({
  String eventId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  String eventType = 'BOOKING_REQUEST_CREATED',
  String resourceType = 'BOOKING_REQUEST',
}) => ScheduledCareInvalidationEvent.tryParse(
  _eventBody(
    eventId: eventId,
    eventType: eventType,
    resourceType: resourceType,
  ),
)!;

Future<void> _pumpEvents() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

class _MemoryTokenBackend implements SecureTokenStorageBackend {
  final Map<String, String> values = <String, String>{};

  @override
  Future<void> delete({required String key}) async => values.remove(key);

  @override
  Future<String?> read({required String key}) async => values[key];

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }
}

class _FakeSocketFactory implements RealtimeSocketFactory {
  final List<RealtimeSocketConfiguration> configurations = [];
  final List<_FakeSocket> sockets = [];

  @override
  RealtimeSocket create(RealtimeSocketConfiguration configuration) {
    configurations.add(configuration);
    final socket = _FakeSocket();
    sockets.add(socket);
    return socket;
  }
}

class _FakeSocket implements RealtimeSocket {
  bool activated = false;
  bool deactivated = false;
  bool unsubscribed = false;
  bool closed = false;
  bool throwDisconnectedOnUnsubscribe = false;
  Object? unsubscribeError;
  int unsubscribeAttempts = 0;
  int deactivateCalls = 0;
  final Map<String, RealtimeMessageCallback> callbacks = {};
  final List<String> destinations = [];

  @override
  bool get isActive => activated && !deactivated;

  @override
  void activate() => activated = true;

  @override
  void deactivate() {
    deactivateCalls++;
    deactivated = true;
    closed = true;
  }

  @override
  void Function() subscribe({
    required String destination,
    required RealtimeMessageCallback onMessage,
  }) {
    destinations.add(destination);
    callbacks[destination] = onMessage;
    return () {
      unsubscribeAttempts++;
      unsubscribed = true;
      final error = unsubscribeError;
      if (error != null) throw error;
      if (closed && throwDisconnectedOnUnsubscribe) {
        throw StompBadStateException(
          'The StompHandler has no active connection '
          'or the connection was unexpectedly closed.',
        );
      }
    };
  }

  void closeBeforeCleanup() {
    closed = true;
    throwDisconnectedOnUnsubscribe = true;
  }

  void emit(String body) =>
      callbacks[AuthenticatedRealtimeTransport.privateDestination]?.call(body);

  void emitNotification(String body) =>
      callbacks[AuthenticatedRealtimeTransport.notificationDestination]?.call(
        body,
      );
}

class _FakeTransport implements ScheduledCareRealtimeTransport {
  final StreamController<String> _messages = StreamController.broadcast();
  final StreamController<String> _notificationMessages =
      StreamController.broadcast();
  final StreamController<int> _epochs = StreamController.broadcast();
  RealtimeSessionOwner? _owner;
  int _epoch = 0;
  int ensureCalls = 0;

  @override
  int get connectionEpoch => _epoch;

  @override
  Stream<int> get connectedEpochs => _epochs.stream;

  @override
  Stream<String> get messages => _messages.stream;

  @override
  Stream<String> get notificationMessages => _notificationMessages.stream;

  @override
  RealtimeSessionOwner? get owner => _owner;

  @override
  RealtimeConnectionState get state => _owner == null
      ? RealtimeConnectionState.disconnected
      : RealtimeConnectionState.connected;

  @override
  Future<void> ensureConnected() async => ensureCalls++;

  @override
  Future<void> startSession(RealtimeSessionOwner owner) async => _owner = owner;

  @override
  Future<void> stopSession() async {
    _owner = null;
    _epoch = 0;
  }

  void emit(String body) => _messages.add(body);

  void emitNotification(String body) => _notificationMessages.add(body);

  void connect() => _epochs.add(++_epoch);
}

class _FakeTarget implements ScheduledCareRealtimeTarget {
  _FakeTarget(this.role);

  @override
  final String role;
  bool active = false;
  int invalidations = 0;
  int resyncs = 0;

  @override
  void activate() => active = true;

  @override
  void deactivate() => active = false;

  @override
  void dispose() => active = false;

  @override
  Future<void> invalidate(ScheduledCareInvalidationEvent event) async {
    invalidations++;
  }

  @override
  Future<void> resync() async => resyncs++;
}

class _Projection extends ChangeNotifier {
  _Projection({this.active = false, this.loaded = false});

  bool active;
  bool loaded;
  bool busy = false;
  int refreshes = 0;
  String? serverState;
  String? uiState;

  Future<void> refresh() async {
    refreshes++;
    uiState = serverState;
  }

  void notify() => notifyListeners();
}

ScheduledCareRefreshBinding _binding(_Projection projection) =>
    ScheduledCareRefreshBinding(
      listenable: projection,
      shouldRefresh: () => projection.active && projection.loaded,
      isBusy: () => projection.busy,
      refresh: projection.refresh,
    );
