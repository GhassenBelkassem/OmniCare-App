import 'package:flutter/foundation.dart';

import 'medical_sharing_models.dart';

enum PatientMedicalAccessStatus { none, active, expired, revoked, unavailable }

@immutable
class MedicalSharingDoctor {
  const MedicalSharingDoctor({required this.displayName, this.specialty});

  final String displayName;
  final String? specialty;

  factory MedicalSharingDoctor.fromJson(Map<String, dynamic> json) =>
      MedicalSharingDoctor(
        displayName: _requiredString(json, 'displayName'),
        specialty: _optionalString(json['specialty']),
      );
}

@immutable
class DirectAuthorizationContext {
  const DirectAuthorizationContext({
    required this.consultationId,
    required this.subject,
    required this.doctor,
    required this.startedAt,
  });

  final String consultationId;
  final MedicalSharingSubject subject;
  final MedicalSharingDoctor doctor;
  final DateTime startedAt;

  factory DirectAuthorizationContext.fromJson(Map<String, dynamic> json) {
    final subjectType = _requiredString(json, 'subjectType');
    final familyMemberId = _optionalString(json['familyMemberId']);
    final subject = switch (subjectType) {
      'SELF' when familyMemberId == null => const MedicalSharingSubject.self(),
      'FAMILY_MEMBER' when familyMemberId != null =>
        MedicalSharingSubject.family(familyMemberId),
      _ => throw const FormatException('Invalid authorization subject.'),
    };
    return DirectAuthorizationContext(
      consultationId: _requiredString(json, 'consultationId'),
      subject: subject,
      doctor: MedicalSharingDoctor.fromJson(_object(json['doctor'])),
      startedAt: _requiredDateTime(json, 'startedAt'),
    );
  }
}

@immutable
class PatientMedicalAccess {
  const PatientMedicalAccess({
    required this.status,
    required this.consultationId,
    this.doctor,
    this.grantedVia,
    this.startsAt,
    this.expiresAt,
    this.revocable = false,
  });

  final PatientMedicalAccessStatus status;
  final String consultationId;
  final MedicalSharingDoctor? doctor;
  final String? grantedVia;
  final DateTime? startsAt;
  final DateTime? expiresAt;
  final bool revocable;

  factory PatientMedicalAccess.fromJson(Map<String, dynamic> json) {
    final status = switch (_requiredString(json, 'status')) {
      'NONE' => PatientMedicalAccessStatus.none,
      'ACTIVE' => PatientMedicalAccessStatus.active,
      'EXPIRED' => PatientMedicalAccessStatus.expired,
      'REVOKED' => PatientMedicalAccessStatus.revoked,
      'UNAVAILABLE' => PatientMedicalAccessStatus.unavailable,
      _ => throw const FormatException('Invalid access status.'),
    };
    return PatientMedicalAccess(
      status: status,
      consultationId: _requiredString(json, 'consultationId'),
      doctor: json['doctor'] == null
          ? null
          : MedicalSharingDoctor.fromJson(_object(json['doctor'])),
      grantedVia: _optionalString(json['grantedVia']),
      startsAt: _optionalDateTime(json['startsAt']),
      expiresAt: _optionalDateTime(json['expiresAt']),
      revocable: json['revocable'] == true,
    );
  }
}

Map<String, dynamic> _object(Object? value) {
  if (value is! Map) throw const FormatException('Expected object.');
  return value.cast<String, dynamic>();
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Missing $key.');
  }
  return value.trim();
}

String? _optionalString(Object? value) {
  if (value == null) return null;
  if (value is! String || value.trim().isEmpty) {
    throw const FormatException('Invalid optional string.');
  }
  return value.trim();
}

DateTime _requiredDateTime(Map<String, dynamic> json, String key) {
  final parsed = DateTime.tryParse(_requiredString(json, key));
  if (parsed == null) throw FormatException('Invalid $key.');
  return parsed.toUtc();
}

DateTime? _optionalDateTime(Object? value) {
  if (value == null) return null;
  final text = _optionalString(value);
  final parsed = text == null ? null : DateTime.tryParse(text);
  if (parsed == null) throw const FormatException('Invalid date.');
  return parsed.toUtc();
}
