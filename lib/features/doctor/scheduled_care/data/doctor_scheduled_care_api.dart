import 'package:dio/dio.dart';

import '../../../../core/network/app_http_client.dart';
import '../../../scheduled_care/domain/scheduled_care_models.dart';
import '../domain/doctor_scheduled_care_models.dart';

abstract interface class DoctorScheduledCareApiContract {
  Future<DoctorHomeSummary> getHomeSummary({CancelToken? cancelToken});
  Future<DoctorAgendaSnapshot> getAgenda(
    DoctorAgendaRange range, {
    CancelToken? cancelToken,
  });
  Future<DoctorBookingRequestDetail> getBookingRequest(
    String requestId, {
    CancelToken? cancelToken,
  });
  Future<DoctorAcceptResult> accept(
    DoctorAcceptCommand command, {
    CancelToken? cancelToken,
  });
  Future<DoctorBookingRequestDetail> decline(
    DoctorDeclineCommand command, {
    CancelToken? cancelToken,
  });
  Future<DoctorBookingRequestDetail> propose(
    DoctorProposalCommand command, {
    CancelToken? cancelToken,
  });
  Future<ConfirmedScheduledAppointment> getAppointment(
    String appointmentId, {
    CancelToken? cancelToken,
  });
  Future<ConfirmedScheduledAppointment> cancelAppointment(
    DoctorCancelAppointmentCommand command, {
    CancelToken? cancelToken,
  });
}

class DoctorScheduledCareApi implements DoctorScheduledCareApiContract {
  const DoctorScheduledCareApi(this._httpClient);

  final AppHttpClient _httpClient;
  static const homePath = '/doctor/scheduled-care/home-summary';
  static const requestsPath = '/doctor/booking-requests';
  static const appointmentsPath = '/appointments';

  @override
  Future<DoctorAgendaSnapshot> getAgenda(
    DoctorAgendaRange range, {
    CancelToken? cancelToken,
  }) async {
    final response = await _httpClient.dio.get<dynamic>(
      '/doctor/scheduled-care',
      queryParameters: range.toQueryParameters(),
      cancelToken: cancelToken,
    );
    return DoctorAgendaSnapshot.fromJson(
      _object(response.data, 'Doctor Agenda'),
    );
  }

  @override
  Future<DoctorHomeSummary> getHomeSummary({CancelToken? cancelToken}) async {
    final response = await _httpClient.dio.get<dynamic>(
      homePath,
      cancelToken: cancelToken,
    );
    return DoctorHomeSummary.fromJson(_object(response.data, 'home summary'));
  }

  @override
  Future<DoctorBookingRequestDetail> getBookingRequest(
    String requestId, {
    CancelToken? cancelToken,
  }) async {
    final response = await _httpClient.dio.get<dynamic>(
      '$requestsPath/${requestId.trim()}',
      cancelToken: cancelToken,
    );
    return DoctorBookingRequestDetail.fromJson(
      _object(response.data, 'doctor booking request'),
    );
  }

  @override
  Future<DoctorAcceptResult> accept(
    DoctorAcceptCommand command, {
    CancelToken? cancelToken,
  }) async {
    final response = await _httpClient.dio.post<dynamic>(
      '$requestsPath/${command.requestId.trim()}/accept',
      data: command.toJson(),
      cancelToken: cancelToken,
      options: _mutationOptions(command.idempotencyKey),
    );
    return DoctorAcceptResult.fromJson(
      _object(response.data, 'doctor acceptance result'),
    );
  }

  @override
  Future<DoctorBookingRequestDetail> decline(
    DoctorDeclineCommand command, {
    CancelToken? cancelToken,
  }) async {
    final response = await _httpClient.dio.post<dynamic>(
      '$requestsPath/${command.requestId.trim()}/decline',
      data: command.toJson(),
      cancelToken: cancelToken,
      options: _mutationOptions(command.idempotencyKey),
    );
    return DoctorBookingRequestDetail.fromJson(
      _object(response.data, 'doctor booking request'),
    );
  }

  @override
  Future<DoctorBookingRequestDetail> propose(
    DoctorProposalCommand command, {
    CancelToken? cancelToken,
  }) async {
    final response = await _httpClient.dio.post<dynamic>(
      '$requestsPath/${command.requestId.trim()}/proposals',
      data: command.toJson(),
      cancelToken: cancelToken,
      options: _mutationOptions(command.idempotencyKey),
    );
    return DoctorBookingRequestDetail.fromJson(
      _object(response.data, 'doctor booking request'),
    );
  }

  @override
  Future<ConfirmedScheduledAppointment> getAppointment(
    String appointmentId, {
    CancelToken? cancelToken,
  }) async {
    final response = await _httpClient.dio.get<dynamic>(
      '$appointmentsPath/${appointmentId.trim()}',
      cancelToken: cancelToken,
    );
    return ConfirmedScheduledAppointment.fromJson(
      _object(response.data, 'appointment'),
    );
  }

  @override
  Future<ConfirmedScheduledAppointment> cancelAppointment(
    DoctorCancelAppointmentCommand command, {
    CancelToken? cancelToken,
  }) async {
    final response = await _httpClient.dio.post<dynamic>(
      '$appointmentsPath/${command.appointmentId.trim()}/cancel',
      data: command.toJson(),
      cancelToken: cancelToken,
      options: _mutationOptions(command.idempotencyKey),
    );
    return ConfirmedScheduledAppointment.fromJson(
      _object(response.data, 'appointment'),
    );
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

  static Map<String, dynamic> _object(Object? value, String label) {
    if (value is Map) return value.cast<String, dynamic>();
    throw ScheduledCareContractException('Expected a $label object.');
  }
}
