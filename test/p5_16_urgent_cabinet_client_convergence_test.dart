import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/features/doctor/urgent_cabinet/doctor_urgent_cabinet_commitment.dart';

void main() {
  test('arrival-ready authority exposes canonical Start', () {
    final commitment = parseDoctorUrgentCabinetCommitment(
      _commitment(
        arrivalVerifiedAt: '2026-10-28T09:05:00Z',
        clinicalStartReady: true,
        allowedActions: const ['START_CONSULTATION'],
      ),
    );

    expect(commitment.canStartConsultation, isTrue);
    expect(commitment.revision, 4);
    expect(commitment.commitmentId, '11111111-1111-4111-8111-111111111111');
  });

  test(
    'deferred responsibility remains visible but cannot Start while busy',
    () {
      final commitment = parseDoctorUrgentCabinetCommitment(
        _commitment(
          arrivalVerifiedAt: '2026-10-28T09:05:00Z',
          clinicalStartReady: false,
          allowedActions: const [],
        ),
      );

      expect(commitment.isDeferred, isTrue);
      expect(commitment.canStartConsultation, isFalse);
    },
  );

  test('completed commitment is terminal clinical history, not actionable', () {
    final commitment = parseDoctorUrgentCabinetCommitment(
      _commitment(
        status: 'COMPLETED',
        arrivalVerifiedAt: '2026-10-28T09:05:00Z',
        consultationId: '33333333-3333-4333-8333-333333333333',
        consultationStatus: 'COMPLETED',
        completedAt: '2026-10-28T09:40:00Z',
        allowedActions: const [],
      ),
    );

    expect(commitment.status, DoctorUrgentCabinetCommitmentStatus.completed);
    expect(commitment.canStartConsultation, isFalse);
  });
}

Map<String, Object?> _commitment({
  String status = 'ACTIVE',
  String? arrivalVerifiedAt,
  bool clinicalStartReady = false,
  String? consultationId,
  String? consultationStatus,
  String? completedAt,
  required List<String> allowedActions,
}) => <String, Object?>{
  'commitmentId': '11111111-1111-4111-8111-111111111111',
  'requestId': '22222222-2222-4222-8222-222222222222',
  'practiceLocationId': '44444444-4444-4444-8444-444444444444',
  'status': status,
  'revision': 4,
  'quotedFeeTnd': '45.000',
  'currency': 'TND',
  'quoteConfigurationRevision': 2,
  'committedAt': '2026-10-28T09:00:00Z',
  'arrivalVerifiedAt': arrivalVerifiedAt,
  'terminalAt': null,
  'updatedAt': completedAt ?? arrivalVerifiedAt ?? '2026-10-28T09:00:00Z',
  'allowedActions': allowedActions,
  'evaluatedAt': '2026-10-28T09:41:00Z',
  'capacityBinding': 'DEFERRED_CLINICAL_BUSY',
  'clinicalStartReady': clinicalStartReady,
  'consultationId': consultationId,
  'consultationStatus': consultationStatus,
  'clinicalStartedAt': consultationId == null ? null : '2026-10-28T09:10:00Z',
  'completedAt': completedAt,
};
