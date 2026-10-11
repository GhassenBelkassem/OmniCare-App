import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnicare_mobile/core/network/app_http_client.dart';
import 'package:omnicare_mobile/core/storage/secure_token_store.dart';
import 'package:omnicare_mobile/features/patient_doctor/data/doctor_detail_models.dart';
import 'package:omnicare_mobile/features/patient_doctor/data/doctor_directory_api.dart';
import 'package:omnicare_mobile/features/patient_doctor/data/doctor_directory_failure.dart';
import 'package:omnicare_mobile/features/patient_doctor/data/doctor_directory_mapper.dart';
import 'package:omnicare_mobile/features/patient_doctor/data/doctor_directory_models.dart';
import 'package:omnicare_mobile/features/patient_doctor/data/doctor_directory_repository.dart';

const _searchCardJson = <String, dynamic>{
  'doctorId': 'doc-1',
  'displayName': 'Dr. Sarah Mansour',
  'specialty': 'Médecin généraliste',
  'photoUrl': null,
  'consultationPriceTnd': null,
  'experienceYears': 12,
  'verified': true,
  'acceptingNewPatients': true,
  'careCapabilities': ['CABINET', 'HOME_VISIT'],
  'distanceKm': 2.4,
  'matchingPracticeLocation': {
    'practiceLocationId': 'cabinet-1',
    'name': 'Cabinet La Marsa',
    'city': 'La Marsa',
    'governorate': 'Tunis',
    'distanceKm': 2.4,
  },
};

const _searchPageJson = <String, dynamic>{
  'content': [_searchCardJson],
  'page': 0,
  'size': 20,
  'hasNext': false,
};

const _detailJson = <String, dynamic>{
  'doctorId': 'doc-1',
  'displayName': 'Dr. Sarah Mansour',
  'specialty': 'Médecin généraliste',
  'photoUrl': null,
  'affiliatedClinicId': null,
  'availableForUrgent': false,
  'consultationPriceTnd': null,
  'phoneNumber': '+216 98 000 000',
  'isActive': true,
  'experienceYears': 12,
  'distanceKm': null,
  'verified': true,
  'subSpecialties': ['Médecine familiale', 'Prévention'],
  'practiceCity': 'Tunis',
  'languages': ['Français', 'Arabe'],
  'acceptingNewPatients': true,
  'areasOfCare': ['Bilan général', 'Hypertension'],
  'expertise': ['Médecine préventive', 'Coordination des soins'],
  'visitReasons': ['Bilan de santé', 'Suivi de maladie chronique'],
  'patientAgeGroups': ['Adultes', 'Personnes âgées'],
  'consultationTypes': ['En cabinet', 'Téléconsultation'],
  'biography': 'Une brève biographie.',
  'education': [
    {
      'id': 'education-1',
      'institution': 'Faculté de Médecine de Tunis',
      'qualification': 'Doctorat en médecine',
      'fieldOfStudy': 'Médecine familiale',
      'completionYear': 2014,
      'displayOrder': 0,
    },
  ],
  'certifications': [
    {
      'id': 'certification-1',
      'name': 'Formation en échographie',
      'issuer': 'Société tunisienne de médecine',
      'issuedYear': 2022,
      'expiryDate': '2027-12-31',
      'displayOrder': 0,
    },
  ],
  'practiceLocations': [
    {
      'id': 'cabinet-1',
      'type': 'CABINET',
      'name': 'Cabinet La Marsa',
      'governorate': 'Tunis',
      'city': 'La Marsa',
      'address': '1 rue du Lac',
      'latitude': 36.84,
      'longitude': 10.27,
      'publicPhone': '+216 71 000 000',
      'wheelchairAccessible': true,
      'patientInstructions': 'Apportez vos anciens résultats.',
      'primary': true,
      'gallery': [
        {'url': 'https://cdn.example/cabinet.jpg', 'displayOrder': 0},
      ],
      'equipment': [
        {'code': 'ECG', 'displayName': 'ECG', 'portable': false},
      ],
      'coverage': {
        'selfPay': {
          'acceptance': 'ACCEPTED',
          'provenance': 'DECLARED',
          'verified': false,
        },
        'cnam': {
          'acceptance': 'ACCEPTED',
          'provenance': 'DECLARED',
          'verified': false,
        },
        'privateInsurance': {
          'acceptance': 'NOT_DECLARED',
          'provenance': null,
          'verified': false,
        },
        'specificPrivateInsurerDetailsAvailable': false,
      },
    },
  ],
  'careCapabilities': ['CABINET', 'HOME_VISIT'],
};

DioException _dio({
  DioExceptionType type = DioExceptionType.badResponse,
  int? statusCode,
}) {
  final requestOptions = RequestOptions(path: '/doctors');
  return DioException(
    requestOptions: requestOptions,
    type: type,
    response: statusCode == null
        ? null
        : Response(
            requestOptions: requestOptions,
            statusCode: statusCode,
            data: const <String, dynamic>{},
          ),
  );
}

DioException _badResponse(int statusCode) => _dio(statusCode: statusCode);

void main() {
  group('Search request contract', () {
    test('serializes every P1-06 query parameter with exact enum values', () {
      final query = const DoctorSearchCriteria(
        query: '  cardio ',
        specialty: 'Cardiologie',
        governorate: 'Tunis',
        city: 'La Marsa',
        location: DoctorSearchLocation(latitude: 36.88, longitude: 10.32),
        maxDistanceKm: 10,
        careCapability: DoctorCareCapability.homeVisit,
        cnamAcceptance: DoctorCoverageAcceptance.accepted,
        privateInsuranceAcceptance: DoctorCoverageAcceptance.notDeclared,
        selfPayAcceptance: DoctorCoverageAcceptance.notAccepted,
        acceptingNewPatients: true,
        page: 3,
        size: 25,
      ).toQueryParameters();

      expect(query, {
        'q': 'cardio',
        'specialty': 'Cardiologie',
        'governorate': 'Tunis',
        'city': 'La Marsa',
        'lat': 36.88,
        'lng': 10.32,
        'maxDistanceKm': 10.0,
        'careCapability': 'HOME_VISIT',
        'cnamAcceptance': 'ACCEPTED',
        'privateInsuranceAcceptance': 'NOT_DECLARED',
        'selfPayAcceptance': 'NOT_ACCEPTED',
        'acceptingNewPatients': true,
        'page': 3,
        'size': 25,
      });
    });

    test('uses /doctors/search and decodes the slice envelope', () async {
      final adapter = _RecordingAdapter(jsonEncode(_searchPageJson));
      final dio = Dio()..httpClientAdapter = adapter;
      final client = AppHttpClient(
        tokenStore: SecureTokenStore(backend: _MemoryBackend()),
        baseUrl: 'https://api.example.test',
        dio: dio,
        refreshDio: Dio(),
      );
      final api = DoctorDirectoryApi(client);

      final page = await api.searchDoctors(
        criteria: const DoctorSearchCriteria(query: 'cardio', page: 0),
      );

      expect(adapter.path, '/api/v1/doctors/search');
      expect(adapter.query['q'], 'cardio');
      expect(adapter.query['page'], 0);
      expect(adapter.query['size'], 20);
      expect(page.content.single.doctorId, 'doc-1');
    });

    test('sends exact Cabinet acquisition query parameters', () async {
      final adapter = _RecordingAdapter(jsonEncode(_searchPageJson));
      final dio = Dio()..httpClientAdapter = adapter;
      final client = AppHttpClient(
        tokenStore: SecureTokenStore(backend: _MemoryBackend()),
        baseUrl: 'https://api.example.test',
        dio: dio,
        refreshDio: Dio(),
      );
      final api = DoctorDirectoryApi(client);

      await api.searchDoctors(
        criteria: const DoctorSearchCriteria(
          careCapability: DoctorCareCapability.cabinet,
          acceptingNewPatients: true,
          page: 0,
          size: 20,
        ),
      );

      expect(adapter.path, '/api/v1/doctors/search');
      expect(adapter.query, {
        'careCapability': 'CABINET',
        'acceptingNewPatients': true,
        'page': 0,
        'size': 20,
      });
    });

    test('uses the selected real doctorId for the detail endpoint', () async {
      final adapter = _RecordingAdapter(jsonEncode(_detailJson));
      final dio = Dio()..httpClientAdapter = adapter;
      final client = AppHttpClient(
        tokenStore: SecureTokenStore(backend: _MemoryBackend()),
        baseUrl: 'https://api.example.test',
        dio: dio,
        refreshDio: Dio(),
      );
      final api = DoctorDirectoryApi(client);

      final detail = await api.getDoctor('doc-1');

      expect(adapter.path, '/api/v1/doctors/doc-1');
      expect(detail.doctorId, 'doc-1');
      expect(detail.practiceLocations.single.id, 'cabinet-1');
    });

    test('scopes availability to the selected Cabinet', () async {
      final adapter = _RecordingAdapter(
        jsonEncode(const <String, dynamic>{
          'slots': [
            {'start': '2026-09-24T09:00:00Z', 'end': '2026-09-24T09:30:00Z'},
          ],
        }),
      );
      final dio = Dio()..httpClientAdapter = adapter;
      final client = AppHttpClient(
        tokenStore: SecureTokenStore(backend: _MemoryBackend()),
        baseUrl: 'https://api.example.test',
        dio: dio,
        refreshDio: Dio(),
      );
      final api = DoctorDirectoryApi(client);

      final slots = await api.getSlots(
        doctorId: 'doc-1',
        practiceLocationId: 'cabinet-1',
        from: DateTime.utc(2026, 9, 24),
        to: DateTime.utc(2026, 9, 25),
      );

      expect(adapter.path, '/api/v1/appointments/availability/slots');
      expect(adapter.query['doctorId'], 'doc-1');
      expect(adapter.query['practiceLocationId'], 'cabinet-1');
      expect(slots.single.start, '2026-09-24T09:00:00Z');
    });
  });

  group('DTO parsing — Doctor search slice', () {
    test('parses the full contract payload', () {
      final page = DoctorSearchPage.fromJson(_searchPageJson);
      final item = page.content.single;
      expect(item.doctorId, 'doc-1');
      expect(item.displayName, 'Dr. Sarah Mansour');
      expect(item.specialty, 'Médecin généraliste');
      expect(item.experienceYears, 12);
      expect(item.consultationPriceTnd, isNull);
      expect(item.distanceKm, 2.4);
      expect(item.careCapabilities, [
        DoctorCareCapability.cabinet,
        DoctorCareCapability.homeVisit,
      ]);
      expect(item.matchingPracticeLocation?.name, 'Cabinet La Marsa');
      expect(item.matchingPracticeLocation?.city, 'La Marsa');
      expect(page.hasNext, isFalse);
    });

    test('accepts nullable card values', () {
      final item = DoctorSearchCard.fromJson(const <String, dynamic>{
        'doctorId': 'doc-2',
        'displayName': 'Dr. Nadia Cherif',
        'verified': true,
        'acceptingNewPatients': false,
        'careCapabilities': <String>[],
      });
      expect(item.doctorId, 'doc-2');
      expect(item.specialty, isNull);
      expect(item.matchingPracticeLocation, isNull);
    });

    test('rejects a missing required identifier', () {
      expect(
        () => DoctorSearchCard.fromJson(const <String, dynamic>{
          'displayName': 'Dr. X',
          'verified': true,
          'acceptingNewPatients': true,
          'careCapabilities': <String>[],
        }),
        throwsA(isA<DoctorContractException>()),
      );
    });

    test('rejects an unknown capability enum', () {
      expect(
        () => DoctorSearchCard.fromJson(const <String, dynamic>{
          'doctorId': 'doc-2',
          'displayName': 'Dr. X',
          'verified': true,
          'acceptingNewPatients': true,
          'careCapabilities': ['ONLINE_NOW'],
        }),
        throwsA(isA<DoctorContractException>()),
      );
    });
  });

  group('DTO parsing — DoctorDirectoryDetail', () {
    test('parses the full contract payload', () {
      final detail = DoctorDirectoryDetail.fromJson(_detailJson);
      expect(detail.doctorId, 'doc-1');
      expect(detail.verified, isTrue);
      expect(detail.experienceYears, 12);
      expect(detail.practiceCity, 'Tunis');
      expect(detail.subSpecialties, ['Médecine familiale', 'Prévention']);
      expect(detail.languages, ['Français', 'Arabe']);
      expect(detail.acceptingNewPatients, isTrue);
      expect(detail.areasOfCare, ['Bilan général', 'Hypertension']);
      expect(detail.expertise, [
        'Médecine préventive',
        'Coordination des soins',
      ]);
      expect(detail.visitReasons, [
        'Bilan de santé',
        'Suivi de maladie chronique',
      ]);
      expect(detail.patientAgeGroups, ['Adultes', 'Personnes âgées']);
      expect(detail.consultationTypes, ['En cabinet', 'Téléconsultation']);
      expect(detail.biography, 'Une brève biographie.');
      expect(detail.education.single.qualification, 'Doctorat en médecine');
      expect(detail.education.single.completionYear, 2014);
      expect(detail.certifications.single.name, 'Formation en échographie');
      expect(detail.certifications.single.expiryDate, DateTime(2027, 12, 31));
      expect(detail.careCapabilities, [
        DoctorCareCapability.cabinet,
        DoctorCareCapability.homeVisit,
      ]);
      final cabinet = detail.practiceLocations.single;
      expect(cabinet.id, 'cabinet-1');
      expect(cabinet.type, DoctorPracticeLocationType.cabinet);
      expect(cabinet.gallery.single.url, 'https://cdn.example/cabinet.jpg');
      expect(cabinet.equipment.single.displayName, 'ECG');
      expect(
        cabinet.coverage?.cnam.acceptance,
        DoctorCoverageAcceptance.accepted,
      );
      expect(
        cabinet.coverage?.cnam.provenance,
        DoctorCoverageProvenance.declared,
      );
      expect(cabinet.coverage?.cnam.verified, isFalse);
    });

    test('defaults acceptingNewPatients to true when absent', () {
      final detail = DoctorDirectoryDetail.fromJson(const <String, dynamic>{
        'doctorId': 'doc-1',
        'displayName': 'Dr. X',
        'availableForUrgent': false,
        'isActive': true,
        'verified': false,
      });
      expect(detail.acceptingNewPatients, isTrue);
    });

    test('acceptingNewPatients false is honored', () {
      final detail = DoctorDirectoryDetail.fromJson(const <String, dynamic>{
        'doctorId': 'doc-1',
        'displayName': 'Dr. X',
        'availableForUrgent': false,
        'isActive': true,
        'verified': false,
        'acceptingNewPatients': false,
      });
      expect(detail.acceptingNewPatients, isFalse);
    });

    test('accepts nullable optional nested values and zero Cabinets', () {
      final json = Map<String, dynamic>.from(_detailJson)
        ..['education'] = [
          {
            'id': 'education-2',
            'institution': 'Faculté de Médecine',
            'qualification': 'Doctorat',
            'fieldOfStudy': null,
            'completionYear': null,
            'displayOrder': 0,
          },
        ]
        ..['certifications'] = [
          {
            'id': 'certification-2',
            'name': 'Certification',
            'issuer': null,
            'issuedYear': null,
            'expiryDate': null,
            'displayOrder': 0,
          },
        ]
        ..['practiceLocations'] = <Map<String, dynamic>>[];

      final detail = DoctorDirectoryDetail.fromJson(json);

      expect(detail.education.single.fieldOfStudy, isNull);
      expect(detail.education.single.completionYear, isNull);
      expect(detail.certifications.single.issuer, isNull);
      expect(detail.certifications.single.expiryDate, isNull);
      expect(detail.practiceLocations, isEmpty);
    });

    test('preserves every Cabinet in backend order', () {
      final first = Map<String, dynamic>.from(
        (_detailJson['practiceLocations'] as List).single as Map,
      );
      final second = Map<String, dynamic>.from(first)
        ..['id'] = 'cabinet-2'
        ..['name'] = 'Cabinet Bizerte'
        ..['city'] = 'Bizerte'
        ..['primary'] = false
        ..['gallery'] = <Map<String, dynamic>>[]
        ..['equipment'] = <Map<String, dynamic>>[]
        ..['coverage'] = null;
      final json = Map<String, dynamic>.from(_detailJson)
        ..['practiceLocations'] = [first, second];

      final detail = DoctorDirectoryDetail.fromJson(json);

      expect(detail.practiceLocations.map((location) => location.id), [
        'cabinet-1',
        'cabinet-2',
      ]);
      expect(detail.practiceLocations.last.primary, isFalse);
    });

    test('rejects a string list carrying a non-string element', () {
      expect(
        () => DoctorDirectoryDetail.fromJson(const <String, dynamic>{
          'doctorId': 'doc-1',
          'displayName': 'Dr. X',
          'availableForUrgent': false,
          'isActive': true,
          'verified': false,
          'subSpecialties': ['ok', 42],
        }),
        throwsA(isA<DoctorContractException>()),
      );
    });
  });

  group('DTO parsing — slots', () {
    test('parses an availability slot', () {
      final slot = AvailabilitySlotDto.fromJson(const <String, dynamic>{
        'start': '2026-09-24T09:00:00Z',
        'end': '2026-09-24T09:30:00Z',
      });
      expect(slot.start, '2026-09-24T09:00:00Z');
      expect(slot.end, '2026-09-24T09:30:00Z');
    });

    test('rejects a slot missing its window', () {
      expect(
        () => AvailabilitySlotDto.fromJson(const <String, dynamic>{
          'end': '2026-09-24T09:30:00Z',
        }),
        throwsA(isA<DoctorContractException>()),
      );
    });
  });

  group('Mapper', () {
    test('maps a list DTO onto DoctorListItem', () {
      final item = toDoctorListItem(DoctorSearchCard.fromJson(_searchCardJson));
      expect(item.id, 'doc-1');
      expect(item.name, 'Dr. Sarah Mansour');
      expect(item.specialty, 'Médecin généraliste');
      expect(item.experienceYears, 12);
      expect(item.consultationPriceTnd, isNull);
      expect(item.acceptingNewPatients, isTrue);
      expect(item.photoUrl, isNull);
      expect(item.matchingPracticeLocation?.name, 'Cabinet La Marsa');
    });

    test('builds DoctorDetail from the detail DTO', () {
      final detail = buildDoctorDetail(
        DoctorDirectoryDetail.fromJson(_detailJson),
      );
      expect(detail.id, 'doc-1');
      expect(detail.name, 'Dr. Sarah Mansour');
      expect(detail.verified, isTrue);
      expect(detail.experienceYears, 12);
      expect(detail.languages, ['Français', 'Arabe']);
      expect(detail.areasOfCare, ['Bilan général', 'Hypertension']);
      expect(detail.consultationTypes, ['En cabinet', 'Téléconsultation']);
      expect(
        detail.education.single.institution,
        'Faculté de Médecine de Tunis',
      );
      expect(
        detail.certifications.single.issuer,
        'Société tunisienne de médecine',
      );
      expect(detail.careCapabilities, [
        DoctorCareCapability.cabinet,
        DoctorCareCapability.homeVisit,
      ]);
      final cabinet = detail.practiceLocations.single;
      expect(cabinet.name, 'Cabinet La Marsa');
      expect(cabinet.address, '1 rue du Lac');
      expect(cabinet.city, 'La Marsa');
      expect(cabinet.galleryImages, ['https://cdn.example/cabinet.jpg']);
      expect(cabinet.equipment.single.label, 'ECG');
      expect(cabinet.accessibility, ['Accessible PMR']);
      expect(cabinet.coverage, [
        'CNAM acceptée (déclaration du professionnel)',
        'Paiement direct accepté (déclaration du professionnel)',
      ]);
      expect(
        cabinet.appointmentInstructions,
        'Apportez vos anciens résultats.',
      );
    });

    test('does not fabricate a Cabinet from legacy practiceCity', () {
      final json = Map<String, dynamic>.from(_detailJson)
        ..['practiceLocations'] = <Map<String, dynamic>>[];
      final detail = buildDoctorDetail(DoctorDirectoryDetail.fromJson(json));
      expect(detail.practiceLocations, isEmpty);
    });

    group('groupAvailabilitySlots', () {
      test('groups slots by date and period, sorted', () {
        final slots = [
          _slotUtc(DateTime(2026, 9, 24, 14, 30)),
          _slotUtc(DateTime(2026, 9, 24, 9, 0)),
          _slotUtc(DateTime(2026, 9, 25, 10, 0)),
        ];
        final days = groupAvailabilitySlots(slots);

        expect(days, hasLength(2));
        expect(days.first.slots, hasLength(2));
        expect(days.first.slots.first.time, '09:00');
        expect(days.first.slots.map((s) => s.timeOfDay).toSet(), {
          'Matin',
          'Après-midi',
        });
        expect(days.last.slots.single.timeOfDay, 'Matin');
      });

      test('evening slots are mapped to Soir', () {
        final days = groupAvailabilitySlots([
          _slotUtc(DateTime(2026, 9, 24, 19, 0)),
        ]);
        expect(days.single.slots.single.timeOfDay, 'Soir');
      });

      test('throws on an unparseable instant', () {
        expect(
          () => groupAvailabilitySlots(const [
            AvailabilitySlotDto(start: 'nope', end: '2026-09-24T09:30:00Z'),
          ]),
          throwsA(isA<DoctorContractException>()),
        );
      });
    });

    group('nextAvailableLabelFor', () {
      test('today label uses Aujourd\'hui', () {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final days = [
          _day(today, ['09:30', '10:00'], ['Matin', 'Matin']),
        ];
        expect(nextAvailableLabelFor(days), 'Aujourd\'hui · 09:30');
      });

      test('tomorrow label uses Demain', () {
        final now = DateTime.now();
        final tomorrow = DateTime(now.year, now.month, now.day + 1);
        final days = [
          _day(tomorrow, ['10:00'], ['Matin']),
        ];
        expect(nextAvailableLabelFor(days), 'Demain · 10:00');
      });

      test('later days use the French weekday name', () {
        final now = DateTime.now();
        final later = DateTime(now.year, now.month, now.day + 4);
        const names = [
          'Lundi',
          'Mardi',
          'Mercredi',
          'Jeudi',
          'Vendredi',
          'Samedi',
          'Dimanche',
        ];
        final expectedDay = names[later.weekday - 1];
        final days = [
          _day(later, ['14:00'], ['Après-midi']),
        ];
        expect(nextAvailableLabelFor(days), '$expectedDay · 14:00');
      });

      test('returns null when there is no availability', () {
        expect(nextAvailableLabelFor(const []), isNull);
      });
    });
  });

  group('Failure mapping', () {
    test('401 maps to sessionExpired', () {
      final failure = DoctorDirectoryFailure.from(_badResponse(401));
      expect(failure.kind, DoctorDirectoryFailureKind.sessionExpired);
    });

    test('404 maps to notFound and reports it', () {
      final failure = DoctorDirectoryFailure.from(_badResponse(404));
      expect(failure.kind, DoctorDirectoryFailureKind.notFound);
      expect(failure.isNotFound, isTrue);
    });

    test('500 maps to server', () {
      final failure = DoctorDirectoryFailure.from(_badResponse(500));
      expect(failure.kind, DoctorDirectoryFailureKind.server);
    });

    test('bad response 422 maps to validation', () {
      final failure = DoctorDirectoryFailure.from(_badResponse(422));
      expect(failure.kind, DoctorDirectoryFailureKind.validation);
    });

    test('connection error maps to network', () {
      final failure = DoctorDirectoryFailure.from(
        _dio(type: DioExceptionType.connectionError),
      );
      expect(failure.kind, DoctorDirectoryFailureKind.network);
    });

    test('timeout maps to timeout', () {
      final failure = DoctorDirectoryFailure.from(
        _dio(type: DioExceptionType.receiveTimeout),
      );
      expect(failure.kind, DoctorDirectoryFailureKind.timeout);
    });

    test('contract exception maps to invalid response', () {
      final failure = DoctorDirectoryFailure.from(
        const DoctorContractException('broken'),
      );
      expect(failure.kind, DoctorDirectoryFailureKind.contract);
    });

    test('unknown errors map to unexpected', () {
      final failure = DoctorDirectoryFailure.from(Exception('boom'));
      expect(failure.kind, DoctorDirectoryFailureKind.unexpected);
    });

    test('never leaks backend detail strings', () {
      final failure = DoctorDirectoryFailure.from(_badResponse(500));
      expect(failure.message, isNot(contains('detail')));
      expect(failure.message, isNot(contains('traceId')));
      expect(
        DoctorDirectoryFailure.from(
          _dio(type: DioExceptionType.connectionError),
        ).message,
        isNot(contains('SocketException')),
      );
    });
  });

  group('Repository', () {
    test(
      'list, detail and slots failures become DoctorDirectoryFailure',
      () async {
        final api = _FakeApi(
          listError: _badResponse(401),
          detailError: _badResponse(404),
          slotsError: _dio(type: DioExceptionType.connectionError),
        );
        final repository = DoctorDirectoryRepository(api);

        await expectLater(
          repository.searchDoctors(criteria: const DoctorSearchCriteria()),
          throwsA(
            isA<DoctorDirectoryFailure>().having(
              (f) => f.kind,
              'kind',
              DoctorDirectoryFailureKind.sessionExpired,
            ),
          ),
        );
        await expectLater(
          repository.getDoctor('doc-1'),
          throwsA(
            isA<DoctorDirectoryFailure>().having(
              (f) => f.isNotFound,
              'notFound',
              true,
            ),
          ),
        );
        await expectLater(
          repository.getSlots(
            doctorId: 'doc-1',
            practiceLocationId: 'cabinet-1',
            from: DateTime.now(),
            to: DateTime.now().add(const Duration(days: 1)),
          ),
          throwsA(
            isA<DoctorDirectoryFailure>().having(
              (f) => f.kind,
              'kind',
              DoctorDirectoryFailureKind.network,
            ),
          ),
        );
      },
    );
  });
}

AvailabilitySlotDto _slotUtc(DateTime local) {
  final start = local;
  final end = start.add(const Duration(minutes: 30));
  return AvailabilitySlotDto(
    start: start.toUtc().toIso8601String(),
    end: end.toUtc().toIso8601String(),
  );
}

DoctorDayAvailability _day(
  DateTime date,
  List<String> times,
  List<String> periods,
) {
  assert(times.length == periods.length);
  return DoctorDayAvailability(
    date: DateTime(date.year, date.month, date.day),
    slots: List.unmodifiable([
      for (var i = 0; i < times.length; i++)
        DoctorAvailabilitySlot(
          time: times[i],
          timeOfDay: periods[i],
          startIso: '2026-09-24T${times[i]}:00Z',
          endIso: '2026-09-24T${times[i]}:30Z',
          start: DateTime(date.year, date.month, date.day, 9),
          end: DateTime(date.year, date.month, date.day, 9, 30),
        ),
    ]),
  );
}

class _FakeApi implements DoctorDirectoryApi {
  _FakeApi({this.listError, this.detailError, this.slotsError});

  final Object? listError;
  final Object? detailError;
  final Object? slotsError;

  @override
  Future<DoctorSearchPage> searchDoctors({
    required DoctorSearchCriteria criteria,
    CancelToken? cancelToken,
  }) async {
    final error = listError;
    if (error != null) throw error;
    return DoctorSearchPage(
      content: const [],
      page: criteria.page,
      size: criteria.size,
      hasNext: false,
    );
  }

  @override
  Future<DoctorDirectoryDetail> getDoctor(
    String doctorId, {
    CancelToken? cancelToken,
  }) async {
    final error = detailError;
    if (error != null) throw error;
    return DoctorDirectoryDetail.fromJson(_detailJson);
  }

  @override
  Future<List<AvailabilitySlotDto>> getSlots({
    required String doctorId,
    required String practiceLocationId,
    required DateTime from,
    required DateTime to,
    CancelToken? cancelToken,
  }) async {
    final error = slotsError;
    if (error != null) throw error;
    return const [];
  }
}

class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this.responseBody);

  final String responseBody;
  String? path;
  Map<String, dynamic> query = const {};

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    path = options.uri.path;
    query = Map<String, dynamic>.from(options.queryParameters);
    return ResponseBody.fromString(
      responseBody,
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _MemoryBackend implements SecureTokenStorageBackend {
  @override
  Future<void> delete({required String key}) async {}

  @override
  Future<String?> read({required String key}) async => null;

  @override
  Future<void> write({required String key, required String value}) async {}
}
