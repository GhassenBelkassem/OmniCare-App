import 'package:dio/dio.dart';

import 'dio_client.dart';

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
    return f.contains('soluble') || f.contains('efferves') || f.contains('orodispers') || f.contains('dispers');
  }
}

class MedicationsApi {
  final Dio _dio;

  MedicationsApi({Dio? dio}) : _dio = dio ?? DioClient.instance.dio;

  Future<List<MedicationSearchResult>> searchTop10(String q) async {
    final trimmed = q.trim();
    if (trimmed.isEmpty) return const [];

    final res = await _dio.get(
      '/medications/search',
      queryParameters: {'q': trimmed},
    );

    final data = res.data;
    if (data is List) {
      return data
          .whereType<Map>()
          .map((e) => MedicationSearchResult.fromJson(e.cast<String, dynamic>()))
          .where((e) => e.id.isNotEmpty && e.name.trim().isNotEmpty)
          .toList();
    }

    throw StateError('Unexpected /medications/search response: $data');
  }

  Future<List<String>> searchDistinctDciTop20(String q) async {
    final trimmed = q.trim();
    if (trimmed.isEmpty) return const [];

    final res = await _dio.get(
      '/medications/dci',
      queryParameters: {'q': trimmed},
    );

    final data = res.data;
    if (data is List) {
      return data.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
    }

    throw StateError('Unexpected /medications/dci response: $data');
  }
}
