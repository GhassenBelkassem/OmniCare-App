import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/demo/demo_auth_repository.dart';

void main() {
  group('DemoAuthRepository', () {
    test('restores the patient demo by default', () async {
      final repository = DemoAuthRepository();

      final session = await repository.restoreSession();

      expect(session?.user.role, 'PATIENT');
      expect(session?.profile?.displayName, 'Sarah Ben Amor');
    });

    test('selects professional workspaces from demo email addresses', () async {
      final repository = DemoAuthRepository();

      final doctor = await repository.loginWithEmailPassword(
        'doctor@demo.omnicare.tn',
        'anything',
      );
      final clinic = await repository.loginWithEmailPassword(
        'clinic@demo.omnicare.tn',
        'anything',
      );

      expect(doctor.session?.user.role, 'DOCTOR');
      expect(doctor.session?.profile, isNull);
      expect(clinic.session?.user.role, 'CLINIC_ADMIN');
      expect(clinic.session?.profile, isNull);
    });
  });
}
