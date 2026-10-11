import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('P4 feature imports no forbidden production dependency', () {
    final feature = Directory('lib/features/urgent_journey');
    final dartFiles = feature
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'));
    final importLines = dartFiles
        .expand((file) => file.readAsLinesSync())
        .where((line) => line.trimLeft().startsWith('import '))
        .join('\n')
        .toLowerCase();

    for (final forbidden in const [
      'consultations_api',
      'scheduled_care',
      'consultation_qr',
      'medical_record',
      '/mrs/',
      'notification_service',
      'realtime',
      'urgentrequest',
      'urgent_request_api',
      'geolocator',
      'geocoding',
      'google_maps',
      'places',
      'package:http',
      'dio',
    ]) {
      expect(importLines, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('coordinator contains no navigation into prohibited continuations', () {
    final coordinator = File(
      'lib/features/urgent_journey/presentation/'
      'p4_urgent_journey_coordinator.dart',
    ).readAsStringSync();

    expect(coordinator, isNot(contains('pushNamed')));
    expect(coordinator, isNot(contains('ConsultationsApi')));
    expect(coordinator, isNot(contains('DoctorCabinetEntryScreen')));
    expect(coordinator, isNot(contains('ConsultationQRScreen')));
    expect(coordinator, isNot(contains('Image.network')));
    expect(coordinator, contains('EmergencyRequestStep1('));
    expect(coordinator, contains('EmergencyRequestStep2('));
    expect(coordinator, contains('EmergencyRequestStep3('));
    expect(coordinator, contains('EmergencyReviewScreen('));
    expect(coordinator, isNot(contains('P4HomeDestinationScreen(')));
    expect(coordinator, isNot(contains('P4AttemptSetupReviewScreen(')));
  });

  test('HOME presentation adapter never instantiates production location', () {
    final adapter = File(
      'lib/features/emergency/'
      'p4_synthetic_emergency_location_adapter.dart',
    ).readAsStringSync();

    for (final forbidden in const [
      'DeviceEmergencyLocationGateway(',
      'AndroidEmergencyPlacesGateway(',
      'Geolocator.',
      'placemarkFromCoordinates(',
      'locationFromAddress(',
      'MethodChannel(',
    ]) {
      expect(adapter, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('global and nested navigators delegate urgent routes to one owner', () {
    final global = File('lib/main.dart').readAsStringSync();
    final nested = File(
      'lib/features/home/new_home_screen.dart',
    ).readAsStringSync();

    for (final source in [global, nested]) {
      expect(source, contains('P4UrgentRouteOwner.buildPage(settings)'));
      expect(source, isNot(contains('EmergencyRequestStep2(')));
      expect(source, isNot(contains('DoctorSelectionScreen(')));
      expect(source, isNot(contains('ReviewConfirmScreen(')));
      expect(source, isNot(contains('ConsultationQRScreen(')));
      expect(source, isNot(contains('ConsultationCompleteScreen(')));
    }
  });

  test('scheduled-care directory remains available only on its M05 route', () {
    final global = File('lib/main.dart').readAsStringSync();
    final nested = File(
      'lib/features/home/new_home_screen.dart',
    ).readAsStringSync();

    expect(global, contains("'/m05/doctor-directory'"));
    expect(nested, contains("'/m05/doctor-directory'"));
    expect(global, isNot(contains("'/doctor/cabinet/who-needs-care':")));
    expect(nested, isNot(contains("'/doctor/cabinet/who-needs-care' =>")));
  });
}
