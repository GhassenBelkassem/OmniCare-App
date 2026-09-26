import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../data/doctor_detail_models.dart';
import '../data/doctor_directory_failure.dart';
import '../data/doctor_directory_mapper.dart';
import '../data/doctor_directory_repository.dart';
import '../data/doctor_models.dart';

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

/// Owns the patient doctor directory: the real list, search, doctor detail,
/// availability slots, and slot booking.
///
/// The list endpoint (`GET /doctors`) is not paginated, so there is no
/// "load more" path (unlike clinics). Search is debounced and cancel-safe with
/// a [CancelToken] so a slower earlier query can never overwrite a newer one.
class DoctorDirectoryController extends ChangeNotifier {
  DoctorDirectoryController({
    required DoctorDirectoryRepository repository,
    this.debounce = const Duration(milliseconds: 350),
  }) : _repository = repository;

  final DoctorDirectoryRepository _repository;

  final Duration debounce;

  static const Duration availabilityWindow = Duration(days: 14);

  // ── Directory list state ─────────────────────────────────────────────
  List<DoctorListItem> _items = const [];
  bool _isLoadingFirst = false;
  bool _hasCompletedFirstLoad = false;
  DoctorDirectoryFailure? _error;
  String _query = '';
  bool _disposed = false;

  List<DoctorListItem> get items => _items;
  bool get isLoadingFirst => _isLoadingFirst;
  DoctorDirectoryFailure? get error => _error;
  String get query => _query;
  bool get hasItems => _items.isNotEmpty;

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
  DoctorBookingResult? _lastBookingResult;

  DoctorDetail? get detail => _detail;
  bool get isLoadingDetail => _isLoadingDetail;
  bool get isNotFound => _isNotFound;
  DoctorDirectoryFailure? get detailError => _detailError;
  DoctorDirectoryFailure? get availabilityError => _availabilityError;
  bool get hasAvailabilityError => _availabilityError != null;
  DoctorBookingResult? get lastBookingResult => _lastBookingResult;

  Timer? _debounceTimer;
  CancelToken? _directoryToken;
  CancelToken? _detailToken;
  int _directoryGeneration = 0;

  /// Loads the first doctor list for [query], replacing any current list.
  Future<void> loadFirst({String? query}) async {
    final normalized = query?.trim() ?? _query;
    _query = normalized;
    _isLoadingFirst = true;
    _error = null;
    _notify();

    final generation = _nextDirectoryToken();
    final token = _directoryToken!;
    try {
      final page = await _repository.listDoctors(
        query: normalized.isEmpty ? null : normalized,
        cancelToken: token,
      );
      if (token.isCancelled || _disposed || generation != _directoryGeneration) {
        return;
      }
      _items = List.unmodifiable(page.map(toDoctorListItem));
      _hasCompletedFirstLoad = true;
      _error = null;
    } on DoctorDirectoryFailure catch (failure) {
      if (token.isCancelled || _disposed || generation != _directoryGeneration) {
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

  /// Debounced, cancel-safe search. Each call restarts the debounce window and
  /// cancels the in-flight search from any previous query.
  void search(String rawQuery) {
    _debounceTimer?.cancel();
    final next = rawQuery.trim();
    // New text is the new authoritative query immediately, even during the
    // debounce window. A prior result must not paint over it.
    _nextDirectoryToken();
    _debounceTimer = Timer(debounce, () {
      if (_disposed) return;
      unawaited(loadFirst(query: next));
    });
  }

  /// Fetches the full detail for one doctor (profile + real availability
  /// slots + next-availability label). Used by the detail screen.
  Future<void> fetchDetail(String doctorId) async {
    if (_disposed) return;
    _detailToken?.cancel('doctor-detail-superseded');
    final token = _detailToken = CancelToken();
    _isLoadingDetail = true;
    _isNotFound = false;
    _detailError = null;
    _availabilityError = null;
    _detail = null;
    _lastBookingResult = null;
    _notify();
    try {
      final dto = await _repository.getDoctor(doctorId, cancelToken: token);
      if (token.isCancelled || _disposed || token != _detailToken) return;
      _detail = buildDoctorDetail(dto);
      await _loadSlotsIntoDetail(doctorId, token);
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
    if (doctorId == null || _disposed) return;
    _detailToken?.cancel('doctor-availability-superseded');
    final token = _detailToken = CancelToken();
    _availabilityError = null;
    _notify();
    try {
      await _loadSlotsIntoDetail(doctorId, token);
    } on DoctorDirectoryFailure catch (failure) {
      if (token.isCancelled || _disposed || token != _detailToken) return;
      _availabilityError = failure;
    } finally {
      if (!token.isCancelled && !_disposed && token == _detailToken) {
        _notify();
      }
    }
  }

  Future<void> _loadSlotsIntoDetail(String doctorId, CancelToken token) async {
    final now = DateTime.now();
    final slots = await _repository.getSlots(
      doctorId: doctorId,
      from: now,
      to: now.add(availabilityWindow),
      cancelToken: token,
    );
    if (token.isCancelled || _disposed || token != _detailToken) return;
    final days = groupAvailabilitySlots(slots);
    _detail = attachAvailability(_detail!, days);
  }

  /// Books a slot using the exact backend start/end instants.
  Future<DoctorBookingResult> bookSlot({
    required String doctorId,
    required DoctorAvailabilitySlot slot,
    String? notes,
  }) async {
    final result = await _repository.bookAppointment(
      doctorId: doctorId,
      startTime: slot.startIso,
      endTime: slot.endIso,
      notes: notes,
    );
    _lastBookingResult = result;
    _notify();
    return result;
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