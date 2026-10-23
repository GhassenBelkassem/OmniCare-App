import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:omnicare_mobile/core/theme/omni_theme.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_arrival_instructions_screen.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_care_subject.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_check_in_presentation.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_doctor_fixture.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_flow_controller.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_patient_qr_preview_screen.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_request_accepted_screen.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_request_decision_source.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_request_review.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_request_source.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_request_state.dart';

const bool _patientCheckInScenariosEnabled = bool.fromEnvironment(
  'P4_PATIENT_CHECK_IN_SCENARIOS',
  defaultValue: false,
);

class _NonDevelopmentAcceptedController extends UrgentCabinetFlowController {
  _NonDevelopmentAcceptedController(this.review)
    : super(accountId: 'patient-user-1');

  final UrgentCabinetRequestReview review;

  @override
  String? get accountId => 'patient-user-1';

  @override
  UrgentCabinetCareSubject? get selectedSubject => review.careSubject;

  @override
  String? get selectedDoctorId => review.doctorId;

  @override
  String? get selectedCabinetId => review.cabinetId;

  @override
  UrgentCabinetRequestState get requestState => UrgentCabinetRequestAccepted(
    review: review,
    localAttemptGeneration: 1,
    isDevelopmentSimulation: false,
  );
}

UrgentCabinetRequestReview _review({
  UrgentCabinetCareSubject subject = const UrgentCabinetCareSubject.self(),
  String patientName = 'Sarah Martin',
}) {
  final doctor =
      UrgentCabinetDoctorFixtureSource.developmentDoctorDetails.first;
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
  UrgentCabinetCareSubject subject = const UrgentCabinetCareSubject.self(),
  String patientName = 'Sarah Martin',
}) async {
  final review = _review(subject: subject, patientName: patientName);
  final controller = UrgentCabinetFlowController(accountId: 'patient-user-1');
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
      accountId: controller.accountId!,
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

Widget _previewApp({
  required UrgentCabinetFlowController controller,
  double textScale = 1,
  bool disableAnimations = false,
}) {
  final accepted = controller.requestState as UrgentCabinetRequestAccepted;
  return ChangeNotifierProvider<UrgentCabinetFlowController>.value(
    value: controller,
    child: MaterialApp(
      theme: buildOmniTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
          disableAnimations: disableAnimations,
        ),
        child: child!,
      ),
      home: UrgentCabinetPatientQrPreviewScreen(
        review: accepted.review,
        localAttemptGeneration: accepted.localAttemptGeneration,
        accountId: controller.accountId!,
      ),
    ),
  );
}

Widget _journeyApp(UrgentCabinetFlowController controller) {
  return ChangeNotifierProvider<UrgentCabinetFlowController>.value(
    value: controller,
    child: MaterialApp(
      theme: buildOmniTheme(),
      home: Builder(
        builder: (acceptedContext) => UrgentCabinetRequestAcceptedScreen(
          onExitJourney: () {},
          onOpenArrivalInstructions: () {
            final accepted =
                controller.requestState as UrgentCabinetRequestAccepted;
            return Navigator.of(acceptedContext).push<void>(
              MaterialPageRoute<void>(
                builder: (instructionsContext) =>
                    UrgentCabinetArrivalInstructionsScreen(
                      review: accepted.review,
                      localAttemptGeneration: accepted.localAttemptGeneration,
                      accountId: controller.accountId!,
                      onOpenPatientQrPreview: () =>
                          Navigator.of(instructionsContext).push<void>(
                            MaterialPageRoute<void>(
                              builder: (_) =>
                                  UrgentCabinetPatientQrPreviewScreen(
                                    review: accepted.review,
                                    localAttemptGeneration:
                                        accepted.localAttemptGeneration,
                                    accountId: controller.accountId!,
                                  ),
                            ),
                          ),
                    ),
              ),
            );
          },
        ),
      ),
    ),
  );
}

Widget _invalidationApp(UrgentCabinetFlowController controller) {
  final accepted = controller.requestState as UrgentCabinetRequestAccepted;
  return ChangeNotifierProvider<UrgentCabinetFlowController>.value(
    value: controller,
    child: MaterialApp(
      theme: buildOmniTheme(),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: FilledButton(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => UrgentCabinetPatientQrPreviewScreen(
                    review: accepted.review,
                    localAttemptGeneration: accepted.localAttemptGeneration,
                    accountId: controller.accountId!,
                  ),
                ),
              ),
              child: const Text('Open preview'),
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

Future<void> _openPreview(WidgetTester tester) async {
  final action = find.byKey(
    const ValueKey('urgent-cabinet-open-patient-qr-preview'),
  );
  await tester.scrollUntilVisible(
    action,
    180,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(action);
  await tester.pumpAndSettle();
}

Future<void> _expandScenarioControls(WidgetTester tester) async {
  final toggle = find.byKey(
    const ValueKey('urgent-cabinet-patient-scenarios-toggle'),
  );
  await tester.scrollUntilVisible(
    toggle,
    180,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(toggle);
  await tester.pumpAndSettle();
}

Future<void> _selectScenario(
  WidgetTester tester,
  UrgentCabinetPatientCheckInPreviewState state,
) async {
  final selector = find.byKey(
    const ValueKey('urgent-cabinet-patient-scenario-selector'),
  );
  await tester.scrollUntilVisible(
    selector,
    140,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(selector);
  await tester.pumpAndSettle();
  final title = UrgentCabinetPatientCheckInPresentation(state).title;
  await tester.tap(find.text(title).last);
  await tester.pumpAndSettle();
}

Future<void> _showSelectedScenario(WidgetTester tester) async {
  final action = find.byKey(
    const ValueKey('urgent-cabinet-patient-show-selected-scenario'),
  );
  await tester.scrollUntilVisible(
    action,
    140,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(action);
  await tester.pumpAndSettle();
}

void main() {
  group('eligibility and immutable context', () {
    test(
      'pending and non-development states cannot expose the preview',
      () async {
        final pending = UrgentCabinetFlowController(accountId: 'patient-user-1')
          ..selectSelf()
          ..selectDoctor(
            doctorId: _review().doctorId,
            cabinetId: _review().cabinetId,
          );
        await pending.submitReview(
          review: _review(),
          source: const UrgentCabinetDevelopmentRequestSource(),
        );
        addTearDown(pending.dispose);
        expect(canOpenUrgentCabinetPatientQrPreview(pending), isFalse);

        final nonDevelopment = _NonDevelopmentAcceptedController(_review());
        addTearDown(nonDevelopment.dispose);
        expect(canOpenUrgentCabinetPatientQrPreview(nonDevelopment), isFalse);
      },
    );

    test('requires the stable accepted development attempt scope', () async {
      final controller = await _acceptedController();
      addTearDown(controller.dispose);
      final accepted = controller.requestState as UrgentCabinetRequestAccepted;

      expect(canOpenUrgentCabinetPatientQrPreview(controller), isTrue);
      expect(
        canOpenUrgentCabinetPatientQrPreview(
          controller,
          expectedReview: _review(
            subject: UrgentCabinetCareSubject.familyMember('family-42'),
          ),
        ),
        isFalse,
      );
      expect(
        canOpenUrgentCabinetPatientQrPreview(
          controller,
          expectedAttemptGeneration: accepted.localAttemptGeneration + 1,
        ),
        isFalse,
      );
      expect(
        canOpenUrgentCabinetPatientQrPreview(
          controller,
          expectedAccountId: 'foreign-account',
        ),
        isFalse,
      );

      controller.endDevelopmentSimulation();
      expect(canOpenUrgentCabinetPatientQrPreview(controller), isFalse);
    });

    testWidgets('SELF uses only the exact frozen accepted snapshot', (
      tester,
    ) async {
      final controller = await _acceptedController();
      addTearDown(controller.dispose);
      final accepted = controller.requestState as UrgentCabinetRequestAccepted;
      final review = accepted.review;
      await tester.pumpWidget(_previewApp(controller: controller));

      expect(find.text('QR de présence'), findsOneWidget);
      expect(find.text('Patient concerné'), findsOneWidget);
      expect(find.text(review.patientDisplayName), findsOneWidget);
      expect(find.text(review.doctorDisplayName), findsOneWidget);
      expect(find.text(review.specialty), findsOneWidget);
      expect(find.text(review.cabinetName), findsOneWidget);
      expect(find.textContaining(review.cabinetAddress!), findsOneWidget);
      expect(controller.requestState, same(accepted));
      expect(controller.frozenReview, same(review));
      expect(controller.selectedDoctorId, review.doctorId);
      expect(controller.selectedCabinetId, review.cabinetId);
      expect(
        formatUrgentCabinetFee(controller.frozenReview!.feeQuote),
        formatUrgentCabinetFee(review.feeQuote),
      );
    });

    testWidgets('FAMILY_MEMBER remains the displayed care recipient', (
      tester,
    ) async {
      final subject = UrgentCabinetCareSubject.familyMember('family-42');
      final controller = await _acceptedController(
        subject: subject,
        patientName: 'Yasmine Martin',
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(_previewApp(controller: controller));

      expect(find.text('Yasmine Martin'), findsOneWidget);
      expect(find.text('Sarah Martin'), findsNothing);
      expect(controller.selectedSubject, subject);
      expect(controller.frozenReview!.careSubject, subject);
    });
  });

  group('debug-only check-in scenarios', () {
    test(
      'gating requires debug, flag and the exact accepted context',
      () async {
        final controller = await _acceptedController();
        addTearDown(controller.dispose);
        final accepted =
            controller.requestState as UrgentCabinetRequestAccepted;

        expect(
          canShowUrgentCabinetPatientCheckInScenarios(
            controller,
            isDebugBuild: false,
            flagEnabled: true,
          ),
          isFalse,
        );
        expect(
          canShowUrgentCabinetPatientCheckInScenarios(
            controller,
            isDebugBuild: true,
            flagEnabled: false,
          ),
          isFalse,
        );
        expect(
          canShowUrgentCabinetPatientCheckInScenarios(
            controller,
            isDebugBuild: true,
            flagEnabled: true,
            expectedReview: accepted.review,
            expectedAttemptGeneration: accepted.localAttemptGeneration,
            expectedAccountId: controller.accountId,
          ),
          isTrue,
        );
        expect(
          canShowUrgentCabinetPatientCheckInScenarios(
            controller,
            isDebugBuild: true,
            flagEnabled: true,
            expectedAttemptGeneration: accepted.localAttemptGeneration + 1,
          ),
          isFalse,
        );
      },
    );

    testWidgets('the real compile-time flag controls widget visibility', (
      tester,
    ) async {
      final controller = await _acceptedController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_previewApp(controller: controller));

      expect(
        find.byKey(const ValueKey('urgent-cabinet-patient-debug-scenarios')),
        _patientCheckInScenariosEnabled ? findsOneWidget : findsNothing,
      );
      expect(
        find.byKey(const ValueKey('urgent-cabinet-patient-scenario-result')),
        findsNothing,
      );
    });

    if (_patientCheckInScenariosEnabled) {
      testWidgets('selection is explicit and clearing changes no authority', (
        tester,
      ) async {
        final controller = await _acceptedController();
        addTearDown(controller.dispose);
        final accepted = controller.requestState;
        final review = controller.frozenReview;
        final subject = controller.selectedSubject;
        final doctorId = controller.selectedDoctorId;
        final cabinetId = controller.selectedCabinetId;
        final fee = controller.frozenReview!.feeQuote;
        await tester.pumpWidget(_previewApp(controller: controller));

        expect(
          find.byKey(const ValueKey('urgent-cabinet-patient-scenario-result')),
          findsNothing,
        );
        await _expandScenarioControls(tester);
        expect(
          find.byKey(const ValueKey('urgent-cabinet-patient-scenario-result')),
          findsNothing,
        );

        await _selectScenario(
          tester,
          UrgentCabinetPatientCheckInPreviewState.unknownOutcome,
        );
        expect(
          find.byKey(const ValueKey('urgent-cabinet-patient-scenario-result')),
          findsNothing,
        );

        await _showSelectedScenario(tester);
        expect(find.text('Résultat non confirmé'), findsWidgets);
        expect(find.textContaining('nouvelle tentative'), findsWidgets);
        expect(find.text('Réessayer'), findsNothing);
        expect(find.text('Actualiser'), findsNothing);
        expect(
          find.text(
            UrgentCabinetPatientCheckInPresentation.demonstrationDisclosure,
          ),
          findsOneWidget,
        );

        expect(controller.requestState, same(accepted));
        expect(controller.frozenReview, same(review));
        expect(controller.selectedSubject, subject);
        expect(controller.selectedDoctorId, doctorId);
        expect(controller.selectedCabinetId, cabinetId);
        expect(controller.frozenReview!.feeQuote, same(fee));

        final clear = find.byKey(
          const ValueKey('urgent-cabinet-patient-clear-scenario-result'),
        );
        await tester.scrollUntilVisible(
          clear,
          140,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(clear);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('urgent-cabinet-patient-scenario-result')),
          findsNothing,
        );
      });

      testWidgets('relationship scenario is generic and FAMILY remains safe', (
        tester,
      ) async {
        final subject = UrgentCabinetCareSubject.familyMember('family-42');
        final controller = await _acceptedController(
          subject: subject,
          patientName: 'Yasmine Martin',
        );
        addTearDown(controller.dispose);
        await tester.pumpWidget(_previewApp(controller: controller));
        await _expandScenarioControls(tester);
        await _selectScenario(
          tester,
          UrgentCabinetPatientCheckInPreviewState.relationshipUnavailable,
        );
        await _showSelectedScenario(tester);

        expect(find.text('Accès au proche indisponible'), findsWidgets);
        expect(find.textContaining('family-42'), findsNothing);
        expect(find.textContaining('révoqué'), findsNothing);
        expect(find.textContaining('détecté'), findsNothing);
        expect(controller.selectedSubject, subject);
        expect(controller.requestState, isA<UrgentCabinetRequestAccepted>());
      });

      testWidgets('popping and reopening clears local scenario state', (
        tester,
      ) async {
        final controller = await _acceptedController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(_journeyApp(controller));
        await _openInstructions(tester);
        await _openPreview(tester);
        await _expandScenarioControls(tester);
        await _showSelectedScenario(tester);
        expect(
          find.byKey(const ValueKey('urgent-cabinet-patient-scenario-result')),
          findsOneWidget,
        );

        await tester.tap(
          find.byKey(const ValueKey('urgent-cabinet-patient-qr-preview-back')),
        );
        await tester.pumpAndSettle();
        await _openPreview(tester);

        expect(
          find.byKey(const ValueKey('urgent-cabinet-patient-scenario-result')),
          findsNothing,
        );
        expect(
          find.byKey(
            const ValueKey('urgent-cabinet-patient-scenario-selector'),
          ),
          findsNothing,
        );
      });

      testWidgets('an invalidated context removes the displayed result', (
        tester,
      ) async {
        final controller = await _acceptedController();
        await tester.pumpWidget(_invalidationApp(controller));
        await tester.tap(find.text('Open preview'));
        await tester.pumpAndSettle();
        await _expandScenarioControls(tester);
        await _showSelectedScenario(tester);
        expect(
          find.byKey(const ValueKey('urgent-cabinet-patient-scenario-result')),
          findsOneWidget,
        );

        controller.ensureAccount('foreign-account');
        await tester.pumpAndSettle();

        expect(find.byType(UrgentCabinetPatientQrPreviewScreen), findsNothing);
        expect(
          find.byKey(const ValueKey('urgent-cabinet-patient-scenario-result')),
          findsNothing,
        );
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
      });
    }
  });

  group('static non-scannable presentation', () {
    testWidgets('shows explicit non-scannable and clinical boundaries', (
      tester,
    ) async {
      final controller = await _acceptedController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(_previewApp(controller: controller));

      expect(find.text('APERÇU NON SCANNABLE'), findsOneWidget);
      expect(find.text("Aucun code sécurisé n'a été émis."), findsOneWidget);
      expect(
        find.text(
          'Ce visuel ne confirme pas votre présence et ne donne accès à aucune donnée médicale.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'La présence devra être vérifiée par le médecin. Cette étape ne démarre pas la consultation.',
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          "Aperçu non scannable. Aucun code sécurisé n'a été émis.",
        ),
        findsOneWidget,
      );

      for (final prohibited in <String>[
        'Je suis arrivé au cabinet',
        'Patient arrivé',
        'Présence confirmée',
        'Démarrer la consultation',
        'Consultation démarrée',
        'Ouvrir le dossier médical',
      ]) {
        expect(find.text(prohibited), findsNothing);
      }
      expect(find.byType(TextField), findsNothing);
      expect(find.byIcon(Icons.qr_code), findsNothing);
      expect(find.byIcon(Icons.qr_code_2), findsNothing);
      expect(find.byIcon(Icons.qr_code_scanner), findsNothing);
    });

    testWidgets('renders no internal identity or credential material', (
      tester,
    ) async {
      final subject = UrgentCabinetCareSubject.familyMember('family-42');
      final controller = await _acceptedController(
        subject: subject,
        patientName: 'Yasmine Martin',
      );
      addTearDown(controller.dispose);
      final review = controller.frozenReview!;
      await tester.pumpWidget(_previewApp(controller: controller));

      for (final secret in <String>[
        'patient-user-1',
        'family-42',
        review.doctorId,
        review.cabinetId,
        'token',
        'nonce',
        'signature',
        'HMAC',
        'MRS',
      ]) {
        expect(find.textContaining(secret), findsNothing);
      }
    });

    test(
      'authoritative QR rendering has no transport, persistence, or clinical dependency',
      () {
        final source = <String>[
          'lib/features/emergency/urgent_cabinet/'
              'urgent_cabinet_patient_qr_preview_screen.dart',
          'lib/features/emergency/urgent_cabinet/'
              'urgent_cabinet_check_in_presentation.dart',
        ].map((path) => File(path).readAsStringSync()).join('\n');

        expect(source, contains('QrImageView'));
        expect(source, contains('qr_flutter'));
        expect(source, contains('issueArrivalHandoff'));

        for (final forbidden in <String>[
          'CustomPainter',
          'qr_code_rounded',
          'qr_code_scanner',
          'package:http',
          'package:dio',
          'WebSocket',
          'Notification',
          'Audit',
          'SharedPreferences',
          'Timer(',
        ]) {
          expect(source, isNot(contains(forbidden)));
        }
      },
    );
  });

  group('navigation and invalidation', () {
    testWidgets('Back returns through instructions to the same acceptance', (
      tester,
    ) async {
      final controller = await _acceptedController();
      addTearDown(controller.dispose);
      final accepted = controller.requestState;
      final review = controller.frozenReview;
      await tester.pumpWidget(_journeyApp(controller));

      await _openInstructions(tester);
      await _openPreview(tester);
      expect(find.byType(UrgentCabinetPatientQrPreviewScreen), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('urgent-cabinet-patient-qr-preview-back')),
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
      expect(find.text('Votre demande a été acceptée'), findsOneWidget);
      expect(controller.requestState, same(accepted));
      expect(controller.frozenReview, same(review));
    });

    testWidgets('rapid entry taps open only one preview', (tester) async {
      final controller = await _acceptedController();
      addTearDown(controller.dispose);
      final accepted = controller.requestState as UrgentCabinetRequestAccepted;
      final navigation = Completer<void>();
      var opens = 0;
      await tester.pumpWidget(
        ChangeNotifierProvider<UrgentCabinetFlowController>.value(
          value: controller,
          child: MaterialApp(
            theme: buildOmniTheme(),
            home: UrgentCabinetArrivalInstructionsScreen(
              review: accepted.review,
              localAttemptGeneration: accepted.localAttemptGeneration,
              accountId: controller.accountId!,
              onOpenPatientQrPreview: () {
                opens++;
                return navigation.future;
              },
            ),
          ),
        ),
      );
      final action = find.byKey(
        const ValueKey('urgent-cabinet-open-patient-qr-preview'),
      );
      await tester.scrollUntilVisible(
        action,
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(action);
      await tester.tap(action);
      expect(opens, 1);
      navigation.complete();
      await tester.pump();
    });

    testWidgets('account change and reset remove stale preview details', (
      tester,
    ) async {
      for (final invalidate in <void Function(UrgentCabinetFlowController)>[
        (controller) => controller.ensureAccount('foreign-account'),
        (controller) => controller.endDevelopmentSimulation(),
      ]) {
        final controller = await _acceptedController();
        await tester.pumpWidget(_invalidationApp(controller));
        await tester.tap(find.text('Open preview'));
        await tester.pumpAndSettle();
        expect(
          find.byType(UrgentCabinetPatientQrPreviewScreen),
          findsOneWidget,
        );

        invalidate(controller);
        await tester.pumpAndSettle();
        expect(find.byType(UrgentCabinetPatientQrPreviewScreen), findsNothing);
        expect(find.text('Sarah Martin'), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
      }
    });

    testWidgets('route teardown leaves no preview context mounted', (
      tester,
    ) async {
      final controller = await _acceptedController();
      await tester.pumpWidget(_previewApp(controller: controller));
      expect(find.text('Sarah Martin'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      expect(find.byType(UrgentCabinetPatientQrPreviewScreen), findsNothing);
      expect(find.text('Sarah Martin'), findsNothing);
      controller.dispose();
    });
  });

  group('responsive and accessible preview', () {
    for (final size in <Size>[
      const Size(320, 568),
      const Size(360, 640),
      const Size(390, 844),
      const Size(430, 932),
      const Size(844, 390),
      const Size(900, 1100),
    ]) {
      testWidgets(
        '${size.width.toInt()}x${size.height.toInt()} remains scrollable',
        (tester) async {
          await tester.binding.setSurfaceSize(size);
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final controller = await _acceptedController();
          addTearDown(controller.dispose);
          await tester.pumpWidget(_previewApp(controller: controller));
          await tester.drag(find.byType(Scrollable), const Offset(0, -500));
          await tester.pump();

          expect(
            find.byKey(const ValueKey('urgent-cabinet-non-scannable-preview')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }

    for (final scale in <double>[1.5, 2]) {
      testWidgets('${scale}x text remains overflow-free', (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 568));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final controller = await _acceptedController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          _previewApp(controller: controller, textScale: scale),
        );
        await tester.drag(find.byType(Scrollable), const Offset(0, -700));
        await tester.pump();
        expect(
          find.byKey(
            const ValueKey('urgent-cabinet-patient-qr-security-notice'),
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('Back, semantics and reduced motion remain accessible', (
      tester,
    ) async {
      final controller = await _acceptedController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _previewApp(controller: controller, disableAnimations: true),
      );

      final back = find.byKey(
        const ValueKey('urgent-cabinet-patient-qr-preview-back'),
      );
      expect(tester.getSize(back).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(back).height, greaterThanOrEqualTo(48));
      expect(
        find.byTooltip("Retour aux instructions d'arrivée"),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          'Ce visuel ne confirme pas votre présence et ne donne accès à aucune donnée médicale. '
          'La présence devra être vérifiée par le médecin. Cette étape ne démarre pas la consultation.',
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    if (_patientCheckInScenariosEnabled) {
      for (final configuration in <({Size size, double scale})>[
        (size: const Size(320, 568), scale: 2),
        (size: const Size(844, 390), scale: 1.5),
        (size: const Size(900, 1100), scale: 2),
      ]) {
        testWidgets(
          'scenario result fits ${configuration.size.width.toInt()}x${configuration.size.height.toInt()} at ${configuration.scale}x',
          (tester) async {
            await tester.binding.setSurfaceSize(configuration.size);
            addTearDown(() => tester.binding.setSurfaceSize(null));
            final controller = await _acceptedController();
            addTearDown(controller.dispose);
            await tester.pumpWidget(
              _previewApp(
                controller: controller,
                textScale: configuration.scale,
                disableAnimations: true,
              ),
            );
            await _expandScenarioControls(tester);
            await _showSelectedScenario(tester);
            await tester.drag(find.byType(Scrollable), const Offset(0, -700));
            await tester.pump();

            final presentation = const UrgentCabinetPatientCheckInPresentation(
              UrgentCabinetPatientCheckInPreviewState.ready,
            );
            expect(
              find.bySemanticsLabel(presentation.accessibilityAnnouncement),
              findsOneWidget,
            );
            expect(
              tester
                  .getSize(
                    find.byKey(
                      const ValueKey(
                        'urgent-cabinet-patient-clear-scenario-result',
                      ),
                    ),
                  )
                  .height,
              greaterThanOrEqualTo(48),
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  });
}
