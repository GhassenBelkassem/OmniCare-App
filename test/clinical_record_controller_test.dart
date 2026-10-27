import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/features/doctor/clinical_record/clinical_record.dart';
import 'package:omnicare_mobile/features/doctor/clinical_record/clinical_record_api.dart';
import 'package:omnicare_mobile/features/doctor/clinical_record/clinical_record_controller.dart';
import 'package:omnicare_mobile/features/scheduled_care/realtime/scheduled_care_event.dart';

const consultationId = '11111111-1111-4111-8111-111111111111';

void main() {
  test(
    'save sends expected clinical version and updates only on success',
    () async {
      final api = _FakeClinicalRecordApi();
      final controller = ClinicalRecordController(
        consultationId: consultationId,
        api: api,
      );
      await controller.load();
      controller.update((draft) => draft.notes = 'local note');

      await controller.save();

      expect(api.expectedVersions, [3]);
      expect(controller.authoritative?.clinicalRecordVersion, 4);
      expect(controller.dirty, isFalse);
      controller.dispose();
    },
  );

  test(
    'ambiguous failure preserves draft and retries with the same key',
    () async {
      final api = _FakeClinicalRecordApi()..failAmbiguouslyOnce = true;
      final controller = ClinicalRecordController(
        consultationId: consultationId,
        api: api,
      );
      await controller.load();
      controller.update((draft) => draft.assessment = 'unsaved assessment');

      await controller.save();
      expect(controller.authoritative?.clinicalRecordVersion, 3);
      expect(controller.draft.assessment, 'unsaved assessment');
      final firstKey = api.keys.single;

      await controller.save();
      expect(api.keys.last, firstKey);
      expect(controller.authoritative?.clinicalRecordVersion, 4);
      controller.dispose();
    },
  );

  test(
    'conflict and realtime invalidation never overwrite dirty input',
    () async {
      final api = _FakeClinicalRecordApi()..conflict = true;
      final controller = ClinicalRecordController(
        consultationId: consultationId,
        api: api,
      );
      await controller.load();
      controller.update((draft) => draft.notes = 'keep me');

      await controller.save();
      await controller.invalidate(
        ScheduledCareInvalidationEvent(
          eventId: '22222222-2222-4222-8222-222222222222',
          type: ScheduledCareEventType.unknown,
          rawEventType: 'CONSULTATION_UPDATED',
          resourceType: ScheduledCareResourceType.consultation,
          resourceId: consultationId,
          version: 4,
          occurredAt: DateTime.utc(2026, 10, 25),
        ),
      );

      expect(controller.conflict, isTrue);
      expect(controller.newerVersionAvailable, isTrue);
      expect(controller.draft.notes, 'keep me');
      expect(api.readCount, 1);
      controller.dispose();
    },
  );

  test(
    'consultation realtime envelope is accepted without clinical content',
    () {
      final event = ScheduledCareInvalidationEvent.tryParse('''
      {"eventId":"22222222-2222-4222-8222-222222222222",
       "eventType":"CONSULTATION_UPDATED","resourceType":"CONSULTATION",
       "resourceId":"$consultationId","version":4,
       "occurredAt":"2026-10-25T10:00:00Z"}
    ''');
      expect(event?.resourceType, ScheduledCareResourceType.consultation);
      expect(event?.rawEventType, 'CONSULTATION_UPDATED');
    },
  );

  test('stale realtime clinical versions are ignored', () async {
    final api = _FakeClinicalRecordApi();
    final controller = ClinicalRecordController(
      consultationId: consultationId,
      api: api,
    );
    await controller.load();

    await controller.invalidate(
      ScheduledCareInvalidationEvent(
        eventId: '33333333-3333-4333-8333-333333333333',
        type: ScheduledCareEventType.unknown,
        rawEventType: 'CONSULTATION_UPDATED',
        resourceType: ScheduledCareResourceType.consultation,
        resourceId: consultationId,
        version: 3,
        occurredAt: DateTime.utc(2026, 10, 25),
      ),
    );

    expect(api.readCount, 1);
    expect(controller.newerVersionAvailable, isFalse);
    controller.dispose();
  });

  test('clean realtime invalidation refetches the canonical version', () async {
    final api = _FakeClinicalRecordApi();
    final controller = ClinicalRecordController(
      consultationId: consultationId,
      api: api,
    );
    await controller.load();
    api.readVersion = 4;

    await controller.invalidate(
      ScheduledCareInvalidationEvent(
        eventId: '44444444-4444-4444-8444-444444444444',
        type: ScheduledCareEventType.unknown,
        rawEventType: 'CONSULTATION_UPDATED',
        resourceType: ScheduledCareResourceType.consultation,
        resourceId: consultationId,
        version: 4,
        occurredAt: DateTime.utc(2026, 10, 25),
      ),
    );

    expect(api.readCount, 2);
    expect(controller.authoritative?.clinicalRecordVersion, 4);
    controller.dispose();
  });

  test(
    'session deactivation clears clinical record and volatile draft',
    () async {
      final api = _FakeClinicalRecordApi();
      final controller = ClinicalRecordController(
        consultationId: consultationId,
        api: api,
      );
      final target = ClinicalRecordRealtimeTarget(controller)..activate();
      await controller.load();
      controller.update((draft) => draft.notes = 'volatile');

      target.deactivate();

      expect(controller.authoritative, isNull);
      expect(controller.draft.notes, isNull);
      target.dispose();
      controller.dispose();
    },
  );
}

class _FakeClinicalRecordApi implements ClinicalRecordApiContract {
  bool failAmbiguouslyOnce = false;
  bool conflict = false;
  int readCount = 0;
  int readVersion = 3;
  final List<int> expectedVersions = [];
  final List<String> keys = [];

  @override
  Future<ClinicalRecordEnvelope> read(String consultationId) async {
    readCount++;
    return ClinicalRecordEnvelope(
      clinicalRecordVersion: readVersion,
      schemaVersion: 2,
      record: ClinicalRecordDraft(chiefComplaint: 'reason'),
    );
  }

  @override
  Future<ClinicalRecordEnvelope> save({
    required String consultationId,
    required int expectedClinicalRecordVersion,
    required String idempotencyKey,
    required ClinicalRecordDraft record,
  }) async {
    expectedVersions.add(expectedClinicalRecordVersion);
    keys.add(idempotencyKey);
    if (failAmbiguouslyOnce) {
      failAmbiguouslyOnce = false;
      throw DioException(
        requestOptions: RequestOptions(path: '/clinical-record'),
        type: DioExceptionType.connectionError,
      );
    }
    if (conflict) {
      throw DioException(
        requestOptions: RequestOptions(path: '/clinical-record'),
        response: Response<dynamic>(
          requestOptions: RequestOptions(path: '/clinical-record'),
          statusCode: 409,
          data: {'code': 'CLINICAL_RECORD_VERSION_CONFLICT'},
        ),
        type: DioExceptionType.badResponse,
      );
    }
    return ClinicalRecordEnvelope(
      clinicalRecordVersion: expectedClinicalRecordVersion + 1,
      schemaVersion: 2,
      record: record.copy(),
    );
  }
}
