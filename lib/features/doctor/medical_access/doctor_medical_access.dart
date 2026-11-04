import 'package:flutter/foundation.dart';

@immutable
class DoctorMedicalAccessActivation {
  const DoctorMedicalAccessActivation({
    required this.consultationId,
    required this.activatedAt,
    required this.expiresAt,
  });

  final String consultationId;
  final DateTime activatedAt;
  final DateTime expiresAt;

  factory DoctorMedicalAccessActivation.fromJson(Map<String, dynamic> json) {
    final consultationId = _string(json, 'consultationId');
    final status = _string(json, 'medicalAccessStatus');
    if (status != 'ACTIVE') {
      throw const FormatException('Medical access is not active.');
    }
    return DoctorMedicalAccessActivation(
      consultationId: consultationId,
      activatedAt: _date(json, 'activatedAt'),
      expiresAt: _date(json, 'expiresAt'),
    );
  }

  static String _string(Map<String, dynamic> json, String key) {
    final value = json[key];
    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Missing $key.');
    }
    return value.trim();
  }

  static DateTime _date(Map<String, dynamic> json, String key) {
    final value = _string(json, key);
    final parsed = DateTime.tryParse(value);
    if (parsed == null) throw FormatException('Invalid $key.');
    return parsed.toUtc();
  }
}

enum DoctorMedicalAccessStatus { ready, submitting, active, error }
