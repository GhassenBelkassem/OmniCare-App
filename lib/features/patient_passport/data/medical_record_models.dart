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
    this.bloodTypeAuthor = RecordAuthor.unknown,
    this.bloodTypeVersion = 0,
    this.allergyItems = const [],
    this.allergiesVersion = 0,
    this.conditionItems = const [],
    this.conditionsVersion = 0,
    this.measurementsAuthor = RecordAuthor.unknown,
    this.measurementsVersion = 0,
  });

  final String? bloodType;
  final List<String> allergies;
  final RecordListStatus allergiesStatus;
  final List<String> conditions;
  final RecordListStatus conditionsStatus;
  final double? heightCm;
  final double? weightKg;
  final double? bmi;

  // G2.1-A1 (SB1 §4b, additive). A section never recorded has version 0;
  // each version is the `expectedVersion` of that section's next save.

  /// Who set the blood type: a PROFESSIONAL value is read-only for the patient.
  final RecordAuthor bloodTypeAuthor;
  final int bloodTypeVersion;

  /// The allergies with their id, author and severity (same order as [allergies]).
  final List<RecordItem> allergyItems;
  final int allergiesVersion;
  final List<RecordItem> conditionItems;
  final int conditionsVersion;
  final RecordAuthor measurementsAuthor;
  final int measurementsVersion;

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
      bloodTypeAuthor: RecordAuthor.fromServer(
        lifeSafety['bloodTypeAuthorType'],
      ),
      bloodTypeVersion: _version(lifeSafety['bloodTypeVersion']),
      allergyItems: _items(lifeSafety['allergyItems']),
      allergiesVersion: _version(lifeSafety['allergiesVersion']),
      conditionItems: _items(lifeSafety['conditionItems']),
      conditionsVersion: _version(lifeSafety['conditionsVersion']),
      measurementsAuthor: RecordAuthor.fromServer(body['authorType']),
      measurementsVersion: _version(body['version']),
    );
  }
}

/// Who recorded a value. Unknown values read as [unknown], which the editor
/// treats as read-only (never as the patient's own).
enum RecordAuthor {
  patient,
  professional,
  unknown;

  static RecordAuthor fromServer(Object? value) => switch (value) {
    'PATIENT' => patient,
    'PROFESSIONAL' => professional,
    _ => unknown,
  };

  /// Only the patient's own items can be edited or removed (ADR-012).
  bool get isEditableByPatient => this == patient;
}

/// Allergy severity; an absent severity is `null`, an unknown one [unknown].
enum AllergySeverity {
  mild('MILD'),
  moderate('MODERATE'),
  severe('SEVERE'),
  unknown('');

  const AllergySeverity(this.serverValue);

  final String serverValue;

  static AllergySeverity? fromServer(Object? value) => switch (value) {
    null => null,
    'MILD' => mild,
    'MODERATE' => moderate,
    'SEVERE' => severe,
    _ => unknown,
  };
}

/// One allergy or condition, with its identity and author (SB1 §4b).
@immutable
class RecordItem {
  const RecordItem({
    required this.itemId,
    required this.label,
    required this.author,
    this.severity,
  });

  final String itemId;
  final String label;
  final RecordAuthor author;

  /// Allergies only; always `null` for conditions.
  final AllergySeverity? severity;

  factory RecordItem.fromJson(Map<String, Object?> json) => RecordItem(
    itemId: _required(json['itemId'], 'itemId'),
    label: _required(json['label'], 'label'),
    author: RecordAuthor.fromServer(json['authorType']),
    severity: AllergySeverity.fromServer(_text(json['severity'])),
  );

  /// No label: medical text never reaches a log.
  @override
  String toString() => 'RecordItem(author: ${author.name})';
}

/// Where a treatment comes from: an OmniCare prescription (read-only) or a
/// medication the patient declared (outside OmniCare).
enum MedicationSource {
  prescription,
  patientDeclared,
  unknown;

  static MedicationSource fromServer(Object? value) => switch (value) {
    'PRESCRIPTION' => prescription,
    'PATIENT_DECLARED' => patientDeclared,
    _ => unknown,
  };
}

enum DurationUnit {
  day('DAY'),
  week('WEEK'),
  month('MONTH'),
  unknown('');

  const DurationUnit(this.serverValue);

  final String serverValue;

  static DurationUnit fromServer(Object? value) => switch (value) {
    'DAY' => day,
    'WEEK' => week,
    'MONTH' => month,
    _ => unknown,
  };
}

/// A declared course length: [value] (1–365) of [unit].
@immutable
class MedicationDuration {
  const MedicationDuration({required this.value, required this.unit});

  final int value;
  final DurationUnit unit;

  static MedicationDuration? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final value = json['value'];
    if (value is! int) return null;
    return MedicationDuration(
      value: value,
      unit: DurationUnit.fromServer(json['unit']),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MedicationDuration && other.value == value && other.unit == unit;

  @override
  int get hashCode => Object.hash(value, unit);
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
    this.source = MedicationSource.unknown,
    this.author = RecordAuthor.unknown,
    this.itemId,
    this.duration,
    this.startedOn,
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

  // G2.1-A1 (SB1 §4b, additive).
  final MedicationSource source;
  final RecordAuthor author;

  /// The declared item's id (sent back as `itemId` to keep or edit it);
  /// `null` for a prescription.
  final String? itemId;
  final MedicationDuration? duration;

  /// `YYYY-MM-DD` (Africa/Tunis date).
  final String? startedOn;

  /// A patient-declared medication the patient may edit or remove.
  bool get isDeclaredByPatient =>
      source == MedicationSource.patientDeclared &&
      author == RecordAuthor.patient &&
      itemId != null;

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
      source: MedicationSource.fromServer(json['source']),
      author: RecordAuthor.fromServer(json['authorType']),
      itemId: _text(json['itemId']),
      duration: MedicationDuration.fromJson(json['duration']),
      startedOn: _text(json['startedOn']),
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
  const RecordPage({
    required this.items,
    required this.hasMore,
    this.listStatus,
    this.listVersion,
    this.nextCursor,
  });

  final List<T> items;

  /// The server has more than this page.
  final bool hasMore;

  /// The cursor of the next page (G2.1-A2: the editor reads every page of
  /// the medications to keep the patient's past declared items).
  final String? nextCursor;

  /// Medications only (SB1 §4b): the declared list's status, and its version
  /// (the `expectedVersion` of `PUT …/medications/declared`). `null` on other
  /// lists or when the server does not send them.
  final RecordListStatus? listStatus;
  final int? listVersion;

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
      nextCursor: _text(json['nextCursor']),
      listStatus: json.containsKey('listStatus')
          ? RecordListStatus.fromServer(json['listStatus'])
          : null,
      listVersion: json['listVersion'] is int
          ? json['listVersion'] as int
          : null,
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

/// A missing or malformed version reads as 0 ("never recorded").
int _version(Object? value) => value is int && value >= 0 ? value : 0;

/// Items with a missing id or label fail the read (nothing partial).
List<RecordItem> _items(Object? value) => value is List
    ? List.unmodifiable(
        value.map((item) => RecordItem.fromJson(_object(item, 'item'))),
      )
    : const [];

/// Every medication of a subject, read for the editor (G2.1-A2).
@immutable
class MedicationSnapshot {
  const MedicationSnapshot({
    required this.current,
    required this.past,
    required this.listVersion,
  });

  final List<MedicationRecord> current;
  final List<MedicationRecord> past;

  /// The `expectedVersion` of the declared-medications save.
  final int listVersion;
}
