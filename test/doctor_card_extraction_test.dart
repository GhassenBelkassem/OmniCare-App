import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnicare_mobile/core/theme/omni_theme.dart';
import 'package:omnicare_mobile/features/patient_doctor/data/doctor_models.dart';
import 'package:omnicare_mobile/features/patient_doctor/presentation/widgets/doctor_card.dart';
import 'package:omnicare_mobile/features/patient_doctor/presentation/widgets/doctor_result_card.dart';

DoctorListItem _doctor({
  String name = 'Dr. Sarah Mansour',
  String specialty = 'Pediatre',
  int experienceYears = 10,
  String? address,
  double? distanceKm,
  String? imageAssetPath,
  bool acceptingNewPatients = true,
}) {
  return DoctorListItem(
    id: 'doctor-1',
    name: name,
    specialty: specialty,
    rating: 4.8,
    totalReviews: 100,
    officeConsultationFee: 80,
    experienceYears: experienceYears,
    isOnline: true,
    providerId: 'provider-1',
    address: address,
    distanceKm: distanceKm,
    imageAssetPath: imageAssetPath,
    acceptingNewPatients: acceptingNewPatients,
    languages: const ['Francais'],
  );
}

Widget _host(DoctorListItem doctor, {VoidCallback? onTap}) {
  return MaterialApp(
    theme: buildOmniTheme(),
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 380,
          child: DoctorListCard(doctor: doctor, onTap: onTap ?? () {}),
        ),
      ),
    ),
  );
}

void main() {
  group('DoctorListCard baseline characterization', () {
    testWidgets('renders name, specialty, and optional experience', (
      tester,
    ) async {
      await tester.pumpWidget(_host(_doctor()));

      expect(find.text('Dr. Sarah Mansour'), findsOneWidget);
      expect(find.text('Pediatre'), findsOneWidget);
      expect(find.text('10 years exp.'), findsOneWidget);

      await tester.pumpWidget(_host(_doctor(experienceYears: 0)));
      expect(find.textContaining('years exp.'), findsNothing);
    });

    testWidgets('preserves every address and distance combination', (
      tester,
    ) async {
      await tester.pumpWidget(
        _host(_doctor(address: '12 rue de Tunis', distanceKm: 2.45)),
      );
      expect(find.text('12 rue de Tunis · 2.5 km'), findsOneWidget);

      await tester.pumpWidget(_host(_doctor(address: '12 rue de Tunis')));
      expect(find.text('12 rue de Tunis'), findsOneWidget);

      await tester.pumpWidget(_host(_doctor(distanceKm: 2.45)));
      expect(find.text('2.5 km'), findsOneWidget);

      await tester.pumpWidget(_host(_doctor()));
      expect(find.byIcon(Icons.location_on_outlined), findsNothing);
    });

    testWidgets('uses the existing initials fallback', (tester) async {
      await tester.pumpWidget(
        _host(_doctor(name: 'Dr. Sarah Ben Mansour', imageAssetPath: null)),
      );

      expect(find.text('SM'), findsOneWidget);
      final avatar = tester.widget<SizedBox>(
        find.byWidgetPredicate(
          (widget) =>
              widget is SizedBox && widget.width == 72 && widget.height == 72,
        ),
      );
      expect(avatar.width, 72);
      expect(avatar.height, 72);
    });

    testWidgets('shows Complet only when new patients are not accepted', (
      tester,
    ) async {
      await tester.pumpWidget(_host(_doctor(acceptingNewPatients: false)));
      expect(find.text('Complet'), findsOneWidget);

      await tester.pumpWidget(_host(_doctor(acceptingNewPatients: true)));
      expect(find.text('Complet'), findsNothing);
    });

    testWidgets('invokes the tap callback exactly once', (tester) async {
      var taps = 0;
      await tester.pumpWidget(_host(_doctor(), onTap: () => taps += 1));

      await tester.tap(find.byType(DoctorListCard));

      expect(taps, 1);
    });

    testWidgets('exposes the existing button semantics label', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(_doctor(specialty: 'Cardiologue', distanceKm: 2.45)),
      );

      final semanticsWidget = tester.widget<Semantics>(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.label ==
                  'Dr. Sarah Mansour, Cardiologue, 2.45 km',
        ),
      );
      expect(semanticsWidget.properties.button, isTrue);
      expect(semanticsWidget.properties.enabled, isTrue);
      semantics.dispose();
    });

    testWidgets('preserves card padding, radius, border, and shadow', (
      tester,
    ) async {
      await tester.pumpWidget(_host(_doctor()));

      final gesture = find.descendant(
        of: find.byType(DoctorListCard),
        matching: find.byType(GestureDetector),
      );
      final cardContainerFinder = find
          .descendant(of: gesture, matching: find.byType(Container))
          .first;
      final cardContainer = tester.widget<Container>(cardContainerFinder);
      final decoration = cardContainer.decoration! as BoxDecoration;
      final border = decoration.border! as Border;

      expect(decoration.color, OmniColors.surfacePrimary);
      expect(decoration.borderRadius, BorderRadius.circular(OmniRadii.card));
      expect(border.top.color, OmniColors.borderLight);
      expect(decoration.boxShadow, const [OmniColors.shadowCard]);

      final padding = tester.widget<Padding>(
        find.byWidgetPredicate(
          (widget) =>
              widget is Padding && widget.padding == const EdgeInsets.all(14),
        ),
      );
      expect(padding.padding, const EdgeInsets.all(14));
    });
  });

  testWidgets('DoctorResultCard renders without providers or backend models', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildOmniTheme(),
        home: Scaffold(
          body: DoctorResultCard(
            data: const DoctorResultCardData(
              name: 'Dr. Shared Card',
              specialty: 'Medecine generale',
              experienceLabel: '8 years exp.',
              address: 'Cabinet du Lac',
              distanceKm: 1.2,
              status: DoctorResultCardStatus(label: 'Complet'),
            ),
            onTap: () => taps += 1,
          ),
        ),
      ),
    );

    expect(find.byType(DoctorResultCard), findsOneWidget);
    expect(find.text('Dr. Shared Card'), findsOneWidget);
    expect(find.text('Medecine generale'), findsOneWidget);
    expect(find.text('8 years exp.'), findsOneWidget);
    expect(find.text('Cabinet du Lac · 1.2 km'), findsOneWidget);
    expect(find.text('Complet'), findsOneWidget);
    expect(find.text('SC'), findsOneWidget);

    await tester.tap(find.byType(DoctorResultCard));
    expect(taps, 1);
  });
}
