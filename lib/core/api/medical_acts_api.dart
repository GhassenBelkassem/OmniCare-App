import 'package:dio/dio.dart';

import 'dio_client.dart';

class MedicalActsApi {
  final Dio _dio;

  MedicalActsApi({Dio? dio}) : _dio = dio ?? DioClient.instance.dio;

  Future<Map<String, dynamic>> createMedicalAct({
    required String prescriptionId,
    required String actType,
    String? photoUrl,
    String? notes,
  }) async {
    final payload = <String, dynamic>{
      'prescriptionId': prescriptionId,
      'actType': actType,
      'photoUrl': photoUrl,
      'notes': notes,
    };

    final res = await _dio.post('/medical-acts', data: payload);
    final data = res.data;
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    throw StateError('Unexpected POST /medical-acts response: $data');
  }
}
