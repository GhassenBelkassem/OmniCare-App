import 'package:dio/dio.dart';

import '../../../core/network/app_http_client.dart';
import 'patient_clinic_models.dart';

/// Thin transport for the patient clinic directory.
///
/// Reuses the shared [AppHttpClient] — one auth interceptor, one refresh
/// coordinator. It never reads or writes tokens and installs no
/// `LogInterceptor`.
class PatientClinicApi {
  const PatientClinicApi(this._httpClient);

  final AppHttpClient _httpClient;

  static const String clinicsPath = '/patient/clinics';

  /// `GET /patient/clinics`.
  Future<PatientClinicDirectoryPage> listClinics({
    String? query,
    String? city,
    int? page,
    int? pageSize,
    CancelToken? cancelToken,
  }) async {
    final queryParameters = <String, dynamic>{
      if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
      if (city != null && city.trim().isNotEmpty) 'city': city.trim(),
      if (page != null) 'page': page,
      if (pageSize != null) 'pageSize': pageSize,
    };
    final response = await _httpClient.dio.get<dynamic>(
      clinicsPath,
      queryParameters: queryParameters,
      cancelToken: cancelToken,
    );
    final data = response.data;
    if (data is! Map) {
      throw const PatientClinicContractException('Expected a JSON object.');
    }
    return PatientClinicDirectoryPage.fromJson(data.cast<String, dynamic>());
  }

  /// `GET /patient/clinics/{clinicId}`.
  Future<PatientClinicDetail> getClinic(
    String clinicId, {
    CancelToken? cancelToken,
  }) async {
    final id = clinicId.trim();
    if (id.isEmpty) {
      throw const PatientClinicContractException(
        'Clinic identifier is required.',
      );
    }
    final response = await _httpClient.dio.get<dynamic>(
      '$clinicsPath/$id',
      cancelToken: cancelToken,
    );
    final data = response.data;
    if (data is! Map) {
      throw const PatientClinicContractException('Expected a JSON object.');
    }
    return PatientClinicDetail.fromJson(data.cast<String, dynamic>());
  }
}
