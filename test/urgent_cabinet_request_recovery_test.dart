import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:omnicare_mobile/core/api/family_api.dart';
import 'package:omnicare_mobile/core/models/family_models.dart';
import 'package:omnicare_mobile/core/models/patient_profile.dart';
import 'package:omnicare_mobile/core/theme/omni_theme.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_care_subject.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_care_subject_screen.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_doctor_directory_screen.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_doctor_fixture.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_flow_controller.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_flow_shell.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_request_decision_source.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_request_recovery_screen.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_request_review.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_request_source.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_request_state.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_request_waiting_screen.dart';
import 'package:omnicare_mobile/providers/family_provider.dart';
import 'package:omnicare_mobile/providers/user_provider.dart';
import 'package:omnicare_mobile/repositories/family_repository.dart';
import 'package:omnicare_mobile/core/result/result.dart';

class _EmptyFamilyRepository extends FamilyRepository {
  _EmptyFamilyRepository() : super(api: FamilyApi());

  @override
  Future<Result<List<FamilyMember>>> getFamilyMembers() async => Ok(const []);
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
  required String doctorId,
  required String cabinetId,
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
  UrgentCabinetCareSubject subject = const UrgentCabinetCareSubject.self(),
  String patientName = 'Sarah Martin',
  String doctorId = 'p4-demo-doctor-amine-ben-salah',
  String cabinetId = 'p4-demo-cabinet-lac-1',
}) async {
  final controller = UrgentCabinetFlowController(accountId: 'patient-user-1')
    ..updateSubject(subject)
    ..selectDoctor(doctorId: doctorId, cabinetId: cabinetId);
  await controller.submitReview(
    review: _reviewFor(
      doctorId: doctorId,
      cabinetId: cabinetId,
      subject: subject,
      patientName: patientName,
    ),
    source: const UrgentCabinetDevelopmentRequestSource(),
  );
  return controller;
}

UrgentCabinetDoctorDecisionEvent _decision(
  UrgentCabinetFlowController controller, {
  UrgentCabinetDoctorDecisionType type =
      UrgentCabinetDoctorDecisionType.declined,
  String accountId = 'patient-user-1',
  int? generation,
  String? doctorId,
  String? cabinetId,
}) {
  final pending = controller.requestState as UrgentCabinetRequestAttemptState;
  return UrgentCabinetDoctorDecisionEvent(
    accountId: accountId,
    localAttemptGeneration: generation ?? pending.localAttemptGeneration,
    doctorId: doctorId ?? pending.review.doctorId,
    cabinetId: cabinetId ?? pending.review.cabinetId,
    type: type,
    provenance: UrgentCabinetDecisionProvenance.developmentFixture,
  );
}

Widget _recoveryApp({
  required UrgentCabinetFlowController controller,
  VoidCallback? onRetry,
  VoidCallback? onExit,
  double textScale = 1,
}) {
  return ChangeNotifierProvider<UrgentCabinetFlowController>.value(
    value: controller,
    child: MaterialApp(
      theme: buildOmniTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: UrgentCabinetRequestRecoveryScreen(
        onChooseAnotherDoctor: onRetry ?? () {},
        onExitJourney: onExit ?? () {},
      ),
    ),
  );
}

Widget _flowApp(UrgentCabinetDevelopmentDecisionSource decisionSource) {
  final user = UserProvider()..setPatientProfile(_profile());
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<UserProvider>.value(value: user),
      ChangeNotifierProvider(
        create: (_) => FamilyProvider(repository: _EmptyFamilyRepository()),
      ),
    ],
    child: MaterialApp(
      theme: buildOmniTheme(),
      home: Scaffold(
        body: UrgentCabinetFlowShell(
          doctorSource: const UrgentCabinetDoctorFixtureSource(),
          requestSource: const UrgentCabinetDevelopmentRequestSource(),
          decisionSource: decisionSource,
        ),
      ),
    ),
  );
}

Widget _flowLauncherApp(UrgentCabinetDevelopmentDecisionSource decisionSource) {
  final user = UserProvider()..setPatientProfile(_profile());
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
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    body: UrgentCabinetFlowShell(
                      doctorSource: const UrgentCabinetDoctorFixtureSource(),
                      requestSource:
                          const UrgentCabinetDevelopmentRequestSource(),
                      decisionSource: decisionSource,
                    ),
                  ),
                ),
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
  await _completeSymptomIntake(tester);
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

Future<void> _completeSymptomIntake(WidgetTester tester) async {
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
  await tester.drag(painSlider, const Offset(24, 0));
  await tester.pump();
  final description = find.byKey(const ValueKey('emergency-description'));
  await tester.ensureVisible(description);
  await tester.enterText(description, 'Douleur aiguë depuis ce matin.');
  await tester.pump();
  final continueButton = find.byKey(const ValueKey('emergency-continue'));
  await tester.ensureVisible(continueButton);
  await tester.tap(continueButton);
  await tester.pumpAndSettle();
}

void main() {
  group('decision validation', () {
    test('valid pending decisions become declined or unavailable', () async {
      final declined = await _pendingController();
      expect(
        declined.applyDoctorDecision(_decision(declined)),
        UrgentCabinetDecisionTransition.declined,
      );
      expect(declined.requestState, isA<UrgentCabinetRequestDeclined>());

      final unavailable = await _pendingController();
      expect(
        unavailable.applyDoctorDecision(
          _decision(
            unavailable,
            type: UrgentCabinetDoctorDecisionType.unavailable,
          ),
        ),
        UrgentCabinetDecisionTransition.unavailable,
      );
      expect(unavailable.requestState, isA<UrgentCabinetRequestUnavailable>());
    });

    test(
      'wrong identity, stale, duplicate and accepted events are rejected',
      () async {
        Future<void> rejects(
          UrgentCabinetDoctorDecisionEvent Function(
            UrgentCabinetFlowController controller,
          )
          event,
        ) async {
          final controller = await _pendingController();
          expect(
            controller.applyDoctorDecision(event(controller)),
            UrgentCabinetDecisionTransition.rejected,
          );
          expect(
            controller.requestState,
            isA<UrgentCabinetRequestPendingDoctorResponse>(),
          );
        }

        await rejects(
          (controller) => _decision(controller, accountId: 'other'),
        );
        await rejects(
          (controller) => _decision(
            controller,
            generation:
                (controller.requestState as UrgentCabinetRequestAttemptState)
                    .localAttemptGeneration +
                1,
          ),
        );
        await rejects(
          (controller) => _decision(controller, doctorId: 'another-doctor'),
        );
        await rejects(
          (controller) => _decision(controller, cabinetId: 'another-cabinet'),
        );

        final unauthorizedAcceptance = await _pendingController();
        expect(
          unauthorizedAcceptance.applyDoctorDecision(
            _decision(
              unauthorizedAcceptance,
              type: UrgentCabinetDoctorDecisionType.accepted,
            ),
          ),
          UrgentCabinetDecisionTransition.rejected,
        );
        expect(
          unauthorizedAcceptance.requestState,
          isA<UrgentCabinetRequestPendingDoctorResponse>(),
        );

        final duplicate = await _pendingController();
        final event = _decision(duplicate);
        expect(
          duplicate.applyDoctorDecision(event),
          UrgentCabinetDecisionTransition.declined,
        );
        expect(
          duplicate.applyDoctorDecision(event),
          UrgentCabinetDecisionTransition.rejected,
        );
        expect(
          duplicate.applyDoctorDecision(
            UrgentCabinetDoctorDecisionEvent(
              accountId: event.accountId,
              localAttemptGeneration: event.localAttemptGeneration,
              doctorId: event.doctorId,
              cabinetId: event.cabinetId,
              type: UrgentCabinetDoctorDecisionType.unavailable,
              provenance: event.provenance,
            ),
          ),
          UrgentCabinetDecisionTransition.rejected,
        );
      },
    );

    test('release/profile factory cannot emit simulated decisions', () {
      final source = UrgentCabinetRequestDecisionSources.forBuild(
        enableDevelopmentFixtures: false,
      );
      expect(source, isA<UrgentCabinetUnavailableDecisionSource>());
      expect(source.isDevelopmentFixture, isFalse);
      source.dispose();
    });
  });

  group('subject-preserving retry', () {
    test('preserves exact family member and clears attempt data', () async {
      final subject = UrgentCabinetCareSubject.familyMember('family-42');
      final controller = await _pendingController(
        subject: subject,
        patientName: 'Aicha Martin',
      );
      final oldGeneration =
          (controller.requestState as UrgentCabinetRequestAttemptState)
              .localAttemptGeneration;
      controller.applyDoctorDecision(_decision(controller));

      expect(
        controller.prepareDoctorRetry(),
        UrgentCabinetDoctorRetryTransition.prepared,
      );
      expect(controller.selectedSubject, subject);
      expect(controller.selectedSubject?.familyMemberId, 'family-42');
      expect(controller.selectedDoctorId, isNull);
      expect(controller.selectedCabinetId, isNull);
      expect(controller.frozenReview, isNull);
      expect(controller.requestState, isA<UrgentCabinetRequestDraft>());
      expect(
        controller.excludedDoctorIds,
        contains('p4-demo-doctor-amine-ben-salah'),
      );

      controller.selectDoctor(
        doctorId: 'p4-demo-doctor-ines-trabelsi',
        cabinetId: 'p4-demo-cabinet-menzah-1',
      );
      await controller.submitReview(
        review: _reviewFor(
          doctorId: 'p4-demo-doctor-ines-trabelsi',
          cabinetId: 'p4-demo-cabinet-menzah-1',
          subject: subject,
          patientName: 'Aicha Martin',
        ),
        source: const UrgentCabinetDevelopmentRequestSource(),
      );
      final newGeneration =
          (controller.requestState as UrgentCabinetRequestAttemptState)
              .localAttemptGeneration;
      expect(newGeneration, greaterThan(oldGeneration));
    });

    test('old decisions cannot affect a retried attempt', () async {
      final controller = await _pendingController();
      final oldEvent = _decision(controller);
      controller.applyDoctorDecision(oldEvent);
      controller.prepareDoctorRetry();
      controller.selectDoctor(
        doctorId: 'p4-demo-doctor-ines-trabelsi',
        cabinetId: 'p4-demo-cabinet-menzah-1',
      );
      await controller.submitReview(
        review: _reviewFor(
          doctorId: 'p4-demo-doctor-ines-trabelsi',
          cabinetId: 'p4-demo-cabinet-menzah-1',
        ),
        source: const UrgentCabinetDevelopmentRequestSource(),
      );

      expect(
        controller.applyDoctorDecision(oldEvent),
        UrgentCabinetDecisionTransition.rejected,
      );
      expect(
        controller.requestState,
        isA<UrgentCabinetRequestPendingDoctorResponse>(),
      );
    });

    test(
      'account switch and full exit invalidate attempts and exclusions',
      () async {
        final switched = await _pendingController();
        final oldEvent = _decision(switched);
        switched.ensureAccount('patient-user-2');
        expect(
          switched.applyDoctorDecision(oldEvent),
          UrgentCabinetDecisionTransition.rejected,
        );
        expect(switched.requestState, isA<UrgentCabinetRequestDraft>());
        expect(switched.selectedSubject, isNull);

        final exited = await _pendingController();
        exited.applyDoctorDecision(_decision(exited));
        exited.prepareDoctorRetry();
        expect(exited.excludedDoctorIds, isNotEmpty);
        exited.endDevelopmentSimulation();
        expect(exited.excludedDoctorIds, isEmpty);
        expect(exited.selectedSubject, isNull);
        expect(exited.frozenReview, isNull);
      },
    );

    test('exclusions accumulate and clear only on a full reset', () async {
      final controller = await _pendingController();
      controller.applyDoctorDecision(_decision(controller));
      controller.prepareDoctorRetry();

      controller.selectDoctor(
        doctorId: 'p4-demo-doctor-ines-trabelsi',
        cabinetId: 'p4-demo-cabinet-menzah-1',
      );
      await controller.submitReview(
        review: _reviewFor(
          doctorId: 'p4-demo-doctor-ines-trabelsi',
          cabinetId: 'p4-demo-cabinet-menzah-1',
        ),
        source: const UrgentCabinetDevelopmentRequestSource(),
      );
      controller.applyDoctorDecision(_decision(controller));
      controller.prepareDoctorRetry();

      expect(controller.excludedDoctorIds, hasLength(2));
      controller.beginNewJourney(accountId: 'patient-user-1');
      expect(controller.excludedDoctorIds, isEmpty);
      expect(controller.selectedSubject, isNull);
    });
  });

  group('recovery presentation', () {
    testWidgets('declined renders frozen context and performs atomic retry', (
      tester,
    ) async {
      final controller = await _pendingController();
      controller.applyDoctorDecision(_decision(controller));
      var retries = 0;
      await tester.pumpWidget(
        _recoveryApp(controller: controller, onRetry: () => retries++),
      );

      expect(
        find.text("Le médecin n'a pas accepté votre demande"),
        findsOneWidget,
      );
      expect(find.text('Sarah Martin'), findsOneWidget);
      expect(find.text('Dr. Amine Ben Salah'), findsOneWidget);
      expect(find.text('Médecine générale'), findsOneWidget);
      expect(find.text('Cabinet Les Berges du Lac'), findsOneWidget);
      expect(find.text('75,000 DT'), findsOneWidget);
      expect(
        find.text("Simulation — aucune demande réelle n'a été envoyée."),
        findsOneWidget,
      );
      expect(
        find.textContaining("Aucun montant n'a été facturé"),
        findsOneWidget,
      );
      expect(find.textContaining('Itinéraire'), findsNothing);
      expect(find.textContaining('créneau'), findsNothing);
      expect(find.textContaining('paiement'), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey('urgent-cabinet-choose-another-doctor')),
      );
      await tester.pump();
      await tester.pump();
      expect(retries, 1);
      expect(controller.selectedSubject, const UrgentCabinetCareSubject.self());
      expect(controller.selectedDoctorId, isNull);
      expect(controller.selectedCabinetId, isNull);
      expect(controller.frozenReview, isNull);
    });

    testWidgets('unavailable uses distinct copy and Back confirms safe exit', (
      tester,
    ) async {
      final controller = await _pendingController();
      controller.applyDoctorDecision(
        _decision(
          controller,
          type: UrgentCabinetDoctorDecisionType.unavailable,
        ),
      );
      var exits = 0;
      await tester.pumpWidget(
        _recoveryApp(controller: controller, onExit: () => exits++),
      );

      expect(find.text("Ce médecin n'est plus disponible"), findsOneWidget);
      expect(find.textContaining('ne peut plus recevoir'), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('urgent-cabinet-recovery-exit-dialog')),
        findsOneWidget,
      );
      expect(exits, 0);
      await tester.tap(find.text('Rester'));
      await tester.pumpAndSettle();
      expect(find.byType(UrgentCabinetRequestRecoveryScreen), findsOneWidget);
    });

    testWidgets('narrow screen and large text remain overflow-free', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(320, 568));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final controller = await _pendingController();
      controller.applyDoctorDecision(_decision(controller));
      await tester.pumpWidget(
        _recoveryApp(controller: controller, textScale: 1.6),
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey('urgent-cabinet-choose-another-doctor')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets(
    'shell replaces waiting once and retry returns to retained directory state',
    (tester) async {
      final decisions = UrgentCabinetDevelopmentDecisionSource();
      await tester.pumpWidget(_flowApp(decisions));
      await tester.pumpAndSettle();
      final controller = await _openWaiting(tester);
      final attempt =
          controller.requestState as UrgentCabinetRequestAttemptState;

      decisions.emitDeclined(
        accountId: 'patient-user-1',
        localAttemptGeneration: attempt.localAttemptGeneration,
        doctorId: attempt.review.doctorId,
        cabinetId: attempt.review.cabinetId,
      );
      await tester.pumpAndSettle();

      expect(find.byType(UrgentCabinetRequestWaitingScreen), findsNothing);
      expect(find.byType(UrgentCabinetRequestRecoveryScreen), findsOneWidget);

      decisions.emitDeclined(
        accountId: 'patient-user-1',
        localAttemptGeneration: attempt.localAttemptGeneration,
        doctorId: attempt.review.doctorId,
        cabinetId: attempt.review.cabinetId,
      );
      await tester.pump();
      expect(find.byType(UrgentCabinetRequestRecoveryScreen), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('urgent-cabinet-choose-another-doctor')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(UrgentCabinetDoctorDirectoryScreen), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller?.text,
        'amine',
      );
      expect(controller.selectedSubject, const UrgentCabinetCareSubject.self());
      expect(controller.selectedDoctorId, isNull);
      expect(controller.excludedDoctorIds, contains(attempt.review.doctorId));
      expect(find.text('Dr. Amine Ben Salah'), findsNothing);
      expect(find.byType(UrgentCabinetCareSubjectScreen), findsNothing);
    },
  );

  testWidgets('no eligible alternatives uses the approved empty-state style', (
    tester,
  ) async {
    final selections = <(String, String)>[
      ('p4-demo-doctor-amine-ben-salah', 'p4-demo-cabinet-lac-1'),
      ('p4-demo-doctor-ines-trabelsi', 'p4-demo-cabinet-menzah-1'),
      ('p4-demo-doctor-youssef-gharbi', 'p4-demo-cabinet-lafayette-1'),
    ];
    final controller = await _pendingController(
      doctorId: selections.first.$1,
      cabinetId: selections.first.$2,
    );
    for (var index = 0; index < selections.length; index++) {
      controller.applyDoctorDecision(_decision(controller));
      controller.prepareDoctorRetry();
      if (index == selections.length - 1) break;
      final next = selections[index + 1];
      controller.selectDoctor(doctorId: next.$1, cabinetId: next.$2);
      await controller.submitReview(
        review: _reviewFor(doctorId: next.$1, cabinetId: next.$2),
        source: const UrgentCabinetDevelopmentRequestSource(),
      );
    }

    var exits = 0;
    await tester.pumpWidget(
      ChangeNotifierProvider<UrgentCabinetFlowController>.value(
        value: controller,
        child: MaterialApp(
          theme: buildOmniTheme(),
          home: UrgentCabinetDoctorDirectoryScreen(
            source: const UrgentCabinetDoctorFixtureSource(),
            onExitJourney: () => exits++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Aucun autre médecin disponible'), findsOneWidget);
    expect(find.text('Quitter la demande urgente'), findsOneWidget);
    expect(controller.selectedSubject, const UrgentCabinetCareSubject.self());
    expect(controller.excludedDoctorIds, hasLength(3));
    await tester.tap(find.text('Quitter la demande urgente'));
    expect(exits, 1);
  });

  testWidgets(
    'confirmed exit clears state and returns through the parent route',
    (tester) async {
      final decisions = UrgentCabinetDevelopmentDecisionSource();
      await tester.pumpWidget(_flowLauncherApp(decisions));
      await tester.tap(find.text('Urgent mode selection'));
      await tester.pumpAndSettle();
      final controller = await _openWaiting(tester);
      final attempt =
          controller.requestState as UrgentCabinetRequestAttemptState;
      decisions.emitUnavailable(
        accountId: 'patient-user-1',
        localAttemptGeneration: attempt.localAttemptGeneration,
        doctorId: attempt.review.doctorId,
        cabinetId: attempt.review.cabinetId,
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('urgent-cabinet-recovery-exit')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('urgent-cabinet-confirm-recovery-exit')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Urgent mode selection'), findsOneWidget);
      expect(find.byType(UrgentCabinetRequestRecoveryScreen), findsNothing);
      expect(controller.requestState, isA<UrgentCabinetRequestDraft>());
      expect(controller.selectedSubject, isNull);
      expect(controller.excludedDoctorIds, isEmpty);
    },
  );
}
