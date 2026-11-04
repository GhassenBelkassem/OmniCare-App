import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:omnicare_mobile/core/network/app_http_client.dart';
import 'package:omnicare_mobile/core/realtime/authenticated_realtime_transport.dart';
import 'package:omnicare_mobile/core/storage/secure_token_store.dart';
import 'package:omnicare_mobile/features/auth/application/auth_role_family.dart';
import 'package:omnicare_mobile/features/notifications/application/notification_center_controller.dart';
import 'package:omnicare_mobile/features/notifications/application/notification_navigation_resolver.dart';
import 'package:omnicare_mobile/features/notifications/data/notification_api.dart';
import 'package:omnicare_mobile/features/notifications/data/notification_repository.dart';
import 'package:omnicare_mobile/features/notifications/domain/notification_models.dart';
import 'package:omnicare_mobile/features/notifications/notifications_screen.dart';
import 'package:omnicare_mobile/features/notifications/presentation/notification_badge.dart';
import 'package:omnicare_mobile/features/notifications/realtime/notification_realtime_coordinator.dart';
import 'package:omnicare_mobile/services/notification_service.dart';

const _notificationId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _secondNotificationId = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const _requestId = '11111111-1111-4111-8111-111111111111';
const _appointmentId = '22222222-2222-4222-8222-222222222222';

void main() {
  test(
    'urgent notification payload emits only a validated request intent',
    () async {
      final service = NotificationService();
      final opened = service.urgentCabinetOpens.first;

      service.openPayload({
        'destination': 'URGENT_CABINET_REQUEST',
        'request_id': _requestId,
        'outcome': 'ACCEPTED',
      });

      final intent = await opened;
      expect(intent.requestId, _requestId);
      expect(service.claimUrgentCabinetOpen(intent), same(intent));
      expect(service.takePendingUrgentCabinetOpen(), isNull);
    },
  );

  test(
    'urgent notification identity survives until Doctor bootstrap claims it',
    () {
      final service = NotificationService();

      service.openPayload({
        'destination': 'URGENT_CABINET_REQUEST',
        'request_id': _requestId.toUpperCase(),
        'outcome': 'DOCTOR_PENDING',
      });

      final pending = service.takePendingUrgentCabinetOpen();
      expect(pending?.requestId, _requestId);
      expect(service.takePendingUrgentCabinetOpen(), isNull);
    },
  );

  group('notification DTO and query contract', () {
    test('parses exact fields, category, priority, and Instant', () {
      final value = InboxNotification.fromJson(_item());
      expect(value.id, _notificationId);
      expect(value.priority, InboxNotificationPriority.high);
      expect(value.category, InboxNotificationCategory.appointment);
      expect(value.titleFr, 'Rendez-vous confirmé');
      expect(value.bodyFr, 'Votre rendez-vous est confirmé.');
      expect(value.titleAr, 'موعد مؤكد');
      expect(value.deepLinkPayload['appointment_id'], _appointmentId);
      expect(value.createdAt, DateTime.utc(2026, 10, 12, 10, 30));
    });

    test('unknown enum values remain renderable and defensive', () {
      final value = InboxNotification.fromJson(
        _item(priority: 'FUTURE', category: 'FUTURE_CATEGORY'),
      );
      expect(value.priority, InboxNotificationPriority.unknown);
      expect(value.category, InboxNotificationCategory.unknown);
    });

    test('malformed list item is skipped without losing valid items', () {
      final page = NotificationPage.fromJson(
        _page(
          items: [
            _item(),
            _item(id: 'not-a-uuid'),
          ],
          totalElements: 2,
        ),
      );
      expect(page.items.map((item) => item.id), [_notificationId]);
      expect(page.totalElements, 2);
    });

    test('default query always sends numeric page and pageSize', () {
      expect(const NotificationListQuery().toQueryParameters(), {
        'page': 0,
        'pageSize': 20,
      });
    });

    test(
      'query sends normalized category and unreadOnly only when enabled',
      () {
        expect(
          const NotificationListQuery(
            category: ' appointment ',
            unreadOnly: true,
            page: 2,
            pageSize: 10,
          ).toQueryParameters(),
          {
            'category': 'APPOINTMENT',
            'unreadOnly': true,
            'page': 2,
            'pageSize': 10,
          },
        );
      },
    );
  });

  group('notification REST API and repository', () {
    late _RecordingAdapter adapter;
    late NotificationApi api;

    setUp(() {
      adapter = _RecordingAdapter();
      final dio = Dio()..httpClientAdapter = adapter;
      api = NotificationApi(
        AppHttpClient(
          tokenStore: SecureTokenStore(backend: _MemoryTokenBackend()),
          baseUrl: 'https://api.example.test/api/v1',
          dio: dio,
          refreshDio: Dio(),
        ),
      );
    });

    test('list uses exact path and query', () async {
      adapter.enqueueJson(_page(items: [_item()]));
      final json = await api.getNotifications(
        const NotificationListQuery(category: 'APPOINTMENT', unreadOnly: true),
      );
      expect(json['totalElements'], 1);
      expect(adapter.requests.single.method, 'GET');
      expect(adapter.requests.single.path, '/notifications');
      expect(adapter.requests.single.queryParameters, {
        'category': 'APPOINTMENT',
        'unreadOnly': true,
        'page': 0,
        'pageSize': 20,
      });
    });

    test('unread count uses exact path and parses authority', () async {
      adapter.enqueueJson({'unreadCount': 7});
      final count = await NotificationRepository(api).getUnreadCount();
      expect(count, 7);
      expect(adapter.requests.single.path, '/notifications/unread-count');
    });

    test('mark one uses exact POST path and accepts 204', () async {
      adapter.enqueue(statusCode: 204);
      await NotificationRepository(api).markRead(_notificationId);
      expect(adapter.requests.single.method, 'POST');
      expect(
        adapter.requests.single.path,
        '/notifications/$_notificationId/read',
      );
    });

    test('mark all uses exact POST path and parses updated count', () async {
      adapter.enqueueJson({'updated': 4});
      final updated = await NotificationRepository(api).markAllRead();
      expect(updated, 4);
      expect(adapter.requests.single.method, 'POST');
      expect(adapter.requests.single.path, '/notifications/read-all');
    });

    test('404 mark-read is mapped without leaking transport exception', () {
      expect(
        NotificationFailure.from(_httpFailure(404)).kind,
        NotificationFailureKind.notFound,
      );
    });

    test('401 and 403 are mapped to auth-safe failures', () {
      expect(
        NotificationFailure.from(_httpFailure(401)).kind,
        NotificationFailureKind.unauthenticated,
      );
      expect(
        NotificationFailure.from(_httpFailure(403)).kind,
        NotificationFailureKind.forbidden,
      );
    });

    test('malformed top-level response is a contract failure', () async {
      adapter.enqueueJson(<Object>[]);
      await expectLater(
        NotificationRepository(api).getUnreadCount(),
        throwsA(
          isA<NotificationFailure>().having(
            (value) => value.kind,
            'kind',
            NotificationFailureKind.contract,
          ),
        ),
      );
    });
  });

  group('notification controller', () {
    test(
      'initial load publishes items, paging, and authoritative count',
      () async {
        final repository = _FakeRepository()
          ..pages.add(
            _notificationPage(items: [_notification()], unreadCount: 3),
          );
        final controller = NotificationCenterController(repository: repository);
        await controller.load();
        expect(controller.state, NotificationCenterLoadState.ready);
        expect(controller.items, hasLength(1));
        expect(controller.unreadCount, 3);
        expect(repository.queries.single.pageSize, 20);
      },
    );

    test('empty response produces a ready empty inbox', () async {
      final repository = _FakeRepository()
        ..pages.add(_notificationPage(items: const [], unreadCount: 0));
      final controller = NotificationCenterController(repository: repository);
      await controller.load();
      expect(controller.state, NotificationCenterLoadState.ready);
      expect(controller.items, isEmpty);
    });

    test('first-load failure and retry recover', () async {
      final repository = _FakeRepository()
        ..pageErrors.add(
          const NotificationFailure(NotificationFailureKind.network, 'offline'),
        )
        ..pages.add(_notificationPage(items: [_notification()]));
      final controller = NotificationCenterController(repository: repository);
      await controller.load();
      expect(controller.state, NotificationCenterLoadState.failed);
      await controller.load();
      expect(controller.state, NotificationCenterLoadState.ready);
      expect(controller.items, hasLength(1));
    });

    test('pagination appends with ID dedupe and sends next page', () async {
      final repository = _FakeRepository()
        ..pages.add(
          _notificationPage(items: [_notification()], totalElements: 2),
        )
        ..pages.add(
          _notificationPage(
            items: [
              _notification(),
              _notification(id: _secondNotificationId),
            ],
            page: 1,
            totalElements: 2,
          ),
        );
      final controller = NotificationCenterController(repository: repository);
      await controller.load();
      await controller.loadMore();
      expect(controller.items.map((item) => item.id), [
        _notificationId,
        _secondNotificationId,
      ]);
      expect(repository.queries.map((query) => query.page), [0, 1]);
      expect(controller.hasMore, isFalse);
    });

    test(
      'loading-more guard suppresses a concurrent duplicate request',
      () async {
        final gate = Completer<NotificationPage>();
        final repository = _FakeRepository()
          ..pages.add(
            _notificationPage(items: [_notification()], totalElements: 2),
          );
        final controller = NotificationCenterController(repository: repository);
        await controller.load();
        repository.pageCompleters.add(gate);
        final first = controller.loadMore();
        final second = controller.loadMore();
        expect(repository.queries, hasLength(2));
        gate.complete(
          _notificationPage(
            items: [_notification(id: _secondNotificationId)],
            page: 1,
            totalElements: 2,
          ),
        );
        await Future.wait([first, second]);
        expect(repository.queries, hasLength(2));
      },
    );

    test('refresh failure preserves already loaded notifications', () async {
      final repository = _FakeRepository()
        ..pages.add(_notificationPage(items: [_notification()]));
      final controller = NotificationCenterController(repository: repository);
      await controller.load();
      repository.pageErrors.add(
        const NotificationFailure(NotificationFailureKind.network, 'offline'),
      );
      await controller.refresh();
      expect(controller.items, hasLength(1));
      expect(controller.state, NotificationCenterLoadState.ready);
      expect(controller.failure?.kind, NotificationFailureKind.network);
    });

    test(
      'mark one is optimistic then reconciles authoritative count',
      () async {
        final repository = _FakeRepository()
          ..pages.add(
            _notificationPage(items: [_notification()], unreadCount: 1),
          )
          ..counts.add(0);
        final controller = NotificationCenterController(repository: repository);
        await controller.load();
        final operation = controller.markRead(_notificationId);
        expect(controller.items.single.isRead, isTrue);
        expect(controller.unreadCount, 0);
        await operation;
        expect(repository.markedIds, [_notificationId]);
        expect(controller.unreadCount, 0);
      },
    );

    test(
      'mark-read failure refetches list and count without blocking caller',
      () async {
        final repository = _FakeRepository()
          ..pages.add(
            _notificationPage(items: [_notification()], unreadCount: 1),
          )
          ..markReadError = const NotificationFailure(
            NotificationFailureKind.notFound,
            'gone',
          )
          ..pages.add(
            _notificationPage(
              items: [_notification(isRead: true)],
              unreadCount: 0,
            ),
          )
          ..counts.add(0);
        final controller = NotificationCenterController(repository: repository);
        await controller.load();
        await controller.markRead(_notificationId);
        expect(repository.queries, hasLength(2));
        expect(controller.items.single.isRead, isTrue);
        expect(controller.unreadCount, 0);
      },
    );

    test('mark all works even when only badge count is loaded', () async {
      final repository = _FakeRepository()..counts.addAll([4, 0]);
      final controller = NotificationCenterController(repository: repository);
      await controller.startSession('patient-a::PATIENT');
      await controller.markAllRead();
      expect(repository.markAllCalls, 1);
      expect(controller.unreadCount, 0);
    });

    test('clear removes all session-owned state', () async {
      final repository = _FakeRepository()
        ..counts.add(2)
        ..pages.add(
          _notificationPage(items: [_notification()], unreadCount: 2),
        );
      final controller = NotificationCenterController(repository: repository);
      await controller.startSession('patient-a::PATIENT');
      await controller.load();
      controller.clearForSession();
      expect(controller.items, isEmpty);
      expect(controller.unreadCount, isNull);
      expect(controller.state, NotificationCenterLoadState.initial);
      expect(controller.page, 0);
    });

    test('user switch clears A and ignores A late list response', () async {
      final gate = Completer<NotificationPage>();
      final repository = _FakeRepository()
        ..counts.addAll([1, 0])
        ..pageCompleters.add(gate);
      final controller = NotificationCenterController(repository: repository);
      await controller.startSession('patient-a::PATIENT');
      final lateLoad = controller.load();
      await controller.startSession('doctor-a::DOCTOR');
      gate.complete(_notificationPage(items: [_notification()]));
      await lateLoad;
      expect(controller.items, isEmpty);
      expect(controller.unreadCount, 0);
    });

    test(
      'late list metadata cannot overwrite a newer unread authority',
      () async {
        final pageGate = Completer<NotificationPage>();
        final repository = _FakeRepository()
          ..counts.addAll([4, 1])
          ..pageCompleters.add(pageGate);
        final controller = NotificationCenterController(repository: repository);
        await controller.startSession('doctor-a::DOCTOR');

        final lateLoad = controller.load();
        await controller.refreshUnreadCount();
        expect(controller.unreadCount, 1);

        pageGate.complete(
          _notificationPage(items: [_notification()], unreadCount: 4),
        );
        await lateLoad;
        expect(controller.unreadCount, 1);
      },
    );

    test('pagination never changes the global unread badge', () async {
      final repository = _FakeRepository()
        ..pages.add(
          _notificationPage(
            items: [_notification()],
            unreadCount: 4,
            totalElements: 2,
          ),
        )
        ..counts.add(1)
        ..pages.add(
          _notificationPage(
            items: [_notification(id: _secondNotificationId)],
            page: 1,
            unreadCount: 99,
            totalElements: 2,
          ),
        );
      final controller = NotificationCenterController(repository: repository);
      await controller.load();
      await controller.startSession('doctor-a::DOCTOR');
      await controller.loadMore();
      expect(controller.unreadCount, 1);
    });

    test(
      'unread endpoint failure preserves the last trustworthy count',
      () async {
        final countGate = Completer<int>();
        final repository = _FakeRepository()..counts.add(4);
        final controller = NotificationCenterController(repository: repository);
        await controller.startSession('doctor-a::DOCTOR');
        repository.countCompleters.add(countGate);
        final failedRefresh = controller.refreshUnreadCount();
        countGate.completeError(
          const NotificationFailure(NotificationFailureKind.network, 'offline'),
        );
        await failedRefresh;
        expect(controller.unreadCount, 4);
      },
    );
  });

  group('structured notification navigation', () {
    const cases =
        <
          (
            String,
            AuthRoleFamily,
            NotificationNavigationResource,
            String,
            String,
          )
        >[
          (
            'DOCTOR_BOOKING_REQUEST_CREATED',
            AuthRoleFamily.doctor,
            NotificationNavigationResource.bookingRequest,
            'request_id',
            _requestId,
          ),
          (
            'DOCTOR_BOOKING_TIME_PROPOSED',
            AuthRoleFamily.patient,
            NotificationNavigationResource.bookingRequest,
            'request_id',
            _requestId,
          ),
          (
            'DOCTOR_BOOKING_REQUEST_DECLINED',
            AuthRoleFamily.patient,
            NotificationNavigationResource.bookingRequest,
            'request_id',
            _requestId,
          ),
          (
            'DOCTOR_BOOKING_REQUEST_CANCELLED_BY_PATIENT',
            AuthRoleFamily.doctor,
            NotificationNavigationResource.bookingRequest,
            'request_id',
            _requestId,
          ),
          (
            'DOCTOR_BOOKING_PROPOSAL_ACCEPTED',
            AuthRoleFamily.doctor,
            NotificationNavigationResource.appointment,
            'appointment_id',
            _appointmentId,
          ),
          (
            'DOCTOR_BOOKING_PROPOSAL_DECLINED',
            AuthRoleFamily.doctor,
            NotificationNavigationResource.bookingRequest,
            'request_id',
            _requestId,
          ),
          (
            'DOCTOR_BOOKING_REQUEST_EXPIRED',
            AuthRoleFamily.patient,
            NotificationNavigationResource.bookingRequest,
            'request_id',
            _requestId,
          ),
          (
            'DOCTOR_BOOKING_PROPOSAL_EXPIRED',
            AuthRoleFamily.doctor,
            NotificationNavigationResource.bookingRequest,
            'request_id',
            _requestId,
          ),
          (
            'APPOINTMENT_CONFIRMED',
            AuthRoleFamily.patient,
            NotificationNavigationResource.appointment,
            'appointment_id',
            _appointmentId,
          ),
          (
            'APPOINTMENT_CANCELLED_BY_PATIENT',
            AuthRoleFamily.doctor,
            NotificationNavigationResource.appointment,
            'appointment_id',
            _appointmentId,
          ),
          (
            'APPOINTMENT_CANCELLED_BY_PROFESSIONAL',
            AuthRoleFamily.patient,
            NotificationNavigationResource.appointment,
            'appointment_id',
            _appointmentId,
          ),
          (
            'URGENT_CABINET_REQUEST_TARGETED',
            AuthRoleFamily.doctor,
            NotificationNavigationResource.urgentCabinetRequest,
            'request_id',
            _requestId,
          ),
          (
            'URGENT_CABINET_REQUEST_ACCEPTED',
            AuthRoleFamily.patient,
            NotificationNavigationResource.urgentCabinetRequest,
            'request_id',
            _requestId,
          ),
          (
            'URGENT_CABINET_REQUEST_DECLINED',
            AuthRoleFamily.patient,
            NotificationNavigationResource.urgentCabinetRequest,
            'request_id',
            _requestId,
          ),
          (
            'URGENT_CABINET_REQUEST_EXPIRED',
            AuthRoleFamily.patient,
            NotificationNavigationResource.urgentCabinetRequest,
            'request_id',
            _requestId,
          ),
          (
            'URGENT_CABINET_REQUEST_CANCELLED',
            AuthRoleFamily.patient,
            NotificationNavigationResource.urgentCabinetRequest,
            'request_id',
            _requestId,
          ),
          (
            'URGENT_CABINET_COMMITMENT_WITHDRAWN',
            AuthRoleFamily.doctor,
            NotificationNavigationResource.urgentCabinetRequest,
            'request_id',
            _requestId,
          ),
        ];

    for (final value in cases) {
      test('${value.$1} resolves exact ${value.$4}', () {
        final notification = _notification(
          type: value.$1,
          payload: {'request_id': _requestId, 'appointment_id': _appointmentId},
        );
        final result = NotificationNavigationResolver.resolve(
          notification,
          value.$2,
        );
        expect(result.status, NotificationNavigationStatus.target);
        expect(result.resource, value.$3);
        expect(result.resourceId, value.$5);
      });

      test('${value.$1} cannot cross role boundary', () {
        final otherRole = value.$2 == AuthRoleFamily.patient
            ? AuthRoleFamily.doctor
            : AuthRoleFamily.patient;
        final result = NotificationNavigationResolver.resolve(
          _notification(
            type: value.$1,
            payload: {
              'request_id': _requestId,
              'appointment_id': _appointmentId,
            },
          ),
          otherRole,
        );
        expect(result.status, NotificationNavigationStatus.noDestination);
      });
    }

    test('missing, wrong-type, and malformed exact ID are unavailable', () {
      for (final payload in <Map<String, dynamic>>[
        {},
        {'request_id': 42},
        {'request_id': 'not-a-uuid'},
        {'appointment_id': _appointmentId},
      ]) {
        final result = NotificationNavigationResolver.resolve(
          _notification(type: 'DOCTOR_BOOKING_TIME_PROPOSED', payload: payload),
          AuthRoleFamily.patient,
        );
        expect(result.status, NotificationNavigationStatus.unavailable);
      }
    });

    test('unknown type never guesses from payload or localized copy', () {
      final result = NotificationNavigationResolver.resolve(
        _notification(
          type: 'FUTURE_NOTIFICATION',
          payload: {'appointment_id': _appointmentId},
          titleFr: 'Rendez-vous confirmé $_appointmentId',
        ),
        AuthRoleFamily.patient,
      );
      expect(result.status, NotificationNavigationStatus.noDestination);
    });

    test('expired Doctor CABINET alert remains an authority lookup only', () {
      final result = NotificationNavigationResolver.resolve(
        _notification(
          type: 'URGENT_CABINET_REQUEST_TARGETED',
          payload: const {'request_id': _requestId},
          expiresAt: DateTime.utc(2020),
        ),
        AuthRoleFamily.doctor,
      );
      expect(result.status, NotificationNavigationStatus.target);
      expect(result.resourceId, _requestId);
    });

    test('other expired notification routes remain unavailable', () {
      final result = NotificationNavigationResolver.resolve(
        _notification(
          type: 'DOCTOR_BOOKING_REQUEST_CREATED',
          payload: const {'request_id': _requestId},
          expiresAt: DateTime.utc(2020),
        ),
        AuthRoleFamily.doctor,
      );
      expect(result.status, NotificationNavigationStatus.unavailable);
    });
  });

  group('notification realtime invalidation', () {
    test('strictly parses only the PII-free committed envelope', () {
      final parsed = NotificationRealtimeInvalidation.tryParse(
        _notificationEvent(),
      );
      expect(parsed?.notificationId, _notificationId);
      expect(parsed?.occurredAt, DateTime.utc(2026, 10, 12, 10, 30));
      for (final invalid in [
        '{}',
        '[]',
        'not-json',
        _notificationEvent(id: 'bad'),
      ]) {
        expect(NotificationRealtimeInvalidation.tryParse(invalid), isNull);
      }
    });

    test(
      'event retrieves authenticated inbox item and emits one foreground alert',
      () async {
        final repository = _FakeRepository()
          ..counts.addAll([0, 1])
          ..pages.add(_notificationPage(items: [_notification()]));
        final controller = NotificationCenterController(repository: repository);
        await controller.startSession('patient-a::PATIENT');
        final transport = _FakeTransport();
        final alerts = <InboxNotification>[];
        final coordinator = NotificationRealtimeCoordinator(
          transport: transport,
          controller: controller,
          onForegroundNotification: (notification) async =>
              alerts.add(notification),
        )..startSession();
        transport.emitNotification(_notificationEvent());
        await _pumpEvents();
        expect(controller.unreadCount, 1);
        expect(repository.queries, hasLength(1));
        expect(alerts.map((item) => item.id), [_notificationId]);
        await coordinator.dispose();
      },
    );

    test(
      'visible inbox event refreshes both count and list through REST',
      () async {
        final repository = _FakeRepository()
          ..counts.addAll([0, 1])
          ..pages.add(_notificationPage(items: const []))
          ..pages.add(
            _notificationPage(items: [_notification()], unreadCount: 1),
          );
        final controller = NotificationCenterController(repository: repository);
        await controller.startSession('patient-a::PATIENT');
        await controller.load();
        controller.setInboxVisible(true);
        final transport = _FakeTransport();
        final coordinator = NotificationRealtimeCoordinator(
          transport: transport,
          controller: controller,
        )..startSession();
        transport.emitNotification(_notificationEvent());
        await _pumpEvents();
        expect(controller.items, hasLength(1));
        expect(controller.unreadCount, 1);
        await coordinator.dispose();
      },
    );

    test(
      'reconnect and foreground each resync visible inbox and count',
      () async {
        final repository = _FakeRepository()
          ..counts.addAll([0, 1, 2])
          ..pages.addAll([
            _notificationPage(items: const []),
            _notificationPage(items: const []),
            _notificationPage(items: const []),
          ]);
        final controller = NotificationCenterController(repository: repository);
        await controller.startSession('doctor-a::DOCTOR');
        await controller.load();
        controller.setInboxVisible(true);
        final transport = _FakeTransport();
        final coordinator = NotificationRealtimeCoordinator(
          transport: transport,
          controller: controller,
        )..startSession();
        transport.connect();
        await _pumpEvents();
        await coordinator.foregroundResync();
        expect(repository.countCalls, 3);
        expect(repository.queries, hasLength(3));
        await coordinator.dispose();
      },
    );

    test(
      'repeated invalidations are bounded to one eventual count follow-up',
      () async {
        final gate = Completer<int>();
        final repository = _FakeRepository()
          ..counts.addAll([0, 2])
          ..pages.addAll([
            _notificationPage(items: [_notification()]),
            _notificationPage(items: [_notification()]),
          ]);
        final controller = NotificationCenterController(repository: repository);
        await controller.startSession('patient-a::PATIENT');
        repository.countCompleters.add(gate);
        final transport = _FakeTransport();
        final alerts = <InboxNotification>[];
        final coordinator = NotificationRealtimeCoordinator(
          transport: transport,
          controller: controller,
          onForegroundNotification: (notification) async =>
              alerts.add(notification),
        )..startSession();

        transport.emitNotification(_notificationEvent());
        transport.emitNotification(_notificationEvent());
        transport.emitNotification(_notificationEvent());
        await _pumpEvents();
        expect(repository.countCalls, 2);
        gate.complete(1);
        await _pumpEvents();

        expect(repository.countCalls, 3);
        expect(controller.unreadCount, 2);
        expect(alerts.map((item) => item.id), [_notificationId]);
        await coordinator.dispose();
      },
    );

    test('late event after logout is ignored', () async {
      final repository = _FakeRepository()..counts.add(0);
      final controller = NotificationCenterController(repository: repository);
      await controller.startSession('doctor-a::DOCTOR');
      final transport = _FakeTransport();
      final coordinator = NotificationRealtimeCoordinator(
        transport: transport,
        controller: controller,
      )..startSession();
      coordinator.stopSession();
      controller.clearForSession();
      transport.emitNotification(_notificationEvent());
      await _pumpEvents();
      expect(repository.countCalls, 1);
      expect(controller.unreadCount, isNull);
      await coordinator.dispose();
    });
  });

  group('notification presentation', () {
    testWidgets('badge hides zero, shows real count, and caps at 99+', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Row(
            children: [
              NotificationBadge(count: 0, onTap: () {}),
              NotificationBadge(count: 7, onTap: () {}),
              NotificationBadge(count: 120, onTap: () {}),
            ],
          ),
        ),
      );
      expect(find.text('0'), findsNothing);
      expect(find.text('7'), findsOneWidget);
      expect(find.text('99+'), findsOneWidget);
    });

    testWidgets('screen renders repository data and no fallback on failure', (
      tester,
    ) async {
      final repository = _FakeRepository()
        ..pageErrors.add(
          const NotificationFailure(
            NotificationFailureKind.network,
            'Connexion impossible. Réessayez.',
          ),
        );
      final controller = NotificationCenterController(repository: repository);
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: controller,
          child: const MaterialApp(home: NotificationsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Connexion impossible. Réessayez.'), findsOneWidget);
      expect(find.textContaining('Ahmed'), findsNothing);
      expect(find.textContaining('Sarah'), findsNothing);
      expect(find.textContaining('Karim'), findsNothing);
    });

    test('production screen source contains no legacy static authority', () {
      final source = File(
        'lib/features/notifications/notifications_screen.dart',
      ).readAsStringSync();
      expect(source, isNot(contains('Ahmed')));
      expect(source, isNot(contains('Sarah')));
      expect(source, isNot(contains('Karim')));
      expect(source, isNot(contains('appointment_confirmed')));
    });
  });
}

Map<String, dynamic> _item({
  String id = _notificationId,
  String type = 'APPOINTMENT_CONFIRMED',
  String priority = 'HIGH',
  String category = 'APPOINTMENT',
  bool isRead = false,
  String titleFr = 'Rendez-vous confirmé',
  Map<String, dynamic>? payload,
  DateTime? expiresAt,
}) => {
  'id': id,
  'type': type,
  'priority': priority,
  'category': category,
  'titleFr': titleFr,
  'bodyFr': 'Votre rendez-vous est confirmé.',
  'titleAr': 'موعد مؤكد',
  'bodyAr': 'تم تأكيد موعدك.',
  'deepLinkPayload':
      payload ?? {'appointment_id': _appointmentId, 'request_id': _requestId},
  'read': isRead,
  'createdAt': '2026-10-12T10:30:00Z',
  if (expiresAt != null) 'expiresAt': expiresAt.toUtc().toIso8601String(),
};

Map<String, dynamic> _page({
  required List<Map<String, dynamic>> items,
  int page = 0,
  int totalElements = 1,
  int unreadCount = 1,
}) => {
  'items': items,
  'page': page,
  'pageSize': 20,
  'totalElements': totalElements,
  'unreadCount': unreadCount,
};

InboxNotification _notification({
  String id = _notificationId,
  String type = 'APPOINTMENT_CONFIRMED',
  bool isRead = false,
  String titleFr = 'Rendez-vous confirmé',
  Map<String, dynamic>? payload,
  DateTime? expiresAt,
}) => InboxNotification.fromJson(
  _item(
    id: id,
    type: type,
    isRead: isRead,
    titleFr: titleFr,
    payload: payload,
    expiresAt: expiresAt,
  ),
);

NotificationPage _notificationPage({
  required List<InboxNotification> items,
  int page = 0,
  int? totalElements,
  int unreadCount = 1,
}) => NotificationPage(
  items: items,
  page: page,
  pageSize: 20,
  totalElements: totalElements ?? items.length,
  unreadCount: unreadCount,
);

DioException _httpFailure(int statusCode) {
  final options = RequestOptions(path: '/notifications');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response(requestOptions: options, statusCode: statusCode),
  );
}

String _notificationEvent({String id = _notificationId}) => jsonEncode({
  'eventType': 'NOTIFICATION_CREATED',
  'notificationId': id,
  'occurredAt': '2026-10-12T10:30:00Z',
});

Future<void> _pumpEvents() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

class _FakeRepository implements NotificationRepositoryContract {
  final List<NotificationPage> pages = [];
  final List<Completer<NotificationPage>> pageCompleters = [];
  final List<Object> pageErrors = [];
  final List<int> counts = [];
  final List<Completer<int>> countCompleters = [];
  final List<NotificationListQuery> queries = [];
  final List<String> markedIds = [];
  Object? markReadError;
  int countCalls = 0;
  int markAllCalls = 0;

  @override
  Future<NotificationPage> getNotifications(
    NotificationListQuery query, {
    CancelToken? cancelToken,
  }) async {
    queries.add(query);
    if (pageErrors.isNotEmpty) throw pageErrors.removeAt(0);
    if (pageCompleters.isNotEmpty) return pageCompleters.removeAt(0).future;
    return pages.removeAt(0);
  }

  @override
  Future<int> getUnreadCount({CancelToken? cancelToken}) async {
    countCalls++;
    if (countCompleters.isNotEmpty) return countCompleters.removeAt(0).future;
    return counts.isEmpty ? 0 : counts.removeAt(0);
  }

  @override
  Future<void> markRead(
    String notificationId, {
    CancelToken? cancelToken,
  }) async {
    markedIds.add(notificationId);
    if (markReadError case final error?) throw error;
  }

  @override
  Future<int> markAllRead({CancelToken? cancelToken}) async {
    markAllCalls++;
    return 1;
  }
}

class _FakeTransport implements ScheduledCareRealtimeTransport {
  final StreamController<String> _messages = StreamController.broadcast();
  final StreamController<String> _notifications = StreamController.broadcast();
  final StreamController<int> _epochs = StreamController.broadcast();
  int _epoch = 0;

  @override
  int get connectionEpoch => _epoch;
  @override
  Stream<int> get connectedEpochs => _epochs.stream;
  @override
  Stream<String> get messages => _messages.stream;
  @override
  Stream<String> get notificationMessages => _notifications.stream;
  @override
  RealtimeSessionOwner? get owner => null;
  @override
  RealtimeConnectionState get state => RealtimeConnectionState.connected;
  @override
  Future<void> ensureConnected() async {}
  @override
  Future<void> startSession(RealtimeSessionOwner owner) async {}
  @override
  Future<void> stopSession() async {}

  void emitNotification(String value) => _notifications.add(value);
  void connect() => _epochs.add(++_epoch);
}

class _RecordingAdapter implements HttpClientAdapter {
  final List<RequestOptions> requests = [];
  final List<ResponseBody> _responses = [];

  void enqueueJson(Object value, {int statusCode = 200}) => enqueue(
    statusCode: statusCode,
    body: jsonEncode(value),
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  void enqueue({
    required int statusCode,
    String body = '',
    Map<String, List<String>>? headers,
  }) {
    _responses.add(
      ResponseBody.fromString(body, statusCode, headers: headers ?? const {}),
    );
  }

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return _responses.removeAt(0);
  }

  @override
  void close({bool force = false}) {}
}

class _MemoryTokenBackend implements SecureTokenStorageBackend {
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
