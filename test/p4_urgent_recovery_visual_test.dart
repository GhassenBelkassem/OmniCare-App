import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/core/theme/omni_theme.dart';
import 'package:omnicare_mobile/features/urgent_journey/data/synthetic_home_location_gateway.dart';
import 'package:omnicare_mobile/features/urgent_journey/data/synthetic_urgent_journey_fixture_source.dart';
import 'package:omnicare_mobile/features/urgent_journey/domain/p4_urgent_feature_gate.dart';
import 'package:omnicare_mobile/features/urgent_journey/domain/urgent_journey_intents.dart';
import 'package:omnicare_mobile/features/urgent_journey/domain/urgent_journey_models.dart';
import 'package:omnicare_mobile/features/urgent_journey/presentation/p4_urgent_journey_coordinator.dart';
import 'package:omnicare_mobile/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final jakarta = FontLoader('Plus Jakarta Sans')
      ..addFont(rootBundle.load('assets/fonts/PlusJakartaSans-Medium.ttf'))
      ..addFont(rootBundle.load('assets/fonts/PlusJakartaSans-SemiBold.ttf'))
      ..addFont(rootBundle.load('assets/fonts/PlusJakartaSans-Bold.ttf'))
      ..addFont(rootBundle.load('assets/fonts/PlusJakartaSans-ExtraBold.ttf'));
    final materialIcons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await Future.wait([jakarta.load(), materialIcons.load()]);
  });

  testWidgets('recovered HOME subject presentation matches baseline', (
    tester,
  ) async {
    await _pumpRecoveryFrame(
      tester,
      const P4UrgentJourneyCoordinator(
        initialStage: P4UrgentCoordinatorStage.subject,
        initialMode: UrgentAttemptMode.home,
        featureGate: P4UrgentFeatureGate.enabledForTests,
      ),
    );
    await expectLater(
      find.byKey(const ValueKey('p4-recovery-frame')),
      matchesGoldenFile('goldens/p4_recovered_home_subject.png'),
    );
  });

  testWidgets('recovered structured triage presentation matches baseline', (
    tester,
  ) async {
    await _pumpRecoveryFrame(
      tester,
      P4UrgentJourneyCoordinator(
        fixtureSource: _sourceAtTriage(UrgentAttemptMode.home),
        featureGate: P4UrgentFeatureGate.enabledForTests,
      ),
    );
    await expectLater(
      find.byKey(const ValueKey('p4-recovery-frame')),
      matchesGoldenFile('goldens/p4_recovered_structured_triage.png'),
    );
  });

  testWidgets('recovered HOME destination presentation matches baseline', (
    tester,
  ) async {
    await _pumpRecoveryFrame(
      tester,
      P4UrgentJourneyCoordinator(
        fixtureSource: _sourceAtModeSpecific(UrgentAttemptMode.home),
        locationGateway: InMemorySyntheticHomeLocationGateway(
          scenario: SyntheticHomeLocationScenario.manual,
        ),
        featureGate: P4UrgentFeatureGate.enabledForTests,
      ),
    );
    await expectLater(
      find.byKey(const ValueKey('p4-recovery-frame')),
      matchesGoldenFile('goldens/p4_recovered_home_destination.png'),
    );
  });

  testWidgets('recovered HOME review presentation matches baseline', (
    tester,
  ) async {
    await _pumpRecoveryFrame(
      tester,
      P4UrgentJourneyCoordinator(
        fixtureSource: _sourceAtHomeReview(),
        locationGateway: InMemorySyntheticHomeLocationGateway(
          scenario: SyntheticHomeLocationScenario.confirmed,
        ),
        featureGate: P4UrgentFeatureGate.enabledForTests,
      ),
    );
    await expectLater(
      find.byKey(const ValueKey('p4-recovery-frame')),
      matchesGoldenFile('goldens/p4_recovered_home_review.png'),
    );
  });

  testWidgets('recovered CABINET directory presentation matches baseline', (
    tester,
  ) async {
    await _pumpRecoveryFrame(
      tester,
      P4UrgentJourneyCoordinator(
        fixtureSource: _sourceAtModeSpecific(UrgentAttemptMode.cabinet),
        featureGate: P4UrgentFeatureGate.enabledForTests,
      ),
    );
    await expectLater(
      find.byKey(const ValueKey('p4-recovery-frame')),
      matchesGoldenFile('goldens/p4_recovered_cabinet_directory.png'),
    );
  });
}

SyntheticUrgentJourneyFixtureSource _sourceAtTriage(UrgentAttemptMode mode) {
  final source = SyntheticUrgentJourneyFixtureSource();
  source.execute(
    StartUrgentJourneyIntent(
      actionId: 'visual-start-${mode.name}',
      accountScopeRef: SyntheticUrgentJourneyFixtureSource.patientAccount,
      subjectSelectionRef: SyntheticUrgentJourneyFixtureSource.selfSubject,
      initialMode: mode,
    ),
  );
  return source;
}

SyntheticUrgentJourneyFixtureSource _sourceAtModeSpecific(
  UrgentAttemptMode mode,
) {
  final source = _sourceAtTriage(mode);
  final journey = source.snapshot().patientJourney!;
  final attempt = journey.activeAttempt;
  source.execute(
    SaveStructuredTriageIntent(
      actionId: 'visual-triage-${mode.name}',
      accountScopeRef: journey.requestingAccountScopeRef,
      journeyRef: journey.journeyRef,
      attemptRef: attempt.attemptRef,
      triage: PatientTriageProjection(
        minimum: StructuredTriageMinimumProjection(
          bodyAreaCodes: const ['front-chest-pectoral-left'],
          painIntensity: 5,
          painBandCode: 'SYNTHETIC_MODERATE_PENDING_APPROVAL',
          painBandDisplayKey: 'p4_pain_medium',
        ),
      ),
      expectedJourneyVersion: journey.version,
      expectedAttemptVersion: attempt.version,
    ),
  );
  return source;
}

SyntheticUrgentJourneyFixtureSource _sourceAtHomeReview() {
  final source = _sourceAtModeSpecific(UrgentAttemptMode.home);
  final journey = source.snapshot().patientJourney!;
  final attempt = journey.activeAttempt;
  source.execute(
    ConfirmHomeDestinationIntent(
      actionId: 'visual-home-destination',
      accountScopeRef: journey.requestingAccountScopeRef,
      journeyRef: journey.journeyRef,
      attemptRef: attempt.attemptRef,
      destination: const HomeDestinationDraft(
        permission: HomeLocationPermission.granted,
        service: HomeLocationService.available,
        quality: HomeLocationQuality.fresh,
        status: HomeDestinationStatus.confirmed,
        source: HomeDestinationSource.manualAddress,
        displayAddress: 'Adresse HOME synthétique, Tunis',
        latitude: 36.8065,
        longitude: 10.1815,
      ),
      expectedJourneyVersion: journey.version,
      expectedAttemptVersion: attempt.version,
    ),
  );
  return source;
}

Future<void> _pumpRecoveryFrame(WidgetTester tester, Widget content) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('fr'),
      supportedLocales: const [Locale('en'), Locale('fr'), Locale('ar')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: _recoveryTheme(),
      home: Scaffold(
        body: RepaintBoundary(
          key: const ValueKey('p4-recovery-frame'),
          child: content,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

ThemeData _recoveryTheme() {
  final base = ThemeData.light(useMaterial3: true);
  return base.copyWith(
    colorScheme: ColorScheme.fromSeed(
      seedColor: OmniColors.freshMint,
      primary: OmniColors.freshMint,
      onPrimary: OmniColors.textOnMint,
      surface: OmniColors.surfacePrimary,
      onSurface: OmniColors.textPrimary,
    ),
    scaffoldBackgroundColor: OmniColors.pageBackground,
    textTheme: base.textTheme.apply(
      fontFamily: 'Plus Jakarta Sans',
      bodyColor: OmniColors.textPrimary,
      displayColor: OmniColors.textPrimary,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: buildOmniPrimaryButtonStyle(),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: buildOmniPrimaryButtonStyle(),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: OmniColors.surfacePrimary,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(OmniRadii.field),
        borderSide: const BorderSide(color: OmniColors.borderLight),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(OmniRadii.field),
        borderSide: const BorderSide(color: OmniColors.borderLight),
      ),
    ),
  );
}
