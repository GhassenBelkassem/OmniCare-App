import 'package:dio/dio.dart';

import '../../../core/network/app_http_client.dart';
import '../domain/scheduled_care_models.dart';

class ScheduledCareApi {
  const ScheduledCareApi(this._client);
  final AppHttpClient _client;

  Future<AvailabilityWindow> getAvailability({
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

  Future<PatientBookingRequest> createRequest({
    required String requestId,
    required String doctorId,
    required String practiceLocationId,
    required CareSubject subject,
    required ScheduledCareSlot slot,
  }) async {
    final response = await _client.dio.post<dynamic>(
      '/doctor-booking-requests',
      data: {
        'requestId': requestId,
        'doctorId': doctorId,
        'practiceLocationId': practiceLocationId,
        'subject': subject.toCreateJson(),
        'requestedSlot': slot.toJson(),
      },
    );
    return PatientBookingRequest.fromJson(_object(response.data));
  }

  Future<PatientBookingRequest> getRequest(String requestId) async {
    final response = await _client.dio.get<dynamic>(
      '/doctor-booking-requests/$requestId',
    );
    return PatientBookingRequest.fromJson(_object(response.data));
  }

  Future<PatientBookingRequest> cancelRequest({
    required String requestId,
    required int expectedVersion,
    required String reasonCode,
    required String idempotencyKey,
  }) async {
    final response = await _client.dio.post<dynamic>(
      '/doctor-booking-requests/$requestId/cancel',
      data: {'expectedVersion': expectedVersion, 'reasonCode': reasonCode},
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
    return PatientBookingRequest.fromJson(_object(response.data));
  }

  Future<ProposalAcceptance> acceptProposal({
    required String requestId,
    required String proposalId,
    required int expectedVersion,
    required String idempotencyKey,
  }) async {
    final response = await _client.dio.post<dynamic>(
      '/doctor-booking-requests/$requestId/proposals/$proposalId/accept',
      data: {'expectedVersion': expectedVersion},
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
    return ProposalAcceptance.fromJson(_object(response.data));
  }

  Future<PatientBookingRequest> declineProposal({
    required String requestId,
    required String proposalId,
    required int expectedVersion,
    required String reasonCode,
    required String idempotencyKey,
  }) async {
    final response = await _client.dio.post<dynamic>(
      '/doctor-booking-requests/$requestId/proposals/$proposalId/decline',
      data: {'expectedVersion': expectedVersion, 'reasonCode': reasonCode},
      options: Options(headers: {'Idempotency-Key': idempotencyKey}),
    );
    return PatientBookingRequest.fromJson(_object(response.data));
  }

  Future<ScheduledCarePage> list({
    required ScheduledCareBucket bucket,
    String? cursor,
    int limit = 20,
    String? query,
    DateTime? from,
    DateTime? to,
    CareSubjectType? subjectType,
    String? familyMemberId,
    String? city,
  }) async {
    final response = await _client.dio.get<dynamic>(
      '/patient/scheduled-care',
      queryParameters: {
        'bucket': bucket.wireName,
        'limit': limit,
        'cursor': ?cursor,
        if (query != null && query.trim().isNotEmpty) 'query': query.trim(),
        if (from != null) 'from': from.toUtc().toIso8601String(),
        if (to != null) 'to': to.toUtc().toIso8601String(),
        if (subjectType != null) 'subjectType': subjectType.wireName,
        'familyMemberId': ?familyMemberId,
        if (city != null && city.trim().isNotEmpty) 'city': city.trim(),
      },
    );
    return ScheduledCarePage.fromJson(_object(response.data));
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
