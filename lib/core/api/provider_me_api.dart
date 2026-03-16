import 'package:dio/dio.dart';

import 'dio_client.dart';
import '../models/consultation.dart';
import '../models/patient_models.dart';

class ProviderMeApi {
  final Dio _dio;

  ProviderMeApi({Dio? dio}) : _dio = dio ?? DioClient.instance.dio;

  Future<List<Consultation>> listMyConsultations({String? status}) async {
    final res = await _dio.get(
      '/providers/me/consultations',
      queryParameters: {
        if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
      },
    );

    if (res.data is List) {
      return (res.data as List).whereType<Map>().map((e) {
        return Consultation.fromJson(Map<String, dynamic>.from(e));
      }).toList();
    }

    throw StateError('Unexpected GET /providers/me/consultations response: ${res.data}');
  }

  Future<List<PatientSummary>> listMyPatients() async {
    final res = await _dio.get('/providers/me/patients');

    if (res.data is List) {
      return (res.data as List).whereType<Map>().map((e) {
        return PatientSummary.fromJson(Map<String, dynamic>.from(e));
      }).toList();
    }

    throw StateError('Unexpected GET /providers/me/patients response: ${res.data}');
  }
}
