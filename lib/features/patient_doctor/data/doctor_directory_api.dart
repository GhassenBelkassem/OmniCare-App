import 'package:dio/dio.dart';

import '../../../core/network/app_http_client.dart';
import 'doctor_directory_models.dart';

/// Thin transport for the real patient doctor directory.
///
/// Reuses the shared [AppHttpClient] — one auth interceptor, one refresh
/// coordinator. It never reads or writes tokens and installs no
/// `LogInterceptor`.
class DoctorDirectoryApi {
  const DoctorDirectoryApi(this._httpClient);

  final AppHttpClient _httpClient;

  static const String doctorsBasePath = '/doctors';
  static const String doctorSearchPath = '/doctors/search';
  static const String availabilitySlotsPath =
      '/appointments/availability/slots';

  /// `GET /doctors/search` using the certified P1-06 slice contract.
  Future<DoctorSearchPage> searchDoctors({
    required DoctorSearchCriteria criteria,
    CancelToken? cancelToken,
  }) async {
    final response = await _httpClient.dio.get<dynamic>(
      doctorSearchPath,
      queryParameters: criteria.toQueryParameters(),
      cancelToken: cancelToken,
    );
    final data = response.data;
    if (data is! Map) {
      throw const DoctorContractException('Expected a JSON object.');
    }
    return DoctorSearchPage.fromJson(data.cast<String, dynamic>());
  }

  /// `GET /doctors/{doctorId}`.
  Future<DoctorDirectoryDetail> getDoctor(
    String doctorId, {
    CancelToken? cancelToken,
  }) async {
    final id = doctorId.trim();
    if (id.isEmpty) {
      throw const DoctorContractException('Doctor identifier is required.');
    }
    final response = await _httpClient.dio.get<dynamic>(
      '$doctorsBasePath/$id',
      cancelToken: cancelToken,
    );
    final data = response.data;
    if (data is! Map) {
      throw const DoctorContractException('Expected a JSON object.');
    }
    return DoctorDirectoryDetail.fromJson(data.cast<String, dynamic>());
  }

  /// `GET /appointments/availability/slots`.
  Future<List<AvailabilitySlotDto>> getSlots({
    required String doctorId,
    required String practiceLocationId,
    required DateTime from,
    required DateTime to,
    CancelToken? cancelToken,
  }) async {
    final queryParameters = <String, dynamic>{
      'doctorId': doctorId.trim(),
      'practiceLocationId': practiceLocationId.trim(),
      'from': from.toUtc().toIso8601String(),
      'to': to.toUtc().toIso8601String(),
    };
    final response = await _httpClient.dio.get<dynamic>(
      availabilitySlotsPath,
      queryParameters: queryParameters,
      cancelToken: cancelToken,
    );
    final data = response.data;
    if (data is! Map || data['slots'] is! List) {
      throw const DoctorContractException(
        'Expected a Cabinet-scoped availability response.',
      );
    }
    final rawSlots = data['slots'] as List;
    final slots = <AvailabilitySlotDto>[];
    for (final element in rawSlots) {
      if (element is! Map) {
        throw const DoctorContractException('Slot entry is malformed.');
      }
      slots.add(AvailabilitySlotDto.fromJson(element.cast<String, dynamic>()));
    }
    return List.unmodifiable(slots);
  }
}
