import 'package:flutter_test/flutter_test.dart';

import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_doctor_filter.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_doctor_list_item.dart';

UrgentCabinetDoctorListItem _doctor({
  required String id,
  required String name,
  required String specialty,
  required String governorate,
  required String city,
  double? distanceKm,
  UrgentCabinetEligibility eligibility = UrgentCabinetEligibility.eligible,
  UrgentCabinetAvailability availability =
      UrgentCabinetAvailability.availableNow,
}) {
  return UrgentCabinetDoctorListItem(
    doctorId: id,
    displayName: name,
    specialty: specialty,
    eligibility: eligibility,
    availability: availability,
    activeCabinetId: 'cabinet-$id',
    cabinetName: 'Cabinet $name',
    cabinetLocality: '$city, $governorate',
    cabinetGovernorate: governorate,
    cabinetCity: city,
    cabinetAddress: 'Adresse $id',
    distanceKm: distanceKm,
  );
}

final _doctors = <UrgentCabinetDoctorListItem>[
  _doctor(
    id: 'b',
    name: 'Dr. Béchir',
    specialty: 'Médecine générale',
    governorate: 'Tunis',
    city: 'Tunis',
    distanceKm: 5,
  ),
  _doctor(
    id: 'a',
    name: 'Dr. Amira',
    specialty: 'Médecine interne',
    governorate: 'Ariana',
    city: 'Ariana',
    distanceKm: 5,
  ),
  _doctor(
    id: 'c',
    name: 'Dr. Chahinez',
    specialty: 'Pédiatrie',
    governorate: 'Tunis',
    city: 'La Marsa',
    distanceKm: 10,
  ),
  _doctor(
    id: 'z',
    name: 'Dr. Zied',
    specialty: 'Médecine générale',
    governorate: 'Tunis',
    city: 'Tunis',
  ),
  _doctor(
    id: 'hidden',
    name: 'Dr. Indisponible',
    specialty: 'Pédiatrie',
    governorate: 'Sousse',
    city: 'Sousse',
    distanceKm: 1,
    availability: UrgentCabinetAvailability.unavailable,
  ),
];

List<UrgentCabinetDoctorListItem> _apply(
  UrgentCabinetDoctorFilterSnapshot filters, {
  String query = '',
}) {
  return filterAndSortUrgentCabinetDoctors(
    doctors: _doctors,
    query: query,
    filters: filters,
  );
}

void main() {
  group('UrgentCabinetDoctorFilterSnapshot', () {
    test('defaults and sorting do not count as active filters', () {
      expect(UrgentCabinetDoctorFilterSnapshot.none.activeGroupCount, 0);
      expect(UrgentCabinetDoctorFilterSnapshot.none.isActive, isFalse);
      final sorted = UrgentCabinetDoctorFilterSnapshot.none.copyWith(
        sortOrder: UrgentCabinetSortOrder.nameAscending,
      );
      expect(sorted.activeGroupCount, 0);
    });

    test('counts active categories, not selected specialty values', () {
      final filters = UrgentCabinetDoctorFilterSnapshot(
        specialties: {'Médecine générale', 'Médecine interne'},
        maximumDistanceKm: 10,
        governorate: 'Tunis',
        city: 'Tunis',
      );
      expect(filters.activeGroupCount, 4);
    });

    test('owns an immutable specialty set and has value semantics', () {
      final input = <String>{'Médecine générale'};
      final filters = UrgentCabinetDoctorFilterSnapshot(specialties: input);
      input.add('Pédiatrie');
      expect(filters.specialties, {'Médecine générale'});
      expect(
        () => filters.specialties.add('Pédiatrie'),
        throwsUnsupportedError,
      );
      expect(
        filters,
        UrgentCabinetDoctorFilterSnapshot(specialties: {'Médecine générale'}),
      );
    });
  });

  group('urgent CABINET filtering', () {
    test('specialties use OR matching and can be cleared', () {
      final filtered = _apply(
        UrgentCabinetDoctorFilterSnapshot(
          specialties: {'Médecine générale', 'Médecine interne'},
        ),
      );
      expect(filtered.map((doctor) => doctor.doctorId), ['a', 'b', 'z']);

      final cleared = _apply(UrgentCabinetDoctorFilterSnapshot.none);
      expect(cleared, hasLength(4));
    });

    test('distance is inclusive and excludes unknown values when active', () {
      final atFive = _apply(
        UrgentCabinetDoctorFilterSnapshot(maximumDistanceKm: 5),
      );
      expect(atFive.map((doctor) => doctor.doctorId), ['a', 'b']);

      final atTen = _apply(
        UrgentCabinetDoctorFilterSnapshot(maximumDistanceKm: 10),
      );
      expect(atTen.map((doctor) => doctor.doctorId), ['a', 'b', 'c']);
      expect(atTen.any((doctor) => doctor.doctorId == 'z'), isFalse);
    });

    test('unknown distance remains visible without a distance filter', () {
      expect(_apply(UrgentCabinetDoctorFilterSnapshot.none).last.doctorId, 'z');
    });

    test('governorate and city use typed exact values', () {
      final tunis = _apply(
        UrgentCabinetDoctorFilterSnapshot(governorate: 'Tunis'),
      );
      expect(tunis.map((doctor) => doctor.doctorId), ['b', 'c', 'z']);

      final laMarsa = _apply(
        UrgentCabinetDoctorFilterSnapshot(
          governorate: 'Tunis',
          city: 'La Marsa',
        ),
      );
      expect(laMarsa.single.doctorId, 'c');
    });

    test('eligibility policy runs before all presentation filters', () {
      final results = _apply(
        UrgentCabinetDoctorFilterSnapshot(
          governorate: 'Sousse',
          maximumDistanceKm: 5,
        ),
      );
      expect(results, isEmpty);
    });

    test('search, filters, and sorting compose without mutating source', () {
      final originalOrder = _doctors.map((doctor) => doctor.doctorId).toList();
      final results = _apply(
        UrgentCabinetDoctorFilterSnapshot(
          specialties: {'Médecine générale'},
          governorate: 'Tunis',
          sortOrder: UrgentCabinetSortOrder.nameAscending,
        ),
        query: 'cabinet dr',
      );
      expect(results.map((doctor) => doctor.doctorId), ['b', 'z']);
      expect(_doctors.map((doctor) => doctor.doctorId), originalOrder);
    });
  });

  group('urgent CABINET sorting and options', () {
    test('nearest uses known distance, normalized name, then doctor ID', () {
      final results = _apply(UrgentCabinetDoctorFilterSnapshot.none);
      expect(results.map((doctor) => doctor.doctorId), ['a', 'b', 'c', 'z']);

      final sameName = [
        _doctor(
          id: 'b',
          name: 'Dr. Même',
          specialty: 'Médecine générale',
          governorate: 'Tunis',
          city: 'Tunis',
          distanceKm: 2,
        ),
        _doctor(
          id: 'a',
          name: 'Dr. Même',
          specialty: 'Médecine générale',
          governorate: 'Tunis',
          city: 'Tunis',
          distanceKm: 2,
        ),
      ];
      final stable = filterAndSortUrgentCabinetDoctors(
        doctors: sameName,
        query: '',
        filters: UrgentCabinetDoctorFilterSnapshot.none,
      );
      expect(stable.map((doctor) => doctor.doctorId), ['a', 'b']);
    });

    test('alphabetical ordering consistently normalizes accents', () {
      final results = _apply(
        UrgentCabinetDoctorFilterSnapshot(
          sortOrder: UrgentCabinetSortOrder.nameAscending,
        ),
      );
      expect(results.map((doctor) => doctor.doctorId), ['a', 'b', 'c', 'z']);
    });

    test('options come only from currently eligible doctors', () {
      final options = buildUrgentCabinetDoctorFilterOptions(_doctors);
      expect(options.governorates, ['Ariana', 'Tunis']);
      expect(options.citiesFor('Tunis'), ['La Marsa', 'Tunis']);
      expect(options.citiesFor('Sousse'), isEmpty);
      expect(options.specialties, [
        'Médecine générale',
        'Médecine interne',
        'Pédiatrie',
      ]);
    });
  });
}
