import 'package:flutter/foundation.dart';

enum MedicalSharingSubjectType { self, familyMember }

enum ConsultationSharingState { locked, shareable }

@immutable
class MedicalSharingSubject {
  const MedicalSharingSubject.self()
    : type = MedicalSharingSubjectType.self,
      familyMemberId = null;

  const MedicalSharingSubject.family(this.familyMemberId)
    : type = MedicalSharingSubjectType.familyMember;

  final MedicalSharingSubjectType type;
  final String? familyMemberId;

  Map<String, dynamic> toJson() => {
    'subjectType': switch (type) {
      MedicalSharingSubjectType.self => 'SELF',
      MedicalSharingSubjectType.familyMember => 'FAMILY_MEMBER',
    },
    if (familyMemberId != null) 'familyMemberId': familyMemberId,
  };

  Map<String, dynamic> toQueryParameters() => toJson();

  String get cacheKey => '${type.name}:${familyMemberId ?? 'self'}';
}

@immutable
class MedicalSharingPolicy {
  const MedicalSharingPolicy({
    required this.subject,
    required this.version,
    required this.essentialInformationEnabled,
    required this.currentMedicationsEnabled,
    required this.consultationSummariesEnabled,
    required this.documentsEnabled,
    required this.updatedAt,
  });

  final MedicalSharingSubject subject;
  final int version;
  final bool essentialInformationEnabled;
  final bool currentMedicationsEnabled;
  final bool consultationSummariesEnabled;
  final bool documentsEnabled;
  final DateTime updatedAt;

  MedicalSharingPolicy copyWith({
    bool? essentialInformationEnabled,
    bool? currentMedicationsEnabled,
    bool? consultationSummariesEnabled,
    bool? documentsEnabled,
  }) => MedicalSharingPolicy(
    subject: subject,
    version: version,
    essentialInformationEnabled:
        essentialInformationEnabled ?? this.essentialInformationEnabled,
    currentMedicationsEnabled:
        currentMedicationsEnabled ?? this.currentMedicationsEnabled,
    consultationSummariesEnabled:
        consultationSummariesEnabled ?? this.consultationSummariesEnabled,
    documentsEnabled: documentsEnabled ?? this.documentsEnabled,
    updatedAt: updatedAt,
  );

  Map<String, dynamic> toUpdateJson() => {
    ...subject.toJson(),
    'expectedVersion': version,
    'essentialInformationEnabled': essentialInformationEnabled,
    'currentMedicationsEnabled': currentMedicationsEnabled,
    'consultationSummariesEnabled': consultationSummariesEnabled,
    'documentsEnabled': documentsEnabled,
  };

  factory MedicalSharingPolicy.fromJson(Map<String, dynamic> json) {
    final type = _requiredString(json, 'subjectType');
    final familyMemberId = _optionalString(json['familyMemberId']);
    final subject = switch (type) {
      'SELF' when familyMemberId == null => const MedicalSharingSubject.self(),
      'FAMILY_MEMBER' when familyMemberId != null =>
        MedicalSharingSubject.family(familyMemberId),
      _ => throw const FormatException('Invalid medical-sharing subject.'),
    };
    return MedicalSharingPolicy(
      subject: subject,
      version: _requiredNonNegativeInt(json, 'version'),
      essentialInformationEnabled: _requiredBool(
        json,
        'essentialInformationEnabled',
      ),
      currentMedicationsEnabled: _requiredBool(
        json,
        'currentMedicationsEnabled',
      ),
      consultationSummariesEnabled: _requiredBool(
        json,
        'consultationSummariesEnabled',
      ),
      documentsEnabled: _requiredBool(json, 'documentsEnabled'),
      updatedAt: _requiredDateTime(json, 'updatedAt'),
    );
  }
}

@immutable
class ConsultationSharingPolicy {
  const ConsultationSharingPolicy({
    required this.subject,
    required this.consultationId,
    required this.state,
    required this.version,
    required this.updatedAt,
  });

  final MedicalSharingSubject subject;
  final String consultationId;
  final ConsultationSharingState state;
  final int version;
  final DateTime updatedAt;

  factory ConsultationSharingPolicy.fromJson(Map<String, dynamic> json) {
    final policy = MedicalSharingPolicy.fromJson({
      ...json,
      'essentialInformationEnabled': false,
      'currentMedicationsEnabled': false,
      'consultationSummariesEnabled': false,
      'documentsEnabled': false,
    });
    return ConsultationSharingPolicy(
      subject: policy.subject,
      consultationId: _requiredString(json, 'consultationId'),
      state: switch (_requiredString(json, 'sharingState')) {
        'LOCKED' => ConsultationSharingState.locked,
        'SHAREABLE' => ConsultationSharingState.shareable,
        _ => throw const FormatException('Invalid Consultation sharing state.'),
      },
      version: policy.version,
      updatedAt: policy.updatedAt,
    );
  }
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

bool _requiredBool(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! bool) throw FormatException('Missing $key.');
  return value;
}

int _requiredNonNegativeInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int || value < 0) throw FormatException('Invalid $key.');
  return value;
}

DateTime _requiredDateTime(Map<String, dynamic> json, String key) {
  final value = _requiredString(json, key);
  final parsed = DateTime.tryParse(value);
  if (parsed == null) throw FormatException('Invalid $key.');
  return parsed.toUtc();
}
