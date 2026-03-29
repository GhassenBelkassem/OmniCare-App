import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../api/dio_client.dart';

class ReservationApiException implements Exception {
  final String code;
  final String message;

  ReservationApiException(this.code, this.message);

  @override
  String toString() => message;
}

List<Map<String, dynamic>> _parseReservationList(
  List<Map<String, dynamic>> items,
) {
  return items;
}

class ReservationsApi {
  final Dio _dio;

  ReservationsApi({Dio? dio}) : _dio = dio ?? DioClient.instance.dio;

  Future<Map<String, dynamic>> createReservationRequest({
    required String providerId,
    String? visitType,
    bool isEmergency = false,
    required DateTime searchStartDate,
    required DateTime searchEndDate,
    String? reason,
    required List<Map<String, dynamic>> intents,
  }) async {
    final provider = providerId.trim();
    if (provider.isEmpty) {
      throw StateError('providerId is required');
    }
    if (intents.length != 3) {
      throw StateError('Exactly 3 intents are required');
    }

    final payload = <String, dynamic>{
      'providerId': provider,
      if (visitType != null && visitType.trim().isNotEmpty)
        'visitType': visitType.trim(),
      if (isEmergency) 'isEmergency': true,
      'searchStartDate': _isoDate(searchStartDate),
      'searchEndDate': _isoDate(searchEndDate),
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      'intents': intents,
    };

    late final Response res;
    try {
      res = await _dio.post('/reservations/requests', data: payload);
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map) {
        final map = Map<String, dynamic>.from(data);
        final success = map['success'] == true;
        if (!success) {
          final code = (map['error'] ?? '').toString().trim();
          final msg = (map['message'] ?? '').toString().trim();
          if (code.isNotEmpty) {
            throw ReservationApiException(code, msg.isEmpty ? code : msg);
          }
        }
      }
      rethrow;
    }

    if (res.data is Map) {
      return Map<String, dynamic>.from(res.data as Map);
    }

    throw StateError(
      'Unexpected POST /reservations/requests response: ${res.data}',
    );
  }

  Future<List<Map<String, dynamic>>> listReservationRequests({
    String? status,
  }) async {
    final res = await _dio.get(
      '/reservations/requests',
      queryParameters: {
        if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
      },
    );

    if (res.data is List) {
      final raw = (res.data as List)
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList(growable: false);
      return compute(_parseReservationList, raw);
    }

    throw StateError(
      'Unexpected GET /reservations/requests response: ${res.data}',
    );
  }

  Future<Map<String, dynamic>> proposeSlots({
    required String requestId,
    required List<DateTime> slots,
  }) async {
    final id = requestId.trim();
    if (id.isEmpty) {
      throw StateError('requestId is required');
    }
    final cleaned = slots
        .map(
          (e) => DateTime(e.year, e.month, e.day, e.hour, e.minute, e.second),
        )
        .toSet()
        .toList(growable: false);
    if (cleaned.length != 1 && cleaned.length != 3) {
      throw StateError('Exactly 1 or 3 distinct slots are required');
    }

    final payload = <String, dynamic>{
      'slots': cleaned.map(_isoDateTimeLocal).toList(growable: false),
    };

    final res = await _dio.post(
      '/reservations/requests/$id/propose',
      data: payload,
    );

    if (res.data is Map) {
      return Map<String, dynamic>.from(res.data as Map);
    }

    throw StateError(
      'Unexpected POST /reservations/requests/$id/propose response: ${res.data}',
    );
  }
}

String _isoDate(DateTime dt) {
  final y = dt.year.toString().padLeft(4, '0');
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

String _isoDateTimeLocal(DateTime dt) {
  final y = dt.year.toString().padLeft(4, '0');
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  final hh = dt.hour.toString().padLeft(2, '0');
  final mm = dt.minute.toString().padLeft(2, '0');
  final ss = dt.second.toString().padLeft(2, '0');
  return '$y-$m-${d}T$hh:$mm:$ss';
}
