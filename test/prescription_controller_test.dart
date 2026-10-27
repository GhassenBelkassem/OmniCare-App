import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/features/doctor/prescription/prescription.dart';
import 'package:omnicare_mobile/features/doctor/prescription/prescription_api.dart';
import 'package:omnicare_mobile/features/doctor/prescription/prescription_controller.dart';
import 'package:omnicare_mobile/features/scheduled_care/realtime/scheduled_care_event.dart';

const consultationId = '11111111-1111-4111-8111-111111111111';

void main() {
  test(
    'canonical v2 optional frequency, duration, and replacement fields roundtrip',
    () {
      final draft = PrescriptionDraft.fromJson({
        'medications': [
          {
            'itemId': '44444444-4444-4444-8444-444444444444',
            'replacesItemId': '55555555-5555-4555-8555-555555555555',
            'medicationCode': 'CODE',
            'dose': {'amount': 5, 'unit': 'mL'},
            'route': 'ORAL',
            'frequency': {'timesPerDay': null, 'text': 'when required'},
            'duration': {'value': 2, 'unit': 'WEEK'},
          },
        ],
      });

      final medication = draft.toJson()['medications'] as List<dynamic>;
      final encoded = medication.single as Map<String, dynamic>;
      expect(encoded['replacesItemId'], '55555555-5555-4555-8555-555555555555');
      expect((encoded['frequency'] as Map)['text'], 'when required');
      expect((encoded['duration'] as Map)['unit'], 'WEEK');
    },
  );

  test(
    'saves the same canonical series with CAS and stable retry key',
    () async {
      final api = _FakePrescriptionApi()..failAmbiguouslyOnce = true;
      final controller = PrescriptionController(
        consultationId: consultationId,
        api: api,
      );
      await controller.load();
      controller.update((draft) => draft.generalInstructions = 'Keep this');

      await controller.save();
      final retryKey = api.keys.single;
      expect(controller.draft.generalInstructions, 'Keep this');
      expect(controller.authoritative?.prescriptionVersion, 1);

      await controller.save();
      expect(api.keys.last, retryKey);
      expect(controller.authoritative?.prescriptionId, api.id);
      expect(controller.authoritative?.prescriptionVersion, 2);
      controller.dispose();
    },
  );

  test(
    'cross-device stale save conflicts without overwriting volatile input',
    () async {
      final api = _FakePrescriptionApi();
      final controller = PrescriptionController(
        consultationId: consultationId,
        api: api,
      );
      await controller.load();
      controller.update((draft) => draft.generalInstructions = 'Mobile draft');
      api.version = 2;

      await controller.save();

      expect(controller.conflict, isTrue);
      expect(controller.failureCode, 'PRESCRIPTION_VERSION_CONFLICT');
      expect(controller.draft.generalInstructions, 'Mobile draft');
      expect(controller.authoritative?.prescriptionVersion, 1);
      controller.dispose();
    },
  );

  test(
    'dirty realtime invalidation marks newer data without overwrite',
    () async {
      final api = _FakePrescriptionApi();
      final controller = PrescriptionController(
        consultationId: consultationId,
        api: api,
      );
      await controller.load();
      controller.update((draft) => draft.generalInstructions = 'Unsaved');
      await controller.invalidate(
        _event(
          'PRESCRIPTION_UPDATED',
          ScheduledCareResourceType.prescription,
          2,
        ),
      );

      expect(controller.newerVersionAvailable, isTrue);
      expect(controller.draft.generalInstructions, 'Unsaved');
      expect(api.readCount, 1);
      controller.dispose();
    },
  );

  test('finalization carries both versions and becomes immutable', () async {
    final api = _FakePrescriptionApi();
    final controller = PrescriptionController(
      consultationId: consultationId,
      api: api,
    );
    await controller.load();

    await controller.finalize();

    expect(api.finalizedPrescriptionVersion, 1);
    expect(api.finalizedClinicalVersion, 5);
    expect(controller.authoritative?.finalized, isTrue);
    controller.update((draft) => draft.generalInstructions = 'crafted edit');
    await controller.save();
    expect(api.version, 1);
    controller.dispose();
  });

  test('signer error is safe and session deactivation clears PHI', () async {
    final api = _FakePrescriptionApi()..signerUnavailable = true;
    final controller = PrescriptionController(
      consultationId: consultationId,
      api: api,
    );
    final target = PrescriptionRealtimeTarget(controller)..activate();
    await controller.load();
    await controller.finalize();
    expect(controller.failureCode, 'PRESCRIPTION_SIGNING_UNAVAILABLE');

    target.deactivate();
    expect(controller.authoritative, isNull);
    expect(controller.draft.medications, isEmpty);
    target.dispose();
    controller.dispose();
  });
}

ScheduledCareInvalidationEvent _event(
  String type,
  ScheduledCareResourceType resourceType,
  int version,
) => ScheduledCareInvalidationEvent(
  eventId: '22222222-2222-4222-8222-222222222222',
  type: ScheduledCareEventType.unknown,
  rawEventType: type,
  resourceType: resourceType,
  resourceId: consultationId,
  version: version,
  occurredAt: DateTime.utc(2026, 10, 26),
);

class _FakePrescriptionApi implements PrescriptionApiContract {
  final String id = '33333333-3333-4333-8333-333333333333';
  int version = 1;
  int readCount = 0;
  bool failAmbiguouslyOnce = false;
  bool signerUnavailable = false;
  int? finalizedPrescriptionVersion;
  int? finalizedClinicalVersion;
  final List<String> keys = [];
  PrescriptionDraft content = PrescriptionDraft(
    medications: [
      PrescriptionMedication(
        itemId: '44444444-4444-4444-8444-444444444444',
        name: 'Medicine',
      ),
    ],
  );

  PrescriptionEnvelope envelope({bool finalized = false}) =>
      PrescriptionEnvelope(
        prescriptionId: id,
        prescriptionVersion: version,
        clinicalRecordVersion: 5,
        status: finalized ? 'ACTIVE' : 'DRAFT',
        finalized: finalized,
        medicationDecision: 'MEDICATION_PRESCRIBED',
        signedAt: finalized ? DateTime.utc(2026, 10, 26) : null,
        signatureAlgorithm: finalized ? 'ED25519_SHA256' : null,
        content: content.copy(),
      );

  @override
  Future<PrescriptionEnvelope> read(String consultationId) async {
    readCount++;
    return envelope();
  }

  @override
  Future<PrescriptionEnvelope> save({
    required String consultationId,
    required int expectedPrescriptionVersion,
    required String idempotencyKey,
    required PrescriptionDraft prescription,
  }) async {
    keys.add(idempotencyKey);
    if (failAmbiguouslyOnce) {
      failAmbiguouslyOnce = false;
      throw DioException(
        requestOptions: RequestOptions(path: '/prescription'),
        type: DioExceptionType.connectionError,
      );
    }
    if (expectedPrescriptionVersion != version) {
      throw _error('PRESCRIPTION_VERSION_CONFLICT');
    }
    content = prescription.copy();
    version++;
    return envelope();
  }

  @override
  Future<PrescriptionEnvelope> finalize({
    required String consultationId,
    required int expectedPrescriptionVersion,
    required int expectedClinicalRecordVersion,
    required String idempotencyKey,
  }) async {
    if (signerUnavailable) {
      throw _error('PRESCRIPTION_SIGNING_UNAVAILABLE', status: 503);
    }
    finalizedPrescriptionVersion = expectedPrescriptionVersion;
    finalizedClinicalVersion = expectedClinicalRecordVersion;
    return envelope(finalized: true);
  }

  DioException _error(String code, {int status = 409}) => DioException(
    requestOptions: RequestOptions(path: '/prescription'),
    response: Response<dynamic>(
      requestOptions: RequestOptions(path: '/prescription'),
      statusCode: status,
      data: {'errorCode': code},
    ),
    type: DioExceptionType.badResponse,
  );
}
