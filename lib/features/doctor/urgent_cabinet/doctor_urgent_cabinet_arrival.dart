import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'doctor_urgent_cabinet_commitment.dart';

@immutable
class DoctorUrgentCabinetArrivalVerification {
  const DoctorUrgentCabinetArrivalVerification({
    required this.commitmentId,
    required this.requestId,
    required this.commitmentRevision,
    required this.arrivalVerifiedAt,
    required this.replayed,
  });

  final String commitmentId;
  final String requestId;
  final int commitmentRevision;
  final DateTime arrivalVerifiedAt;
  final bool replayed;
}

abstract interface class DoctorUrgentCabinetArrivalSource {
  Future<DoctorUrgentCabinetArrivalVerification> verifyArrival({
    required DoctorUrgentCabinetCommitment commitment,
    required String token,
    CancelToken? cancelToken,
  });
}
