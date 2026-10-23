import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/core/theme/omni_theme.dart';
import 'package:omnicare_mobile/features/doctor/demo/doctor_demo_profile.dart';
import 'package:omnicare_mobile/features/doctor/home/doctor_home_demo_state.dart';
import 'package:omnicare_mobile/features/doctor/home/doctor_home_screen.dart';
import 'package:omnicare_mobile/features/doctor/shell/doctor_app_shell.dart';
import 'package:omnicare_mobile/features/doctor/workspace/doctor_workspace_config.dart';

DoctorWorkspaceConfig _workspace(Set<DoctorPracticeMode> modes) {
  final hasCabinet = modes.contains(DoctorPracticeMode.cabinet);
  final hasHome =
      modes.contains(DoctorPracticeMode.homeVisit) ||
      modes.contains(DoctorPracticeMode.urgentHome);
  return DoctorWorkspaceConfig(
    doctorId: 'doctor-home-test',
    onboardingCompleted: true,
    practiceModes: modes,
    services: const {},
    cabinet: hasCabinet
        ? const DoctorCabinetConfig(
            name: 'Cabinet Lac 2',
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

Widget _home(
  DoctorWorkspaceConfig config, {
  DoctorHomeDemoState state = DoctorHomeDemoState.normalDay,
}) => MaterialApp(
  theme: buildOmniTheme(),
  home: Scaffold(
    body: DoctorHomeScreen(
      profile: DoctorDemoProfile.current,
      capabilities: deriveDoctorCapabilities(config),
      workspaceConfig: config,
      demoState: state,
    ),
  ),
);

void main() {
  testWidgets(
    'normal hybrid Home prioritizes attention, agenda, and urgent status',
    (tester) async {
      await tester.pumpWidget(
        _home(
          _workspace({
            DoctorPracticeMode.cabinet,
            DoctorPracticeMode.homeVisit,
            DoctorPracticeMode.urgentHome,
          }),
        ),
      );

      expect(find.text('Bonjour Dr Mansour'), findsOneWidget);
      expect(find.text('À traiter'), findsOneWidget);
      expect(find.text('Résultat à revoir'), findsOneWidget);
      expect(find.text('Prochain rendez-vous'), findsOneWidget);
      expect(find.text('Urgences à domicile'), findsNWidgets(2));
      expect(find.text('Votre activité'), findsOneWidget);
    },
  );

  testWidgets('active consultation appears before the operational previews', (
    tester,
  ) async {
    await tester.pumpWidget(
      _home(
        _workspace({DoctorPracticeMode.cabinet}),
        state: DoctorHomeDemoState.activeConsultationDay,
      ),
    );

    expect(find.text('Consultation en cours'), findsOneWidget);
    expect(find.textContaining('Depuis 08 min'), findsOneWidget);
    await tester.tap(find.text('Reprendre'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'La consultation sera ajoutée dans une prochaine étape de la démo.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'empty clinic-only Home stays calm and does not invent operations',
    (tester) async {
      await tester.pumpWidget(
        _home(
          _workspace({DoctorPracticeMode.clinic}),
          state: DoctorHomeDemoState.emptyDay,
        ),
      );

      expect(find.text('Tout est à jour'), findsOneWidget);
      expect(find.text('Clinique'), findsOneWidget);
      expect(find.text('À traiter'), findsNothing);
      expect(find.text('Prochain rendez-vous'), findsNothing);
      expect(find.text('Urgences à domicile'), findsNothing);
    },
  );

  testWidgets('capabilities hide irrelevant agenda and urgent sections', (
    tester,
  ) async {
    await tester.pumpWidget(_home(_workspace({DoctorPracticeMode.cabinet})));
    expect(find.text('Prochain rendez-vous'), findsOneWidget);
    expect(find.text('Urgences à domicile'), findsNothing);

    await tester.pumpWidget(
      _home(
        _workspace({
          DoctorPracticeMode.homeVisit,
          DoctorPracticeMode.urgentHome,
        }),
      ),
    );
    expect(find.text('Prochain rendez-vous'), findsNothing);
    expect(find.text('Urgences à domicile'), findsNWidgets(2));
  });

  testWidgets('Home actions select the existing agenda and urgent shell tabs', (
    tester,
  ) async {
    final config = _workspace({
      DoctorPracticeMode.cabinet,
      DoctorPracticeMode.homeVisit,
      DoctorPracticeMode.urgentHome,
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: buildOmniTheme(),
        home: DoctorAppShell(
          profile: DoctorDemoProfile.current,
          onLogout: () async {},
          workspaceConfig: config,
        ),
      ),
    );

    await tester.ensureVisible(find.text('Voir dans l’agenda'));
    await tester.tap(find.text('Voir dans l’agenda'));
    await tester.pumpAndSettle();
    expect(find.text('Agenda'), findsNWidgets(2));

    await tester.tap(find.byKey(const ValueKey('doctor-tab-home')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Voir les urgences'));
    await tester.tap(find.text('Voir les urgences'));
    await tester.pumpAndSettle();
    expect(find.text('Urgences'), findsNWidgets(2));
  });

  testWidgets('Home content fits supported phone dimensions', (tester) async {
    const sizes = <Size>[Size(360, 568), Size(390, 844), Size(430, 932)];
    final config = _workspace({
      DoctorPracticeMode.cabinet,
      DoctorPracticeMode.homeVisit,
      DoctorPracticeMode.urgentHome,
    });
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final size in sizes) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(_home(config));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('doctor-home-scroll')), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
