import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../data/scheduled_care_failure.dart';
import '../data/scheduled_care_repository.dart';
import '../domain/patient_scheduled_care_models.dart';

enum PatientScheduledCareLoadState { initial, loading, ready, failed }

/// Server-backed owner of the Patient "Mes rendez-vous" list.
///
/// It preserves backend order, treats cursors as opaque, and deduplicates only
/// by the discriminated resource identity.
class PatientScheduledCareController extends ChangeNotifier {
  PatientScheduledCareController({
    required PatientScheduledCareRepositoryContract repository,
    this.pageSize = 20,
  }) : _repository = repository;

  final PatientScheduledCareRepositoryContract _repository;
  final int pageSize;

  PatientScheduledCareBucket _bucket = PatientScheduledCareBucket.upcoming;
  PatientScheduledCareFilters _filters = PatientScheduledCareFilters.none;
  String _query = '';
  List<PatientScheduledCareItem> _items = const [];
  String? _nextCursor;
  ScheduledCareFailure? _failure;
  PatientScheduledCareLoadState _state = PatientScheduledCareLoadState.initial;
  bool _isLoadingMore = false;
  CancelToken? _pageToken;
  int _generation = 0;
  bool _disposed = false;
  bool _realtimeActive = false;

  PatientScheduledCareBucket get bucket => _bucket;
  PatientScheduledCareFilters get filters => _filters;
  String get query => _query;
  List<PatientScheduledCareItem> get items => _items;
  String? get nextCursor => _nextCursor;
  ScheduledCareFailure? get failure => _failure;
  PatientScheduledCareLoadState get state => _state;
  bool get hasLoaded => _state != PatientScheduledCareLoadState.initial;
  bool get isLoading => _state == PatientScheduledCareLoadState.loading;
  bool get isLoadingMore => _isLoadingMore;
  bool get canLoadMore => _nextCursor != null && !_isLoadingMore && !isLoading;
  bool get realtimeActive => _realtimeActive;

  void setRealtimeActive(bool value) {
    if (!_disposed) _realtimeActive = value;
  }

  Future<void> load() => _replacePage();

  Future<void> refresh() => _replacePage();

  Future<void> setBucket(PatientScheduledCareBucket value) async {
    if (_bucket == value) return;
    _bucket = value;
    await _replacePage();
  }

  Future<void> setQuery(String value) async {
    final normalized = value.trim();
    if (_query == normalized) return;
    _query = normalized;
    await _replacePage();
  }

  Future<void> setFilters(PatientScheduledCareFilters value) async {
    if (_sameFilters(_filters, value)) return;
    _filters = value;
    await _replacePage();
  }

  Future<void> resetFilters() => setFilters(PatientScheduledCareFilters.none);

  Future<void> resetSearchAndFilters() async {
    if (_query.isEmpty && !_filters.isActive) return;
    _query = '';
    _filters = PatientScheduledCareFilters.none;
    await _replacePage();
  }

  Future<void> loadMore() async {
    final cursor = _nextCursor;
    if (_disposed || cursor == null || isLoading || _isLoadingMore) return;
    final generation = _generation;
    final token = _pageToken ??= CancelToken();
    _isLoadingMore = true;
    _failure = null;
    _notify();
    try {
      final page = await _repository.getPatientScheduledCare(
        _queryFor(cursor: cursor),
        cancelToken: token,
      );
      if (!_isCurrent(generation, token)) return;
      _items = _dedupe([..._items, ...page.items]);
      _nextCursor = page.nextCursor;
      _state = PatientScheduledCareLoadState.ready;
    } catch (error) {
      if (!_isCurrent(generation, token)) return;
      _failure = ScheduledCareFailure.from(error);
    }
    if (_isCurrent(generation, token)) {
      _isLoadingMore = false;
      _notify();
    }
  }

  Future<void> _replacePage() async {
    if (_disposed) return;
    final generation = ++_generation;
    _pageToken?.cancel('scheduled-care-query-replaced');
    final token = _pageToken = CancelToken();
    _nextCursor = null;
    _isLoadingMore = false;
    _failure = null;
    _state = PatientScheduledCareLoadState.loading;
    _notify();
    try {
      final page = await _repository.getPatientScheduledCare(
        _queryFor(),
        cancelToken: token,
      );
      if (!_isCurrent(generation, token)) return;
      _items = _dedupe(page.items);
      _nextCursor = page.nextCursor;
      _state = PatientScheduledCareLoadState.ready;
    } catch (error) {
      if (!_isCurrent(generation, token)) return;
      _items = const [];
      _nextCursor = null;
      _failure = ScheduledCareFailure.from(error);
      _state = PatientScheduledCareLoadState.failed;
    }
    if (_isCurrent(generation, token)) _notify();
  }

  PatientScheduledCareQuery _queryFor({String? cursor}) =>
      PatientScheduledCareQuery(
        bucket: _bucket,
        cursor: cursor,
        limit: pageSize,
        query: _query.isEmpty ? null : _query,
        filters: _filters,
      );

  static List<PatientScheduledCareItem> _dedupe(
    Iterable<PatientScheduledCareItem> values,
  ) {
    final seen = <String>{};
    return List.unmodifiable(
      values.where((value) => seen.add(value.identityKey)),
    );
  }

  static bool _sameFilters(
    PatientScheduledCareFilters a,
    PatientScheduledCareFilters b,
  ) =>
      a.from == b.from &&
      a.to == b.to &&
      a.subjectType == b.subjectType &&
      a.familyMemberId == b.familyMemberId &&
      a.city == b.city;

  /// Clears Patient-owned list state and invalidates every late page result.
  void clear() {
    if (_disposed) return;
    _pageToken?.cancel('scheduled-care-session-cleared');
    _generation++;
    _bucket = PatientScheduledCareBucket.upcoming;
    _filters = PatientScheduledCareFilters.none;
    _query = '';
    _items = const [];
    _nextCursor = null;
    _failure = null;
    _isLoadingMore = false;
    _state = PatientScheduledCareLoadState.initial;
    _realtimeActive = false;
    _notify();
  }

  bool _isCurrent(int generation, CancelToken token) =>
      !_disposed && !token.isCancelled && generation == _generation;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _pageToken?.cancel('scheduled-care-controller-disposed');
    super.dispose();
  }
}
