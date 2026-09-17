import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/core/theme/omni_theme.dart';
import 'package:omnicare_mobile/features/emergency/widgets/body_map_widget.dart';
import 'package:omnicare_mobile/features/emergency/widgets/specialty_assistant_card.dart';

void main() {
  test(
    'stable region IDs retain complete labels and distinct presentation',
    () {
      expect(muscleParts.length, 54);
      expect(bodyAreaLabel('front-chest-pectoral-left'), 'Poitrine gauche');
      expect(
        bodyAreaLabel('back-hand-left'),
        isNot(bodyAreaLabel('front-hand-left')),
      );
      expect(bodyAreaLabel('unknown-id'), 'Zone sélectionnée');
    },
  );

  testWidgets('both maps preserve 29 front and 26 rear accessible tap zones', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.binding.setSurfaceSize(const Size(800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final tapped = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        theme: buildOmniTheme(),
        home: Scaffold(
          body: Row(
            children: [
              Expanded(
                child: MuscleAnatomyMap(
                  selectedParts: const ['back-lumbar'],
                  onPartClick: tapped.add,
                ),
              ),
              Expanded(
                child: MuscleAnatomyMap(
                  isFront: false,
                  selectedParts: const ['back-lumbar'],
                  onPartClick: tapped.add,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final frontZones = find.byWidgetPredicate(
      (w) => w is Semantics && w.key.toString().contains('front-zone-'),
    );
    final backZones = find.byWidgetPredicate(
      (w) => w is Semantics && w.key.toString().contains('back-zone-'),
    );
    expect(frontZones, findsNWidgets(29));
    expect(backZones, findsNWidgets(26));
    final node = tester.getSemantics(
      find.byKey(const ValueKey('back-zone-back-lumbar')),
    );
    expect(node.flagsCollection.isSelected, ui.Tristate.isTrue);
    tester
        .renderObject(find.byKey(const ValueKey('back-zone-back-lumbar')))
        .owner!
        .semanticsOwner!
        .performAction(node.id, SemanticsAction.tap);
    expect(tapped, ['back-lumbar']);
    for (final key in ['emergency-body-front', 'emergency-body-back']) {
      final size = tester.getSize(find.byKey(ValueKey(key)));
      expect(size.width / size.height, closeTo(300 / 650, .0001));
      expect(size.width, greaterThan(220));
    }
    semantics.dispose();
  });

  testWidgets(
    'selection paints immediately even if a caller mutates the same list',
    (tester) async {
      final selected = <String>[];
      late StateSetter update;
      final boundaryKey = GlobalKey();
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: buildOmniTheme(),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return RepaintBoundary(
                  key: boundaryKey,
                  child: MuscleAnatomyMap(
                    selectedParts: selected,
                    onPartClick: (id) => setState(() => selected.add(id)),
                  ),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final paintFinder = find.byKey(const ValueKey('front-highlights'));
      final previous = tester.widget<CustomPaint>(paintFinder).painter!;
      final boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      Future<List<int>> pixels() async {
        final image = await boundary.toImage();
        final bytes = await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        image.dispose();
        return bytes!.buffer.asUint8List().toList();
      }

      final before = await tester.runAsync(pixels);
      update(() => selected.add('front-chest-pectoral-left'));
      await tester.pump();
      final next = tester.widget<CustomPaint>(paintFinder).painter!;
      expect(next.shouldRepaint(previous), isTrue);
      final after = await tester.runAsync(pixels);
      expect(after, isNot(equals(before)));
      update(() {});
      await tester.pump();
      expect(
        tester.widget<CustomPaint>(paintFinder).painter!.shouldRepaint(next),
        isFalse,
      );
      update(selected.clear);
      await tester.pump();
      expect(await tester.runAsync(pixels), equals(before));
    },
  );

  testWidgets('taps outside anatomy do not select arbitrary regions', (
    tester,
  ) async {
    final selected = <String>[];
    await tester.binding.setSurfaceSize(const Size(390, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: buildOmniTheme(),
        home: Scaffold(
          body: MuscleAnatomyMap(
            selectedParts: const [],
            onPartClick: selected.add,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final rect = tester.getRect(
      find.byKey(const ValueKey('emergency-body-front')),
    );
    await tester.tapAt(rect.topLeft + const Offset(4, 4));
    expect(selected, isEmpty);
  });

  test(
    'demo requires input and returns deterministic known labels without scores',
    () {
      expect(DemoSpecialtySuggestionEngine.suggest([], 'douleur'), isEmpty);
      expect(
        DemoSpecialtySuggestionEngine.suggest(['front-head'], '  '),
        isEmpty,
      );
      final areas = ['front-chest-pectoral-left', 'back-lumbar'];
      expect(DemoSpecialtySuggestionEngine.suggest(areas, 'Douleur'), [
        'Cardiologue',
        'Orthopédiste',
        'Généraliste',
      ]);
      expect(
        DemoSpecialtySuggestionEngine.suggest(['front-hand-left'], 'La peau'),
        ['Dermatologue', 'Généraliste'],
      );
      expect(
        DemoSpecialtySuggestionEngine.suggest(areas, 'Douleur'),
        everyElement(isIn(DemoSpecialtySuggestionEngine.vocabulary)),
      );
    },
  );
}
