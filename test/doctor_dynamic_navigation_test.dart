import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/core/theme/omni_theme.dart';
import 'package:omnicare_mobile/features/doctor/demo/doctor_demo_profile.dart';
import 'package:omnicare_mobile/features/doctor/shell/doctor_app_shell.dart';
import 'package:omnicare_mobile/features/doctor/shell/doctor_navigation_destination.dart';
import 'package:omnicare_mobile/features/doctor/workspace/doctor_workspace_config.dart';

DoctorWorkspaceConfig _workspace(
  String doctorId,
  Set<DoctorPracticeMode> modes,
) {
  final hasCabinet = modes.contains(DoctorPracticeMode.cabinet);
  final hasHome =
      modes.contains(DoctorPracticeMode.homeVisit) ||
      modes.contains(DoctorPracticeMode.urgentHome);
  return DoctorWorkspaceConfig(
    doctorId: doctorId,
    onboardingCompleted: true,
    practiceModes: modes,
    services: <DoctorWorkspaceService>{},
    cabinet: hasCabinet
        ? const DoctorCabinetConfig(
            name: 'Cabinet de démonstration',
            governorate: 'Tunis',
            city: 'Tunis',
            address: '1, rue de la Santé',
          )
        : null,
    clinics: const [],
    homeVisit: hasHome
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
}

Widget _shell(DoctorWorkspaceConfig config) => MaterialApp(
  theme: buildOmniTheme(),
  home: DoctorAppShell(
    profile: DoctorDemoProfile.current,
    onLogout: () async {},
    workspaceConfig: config,
  ),
);

List<String> _labels(DoctorWorkspaceConfig config) =>
    deriveDoctorNavigationDestinations(
      deriveDoctorCapabilities(config),
    ).map((destination) => destination.label).toList(growable: false);

void main() {
  test('derives each D2 workspace from the central capability mapping', () {
    final cabinet = _workspace('doctor-a', {DoctorPracticeMode.cabinet});
    final homeUrgent = _workspace('doctor-b', {
      DoctorPracticeMode.homeVisit,
      DoctorPracticeMode.urgentHome,
    });
    final hybrid = _workspace('doctor-c', {
      DoctorPracticeMode.cabinet,
      DoctorPracticeMode.homeVisit,
      DoctorPracticeMode.urgentHome,
    });
    final clinic = _workspace('doctor-d', {DoctorPracticeMode.clinic});

    expect(_labels(cabinet), ['Accueil', 'Agenda', 'Patients', 'Profil']);
    expect(_labels(homeUrgent), ['Accueil', 'Urgences', 'Patients', 'Profil']);
    expect(_labels(hybrid), [
      'Accueil',
      'Agenda',
      'Urgences',
      'Patients',
      'Profil',
    ]);
    expect(_labels(clinic), ['Accueil', 'Profil']);
    expect(
      canAccessDoctorFeature(
        deriveDoctorCapabilities(cabinet),
        DoctorCapability.urgentRequests,
      ),
      isFalse,
    );
  });

  testWidgets('falls back to Accueil when a selected capability disappears', (
    tester,
  ) async {
    final hybrid = _workspace('doctor-a', {
      DoctorPracticeMode.cabinet,
      DoctorPracticeMode.homeVisit,
      DoctorPracticeMode.urgentHome,
    });
    await tester.pumpWidget(_shell(hybrid));
    await tester.tap(find.byKey(const ValueKey('doctor-tab-urgent')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('doctor-tab-urgent')), findsOneWidget);
    expect(find.text('Urgences'), findsNWidgets(2));

    await tester.pumpWidget(
      _shell(_workspace('doctor-a', {DoctorPracticeMode.cabinet})),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('doctor-tab-urgent')), findsNothing);
    expect(find.text('Bonjour Dr Mansour'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Accueil')), findsOneWidget);
  });

  testWidgets('uses the same dynamic list for tabs and placeholder content', (
    tester,
  ) async {
    await tester.pumpWidget(
      _shell(
        _workspace('doctor-b', {
          DoctorPracticeMode.homeVisit,
          DoctorPracticeMode.urgentHome,
        }),
      ),
    );

    expect(find.byKey(const ValueKey('doctor-tab-agenda')), findsNothing);
    expect(find.byKey(const ValueKey('doctor-tab-urgent')), findsOneWidget);
    expect(find.byKey(const ValueKey('doctor-tab-patients')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('doctor-tab-urgent')));
    await tester.pumpAndSettle();
    expect(find.text('Urgences'), findsNWidgets(2));

    await tester.tap(find.byKey(const ValueKey('doctor-tab-patients')));
    await tester.pumpAndSettle();
    expect(find.text('Patients'), findsNWidgets(2));
  });

  testWidgets('fits four and five dynamic destinations on supported widths', (
    tester,
  ) async {
    const sizes = <Size>[Size(360, 568), Size(390, 844), Size(430, 932)];
    final fourTabs = _workspace('doctor-a', {DoctorPracticeMode.cabinet});
    final fiveTabs = _workspace('doctor-b', {
      DoctorPracticeMode.cabinet,
      DoctorPracticeMode.homeVisit,
      DoctorPracticeMode.urgentHome,
    });
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final size in sizes) {
      tester.view.physicalSize = size;
      for (final config in [fourTabs, fiveTabs]) {
        await tester.pumpWidget(_shell(config));
        await tester.pumpAndSettle();
        final navigation = tester.getRect(
          find.byKey(const ValueKey('doctor-bottom-navigation')),
        );
        expect(navigation.width, size.width);
        expect(tester.takeException(), isNull);
      }
    }
  });
}
