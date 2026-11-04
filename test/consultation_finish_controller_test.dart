import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/features/doctor/clinical_record/clinical_record.dart';
import 'package:omnicare_mobile/features/doctor/clinical_record/clinical_record_api.dart';
import 'package:omnicare_mobile/features/doctor/clinical_record/clinical_record_controller.dart';
import 'package:omnicare_mobile/features/doctor/finish/consultation_finish.dart';
import 'package:omnicare_mobile/features/doctor/finish/consultation_finish_api.dart';
import 'package:omnicare_mobile/features/doctor/finish/consultation_finish_controller.dart';

const consultationId = '11111111-1111-4111-8111-111111111111';

void main() {
  test('blocks Finish when clinical edits exist only in memory', () async {
    final clinical = _clinical();
    clinical.update((draft) => draft.notes = 'unsaved');
    final api = _FinishApi();
    final controller = ConsultationFinishController(
      consultationId: consultationId,
      api: api,
      clinical: clinical,
    );
    await controller.load();
    await controller.finish();
    expect(controller.failureCode, 'UNSAVED_CLINICAL_CHANGES');
    expect(api.calls, isEmpty);
  });

  test('ambiguous retry preserves key and expected versions', () async {
    final clinical = _clinical();
    final api = _FinishApi(failOnce: true);
    final controller = ConsultationFinishController(
      consultationId: consultationId,
      api: api,
      clinical: clinical,
    );
    await controller.load();
    await controller.finish();
    await controller.finish();
    expect(api.calls, hasLength(2));
    expect(api.calls[1], api.calls[0]);
    expect(controller.consultation?.status, 'COMPLETED');
  });
}

ClinicalRecordController _clinical() {
  final controller = ClinicalRecordController(
    consultationId: consultationId,
    api: _ClinicalApi(),
  );
  controller.authoritative = ClinicalRecordEnvelope(
    clinicalRecordVersion: 7,
    schemaVersion: 2,
    record: ClinicalRecordDraft(),
  );
  controller.draft = controller.authoritative!.record.copy();
  return controller;
}

class _ClinicalApi implements ClinicalRecordApiContract {
  @override
  Future<ClinicalRecordEnvelope> read(String consultationId) =>
      throw UnimplementedError();
  @override
  Future<ClinicalRecordEnvelope> save({
    required String consultationId,
    required int expectedClinicalRecordVersion,
    required String idempotencyKey,
    required ClinicalRecordDraft record,
  }) => throw UnimplementedError();
}

class _FinishApi implements ConsultationFinishApiContract {
  _FinishApi({this.failOnce = false});
  bool failOnce;
  final calls = <String>[];
  final active = const ConsultationOperationalState(
    consultationId: consultationId,
    status: 'IN_PROGRESS',
    medicalAccessStatus: 'ACTIVE',
    version: 4,
  );
  @override
  Future<ConsultationOperationalState> read(String consultationId) async =>
      active;
  @override
  Future<ConsultationOperationalState> finish({
    required String consultationId,
    required int expectedConsultationVersion,
    required int expectedClinicalRecordVersion,
    required String idempotencyKey,
  }) async {
    calls.add(
      '$expectedConsultationVersion/$expectedClinicalRecordVersion/$idempotencyKey',
    );
    if (failOnce) {
      failOnce = false;
      throw DioException(requestOptions: RequestOptions(path: '/finish'));
    }
    return ConsultationOperationalState(
      consultationId: consultationId,
      status: 'COMPLETED',
      medicalAccessStatus: 'EXPIRED',
      version: 6,
    );
  }
}
