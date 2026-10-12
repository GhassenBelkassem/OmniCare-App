import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:omnicare_mobile/features/auth/application/auth_role_family.dart';
import 'package:omnicare_mobile/features/notifications/application/notification_center_controller.dart';
import 'package:omnicare_mobile/features/notifications/data/notification_repository.dart';
import 'package:omnicare_mobile/features/notifications/domain/notification_models.dart';
import 'package:omnicare_mobile/features/notifications/notifications_screen.dart';
import 'package:omnicare_mobile/features/scheduled_care/presentation/booking_review_screen.dart';

const _notificationId = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const _appointmentId = '22222222-2222-4222-8222-222222222222';

void main() {
  group('P3-R5A asset and timezone hardening', () {
    test('production SVGs use supported explicit presentation attributes', () {
      final expected = <String, String>{
        'assets/svg/medical_pass_green.svg': 'fill="#2C7564"',
        'assets/svg/medical_pass_grey.svg': 'fill="#A8AAAD"',
        'assets/svg/omnicare_logo_white.svg': 'fill="#FEFEFD"',
      };
      for (final entry in expected.entries) {
        final source = File(entry.key).readAsStringSync();
        expect(source, isNot(contains('<style')), reason: entry.key);
        expect(source, contains(entry.value), reason: entry.key);
      }
      expect(
        File('assets/svg/medical_pass_green.svg').readAsStringSync(),
        contains('display="none"'),
      );
    });

    test('scheduled-care wall clock never falls back to device local time', () {
      final instant = DateTime.parse('2026-10-12T10:30:00Z');
      expect(
        schedulingWallClock(instant, timezone: 'Africa/Tunis'),
        DateTime.utc(2026, 10, 12, 11, 30),
      );
      expect(
        schedulingWallClock(instant, timezone: 'Future/Unknown'),
        DateTime.utc(2026, 10, 12, 10, 30),
      );
      final homeSource = File(
        'lib/features/doctor/home/doctor_home_screen.dart',
      ).readAsStringSync();
      expect(homeSource, isNot(contains('.start.toLocal()')));
    });
  });

  group('P3-R5A notification lifecycle and races', () {
    test(
      'dispose during an active fetch emits no disposal or late notify',
      () async {
        final gate = Completer<NotificationPage>();
        final repository = _HardeningNotificationRepository()..pages.add(gate);
        final controller = NotificationCenterController(repository: repository);
        var notifications = 0;
        controller.addListener(() => notifications++);

        final load = controller.load();
        expect(notifications, 1);
        notifications = 0;
        controller.dispose();
        expect(notifications, 0);

        gate.complete(_page([_notification()]));
        await load;
        expect(notifications, 0);
      },
    );

    test('visible mark-read wins over an overlapping stale refresh', () async {
      final staleRefresh = Completer<NotificationPage>();
      final mark = Completer<void>();
      final repository = _HardeningNotificationRepository()
        ..counts.addAll([1, 0])
        ..pages.add(_page([_notification()], unreadCount: 1))
        ..pages.add(staleRefresh)
        ..pages.add(_page([_notification(isRead: true)], unreadCount: 0))
        ..markReadResults.add(mark);
      final controller = NotificationCenterController(repository: repository);
      addTearDown(controller.dispose);
      await controller.startSession('patient-a::PATIENT');
      await controller.load();
      controller.setInboxVisible(true);

      final refresh = controller.refresh();
      final markRead = controller.markRead(_notificationId);
      expect(controller.items.single.isRead, isTrue);

      staleRefresh.complete(_page([_notification()], unreadCount: 1));
      await refresh;
      expect(controller.items.single.isRead, isFalse);

      mark.complete();
      await markRead;
      expect(controller.items.single.isRead, isTrue);
      expect(controller.unreadCount, 0);
      expect(repository.queries, hasLength(3));
    });

    test('mark-all reconciles after an overlapping realtime refresh', () async {
      final staleRefresh = Completer<NotificationPage>();
      final markAll = Completer<void>();
      final repository = _HardeningNotificationRepository()
        ..counts.addAll([1, 1, 0])
        ..pages.add(_page([_notification()], unreadCount: 1))
        ..pages.add(staleRefresh)
        ..pages.add(_page([_notification(isRead: true)], unreadCount: 0))
        ..markAllResult = markAll;
      final controller = NotificationCenterController(repository: repository);
      addTearDown(controller.dispose);
      await controller.startSession('patient-a::PATIENT');
      await controller.load();
      controller.setInboxVisible(true);

      final mutation = controller.markAllRead();
      expect(controller.items.single.isRead, isTrue);
      final invalidation = controller.onRealtimeInvalidation();
      staleRefresh.complete(_page([_notification()], unreadCount: 1));
      await invalidation;
      expect(controller.items.single.isRead, isFalse);

      markAll.complete();
      await mutation;
      expect(controller.items.single.isRead, isTrue);
      expect(controller.unreadCount, 0);
    });

    testWidgets('screen can close during load and reopen without callbacks', (
      tester,
    ) async {
      final gate = Completer<NotificationPage>();
      final repository = _HardeningNotificationRepository()
        ..pages.add(gate)
        ..pages.add(_page([_notification(isRead: true)], unreadCount: 0));
      final controller = NotificationCenterController(repository: repository);
      addTearDown(controller.dispose);

      await tester.pumpWidget(_notificationApp(controller));
      await tester.pump();
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      gate.complete(_page([_notification()], unreadCount: 1));
      await tester.pump();
      await tester.pumpWidget(_notificationApp(controller));
      await tester.pumpAndSettle();

      expect(find.text('Notifications'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('P3-R5A notification responsive layout', () {
    for (final config in <({String name, Size size, double textScale})>[
      (name: 'small phone', size: const Size(320, 568), textScale: 1),
      (name: 'normal phone', size: const Size(390, 844), textScale: 1),
      (name: 'large text', size: const Size(390, 844), textScale: 2),
      (name: 'narrow web', size: const Size(360, 700), textScale: 1),
    ]) {
      testWidgets('${config.name} has no Flutter layout error', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = config.size;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final repository = _HardeningNotificationRepository()
          ..pages.add(
            _page([
              _notification(
                title:
                    'Rendez-vous confirmé avec un intitulé volontairement très long',
                body:
                    'Une description longue vérifie que la carte reste contrainte et lisible sans largeur infinie.',
              ),
            ]),
          );
        final controller = NotificationCenterController(repository: repository);
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              size: config.size,
              textScaler: TextScaler.linear(config.textScale),
            ),
            child: _notificationApp(controller),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Notifications'), findsOneWidget);
        if (config.name == 'large text') {
          expect(find.byIcon(Icons.done_all_rounded), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      });
    }
  });
}

Widget _notificationApp(NotificationCenterController controller) =>
    ChangeNotifierProvider.value(
      value: controller,
      child: const MaterialApp(
        home: NotificationsScreen(role: AuthRoleFamily.patient),
      ),
    );

InboxNotification _notification({
  bool isRead = false,
  String title = 'Rendez-vous confirmé',
  String body = 'Votre rendez-vous est confirmé.',
}) => InboxNotification.fromJson({
  'id': _notificationId,
  'type': 'APPOINTMENT_CONFIRMED',
  'priority': 'HIGH',
  'category': 'APPOINTMENT',
  'titleFr': title,
  'bodyFr': body,
  'titleAr': 'موعد مؤكد',
  'bodyAr': 'تم تأكيد موعدك.',
  'deepLinkPayload': {'appointment_id': _appointmentId},
  'read': isRead,
  'createdAt': '2026-10-12T10:30:00Z',
});

NotificationPage _page(List<InboxNotification> items, {int unreadCount = 1}) =>
    NotificationPage(
      items: items,
      page: 0,
      pageSize: 20,
      totalElements: items.length,
      unreadCount: unreadCount,
    );

class _HardeningNotificationRepository
    implements NotificationRepositoryContract {
  final List<Object> pages = <Object>[];
  final List<int> counts = <int>[];
  final List<Completer<void>> markReadResults = <Completer<void>>[];
  final List<NotificationListQuery> queries = <NotificationListQuery>[];
  Completer<void>? markAllResult;

  @override
  Future<NotificationPage> getNotifications(
    NotificationListQuery query, {
    CancelToken? cancelToken,
  }) async {
    queries.add(query);
    final result = pages.removeAt(0);
    if (result is Completer<NotificationPage>) return result.future;
    return result as NotificationPage;
  }

  @override
  Future<int> getUnreadCount({CancelToken? cancelToken}) async =>
      counts.isEmpty ? 0 : counts.removeAt(0);

  @override
  Future<int> markAllRead({CancelToken? cancelToken}) async {
    await markAllResult?.future;
    return 1;
  }

  @override
  Future<void> markRead(
    String notificationId, {
    CancelToken? cancelToken,
  }) async {
    if (markReadResults.isNotEmpty) await markReadResults.removeAt(0).future;
  }
}
