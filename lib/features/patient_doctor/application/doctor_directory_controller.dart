import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../data/doctor_detail_models.dart';
import '../data/doctor_directory_failure.dart';
import '../data/doctor_directory_mapper.dart';
import '../data/doctor_directory_models.dart';
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
/// Cabinet-scoped availability slots, and legacy booking compatibility.
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
  PracticeLocation? _selectedPracticeLocation;
  DateTime? _availabilityMonth;
  bool _isLoadingAvailability = false;

  DoctorDetail? get detail => _detail;
  bool get isLoadingDetail => _isLoadingDetail;
  bool get isNotFound => _isNotFound;
  DoctorDirectoryFailure? get detailError => _detailError;
  DoctorDirectoryFailure? get availabilityError => _availabilityError;
  bool get hasAvailabilityError => _availabilityError != null;
  DoctorBookingResult? get lastBookingResult => _lastBookingResult;
  PracticeLocation? get selectedPracticeLocation => _selectedPracticeLocation;
  DateTime? get availabilityMonth => _availabilityMonth;
  bool get isLoadingAvailability => _isLoadingAvailability;

  Timer? _debounceTimer;
  CancelToken? _directoryToken;
  CancelToken? _detailToken;
  CancelToken? _availabilityToken;
  int _directoryGeneration = 0;
  int _availabilityGeneration = 0;

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
      if (token.isCancelled ||
          _disposed ||
          generation != _directoryGeneration) {
        return;
      }
      _items = List.unmodifiable(page.map(toDoctorListItem));
      _hasCompletedFirstLoad = true;
      _error = null;
    } on DoctorDirectoryFailure catch (failure) {
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
    _availabilityToken?.cancel('doctor-detail-superseded');
    _availabilityGeneration++;
    final token = _detailToken = CancelToken();
    _isLoadingDetail = true;
    _isNotFound = false;
    _detailError = null;
    _availabilityError = null;
    _detail = null;
    _selectedPracticeLocation = null;
    _availabilityMonth = null;
    _lastBookingResult = null;
    _notify();
    try {
      final dto = await _repository.getDoctor(doctorId, cancelToken: token);
      if (token.isCancelled || _disposed || token != _detailToken) return;
      _detail = buildDoctorDetail(dto);
      final locations = _detail!.practiceLocations;
      if (locations.isNotEmpty) {
        _selectedPracticeLocation = locations.firstWhere(
          (location) => location.primary,
          orElse: () => locations.first,
        );
        await fetchAvailabilityForMonth(tunisCalendarMonth(DateTime.now()));
      }
    } on DoctorDirectoryFailure catch (failure) {
      if (token.isCancelled || _disposed || token != _detailToken) return;
      if (_detail == null) {
        if (failure.isNotFound) _isNotFound = true;
        _detailError = failure;
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
    await fetchAvailabilityForMonth(
      _availabilityMonth ?? tunisCalendarMonth(DateTime.now()),
    );
  }

  /// Selects an exact backend Cabinet and refreshes the visible month.
  Future<void> selectPracticeLocation(PracticeLocation location) async {
    final detail = _detail;
    if (_disposed || detail == null) return;
    final authoritative = detail.practiceLocations.where(
      (candidate) =>
          candidate.practiceLocationId == location.practiceLocationId,
    );
    if (authoritative.isEmpty) return;
    _selectedPracticeLocation = authoritative.single;
    _detail = attachAvailability(detail, const []);
    _notify();
    await fetchAvailabilityForMonth(
      _availabilityMonth ?? tunisCalendarMonth(DateTime.now()),
    );
  }

  /// Fetches exactly the displayed Africa/Tunis calendar month. A generation
  /// guard prevents a slow older month from replacing the active month.
  Future<void> fetchAvailabilityForMonth(
    DateTime month, {
    DateTime? now,
  }) async {
    final detail = _detail;
    final location = _selectedPracticeLocation;
    if (_disposed || detail == null || location == null) return;

    final requestedMonth = DateTime(month.year, month.month);
    final range = availabilityRangeForMonth(
      requestedMonth,
      now: now ?? DateTime.now().toUtc(),
    );
    final generation = ++_availabilityGeneration;
    _availabilityToken?.cancel('doctor-availability-superseded');
    final token = _availabilityToken = CancelToken();
    _availabilityMonth = requestedMonth;
    _isLoadingAvailability = true;
    _availabilityError = null;
    _notify();
    try {
      final response = await _repository.getSlots(
        doctorId: detail.id,
        practiceLocationId: location.practiceLocationId,
        from: range.from,
        to: range.to,
        cancelToken: token,
      );
      if (token.isCancelled ||
          _disposed ||
          generation != _availabilityGeneration) {
        return;
      }
      if (response.doctorId != detail.id ||
          response.practiceLocationId != location.practiceLocationId ||
          response.timezone != location.timezone) {
        throw const DoctorContractException(
          'Availability context does not match the selected Cabinet.',
        );
      }
      _detail = attachAvailability(
        _detail!,
        groupAvailabilitySlots(response.slots),
      );
    } on DoctorDirectoryFailure catch (failure) {
      if (token.isCancelled ||
          _disposed ||
          generation != _availabilityGeneration) {
        return;
      }
      _availabilityError = failure;
    } on DoctorContractException catch (error) {
      if (token.isCancelled ||
          _disposed ||
          generation != _availabilityGeneration) {
        return;
      }
      _availabilityError = DoctorDirectoryFailure.from(error);
    } finally {
      if (!token.isCancelled &&
          !_disposed &&
          generation == _availabilityGeneration) {
        _isLoadingAvailability = false;
        _notify();
      }
    }
  }

  /// Books a slot using the exact backend start/end instants.
  @Deprecated('Compatibility only. Scheduled patient care creates a request.')
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
    _availabilityToken?.cancel('doctor-directory-disposed');
    super.dispose();
  }
}

class AvailabilityRange {
  const AvailabilityRange({required this.from, required this.to});

  final DateTime from;
  final DateTime to;
}

/// Builds an absolute request range from Africa/Tunis month boundaries.
/// Tunisia's scheduling horizon uses UTC+01:00; the backend remains the final
/// authority for all slot and minimum-notice validation.
AvailabilityRange availabilityRangeForMonth(
  DateTime displayedMonth, {
  required DateTime now,
}) {
  final utcNow = now.toUtc();
  final tunisNow = utcNow.add(const Duration(hours: 1));
  final isCurrent =
      displayedMonth.year == tunisNow.year &&
      displayedMonth.month == tunisNow.month;
  final monthStart = DateTime.utc(
    displayedMonth.year,
    displayedMonth.month,
  ).subtract(const Duration(hours: 1));
  final nextMonth = DateTime.utc(
    displayedMonth.year,
    displayedMonth.month + 1,
  ).subtract(const Duration(hours: 1));
  final from = isCurrent ? utcNow : monthStart;
  final maximumTo = from.add(const Duration(days: 31));
  final to = nextMonth.isAfter(maximumTo) ? maximumTo : nextMonth;
  if (!from.isBefore(to)) {
    throw const DoctorContractException('Availability range is empty.');
  }
  return AvailabilityRange(from: from, to: to);
}

DateTime tunisCalendarMonth(DateTime instant) {
  final tunis = instant.toUtc().add(const Duration(hours: 1));
  return DateTime(tunis.year, tunis.month);
}
