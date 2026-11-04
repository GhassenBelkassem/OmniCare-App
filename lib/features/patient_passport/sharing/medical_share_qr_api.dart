import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/app_http_client.dart';
import 'medical_share_qr.dart';
import 'medical_sharing_models.dart';

abstract interface class MedicalShareQrApiContract {
  Future<MedicalShareQr> issueQr(
    MedicalSharingSubject subject, {
    required String idempotencyKey,
  });
}

class MedicalShareQrApi implements MedicalShareQrApiContract {
  const MedicalShareQrApi(this._httpClient);

  final AppHttpClient _httpClient;

  @override
  Future<MedicalShareQr> issueQr(
    MedicalSharingSubject subject, {
    required String idempotencyKey,
  }) async {
    try {
      final response = await _httpClient.dio.post<dynamic>(
        '/patient/medical-sharing/qr',
        data: subject.toJson(),
        options: Options(
          contentType: Headers.jsonContentType,
          headers: {
            'Cache-Control': 'no-store',
            'Idempotency-Key': _validIdempotencyKey(idempotencyKey),
          },
        ),
      );
      return MedicalShareQr.fromJson(_object(response.data));
    } on DioException catch (error) {
      throw _safeApiException(error);
    } on FormatException catch (error) {
      throw ApiException(
        'Réponse QR invalide.',
        code: 'MALFORMED_RESPONSE',
        cause: error,
      );
    }
  }

  static String _validIdempotencyKey(String value) {
    final key = value.trim();
    if (key.isEmpty || key.length > 128) {
      throw const ApiException(
        'Identifiant de requête invalide.',
        code: 'INVALID_IDEMPOTENCY_KEY',
      );
    }
    return key;
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
      'Impossible de générer le QR médical.',
      code: code,
      statusCode: statusCode,
      cause: error,
    );
  }
}
