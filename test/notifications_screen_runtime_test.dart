import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/core/theme/omni_theme.dart';
import 'package:omnicare_mobile/features/notifications/application/notification_controller.dart';
import 'package:omnicare_mobile/features/notifications/data/notification_models.dart';
import 'package:omnicare_mobile/features/notifications/data/notification_repository.dart';
import 'package:omnicare_mobile/features/notifications/notifications_screen.dart';
import 'package:omnicare_mobile/features/scheduled_care/realtime/scheduled_care_realtime.dart';
import 'package:provider/provider.dart';

void main() {
  group('NotificationsScreen runtime lifecycle', () {
    testWidgets(
      'mounts, unmounts, and reopens without disposing shared state',
      (tester) async {
        final fixture = _NotificationFixture();
        addTearDown(fixture.dispose);
        await fixture.controller.start();

        await tester.pumpWidget(_NotificationHarness(fixture.controller));

        for (var visit = 0; visit < 2; visit++) {
          await tester.tap(find.byKey(_NotificationHarness.openButtonKey));
          await tester.pumpAndSettle();
          expect(find.byType(NotificationsScreen), findsOneWidget);
          expect(tester.takeException(), isNull);

          await tester.tap(find.byIcon(Icons.arrow_back));
          await tester.pumpAndSettle();
          expect(find.byType(NotificationsScreen), findsNothing);
          expect(tester.takeException(), isNull);
        }

        final listCallsWhileClosed = fixture.repository.listCalls;
        fixture.repository.unreadCountValue = 7;
        fixture.realtime.emit();
        await tester.pump();

        expect(fixture.controller.unreadCount, 7);
        expect(fixture.repository.listCalls, listCallsWhileClosed);
        expect(fixture.realtime.notificationDisconnected, isFalse);
        expect(tester.takeException(), isNull);
      },
    );

    for (final size in <Size>[const Size(360, 640), const Size(1440, 900)]) {
      testWidgets(
        'renders notification cards with finite constraints at $size',
        (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = size;
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPhysicalSize);

          final fixture = _NotificationFixture();
          addTearDown(fixture.dispose);
          await fixture.controller.start();

          await tester.pumpWidget(
            ChangeNotifierProvider<NotificationController>.value(
              value: fixture.controller,
              child: MaterialApp(
                theme: buildOmniTheme(),
                home: const NotificationsScreen(),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final cardTitleSize = tester.getSize(
            find.text('Rendez-vous confirmé'),
          );
          expect(cardTitleSize.width.isFinite, isTrue);
          expect(cardTitleSize.height.isFinite, isTrue);
          expect(tester.takeException(), isNull);
        },
      );
    }
  });
}

class _NotificationHarness extends StatelessWidget {
  const _NotificationHarness(this.controller);

  static const openButtonKey = ValueKey('open-notifications');
  final NotificationController controller;

  @override
  Widget build(BuildContext context) =>
      ChangeNotifierProvider<NotificationController>.value(
        value: controller,
        child: MaterialApp(
          theme: buildOmniTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: FilledButton(
                  key: openButtonKey,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const NotificationsScreen(),
                    ),
                  ),
                  child: const Text('Open notifications'),
                ),
              ),
            ),
          ),
        ),
      );
}

class _NotificationFixture {
  _NotificationFixture()
    : repository = _NotificationRepository(),
      realtime = _NotificationRealtime() {
    controller = NotificationController(
      repository: repository,
      realtime: realtime,
    );
  }

  final _NotificationRepository repository;
  final _NotificationRealtime realtime;
  late final NotificationController controller;

  void dispose() => controller.dispose();
}

class _NotificationRepository implements NotificationRepositoryContract {
  int listCalls = 0;
  int unreadCountValue = 1;

  @override
  Future<NotificationPage> list({int page = 0, int pageSize = 20}) async {
    listCalls++;
    return NotificationPage(
      items: page == 0 ? [_notification] : const [],
      page: page,
      pageSize: pageSize,
      totalElements: 1,
      unreadCount: unreadCountValue,
    );
  }

  @override
  Future<int> unreadCount() async => unreadCountValue;

  @override
  Future<void> markRead(String id) async {}

  @override
  Future<int> markAllRead() async => 0;
}

class _NotificationRealtime implements ScheduledCareRealtime {
  NotificationInvalidationCallback? _onNotification;
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
    notificationDisconnected = false;
    _onNotification = onEvent;
  }

  void emit() {
    _onNotification?.call(
      NotificationInvalidation.fromJson({
        'eventType': 'NOTIFICATION_CREATED',
        'notificationId': 'notification-2',
        'occurredAt': '2026-10-09T10:01:00Z',
      }),
    );
  }

  @override
  void disconnectNotifications() {
    notificationDisconnected = true;
    _onNotification = null;
  }

  @override
  void disconnect() {}
}

final _notification = InboxNotification.fromJson({
  'id': 'notification-1',
  'type': 'APPOINTMENT_CONFIRMED',
  'priority': 'HIGH',
  'category': 'APPOINTMENT',
  'titleFr': 'Rendez-vous confirmé',
  'bodyFr': 'Votre rendez-vous est confirmé.',
  'titleAr': null,
  'bodyAr': null,
  'deepLinkPayload': const <String, Object?>{},
  'read': false,
  'createdAt': '2026-10-09T10:00:00Z',
});
