import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/core/theme/omni_theme.dart';
import 'package:omnicare_mobile/features/doctor/demo/doctor_demo_profile.dart';
import 'package:omnicare_mobile/features/doctor/shell/doctor_app_shell.dart';
import 'package:omnicare_mobile/features/doctor/urgent/doctor_urgent_controller.dart';
import 'package:omnicare_mobile/features/doctor/workspace/doctor_workspace_config.dart';

void main() {
  Widget buildSubject({
    Future<void> Function()? onLogout,
    DoctorUrgentController? urgentController,
  }) {
    return MaterialApp(
      theme: buildOmniTheme(),
      home: DoctorAppShell(
        profile: DoctorDemoProfile.current,
        onLogout: onLogout ?? () async {},
        workspaceConfig: _hybridWorkspace(),
        urgentController: urgentController,
      ),
    );
  }

  testWidgets('Doctor shell keeps navigation fixed and switches tabs', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildSubject());

    expect(find.text('Bonjour Dr Mansour'), findsOneWidget);
    expect(find.byKey(const ValueKey('doctor-top-bar')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('doctor-bottom-navigation')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Agenda'));
    await tester.pumpAndSettle();
    expect(find.text('Agenda'), findsWidgets);
    expect(find.byKey(const ValueKey('doctor-top-bar')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('doctor-bottom-navigation')),
      findsOneWidget,
    );

    await tester.tap(find.text('Urgences'));
    await tester.pumpAndSettle();
    expect(find.text('Urgences'), findsNWidgets(2));

    await tester.tap(find.byKey(DoctorAppShell.profileTabKey));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('doctor-logout-button')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('D0 Doctor logout remains available only from Profil', (
    tester,
  ) async {
    var logoutCalls = 0;
    await tester.pumpWidget(
      buildSubject(
        onLogout: () async {
          logoutCalls += 1;
        },
      ),
    );

    expect(find.byKey(const ValueKey('doctor-logout-button')), findsNothing);
    await tester.tap(find.byKey(DoctorAppShell.profileTabKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('doctor-logout-button')));
    await tester.pumpAndSettle();

    expect(logoutCalls, 1);
  });

  testWidgets('D0 Doctor shell fits supported phone dimensions', (
    tester,
  ) async {
    const sizes = <Size>[
      Size(360, 700),
      Size(390, 844),
      Size(430, 932),
      Size(360, 568),
    ];
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final size in sizes) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      final navigation = tester.getRect(
        find.byKey(const ValueKey('doctor-bottom-navigation')),
      );
      expect(navigation.left, 0);
      expect(navigation.right, size.width);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('EN_ROUTE arrival CTA scrolls above the fixed navigation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final urgent = DoctorUrgentController();
    addTearDown(urgent.dispose);

    await tester.pumpWidget(buildSubject(urgentController: urgent));
    await tester.tap(find.text('Urgences'));
    await tester.pumpAndSettle();
    urgent.goOnline();
    urgent.showOffer();
    urgent.accept();
    urgent.simulateSelection();
    urgent.startRoute();
    await tester.pump(const Duration(milliseconds: 250));

    final arrived = find.text('Je suis arrivé');
    await tester.scrollUntilVisible(arrived, 180);
    final arrivalButton = tester.getRect(arrived);
    final navigation = tester.getRect(
      find.byKey(const ValueKey('doctor-bottom-navigation')),
    );
    expect(arrivalButton.bottom, lessThanOrEqualTo(navigation.top));
    expect(tester.takeException(), isNull);
  });

  testWidgets('urgent QR and medical record stay inside the Doctor shell', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final urgent = DoctorUrgentController();
    addTearDown(urgent.dispose);

    await tester.pumpWidget(buildSubject(urgentController: urgent));
    await tester.tap(find.byKey(const ValueKey('doctor-tab-urgent')));
    await tester.pumpAndSettle();
    urgent.goOnline();
    urgent.showOffer();
    urgent.accept();
    urgent.simulateSelection();
    urgent.startRoute();
    urgent.arrive();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Scanner le QR du patient'));
    await tester.pumpAndSettle();
    _expectUrgentShell(tester);
    expect(find.text('Scanner le QR'), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'QR page');

    final simulateQr = find.text('Simuler un QR valide');
    await tester.scrollUntilVisible(simulateQr, 160);
    await tester.tap(simulateQr);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    final medicalRecord = find.text('Voir le dossier médical');
    await tester.scrollUntilVisible(medicalRecord, -160);
    await tester.tap(medicalRecord);
    await tester.pumpAndSettle();
    _expectUrgentShell(tester);
    expect(find.text('Dossier médical indisponible.'), findsOneWidget);
    expect(find.text('Informations essentielles'), findsNothing);
    expect(
      tester.takeException(),
      isNull,
      reason: 'medical record unavailable',
    );
  });
}

void _expectUrgentShell(WidgetTester tester) {
  expect(find.byKey(const ValueKey('doctor-top-bar')), findsOneWidget);
  expect(
    find.byKey(const ValueKey('doctor-bottom-navigation')),
    findsOneWidget,
  );
  final urgentTab = find.byKey(const ValueKey('doctor-tab-urgent'));
  expect(urgentTab, findsOneWidget);
  expect(
    tester.getSemantics(urgentTab).flagsCollection.isSelected,
    Tristate.isTrue,
  );
}

DoctorWorkspaceConfig _hybridWorkspace() => DoctorWorkspaceConfig(
  doctorId: 'doctor-a',
  onboardingCompleted: true,
  practiceModes: {
    DoctorPracticeMode.cabinet,
    DoctorPracticeMode.homeVisit,
    DoctorPracticeMode.urgentHome,
  },
  services: {
    DoctorWorkspaceService.cabinetConsultations,
    DoctorWorkspaceService.patientFollowUp,
    DoctorWorkspaceService.appointments,
    DoctorWorkspaceService.homeVisits,
    DoctorWorkspaceService.urgentHomeVisits,
  },
  cabinet: const DoctorCabinetConfig(
    name: 'Cabinet Mansour',
    governorate: 'Tunis',
    city: 'Carthage',
    address: '12 avenue de la République',
  ),
  clinics: const [],
  homeVisit: const DoctorHomeVisitConfig(
    governorate: 'Tunis',
    availableForHomeVisits: true,
  ),
  availability: const DoctorAvailability(
    workingDays: {DoctorWorkingDay.monday},
    startTime: '08:00',
    endTime: '17:00',
  ),
);
