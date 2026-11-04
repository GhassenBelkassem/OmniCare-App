import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/core/theme/omni_theme.dart';
import 'package:omnicare_mobile/features/doctor/demo/doctor_demo_profile.dart';
import 'package:omnicare_mobile/features/doctor/shell/doctor_app_shell.dart';
import 'package:omnicare_mobile/features/doctor/urgent/doctor_urgent_controller.dart';
import 'package:omnicare_mobile/features/doctor/workspace/doctor_workspace_config.dart';

DoctorWorkspaceConfig _workspace(
  String doctorId, {
  required bool home,
  required bool cabinet,
}) => DoctorWorkspaceConfig(
  doctorId: doctorId,
  onboardingCompleted: true,
  practiceModes: {
    if (home) DoctorPracticeMode.urgentHome,
    if (cabinet) DoctorPracticeMode.cabinet,
  },
  services: {
    if (home) DoctorWorkspaceService.urgentHomeVisits,
    if (cabinet) DoctorWorkspaceService.urgentCabinetConsultations,
  },
  cabinet: cabinet
      ? const DoctorCabinetConfig(
          name: 'Cabinet Mansour',
          governorate: 'Tunis',
          city: 'La Marsa',
          address: '1, rue de la Santé',
        )
      : null,
  clinics: const [],
  homeVisit: home
      ? const DoctorHomeVisitConfig(
          governorate: 'Tunis',
          availableForHomeVisits: true,
        )
      : null,
  availability: const DoctorAvailability(
    workingDays: {DoctorWorkingDay.monday},
    startTime: '08:00',
    endTime: '17:00',
  ),
);

Widget _shell(
  DoctorWorkspaceConfig config, {
  DoctorUrgentController? controller,
}) => MaterialApp(
  theme: buildOmniTheme(),
  home: DoctorAppShell(
    profile: DoctorDemoProfile.current,
    onLogout: () async {},
    workspaceConfig: config,
    urgentController: controller,
  ),
);

void main() {
  testWidgets('configuration matrix exposes at most one Urgences destination', (
    tester,
  ) async {
    final cases = [
      _workspace('home', home: true, cabinet: false),
      _workspace('cabinet', home: false, cabinet: true),
      _workspace('both', home: true, cabinet: true),
      _workspace('neither', home: false, cabinet: false),
    ];

    for (final config in cases) {
      await tester.pumpWidget(_shell(config));
      await tester.pumpAndSettle();
      final expected = config.doctorId == 'neither' ? 0 : 1;
      expect(
        find.byKey(const ValueKey('doctor-tab-urgent')),
        findsNWidgets(expected),
        reason: config.doctorId,
      );
    }
  });

  testWidgets(
    'CABINET-only opens CABINET directly and does not show HOME status',
    (tester) async {
      await tester.pumpWidget(
        _shell(_workspace('cabinet', home: false, cabinet: true)),
      );

      expect(find.text('Urgences à domicile'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('doctor-tab-urgent')));
      await tester.pumpAndSettle();

      expect(find.text('Urgences au cabinet'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('doctor-urgent-mode-selector')),
        findsNothing,
      );
      expect(find.byType(Switch), findsNothing);
    },
  );

  testWidgets('dual-mode selection survives bottom-tab changes', (
    tester,
  ) async {
    await tester.pumpWidget(
      _shell(_workspace('both', home: true, cabinet: true)),
    );
    await tester.tap(find.byKey(const ValueKey('doctor-tab-urgent')));
    await tester.pumpAndSettle();
    expect(
      find.text('Gérez vos demandes urgentes et visites à domicile.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('doctor-urgent-mode-cabinet')));
    await tester.pumpAndSettle();
    expect(find.text('Urgences au cabinet'), findsOneWidget);

    await tester.tap(find.byKey(DoctorAppShell.profileTabKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('doctor-tab-urgent')));
    await tester.pumpAndSettle();

    expect(find.text('Urgences au cabinet'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('doctor-urgent-mode-selector')),
      findsOneWidget,
    );
  });

  testWidgets('losing HOME falls back to CABINET and clears HOME subworkflow', (
    tester,
  ) async {
    final controller = DoctorUrgentController();
    addTearDown(controller.dispose);
    final dual = _workspace('doctor-a', home: true, cabinet: true);
    final cabinetOnly = _workspace('doctor-a', home: false, cabinet: true);
    await tester.pumpWidget(_shell(dual, controller: controller));
    await tester.tap(find.byKey(const ValueKey('doctor-tab-urgent')));
    await tester.pumpAndSettle();

    controller.goOnline();
    controller.showOffer();
    controller.accept();
    controller.simulateSelection();
    controller.startRoute();
    controller.arrive();
    await tester.pumpAndSettle();
    final openQr = find.text('Scanner le QR du patient');
    await tester.scrollUntilVisible(openQr, 180);
    await tester.tap(openQr);
    await tester.pumpAndSettle();
    expect(find.text('Scanner le QR'), findsOneWidget);

    await tester.pumpWidget(_shell(cabinetOnly, controller: controller));
    await tester.pumpAndSettle();

    expect(find.text('Scanner le QR'), findsNothing);
    expect(find.text('Urgences au cabinet'), findsOneWidget);
  });

  testWidgets('losing both urgent modes redirects safely to Accueil', (
    tester,
  ) async {
    final dual = _workspace('doctor-a', home: true, cabinet: true);
    final neither = _workspace('doctor-a', home: false, cabinet: false);
    await tester.pumpWidget(_shell(dual));
    await tester.tap(find.byKey(const ValueKey('doctor-tab-urgent')));
    await tester.pumpAndSettle();

    await tester.pumpWidget(_shell(neither));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('doctor-tab-urgent')), findsNothing);
    expect(find.text('Bonjour Dr Mansour'), findsOneWidget);
  });

  testWidgets('Doctor identity change resets shell-owned HOME urgent state', (
    tester,
  ) async {
    final doctorA = _workspace('doctor-a', home: true, cabinet: false);
    final doctorB = _workspace('doctor-b', home: true, cabinet: false);
    await tester.pumpWidget(_shell(doctorA));
    await tester.tap(find.byKey(const ValueKey('doctor-tab-urgent')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    expect(find.text('Disponible pour les urgences'), findsOneWidget);

    await tester.pumpWidget(_shell(doctorB));
    await tester.pumpAndSettle();

    expect(find.text('Hors ligne'), findsOneWidget);
    expect(find.text('Disponible pour les urgences'), findsNothing);
  });
}
