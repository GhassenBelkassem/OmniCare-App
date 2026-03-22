import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../api/dio_client.dart';
import '../models/consultation.dart';

List<Consultation> _parseConsultationsList(List<Map<String, dynamic>> items) {
  return items.map(Consultation.fromJson).toList();
}

class ConsultationsApi {
  final Dio _dio;

  static final Map<String, Future<List<Consultation>>> _inflightList =
      <String, Future<List<Consultation>>>{};
  static final Map<String, ({DateTime at, List<Consultation> data})> _cache =
      <String, ({DateTime at, List<Consultation> data})>{};

  static void invalidateListCache() {
    _cache.clear();
    _inflightList.clear();
  }

  ConsultationsApi({Dio? dio}) : _dio = dio ?? DioClient.instance.dio;

  Future<List<Consultation>> listConsultations({String? status}) async {
    final key = 'status=${(status ?? '').trim()}';

    final cached = _cache[key];
    if (cached != null) {
      final age = DateTime.now().difference(cached.at);
      if (age.inSeconds <= 30) {
        return cached.data;
      }
    }

    final inflight = _inflightList[key];
    if (inflight != null) {
      return inflight;
    }

    final future = _listConsultationsNetwork(status: status);
    _inflightList[key] = future;
    try {
      final data = await future;
      _cache[key] = (at: DateTime.now(), data: data);
      return data;
    } finally {
      _inflightList.remove(key);
    }
  }

  Future<List<Consultation>> _listConsultationsNetwork({String? status}) async {
    final res = await _dio.get(
      '/consultations',
      queryParameters: {
        if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
      },
    );

    if (res.data is List) {
      final rawList = (res.data as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);
      return compute(_parseConsultationsList, rawList);
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

  Future<Map<String, dynamic>> getPrescription({
    required String consultationId,
  }) async {
    final res = await _dio.get('/consultations/$consultationId/prescription');

    if (res.data is Map) {
      return Map<String, dynamic>.from(res.data as Map);
    }

    throw StateError(
      'Unexpected /consultations/{id}/prescription response: ${res.data}',
    );
  }

  Future<Map<String, dynamic>> putPrescription({
    required String consultationId,
    required Map<String, dynamic> payload,
  }) async {
    final id = consultationId.trim();
    if (id.isEmpty) {
      throw StateError('consultationId is required');
    }

    final res = await _dio.put(
      '/consultations/$id/prescription',
      data: payload,
    );

    invalidateListCache();

    if (res.data is Map) {
      return Map<String, dynamic>.from(res.data as Map);
    }

    throw StateError(
      'Unexpected PUT /consultations/{id}/prescription response: ${res.data}',
    );
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

    throw StateError(
      'Unexpected POST /auth/dev/consultations/{id}/auto-complete response: ${res.data}',
    );
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
    num? fee,
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
      if (fee != null) 'fee': fee,
    };

    final res = await _dio.post('/consultations', data: payload);

    invalidateListCache();

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
    num? fee,
  }) async {
    final payload = {
      'status': status,
      'diagnosis': diagnosis,
      'treatment': treatment,
      if (fee != null) 'fee': fee,
    };

    final url = '/consultations/$consultationId';
    final res = await _dio.patch(url, data: payload);

    invalidateListCache();

    if (res.data is Map<String, dynamic>) {
      return Consultation.fromJson(res.data as Map<String, dynamic>);
    }

    throw StateError(
      'Unexpected PATCH /consultations/{id} response: ${res.data}',
    );
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

    invalidateListCache();

    if (res.data is Map<String, dynamic>) {
      return Consultation.fromJson(res.data as Map<String, dynamic>);
    }

    throw StateError(
      'Unexpected POST /consultations/{id}/complete response: ${res.data}',
    );
  }
}
