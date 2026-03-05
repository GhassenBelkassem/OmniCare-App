import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/account_models.dart';
import 'dio_client.dart';

class AccountApi {
  final Dio _dio;

  AccountApi({Dio? dio}) : _dio = dio ?? DioClient.instance.dio;

  Future<AccountFullProfile> getFullProfile() async {
    debugPrint('[AccountApi] getFullProfile() -> GET /account/full-profile');
    final response = await _dio.get('/account/full-profile');
    print('DEBUG: Raw Backend Response: ${response.data}');
    debugPrint('[AccountApi] Response status: ${response.statusCode}');
    final raw = response.data;
    debugPrint('[AccountApi] Response runtimeType: ${raw.runtimeType}');
    debugPrint('[AccountApi] Response data (raw): $raw');

    if (raw is Map) {
      final map = raw.cast<String, dynamic>();
      final unwrapped = (map['data'] is Map)
          ? (map['data'] as Map).cast<String, dynamic>()
          : map;
      return AccountFullProfile.fromJson(unwrapped);
    }
    throw StateError('Unexpected /account/full-profile response: ${response.data}');
  }

  Future<void> patchMedicalPassport({String? bloodGroup, Map<String, dynamic>? medicalInfo}) async {
    debugPrint('[AccountApi] patchMedicalPassport() -> PATCH /account/medical-passport');

    final payload = <String, dynamic>{};
    final backendBlood = _bloodGroupToBackend(bloodGroup);
    if (backendBlood != null) {
      payload['bloodGroup'] = backendBlood;
    }
    if (medicalInfo != null) {
      payload['medicalInfo'] = medicalInfo;
    }

    debugPrint('[AccountApi] patchMedicalPassport() payload: $payload');

    await _dio.patch('/account/medical-passport', data: payload);
  }
}

String? _bloodGroupToBackend(String? ui) {
  if (ui == null) return null;
  final v = ui.trim();
  if (v.isEmpty || v == '-' || v == 'IDK') return null;
  return switch (v) {
    'A+' => 'A_POS',
    'A-' => 'A_NEG',
    'B+' => 'B_POS',
    'B-' => 'B_NEG',
    'AB+' => 'AB_POS',
    'AB-' => 'AB_NEG',
    'O+' => 'O_POS',
    'O-' => 'O_NEG',
    _ => v,
  };
}
