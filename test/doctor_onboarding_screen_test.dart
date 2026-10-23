import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/core/theme/omni_theme.dart';
import 'package:omnicare_mobile/features/doctor/demo/doctor_demo_profile.dart';
import 'package:omnicare_mobile/features/doctor/onboarding/doctor_onboarding_screen.dart';
import 'package:omnicare_mobile/features/doctor/workspace/doctor_workspace_config.dart';

void main() {
  Widget buildSubject(
    Future<void> Function(DoctorWorkspaceConfig) onCompleted,
  ) {
    return MaterialApp(
      theme: buildOmniTheme(),
      home: DoctorOnboardingScreen(
        doctorId: 'doctor-a',
        profile: DoctorDemoProfile.current,
        onCompleted: onCompleted,
      ),
    );
  }

  testWidgets('requires an activity before continuing', (tester) async {
    await tester.pumpWidget(buildSubject((_) async {}));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('doctor-onboarding-continue')));
    await tester.pumpAndSettle();

    expect(
      find.text('Sélectionnez au moins une façon d’exercer.'),
      findsOneWidget,
    );
  });

  testWidgets('renders the complete first onboarding step onstage', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject((_) async {}));
    await tester.pumpAndSettle();

    for (final label in const [
      'Étape 1 sur 5',
      'Votre activité',
      "Comment exercez-vous aujourd'hui ?",
      'Cabinet',
      'Clinique',
      'Visites à domicile',
      'Urgences à domicile',
      'Téléconsultation',
      'Continuer',
    ]) {
      expect(find.text(label), findsOneWidget);
    }

    final heading = tester.getRect(find.text('Votre activité'));
    final firstChoice = tester.getRect(find.text('Cabinet'));
    final cta = tester.getRect(
      find.byKey(const ValueKey('doctor-onboarding-continue')),
    );
    expect(heading.top, greaterThanOrEqualTo(0));
    expect(firstChoice.height, greaterThan(0));
    expect(cta.bottom, lessThanOrEqualTo(tester.view.physicalSize.height));
  });

  testWidgets('keeps the main content visible through steps two to five', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject((_) async {}));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('doctor-onboarding-mode-cabinet')),
    );
    await tester.tap(
      find.byKey(const ValueKey('doctor-onboarding-mode-homeVisit')),
    );
    await tester.tap(
      find.byKey(const ValueKey('doctor-onboarding-mode-urgentHome')),
    );
    await tester.tap(find.byKey(const ValueKey('doctor-onboarding-continue')));
    await tester.pumpAndSettle();

    expect(find.text('Étape 2 sur 5'), findsOneWidget);
    expect(find.text('Vos lieux d’exercice'), findsOneWidget);
    expect(find.text('Nom du cabinet'), findsOneWidget);
    expect(find.text('Zone de visites à domicile'), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('doctor-cabinet-name')),
      'Cabinet Mansour',
    );
    await tester.enterText(
      find.byKey(const ValueKey('doctor-cabinet-governorate')),
      'Tunis',
    );
    await tester.enterText(
      find.byKey(const ValueKey('doctor-cabinet-city')),
      'La Marsa',
    );
    await tester.enterText(
      find.byKey(const ValueKey('doctor-cabinet-address')),
      '1, rue de la Santé',
    );
    await tester.enterText(
      find.byKey(const ValueKey('doctor-home-governorate')),
      'Tunis',
    );
    await tester.tap(find.byKey(const ValueKey('doctor-onboarding-continue')));
    await tester.pumpAndSettle();

    expect(find.text('Étape 3 sur 5'), findsOneWidget);
    expect(find.text('Vos services'), findsOneWidget);
    expect(find.text('Consultations au cabinet'), findsOneWidget);
    expect(find.text('Visites à domicile'), findsOneWidget);
    expect(find.text('Urgences à domicile'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('doctor-onboarding-continue')));
    await tester.pumpAndSettle();

    expect(find.text('Étape 4 sur 5'), findsOneWidget);
    expect(find.text('Vos disponibilités'), findsOneWidget);
    expect(find.text('Jours travaillés'), findsOneWidget);
    expect(find.text('Disponible pour les visites à domicile'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('doctor-onboarding-continue')));
    await tester.pumpAndSettle();

    expect(find.text('Étape 5 sur 5'), findsOneWidget);
    expect(find.text('Votre espace médecin'), findsOneWidget);
    expect(find.text('Votre activité'), findsOneWidget);
    expect(find.text('Terminer la configuration'), findsOneWidget);
  });

  testWidgets('onboarding layout fits supported phone dimensions', (
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
      await tester.pumpWidget(buildSubject((_) async {}));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Votre activité'), findsOneWidget);
      expect(find.text('Cabinet'), findsOneWidget);
      expect(find.text('Étape 1 sur 5'), findsOneWidget);
      final heading = tester.getRect(find.text('Votre activité'));
      final firstChoice = tester.getRect(find.text('Cabinet'));
      final cta = tester.getRect(
        find.byKey(const ValueKey('doctor-onboarding-continue')),
      );
      expect(heading.top, greaterThanOrEqualTo(0));
      expect(heading.bottom, lessThan(cta.top));
      expect(firstChoice.top, lessThan(cta.top));
      expect(cta.right, lessThanOrEqualTo(size.width));
      expect(cta.bottom, lessThanOrEqualTo(size.height));
    }
  });
}
