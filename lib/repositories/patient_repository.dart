import '../core/api/patients_api.dart';
import '../core/models/patient_models.dart';
import '../mock_data/mock_patients.dart';

class PatientRepository {
  PatientsApi? _api;

  PatientRepository({PatientsApi? api}) : _api = api;

  void useMock() {
    _api = null;
  }

  void useApi(PatientsApi api) {
    _api = api;
  }

  bool get isMock => _api == null;

  Future<List<PatientSummary>> getPatients() async {
    if (_api == null) return createMockPatientSummaries();
    return _api!.getPatients();
  }

  Future<List<PatientSummary>> getPatientsForProfessional() async {
    if (_api == null) return createMockPatientSummaries();
    return _api!.getPatientsForProfessional();
  }

  Future<List<PatientSummary>> getPatientsForDoctor() async {
    if (_api == null) return createMockPatientSummaries();
    return _api!.getPatientsForDoctor();
  }

  Future<Map<String, dynamic>> getPatientPassport(String patientId) async {
    if (_api == null) {
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
    return _api!.getPatientPassport(patientId);
  }

  Future<PatientPassport> getPatientPassportTyped(String patientId) async {
    if (_api == null) return createMockPatientPassport();
    return _api!.getPatientPassportTyped(patientId);
  }

  Future<void> addPatientCondition({
    required String patientId,
    required String name,
    String? notes,
  }) async {
    if (_api == null) return;
    await _api!.addPatientCondition(patientId: patientId, name: name, notes: notes);
  }

  Future<void> addPatientMedication({
    required String patientId,
    required String medicationId,
    String? frequency,
    String? notes,
    int? timesPerDay,
    int? durationDays,
    String? startDate,
  }) async {
    if (_api == null) return;
    await _api!.addPatientMedication(
      patientId: patientId,
      medicationId: medicationId,
      frequency: frequency,
      notes: notes,
      timesPerDay: timesPerDay,
      durationDays: durationDays,
      startDate: startDate,
    );
  }
}
