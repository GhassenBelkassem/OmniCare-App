import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/core/theme/omni_theme.dart';
import 'package:omnicare_mobile/features/doctor/demo/doctor_demo_profile.dart';
import 'package:omnicare_mobile/features/doctor/shell/doctor_app_shell.dart';
import 'package:omnicare_mobile/features/doctor/urgent/doctor_urgent_controller.dart';
import 'package:omnicare_mobile/features/doctor/urgent_cabinet/doctor_urgent_cabinet_accepted_card.dart';
import 'package:omnicare_mobile/features/doctor/urgent_cabinet/doctor_urgent_cabinet_decision_source.dart';
import 'package:omnicare_mobile/features/doctor/urgent_cabinet/doctor_urgent_cabinet_in_app_preview.dart';
import 'package:omnicare_mobile/features/doctor/urgent_cabinet/doctor_urgent_cabinet_request_source.dart';
import 'package:omnicare_mobile/features/doctor/workspace/doctor_workspace_config.dart';

const _cabinet = DoctorCabinetConfig(
  name: 'Cabinet Mansour',
  governorate: 'Tunis',
  city: 'La Marsa',
  address: '1, rue de la Santé',
);

const _otherCabinet = DoctorCabinetConfig(
  name: 'Cabinet Lac 2',
  governorate: 'Tunis',
  city: 'Les Berges du Lac',
  address: '8, avenue du Lac',
);

const _enabledPreview = DoctorUrgentCabinetInAppPreviewConfig(
  enabled: true,
  developmentDoctorId: 'doctor-a',
  cabinetName: 'Cabinet Mansour',
  cabinetAddress: '1, rue de la Santé',
  cabinetCity: 'La Marsa',
  cabinetGovernorate: 'Tunis',
);

DoctorWorkspaceConfig _workspace({
  String doctorId = 'doctor-a',
  DoctorCabinetConfig? cabinet = _cabinet,
  bool urgentCabinet = true,
  bool urgentHome = false,
}) => DoctorWorkspaceConfig(
  doctorId: doctorId,
  onboardingCompleted: true,
  practiceModes: {
    DoctorPracticeMode.cabinet,
    if (urgentHome) DoctorPracticeMode.urgentHome,
  },
  services: {
    DoctorWorkspaceService.cabinetConsultations,
    if (urgentCabinet) DoctorWorkspaceService.urgentCabinetConsultations,
    if (urgentHome) DoctorWorkspaceService.urgentHomeVisits,
  },
  cabinet: cabinet,
  clinics: const [],
  homeVisit: urgentHome
      ? const DoctorHomeVisitConfig(
          governorate: 'Tunis',
          availableForHomeVisits: true,
        )
      : null,
  availability: const DoctorAvailability(
    workingDays: {DoctorWorkingDay.monday},
    startTime: '08:00',
    endTime: '17:00',
  ),
);

DoctorUrgentCabinetInAppPreviewDecision _resolve({
  bool isDebugBuild = true,
  bool isAuthenticatedDoctor = true,
  String authenticatedDoctorId = 'doctor-a',
  DoctorWorkspaceConfig? workspace,
  DoctorUrgentCabinetInAppPreviewConfig config = _enabledPreview,
}) => DoctorUrgentCabinetInAppPreview.resolve(
  isDebugBuild: isDebugBuild,
  isAuthenticatedDoctor: isAuthenticatedDoctor,
  authenticatedDoctorId: authenticatedDoctorId,
  workspaceConfig: workspace ?? _workspace(),
  config: config,
);

Widget _shell(
  DoctorWorkspaceConfig workspace, {
  DoctorUrgentCabinetRequestSource? source,
  DoctorUrgentCabinetDecisionSource? decisionSource,
  DoctorUrgentController? homeController,
}) => MaterialApp(
  theme: buildOmniTheme(),
  home: DoctorAppShell(
    profile: DoctorDemoProfile.current,
    onLogout: () async {},
    workspaceConfig: workspace,
    urgentController: homeController,
    urgentCabinetRequestSource: source,
    urgentCabinetDecisionSource: decisionSource,
  ),
);

Future<void> _openUrgentCabinet(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('doctor-tab-urgent')));
  await tester.pumpAndSettle();
  final cabinetMode = find.byKey(const ValueKey('doctor-urgent-mode-cabinet'));
  if (cabinetMode.evaluate().isNotEmpty) {
    await tester.tap(cabinetMode);
    await tester.pumpAndSettle();
  }
}

void main() {
  group('D-UI-02B fail-closed preview decision', () {
    test('compile-time preview is disabled by default', () {
      const config = DoctorUrgentCabinetInAppPreviewConfig.fromEnvironment();
      final decision = _resolve(config: config);

      expect(config.enabled, isFalse);
      expect(
        decision.reason,
        DoctorUrgentCabinetInAppPreviewReason.previewDisabled,
      );
      expect(decision.requestSource, isNull);
      expect(decision.decisionSource, isNull);
    });

    test(
      'matching authenticated Doctor and cabinet enable one fixture',
      () async {
        final workspace = _workspace();
        final decision = _resolve(workspace: workspace);

        expect(decision.isEnabled, isTrue);
        expect(decision.decisionSource, isNotNull);
        final state = await decision.requestSource!.load(
          DoctorUrgentCabinetRequestContext.fromWorkspace(workspace),
        );
        expect(state, isA<DoctorUrgentCabinetFeedLoaded>());
        expect((state as DoctorUrgentCabinetFeedLoaded).requests, hasLength(1));
        final request = state.requests.single;
        expect(request.targetDoctorId, 'doctor-a');
        expect(request.fee.amountMilliTnd, 75000);
        expect(request.serverRequestReference, isNull);
      },
    );

    test('non-Doctor session and wrong authenticated Doctor fail closed', () {
      expect(
        _resolve(isAuthenticatedDoctor: false).reason,
        DoctorUrgentCabinetInAppPreviewReason.notAuthenticatedDoctor,
      );
      expect(
        _resolve(authenticatedDoctorId: 'doctor-b').reason,
        DoctorUrgentCabinetInAppPreviewReason.developmentDoctorIdMismatch,
      );
    });

    test('local workspace identity cannot replace authenticated identity', () {
      final workspace = _workspace(doctorId: 'doctor-a');
      const configForAuthenticatedDoctor =
          DoctorUrgentCabinetInAppPreviewConfig(
            enabled: true,
            developmentDoctorId: 'doctor-b',
            cabinetName: 'Cabinet Mansour',
            cabinetAddress: '1, rue de la Santé',
            cabinetCity: 'La Marsa',
            cabinetGovernorate: 'Tunis',
          );

      final decision = _resolve(
        authenticatedDoctorId: 'doctor-b',
        workspace: workspace,
        config: configForAuthenticatedDoctor,
      );

      expect(
        decision.reason,
        DoctorUrgentCabinetInAppPreviewReason.workspaceDoctorIdMismatch,
      );
      expect(decision.requestSource, isNull);
      expect(decision.decisionSource, isNull);
    });

    test('wrong or incomplete cabinets fail closed', () {
      expect(
        _resolve(workspace: _workspace(cabinet: _otherCabinet)).reason,
        DoctorUrgentCabinetInAppPreviewReason.cabinetMismatch,
      );
      expect(
        _resolve(
          workspace: _workspace(
            cabinet: const DoctorCabinetConfig(
              name: 'Cabinet incomplet',
              governorate: 'Tunis',
              city: 'Tunis',
              address: '',
            ),
          ),
        ).reason,
        DoctorUrgentCabinetInAppPreviewReason.localCabinetMissingOrIncomplete,
      );
    });

    test('missing capability and development definitions fail closed', () {
      expect(
        _resolve(workspace: _workspace(urgentCabinet: false)).reason,
        DoctorUrgentCabinetInAppPreviewReason.urgentCabinetCapabilityMissing,
      );
      expect(
        _resolve(
          config: const DoctorUrgentCabinetInAppPreviewConfig(
            enabled: true,
            developmentDoctorId: '',
            cabinetName: 'Cabinet Mansour',
            cabinetAddress: '1, rue de la Santé',
            cabinetCity: 'La Marsa',
            cabinetGovernorate: 'Tunis',
          ),
        ).reason,
        DoctorUrgentCabinetInAppPreviewReason.developmentDoctorIdMissing,
      );
      expect(
        _resolve(
          config: const DoctorUrgentCabinetInAppPreviewConfig(
            enabled: true,
            developmentDoctorId: 'doctor-a',
            cabinetName: '',
            cabinetAddress: '',
            cabinetCity: '',
            cabinetGovernorate: '',
          ),
        ).reason,
        DoctorUrgentCabinetInAppPreviewReason
            .developmentCabinetMissingOrIncomplete,
      );
    });

    test('profile and release builds ignore every preview definition', () {
      final decision = _resolve(isDebugBuild: false);

      expect(
        decision.reason,
        DoctorUrgentCabinetInAppPreviewReason.notDebugBuild,
      );
      expect(decision.requestSource, isNull);
      expect(decision.decisionSource, isNull);
    });
  });

  group('D-UI-02B normal Doctor shell integration', () {
    testWidgets('normal navigation displays the approved card and sheet', (
      tester,
    ) async {
      final workspace = _workspace();
      final preview = _resolve(workspace: workspace);
      await tester.pumpWidget(
        _shell(
          workspace,
          source: preview.requestSource,
          decisionSource: preview.decisionSource,
        ),
      );

      await _openUrgentCabinet(tester);

      expect(find.text('Urgences au cabinet'), findsOneWidget);
      expect(find.text('Nouvelles demandes'), findsOneWidget);
      expect(find.text('URGENCE AU CABINET'), findsOneWidget);
      expect(find.text('Patient concerné'), findsOneWidget);
      expect(find.text('75,000 DT'), findsOneWidget);
      expect(find.text('Tarif de démonstration locale'), findsOneWidget);
      expect(find.text('Voir la demande'), findsOneWidget);
      expect(find.text('Accepter'), findsNothing);
      expect(find.text('Refuser'), findsNothing);

      await tester.ensureVisible(find.text('Voir la demande'));
      await tester.tap(find.text('Voir la demande'));
      await tester.pumpAndSettle();
      expect(find.text('Nouvelle demande urgente'), findsOneWidget);
      expect(find.text('Accepter'), findsOneWidget);
      expect(find.text('Refuser'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('doctor-urgent-cabinet-sheet-close-icon')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Nouvelle demande urgente'), findsNothing);
    });

    testWidgets('rebuild and mode switching preserve HOME without duplicates', (
      tester,
    ) async {
      final workspace = _workspace(urgentHome: true);
      final preview = _resolve(workspace: workspace);
      final homeController = DoctorUrgentController()..goOnline();
      addTearDown(homeController.dispose);

      await tester.pumpWidget(
        _shell(
          workspace,
          source: preview.requestSource,
          decisionSource: preview.decisionSource,
          homeController: homeController,
        ),
      );
      await _openUrgentCabinet(tester);
      expect(find.text('Voir la demande'), findsOneWidget);

      await tester.pumpWidget(
        _shell(
          workspace,
          source: preview.requestSource,
          decisionSource: preview.decisionSource,
          homeController: homeController,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Voir la demande'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('doctor-urgent-mode-home')));
      await tester.pumpAndSettle();
      expect(homeController.state, DoctorUrgentState.available);
      expect(find.text('Disponible pour les urgences'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('doctor-urgent-mode-cabinet')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Voir la demande'), findsOneWidget);
    });

    testWidgets(
      'terminal decision persists across mode and bottom-tab remounts',
      (tester) async {
        final workspace = _workspace(urgentHome: true);
        final preview = _resolve(workspace: workspace);
        final homeController = DoctorUrgentController()..goOnline();
        addTearDown(homeController.dispose);

        await tester.pumpWidget(
          _shell(
            workspace,
            source: preview.requestSource,
            decisionSource: preview.decisionSource,
            homeController: homeController,
          ),
        );
        await _openUrgentCabinet(tester);
        await tester.ensureVisible(find.text('Voir la demande'));
        await tester.tap(find.text('Voir la demande'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('doctor-urgent-cabinet-accept')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Patient attendu au cabinet'), findsOneWidget);
        expect(find.text('Voir la demande'), findsNothing);

        await tester.tap(find.byKey(const ValueKey('doctor-urgent-mode-home')));
        await tester.pumpAndSettle();
        expect(find.text('Disponible pour les urgences'), findsOneWidget);
        await tester.tap(
          find.byKey(const ValueKey('doctor-urgent-mode-cabinet')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Patient attendu au cabinet'), findsOneWidget);
        expect(find.text('Voir la demande'), findsNothing);

        await tester.tap(find.byKey(DoctorAppShell.profileTabKey));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('doctor-tab-urgent')));
        await tester.pumpAndSettle();
        expect(find.text('Patient attendu au cabinet'), findsOneWidget);
        expect(find.text('Voir la demande'), findsNothing);
      },
    );

    testWidgets('manual in-app simulation needs no preview dart definitions', (
      tester,
    ) async {
      final workspace = _workspace(urgentHome: true);
      final homeController = DoctorUrgentController()..goOnline();
      addTearDown(homeController.dispose);
      await tester.pumpWidget(
        _shell(workspace, homeController: homeController),
      );
      await _openUrgentCabinet(tester);

      expect(find.text('Voir la demande'), findsNothing);
      final simulate = find.byKey(
        const ValueKey('doctor-urgent-cabinet-simulate'),
      );
      await tester.ensureVisible(simulate);
      await tester.tap(simulate);
      await tester.pumpAndSettle();
      expect(find.text('Voir la demande'), findsOneWidget);
      await tester.ensureVisible(find.text('Voir la demande'));
      await tester.tap(find.text('Voir la demande'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('doctor-urgent-cabinet-accept')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Patient attendu au cabinet'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('doctor-urgent-mode-home')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('doctor-urgent-mode-cabinet')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Patient attendu au cabinet'), findsOneWidget);
      expect(find.text('Voir la demande'), findsNothing);

      await tester.tap(find.byKey(DoctorAppShell.profileTabKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('doctor-tab-urgent')));
      await tester.pumpAndSettle();
      expect(find.text('Patient attendu au cabinet'), findsOneWidget);
    });

    testWidgets(
      'authenticated shell completes refusal then four accepted simulations',
      (tester) async {
        final workspace = _workspace(urgentHome: true);
        final homeController = DoctorUrgentController()..goOnline();
        addTearDown(homeController.dispose);
        await tester.pumpWidget(
          _shell(workspace, homeController: homeController),
        );
        await _openUrgentCabinet(tester);

        final simulate = find.byKey(
          const ValueKey('doctor-urgent-cabinet-simulate'),
        );
        await tester.ensureVisible(simulate);
        await tester.tap(simulate);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Voir la demande'));
        await tester.tap(find.text('Voir la demande'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('doctor-urgent-cabinet-refuse')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('doctor-urgent-cabinet-refuse-confirm')),
        );
        await tester.pumpAndSettle();
        expect(find.text('Demande refusée — simulation'), findsOneWidget);

        for (var index = 0; index < 4; index++) {
          await tester.ensureVisible(simulate);
          await tester.tap(simulate);
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.text('Voir la demande'));
          await tester.tap(find.text('Voir la demande'));
          await tester.pumpAndSettle();
          await tester.tap(
            find.byKey(const ValueKey('doctor-urgent-cabinet-accept')),
          );
          await tester.pumpAndSettle();
        }

        expect(find.byType(DoctorUrgentCabinetAcceptedCard), findsNWidgets(3));
        await tester.ensureVisible(
          find.byKey(const ValueKey('doctor-urgent-cabinet-accepted-expand')),
        );
        await tester.tap(
          find.byKey(const ValueKey('doctor-urgent-cabinet-accepted-expand')),
        );
        await tester.pumpAndSettle();
        final acceptedCards = tester
            .widgetList<DoctorUrgentCabinetAcceptedCard>(
              find.byType(DoctorUrgentCabinetAcceptedCard),
            )
            .toList(growable: false);
        expect(acceptedCards, hasLength(4));
        expect(
          acceptedCards.map((card) => card.request.stableIdentity).toSet(),
          hasLength(4),
        );

        final selected = acceptedCards[2].request;
        final open = find.byKey(
          ValueKey(
            'doctor-urgent-cabinet-accepted-open-${selected.stableIdentity}',
          ),
        );
        await tester.scrollUntilVisible(open, 500);
        await tester.tap(open);
        await tester.pumpAndSettle();
        expect(
          find.byKey(
            ValueKey(
              'doctor-urgent-cabinet-accepted-sheet-${selected.stableIdentity}',
            ),
          ),
          findsOneWidget,
        );
        expect(find.text('Patient concerné'), findsWidgets);
        expect(find.text('75,000 DT'), findsWidgets);
        expect(find.textContaining('Amina'), findsNothing);
      },
    );

    testWidgets('account switch clears the old card and open sheet', (
      tester,
    ) async {
      final doctorA = _workspace();
      final sourceA = _resolve(workspace: doctorA).requestSource;
      await tester.pumpWidget(_shell(doctorA, source: sourceA));
      await _openUrgentCabinet(tester);
      await tester.ensureVisible(find.text('Voir la demande'));
      await tester.tap(find.text('Voir la demande'));
      await tester.pumpAndSettle();
      expect(find.text('Nouvelle demande urgente'), findsOneWidget);

      final doctorB = _workspace(doctorId: 'doctor-b');
      final blocked = _resolve(
        authenticatedDoctorId: 'doctor-b',
        workspace: doctorB,
      );
      await tester.pumpWidget(_shell(doctorB, source: blocked.requestSource));
      await tester.pumpAndSettle();

      expect(blocked.requestSource, isNull);
      expect(find.text('Nouvelle demande urgente'), findsNothing);
      expect(find.text('Voir la demande'), findsNothing);
      expect(find.text('Aucune demande urgente au cabinet'), findsOneWidget);
    });

    testWidgets('cabinet change invalidates the old injected request', (
      tester,
    ) async {
      final original = _workspace();
      final source = _resolve(workspace: original).requestSource;
      await tester.pumpWidget(_shell(original, source: source));
      await _openUrgentCabinet(tester);
      expect(find.text('Voir la demande'), findsOneWidget);

      final changed = _workspace(cabinet: _otherCabinet);
      await tester.pumpWidget(_shell(changed, source: source));
      await tester.pumpAndSettle();

      expect(find.text('Voir la demande'), findsNothing);
      expect(find.text('Aucune demande urgente au cabinet'), findsOneWidget);
      expect(find.text('Cabinet Lac 2'), findsOneWidget);
    });
  });
}
