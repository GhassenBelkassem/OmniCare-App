import 'package:dio/dio.dart';

import '../api/dio_client.dart';
import '../auth/token_storage.dart';

class DoctorsApi {
  final Dio _dio;

  DoctorsApi({Dio? dio}) : _dio = dio ?? DioClient.instance.dio;

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
}
