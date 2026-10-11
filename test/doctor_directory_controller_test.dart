import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnicare_mobile/features/patient_doctor/application/doctor_discovery_context.dart';
import 'package:omnicare_mobile/features/patient_doctor/application/doctor_directory_controller.dart';
import 'package:omnicare_mobile/features/patient_doctor/application/doctor_directory_filters.dart';
import 'package:omnicare_mobile/features/patient_doctor/data/doctor_directory_failure.dart';
import 'package:omnicare_mobile/features/patient_doctor/data/doctor_directory_models.dart';
import 'package:omnicare_mobile/features/patient_doctor/data/doctor_directory_repository.dart';

DoctorSearchCard _card(String id) => DoctorSearchCard(
  doctorId: id,
  displayName: 'Dr. $id',
  verified: true,
  acceptingNewPatients: true,
);

DoctorSearchPage _page(int page, List<String> ids, {required bool hasNext}) =>
    DoctorSearchPage(
      content: ids.map(_card).toList(growable: false),
      page: page,
      size: 2,
      hasNext: hasNext,
    );

void main() {
  test(
    'search is debounced and only the latest text reaches the backend',
    () async {
      final repository = _FakeRepository(
        onSearch: (criteria) async => _page(0, const [], hasNext: false),
      );
      final controller = DoctorDirectoryController(
        repository: repository,
        debounce: const Duration(milliseconds: 15),
      );
      addTearDown(controller.dispose);

      controller.search('c');
      controller.search('card');
      controller.search('cardio');
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(repository.criteria, hasLength(1));
      expect(repository.criteria.single.query, 'cardio');
      expect(repository.criteria.single.page, 0);
    },
  );

  test('a slower stale response cannot replace the newer query', () async {
    final card = Completer<DoctorSearchPage>();
    final cardio = Completer<DoctorSearchPage>();
    final repository = _FakeRepository(
      onSearch: (criteria) => switch (criteria.query) {
        'card' => card.future,
        'cardio' => cardio.future,
        _ => Future.value(_page(0, const [], hasNext: false)),
      },
    );
    final controller = DoctorDirectoryController(repository: repository);
    addTearDown(controller.dispose);

    final first = controller.loadFirst(query: 'card');
    final second = controller.loadFirst(query: 'cardio');
    cardio.complete(_page(0, const ['new'], hasNext: false));
    await second;
    card.complete(_page(0, const ['stale'], hasNext: false));
    await first;

    expect(controller.query, 'cardio');
    expect(controller.items.map((item) => item.id), ['new']);
  });

  test(
    'filters serialize through one backend query and reset page zero',
    () async {
      final repository = _FakeRepository(
        onSearch: (criteria) async =>
            _page(criteria.page, const [], hasNext: false),
      );
      final controller = DoctorDirectoryController(repository: repository);
      addTearDown(controller.dispose);
      const filters = DoctorFilterSnapshot(
        specialty: 'Cardiologie',
        governorate: 'Tunis',
        city: 'La Marsa',
        maxDistanceKm: 10,
        careCapability: DoctorCareCapability.homeVisit,
        cnamAccepted: true,
        privateInsuranceAccepted: true,
        acceptingNewPatients: true,
      );

      await controller.applyFilters(
        filters,
        location: const DoctorSearchLocation(latitude: 36.88, longitude: 10.32),
      );

      final criteria = repository.criteria.single;
      expect(criteria.page, 0);
      expect(criteria.specialty, 'Cardiologie');
      expect(criteria.governorate, 'Tunis');
      expect(criteria.city, 'La Marsa');
      expect(criteria.maxDistanceKm, 10);
      expect(criteria.careCapability, DoctorCareCapability.homeVisit);
      expect(criteria.cnamAcceptance, DoctorCoverageAcceptance.accepted);
      expect(
        criteria.privateInsuranceAcceptance,
        DoctorCoverageAcceptance.accepted,
      );
      expect(criteria.acceptingNewPatients, isTrue);
    },
  );

  test('pagination appends uniquely and stops after hasNext false', () async {
    final repository = _FakeRepository(
      onSearch: (criteria) async => criteria.page == 0
          ? _page(0, const ['a', 'b'], hasNext: true)
          : _page(1, const ['b', 'c'], hasNext: false),
    );
    final controller = DoctorDirectoryController(
      repository: repository,
      pageSize: 2,
    );
    addTearDown(controller.dispose);

    await controller.loadFirst();
    await controller.loadNext();
    await controller.loadNext();

    expect(controller.items.map((item) => item.id), ['a', 'b', 'c']);
    expect(controller.hasNext, isFalse);
    expect(repository.criteria.map((value) => value.page), [0, 1]);
  });

  test('repeated next-page calls share the in-flight request', () async {
    final nextPage = Completer<DoctorSearchPage>();
    final repository = _FakeRepository(
      onSearch: (criteria) => criteria.page == 0
          ? Future.value(_page(0, const ['a'], hasNext: true))
          : nextPage.future,
    );
    final controller = DoctorDirectoryController(repository: repository);
    addTearDown(controller.dispose);
    await controller.loadFirst();

    final first = controller.loadNext();
    final second = controller.loadNext();
    expect(repository.criteria.where((value) => value.page == 1), hasLength(1));
    nextPage.complete(_page(1, const ['b'], hasNext: false));
    await Future.wait([first, second]);

    expect(controller.items.map((item) => item.id), ['a', 'b']);
  });

  test('next-page failure preserves data and can be retried', () async {
    var failPage = true;
    final repository = _FakeRepository(
      onSearch: (criteria) async {
        if (criteria.page == 0) return _page(0, const ['a'], hasNext: true);
        if (failPage) throw DoctorDirectoryFailure.timedOut;
        return _page(1, const ['b'], hasNext: false);
      },
    );
    final controller = DoctorDirectoryController(repository: repository);
    addTearDown(controller.dispose);
    await controller.loadFirst();

    await controller.loadNext();
    expect(controller.items.map((item) => item.id), ['a']);
    expect(controller.nextPageError?.kind, DoctorDirectoryFailureKind.timeout);

    failPage = false;
    await controller.retryNextPage();
    expect(controller.items.map((item) => item.id), ['a', 'b']);
    expect(controller.nextPageError, isNull);
  });

  test('clearing filters retains no stale pagination state', () async {
    final repository = _FakeRepository(
      onSearch: (criteria) async =>
          _page(criteria.page, const [], hasNext: criteria.page == 0),
    );
    final controller = DoctorDirectoryController(repository: repository);
    addTearDown(controller.dispose);
    await controller.applyFilters(
      const DoctorFilterSnapshot(specialty: 'Cardiologie'),
    );
    await controller.loadNext();
    await controller.clearFilters();

    expect(repository.criteria.last.page, 0);
    expect(repository.criteria.last.specialty, isNull);
    expect(controller.filters, DoctorFilterSnapshot.none);
  });

  group('Cabinet acquisition constraints', () {
    late _FakeRepository repository;
    late DoctorDirectoryController controller;

    setUp(() {
      repository = _FakeRepository(
        onSearch: (criteria) async =>
            _page(criteria.page, const [], hasNext: criteria.page == 0),
      );
      controller = DoctorDirectoryController(
        repository: repository,
        discoveryContext: DoctorDiscoveryContext.cabinetNewPatient,
        debounce: const Duration(milliseconds: 15),
        pageSize: 25,
      );
      addTearDown(controller.dispose);
    });

    void expectCabinetConstraints(DoctorSearchCriteria criteria) {
      expect(criteria.careCapability, DoctorCareCapability.cabinet);
      expect(criteria.acceptingNewPatients, isTrue);
    }

    test('initial page and retry retain required constraints', () async {
      await controller.loadFirst();
      await controller.loadFirst();

      expect(repository.criteria, hasLength(2));
      for (final criteria in repository.criteria) {
        expectCabinetConstraints(criteria);
        expect(criteria.page, 0);
        expect(criteria.size, 25);
      }
    });

    test('retry after an error cannot broaden the request', () async {
      var attempts = 0;
      final retryRepository = _FakeRepository(
        onSearch: (criteria) async {
          attempts += 1;
          if (attempts == 1) throw DoctorDirectoryFailure.timedOut;
          return _page(0, const [], hasNext: false);
        },
      );
      final retryController = DoctorDirectoryController(
        repository: retryRepository,
        discoveryContext: DoctorDiscoveryContext.cabinetNewPatient,
      );
      addTearDown(retryController.dispose);

      await retryController.loadFirst();
      expect(retryController.status, DoctorDirectoryStatus.error);
      await retryController.loadFirst();

      expect(retryRepository.criteria, hasLength(2));
      for (final criteria in retryRepository.criteria) {
        expectCabinetConstraints(criteria);
      }
    });

    test(
      'optional filters compose and conflicting capability cannot win',
      () async {
        await controller.applyFilters(
          const DoctorFilterSnapshot(
            specialty: 'Cardiologie',
            governorate: 'Tunis',
            city: 'La Marsa',
            maxDistanceKm: 10,
            careCapability: DoctorCareCapability.homeVisit,
            cnamAccepted: true,
            privateInsuranceAccepted: true,
          ),
          location: const DoctorSearchLocation(
            latitude: 36.88,
            longitude: 10.32,
          ),
        );

        final criteria = repository.criteria.single;
        expectCabinetConstraints(criteria);
        expect(criteria.specialty, 'Cardiologie');
        expect(criteria.governorate, 'Tunis');
        expect(criteria.city, 'La Marsa');
        expect(criteria.maxDistanceKm, 10);
        expect(criteria.cnamAcceptance, DoctorCoverageAcceptance.accepted);
        expect(
          criteria.privateInsuranceAcceptance,
          DoctorCoverageAcceptance.accepted,
        );
      },
    );

    test('clearing filters cannot clear required constraints', () async {
      await controller.applyFilters(
        const DoctorFilterSnapshot(specialty: 'Cardiologie'),
      );
      await controller.clearSearchAndFilters();

      final criteria = repository.criteria.last;
      expectCabinetConstraints(criteria);
      expect(criteria.specialty, isNull);
      expect(criteria.query, isEmpty);
      expect(criteria.page, 0);
    });

    test(
      'debounced search and pagination retain required constraints',
      () async {
        controller.search('cardio');
        await Future<void>.delayed(const Duration(milliseconds: 40));
        await controller.loadNext();

        expect(repository.criteria.map((value) => value.page), [0, 1]);
        for (final criteria in repository.criteria) {
          expectCabinetConstraints(criteria);
          expect(criteria.query, 'cardio');
        }
      },
    );

    test('stale-request replacement retains required constraints', () async {
      final first = Completer<DoctorSearchPage>();
      final second = Completer<DoctorSearchPage>();
      final staleRepository = _FakeRepository(
        onSearch: (criteria) => switch (criteria.query) {
          'card' => first.future,
          'cardio' => second.future,
          _ => Future.value(_page(0, const [], hasNext: false)),
        },
      );
      final staleController = DoctorDirectoryController(
        repository: staleRepository,
        discoveryContext: DoctorDiscoveryContext.cabinetNewPatient,
      );
      addTearDown(staleController.dispose);

      final staleLoad = staleController.loadFirst(query: 'card');
      final currentLoad = staleController.loadFirst(query: 'cardio');
      second.complete(_page(0, const ['current'], hasNext: false));
      await currentLoad;
      first.complete(_page(0, const ['stale'], hasNext: false));
      await staleLoad;

      expect(staleController.items.map((item) => item.id), ['current']);
      expect(staleRepository.criteria, hasLength(2));
      for (final criteria in staleRepository.criteria) {
        expectCabinetConstraints(criteria);
      }
    });

    test('empty response does not issue a broader fallback request', () async {
      await controller.loadFirst();

      expect(controller.status, DoctorDirectoryStatus.empty);
      expect(repository.criteria, hasLength(1));
      expectCabinetConstraints(repository.criteria.single);
    });
  });

  test('generic discovery remains unconstrained', () async {
    final repository = _FakeRepository(
      onSearch: (criteria) async => _page(0, const [], hasNext: false),
    );
    final controller = DoctorDirectoryController(repository: repository);
    addTearDown(controller.dispose);

    await controller.loadFirst();

    expect(repository.criteria.single.careCapability, isNull);
    expect(repository.criteria.single.acceptingNewPatients, isNull);
  });
}

class _FakeRepository implements DoctorDirectoryRepository {
  _FakeRepository({required this.onSearch});

  final Future<DoctorSearchPage> Function(DoctorSearchCriteria) onSearch;
  final List<DoctorSearchCriteria> criteria = [];

  @override
  Future<DoctorSearchPage> searchDoctors({
    required DoctorSearchCriteria criteria,
    CancelToken? cancelToken,
  }) {
    this.criteria.add(criteria);
    return onSearch(criteria);
  }

  @override
  Future<DoctorDirectoryDetail> getDoctor(
    String doctorId, {
    CancelToken? cancelToken,
  }) => throw UnimplementedError();

  @override
  Future<List<AvailabilitySlotDto>> getSlots({
    required String doctorId,
    required String practiceLocationId,
    required DateTime from,
    required DateTime to,
    CancelToken? cancelToken,
  }) => throw UnimplementedError();
}
