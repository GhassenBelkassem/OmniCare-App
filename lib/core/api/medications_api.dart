import '../../mock_data/mock_medications.dart';

class MedicationSearchResult {
  final String id;
  final String name;
  final String? dosage;
  final String? form;
  final String? dci;
  final String? type;

  MedicationSearchResult({
    required this.id,
    required this.name,
    this.dosage,
    this.form,
    this.dci,
    this.type,
  });

  factory MedicationSearchResult.fromJson(Map<String, dynamic> json) {
    return MedicationSearchResult(
      id: (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      dosage: json['dosage']?.toString(),
      form: json['form']?.toString(),
      dci: json['dci']?.toString(),
      type: json['type']?.toString(),
    );
  }

  bool get isSoluble {
    final f = (form ?? '').toLowerCase();
    return f.contains('soluble') ||
        f.contains('efferves') ||
        f.contains('orodispers') ||
        f.contains('dispers');
  }
}

class MedicationsApi {
  MedicationsApi({Object? dio});

  Future<List<MedicationSearchResult>> searchTop10(String q) async {
    final trimmed = q.trim();
    if (trimmed.isEmpty) return const [];
    final all = createMockMedications();
    final lower = trimmed.toLowerCase();
    return all
        .where((m) =>
            m.name.toLowerCase().contains(lower) ||
            (m.dci?.toLowerCase().contains(lower) ?? false))
        .take(10)
        .toList();
  }

  Future<List<String>> searchDistinctDciTop20(String q) async {
    final trimmed = q.trim();
    if (trimmed.isEmpty) return const [];
    final all = createMockMedications();
    final lower = trimmed.toLowerCase();
    return all
        .map((m) => m.dci ?? '')
        .where((dci) => dci.toLowerCase().contains(lower))
        .toSet()
        .take(20)
        .toList();
  }
}
