import 'package:dio/dio.dart';

import '../../../core/network/app_http_client.dart';
import '../../../core/network/request_replay_policy.dart';
import 'clinical_record.dart';

abstract interface class ClinicalRecordApiContract {
  Future<ClinicalRecordEnvelope> read(String consultationId);

  Future<ClinicalRecordEnvelope> save({
    required String consultationId,
    required int expectedClinicalRecordVersion,
    required String idempotencyKey,
    required ClinicalRecordDraft record,
  });
}

class ClinicalRecordApi implements ClinicalRecordApiContract {
  const ClinicalRecordApi(this._httpClient);

  final AppHttpClient _httpClient;

  @override
  Future<ClinicalRecordEnvelope> read(String consultationId) async {
    final response = await _httpClient.dio.get<dynamic>(
      '/doctor/consultations/${consultationId.trim()}/clinical-record',
    );
    return ClinicalRecordEnvelope.fromJson(_object(response.data));
  }

  @override
  Future<ClinicalRecordEnvelope> save({
    required String consultationId,
    required int expectedClinicalRecordVersion,
    required String idempotencyKey,
    required ClinicalRecordDraft record,
  }) async {
    final response = await _httpClient.dio.put<dynamic>(
      '/doctor/consultations/${consultationId.trim()}/clinical-record',
      data: {
        'expectedClinicalRecordVersion': expectedClinicalRecordVersion,
        'clinicalRecord': record.toJson(),
      },
      options: Options(
        headers: {'Idempotency-Key': idempotencyKey},
        extra: requestReplayExtra(RequestReplayPolicy.declaredIdempotentWrite),
      ),
    );
    return ClinicalRecordEnvelope.fromJson(_object(response.data));
  }

  static Map<String, dynamic> _object(Object? value) {
    if (value is! Map) {
      throw const FormatException('Invalid clinical record response.');
    }
    return value.cast<String, dynamic>();
  }
}
