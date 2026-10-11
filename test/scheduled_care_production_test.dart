import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/core/network/app_http_client.dart';
import 'package:omnicare_mobile/core/storage/secure_token_store.dart';
import 'package:omnicare_mobile/features/patient_doctor/data/doctor_detail_models.dart';
import 'package:omnicare_mobile/features/patient_doctor/data/doctor_models.dart';
import 'package:omnicare_mobile/features/patient_doctor/presentation/doctor_availability_sheet.dart';
import 'package:omnicare_mobile/features/scheduled_care/application/scheduled_care_controller.dart';
import 'package:omnicare_mobile/features/scheduled_care/data/scheduled_care_api.dart';
import 'package:omnicare_mobile/features/scheduled_care/data/scheduled_care_failure.dart';
import 'package:omnicare_mobile/features/scheduled_care/data/scheduled_care_repository.dart';
import 'package:omnicare_mobile/features/scheduled_care/domain/scheduled_care_models.dart';
import 'package:omnicare_mobile/features/scheduled_care/realtime/scheduled_care_realtime.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:stomp_dart_client/stomp_dart_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(tz.initializeTimeZones);

  test(
    'availability sends doctor, exact cabinet and bounded UTC window',
    () async {
      final adapter = _RecordingAdapter(_availabilityJson);
      final api = ScheduledCareApi(_client(adapter));

      final result = await api.getAvailability(
        doctorId: 'doctor-1',
        practiceLocationId: 'cabinet-7',
        from: DateTime.parse('2026-10-08T08:00:00Z'),
        to: DateTime.parse('2026-11-08T08:00:00Z'),
      );

      expect(adapter.path, '/api/v1/appointments/availability/slots');
      expect(adapter.query['doctorId'], 'doctor-1');
      expect(adapter.query['practiceLocationId'], 'cabinet-7');
      expect(adapter.query['from'], '2026-10-08T08:00:00.000Z');
      expect(result.practiceLocationId, 'cabinet-7');
      expect(result.slots.single.start, DateTime.parse('2026-10-10T09:00:00Z'));
    },
  );

  test(
    'create request preserves subject, cabinet and exact slot instants',
    () async {
      final adapter = _RecordingAdapter(_requestJson, statusCode: 201);
      final api = ScheduledCareApi(_client(adapter));
      final slot = ScheduledCareSlot(
        start: DateTime.parse('2026-10-10T09:00:00Z'),
        end: DateTime.parse('2026-10-10T09:30:00Z'),
      );

      await api.createRequest(
        requestId: _requestId,
        doctorId: 'doctor-1',
        practiceLocationId: 'cabinet-7',
        subject: const CareSubject(
          type: CareSubjectType.familyMember,
          familyMemberId: 'family-9',
          displayName: 'Aicha',
          relationship: 'Mère',
        ),
        slot: slot,
      );

      expect(adapter.path, '/api/v1/doctor-booking-requests');
      final body = adapter.body as Map<String, dynamic>;
      expect(body['requestId'], _requestId);
      expect(body['practiceLocationId'], 'cabinet-7');
      expect(body['subject'], {
        'subjectType': 'FAMILY_MEMBER',
        'familyMemberId': 'family-9',
      });
      expect(
        (body['requestedSlot'] as Map)['start'],
        '2026-10-10T09:00:00.000Z',
      );
    },
  );

  test('SELF create payload never sends a family member identifier', () {
    const subject = CareSubject(
      type: CareSubjectType.self,
      displayName: 'Moi',
      relationship: 'Moi-même',
    );

    expect(subject.toCreateJson(), {'subjectType': 'SELF'});
  });

  test('HTTP 200 create replay is accepted as authoritative success', () async {
    final adapter = _RecordingAdapter({..._requestJson, 'version': 4});
    final result = await ScheduledCareApi(_client(adapter)).createRequest(
      requestId: _requestId,
      doctorId: 'doctor-1',
      practiceLocationId: 'cabinet-7',
      subject: const CareSubject(
        type: CareSubjectType.self,
        displayName: 'Moi',
        relationship: 'Moi-même',
      ),
      slot: ScheduledCareSlot.fromJson(
        _requestJson['originalRequestedSlot']! as Map<String, dynamic>,
      ),
    );

    expect(result.requestId, _requestId);
    expect(result.version, 4);
    expect(result.status, 'PENDING_DOCTOR');
  });

  test(
    'request and appointment lifecycle statuses parse without conflation',
    () {
      for (final status in const [
        'PENDING_DOCTOR',
        'PENDING_PATIENT_TIME_CONFIRMATION',
        'FULFILLED',
        'CANCELLED_BY_PATIENT',
        'CANCELLED_BY_DOCTOR',
        'EXPIRED',
      ]) {
        final json = Map<String, dynamic>.from(_requestJson)
          ..['status'] = status
          ..['availableActions'] = <String>[];
        expect(PatientBookingRequest.fromJson(json).status, status);
      }
      for (final status in const [
        'CONFIRMED',
        'IN_PROGRESS',
        'CANCELLED',
        'COMPLETED',
        'NO_SHOW',
      ]) {
        final json = Map<String, dynamic>.from(_appointmentJson)
          ..['status'] = status
          ..['availableActions'] = <String>[];
        expect(ConfirmedScheduledAppointment.fromJson(json).status, status);
      }
      expect(
        () => ScheduledCareResourceType.parse('FUTURE_RESOURCE'),
        throwsFormatException,
      );
    },
  );

  test('RFC 9457 errorCode and uncertain command outcomes are classified', () {
    final conflict = ScheduledCareFailure.from(
      DioException(
        requestOptions: RequestOptions(path: '/command'),
        response: Response<dynamic>(
          requestOptions: RequestOptions(path: '/command'),
          statusCode: 409,
          data: {
            'type': 'https://api.omnicare.tn/problems/version-conflict',
            'title': 'Conflict',
            'detail': 'SQL constraint booking_request_version_idx failed.',
            'errorCode': 'VERSION_CONFLICT',
          },
        ),
      ),
      command: true,
    );
    final timeout = ScheduledCareFailure.from(
      DioException(
        requestOptions: RequestOptions(path: '/command'),
        type: DioExceptionType.receiveTimeout,
      ),
      command: true,
    );

    expect(conflict.errorCode, 'VERSION_CONFLICT');
    expect(conflict.versionConflict, isTrue);
    expect(conflict.message, isNot(contains('SQL')));
    expect(timeout.unknownOutcome, isTrue);
  });

  test(
    'scheduled-care list keeps request and appointment identities distinct',
    () async {
      final adapter = _RecordingAdapter({
        'items': [
          {
            'resourceType': 'BOOKING_REQUEST',
            'requestId': _requestId,
            'appointmentId': null,
            'sourceBookingRequestId': null,
            'version': 3,
            'status': 'PENDING_DOCTOR',
            'doctor': {'displayName': 'Dr. Test', 'specialty': 'Cardiologie'},
            'subject': {
              'subjectType': 'SELF',
              'displayName': 'Moi',
              'relationship': 'Moi-même',
            },
            'cabinet': {
              'name': 'Cabinet Lac',
              'address': 'Rue 1',
              'city': 'Tunis',
              'governorate': 'Tunis',
              'timezone': 'Africa/Tunis',
            },
            'start': '2026-10-10T09:00:00Z',
            'end': '2026-10-10T09:30:00Z',
            'timezone': 'Africa/Tunis',
            'responseDeadline': '2026-10-09T08:00:00Z',
            'cancellation': null,
            'intakeStatus': null,
            'availableActions': ['CANCEL_REQUEST'],
            'sortAt': '2026-10-10T09:00:00Z',
            'updatedAt': '2026-10-08T08:00:00Z',
          },
        ],
        'nextCursor': 'opaque-cursor',
      });
      final api = ScheduledCareApi(_client(adapter));

      final page = await api.list(
        bucket: ScheduledCareBucket.upcoming,
        query: 'cardio',
        subjectType: CareSubjectType.self,
        city: 'Tunis',
      );

      expect(adapter.path, '/api/v1/patient/scheduled-care');
      expect(adapter.query['bucket'], 'UPCOMING');
      expect(adapter.query['query'], 'cardio');
      expect(page.nextCursor, 'opaque-cursor');
      expect(page.items.single.requestId, _requestId);
      expect(page.items.single.appointmentId, isNull);
      expect(page.items.single.resourceId, _requestId);
    },
  );

  test(
    'proposal accept is versioned, idempotent and returns appointment',
    () async {
      final adapter = _RecordingAdapter({
        'request': {
          ..._requestJson,
          'version': 2,
          'status': 'FULFILLED',
          'confirmedAppointmentId': _appointmentId,
          'availableActions': <String>[],
        },
        'appointment': _appointmentJson,
      });
      final api = ScheduledCareApi(_client(adapter));

      final result = await api.acceptProposal(
        requestId: _requestId,
        proposalId: '00000000-0000-4000-8000-000000000002',
        expectedVersion: 1,
        idempotencyKey: 'operation-key',
      );

      expect(
        adapter.path,
        '/api/v1/doctor-booking-requests/$_requestId/proposals/'
        '00000000-0000-4000-8000-000000000002/accept',
      );
      expect(adapter.headers['Idempotency-Key'], 'operation-key');
      expect(adapter.body, {'expectedVersion': 1});
      expect(result.appointment.appointmentId, _appointmentId);
      expect(result.appointment.sourceBookingRequestId, _requestId);
    },
  );

  test(
    'proposal decline uses request/proposal ids, version and command key',
    () async {
      final adapter = _RecordingAdapter({
        ..._requestJson,
        'version': 2,
        'status': 'CANCELLED_BY_PATIENT',
        'availableActions': <String>[],
      });
      final api = ScheduledCareApi(_client(adapter));

      final result = await api.declineProposal(
        requestId: _requestId,
        proposalId: '00000000-0000-4000-8000-000000000002',
        expectedVersion: 1,
        reasonCode: 'PROPOSAL_DECLINED',
        idempotencyKey: 'decline-key',
      );

      expect(
        adapter.path,
        '/api/v1/doctor-booking-requests/$_requestId/proposals/'
        '00000000-0000-4000-8000-000000000002/decline',
      );
      expect(adapter.headers['Idempotency-Key'], 'decline-key');
      expect(adapter.body, {
        'expectedVersion': 1,
        'reasonCode': 'PROPOSAL_DECLINED',
      });
      expect(result.status, 'CANCELLED_BY_PATIENT');
    },
  );

  test(
    'pending request cancellation uses versioned POST and command key',
    () async {
      final adapter = _RecordingAdapter({
        ..._requestJson,
        'version': 2,
        'status': 'CANCELLED_BY_PATIENT',
        'availableActions': <String>[],
      });
      final api = ScheduledCareApi(_client(adapter));

      await api.cancelRequest(
        requestId: _requestId,
        expectedVersion: 1,
        reasonCode: 'CHANGE_OF_PLANS',
        idempotencyKey: 'cancel-request-key',
      );

      expect(
        adapter.path,
        '/api/v1/doctor-booking-requests/$_requestId/cancel',
      );
      expect(adapter.headers['Idempotency-Key'], 'cancel-request-key');
      expect(adapter.body, {
        'expectedVersion': 1,
        'reasonCode': 'CHANGE_OF_PLANS',
      });
    },
  );

  test(
    'P2 appointment cancellation uses POST cancel, version and key',
    () async {
      final adapter = _RecordingAdapter({
        ..._appointmentJson,
        'version': 5,
        'status': 'CANCELLED',
        'availableActions': <String>[],
        'cancellation': {
          'actor': 'PATIENT',
          'reasonCode': 'NO_LONGER_NEEDED',
          'cancelledAt': '2026-10-08T10:00:00Z',
          'lateCancellation': false,
        },
      });
      final api = ScheduledCareApi(_client(adapter));

      final result = await api.cancelAppointment(
        appointmentId: _appointmentId,
        expectedVersion: 4,
        reasonCode: 'NO_LONGER_NEEDED',
        idempotencyKey: 'cancel-key',
      );

      expect(adapter.path, '/api/v1/appointments/$_appointmentId/cancel');
      expect(adapter.headers['Idempotency-Key'], 'cancel-key');
      expect(adapter.body, {
        'expectedVersion': 4,
        'reasonCode': 'NO_LONGER_NEEDED',
      });
      expect(result.version, 5);
    },
  );

  test(
    'unknown create outcome retries with the same client request UUID',
    () async {
      final repository = _FakeRepository()..failFirstCreate = true;
      var uuidCalls = 0;
      final controller = ScheduledCareController(
        repository: repository,
        uuidFactory: () {
          uuidCalls++;
          return _requestId;
        },
      );
      controller.selectFamilyMember(
        familyMemberId: 'family-9',
        displayName: 'Aicha',
        relationshipLabel: 'Mère',
      );
      controller.selectDoctorAndCabinet(
        doctorId: 'doctor-1',
        doctorName: 'Dr. Test',
        doctorSpecialty: 'Cardiologie',
        cabinet: const ScheduledCareCabinet(
          practiceLocationId: 'cabinet-7',
          name: 'Cabinet Lac',
          address: 'Rue 1',
          city: 'Tunis',
        ),
      );
      await controller.loadAvailability();
      controller.selectSlot(repository.window.slots.single);

      expect(await controller.submitDraft(), isNull);
      expect(await controller.submitDraft(), isNotNull);
      expect(repository.createIds, [_requestId, _requestId]);
      expect(uuidCalls, 1);
      controller.dispose();
    },
  );

  test(
    'availability refresh removes a selected slot that disappeared',
    () async {
      final repository = _FakeRepository();
      final controller = ScheduledCareController(repository: repository);
      controller.selectSelf(displayName: 'Moi');
      controller.selectDoctorAndCabinet(
        doctorId: 'doctor-1',
        doctorName: 'Dr. Test',
        doctorSpecialty: 'Cardiologie',
        cabinet: const ScheduledCareCabinet(
          practiceLocationId: 'cabinet-7',
          name: 'Cabinet Lac',
          address: 'Rue 1',
          city: 'Tunis',
        ),
      );
      await controller.loadAvailability();
      controller.selectSlot(repository.window.slots.single);
      expect(controller.draft.slot, isNotNull);

      repository.window = AvailabilityWindow.fromJson({
        ..._availabilityJson,
        'slots': <Object>[],
      });
      await controller.loadAvailability();

      expect(controller.draft.slot, isNull);
      controller.dispose();
    },
  );

  test(
    'controller requests only the current displayed month within 31 days',
    () async {
      final repository = _FakeRepository();
      final controller = ScheduledCareController(
        repository: repository,
        clock: () => DateTime.parse('2026-10-08T22:26:42Z'),
      );
      controller.selectDoctorAndCabinet(
        doctorId: 'doctor-1',
        doctorName: 'Dr. Test',
        doctorSpecialty: 'Cardiologie',
        cabinet: const ScheduledCareCabinet(
          practiceLocationId: 'cabinet-7',
          name: 'Cabinet Lac',
          address: 'Rue 1',
          city: 'Tunis',
          timezone: 'Africa/Tunis',
        ),
      );

      await controller.loadAvailability(month: DateTime(2026, 10));

      expect(
        repository.lastAvailabilityFrom,
        DateTime.parse('2026-10-08T22:26:42Z'),
      );
      expect(
        repository.lastAvailabilityTo,
        DateTime.parse('2026-10-31T23:00:00Z'),
      );
      expect(
        repository.lastAvailabilityTo!.difference(
          repository.lastAvailabilityFrom!,
        ),
        lessThanOrEqualTo(const Duration(days: 31)),
      );
      controller.dispose();
    },
  );

  test(
    'controller month navigation replaces the query with the requested month',
    () async {
      final repository = _FakeRepository();
      final controller = ScheduledCareController(
        repository: repository,
        clock: () => DateTime.parse('2026-10-08T22:26:42Z'),
      );
      controller.selectDoctorAndCabinet(
        doctorId: 'doctor-1',
        doctorName: 'Dr. Test',
        doctorSpecialty: 'Cardiologie',
        cabinet: const ScheduledCareCabinet(
          practiceLocationId: 'cabinet-7',
          name: 'Cabinet Lac',
          address: 'Rue 1',
          city: 'Tunis',
          timezone: 'Africa/Tunis',
        ),
      );

      await controller.loadAvailability(month: DateTime(2026, 11));

      expect(
        repository.lastAvailabilityFrom,
        DateTime.parse('2026-10-31T23:00:00Z'),
      );
      expect(
        repository.lastAvailabilityTo,
        DateTime.parse('2026-11-30T23:00:00Z'),
      );
      controller.dispose();
    },
  );

  testWidgets(
    'availability sheet defers its initial notification and renders only authoritative dates',
    (tester) async {
      final repository = _FakeRepository()
        ..window = AvailabilityWindow.fromJson({
          ..._availabilityJson,
          'slots': [
            {
              'start': '2026-10-12T08:00:00Z',
              'end': '2026-10-12T08:20:00Z',
              'timezone': 'Africa/Tunis',
              'durationMinutes': 20,
            },
          ],
        });
      final controller = ScheduledCareController(
        repository: repository,
        clock: () => DateTime.parse('2026-10-08T22:26:42Z'),
      );
      controller.selectDoctorAndCabinet(
        doctorId: 'doctor-1',
        doctorName: 'Dr. Test',
        doctorSpecialty: 'Cardiologie',
        cabinet: const ScheduledCareCabinet(
          practiceLocationId: 'cabinet-7',
          name: 'Cabinet Lac',
          address: 'Rue 1',
          city: 'Tunis',
          timezone: 'Africa/Tunis',
        ),
      );
      addTearDown(controller.dispose);
      final reportedErrors = <FlutterErrorDetails>[];
      final previousHandler = FlutterError.onError;
      FlutterError.onError = reportedErrors.add;
      addTearDown(() => FlutterError.onError = previousHandler);

      await tester.pumpWidget(
        MaterialApp(
          home: DoctorAvailabilitySheet(
            detail: const DoctorDetail(
              listItem: DoctorListItem(
                id: 'doctor-1',
                name: 'Dr. Test',
                specialty: 'Cardiologie',
              ),
            ),
            cabinet: const ScheduledCareCabinet(
              practiceLocationId: 'cabinet-7',
              name: 'Cabinet Lac',
              address: 'Rue 1',
              city: 'Tunis',
              timezone: 'Africa/Tunis',
            ),
            scheduledCareController: controller,
          ),
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      expect(
        reportedErrors.where(
          (error) => error.exceptionAsString().contains(
            'markNeedsBuild() called during build',
          ),
        ),
        isEmpty,
      );
      expect(
        find.byKey(const ValueKey('availability-day-2026-10-12')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('availability-day-2026-10-09')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('availability-day-2026-10-10')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('availability-day-2026-10-11')),
        findsNothing,
      );
    },
  );

  test(
    'realtime authenticates in STOMP CONNECT and subscribes to the private queue',
    () async {
      final backend = _MemoryBackend();
      final tokenStore = SecureTokenStore(backend: backend);
      await tokenStore.saveSession(_storedSession());
      late _FakeStompClient stomp;
      var connectedCallbacks = 0;
      final realtime = StompScheduledCareRealtime(
        tokenStore: tokenStore,
        clientFactory: (config) => stomp = _FakeStompClient(config),
      );

      await realtime.connect((_) {}, onConnected: () => connectedCallbacks++);
      await stomp.config.beforeConnect();

      expect(stomp.config.useSockJS, isTrue);
      expect(stomp.config.url, endsWith('/api/v1/ws'));
      expect(stomp.config.webSocketConnectHeaders, isNull);
      expect(stomp.config.stompConnectHeaders, {
        'Authorization': 'Bearer access-token',
      });
      stomp.config.onConnect(StompFrame(command: 'CONNECTED'));
      expect(stomp.subscribedDestinations, [
        '/user/queue/scheduled-care',
        '/user/queue/notifications',
      ]);
      expect(realtime.isConnected, isTrue);
      expect(connectedCallbacks, 1);
    },
  );

  test(
    'STOMP authentication rejection stops reconnect without domain mutation',
    () async {
      final backend = _MemoryBackend();
      final tokenStore = SecureTokenStore(backend: backend);
      await tokenStore.saveSession(_storedSession());
      late _FakeStompClient stomp;
      var domainEvents = 0;
      final realtime = StompScheduledCareRealtime(
        tokenStore: tokenStore,
        clientFactory: (config) => stomp = _FakeStompClient(config),
      );
      await realtime.connect((_) => domainEvents++);

      stomp.config.onStompError(
        StompFrame(
          command: 'ERROR',
          headers: const {'message': 'WebSocket CONNECT rejected'},
        ),
      );

      expect(stomp.deactivateCalls, 1);
      expect(stomp.isActive, isFalse);
      expect(realtime.isConnected, isFalse);
      expect(domainEvents, 0);
      expect(await tokenStore.readSession(), isNotNull);
    },
  );

  test('logout disconnect deactivates the scheduled-care transport', () async {
    final backend = _MemoryBackend();
    final tokenStore = SecureTokenStore(backend: backend);
    await tokenStore.saveSession(_storedSession());
    late _FakeStompClient stomp;
    final realtime = StompScheduledCareRealtime(
      tokenStore: tokenStore,
      clientFactory: (config) => stomp = _FakeStompClient(config),
    );
    await realtime.connect((_) {});

    realtime.disconnect();

    expect(stomp.deactivateCalls, 1);
    expect(realtime.isConnected, isFalse);
  });

  test(
    'family list criteria sends the exact profile family member id',
    () async {
      final repository = _FakeRepository();
      final controller = ScheduledCareController(repository: repository);

      await controller.loadList(
        const ScheduledCareListCriteria(
          subjectType: CareSubjectType.familyMember,
          familyMemberId: 'family-9',
        ),
      );

      expect(repository.lastSubjectType, CareSubjectType.familyMember);
      expect(repository.lastFamilyMemberId, 'family-9');
      controller.dispose();
    },
  );

  test(
    'command key survives unknown outcome and version is reconciled',
    () async {
      final repository = _FakeRepository()..failFirstCancel = true;
      var sequence = 0;
      final controller = ScheduledCareController(
        repository: repository,
        uuidFactory: () => '00000000-0000-4000-8000-00000000000${sequence++}',
      );
      await controller.loadRequest(_requestId);

      expect(await controller.cancelRequest(), isFalse);
      expect(await controller.cancelRequest(), isTrue);
      expect(repository.commandKeys.length, 2);
      expect(repository.commandKeys[0], repository.commandKeys[1]);
      expect(controller.request!.version, 2);
      controller.dispose();
    },
  );

  test(
    'duplicate realtime event is one invalidation, never a state mutation',
    () async {
      final repository = _FakeRepository();
      final realtime = _FakeRealtime();
      final controller = ScheduledCareController(
        repository: repository,
        realtime: realtime,
      );
      await controller.connectRealtime();
      final event = ScheduledCareEvent(
        eventId: 'event-1',
        eventType: 'BOOKING_REQUEST_UPDATED',
        resourceType: ScheduledCareResourceType.bookingRequest,
        resourceId: _requestId,
        version: 2,
        occurredAt: DateTime.parse('2026-10-08T09:00:00Z'),
      );

      realtime.emit(event);
      realtime.emit(event);
      await Future<void>.delayed(Duration.zero);

      expect(repository.listCalls, 1);
      controller.dispose();
    },
  );

  test('realtime reconnect performs an authoritative REST resync', () async {
    final repository = _FakeRepository();
    final realtime = _FakeRealtime();
    final controller = ScheduledCareController(
      repository: repository,
      realtime: realtime,
    );
    await controller.connectRealtime();

    realtime.reconnect();
    await Future<void>.delayed(Duration.zero);

    expect(repository.listCalls, 1);
    controller.dispose();
  });
}

const _requestId = '00000000-0000-4000-8000-000000000001';
const _appointmentId = '00000000-0000-4000-8000-000000000099';

final _availabilityJson = {
  'doctorId': 'doctor-1',
  'practiceLocationId': 'cabinet-7',
  'timezone': 'Africa/Tunis',
  'generatedAt': '2026-10-08T08:00:00Z',
  'slots': [
    {'start': '2026-10-10T09:00:00Z', 'end': '2026-10-10T09:30:00Z'},
  ],
};

final _requestJson = {
  'requestId': _requestId,
  'version': 1,
  'status': 'PENDING_DOCTOR',
  'subject': {
    'subjectType': 'FAMILY_MEMBER',
    'familyMemberId': 'family-9',
    'displayName': 'Aicha',
    'relationship': 'Mère',
  },
  'doctor': {
    'doctorId': 'doctor-1',
    'displayName': 'Dr. Test',
    'specialty': 'Cardiologie',
  },
  'cabinet': {
    'practiceLocationId': 'cabinet-7',
    'name': 'Cabinet Lac',
    'address': 'Rue 1',
    'city': 'Tunis',
    'governorate': 'Tunis',
    'timezone': 'Africa/Tunis',
  },
  'originalRequestedSlot': {
    'start': '2026-10-10T09:00:00Z',
    'end': '2026-10-10T09:30:00Z',
  },
  'proposedSlot': null,
  'activeSlot': {
    'start': '2026-10-10T09:00:00Z',
    'end': '2026-10-10T09:30:00Z',
    'durationMinutes': 30,
  },
  'priceQuote': null,
  'createdAt': '2026-10-08T08:00:00Z',
  'responseDeadline': '2026-10-09T08:00:00Z',
  'confirmedAppointmentId': null,
  'cancellation': null,
  'expiredAt': null,
  'expiryReason': null,
  'slotReleased': false,
  'availableActions': ['CANCEL_REQUEST'],
  'updatedAt': '2026-10-08T08:00:00Z',
};

final _appointmentJson = {
  'appointmentId': _appointmentId,
  'sourceBookingRequestId': _requestId,
  'version': 4,
  'status': 'CONFIRMED',
  'doctor': {
    'doctorId': 'doctor-1',
    'displayName': 'Dr. Test',
    'specialty': 'Cardiologie',
  },
  'subject': {
    'subjectType': 'SELF',
    'familyMemberId': null,
    'displayName': 'Moi',
    'relationship': 'Moi-même',
  },
  'cabinet': {
    'practiceLocationId': 'cabinet-7',
    'name': 'Cabinet Lac',
    'address': 'Rue 1',
    'city': 'Tunis',
    'governorate': 'Tunis',
    'timezone': 'Africa/Tunis',
  },
  'slot': {
    'start': '2026-10-10T09:00:00Z',
    'end': '2026-10-10T09:30:00Z',
    'timezone': 'Africa/Tunis',
    'durationMinutes': 30,
  },
  'quotedPrice': null,
  'confirmedAt': '2026-10-08T09:00:00Z',
  'createdAt': '2026-10-08T08:00:00Z',
  'updatedAt': '2026-10-08T09:00:00Z',
  'cancellation': null,
  'intakeStatus': 'NOT_SUBMITTED',
  'availableActions': ['CANCEL_APPOINTMENT'],
};

class _FakeRepository extends ScheduledCareRepository {
  _FakeRepository() : super(ScheduledCareApi(_client(_RecordingAdapter({}))));

  bool failFirstCreate = false;
  bool failFirstCancel = false;
  int listCalls = 0;
  final List<String> createIds = [];
  final List<String> commandKeys = [];
  AvailabilityWindow window = AvailabilityWindow.fromJson(_availabilityJson);
  PatientBookingRequest current = PatientBookingRequest.fromJson(_requestJson);
  CareSubjectType? lastSubjectType;
  String? lastFamilyMemberId;
  DateTime? lastAvailabilityFrom;
  DateTime? lastAvailabilityTo;

  @override
  Future<AvailabilityWindow> getAvailability({
    required String doctorId,
    required String practiceLocationId,
    required DateTime from,
    required DateTime to,
  }) async {
    lastAvailabilityFrom = from;
    lastAvailabilityTo = to;
    return window;
  }

  @override
  Future<PatientBookingRequest> createRequest({
    required String requestId,
    required String doctorId,
    required String practiceLocationId,
    required CareSubject subject,
    required ScheduledCareSlot slot,
  }) async {
    createIds.add(requestId);
    if (failFirstCreate) {
      failFirstCreate = false;
      throw const ScheduledCareFailure(
        message: 'unknown',
        unknownOutcome: true,
      );
    }
    return current;
  }

  @override
  Future<PatientBookingRequest> getRequest(String id) async {
    if (createIds.length == 1 && failFirstCreate == false) {
      throw const ScheduledCareFailure(message: 'not found', statusCode: 404);
    }
    return current;
  }

  @override
  Future<PatientBookingRequest> cancelRequest({
    required String requestId,
    required int expectedVersion,
    required String reasonCode,
    required String idempotencyKey,
  }) async {
    commandKeys.add(idempotencyKey);
    if (failFirstCancel) {
      failFirstCancel = false;
      throw const ScheduledCareFailure(
        message: 'unknown',
        unknownOutcome: true,
      );
    }
    final next = Map<String, dynamic>.from(_requestJson)
      ..['version'] = 2
      ..['status'] = 'CANCELLED_BY_PATIENT'
      ..['availableActions'] = <String>[];
    current = PatientBookingRequest.fromJson(next);
    return current;
  }

  @override
  Future<ScheduledCarePage> list({
    required ScheduledCareBucket bucket,
    String? cursor,
    String? query,
    DateTime? from,
    DateTime? to,
    CareSubjectType? subjectType,
    String? familyMemberId,
    String? city,
  }) async {
    listCalls++;
    lastSubjectType = subjectType;
    lastFamilyMemberId = familyMemberId;
    return const ScheduledCarePage(items: []);
  }
}

class _FakeRealtime implements ScheduledCareRealtime {
  ScheduledCareEventCallback? callback;
  void Function()? onConnected;
  @override
  bool get isConnected => callback != null;
  @override
  Future<void> connect(
    ScheduledCareEventCallback onEvent, {
    void Function()? onConnected,
  }) async {
    callback = onEvent;
    this.onConnected = onConnected;
  }

  void emit(ScheduledCareEvent event) => callback?.call(event);
  void reconnect() => onConnected?.call();
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
    onConnected = null;
  }
}

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.responseBody, {this.statusCode = 200});
  final Object? responseBody;
  final int statusCode;
  String? path;
  Map<String, dynamic> query = const {};
  Map<String, dynamic> headers = const {};
  Object? body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    path = options.uri.path;
    query = Map<String, dynamic>.from(options.queryParameters);
    headers = Map<String, dynamic>.from(options.headers);
    body = options.data;
    return ResponseBody.fromString(
      _json(responseBody),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

AppHttpClient _client(_RecordingAdapter adapter) {
  final dio = Dio()..httpClientAdapter = adapter;
  return AppHttpClient(
    tokenStore: SecureTokenStore(backend: _MemoryBackend()),
    baseUrl: 'https://api.omnicare.test',
    dio: dio,
    refreshDio: Dio(),
  );
}

String _json(Object? value) {
  // Dio's default transformer accepts a JSON string. This small encoder keeps
  // test fixtures dependency-free.
  if (value is Map) {
    final entries = value.entries.map(
      (entry) => '"${entry.key}":${_json(entry.value)}',
    );
    return '{${entries.join(',')}}';
  }
  if (value is List) return '[${value.map((item) => _json(item)).join(',')}]';
  if (value is String) {
    return '"${value.replaceAll('\\', '\\\\').replaceAll('"', '\\"')}"';
  }
  if (value == null) return 'null';
  return '$value';
}

class _MemoryBackend implements SecureTokenStorageBackend {
  final Map<String, String> values = {};

  @override
  Future<void> delete({required String key}) async => values.remove(key);
  @override
  Future<String?> read({required String key}) async => values[key];
  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }
}

StoredSession _storedSession() => StoredSession(
  accessToken: 'access-token',
  refreshToken: 'refresh-token',
  accessTokenExpiresAt: DateTime.parse('2026-10-08T23:30:00Z'),
  refreshTokenExpiresAt: DateTime.parse('2026-10-20T00:00:00Z'),
  userId: 'patient-1',
  userRole: 'PATIENT',
  sessionId: 'session-1',
);

class _FakeStompClient extends StompClient {
  _FakeStompClient(StompConfig config) : super(config: config);

  bool active = false;
  int deactivateCalls = 0;
  final List<String> subscribedDestinations = [];

  @override
  bool get isActive => active;

  @override
  void activate() => active = true;

  @override
  void deactivate() {
    deactivateCalls++;
    active = false;
  }

  @override
  StompUnsubscribe subscribe({
    required String destination,
    required StompFrameCallback callback,
    Map<String, String>? headers,
  }) {
    subscribedDestinations.add(destination);
    return ({Map<String, String>? unsubscribeHeaders}) {};
  }
}
