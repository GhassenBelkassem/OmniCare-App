import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/features/notifications/application/notification_controller.dart';
import 'package:omnicare_mobile/features/notifications/data/notification_models.dart';
import 'package:omnicare_mobile/features/notifications/data/notification_repository.dart';
import 'package:omnicare_mobile/features/scheduled_care/realtime/scheduled_care_realtime.dart';

void main() {
  group('typed notification contract', () {
    test(
      'request created targets request id',
      () => _expectRequest('DOCTOR_BOOKING_REQUEST_CREATED'),
    );
    test(
      'time proposed targets request id',
      () => _expectRequest('DOCTOR_BOOKING_TIME_PROPOSED'),
    );
    test(
      'request declined targets request id',
      () => _expectRequest('DOCTOR_BOOKING_REQUEST_DECLINED'),
    );
    test(
      'patient request cancellation targets request id',
      () => _expectRequest('DOCTOR_BOOKING_REQUEST_CANCELLED_BY_PATIENT'),
    );
    test(
      'proposal decline targets request id',
      () => _expectRequest('DOCTOR_BOOKING_PROPOSAL_DECLINED'),
    );
    test(
      'request expiry targets request id',
      () => _expectRequest('DOCTOR_BOOKING_REQUEST_EXPIRED'),
    );
    test(
      'proposal acceptance prefers appointment id',
      () => _expectAppointment('DOCTOR_BOOKING_PROPOSAL_ACCEPTED'),
    );
    test(
      'confirmation targets appointment id',
      () => _expectAppointment('APPOINTMENT_CONFIRMED'),
    );
    test(
      'patient appointment cancellation targets appointment id',
      () => _expectAppointment('APPOINTMENT_CANCELLED_BY_PATIENT'),
    );
    test(
      'professional appointment cancellation targets appointment id',
      () => _expectAppointment('APPOINTMENT_CANCELLED_BY_PROFESSIONAL'),
    );

    test('unknown types never infer navigation from copy', () {
      final item = InboxNotification.fromJson(_json('SOMETHING_NEW'));
      expect(item.type, InboxNotificationType.unknown);
      expect(item.reference.type, NotificationReferenceType.none);
    });

    test('missing safe id disables navigation', () {
      final item = InboxNotification.fromJson(
        _json('APPOINTMENT_CONFIRMED', payload: const {}),
      );
      expect(item.reference.type, NotificationReferenceType.none);
    });

    test('page parser preserves server pagination and count', () {
      final page = NotificationPage.fromJson({
        'items': [_json('APPOINTMENT_CONFIRMED')],
        'page': 2,
        'pageSize': 20,
        'totalElements': 45,
        'unreadCount': 7,
      });
      expect(
        (page.page, page.pageSize, page.totalElements, page.unreadCount),
        (2, 20, 45, 7),
      );
    });

    test('malformed realtime invalidation is rejected', () {
      expect(
        () => NotificationInvalidation.fromJson({
          'eventType': 'NOTIFICATION_CREATED',
        }),
        throwsFormatException,
      );
    });

    test('valid realtime invalidation is typed', () {
      final event = NotificationInvalidation.fromJson({
        'eventType': 'NOTIFICATION_CREATED',
        'notificationId': 'notification-1',
        'occurredAt': '2026-10-09T10:00:00Z',
      });
      expect(event.notificationId, 'notification-1');
    });
  });

  group('notification controller', () {
    testWidgets('start hydrates count and first page', (tester) async {
      final fixture = _fixture();
      await fixture.controller.start();
      expect(fixture.controller.items, hasLength(1));
      expect(fixture.controller.unreadCount, 3);
      fixture.dispose();
    });

    testWidgets('refresh failure preserves loaded page', (tester) async {
      final fixture = _fixture();
      await fixture.controller.start();
      fixture.repository.failList = true;
      await fixture.controller.refresh();
      expect(fixture.controller.items.single.id, 'notification-0');
      expect(fixture.controller.error, isNotNull);
      fixture.dispose();
    });

    testWidgets('pagination appends and de-duplicates ids', (tester) async {
      final fixture = _fixture(totalElements: 3);
      fixture.repository.pages[1] = _page(
        [
          _notification(id: 'notification-0'),
          _notification(id: 'notification-1'),
        ],
        page: 1,
        total: 3,
      );
      await fixture.controller.start();
      await fixture.controller.loadMore();
      expect(fixture.controller.items.map((item) => item.id), [
        'notification-0',
        'notification-1',
      ]);
      fixture.dispose();
    });

    testWidgets('mark read updates badge before network completion', (
      tester,
    ) async {
      final fixture = _fixture();
      await fixture.controller.start();
      final future = fixture.controller.markRead(
        fixture.controller.items.single,
      );
      expect(fixture.controller.items.single.read, isTrue);
      expect(fixture.controller.unreadCount, 2);
      await future;
      fixture.dispose();
    });

    testWidgets('mark all clears loaded unread state', (tester) async {
      final fixture = _fixture();
      await fixture.controller.start();
      await fixture.controller.markAllRead();
      expect(fixture.controller.unreadCount, 0);
      expect(
        fixture.controller.items,
        everyElement(
          isA<InboxNotification>().having((item) => item.read, 'read', true),
        ),
      );
      fixture.dispose();
    });

    testWidgets('realtime refreshes count while center is hidden', (
      tester,
    ) async {
      final fixture = _fixture();
      await fixture.controller.start();
      final listCalls = fixture.repository.listCalls;
      fixture.repository.count = 9;
      fixture.realtime.emit();
      await tester.pump();
      expect(fixture.controller.unreadCount, 9);
      expect(fixture.repository.listCalls, listCalls);
      fixture.dispose();
    });

    testWidgets('realtime refreshes visible inbox via REST', (tester) async {
      final fixture = _fixture();
      await fixture.controller.start();
      fixture.controller.setCenterVisible(true);
      await tester.pump();
      final calls = fixture.repository.listCalls;
      fixture.realtime.emit();
      await tester.pump();
      expect(fixture.repository.listCalls, greaterThan(calls));
      fixture.dispose();
    });

    testWidgets(
      'clear session removes user-scoped state and disconnects queue',
      (tester) async {
        final fixture = _fixture();
        await fixture.controller.start();
        fixture.controller.clearSessionState();
        expect(fixture.controller.items, isEmpty);
        expect(fixture.controller.unreadCount, 0);
        expect(fixture.realtime.notificationDisconnected, isTrue);
        fixture.dispose();
      },
    );
  });
}

void _expectRequest(String type) {
  final item = InboxNotification.fromJson(_json(type));
  expect(item.reference.type, NotificationReferenceType.bookingRequest);
  expect(item.reference.id, 'request-1');
}

void _expectAppointment(String type) {
  final item = InboxNotification.fromJson(_json(type));
  expect(item.reference.type, NotificationReferenceType.appointment);
  expect(item.reference.id, 'appointment-1');
}

Map<String, Object?> _json(String type, {Map<String, Object?>? payload}) => {
  'id': 'notification-0',
  'type': type,
  'priority': 'HIGH',
  'category': 'APPOINTMENT',
  'titleFr': 'Titre durable',
  'bodyFr': 'Corps durable',
  'titleAr': null,
  'bodyAr': null,
  'deepLinkPayload':
      payload ?? {'request_id': 'request-1', 'appointment_id': 'appointment-1'},
  'read': false,
  'createdAt': '2026-10-09T10:00:00Z',
};

InboxNotification _notification({required String id}) =>
    InboxNotification.fromJson({..._json('APPOINTMENT_CONFIRMED'), 'id': id});

NotificationPage _page(
  List<InboxNotification> items, {
  int page = 0,
  int total = 1,
}) => NotificationPage(
  items: items,
  page: page,
  pageSize: 20,
  totalElements: total,
  unreadCount: 3,
);

_Fixture _fixture({int totalElements = 1}) {
  final repository = _FakeNotificationRepository()
    ..pages[0] = _page([
      _notification(id: 'notification-0'),
    ], total: totalElements);
  final realtime = _FakeRealtime();
  final controller = NotificationController(
    repository: repository,
    realtime: realtime,
  );
  return _Fixture(controller, repository, realtime);
}

class _Fixture {
  const _Fixture(this.controller, this.repository, this.realtime);
  final NotificationController controller;
  final _FakeNotificationRepository repository;
  final _FakeRealtime realtime;
  void dispose() => controller.dispose();
}

class _FakeNotificationRepository implements NotificationRepositoryContract {
  final Map<int, NotificationPage> pages = {};
  int count = 3;
  int listCalls = 0;
  bool failList = false;

  @override
  Future<NotificationPage> list({int page = 0, int pageSize = 20}) async {
    listCalls++;
    if (failList) throw StateError('offline');
    return pages[page] ??
        _page(const [], page: page, total: pages[0]?.totalElements ?? 0);
  }

  @override
  Future<int> unreadCount() async => count;
  @override
  Future<void> markRead(String id) async {}
  @override
  Future<int> markAllRead() async => count;
}

class _FakeRealtime implements ScheduledCareRealtime {
  NotificationInvalidationCallback? notificationCallback;
  bool notificationDisconnected = false;
  @override
  bool get isConnected => true;
  @override
  Future<void> connect(
    ScheduledCareEventCallback onEvent, {
    void Function()? onConnected,
  }) async {}
  @override
  Future<void> connectNotifications(
    NotificationInvalidationCallback onEvent, {
    void Function()? onConnected,
  }) async {
    notificationCallback = onEvent;
  }

  void emit() => notificationCallback?.call(
    NotificationInvalidation.fromJson({
      'eventType': 'NOTIFICATION_CREATED',
      'notificationId': 'new-id',
      'occurredAt': '2026-10-09T10:00:00Z',
    }),
  );
  @override
  void disconnectNotifications() => notificationDisconnected = true;
  @override
  void disconnect() {}
}
