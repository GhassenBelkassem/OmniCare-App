import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/features/home/patient_home_feed.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final jakarta = FontLoader('PlusJakartaSans')
      ..addFont(rootBundle.load('assets/fonts/PlusJakartaSans-Medium.ttf'))
      ..addFont(rootBundle.load('assets/fonts/PlusJakartaSans-SemiBold.ttf'))
      ..addFont(rootBundle.load('assets/fonts/PlusJakartaSans-Bold.ttf'))
      ..addFont(rootBundle.load('assets/fonts/PlusJakartaSans-ExtraBold.ttf'));
    final materialIcons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await Future.wait([jakarta.load(), materialIcons.load()]);
  });

  testWidgets('patient feed exposes the main sections and search overlay', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        routes: {
          '/provider-selection': (_) => const _RoutePlaceholder('Soins'),
          '/emergency-step0': (_) => const _RoutePlaceholder('Demande'),
          '/clinic-request': (_) => const _RoutePlaceholder('Clinique'),
          '/notifications': (_) => const _RoutePlaceholder('Notifications'),
        },
        home: const Scaffold(
          backgroundColor: Color(0xFFF4F6F7),
          body: SafeArea(child: PatientHomeFeed(displayName: 'Sarah Martin')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 350)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bonjour Sarah'), findsOneWidget);
    expect(find.text('Votre rendez-vous santé'), findsOneWidget);
    expect(
      find.text('30 minutes de marche font déjà la différence'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.smart_toy_outlined), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(PatientHomeFeed),
      matchesGoldenFile('goldens/patient_home_feed_top.png'),
    );

    await tester.tap(find.bySemanticsLabel('Rechercher dans OmniCare'));
    await tester.pumpAndSettle();

    expect(find.text('Que souhaitez-vous faire ?'), findsOneWidget);
    expect(
      find.text(
        'Recherche de navigation et d’assistance — aucun diagnostic médical.',
      ),
      findsOneWidget,
    );
    expect(find.text('Demander des soins'), findsOneWidget);
    expect(find.byIcon(Icons.smart_toy_outlined), findsNothing);
    await expectLater(
      find.byType(PatientHomeFeed),
      matchesGoldenFile('goldens/patient_home_search.png'),
    );

    await tester.enterText(find.byType(TextField), 'famille');
    await tester.pump();

    expect(find.text('Actions'), findsOneWidget);
    expect(find.text('Ajouter un membre de la famille'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byTooltip('Fermer la recherche'));
    await tester.pumpAndSettle();
    final verticalFeed = find.byType(Scrollable).first;

    await tester.scrollUntilVisible(
      find.text('Demander des soins'),
      520,
      scrollable: verticalFeed,
    );
    await tester.pumpAndSettle();
    expect(find.text('Kinésithérapeute'), findsOneWidget);
    await expectLater(
      find.byType(PatientHomeFeed),
      matchesGoldenFile('goldens/patient_home_care.png'),
    );

    await tester.scrollUntilVisible(
      find.text('Avancez plus vite vers votre OmniBand'),
      520,
      scrollable: verticalFeed,
    );
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(PatientHomeFeed),
      matchesGoldenFile('goldens/patient_home_referral.png'),
    );

    await tester.scrollUntilVisible(
      find.textContaining('Vos informations restent privées'),
      520,
      scrollable: verticalFeed,
    );
    await tester.pumpAndSettle();
    expect(find.text('Votre espace OmniCare'), findsOneWidget);
    expect(find.text('Français · العربية · English'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(PatientHomeFeed),
      matchesGoldenFile('goldens/patient_home_overview.png'),
    );
  });
}

class _RoutePlaceholder extends StatelessWidget {
  const _RoutePlaceholder(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text(label)));
  }
}
