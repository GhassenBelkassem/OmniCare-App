import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:omnicare_mobile/core/theme/omni_theme.dart';
import 'package:omnicare_mobile/features/doctor/urgent_cabinet/doctor_urgent_cabinet_accepted_card.dart';
import 'package:omnicare_mobile/features/doctor/urgent_cabinet/doctor_urgent_cabinet_check_in_entry_sheet.dart';
import 'package:omnicare_mobile/features/doctor/urgent_cabinet/doctor_urgent_cabinet_controller.dart';
import 'package:omnicare_mobile/features/doctor/urgent_cabinet/doctor_urgent_cabinet_decision.dart';
import 'package:omnicare_mobile/features/doctor/urgent_cabinet/doctor_urgent_cabinet_qr_preview_screen.dart';
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
  homeVisit: null,
  availability: const DoctorAvailability(
    workingDays: {DoctorWorkingDay.monday},
    startTime: '08:00',
    endTime: '18:00',
  ),
);

class _CountingDevelopmentSource
    extends DoctorUrgentCabinetDevelopmentRequestSource {
  int loads = 0;

  @override
  Future<DoctorUrgentCabinetFeedState> load(
    DoctorUrgentCabinetRequestContext context, {
    CancelToken? cancelToken,
  }) {
    loads++;
    return super.load(context, cancelToken: cancelToken);
  }
}

DoctorUrgentCabinetController _configuredController({
  DoctorWorkspaceConfig? workspace,
  DoctorUrgentCabinetRequestSource? source,
}) => DoctorUrgentCabinetController()
  ..configure(
    authenticatedDoctorId: workspace?.doctorId ?? 'doctor-a',
    workspaceConfig: workspace ?? _workspace(),
    requestSource: source ?? DoctorUrgentCabinetDevelopmentRequestSource(),
  );

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

Finder _acceptedOpen(DoctorUrgentCabinetRequest request) => find.byKey(
  ValueKey('doctor-urgent-cabinet-accepted-open-${request.stableIdentity}'),
);

const _verifyAction = ValueKey(
  'doctor-urgent-cabinet-accepted-sheet-verify-arrival',
);
const _entrySheet = ValueKey('doctor-urgent-cabinet-check-in-entry-sheet');
const _entryClose = ValueKey('doctor-urgent-cabinet-check-in-entry-close');
const _openScanner = ValueKey(
  'doctor-urgent-cabinet-check-in-open-scanner-preview',
);
const _scannerScreen = ValueKey('doctor-urgent-cabinet-qr-preview-screen');

Future<void> _openAcceptedDetails(
  WidgetTester tester,
  DoctorUrgentCabinetRequest request,
) async {
  await tester.ensureVisible(_acceptedOpen(request));
  await tester.tap(_acceptedOpen(request));
  await tester.pumpAndSettle();
}

Future<void> _openEntry(
  WidgetTester tester,
  DoctorUrgentCabinetRequest request,
) async {
  await _openAcceptedDetails(tester, request);
  await tester.tap(find.byKey(_verifyAction));
  await tester.pumpAndSettle();
}

Future<void> _openScannerPreview(
  WidgetTester tester,
  DoctorUrgentCabinetRequest request,
) async {
  await _openEntry(tester, request);
  await tester.ensureVisible(find.byKey(_openScanner));
  await tester.tap(find.byKey(_openScanner));
  await tester.pumpAndSettle();
}

void _expectAccepted(
  DoctorUrgentCabinetController controller,
  DoctorUrgentCabinetRequest request,
) {
  final state = controller.stateFor(request.stableIdentity);
  expect(state, isA<DoctorUrgentCabinetAccepted>());
  expect((state! as DoctorUrgentCabinetAccepted).request, same(request));
}

void main() {
  testWidgets(
    'only an accepted request exposes the arrival verification entry',
    (tester) async {
      final controller = _configuredController();
      addTearDown(controller.dispose);
      expect(
        controller.simulateDevelopmentRequest(),
        DoctorUrgentCabinetSimulationTransition.created,
      );
      await tester.pumpWidget(_screen(controller));
      await tester.pumpAndSettle();

      expect(find.byKey(_verifyAction), findsNothing);
      expect(find.byKey(_entrySheet), findsNothing);
      expect(find.byType(DoctorUrgentCabinetAcceptedCard), findsNothing);
    },
  );

  testWidgets('disabled/profile gate preserves the informational QR card', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildOmniTheme(),
        home: Scaffold(
          body: DoctorUrgentCabinetCheckInEntrySheet(
            onOpenScannerPreview: null,
            onClose: () {},
          ),
        ),
      ),
    );

    expect(find.text('Fonctionnalité à venir'), findsOneWidget);
    expect(find.byKey(_openScanner), findsNothing);
    expect(find.text('Patient sans QR disponible'), findsOneWidget);
    expect(
      find.text('Procédure non disponible dans cette démonstration'),
      findsOneWidget,
    );
  });

  testWidgets(
    'accepted details transition to an informational sheet without mutation',
    (tester) async {
      final source = _CountingDevelopmentSource();
      final controller = _configuredController(source: source);
      addTearDown(controller.dispose);
      final request = await _acceptSimulation(controller);
      await tester.pumpWidget(_screen(controller));
      await tester.pumpAndSettle();
      final loadsBeforeEntry = source.loads;

      await _openEntry(tester, request);

      expect(find.byKey(_entrySheet), findsOneWidget);
      expect(find.byKey(_verifyAction), findsNothing);
      expect(find.text('Vérification de présence'), findsOneWidget);
      expect(
        find.text(
          'Vérifiez la présence du patient au cabinet avant toute prise en charge clinique.',
        ),
        findsOneWidget,
      );
      expect(find.text('Scanner le QR du patient'), findsOneWidget);
      expect(find.text('Aperçu de développement'), findsOneWidget);
      expect(find.byKey(_openScanner), findsOneWidget);
      expect(find.text('Patient sans QR disponible'), findsOneWidget);
      expect(
        find.text('Procédure non disponible dans cette démonstration'),
        findsOneWidget,
      );
      expect(
        find.text(
          'La vérification de présence ne démarre pas la consultation et ne donne pas accès au dossier médical.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          "Démonstration — aucune vérification réelle n'est effectuée.",
        ),
        findsOneWidget,
      );
      expect(source.loads, loadsBeforeEntry);
      _expectAccepted(controller, request);
    },
  );

  testWidgets('entry exposes only the static preview and no clinical action', (
    tester,
  ) async {
    final controller = _configuredController();
    addTearDown(controller.dispose);
    final request = await _acceptSimulation(controller);
    await tester.pumpWidget(_screen(controller));
    await tester.pumpAndSettle();
    await _openEntry(tester, request);

    expect(find.textContaining('Patient arrivé'), findsNothing);
    expect(find.textContaining('Présence confirmée'), findsNothing);
    expect(find.textContaining('Commencer la consultation'), findsNothing);
    expect(find.textContaining('Consultation en cours'), findsNothing);
    expect(
      find.textContaining('dossier médical', findRichText: true),
      findsOneWidget,
    );
    expect(find.textContaining('token', findRichText: true), findsNothing);
    expect(find.textContaining('consultationId'), findsNothing);
    expect(find.textContaining('requestId'), findsNothing);
    expect(find.textContaining('patientId'), findsNothing);
    expect(find.textContaining('Scanner maintenant'), findsNothing);
    expect(find.byIcon(Icons.camera_alt), findsNothing);
    expect(find.byType(FilledButton), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Fermer'), findsOneWidget);
    _expectAccepted(controller, request);
  });

  testWidgets('Fermer returns to the workspace and retains frozen snapshots', (
    tester,
  ) async {
    final controller = _configuredController();
    addTearDown(controller.dispose);
    final request = await _acceptSimulation(controller);
    final originalCabinet = request.cabinet;
    final originalFee = request.fee;
    final originalPatient = request.patient;
    await tester.pumpWidget(_screen(controller));
    await tester.pumpAndSettle();
    await _openEntry(tester, request);

    await tester.tap(find.byKey(_entryClose));
    await tester.pumpAndSettle();

    expect(find.byKey(_entrySheet), findsNothing);
    expect(find.text('Demandes acceptées'), findsOneWidget);
    expect(find.byType(DoctorUrgentCabinetAcceptedCard), findsOneWidget);
    _expectAccepted(controller, request);
    expect(request.cabinet, same(originalCabinet));
    expect(request.fee, same(originalFee));
    expect(request.patient, same(originalPatient));
    expect(find.text(_cabinet.name), findsWidgets);
    expect(find.text('75,000 DT'), findsOneWidget);
    expect(find.text('Patient concerné'), findsOneWidget);
    expect(find.text('Identité non communiquée à ce stade'), findsOneWidget);
  });

  testWidgets('system Back and drag dismiss without changing acceptance', (
    tester,
  ) async {
    final controller = _configuredController();
    addTearDown(controller.dispose);
    final request = await _acceptSimulation(controller);
    await tester.pumpWidget(_screen(controller));
    await tester.pumpAndSettle();

    await _openEntry(tester, request);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byKey(_entrySheet), findsNothing);
    _expectAccepted(controller, request);

    await _openEntry(tester, request);
    final bottomSheet = find.byType(BottomSheet);
    final sheetTop = tester.getTopLeft(bottomSheet);
    final sheetSize = tester.getSize(bottomSheet);
    await tester.dragFrom(
      sheetTop + Offset(sheetSize.width / 2, 12),
      const Offset(0, 900),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(_entrySheet), findsNothing);
    _expectAccepted(controller, request);
  });

  testWidgets('rapid repeated taps produce one verification route', (
    tester,
  ) async {
    final controller = _configuredController();
    addTearDown(controller.dispose);
    final request = await _acceptSimulation(controller);
    await tester.pumpWidget(_screen(controller));
    await tester.pumpAndSettle();
    await _openAcceptedDetails(tester, request);

    final action = find.byKey(_verifyAction);
    await tester.tap(action);
    await tester.tap(action, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.byKey(_entrySheet), findsOneWidget);
    expect(find.text('Vérification de présence'), findsOneWidget);
    _expectAccepted(controller, request);
  });

  testWidgets(
    'account, cabinet, capability and controller reset invalidate open entry',
    (tester) async {
      Future<void> verifyInvalidation(
        void Function(DoctorUrgentCabinetController controller) invalidate,
      ) async {
        final controller = _configuredController();
        final request = await _acceptSimulation(controller);
        await tester.pumpWidget(_screen(controller));
        await tester.pumpAndSettle();
        await _openEntry(tester, request);

        invalidate(controller);
        await tester.pumpAndSettle();

        expect(find.byKey(_entrySheet), findsNothing);
        expect(controller.stateFor(request.stableIdentity), isNull);
        controller.dispose();
        await tester.pumpWidget(const SizedBox.shrink());
      }

      await verifyInvalidation(
        (controller) => controller.configure(
          authenticatedDoctorId: 'doctor-b',
          workspaceConfig: _workspace(doctorId: 'doctor-b'),
          requestSource: DoctorUrgentCabinetDevelopmentRequestSource(),
        ),
      );
      await verifyInvalidation(
        (controller) => controller.configure(
          authenticatedDoctorId: 'doctor-a',
          workspaceConfig: _workspace(cabinet: _otherCabinet),
          requestSource: DoctorUrgentCabinetDevelopmentRequestSource(),
        ),
      );
      await verifyInvalidation(
        (controller) => controller.configure(
          authenticatedDoctorId: 'doctor-a',
          workspaceConfig: _workspace(urgentCabinetEnabled: false),
          requestSource: DoctorUrgentCabinetDevelopmentRequestSource(),
        ),
      );
      await verifyInvalidation(
        (controller) => controller.resetDevelopmentSimulation(),
      );
    },
  );

  testWidgets('an invalidated accepted entry cannot complete the transition', (
    tester,
  ) async {
    final controller = _configuredController();
    addTearDown(controller.dispose);
    final request = await _acceptSimulation(controller);
    await tester.pumpWidget(_screen(controller));
    await tester.pumpAndSettle();
    await _openAcceptedDetails(tester, request);

    controller.clear();
    await tester.pumpAndSettle();
    expect(find.byKey(_verifyAction), findsNothing);
    expect(find.byKey(_entrySheet), findsNothing);
    expect(controller.stateFor(request.stableIdentity), isNull);
  });

  testWidgets(
    'entry is responsive at narrow widths, large text and landscape',
    (tester) async {
      final controller = _configuredController();
      addTearDown(controller.dispose);
      final request = await _acceptSimulation(controller);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;

      for (final configuration in <(Size, double)>[
        (const Size(320, 720), 2),
        (const Size(360, 720), 2),
        (const Size(390, 720), 2),
        (const Size(430, 720), 2),
        (const Size(844, 390), 2),
      ]) {
        tester.view.physicalSize = configuration.$1;
        await tester.pumpWidget(
          _screen(controller, textScale: configuration.$2),
        );
        await tester.pumpAndSettle();
        await _openEntry(tester, request);

        expect(tester.takeException(), isNull, reason: '$configuration');
        expect(find.byKey(_entrySheet), findsOneWidget);
        expect(
          tester.getSize(find.byKey(_entryClose)).height,
          greaterThanOrEqualTo(48),
        );
        await tester.tap(find.byKey(_entryClose));
        await tester.pumpAndSettle();
      }
    },
  );

  testWidgets(
    'preview entry has button semantics while fallback stays unavailable',
    (tester) async {
      final controller = _configuredController();
      addTearDown(controller.dispose);
      final request = await _acceptSimulation(controller);
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_screen(controller));
      await tester.pumpAndSettle();
      await _openEntry(tester, request);

      final qrSemantics = find.bySemanticsLabel(
        'Scanner le QR du patient. Le patient ou son représentant autorisé devra présenter un QR sécurisé associé à cette demande. Aperçu de développement.',
      );
      final fallbackSemantics = find.bySemanticsLabel(
        "Patient sans QR disponible. Une procédure exceptionnelle de vérification d'identité pourra être prévue lorsque le patient ne peut pas utiliser son téléphone. Procédure non disponible dans cette démonstration.",
      );
      expect(qrSemantics, findsOneWidget);
      expect(fallbackSemantics, findsOneWidget);
      expect(tester.getSemantics(qrSemantics).flagsCollection.isButton, isTrue);
      expect(
        tester.getSemantics(fallbackSemantics).flagsCollection.isButton,
        isFalse,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      expect(FocusManager.instance.primaryFocus, isNotNull);
      expect(find.byKey(_entryClose), findsOneWidget);
      _expectAccepted(controller, request);
      semantics.dispose();
    },
  );

  testWidgets('simulator remains functional after entry closes', (
    tester,
  ) async {
    final controller = _configuredController();
    addTearDown(controller.dispose);
    final request = await _acceptSimulation(controller);
    await tester.pumpWidget(_screen(controller));
    await tester.pumpAndSettle();
    await _openEntry(tester, request);
    await tester.tap(find.byKey(_entryClose));
    await tester.pumpAndSettle();

    expect(
      controller.simulateDevelopmentRequest(),
      DoctorUrgentCabinetSimulationTransition.created,
    );
    expect(controller.visibleNewRequests, hasLength(1));
    _expectAccepted(controller, request);
  });

  testWidgets(
    'entry closes before scanner opens and Back preserves the accepted request',
    (tester) async {
      final controller = _configuredController();
      addTearDown(controller.dispose);
      final request = await _acceptSimulation(controller);
      final originalCabinet = request.cabinet;
      final originalFee = request.fee;
      await tester.pumpWidget(_screen(controller));
      await tester.pumpAndSettle();

      await _openScannerPreview(tester, request);

      expect(find.byKey(_entrySheet), findsNothing);
      expect(find.byKey(_verifyAction), findsNothing);
      expect(find.byKey(_scannerScreen), findsOneWidget);
      expect(find.byType(DoctorUrgentCabinetQrPreviewScreen), findsOneWidget);
      _expectAccepted(controller, request);

      await tester.tap(
        find.byKey(const ValueKey('doctor-urgent-cabinet-qr-preview-back')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(_scannerScreen), findsNothing);
      expect(find.byType(DoctorUrgentCabinetAcceptedCard), findsOneWidget);
      expect(_acceptedOpen(request), findsOneWidget);
      _expectAccepted(controller, request);
      expect(request.cabinet, same(originalCabinet));
      expect(request.fee, same(originalFee));

      await _openAcceptedDetails(tester, request);
      expect(find.byKey(_verifyAction), findsOneWidget);
    },
  );

  testWidgets('rapid preview taps create one scanner route', (tester) async {
    final controller = _configuredController();
    addTearDown(controller.dispose);
    final request = await _acceptSimulation(controller);
    await tester.pumpWidget(_screen(controller));
    await tester.pumpAndSettle();
    await _openEntry(tester, request);
    await tester.ensureVisible(find.byKey(_openScanner));

    await tester.tap(find.byKey(_openScanner));
    await tester.tap(find.byKey(_openScanner), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.byType(DoctorUrgentCabinetQrPreviewScreen), findsOneWidget);
    expect(find.byKey(_entrySheet), findsNothing);
    _expectAccepted(controller, request);
  });

  testWidgets(
    'account, cabinet, capability and reset invalidate the exact scanner route',
    (tester) async {
      Future<void> verifyInvalidation(
        void Function(DoctorUrgentCabinetController controller) invalidate,
      ) async {
        final controller = _configuredController();
        final request = await _acceptSimulation(controller);
        await tester.pumpWidget(_screen(controller));
        await tester.pumpAndSettle();
        await _openScannerPreview(tester, request);

        invalidate(controller);
        await tester.pumpAndSettle();

        expect(find.byKey(_scannerScreen), findsNothing);
        expect(controller.stateFor(request.stableIdentity), isNull);
        controller.dispose();
        await tester.pumpWidget(const SizedBox.shrink());
      }

      await verifyInvalidation(
        (controller) => controller.configure(
          authenticatedDoctorId: 'doctor-b',
          workspaceConfig: _workspace(doctorId: 'doctor-b'),
          requestSource: DoctorUrgentCabinetDevelopmentRequestSource(),
        ),
      );
      await verifyInvalidation(
        (controller) => controller.configure(
          authenticatedDoctorId: 'doctor-a',
          workspaceConfig: _workspace(cabinet: _otherCabinet),
          requestSource: DoctorUrgentCabinetDevelopmentRequestSource(),
        ),
      );
      await verifyInvalidation(
        (controller) => controller.configure(
          authenticatedDoctorId: 'doctor-a',
          workspaceConfig: _workspace(urgentCabinetEnabled: false),
          requestSource: DoctorUrgentCabinetDevelopmentRequestSource(),
        ),
      );
      await verifyInvalidation(
        (controller) => controller.resetDevelopmentSimulation(),
      );
    },
  );

  testWidgets('disposing the owning CABINET screen removes its scanner route', (
    tester,
  ) async {
    final controller = _configuredController();
    final request = await _acceptSimulation(controller);
    await tester.pumpWidget(_screen(controller));
    await tester.pumpAndSettle();
    await _openScannerPreview(tester, request);

    controller.dispose();
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pumpAndSettle();

    expect(find.byKey(_scannerScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
