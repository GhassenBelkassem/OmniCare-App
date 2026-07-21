import '../../mock_data/mock_patients.dart';
import '../models/patient_models.dart';

class PatientsApi {
  PatientsApi({Object? dio});

  Future<List<PatientSummary>> getPatients() async {
    return createMockPatientSummaries();
  }

  Future<List<PatientSummary>> getPatientsForProfessional() async {
    return createMockPatientSummaries();
  }

  Future<List<PatientSummary>> getPatientsForDoctor() async {
    return createMockPatientSummaries();
  }

  Future<Map<String, dynamic>> getPatientPassport(String patientId) async {
    return {
      'patientId': patientId,
      'type': 'USER',
      'displayName': 'Ahmed Benali',
      'fullName': 'Ahmed Benali',
      'bloodGroup': 'A+',
      'age': 34,
      'chronicDiseases': ['Asthma'],
      'allergies': ['Pénicilline'],
      'currentMedicines': [],
      'pastConsultations': [],
      'medicalDocuments': [],
    };
  }

  Future<PatientPassport> getPatientPassportTyped(String patientId) async {
    return createMockPatientPassport();
  }

  Future<void> addPatientCondition({
    required String patientId,
    required String name,
    String? notes,
  }) async {}

  Future<void> addPatientMedication({
    required String patientId,
    required String medicationId,
    String? frequency,
    String? notes,
    int? timesPerDay,
    int? durationDays,
    String? startDate,
  }) async {}
}
