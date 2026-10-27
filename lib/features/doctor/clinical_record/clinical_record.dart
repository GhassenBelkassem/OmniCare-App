import 'dart:convert';

class ClinicalRecordEnvelope {
  const ClinicalRecordEnvelope({
    required this.clinicalRecordVersion,
    required this.schemaVersion,
    required this.record,
  });

  final int clinicalRecordVersion;
  final int schemaVersion;
  final ClinicalRecordDraft record;

  factory ClinicalRecordEnvelope.fromJson(Map<String, dynamic> json) {
    final version = json['clinicalRecordVersion'];
    final schema = json['schemaVersion'];
    final record = json['clinicalRecord'];
    if (version is! int || version < 0 || schema != 2 || record is! Map) {
      throw const FormatException('Invalid clinical record response.');
    }
    return ClinicalRecordEnvelope(
      clinicalRecordVersion: version,
      schemaVersion: schema as int,
      record: ClinicalRecordDraft.fromJson(record.cast<String, dynamic>()),
    );
  }
}

class ClinicalRecordDraft {
  ClinicalRecordDraft({
    this.chiefComplaint,
    this.presentIllness,
    this.relevantMedicalHistory,
    this.relevantDentalHistory,
    this.findingType = '',
    this.findingDescription = '',
    this.diagnosisSystem = '',
    this.diagnosisCode = '',
    this.diagnosisLabel = '',
    this.diagnosisStatus = 'PROVISIONAL',
    this.assessment,
    List<String>? treatmentPlan,
    this.followUpRequired = false,
    this.followUpRecommendedAt,
    this.followUpDecision,
    this.notes,
    this.medicationDecision,
  }) : treatmentPlan = treatmentPlan ?? <String>[];

  String? chiefComplaint;
  String? presentIllness;
  String? relevantMedicalHistory;
  String? relevantDentalHistory;
  String findingType;
  String findingDescription;
  String diagnosisSystem;
  String diagnosisCode;
  String diagnosisLabel;
  String diagnosisStatus;
  String? assessment;
  List<String> treatmentPlan;
  bool followUpRequired;
  String? followUpRecommendedAt;
  String? followUpDecision;
  String? notes;
  String? medicationDecision;

  factory ClinicalRecordDraft.fromJson(Map<String, dynamic> json) {
    final history = _map(json['history']);
    final findings = _list(json['clinicalFindings']);
    final diagnoses = _list(json['diagnoses']);
    final finding = findings.isEmpty
        ? const <String, dynamic>{}
        : _map(findings.first);
    final diagnosis = diagnoses.isEmpty
        ? const <String, dynamic>{}
        : _map(diagnoses.first);
    final followUp = _map(json['followUp']);
    return ClinicalRecordDraft(
      chiefComplaint: _text(json['chiefComplaint']),
      presentIllness: _text(history['presentIllness']),
      relevantMedicalHistory: _text(history['relevantMedicalHistory']),
      relevantDentalHistory: _text(history['relevantDentalHistory']),
      findingType: _text(finding['type']) ?? '',
      findingDescription: _text(finding['description']) ?? '',
      diagnosisSystem: _text(diagnosis['system']) ?? '',
      diagnosisCode: _text(diagnosis['code']) ?? '',
      diagnosisLabel: _text(diagnosis['label']) ?? '',
      diagnosisStatus: _text(diagnosis['status']) ?? 'PROVISIONAL',
      assessment: _text(json['assessment']),
      treatmentPlan: _list(json['treatmentPlan']).whereType<String>().toList(),
      followUpRequired: followUp['required'] == true,
      followUpRecommendedAt: _text(followUp['recommendedAt']),
      followUpDecision: _text(followUp['decision']),
      notes: _text(json['notes']),
      medicationDecision: _text(json['medicationDecision']),
    );
  }

  ClinicalRecordDraft copy() => ClinicalRecordDraft.fromJson(toJson());

  Map<String, dynamic> toJson() => {
    'chiefComplaint': chiefComplaint,
    'history': {
      'presentIllness': presentIllness,
      'relevantMedicalHistory': relevantMedicalHistory,
      'relevantDentalHistory': relevantDentalHistory,
    },
    'clinicalFindings':
        findingType.trim().isEmpty && findingDescription.trim().isEmpty
        ? <Object>[]
        : <Object>[
            {'type': findingType, 'description': findingDescription},
          ],
    'diagnoses':
        diagnosisSystem.trim().isEmpty &&
            diagnosisCode.trim().isEmpty &&
            diagnosisLabel.trim().isEmpty
        ? <Object>[]
        : <Object>[
            {
              'system': diagnosisSystem,
              'code': diagnosisCode,
              'label': diagnosisLabel,
              'status': diagnosisStatus,
            },
          ],
    'assessment': assessment,
    'treatmentPlan': treatmentPlan,
    'followUp': {
      'required': followUpRequired,
      'recommendedAt': followUpRequired ? followUpRecommendedAt : null,
      'decision': followUpDecision,
    },
    'notes': notes,
    'medicationDecision': medicationDecision,
  };

  String fingerprint() => jsonEncode(toJson());
}

Map<String, dynamic> _map(Object? value) =>
    value is Map ? value.cast<String, dynamic>() : const <String, dynamic>{};
List<dynamic> _list(Object? value) => value is List ? value : const <dynamic>[];
String? _text(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  return value;
}

String? nullableClinicalText(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}
