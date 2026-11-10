import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Phase 3 lifecycle and stable-route boundary', () {
    test('clinic receipt is opaque, owner-scoped, and GET-first', () {
      final store = File(
        'lib/features/request_core/identity/in_flight_request_store.dart',
      ).readAsStringSync();
      final controller = File(
        'lib/features/request_core/application/request_submission_controller.dart',
      ).readAsStringSync();

      expect(store, contains("static const int schemaVersion = 3"));
      expect(store, contains("'accountScope'"));
      expect(store, contains("'createdAt'"));
      expect(store, contains("'dispatchState'"));
      expect(store, isNot(contains("'pickup'")));
      expect(store, isNot(contains("'situation'")));
      expect(store, isNot(contains('PickupLocationSelection')));
      expect(controller, contains('_repository.getRequest('));
      expect(controller, contains('recoverAfterAuthentication'));
      expect(controller, contains('recoveryPersistenceUnavailable'));
    });

    test('flow entry and Doctor entry cannot erase unresolved clinic work', () {
      final patientEntry = File(
        'lib/features/request_flow/screens/request_flow_entry_screen.dart',
      ).readAsStringSync();
      final doctorEntry = File(
        'lib/features/request_flow/screens/doctor_cabinet_entry_screen.dart',
      ).readAsStringSync();

      expect(patientEntry, contains('!request.hasUnresolvedOperation'));
      expect(doctorEntry, isNot(contains('beginNewRequest')));
      expect(doctorEntry, isNot(contains('RequestSubmissionController')));
    });

    test('critical stable-ID route casts fail closed', () {
      final home = File(
        'lib/features/home/new_home_screen.dart',
      ).readAsStringSync();
      final task = File(
        'lib/features/clinic/screens/clinic_task_detail_screen.dart',
      ).readAsStringSync();

      final doctorRoute = home.substring(
        home.indexOf("settings.name == '/m05/doctor-detail'"),
        home.indexOf('// Static routes'),
      );
      expect(doctorRoute, contains('args is String'));
      expect(doctorRoute, isNot(contains('as String')));
      expect(doctorRoute, contains('_InvalidDoctorDetailRouteScreen'));
      expect(task, contains('if (_taskId == null)'));
      expect(task, contains('_InvalidTaskRouteScreen'));
    });

    test('cold notification entry retains opaque identity until auth', () {
      final service = File(
        'lib/services/notification_service.dart',
      ).readAsStringSync();
      final push = File(
        'lib/features/notifications/push/notification_push_coordinator.dart',
      ).readAsStringSync();
      final resolver = File(
        'lib/features/notifications/application/notification_navigation_resolver.dart',
      ).readAsStringSync();

      expect(service, contains('getNotificationAppLaunchDetails'));
      expect(service, contains('PendingNotificationOpenIdentity'));
      expect(push, contains('_alerts.openPayload('));
      expect(resolver, contains('parsePendingPayload'));
      expect(resolver, contains('resolvePending'));
      expect(resolver, isNot(contains('title;')));
      expect(resolver, isNot(contains('body;')));
    });

    test('Urgent HOME remains behind the existing fail-closed boundary', () {
      final mainSource = File('lib/main.dart').readAsStringSync();
      expect(
        mainSource,
        contains("'/doctor-selection',\n                '/review-confirm'"),
      );
      expect(mainSource, contains('ClinicalFeatureUnavailableScreen'));
    });
  });
}
