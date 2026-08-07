import 'package:dio/dio.dart';

import 'clinic_api.dart';
import 'clinic_failure.dart';
import 'clinic_models.dart';

/// Repository boundary for the clinic access flow.
///
/// It converts every transport or contract problem into a safe [ClinicFailure]
/// so no controller or screen ever sees backend detail, request IDs or internal
/// error codes.
class ClinicRepository {
  const ClinicRepository(this._api);

  final ClinicApi _api;

  Future<ClinicAccessFamily> resolveAccessFamily({
    CancelToken? cancelToken,
  }) async {
    try {
      final result = await _api.fetchAccess(cancelToken: cancelToken);
      return result.accessFamily;
    } catch (error) {
      throw ClinicFailure.from(error);
    }
  }

  Future<ClinicMembershipDirectory> loadMemberships({
    CancelToken? cancelToken,
  }) async {
    try {
      return await _api.fetchMemberships(cancelToken: cancelToken);
    } catch (error) {
      throw ClinicFailure.from(error);
    }
  }

  Future<ClinicBootstrap> loadBootstrap(
    String clinicId, {
    CancelToken? cancelToken,
  }) async {
    try {
      return await _api.fetchBootstrap(clinicId, cancelToken: cancelToken);
    } catch (error) {
      throw ClinicFailure.from(error);
    }
  }
}
