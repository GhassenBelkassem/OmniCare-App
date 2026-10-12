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
  static const String availabilitySlotsPath =
      '/appointments/availability/slots';
  static const String appointmentsPath = '/appointments';

  /// `GET /doctors`.
  Future<List<DoctorDirectoryListItem>> listDoctors({
    String? query,
    CancelToken? cancelToken,
  }) async {
    final queryParameters = <String, dynamic>{
      if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
    };
    final response = await _httpClient.dio.get<dynamic>(
      doctorsBasePath,
      queryParameters: queryParameters,
      cancelToken: cancelToken,
    );
    final data = response.data;
    if (data is! List) {
      throw const DoctorContractException('Expected a JSON array.');
    }
    final items = <DoctorDirectoryListItem>[];
    for (final element in data) {
      if (element is! Map) {
        throw const DoctorContractException('Doctor list entry is malformed.');
      }
      items.add(
        DoctorDirectoryListItem.fromJson(element.cast<String, dynamic>()),
      );
    }
    return List.unmodifiable(items);
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
  Future<AvailabilitySlotsDto> getSlots({
    required String doctorId,
    required String practiceLocationId,
    required DateTime from,
    required DateTime to,
    CancelToken? cancelToken,
  }) async {
    final normalizedDoctorId = doctorId.trim();
    final normalizedPracticeLocationId = practiceLocationId.trim();
    final utcFrom = from.toUtc();
    final utcTo = to.toUtc();
    if (normalizedDoctorId.isEmpty || normalizedPracticeLocationId.isEmpty) {
      throw const DoctorContractException(
        'Doctor and practice location identifiers are required.',
      );
    }
    if (!utcFrom.isBefore(utcTo) ||
        utcTo.difference(utcFrom) > const Duration(days: 31)) {
      throw const DoctorContractException(
        'Availability range must be increasing and at most 31 days.',
      );
    }
    final queryParameters = <String, dynamic>{
      'doctorId': normalizedDoctorId,
      'practiceLocationId': normalizedPracticeLocationId,
      'from': utcFrom.toIso8601String(),
      'to': utcTo.toIso8601String(),
    };
    final response = await _httpClient.dio.get<dynamic>(
      availabilitySlotsPath,
      queryParameters: queryParameters,
      cancelToken: cancelToken,
    );
    final data = response.data;
    if (data is! Map) {
      throw const DoctorContractException('Expected a JSON object.');
    }
    return AvailabilitySlotsDto.fromJson(data.cast<String, dynamic>());
  }

  /// `POST /appointments`.
  ///
  /// `startTime`/`endTime` are the exact slot `start`/`end` values from
  /// [AvailabilitySlotDto]; the backend re-validates against the live slot
  /// window (exact-match rule).
  @Deprecated('Compatibility only. Scheduled patient care creates a request.')
  Future<AppointmentBooking> bookAppointment({
    required String doctorId,
    required String startTime,
    required String endTime,
    String? notes,
    CancelToken? cancelToken,
  }) async {
    final payload = <String, dynamic>{
      'doctorId': doctorId.trim(),
      'startTime': startTime,
      'endTime': endTime,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    };
    final response = await _httpClient.dio.post<dynamic>(
      appointmentsPath,
      data: payload,
      cancelToken: cancelToken,
      options: Options(contentType: Headers.jsonContentType),
    );
    final data = response.data;
    if (data is! Map) {
      throw const DoctorContractException('Expected a JSON object.');
    }
    return AppointmentBooking.fromJson(data.cast<String, dynamic>());
  }
}
