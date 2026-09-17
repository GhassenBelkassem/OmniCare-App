import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnicare_mobile/core/theme/omni_theme.dart';
import 'package:omnicare_mobile/features/emergency/doctor_matching.dart';
import 'package:omnicare_mobile/features/emergency/doctor_selection_screen.dart';

class _ManualMatchingSource implements DoctorMatchingSource {
  final _controller = StreamController<DoctorMatchingEvent>.broadcast();
  bool disposed = false;

  @override
  Stream<DoctorMatchingEvent> get events => _controller.stream;

  @override
  void start() {}

  void emit(DoctorMatchingEvent event) {
    if (!disposed) _controller.add(event);
  }

  @override
  void dispose() {
    disposed = true;
    _controller.close();
  }
}

Widget _buildScreen(_ManualMatchingSource source, {TextScaler? textScaler}) {
  return MaterialApp(
    home: Builder(
      builder: (context) {
        final screen = DoctorSelectionScreen(
          emergencyData: const {
            'patientType': 'me',
            'patientName': 'Aicha Ben Ali',
          },
          matchingSource: source,
        );
        if (textScaler == null) return screen;
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: screen,
        );
      },
    ),
    onGenerateRoute: (settings) => MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => const Scaffold(body: Text('Review confirm')),
    ),
  );
}

void main() {
  final doctors = createDemoUrgentDoctors();

  testWidgets('starts in searching state without an empty candidate message', (
    tester,
  ) async {
    final source = _ManualMatchingSource();
    addTearDown(source.dispose);
    await tester.pumpWidget(_buildScreen(source));

    final surface = tester.widget<ColoredBox>(
      find.byKey(const ValueKey('doctor-selection-page-surface')),
    );
    expect(surface.color, OmniColors.pageBackground);
    expect(find.text('Recherche de médecins disponibles…'), findsOneWidget);
    expect(
      find.text(
        'Votre demande a été transmise aux médecins pouvant intervenir dans votre zone.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('matching-radar-large')), findsOneWidget);
    expect(find.text('Recherche toujours active'), findsNothing);
    expect(find.textContaining('0 médecins'), findsNothing);
    expect(find.text('Choisir ce médecin'), findsNothing);
  });

  testWidgets('accepted doctor appears immediately and is selectable', (
    tester,
  ) async {
    final source = _ManualMatchingSource();
    addTearDown(source.dispose);
    await tester.pumpWidget(_buildScreen(source));

    source.emit(DoctorAccepted(doctors[0]));
    await tester.pump();

    expect(find.text('Un médecin est disponible'), findsOneWidget);
    expect(
      find.text(
        "Vous pouvez choisir maintenant ou attendre d'autres réponses.",
      ),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('matching-radar-large')), findsNothing);
    expect(
      find.byKey(const ValueKey('matching-radar-compact')),
      findsOneWidget,
    );
    expect(find.text('Recherche toujours active'), findsOneWidget);
    expect(find.text('Dr. Sami Ben Ali'), findsOneWidget);
    expect(find.text('Médecin généraliste'), findsOneWidget);
    final specialty = tester.widget<Text>(find.text('Médecin généraliste'));
    expect(specialty.style?.color, OmniColors.textSecondary);
    final title = tester.widget<Text>(find.text('Un médecin est disponible'));
    expect(title.textAlign, isNull);
    expect(find.text('Arrivée estimée'), findsOneWidget);
    expect(find.text('≈ 8 min'), findsOneWidget);
    expect(find.text('2,4 km'), findsOneWidget);
    expect(find.text('★ 4,8 (142 avis)'), findsOneWidget);
    expect(find.text('Disponible maintenant'), findsNothing);
    expect(find.byIcon(Icons.verified_rounded), findsOneWidget);
    expect(find.text('Choisir ce médecin'), findsOneWidget);
    final chooseButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Choisir ce médecin'),
    );
    expect(
      chooseButton.style?.backgroundColor?.resolve({}),
      OmniColors.primaryAction,
    );
    expect(find.text('Prêt à accepter votre demande'), findsNothing);
    expect(find.text('Confirmer'), findsNothing);
    expect(find.textContaining('100 TND'), findsNothing);
  });

  testWidgets('additional accepted doctors append and update the count', (
    tester,
  ) async {
    final source = _ManualMatchingSource();
    addTearDown(source.dispose);
    await tester.pumpWidget(_buildScreen(source));

    source.emit(DoctorAccepted(doctors[0]));
    await tester.pump();
    source.emit(DoctorAccepted(doctors[1]));
    await tester.pump();
    source.emit(DoctorAccepted(doctors[2]));
    await tester.pump();

    expect(find.text('3 médecins sont disponibles'), findsOneWidget);
    expect(
      find.text("D'autres médecins peuvent encore répondre."),
      findsOneWidget,
    );
    expect(find.text('Dr. Sami Ben Ali'), findsOneWidget);
    expect(find.text('Dr. Amira Mansouri'), findsOneWidget);
    expect(find.text('Dr. Youssef Gharbi'), findsOneWidget);
  });

  testWidgets(
    'selection preserves the selected doctor and prevents duplicates',
    (tester) async {
      final source = _ManualMatchingSource();
      addTearDown(source.dispose);
      final routes = <RouteSettings>[];
      await tester.pumpWidget(
        MaterialApp(
          home: DoctorSelectionScreen(
            emergencyData: const {'patientType': 'me'},
            matchingSource: source,
          ),
          onGenerateRoute: (settings) {
            routes.add(settings);
            return MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => const Scaffold(body: Text('Review confirm')),
            );
          },
        ),
      );
      source.emit(DoctorAccepted(doctors[0]));
      await tester.pump();

      final chooseButton = find.byType(FilledButton);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.ensureVisible(chooseButton);
      await tester.tap(chooseButton);
      await tester.tap(chooseButton);
      await tester.pump(const Duration(milliseconds: 220));
      await tester.pump(const Duration(milliseconds: 400));

      expect(routes, hasLength(1));
      expect(routes.single.name, '/review-confirm');
      final arguments = routes.single.arguments! as Map<String, dynamic>;
      expect(arguments['selectedDoctorId'], doctors[0].backendDoctorId);
      expect(arguments['doctor'], same(doctors[0]));
    },
  );

  testWidgets('does not overflow at the primary mobile viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final source = _ManualMatchingSource();
    addTearDown(source.dispose);
    await tester.pumpWidget(_buildScreen(source));
    source.emit(DoctorAccepted(doctors[0]));
    source.emit(DoctorAccepted(doctors[1]));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Dr. Sami Ben Ali'), findsOneWidget);
    expect(find.text('Dr. Amira Mansouri'), findsOneWidget);
    expect(
      tester.getBottomRight(find.text('Choisir ce médecin').first).dy,
      lessThanOrEqualTo(844),
    );
    expect(
      tester.getTopLeft(find.text('Dr. Amira Mansouri')).dy,
      lessThan(844),
    );
  });

  testWidgets('keeps candidates usable with large text', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final source = _ManualMatchingSource();
    addTearDown(source.dispose);
    await tester.pumpWidget(
      _buildScreen(source, textScaler: const TextScaler.linear(1.8)),
    );
    source.emit(DoctorAccepted(doctors[0]));
    await tester.pump();

    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.text('Choisir ce médecin'));
    expect(tester.takeException(), isNull);
  });

  test('controller ignores events after disposal', () async {
    final source = _ManualMatchingSource();
    final controller = DoctorMatchingController(source: source);
    controller.start();
    controller.dispose();

    source.emit(DoctorAccepted(doctors[0]));
    await Future<void>.delayed(Duration.zero);

    expect(source.disposed, isTrue);
  });
}
