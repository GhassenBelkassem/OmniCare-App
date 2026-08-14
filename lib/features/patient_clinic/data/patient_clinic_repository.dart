import 'package:dio/dio.dart';

import 'patient_clinic_api.dart';
import 'patient_clinic_failure.dart';
import 'patient_clinic_models.dart';

/// Repository boundary for the patient clinic directory.
///
/// Turns the transport layer into typed models and every failure into a
/// [PatientClinicFailure], so no screen ever sees a `DioException` or a raw
/// backend error.
class PatientClinicRepository {
  const PatientClinicRepository(this._api);

  final PatientClinicApi _api;

  Future<PatientClinicDirectoryPage> listClinics({
    String? query,
    String? city,
    int? page,
    int? pageSize,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _api.listClinics(
        query: query,
        city: city,
        page: page,
        pageSize: pageSize,
        cancelToken: cancelToken,
      );
    } catch (error) {
      throw PatientClinicFailure.from(error);
    }
  }

  Future<PatientClinicDetail> getClinic(
    String clinicId, {
    CancelToken? cancelToken,
  }) async {
    try {
      return await _api.getClinic(clinicId, cancelToken: cancelToken);
    } catch (error) {
      throw PatientClinicFailure.from(error);
    }
  }
}
