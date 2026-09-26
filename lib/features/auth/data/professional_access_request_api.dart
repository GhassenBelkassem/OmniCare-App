import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
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
      final body = error.response?.data;
      if (body is Map) {
        final json = body.cast<String, dynamic>();
        throw ApiException(
          json['message']?.toString() ?? 'Impossible d’envoyer la demande.',
          code: json['code']?.toString(),
          statusCode: error.response?.statusCode,
          fieldErrors: (json['fieldErrors'] is Map)
              ? (json['fieldErrors'] as Map).map(
                  (key, value) => MapEntry(key.toString(), value.toString()),
                )
              : const {},
          cause: error,
        );
      }
      throw ApiException(
        'Impossible d’envoyer la demande. Vérifiez votre connexion.',
        code: 'NETWORK_REQUEST_FAILED',
        statusCode: error.response?.statusCode,
        cause: error,
      );
    }
  }
}
