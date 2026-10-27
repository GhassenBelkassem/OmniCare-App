import 'package:dio/dio.dart';
import '../../../core/network/app_http_client.dart';
import 'consultation_finish.dart';

abstract interface class ConsultationFinishApiContract {
  Future<ConsultationOperationalState> read(String consultationId);
  Future<ConsultationOperationalState> finish({
    required String consultationId,
    required int expectedConsultationVersion,
    required int expectedClinicalRecordVersion,
    required String idempotencyKey,
  });
}

class ConsultationFinishApi implements ConsultationFinishApiContract {
  const ConsultationFinishApi(this._http);
  final AppHttpClient _http;
  @override
  Future<ConsultationOperationalState> read(String id) async =>
      ConsultationOperationalState.fromJson(
        _map(
          (await _http.dio.get<dynamic>(
            '/doctor/consultations/${id.trim()}',
          )).data,
        ),
      );
  @override
  Future<ConsultationOperationalState> finish({
    required String consultationId,
    required int expectedConsultationVersion,
    required int expectedClinicalRecordVersion,
    required String idempotencyKey,
  }) async => ConsultationOperationalState.fromJson(
    _map(
      (await _http.dio.post<dynamic>(
        '/doctor/consultations/${consultationId.trim()}/finish',
        data: {
          'expectedConsultationVersion': expectedConsultationVersion,
          'expectedClinicalRecordVersion': expectedClinicalRecordVersion,
        },
        options: Options(headers: {'Idempotency-Key': idempotencyKey}),
      )).data,
    ),
  );
  static Map<String, dynamic> _map(Object? value) {
    if (value is! Map) {
      throw const FormatException('Invalid Consultation response.');
    }
    return value.cast<String, dynamic>();
  }
}
