// G-1: « Retirer l'accès » asks first; approve / revoke reuse their
// Idempotency-Key when a retry follows a failure that may have reached the
// server.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/core/network/api_exception.dart';
import 'package:omnicare_mobile/core/theme/omni_theme.dart';
import 'package:omnicare_mobile/features/patient_passport/presentation/widgets/medical_sharing_settings_sheet.dart';
import 'package:omnicare_mobile/features/patient_passport/sharing/direct_patient_authorization.dart';
import 'package:omnicare_mobile/features/patient_passport/sharing/direct_patient_authorization_api.dart';
import 'package:omnicare_mobile/features/patient_passport/sharing/direct_patient_authorization_controller.dart';
import 'package:omnicare_mobile/features/patient_passport/sharing/medical_sharing_api.dart';
import 'package:omnicare_mobile/features/patient_passport/sharing/medical_sharing_controller.dart';
import 'package:omnicare_mobile/features/patient_passport/sharing/medical_sharing_models.dart';

const _self = MedicalSharingSubject.self();

void main() {
  testWidgets(
    '« Retirer l’accès » asks for confirmation; the button is unchanged',
    (tester) async {
      final api = _FakeDirectApi();
      final direct = DirectPatientAuthorizationController(api);
      await tester.binding.setSurfaceSize(const Size(500, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: buildOmniTheme(),
          home: Scaffold(
            body: MedicalSharingSettingsSheet(
              controller: MedicalSharingController(_FakeSharingApi()),
              subject: _self,
              directAuthorizationController: direct,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final button = find.byKey(const Key('revoke-direct-consent'));
      expect(button, findsOneWidget);
      expect(
        find.descendant(of: button, matching: find.text('Retirer l’accès')),
        findsOneWidget,
      );

      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(find.text('Retirer l’accès ?'), findsOneWidget);
      expect(
        find.text('Le médecin ne pourra plus consulter votre dossier.'),
        findsOneWidget,
      );
      await tester.tap(find.byKey(const Key('revoke-direct-consent-cancel')));
      await tester.pumpAndSettle();
      expect(api.revokeKeys, isEmpty);

      await tester.tap(button);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('revoke-direct-consent-confirm')));
      await tester.pumpAndSettle();
      expect(api.revokeKeys, hasLength(1));
    },
  );

  test('a retry after a network failure replays the same key', () async {
    final api = _FakeDirectApi()
      ..revokeFailures = [
        const ApiException('x', code: 'MRS_UNAVAILABLE'),
        const ApiException('x', code: 'VALIDATION', statusCode: 400),
      ];
    final controller = DirectPatientAuthorizationController(api);
    await controller.load(_self);

    await controller.revoke(); // network: may have reached the server
    await controller.revoke(); // same key; definitive 400
    await controller.revoke(); // new key
    expect(api.revokeKeys[0], api.revokeKeys[1]);
    expect(api.revokeKeys[2], isNot(api.revokeKeys[1]));

    await controller.approve();
    expect(api.approveKeys.single, isNot(api.revokeKeys[2]));
  });
}

class _FakeDirectApi implements DirectPatientAuthorizationApiContract {
  final revokeKeys = <String>[];
  final approveKeys = <String>[];
  List<Object> revokeFailures = [];

  @override
  Future<List<DirectAuthorizationContext>> activeContexts(
    MedicalSharingSubject subject,
  ) async => [
    DirectAuthorizationContext(
      consultationId: 'consultation-1',
      subject: subject,
      doctor: const MedicalSharingDoctor(displayName: 'Ahmed'),
      startedAt: DateTime.utc(2026, 11, 9, 9),
    ),
  ];

  @override
  Future<PatientMedicalAccess> readAccess(String consultationId) async =>
      _active(consultationId);

  @override
  Future<PatientMedicalAccess> approve(
    String consultationId, {
    required String idempotencyKey,
  }) async {
    approveKeys.add(idempotencyKey);
    return _active(consultationId);
  }

  @override
  Future<PatientMedicalAccess> revoke(
    String consultationId, {
    required String idempotencyKey,
  }) async {
    revokeKeys.add(idempotencyKey);
    if (revokeFailures.isNotEmpty) throw revokeFailures.removeAt(0);
    return PatientMedicalAccess(
      status: PatientMedicalAccessStatus.revoked,
      consultationId: consultationId,
    );
  }

  static PatientMedicalAccess _active(String consultationId) =>
      PatientMedicalAccess(
        status: PatientMedicalAccessStatus.active,
        consultationId: consultationId,
        doctor: const MedicalSharingDoctor(displayName: 'Ahmed'),
        grantedVia: 'DIRECT_CONSENT',
        expiresAt: DateTime.utc(2026, 11, 9, 17),
        revocable: true,
      );
}

class _FakeSharingApi implements MedicalSharingApiContract {
  @override
  Future<MedicalSharingPolicy> readPolicy(
    MedicalSharingSubject subject,
  ) async => MedicalSharingPolicy(
    subject: subject,
    version: 1,
    essentialInformationEnabled: false,
    currentMedicationsEnabled: false,
    consultationSummariesEnabled: false,
    documentsEnabled: false,
    updatedAt: DateTime.utc(2026, 10, 20),
  );

  @override
  Future<MedicalSharingPolicy> updatePolicy(
    MedicalSharingPolicy desired, {
    required String idempotencyKey,
  }) async => desired;

  @override
  Future<ConsultationSharingPolicy> readConsultationPolicy(
    MedicalSharingSubject subject,
    String consultationId,
  ) async => ConsultationSharingPolicy(
    subject: subject,
    consultationId: consultationId,
    state: ConsultationSharingState.locked,
    version: 1,
    updatedAt: DateTime.utc(2026, 10, 20),
  );

  @override
  Future<ConsultationSharingPolicy> updateConsultationPolicy(
    ConsultationSharingPolicy current,
    ConsultationSharingState desired, {
    required String idempotencyKey,
  }) async => current;
}
