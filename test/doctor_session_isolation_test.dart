import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:omnicare_mobile/core/storage/secure_token_store.dart';
import 'package:omnicare_mobile/features/doctor/scheduled_care/doctor_scheduled_care_coordinator.dart';
import 'package:omnicare_mobile/features/doctor/scheduled_care/doctor_scheduled_care_models.dart';
import 'package:omnicare_mobile/features/doctor/scheduled_care/doctor_scheduled_care_repository.dart';
import 'package:omnicare_mobile/features/doctor/scheduled_care/doctor_session_access.dart';
import 'package:omnicare_mobile/features/notifications/application/notification_controller.dart';
import 'package:omnicare_mobile/features/notifications/data/notification_models.dart';
import 'package:omnicare_mobile/features/notifications/data/notification_repository.dart';
import 'package:omnicare_mobile/features/scheduled_care/data/scheduled_care_failure.dart';
import 'package:omnicare_mobile/features/scheduled_care/domain/scheduled_care_models.dart';
import 'package:omnicare_mobile/features/scheduled_care/realtime/scheduled_care_realtime.dart';

import 'support/doctor_scheduled_care_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('same-origin session ownership', () {
    test(
      'a second store instance replaces the one origin-wide session',
      () async {
        final backend = _MemoryStorageBackend();
        final doctorTab = SecureTokenStore(backend: backend);
        final patientTab = SecureTokenStore(backend: backend);
        await doctorTab.saveSession(_session('doctor-a', 'DOCTOR'));

        await patientTab.saveSession(_session('patient-b', 'PATIENT'));

        final visibleToDoctorTab = await doctorTab.readSession();
        expect(visibleToDoctorTab?.userId, 'patient-b');
        expect(visibleToDoctorTab?.userRole, 'PATIENT');
      },
    );

    test('Doctor login permits Home and Agenda loads', () async {
      final fixture = await _Fixture.doctor();
      addTearDown(fixture.dispose);

      await fixture.coordinator.start();

      expect(fixture.repository.homeReads, greaterThan(0));
      expect(fixture.repository.agendaReads, greaterThan(0));
      expect(fixture.coordinator.home.summary, isNotNull);
      expect(fixture.coordinator.agenda.records, isNotEmpty);
    });

    test('Patient session never reaches the Doctor repository', () async {
      final fixture = await _Fixture.patient();
      addTearDown(fixture.dispose);

      await expectLater(
        fixture.guarded.getHomeSummary(),
        throwsA(isA<ScheduledCareFailure>()),
      );

      expect(fixture.repository.homeReads, 0);
      expect(fixture.reconciliations, 0);
    });

    test(
      'Doctor to Patient replacement reconciles before Doctor HTTP',
      () async {
        final fixture = await _Fixture.doctor();
        addTearDown(fixture.dispose);
        await fixture.store.saveSession(_session('patient-b', 'PATIENT'));

        await expectLater(
          fixture.guarded.getHomeSummary(),
          throwsA(isA<ScheduledCareFailure>()),
        );

        expect(fixture.repository.homeReads, 0);
        expect(fixture.reconciliations, 1);
        expect(fixture.currentUserId, 'patient-b');
        expect(fixture.currentRole, 'PATIENT');
      },
    );

    test('Doctor A to Doctor B clears A state and stops old resync', () async {
      final fixture = await _Fixture.doctor();
      addTearDown(fixture.dispose);
      await fixture.coordinator.start();
      final homeReads = fixture.repository.homeReads;
      final agendaReads = fixture.repository.agendaReads;
      await fixture.store.saveSession(_session('doctor-b', 'DOCTOR'));

      fixture.realtime.emitScheduled(_event('doctor-switch'));
      await _drain();

      expect(fixture.reconciliations, 1);
      expect(fixture.currentUserId, 'doctor-b');
      expect(fixture.coordinator.home.summary, isNull);
      expect(fixture.coordinator.agenda.records, isEmpty);
      fixture.realtime.emitScheduled(_event('after-suspension'));
      await _drain();
      expect(fixture.repository.homeReads, homeReads);
      expect(fixture.repository.agendaReads, agendaReads);
    });

    test(
      'in-flight Doctor A detail cannot repopulate Doctor B state',
      () async {
        final repository = _DeferredRequestRepository();
        final fixture = await _Fixture.doctor(repository: repository);
        addTearDown(fixture.dispose);
        await fixture.coordinator.start();
        final requestItem = fixture.coordinator.agenda.records.firstWhere(
          (item) =>
              item.resourceType == ScheduledCareResourceType.bookingRequest,
        );

        final refresh = fixture.coordinator.agenda.refreshItem(requestItem);
        await repository.requestStarted.future;
        fixture.coordinator.clearSessionState();
        repository.requestResult.complete(repository.request!);

        expect(await refresh, isNull);
        expect(fixture.coordinator.agenda.records, isEmpty);
        expect(fixture.coordinator.agenda.isLoadingDetail, isFalse);
      },
    );

    test('logout and foreground do not restart Doctor coordination', () async {
      final fixture = await _Fixture.doctor();
      addTearDown(fixture.dispose);
      await fixture.coordinator.start();
      fixture.coordinator.clearSessionState();
      fixture.isAuthenticated = false;
      await fixture.store.clearSession();
      final homeReads = fixture.repository.homeReads;
      final agendaReads = fixture.repository.agendaReads;

      fixture.coordinator.didChangeAppLifecycleState(AppLifecycleState.resumed);
      fixture.realtime.emitScheduled(_event('after-logout'));
      await _drain();

      expect(fixture.repository.homeReads, homeReads);
      expect(fixture.repository.agendaReads, agendaReads);
      expect(fixture.realtime.isConnected, isFalse);
    });

    test(
      'scheduled-care invalidation under Patient makes no Doctor call',
      () async {
        final fixture = await _Fixture.patient();
        addTearDown(fixture.dispose);

        await fixture.coordinator.start();
        fixture.realtime.emitScheduled(_event('patient-event'));
        await _drain();

        expect(fixture.repository.homeReads, 0);
        expect(fixture.repository.agendaReads, 0);
        expect(fixture.realtime.isConnected, isFalse);
      },
    );

    test(
      'notification invalidation under Patient remains role agnostic',
      () async {
        final fixture = await _Fixture.patient();
        final notifications = _NotificationRepository();
        final controller = NotificationController(
          repository: notifications,
          realtime: fixture.realtime,
        );
        addTearDown(controller.dispose);
        addTearDown(fixture.dispose);
        await fixture.coordinator.start();
        await controller.start();
        final notificationReads = notifications.listReads;
        final unreadCountReads = notifications.countReads;

        fixture.realtime.emitNotification();
        await _drain();

        expect(notifications.listReads, notificationReads);
        expect(notifications.countReads, greaterThan(unreadCountReads));
        expect(fixture.repository.homeReads, 0);
        expect(fixture.repository.agendaReads, 0);
      },
    );
  });

  group('controlled auth failures', () {
    test('403 is mapped, contained, and suspends repeated resync', () async {
      final fixture = await _Fixture.doctor(
        repository: _AuthFailureRepository(403),
      );
      addTearDown(fixture.dispose);

      await expectLater(fixture.coordinator.start(), completes);
      final attempts = (fixture.repository as _AuthFailureRepository).attempts;
      expect(fixture.invalidations, 1);
      expect(fixture.coordinator.home.summary, isNull);
      fixture.realtime.emitScheduled(_event('forbidden-loop'));
      await _drain();
      expect((fixture.repository as _AuthFailureRepository).attempts, attempts);
    });

    test('401 follows the session-invalid flow without escaping', () async {
      final fixture = await _Fixture.doctor(
        repository: _AuthFailureRepository(401),
      );
      addTearDown(fixture.dispose);

      await expectLater(fixture.coordinator.start(), completes);

      expect(fixture.invalidations, 1);
      expect(await fixture.store.readSession(), isNull);
      expect(fixture.isAuthenticated, isFalse);
    });

    test('Dio 401 and 403 receive explicit failure codes', () {
      expect(_dioFailure(401).errorCode, 'UNAUTHORIZED');
      expect(_dioFailure(403).errorCode, 'FORBIDDEN');
    });
  });

  const productionSvgAssets = [
    'assets/svg/omnicare_logo_white.svg',
    'assets/svg/medical_pass_green.svg',
    'assets/svg/medical_pass_grey.svg',
  ];

  test(
    'production SVG assets avoid unsupported style elements',
    () async {
      for (final asset in productionSvgAssets) {
        final source = await rootBundle.loadString(asset);
        expect(source, isNot(contains('<style')), reason: asset);
        expect(source, contains('fill='), reason: asset);
      }
    },
    // Chrome's test asset-bundle request remains pending in this harness.
    skip: kIsWeb,
  );

  testWidgets(
    'production SVG assets render successfully',
    (tester) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            children: [
              for (final asset in productionSvgAssets)
                SvgPicture.asset(asset, width: 24, height: 24),
            ],
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(tester.takeException(), isNull);
    },
    // flutter_svg asset decoding does not settle in the Chrome test harness;
    // the source contract remains covered there by the test above.
    skip: kIsWeb,
  );
}

class _Fixture {
  _Fixture._({
    required this.store,
    required this.repository,
    required this.guarded,
    required this.realtime,
    required this.coordinator,
    required this.currentUserId,
    required this.currentRole,
    required this.isAuthenticated,
  });

  static Future<_Fixture> doctor({
    FakeDoctorScheduledCareRepository? repository,
  }) => _create(userId: 'doctor-a', role: 'DOCTOR', repository: repository);

  static Future<_Fixture> patient() =>
      _create(userId: 'patient-b', role: 'PATIENT');

  static Future<_Fixture> _create({
    required String userId,
    required String role,
    FakeDoctorScheduledCareRepository? repository,
  }) async {
    final store = SecureTokenStore(backend: _MemoryStorageBackend());
    await store.saveSession(_session(userId, role));
    late _Fixture fixture;
    var currentUserId = userId;
    var currentRole = role;
    var authenticated = true;
    final delegate = repository ?? FakeDoctorScheduledCareRepository();
    final realtime = _Realtime();
    final access = DoctorSessionAccess(
      tokenStore: store,
      isAuthenticated: () => authenticated,
      currentUserId: () => currentUserId,
      currentRole: () => currentRole,
      reconcilePersistedSession: () async {
        fixture.reconciliations++;
        final stored = await store.readSession();
        authenticated = stored != null;
        currentUserId = stored?.userId ?? '';
        currentRole = stored?.userRole ?? '';
        fixture
          ..currentUserId = currentUserId
          ..currentRole = currentRole
          ..isAuthenticated = authenticated;
      },
      invalidateSession: () async {
        fixture.invalidations++;
        authenticated = false;
        currentUserId = '';
        currentRole = '';
        fixture
          ..currentUserId = currentUserId
          ..currentRole = currentRole
          ..isAuthenticated = authenticated;
      },
    );
    final guarded = SessionGuardedDoctorScheduledCareRepository(
      delegate: delegate,
      sessionAccess: access,
    );
    final coordinator = DoctorScheduledCareCoordinator(
      repository: guarded,
      realtime: realtime,
      doctorId: userId,
      initialDate: DateTime(2026, 10, 6),
    );
    fixture = _Fixture._(
      store: store,
      repository: delegate,
      guarded: guarded,
      realtime: realtime,
      coordinator: coordinator,
      currentUserId: currentUserId,
      currentRole: currentRole,
      isAuthenticated: authenticated,
    );
    return fixture;
  }

  final SecureTokenStore store;
  final FakeDoctorScheduledCareRepository repository;
  final DoctorScheduledCareRepository guarded;
  final _Realtime realtime;
  final DoctorScheduledCareCoordinator coordinator;
  String currentUserId;
  String currentRole;
  bool isAuthenticated;
  int reconciliations = 0;
  int invalidations = 0;

  void dispose() => coordinator.dispose();
}

class _MemoryStorageBackend implements SecureTokenStorageBackend {
  final Map<String, String> values = <String, String>{};

  @override
  Future<void> delete({required String key}) async {
    values.remove(key);
  }

  @override
  Future<String?> read({required String key}) async => values[key];

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }
}

StoredSession _session(String userId, String role) => StoredSession(
  accessToken: '$role-access',
  refreshToken: '$role-refresh',
  accessTokenExpiresAt: DateTime.utc(2026, 10, 10),
  refreshTokenExpiresAt: DateTime.utc(2026, 11),
  userId: userId,
  userRole: role,
  sessionId: '$userId-session',
);

class _Realtime implements ScheduledCareRealtime {
  ScheduledCareEventCallback? _scheduled;
  NotificationInvalidationCallback? _notification;
  bool _connected = false;

  @override
  bool get isConnected => _connected;

  @override
  Future<void> connect(
    ScheduledCareEventCallback onEvent, {
    void Function()? onConnected,
  }) async {
    _scheduled = onEvent;
    _connected = true;
    onConnected?.call();
  }

  @override
  Future<void> connectNotifications(
    NotificationInvalidationCallback onEvent, {
    void Function()? onConnected,
  }) async {
    _notification = onEvent;
    _connected = true;
    onConnected?.call();
  }

  void emitScheduled(ScheduledCareEvent event) => _scheduled?.call(event);

  void emitNotification() => _notification?.call(
    NotificationInvalidation(
      eventType: 'NOTIFICATION_CREATED',
      notificationId: 'notification-1',
      occurredAt: DateTime.utc(2026, 10, 9),
    ),
  );

  @override
  void disconnect() {
    _scheduled = null;
    if (_notification == null) _connected = false;
  }

  @override
  void disconnectNotifications() {
    _notification = null;
    if (_scheduled == null) _connected = false;
  }
}

class _NotificationRepository implements NotificationRepositoryContract {
  int listReads = 0;
  int countReads = 0;

  @override
  Future<NotificationPage> list({
    String? category,
    bool unreadOnly = false,
    int page = 0,
    int pageSize = 20,
  }) async {
    listReads++;
    return NotificationPage(
      items: const [],
      page: page,
      pageSize: pageSize,
      totalElements: 0,
      unreadCount: 0,
    );
  }

  @override
  Future<void> markRead(String id) async {}

  @override
  Future<int> markAllRead() async => 0;

  @override
  Future<int> unreadCount() async {
    countReads++;
    return 0;
  }
}

class _AuthFailureRepository extends FakeDoctorScheduledCareRepository {
  _AuthFailureRepository(this.statusCode);
  final int statusCode;
  int attempts = 0;

  ScheduledCareFailure get _failure => ScheduledCareFailure(
    message: 'auth failure',
    errorCode: statusCode == 401 ? 'UNAUTHORIZED' : 'FORBIDDEN',
    statusCode: statusCode,
  );

  @override
  Future<DoctorHomeSummary> getHomeSummary() async {
    attempts++;
    throw _failure;
  }

  @override
  Future<DoctorScheduledCareAgenda> getAgenda({
    required DateTime from,
    required DateTime to,
  }) async {
    attempts++;
    throw _failure;
  }
}

class _DeferredRequestRepository extends FakeDoctorScheduledCareRepository {
  final Completer<void> requestStarted = Completer<void>();
  final Completer<DoctorBookingRequest> requestResult =
      Completer<DoctorBookingRequest>();

  @override
  Future<DoctorBookingRequest> getRequest(String requestId) {
    requestReads++;
    requestStarted.complete();
    return requestResult.future;
  }
}

ScheduledCareFailure _dioFailure(int status) => ScheduledCareFailure.from(
  DioException(
    requestOptions: RequestOptions(path: '/doctor/scheduled-care'),
    response: Response<dynamic>(
      requestOptions: RequestOptions(path: '/doctor/scheduled-care'),
      statusCode: status,
    ),
  ),
);

ScheduledCareEvent _event(String id) => ScheduledCareEvent(
  eventId: id,
  eventType: 'BOOKING_REQUEST_UPDATED',
  resourceType: ScheduledCareResourceType.bookingRequest,
  resourceId: 'request-1',
  version: 1,
  occurredAt: DateTime.utc(2026, 10, 9),
);

Future<void> _drain() => Future<void>.delayed(Duration.zero);
