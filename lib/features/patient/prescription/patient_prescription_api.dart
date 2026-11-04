import '../../../core/network/app_http_client.dart';
import '../../doctor/prescription/prescription.dart';

class PatientPrescriptionApi {
  const PatientPrescriptionApi(this._http);
  final AppHttpClient _http;

  Future<PrescriptionEnvelope> read({
    required String consultationId,
    required String subjectType,
    String? familyMemberId,
  }) async {
    final response = await _http.dio.get<dynamic>(
      '/patient/consultations/${consultationId.trim()}/prescription',
      queryParameters: {
        'subjectType': subjectType,
        'familyMemberId': ?familyMemberId,
      },
    );
    if (response.data is! Map) {
      throw const FormatException('Invalid prescription response.');
    }
    return PrescriptionEnvelope.fromJson(
      (response.data as Map).cast<String, dynamic>(),
    );
  }
}
