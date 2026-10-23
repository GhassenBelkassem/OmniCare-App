import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/core/theme/omni_theme.dart';
import 'package:omnicare_mobile/features/doctor/urgent_cabinet/doctor_urgent_cabinet_check_in_result.dart';
import 'package:omnicare_mobile/features/doctor/urgent_cabinet/doctor_urgent_cabinet_qr_preview_screen.dart';
import 'package:omnicare_mobile/features/doctor/urgent_cabinet/doctor_urgent_cabinet_request.dart';

final _request = DoctorUrgentCabinetRequest(
  developmentFixtureKey: DoctorUrgentCabinetDevelopmentFixtureKey(
    'private-development-key',
  ),
  targetDoctorId: 'private-doctor-id',
  targetCabinetIdentity: DoctorUrgentCabinetDevelopmentTargetIdentity(
    DoctorUrgentCabinetDevelopmentCabinetKey('private-cabinet-id'),
  ),
  cabinet: DoctorUrgentCabinetSnapshot(
    name: 'Cabinet Mansour',
    address: '1, rue de la Santé',
    city: 'La Marsa',
    governorate: 'Tunis',
  ),
  patient: const DoctorUrgentCabinetPatientProjection.masked(),
  fee: DoctorUrgentCabinetFeeSnapshot(
    amountMilliTnd: 75000,
    currencyCode: 'TND',
    provenance: DoctorUrgentCabinetFeeProvenance.developmentFixture,
  ),
  dataProvenance: DoctorUrgentCabinetDataProvenance.developmentFixture,
  status: DoctorUrgentCabinetRequestStatus.newRequest,
);

Widget _preview({
  bool debugScenariosEnabled = true,
  double textScale = 1,
  bool disableAnimations = false,
}) => MaterialApp(
  theme: buildOmniTheme(),
  home: MediaQuery(
    data: MediaQueryData(
      textScaler: TextScaler.linear(textScale),
      disableAnimations: disableAnimations,
    ),
    child: DoctorUrgentCabinetQrPreviewScreen(
      request: _request,
      debugScenariosEnabled: debugScenariosEnabled,
    ),
  ),
);

Future<void> _showScenario(
  WidgetTester tester,
  DoctorUrgentCabinetCheckInPreviewState state,
) async {
  final toggle = find.byKey(
    const ValueKey('doctor-urgent-cabinet-scenarios-toggle'),
  );
  if (find
      .byKey(const ValueKey('doctor-urgent-cabinet-scenario-selector'))
      .evaluate()
      .isEmpty) {
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pump();
  }

  final selector = find.byKey(
    const ValueKey('doctor-urgent-cabinet-scenario-selector'),
  );
  await tester.ensureVisible(selector);
  await tester.tap(selector);
  await tester.pumpAndSettle();
  final title = DoctorUrgentCabinetCheckInResult(state).title;
  await tester.tap(find.text(title).last);
  await tester.pumpAndSettle();

  final show = find.byKey(
    const ValueKey('doctor-urgent-cabinet-show-selected-scenario'),
  );
  await tester.ensureVisible(show);
  await tester.tap(show);
  await tester.pump();
}

void main() {
  test('typed presentation model maps every state exhaustively', () {
    for (final state in DoctorUrgentCabinetCheckInPreviewState.values) {
      final result = DoctorUrgentCabinetCheckInResult(state);
      expect(result.title, isNotEmpty, reason: state.name);
      expect(result.description, isNotEmpty, reason: state.name);
      expect(result.recovery, isNotNull, reason: state.name);
      expect(result.visualTreatment, isNotNull, reason: state.name);
    }
    expect(
      DoctorUrgentCabinetCheckInResult(
        DoctorUrgentCabinetCheckInPreviewState.unknownOutcome,
      ).recovery,
      DoctorUrgentCabinetCheckInRecovery.authoritativeRefreshRequired,
    );
  });

  testWidgets(
    'renders a static, redacted and explicitly non-authoritative preview',
    (tester) async {
      await tester.pumpWidget(_preview());
      await tester.pumpAndSettle();

      expect(find.text('Scanner le QR du patient'), findsOneWidget);
      expect(
        find.text(
          "Aperçu de démonstration — aucune vérification réelle n'est effectuée.",
        ),
        findsOneWidget,
      );
      expect(find.text('Patient concerné'), findsOneWidget);
      expect(find.text('Identité non communiquée à ce stade'), findsOneWidget);
      expect(find.text('Cabinet Mansour'), findsOneWidget);
      expect(find.text('1, rue de la Santé\nLa Marsa, Tunis'), findsOneWidget);
      expect(find.text('Caméra non connectée'), findsNWidgets(2));
      expect(
        find.text("Aucun QR réel n'est lu dans cette démonstration."),
        findsOneWidget,
      );
      expect(
        find.text(
          "Aucune présence n'est enregistrée, aucune consultation n'est démarrée et aucun accès au dossier médical n'est accordé.",
        ),
        findsOneWidget,
      );
      expect(find.textContaining('private-development-key'), findsNothing);
      expect(find.textContaining('private-doctor-id'), findsNothing);
      expect(find.textContaining('private-cabinet-id'), findsNothing);
      expect(find.textContaining('Patient arrivé'), findsNothing);
      expect(find.textContaining('Présence confirmée'), findsNothing);
      expect(find.textContaining('Voir le dossier'), findsNothing);
    },
  );

  testWidgets(
    'debug scenario controls require explicit action and render every copy',
    (tester) async {
      await tester.pumpWidget(_preview());
      await tester.pumpAndSettle();

      expect(find.text('QR invalide'), findsNothing);
      for (final state in DoctorUrgentCabinetCheckInPreviewState.values) {
        await _showScenario(tester, state);
        final result = DoctorUrgentCabinetCheckInResult(state);
        expect(find.text(result.title), findsWidgets, reason: state.name);
        expect(
          find.text(result.description),
          findsOneWidget,
          reason: state.name,
        );
        if (result.guidance != null) {
          expect(
            find.text(result.guidance!),
            findsOneWidget,
            reason: state.name,
          );
        }
        expect(
          find.text(
            "Aperçu de démonstration — aucune vérification réelle n'est effectuée.",
          ),
          findsOneWidget,
        );
      }
    },
  );

  testWidgets('verifying simulation never advances automatically', (
    tester,
  ) async {
    await tester.pumpWidget(_preview());
    await tester.pumpAndSettle();
    await _showScenario(
      tester,
      DoctorUrgentCabinetCheckInPreviewState.verifyingSimulation,
    );

    await tester.pump(const Duration(minutes: 5));
    expect(find.text('Simulation de vérification en cours'), findsWidgets);
    expect(find.text("Aperçu d'un résultat positif"), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('unknown outcome offers no immediate retry', (tester) async {
    await tester.pumpWidget(_preview());
    await tester.pumpAndSettle();
    await _showScenario(
      tester,
      DoctorUrgentCabinetCheckInPreviewState.unknownOutcome,
    );

    expect(find.text('Résultat non confirmé'), findsWidgets);
    expect(find.text('Réessayer'), findsNothing);
    expect(find.text('Actualiser'), findsNothing);
  });

  testWidgets(
    'scenario controls remain unavailable outside the debug fixture gate',
    (tester) async {
      await tester.pumpWidget(_preview(debugScenariosEnabled: false));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('doctor-urgent-cabinet-debug-scenarios')),
        findsNothing,
      );
      expect(find.text('Scénarios de test'), findsNothing);
    },
  );

  testWidgets('Back closes only the preview route', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildOmniTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => DoctorUrgentCabinetQrPreviewScreen(
                      request: _request,
                      debugScenariosEnabled: true,
                    ),
                  ),
                ),
                child: const Text('Ouvrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Ouvrir'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('doctor-urgent-cabinet-qr-preview-back')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('doctor-urgent-cabinet-qr-preview-screen')),
      findsNothing,
    );
    expect(find.text('Ouvrir'), findsOneWidget);
  });

  testWidgets('supports narrow, landscape, tablet and 2x text layouts', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;

    for (final size in <Size>[
      const Size(320, 720),
      const Size(360, 720),
      const Size(390, 720),
      const Size(430, 720),
      const Size(844, 390),
      const Size(1024, 768),
    ]) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(_preview(textScale: 2));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: '$size');
      expect(
        find.byKey(const ValueKey('doctor-urgent-cabinet-qr-preview-scroll')),
        findsOneWidget,
      );
    }
  });

  testWidgets('announces status and honors reduced motion', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(_preview(disableAnimations: true));
    await tester.pumpAndSettle();

    final switcher = tester.widget<AnimatedSwitcher>(
      find.byType(AnimatedSwitcher),
    );
    expect(switcher.duration, Duration.zero);
    expect(find.byTooltip('Retour'), findsOneWidget);
    final resultPanel = find.byKey(
      const ValueKey('doctor-urgent-cabinet-check-in-result-ready'),
    );
    await tester.ensureVisible(resultPanel);
    await tester.pump();
    final resultSemantics = tester.getSemantics(resultPanel);
    expect(resultSemantics.label, contains('Caméra non connectée'));
    expect(
      resultSemantics.label,
      contains(
        'Placez le futur QR sécurisé dans la zone de scan lorsque la fonctionnalité sera disponible.',
      ),
    );
    expect(resultSemantics.flagsCollection.isLiveRegion, isTrue);
    semantics.dispose();
  });
}
