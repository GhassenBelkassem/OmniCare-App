import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:omnicare_mobile/core/api/family_api.dart';
import 'package:omnicare_mobile/core/models/family_models.dart';
import 'package:omnicare_mobile/core/models/patient_profile.dart';
import 'package:omnicare_mobile/core/theme/omni_theme.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_care_subject.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_doctor_fixture.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_flow_controller.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_flow_shell.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_request_accepted_screen.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_request_confirmation_screen.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_request_decision_source.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_request_recovery_screen.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_request_review.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_request_source.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_request_state.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_request_waiting_screen.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_targeted_request_models.dart';
import 'package:omnicare_mobile/features/emergency/emergency_request_step2.dart';
import 'package:omnicare_mobile/providers/family_provider.dart';
import 'package:omnicare_mobile/providers/user_provider.dart';
import 'package:omnicare_mobile/repositories/family_repository.dart';

const bool _compileTimePatientDecisionControlsEnabled = bool.fromEnvironment(
  'P4_PATIENT_DECISION_CONTROLS',
  defaultValue: false,
);

class _EmptyFamilyRepository extends FamilyRepository {
  _EmptyFamilyRepository() : super(api: FamilyApi());

  @override
  Future<List<FamilyMember>> getFamilyMembers() async => const [];
}

class _ControlledRequestSource extends UrgentCabinetRequestSource {
  final completer = Completer<UrgentCabinetSubmissionOutcome>();

  @override
  bool get isDevelopmentFixture => true;

  @override
  Future<UrgentCabinetSubmissionOutcome> submit(
    UrgentCabinetRequestReview review,
  ) => completer.future;
}

PatientProfile _profile([String userId = 'patient-user-1']) {
  return PatientProfile(
    userId: userId,
    firstName: 'Sarah',
    lastName: 'Martin',
    displayName: 'Sarah Martin',
    dateOfBirth: null,
    gender: null,
    photoUrl: null,
    primaryPhone: const VerifiedContact(value: '+21698123456', verified: true),
    primaryEmail: const VerifiedContact(
      value: 'sarah@example.tn',
      verified: true,
    ),
    onboardingCompleted: true,
    onboardingStep: 4,
    preferredLanguage: 'fr',
    notifications: const ProfileNotificationPreferences(
      medications: true,
      appointments: true,
      passport: true,
    ),
    updatedAt: null,
  );
}

UrgentCabinetRequestReview _reviewFor({
  String doctorId = 'p4-demo-doctor-amine-ben-salah',
  String cabinetId = 'p4-demo-cabinet-lac-1',
  UrgentCabinetCareSubject subject = const UrgentCabinetCareSubject.self(),
  String patientName = 'Sarah Martin',
}) {
  final doctor = UrgentCabinetDoctorFixtureSource.developmentDoctorDetails
      .firstWhere((detail) => detail.doctorId == doctorId);
  final cabinet = doctor.cabinetById(cabinetId)!;
  final fee = UrgentCabinetDoctorFixtureSource.developmentFeeQuotes.firstWhere(
    (quote) => quote.doctorId == doctorId && quote.cabinetId == cabinetId,
  );
  return validateUrgentCabinetRequestReview(
    careSubject: subject,
    patientDisplayName: patientName,
    selectedDoctorId: doctorId,
    selectedCabinetId: cabinetId,
    doctor: doctor,
    cabinet: cabinet,
    feeQuote: fee,
    developmentFixturesEnabled: true,
    now: DateTime.utc(2026, 10, 12),
  ).review!;
}

Future<UrgentCabinetFlowController> _pendingController({
  String accountId = 'patient-user-1',
  String doctorId = 'p4-demo-doctor-amine-ben-salah',
  String cabinetId = 'p4-demo-cabinet-lac-1',
}) async {
  final controller = UrgentCabinetFlowController(accountId: accountId)
    ..selectSelf()
    ..selectDoctor(doctorId: doctorId, cabinetId: cabinetId);
  await controller.submitReview(
    review: _reviewFor(doctorId: doctorId, cabinetId: cabinetId),
    source: const UrgentCabinetDevelopmentRequestSource(),
  );
  return controller;
}

UrgentCabinetFlowController _authoritativeAcceptedController() {
  final snapshot = UrgentCabinetTargetedRequestSnapshot.fromJson({
    'requestId': '11111111-1111-4111-8111-111111111111',
    'journeyId': '22222222-2222-4222-8222-222222222222',
    'subjectType': 'SELF',
    'familyMemberId': null,
    'doctorId': '33333333-3333-4333-8333-333333333333',
    'practiceLocationId': '44444444-4444-4444-8444-444444444444',
    'doctorDisplayName': 'Dr Autorisé',
    'specialty': 'Médecine générale',
    'cabinetName': 'Cabinet autorisé',
    'cabinetAddress': '1 rue du Cabinet',
    'governorate': 'Tunis',
    'city': 'Tunis',
    'cabinetLatitude': 36.8065,
    'cabinetLongitude': 10.1815,
    'quotedFeeTnd': 60.000,
    'currency': 'TND',
    'configurationRevision': 1,
    'runtimeRevision': 2,
    'practiceLocationVersion': 3,
    'responseStatus': 'ACCEPTED',
    'responseRevision': 1,
    'respondedAt': '2026-10-19T10:02:00Z',
    'commitmentId': '55555555-5555-4555-8555-555555555555',
    'commitmentStatus': 'ACTIVE',
    'commitmentRevision': 0,
    'committedAt': '2026-10-19T10:02:00Z',
    'state': 'CABINET_COMMITTED',
    'requestRevision': 2,
    'journeyRevision': 2,
    'createdAt': '2026-10-19T10:00:00Z',
    'responseDeadlineAt': '2026-10-19T10:05:00Z',
    'terminalAt': '2026-10-19T10:02:00Z',
    'terminalReason': null,
    'allowedActions': <String>[],
    'replayed': false,
    'evaluatedAt': '2026-10-19T10:02:01Z',
  });
  final controller = UrgentCabinetFlowController(accountId: 'patient-user-1');
  expect(
    controller.applyAuthoritativeSnapshot(
      snapshot: snapshot,
      patientDisplayName: 'Sarah Martin',
    ),
    isTrue,
  );
  return controller;
}

UrgentCabinetDoctorDecisionEvent _acceptance(
  UrgentCabinetFlowController controller, {
  String? accountId,
  int? generation,
  String? doctorId,
  String? cabinetId,
  UrgentCabinetDecisionProvenance provenance =
      UrgentCabinetDecisionProvenance.developmentFixture,
}) {
  final attempt = controller.requestState as UrgentCabinetRequestAttemptState;
  return UrgentCabinetDoctorDecisionEvent(
    accountId: accountId ?? controller.accountId!,
    localAttemptGeneration: generation ?? attempt.localAttemptGeneration,
    doctorId: doctorId ?? attempt.review.doctorId,
    cabinetId: cabinetId ?? attempt.review.cabinetId,
    type: UrgentCabinetDoctorDecisionType.accepted,
    provenance: provenance,
  );
}

UrgentCabinetDecisionTransition _accept(
  UrgentCabinetFlowController controller,
) {
  return controller.applyDoctorDecision(
    _acceptance(controller),
    developmentAcceptanceAuthorized: true,
  );
}

Widget _acceptedApp({
  required UrgentCabinetFlowController controller,
  VoidCallback? onExit,
  Future<void> Function()? onOpenArrivalInstructions,
  double textScale = 1,
  EdgeInsets viewInsets = EdgeInsets.zero,
  EdgeInsets padding = EdgeInsets.zero,
}) {
  return ChangeNotifierProvider<UrgentCabinetFlowController>.value(
    value: controller,
    child: MaterialApp(
      theme: buildOmniTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          viewInsets: viewInsets,
          padding: padding,
        ),
        child: child!,
      ),
      home: UrgentCabinetRequestAcceptedScreen(
        onExitJourney: onExit ?? () {},
        onOpenArrivalInstructions: onOpenArrivalInstructions ?? () async {},
      ),
    ),
  );
}

Widget _flowLauncherApp(
  UrgentCabinetDevelopmentDecisionSource decisions, {
  bool? enableDevelopmentDecisionControls = false,
}) {
  final user = UserProvider()..setPatientProfile(_profile());
  final flowShell = enableDevelopmentDecisionControls == null
      ? UrgentCabinetFlowShell(
          doctorSource: const UrgentCabinetDoctorFixtureSource(),
          requestSource: const UrgentCabinetDevelopmentRequestSource(),
          decisionSource: decisions,
        )
      : UrgentCabinetFlowShell(
          doctorSource: const UrgentCabinetDoctorFixtureSource(),
          requestSource: const UrgentCabinetDevelopmentRequestSource(),
          decisionSource: decisions,
          developmentDecisionControlsEnabledForTesting:
              enableDevelopmentDecisionControls,
        );
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<UserProvider>.value(value: user),
      ChangeNotifierProvider(
        create: (_) => FamilyProvider(repository: _EmptyFamilyRepository()),
      ),
    ],
    child: MaterialApp(
      theme: buildOmniTheme(),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(builder: (_) => Scaffold(body: flowShell)),
              ),
              child: const Text('Urgent mode selection'),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<UrgentCabinetFlowController> _openWaiting(WidgetTester tester) async {
  await tester.tap(find.text('Sarah Martin'));
  await tester.pump();
  await tester.tap(find.text('Continuer'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), 'amine');
  await tester.pump();
  await tester.tap(find.text('Dr. Amine Ben Salah'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Cabinet'));
  await tester.pumpAndSettle();
  await tester.tap(
    find.byKey(const ValueKey('urgent-cabinet-detail-continue')),
  );
  await tester.pumpAndSettle();
  expect(find.byType(EmergencyRequestStep2), findsOneWidget);
  final body = find.byKey(const ValueKey('emergency-body-front'));
  await tester.ensureVisible(body);
  final bodyRect = tester.getRect(body);
  await tester.tapAt(
    Offset(
      bodyRect.left + bodyRect.width * .42,
      bodyRect.top + bodyRect.height * .2,
    ),
  );
  await tester.pump();
  final painSlider = find.byType(Slider);
  await tester.ensureVisible(painSlider);
  await tester.pumpAndSettle();
  await tester.drag(painSlider, const Offset(24, 0));
  await tester.pump();
  final description = find.byKey(const ValueKey('emergency-description'));
  await tester.ensureVisible(description);
  await tester.enterText(description, 'Douleur aiguë depuis ce matin.');
  await tester.pump();
  await tester.ensureVisible(find.byKey(const ValueKey('emergency-continue')));
  await tester.tap(find.byKey(const ValueKey('emergency-continue')));
  await tester.pumpAndSettle();
  await tester.tap(
    find.byKey(const ValueKey('urgent-cabinet-confirmation-submit')),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  final context = tester.element(
    find.byType(UrgentCabinetRequestWaitingScreen),
  );
  return context.read<UrgentCabinetFlowController>();
}

void main() {
  group('accepted decision lifecycle', () {
    test(
      'development control gate requires debug, flag, source, account and pending context',
      () async {
        final controller = await _pendingController();
        final source = UrgentCabinetDevelopmentDecisionSource();

        bool eligible({
          bool isDebugBuild = true,
          bool flagEnabled = true,
          bool decisionSourceActive = true,
          String? accountId = 'patient-user-1',
          UrgentCabinetRequestDecisionSource? decisionSource,
        }) {
          return canUsePatientDevelopmentDecisionControls(
            isDebugBuild: isDebugBuild,
            flagEnabled: flagEnabled,
            decisionSourceActive: decisionSourceActive,
            authenticatedAccountId: accountId,
            decisionSource: decisionSource ?? source,
            controller: controller,
          );
        }

        expect(eligible(), isTrue);
        expect(eligible(flagEnabled: false), isFalse);
        expect(eligible(isDebugBuild: false), isFalse);
        expect(eligible(decisionSourceActive: false), isFalse);
        expect(eligible(accountId: 'other-account'), isFalse);
        expect(
          eligible(
            decisionSource: const UrgentCabinetUnavailableDecisionSource(),
          ),
          isFalse,
        );

        controller.ensureAccount('patient-user-2');
        expect(eligible(accountId: 'patient-user-2'), isFalse);
        source.dispose();
      },
    );

    test(
      'explicit authorized pending decision preserves the frozen review',
      () async {
        final controller = await _pendingController();
        final review = controller.frozenReview;

        expect(_accept(controller), UrgentCabinetDecisionTransition.accepted);
        expect(controller.requestState, isA<UrgentCabinetRequestAccepted>());
        expect(controller.frozenReview, same(review));
        expect(controller.selectedDoctorId, review!.doctorId);
        expect(controller.selectedCabinetId, review.cabinetId);
      },
    );

    test(
      'development source emits acceptance only when explicitly invoked',
      () async {
        final controller = await _pendingController();
        final source = UrgentCabinetDevelopmentDecisionSource();
        final subscription = source.decisions.listen((event) {
          controller.applyDoctorDecision(
            event,
            developmentAcceptanceAuthorized: source.isDevelopmentFixture,
          );
        });

        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(
          controller.requestState,
          isA<UrgentCabinetRequestPendingDoctorResponse>(),
        );

        final pending =
            controller.requestState as UrgentCabinetRequestAttemptState;
        source.emitAccepted(
          accountId: controller.accountId!,
          localAttemptGeneration: pending.localAttemptGeneration,
          doctorId: pending.review.doctorId,
          cabinetId: pending.review.cabinetId,
        );
        expect(controller.requestState, isA<UrgentCabinetRequestAccepted>());

        await subscription.cancel();
        source.dispose();
      },
    );

    test(
      'identity, provenance and source authorization are mandatory',
      () async {
        Future<void> rejects(
          UrgentCabinetDoctorDecisionEvent Function(
            UrgentCabinetFlowController controller,
          )
          event, {
          bool authorized = true,
        }) async {
          final controller = await _pendingController();
          expect(
            controller.applyDoctorDecision(
              event(controller),
              developmentAcceptanceAuthorized: authorized,
            ),
            UrgentCabinetDecisionTransition.rejected,
          );
          expect(
            controller.requestState,
            isA<UrgentCabinetRequestPendingDoctorResponse>(),
          );
        }

        await rejects(
          (controller) => _acceptance(controller),
          authorized: false,
        );
        await rejects(
          (controller) => _acceptance(controller, accountId: 'other-account'),
        );
        await rejects(
          (controller) => _acceptance(
            controller,
            generation:
                (controller.requestState as UrgentCabinetRequestAttemptState)
                    .localAttemptGeneration +
                1,
          ),
        );
        await rejects(
          (controller) => _acceptance(controller, doctorId: 'other-doctor'),
        );
        await rejects(
          (controller) => _acceptance(controller, cabinetId: 'other-cabinet'),
        );
        await rejects(
          (controller) => _acceptance(
            controller,
            provenance: UrgentCabinetDecisionProvenance.service,
          ),
        );
      },
    );

    test(
      'acceptance is rejected during submission and after disposal',
      () async {
        final submitting =
            UrgentCabinetFlowController(accountId: 'patient-user-1')
              ..selectSelf()
              ..selectDoctor(
                doctorId: 'p4-demo-doctor-amine-ben-salah',
                cabinetId: 'p4-demo-cabinet-lac-1',
              );
        final source = _ControlledRequestSource();
        unawaited(
          submitting.submitReview(review: _reviewFor(), source: source),
        );
        final review = submitting.frozenReview!;
        final generation = submitting.requestState.localAttemptGeneration!;
        final event = UrgentCabinetDoctorDecisionEvent(
          accountId: 'patient-user-1',
          localAttemptGeneration: generation,
          doctorId: review.doctorId,
          cabinetId: review.cabinetId,
          type: UrgentCabinetDoctorDecisionType.accepted,
          provenance: UrgentCabinetDecisionProvenance.developmentFixture,
        );
        expect(
          submitting.applyDoctorDecision(
            event,
            developmentAcceptanceAuthorized: true,
          ),
          UrgentCabinetDecisionTransition.rejected,
        );
        submitting.endDevelopmentSimulation();
        source.completer.complete(const UrgentCabinetSubmissionAcknowledged());

        final disposed = await _pendingController();
        final disposedEvent = _acceptance(disposed);
        disposed.dispose();
        expect(
          disposed.applyDoctorDecision(
            disposedEvent,
            developmentAcceptanceAuthorized: true,
          ),
          UrgentCabinetDecisionTransition.obsolete,
        );
      },
    );

    test(
      'duplicate and post-decline or unavailable acceptance are rejected',
      () async {
        final accepted = await _pendingController();
        final event = _acceptance(accepted);
        expect(
          accepted.applyDoctorDecision(
            event,
            developmentAcceptanceAuthorized: true,
          ),
          UrgentCabinetDecisionTransition.accepted,
        );
        expect(
          accepted.applyDoctorDecision(
            event,
            developmentAcceptanceAuthorized: true,
          ),
          UrgentCabinetDecisionTransition.rejected,
        );

        for (final type in [
          UrgentCabinetDoctorDecisionType.declined,
          UrgentCabinetDoctorDecisionType.unavailable,
        ]) {
          final terminal = await _pendingController();
          final pending =
              terminal.requestState as UrgentCabinetRequestAttemptState;
          terminal.applyDoctorDecision(
            UrgentCabinetDoctorDecisionEvent(
              accountId: terminal.accountId!,
              localAttemptGeneration: pending.localAttemptGeneration,
              doctorId: pending.review.doctorId,
              cabinetId: pending.review.cabinetId,
              type: type,
              provenance: UrgentCabinetDecisionProvenance.developmentFixture,
            ),
          );
          expect(
            terminal.applyDoctorDecision(
              UrgentCabinetDoctorDecisionEvent(
                accountId: terminal.accountId!,
                localAttemptGeneration: pending.localAttemptGeneration,
                doctorId: pending.review.doctorId,
                cabinetId: pending.review.cabinetId,
                type: UrgentCabinetDoctorDecisionType.accepted,
                provenance: UrgentCabinetDecisionProvenance.developmentFixture,
              ),
              developmentAcceptanceAuthorized: true,
            ),
            UrgentCabinetDecisionTransition.rejected,
          );
        }
      },
    );

    test(
      'stale acceptance cannot cross retry, reset, exit or account change',
      () async {
        final retried = await _pendingController();
        final oldAcceptance = _acceptance(retried);
        final pending =
            retried.requestState as UrgentCabinetRequestAttemptState;
        retried.applyDoctorDecision(
          UrgentCabinetDoctorDecisionEvent(
            accountId: retried.accountId!,
            localAttemptGeneration: pending.localAttemptGeneration,
            doctorId: pending.review.doctorId,
            cabinetId: pending.review.cabinetId,
            type: UrgentCabinetDoctorDecisionType.declined,
            provenance: UrgentCabinetDecisionProvenance.developmentFixture,
          ),
        );
        retried.prepareDoctorRetry();
        retried.selectDoctor(
          doctorId: 'p4-demo-doctor-ines-trabelsi',
          cabinetId: 'p4-demo-cabinet-menzah-1',
        );
        await retried.submitReview(
          review: _reviewFor(
            doctorId: 'p4-demo-doctor-ines-trabelsi',
            cabinetId: 'p4-demo-cabinet-menzah-1',
          ),
          source: const UrgentCabinetDevelopmentRequestSource(),
        );
        expect(
          retried.applyDoctorDecision(
            oldAcceptance,
            developmentAcceptanceAuthorized: true,
          ),
          UrgentCabinetDecisionTransition.rejected,
        );

        for (final invalidate in <void Function(UrgentCabinetFlowController)>[
          (controller) =>
              controller.beginNewJourney(accountId: 'patient-user-1'),
          (controller) => controller.ensureAccount('patient-user-2'),
          (controller) => controller.endDevelopmentSimulation(),
        ]) {
          final controller = await _pendingController();
          final event = _acceptance(controller);
          invalidate(controller);
          expect(
            controller.applyDoctorDecision(
              event,
              developmentAcceptanceAuthorized: true,
            ),
            UrgentCabinetDecisionTransition.rejected,
          );
        }
      },
    );

    test(
      'profile and release source cannot generate fixture acceptance',
      () async {
        final source = UrgentCabinetRequestDecisionSources.forBuild(
          enableDevelopmentFixtures: false,
        );
        expect(source, isA<UrgentCabinetUnavailableDecisionSource>());
        expect(source.isDevelopmentFixture, isFalse);
        await expectLater(source.decisions, emitsDone);
        source.dispose();
      },
    );
  });

  group('accepted presentation', () {
    testWidgets(
      'authoritative acceptance offers external directions without arrival preview',
      (tester) async {
        final controller = _authoritativeAcceptedController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(_acceptedApp(controller: controller));

        expect(
          find.byKey(const ValueKey('urgent-cabinet-directions-available')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('urgent-cabinet-open-directions')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('urgent-cabinet-arrival-entry-card')),
          findsNothing,
        );
      },
    );

    testWidgets('shows the immutable context and honest simulation limits', (
      tester,
    ) async {
      final controller = await _pendingController();
      final frozen = controller.frozenReview!;
      _accept(controller);
      await tester.pumpWidget(_acceptedApp(controller: controller));

      expect(find.text('Votre demande a été acceptée'), findsOneWidget);
      expect(
        find.text(
          'Le médecin a accepté votre demande de consultation urgente au cabinet.',
        ),
        findsOneWidget,
      );
      expect(
        find.text("Simulation — aucune demande réelle n'a été envoyée."),
        findsOneWidget,
      );
      expect(find.text(frozen.patientDisplayName), findsOneWidget);
      expect(find.text(frozen.doctorDisplayName), findsOneWidget);
      expect(find.text(frozen.specialty), findsOneWidget);
      expect(find.text(frozen.cabinetName), findsOneWidget);
      expect(find.textContaining(frozen.cabinetAddress!), findsOneWidget);
      expect(find.text('75,000 DT'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('urgent-cabinet-arrival-entry-card')),
        findsOneWidget,
      );
      expect(find.text('Préparez votre arrivée'), findsOneWidget);
      expect(find.text("Voir les instructions d'arrivée"), findsOneWidget);
      expect(find.text('Itinéraire'), findsOneWidget);
      expect(
        find.text(
          'Itinéraire indisponible pour les adresses de démonstration.',
        ),
        findsOneWidget,
      );
      final directions = find.byKey(
        const ValueKey('urgent-cabinet-directions-unavailable'),
      );
      expect(
        find.descendant(
          of: directions,
          matching: find.byType(ButtonStyleButton),
        ),
        findsNothing,
      );
      expect(find.textContaining('créneau'), findsNothing);
      expect(find.textContaining('Date et heure'), findsNothing);
      expect(find.textContaining('Temps estimé'), findsNothing);
      expect(find.textContaining('Rendez-vous'), findsNothing);
    });

    testWidgets(
      'Back is protected and confirmed exit clears the full journey',
      (tester) async {
        final controller = await _pendingController();
        _accept(controller);
        var exits = 0;
        await tester.pumpWidget(
          _acceptedApp(
            controller: controller,
            onExit: () {
              controller.endDevelopmentSimulation();
              exits++;
            },
          ),
        );

        await tester.binding.handlePopRoute();
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('urgent-cabinet-accepted-exit-dialog')),
          findsOneWidget,
        );
        expect(exits, 0);
        await tester.tap(
          find.byKey(const ValueKey('urgent-cabinet-confirm-accepted-exit')),
        );
        await tester.pumpAndSettle();

        expect(exits, 1);
        expect(controller.requestState, isA<UrgentCabinetRequestDraft>());
        expect(controller.selectedSubject, isNull);
        expect(controller.selectedDoctorId, isNull);
        expect(controller.selectedCabinetId, isNull);
        expect(controller.frozenReview, isNull);
        expect(controller.excludedDoctorIds, isEmpty);
      },
    );

    testWidgets('small screen and large text remain overflow-free', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = await _pendingController();
      _accept(controller);

      await tester.pumpWidget(
        _acceptedApp(controller: controller, textScale: 1.6),
      );
      await tester.pump();

      expect(
        find.byKey(const ValueKey('urgent-cabinet-accepted-exit')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('compact height scrolls content and both Patient controls', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 420));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = _authoritativeAcceptedController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(_acceptedApp(controller: controller));
      await tester.pump();

      final compactScroll = find.byKey(
        const PageStorageKey('urgent-cabinet-accepted-compact-scroll'),
      );
      final compactScrollable = find.descendant(
        of: compactScroll,
        matching: find.byType(Scrollable),
      );
      expect(compactScroll, findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('urgent-cabinet-withdraw')),
        500,
        scrollable: compactScrollable,
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('urgent-cabinet-accepted-exit')),
        200,
        scrollable: compactScrollable,
      );
      expect(
        find.byKey(const ValueKey('urgent-cabinet-withdraw')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('urgent-cabinet-accepted-exit')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('normal portrait retains fixed footer without overflow', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = _authoritativeAcceptedController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(_acceptedApp(controller: controller));
      await tester.pump();

      expect(
        find.byKey(const PageStorageKey('urgent-cabinet-accepted-scroll')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('urgent-cabinet-withdraw')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('urgent-cabinet-accepted-exit')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'keyboard and safe areas switch to the compact scroll surface',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final controller = _authoritativeAcceptedController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(
          _acceptedApp(
            controller: controller,
            viewInsets: const EdgeInsets.only(bottom: 360),
            padding: const EdgeInsets.only(top: 24, bottom: 16),
          ),
        );
        await tester.pump();

        final compactScroll = find.byKey(
          const PageStorageKey('urgent-cabinet-accepted-compact-scroll'),
        );
        final compactScrollable = find.descendant(
          of: compactScroll,
          matching: find.byType(Scrollable),
        );
        expect(compactScroll, findsOneWidget);
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('urgent-cabinet-accepted-exit')),
          500,
          scrollable: compactScrollable,
        );
        expect(
          find.byKey(const ValueKey('urgent-cabinet-accepted-exit')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'transient one-pixel viewport restores all controls on resize',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1, 1));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final controller = _authoritativeAcceptedController();
        addTearDown(controller.dispose);

        await tester.pumpWidget(_acceptedApp(controller: controller));
        await tester.pump();
        expect(
          find.byKey(
            const ValueKey('urgent-cabinet-accepted-transient-viewport'),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);

        await tester.binding.setSurfaceSize(const Size(320, 568));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('urgent-cabinet-withdraw')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('urgent-cabinet-accepted-exit')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  });

  testWidgets(
    'compile-time patient decision flag gates the real pending flow',
    (tester) async {
      final decisions = UrgentCabinetDevelopmentDecisionSource();
      var emittedEvents = 0;
      final observation = decisions.decisions.listen((_) => emittedEvents++);
      addTearDown(observation.cancel);

      await tester.pumpWidget(
        _flowLauncherApp(decisions, enableDevelopmentDecisionControls: null),
      );
      final action = find.byKey(
        const ValueKey('urgent-cabinet-simulate-acceptance'),
      );

      expect(action, findsNothing);
      await tester.tap(find.text('Urgent mode selection'));
      await tester.pumpAndSettle();
      expect(action, findsNothing);

      final controller = await _openWaiting(tester);
      final frozenReview = controller.frozenReview;

      if (!_compileTimePatientDecisionControlsEnabled) {
        expect(action, findsNothing);
        expect(
          controller.requestState,
          isA<UrgentCabinetRequestPendingDoctorResponse>(),
        );
        expect(emittedEvents, 0);
        return;
      }

      expect(action, findsOneWidget);
      await tester.tap(action);
      expect(emittedEvents, 1);
      await tester.pumpAndSettle();

      expect(controller.requestState, isA<UrgentCabinetRequestAccepted>());
      expect(controller.frozenReview, same(frozenReview));
      expect(find.byType(UrgentCabinetRequestWaitingScreen), findsNothing);
      expect(find.byType(UrgentCabinetRequestAcceptedScreen), findsOneWidget);
      expect(find.text('Votre demande a été acceptée'), findsOneWidget);
      expect(find.text('Préparez votre arrivée'), findsOneWidget);
    },
  );

  testWidgets(
    'shell replaces waiting once and exit returns to urgent mode selection',
    (tester) async {
      final decisions = UrgentCabinetDevelopmentDecisionSource();
      await tester.pumpWidget(_flowLauncherApp(decisions));
      await tester.tap(find.text('Urgent mode selection'));
      await tester.pumpAndSettle();
      final controller = await _openWaiting(tester);
      final attempt =
          controller.requestState as UrgentCabinetRequestAttemptState;

      decisions.emitAccepted(
        accountId: 'patient-user-1',
        localAttemptGeneration: attempt.localAttemptGeneration,
        doctorId: attempt.review.doctorId,
        cabinetId: attempt.review.cabinetId,
      );
      await tester.pumpAndSettle();

      expect(find.byType(UrgentCabinetRequestAcceptedScreen), findsOneWidget);
      expect(find.byType(UrgentCabinetRequestWaitingScreen), findsNothing);
      expect(find.byType(UrgentCabinetRequestConfirmationScreen), findsNothing);
      expect(find.byType(UrgentCabinetRequestRecoveryScreen), findsNothing);

      decisions.emitAccepted(
        accountId: 'patient-user-1',
        localAttemptGeneration: attempt.localAttemptGeneration,
        doctorId: attempt.review.doctorId,
        cabinetId: attempt.review.cabinetId,
      );
      await tester.pump();
      expect(find.byType(UrgentCabinetRequestAcceptedScreen), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('urgent-cabinet-accepted-exit')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('urgent-cabinet-confirm-accepted-exit')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Urgent mode selection'), findsOneWidget);
      expect(find.byType(UrgentCabinetRequestAcceptedScreen), findsNothing);
      expect(find.byType(UrgentCabinetRequestWaitingScreen), findsNothing);
      expect(controller.requestState, isA<UrgentCabinetRequestDraft>());
      expect(controller.selectedSubject, isNull);
      expect(controller.excludedDoctorIds, isEmpty);
    },
  );

  testWidgets(
    'debug control emits once and naturally reaches accepted arrival instructions',
    (tester) async {
      final decisions = UrgentCabinetDevelopmentDecisionSource();
      var emittedEvents = 0;
      final observation = decisions.decisions.listen((_) => emittedEvents++);
      addTearDown(observation.cancel);

      await tester.pumpWidget(
        _flowLauncherApp(decisions, enableDevelopmentDecisionControls: true),
      );
      await tester.tap(find.text('Urgent mode selection'));
      await tester.pumpAndSettle();
      final controller = await _openWaiting(tester);
      final frozenReview = controller.frozenReview;
      final action = find.byKey(
        const ValueKey('urgent-cabinet-simulate-acceptance'),
      );

      expect(action, findsOneWidget);
      await tester.tap(action);
      await tester.tap(action, warnIfMissed: false);
      expect(emittedEvents, 1);
      await tester.pumpAndSettle();

      expect(controller.requestState, isA<UrgentCabinetRequestAccepted>());
      expect(controller.frozenReview, same(frozenReview));
      expect(find.text('Votre demande a été acceptée'), findsOneWidget);
      expect(find.text('Préparez votre arrivée'), findsOneWidget);
      expect(find.text(frozenReview!.patientDisplayName), findsOneWidget);
      expect(find.text(frozenReview.doctorDisplayName), findsOneWidget);
      expect(find.text(frozenReview.cabinetName), findsOneWidget);
      expect(
        find.text(formatUrgentCabinetFee(frozenReview.feeQuote)),
        findsOneWidget,
      );

      final arrivalAction = find.text("Voir les instructions d'arrivée");
      await tester.ensureVisible(arrivalAction);
      await tester.pumpAndSettle();
      await tester.tap(arrivalAction);
      await tester.pumpAndSettle();
      expect(find.text("Instructions d'arrivée"), findsWidgets);

      final qrPreviewAction = find.byKey(
        const ValueKey('urgent-cabinet-open-patient-qr-preview'),
      );
      await tester.scrollUntilVisible(
        qrPreviewAction,
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(qrPreviewAction);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('urgent-cabinet-patient-qr-preview-screen')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey('urgent-cabinet-patient-qr-preview-back')),
      );
      await tester.pumpAndSettle();
      expect(find.text("Instructions d'arrivée"), findsWidgets);

      await tester.tap(
        find.byKey(const ValueKey('urgent-cabinet-arrival-back')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Votre demande a été acceptée'), findsOneWidget);
      expect(controller.frozenReview, same(frozenReview));
    },
  );
}
