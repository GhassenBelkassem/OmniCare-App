import 'package:dio/dio.dart';

import '../../../core/network/app_http_client.dart';
import '../../../core/network/request_replay_policy.dart';
import 'medical_record_models.dart';
import 'medical_record_write_models.dart';

/// HTTP access to `PUT /api/v1/me/medical-record/<section>` (G2.1-SB1 §4a).
/// Returns the raw JSON body; the repository maps it. Errors propagate as
/// Dio exceptions.
abstract interface class MedicalRecordWriteApiContract {
  Future<Object?> put(
    RecordSection section,
    RecordSubject subject,
    Map<String, Object?> body, {
    required String idempotencyKey,
    CancelToken? cancelToken,
  });
}

class MedicalRecordWriteApi implements MedicalRecordWriteApiContract {
  const MedicalRecordWriteApi(this._httpClient);

  static const path = '/me/medical-record';

  final AppHttpClient _httpClient;

  @override
  Future<Object?> put(
    RecordSection section,
    RecordSubject subject,
    Map<String, Object?> body, {
    required String idempotencyKey,
    CancelToken? cancelToken,
  }) async {
    final response = await _httpClient.dio.put<Object?>(
      '$path/${section.path}',
      queryParameters: {'subject': subject.queryValue},
      data: body,
      cancelToken: cancelToken,
      options: Options(
        headers: {
          'Idempotency-Key': idempotencyKey,
          'Cache-Control': 'no-store',
        },
        // Same key, same body: safe to send again after a token refresh.
        extra: requestReplayExtra(RequestReplayPolicy.declaredIdempotentWrite),
      ),
    );
    return response.data;
  }
}
