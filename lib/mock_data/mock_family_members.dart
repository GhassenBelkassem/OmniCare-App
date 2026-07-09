import '../core/models/family_models.dart';

List<FamilyMember> createMockFamilyMembers() {
  return [
    FamilyMember(
      id: 'fam-1',
      fullName: 'Fatima Benali',
      firstName: 'Fatima',
      lastName: 'Benali',
      relationship: 'Maman',
      relationshipDescription: 'Mère',
      phoneNumber: '+213 555 98 76 54',
      birthDate: '1975-03-15',
      ageYears: 49,
      gender: 'FEMALE',
      profilePictureUrl: null,
      profilePicturePublicId: null,
      bloodGroup: 'O+',
      medicalInfo: {
        'chronicConditions': ['Hypertension', 'Diabète'],
        'currentMedications': [
          {'name': 'Metformin', 'dosage': '500mg', 'frequency': '2x/jour'},
        ],
      },
      patientId: 'patient-fam-1',
    ),
    FamilyMember(
      id: 'fam-2',
      fullName: 'Youssef Benali',
      firstName: 'Youssef',
      lastName: 'Benali',
      relationship: 'Fils',
      relationshipDescription: 'Fils',
      phoneNumber: null,
      birthDate: '2012-07-22',
      ageYears: 12,
      gender: 'MALE',
      profilePictureUrl: null,
      profilePicturePublicId: null,
      bloodGroup: 'A+',
      medicalInfo: {
        'chronicConditions': ['Allergie aux arachides'],
        'currentMedications': [],
      },
      patientId: 'patient-fam-2',
    ),
  ];
}
