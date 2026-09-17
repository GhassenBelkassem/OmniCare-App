import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnicare_mobile/core/theme/omni_theme.dart';
import 'package:omnicare_mobile/features/patient_doctor/data/doctor_models.dart';
import 'package:omnicare_mobile/features/patient_doctor/presentation/doctor_filter_model.dart';
import 'package:omnicare_mobile/features/patient_doctor/presentation/widgets/doctor_card.dart';

Widget _buildCard(DoctorListItem doctor) {
  return MaterialApp(
    theme: buildOmniTheme(),
    home: Scaffold(
      body: DoctorListCard(doctor: doctor, onTap: () {}),
    ),
  );
}

DoctorListItem _makeDoctor({
  String? imageAssetPath,
  String name = 'Dr. Test Doctor',
  String specialty = 'Cardiologue',
}) {
  return DoctorListItem(
    id: 'test-1',
    name: name,
    specialty: specialty,
    rating: 4.8,
    totalReviews: 100,
    officeConsultationFee: 3000.0,
    experienceYears: 10,
    isOnline: true,
    providerId: 'prov-test',
    imageAssetPath: imageAssetPath,
    acceptingNewPatients: true,
    languages: const ['Français'],
  );
}

void main() {
  group('Doctor card — no price rendered', () {
    testWidgets('does not display consultation fee text', (tester) async {
      final doctor = _makeDoctor();
      await tester.pumpWidget(_buildCard(doctor));

      expect(find.text('3000 DA'), findsNothing);
      expect(find.textContaining('DA'), findsNothing);
    });
  });

  group('Doctor card — overflow fix', () {
    testWidgets('card renders without overflow', (tester) async {
      final doctor = _makeDoctor();
      await tester.pumpWidget(_buildCard(doctor));

      // If there's a RenderFlex overflow, Flutter throws during the build.
      expect(tester.takeException(), isNull);
      expect(find.byType(DoctorListCard), findsOneWidget);
    });
  });

  group('Doctor card — image fallback', () {
    testWidgets('shows initials when imageAssetPath is null', (tester) async {
      final doctor = _makeDoctor(imageAssetPath: null);
      await tester.pumpWidget(_buildCard(doctor));

      expect(find.text('TD'), findsOneWidget);
    });

    testWidgets('shows initials when imageAssetPath is empty', (tester) async {
      final doctor = _makeDoctor(imageAssetPath: '');
      await tester.pumpWidget(_buildCard(doctor));

      expect(find.text('TD'), findsOneWidget);
    });

    testWidgets('shows initials when imageAssetPath is whitespace', (
      tester,
    ) async {
      final doctor = _makeDoctor(imageAssetPath: '   ');
      await tester.pumpWidget(_buildCard(doctor));

      expect(find.text('TD'), findsOneWidget);
    });
  });

  group('Doctor card — basic content', () {
    testWidgets('renders doctor name and specialty', (tester) async {
      final doctor = _makeDoctor(
        name: 'Dr. Sarah Mansour',
        specialty: 'Pédiatre',
      );
      await tester.pumpWidget(_buildCard(doctor));

      expect(find.text('Dr. Sarah Mansour'), findsOneWidget);
      expect(find.text('Pédiatre'), findsOneWidget);
    });

    testWidgets('does not render rating or review count', (tester) async {
      final doctor = _makeDoctor();
      await tester.pumpWidget(_buildCard(doctor));

      expect(find.text('4.8'), findsNothing);
      expect(find.text('(100)'), findsNothing);
    });

    testWidgets('does not render online status', (tester) async {
      final doctor = _makeDoctor();
      await tester.pumpWidget(_buildCard(doctor));

      expect(find.text('En ligne'), findsNothing);
      expect(find.text('Hors ligne'), findsNothing);
    });
  });

  group('Filter model — DoctorFilterSnapshot', () {
    test('none has zero active groups', () {
      expect(DoctorFilterSnapshot.none.isActive, isFalse);
      expect(DoctorFilterSnapshot.none.activeGroupCount, 0);
    });

    test('adding specialties increments active count', () {
      final snap = DoctorFilterSnapshot.none.copyWith(
        specialties: {'Cardiologue'},
      );
      expect(snap.activeGroupCount, 1);
      expect(snap.isActive, isTrue);
    });

    test('adding distance increments active count', () {
      final snap = DoctorFilterSnapshot.none.copyWith(distance: '5 km');
      expect(snap.activeGroupCount, 1);
    });

    test('clearing distance resets', () {
      final snap = DoctorFilterSnapshot.none
          .copyWith(distance: '5 km')
          .copyWith(clearDistance: true);
      expect(snap.distance, isNull);
      expect(snap.activeGroupCount, 0);
    });

    test('multiple filters sum correctly', () {
      final snap = DoctorFilterSnapshot.none.copyWith(
        specialties: {'Cardiologue'},
        distance: '10 km',
        gender: 'Femme',
        acceptingNewPatients: true,
      );
      expect(snap.activeGroupCount, 4);
    });

    test('sort order counts as active', () {
      final snap = DoctorFilterSnapshot.none.copyWith(
        sortOrder: DoctorSortOrder.ratingDesc,
      );
      expect(snap.activeGroupCount, 1);
    });
  });

  group('Filter model — applyDoctorFilters', () {
    test('filters by specialty', () {
      final doctors = [
        _makeDoctor(specialty: 'Cardiologue'),
        _makeDoctor(name: 'Dr. Other', specialty: 'Pédiatre'),
      ];

      final filters = DoctorFilterSnapshot.none.copyWith(
        specialties: {'Cardiologue'},
      );

      final result = applyDoctorFilters(items: doctors, filters: filters);
      expect(result.length, 1);
      expect(result.first.specialty, 'Cardiologue');
    });

    test('filters by accepting new patients', () {
      final doctors = [
        _makeDoctor(),
        _makeDoctor(name: 'Dr. Full').copyWith(acceptingNewPatients: false),
      ];

      final filters = DoctorFilterSnapshot.none.copyWith(
        acceptingNewPatients: true,
      );

      final result = applyDoctorFilters(items: doctors, filters: filters);
      expect(result.length, 1);
      expect(result.first.acceptingNewPatients, isTrue);
    });

    test('filters by gender', () {
      final doctors = [
        _makeDoctor(name: 'Dr. Femme').copyWith(gender: 'Femme'),
        _makeDoctor(name: 'Dr. Homme').copyWith(gender: 'Homme'),
      ];

      final filters = DoctorFilterSnapshot.none.copyWith(gender: 'Femme');
      final result = applyDoctorFilters(items: doctors, filters: filters);
      expect(result.length, 1);
      expect(result.first.gender, 'Femme');
    });

    test('no filter returns all', () {
      final doctors = [_makeDoctor(), _makeDoctor(name: 'Dr. B')];
      final result = applyDoctorFilters(
        items: doctors,
        filters: DoctorFilterSnapshot.none,
      );
      expect(result.length, 2);
    });
  });
}

/// Extension to create a copy with specific fields for test purposes.
extension _DoctorCopy on DoctorListItem {
  DoctorListItem copyWith({bool? acceptingNewPatients, String? gender}) {
    return DoctorListItem(
      id: id,
      name: name,
      specialty: specialty,
      rating: rating,
      totalReviews: totalReviews,
      officeConsultationFee: officeConsultationFee,
      experienceYears: experienceYears,
      isOnline: isOnline,
      providerId: providerId,
      address: address,
      phoneNumber: phoneNumber,
      latitude: latitude,
      longitude: longitude,
      imageAssetPath: imageAssetPath,
      subSpecialties: subSpecialties,
      distanceKm: distanceKm,
      acceptingNewPatients: acceptingNewPatients ?? this.acceptingNewPatients,
      patientAgeGroup: patientAgeGroup,
      consultationTypes: consultationTypes,
      gender: gender ?? this.gender,
      languages: languages,
      visitReasons: visitReasons,
      insuranceAccepted: insuranceAccepted,
      practiceLocationType: practiceLocationType,
      timeOfDay: timeOfDay,
      availableSaturday: availableSaturday,
      homeVisitAvailable: homeVisitAvailable,
      dutyService: dutyService,
    );
  }
}
