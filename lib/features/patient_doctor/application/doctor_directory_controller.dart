import 'package:flutter/foundation.dart';

import '../data/doctor_models.dart';
import '../data/doctor_mock_data.dart';

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

  /// The last operation failed.
  error,
}

/// Owns the patient doctor directory state: search, filtering, and mock data.
///
/// This is a static/mock-only controller — no backend API or pagination.
/// Search operates on the local mock data. Presentation filters are applied
/// on top of the search results.
class DoctorDirectoryController extends ChangeNotifier {
  DoctorDirectoryController() : _allItems = createDoctorListItems();

  final List<DoctorListItem> _allItems;
  List<DoctorListItem> _filteredItems = const [];
  String _query = '';
  bool _hasLoaded = false;

  List<DoctorListItem> get items => _filteredItems;
  String get query => _query;
  bool get hasItems => _filteredItems.isNotEmpty;

  DoctorDirectoryStatus get status {
    if (!_hasLoaded) return DoctorDirectoryStatus.idle;
    if (_filteredItems.isEmpty) return DoctorDirectoryStatus.empty;
    return DoctorDirectoryStatus.populated;
  }

  /// Loads the initial doctor list.
  void loadFirst() {
    _hasLoaded = true;
    _applySearch();
  }

  /// Debounced search on the local doctor data.
  void search(String rawQuery) {
    _query = rawQuery.trim();
    _applySearch();
  }

  void _applySearch() {
    if (_query.isEmpty) {
      _filteredItems = List.unmodifiable(_allItems);
    } else {
      final needle = _query.toLowerCase();
      _filteredItems = List.unmodifiable(
        _allItems.where((d) {
          return d.name.toLowerCase().contains(needle) ||
              d.specialty.toLowerCase().contains(needle) ||
              (d.address?.toLowerCase().contains(needle) ?? false);
        }),
      );
    }
    notifyListeners();
  }
}
