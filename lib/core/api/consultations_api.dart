import 'package:dio/dio.dart';

import '../api/dio_client.dart';
import '../auth/token_storage.dart';
import '../models/consultation.dart';

class ConsultationsApi {
  final Dio _dio;

  ConsultationsApi({Dio? dio}) : _dio = dio ?? DioClient.instance.dio;

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
}
