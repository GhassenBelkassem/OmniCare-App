import 'package:dio/dio.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/network/app_http_client.dart';

class ProfessionalAccessRequestApi {
  const ProfessionalAccessRequestApi(this._httpClient);

  final AppHttpClient _httpClient;

  Future<void> submit(Map<String, dynamic> request) async {
    try {
      await _httpClient.dio.post<dynamic>(
        '/professional-access-requests',
        data: request,
      );
    } on DioException catch (error) {
      // One parser for every backend error shape; no server text is kept.
      throw ApiFailure.fromDio(error);
    }
  }
}
