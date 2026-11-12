import '../network/api_failure.dart';

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

/// Medication catalog search.
///
/// There is no usable backend catalog yet (P0 F4), and the former local mock
/// list is cut off from production (G-2 1b-3): every search fails with
/// [ApiFailure.featureUnavailable]. Callers keep their own state; the search
/// field simply shows no suggestions.
class MedicationsApi {
  MedicationsApi({Object? dio});

  Future<List<MedicationSearchResult>> searchTop10(String q) async {
    if (q.trim().isEmpty) return const [];
    throw ApiFailure.featureUnavailable;
  }

  Future<List<String>> searchDistinctDciTop20(String q) async {
    if (q.trim().isEmpty) return const [];
    throw ApiFailure.featureUnavailable;
  }
}
