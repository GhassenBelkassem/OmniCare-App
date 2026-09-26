import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/core/theme/omni_theme.dart';
import 'package:omnicare_mobile/features/doctor/urgent/doctor_urgent_controller.dart';
import 'package:omnicare_mobile/features/doctor/urgent/doctor_urgent_map.dart';
import 'package:omnicare_mobile/features/doctor/urgent/doctor_urgent_qr_scanner_screen.dart';
import 'package:omnicare_mobile/features/doctor/urgent/doctor_urgent_screen.dart';

void main() {
  test('Google Maps directions URL uses the static patient destination', () {
    final uri = DoctorUrgentMapDemo.directionsUri();

    expect(uri.scheme, 'https');
    expect(uri.host, 'www.google.com');
    expect(uri.path, '/maps/dir/');
    expect(uri.queryParameters, {
      'api': '1',
      'destination': '36.8065,10.1815',
      'travelmode': 'driving',
    });
  });

  testWidgets('offline composition exposes availability and grouped visits', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: buildOmniTheme(),
        home: Scaffold(
          body: DoctorUrgentScreen(controller: DoctorUrgentController()),
        ),
      ),
    );
    for (final label in [
      'Urgences',
      'Gérez vos demandes urgentes et visites à domicile.',
      'Hors ligne',
      'Passez en ligne pour recevoir des demandes.',
      'Vous êtes hors ligne',
      'Passer en ligne',
      'Visites récentes',
      'Sami Ben Ali',
      'Nadia Mansour',
      'Hatem Gharbi',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.byType(Switch), findsOneWidget);
    expect(
      find.byKey(const ValueKey('urgent-recent-visits-card')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
  testWidgets('available state shows anonymous nearby requests', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = DoctorUrgentController();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildOmniTheme(),
        home: Scaffold(body: DoctorUrgentScreen(controller: c)),
      ),
    );
    c.goOnline();
    await tester.pump();
    for (final label in [
      'Disponible pour les urgences',
      'Nouvelles demandes',
      'URGENT · OMN-2026-1847',
      'Patient · 45 ans',
      'Douleur thoracique sévère',
      'À proximité de Tunis · 1,8 km · ~6 min',
      'Refuser',
      'Voir',
      'Accepter',
      '1 autre demande à proximité',
      'Patient · 61 ans',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.textContaining('Amina'), findsNothing);
    expect(find.textContaining('Chaari'), findsNothing);
    expect(find.textContaining('Avenue Habib'), findsNothing);
    expect(tester.takeException(), isNull);
    c.dispose();
  });
  testWidgets('waiting state remains anonymous with debug-only simulation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final c = DoctorUrgentController();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildOmniTheme(),
        home: Scaffold(body: DoctorUrgentScreen(controller: c)),
      ),
    );
    c.goOnline();
    c.showOffer();
    c.accept();
    await tester.pump();
    for (final label in [
      'Proposition envoyée',
      'Le patient choisit actuellement son médecin.',
      'En attente du patient',
      'Patient · 45 ans',
      'Douleur thoracique sévère',
      'Visites récentes',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.textContaining('À proximité de Tunis'), findsOneWidget);
    for (final private in [
      'Amina',
      'Chaari',
      'AC',
      '15 Avenue Habib Bourguiba',
      'Réponse dans',
    ]) {
      expect(find.textContaining(private), findsNothing);
    }
    expect(
      find.text('Simuler la sélection du patient'),
      kDebugMode ? findsOneWidget : findsNothing,
    );
    expect(tester.takeException(), isNull);
    c.dispose();
  });
  testWidgets('debug patient-selection action renders the selected state', (
    tester,
  ) async {
    final c = DoctorUrgentController();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildOmniTheme(),
        home: Scaffold(body: DoctorUrgentScreen(controller: c)),
      ),
    );
    c.goOnline();
    c.showOffer();
    c.accept();
    await tester.pump();

    final action = find.text('Simuler la sélection du patient');
    expect(kDebugMode, isTrue);
    expect(action, findsOneWidget);
    await tester.tap(action);
    await tester.pumpAndSettle();

    expect(c.state, DoctorUrgentState.selected);
    expect(find.text('Amina Chaari'), findsOneWidget);
    expect(find.text('Proposition envoyée'), findsNothing);
    expect(tester.takeException(), isNull);
    c.dispose();
  });
  testWidgets(
    'primary request accept renders waiting state without an exception',
    (tester) async {
      final c = DoctorUrgentController();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildOmniTheme(),
          home: Scaffold(body: DoctorUrgentScreen(controller: c)),
        ),
      );
      c.goOnline();
      await tester.pump();
      await tester.tap(find.text('Accepter'));
      await tester.pumpAndSettle();
      expect(c.state, DoctorUrgentState.acceptedWaitingPatient);
      expect(find.text('Proposition envoyée'), findsOneWidget);
      expect(find.text('En attente du patient'), findsOneWidget);
      expect(find.textContaining('Amina'), findsNothing);
      expect(tester.takeException(), isNull);
      c.dispose();
    },
  );
  testWidgets(
    'primary accept, selection, and route render the authoritative state sequence',
    (tester) async {
      final c = DoctorUrgentController();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildOmniTheme(),
          home: Scaffold(body: DoctorUrgentScreen(controller: c)),
        ),
      );

      c.goOnline();
      await tester.pump();
      await tester.tap(find.text('Accepter'));
      await tester.pump(const Duration(milliseconds: 250));
      expect(c.state, DoctorUrgentState.acceptedWaitingPatient);
      expect(find.text('Proposition envoyée'), findsOneWidget);

      c.simulateSelection();
      await tester.pump(const Duration(milliseconds: 250));
      expect(c.state, DoctorUrgentState.selected);
      expect(find.text('Amina Chaari'), findsOneWidget);

      await tester.tap(find.text('Démarrer le trajet'));
      await tester.pump(const Duration(milliseconds: 250));
      expect(c.state, DoctorUrgentState.enRoute);
      expect(find.text('En route vers le patient'), findsOneWidget);
      expect(find.text('Proposition envoyée'), findsNothing);
      expect(tester.takeException(), isNull);
      c.dispose();
    },
  );
  testWidgets(
    'detail-sheet accept closes into waiting state without an exception',
    (tester) async {
      final c = DoctorUrgentController();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildOmniTheme(),
          home: Scaffold(body: DoctorUrgentScreen(controller: c)),
        ),
      );
      c.goOnline();
      await tester.pump();
      await tester.tap(find.text('Voir'));
      await tester.pumpAndSettle();
      final sheet = find.byType(BottomSheet);
      expect(sheet, findsOneWidget);
      final acceptButton = find.descendant(
        of: sheet,
        matching: find.widgetWithText(FilledButton, 'Accepter'),
      );
      await tester.scrollUntilVisible(
        acceptButton,
        160,
        scrollable: find.descendant(
          of: sheet,
          matching: find.byType(Scrollable),
        ),
      );
      await tester.tap(acceptButton);
      await tester.pumpAndSettle();
      expect(c.state, DoctorUrgentState.acceptedWaitingPatient);
      expect(find.text('Proposition envoyée'), findsOneWidget);
      expect(find.text('En attente du patient'), findsOneWidget);
      expect(tester.takeException(), isNull);
      c.dispose();
    },
  );
  testWidgets('selected state reveals the confirmed patient and starts route', (
    tester,
  ) async {
    final c = DoctorUrgentController();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildOmniTheme(),
        home: Scaffold(body: DoctorUrgentScreen(controller: c)),
      ),
    );
    c.goOnline();
    c.showOffer();
    c.accept();
    c.simulateSelection();
    await tester.pumpAndSettle();
    for (final label in [
      'PATIENT CONFIRMÉ',
      'Amina Chaari',
      '45 ans',
      'AC',
      'Douleur thoracique sévère',
      '15 Avenue Habib Bourguiba, Tunis',
      'Démarrer le trajet',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.textContaining('1,8 km'), findsOneWidget);
    expect(find.textContaining('ETA 6 min'), findsOneWidget);
    for (final label in [
      'Proposition envoyée',
      'En attente du patient',
      'Identité non disponible',
    ]) {
      expect(find.text(label), findsNothing);
    }
    await tester.tap(find.text('Démarrer le trajet'));
    await tester.pumpAndSettle();
    expect(c.state, DoctorUrgentState.enRoute);
    expect(tester.takeException(), isNull);
    c.dispose();
  });
  testWidgets('en route shows the static map journey and arrival action', (
    tester,
  ) async {
    final c = DoctorUrgentController();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildOmniTheme(),
        home: Scaffold(body: DoctorUrgentScreen(controller: c)),
      ),
    );
    c.goOnline();
    c.showOffer();
    c.accept();
    c.simulateSelection();
    c.startRoute();
    await tester.pump(const Duration(milliseconds: 250));

    for (final label in [
      'EN ROUTE',
      'En route vers le patient',
      'Amina Chaari · 45 ans',
      '15 Avenue Habib Bourguiba, Tunis',
      'Message',
      'Maps',
      'Motif de la visite',
      'Douleur thoracique sévère',
      'Difficulté à respirer',
      'Nausées',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.textContaining('1,8 km'), findsOneWidget);
    expect(find.textContaining('environ 6 min'), findsOneWidget);
    final arrived = find.text('Je suis arrivé');
    await tester.scrollUntilVisible(
      arrived,
      180,
      scrollable: find.byType(Scrollable),
    );
    expect(arrived, findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(arrived);
    await tester.pump();
    expect(c.state, DoctorUrgentState.arrived);
    expect(tester.takeException(), isNull);
    c.dispose();
  });
  testWidgets(
    'arrived QR action opens focused scanner and back preserves arrival',
    (tester) async {
      final c = DoctorUrgentController();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildOmniTheme(),
          home: Scaffold(body: DoctorUrgentScreen(controller: c)),
        ),
      );
      c.goOnline();
      c.showOffer();
      c.accept();
      c.simulateSelection();
      c.startRoute();
      c.arrive();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Scanner le QR du patient'));
      await tester.pumpAndSettle();
      expect(find.text('Scanner le QR'), findsOneWidget);
      expect(find.bySemanticsLabel('Zone de scan QR'), findsOneWidget);
      expect(
        find.text('Placez le QR du patient dans le cadre'),
        findsOneWidget,
      );
      expect(c.state, DoctorUrgentState.arrived);

      await tester.tap(find.byTooltip('Retour'));
      await tester.pumpAndSettle();
      expect(c.state, DoctorUrgentState.arrived);
      expect(find.text('Scanner le QR du patient'), findsOneWidget);
      expect(tester.takeException(), isNull);
      c.dispose();
    },
  );
  testWidgets('debug QR simulation verifies without exposing medical data', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildOmniTheme(),
        home: DoctorUrgentQrScannerScreen(request: DoctorUrgentRequest.demo),
      ),
    );
    expect(kDebugMode, isTrue);
    expect(find.text('Simuler un QR valide'), findsOneWidget);
    await tester.tap(find.text('Simuler un QR valide'));
    await tester.pump();
    expect(find.text('Vérification du QR...'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    for (final label in [
      'QR vérifié',
      'Accès médical autorisé pour cette consultation.',
      'Amina Chaari · 45 ans',
      'Accès temporaire',
      'Voir le dossier médical',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    for (final medicalData in [
      'Allergies',
      'Groupe sanguin',
      'Médicaments',
      'Diagnostic',
    ]) {
      expect(find.textContaining(medicalData), findsNothing);
    }
    await tester.tap(find.text('Voir le dossier médical'));
    await tester.pumpAndSettle();
    expect(find.text('Dossier médical'), findsOneWidget);
    expect(find.text('Amina Chaari · 45 ans'), findsOneWidget);
    expect(find.text('Informations essentielles'), findsOneWidget);
    await tester.tap(find.byTooltip('Retour'));
    await tester.pumpAndSettle();
    expect(find.text('QR vérifié'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('invalid QR fixture offers a retry without technical details', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildOmniTheme(),
        home: const DoctorUrgentQrScannerScreen(
          request: DoctorUrgentRequest.demo,
          initialState: DoctorUrgentQrScannerState.invalid,
        ),
      ),
    );
    expect(find.text('QR invalide ou expiré'), findsOneWidget);
    expect(
      find.text('Demandez au patient d’afficher un nouveau QR.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Zone de scan QR'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  test('controller permits only the D5 urgent lifecycle', () {
    final c = DoctorUrgentController();
    c.arrive();
    expect(c.state, DoctorUrgentState.offline);
    c.goOnline();
    c.showOffer();
    c.accept();
    c.simulateSelection();
    c.startRoute();
    c.arrive();
    expect(c.state, DoctorUrgentState.arrived);
  });
  test('controller traces accepted selection through en route', () {
    final c = DoctorUrgentController();
    final trace = <DoctorUrgentState>[];
    c.addListener(() => trace.add(c.state));

    c.goOnline();
    c.showOffer();
    c.accept();
    expect(c.state, DoctorUrgentState.acceptedWaitingPatient);
    c.simulateSelection();
    expect(c.state, DoctorUrgentState.selected);
    c.startRoute();
    expect(c.state, DoctorUrgentState.enRoute);

    expect(trace, [
      DoctorUrgentState.available,
      DoctorUrgentState.offerReceived,
      DoctorUrgentState.acceptedWaitingPatient,
      DoctorUrgentState.selected,
      DoctorUrgentState.enRoute,
    ]);
    c.dispose();
  });
  testWidgets('identity remains private until patient selection', (
    tester,
  ) async {
    final c = DoctorUrgentController();
    await tester.pumpWidget(
      MaterialApp(
        theme: buildOmniTheme(),
        home: Scaffold(body: DoctorUrgentScreen(controller: c)),
      ),
    );
    c.goOnline();
    c.showOffer();
    await tester.pump();
    expect(find.textContaining('Amina'), findsNothing);
    expect(find.textContaining('Avenue Habib'), findsNothing);
    c.accept();
    await tester.pump();
    expect(find.textContaining('Amina'), findsNothing);
    expect(find.textContaining('Avenue Habib'), findsNothing);
    c.simulateSelection();
    await tester.pump();
    expect(find.text('Amina Chaari'), findsOneWidget);
    expect(find.textContaining('Avenue Habib'), findsOneWidget);
  });
  test('decline and deterministic expiry return to available', () {
    final c = DoctorUrgentController();
    c.goOnline();
    c.showOffer();
    c.decline();
    expect(c.state, DoctorUrgentState.available);
    c.showOffer();
    c.expireOffer();
    expect(c.state, DoctorUrgentState.available);
    c.dispose();
  });
  test('countdown ticks deterministically and expires the offer', () {
    final c = DoctorUrgentController(offerDuration: const Duration(seconds: 2));
    c.goOnline();
    c.showOffer();
    expect(c.countdownLabel, '00:02');
    c.tick();
    expect(c.countdownLabel, '00:01');
    c.tick();
    expect(c.state, DoctorUrgentState.available);
    expect(c.remainingSeconds, 0);
    c.dispose();
  });
  testWidgets('urgent states fit supported phone dimensions', (tester) async {
    const sizes = [Size(360, 568), Size(390, 844), Size(430, 932)];
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final size in sizes) {
      tester.view.physicalSize = size;
      final c = DoctorUrgentController();
      await tester.pumpWidget(
        MaterialApp(
          theme: buildOmniTheme(),
          home: Scaffold(body: DoctorUrgentScreen(controller: c)),
        ),
      );
      c.goOnline();
      c.showOffer();
      await tester.pump();
      c.accept();
      await tester.pump();
      c.simulateSelection();
      await tester.pump();
      expect(find.text('Démarrer le trajet'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'selected at $size');
      c.startRoute();
      await tester.pump();
      expect(find.text('En route vers le patient'), findsOneWidget);
      expect(find.text('Je suis arrivé'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'en route at $size');
      c.arrive();
      await tester.pump();
      expect(find.text('Scanner le QR du patient'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: '$size');
      c.dispose();
    }
  });
  testWidgets('QR scanner fits supported phone dimensions', (tester) async {
    const sizes = [Size(360, 568), Size(390, 844), Size(430, 932)];
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final size in sizes) {
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        const MaterialApp(
          home: DoctorUrgentQrScannerScreen(
            request: DoctorUrgentRequest.demo,
            verificationDelay: Duration.zero,
          ),
        ),
      );
      final action = find.text('Simuler un QR valide');
      await tester.scrollUntilVisible(action, 160);
      expect(action, findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'ready at $size');
    }
  });
}
