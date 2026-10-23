import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/core/theme/omni_theme.dart';
import 'package:omnicare_mobile/features/patient_passport/presentation/patient_passport_screen.dart';

void main() {
  Widget buildTestApp() {
    return MaterialApp(
      theme: buildOmniTheme(),
      home: const Scaffold(body: PatientPassportScreen()),
    );
  }

  testWidgets('switches passport sections and medication groups', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(buildTestApp());

    expect(find.text('Identité du passeport'), findsOneWidget);
    expect(find.text('Metformine'), findsOneWidget);

    final previousMedicines = find.text('Anciens');
    await tester.scrollUntilVisible(previousMedicines, 160);
    await tester.tap(previousMedicines);
    await tester.pumpAndSettle();
    expect(find.text('Amoxicilline'), findsOneWidget);
    expect(find.text('Metformine'), findsNothing);

    final history = find.text('Historique');
    await tester.scrollUntilVisible(history, -160);
    await tester.tap(history);
    await tester.pumpAndSettle();
    expect(find.text('Historique des consultations'), findsOneWidget);
    expect(find.text('3 consultations'), findsOneWidget);
  });

  testWidgets('opens family selector and updates selected passport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(buildTestApp());

    await tester.tap(find.text('Sarah Ben Ahmed').first);
    await tester.pumpAndSettle();
    expect(find.text('Passeports de la famille'), findsOneWidget);

    await tester.tap(find.text('Mohamed Ben Ahmed'));
    await tester.pumpAndSettle();
    expect(find.text('Mohamed Ben Ahmed'), findsNWidgets(2));

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Modifier les Données de Mohamed'), findsOneWidget);
  });

  testWidgets('opens the static medical data editor from the pencil action', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(buildTestApp());

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();

    expect(find.text('Modifier les Données de Sarah'), findsOneWidget);
    expect(find.text('Groupe Sanguin *'), findsOneWidget);
    expect(find.text('Taille, Poids & IMC'), findsOneWidget);
    expect(find.text('Conditions Chroniques'), findsOneWidget);
    expect(find.text('Médicaments Actuels'), findsOneWidget);
    expect(find.text('Enregistrer les Modifications'), findsOneWidget);

    await tester.tap(find.byTooltip('Fermer sans enregistrer'));
    await tester.pumpAndSettle();
    expect(find.text('Identité du passeport'), findsOneWidget);
  });
}
