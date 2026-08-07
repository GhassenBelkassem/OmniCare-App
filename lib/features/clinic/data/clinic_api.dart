import 'package:dio/dio.dart';

import '../../../core/network/app_http_client.dart';
import 'clinic_models.dart';

/// Thin transport layer for the Phase 1 clinic contract.
///
/// It reuses the shared [AppHttpClient] (and therefore the existing auth
/// interceptor, serialized refresh and session-invalidation pipeline). It never
/// reads or writes tokens itself.
class ClinicApi {
  const ClinicApi(this._httpClient);

  final AppHttpClient _httpClient;

  static const String accessPath = '/me/access';
  static const String membershipsPath = '/me/clinics';

  static String bootstrapPath(String clinicId) =>
      '/clinics/$clinicId/bootstrap';

  Future<ClinicAccessResult> fetchAccess({CancelToken? cancelToken}) {
    return _get(accessPath, ClinicAccessResult.fromJson, cancelToken);
  }

  Future<ClinicMembershipDirectory> fetchMemberships({
    CancelToken? cancelToken,
  }) {
    return _get(
      membershipsPath,
      ClinicMembershipDirectory.fromJson,
      cancelToken,
    );
  }

  Future<ClinicBootstrap> fetchBootstrap(
    String clinicId, {
    CancelToken? cancelToken,
  }) {
    final id = clinicId.trim();
    if (id.isEmpty) {
      throw const ClinicContractException('Clinic identifier is required.');
    }
    return _get(bootstrapPath(id), ClinicBootstrap.fromJson, cancelToken);
  }

  Future<T> _get<T>(
    String path,
    T Function(Map<String, dynamic>) fromJson,
    CancelToken? cancelToken,
  ) async {
    final response = await _httpClient.dio.get<dynamic>(
      path,
      cancelToken: cancelToken,
    );
    final data = response.data;
    if (data is! Map) {
      throw const ClinicContractException('Expected a JSON object.');
    }
    return fromJson(data.cast<String, dynamic>());
  }
}
