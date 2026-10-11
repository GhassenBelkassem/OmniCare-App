import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/features/emergency/emergency_request_step0.dart';
import 'package:omnicare_mobile/features/emergency/emergency_request_step1.dart';
import 'package:omnicare_mobile/features/emergency/emergency_request_step2.dart';
import 'package:omnicare_mobile/features/emergency/widgets/body_map_widget.dart';
import 'package:omnicare_mobile/features/urgent_journey/domain/urgent_journey_models.dart';
import 'package:omnicare_mobile/features/urgent_journey/domain/p4_urgent_feature_gate.dart';
import 'package:omnicare_mobile/features/urgent_journey/presentation/p4_urgent_journey_coordinator.dart';
import 'package:omnicare_mobile/features/urgent_journey/presentation/p4_urgent_route_owner.dart';

void main() {
  testWidgets('HOME entry requires explicit synthetic subject selection', (
    tester,
  ) async {
    await _pumpCoordinator(tester);
    expect(find.byType(EmergencyRequestStep0), findsOneWidget);

    await _tapMode(tester, UrgentAttemptMode.home);
    await tester.pumpAndSettle();

    expect(find.byType(EmergencyRequestStep1), findsOneWidget);
    expect(
      find.byKey(const ValueKey('emergency-step1-page-surface')),
      findsOneWidget,
    );
    final continueButton = tester.widget<ElevatedButton>(
      find.byKey(const ValueKey('emergency-subject-continue')),
    );
    expect(continueButton.onPressed, isNull);

    await tester.tap(
      find.byKey(const ValueKey('emergency-subject-syn_subject_self')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('emergency-subject-continue')));
    await tester.pumpAndSettle();

    expect(find.byType(EmergencyRequestStep2), findsOneWidget);
    expect(
      find.byKey(const ValueKey('emergency-step2-page-surface')),
      findsOneWidget,
    );
  });

  testWidgets('CABINET path stops before targeted Doctor acceptance UI', (
    tester,
  ) async {
    await _pumpCoordinator(tester);

    await _tapMode(tester, UrgentAttemptMode.cabinet);
    await tester.pumpAndSettle();
    expect(find.byType(EmergencyRequestStep1), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('emergency-subject-syn_subject_family_1')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('emergency-subject-continue')));
    await tester.pumpAndSettle();

    expect(find.byType(EmergencyRequestStep2), findsOneWidget);
    expect(find.textContaining('créneau'), findsNothing);
  });

  testWidgets(
    'restored triage keeps dual body maps and removes P5 disclosure controls',
    (tester) async {
      await _pumpCoordinator(tester);
      await _tapMode(tester, UrgentAttemptMode.home);
      await tester.tap(
        find.byKey(const ValueKey('emergency-subject-syn_subject_self')),
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('emergency-subject-continue')),
      );
      await tester.pumpAndSettle();

      expect(find.byType(EmergencyRequestStep2), findsOneWidget);
      expect(find.byType(MuscleAnatomyMap), findsNWidgets(2));
      expect(find.text('Passeport médical'), findsNothing);
      expect(find.textContaining('reste privée au Patient'), findsOneWidget);
      final mode = tester.widget<SegmentedButton<String>>(
        find.byType(SegmentedButton<String>),
      );
      expect(
        mode.segments
            .singleWhere((segment) => segment.value == 'voice')
            .enabled,
        isFalse,
      );
    },
  );

  testWidgets('coordinator back navigation remains inside safe P4 stages', (
    tester,
  ) async {
    await _pumpCoordinator(tester);
    await _tapMode(tester, UrgentAttemptMode.home);
    await tester.pumpAndSettle();
    expect(find.byType(EmergencyRequestStep1), findsOneWidget);

    await tester.tap(find.byTooltip('Fermer'));
    await tester.pumpAndSettle();
    expect(find.byType(EmergencyRequestStep0), findsOneWidget);

    await _tapMode(tester, UrgentAttemptMode.cabinet);
    expect(find.byType(EmergencyRequestStep1), findsOneWidget);
  });

  testWidgets('global route owner blocks every prohibited continuation', (
    tester,
  ) async {
    for (final route in P4UrgentRoutes.prohibitedContinuations) {
      await tester.pumpWidget(_RouteHarness(initialRoute: route));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('p4-prohibited-continuation')),
        findsOneWidget,
        reason: route,
      );
    }
  });

  testWidgets('direct HOME and CABINET links resolve through one owner', (
    tester,
  ) async {
    await tester.pumpWidget(
      const _RouteHarness(initialRoute: P4UrgentRoutes.subject),
    );
    await tester.pumpAndSettle();
    expect(find.byType(EmergencyRequestStep1), findsOneWidget);

    await tester.pumpWidget(
      const _RouteHarness(initialRoute: P4UrgentRoutes.cabinetEntry),
    );
    await tester.pumpAndSettle();
    expect(find.byType(EmergencyRequestStep1), findsOneWidget);
  });

  for (final size in const [Size(320, 568), Size(390, 844), Size(430, 932)]) {
    testWidgets(
      'entry renders without overflow at ${size.width}x${size.height}',
      (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await _pumpCoordinator(tester);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

Future<void> _pumpCoordinator(WidgetTester tester) => tester.pumpWidget(
  const MaterialApp(
    home: Scaffold(
      body: P4UrgentJourneyCoordinator(
        featureGate: P4UrgentFeatureGate.enabledForTests,
      ),
    ),
  ),
);

class _RouteHarness extends StatelessWidget {
  const _RouteHarness({required this.initialRoute});

  final String initialRoute;

  @override
  Widget build(BuildContext context) => MaterialApp(
    key: ValueKey(initialRoute),
    initialRoute: initialRoute,
    onGenerateRoute: (settings) {
      final page = P4UrgentRouteOwner.buildPage(
        settings,
        featureGate: P4UrgentFeatureGate.enabledForTests,
      );
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (_) => Scaffold(body: page ?? const SizedBox.shrink()),
      );
    },
  );
}

Future<void> _tapMode(WidgetTester tester, UrgentAttemptMode mode) async {
  final key = ValueKey(
    mode == UrgentAttemptMode.home
        ? 'p4-home-mode-card'
        : 'p4-cabinet-mode-card',
  );
  if (mode == UrgentAttemptMode.cabinet) {
    await tester.drag(find.byType(ListView), const Offset(0, -620));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.byKey(key));
  await tester.pumpAndSettle();
}
