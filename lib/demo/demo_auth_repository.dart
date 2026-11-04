import '../core/models/patient_profile.dart';
import '../features/auth/application/auth_flow_models.dart';
import '../features/auth/data/auth_repository.dart';
import '../features/auth/data/models/auth_dtos.dart';

enum DemoRole { patient, doctor, clinic }

/// Authentication used only by the browser demo target.
///
/// No token is persisted and no identity provider or backend is contacted.
class DemoAuthRepository implements AuthRepositoryContract {
  DemoRole _selectedRole = DemoRole.patient;

  DemoRole get selectedRole => _selectedRole;

  void selectRole(DemoRole role) {
    _selectedRole = role;
  }

  @override
  Future<AuthenticatedPatientSession?> restoreSession() async {
    return _sessionFor(_selectedRole);
  }

  @override
  Future<AuthenticatedPatientSession> loadCurrentProfile() async {
    return _sessionFor(_selectedRole);
  }

  @override
  Future<EmailPasswordLoginResult> loginWithEmailPassword(
    String email,
    String password, {
    bool rememberDevice = false,
  }) async {
    final normalized = email.trim().toLowerCase();
    if (normalized.contains('clinic')) {
      _selectedRole = DemoRole.clinic;
    } else if (normalized.contains('doctor') ||
        normalized.contains('medecin')) {
      _selectedRole = DemoRole.doctor;
    } else {
      _selectedRole = DemoRole.patient;
    }
    return EmailPasswordLoginResult.authenticated(_sessionFor(_selectedRole));
  }

  @override
  Future<GoogleAuthResult> initiateGoogle(
    String idToken, {
    bool rememberDevice = false,
  }) async {
    _selectedRole = DemoRole.patient;
    return GoogleAuthResult.authenticated(_sessionFor(_selectedRole));
  }

  @override
  Future<AuthenticatedPatientSession> linkGoogleAccount(String password) async {
    return _sessionFor(_selectedRole);
  }

  @override
  void cancelGoogleAccountLink() {}

  @override
  Future<void> initiateGooglePhoneSignup(String phone) async {}

  @override
  Future<void> verifyGooglePhoneSignupOtp(String phone, String otp) async {}

  @override
  Future<AuthenticatedPatientSession> completeGoogleSignup({
    String? phone,
    bool rememberDevice = false,
  }) async {
    _selectedRole = DemoRole.patient;
    return _sessionFor(_selectedRole);
  }

  @override
  Future<void> initiatePhoneSignup(String phone) async {}

  @override
  Future<void> verifyPhoneSignupOtp(String phone, String otp) async {}

  @override
  Future<AuthenticatedPatientSession> completePhoneSignup(
    PhoneSignupDraft draft,
    String phone, {
    bool rememberDevice = false,
  }) async {
    _selectedRole = DemoRole.patient;
    return _sessionFor(_selectedRole);
  }

  @override
  Future<void> initiatePhoneLogin(String phone) async {}

  @override
  Future<AuthenticatedPatientSession> verifyPhoneLoginOtp(
    String phone,
    String otp, {
    bool rememberDevice = false,
  }) async {
    _selectedRole = DemoRole.patient;
    return _sessionFor(_selectedRole);
  }

  @override
  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {}

  @override
  Future<void> logout() async {}

  AuthenticatedPatientSession _sessionFor(DemoRole role) {
    final roleName = switch (role) {
      DemoRole.patient => 'PATIENT',
      DemoRole.doctor => 'DOCTOR',
      DemoRole.clinic => 'CLINIC_ADMIN',
    };
    final id = '00000000-0000-4000-8000-00000000000${role.index + 1}';
    return AuthenticatedPatientSession(
      user: CurrentUserDto(
        id: id,
        role: roleName,
        sessionId: 'demo-session-${role.name}',
        mustChangePassword: false,
      ),
      profile: role == DemoRole.patient ? _patientProfile(id) : null,
    );
  }

  PatientProfile _patientProfile(String userId) {
    return PatientProfile(
      patientId: '10000000-0000-4000-8000-000000000001',
      userId: userId,
      firstName: 'Sarah',
      lastName: 'Ben Amor',
      displayName: 'Sarah Ben Amor',
      dateOfBirth: DateTime(1992, 5, 14),
      gender: 'FEMALE',
      photoUrl: null,
      primaryPhone: const VerifiedContact(
        value: '+216 22 345 678',
        verified: true,
      ),
      primaryEmail: const VerifiedContact(
        value: 'patient@demo.omnicare.tn',
        verified: true,
      ),
      onboardingCompleted: true,
      onboardingStep: 6,
      preferredLanguage: 'fr',
      notifications: const ProfileNotificationPreferences(
        medications: true,
        appointments: true,
        passport: true,
      ),
      updatedAt: DateTime.utc(2026, 10, 29, 9),
    );
  }
}
