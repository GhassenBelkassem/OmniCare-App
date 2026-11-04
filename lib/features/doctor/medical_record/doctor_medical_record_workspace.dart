import 'package:flutter/foundation.dart';

@immutable
class DoctorMedicalRecordWorkspace {
  const DoctorMedicalRecordWorkspace({
    required this.consultationId,
    required this.accessExpiresAt,
    required this.sections,
    required this.essentialInformation,
    required this.currentMedications,
    required this.consultationSummaries,
  });

  final String consultationId;
  final DateTime accessExpiresAt;
  final Map<String, String> sections;
  final DoctorEssentialInformation? essentialInformation;
  final List<DoctorCurrentMedication> currentMedications;
  final List<DoctorConsultationSummary> consultationSummaries;

  bool sectionAuthorized(String section) => sections[section] == 'AUTHORIZED';

  factory DoctorMedicalRecordWorkspace.fromJson(Map<String, dynamic> json) {
    final consultation = _map(json, 'consultation');
    final access = _map(json, 'access');
    final summaries = _map(json, 'consultationSummaries');
    final sections = _map(access, 'sections');
    return DoctorMedicalRecordWorkspace(
      consultationId: _string(consultation, 'consultationId'),
      accessExpiresAt: _dateTime(access, 'expiresAt'),
      sections: sections.map((key, value) => MapEntry(key, value.toString())),
      essentialInformation: json['essentialInformation'] == null
          ? null
          : DoctorEssentialInformation.fromJson(
              (json['essentialInformation'] as Map).cast<String, dynamic>(),
            ),
      currentMedications: _list(
        json,
        'currentMedications',
      ).map(DoctorCurrentMedication.fromJson).toList(growable: false),
      consultationSummaries: _list(
        summaries,
        'items',
      ).map(DoctorConsultationSummary.fromJson).toList(growable: false),
    );
  }
}

@immutable
class DoctorEssentialInformation {
  const DoctorEssentialInformation({
    required this.bloodType,
    required this.allergies,
    required this.criticalConditions,
  });

  final String? bloodType;
  final List<String> allergies;
  final List<String> criticalConditions;

  factory DoctorEssentialInformation.fromJson(Map<String, dynamic> json) =>
      DoctorEssentialInformation(
        bloodType: _optionalString(json, 'bloodType'),
        allergies: _strings(json, 'allergies'),
        criticalConditions: _strings(json, 'criticalConditions'),
      );
}

@immutable
class DoctorCurrentMedication {
  const DoctorCurrentMedication({
    required this.recordVersion,
    required this.status,
    required this.name,
    required this.code,
    required this.strength,
    required this.doseAmount,
    required this.doseUnit,
    required this.dosageText,
    required this.route,
    required this.timesPerDay,
    required this.frequencyText,
  });

  final int recordVersion;
  final String? status;
  final String? name;
  final String? code;
  final String? strength;
  final num? doseAmount;
  final String? doseUnit;
  final String? dosageText;
  final String? route;
  final int? timesPerDay;
  final String? frequencyText;

  factory DoctorCurrentMedication.fromJson(Map<String, dynamic> json) =>
      DoctorCurrentMedication(
        recordVersion: _integer(json, 'recordVersion'),
        status: _optionalString(json, 'status'),
        name: _optionalString(json, 'name'),
        code: _optionalString(json, 'code'),
        strength: _optionalString(json, 'strength'),
        doseAmount: json['doseAmount'] as num?,
        doseUnit: _optionalString(json, 'doseUnit'),
        dosageText: _optionalString(json, 'dosageText'),
        route: _optionalString(json, 'route'),
        timesPerDay: json['timesPerDay'] as int?,
        frequencyText: _optionalString(json, 'frequencyText'),
      );

  String get displayName => name ?? code ?? 'Médicament sans libellé';

  String get instruction => <String?>[
    strength,
    dosageText ??
        (doseAmount == null ? null : '$doseAmount ${doseUnit ?? ''}'.trim()),
    frequencyText ?? (timesPerDay == null ? null : '$timesPerDay fois/jour'),
    route,
  ].whereType<String>().where((value) => value.isNotEmpty).join(' · ');
}

@immutable
class DoctorConsultationSummary {
  const DoctorConsultationSummary({
    required this.consultationId,
    required this.occurredAt,
    required this.chiefComplaint,
    required this.diagnoses,
    required this.clinicalCodes,
    required this.assessment,
    required this.treatmentPlan,
    required this.notes,
  });

  final String consultationId;
  final String? occurredAt;
  final String? chiefComplaint;
  final List<String> diagnoses;
  final List<String> clinicalCodes;
  final String? assessment;
  final List<String> treatmentPlan;
  final String? notes;

  factory DoctorConsultationSummary.fromJson(Map<String, dynamic> json) {
    final diagnosisValues = _list(json, 'diagnoses')
        .map(
          (value) =>
              _optionalString(value, 'label') ?? _optionalString(value, 'code'),
        )
        .whereType<String>()
        .toList(growable: false);
    final codeValues = _list(json, 'clinicalCodes')
        .map((value) => _optionalString(value, 'code'))
        .whereType<String>()
        .toList(growable: false);
    return DoctorConsultationSummary(
      consultationId: _string(json, 'consultationId'),
      occurredAt: _optionalString(json, 'occurredAt'),
      chiefComplaint: _optionalString(json, 'chiefComplaint'),
      diagnoses: diagnosisValues,
      clinicalCodes: codeValues,
      assessment: _optionalString(json, 'assessment'),
      treatmentPlan: _strings(json, 'treatmentPlan'),
      notes: _optionalString(json, 'notes'),
    );
  }

  String get title =>
      chiefComplaint ??
      _first(diagnoses) ??
      _first(clinicalCodes) ??
      'Consultation';
}

Map<String, dynamic> _map(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! Map) throw FormatException('Missing $key.');
  return value.cast<String, dynamic>();
}

List<Map<String, dynamic>> _list(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List) throw FormatException('Missing $key.');
  return value
      .map((item) {
        if (item is! Map) throw FormatException('Invalid $key item.');
        return item.cast<String, dynamic>();
      })
      .toList(growable: false);
}

String _string(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Missing $key.');
  }
  return value.trim();
}

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  return value is String && value.trim().isNotEmpty ? value.trim() : null;
}

int _integer(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int || value < 0) throw FormatException('Invalid $key.');
  return value;
}

DateTime _dateTime(Map<String, dynamic> json, String key) {
  final value = DateTime.tryParse(_string(json, key));
  if (value == null) throw FormatException('Invalid $key.');
  return value.toUtc();
}

List<String> _strings(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! List) throw FormatException('Missing $key.');
  return value
      .map((item) {
        if (item is! String) throw FormatException('Invalid $key item.');
        return item;
      })
      .toList(growable: false);
}

String? _first(List<String> values) => values.isEmpty ? null : values.first;
