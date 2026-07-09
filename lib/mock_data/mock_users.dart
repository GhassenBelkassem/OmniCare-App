import '../core/models/account_models.dart';

AccountFullProfile createMockProfile() {
  return AccountFullProfile(
    user: AccountUser(
      email: 'user@omnicare.app',
      name: 'Ahmed Benali',
      role: 'patient',
      firstName: 'Ahmed',
      lastName: 'Benali',
      phoneNumber: '+213 555 12 34 56',
      bloodGroup: 'A+',
      medicalInfo: {
        'chronicConditions': ['Asthma'],
        'currentMedications': [],
      },
      avatar: null,
    ),
    familyMembers: const [],
    documents: const [],
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
