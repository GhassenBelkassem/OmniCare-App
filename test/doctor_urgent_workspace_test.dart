import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/core/theme/omni_theme.dart';
import 'package:omnicare_mobile/features/doctor/urgent/doctor_urgent_controller.dart';
import 'package:omnicare_mobile/features/doctor/urgent/doctor_urgent_workspace_screen.dart';
import 'package:omnicare_mobile/features/doctor/urgent_cabinet/doctor_urgent_cabinet_controller.dart';
import 'package:omnicare_mobile/features/doctor/workspace/doctor_workspace_config.dart';

DoctorWorkspaceConfig _workspace({
  required Set<DoctorPracticeMode> modes,
  required Set<DoctorWorkspaceService> services,
  DoctorCabinetConfig? cabinet,
}) => DoctorWorkspaceConfig(
  doctorId: 'doctor-workspace-test',
  onboardingCompleted: true,
  practiceModes: modes,
  services: services,
  cabinet: cabinet,
  clinics: const [],
  homeVisit: modes.contains(DoctorPracticeMode.urgentHome)
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

const _cabinet = DoctorCabinetConfig(
  name: 'Cabinet Mansour',
  governorate: 'Tunis',
  city: 'La Marsa',
  address: '1, rue de la Santé',
);

Widget _subject({
  required DoctorWorkspaceConfig config,
  required DoctorUrgentController controller,
  required DoctorUrgentMode selectedMode,
  required ValueChanged<DoctorUrgentMode> onModeChanged,
  String? homeOperationalMessage,
  String? cabinetOperationalMessage,
}) {
  final cabinetController = DoctorUrgentCabinetController()
    ..configure(
      authenticatedDoctorId: config.doctorId,
      workspaceConfig: config,
    );
  return MaterialApp(
    theme: buildOmniTheme(),
    home: Scaffold(
      body: DoctorUrgentWorkspaceScreen(
        capabilities: deriveDoctorCapabilities(config),
        workspaceConfig: config,
        selectedMode: selectedMode,
        onModeChanged: onModeChanged,
        homeController: controller,
        urgentCabinetController: cabinetController,
        homeOperationalMessage: homeOperationalMessage,
        cabinetOperationalMessage: cabinetOperationalMessage,
      ),
    ),
  );
}

void main() {
  testWidgets('HOME-only renders the frozen HOME screen without a selector', (
    tester,
  ) async {
    final controller = DoctorUrgentController();
    addTearDown(controller.dispose);
    final config = _workspace(
      modes: {DoctorPracticeMode.urgentHome},
      services: {DoctorWorkspaceService.urgentHomeVisits},
    );

    await tester.pumpWidget(
      _subject(
        config: config,
        controller: controller,
        selectedMode: DoctorUrgentMode.home,
        onModeChanged: (_) {},
      ),
    );

    expect(
      find.text('Gérez vos demandes urgentes et visites à domicile.'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('doctor-urgent-mode-selector')),
      findsNothing,
    );
    expect(find.text('Urgences au cabinet'), findsNothing);
  });

  testWidgets('CABINET-only renders its local empty state without a selector', (
    tester,
  ) async {
    final controller = DoctorUrgentController();
    addTearDown(controller.dispose);
    final config = _workspace(
      modes: {DoctorPracticeMode.cabinet},
      services: {DoctorWorkspaceService.urgentCabinetConsultations},
      cabinet: _cabinet,
    );

    await tester.pumpWidget(
      _subject(
        config: config,
        controller: controller,
        selectedMode: DoctorUrgentMode.home,
        onModeChanged: (_) {},
      ),
    );

    expect(find.text('Urgences au cabinet'), findsOneWidget);
    expect(find.text('Cabinet Mansour'), findsOneWidget);
    expect(find.text('Aucune demande urgente au cabinet'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('doctor-urgent-mode-selector')),
      findsNothing,
    );
    expect(find.byType(Switch), findsNothing);
  });

  testWidgets(
    'dual mode switches visible content without resetting HOME state',
    (tester) async {
      final controller = DoctorUrgentController()..goOnline();
      addTearDown(controller.dispose);
      final config = _workspace(
        modes: {DoctorPracticeMode.cabinet, DoctorPracticeMode.urgentHome},
        services: {
          DoctorWorkspaceService.urgentHomeVisits,
          DoctorWorkspaceService.urgentCabinetConsultations,
        },
        cabinet: _cabinet,
      );
      var selected = DoctorUrgentMode.home;

      Widget build() => _subject(
        config: config,
        controller: controller,
        selectedMode: selected,
        onModeChanged: (mode) {
          selected = mode;
        },
      );

      await tester.pumpWidget(build());
      expect(
        find.byKey(const ValueKey('doctor-urgent-mode-selector')),
        findsOneWidget,
      );
      expect(find.text('Disponible pour les urgences'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('doctor-urgent-mode-cabinet')),
      );
      await tester.pumpWidget(build());
      await tester.pumpAndSettle();
      expect(find.text('Urgences au cabinet'), findsOneWidget);
      expect(controller.state, DoctorUrgentState.available);

      await tester.tap(find.byKey(const ValueKey('doctor-urgent-mode-home')));
      await tester.pumpWidget(build());
      await tester.pumpAndSettle();
      expect(find.text('Disponible pour les urgences'), findsOneWidget);
      expect(controller.state, DoctorUrgentState.available);
    },
  );

  testWidgets('missing cabinet shows a configuration warning', (tester) async {
    final controller = DoctorUrgentController();
    addTearDown(controller.dispose);
    final config = _workspace(
      modes: const {},
      services: {DoctorWorkspaceService.urgentCabinetConsultations},
    );

    await tester.pumpWidget(
      _subject(
        config: config,
        controller: controller,
        selectedMode: DoctorUrgentMode.cabinet,
        onModeChanged: (_) {},
      ),
    );

    expect(find.text('Configuration du cabinet requise'), findsOneWidget);
    expect(find.text('Cabinet Mansour'), findsNothing);
  });

  testWidgets(
    'backend gate keeps configured HOME visible but non-operational',
    (tester) async {
      final controller = DoctorUrgentController();
      addTearDown(controller.dispose);
      final config = _workspace(
        modes: {DoctorPracticeMode.urgentHome},
        services: {DoctorWorkspaceService.urgentHomeVisits},
      );

      await tester.pumpWidget(
        _subject(
          config: config,
          controller: controller,
          selectedMode: DoctorUrgentMode.home,
          onModeChanged: (_) {},
          homeOperationalMessage:
              'La disponibilité HOME est désactivée côté serveur.',
        ),
      );

      expect(find.text('Urgences à domicile'), findsOneWidget);
      expect(
        find.text('Actions opérationnelles indisponibles'),
        findsOneWidget,
      );
      expect(find.byType(Switch), findsNothing);
      expect(find.text('Passer en ligne'), findsNothing);
      expect(controller.state, DoctorUrgentState.offline);
    },
  );

  testWidgets(
    'selector and CABINET layout fit supported widths and large text',
    (tester) async {
      final controller = DoctorUrgentController();
      addTearDown(controller.dispose);
      final config = _workspace(
        modes: {DoctorPracticeMode.cabinet, DoctorPracticeMode.urgentHome},
        services: {
          DoctorWorkspaceService.urgentHomeVisits,
          DoctorWorkspaceService.urgentCabinetConsultations,
        },
        cabinet: _cabinet,
      );
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (final width in [320.0, 360.0, 390.0, 430.0]) {
        tester.view.physicalSize = Size(width, 700);
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(
              textScaler: TextScaler.linear(1.8),
              disableAnimations: true,
            ),
            child: _subject(
              config: config,
              controller: controller,
              selectedMode: DoctorUrgentMode.cabinet,
              onModeChanged: (_) {},
            ),
          ),
        );
        await tester.pump();
        expect(
          find.byKey(const ValueKey('doctor-urgent-mode-selector')),
          findsOneWidget,
        );
        expect(find.text('Urgences au cabinet'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'width $width');
      }

      expect(
        tester
            .getSemantics(
              find.byKey(const ValueKey('doctor-urgent-mode-cabinet')),
            )
            .flagsCollection
            .isSelected,
        Tristate.isTrue,
      );
    },
  );
}
