import 'package:flutter/foundation.dart';

enum DoctorConsultationSourceType {
  scheduledAppointment,
  urgentHome,
  urgentCabinet,
}

enum DoctorConsultationStatus { inProgress, finalizing, completed, aborted }

enum DoctorConsultationMedicalAccessStatus {
  none,
  active,
  expired,
  revoked,
  unavailable,
}

@immutable
class DoctorActiveConsultation {
  const DoctorActiveConsultation({
    required this.consultationId,
    required this.sourceType,
    required this.sourceId,
    required this.status,
    required this.medicalAccessStatus,
    required this.version,
    required this.startedAt,
  });

  final String consultationId;
  final DoctorConsultationSourceType sourceType;
  final String sourceId;
  final DoctorConsultationStatus status;
  final DoctorConsultationMedicalAccessStatus medicalAccessStatus;
  final int version;
  final DateTime startedAt;

  factory DoctorActiveConsultation.fromJson(Map<String, dynamic> json) =>
      DoctorActiveConsultation(
        consultationId: _requiredString(json, 'consultationId'),
        sourceType: _sourceType(_requiredString(json, 'sourceType')),
        sourceId: _requiredString(json, 'sourceId'),
        status: _status(_requiredString(json, 'status')),
        medicalAccessStatus: _access(
          _requiredString(json, 'medicalAccessStatus'),
        ),
        version: _nonNegativeInt(json, 'version'),
        startedAt: _instant(json, 'startedAt'),
      );

  static String _requiredString(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Missing $key.');
    }
    return value.trim();
  }

  static int _nonNegativeInt(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! int || value < 0) throw FormatException('Invalid $key.');
    return value;
  }

  static DateTime _instant(Map<String, dynamic> json, String key) {
    final parsed = DateTime.tryParse(_requiredString(json, key));
    if (parsed == null) throw FormatException('Invalid $key.');
    return parsed.toUtc();
  }

  static DoctorConsultationSourceType _sourceType(String value) =>
      switch (value) {
        'SCHEDULED_APPOINTMENT' =>
          DoctorConsultationSourceType.scheduledAppointment,
        'URGENT_HOME' => DoctorConsultationSourceType.urgentHome,
        'URGENT_CABINET' => DoctorConsultationSourceType.urgentCabinet,
        _ => throw FormatException('Unknown sourceType: $value.'),
      };

  static DoctorConsultationStatus _status(String value) => switch (value) {
    'IN_PROGRESS' => DoctorConsultationStatus.inProgress,
    'FINALIZING' => DoctorConsultationStatus.finalizing,
    'COMPLETED' => DoctorConsultationStatus.completed,
    'ABORTED' => DoctorConsultationStatus.aborted,
    _ => throw FormatException('Unknown status: $value.'),
  };

  static DoctorConsultationMedicalAccessStatus _access(String value) =>
      switch (value) {
        'NONE' => DoctorConsultationMedicalAccessStatus.none,
        'ACTIVE' => DoctorConsultationMedicalAccessStatus.active,
        'EXPIRED' => DoctorConsultationMedicalAccessStatus.expired,
        'REVOKED' => DoctorConsultationMedicalAccessStatus.revoked,
        'UNAVAILABLE' => DoctorConsultationMedicalAccessStatus.unavailable,
        _ => throw FormatException('Unknown medicalAccessStatus: $value.'),
      };
}
