import '../core/models/account_models.dart';
import '../core/models/patient_profile.dart';

PatientProfile createMockProfile() {
  return PatientProfile(
    userId: 'mock-patient-user',
    firstName: 'Ahmed',
    lastName: 'Benali',
    displayName: 'Ahmed Benali',
    dateOfBirth: DateTime.utc(1990, 5, 18),
    gender: 'M',
    photoUrl: null,
    primaryPhone: const VerifiedContact(
      value: '+216 55 512 345',
      verified: true,
    ),
    primaryEmail: const VerifiedContact(
      value: 'user@omnicare.app',
      verified: true,
    ),
    onboardingCompleted: true,
    onboardingStep: 4,
    preferredLanguage: 'fr',
    notifications: const ProfileNotificationPreferences(
      medications: true,
      appointments: true,
      passport: true,
    ),
    updatedAt: null,
  );
}

AccountUser createMockUser() {
  return AccountUser(
    email: 'user@omnicare.app',
    name: 'Ahmed Benali',
    role: 'patient',
    firstName: 'Ahmed',
    lastName: 'Benali',
    phoneNumber: '+213 555 12 34 56',
    bloodGroup: 'A+',
    medicalInfo: null,
    avatar: null,
  );
}
