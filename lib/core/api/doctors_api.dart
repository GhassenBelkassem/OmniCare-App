import 'package:dio/dio.dart';

import '../api/dio_client.dart';
import '../auth/token_storage.dart';

class DoctorsApi {
  final Dio _dio;

  DoctorsApi({Dio? dio}) : _dio = dio ?? DioClient.instance.dio;

  Future<Map<String, dynamic>> getMyProfile() async {
    final res = await _dio.get('/doctor/profile');
    final data = res.data;
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    throw StateError('Unexpected GET /doctor/profile response: $data');
  }

  Future<List<Map<String, dynamic>>> listDoctors() async {
    final jwt = await TokenStorage.readJwt();
    if (jwt == null || jwt.isEmpty) {
      throw StateError('Missing JWT. Please login first.');
    }

    final res = await _dio.get(
      '/doctors',
      options: Options(headers: {'Authorization': 'Bearer $jwt'}),
    );

    final data = res.data;
    if (data is List) {
      return data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }

    throw StateError('Unexpected /doctors response: $data');
  }

  Future<List<Map<String, dynamic>>> getDoctors() async {
    final raw = await listDoctors();
    return raw
        .map((d) {
          final providerId = d['providerId']?.toString();
          return <String, dynamic>{
            'id': providerId ?? d['doctorId']?.toString() ?? '',
            'name': d['name']?.toString() ?? '',
            'specialty': d['specialty']?.toString() ?? '',
            'rating': d['rating'],
            'totalReviews': d['totalReviews'],
            'officeConsultationFee': d['officeConsultationFee'],
            'experienceYears': d['experienceYears'],
            'isOnline': d['isOnline'],
          };
        })
        .toList(growable: false);
  }
}
