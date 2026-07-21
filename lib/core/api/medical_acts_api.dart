class MedicalActsApi {
  MedicalActsApi({Object? dio});

  Future<Map<String, dynamic>> createMedicalAct({
    required String prescriptionId,
    required String actType,
    String? photoUrl,
    String? notes,
  }) async {
    return {
      'id': 'act-${DateTime.now().millisecondsSinceEpoch}',
      'prescriptionId': prescriptionId,
      'actType': actType,
      'photoUrl': photoUrl,
      'notes': notes,
    };
  }
}
