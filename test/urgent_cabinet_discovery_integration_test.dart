import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/core/network/app_http_client.dart';
import 'package:omnicare_mobile/core/storage/secure_token_store.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_discovery_controller.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_discovery_mapper.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_discovery_models.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_discovery_repository.dart';
import 'package:omnicare_mobile/features/emergency/urgent_cabinet/urgent_cabinet_doctor_filter.dart';

void main() {
  group('urgent CABINET discovery contract', () {
    test('parses exact Doctor/Cabinet identity, zero fee and revisions', () {
      final page = UrgentCabinetDiscoveryPage.fromJson(
        _pageJson(items: [_pairJson(fee: '0.000', distanceMeters: 1842)]),
      );

      final pair = page.items.single;
      expect(pair.doctorId, '11111111-1111-1111-1111-111111111111');
      expect(pair.practiceLocationId, '22222222-2222-2222-2222-222222222222');
      expect(pair.urgentCabinetFeeMilliTnd, 0);
      expect(pair.patientToCabinetDistance?.meters, 1842);
      expect(pair.patientToCabinetDistance?.method, 'STRAIGHT_LINE_HAVERSINE');
      expect(pair.configurationRevision, 7);
      expect(pair.runtimeRevision, 8);
      expect(pair.practiceLocationVersion, 9);
      expect(page.evaluatedAt, DateTime.parse('2026-10-17T10:00:00Z'));
    });

    test('rejects malformed or over-precise money', () {
      expect(
        () => UrgentCabinetDoctorCabinet.fromJson(_pairJson(fee: '75.0001')),
        throwsFormatException,
      );
    });

    test('service mapping carries no fabricated profile information', () {
      final detail = UrgentCabinetDiscoveryDetail.fromJson(
        _detailJson(),
      ).toDetail();

      expect(detail.languages, isEmpty);
      expect(detail.subSpecialties, isEmpty);
      expect(detail.biography, isNull);
      expect(detail.areasOfCare, isEmpty);
      expect(detail.expertise, isEmpty);
      expect(detail.visitReasons, isEmpty);
      expect(detail.portrait, isNull);
      expect(detail.cabinets.single.gallery, isEmpty);
      expect(detail.cabinets.single.equipment, isEmpty);
      expect(detail.cabinets.single.openingHours, isEmpty);
    });

    test('maps only allowlisted public profile and selected Cabinet data', () {
      final detail = UrgentCabinetDiscoveryDetail.fromJson(
        _detailJson(
          publicProfile: {
            'photoUrl': 'https://cdn.test/doctor.jpg',
            'experienceYears': 12,
            'subSpecialties': ['Rythmologie'],
            'languages': ['Français', 'Arabe'],
            'areasOfCare': ['Suivi cardiaque'],
            'expertise': ['ECG'],
            'visitReasons': ['Douleur thoracique'],
            'biography': 'Profil public configuré.',
          },
          selectedPractice: {
            'gallery': [
              {'url': 'https://cdn.test/cabinet.jpg', 'displayOrder': 0},
            ],
            'equipment': [
              {
                'code': 'ECG',
                'displayName': 'Électrocardiographe',
                'portable': false,
              },
            ],
            'wheelchairAccessible': true,
            'patientInstructions': 'Entrée B',
          },
        ),
      ).toDetail();

      expect(detail.portrait?.value, 'https://cdn.test/doctor.jpg');
      expect(detail.experienceYears, 12);
      expect(detail.languages, ['Français', 'Arabe']);
      expect(detail.areasOfCare, ['Suivi cardiaque']);
      expect(detail.cabinets.single.gallery.single.isNetwork, isTrue);
      expect(detail.cabinets.single.equipment, ['Électrocardiographe']);
      expect(detail.cabinets.single.accessibility, [
        'Accès fauteuil roulant',
        'Entrée B',
      ]);
    });

    test('parses complete facets independent of a result page', () {
      final facets = UrgentCabinetDiscoveryFacets.fromJson(_facetsJson());

      expect(facets.specialties, ['Cardiologie', 'Dermatologie']);
      expect(facets.locations.single.governorate, 'Tunis');
      expect(facets.locations.single.cities, ['La Marsa', 'Tunis']);
      final options = facets.toFilterOptions();
      expect(options.specialties, ['Cardiologie', 'Dermatologie']);
      expect(options.citiesFor('Tunis'), ['La Marsa', 'Tunis']);
      expect(options.citiesFor('Ariana'), isEmpty);
    });

    test('keeps multiple active Cabinets as distinct pair identities', () {
      final page = UrgentCabinetDiscoveryPage.fromJson(
        _pageJson(
          items: [
            _pairJson(
              practiceLocationId: '22222222-2222-2222-2222-222222222222',
            ),
            _pairJson(
              practiceLocationId: '44444444-4444-4444-4444-444444444444',
            ),
          ],
        ),
      );

      expect(page.items, hasLength(2));
      expect(
        page.items.map((item) => item.practiceLocationId).toSet(),
        hasLength(2),
      );
    });

    test('omits all location fields and forces NAME without valid GPS', () {
      final payload = const UrgentCabinetDiscoveryCriteria(
        query: '  Amine ',
        maximumDistanceMeters: 5000,
        sort: UrgentCabinetDiscoverySort.distance,
      ).toJson();

      expect(payload['query'], 'Amine');
      expect(payload['sort'], 'NAME');
      expect(payload, isNot(contains('latitude')));
      expect(payload, isNot(contains('longitude')));
      expect(payload, isNot(contains('maxDistanceMeters')));
    });
  });

  group('urgent CABINET discovery repository', () {
    test('loads the patient-authorized facets catalogue separately', () async {
      final adapter = _QueueAdapter([_facetsJson()]);
      final repository = AppUrgentCabinetDiscoveryRepository(_client(adapter));

      final facets = await repository.facets();

      expect(facets.specialties, contains('Dermatologie'));
      expect(adapter.requests.single.method, 'GET');
      expect(
        adapter.requests.single.path,
        '/me/urgent-cabinet/discovery/facets',
      );
    });

    test('uses authenticated API paths and exact request payload', () async {
      final adapter = _QueueAdapter([
        _pageJson(items: [_pairJson()]),
        _detailJson(),
      ]);
      final repository = AppUrgentCabinetDiscoveryRepository(_client(adapter));

      final page = await repository.search(
        const UrgentCabinetDiscoveryCriteria(
          specialty: 'Médecine générale',
          governorate: 'Tunis',
          city: 'Tunis',
          position: UrgentCabinetSearchPosition(
            latitude: 36.8065,
            longitude: 10.1815,
          ),
          maximumDistanceMeters: 10000,
          sort: UrgentCabinetDiscoverySort.distance,
          page: 0,
          size: 20,
        ),
      );
      await repository.detail(
        doctorId: page.items.single.doctorId,
        practiceLocationId: page.items.single.practiceLocationId,
      );

      expect(adapter.requests[0].method, 'POST');
      expect(adapter.requests[0].path, '/me/urgent-cabinet/discovery/search');
      expect(adapter.requests[0].baseUrl, 'https://api.test/api/v1');
      expect(adapter.bodies[0], containsPair('sort', 'DISTANCE'));
      expect(adapter.bodies[0], containsPair('maxDistanceMeters', 10000));
      expect(adapter.requests[1].method, 'GET');
      expect(
        adapter.requests[1].path,
        '/me/urgent-cabinet/discovery/doctors/'
        '11111111-1111-1111-1111-111111111111/practice-locations/'
        '22222222-2222-2222-2222-222222222222',
      );
    });

    test(
      'maps an unavailable exact pair to an opaque not-found failure',
      () async {
        final repository = AppUrgentCabinetDiscoveryRepository(
          _client(_QueueAdapter([const _QueuedError(404)])),
        );

        await expectLater(
          repository.detail(
            doctorId: '11111111-1111-1111-1111-111111111111',
            practiceLocationId: '22222222-2222-2222-2222-222222222222',
          ),
          throwsA(
            isA<UrgentCabinetDiscoveryFailure>().having(
              (failure) => failure.kind,
              'kind',
              UrgentCabinetDiscoveryFailureKind.notFound,
            ),
          ),
        );
      },
    );
  });

  group('urgent CABINET discovery controller', () {
    test(
      'sends filters to backend, paginates, and clears on account switch',
      () async {
        final repository = _FakeRepository();
        final controller = UrgentCabinetDiscoveryController(
          repository: repository,
          searchDebounce: Duration.zero,
          pageSize: 1,
        );
        addTearDown(controller.dispose);

        await controller.startSession('patient-a');
        expect(controller.items, hasLength(1));
        expect(controller.hasNext, isTrue);

        await controller.setSearchPosition(
          const UrgentCabinetSearchPosition(
            latitude: 36.8065,
            longitude: 10.1815,
          ),
        );
        await controller.applyFilters(
          UrgentCabinetDoctorFilterSnapshot(
            specialties: const {'Médecine générale'},
            governorate: 'Tunis',
            city: 'Tunis',
            maximumDistanceKm: 10,
            sortOrder: UrgentCabinetSortOrder.nearest,
          ),
        );
        final filtered = repository.criteria.last;
        expect(filtered.specialty, 'Médecine générale');
        expect(filtered.governorate, 'Tunis');
        expect(filtered.city, 'Tunis');
        expect(filtered.maximumDistanceMeters, 10000);
        expect(filtered.sort, UrgentCabinetDiscoverySort.distance);

        await controller.loadMore();
        expect(repository.criteria.last.page, 1);
        expect(controller.items, hasLength(2));

        await controller.startSession('patient-b');
        expect(repository.criteria.last.page, 0);
        expect(controller.items, hasLength(1));
      },
    );

    test(
      'debounces text search and does not send distance without GPS',
      () async {
        final repository = _FakeRepository();
        final controller = UrgentCabinetDiscoveryController(
          repository: repository,
          searchDebounce: const Duration(milliseconds: 5),
        );
        addTearDown(controller.dispose);
        await controller.startSession('patient-a');

        controller.updateQuery('A');
        controller.updateQuery('Am');
        controller.updateQuery('Amine');
        await Future<void>.delayed(const Duration(milliseconds: 20));

        expect(
          repository.criteria.where((value) => value.query == 'Amine'),
          hasLength(1),
        );
        expect(repository.criteria.last.position, isNull);
        expect(repository.criteria.last.maximumDistanceMeters, isNull);
        expect(repository.criteria.last.sort, UrgentCabinetDiscoverySort.name);
      },
    );

    test('cancels and disregards an obsolete search response', () async {
      final repository = _DeferredRepository();
      final controller = UrgentCabinetDiscoveryController(
        repository: repository,
        searchDebounce: Duration.zero,
      );
      addTearDown(controller.dispose);

      final obsolete = controller.startSession('patient-a');
      await Future<void>.delayed(Duration.zero);
      controller.updateQuery('latest');
      await Future<void>.delayed(const Duration(milliseconds: 5));

      expect(repository.tokens.first.isCancelled, isTrue);
      expect(controller.items.single.doctorDisplayName, 'Dr. Réponse récente');

      repository.first.complete(
        UrgentCabinetDiscoveryPage.fromJson(
          _pageJson(items: [_pairJson(displayName: 'Dr. Réponse obsolète')]),
        ),
      );
      await obsolete;
      expect(controller.items.single.doctorDisplayName, 'Dr. Réponse récente');
    });
  });
}

class _FakeRepository implements UrgentCabinetDiscoveryRepository {
  final criteria = <UrgentCabinetDiscoveryCriteria>[];

  @override
  Future<UrgentCabinetDiscoveryFacets> facets({
    CancelToken? cancelToken,
  }) async => UrgentCabinetDiscoveryFacets.fromJson(_facetsJson());

  @override
  Future<UrgentCabinetDiscoveryPage> search(
    UrgentCabinetDiscoveryCriteria value, {
    CancelToken? cancelToken,
  }) async {
    criteria.add(value);
    return UrgentCabinetDiscoveryPage.fromJson(
      _pageJson(
        page: value.page,
        size: value.size,
        hasNext: value.page == 0,
        items: [
          _pairJson(
            doctorId: value.page == 0
                ? '11111111-1111-1111-1111-111111111111'
                : '33333333-3333-3333-3333-333333333333',
          ),
        ],
      ),
    );
  }

  @override
  Future<UrgentCabinetDiscoveryDetail> detail({
    required String doctorId,
    required String practiceLocationId,
    CancelToken? cancelToken,
  }) => throw UnimplementedError();
}

class _DeferredRepository implements UrgentCabinetDiscoveryRepository {
  final first = Completer<UrgentCabinetDiscoveryPage>();
  final tokens = <CancelToken>[];
  int calls = 0;

  @override
  Future<UrgentCabinetDiscoveryFacets> facets({
    CancelToken? cancelToken,
  }) async => UrgentCabinetDiscoveryFacets.fromJson(_facetsJson());

  @override
  Future<UrgentCabinetDiscoveryPage> search(
    UrgentCabinetDiscoveryCriteria value, {
    CancelToken? cancelToken,
  }) {
    tokens.add(cancelToken!);
    calls++;
    if (calls == 1) return first.future;
    return Future.value(
      UrgentCabinetDiscoveryPage.fromJson(
        _pageJson(items: [_pairJson(displayName: 'Dr. Réponse récente')]),
      ),
    );
  }

  @override
  Future<UrgentCabinetDiscoveryDetail> detail({
    required String doctorId,
    required String practiceLocationId,
    CancelToken? cancelToken,
  }) => throw UnimplementedError();
}

Map<String, dynamic> _pageJson({
  required List<Map<String, dynamic>> items,
  int page = 0,
  int size = 20,
  bool hasNext = false,
}) => {
  'items': items,
  'page': page,
  'size': size,
  'hasNext': hasNext,
  'evaluatedAt': '2026-10-17T10:00:00Z',
};

Map<String, dynamic> _facetsJson() => {
  'specialties': ['Cardiologie', 'Dermatologie'],
  'locations': [
    {
      'governorate': 'Tunis',
      'cities': ['La Marsa', 'Tunis'],
    },
  ],
  'evaluatedAt': '2026-10-17T10:00:00Z',
};

Map<String, dynamic> _detailJson({
  Map<String, dynamic>? publicProfile,
  Map<String, dynamic>? selectedPractice,
}) => {
  'doctorCabinet': _pairJson(),
  'publicProfile':
      publicProfile ??
      {
        'photoUrl': null,
        'experienceYears': null,
        'subSpecialties': <String>[],
        'languages': <String>[],
        'areasOfCare': <String>[],
        'expertise': <String>[],
        'visitReasons': <String>[],
        'biography': null,
      },
  'selectedPractice':
      selectedPractice ??
      {
        'gallery': <Object>[],
        'equipment': <Object>[],
        'wheelchairAccessible': false,
        'patientInstructions': null,
      },
  'evaluatedAt': '2026-10-17T10:01:00Z',
};

Map<String, dynamic> _pairJson({
  String doctorId = '11111111-1111-1111-1111-111111111111',
  String practiceLocationId = '22222222-2222-2222-2222-222222222222',
  String displayName = 'Dr. Amine Ben Salah',
  Object fee = '75.000',
  int? distanceMeters,
}) => {
  'doctorId': doctorId,
  'practiceLocationId': practiceLocationId,
  'doctorDisplayName': displayName,
  'specialty': 'Médecine générale',
  'cabinetName': 'Cabinet du Lac',
  'cabinetAddress': 'Rue du Lac Victoria',
  'governorate': 'Tunis',
  'city': 'Tunis',
  'latitude': 36.8065,
  'longitude': 10.1815,
  'patientToCabinetDistance': distanceMeters == null
      ? null
      : {'meters': distanceMeters, 'method': 'STRAIGHT_LINE_HAVERSINE'},
  'urgentCabinetFeeTnd': fee,
  'configurationRevision': 7,
  'runtimeRevision': 8,
  'practiceLocationVersion': 9,
};

AppHttpClient _client(HttpClientAdapter adapter) {
  final dio = Dio()..httpClientAdapter = adapter;
  return AppHttpClient(
    tokenStore: SecureTokenStore(backend: _MemoryTokenBackend()),
    baseUrl: 'https://api.test',
    dio: dio,
    refreshDio: Dio(),
  );
}

class _QueueAdapter implements HttpClientAdapter {
  _QueueAdapter(this.responses);

  final List<Object> responses;
  final requests = <RequestOptions>[];
  final bodies = <Object?>[];
  int _index = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    bodies.add(options.data);
    final response = responses[_index++];
    if (response case _QueuedError(:final statusCode)) {
      return ResponseBody.fromString(
        jsonEncode({
          'type': 'about:blank',
          'title': 'Resource not found',
          'status': statusCode,
        }),
        statusCode,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );
    }
    return ResponseBody.fromString(
      jsonEncode(response),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _QueuedError {
  const _QueuedError(this.statusCode);

  final int statusCode;
}

class _MemoryTokenBackend implements SecureTokenStorageBackend {
  final values = <String, String>{};

  @override
  Future<void> delete({required String key}) async => values.remove(key);

  @override
  Future<String?> read({required String key}) async => values[key];

  @override
  Future<void> write({required String key, required String value}) async {
    values[key] = value;
  }
}
