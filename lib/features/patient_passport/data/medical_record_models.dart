import 'package:flutter/foundation.dart';

/// Domain models of the patient's « Dossier médical » (G2-FT-3), mapped from
/// `GET /api/v1/me/medical-record/*` (G2-FT-1 §5). Immutable; no `dynamic`.
/// A missing required field throws a [FormatException], which the repository
/// turns into a failure: nothing partial is ever shown.

/// Whose record is read. The app sends only SELF or a family member id; the
/// server resolves the medical record (the app never sends an MRS id).
@immutable
sealed class RecordSubject {
  const RecordSubject();

  /// The `subject` query value: `SELF` or `FAMILY:<familyMemberId>`.
  String get queryValue;
}

final class SelfRecordSubject extends RecordSubject {
  const SelfRecordSubject();

  @override
  String get queryValue => 'SELF';

  @override
  bool operator ==(Object other) => other is SelfRecordSubject;

  @override
  int get hashCode => (SelfRecordSubject).hashCode;
}

final class FamilyRecordSubject extends RecordSubject {
  const FamilyRecordSubject(this.familyMemberId);

  final String familyMemberId;

  @override
  String get queryValue => 'FAMILY:$familyMemberId';

  @override
  bool operator ==(Object other) =>
      other is FamilyRecordSubject && other.familyMemberId == familyMemberId;

  @override
  int get hashCode => familyMemberId.hashCode;
}

/// Whether a list (allergies, conditions) was recorded. An empty list alone
/// never means "none": only [noneKnown] does.
enum RecordListStatus {
  /// Never recorded. Also the fallback for any value the app does not know.
  unknown,

  /// Recorded as "none".
  noneKnown,

  /// Recorded items.
  list;

  static RecordListStatus fromServer(Object? value) => switch (value) {
    'NONE_KNOWN' => noneKnown,
    'LIST' => list,
    _ => unknown,
  };
}

@immutable
class MedicalDataRecord {
  const MedicalDataRecord({
    required this.bloodType,
    required this.allergies,
    required this.allergiesStatus,
    required this.conditions,
    required this.conditionsStatus,
    required this.heightCm,
    required this.weightKg,
    required this.bmi,
  });

  final String? bloodType;
  final List<String> allergies;
  final RecordListStatus allergiesStatus;
  final List<String> conditions;
  final RecordListStatus conditionsStatus;
  final double? heightCm;
  final double? weightKg;
  final double? bmi;

  factory MedicalDataRecord.fromJson(Map<String, Object?> json) {
    final lifeSafety = _object(json['lifeSafety'], 'lifeSafety');
    final body = _object(json['bodyMeasurements'], 'bodyMeasurements');
    return MedicalDataRecord(
      bloodType: _text(lifeSafety['bloodType']),
      allergies: _texts(lifeSafety['allergies']),
      allergiesStatus: RecordListStatus.fromServer(
        lifeSafety['allergiesStatus'],
      ),
      conditions: _texts(lifeSafety['criticalConditions']),
      conditionsStatus: RecordListStatus.fromServer(
        lifeSafety['conditionsStatus'],
      ),
      heightCm: _number(body['heightCm']),
      weightKg: _number(body['weightKg']),
      bmi: _number(body['bmi']),
    );
  }
}

/// One treatment (current or past), summary fields only.
@immutable
class MedicationRecord {
  const MedicationRecord({
    required this.id,
    this.name,
    this.strength,
    this.doseAmount,
    this.doseUnit,
    this.dosageText,
    this.timesPerDay,
    this.frequencyText,
    this.expectedEndOn,
    this.displayStatus,
  });

  final String id;
  final String? name;
  final String? strength;
  final double? doseAmount;
  final String? doseUnit;
  final String? dosageText;
  final int? timesPerDay;
  final String? frequencyText;
  final String? expectedEndOn;
  final String? displayStatus;

  factory MedicationRecord.fromJson(Map<String, Object?> json) {
    final timesPerDay = json['timesPerDay'];
    return MedicationRecord(
      id: _required(json['medicationStatementId'], 'medicationStatementId'),
      name: _text(json['name']),
      strength: _text(json['strength']),
      doseAmount: _number(json['doseAmount']),
      doseUnit: _text(json['doseUnit']),
      dosageText: _text(json['dosageText']),
      timesPerDay: timesPerDay is int ? timesPerDay : null,
      frequencyText: _text(json['frequencyText']),
      expectedEndOn: _text(json['expectedEndOn']),
      displayStatus: _text(json['displayStatus']),
    );
  }
}

/// A completed consultation, summary fields only.
@immutable
class ConsultationRecord {
  const ConsultationRecord({
    required this.id,
    required this.completedAt,
    required this.isShareable,
    this.doctorFirstName,
    this.doctorLastName,
    this.specialty,
    this.reason,
    this.sharingVersion,
  });

  final String id;

  /// UTC instant; displayed in Africa/Tunis.
  final DateTime completedAt;
  final String? doctorFirstName;
  final String? doctorLastName;
  final String? specialty;
  final String? reason;
  final bool isShareable;
  final int? sharingVersion;

  factory ConsultationRecord.fromJson(Map<String, Object?> json) {
    final professional = json['professional'];
    final doctor = professional is Map<String, Object?>
        ? professional
        : const <String, Object?>{};
    final completedAt = DateTime.tryParse(
      _required(json['completedAt'], 'completedAt'),
    );
    if (completedAt == null) {
      throw const FormatException('completedAt is not an instant');
    }
    final version = json['sharingPolicyVersion'];
    return ConsultationRecord(
      id: _required(json['consultationId'], 'consultationId'),
      completedAt: completedAt.toUtc(),
      doctorFirstName: _text(doctor['firstName']),
      doctorLastName: _text(doctor['lastName']),
      specialty: _text(doctor['specialty']),
      reason: _text(json['reason']),
      isShareable: json['sharingState'] == 'SHAREABLE',
      sharingVersion: version is int ? version : null,
    );
  }

  ConsultationRecord withSharing({
    required bool isShareable,
    required int sharingVersion,
  }) => ConsultationRecord(
    id: id,
    completedAt: completedAt,
    isShareable: isShareable,
    doctorFirstName: doctorFirstName,
    doctorLastName: doctorLastName,
    specialty: specialty,
    reason: reason,
    sharingVersion: sharingVersion,
  );
}

/// The first page of a list (at most 20 items, G2-FT-3: never "fetch all").
@immutable
class RecordPage<T> {
  const RecordPage({required this.items, required this.hasMore});

  final List<T> items;

  /// The server has more than this page.
  final bool hasMore;

  static RecordPage<T> fromJson<T>(
    Map<String, Object?> json,
    T Function(Map<String, Object?> item) item,
  ) {
    final items = json['items'];
    if (items is! List) throw const FormatException('items is not a list');
    return RecordPage(
      items: List.unmodifiable(
        items.map((value) => item(_object(value, 'item'))),
      ),
      hasMore: json['nextCursor'] is String,
    );
  }
}

Map<String, Object?> _object(Object? value, String field) {
  if (value is Map<String, Object?>) return value;
  throw FormatException('$field is not an object');
}

String _required(Object? value, String field) {
  final text = _text(value);
  if (text == null) throw FormatException('$field is missing');
  return text;
}

String? _text(Object? value) =>
    value is String && value.trim().isNotEmpty ? value.trim() : null;

double? _number(Object? value) => value is num ? value.toDouble() : null;

List<String> _texts(Object? value) => value is List
    ? List.unmodifiable(value.map(_text).whereType<String>())
    : const [];
