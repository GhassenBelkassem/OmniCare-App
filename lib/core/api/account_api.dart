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
}
