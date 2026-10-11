import 'package:dio/dio.dart';

import 'doctor_directory_api.dart';
import 'doctor_directory_failure.dart';
import 'doctor_directory_models.dart';

/// Repository boundary for the patient doctor directory.
///
/// Turns the transport layer into typed models and every failure into a
/// [DoctorDirectoryFailure], so no screen ever sees a `DioException` or a raw
/// backend error. Appointment creation belongs exclusively to scheduled care.
class DoctorDirectoryRepository {
  const DoctorDirectoryRepository(this._api);

  final DoctorDirectoryApi _api;

  Future<DoctorSearchPage> searchDoctors({
    required DoctorSearchCriteria criteria,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _api.searchDoctors(
        criteria: criteria,
        cancelToken: cancelToken,
      );
    } catch (error) {
      throw DoctorDirectoryFailure.from(error);
    }
  }

  Future<DoctorDirectoryDetail> getDoctor(
    String doctorId, {
    CancelToken? cancelToken,
  }) async {
    try {
      return await _api.getDoctor(doctorId, cancelToken: cancelToken);
    } catch (error) {
      throw DoctorDirectoryFailure.from(error);
    }
  }

  Future<List<AvailabilitySlotDto>> getSlots({
    required String doctorId,
    required String practiceLocationId,
    required DateTime from,
    required DateTime to,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _api.getSlots(
        doctorId: doctorId,
        practiceLocationId: practiceLocationId,
        from: from,
        to: to,
        cancelToken: cancelToken,
      );
    } catch (error) {
      throw DoctorDirectoryFailure.from(error);
    }
  }
}
