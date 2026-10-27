import 'package:dio/dio.dart';
import '../../../core/network/app_http_client.dart';
import 'prescription.dart';

abstract interface class PrescriptionApiContract {
  Future<PrescriptionEnvelope> read(String consultationId);
  Future<PrescriptionEnvelope> save({
    required String consultationId,
    required int expectedPrescriptionVersion,
    required String idempotencyKey,
    required PrescriptionDraft prescription,
  });
  Future<PrescriptionEnvelope> finalize({
    required String consultationId,
    required int expectedPrescriptionVersion,
    required int expectedClinicalRecordVersion,
    required String idempotencyKey,
  });
}

class PrescriptionApi implements PrescriptionApiContract {
  const PrescriptionApi(this._http);
  final AppHttpClient _http;
  @override
  Future<PrescriptionEnvelope> read(String id) async =>
      PrescriptionEnvelope.fromJson(
        _object(
          (await _http.dio.get<dynamic>(
            '/doctor/consultations/${id.trim()}/prescription',
          )).data,
        ),
      );
  @override
  Future<PrescriptionEnvelope> save({
    required String consultationId,
    required int expectedPrescriptionVersion,
    required String idempotencyKey,
    required PrescriptionDraft prescription,
  }) async => PrescriptionEnvelope.fromJson(
    _object(
      (await _http.dio.put<dynamic>(
        '/doctor/consultations/${consultationId.trim()}/prescription',
        data: {
          'expectedPrescriptionVersion': expectedPrescriptionVersion,
          'prescription': prescription.toJson(),
        },
        options: Options(headers: {'Idempotency-Key': idempotencyKey}),
      )).data,
    ),
  );
  @override
  Future<PrescriptionEnvelope> finalize({
    required String consultationId,
    required int expectedPrescriptionVersion,
    required int expectedClinicalRecordVersion,
    required String idempotencyKey,
  }) async => PrescriptionEnvelope.fromJson(
    _object(
      (await _http.dio.post<dynamic>(
        '/doctor/consultations/${consultationId.trim()}/prescription/finalize',
        data: {
          'expectedPrescriptionVersion': expectedPrescriptionVersion,
          'expectedClinicalRecordVersion': expectedClinicalRecordVersion,
          'confirmation': true,
        },
        options: Options(headers: {'Idempotency-Key': idempotencyKey}),
      )).data,
    ),
  );
  static Map<String, dynamic> _object(Object? value) {
    if (value is! Map) {
      throw const FormatException('Invalid prescription response.');
    }
    return value.cast<String, dynamic>();
  }
}
