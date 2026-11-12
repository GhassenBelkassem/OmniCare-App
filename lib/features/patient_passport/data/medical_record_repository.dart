import 'package:dio/dio.dart';

import '../../../core/result/result.dart';
import 'medical_record_api.dart';
import 'medical_record_models.dart';

/// The single source of the « Dossier médical » (G2-FT-3). Each read returns a
/// [Result]: the mapped value, or the parsed failure. Lists are the first page
/// only ([firstPageSize] items); the app never fetches a whole list.
class MedicalRecordRepository {
  const MedicalRecordRepository(this._api);

  static const firstPageSize = 20;

  final MedicalRecordApiContract _api;

  Future<Result<MedicalDataRecord>> medicalData(
    RecordSubject subject, {
    CancelToken? cancelToken,
  }) => guardApiCall(() async {
    final body = await _api.read(
      MedicalRecordResource.medicalData,
      subject,
      cancelToken: cancelToken,
    );
    return MedicalDataRecord.fromJson(_object(body));
  });

  Future<Result<RecordPage<MedicationRecord>>> medications(
    RecordSubject subject, {
    required bool current,
    CancelToken? cancelToken,
  }) => guardApiCall(() async {
    final body = await _api.read(
      MedicalRecordResource.medications,
      subject,
      query: {'group': current ? 'CURRENT' : 'PAST', 'size': '$firstPageSize'},
      cancelToken: cancelToken,
    );
    return RecordPage.fromJson(_object(body), MedicationRecord.fromJson);
  });

  Future<Result<RecordPage<ConsultationRecord>>> consultations(
    RecordSubject subject, {
    CancelToken? cancelToken,
  }) => guardApiCall(() async {
    final body = await _api.read(
      MedicalRecordResource.consultations,
      subject,
      query: const {'size': '$firstPageSize'},
      cancelToken: cancelToken,
    );
    return RecordPage.fromJson(_object(body), ConsultationRecord.fromJson);
  });

  static Map<String, Object?> _object(Object? body) {
    if (body is Map<String, Object?>) return body;
    throw const FormatException('The response is not a JSON object');
  }
}
