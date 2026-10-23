import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/core/theme/omni_theme.dart';
import 'package:omnicare_mobile/features/doctor/urgent_cabinet/doctor_urgent_cabinet_controller.dart';
import 'package:omnicare_mobile/features/doctor/urgent_cabinet/doctor_urgent_cabinet_decision.dart';
import 'package:omnicare_mobile/features/doctor/urgent_cabinet/doctor_urgent_cabinet_decision_source.dart';
import 'package:omnicare_mobile/features/doctor/urgent_cabinet/doctor_urgent_cabinet_request.dart';
import 'package:omnicare_mobile/features/doctor/urgent_cabinet/doctor_urgent_cabinet_request_source.dart';
import 'package:omnicare_mobile/features/doctor/urgent_cabinet/doctor_urgent_cabinet_screen.dart';
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

DoctorWorkspaceConfig _workspace({
  String doctorId = 'doctor-a',
  DoctorCabinetConfig? cabinet = _cabinet,
  bool urgentCabinetEnabled = true,
}) => DoctorWorkspaceConfig(
  doctorId: doctorId,
  onboardingCompleted: true,
  practiceModes: const {DoctorPracticeMode.cabinet},
  services: {
    DoctorWorkspaceService.cabinetConsultations,
    if (urgentCabinetEnabled) DoctorWorkspaceService.urgentCabinetConsultations,
  },
  cabinet: cabinet,
  clinics: const [],
  availability: const DoctorAvailability(
    workingDays: {DoctorWorkingDay.monday},
    startTime: '08:00',
    endTime: '17:00',
  ),
);

DoctorUrgentCabinetSnapshot _snapshot(DoctorCabinetConfig cabinet) =>
    DoctorUrgentCabinetSnapshot(
      name: cabinet.name,
      address: cabinet.address,
      city: cabinet.city,
      governorate: cabinet.governorate,
    );

DoctorUrgentCabinetRequest _request({
  String fixtureKey = 'request-a',
  String doctorId = 'doctor-a',
  DoctorCabinetConfig cabinet = _cabinet,
  int amountMilliTnd = 75000,
  String? serverRequestReference,
}) => DoctorUrgentCabinetRequest(
  developmentFixtureKey: DoctorUrgentCabinetDevelopmentFixtureKey(fixtureKey),
  targetDoctorId: doctorId,
  targetCabinetIdentity: DoctorUrgentCabinetDevelopmentTargetIdentity(
    DoctorUrgentCabinetDevelopmentCabinetKey('cabinet-fixture-a'),
  ),
  cabinet: _snapshot(cabinet),
  patient: const DoctorUrgentCabinetPatientProjection.masked(),
  fee: DoctorUrgentCabinetFeeSnapshot(
    amountMilliTnd: amountMilliTnd,
    currencyCode: 'TND',
    provenance: DoctorUrgentCabinetFeeProvenance.developmentFixture,
  ),
  dataProvenance: DoctorUrgentCabinetDataProvenance.developmentFixture,
  status: DoctorUrgentCabinetRequestStatus.newRequest,
  serverRequestReference: serverRequestReference,
);

Widget _subject({
  required DoctorWorkspaceConfig workspace,
  required DoctorUrgentCabinetRequestSource source,
  DoctorUrgentCabinetDecisionSource? decisionSource,
  DoctorUrgentCabinetController? controller,
  String? authenticatedDoctorId,
  bool developmentSimulationEnabled = true,
  double textScale = 1,
}) {
  final resolvedController =
      controller ??
      DoctorUrgentCabinetController(
        developmentSimulationEnabled: developmentSimulationEnabled,
      );
  resolvedController.configure(
    authenticatedDoctorId: authenticatedDoctorId ?? workspace.doctorId,
    workspaceConfig: workspace,
    requestSource: source,
    decisionSource: decisionSource,
  );
  return MaterialApp(
    theme: buildOmniTheme(),
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Scaffold(
        body: DoctorUrgentCabinetScreen(
          workspaceConfig: workspace,
          controller: resolvedController,
        ),
      ),
    ),
  );
}

class _FixedSource implements DoctorUrgentCabinetRequestSource {
  _FixedSource(this.state);

  final DoctorUrgentCabinetFeedState state;
  int loadCount = 0;

  @override
  Future<DoctorUrgentCabinetFeedState> load(
    DoctorUrgentCabinetRequestContext context, {
    CancelToken? cancelToken,
  }) async {
    loadCount += 1;
    return state;
  }
}

class _ControlledSource implements DoctorUrgentCabinetRequestSource {
  final completers = <Completer<DoctorUrgentCabinetFeedState>>[];

  @override
  Future<DoctorUrgentCabinetFeedState> load(
    DoctorUrgentCabinetRequestContext context, {
    CancelToken? cancelToken,
  }) {
    final completer = Completer<DoctorUrgentCabinetFeedState>();
    completers.add(completer);
    return completer.future;
  }
}

class _SequenceSource implements DoctorUrgentCabinetRequestSource {
  _SequenceSource(this.states);

  final List<DoctorUrgentCabinetFeedState> states;
  int loadCount = 0;

  @override
  Future<DoctorUrgentCabinetFeedState> load(
    DoctorUrgentCabinetRequestContext context, {
    CancelToken? cancelToken,
  }) async {
    final index = loadCount.clamp(0, states.length - 1);
    loadCount += 1;
    return states[index];
  }
}

void main() {
  group('Doctor urgent CABINET request model', () {
    test('uses integer milli-TND and formats the approved fixture amount', () {
      final request = _request();

      expect(request.fee.amountMilliTnd, 75000);
      expect(request.fee.currencyCode, 'TND');
      expect(request.fee.formattedAmount, '75,000 DT');
      expect(request.patient.label, 'Patient concerné');
      expect(request.patient.disclosure, 'Identité non communiquée à ce stade');
    });

    test('rejects invalid fee, target identity and server reference', () {
      expect(
        () => DoctorUrgentCabinetFeeSnapshot(
          amountMilliTnd: -1,
          currencyCode: 'TND',
          provenance: DoctorUrgentCabinetFeeProvenance.developmentFixture,
        ),
        throwsArgumentError,
      );
      expect(
        () => DoctorUrgentCabinetFeeSnapshot(
          amountMilliTnd: 75000,
          currencyCode: 'EUR',
          provenance: DoctorUrgentCabinetFeeProvenance.developmentFixture,
        ),
        throwsArgumentError,
      );
      expect(() => _request(doctorId: ' '), throwsArgumentError);
      expect(
        () => _request(serverRequestReference: 'fake-server-request'),
        throwsArgumentError,
      );
    });

    test('requires a complete normalized cabinet snapshot', () {
      expect(
        () => DoctorUrgentCabinetSnapshot(
          name: 'Cabinet',
          address: '',
          city: 'Tunis',
          governorate: 'Tunis',
        ),
        throwsArgumentError,
      );
      final left = _snapshot(_cabinet);
      final right = DoctorUrgentCabinetSnapshot(
        name: ' cabinet   mansour ',
        address: ' 1, rue de la santé ',
        city: 'la marsa',
        governorate: 'TUNIS',
      );
      expect(left.matches(right), isTrue);
    });
  });

  group('Doctor urgent CABINET development source', () {
    test('matches the authenticated Doctor and exact local cabinet', () async {
      final request = _request();
      final source = DoctorUrgentCabinetDevelopmentRequestSource(
        requests: [request],
      );

      final matching = await source.load(
        DoctorUrgentCabinetRequestContext.fromWorkspace(_workspace()),
      );
      final wrongDoctor = await source.load(
        DoctorUrgentCabinetRequestContext.fromWorkspace(
          _workspace(doctorId: 'doctor-b'),
        ),
      );
      final wrongCabinet = await source.load(
        DoctorUrgentCabinetRequestContext.fromWorkspace(
          _workspace(cabinet: _otherCabinet),
        ),
      );

      expect(matching, isA<DoctorUrgentCabinetFeedLoaded>());
      expect(wrongDoctor, isA<DoctorUrgentCabinetFeedEmpty>());
      expect(wrongCabinet, isA<DoctorUrgentCabinetFeedEmpty>());
    });

    test('missing cabinet or capability disables the fixture feed', () async {
      final source = DoctorUrgentCabinetDevelopmentRequestSource(
        requests: [_request()],
      );

      final missing = await source.load(
        DoctorUrgentCabinetRequestContext.fromWorkspace(
          _workspace(cabinet: null),
        ),
      );
      final disabled = await source.load(
        DoctorUrgentCabinetRequestContext.fromWorkspace(
          _workspace(urgentCabinetEnabled: false),
        ),
      );
      final incomplete = await source.load(
        DoctorUrgentCabinetRequestContext.fromWorkspace(
          _workspace(
            cabinet: const DoctorCabinetConfig(
              name: 'Cabinet incomplet',
              governorate: 'Tunis',
              city: 'Tunis',
              address: '',
            ),
          ),
        ),
      );

      expect(missing, isA<DoctorUrgentCabinetFeedEmpty>());
      expect(disabled, isA<DoctorUrgentCabinetFeedEmpty>());
      expect(incomplete, isA<DoctorUrgentCabinetFeedEmpty>());
    });

    test('deduplicates stable fixture identities', () async {
      final source = DoctorUrgentCabinetDevelopmentRequestSource(
        requests: [_request(), _request()],
      );

      final state = await source.load(
        DoctorUrgentCabinetRequestContext.fromWorkspace(_workspace()),
      );

      expect(state, isA<DoctorUrgentCabinetFeedLoaded>());
      expect((state as DoctorUrgentCabinetFeedLoaded).requests, hasLength(1));
    });

    test('profile/release build selection is unavailable', () async {
      final source = DoctorUrgentCabinetRequestSources.forBuild(
        enableDevelopmentFixtures: false,
        requests: [_request()],
      );

      final state = await source.load(
        DoctorUrgentCabinetRequestContext.fromWorkspace(_workspace()),
      );

      expect(state, isA<DoctorUrgentCabinetFeedUnavailable>());
    });
  });

  group('Doctor urgent CABINET request UI', () {
    testWidgets('manual simulator is debug-only and context-gated', (
      tester,
    ) async {
      const empty = DoctorUrgentCabinetFeedEmpty();
      await tester.pumpWidget(
        _subject(workspace: _workspace(), source: _FixedSource(empty)),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('doctor-urgent-cabinet-simulate')),
        findsOneWidget,
      );
      expect(find.text('Outil de développement'), findsOneWidget);
      expect(
        find.text('Demande simulée — aucun patient réel.'),
        findsOneWidget,
      );

      await tester.pumpWidget(
        _subject(
          workspace: _workspace(),
          source: _FixedSource(empty),
          developmentSimulationEnabled: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('doctor-urgent-cabinet-simulate')),
        findsNothing,
      );

      for (final subject in [
        _subject(
          workspace: _workspace(urgentCabinetEnabled: false),
          source: _FixedSource(empty),
        ),
        _subject(
          workspace: _workspace(cabinet: null),
          source: _FixedSource(empty),
        ),
        _subject(
          workspace: _workspace(),
          authenticatedDoctorId: 'doctor-b',
          source: _FixedSource(empty),
        ),
      ]) {
        await tester.pumpWidget(subject);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('doctor-urgent-cabinet-simulate')),
          findsNothing,
        );
      }
    });

    testWidgets('rapid simulator taps create one masked local request', (
      tester,
    ) async {
      final controller = DoctorUrgentCabinetController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _subject(
          workspace: _workspace(),
          source: _FixedSource(const DoctorUrgentCabinetFeedEmpty()),
          controller: controller,
        ),
      );
      await tester.pumpAndSettle();

      final simulate = find.byKey(
        const ValueKey('doctor-urgent-cabinet-simulate'),
      );
      await tester.tap(simulate);
      await tester.tap(simulate);
      await tester.pumpAndSettle();

      expect(controller.visibleNewRequests, hasLength(1));
      expect(find.text('Voir la demande'), findsOneWidget);
      expect(find.text('Patient concerné'), findsOneWidget);
      expect(find.text('Identité non communiquée à ce stade'), findsOneWidget);
      expect(find.text('75,000 DT'), findsOneWidget);
      final button = tester.widget<OutlinedButton>(simulate);
      expect(button.onPressed, isNull);
    });

    testWidgets('manual attempts reuse accept and refuse lifecycle', (
      tester,
    ) async {
      final controller = DoctorUrgentCabinetController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _subject(
          workspace: _workspace(),
          source: _FixedSource(const DoctorUrgentCabinetFeedEmpty()),
          controller: controller,
        ),
      );
      await tester.pumpAndSettle();
      final simulate = find.byKey(
        const ValueKey('doctor-urgent-cabinet-simulate'),
      );

      await tester.tap(simulate);
      await tester.pumpAndSettle();
      final firstIdentity = controller.visibleNewRequests.single.stableIdentity;
      await tester.ensureVisible(find.text('Voir la demande'));
      await tester.tap(find.text('Voir la demande'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('doctor-urgent-cabinet-accept')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Patient attendu au cabinet'), findsOneWidget);

      await tester.ensureVisible(simulate);
      await tester.tap(simulate);
      await tester.pumpAndSettle();
      final secondIdentity =
          controller.visibleNewRequests.single.stableIdentity;
      expect(secondIdentity, isNot(firstIdentity));
      expect(
        controller.stateFor(firstIdentity),
        isA<DoctorUrgentCabinetAccepted>(),
      );
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

      expect(find.text('Patient attendu au cabinet'), findsOneWidget);
      expect(find.text('Demande refusée — simulation'), findsOneWidget);
      expect(controller.terminalDecisions, hasLength(2));
    });

    testWidgets('shows loading then the approved empty state', (tester) async {
      final source = _ControlledSource();
      await tester.pumpWidget(
        _subject(workspace: _workspace(), source: source),
      );

      expect(
        find.byKey(const ValueKey('doctor-urgent-cabinet-loading')),
        findsOneWidget,
      );
      source.completers.single.complete(const DoctorUrgentCabinetFeedEmpty());
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('doctor-urgent-cabinet-empty')),
        findsOneWidget,
      );
    });

    testWidgets(
      'refresh hides stale cards, dismisses their sheet and recovers safely',
      (tester) async {
        final request = _request();
        final source = _ControlledSource();
        final controller = DoctorUrgentCabinetController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          _subject(
            workspace: _workspace(),
            source: source,
            controller: controller,
            decisionSource: DoctorUrgentCabinetDevelopmentDecisionSource(
              request: request,
            ),
          ),
        );

        source.completers.single.complete(
          DoctorUrgentCabinetFeedLoaded([request]),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Voir la demande'));
        await tester.tap(find.text('Voir la demande'));
        await tester.pumpAndSettle();
        expect(find.text('Nouvelle demande urgente'), findsOneWidget);

        final failedRefresh = controller.refresh();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        await tester.pump();
        expect(find.text('Nouvelle demande urgente'), findsNothing);
        expect(
          find.byKey(const ValueKey('doctor-urgent-cabinet-loading')),
          findsOneWidget,
        );
        expect(find.text('Voir la demande'), findsNothing);

        source.completers.last.complete(
          const DoctorUrgentCabinetFeedError(
            message: 'Échec contrôlé.',
            canRetry: true,
          ),
        );
        await failedRefresh;
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('doctor-urgent-cabinet-error')),
          findsOneWidget,
        );
        expect(find.text('Voir la demande'), findsNothing);
        expect(
          await controller.accept(request.stableIdentity),
          DoctorUrgentCabinetDecisionTransition.rejected,
        );

        final recovery = controller.refresh();
        source.completers.last.complete(
          DoctorUrgentCabinetFeedLoaded([request]),
        );
        await recovery;
        await tester.pumpAndSettle();
        expect(find.text('Voir la demande'), findsOneWidget);
        expect(
          controller.containsCurrentRequest(request.stableIdentity),
          isTrue,
        );

        expect(
          await controller.accept(request.stableIdentity),
          DoctorUrgentCabinetDecisionTransition.accepted,
        );
        await tester.pump();
        expect(
          find.byKey(const ValueKey('doctor-urgent-cabinet-accepted-section')),
          findsOneWidget,
        );

        final terminalRefresh = controller.refresh();
        source.completers.last.complete(
          const DoctorUrgentCabinetFeedUnavailable(message: 'Indisponible.'),
        );
        await terminalRefresh;
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('doctor-urgent-cabinet-accepted-section')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('doctor-urgent-cabinet-unavailable')),
          findsOneWidget,
        );
        expect(find.text('Voir la demande'), findsNothing);
      },
    );

    testWidgets('ordinary background refresh keeps the current request sheet', (
      tester,
    ) async {
      final request = _request();
      final source = _ControlledSource();
      final controller = DoctorUrgentCabinetController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        _subject(
          workspace: _workspace(),
          source: source,
          controller: controller,
          decisionSource: DoctorUrgentCabinetDevelopmentDecisionSource(
            request: request,
          ),
        ),
      );

      source.completers.single.complete(
        DoctorUrgentCabinetFeedLoaded([request]),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Voir la demande'));
      await tester.tap(find.text('Voir la demande'));
      await tester.pumpAndSettle();
      expect(find.text('Nouvelle demande urgente'), findsOneWidget);

      final refresh = controller.refresh(showLoading: false);
      await tester.pump();
      expect(find.text('Nouvelle demande urgente'), findsOneWidget);

      source.completers.last.complete(DoctorUrgentCabinetFeedLoaded([request]));
      expect(await refresh, isTrue);
      await tester.pumpAndSettle();
      expect(find.text('Nouvelle demande urgente'), findsOneWidget);
    });

    testWidgets('shows unavailable and controlled retryable error states', (
      tester,
    ) async {
      final unavailable = _FixedSource(
        const DoctorUrgentCabinetFeedUnavailable(
          message: 'Source de démonstration désactivée.',
        ),
      );
      await tester.pumpWidget(
        _subject(workspace: _workspace(), source: unavailable),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('doctor-urgent-cabinet-unavailable')),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();

      final sequence = _SequenceSource([
        const DoctorUrgentCabinetFeedError(
          message: 'Échec contrôlé.',
          canRetry: true,
        ),
        const DoctorUrgentCabinetFeedError(
          message: 'Échec contrôlé.',
          canRetry: true,
        ),
        DoctorUrgentCabinetFeedLoaded([_request()]),
      ]);
      await tester.pumpWidget(
        _subject(workspace: _workspace(), source: sequence),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('doctor-urgent-cabinet-error')),
        findsOneWidget,
      );
      final retry = find.byKey(const ValueKey('doctor-urgent-cabinet-retry'));
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(find.text('Nouvelles demandes'), findsOneWidget);
      expect(sequence.loadCount, 3);
    });

    testWidgets('request section follows the unchanged availability card', (
      tester,
    ) async {
      final source = _FixedSource(DoctorUrgentCabinetFeedLoaded([_request()]));
      await tester.pumpWidget(
        _subject(workspace: _workspace(), source: source),
      );
      await tester.pumpAndSettle();

      final availability = find.byKey(
        const ValueKey('doctor-urgent-cabinet-availability'),
      );
      final section = find.byKey(
        const ValueKey('doctor-urgent-cabinet-request-section'),
      );
      expect(find.text('Cabinet Mansour'), findsNWidgets(2));
      expect(
        tester.getTopLeft(section).dy,
        greaterThan(tester.getBottomLeft(availability).dy),
      );
      expect(
        find.text('Flux synthétique — aucune notification temps réel.'),
        findsOneWidget,
      );
    });

    testWidgets('card uses masked data and excludes unsupported HOME fields', (
      tester,
    ) async {
      await tester.pumpWidget(
        _subject(
          workspace: _workspace(),
          source: _FixedSource(DoctorUrgentCabinetFeedLoaded([_request()])),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('URGENCE AU CABINET'), findsOneWidget);
      expect(find.text('Nouvelle demande'), findsOneWidget);
      expect(find.text('Patient concerné'), findsOneWidget);
      expect(find.text('Identité non communiquée à ce stade'), findsOneWidget);
      expect(find.text('75,000 DT'), findsOneWidget);
      expect(find.text('Tarif de démonstration locale'), findsOneWidget);
      expect(find.text('Voir la demande'), findsOneWidget);
      final urgencyLabel = tester.widget<Text>(find.text('URGENCE AU CABINET'));
      final statusLabel = tester.widget<Text>(find.text('Nouvelle demande'));
      expect(urgencyLabel.style?.color, OmniColors.urgentCoral);
      expect(statusLabel.style?.color, OmniColors.urgentCoral);
      expect(find.text('Patient · 45 ans'), findsNothing);
      expect(find.text('Patient · 61 ans'), findsNothing);
      expect(find.textContaining('km'), findsNothing);
      expect(find.textContaining('min'), findsNothing);
      expect(find.textContaining('sympt'), findsNothing);
      expect(find.textContaining('GPS'), findsNothing);
      expect(find.textContaining('ETA'), findsNothing);
      expect(find.textContaining('OMN-'), findsNothing);
      expect(find.text('Accepter'), findsNothing);
      expect(find.text('Refuser'), findsNothing);
    });

    testWidgets(
      'screen rejects mismatched loaded data from an injected source',
      (tester) async {
        await tester.pumpWidget(
          _subject(
            workspace: _workspace(doctorId: 'doctor-b'),
            source: _FixedSource(
              DoctorUrgentCabinetFeedLoaded([_request(doctorId: 'doctor-a')]),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Nouvelles demandes'), findsNothing);
        expect(
          find.byKey(const ValueKey('doctor-urgent-cabinet-empty')),
          findsOneWidget,
        );
      },
    );

    testWidgets('caps the dashboard preview at three stable requests', (
      tester,
    ) async {
      final requests = List.generate(
        4,
        (index) => _request(fixtureKey: 'request-$index'),
      );
      await tester.pumpWidget(
        _subject(
          workspace: _workspace(),
          source: _FixedSource(DoctorUrgentCabinetFeedLoaded(requests)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Voir la demande'), findsNWidgets(3));
      expect(
        find.byKey(const ValueKey('doctor-urgent-cabinet-request-request-3')),
        findsNothing,
      );

      await tester.pumpWidget(
        _subject(
          workspace: _workspace(),
          source: _FixedSource(DoctorUrgentCabinetFeedLoaded(requests)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Voir la demande'), findsNWidgets(3));
    });

    testWidgets('opens the approved details sheet and close icon works', (
      tester,
    ) async {
      await tester.pumpWidget(
        _subject(
          workspace: _workspace(),
          source: _FixedSource(DoctorUrgentCabinetFeedLoaded([_request()])),
        ),
      );
      await tester.pumpAndSettle();
      final open = find.text('Voir la demande');
      await tester.ensureVisible(open);
      await tester.tap(open);
      await tester.pumpAndSettle();

      expect(find.text('Nouvelle demande urgente'), findsOneWidget);
      expect(
        find.text("Aucun motif médical n'a été recueilli dans ce parcours."),
        findsOneWidget,
      );
      expect(
        find.text("Simulation locale — aucune demande réelle n'a été reçue."),
        findsOneWidget,
      );
      expect(find.text('Accepter'), findsOneWidget);
      expect(find.text('Refuser'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('doctor-urgent-cabinet-sheet-close-icon')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Nouvelle demande urgente'), findsNothing);

      expect(
        find.byKey(const ValueKey('doctor-urgent-cabinet-sheet-close-button')),
        findsNothing,
      );
    });

    testWidgets('accept removes the card and shows the simulation outcome', (
      tester,
    ) async {
      final request = _request();
      await tester.pumpWidget(
        _subject(
          workspace: _workspace(),
          source: _FixedSource(DoctorUrgentCabinetFeedLoaded([request])),
          decisionSource: DoctorUrgentCabinetDevelopmentDecisionSource(
            request: request,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text('Voir la demande'));
      await tester.tap(find.text('Voir la demande'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('doctor-urgent-cabinet-accept')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nouvelle demande urgente'), findsNothing);
      expect(find.text('Voir la demande'), findsNothing);
      expect(find.text('Patient attendu au cabinet'), findsOneWidget);
      expect(find.text('Aucune demande urgente au cabinet'), findsOneWidget);
      expect(find.textContaining('QR'), findsNothing);
      expect(find.textContaining('itinéraire'), findsNothing);
    });

    testWidgets('refusal requires confirmation and cancel is non-mutating', (
      tester,
    ) async {
      final request = _request();
      await tester.pumpWidget(
        _subject(
          workspace: _workspace(),
          source: _FixedSource(DoctorUrgentCabinetFeedLoaded([request])),
          decisionSource: DoctorUrgentCabinetDevelopmentDecisionSource(
            request: request,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Voir la demande'));
      await tester.tap(find.text('Voir la demande'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('doctor-urgent-cabinet-refuse')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Refuser cette demande ?'), findsOneWidget);
      expect(
        find.text('Cette demande sera retirée de vos nouvelles demandes.'),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('doctor-urgent-cabinet-refuse-cancel')),
      );
      await tester.pumpAndSettle();
      expect(find.text('Nouvelle demande urgente'), findsOneWidget);
      expect(find.text('Voir la demande'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('doctor-urgent-cabinet-refuse')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('doctor-urgent-cabinet-refuse-confirm')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nouvelle demande urgente'), findsNothing);
      expect(find.text('Voir la demande'), findsNothing);
      expect(find.text('Demande refusée — simulation'), findsOneWidget);
    });

    testWidgets('decision progress disables both actions until completion', (
      tester,
    ) async {
      final request = _request();
      final completer = Completer<DoctorUrgentCabinetDecisionResult>();
      DoctorUrgentCabinetDecisionContext? capturedContext;
      await tester.pumpWidget(
        _subject(
          workspace: _workspace(),
          source: _FixedSource(DoctorUrgentCabinetFeedLoaded([request])),
          decisionSource: DoctorUrgentCabinetDevelopmentDecisionSource(
            request: request,
            executor: ({required request, required action, required context}) {
              capturedContext = context;
              return completer.future;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Voir la demande'));
      await tester.tap(find.text('Voir la demande'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('doctor-urgent-cabinet-accept')),
      );
      await tester.pump();

      final accept = tester.widget<FilledButton>(
        find.descendant(
          of: find.byKey(const ValueKey('doctor-urgent-cabinet-accept')),
          matching: find.byType(FilledButton),
        ),
      );
      final refuse = tester.widget<OutlinedButton>(
        find.descendant(
          of: find.byKey(const ValueKey('doctor-urgent-cabinet-refuse')),
          matching: find.byType(OutlinedButton),
        ),
      );
      expect(accept.onPressed, isNull);
      expect(refuse.onPressed, isNull);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      final semantics = tester.ensureSemantics();
      expect(
        find.bySemanticsLabel("Acceptation de la demande en cours"),
        findsOneWidget,
      );
      expect(
        tester
            .getSize(find.byKey(const ValueKey('doctor-urgent-cabinet-accept')))
            .height,
        greaterThanOrEqualTo(48),
      );
      expect(
        tester
            .getSize(find.byKey(const ValueKey('doctor-urgent-cabinet-refuse')))
            .height,
        greaterThanOrEqualTo(48),
      );

      await tester.binding.handlePopRoute();
      await tester.pump();
      expect(find.text('Nouvelle demande urgente'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      semantics.dispose();

      completer.complete(
        DoctorUrgentCabinetAcceptedResult(
          requestIdentity: request.stableIdentity,
          action: DoctorUrgentCabinetDecisionAction.accept,
          contextFingerprint: capturedContext!.fingerprint,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Patient attendu au cabinet'), findsOneWidget);
    });

    testWidgets('definite failure remains retryable only for its action', (
      tester,
    ) async {
      final request = _request();
      var calls = 0;
      await tester.pumpWidget(
        _subject(
          workspace: _workspace(),
          source: _FixedSource(DoctorUrgentCabinetFeedLoaded([request])),
          decisionSource: DoctorUrgentCabinetDevelopmentDecisionSource(
            request: request,
            executor:
                ({required request, required action, required context}) async {
                  calls++;
                  if (calls == 1) {
                    return DoctorUrgentCabinetDecisionDefiniteFailureResult(
                      requestIdentity: request.stableIdentity,
                      action: action,
                      contextFingerprint: context.fingerprint,
                      message: "La décision n'a pas été envoyée.",
                    );
                  }
                  return DoctorUrgentCabinetAcceptedResult(
                    requestIdentity: request.stableIdentity,
                    action: action,
                    contextFingerprint: context.fingerprint,
                  );
                },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Voir la demande'));
      await tester.tap(find.text('Voir la demande'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('doctor-urgent-cabinet-accept')),
      );
      await tester.pumpAndSettle();

      expect(find.text("La décision n'a pas été envoyée."), findsOneWidget);
      expect(find.text("Réessayer l'acceptation"), findsOneWidget);
      final refuse = tester.widget<OutlinedButton>(
        find.descendant(
          of: find.byKey(const ValueKey('doctor-urgent-cabinet-refuse')),
          matching: find.byType(OutlinedButton),
        ),
      );
      expect(refuse.onPressed, isNull);

      await tester.tap(find.text("Réessayer l'acceptation"));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.text('Patient attendu au cabinet'), findsOneWidget);
    });

    testWidgets('unknown and unavailable outcomes stay distinct', (
      tester,
    ) async {
      final request = _request();
      await tester.pumpWidget(
        _subject(
          workspace: _workspace(),
          source: _FixedSource(DoctorUrgentCabinetFeedLoaded([request])),
          decisionSource: DoctorUrgentCabinetDevelopmentDecisionSource(
            request: request,
            executor:
                ({
                  required request,
                  required action,
                  required context,
                }) async => DoctorUrgentCabinetDecisionUnknownResult(
                  requestIdentity: request.stableIdentity,
                  action: action,
                  contextFingerprint: context.fingerprint,
                  message:
                      'Le résultat de cette décision ne peut pas être vérifié pour le moment.',
                ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Voir la demande'));
      await tester.tap(find.text('Voir la demande'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('doctor-urgent-cabinet-accept')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('doctor-urgent-cabinet-decision-unknown')),
        findsOneWidget,
      );
      expect(find.text('Nouvelle demande urgente'), findsOneWidget);

      final unavailableRequest = _request(fixtureKey: 'request-b');
      await tester.pumpWidget(
        _subject(
          workspace: _workspace(),
          source: _FixedSource(
            DoctorUrgentCabinetFeedLoaded([unavailableRequest]),
          ),
          decisionSource: DoctorUrgentCabinetDevelopmentDecisionSource(
            request: unavailableRequest,
            executor:
                ({required request, required action, required context}) async =>
                    DoctorUrgentCabinetUnavailableResult(
                      requestIdentity: request.stableIdentity,
                      action: action,
                      contextFingerprint: context.fingerprint,
                    ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Voir la demande'));
      await tester.tap(find.text('Voir la demande'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const ValueKey('doctor-urgent-cabinet-accept')),
      );
      await tester.pumpAndSettle();
      expect(find.text("Cette demande n'est plus disponible"), findsOneWidget);
      expect(find.text('Demande refusée — simulation'), findsNothing);
    });

    testWidgets('Doctor and cabinet changes invalidate stale async results', (
      tester,
    ) async {
      final source = _ControlledSource();
      await tester.pumpWidget(
        _subject(workspace: _workspace(), source: source),
      );
      expect(source.completers, hasLength(1));

      await tester.pumpWidget(
        _subject(
          workspace: _workspace(doctorId: 'doctor-b', cabinet: _otherCabinet),
          source: source,
        ),
      );
      expect(source.completers, hasLength(2));

      source.completers[1].complete(
        DoctorUrgentCabinetFeedLoaded([
          _request(
            fixtureKey: 'request-b',
            doctorId: 'doctor-b',
            cabinet: _otherCabinet,
          ),
        ]),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('doctor-urgent-cabinet-request-request-b')),
        findsOneWidget,
      );

      source.completers[0].complete(
        DoctorUrgentCabinetFeedLoaded([_request()]),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('doctor-urgent-cabinet-request-request-a')),
        findsNothing,
      );
    });

    testWidgets('account change dismisses an open request sheet', (
      tester,
    ) async {
      final requestA = _request();
      await tester.pumpWidget(
        _subject(
          workspace: _workspace(),
          source: _FixedSource(DoctorUrgentCabinetFeedLoaded([requestA])),
        ),
      );
      await tester.pumpAndSettle();
      final open = find.text('Voir la demande');
      await tester.ensureVisible(open);
      await tester.tap(open);
      await tester.pumpAndSettle();
      expect(find.text('Nouvelle demande urgente'), findsOneWidget);

      await tester.pumpWidget(
        _subject(
          workspace: _workspace(doctorId: 'doctor-b'),
          source: _FixedSource(const DoctorUrgentCabinetFeedEmpty()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Nouvelle demande urgente'), findsNothing);
    });

    testWidgets('card and sheet fit supported widths with 2x text', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (final width in [320.0, 360.0, 390.0, 430.0, 768.0]) {
        tester.view.physicalSize = Size(width, 900);
        await tester.pumpWidget(
          _subject(
            workspace: _workspace(),
            source: _FixedSource(DoctorUrgentCabinetFeedLoaded([_request()])),
            textScale: 2,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'card width $width');

        final open = find.text('Voir la demande');
        await tester.ensureVisible(open);
        await tester.tap(open);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'sheet width $width');
        await tester.tap(
          find.byKey(const ValueKey('doctor-urgent-cabinet-sheet-close-icon')),
        );
        await tester.pumpAndSettle();
      }
    });
  });
}
