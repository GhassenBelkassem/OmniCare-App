import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/app_http_client.dart';
import 'doctor_active_consultation.dart';

abstract interface class DoctorActiveConsultationApiContract {
  Future<DoctorActiveConsultation?> getActive();
}

class DoctorActiveConsultationApi
    implements DoctorActiveConsultationApiContract {
  const DoctorActiveConsultationApi(this._httpClient);

  final AppHttpClient _httpClient;

  @override
  Future<DoctorActiveConsultation?> getActive() async {
    try {
      final response = await _httpClient.dio.get<dynamic>(
        '/doctor/consultations/active',
        options: Options(headers: const {'Cache-Control': 'no-store'}),
      );
      if (response.statusCode == 204 || response.data == null) return null;
      final data = response.data;
      if (data is! Map) throw const FormatException('Expected JSON object.');
      return DoctorActiveConsultation.fromJson(data.cast<String, dynamic>());
    } on DioException catch (error) {
      throw ApiException(
        'Impossible de synchroniser la consultation active.',
        code: error.response?.statusCode == 401
            ? 'UNAUTHORIZED'
            : 'ACTIVE_CONSULTATION_UNAVAILABLE',
        statusCode: error.response?.statusCode,
        cause: error,
      );
    } on FormatException catch (error) {
      throw ApiException(
        'Réponse de consultation active invalide.',
        code: 'MALFORMED_RESPONSE',
        cause: error,
      );
    }
  }
}
