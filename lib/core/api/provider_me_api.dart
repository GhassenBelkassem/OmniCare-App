import '../../mock_data/mock_consultations.dart';
import '../../mock_data/mock_patients.dart';
import '../models/consultation.dart';
import '../models/patient_models.dart';

class ProviderMeApi {
  ProviderMeApi({Object? dio});

  static void invalidateConsultationsCache() {}

  Future<List<Consultation>> listMyConsultations({
    String? status,
    double? lat,
    double? lng,
    double? radiusKm,
  }) async {
    final all = createMockConsultations();
    if (status != null && status.trim().isNotEmpty) {
      return all.where((c) => c.status == status.trim()).toList();
    }
    return all;
  }

  Future<List<PatientSummary>> listMyPatients() async {
    return createMockPatientSummaries();
  }
}
