import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../data/doctor_detail_models.dart';
import '../data/doctor_directory_failure.dart';
import '../data/doctor_directory_mapper.dart';
import '../data/doctor_directory_models.dart';
import '../data/doctor_directory_repository.dart';
import '../data/doctor_models.dart';
import 'doctor_discovery_context.dart';
import 'doctor_directory_filters.dart';

/// Lifecycle of the patient doctor directory.
enum DoctorDirectoryStatus {
  /// Nothing loaded yet.
  idle,

  /// Loading the first page.
  loadingFirst,

  /// At least one doctor is shown.
  populated,

  /// A search returned zero results.
  empty,

  /// The last list operation failed.
  error,
}

/// Owns the backend-authoritative patient Doctor search slice and detail flow.
class DoctorDirectoryController extends ChangeNotifier {
  DoctorDirectoryController({
    required DoctorDirectoryRepository repository,
    this.discoveryContext = DoctorDiscoveryContext.generic,
    this.debounce = const Duration(milliseconds: 350),
    this.pageSize = 20,
  }) : _repository = repository;

  final DoctorDirectoryRepository _repository;
  final DoctorDiscoveryContext discoveryContext;

  final Duration debounce;
  final int pageSize;

  static const Duration availabilityWindow = Duration(days: 14);

  // ── Directory list state ─────────────────────────────────────────────
  List<DoctorListItem> _items = const [];
  bool _isLoadingFirst = false;
  bool _isLoadingNext = false;
  bool _hasCompletedFirstLoad = false;
  bool _hasNext = false;
  int _nextPage = 0;
  DoctorDirectoryFailure? _error;
  DoctorDirectoryFailure? _nextPageError;
  String _query = '';
  DoctorFilterSnapshot _filters = DoctorFilterSnapshot.none;
  DoctorSearchLocation? _searchLocation;
  bool _disposed = false;

  List<DoctorListItem> get items => _items;
  bool get isLoadingFirst => _isLoadingFirst;
  bool get isReloading => _isLoadingFirst && _items.isNotEmpty;
  bool get isLoadingNext => _isLoadingNext;
  bool get hasNext => _hasNext;
  DoctorDirectoryFailure? get error => _error;
  DoctorDirectoryFailure? get nextPageError => _nextPageError;
  String get query => _query;
  DoctorFilterSnapshot get filters => _filters;
  bool get hasItems => _items.isNotEmpty;

  /// Creates a fresh directory session with immutable flow constraints while
  /// reusing the canonical repository and controller tuning.
  DoctorDirectoryController forDiscoveryContext(
    DoctorDiscoveryContext context,
  ) {
    return DoctorDirectoryController(
      repository: _repository,
      discoveryContext: context,
      debounce: debounce,
      pageSize: pageSize,
    );
  }

  DoctorDirectoryStatus get status {
    if (_isLoadingFirst && _items.isEmpty) {
      return DoctorDirectoryStatus.loadingFirst;
    }
    if (_error != null && _items.isEmpty) {
      return DoctorDirectoryStatus.error;
    }
    if (!_hasCompletedFirstLoad && !_isLoadingFirst) {
      return DoctorDirectoryStatus.idle;
    }
    if (_items.isEmpty) return DoctorDirectoryStatus.empty;
    return DoctorDirectoryStatus.populated;
  }

  // ── Detail state ─────────────────────────────────────────────────────
  DoctorDetail? _detail;
  bool _isLoadingDetail = false;
  bool _isNotFound = false;
  DoctorDirectoryFailure? _detailError;
  DoctorDirectoryFailure? _availabilityError;
  String? _availabilityPracticeLocationId;

  DoctorDetail? get detail => _detail;
  bool get isLoadingDetail => _isLoadingDetail;
  bool get isNotFound => _isNotFound;
  DoctorDirectoryFailure? get detailError => _detailError;
  DoctorDirectoryFailure? get availabilityError => _availabilityError;
  bool get hasAvailabilityError => _availabilityError != null;

  Timer? _debounceTimer;
  CancelToken? _directoryToken;
  CancelToken? _detailToken;
  int _directoryGeneration = 0;

  /// Resets pagination and loads page zero with current search/filter state.
  Future<void> loadFirst({String? query, bool clearItems = false}) async {
    _query = query?.trim() ?? _query;
    if (clearItems) _items = const [];
    _isLoadingFirst = true;
    _isLoadingNext = false;
    _hasNext = false;
    _nextPage = 0;
    _error = null;
    _nextPageError = null;
    _notify();

    final generation = _nextDirectoryToken();
    final token = _directoryToken!;
    try {
      final page = await _repository.searchDoctors(
        criteria: _criteriaForPage(0),
        cancelToken: token,
      );
      if (token.isCancelled ||
          _disposed ||
          generation != _directoryGeneration) {
        return;
      }
      _items = List.unmodifiable(page.content.map(toDoctorListItem));
      _hasNext = page.hasNext;
      _nextPage = page.page + 1;
      _hasCompletedFirstLoad = true;
      _error = null;
    } on DoctorDirectoryFailure catch (failure) {
      if (token.isCancelled ||
          _disposed ||
          generation != _directoryGeneration) {
        return;
      }
      _error = failure;
      _hasCompletedFirstLoad = true;
    } finally {
      if (!token.isCancelled &&
          !_disposed &&
          generation == _directoryGeneration) {
        _isLoadingFirst = false;
        _notify();
      }
    }
  }

  Future<void> applyFilters(
    DoctorFilterSnapshot filters, {
    DoctorSearchLocation? location,
  }) async {
    if (filters.maxDistanceKm != null && location == null) {
      throw ArgumentError(
        'Distance filtering requires an intentional location.',
      );
    }
    _filters = filters;
    _searchLocation = location;
    await loadFirst(clearItems: true);
  }

  Future<void> clearFilters() async {
    _filters = DoctorFilterSnapshot.none;
    _searchLocation = null;
    await loadFirst(clearItems: true);
  }

  Future<void> clearSearchAndFilters() async {
    _debounceTimer?.cancel();
    _query = '';
    _filters = DoctorFilterSnapshot.none;
    _searchLocation = null;
    await loadFirst(query: '', clearItems: true);
  }

  Future<void> refresh() => loadFirst();

  /// Loads exactly one next slice. Existing results survive page failures.
  Future<void> loadNext() async {
    if (_disposed || _isLoadingFirst || _isLoadingNext || !_hasNext) return;
    _isLoadingNext = true;
    _nextPageError = null;
    _notify();

    final generation = _directoryGeneration;
    final token = _directoryToken ??= CancelToken();
    try {
      final page = await _repository.searchDoctors(
        criteria: _criteriaForPage(_nextPage),
        cancelToken: token,
      );
      if (token.isCancelled ||
          _disposed ||
          generation != _directoryGeneration) {
        return;
      }
      final byId = <String, DoctorListItem>{
        for (final item in _items) item.id: item,
      };
      for (final dto in page.content) {
        final item = toDoctorListItem(dto);
        byId.putIfAbsent(item.id, () => item);
      }
      _items = List.unmodifiable(byId.values);
      _hasNext = page.hasNext;
      _nextPage = page.page + 1;
    } on DoctorDirectoryFailure catch (failure) {
      if (token.isCancelled ||
          _disposed ||
          generation != _directoryGeneration) {
        return;
      }
      _nextPageError = failure;
    } finally {
      if (!token.isCancelled &&
          !_disposed &&
          generation == _directoryGeneration) {
        _isLoadingNext = false;
        _notify();
      }
    }
  }

  Future<void> retryNextPage() => loadNext();

  /// Debounced, cancel-safe search. Each call restarts the debounce window and
  /// cancels the in-flight search from any previous query.
  void search(String rawQuery) {
    _debounceTimer?.cancel();
    final next = rawQuery.trim();
    // New text is the new authoritative query immediately, even during the
    // debounce window. A prior result must not paint over it.
    _nextDirectoryToken();
    _query = next;
    _isLoadingFirst = false;
    _isLoadingNext = false;
    _hasNext = false;
    _nextPageError = null;
    _notify();
    _debounceTimer = Timer(debounce, () {
      if (_disposed) return;
      unawaited(loadFirst(query: next, clearItems: true));
    });
  }

  DoctorSearchCriteria _criteriaForPage(int page) {
    return DoctorSearchCriteria(
      query: _query,
      specialty: _filters.specialty,
      governorate: _filters.governorate,
      city: _filters.city,
      location: _searchLocation,
      maxDistanceKm: _filters.maxDistanceKm,
      careCapability:
          discoveryContext.requiredCareCapability ?? _filters.careCapability,
      cnamAcceptance: _filters.cnamAccepted
          ? DoctorCoverageAcceptance.accepted
          : null,
      privateInsuranceAcceptance: _filters.privateInsuranceAccepted
          ? DoctorCoverageAcceptance.accepted
          : null,
      acceptingNewPatients: discoveryContext.requireAcceptingNewPatients
          ? true
          : _filters.acceptingNewPatients
          ? true
          : null,
      page: page,
      size: pageSize,
    );
  }

  /// Fetches the full detail for one doctor (profile + real availability
  /// slots + next-availability label). Used by the detail screen.
  Future<void> fetchDetail(
    String doctorId, {
    String? practiceLocationId,
  }) async {
    if (_disposed) return;
    _detailToken?.cancel('doctor-detail-superseded');
    final token = _detailToken = CancelToken();
    _isLoadingDetail = true;
    _isNotFound = false;
    _detailError = null;
    _availabilityError = null;
    _detail = null;
    _availabilityPracticeLocationId = _validId(practiceLocationId);
    _notify();
    try {
      final dto = await _repository.getDoctor(doctorId, cancelToken: token);
      if (token.isCancelled || _disposed || token != _detailToken) return;
      _detail = buildDoctorDetail(dto);
      final cabinetId = _availabilityPracticeLocationId;
      if (cabinetId != null) {
        await _loadSlotsIntoDetail(doctorId, cabinetId, token);
      }
    } on DoctorDirectoryFailure catch (failure) {
      if (token.isCancelled || _disposed || token != _detailToken) return;
      if (_detail == null) {
        if (failure.isNotFound) _isNotFound = true;
        _detailError = failure;
      } else {
        // The profile loaded; only the availability window failed.
        _availabilityError = failure;
      }
    } finally {
      if (!token.isCancelled && !_disposed && token == _detailToken) {
        _isLoadingDetail = false;
        _notify();
      }
    }
  }

  /// Re-fetches only the availability window for the already-loaded doctor.
  /// Used by the Disponibilités tab / sheet retry path.
  Future<void> retryFetchAvailability() async {
    final doctorId = _detail?.id;
    final cabinetId = _availabilityPracticeLocationId;
    if (doctorId == null || cabinetId == null || _disposed) return;
    _detailToken?.cancel('doctor-availability-superseded');
    final token = _detailToken = CancelToken();
    _availabilityError = null;
    _notify();
    try {
      await _loadSlotsIntoDetail(doctorId, cabinetId, token);
    } on DoctorDirectoryFailure catch (failure) {
      if (token.isCancelled || _disposed || token != _detailToken) return;
      _availabilityError = failure;
    } finally {
      if (!token.isCancelled && !_disposed && token == _detailToken) {
        _notify();
      }
    }
  }

  Future<void> fetchAvailabilityForPracticeLocation(
    String practiceLocationId,
  ) async {
    final doctorId = _detail?.id;
    final cabinetId = _validId(practiceLocationId);
    if (doctorId == null || cabinetId == null || _disposed) return;
    _availabilityPracticeLocationId = cabinetId;
    await retryFetchAvailability();
  }

  Future<void> _loadSlotsIntoDetail(
    String doctorId,
    String practiceLocationId,
    CancelToken token,
  ) async {
    final now = DateTime.now();
    final slots = await _repository.getSlots(
      doctorId: doctorId,
      practiceLocationId: practiceLocationId,
      from: now,
      to: now.add(availabilityWindow),
      cancelToken: token,
    );
    if (token.isCancelled || _disposed || token != _detailToken) return;
    final days = groupAvailabilitySlots(slots);
    _detail = attachAvailability(_detail!, days);
  }

  static String? _validId(String? value) {
    final id = value?.trim() ?? '';
    return id.isEmpty ? null : id;
  }

  int _nextDirectoryToken() {
    _directoryGeneration++;
    _directoryToken?.cancel('doctor-directory-superseded');
    _directoryToken = CancelToken();
    return _directoryGeneration;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounceTimer?.cancel();
    _directoryToken?.cancel('doctor-directory-disposed');
    _detailToken?.cancel('doctor-directory-disposed');
    super.dispose();
  }
}
