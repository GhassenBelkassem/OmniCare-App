import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'urgent_cabinet_discovery_models.dart';
import 'urgent_cabinet_discovery_repository.dart';
import 'urgent_cabinet_doctor_filter.dart';

enum UrgentCabinetDiscoveryLoadState {
  idle,
  loading,
  loaded,
  loadingMore,
  error,
}

/// Session-scoped, cancel-safe state for the authoritative CABINET directory.
class UrgentCabinetDiscoveryController extends ChangeNotifier {
  UrgentCabinetDiscoveryController({
    required UrgentCabinetDiscoveryRepository repository,
    Duration searchDebounce = const Duration(milliseconds: 350),
    int pageSize = 20,
  }) : _repository = repository,
       _searchDebounce = searchDebounce,
       _pageSize = pageSize;

  final UrgentCabinetDiscoveryRepository _repository;
  final Duration _searchDebounce;
  final int _pageSize;

  String? _sessionOwnerId;
  String _query = '';
  UrgentCabinetDoctorFilterSnapshot _filters = UrgentCabinetDoctorFilterSnapshot
      .none
      .copyWith(sortOrder: UrgentCabinetSortOrder.nameAscending);
  UrgentCabinetSearchPosition? _position;
  List<UrgentCabinetDoctorCabinet> _items = const [];
  UrgentCabinetDiscoveryFacets? _facets;
  UrgentCabinetDiscoveryLoadState _state = UrgentCabinetDiscoveryLoadState.idle;
  UrgentCabinetDiscoveryFailure? _failure;
  DateTime? _evaluatedAt;
  bool _hasNext = false;
  int _loadedPage = -1;
  int _generation = 0;
  Timer? _debounce;
  CancelToken? _requestToken;
  bool _disposed = false;

  String get query => _query;
  UrgentCabinetDoctorFilterSnapshot get filters => _filters;
  UrgentCabinetSearchPosition? get position => _position;
  List<UrgentCabinetDoctorCabinet> get items => _items;
  UrgentCabinetDiscoveryFacets? get facets => _facets;
  UrgentCabinetDiscoveryLoadState get state => _state;
  UrgentCabinetDiscoveryFailure? get failure => _failure;
  DateTime? get evaluatedAt => _evaluatedAt;
  bool get hasNext => _hasNext;
  bool get canUseDistance => _position?.isValid == true;

  Future<void> startSession(
    String? ownerId, {
    UrgentCabinetSearchPosition? initialPosition,
  }) {
    final normalized = _normalize(ownerId);
    if (_sessionOwnerId != normalized) {
      _sessionOwnerId = normalized;
      _clearTransient(notify: false);
    }
    _position = initialPosition?.isValid == true ? initialPosition : null;
    if (normalized == null) {
      _state = UrgentCabinetDiscoveryLoadState.error;
      _failure = const UrgentCabinetDiscoveryFailure(
        UrgentCabinetDiscoveryFailureKind.sessionRejected,
      );
      notifyListeners();
      return SynchronousFuture(null);
    }
    return refresh();
  }

  void updateQuery(String value) {
    final normalized = value.trim();
    if (_query == normalized) return;
    _query = normalized;
    _debounce?.cancel();
    _debounce = Timer(_searchDebounce, () {
      if (!_disposed) unawaited(refresh());
    });
  }

  Future<void> applyFilters(UrgentCabinetDoctorFilterSnapshot value) {
    var next = value;
    if (next.specialties.length > 1) {
      final selected = next.specialties.toList()
        ..sort((left, right) => left.compareTo(right));
      next = next.copyWith(specialties: {selected.first});
    }
    if (!canUseDistance) {
      next = next.copyWith(
        clearMaximumDistance: true,
        sortOrder: UrgentCabinetSortOrder.nameAscending,
      );
    }
    if (_filters == next) return SynchronousFuture(null);
    _filters = next;
    return refresh();
  }

  Future<void> setSearchPosition(UrgentCabinetSearchPosition? position) {
    final next = position?.isValid == true ? position : null;
    if (_position?.latitude == next?.latitude &&
        _position?.longitude == next?.longitude) {
      return SynchronousFuture(null);
    }
    _position = next;
    if (next == null &&
        (_filters.maximumDistanceKm != null ||
            _filters.sortOrder == UrgentCabinetSortOrder.nearest)) {
      _filters = _filters.copyWith(
        clearMaximumDistance: true,
        sortOrder: UrgentCabinetSortOrder.nameAscending,
      );
    }
    return refresh();
  }

  Future<void> refresh() =>
      _facets == null ? _loadFacetsThenSearch() : _load(page: 0, append: false);

  Future<void> _loadFacetsThenSearch() async {
    if (_disposed || _sessionOwnerId == null) return;
    _debounce?.cancel();
    final generation = ++_generation;
    _requestToken?.cancel('urgent-cabinet-facets-obsolete');
    final token = CancelToken();
    _requestToken = token;
    _state = UrgentCabinetDiscoveryLoadState.loading;
    _failure = null;
    _items = const [];
    _hasNext = false;
    _loadedPage = -1;
    notifyListeners();

    try {
      final result = await _repository.facets(cancelToken: token);
      if (!_isCurrent(generation, token)) return;
      _facets = result;
      await _load(page: 0, append: false);
    } catch (error) {
      final failure = UrgentCabinetDiscoveryFailure.from(error);
      if (!_isCurrent(generation, token) || failure.isCancelled) return;
      _state = UrgentCabinetDiscoveryLoadState.error;
      _failure = failure;
      notifyListeners();
    }
  }

  Future<void> loadMore() {
    if (!_hasNext ||
        _state == UrgentCabinetDiscoveryLoadState.loading ||
        _state == UrgentCabinetDiscoveryLoadState.loadingMore) {
      return SynchronousFuture(null);
    }
    return _load(page: _loadedPage + 1, append: true);
  }

  Future<void> _load({required int page, required bool append}) async {
    if (_disposed || _sessionOwnerId == null) return;
    _debounce?.cancel();
    final generation = ++_generation;
    _requestToken?.cancel('urgent-cabinet-discovery-obsolete');
    final token = CancelToken();
    _requestToken = token;
    _state = append
        ? UrgentCabinetDiscoveryLoadState.loadingMore
        : UrgentCabinetDiscoveryLoadState.loading;
    _failure = null;
    if (!append) {
      _items = const [];
      _hasNext = false;
      _loadedPage = -1;
    }
    notifyListeners();

    try {
      final pageResult = await _repository.search(
        _criteria(page),
        cancelToken: token,
      );
      if (!_isCurrent(generation, token)) return;
      if (pageResult.page != page || pageResult.size != _pageSize) {
        throw const UrgentCabinetDiscoveryFailure(
          UrgentCabinetDiscoveryFailureKind.invalidResponse,
        );
      }
      _items = append
          ? List.unmodifiable(<UrgentCabinetDoctorCabinet>[
              ..._items,
              ..._withoutDuplicatePairs(pageResult.items, _items),
            ])
          : pageResult.items;
      _loadedPage = pageResult.page;
      _hasNext = pageResult.hasNext;
      _evaluatedAt = pageResult.evaluatedAt;
      _state = UrgentCabinetDiscoveryLoadState.loaded;
      _failure = null;
      notifyListeners();
    } catch (error) {
      final failure = UrgentCabinetDiscoveryFailure.from(error);
      if (!_isCurrent(generation, token) || failure.isCancelled) return;
      _state = UrgentCabinetDiscoveryLoadState.error;
      _failure = failure;
      if (!append) _items = const [];
      notifyListeners();
    }
  }

  UrgentCabinetDiscoveryCriteria _criteria(int page) {
    final specialty = _filters.specialties.length == 1
        ? _filters.specialties.single
        : null;
    final distanceMeters = canUseDistance
        ? _filters.maximumDistanceKm == null
              ? null
              : (_filters.maximumDistanceKm! * 1000).round()
        : null;
    return UrgentCabinetDiscoveryCriteria(
      query: _query,
      specialty: specialty,
      governorate: _filters.governorate,
      city: _filters.city,
      position: canUseDistance ? _position : null,
      maximumDistanceMeters: distanceMeters,
      sort:
          canUseDistance && _filters.sortOrder == UrgentCabinetSortOrder.nearest
          ? UrgentCabinetDiscoverySort.distance
          : UrgentCabinetDiscoverySort.name,
      page: page,
      size: _pageSize,
    );
  }

  void clearForSession() {
    if (_disposed) return;
    _sessionOwnerId = null;
    _clearTransient(notify: true);
  }

  void _clearTransient({required bool notify}) {
    _generation++;
    _debounce?.cancel();
    _requestToken?.cancel('urgent-cabinet-discovery-session-cleared');
    _requestToken = null;
    _query = '';
    _filters = UrgentCabinetDoctorFilterSnapshot.none.copyWith(
      sortOrder: UrgentCabinetSortOrder.nameAscending,
    );
    _position = null;
    _items = const [];
    _facets = null;
    _state = UrgentCabinetDiscoveryLoadState.idle;
    _failure = null;
    _evaluatedAt = null;
    _hasNext = false;
    _loadedPage = -1;
    if (notify) notifyListeners();
  }

  bool _isCurrent(int generation, CancelToken token) =>
      !_disposed && generation == _generation && !token.isCancelled;

  static Iterable<UrgentCabinetDoctorCabinet> _withoutDuplicatePairs(
    Iterable<UrgentCabinetDoctorCabinet> incoming,
    Iterable<UrgentCabinetDoctorCabinet> existing,
  ) {
    final keys = existing
        .map((item) => '${item.doctorId}/${item.practiceLocationId}')
        .toSet();
    return incoming.where(
      (item) => keys.add('${item.doctorId}/${item.practiceLocationId}'),
    );
  }

  static String? _normalize(String? value) {
    final normalized = value?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _debounce?.cancel();
    _requestToken?.cancel('urgent-cabinet-discovery-disposed');
    super.dispose();
  }
}
