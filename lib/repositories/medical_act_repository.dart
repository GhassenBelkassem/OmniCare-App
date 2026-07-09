import '../core/api/medical_acts_api.dart';

class MedicalActRepository {
  MedicalActsApi? _api;

  MedicalActRepository({MedicalActsApi? api}) : _api = api;

  void useMock() {
    _api = null;
  }

  void useApi(MedicalActsApi api) {
    _api = api;
  }

  bool get isMock => _api == null;

  Future<Map<String, dynamic>> createMedicalAct({
    required String prescriptionId,
    required String actType,
    String? photoUrl,
    String? notes,
  }) async {
    if (_api == null) {
      return {
        'id': 'act-${DateTime.now().millisecondsSinceEpoch}',
        'prescriptionId': prescriptionId,
        'actType': actType,
        'status': 'created',
      };
    }
    return _api!.createMedicalAct(
      prescriptionId: prescriptionId,
      actType: actType,
      photoUrl: photoUrl,
      notes: notes,
    );
  }
}
