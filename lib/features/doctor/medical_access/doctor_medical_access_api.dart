import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/app_http_client.dart';
import 'doctor_medical_access.dart';

abstract interface class DoctorMedicalAccessApiContract {
  Future<DoctorMedicalAccessActivation> consumeQr({
    required String consultationId,
    required String qrPayload,
    required String idempotencyKey,
  });
}

class DoctorMedicalAccessApi implements DoctorMedicalAccessApiContract {
  const DoctorMedicalAccessApi(this._httpClient);

  final AppHttpClient _httpClient;

  @override
  Future<DoctorMedicalAccessActivation> consumeQr({
    required String consultationId,
    required String qrPayload,
    required String idempotencyKey,
  }) async {
    final canonicalConsultationId = consultationId.trim();
    final payload = qrPayload.trim();
    final key = idempotencyKey.trim();
    if (canonicalConsultationId.isEmpty || payload.isEmpty || key.isEmpty) {
      throw const ApiException(
        'Requête de lecture invalide.',
        code: 'INVALID_INPUT',
      );
    }
    try {
      final response = await _httpClient.dio.post<dynamic>(
        '/doctor/consultations/${Uri.encodeComponent(canonicalConsultationId)}'
        '/medical-access/qr/consume',
        data: {'qrPayload': payload},
        options: Options(
          contentType: Headers.jsonContentType,
          headers: {'Cache-Control': 'no-store', 'Idempotency-Key': key},
        ),
      );
      final activation = DoctorMedicalAccessActivation.fromJson(
        _object(response.data),
      );
      if (activation.consultationId != canonicalConsultationId) {
        throw const FormatException('Consultation binding mismatch.');
      }
      return activation;
    } on DioException catch (error) {
      throw _safeApiException(error);
    } on FormatException catch (error) {
      throw ApiException(
        'Réponse d’activation invalide.',
        code: 'MALFORMED_RESPONSE',
        cause: error,
      );
    }
  }

  static Map<String, dynamic> _object(Object? data) {
    if (data is! Map) throw const FormatException('Expected JSON object.');
    return data.cast<String, dynamic>();
  }

  static ApiException _safeApiException(DioException error) {
    final statusCode = error.response?.statusCode;
    final data = error.response?.data;
    String? code;
    if (data is Map) {
      code = (data['errorCode'] ?? data['code'])?.toString();
    }
    code ??= statusCode == 401 ? 'UNAUTHORIZED' : 'MRS_UNAVAILABLE';
    return ApiException(
      'Impossible d’activer l’accès médical.',
      code: code,
      statusCode: statusCode,
      cause: error,
    );
  }
}
