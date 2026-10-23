import 'package:dio/dio.dart';

import '../../../core/network/app_http_client.dart';
import '../domain/patient_scheduled_care_models.dart';
import '../domain/scheduled_care_models.dart';

class ScheduledCareApi {
  const ScheduledCareApi(this._httpClient);

  final AppHttpClient _httpClient;

  static const String bookingRequestsPath = '/doctor-booking-requests';
  static const String appointmentsPath = '/appointments';
  Future<PatientBookingRequestDetail> createBookingRequest(
    CreateBookingRequestCommand command, {
    CancelToken? cancelToken,
  }) async {
    final response = await _httpClient.dio.post<dynamic>(
      bookingRequestsPath,
      data: command.toJson(),
      cancelToken: cancelToken,
      options: Options(contentType: Headers.jsonContentType),
    );
    return _parseDetail(response.data);
  }

  Future<PatientBookingRequestDetail> getBookingRequest(
    String requestId, {
    CancelToken? cancelToken,
  }) async {
    final response = await _httpClient.dio.get<dynamic>(
      '$bookingRequestsPath/${requestId.trim()}',
      cancelToken: cancelToken,
    );
    return _parseDetail(response.data);
  }

  Future<PatientBookingRequestDetail> cancelBookingRequest(
    CancelBookingRequestCommand command, {
    CancelToken? cancelToken,
  }) async {
    final response = await _httpClient.dio.post<dynamic>(
      '$bookingRequestsPath/${command.requestId.trim()}/cancel',
      data: command.toJson(),
      cancelToken: cancelToken,
      options: _mutationOptions(command.idempotencyKey),
    );
    return _parseDetail(response.data);
  }

  Future<ProposalAcceptanceResult> acceptProposal(
    AcceptBookingProposalCommand command, {
    CancelToken? cancelToken,
  }) async {
    final response = await _httpClient.dio.post<dynamic>(
      '$bookingRequestsPath/${command.requestId.trim()}'
      '/proposals/${command.proposalId.trim()}/accept',
      data: command.toJson(),
      cancelToken: cancelToken,
      options: _mutationOptions(command.idempotencyKey),
    );
    return _parseAcceptance(response.data);
  }

  Future<PatientBookingRequestDetail> declineProposal(
    DeclineBookingProposalCommand command, {
    CancelToken? cancelToken,
  }) async {
    final response = await _httpClient.dio.post<dynamic>(
      '$bookingRequestsPath/${command.requestId.trim()}'
      '/proposals/${command.proposalId.trim()}/decline',
      data: command.toJson(),
      cancelToken: cancelToken,
      options: _mutationOptions(command.idempotencyKey),
    );
    return _parseDetail(response.data);
  }

  Future<ConfirmedScheduledAppointment> getAppointment(
    String appointmentId, {
    CancelToken? cancelToken,
  }) async {
    final response = await _httpClient.dio.get<dynamic>(
      '$appointmentsPath/${appointmentId.trim()}',
      cancelToken: cancelToken,
    );
    return _parseAppointment(response.data);
  }

  static Options _mutationOptions(String idempotencyKey) {
    final key = idempotencyKey.trim();
    if (key.isEmpty || key.length > 128) {
      throw const ScheduledCareContractException(
        'Invalid mutation idempotency key.',
      );
    }
    return Options(
      contentType: Headers.jsonContentType,
      headers: {'Idempotency-Key': key},
    );
  }

  static PatientBookingRequestDetail _parseDetail(Object? data) {
    if (data is! Map) {
      throw const ScheduledCareContractException(
        'Expected a booking request object.',
      );
    }
    return PatientBookingRequestDetail.fromJson(data.cast<String, dynamic>());
  }

  static ProposalAcceptanceResult _parseAcceptance(Object? data) {
    if (data is! Map) {
      throw const ScheduledCareContractException(
        'Expected a proposal acceptance object.',
      );
    }
    return ProposalAcceptanceResult.fromJson(data.cast<String, dynamic>());
  }

  static ConfirmedScheduledAppointment _parseAppointment(Object? data) {
    if (data is! Map) {
      throw const ScheduledCareContractException(
        'Expected an appointment object.',
      );
    }
    return ConfirmedScheduledAppointment.fromJson(data.cast<String, dynamic>());
  }
}

abstract interface class PatientScheduledCareApiContract {
  Future<PatientScheduledCarePage> getPatientScheduledCare(
    PatientScheduledCareQuery query, {
    CancelToken? cancelToken,
  });
}

class PatientScheduledCareApi implements PatientScheduledCareApiContract {
  const PatientScheduledCareApi(this._httpClient);

  final AppHttpClient _httpClient;
  static const String path = '/patient/scheduled-care';

  @override
  Future<PatientScheduledCarePage> getPatientScheduledCare(
    PatientScheduledCareQuery query, {
    CancelToken? cancelToken,
  }) async {
    final response = await _httpClient.dio.get<dynamic>(
      path,
      queryParameters: query.toQueryParameters(),
      cancelToken: cancelToken,
    );
    if (response.data is! Map) {
      throw const ScheduledCareContractException(
        'Expected a scheduled-care page object.',
      );
    }
    return PatientScheduledCarePage.fromJson(
      (response.data as Map).cast<String, dynamic>(),
    );
  }
}

abstract interface class ScheduledAppointmentCancellationApiContract {
  Future<ConfirmedScheduledAppointment> cancelAppointment(
    CancelScheduledAppointmentCommand command, {
    CancelToken? cancelToken,
  });
}

class ScheduledAppointmentCancellationApi
    implements ScheduledAppointmentCancellationApiContract {
  const ScheduledAppointmentCancellationApi(this._httpClient);

  final AppHttpClient _httpClient;

  static String pathFor(String appointmentId) =>
      '${ScheduledCareApi.appointmentsPath}/${appointmentId.trim()}/cancel';

  @override
  Future<ConfirmedScheduledAppointment> cancelAppointment(
    CancelScheduledAppointmentCommand command, {
    CancelToken? cancelToken,
  }) async {
    final key = command.idempotencyKey.trim();
    if (key.isEmpty || key.length > 128) {
      throw const ScheduledCareContractException(
        'Invalid mutation idempotency key.',
      );
    }
    final response = await _httpClient.dio.post<dynamic>(
      pathFor(command.appointmentId),
      data: command.toJson(),
      cancelToken: cancelToken,
      options: Options(
        contentType: Headers.jsonContentType,
        headers: {'Idempotency-Key': key},
      ),
    );
    if (response.data is! Map) {
      throw const ScheduledCareContractException(
        'Expected an appointment object.',
      );
    }
    return ConfirmedScheduledAppointment.fromJson(
      (response.data as Map).cast<String, dynamic>(),
    );
  }
}
