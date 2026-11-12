import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/features/patient_passport/sharing/direct_patient_authorization.dart';
import 'package:omnicare_mobile/features/patient_passport/sharing/direct_patient_authorization_api.dart';
import 'package:omnicare_mobile/features/patient_passport/sharing/direct_patient_authorization_controller.dart';
import 'package:omnicare_mobile/features/patient_passport/sharing/medical_sharing_models.dart';

void main() {
  const self = MedicalSharingSubject.self();
  final context = DirectAuthorizationContext(
    consultationId: 'consultation-opaque',
    subject: self,
    doctor: const MedicalSharingDoctor(
      displayName: 'Ahmed',
      specialty: 'Cardiologie',
    ),
    startedAt: DateTime.utc(2026, 11, 9, 9),
  );

  test(
    'single context is selected and approve sends only consultation binding',
    () async {
      final api = _FakeDirectApi([context]);
      final controller = DirectPatientAuthorizationController(api);

      await controller.load(self);
      expect(controller.selected?.consultationId, 'consultation-opaque');
      expect(controller.access?.status, PatientMedicalAccessStatus.none);

      await controller.approve();
      expect(api.approvedConsultation, 'consultation-opaque');
      expect(controller.access?.status, PatientMedicalAccessStatus.active);
      expect(controller.access?.expiresAt, DateTime.utc(2026, 11, 9, 17));
    },
  );

  test(
    'multiple contexts require explicit opaque consultation selection',
    () async {
      final second = DirectAuthorizationContext(
        consultationId: 'consultation-two',
        subject: self,
        doctor: const MedicalSharingDoctor(displayName: 'Leila'),
        startedAt: DateTime.utc(2026, 11, 9, 10),
      );
      final api = _FakeDirectApi([context, second]);
      final controller = DirectPatientAuthorizationController(api);

      await controller.load(self);
      expect(controller.selected, isNull);
      await controller.approve();
      expect(api.approvedConsultation, isNull);

      await controller.select(second);
      await controller.approve();
      expect(api.approvedConsultation, 'consultation-two');
    },
  );
}

class _FakeDirectApi implements DirectPatientAuthorizationApiContract {
  _FakeDirectApi(this.contexts);

  final List<DirectAuthorizationContext> contexts;
  String? approvedConsultation;

  @override
  Future<List<DirectAuthorizationContext>> activeContexts(
    MedicalSharingSubject subject,
  ) async => contexts;

  @override
  Future<PatientMedicalAccess> readAccess(String consultationId) async =>
      PatientMedicalAccess(
        status: PatientMedicalAccessStatus.none,
        consultationId: consultationId,
      );

  @override
  Future<PatientMedicalAccess> approve(
    String consultationId, {
    required String idempotencyKey,
  }) async {
    approvedConsultation = consultationId;
    return PatientMedicalAccess(
      status: PatientMedicalAccessStatus.active,
      consultationId: consultationId,
      doctor: const MedicalSharingDoctor(displayName: 'Ahmed'),
      grantedVia: 'DIRECT_CONSENT',
      startsAt: DateTime.utc(2026, 11, 9, 9),
      expiresAt: DateTime.utc(2026, 11, 9, 17),
      revocable: true,
    );
  }

  @override
  Future<PatientMedicalAccess> revoke(
    String consultationId, {
    required String idempotencyKey,
  }) async => PatientMedicalAccess(
    status: PatientMedicalAccessStatus.revoked,
    consultationId: consultationId,
  );
}
