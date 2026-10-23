import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/features/request/provider_selection_screen.dart';

void main() {
  testWidgets('care chooser exposes Clinic and uses the canonical M05 route', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: const Scaffold(body: ProviderSelectionScreen()),
        routes: {
          '/m05/request': (_) => const Scaffold(body: Text('Who needs care?')),
          '/clinic-request': (_) =>
              const Scaffold(body: Text('Service demandé')),
        },
      ),
    );

    expect(find.text('Médecin'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Infirmier'), 200);
    expect(find.text('Infirmier'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Kinésithérapeute'), 200);
    expect(find.text('Kinésithérapeute'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Clinique'), 200);
    expect(find.text('Clinique'), findsOneWidget);
    await tester.tap(find.text('Clinique'));
    await tester.pumpAndSettle();
    expect(find.text('Who needs care?'), findsOneWidget);
    expect(find.text('Service demandé'), findsNothing);
  });
}
