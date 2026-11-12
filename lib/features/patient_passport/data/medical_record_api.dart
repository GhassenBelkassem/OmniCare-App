import 'package:dio/dio.dart';

import '../../../core/network/app_http_client.dart';
import 'medical_record_models.dart';

/// HTTP access to `GET /api/v1/me/medical-record/*` (G2-FT-1 §5). Returns the
/// raw JSON body; the repository maps it. Errors propagate as Dio exceptions.
abstract interface class MedicalRecordApiContract {
  Future<Object?> read(
    MedicalRecordResource resource,
    RecordSubject subject, {
    Map<String, String> query,
    CancelToken? cancelToken,
  });
}

enum MedicalRecordResource {
  medicalData('medical-data'),
  medications('medications'),
  consultations('consultations');

  const MedicalRecordResource(this.pathSegment);

  final String pathSegment;
}

class MedicalRecordApi implements MedicalRecordApiContract {
  const MedicalRecordApi(this._httpClient);

  static const path = '/me/medical-record';

  final AppHttpClient _httpClient;

  @override
  Future<Object?> read(
    MedicalRecordResource resource,
    RecordSubject subject, {
    Map<String, String> query = const {},
    CancelToken? cancelToken,
  }) async {
    final response = await _httpClient.dio.get<Object?>(
      '$path/${resource.pathSegment}',
      queryParameters: {'subject': subject.queryValue, ...query},
      cancelToken: cancelToken,
      options: Options(headers: const {'Cache-Control': 'no-store'}),
    );
    return response.data;
  }
}
