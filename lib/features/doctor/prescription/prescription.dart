import 'dart:convert';

class PrescriptionEnvelope {
  const PrescriptionEnvelope({
    required this.prescriptionId,
    required this.prescriptionVersion,
    required this.clinicalRecordVersion,
    required this.status,
    required this.finalized,
    required this.medicationDecision,
    required this.signedAt,
    required this.signatureAlgorithm,
    required this.content,
  });
  final String? prescriptionId;
  final int prescriptionVersion;
  final int clinicalRecordVersion;
  final String status;
  final bool finalized;
  final String? medicationDecision;
  final DateTime? signedAt;
  final String? signatureAlgorithm;
  final PrescriptionDraft content;

  factory PrescriptionEnvelope.fromJson(Map<String, dynamic> json) {
    final version = json['prescriptionVersion'];
    final clinicalVersion = json['clinicalRecordVersion'];
    final schema = json['schemaVersion'];
    if (version is! int ||
        clinicalVersion is! int ||
        schema != 2 ||
        json['status'] is! String ||
        json['finalized'] is! bool) {
      throw const FormatException('Invalid prescription response.');
    }
    final content = json['prescription'];
    return PrescriptionEnvelope(
      prescriptionId: _text(json['prescriptionId']),
      prescriptionVersion: version,
      clinicalRecordVersion: clinicalVersion,
      status: json['status'] as String,
      finalized: json['finalized'] as bool,
      medicationDecision: _text(json['medicationDecision']),
      signedAt: DateTime.tryParse(_text(json['signedAt']) ?? ''),
      signatureAlgorithm: _text(json['signatureAlgorithm']),
      content: content is Map
          ? PrescriptionDraft.fromJson(content.cast<String, dynamic>())
          : PrescriptionDraft(),
    );
  }
}

class PrescriptionDraft {
  PrescriptionDraft({
    List<PrescriptionMedication>? medications,
    this.generalInstructions,
  }) : medications = medications ?? <PrescriptionMedication>[];
  List<PrescriptionMedication> medications;
  String? generalInstructions;
  factory PrescriptionDraft.fromJson(Map<String, dynamic> json) =>
      PrescriptionDraft(
        medications:
            (json['medications'] is List
                    ? json['medications'] as List
                    : const <dynamic>[])
                .whereType<Map>()
                .map(
                  (value) => PrescriptionMedication.fromJson(
                    value.cast<String, dynamic>(),
                  ),
                )
                .toList(),
        generalInstructions: _text(json['generalInstructions']),
      );
  Map<String, dynamic> toJson() => {
    'medications': medications.map((value) => value.toJson()).toList(),
    'generalInstructions': generalInstructions,
  };
  PrescriptionDraft copy() => PrescriptionDraft.fromJson(toJson());
  String fingerprint() => jsonEncode(toJson());
}

class PrescriptionMedication {
  PrescriptionMedication({
    required this.itemId,
    this.replacesItemId,
    this.medicationCode,
    this.name,
    this.strength,
    this.doseAmount = 1,
    this.doseUnit = 'mg',
    this.route = 'ORAL',
    this.timesPerDay = 1,
    this.frequencyText,
    this.durationValue,
    this.durationUnit,
    this.quantity,
    this.instructions,
  });
  String itemId;
  String? replacesItemId;
  String? medicationCode;
  String? name;
  String? strength;
  double doseAmount;
  String doseUnit;
  String route;
  int? timesPerDay;
  String? frequencyText;
  int? durationValue;
  String? durationUnit;
  int? quantity;
  String? instructions;
  factory PrescriptionMedication.fromJson(Map<String, dynamic> json) {
    final dose = json['dose'] is Map
        ? (json['dose'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    final frequency = json['frequency'] is Map
        ? (json['frequency'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    final duration = json['duration'] is Map
        ? (json['duration'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    return PrescriptionMedication(
      itemId: json['itemId']?.toString() ?? '',
      replacesItemId: _text(json['replacesItemId']),
      medicationCode: _text(json['medicationCode']),
      name: _text(json['name']),
      strength: _text(json['strength']),
      doseAmount: (dose['amount'] as num?)?.toDouble() ?? 1,
      doseUnit: _text(dose['unit']) ?? 'mg',
      route: _text(json['route']) ?? 'ORAL',
      timesPerDay: frequency['timesPerDay'] as int?,
      frequencyText: _text(frequency['text']),
      durationValue: duration['value'] as int?,
      durationUnit: _text(duration['unit']),
      quantity: json['quantity'] as int?,
      instructions: _text(json['instructions']),
    );
  }
  Map<String, dynamic> toJson() => {
    'itemId': itemId,
    'replacesItemId': replacesItemId,
    'medicationCode': medicationCode,
    'name': name,
    'strength': strength,
    'dose': {'amount': doseAmount, 'unit': doseUnit},
    'route': route,
    'frequency': {'timesPerDay': timesPerDay, 'text': frequencyText},
    'duration': durationValue == null
        ? null
        : {'value': durationValue, 'unit': durationUnit},
    'quantity': quantity,
    'instructions': instructions,
  };

  int? get durationDays => durationUnit == 'DAY' ? durationValue : null;
  set durationDays(int? value) {
    durationValue = value;
    durationUnit = value == null ? null : 'DAY';
  }
}

String? _text(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  return value.trim();
}

String? nullablePrescriptionText(String value) {
  final text = value.trim();
  return text.isEmpty ? null : text;
}
