import 'package:dio/dio.dart';

import '../api/dio_client.dart';
import '../models/consultation.dart';

class ConsultationsApi {
  final Dio _dio;

  ConsultationsApi({Dio? dio}) : _dio = dio ?? DioClient.instance.dio;

  Future<List<Consultation>> listConsultations({String? status}) async {
    final res = await _dio.get(
      '/consultations',
      queryParameters: {
        if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
      },
    );

    if (res.data is List) {
      return (res.data as List).whereType<Map>().map((e) {
        return Consultation.fromJson(Map<String, dynamic>.from(e));
      }).toList();
    }

    throw StateError('Unexpected GET /consultations response: ${res.data}');
  }

  Future<Consultation> getConsultation({required String consultationId}) async {
    final res = await _dio.get('/consultations/$consultationId');

    if (res.data is Map<String, dynamic>) {
      return Consultation.fromJson(res.data as Map<String, dynamic>);
    }

    throw StateError('Unexpected /consultations/{id} response: ${res.data}');
  }

  Future<Map<String, dynamic>> getPrescription({required String consultationId}) async {
    final res = await _dio.get('/consultations/$consultationId/prescription');

    if (res.data is Map) {
      return Map<String, dynamic>.from(res.data as Map);
    }

    throw StateError('Unexpected /consultations/{id}/prescription response: ${res.data}');
  }

  Future<Map<String, dynamic>> devAutoCompleteConsultation({
    required String consultationId,
    String? diagnosis,
    String? treatment,
    String? clinicalNotes,
  }) async {
    final payload = {
      'diagnosis': diagnosis,
      'treatment': treatment,
      'clinicalNotes': clinicalNotes,
    };

    final res = await _dio.post(
      '/auth/dev/consultations/$consultationId/auto-complete',
      data: payload,
    );

    if (res.data is Map) {
      return Map<String, dynamic>.from(res.data as Map);
    }

    throw StateError('Unexpected POST /auth/dev/consultations/{id}/auto-complete response: ${res.data}');
  }

  Future<Consultation> createConsultation({
    required String doctorId,
    String? patientId,
    required String symptoms,
    required int painLevel,
    required List<String> affectedAreas,
    required double latitude,
    required double longitude,
    String? streetAddress,
    String? apartmentSuite,
    String? city,
  }) async {
    final payload = {
      'doctorId': doctorId,
      'patientId': patientId,
      'symptoms': symptoms,
      'painLevel': painLevel,
      'affectedAreas': affectedAreas,
      'streetAddress': streetAddress,
      'apartmentSuite': apartmentSuite,
      'city': city,
      'latitude': latitude,
      'longitude': longitude,
    };

    final res = await _dio.post(
      '/consultations',
      data: payload,
    );

    if (res.data is Map<String, dynamic>) {
      return Consultation.fromJson(res.data as Map<String, dynamic>);
    }

    throw StateError('Unexpected /consultations response: ${res.data}');
  }

  Future<Consultation> patchConsultation({
    required String consultationId,
    String? status,
    String? diagnosis,
    String? treatment,
  }) async {
    final payload = {
      'status': status,
      'diagnosis': diagnosis,
      'treatment': treatment,
    };

    final res = await _dio.patch(
      '/consultations/$consultationId',
      data: payload,
    );

    if (res.data is Map<String, dynamic>) {
      return Consultation.fromJson(res.data as Map<String, dynamic>);
    }

    throw StateError('Unexpected PATCH /consultations/{id} response: ${res.data}');
  }

  Future<Consultation> completeConsultation({
    required String consultationId,
    String? diagnosis,
    String? treatment,
  }) async {
    final payload = {
      'status': null,
      'diagnosis': diagnosis,
      'treatment': treatment,
    };

    final res = await _dio.post(
      '/consultations/$consultationId/complete',
      data: payload,
    );

    if (res.data is Map<String, dynamic>) {
      return Consultation.fromJson(res.data as Map<String, dynamic>);
    }

    throw StateError('Unexpected POST /consultations/{id}/complete response: ${res.data}');
  }
}
