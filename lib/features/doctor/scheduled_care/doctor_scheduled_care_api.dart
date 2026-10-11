import 'package:dio/dio.dart';

import '../../../core/network/app_http_client.dart';
import '../../scheduled_care/domain/scheduled_care_models.dart';
import 'doctor_scheduled_care_models.dart';

class DoctorScheduledCareApi {
  const DoctorScheduledCareApi(this._client);

  final AppHttpClient _client;

  Future<DoctorHomeSummary> getHomeSummary() async {
    final response = await _client.dio.get<dynamic>(
      '/doctor/scheduled-care/home-summary',
    );
    return DoctorHomeSummary.fromJson(_object(response.data));
  }

  Future<DoctorScheduledCareAgenda> getAgenda({
    required DateTime from,
    required DateTime to,
  }) async {
    final response = await _client.dio.get<dynamic>(
      '/doctor/scheduled-care',
      queryParameters: {
        'from': from.toUtc().toIso8601String(),
        'to': to.toUtc().toIso8601String(),
      },
    );
    return DoctorScheduledCareAgenda.fromJson(_object(response.data));
  }

  Future<DoctorBookingRequest> getRequest(String requestId) async {
    final response = await _client.dio.get<dynamic>(
      '/doctor/booking-requests/$requestId',
    );
    return DoctorBookingRequest.fromJson(_object(response.data));
  }

  Future<DoctorBookingAcceptance> acceptRequest({
    required String requestId,
    required int expectedVersion,
    required String idempotencyKey,
  }) async {
    final response = await _client.dio.post<dynamic>(
      '/doctor/booking-requests/$requestId/accept',
      data: {'expectedVersion': expectedVersion},
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
    return DoctorBookingAcceptance.fromJson(_object(response.data));
  }

  Future<AvailabilityWindow> getProposalAvailability({
    required String doctorId,
    required String practiceLocationId,
    required DateTime from,
    required DateTime to,
  }) async {
    final response = await _client.dio.get<dynamic>(
      '/appointments/availability/slots',
      queryParameters: {
        'doctorId': doctorId,
        'practiceLocationId': practiceLocationId,
        'from': from.toUtc().toIso8601String(),
        'to': to.toUtc().toIso8601String(),
      },
    );
    return AvailabilityWindow.fromJson(_object(response.data));
  }

  Future<DoctorBookingRequest> proposeNewTime({
    required String requestId,
    required int expectedVersion,
    required String practiceLocationId,
    required ScheduledCareSlot proposedSlot,
    required String idempotencyKey,
  }) async {
    final response = await _client.dio.post<dynamic>(
      '/doctor/booking-requests/$requestId/proposals',
      data: {
        'expectedVersion': expectedVersion,
        'practiceLocationId': practiceLocationId,
        'proposedSlot': proposedSlot.toJson(),
      },
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
    return DoctorBookingRequest.fromJson(_object(response.data));
  }

  Future<DoctorBookingRequest> declineRequest({
    required String requestId,
    required int expectedVersion,
    required String reasonCode,
    required String idempotencyKey,
  }) async {
    final response = await _client.dio.post<dynamic>(
      '/doctor/booking-requests/$requestId/decline',
      data: {'expectedVersion': expectedVersion, 'reasonCode': reasonCode},
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
    return DoctorBookingRequest.fromJson(_object(response.data));
  }

  Future<ConfirmedScheduledAppointment> getAppointment(
    String appointmentId,
  ) async {
    final response = await _client.dio.get<dynamic>(
      '/appointments/$appointmentId',
    );
    return ConfirmedScheduledAppointment.fromJson(_object(response.data));
  }

  Future<ConfirmedScheduledAppointment> cancelAppointment({
    required String appointmentId,
    required int expectedVersion,
    required String reasonCode,
    required String idempotencyKey,
  }) async {
    final response = await _client.dio.post<dynamic>(
      '/appointments/$appointmentId/cancel',
      data: {'expectedVersion': expectedVersion, 'reasonCode': reasonCode},
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
    return ConfirmedScheduledAppointment.fromJson(_object(response.data));
  }
}

Map<String, dynamic> _object(Object? value) {
  if (value is! Map) throw const FormatException('Expected a JSON object.');
  return value.cast<String, dynamic>();
}
