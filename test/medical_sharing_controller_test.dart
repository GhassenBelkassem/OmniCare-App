import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/core/network/api_exception.dart';
import 'package:omnicare_mobile/features/patient_passport/sharing/medical_sharing_api.dart';
import 'package:omnicare_mobile/features/patient_passport/sharing/medical_sharing_controller.dart';
import 'package:omnicare_mobile/features/patient_passport/sharing/medical_sharing_models.dart';

void main() {
  const self = MedicalSharingSubject.self();
  const familyId = '11111111-1111-4111-8111-111111111111';
  const family = MedicalSharingSubject.family(familyId);

  test('SELF load and mutation use returned canonical policy', () async {
    final api = _FakeSharingApi();
    final controller = MedicalSharingController(api);

    await controller.selectSubject(self);
    expect(api.lastReadSubject?.type, MedicalSharingSubjectType.self);
    expect(controller.policy?.version, 0);
    expect(controller.policy?.essentialInformationEnabled, isFalse);

    final desired = controller.policy!.copyWith(
      essentialInformationEnabled: true,
    );
    expect(await controller.save(desired), isTrue);
    expect(controller.policy?.version, 1);
    expect(controller.policy?.essentialInformationEnabled, isTrue);
    expect(
      api.lastUpdateSubject?.toJson().containsKey('mrsPatientId'),
      isFalse,
    );
  });

  test('FAMILY load carries only the selected family member id', () async {
    final api = _FakeSharingApi();
    final controller = MedicalSharingController(api);

    await controller.selectSubject(family);

    expect(api.lastReadSubject?.familyMemberId, familyId);
    expect(api.lastReadSubject?.toJson(), {
      'subjectType': 'FAMILY_MEMBER',
      'familyMemberId': familyId,
    });
  });

  test('failed mutation retains server canonical state', () async {
    final api = _FakeSharingApi()
      ..updateFailure = const ApiException(
        'unavailable',
        code: 'MRS_UNAVAILABLE',
        statusCode: 503,
      );
    final controller = MedicalSharingController(api);
    await controller.selectSubject(self);
    final before = controller.policy;

    final saved = await controller.save(
      before!.copyWith(documentsEnabled: true),
    );

    expect(saved, isFalse);
    expect(controller.policy, same(before));
    expect(controller.policy?.documentsEnabled, isFalse);
    expect(controller.error, contains('Aucun changement enregistré'));
  });

  test('stale mutation refetches authoritative policy', () async {
    final api = _FakeSharingApi();
    final controller = MedicalSharingController(api);
    await controller.selectSubject(self);
    api.updateFailure = const ApiException(
      'conflict',
      code: 'SHARING_POLICY_VERSION_CONFLICT',
      statusCode: 409,
    );
    api.nextRead = _policy(self, version: 4, currentMedicationsEnabled: true);

    final saved = await controller.save(
      controller.policy!.copyWith(documentsEnabled: true),
    );

    expect(saved, isFalse);
    expect(controller.policy?.version, 4);
    expect(controller.policy?.currentMedicationsEnabled, isTrue);
    expect(controller.policy?.documentsEnabled, isFalse);
    expect(controller.notice, contains('modifiés ailleurs'));
  });

  test(
    'completed Consultation LOCKED/SHAREABLE uses canonical result',
    () async {
      final api = _FakeSharingApi();
      final controller = MedicalSharingController(api);
      await controller.selectSubject(self);

      final result = await controller.updateConsultationSharing(
        consultationId: '22222222-2222-4222-8222-222222222222',
        expectedVersion: 0,
        currentState: ConsultationSharingState.locked,
        desiredState: ConsultationSharingState.shareable,
      );

      expect(result?.state, ConsultationSharingState.shareable);
      expect(result?.version, 1);
      expect(api.lastConsultationSubject?.type, MedicalSharingSubjectType.self);
    },
  );
}

class _FakeSharingApi implements MedicalSharingApiContract {
  MedicalSharingSubject? lastReadSubject;
  MedicalSharingSubject? lastUpdateSubject;
  MedicalSharingSubject? lastConsultationSubject;
  MedicalSharingPolicy? nextRead;
  Object? updateFailure;

  @override
  Future<MedicalSharingPolicy> readPolicy(MedicalSharingSubject subject) async {
    lastReadSubject = subject;
    final selected = nextRead;
    nextRead = null;
    return selected ?? _policy(subject, version: 0);
  }

  @override
  Future<MedicalSharingPolicy> updatePolicy(
    MedicalSharingPolicy desired, {
    required String idempotencyKey,
  }) async {
    lastUpdateSubject = desired.subject;
    final failure = updateFailure;
    updateFailure = null;
    if (failure != null) throw failure;
    return MedicalSharingPolicy(
      subject: desired.subject,
      version: desired.version + 1,
      essentialInformationEnabled: desired.essentialInformationEnabled,
      currentMedicationsEnabled: desired.currentMedicationsEnabled,
      consultationSummariesEnabled: desired.consultationSummariesEnabled,
      documentsEnabled: desired.documentsEnabled,
      updatedAt: DateTime.utc(2026, 10, 20),
    );
  }

  @override
  Future<ConsultationSharingPolicy> readConsultationPolicy(
    MedicalSharingSubject subject,
    String consultationId,
  ) async => ConsultationSharingPolicy(
    subject: subject,
    consultationId: consultationId,
    state: ConsultationSharingState.locked,
    version: 2,
    updatedAt: DateTime.utc(2026, 10, 20),
  );

  @override
  Future<ConsultationSharingPolicy> updateConsultationPolicy(
    ConsultationSharingPolicy current,
    ConsultationSharingState desired, {
    required String idempotencyKey,
  }) async {
    lastConsultationSubject = current.subject;
    return ConsultationSharingPolicy(
      subject: current.subject,
      consultationId: current.consultationId,
      state: desired,
      version: current.version + 1,
      updatedAt: DateTime.utc(2026, 10, 20),
    );
  }
}

MedicalSharingPolicy _policy(
  MedicalSharingSubject subject, {
  required int version,
  bool currentMedicationsEnabled = false,
}) => MedicalSharingPolicy(
  subject: subject,
  version: version,
  essentialInformationEnabled: false,
  currentMedicationsEnabled: currentMedicationsEnabled,
  consultationSummariesEnabled: false,
  documentsEnabled: false,
  updatedAt: DateTime.utc(2026, 10, 20),
);
