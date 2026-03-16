import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/patient_models.dart';
import 'dio_client.dart';
import 'provider_me_api.dart';

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

  Future<List<PatientSummary>> getPatientsForProfessional() async {
    debugPrint(
      '[PatientsApi] getPatientsForProfessional() -> GET /api/providers/me/patients',
    );
    return ProviderMeApi(dio: _dio).listMyPatients();
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

  Future<Map<String, dynamic>> getPatientPassport(String patientId) async {
    final resolved = patientId.trim();
    if (resolved.isEmpty) {
      throw ArgumentError('patientId is required');
    }

    debugPrint(
      '[PatientsApi] getPatientPassport($resolved) -> GET /api/patients/$resolved/passport',
    );
    final response = await _dio.get('/patients/$resolved/passport');
    debugPrint('[PatientsApi] Response status: ${response.statusCode}');

    final raw = response.data;
    if (raw is Map && raw['data'] is Map) {
      return (raw['data'] as Map).cast<String, dynamic>();
    }
    if (raw is Map) {
      return raw.cast<String, dynamic>();
    }

    throw StateError(
      'Unexpected /api/patients/$resolved/passport response: ${response.data}',
    );
  }
}
