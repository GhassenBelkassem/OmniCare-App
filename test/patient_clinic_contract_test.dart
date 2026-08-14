import 'package:flutter_test/flutter_test.dart';

import 'package:omnicare_mobile/features/patient_clinic/data/patient_clinic_models.dart';

void main() {
  group('patient Clinic directory contract', () {
    test('parses a Slice page including availability and pagination', () {
      final page = PatientClinicDirectoryPage.fromJson({
        'contractVersion': '1.0',
        'items': [
          {
            'clinicId': '11111111-1111-4111-8111-111111111111',
            'displayName': 'Clinique El Amal',
            'city': 'Tunis',
            'governorate': 'Tunis',
            'primaryImageUrl': null,
            'acceptingRequests': false,
          },
        ],
        'page': 2,
        'pageSize': 20,
        'hasNext': true,
      });

      expect(page.contractVersion, '1.0');
      expect(page.page, 2);
      expect(page.pageSize, 20);
      expect(page.hasNext, isTrue);
      expect(page.items.single.acceptingRequests, isFalse);
      expect(page.items.single.primaryImageUrl, isNull);
    });

    test(
      'parses optional detail fields and an empty gallery without services',
      () {
        final detail = PatientClinicDetail.fromJson({
          'clinicId': '11111111-1111-4111-8111-111111111111',
          'displayName': 'Clinique El Amal',
          'about': null,
          'city': null,
          'governorate': null,
          'address': null,
          'primaryImageUrl': null,
          'acceptingRequests': true,
          'gallery': [],
        });

        expect(detail.about, isNull);
        expect(detail.address, isNull);
        expect(detail.gallery, isEmpty);
        expect(detail.acceptingRequests, isTrue);
        expect(detail.headerImageUrl, isNull);
      },
    );

    test('parses gallery entries exactly as imageUrl values', () {
      final detail = PatientClinicDetail.fromJson({
        'clinicId': '11111111-1111-4111-8111-111111111111',
        'displayName': 'Clinique El Amal',
        'about': 'About',
        'city': 'Tunis',
        'governorate': 'Tunis',
        'address': '1 Rue de la Santé',
        'primaryImageUrl': 'https://cdn.example/primary.jpg',
        'acceptingRequests': true,
        'gallery': [
          {'imageUrl': 'https://cdn.example/one.jpg'},
          {'imageUrl': 'https://cdn.example/two.jpg'},
        ],
      });

      expect(detail.gallery.map((image) => image.imageUrl), [
        'https://cdn.example/one.jpg',
        'https://cdn.example/two.jpg',
      ]);
      expect(detail.headerImageUrl, 'https://cdn.example/one.jpg');
    });

    test('rejects malformed Slice and availability fields', () {
      expect(
        () => PatientClinicDirectoryPage.fromJson({
          'contractVersion': '1.0',
          'items': {},
          'page': 0,
          'pageSize': 20,
          'hasNext': false,
        }),
        throwsA(isA<PatientClinicContractException>()),
      );
      expect(
        () => PatientClinicListItem.fromJson({
          'clinicId': '11111111-1111-4111-8111-111111111111',
          'displayName': 'Clinique El Amal',
          'acceptingRequests': 'yes',
        }),
        throwsA(isA<PatientClinicContractException>()),
      );
    });
  });
}
