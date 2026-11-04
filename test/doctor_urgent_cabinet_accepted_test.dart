import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/core/theme/omni_theme.dart';
import 'package:omnicare_mobile/features/doctor/urgent_cabinet/doctor_urgent_cabinet_accepted_card.dart';
import 'package:omnicare_mobile/features/doctor/urgent_cabinet/doctor_urgent_cabinet_controller.dart';
import 'package:omnicare_mobile/features/doctor/urgent_cabinet/doctor_urgent_cabinet_decision.dart';
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
  DoctorCabinetConfig cabinet = _cabinet,
}) => DoctorWorkspaceConfig(
  doctorId: doctorId,
  onboardingCompleted: true,
  practiceModes: const {DoctorPracticeMode.cabinet},
  services: const {
    DoctorWorkspaceService.cabinetConsultations,
    DoctorWorkspaceService.urgentCabinetConsultations,
  },
  cabinet: cabinet,
  clinics: const [],
  homeVisit: null,
  availability: const DoctorAvailability(
    workingDays: {DoctorWorkingDay.monday},
    startTime: '08:00',
    endTime: '18:00',
  ),
);

DoctorUrgentCabinetRequest _request(String fixtureKey) =>
    DoctorUrgentCabinetRequest(
      developmentFixtureKey: DoctorUrgentCabinetDevelopmentFixtureKey(
        fixtureKey,
      ),
      targetDoctorId: 'doctor-a',
      targetCabinetIdentity: DoctorUrgentCabinetDevelopmentTargetIdentity(
        DoctorUrgentCabinetDevelopmentCabinetKey('cabinet-a'),
      ),
      cabinet: DoctorUrgentCabinetSnapshot(
        name: _cabinet.name,
        address: _cabinet.address,
        city: _cabinet.city,
        governorate: _cabinet.governorate,
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

DoctorUrgentCabinetController _configuredController() {
  return DoctorUrgentCabinetController()..configure(
    authenticatedDoctorId: 'doctor-a',
    workspaceConfig: _workspace(),
    requestSource: DoctorUrgentCabinetDevelopmentRequestSource(),
  );
}

Future<DoctorUrgentCabinetRequest> _acceptSimulation(
  DoctorUrgentCabinetController controller,
) async {
  expect(
    controller.simulateDevelopmentRequest(),
    DoctorUrgentCabinetSimulationTransition.created,
  );
  final request = controller.visibleNewRequests.single;
  expect(
    await controller.accept(request.stableIdentity),
    DoctorUrgentCabinetDecisionTransition.accepted,
  );
  return request;
}

Widget _screen(
  DoctorUrgentCabinetController controller, {
  DoctorWorkspaceConfig? workspace,
  double textScale = 1,
}) => MaterialApp(
  theme: buildOmniTheme(),
  home: MediaQuery(
    data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
    child: Scaffold(
      body: DoctorUrgentCabinetScreen(
        workspaceConfig: workspace ?? _workspace(),
        controller: controller,
      ),
    ),
  ),
);

Future<void> _pumpUi(WidgetTester tester) async {
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('accepted card replaces the generic accepted acknowledgement', (
    tester,
  ) async {
    final controller = _configuredController();
    addTearDown(controller.dispose);
    final request = await _acceptSimulation(controller);

    await tester.pumpWidget(_screen(controller));
    await _pumpUi(tester);

    expect(
      controller.stateFor(request.stableIdentity),
      isA<DoctorUrgentCabinetAccepted>(),
    );
    expect(
      find.byKey(const ValueKey('doctor-urgent-cabinet-accepted-section')),
      findsOneWidget,
    );
    expect(find.text('Demandes acceptées'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('doctor-urgent-cabinet-accepted-count')),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    expect(find.text('Patient attendu au cabinet'), findsOneWidget);
    expect(find.text('Demande acceptée — simulation'), findsNothing);
    expect(find.text('Nouvelle demande urgente'), findsNothing);
    expect(find.text('Patient concerné'), findsOneWidget);
    expect(find.text('Identité non communiquée à ce stade'), findsOneWidget);
    expect(find.text('75,000 DT'), findsOneWidget);
    expect(
      find.text('Simulation locale — aucune demande réelle'),
      findsOneWidget,
    );
  });

  testWidgets('declined and unavailable decisions stay compact and excluded', (
    tester,
  ) async {
    final declined = _configuredController();
    addTearDown(declined.dispose);
    expect(
      declined.simulateDevelopmentRequest(),
      DoctorUrgentCabinetSimulationTransition.created,
    );
    await declined.refuse(declined.visibleNewRequests.single.stableIdentity);

    await tester.pumpWidget(_screen(declined));
    await _pumpUi(tester);
    expect(find.text('Demande refusée — simulation'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('doctor-urgent-cabinet-accepted-section')),
      findsNothing,
    );

    final source = _MutableSource(
      DoctorUrgentCabinetFeedLoaded([_request('gone')]),
    );
    final unavailable = DoctorUrgentCabinetController()
      ..configure(
        authenticatedDoctorId: 'doctor-a',
        workspaceConfig: _workspace(),
        requestSource: source,
      );
    addTearDown(unavailable.dispose);

    await tester.pumpWidget(_screen(unavailable));
    await _pumpUi(tester);
    source.state = const DoctorUrgentCabinetFeedEmpty();
    await unavailable.refresh();
    await _pumpUi(tester);
    expect(find.text("Cette demande n'est plus disponible"), findsOneWidget);
    expect(
      find.byKey(const ValueKey('doctor-urgent-cabinet-accepted-section')),
      findsNothing,
    );
  });

  testWidgets(
    'preview is newest first and expands and collapses without duplicates',
    (tester) async {
      final controller = _configuredController();
      addTearDown(controller.dispose);
      final accepted = <DoctorUrgentCabinetRequest>[];
      for (var index = 0; index < 4; index++) {
        accepted.add(await _acceptSimulation(controller));
      }

      await tester.pumpWidget(_screen(controller));
      await _pumpUi(tester);

      List<String> visibleIdentities() => tester
          .widgetList<DoctorUrgentCabinetAcceptedCard>(
            find.byType(DoctorUrgentCabinetAcceptedCard),
          )
          .map((card) => card.request.stableIdentity)
          .toList();

      expect(find.byType(DoctorUrgentCabinetAcceptedCard), findsNWidgets(3));
      expect(
        visibleIdentities(),
        accepted.reversed.take(3).map((r) => r.stableIdentity),
      );
      expect(
        find.byKey(const ValueKey('doctor-urgent-cabinet-accepted-expand')),
        findsOneWidget,
      );

      await tester.ensureVisible(
        find.byKey(const ValueKey('doctor-urgent-cabinet-accepted-expand')),
      );
      await tester.tap(
        find.byKey(const ValueKey('doctor-urgent-cabinet-accepted-expand')),
      );
      await _pumpUi(tester);
      expect(find.byType(DoctorUrgentCabinetAcceptedCard), findsNWidgets(4));
      expect(visibleIdentities().toSet(), hasLength(4));

      await tester.ensureVisible(
        find.byKey(const ValueKey('doctor-urgent-cabinet-accepted-collapse')),
      );
      await tester.tap(
        find.byKey(const ValueKey('doctor-urgent-cabinet-accepted-collapse')),
      );
      await _pumpUi(tester);
      expect(find.byType(DoctorUrgentCabinetAcceptedCard), findsNWidgets(3));
    },
  );

  testWidgets('selected accepted card opens exact read-only masked details', (
    tester,
  ) async {
    final controller = _configuredController();
    addTearDown(controller.dispose);
    final first = await _acceptSimulation(controller);
    final second = await _acceptSimulation(controller);

    await tester.pumpWidget(_screen(controller));
    await _pumpUi(tester);
    final open = find.byKey(
      ValueKey('doctor-urgent-cabinet-accepted-open-${second.stableIdentity}'),
    );
    await tester.ensureVisible(open);
    await tester.tap(open);
    await _pumpUi(tester);

    expect(
      find.byKey(
        ValueKey(
          'doctor-urgent-cabinet-accepted-sheet-${second.stableIdentity}',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        ValueKey(
          'doctor-urgent-cabinet-accepted-sheet-${first.stableIdentity}',
        ),
      ),
      findsNothing,
    );
    expect(find.text('Patient concerné'), findsWidgets);
    expect(find.text('Identité non communiquée à ce stade'), findsWidgets);
    expect(find.text(_cabinet.name), findsWidgets);
    expect(find.textContaining(_cabinet.address), findsWidgets);
    expect(find.text('75,000 DT'), findsWidgets);
    expect(
      find.text(
        "Aucun déplacement, arrivée ou début de consultation n'est confirmé.",
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Amina'), findsNothing);
    expect(find.textContaining('Patient arrivé'), findsNothing);
    expect(find.textContaining('Commencer la consultation'), findsNothing);
    expect(find.textContaining('QR'), findsNothing);
    expect(find.textContaining('Maps'), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey('doctor-urgent-cabinet-accepted-sheet-close')),
    );
    await _pumpUi(tester);
    expect(find.text('Demandes acceptées'), findsOneWidget);
    expect(
      controller.stateFor(second.stableIdentity),
      isA<DoctorUrgentCabinetAccepted>(),
    );
  });

  testWidgets('system Back closes only accepted details', (tester) async {
    final controller = _configuredController();
    addTearDown(controller.dispose);
    final request = await _acceptSimulation(controller);
    await tester.pumpWidget(_screen(controller));
    await _pumpUi(tester);

    final open = find.byKey(
      ValueKey('doctor-urgent-cabinet-accepted-open-${request.stableIdentity}'),
    );
    await tester.ensureVisible(open);
    await tester.tap(open);
    await _pumpUi(tester);
    await tester.binding.handlePopRoute();
    await _pumpUi(tester);

    expect(
      find.byKey(
        ValueKey(
          'doctor-urgent-cabinet-accepted-sheet-${request.stableIdentity}',
        ),
      ),
      findsNothing,
    );
    expect(find.text('Demandes acceptées'), findsOneWidget);
    expect(
      controller.stateFor(request.stableIdentity),
      isA<DoctorUrgentCabinetAccepted>(),
    );
  });

  testWidgets(
    'context invalidation closes stale accepted details and clears data',
    (tester) async {
      final controller = _configuredController();
      addTearDown(controller.dispose);
      final request = await _acceptSimulation(controller);
      await tester.pumpWidget(_screen(controller));
      await _pumpUi(tester);

      final open = find.byKey(
        ValueKey(
          'doctor-urgent-cabinet-accepted-open-${request.stableIdentity}',
        ),
      );
      await tester.ensureVisible(open);
      await tester.tap(open);
      await _pumpUi(tester);

      controller.configure(
        authenticatedDoctorId: 'doctor-a',
        workspaceConfig: _workspace(cabinet: _otherCabinet),
        requestSource: DoctorUrgentCabinetDevelopmentRequestSource(),
      );
      await _pumpUi(tester);

      expect(controller.stateFor(request.stableIdentity), isNull);
      expect(find.text('Patient attendu au cabinet'), findsNothing);
      expect(
        find.byKey(const ValueKey('doctor-urgent-cabinet-accepted-section')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'feed refresh retains accepted state and never revives it as new',
    (tester) async {
      final controller = _configuredController();
      addTearDown(controller.dispose);
      final request = await _acceptSimulation(controller);
      await controller.refresh();

      await tester.pumpWidget(_screen(controller));
      await _pumpUi(tester);
      expect(
        controller.stateFor(request.stableIdentity),
        isA<DoctorUrgentCabinetAccepted>(),
      );
      expect(find.byType(DoctorUrgentCabinetAcceptedCard), findsOneWidget);
      expect(find.text('Nouvelle demande urgente'), findsNothing);
    },
  );

  testWidgets(
    'accepted presentation remains scrollable at narrow widths and 2x text',
    (tester) async {
      final controller = _configuredController();
      addTearDown(controller.dispose);
      final request = await _acceptSimulation(controller);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;

      for (final width in <double>[320, 360, 390, 430]) {
        tester.view.physicalSize = Size(width, 720);
        await tester.pumpWidget(_screen(controller, textScale: 2));
        await _pumpUi(tester);
        expect(tester.takeException(), isNull, reason: 'width $width');
        expect(find.byType(DoctorUrgentCabinetAcceptedCard), findsOneWidget);
      }

      final open = find.byKey(
        ValueKey(
          'doctor-urgent-cabinet-accepted-open-${request.stableIdentity}',
        ),
      );
      await tester.ensureVisible(open);
      await tester.tap(open);
      await _pumpUi(tester);
      expect(tester.takeException(), isNull);
      expect(
        find.byKey(
          const ValueKey('doctor-urgent-cabinet-accepted-sheet-close'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'large accepted history stays unique, addressable and bounded on remount',
    (tester) async {
      final controller = _configuredController();
      addTearDown(controller.dispose);
      final accepted = <DoctorUrgentCabinetRequest>[];
      for (var index = 0; index < 40; index++) {
        accepted.add(await _acceptSimulation(controller));
      }
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view
        ..devicePixelRatio = 1
        ..physicalSize = const Size(1024, 768);

      await tester.pumpWidget(_screen(controller, textScale: 1.5));
      await _pumpUi(tester);
      expect(find.byType(DoctorUrgentCabinetAcceptedCard), findsNWidgets(3));

      final expansion = Stopwatch()..start();
      await tester.ensureVisible(
        find.byKey(const ValueKey('doctor-urgent-cabinet-accepted-expand')),
      );
      await tester.tap(
        find.byKey(const ValueKey('doctor-urgent-cabinet-accepted-expand')),
      );
      await _pumpUi(tester);
      expansion.stop();

      final cards = tester
          .widgetList<DoctorUrgentCabinetAcceptedCard>(
            find.byType(DoctorUrgentCabinetAcceptedCard),
          )
          .toList(growable: false);
      expect(cards, hasLength(40));
      expect(
        cards.map((card) => card.request.stableIdentity).toSet(),
        hasLength(40),
      );
      expect(tester.takeException(), isNull);
      // Diagnostic only: this is a local widget-test duration, not frame data.
      // ignore: avoid_print
      print(
        'D-UI-06C metric: expanded 40 accepted cards in '
        '${expansion.elapsedMilliseconds} ms',
      );

      for (final request in accepted.reversed.take(5)) {
        final open = find.byKey(
          ValueKey(
            'doctor-urgent-cabinet-accepted-open-${request.stableIdentity}',
          ),
        );
        await tester.scrollUntilVisible(open, 500);
        await tester.tap(open);
        await _pumpUi(tester);
        expect(
          find.byKey(
            ValueKey(
              'doctor-urgent-cabinet-accepted-sheet-${request.stableIdentity}',
            ),
          ),
          findsOneWidget,
        );
        await tester.tap(
          find.byKey(
            const ValueKey('doctor-urgent-cabinet-accepted-sheet-close'),
          ),
        );
        await _pumpUi(tester);
      }

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(_screen(controller, textScale: 1.5));
      await _pumpUi(tester);
      expect(find.byType(DoctorUrgentCabinetAcceptedCard), findsNWidgets(3));
      expect(controller.terminalDecisions, hasLength(40));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('accepted cards and sheet fit portrait, landscape and tablet', (
    tester,
  ) async {
    final controller = _configuredController();
    addTearDown(controller.dispose);
    final request = await _acceptSimulation(controller);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;

    for (final configuration in <(Size, double)>[
      (const Size(768, 1024), 1),
      (const Size(1024, 768), 1.5),
      (const Size(844, 390), 2),
    ]) {
      tester.view.physicalSize = configuration.$1;
      await tester.pumpWidget(_screen(controller, textScale: configuration.$2));
      await _pumpUi(tester);
      expect(tester.takeException(), isNull, reason: '$configuration');

      final open = find.byKey(
        ValueKey(
          'doctor-urgent-cabinet-accepted-open-${request.stableIdentity}',
        ),
      );
      await tester.ensureVisible(open);
      await tester.tap(open);
      await _pumpUi(tester);
      expect(tester.takeException(), isNull, reason: '$configuration sheet');
      expect(
        tester
            .getSize(
              find.byKey(
                const ValueKey('doctor-urgent-cabinet-accepted-sheet-close'),
              ),
            )
            .height,
        greaterThanOrEqualTo(48),
      );
      await tester.tap(
        find.byKey(
          const ValueKey('doctor-urgent-cabinet-accepted-sheet-close'),
        ),
      );
      await _pumpUi(tester);
    }
  });
}

class _MutableSource implements DoctorUrgentCabinetRequestSource {
  _MutableSource(this.state);

  DoctorUrgentCabinetFeedState state;

  @override
  Future<DoctorUrgentCabinetFeedState> load(
    DoctorUrgentCabinetRequestContext context, {
    CancelToken? cancelToken,
  }) async => state;
}
