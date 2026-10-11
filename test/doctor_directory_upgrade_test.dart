import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnicare_mobile/core/theme/omni_theme.dart';
import 'package:omnicare_mobile/features/patient_doctor/data/doctor_directory_models.dart';
import 'package:omnicare_mobile/features/patient_doctor/data/doctor_models.dart';
import 'package:omnicare_mobile/features/patient_doctor/presentation/doctor_filter_model.dart';
import 'package:omnicare_mobile/features/patient_doctor/presentation/widgets/doctor_card.dart';

DoctorListItem _doctor({
  String? photoUrl,
  String? specialty = 'Cardiologie',
  DoctorMatchingPracticeLocation? matchingPracticeLocation,
}) {
  return DoctorListItem(
    id: 'doctor-real-id',
    name: 'Dr. Sarah Mansour',
    specialty: specialty,
    photoUrl: photoUrl,
    experienceYears: 12,
    consultationPriceTnd: 80,
    verified: true,
    acceptingNewPatients: true,
    careCapabilities: const [
      DoctorCareCapability.cabinet,
      DoctorCareCapability.homeVisit,
    ],
    distanceKm: 2.4,
    matchingPracticeLocation: matchingPracticeLocation,
  );
}

Widget _card(DoctorListItem doctor, {VoidCallback? onTap}) {
  return MaterialApp(
    theme: buildOmniTheme(),
    home: Scaffold(
      body: DoctorListCard(doctor: doctor, onTap: onTap ?? () {}),
    ),
  );
}

void main() {
  group('Doctor card', () {
    testWidgets('renders backend identity, specialty, price and capabilities', (
      tester,
    ) async {
      await tester.pumpWidget(_card(_doctor()));

      expect(find.text('Dr. Sarah Mansour'), findsOneWidget);
      expect(find.text('Cardiologie'), findsOneWidget);
      expect(find.text('80 TND'), findsOneWidget);
      expect(find.text('Consultation au cabinet'), findsOneWidget);
      expect(find.text('Visite à domicile'), findsOneWidget);
    });

    testWidgets('renders matching Cabinet without exposing its identifier', (
      tester,
    ) async {
      await tester.pumpWidget(
        _card(
          _doctor(
            matchingPracticeLocation: const DoctorMatchingPracticeLocation(
              practiceLocationId: 'private-cabinet-uuid',
              name: 'Cabinet La Marsa',
              city: 'La Marsa',
              governorate: 'Tunis',
              distanceKm: 2.4,
            ),
          ),
        ),
      );

      expect(find.text('Cabinet La Marsa'), findsOneWidget);
      expect(find.text('La Marsa, Tunis · 2.4 km'), findsOneWidget);
      expect(find.textContaining('private-cabinet-uuid'), findsNothing);
    });

    testWidgets('uses backend photo URL and initials fallback when absent', (
      tester,
    ) async {
      await tester.pumpWidget(
        _card(_doctor(photoUrl: 'https://images.example.test/doctor.jpg')),
      );
      expect(
        find.byKey(const ValueKey('doctor-network-photo')),
        findsOneWidget,
      );

      await tester.pumpWidget(_card(_doctor(photoUrl: null)));
      expect(
        find.byKey(const ValueKey('doctor-photo-fallback')),
        findsOneWidget,
      );
      expect(find.text('SM'), findsOneWidget);
    });

    testWidgets(
      'handles a missing specialty without inventing general medicine',
      (tester) async {
        await tester.pumpWidget(_card(_doctor(specialty: null)));
        expect(find.text('Spécialité non renseignée'), findsOneWidget);
        expect(find.text('Médecin généraliste'), findsNothing);
      },
    );

    testWidgets('contains no rating, reviews, or online status', (
      tester,
    ) async {
      await tester.pumpWidget(_card(_doctor()));
      expect(find.text('4.8'), findsNothing);
      expect(find.textContaining('avis'), findsNothing);
      expect(find.textContaining('En ligne'), findsNothing);
      expect(find.textContaining('Disponible maintenant'), findsNothing);
    });

    testWidgets('tap delegates navigation with the real card identity', (
      tester,
    ) async {
      String? selectedId;
      final doctor = _doctor();
      await tester.pumpWidget(
        _card(doctor, onTap: () => selectedId = doctor.id),
      );
      await tester.tap(find.byType(DoctorListCard));
      expect(selectedId, 'doctor-real-id');
    });
  });

  group('Backend filter snapshot', () {
    test('counts only supported backend filter groups', () {
      final filters = DoctorFilterSnapshot.none.copyWith(
        specialty: 'Cardiologie',
        governorate: 'Tunis',
        city: 'La Marsa',
        maxDistanceKm: 10,
        careCapability: DoctorCareCapability.homeVisit,
        cnamAccepted: true,
        privateInsuranceAccepted: true,
        acceptingNewPatients: true,
      );
      expect(filters.activeGroupCount, 8);
    });

    test('clear operations restore an inactive snapshot', () {
      final filters = DoctorFilterSnapshot.none
          .copyWith(
            specialty: 'Cardiologie',
            governorate: 'Tunis',
            city: 'La Marsa',
            maxDistanceKm: 10,
            careCapability: DoctorCareCapability.cabinet,
          )
          .copyWith(
            clearSpecialty: true,
            clearGovernorate: true,
            clearCity: true,
            clearMaxDistanceKm: true,
            clearCareCapability: true,
          );
      expect(filters, DoctorFilterSnapshot.none);
      expect(filters.isActive, isFalse);
    });
  });
}
