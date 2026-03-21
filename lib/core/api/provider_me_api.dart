import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'dio_client.dart';
import '../models/consultation.dart';
import '../models/patient_models.dart';

List<Consultation> _parseProviderConsultationsList(
  List<Map<String, dynamic>> items,
) {
  return items.map(Consultation.fromJson).toList();
}

class ProviderMeApi {
  final Dio _dio;

  static final Map<String, Future<List<Consultation>>> _inflightConsultations =
      <String, Future<List<Consultation>>>{};
  static final Map<String, ({DateTime at, List<Consultation> data})>
  _consultationsCache = <String, ({DateTime at, List<Consultation> data})>{};

  ProviderMeApi({Dio? dio}) : _dio = dio ?? DioClient.instance.dio;

  Future<List<Consultation>> listMyConsultations({
    String? status,
    double? lat,
    double? lng,
    double? radiusKm,
  }) async {
    final key = <String>[
      'status=${(status ?? 'PENDING').trim()}',
      'lat=${lat?.toStringAsFixed(6) ?? ''}',
      'lng=${lng?.toStringAsFixed(6) ?? ''}',
      'radiusKm=${radiusKm?.toStringAsFixed(3) ?? ''}',
    ].join('&');

    final cached = _consultationsCache[key];
    if (cached != null) {
      final age = DateTime.now().difference(cached.at);
      if (age.inSeconds <= 30) {
        return cached.data;
      }
    }

    final inflight = _inflightConsultations[key];
    if (inflight != null) {
      return inflight;
    }

    final future = _listMyConsultationsNetwork(
      status: status,
      lat: lat,
      lng: lng,
      radiusKm: radiusKm,
    );

    _inflightConsultations[key] = future;
    try {
      final data = await future;
      _consultationsCache[key] = (at: DateTime.now(), data: data);
      return data;
    } finally {
      _inflightConsultations.remove(key);
    }
  }

  Future<List<Consultation>> _listMyConsultationsNetwork({
    String? status,
    double? lat,
    double? lng,
    double? radiusKm,
  }) async {
    final res = await _dio.get(
      '/providers/me/consultations',
      queryParameters: {
        'status': (status == null || status.trim().isEmpty)
            ? 'PENDING'
            : status.trim(),
        if (lat != null) 'lat': lat,
        if (lng != null) 'lng': lng,
        if (radiusKm != null) 'radiusKm': radiusKm,
      },
    );

    final raw = res.data;
    final list = (raw is Map && raw['data'] is List)
        ? (raw['data'] as List)
        : (raw is List)
        ? raw
        : null;

    if (list != null) {
      final rawList = list
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);
      return compute(_parseProviderConsultationsList, rawList);
    }

    throw StateError(
      'Unexpected GET /providers/me/consultations response: ${res.data}',
    );
  }

  Future<List<PatientSummary>> listMyPatients() async {
    final res = await _dio.get('/providers/me/patients');

    final raw = res.data;
    final list = (raw is Map && raw['data'] is List)
        ? (raw['data'] as List)
        : (raw is List)
        ? raw
        : null;

    if (list != null) {
      return list.whereType<Map>().map((e) {
        return PatientSummary.fromJson(Map<String, dynamic>.from(e));
      }).toList();
    }

    throw StateError(
      'Unexpected GET /providers/me/patients response: ${res.data}',
    );
  }
}
