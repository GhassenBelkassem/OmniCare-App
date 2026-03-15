import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/patient_models.dart';
import 'dio_client.dart';

class PatientsApi {
  final Dio _dio;

  PatientsApi({Dio? dio}) : _dio = dio ?? DioClient.instance.dio;

  Future<List<PatientSummary>> getPatients() async {
    debugPrint('[PatientsApi] getPatients() -> GET /api/patients');
    final response = await _dio.get('/patients');
    debugPrint('[PatientsApi] Response status: ${response.statusCode}');

    final raw = response.data;

    if (raw is Map && raw['data'] is List) {
      final list = (raw['data'] as List);
      return list
          .whereType<Map>()
          .map((e) => PatientSummary.fromJson(e.cast<String, dynamic>()))
          .toList();
    } else if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => PatientSummary.fromJson(e.cast<String, dynamic>()))
          .toList();
    }

    throw StateError('Unexpected /api/patients response: ${response.data}');
  }

  Future<List<PatientSummary>> getPatientsForDoctor() async {
    debugPrint(
      '[PatientsApi] getPatientsForDoctor() -> GET /api/patients/doctor',
    );
    final response = await _dio.get('/patients/doctor');
    debugPrint('[PatientsApi] Response status: ${response.statusCode}');

    final raw = response.data;

    if (raw is Map && raw['data'] is List) {
      final list = (raw['data'] as List);
      return list
          .whereType<Map>()
          .map((e) => PatientSummary.fromJson(e.cast<String, dynamic>()))
          .toList();
    } else if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => PatientSummary.fromJson(e.cast<String, dynamic>()))
          .toList();
    }

    throw StateError(
      'Unexpected /api/patients/doctor response: ${response.data}',
    );
  }
}
