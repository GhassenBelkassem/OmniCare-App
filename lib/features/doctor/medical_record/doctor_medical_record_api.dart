import 'package:dio/dio.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/app_http_client.dart';
import 'doctor_medical_record_workspace.dart';

abstract interface class DoctorMedicalRecordApiContract {
  Future<DoctorMedicalRecordWorkspace> read(String consultationId);
}

class DoctorMedicalRecordApi implements DoctorMedicalRecordApiContract {
  const DoctorMedicalRecordApi(this._httpClient);

  final AppHttpClient _httpClient;

  @override
  Future<DoctorMedicalRecordWorkspace> read(String consultationId) async {
    try {
      final response = await _httpClient.dio.get<dynamic>(
        '/doctor/consultations/$consultationId/medical-record',
        options: Options(headers: const {'Cache-Control': 'no-store'}),
      );
      final data = response.data;
      if (data is! Map) throw const FormatException('Expected JSON object.');
      final workspace = DoctorMedicalRecordWorkspace.fromJson(
        data.cast<String, dynamic>(),
      );
      if (workspace.consultationId != consultationId) {
        throw const FormatException('Consultation mismatch.');
      }
      return workspace;
    } on DioException catch (error) {
      final body = error.response?.data;
      final code = body is Map && body['errorCode'] is String
          ? body['errorCode'] as String
          : 'MRS_UNAVAILABLE';
      throw ApiException(
        'Le dossier médical est indisponible.',
        code: code,
        statusCode: error.response?.statusCode,
        cause: error,
      );
    } on FormatException catch (error) {
      throw ApiException(
        'Réponse de dossier médical invalide.',
        code: 'MALFORMED_RESPONSE',
        cause: error,
      );
    }
  }
}
