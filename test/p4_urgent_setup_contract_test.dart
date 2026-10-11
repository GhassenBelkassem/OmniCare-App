import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/features/urgent_journey/data/synthetic_cabinet_directory_source.dart';
import 'package:omnicare_mobile/features/urgent_journey/data/synthetic_home_location_gateway.dart';
import 'package:omnicare_mobile/features/urgent_journey/data/synthetic_urgent_journey_fixture_source.dart';
import 'package:omnicare_mobile/features/urgent_journey/domain/p4_urgent_feature_gate.dart';
import 'package:omnicare_mobile/features/urgent_journey/domain/urgent_journey_intents.dart';
import 'package:omnicare_mobile/features/urgent_journey/domain/urgent_journey_models.dart';
import 'package:omnicare_mobile/features/urgent_journey/presentation/p4_attempt_setup_screens.dart';
import 'package:omnicare_mobile/features/urgent_journey/presentation/p4_urgent_journey_coordinator.dart';
import 'package:omnicare_mobile/features/urgent_journey/presentation/p4_urgent_route_owner.dart';
import 'package:omnicare_mobile/l10n/app_localizations.dart';

void main() {
  group('typed setup command contract', () {
    test(
      'Patient-private narrative never enters offered Doctor projection',
      () {
        final source = SyntheticUrgentJourneyFixtureSource();
        final started =
            source.execute(
                  const StartUrgentJourneyIntent(
                    actionId: 'home-start',
                    accountScopeRef:
                        SyntheticUrgentJourneyFixtureSource.patientAccount,
                    subjectSelectionRef:
                        SyntheticUrgentJourneyFixtureSource.selfSubject,
                    initialMode: UrgentAttemptMode.home,
                  ),
                )
                as UrgentUiCommandSuccess;
        final attempt = started.projection.activeAttempt;
        final triage = PatientTriageProjection(
          minimum: StructuredTriageMinimumProjection(
            bodyAreaCodes: const ['chest'],
            painIntensity: 7,
            painBandCode: 'SYNTHETIC_SEVERE_PENDING_APPROVAL',
            painBandDisplayKey: 'p4_pain_severe',
          ),
          privateNarrative: const PatientPrivateNarrativeProjection(
            value: 'private synthetic note',
          ),
        );
        final saved =
            source.execute(
                  SaveStructuredTriageIntent(
                    actionId: 'home-triage',
                    accountScopeRef:
                        started.projection.requestingAccountScopeRef,
                    journeyRef: started.projection.journeyRef,
                    attemptRef: attempt.attemptRef,
                    triage: triage,
                    expectedJourneyVersion: started.projection.version,
                    expectedAttemptVersion: attempt.version,
                  ),
                )
                as UrgentUiCommandSuccess;

        expect(
          saved.projection.activeAttempt.triage.privateNarrative?.value,
          'private synthetic note',
        );
        expect(triage.privateNarrative!.canDiscloseToOfferedDoctor, isFalse);
        expect(
          triage.minimum.safeFields.values,
          isNot(contains('private synthetic note')),
        );
      },
    );

    test('HOME destination command is mode-safe and requires confirmation', () {
      final source = SyntheticUrgentJourneyFixtureSource();
      final started =
          source.execute(
                const StartUrgentJourneyIntent(
                  actionId: 'cabinet-start',
                  accountScopeRef:
                      SyntheticUrgentJourneyFixtureSource.patientAccount,
                  subjectSelectionRef:
                      SyntheticUrgentJourneyFixtureSource.selfSubject,
                  initialMode: UrgentAttemptMode.cabinet,
                ),
              )
              as UrgentUiCommandSuccess;
      final attempt = started.projection.activeAttempt;
      final result = source.execute(
        ConfirmHomeDestinationIntent(
          actionId: 'wrong-mode-destination',
          accountScopeRef: started.projection.requestingAccountScopeRef,
          journeyRef: started.projection.journeyRef,
          attemptRef: attempt.attemptRef,
          destination: const HomeDestinationDraft(
            permission: HomeLocationPermission.granted,
            service: HomeLocationService.available,
            quality: HomeLocationQuality.fresh,
            status: HomeDestinationStatus.confirmed,
            source: HomeDestinationSource.syntheticGps,
            displayAddress: 'Synthetic',
            latitude: 36.8,
            longitude: 10.18,
          ),
          expectedJourneyVersion: started.projection.version,
          expectedAttemptVersion: attempt.version,
        ),
      );
      expect(
        (result as UrgentUiCommandFailure).error.code,
        UrgentSafeErrorCode.modeMismatch,
      );
    });

    test('fee quote context prevents HOME/CABINET interchange', () {
      expect(
        () => CabinetTargetProjection(
          doctorRef: const DoctorPublicUiRef('doctor'),
          cabinetRef: const CabinetPublicUiRef('cabinet'),
          doctorDisplayName: 'Synthetic Doctor',
          cabinetDisplayName: 'Synthetic Cabinet',
          publicAddress: 'Public synthetic address',
          specialtyLabel: 'General medicine',
          urgentCapabilityLabel: 'Urgent cabinet',
          quote: const UrgentFeeQuote(
            context: UrgentFeeContext.home,
            amountMinor: 10000,
            currency: 'TND',
            feeVersion: 1,
          ),
        ),
        throwsAssertionError,
      );
    });

    test('location gateway exposes all required deterministic states', () {
      for (final scenario in SyntheticHomeLocationScenario.values) {
        final gateway = InMemorySyntheticHomeLocationGateway(
          scenario: scenario,
        );
        expect(
          gateway.snapshot(),
          isA<HomeDestinationDraft>(),
          reason: scenario.name,
        );
      }
      final gateway = InMemorySyntheticHomeLocationGateway();
      expect(
        gateway.snapshot().permission,
        HomeLocationPermission.notRequested,
      );
      gateway.requestSyntheticPermission();
      final draft = gateway.acquireSyntheticFix();
      expect(draft.quality, HomeLocationQuality.fresh);
      expect(draft.hasExactLocation, isTrue);
      expect(gateway.confirm().status, HomeDestinationStatus.confirmed);
    });

    test('triage unavailability has an explicit deterministic recovery', () {
      final source = SyntheticUrgentJourneyFixtureSource(
        triageAvailability: SyntheticTriageAvailability.unavailable,
      );
      expect(
        source.triageAvailability,
        SyntheticTriageAvailability.unavailable,
      );
      source.retryTriage();
      expect(source.triageAvailability, SyntheticTriageAvailability.ready);
    });

    test(
      'CABINET directory contains public data, independent fees, no slots',
      () {
        final snapshot = SyntheticCabinetDirectorySource().search();
        expect(snapshot.candidates, hasLength(2));
        expect(
          snapshot.candidates.map((value) => value.quote.context).toSet(),
          {UrgentFeeContext.cabinet},
        );
        expect(
          snapshot.candidates.map((value) => value.quote.feeVersion).toSet(),
          hasLength(2),
        );
        expect(
          SyntheticCabinetDirectorySource().search('Lina').candidates,
          hasLength(1),
        );
        expect(
          SyntheticCabinetDirectorySource().search('no-match').status,
          SyntheticCabinetDirectoryStatus.empty,
        );
      },
    );
  });

  testWidgets(
    'triage validates, reuses body map, and keeps voice/passport absent',
    (tester) async {
      PatientTriageProjection? result;
      await _pump(
        tester,
        P4StructuredTriageScreen(
          availability: SyntheticTriageAvailability.ready,
          onBack: () {},
          onContinue: (value) => result = value,
          onRetry: () {},
        ),
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('p4-setup-primary-action')),
      );
      await tester.tap(find.byKey(const ValueKey('p4-setup-primary-action')));
      await tester.pump();
      expect(result, isNull);
      expect(find.textContaining('Passeport médical'), findsNothing);
      expect(find.textContaining('Medical Passport'), findsNothing);

      const chestKey = ValueKey('front-zone-front-chest-pectoral-left');
      await tester.ensureVisible(find.byKey(chestKey));
      await tester.tap(find.byKey(chestKey), warnIfMissed: false);
      await tester.pump();
      await tester.ensureVisible(
        find.byKey(const ValueKey('p4-setup-primary-action')),
      );
      await tester.tap(find.byKey(const ValueKey('p4-setup-primary-action')));
      expect(
        result?.minimum.bodyAreaCodes,
        contains('front-chest-pectoral-left'),
      );
    },
  );

  testWidgets(
    'directory covers loading, empty, failure, search, and selection',
    (tester) async {
      for (final state in const [
        SyntheticCabinetDirectoryStatus.loading,
        SyntheticCabinetDirectoryStatus.empty,
        SyntheticCabinetDirectoryStatus.failure,
      ]) {
        await _pump(
          tester,
          P4CabinetDirectoryScreen(
            key: ValueKey('directory-${state.name}'),
            source: SyntheticCabinetDirectorySource(initialStatus: state),
            onBack: () {},
            onConfirmed: (_) {},
          ),
        );
        expect(tester.takeException(), isNull, reason: state.name);
      }
      CabinetTargetProjection? selected;
      await _pump(
        tester,
        P4CabinetDirectoryScreen(
          key: const ValueKey('directory-ready'),
          source: SyntheticCabinetDirectorySource(),
          onBack: () {},
          onConfirmed: (value) => selected = value,
        ),
      );
      final firstTarget = find.byKey(
        const ValueKey('p4-cabinet-syn_cabinet_1'),
      );
      await tester.ensureVisible(firstTarget);
      await tester.tap(firstTarget);
      await tester.pump();
      await tester.ensureVisible(
        find.byKey(const ValueKey('p4-setup-primary-action')),
      );
      await tester.tap(find.byKey(const ValueKey('p4-setup-primary-action')));
      expect(selected?.quote.context, UrgentFeeContext.cabinet);
      expect(find.textContaining('slot'), findsNothing);
    },
  );

  testWidgets('release gate blocks direct, deep-link, and restored routes', (
    tester,
  ) async {
    for (final route in [
      P4UrgentRoutes.entry,
      P4UrgentRoutes.subject,
      P4UrgentRoutes.cabinetEntry,
      ...P4UrgentRoutes.prohibitedContinuations,
    ]) {
      final page = P4UrgentRouteOwner.buildPage(
        RouteSettings(name: route),
        featureGate: P4UrgentFeatureGate.disabled,
      );
      await _pump(tester, page!);
      expect(
        find.byKey(const ValueKey('p4-synthetic-unavailable')),
        findsOneWidget,
        reason: route,
      );
      expect(find.text('Dr Lina Démo'), findsNothing);
    }
  });

  testWidgets('HOME setup resumes, confirms destination, reviews, and stops', (
    tester,
  ) async {
    final source = _sourceAtModeSpecificSetup(UrgentAttemptMode.home);
    await _pump(
      tester,
      P4UrgentJourneyCoordinator(
        fixtureSource: source,
        locationGateway: InMemorySyntheticHomeLocationGateway(
          scenario: SyntheticHomeLocationScenario.manual,
        ),
        featureGate: P4UrgentFeatureGate.enabledForTests,
      ),
    );
    expect(
      find.byKey(const ValueKey('emergency-step3-page-surface')),
      findsOneWidget,
    );
    await tester.tap(find.text('Continuer'));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('emergency-review-page-surface')),
      findsOneWidget,
    );
    final locationSection = find.byKey(
      const ValueKey('review-location-section'),
    );
    final editLocation = find.descendant(
      of: locationSection,
      matching: find.text('Modifier'),
    );
    await tester.ensureVisible(editLocation);
    await tester.tap(editLocation);
    await tester.pump();
    expect(
      find.byKey(const ValueKey('emergency-step3-page-surface')),
      findsOneWidget,
    );
    await tester.tap(find.text('Continuer'));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('emergency-review-page-surface')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('emergency-review-send')));
    await tester.pump();
    expect(find.byKey(const ValueKey('p4-setup-complete')), findsOneWidget);
    expect(source.snapshot().offeredDoctor, isNull);
    expect(source.snapshot().committedDoctor, isNull);
  });

  testWidgets('CABINET setup selects target before waiting and then stops', (
    tester,
  ) async {
    final source = _sourceAtModeSpecificSetup(UrgentAttemptMode.cabinet);
    await _pump(
      tester,
      P4UrgentJourneyCoordinator(
        fixtureSource: source,
        featureGate: P4UrgentFeatureGate.enabledForTests,
      ),
    );
    final target = find.byKey(const ValueKey('p4-cabinet-syn_cabinet_1'));
    await tester.ensureVisible(target);
    await tester.tap(target);
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('p4-setup-primary-action')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('emergency-review-page-surface')),
      findsOneWidget,
    );
    expect(source.snapshot().offeredDoctor, isNull);
    await tester.tap(find.byKey(const ValueKey('emergency-review-send')));
    await tester.pump();
    expect(find.byKey(const ValueKey('p4-setup-complete')), findsOneWidget);
    final attempt =
        source.snapshot().patientJourney!.activeAttempt
            as CabinetAttemptProjection;
    expect(attempt.target, isNotNull);
    expect(attempt.stage, UrgentAttemptStage.awaitingCabinetDoctor);
    expect(source.snapshot().committedDoctor, isNull);
  });

  testWidgets('HOME location edge states are renderable and recoverable', (
    tester,
  ) async {
    for (final scenario in const [
      SyntheticHomeLocationScenario.permissionNotRequested,
      SyntheticHomeLocationScenario.permissionDenied,
      SyntheticHomeLocationScenario.permissionDeniedForever,
      SyntheticHomeLocationScenario.gpsUnavailable,
      SyntheticHomeLocationScenario.acquiring,
      SyntheticHomeLocationScenario.lowAccuracy,
      SyntheticHomeLocationScenario.stale,
      SyntheticHomeLocationScenario.mapSearchUnavailable,
      SyntheticHomeLocationScenario.offlineUnsent,
    ]) {
      await _pump(
        tester,
        P4HomeDestinationScreen(
          key: ValueKey('location-${scenario.name}'),
          gateway: InMemorySyntheticHomeLocationGateway(scenario: scenario),
          onBack: () {},
          onConfirmed: (_) {},
        ),
      );
      expect(
        find.byKey(const ValueKey('p4-home-destination-stage')),
        findsOneWidget,
        reason: scenario.name,
      );
      expect(tester.takeException(), isNull, reason: scenario.name);
    }
  });

  for (final locale in const [Locale('en'), Locale('fr'), Locale('ar')]) {
    testWidgets(
      'triage localizes and lays out at large text in ${locale.languageCode}',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 568));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await _pump(
          tester,
          P4StructuredTriageScreen(
            availability: SyntheticTriageAvailability.unavailable,
            onBack: () {},
            onContinue: (_) {},
            onRetry: () {},
          ),
          locale: locale,
          textScaler: const TextScaler.linear(2),
        );
        expect(find.text('p4_triage_title'), findsNothing);
        expect(
          Directionality.of(tester.element(find.byType(SafeArea).first)),
          locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'coordinator reconstructs an authorized immutable-mode snapshot',
    (tester) async {
      await _pump(
        tester,
        P4UrgentJourneyCoordinator(
          fixtureSource: SyntheticUrgentJourneyFixtureSource(
            scenario: SyntheticUrgentScenario.linkedFallback,
          ),
          featureGate: P4UrgentFeatureGate.enabledForTests,
        ),
      );
      expect(
        find.byKey(const ValueKey('emergency-step2-page-surface')),
        findsOneWidget,
      );
    },
  );
}

SyntheticUrgentJourneyFixtureSource _sourceAtModeSpecificSetup(
  UrgentAttemptMode mode,
) {
  final source = SyntheticUrgentJourneyFixtureSource();
  final started =
      source.execute(
            StartUrgentJourneyIntent(
              actionId: 'seed-${mode.name}',
              accountScopeRef:
                  SyntheticUrgentJourneyFixtureSource.patientAccount,
              subjectSelectionRef:
                  SyntheticUrgentJourneyFixtureSource.selfSubject,
              initialMode: mode,
            ),
          )
          as UrgentUiCommandSuccess;
  final attempt = started.projection.activeAttempt;
  source.execute(
    SaveStructuredTriageIntent(
      actionId: 'seed-triage-${mode.name}',
      accountScopeRef: started.projection.requestingAccountScopeRef,
      journeyRef: started.projection.journeyRef,
      attemptRef: attempt.attemptRef,
      triage: PatientTriageProjection(
        minimum: StructuredTriageMinimumProjection(
          bodyAreaCodes: const ['front-chest-pectoral-left'],
          painIntensity: 5,
          painBandCode: 'SYNTHETIC_MODERATE_PENDING_APPROVAL',
          painBandDisplayKey: 'p4_pain_medium',
        ),
      ),
      expectedJourneyVersion: started.projection.version,
      expectedAttemptVersion: attempt.version,
    ),
  );
  return source;
}

Future<void> _pump(
  WidgetTester tester,
  Widget content, {
  Locale locale = const Locale('en'),
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      supportedLocales: const [Locale('en'), Locale('fr'), Locale('ar')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      home: Scaffold(body: content),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
}
