import 'package:dio/dio.dart';

import '../../../core/result/result.dart';
import 'medical_record_api.dart';
import 'medical_record_models.dart';

/// The single source of the « Dossier médical » (G2-FT-3). Each read returns a
/// [Result]: the mapped value, or the parsed failure. The cards show the first
/// page only ([firstPageSize] items). Only the editor reads every medication
/// page ([editorMedications]), with a hard cap.
class MedicalRecordRepository {
  const MedicalRecordRepository(this._api);

  static const firstPageSize = 20;

  /// The editor's page size (the server caps a page at 50).
  static const editorPageSize = 50;

  /// At most this many pages per group: past this, the read fails rather than
  /// let a save drop items it never saw.
  static const editorMaxPages = 20;

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

  /// Every medication of [subject], current and past, for the editor
  /// (G2.1-A2). The declared-medications save replaces the patient's whole own
  /// list, so the editor must see each own item, including past ones beyond
  /// the first page. [MedicationSnapshot.listVersion] is the first page's: if
  /// the list changes during the read, the save gets a version conflict.
  Future<Result<MedicationSnapshot>> editorMedications(
    RecordSubject subject, {
    CancelToken? cancelToken,
  }) => guardApiCall(() async {
    final current = await _allPages(subject, 'CURRENT', cancelToken);
    final past = await _allPages(subject, 'PAST', cancelToken);
    return MedicationSnapshot(
      current: current.items,
      past: past.items,
      listVersion: current.listVersion ?? 0,
    );
  });

  Future<RecordPage<MedicationRecord>> _allPages(
    RecordSubject subject,
    String group,
    CancelToken? cancelToken,
  ) async {
    final items = <MedicationRecord>[];
    int? listVersion;
    String? cursor;
    for (var page = 0; page < editorMaxPages; page++) {
      final body = await _api.read(
        MedicalRecordResource.medications,
        subject,
        query: {'group': group, 'size': '$editorPageSize', 'cursor': ?cursor},
        cancelToken: cancelToken,
      );
      final read = RecordPage.fromJson(
        _object(body),
        MedicationRecord.fromJson,
      );
      items.addAll(read.items);
      listVersion ??= read.listVersion;
      cursor = read.nextCursor;
      if (cursor == null) {
        return RecordPage(
          items: List.unmodifiable(items),
          hasMore: false,
          listVersion: listVersion,
        );
      }
    }
    throw const FormatException('Too many medication pages for the editor');
  }

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
