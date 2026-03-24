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

  Future<PatientPassport> getPatientPassportTyped(String patientId) async {
    final resolved = patientId.trim();
    if (resolved.isEmpty) {
      throw ArgumentError('patientId is required');
    }

    debugPrint(
      '[PatientsApi] getPatientPassportTyped($resolved) -> GET /api/patients/$resolved/passport',
    );
    final response = await _dio.get('/patients/$resolved/passport');
    debugPrint('[PatientsApi] Response status: ${response.statusCode}');

    final raw = response.data;
    if (raw is Map && raw['data'] is Map) {
      return PatientPassport.fromJson(
        (raw['data'] as Map).cast<String, dynamic>(),
      );
    }
    if (raw is Map) {
      return PatientPassport.fromJson(raw.cast<String, dynamic>());
    }

    throw StateError(
      'Unexpected /api/patients/$resolved/passport response: ${response.data}',
    );
  }

  Future<void> addPatientCondition({
    required String patientId,
    required String name,
    String? notes,
  }) async {
    final resolvedId = patientId.trim();
    final resolvedName = name.trim();
    if (resolvedId.isEmpty) {
      throw ArgumentError('patientId is required');
    }
    if (resolvedName.isEmpty) {
      throw ArgumentError('name is required');
    }

    final payload = <String, dynamic>{
      'name': resolvedName,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    };

    debugPrint(
      '[PatientsApi] addPatientCondition($resolvedId) -> POST /api/patients/$resolvedId/conditions',
    );
    await _dio.post('/patients/$resolvedId/conditions', data: payload);
  }

  Future<void> addPatientMedication({
    required String patientId,
    required String medicationId,
    String? frequency,
    String? notes,
    int? timesPerDay,
    int? durationDays,
    String? startDate,
  }) async {
    final resolvedPatientId = patientId.trim();
    final resolvedMedicationId = medicationId.trim();
    if (resolvedPatientId.isEmpty) {
      throw ArgumentError('patientId is required');
    }
    if (resolvedMedicationId.isEmpty) {
      throw ArgumentError('medicationId is required');
    }

    final payload = <String, dynamic>{
      'medicationId': resolvedMedicationId,
      if (timesPerDay != null) 'timesPerDay': timesPerDay,
      if (frequency != null && frequency.trim().isNotEmpty)
        'frequency': frequency.trim(),
      if (durationDays != null) 'durationDays': durationDays,
      if (startDate != null && startDate.trim().isNotEmpty)
        'startDate': startDate.trim(),
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    };

    debugPrint(
      '[PatientsApi] addPatientMedication($resolvedPatientId) -> POST /api/patients/$resolvedPatientId/medications',
    );
    await _dio.post('/patients/$resolvedPatientId/medications', data: payload);
  }
}
