import '../../mock_data/mock_consultations.dart';
import '../models/consultation.dart';

class ConsultationsApi {
  ConsultationsApi({Object? dio});

  static void invalidateListCache() {}

  Future<List<Consultation>> listConsultations({String? status}) async {
    final all = createMockConsultations();
    if (status != null && status.trim().isNotEmpty) {
      return all.where((c) => c.status == status.trim()).toList();
    }
    return all;
  }

  Future<Consultation> getConsultation({required String consultationId}) async {
    return createMockConsultationDetail();
  }

  Future<Map<String, dynamic>> getPrescription({
    required String consultationId,
  }) async {
    return {
      'id': 'rx-1',
      'consultationId': consultationId,
      'medications': [
        {'name': 'Paracétamol', 'dosage': '500mg', 'frequency': '3x/jour'},
      ],
    };
  }

  Future<Map<String, dynamic>> putPrescription({
    required String consultationId,
    required Map<String, dynamic> payload,
  }) async {
    return {'id': 'rx-1', ...payload};
  }

  Future<Map<String, dynamic>> devAutoCompleteConsultation({
    required String consultationId,
    String? diagnosis,
    String? treatment,
    String? clinicalNotes,
  }) async {
    return {'status': 'completed'};
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
    return const Consultation(
      id: 'consult-new',
      status: 'PENDING',
      symptoms: 'Mock symptoms',
      painLevel: 5,
    );
  }

  Future<Consultation> patchConsultation({
    required String consultationId,
    String? status,
    String? diagnosis,
    String? treatment,
    num? fee,
  }) async {
    return Consultation(
      id: consultationId,
      status: status,
      diagnosis: diagnosis,
      treatment: treatment,
    );
  }

  Future<Consultation> completeConsultation({
    required String consultationId,
    String? diagnosis,
    String? treatment,
  }) async {
    return Consultation(
      id: consultationId,
      status: 'COMPLETED',
      diagnosis: diagnosis,
      treatment: treatment,
    );
  }
}
