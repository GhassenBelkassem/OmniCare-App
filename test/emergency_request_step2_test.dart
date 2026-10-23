import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/core/theme/omni_theme.dart';
import 'package:omnicare_mobile/features/emergency/emergency_request_step2.dart';
import 'package:omnicare_mobile/features/emergency/emergency_review_screen.dart';
import 'package:omnicare_mobile/features/emergency/widgets/body_map_widget.dart';
import 'package:omnicare_mobile/features/emergency/widgets/medical_intake_widgets.dart';

const _frontId = 'front-chest-pectoral-left';
const _backId = 'back-lumbar';
const _subject = {
  'patientId': 'family-1',
  'backendPatientId': 'patient-1',
  'patientName': 'Amira',
  'patientType': 'family',
  'providerType': 'doctor',
  'consultationType': 'home',
};
final _next = find.byKey(const ValueKey('emergency-continue'));
final _description = find.byKey(const ValueKey('emergency-description'));

Future<void> _pump(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double scale = 1,
  ValueChanged<Map<String, dynamic>>? onNext,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: buildOmniTheme(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: const Scaffold(body: EmergencyRequestStep2(step1Data: _subject)),
      onGenerateRoute: (settings) {
        expect(settings.name, '/emergency-step3');
        onNext?.call(settings.arguments! as Map<String, dynamic>);
        return MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => const Scaffold(body: Text('Step 3')),
        );
      },
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _show(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

Future<void> _select(WidgetTester tester, {bool back = false}) async {
  final view = find.byKey(
    ValueKey(back ? 'emergency-body-back' : 'emergency-body-front'),
  );
  await _show(tester, view);
  final rect = tester.getRect(view);
  await tester.tapAt(
    Offset(
      rect.left + rect.width * (back ? .5 : .42),
      rect.top + rect.height * (back ? .43 : .2),
    ),
  );
  await tester.pump();
}

Future<void> _describe(
  WidgetTester tester, [
  String value = 'Douleur depuis ce matin',
]) async {
  await _show(tester, _description);
  await tester.enterText(_description, value);
  await tester.pump();
}

Future<void> _suggest(WidgetTester tester) async {
  await _show(tester, find.text('Voir les suggestions'));
  await tester.tap(find.text('Voir les suggestions'));
  await tester.pump();
  expect(find.text('Préparation des exemples…'), findsOneWidget);
  await tester.pump(const Duration(milliseconds: 401));
}

bool _enabled(WidgetTester tester) =>
    tester.widget<ElevatedButton>(_next).onPressed != null;

void main() {
  group('Approved anatomy-first Step2', () {
    testWidgets('uses a white page surface without progress UI', (
      tester,
    ) async {
      await _pump(tester);
      final pageSurface = tester.widget<ColoredBox>(
        find.byKey(const ValueKey('emergency-step2-page-surface')),
      );
      expect(pageSurface.color, OmniColors.pageBackground);
      expect(pageSurface.color, Colors.white);
      expect(find.text('Patient'), findsNothing);
      expect(find.text('Symptôme'), findsNothing);
      expect(find.text('Localisation'), findsNothing);
      expect(find.text('Confirmation'), findsNothing);
      expect(find.text('Où avez-vous mal ?'), findsOneWidget);
      expect(
        find.text('Sélectionnez une ou plusieurs zones du corps.'),
        findsOneWidget,
      );
    });

    testWidgets(
      'both detailed maps exist in mobile order without a view switch',
      (tester) async {
        await _pump(tester);
        expect(find.text('Vue de Face'), findsOneWidget);
        expect(find.text('Vue de Dos'), findsOneWidget);
        expect(find.byType(MuscleAnatomyMap), findsNWidgets(2));
        expect(
          tester.getTopLeft(find.text('Vue de Face')).dy,
          lessThan(tester.getTopLeft(find.text('Vue de Dos')).dy),
        );
        expect(find.text('Face'), findsNothing);
        expect(find.text('Dos'), findsNothing);
        expect(find.text('Autres symptômes'), findsNothing);
        expect(find.byType(FilterChip), findsNothing);
      },
    );

    testWidgets('front and back selections coexist and chips precede anatomy', (
      tester,
    ) async {
      await _pump(tester);
      expect(find.byType(SelectedBodyAreasPanel), findsNothing);
      await _select(tester);
      await _select(tester, back: true);
      expect(find.byKey(const ValueKey('selected-$_frontId')), findsOneWidget);
      expect(find.byKey(const ValueKey('selected-$_backId')), findsOneWidget);
      expect(find.text('Poitrine gauche'), findsOneWidget);
      expect(find.text(_frontId), findsNothing);
      expect(
        tester.getTopLeft(find.byType(SelectedBodyAreasPanel)).dy,
        lessThan(tester.getTopLeft(find.text('Vue de Face')).dy),
      );
      for (final map in tester.widgetList<MuscleAnatomyMap>(
        find.byType(MuscleAnatomyMap),
      )) {
        expect(map.selectedParts, [_frontId, _backId]);
      }
    });

    testWidgets(
      'tapping selected anatomy deselects and hides the final panel',
      (tester) async {
        await _pump(tester);
        await _select(tester);
        await _select(tester);
        expect(find.byType(SelectedBodyAreasPanel), findsNothing);
      },
    );

    testWidgets('chip removal affects one region and reset clears both maps', (
      tester,
    ) async {
      await _pump(tester);
      await _select(tester);
      await _select(tester, back: true);
      await _show(tester, find.byKey(const ValueKey('selected-$_frontId')));
      await tester.tap(find.byTooltip('Retirer Poitrine gauche'));
      await tester.pump();
      expect(find.byKey(const ValueKey('selected-$_frontId')), findsNothing);
      expect(find.byKey(const ValueKey('selected-$_backId')), findsOneWidget);
      await _show(tester, find.text('Réinitialiser'));
      await tester.tap(find.text('Réinitialiser'));
      await tester.pump();
      expect(find.byType(SelectedBodyAreasPanel), findsNothing);
      for (final map in tester.widgetList<MuscleAnatomyMap>(
        find.byType(MuscleAnatomyMap),
      )) {
        expect(map.selectedParts, isEmpty);
      }
    });

    testWidgets('pain preserves 1–10 range and descriptive semantics', (
      tester,
    ) async {
      await _pump(tester);
      final slider = find.byType(Slider);
      await _show(tester, slider);
      var control = tester.widget<Slider>(slider);
      expect(control.min, 1);
      expect(control.max, 10);
      expect(control.divisions, 9);
      expect(control.value, 5);
      expect(control.semanticFormatterCallback!(1), '1 sur 10, Légère');
      expect(control.semanticFormatterCallback!(4), '4 sur 10, Modérée');
      expect(control.semanticFormatterCallback!(7), '7 sur 10, Sévère');
      await tester.tapAt(
        tester.getRect(slider).centerRight - const Offset(24, 0),
      );
      await tester.pump();
      control = tester.widget<Slider>(slider);
      expect(control.value, 10);
      expect(find.text('10 / 10'), findsOneWidget);
      expect(find.text('Sévère'), findsOneWidget);
    });

    testWidgets('text is functional and voice is explicitly unavailable', (
      tester,
    ) async {
      await _pump(tester);
      await _show(tester, find.text('Vocal · Bientôt'));
      final selector = tester.widget<SegmentedButton<String>>(
        find.byType(SegmentedButton<String>),
      );
      expect(selector.selected, {'text'});
      expect(selector.segments.first.enabled, isTrue);
      expect(selector.segments.last.enabled, isFalse);
      await tester.tap(find.text('Vocal · Bientôt'));
      await tester.pump();
      expect(find.byType(TextField), findsOneWidget);
      expect(find.textContaining('enregistré'), findsNothing);
      expect(find.text('Facultatif'), findsNothing);
    });

    testWidgets(
      'next requires both a region and a non-whitespace description',
      (tester) async {
        await _pump(tester);
        expect(_enabled(tester), isFalse);
        await _describe(tester);
        expect(_enabled(tester), isFalse);
        await _select(tester);
        expect(_enabled(tester), isTrue);
        await _describe(tester, ' \n  ');
        expect(_enabled(tester), isFalse);
        await _describe(tester, '');
        expect(_enabled(tester), isFalse);
        await _describe(tester, ' Douleur ');
        expect(_enabled(tester), isTrue);
        await _select(tester);
        expect(_enabled(tester), isFalse);
      },
    );

    testWidgets(
      'passport defaults off and confirms only local sharing intent',
      (tester) async {
        await _pump(tester);
        final toggle = find.byKey(const ValueKey('emergency-passport-toggle'));
        await _show(tester, toggle);
        expect(tester.widget<Switch>(toggle).value, isFalse);
        await tester.tap(toggle);
        await tester.pump();
        expect(tester.widget<Switch>(toggle).value, isTrue);
        expect(
          find.textContaining('Aucun accès n’est encore accordé'),
          findsOneWidget,
        );
        await tester.tap(toggle);
        await tester.pump();
        expect(
          find.textContaining('Aucun accès n’est encore accordé'),
          findsNothing,
        );
      },
    );

    testWidgets(
      'passport information explains scope without claiming an access grant',
      (tester) async {
        await _pump(tester);
        await _show(tester, find.text('Quelles informations ?'));
        await tester.tap(find.text('Quelles informations ?'));
        await tester.pumpAndSettle();
        expect(find.text(MedicalPassportToggle.explanation), findsOneWidget);
        expect(find.textContaining('n’ouvre aucun accès'), findsOneWidget);
        await tester.tap(find.text('Compris'));
        await tester.pumpAndSettle();
        expect(find.text(MedicalPassportToggle.explanation), findsNothing);
      },
    );

    testWidgets('demo idle, thinking and deterministic editable suggestions', (
      tester,
    ) async {
      await _pump(tester);
      expect(find.text('Démo'), findsOneWidget);
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Voir les suggestions'),
            )
            .onPressed,
        isNull,
      );
      await _select(tester);
      await _describe(tester);
      await _suggest(tester);
      expect(
        find.byKey(const ValueKey('demo-specialty-Cardiologue')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('demo-specialty-Généraliste')),
        findsOneWidget,
      );
      await _show(
        tester,
        find.byKey(const ValueKey('demo-specialty-Cardiologue')),
      );
      await tester.tap(find.byTooltip('Retirer Cardiologue'));
      await tester.pump();
      expect(
        find.byKey(const ValueKey('demo-specialty-Cardiologue')),
        findsNothing,
      );
      await _show(tester, find.text('Ajouter une spécialité'));
      await tester.tap(find.text('Ajouter une spécialité'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dermatologue'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('demo-specialty-Dermatologue')),
        findsOneWidget,
      );
    });

    testWidgets('skipping demo clears examples and leaves next enabled', (
      tester,
    ) async {
      await _pump(tester);
      await _select(tester);
      await _describe(tester);
      await _suggest(tester);
      await _show(tester, find.text('Ignorer les suggestions'));
      await tester.tap(find.text('Ignorer les suggestions'));
      await tester.pump();
      expect(find.textContaining('Suggestions ignorées'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('demo-specialty-Cardiologue')),
        findsNothing,
      );
      expect(_enabled(tester), isTrue);
    });

    testWidgets(
      'changing inputs invalidates demo results and cancels pending examples',
      (tester) async {
        await _pump(tester);
        await _select(tester);
        await _describe(tester);
        await _show(tester, find.text('Voir les suggestions'));
        await tester.tap(find.text('Voir les suggestions'));
        await tester.pump();
        tester.widget<TextField>(_description).controller!.text =
            'Autre description';
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        expect(find.text('Suggestions de démonstration'), findsNothing);
        expect(find.text('Voir les suggestions'), findsOneWidget);
        await _suggest(tester);
        await _describe(tester, 'Encore une modification');
        expect(find.text('Suggestions de démonstration'), findsNothing);
      },
    );

    testWidgets('sticky full-width Continue CTA exposes button semantics', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await _pump(tester);
      final size = tester.getSize(_next);
      expect(size.height, 50);
      expect(size.width, 350);
      expect(find.widgetWithText(ElevatedButton, 'Continuer'), findsOneWidget);
      expect(find.bySemanticsLabel('Continuer'), findsOneWidget);
      expect(tester.widget<ElevatedButton>(_next).onPressed, isNull);
      handle.dispose();
    });

    for (final demo in [false, true]) {
      testWidgets('valid payload is coherent and uses Step3 (demo=$demo)', (
        tester,
      ) async {
        Map<String, dynamic>? payload;
        await _pump(tester, onNext: (data) => payload = data);
        await _select(tester);
        await _select(tester, back: true);
        await _describe(tester, '  Douleur persistante  ');
        final slider = find.byType(Slider);
        tester.widget<Slider>(slider).onChanged!(8);
        await tester.pump();
        final toggle = find.byKey(const ValueKey('emergency-passport-toggle'));
        await _show(tester, toggle);
        await tester.tap(toggle);
        await tester.pump();
        if (demo) await _suggest(tester);
        await _show(tester, _next);
        await tester.tap(_next);
        await tester.pumpAndSettle();
        expect(find.text('Step 3'), findsOneWidget);
        expect(payload, {
          ..._subject,
          'bodyParts': [_frontId, _backId],
          'painLevel': 8,
          'description': 'Douleur persistante',
          'symptoms': 'Douleur persistante',
          'voiceMessage': null,
          'shareMedicalRecord': true,
        });
        // The real existing review accepts the Step2 string contract.
        await tester.pumpWidget(
          MaterialApp(
            theme: buildOmniTheme(),
            home: Scaffold(
              body: EmergencyReviewScreen(
                requestData: {
                  ...payload!,
                  'location': {'type': 'gps'},
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('passport and demo perform no HTTP calls or route changes', (
      tester,
    ) async {
      var networkCalls = 0;
      var routeCalls = 0;
      await HttpOverrides.runZoned(
        () async {
          await _pump(tester, onNext: (_) => routeCalls++);
          await _select(tester);
          await _describe(tester);
          final toggle = find.byKey(
            const ValueKey('emergency-passport-toggle'),
          );
          await _show(tester, toggle);
          await tester.tap(toggle);
          await tester.pump();
          await _suggest(tester);
          expect(networkCalls, 0);
          expect(routeCalls, 0);
        },
        createHttpClient: (_) {
          networkCalls++;
          throw StateError('Step2 must not perform network operations');
        },
      );
    });

    testWidgets('top Back returns to previous urgent screen', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildOmniTheme(),
          home: const Scaffold(body: Text('Patient')),
        ),
      );
      Navigator.of(tester.element(find.text('Patient'))).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              const Scaffold(body: EmergencyRequestStep2(step1Data: _subject)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Retour'));
      await tester.pumpAndSettle();
      expect(find.byType(EmergencyRequestStep2), findsNothing);
    });

    for (final scenario in [
      (320.0, 1.0),
      (320.0, 1.5),
      (390.0, 2.0),
      (1024.0, 1.0),
    ]) {
      testWidgets(
        'responsive width ${scenario.$1}, scale ${scenario.$2}, long French text',
        (tester) async {
          await _pump(tester, size: Size(scenario.$1, 900), scale: scenario.$2);
          final map = tester
              .widgetList<MuscleAnatomyMap>(find.byType(MuscleAnatomyMap))
              .first;
          map.onPartClick('back-shoulder-deltoid-right');
          map.onPartClick('front-thigh-quad-left');
          await tester.pump();
          await _describe(
            tester,
            List.filled(
              8,
              'Une douleur persistante au niveau de la poitrine depuis plusieurs jours.',
            ).join(' '),
          );
          await _show(tester, _next);
          expect(tester.takeException(), isNull);
          expect(find.byType(SingleChildScrollView), findsOneWidget);
          expect(tester.widget<TextField>(_description).maxLines, isNull);
          expect(
            tester.widget<TextField>(_description).scrollPhysics,
            isA<NeverScrollableScrollPhysics>(),
          );
          final front = tester.getRect(find.text('Vue de Face'));
          final back = tester.getRect(find.text('Vue de Dos'));
          if (scenario.$1 >= 1024) {
            expect(front.top, back.top);
            expect(front.left, lessThan(back.left));
          } else {
            expect(front.top, lessThan(back.top));
          }
        },
      );
    }

    testWidgets(
      'content stays above fixed shell bottom navigation and handles keyboard insets',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 844));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          MaterialApp(
            theme: buildOmniTheme(),
            home: Builder(
              builder: (context) => MediaQuery.removeViewInsets(
                context: context,
                removeBottom: true,
                child: const Scaffold(
                  resizeToAvoidBottomInset: false,
                  body: SafeArea(
                    child: Column(
                      children: [
                        SizedBox(height: 60, child: Text('Fixed top nav')),
                        Expanded(
                          child: EmergencyRequestStep2(step1Data: _subject),
                        ),
                      ],
                    ),
                  ),
                  bottomNavigationBar: SizedBox(
                    key: ValueKey('bottom-nav'),
                    height: 72,
                    child: Text('Fixed bottom nav'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await _show(tester, _next);
        expect(
          tester.getBottomRight(_next).dy,
          lessThanOrEqualTo(
            tester.getTopLeft(find.byKey(const ValueKey('bottom-nav'))).dy,
          ),
        );
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpAndSettle();
        final scroll = tester.widget<SingleChildScrollView>(
          find.byKey(const ValueKey('emergency-step2-scroll')),
        );
        expect(
          (scroll.padding! as EdgeInsets).bottom,
          greaterThan(OmniSpacing.xxl),
        );
        expect(tester.takeException(), isNull);
      },
    );
  });
}
