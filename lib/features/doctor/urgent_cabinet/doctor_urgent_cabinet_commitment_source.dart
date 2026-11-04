import 'package:dio/dio.dart';

import 'doctor_urgent_cabinet_commitment.dart';

abstract interface class DoctorUrgentCabinetCommitmentSource {
  Future<List<DoctorUrgentCabinetCommitment>> listCommitments({
    int limit = 20,
    CancelToken? cancelToken,
  });

  Future<DoctorUrgentCabinetCommitment> getCommitment(
    String commitmentId, {
    CancelToken? cancelToken,
  });
}

abstract interface class DoctorUrgentCabinetSessionStateSource {
  void clearSessionState();
}
