import 'package:dio/dio.dart';

import '../../../core/network/app_http_client.dart';
import '../domain/scheduled_care_models.dart';

abstract interface class PatientScheduledConsultationApiContract {
  Future<String> resolveCompletedConsultation(String appointmentId);
}

class PatientScheduledConsultationApi
    implements PatientScheduledConsultationApiContract {
  const PatientScheduledConsultationApi(this._httpClient);

  final AppHttpClient _httpClient;

  @override
  Future<String> resolveCompletedConsultation(String appointmentId) async {
    final normalized = appointmentId.trim();
    final response = await _httpClient.dio.get<dynamic>(
      '/patient/appointments/$normalized/consultation',
      options: Options(
        headers: const <String, String>{'Cache-Control': 'no-store'},
      ),
    );
    final raw = response.data;
    if (raw is! Map) {
      throw const ScheduledCareContractException(
        'Expected scheduled Consultation identity.',
      );
    }
    final json = raw.cast<String, dynamic>();
    final consultationId = json['consultationId'];
    if (consultationId is! String ||
        consultationId.trim().isEmpty ||
        json['sourceType'] != 'SCHEDULED_APPOINTMENT' ||
        json['sourceId'] != normalized ||
        json['status'] != 'COMPLETED') {
      throw const ScheduledCareContractException(
        'Scheduled Consultation identity does not match the Appointment.',
      );
    }
    return consultationId.trim();
  }
}
