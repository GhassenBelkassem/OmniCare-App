import '../core/models/patient_models.dart';

List<PatientSummary> createMockPatientSummaries() {
  return [
    PatientSummary(
      patientId: 'patient-1',
      type: 'USER',
      displayName: 'Ahmed Benali',
      userId: 'user-1',
      familyMemberId: null,
    ),
    PatientSummary(
      patientId: 'patient-fam-1',
      type: 'FAMILY_MEMBER',
      displayName: 'Fatima Benali',
      userId: null,
      familyMemberId: 'fam-1',
    ),
    PatientSummary(
      patientId: 'patient-fam-2',
      type: 'FAMILY_MEMBER',
      displayName: 'Youssef Benali',
      userId: null,
      familyMemberId: 'fam-2',
    ),
  ];
}

PatientPassport createMockPatientPassport() {
  return PatientPassport(
    patientId: 'patient-1',
    type: 'USER',
    displayName: 'Ahmed Benali',
    fullName: 'Ahmed Benali',
    relationship: null,
    phoneNumber: '+213 555 12 34 56',
    dateOfBirth: '1992-04-10',
    age: 34,
    height: 178.0,
    weight: 75.0,
    gender: 'MALE',
    bloodGroup: 'A+',
    medicalInfo: {
      'chronicConditions': ['Asthma'],
    },
    chronicDiseases: ['Asthma'],
    allergies: ['Pénicilline'],
    currentMedicines: [
      PatientMedicationSummary(
        id: 'med-1',
        medicationId: 'med-001',
        name: 'Salbutamol',
        dosage: '100µg',
        frequency: 'À la demande',
      ),
    ],
    pastConsultations: [
      PastConsultationSummary(
        id: 'consult-1',
        status: 'COMPLETED',
        timestamp: '2026-06-15T10:30:00Z',
        diagnosis: 'Grippe saisonnière',
        treatment: 'Repos, paracétamol',
        fee: 2500.0,
      ),
    ],
    medicalDocuments: [
      MedicalDocumentSummary(
        id: 'doc-1',
        title: 'Analyse sanguine',
        type: 'blood-test',
        issueDate: '2026-06-10',
        fileUrl: null,
      ),
    ],
  );
}
