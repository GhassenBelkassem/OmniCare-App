import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:omnicare_mobile/core/theme/omni_theme.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_arrival_instructions_screen.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_care_subject.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_doctor_fixture.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_flow_controller.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_request_accepted_screen.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_request_decision_source.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_request_review.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_request_source.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_request_state.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_targeted_request_models.dart';

const _authoritativeRequestId = '11111111-1111-4111-8111-111111111111';

UrgentCabinetTargetedRequestSnapshot _authoritativeAcceptedSnapshot({
  String requestId = _authoritativeRequestId,
  int responseRevision = 1,
  String evaluatedAt = '2026-10-21T10:02:01Z',
}) => UrgentCabinetTargetedRequestSnapshot.fromJson({
  'requestId': requestId,
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
  'responseRevision': responseRevision,
  'respondedAt': '2026-10-21T10:02:00Z',
  'commitmentId': '55555555-5555-4555-8555-555555555555',
  'commitmentStatus': 'ACTIVE',
  'commitmentRevision': 0,
  'committedAt': '2026-10-21T10:02:00Z',
  'state': 'CABINET_COMMITTED',
  'requestRevision': 2,
  'journeyRevision': 2,
  'createdAt': '2026-10-21T10:00:00Z',
  'responseDeadlineAt': '2026-10-21T10:05:00Z',
  'terminalAt': '2026-10-21T10:02:00Z',
  'terminalReason': null,
  'allowedActions': <String>[],
  'replayed': false,
  'evaluatedAt': evaluatedAt,
});

UrgentCabinetRequestReview _review({
  UrgentCabinetCareSubject subject = const UrgentCabinetCareSubject.self(),
  String patientName = 'Sarah Martin',
}) {
  final doctor = UrgentCabinetDoctorFixtureSource.developmentDoctorDetails
      .firstWhere(
        (value) => value.doctorId == 'p4-demo-doctor-amine-ben-salah',
      );
  final cabinet = doctor.cabinetById('p4-demo-cabinet-lac-1')!;
  final fee = UrgentCabinetDoctorFixtureSource.developmentFeeQuotes.firstWhere(
    (value) =>
        value.doctorId == doctor.doctorId &&
        value.cabinetId == cabinet.cabinetId,
  );
  return validateUrgentCabinetRequestReview(
    careSubject: subject,
    patientDisplayName: patientName,
    selectedDoctorId: doctor.doctorId,
    selectedCabinetId: cabinet.cabinetId,
    doctor: doctor,
    cabinet: cabinet,
    feeQuote: fee,
    developmentFixturesEnabled: true,
    now: DateTime.utc(2026, 10, 12),
  ).review!;
}

Future<UrgentCabinetFlowController> _acceptedController({
  String accountId = 'patient-user-1',
  UrgentCabinetCareSubject subject = const UrgentCabinetCareSubject.self(),
  String patientName = 'Sarah Martin',
}) async {
  final review = _review(subject: subject, patientName: patientName);
  final controller = UrgentCabinetFlowController(accountId: accountId);
  if (subject.isSelf) {
    controller.selectSelf();
  } else {
    controller.selectFamilyMember(subject.familyMemberId!);
  }
  controller.selectDoctor(
    doctorId: review.doctorId,
    cabinetId: review.cabinetId,
  );
  await controller.submitReview(
    review: review,
    source: const UrgentCabinetDevelopmentRequestSource(),
  );
  final pending = controller.requestState as UrgentCabinetRequestAttemptState;
  controller.applyDoctorDecision(
    UrgentCabinetDoctorDecisionEvent(
      accountId: accountId,
      localAttemptGeneration: pending.localAttemptGeneration,
      doctorId: review.doctorId,
      cabinetId: review.cabinetId,
      type: UrgentCabinetDoctorDecisionType.accepted,
      provenance: UrgentCabinetDecisionProvenance.developmentFixture,
    ),
    developmentAcceptanceAuthorized: true,
  );
  return controller;
}

UrgentCabinetFlowController _authoritativeAcceptedController() {
  final controller = UrgentCabinetFlowController(accountId: 'patient-user-1');
  expect(
    controller.applyAuthoritativeSnapshot(
      snapshot: _authoritativeAcceptedSnapshot(),
      patientDisplayName: 'Sarah Martin',
    ),
    isTrue,
  );
  return controller;
}

Widget _acceptedNavigatorApp({
  required UrgentCabinetFlowController controller,
  VoidCallback? onExit,
  Future<void> Function(BuildContext context)? onOpen,
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
      home: Builder(
        builder: (context) => UrgentCabinetRequestAcceptedScreen(
          onExitJourney: onExit ?? () {},
          onOpenArrivalInstructions: () {
            if (onOpen != null) return onOpen(context);
            final state =
                controller.requestState as UrgentCabinetRequestAccepted;
            return Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => UrgentCabinetArrivalInstructionsScreen(
                  review: state.review,
                  localAttemptGeneration: state.localAttemptGeneration,
                  accountId: controller.accountId!,
                  authoritativeRequestId:
                      state.authoritativeSnapshot?.requestId,
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}

Widget _instructionsApp({
  required UrgentCabinetFlowController controller,
  double textScale = 1,
}) {
  final state = controller.requestState as UrgentCabinetRequestAccepted;
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
      home: UrgentCabinetArrivalInstructionsScreen(
        review: state.review,
        localAttemptGeneration: state.localAttemptGeneration,
        accountId: controller.accountId!,
        authoritativeRequestId: state.authoritativeSnapshot?.requestId,
      ),
    ),
  );
}

Widget _authoritativeRouteNavigatorApp({
  required UrgentCabinetFlowController controller,
}) {
  return ChangeNotifierProvider<UrgentCabinetFlowController>.value(
    value: controller,
    child: MaterialApp(
      theme: buildOmniTheme(),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              key: const ValueKey('open-authoritative-arrival-route'),
              onPressed: () {
                final accepted =
                    controller.requestState as UrgentCabinetRequestAccepted;
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => UrgentCabinetArrivalInstructionsScreen(
                      review: accepted.review,
                      localAttemptGeneration: accepted.localAttemptGeneration,
                      accountId: controller.accountId!,
                      authoritativeRequestId:
                          accepted.authoritativeSnapshot!.requestId,
                    ),
                  ),
                );
              },
              child: const Text('Open arrival route'),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _openInstructions(WidgetTester tester) async {
  final action = find.byKey(
    const ValueKey('urgent-cabinet-open-arrival-instructions'),
  );
  await tester.scrollUntilVisible(
    action,
    180,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(action);
  await tester.pumpAndSettle();
}

void main() {
  group('arrival entry and navigation', () {
    testWidgets('valid accepted development request shows the additive card', (
      tester,
    ) async {
      final controller = await _acceptedController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_acceptedNavigatorApp(controller: controller));

      expect(
        find.byKey(const ValueKey('urgent-cabinet-arrival-entry-card')),
        findsOneWidget,
      );
      expect(find.text('Préparez votre arrivée'), findsOneWidget);
      expect(find.text('Itinéraire'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('urgent-cabinet-accepted-exit')),
        findsOneWidget,
      );
    });

    testWidgets('pending, declined and unavailable requests expose no entry', (
      tester,
    ) async {
      for (final decision in <UrgentCabinetDoctorDecisionType?>[
        null,
        UrgentCabinetDoctorDecisionType.declined,
        UrgentCabinetDoctorDecisionType.unavailable,
      ]) {
        final controller = UrgentCabinetFlowController(
          accountId: 'patient-user-1',
        )..selectSelf();
        final review = _review();
        controller.selectDoctor(
          doctorId: review.doctorId,
          cabinetId: review.cabinetId,
        );
        await controller.submitReview(
          review: review,
          source: const UrgentCabinetDevelopmentRequestSource(),
        );
        if (decision != null) {
          final pending =
              controller.requestState as UrgentCabinetRequestAttemptState;
          controller.applyDoctorDecision(
            UrgentCabinetDoctorDecisionEvent(
              accountId: 'patient-user-1',
              localAttemptGeneration: pending.localAttemptGeneration,
              doctorId: review.doctorId,
              cabinetId: review.cabinetId,
              type: decision,
              provenance: UrgentCabinetDecisionProvenance.developmentFixture,
            ),
          );
        }
        await tester.pumpWidget(_acceptedNavigatorApp(controller: controller));
        expect(
          find.byKey(const ValueKey('urgent-cabinet-arrival-entry-card')),
          findsNothing,
        );
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
      }
    });

    testWidgets('Back returns to the same accepted state without exiting', (
      tester,
    ) async {
      final controller = await _acceptedController();
      addTearDown(controller.dispose);
      final accepted = controller.requestState as UrgentCabinetRequestAccepted;
      final review = accepted.review;
      var exits = 0;
      await tester.pumpWidget(
        _acceptedNavigatorApp(controller: controller, onExit: () => exits++),
      );

      await _openInstructions(tester);
      expect(
        find.byType(UrgentCabinetArrivalInstructionsScreen),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('urgent-cabinet-arrival-back')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Votre demande a été acceptée'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('urgent-cabinet-accepted-exit-dialog')),
        findsNothing,
      );
      expect(exits, 0);
      expect(controller.requestState, same(accepted));
      expect(controller.frozenReview, same(review));
      expect(controller.requestState, isA<UrgentCabinetRequestAccepted>());
    });

    testWidgets('rapid repeated taps request only one instructions route', (
      tester,
    ) async {
      final controller = await _acceptedController();
      addTearDown(controller.dispose);
      final pendingNavigation = Completer<void>();
      var opens = 0;
      await tester.pumpWidget(
        _acceptedNavigatorApp(
          controller: controller,
          onOpen: (_) {
            opens++;
            return pendingNavigation.future;
          },
        ),
      );
      final action = find.byKey(
        const ValueKey('urgent-cabinet-open-arrival-instructions'),
      );
      await tester.scrollUntilVisible(
        action,
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(action);
      await tester.tap(action);
      expect(opens, 1);
      pendingNavigation.complete();
      await tester.pump();
    });

    testWidgets(
      'first tap survives overlapping and later authoritative refreshes',
      (tester) async {
        final controller = _authoritativeAcceptedController();
        addTearDown(controller.dispose);
        final initial = controller.requestState as UrgentCabinetRequestAccepted;
        await tester.pumpWidget(
          _authoritativeRouteNavigatorApp(controller: controller),
        );
        await tester.tap(
          find.byKey(const ValueKey('open-authoritative-arrival-route')),
        );
        expect(
          controller.applyAuthoritativeSnapshot(
            snapshot: _authoritativeAcceptedSnapshot(
              responseRevision: 2,
              evaluatedAt: '2026-10-21T10:02:21Z',
            ),
            patientDisplayName: 'Sarah Martin',
          ),
          isTrue,
        );
        await tester.pumpAndSettle();

        expect(
          find.byType(UrgentCabinetArrivalInstructionsScreen),
          findsOneWidget,
        );
        expect(controller.requestState, isA<UrgentCabinetRequestAccepted>());
        expect(
          (controller.requestState as UrgentCabinetRequestAccepted).review,
          isNot(same(initial.review)),
        );

        expect(
          controller.applyAuthoritativeSnapshot(
            snapshot: _authoritativeAcceptedSnapshot(
              responseRevision: 3,
              evaluatedAt: '2026-10-21T10:02:41Z',
            ),
            patientDisplayName: 'Sarah Martin',
          ),
          isTrue,
        );
        await tester.pumpAndSettle();
        expect(
          find.byType(UrgentCabinetArrivalInstructionsScreen),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const ValueKey('urgent-cabinet-arrival-back')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Open arrival route'), findsOneWidget);
      },
    );

    testWidgets('account change and controller reset remove stale preview', (
      tester,
    ) async {
      for (final invalidate in <void Function(UrgentCabinetFlowController)>[
        (controller) => controller.ensureAccount('foreign-account'),
        (controller) => controller.endDevelopmentSimulation(),
      ]) {
        final controller = await _acceptedController();
        await tester.pumpWidget(_acceptedNavigatorApp(controller: controller));
        await _openInstructions(tester);
        expect(
          find.byType(UrgentCabinetArrivalInstructionsScreen),
          findsOneWidget,
        );

        invalidate(controller);
        await tester.pumpAndSettle();
        expect(
          find.byType(UrgentCabinetArrivalInstructionsScreen),
          findsNothing,
        );
        expect(find.text('Sarah Martin'), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
      }
    });

    test(
      'route eligibility uses stable request scope and rejects stale authority',
      () async {
        final controller = await _acceptedController();
        addTearDown(controller.dispose);
        final state = controller.requestState as UrgentCabinetRequestAccepted;
        expect(canOpenUrgentCabinetArrivalInstructions(controller), isTrue);
        expect(
          canOpenUrgentCabinetArrivalInstructions(
            controller,
            expectedReview: _review(
              subject: UrgentCabinetCareSubject.familyMember('family-42'),
            ),
          ),
          isFalse,
        );
        expect(
          canOpenUrgentCabinetArrivalInstructions(
            controller,
            expectedAttemptGeneration: state.localAttemptGeneration + 1,
          ),
          isFalse,
        );
        expect(
          canOpenUrgentCabinetArrivalInstructions(
            controller,
            expectedAccountId: 'foreign-account',
          ),
          isFalse,
        );
        controller.endDevelopmentSimulation();
        expect(canOpenUrgentCabinetArrivalInstructions(controller), isFalse);
      },
    );

    test('authoritative request identity fences a reused route', () {
      final controller = _authoritativeAcceptedController();
      addTearDown(controller.dispose);
      final state = controller.requestState as UrgentCabinetRequestAccepted;

      expect(
        canOpenUrgentCabinetArrivalInstructions(
          controller,
          expectedReview: state.review,
          expectedAuthoritativeRequestId: _authoritativeRequestId,
          expectedAttemptGeneration: state.localAttemptGeneration,
          expectedAccountId: controller.accountId,
        ),
        isTrue,
      );
      expect(
        canOpenUrgentCabinetArrivalInstructions(
          controller,
          expectedReview: state.review,
          expectedAuthoritativeRequestId:
              'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
          expectedAttemptGeneration: state.localAttemptGeneration,
          expectedAccountId: controller.accountId,
        ),
        isFalse,
      );
    });
  });

  group('instructions content and privacy', () {
    testWidgets('SELF uses the frozen accepted consultation snapshot', (
      tester,
    ) async {
      final controller = await _acceptedController();
      addTearDown(controller.dispose);
      final accepted = controller.requestState as UrgentCabinetRequestAccepted;
      final review = accepted.review;
      await tester.pumpWidget(_instructionsApp(controller: controller));

      expect(find.text("Instructions d'arrivée"), findsNWidgets(2));
      expect(find.text('Patient concerné'), findsOneWidget);
      expect(find.text(review.patientDisplayName), findsOneWidget);
      expect(find.text(review.doctorDisplayName), findsOneWidget);
      expect(find.text(review.specialty), findsOneWidget);
      expect(find.text(review.cabinetName), findsOneWidget);
      expect(find.textContaining(review.cabinetAddress!), findsOneWidget);
      expect(
        find.text(formatUrgentCabinetFee(review.feeQuote)),
        findsOneWidget,
      );
      expect(controller.frozenReview, same(review));
      expect(controller.requestState, same(accepted));
    });

    testWidgets('FAMILY_MEMBER remains the Patient concerné', (tester) async {
      final subject = UrgentCabinetCareSubject.familyMember('family-42');
      final controller = await _acceptedController(
        subject: subject,
        patientName: 'Yasmine Martin',
      );
      addTearDown(controller.dispose);
      final review = controller.frozenReview!;
      await tester.pumpWidget(_instructionsApp(controller: controller));

      expect(find.text('Yasmine Martin'), findsOneWidget);
      expect(find.text('Sarah Martin'), findsNothing);
      expect(review.careSubject, subject);
      expect(controller.selectedSubject, subject);
    });

    testWidgets('shows only instructions and explicit security limits', (
      tester,
    ) async {
      final controller = await _acceptedController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_instructionsApp(controller: controller));

      expect(find.text('Rendez-vous au cabinet'), findsOneWidget);
      expect(find.text('Préparez la vérification'), findsOneWidget);
      expect(find.text('Attendez la validation'), findsOneWidget);
      expect(
        find.text(
          "Signaler sa présence ne démarre pas la consultation et ne donne pas accès au dossier médical.",
        ),
        findsOneWidget,
      );
      expect(
        find.text("Démonstration — aucune présence réelle n'est enregistrée."),
        findsOneWidget,
      );
      for (final prohibited in <String>[
        'Je suis arrivé au cabinet',
        'Confirmer mon arrivée',
        'Présenter mon QR',
        'Scanner',
        'Démarrer la consultation',
      ]) {
        expect(find.text(prohibited), findsNothing);
      }
      expect(find.byIcon(Icons.qr_code), findsNothing);
      expect(find.byIcon(Icons.qr_code_scanner), findsNothing);
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(ElevatedButton), findsNothing);
    });

    testWidgets('internal identifiers and credentials are never rendered', (
      tester,
    ) async {
      final controller = await _acceptedController();
      addTearDown(controller.dispose);
      final review = controller.frozenReview!;
      await tester.pumpWidget(_instructionsApp(controller: controller));

      for (final secret in <String>[
        review.doctorId,
        review.cabinetId,
        'patient-user-1',
        'family-42',
        'commitment',
        'token',
        'MRS',
      ]) {
        expect(find.textContaining(secret), findsNothing);
      }
    });
  });

  group('responsive and accessible presentation', () {
    for (final size in <Size>[
      const Size(320, 568),
      const Size(360, 640),
      const Size(390, 844),
      const Size(430, 932),
      const Size(844, 390),
      const Size(900, 1100),
    ]) {
      testWidgets(
        '${size.width.toInt()}x${size.height.toInt()} is overflow-free',
        (tester) async {
          await tester.binding.setSurfaceSize(size);
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final controller = await _acceptedController();
          addTearDown(controller.dispose);
          await tester.pumpWidget(_instructionsApp(controller: controller));
          await tester.pump();

          expect(
            find.byKey(
              const ValueKey('urgent-cabinet-arrival-instructions-screen'),
            ),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }

    for (final scale in <double>[1.5, 2]) {
      testWidgets('${scale}x text scale remains scrollable and overflow-free', (
        tester,
      ) async {
        await tester.binding.setSurfaceSize(const Size(320, 568));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final controller = await _acceptedController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          _instructionsApp(controller: controller, textScale: scale),
        );
        await tester.drag(find.byType(Scrollable), const Offset(0, -500));
        await tester.pump();

        expect(
          find.byKey(const ValueKey('urgent-cabinet-arrival-security-notice')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Back has an accessible label and a 48px touch target', (
      tester,
    ) async {
      final controller = await _acceptedController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_instructionsApp(controller: controller));

      final back = find.byKey(const ValueKey('urgent-cabinet-arrival-back'));
      expect(back, findsOneWidget);
      expect(tester.getSize(back).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(back).height, greaterThanOrEqualTo(48));
      expect(find.byTooltip('Retour à la demande acceptée'), findsOneWidget);
    });
  });
}
