import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../data/patient_clinic_failure.dart';
import '../data/patient_clinic_models.dart';
import '../data/patient_clinic_repository.dart';

/// Lifecycle of the patient clinic directory.
enum PatientClinicDirectoryStatus {
  /// Nothing loaded yet.
  idle,

  /// Loading the first page (or the first page of a new search).
  loadingFirst,

  /// Appending the next page.
  loadingMore,

  /// At least one clinic is shown.
  populated,

  /// A first page returned zero clinics (or zero search hits).
  empty,

  /// The last operation failed.
  error,
}

/// Owns the patient clinic directory: the first page, subsequent pages, and
/// debounced, cancel-safe search.
///
/// Pagination uses the backend `Slice` directly — there is no "load
/// everything" path. Stale search requests are cancelled with a [CancelToken]
/// so a slower earlier query can never overwrite a newer one. A single-shot
/// debounce [Timer] (not a periodic timer) prevents a request per keystroke.
class PatientClinicDirectoryController extends ChangeNotifier {
  PatientClinicDirectoryController({
    required PatientClinicRepository repository,
    int pageSize = 20,
    this.debounce = const Duration(milliseconds: 350),
  }) : _repository = repository,
       pageSize = pageSize < 1
           ? 1
           : pageSize > maxPageSize
           ? maxPageSize
           : pageSize;

  final PatientClinicRepository _repository;

  final int pageSize;
  final Duration debounce;

  static const int maxPageSize = 50;

  List<PatientClinicListItem> _items = const [];
  int _page = 0;
  bool _hasNext = false;
  bool _isLoadingFirst = false;
  bool _isLoadingMore = false;
  bool _hasCompletedFirstLoad = false;
  PatientClinicFailure? _error;
  String _query = '';
  bool _disposed = false;

  List<PatientClinicListItem> get items => _items;
  bool get hasNext => _hasNext;
  bool get isLoadingFirst => _isLoadingFirst;
  bool get isLoadingMore => _isLoadingMore;
  PatientClinicFailure? get error => _error;
  String get query => _query;
  bool get hasItems => _items.isNotEmpty;

  PatientClinicDetail? _detail;
  bool _isLoadingDetail = false;
  PatientClinicFailure? _detailError;

  PatientClinicDetail? get detail => _detail;
  bool get isLoadingDetail => _isLoadingDetail;
  PatientClinicFailure? get detailError => _detailError;

  PatientClinicDirectoryStatus get status {
    if (!_hasCompletedFirstLoad && !_isLoadingFirst && _error == null) {
      return PatientClinicDirectoryStatus.idle;
    }
    if (_isLoadingFirst && _items.isEmpty) {
      return PatientClinicDirectoryStatus.loadingFirst;
    }
    if (_isLoadingMore) return PatientClinicDirectoryStatus.loadingMore;
    if (_error != null && _items.isEmpty) {
      return PatientClinicDirectoryStatus.error;
    }
    if (_items.isEmpty) return PatientClinicDirectoryStatus.empty;
    return PatientClinicDirectoryStatus.populated;
  }

  Timer? _debounceTimer;
  CancelToken? _directoryToken;
  CancelToken? _detailToken;
  int _directoryGeneration = 0;

  /// Loads the first page for [query], replacing any current list.
  Future<void> loadFirst({String? query}) async {
    final normalized = query?.trim() ?? _query;
    _query = normalized;
    _page = 0;
    _hasNext = false;
    _isLoadingFirst = true;
    _isLoadingMore = false;
    _error = null;
    _notify();

    final generation = _nextDirectoryToken();
    final token = _directoryToken!;
    try {
      final page = await _repository.listClinics(
        query: normalized.isEmpty ? null : normalized,
        page: 0,
        pageSize: pageSize,
        cancelToken: token,
      );
      if (token.isCancelled ||
          _disposed ||
          generation != _directoryGeneration) {
        return;
      }
      _items = page.items;
      _page = page.page;
      _hasNext = page.hasNext;
      _hasCompletedFirstLoad = true;
      _error = null;
    } on PatientClinicFailure catch (failure) {
      if (token.isCancelled ||
          _disposed ||
          generation != _directoryGeneration) {
        return;
      }
      _error = failure;
      _items = const [];
    } finally {
      if (!token.isCancelled &&
          !_disposed &&
          generation == _directoryGeneration) {
        _isLoadingFirst = false;
        _notify();
      }
    }
  }

  /// Appends the next page when one exists.
  Future<void> loadMore() async {
    if (_isLoadingFirst || _isLoadingMore || !_hasNext || _disposed) return;
    _isLoadingMore = true;
    _error = null;
    _notify();

    final nextPage = _page + 1;
    final generation = _nextDirectoryToken();
    final token = _directoryToken!;
    try {
      final page = await _repository.listClinics(
        query: _query.isEmpty ? null : _query,
        page: nextPage,
        pageSize: pageSize,
        cancelToken: token,
      );
      if (token.isCancelled ||
          _disposed ||
          generation != _directoryGeneration) {
        return;
      }
      _items = List.unmodifiable([..._items, ...page.items]);
      _page = page.page;
      _hasNext = page.hasNext;
    } on PatientClinicFailure catch (failure) {
      if (token.isCancelled ||
          _disposed ||
          generation != _directoryGeneration) {
        return;
      }
      _error = failure;
    } finally {
      if (!token.isCancelled &&
          !_disposed &&
          generation == _directoryGeneration) {
        _isLoadingMore = false;
        _notify();
      }
    }
  }

  /// Fetches the full detail for one clinic. Used by the detail screen.
  Future<void> fetchDetail(String clinicId) async {
    if (_disposed) return;
    _detailToken?.cancel('clinic-detail-superseded');
    final token = _detailToken = CancelToken();
    _isLoadingDetail = true;
    _detailError = null;
    _detail = null;
    _notify();
    try {
      final result = await _repository.getClinic(clinicId, cancelToken: token);
      if (token.isCancelled || _disposed || token != _detailToken) return;
      _detail = result;
    } on PatientClinicFailure catch (failure) {
      if (token.isCancelled || _disposed || token != _detailToken) return;
      _detailError = failure;
    } finally {
      if (!token.isCancelled && !_disposed && token == _detailToken) {
        _isLoadingDetail = false;
        _notify();
      }
    }
  }

  /// Debounced, cancel-safe search. Each call restarts the debounce window and
  /// cancels the in-flight search from any previous query.
  void search(String rawQuery) {
    _debounceTimer?.cancel();
    final next = rawQuery.trim();
    // New text is a new authoritative query immediately, even during the
    // debounce window. A prior result must not paint over it.
    _nextDirectoryToken();
    _debounceTimer = Timer(debounce, () {
      if (_disposed) return;
      unawaited(loadFirst(query: next));
    });
  }

  int _nextDirectoryToken() {
    _directoryGeneration++;
    _directoryToken?.cancel('clinic-directory-superseded');
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
    _directoryToken?.cancel('clinic-directory-disposed');
    _detailToken?.cancel('clinic-directory-disposed');
    super.dispose();
  }
}
