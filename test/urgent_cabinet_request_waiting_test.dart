import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:omnicare_mobile/core/theme/omni_theme.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_care_subject.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_doctor_fixture.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_flow_controller.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_request_review.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_request_source.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_request_state.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_request_waiting_screen.dart';

UrgentCabinetRequestReview _review() {
  final doctor =
      UrgentCabinetDoctorFixtureSource.developmentDoctorDetails.first;
  final cabinet = doctor.cabinetById('p4-demo-cabinet-lac-1')!;
  return validateUrgentCabinetRequestReview(
    careSubject: const UrgentCabinetCareSubject.self(),
    patientDisplayName: 'Sarah Martin',
    selectedDoctorId: doctor.doctorId,
    selectedCabinetId: cabinet.cabinetId,
    doctor: doctor,
    cabinet: cabinet,
    feeQuote: UrgentCabinetDoctorFixtureSource.developmentFeeQuotes.first,
    developmentFixturesEnabled: true,
    now: DateTime.utc(2026, 10, 12),
  ).review!;
}

Future<UrgentCabinetFlowController> _pendingController() async {
  final controller = UrgentCabinetFlowController(accountId: 'patient-user-1')
    ..selectSelf()
    ..selectDoctor(
      doctorId: 'p4-demo-doctor-amine-ben-salah',
      cabinetId: 'p4-demo-cabinet-lac-1',
    );
  await controller.submitReview(
    review: _review(),
    source: const UrgentCabinetDevelopmentRequestSource(),
  );
  return controller;
}

Widget _app({
  required UrgentCabinetFlowController controller,
  required VoidCallback onEnd,
  VoidCallback? onSimulateAcceptance,
  double textScale = 1,
  bool disableAnimations = false,
}) {
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
      home: UrgentCabinetRequestWaitingScreen(
        onEndSimulation: onEnd,
        onSimulateAcceptance: onSimulateAcceptance,
      ),
    ),
  );
}

void main() {
  testWidgets('development acceptance action is absent by default', (
    tester,
  ) async {
    final controller = await _pendingController();
    await tester.pumpWidget(_app(controller: controller, onEnd: () {}));

    expect(
      find.byKey(
        const ValueKey('urgent-cabinet-development-decision-controls'),
      ),
      findsNothing,
    );
    expect(find.text("Simuler l'acceptation"), findsNothing);
  });

  testWidgets('eligible pending simulation exposes the isolated action', (
    tester,
  ) async {
    final controller = await _pendingController();
    var actions = 0;
    await tester.pumpWidget(
      _app(
        controller: controller,
        onEnd: () {},
        onSimulateAcceptance: () => actions++,
      ),
    );

    expect(find.text('Contrôles de développement'), findsOneWidget);
    expect(
      find.text(
        'Simulez une réponse du médecin pour tester la suite du parcours.',
      ),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('urgent-cabinet-simulate-acceptance')),
    );
    expect(actions, 1);
    expect(
      find.byKey(const ValueKey('urgent-cabinet-end-simulation')),
      findsOneWidget,
    );
  });

  testWidgets('shows an accurate frozen pending summary and safety copy', (
    tester,
  ) async {
    final controller = await _pendingController();
    await tester.pumpWidget(_app(controller: controller, onEnd: () {}));
    await tester.pump();

    expect(find.text('Demande urgente'), findsOneWidget);
    expect(find.text('En attente de la réponse du médecin'), findsOneWidget);
    expect(
      find.text('Votre demande attend la confirmation du médecin sélectionné.'),
      findsOneWidget,
    );
    expect(
      find.text("Simulation — aucune demande réelle n'a été envoyée."),
      findsOneWidget,
    );
    expect(find.text('Sarah Martin'), findsOneWidget);
    expect(find.text('Dr. Amine Ben Salah'), findsOneWidget);
    expect(find.text('Médecine générale'), findsOneWidget);
    expect(find.text('Cabinet Les Berges du Lac'), findsOneWidget);
    expect(find.text('75,000 DT'), findsOneWidget);
    expect(find.text('Ne vous déplacez pas encore'), findsOneWidget);
    expect(
      find.textContaining('Attendez que le médecin accepte'),
      findsOneWidget,
    );
    expect(find.textContaining('calendrier'), findsNothing);
    expect(find.textContaining('créneau'), findsNothing);
    expect(find.textContaining('ETA'), findsNothing);
    expect(find.textContaining('paiement'), findsNothing);

    await tester.pump(const Duration(minutes: 30));
    expect(
      controller.requestState,
      isA<UrgentCabinetRequestPendingDoctorResponse>(),
    );
  });

  testWidgets('exit dismissal preserves pending and confirmation clears it', (
    tester,
  ) async {
    final controller = await _pendingController();
    var exits = 0;
    await tester.pumpWidget(_app(controller: controller, onEnd: () => exits++));

    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.byKey(const ValueKey('urgent-cabinet-end-simulation-dialog')),
      findsOneWidget,
    );
    expect(
      find.textContaining("Aucune demande médicale réelle"),
      findsOneWidget,
    );

    await tester.tap(find.text('Rester'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      controller.requestState,
      isA<UrgentCabinetRequestPendingDoctorResponse>(),
    );
    expect(exits, 0);

    await tester.tap(
      find.byKey(const ValueKey('urgent-cabinet-end-simulation')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(
      find.byKey(const ValueKey('urgent-cabinet-confirm-end-simulation')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(controller.requestState, isA<UrgentCabinetRequestDraft>());
    expect(controller.frozenReview, isNull);
    expect(exits, 1);
  });

  testWidgets('unknown outcome offers no retry action', (tester) async {
    final controller = UrgentCabinetFlowController(accountId: 'patient-user-1')
      ..selectSelf()
      ..selectDoctor(
        doctorId: 'p4-demo-doctor-amine-ben-salah',
        cabinetId: 'p4-demo-cabinet-lac-1',
      );
    await controller.submitReview(
      review: _review(),
      source: const UrgentCabinetDevelopmentRequestSource(
        scenario: UrgentCabinetDevelopmentSubmissionScenario.unknownOutcome,
      ),
    );
    await tester.pumpWidget(_app(controller: controller, onEnd: () {}));

    expect(find.text('Vérification nécessaire'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('urgent-cabinet-unknown-outcome-notice')),
      findsOneWidget,
    );
    expect(find.textContaining('Ne renvoyez pas la demande'), findsOneWidget);
    expect(find.textContaining('Réessayer'), findsNothing);
  });

  testWidgets('small screen, large text and reduced motion remain usable', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 568));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = await _pendingController();
    await tester.pumpWidget(
      _app(
        controller: controller,
        onEnd: () {},
        textScale: 1.6,
        disableAnimations: true,
      ),
    );
    await tester.pump();

    expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
    expect(
      find.byKey(const ValueKey('urgent-cabinet-end-simulation')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
