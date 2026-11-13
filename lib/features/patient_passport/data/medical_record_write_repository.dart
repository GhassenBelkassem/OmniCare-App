import 'dart:convert';

import 'package:dio/dio.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/result/result.dart';
import 'medical_record_models.dart';
import 'medical_record_write_api.dart';
import 'medical_record_write_models.dart';

/// The patient's saves of the « Dossier médical » sections, for themself or a
/// family member (G2.1-SB1). Every save:
/// - sends the section's `expectedVersion` (its version from the last read);
/// - takes its Idempotency-Key from the section's [SaveAttempt] (same content →
///   same key on « Réessayer »; dropped on success);
/// - returns a [Result]: [SectionSaved], or a failure. A 409
///   `RECORD_VERSION_CONFLICT` is a [RecordVersionConflictFailure] carrying the
///   current version.
///
/// Nothing is logged here; failures carry codes only.
class MedicalRecordWriteRepository {
  const MedicalRecordWriteRepository(this._api);

  final MedicalRecordWriteApiContract _api;

  /// [bloodType]: A+, A-, B+, B-, AB+, AB-, O+, O- or UNKNOWN (« Je ne sais pas »).
  Future<Result<SectionSaved>> saveBloodType({
    required RecordSubject subject,
    required String bloodType,
    required int expectedVersion,
    required SaveAttempt attempt,
    CancelToken? cancelToken,
  }) => _save(
    RecordSection.bloodType,
    subject,
    {'value': bloodType, 'expectedVersion': expectedVersion},
    attempt,
    cancelToken,
  );

  /// The full list of the patient's own allergies; `[]` records « Aucune ».
  Future<Result<SectionSaved>> saveAllergies({
    required RecordSubject subject,
    required List<AllergyDraft> items,
    required int expectedVersion,
    required SaveAttempt attempt,
    CancelToken? cancelToken,
  }) => _save(
    RecordSection.allergies,
    subject,
    {
      'items': [for (final item in items) item.toJson()],
      'expectedVersion': expectedVersion,
    },
    attempt,
    cancelToken,
  );

  Future<Result<SectionSaved>> saveConditions({
    required RecordSubject subject,
    required List<ConditionDraft> items,
    required int expectedVersion,
    required SaveAttempt attempt,
    CancelToken? cancelToken,
  }) => _save(
    RecordSection.conditions,
    subject,
    {
      'items': [for (final item in items) item.toJson()],
      'expectedVersion': expectedVersion,
    },
    attempt,
    cancelToken,
  );

  /// At least one of [heightCm] and [weightKg] (the server refuses neither).
  Future<Result<SectionSaved>> saveMeasurements({
    required RecordSubject subject,
    required num? heightCm,
    required num? weightKg,
    required int expectedVersion,
    required SaveAttempt attempt,
    CancelToken? cancelToken,
  }) => _save(
    RecordSection.measurements,
    subject,
    {
      'heightCm': ?heightCm,
      'weightKg': ?weightKg,
      'expectedVersion': expectedVersion,
    },
    attempt,
    cancelToken,
  );

  /// [expectedVersion] is the medications page's `listVersion`.
  Future<Result<SectionSaved>> saveDeclaredMedications({
    required RecordSubject subject,
    required List<DeclaredMedicationDraft> items,
    required int expectedVersion,
    required SaveAttempt attempt,
    CancelToken? cancelToken,
  }) => _save(
    RecordSection.declaredMedications,
    subject,
    {
      'items': [for (final item in items) item.toJson()],
      'expectedVersion': expectedVersion,
    },
    attempt,
    cancelToken,
  );

  Future<Result<SectionSaved>> _save(
    RecordSection section,
    RecordSubject subject,
    Map<String, Object?> body,
    SaveAttempt attempt,
    CancelToken? cancelToken,
  ) async {
    final key = attempt.keyFor(
      '${section.path}|${subject.queryValue}|${jsonEncode(body)}',
    );
    final result = await guardApiCall(() async {
      final Object? answer;
      try {
        answer = await _api.put(
          section,
          subject,
          body,
          idempotencyKey: key,
          cancelToken: cancelToken,
        );
      } on DioException catch (error) {
        throw versionConflictOf(error) ?? error;
      }
      if (answer is! Map<String, Object?>) {
        throw const FormatException('The response is not a JSON object');
      }
      return SectionSaved.fromJson(answer);
    });
    switch (result) {
      case Ok():
        attempt.reset();
      case Err(:final failure):
        // The key was used for other content: the next save needs a new one.
        if (failure.code == 'IDEMPOTENCY_CONFLICT') attempt.reset();
    }
    return result;
  }
}

/// A 409 `RECORD_VERSION_CONFLICT` with its `currentVersion`; `null` for any
/// other error (including a conflict body without a version, which then reads
/// as a plain conflict).
RecordVersionConflictFailure? versionConflictOf(DioException error) {
  final response = error.response;
  if (response?.statusCode != 409) return null;
  final body = response!.data;
  if (apiErrorCodeOf(body) !=
      RecordVersionConflictFailure.recordVersionConflictCode) {
    return null;
  }
  final json = body is String ? _decode(body) : body;
  final version = json is Map ? json['currentVersion'] : null;
  if (version is! int || version < 0) return null;
  return RecordVersionConflictFailure(currentVersion: version);
}

Object? _decode(String text) {
  try {
    return jsonDecode(text);
  } on FormatException {
    return null;
  }
}
