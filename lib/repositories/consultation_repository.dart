import '../core/api/consultations_api.dart';
import '../core/models/consultation.dart';
import '../core/models/patient_models.dart';
import '../mock_data/mock_consultations.dart';
import '../mock_data/mock_patients.dart';

class ConsultationRepository {
  ConsultationsApi? _api;

  ConsultationRepository({ConsultationsApi? api}) : _api = api;

  void useMock() {
    _api = null;
  }

  void useApi(ConsultationsApi api) {
    _api = api;
  }

  bool get isMock => _api == null;

  Future<List<Consultation>> listConsultations({String? status}) async {
    if (_api == null) return createMockConsultations();
    return _api!.listConsultations(status: status);
  }

  Future<Consultation> getConsultation({required String consultationId}) async {
    if (_api == null) return createMockConsultationDetail();
    return _api!.getConsultation(consultationId: consultationId);
  }

  Future<Map<String, dynamic>> getPrescription({
    required String consultationId,
  }) async {
    if (_api == null) {
      return {
        'prescriptionId': 'rx-1',
        'medications': [
          {'name': 'Paracétamol', 'dosage': '500mg', 'frequency': '3x/jour'},
        ],
        'issuedAt': '2026-07-01T10:00:00Z',
      };
    }
    return _api!.getPrescription(consultationId: consultationId);
  }

  Future<Map<String, dynamic>> putPrescription({
    required String consultationId,
    required Map<String, dynamic> payload,
  }) async {
    if (_api == null) return {'status': 'ok', 'prescriptionId': 'rx-1'};
    return _api!.putPrescription(
      consultationId: consultationId,
      payload: payload,
    );
  }

  Future<Consultation> createConsultation({
    required String doctorId,
    String? patientId,
    required String symptoms,
    required int painLevel,
    required List<String> affectedAreas,
    required double latitude,
    required double longitude,
    String? streetAddress,
    String? apartmentSuite,
    String? city,
    num? fee,
  }) async {
    if (_api == null) {
      return Consultation(
        id: 'new-consult',
        doctorId: 'doc-1',
        status: 'PENDING',
        symptoms: 'Mock symptoms',
        painLevel: 5,
        timestamp: '2026-07-08T12:00:00Z',
      );
    }
    return _api!.createConsultation(
      doctorId: doctorId,
      patientId: patientId,
      symptoms: symptoms,
      painLevel: painLevel,
      affectedAreas: affectedAreas,
      latitude: latitude,
      longitude: longitude,
      streetAddress: streetAddress,
      apartmentSuite: apartmentSuite,
      city: city,
      fee: fee,
    );
  }

  Future<Consultation> patchConsultation({
    required String consultationId,
    String? status,
    String? diagnosis,
    String? treatment,
    num? fee,
  }) async {
    if (_api == null) {
      return Consultation(id: consultationId, status: status ?? 'PENDING');
    }
    return _api!.patchConsultation(
      consultationId: consultationId,
      status: status,
      diagnosis: diagnosis,
      treatment: treatment,
      fee: fee,
    );
  }

  Future<Consultation> completeConsultation({
    required String consultationId,
    String? diagnosis,
    String? treatment,
  }) async {
    if (_api == null) {
      return Consultation(
        id: consultationId,
        status: 'COMPLETED',
        diagnosis: 'Mock diagnosis',
        treatment: 'Mock treatment',
      );
    }
    return _api!.completeConsultation(
      consultationId: consultationId,
      diagnosis: diagnosis,
      treatment: treatment,
    );
  }

  Future<List<PatientSummary>> listMyPatients() async {
    if (_api == null) return createMockPatientSummaries();
    // ProviderMeApi equivalent is called via PatientsApi in the original code
    return createMockPatientSummaries();
  }

  Future<List<Consultation>> listMyConsultations({
    String? status,
    double? lat,
    double? lng,
    double? radiusKm,
  }) async {
    if (_api == null) return createMockConsultations();
    return _api!.listConsultations(status: status);
  }
}
