import '../core/api/medications_api.dart';
import '../mock_data/mock_medications.dart';

class MedicationRepository {
  MedicationsApi? _api;

  MedicationRepository({MedicationsApi? api}) : _api = api;

  void useMock() {
    _api = null;
  }

  void useApi(MedicationsApi api) {
    _api = api;
  }

  bool get isMock => _api == null;

  Future<List<MedicationSearchResult>> searchTop10(String q) async {
    if (_api == null) {
      final query = q.trim().toLowerCase();
      if (query.isEmpty) return [];
      return createMockMedications()
          .where((m) => m.name.toLowerCase().contains(query) || (m.dci?.toLowerCase().contains(query) ?? false))
          .take(10)
          .toList();
    }
    return _api!.searchTop10(q);
  }

  Future<List<String>> searchDistinctDciTop20(String q) async {
    if (_api == null) {
      final query = q.trim().toLowerCase();
      if (query.isEmpty) return [];
      return createMockMedications()
          .map((m) => m.dci ?? '')
          .where((dci) => dci.isNotEmpty && dci.toLowerCase().contains(query))
          .toSet()
          .take(20)
          .toList();
    }
    return _api!.searchDistinctDciTop20(q);
  }
}
