import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/network/api_failure.dart';
import '../data/medical_record_models.dart';
import '../data/medical_record_write_models.dart';

/// The pure logic of the « Modifier les données » editor (G2.1-A2): what was
/// read ([EditorBaseline]), what the user typed ([EditorDraft]), and the
/// request each changed section sends ([planSections]).
///
/// Rules (ADR-012 rules 3–5, SB1 §4a):
/// - a section the user did not change is not sent;
/// - professional items are shown, never sent; the patient's own items keep
///   their `itemId` (and an allergy keeps its severity);
/// - every own declared medication is sent, past ones unchanged, because the
///   save replaces the whole own list;
/// - local checks mirror the server only to show messages at once; the server
///   stays the authority. Errors use the API field paths and kinds, so local
///   and server errors share one French text ([recordFieldMessage]).
///
/// Nothing here logs; `toString` never shows a value.

/// The blood type values the selector offers, then « Je ne sais pas ».
const bloodTypeValues = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
const bloodTypeUnknown = 'UNKNOWN';

/// Input limits (SB1 §4a, counted in characters after trimming).
const maxLabelLength = 160;
const maxDosageLength = 80;
const maxListItems = 50;
const minHeightCm = 30.0;
const maxHeightCm = 300.0;
const maxWeightKg = 500.0;
const minTimesPerDay = 1;
const maxTimesPerDay = 6;
const minDurationValue = 1;
const maxDurationValue = 365;

/// Africa/Tunis is UTC+01:00 all year (the server's date rule).
const Duration _tunisOffset = Duration(hours: 1);

/// The editor sections, in save order.
const editorSections = [
  RecordSection.bloodType,
  RecordSection.measurements,
  RecordSection.allergies,
  RecordSection.conditions,
  RecordSection.declaredMedications,
];

/// What the editor read for one subject. Immutable.
@immutable
class EditorBaseline {
  const EditorBaseline({
    required this.bloodType,
    required this.bloodTypeLocked,
    required this.bloodTypeVersion,
    required this.heightCm,
    required this.weightKg,
    required this.measurementsVersion,
    required this.allergies,
    required this.allergiesVersion,
    required this.conditions,
    required this.conditionsVersion,
    required this.currentMedications,
    required this.pastDeclared,
    required this.medicationsVersion,
  });

  factory EditorBaseline.read(
    MedicalDataRecord record,
    MedicationSnapshot medications,
  ) => EditorBaseline(
    bloodType: bloodTypeOf(record),
    bloodTypeLocked:
        !record.bloodTypeAuthor.isEditableByPatient &&
        record.bloodTypeVersion > 0,
    bloodTypeVersion: record.bloodTypeVersion,
    heightCm: record.heightCm,
    weightKg: record.weightKg,
    measurementsVersion: record.measurementsVersion,
    allergies: record.allergyItems,
    allergiesVersion: record.allergiesVersion,
    conditions: record.conditionItems,
    conditionsVersion: record.conditionsVersion,
    currentMedications: medications.current,
    pastDeclared: List.unmodifiable(
      medications.past.where((item) => item.isDeclaredByPatient),
    ),
    medicationsVersion: medications.listVersion,
  );

  /// `null` (never recorded), [bloodTypeUnknown] (« Je ne sais pas »: the
  /// read shows no value but the section has a version) or a group.
  final String? bloodType;

  /// Set by a professional: shown, never sent (ADR-012 rule 3).
  final bool bloodTypeLocked;
  final int bloodTypeVersion;
  final double? heightCm;
  final double? weightKg;
  final int measurementsVersion;

  /// Every item, own and professional.
  final List<RecordItem> allergies;
  final int allergiesVersion;
  final List<RecordItem> conditions;
  final int conditionsVersion;

  /// Every current medication: prescriptions (read-only) and own declared.
  final List<MedicationRecord> currentMedications;

  /// The patient's own past declared items: not shown in the editor, sent
  /// back unchanged.
  final List<MedicationRecord> pastDeclared;
  final int medicationsVersion;

  List<MedicationRecord> get ownCurrentDeclared => List.unmodifiable(
    currentMedications.where((item) => item.isDeclaredByPatient),
  );

  List<MedicationRecord> get readOnlyCurrentMedications => List.unmodifiable(
    currentMedications.where((item) => !item.isDeclaredByPatient),
  );

  bool get hasAnyValue =>
      bloodType != null ||
      heightCm != null ||
      weightKg != null ||
      allergies.isNotEmpty ||
      conditions.isNotEmpty ||
      currentMedications.isNotEmpty ||
      pastDeclared.isNotEmpty;

  /// This baseline with [section] taken from a fresh read (after a conflict
  /// or a save); every other section stays as it was.
  EditorBaseline withSection(
    RecordSection section, {
    MedicalDataRecord? record,
    MedicationSnapshot? medications,
  }) {
    final fresh = EditorBaseline.read(
      record ?? _recordOf(this),
      medications ?? _snapshotOf(this),
    );
    return EditorBaseline(
      bloodType: section == RecordSection.bloodType
          ? fresh.bloodType
          : bloodType,
      bloodTypeLocked: section == RecordSection.bloodType
          ? fresh.bloodTypeLocked
          : bloodTypeLocked,
      bloodTypeVersion: section == RecordSection.bloodType
          ? fresh.bloodTypeVersion
          : bloodTypeVersion,
      heightCm: section == RecordSection.measurements
          ? fresh.heightCm
          : heightCm,
      weightKg: section == RecordSection.measurements
          ? fresh.weightKg
          : weightKg,
      measurementsVersion: section == RecordSection.measurements
          ? fresh.measurementsVersion
          : measurementsVersion,
      allergies: section == RecordSection.allergies
          ? fresh.allergies
          : allergies,
      allergiesVersion: section == RecordSection.allergies
          ? fresh.allergiesVersion
          : allergiesVersion,
      conditions: section == RecordSection.conditions
          ? fresh.conditions
          : conditions,
      conditionsVersion: section == RecordSection.conditions
          ? fresh.conditionsVersion
          : conditionsVersion,
      currentMedications: section == RecordSection.declaredMedications
          ? fresh.currentMedications
          : currentMedications,
      pastDeclared: section == RecordSection.declaredMedications
          ? fresh.pastDeclared
          : pastDeclared,
      medicationsVersion: section == RecordSection.declaredMedications
          ? fresh.medicationsVersion
          : medicationsVersion,
    );
  }

  @override
  String toString() => 'EditorBaseline';
}

/// The blood type as the editor holds it (see [EditorBaseline.bloodType]).
String? bloodTypeOf(MedicalDataRecord record) {
  final value = record.bloodType;
  if (value != null && bloodTypeValues.contains(value)) return value;
  return record.bloodTypeVersion > 0 ? bloodTypeUnknown : null;
}

/// One medication row as typed. [key] is the row's local identity (for its
/// field errors); [itemId] is set for an own item read from the record.
@immutable
class MedicationInput {
  const MedicationInput({
    required this.key,
    required this.name,
    this.itemId,
    this.dosageText = '',
    this.timesPerDay,
    this.durationText = '',
    this.durationUnit = DurationUnit.day,
    this.startedOn,
  });

  /// The row of an own declared item, as read.
  factory MedicationInput.of(int key, MedicationRecord item) => MedicationInput(
    key: key,
    itemId: item.itemId,
    name: item.name ?? '',
    dosageText: item.dosageText ?? '',
    timesPerDay: item.timesPerDay,
    durationText: item.duration == null ? '' : '${item.duration!.value}',
    durationUnit: _knownUnit(item.duration?.unit),
    startedOn: item.startedOn,
  );

  final int key;
  final String? itemId;
  final String name;
  final String dosageText;
  final int? timesPerDay;
  final String durationText;
  final DurationUnit durationUnit;

  /// Kept as read (`YYYY-MM-DD`): the editor has no start date field.
  final String? startedOn;

  @override
  String toString() => 'MedicationInput(key: $key)';
}

/// What the user typed, for every section. Immutable.
@immutable
class EditorDraft {
  const EditorDraft({
    required this.bloodType,
    required this.heightText,
    required this.weightText,
    required this.allergyLabels,
    required this.conditionLabels,
    required this.medications,
  });

  /// The draft that matches [baseline] exactly (nothing changed).
  factory EditorDraft.of(EditorBaseline baseline) {
    var key = 0;
    return EditorDraft(
      bloodType: baseline.bloodType,
      heightText: formatMeasurement(baseline.heightCm),
      weightText: formatMeasurement(baseline.weightKg),
      allergyLabels: _ownLabels(baseline.allergies),
      conditionLabels: _ownLabels(baseline.conditions),
      medications: [
        for (final item in baseline.ownCurrentDeclared)
          MedicationInput.of(key++, item),
      ],
    );
  }

  /// `null`: nothing chosen (never sent).
  final String? bloodType;
  final String heightText;
  final String weightText;

  /// The selected own labels (professional items are not part of the draft).
  final List<String> allergyLabels;
  final List<String> conditionLabels;

  /// The visible own declared rows, in screen order.
  final List<MedicationInput> medications;

  @override
  String toString() => 'EditorDraft';
}

/// One field error: the API path (as the server would send it) and its kind.
@immutable
class EditorFieldError {
  const EditorFieldError(this.path, this.kind);

  final String path;
  final ApiFieldErrorKind kind;

  @override
  bool operator ==(Object other) =>
      other is EditorFieldError && other.path == path && other.kind == kind;

  @override
  int get hashCode => Object.hash(path, kind);

  @override
  String toString() => 'EditorFieldError($path, ${kind.name})';
}

/// What one section needs on « Enregistrer ».
@immutable
sealed class SectionPlan {
  const SectionPlan();
}

/// Untouched: nothing is sent.
final class SectionUnchanged extends SectionPlan {
  const SectionUnchanged();
}

/// Refused locally: nothing is sent; [errors] are shown on the fields.
final class SectionInvalid extends SectionPlan {
  const SectionInvalid(this.errors);

  final List<EditorFieldError> errors;
}

/// Ready to send. Exactly one of the payload fields is set, by section.
final class SectionReadyToSave extends SectionPlan {
  const SectionReadyToSave.bloodType(String this.bloodType)
    : heightCm = null,
      weightKg = null,
      allergies = null,
      conditions = null,
      medications = null,
      medicationKeys = const [];

  const SectionReadyToSave.measurements({this.heightCm, this.weightKg})
    : bloodType = null,
      allergies = null,
      conditions = null,
      medications = null,
      medicationKeys = const [];

  const SectionReadyToSave.allergies(List<AllergyDraft> this.allergies)
    : bloodType = null,
      heightCm = null,
      weightKg = null,
      conditions = null,
      medications = null,
      medicationKeys = const [];

  const SectionReadyToSave.conditions(List<ConditionDraft> this.conditions)
    : bloodType = null,
      heightCm = null,
      weightKg = null,
      allergies = null,
      medications = null,
      medicationKeys = const [];

  const SectionReadyToSave.medications(
    List<DeclaredMedicationDraft> this.medications,
    this.medicationKeys,
  ) : bloodType = null,
      heightCm = null,
      weightKg = null,
      allergies = null,
      conditions = null;

  final String? bloodType;
  final double? heightCm;
  final double? weightKg;
  final List<AllergyDraft>? allergies;
  final List<ConditionDraft>? conditions;
  final List<DeclaredMedicationDraft>? medications;

  /// For medications: the row key of each sent item, `null` for a past item
  /// sent back unchanged. Maps a server error `items[n]` to its row.
  final List<int?> medicationKeys;
}

/// The plan of every editor section. [now] is the clock (for the start date).
Map<RecordSection, SectionPlan> planSections(
  EditorBaseline baseline,
  EditorDraft draft, {
  required DateTime now,
}) => {
  RecordSection.bloodType: planBloodType(baseline, draft),
  RecordSection.measurements: planMeasurements(baseline, draft),
  RecordSection.allergies: planAllergies(baseline, draft),
  RecordSection.conditions: planConditions(baseline, draft),
  RecordSection.declaredMedications: planMedications(baseline, draft, now: now),
};

SectionPlan planBloodType(EditorBaseline baseline, EditorDraft draft) {
  final value = draft.bloodType;
  if (baseline.bloodTypeLocked ||
      value == null ||
      value == baseline.bloodType) {
    return const SectionUnchanged();
  }
  if (value != bloodTypeUnknown && !bloodTypeValues.contains(value)) {
    return const SectionInvalid([
      EditorFieldError('value', ApiFieldErrorKind.invalidFormat),
    ]);
  }
  return SectionReadyToSave.bloodType(value);
}

SectionPlan planMeasurements(EditorBaseline baseline, EditorDraft draft) {
  final height = _measurement(
    'heightCm',
    draft.heightText,
    baseline.heightCm,
    inRange: (value) => value >= minHeightCm && value <= maxHeightCm,
  );
  final weight = _measurement(
    'weightKg',
    draft.weightText,
    baseline.weightKg,
    inRange: (value) => value > 0 && value <= maxWeightKg,
  );
  final errors = [?height.error, ?weight.error];
  if (errors.isNotEmpty) return SectionInvalid(errors);
  if (height.changed == null && weight.changed == null) {
    return const SectionUnchanged();
  }
  return SectionReadyToSave.measurements(
    heightCm: height.changed,
    weightKg: weight.changed,
  );
}

SectionPlan planAllergies(EditorBaseline baseline, EditorDraft draft) {
  final own = _ownByKey(baseline.allergies);
  final errors = _labelErrors(draft.allergyLabels, baseline.allergies);
  if (errors.isNotEmpty) return SectionInvalid(errors);
  final items = [
    for (final label in draft.allergyLabels)
      switch (own[labelKey(label)]) {
        final item? => AllergyDraft(
          itemId: item.itemId,
          label: item.label,
          severity: item.severity,
        ),
        null => AllergyDraft(label: label.trim()),
      },
  ];
  final before = [
    for (final item in own.values)
      AllergyDraft(
        itemId: item.itemId,
        label: item.label,
        severity: item.severity,
      ),
  ];
  if (_sameSet(items.map((i) => i.toJson()), before.map((i) => i.toJson()))) {
    return const SectionUnchanged();
  }
  return SectionReadyToSave.allergies(List.unmodifiable(items));
}

/// The app never sends `critical`: the server sets it (B6, ADR-012).
SectionPlan planConditions(EditorBaseline baseline, EditorDraft draft) {
  final own = _ownByKey(baseline.conditions);
  final errors = _labelErrors(draft.conditionLabels, baseline.conditions);
  if (errors.isNotEmpty) return SectionInvalid(errors);
  final items = [
    for (final label in draft.conditionLabels)
      switch (own[labelKey(label)]) {
        final item? => ConditionDraft(itemId: item.itemId, label: item.label),
        null => ConditionDraft(label: label.trim()),
      },
  ];
  final before = [
    for (final item in own.values)
      ConditionDraft(itemId: item.itemId, label: item.label),
  ];
  if (_sameSet(items.map((i) => i.toJson()), before.map((i) => i.toJson()))) {
    return const SectionUnchanged();
  }
  return SectionReadyToSave.conditions(List.unmodifiable(items));
}

SectionPlan planMedications(
  EditorBaseline baseline,
  EditorDraft draft, {
  required DateTime now,
}) {
  final ownIds = {
    for (final item in baseline.ownCurrentDeclared) ?item.itemId,
    for (final item in baseline.pastDeclared) ?item.itemId,
  };
  final errors = <EditorFieldError>[];
  final sent = <DeclaredMedicationDraft>[];
  final keys = <int?>[];
  final seen = <String>{};
  final today = tunisToday(now);
  final rows = draft.medications;
  for (var index = 0; index < rows.length; index++) {
    final row = rows[index];
    final at = 'items[$index]';
    final name = row.name.trim();
    if (name.isEmpty) {
      errors.add(EditorFieldError('$at.name', ApiFieldErrorKind.required));
    } else if (name.runes.length > maxLabelLength) {
      errors.add(EditorFieldError('$at.name', ApiFieldErrorKind.tooLong));
    } else if (hasForbiddenCharacter(name)) {
      errors.add(EditorFieldError('$at.name', ApiFieldErrorKind.invalid));
    } else if (!seen.add(labelKey(name))) {
      errors.add(EditorFieldError('$at.name', ApiFieldErrorKind.duplicate));
    }
    final dosage = row.dosageText.trim();
    if (dosage.runes.length > maxDosageLength) {
      errors.add(EditorFieldError('$at.dosageText', ApiFieldErrorKind.tooLong));
    } else if (hasForbiddenCharacter(dosage)) {
      errors.add(EditorFieldError('$at.dosageText', ApiFieldErrorKind.invalid));
    }
    final times = row.timesPerDay;
    if (times != null && (times < minTimesPerDay || times > maxTimesPerDay)) {
      errors.add(
        EditorFieldError('$at.timesPerDay', ApiFieldErrorKind.outOfRange),
      );
    }
    final duration = _duration(row, '$at.duration.value', errors);
    final startedOn = _startedOn(row.startedOn, '$at.startedOn', today, errors);
    sent.add(
      DeclaredMedicationDraft(
        itemId: ownIds.contains(row.itemId) ? row.itemId : null,
        name: name,
        dosageText: dosage.isEmpty ? null : dosage,
        timesPerDay: times,
        duration: duration,
        startedOn: startedOn,
      ),
    );
    keys.add(row.key);
  }
  // Past own items go back unchanged; a visible row with the same name is
  // the duplicate. One map of the rows by name: O(rows + past items).
  final pastStart = sent.length;
  final rowByName = <String, int>{};
  for (var index = 0; index < rows.length; index++) {
    rowByName.putIfAbsent(labelKey(rows[index].name), () => index);
  }
  for (final item in baseline.pastDeclared) {
    final draftOfPast = _declaredOf(item);
    final index = rowByName[labelKey(draftOfPast.name)];
    if (index != null) {
      errors.add(
        EditorFieldError('items[$index].name', ApiFieldErrorKind.duplicate),
      );
    }
    sent.add(draftOfPast);
    keys.add(null);
  }
  if (pastStart + baseline.pastDeclared.length > maxListItems) {
    errors.add(const EditorFieldError('items', ApiFieldErrorKind.tooLong));
  }
  if (errors.isNotEmpty) return SectionInvalid(List.unmodifiable(errors));
  final before = [
    for (final item in baseline.ownCurrentDeclared) _declaredOf(item),
    for (final item in baseline.pastDeclared) _declaredOf(item),
  ];
  if (_sameList(sent, before)) return const SectionUnchanged();
  return SectionReadyToSave.medications(
    List.unmodifiable(sent),
    List.unmodifiable(keys),
  );
}

/// The error of adding [label] as a new chip next to [existing] labels
/// (instant message on the « Autre… » field); `null` when it can be added.
/// A label already present (same letters, any case) is a duplicate.
ApiFieldErrorKind? newChipError(String label, Iterable<String> existing) {
  final trimmed = label.trim();
  if (trimmed.isEmpty) return ApiFieldErrorKind.required;
  if (trimmed.runes.length > maxLabelLength) return ApiFieldErrorKind.tooLong;
  if (hasForbiddenCharacter(trimmed)) return ApiFieldErrorKind.invalid;
  final key = labelKey(trimmed);
  if (existing.any((other) => labelKey(other) == key)) {
    return ApiFieldErrorKind.duplicate;
  }
  return null;
}

/// The comparison key of a label: trimmed, lower case (the server also
/// compares labels without case).
String labelKey(String label) => label.trim().toLowerCase();

/// A control character (Cc) or a direction override (U+202A–U+202E,
/// U+2066–U+2069): the server refuses them (INVALID).
bool hasForbiddenCharacter(String text) => text.runes.any(
  (rune) =>
      rune <= 0x1F ||
      (rune >= 0x7F && rune <= 0x9F) ||
      (rune >= 0x202A && rune <= 0x202E) ||
      (rune >= 0x2066 && rune <= 0x2069),
);

/// Today's date in Africa/Tunis.
DateTime tunisToday(DateTime now) {
  final tunis = now.toUtc().add(_tunisOffset);
  return DateTime(tunis.year, tunis.month, tunis.day);
}

/// A measurement as the field shows it: empty without a value, no trailing
/// `.0`, else one decimal.
String formatMeasurement(double? value) {
  if (value == null) return '';
  return value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);
}

/// The number typed in a measurement field (`,` or `.`); `null` when empty
/// or not a number.
double? parseMeasurement(String text) {
  final value = double.tryParse(text.trim().replaceAll(',', '.'));
  return value == null || !value.isFinite ? null : value;
}

// ---- helpers ----

final class _Measurement {
  const _Measurement({this.changed, this.error});

  final double? changed;
  final EditorFieldError? error;
}

/// A measurement field: unchanged when the text is the read value's text.
/// An empty field can't erase a recorded value (the save has no way to
/// delete it), so it is refused as required.
_Measurement _measurement(
  String path,
  String text,
  double? before, {
  required bool Function(double value) inRange,
}) {
  final trimmed = text.trim();
  if (trimmed == formatMeasurement(before)) return const _Measurement();
  if (trimmed.isEmpty) {
    return _Measurement(
      error: EditorFieldError(path, ApiFieldErrorKind.required),
    );
  }
  final value = parseMeasurement(trimmed);
  if (value == null) {
    return _Measurement(
      error: EditorFieldError(path, ApiFieldErrorKind.invalidFormat),
    );
  }
  if (!inRange(value)) {
    return _Measurement(
      error: EditorFieldError(path, ApiFieldErrorKind.outOfRange),
    );
  }
  return _Measurement(changed: value);
}

MedicationDuration? _duration(
  MedicationInput row,
  String path,
  List<EditorFieldError> errors,
) {
  final text = row.durationText.trim();
  if (text.isEmpty) return null;
  final value = int.tryParse(text);
  if (value == null) {
    errors.add(EditorFieldError(path, ApiFieldErrorKind.invalidFormat));
    return null;
  }
  if (value < minDurationValue || value > maxDurationValue) {
    errors.add(EditorFieldError(path, ApiFieldErrorKind.outOfRange));
    return null;
  }
  return MedicationDuration(value: value, unit: row.durationUnit);
}

DateTime? _startedOn(
  String? text,
  String path,
  DateTime today,
  List<EditorFieldError> errors,
) {
  if (text == null) return null;
  final date = _calendarDate(text);
  if (date == null) {
    errors.add(EditorFieldError(path, ApiFieldErrorKind.invalidFormat));
    return null;
  }
  if (date.isAfter(today)) {
    errors.add(EditorFieldError(path, ApiFieldErrorKind.outOfRange));
  }
  return date;
}

DateTime? _calendarDate(String text) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(text);
  if (match == null) return null;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final date = DateTime(year, month, day);
  return date.year == year && date.month == month && date.day == day
      ? date
      : null;
}

DeclaredMedicationDraft _declaredOf(MedicationRecord item) {
  final dosage = item.dosageText?.trim();
  final duration = item.duration;
  return DeclaredMedicationDraft(
    itemId: item.itemId,
    name: (item.name ?? '').trim(),
    dosageText: dosage == null || dosage.isEmpty ? null : dosage,
    timesPerDay: item.timesPerDay,
    duration: duration == null
        ? null
        : MedicationDuration(
            value: duration.value,
            unit: _knownUnit(duration.unit),
          ),
    startedOn: item.startedOn == null ? null : _calendarDate(item.startedOn!),
  );
}

DurationUnit _knownUnit(DurationUnit? unit) =>
    unit == null || unit == DurationUnit.unknown ? DurationUnit.day : unit;

List<String> _ownLabels(List<RecordItem> items) => List.unmodifiable(
  items
      .where((item) => item.author.isEditableByPatient)
      .map((item) => item.label),
);

Map<String, RecordItem> _ownByKey(List<RecordItem> items) => {
  for (final item in items)
    if (item.author.isEditableByPatient) labelKey(item.label): item,
};

/// Label checks of a chip list, as the server makes them: required, length,
/// forbidden characters, duplicates (also against professional items) and
/// at most [maxListItems] items, professional ones included.
List<EditorFieldError> _labelErrors(List<String> labels, List<RecordItem> all) {
  final errors = <EditorFieldError>[];
  final seen = {
    for (final item in all)
      if (!item.author.isEditableByPatient) labelKey(item.label),
  };
  for (var index = 0; index < labels.length; index++) {
    final path = 'items[$index].label';
    final label = labels[index].trim();
    if (label.isEmpty) {
      errors.add(EditorFieldError(path, ApiFieldErrorKind.required));
    } else if (label.runes.length > maxLabelLength) {
      errors.add(EditorFieldError(path, ApiFieldErrorKind.tooLong));
    } else if (hasForbiddenCharacter(label)) {
      errors.add(EditorFieldError(path, ApiFieldErrorKind.invalid));
    } else if (!seen.add(labelKey(label))) {
      errors.add(EditorFieldError(path, ApiFieldErrorKind.duplicate));
    }
  }
  final professional = all.where((i) => !i.author.isEditableByPatient).length;
  if (labels.length + professional > maxListItems) {
    errors.add(const EditorFieldError('items', ApiFieldErrorKind.tooLong));
  }
  return errors;
}

bool _sameSet(
  Iterable<Map<String, Object?>> left,
  Iterable<Map<String, Object?>> right,
) {
  final a = left.map(jsonEncode).toList()..sort();
  final b = right.map(jsonEncode).toList()..sort();
  return listEquals(a, b);
}

bool _sameList(
  List<DeclaredMedicationDraft> left,
  List<DeclaredMedicationDraft> right,
) => listEquals(
  left.map((item) => jsonEncode(item.toJson())).toList(),
  right.map((item) => jsonEncode(item.toJson())).toList(),
);

MedicalDataRecord _recordOf(EditorBaseline baseline) => MedicalDataRecord(
  bloodType: baseline.bloodType == bloodTypeUnknown ? null : baseline.bloodType,
  allergies: const [],
  allergiesStatus: RecordListStatus.unknown,
  conditions: const [],
  conditionsStatus: RecordListStatus.unknown,
  heightCm: baseline.heightCm,
  weightKg: baseline.weightKg,
  bmi: null,
  bloodTypeAuthor: baseline.bloodTypeLocked
      ? RecordAuthor.professional
      : RecordAuthor.patient,
  bloodTypeVersion: baseline.bloodTypeVersion,
  allergyItems: baseline.allergies,
  allergiesVersion: baseline.allergiesVersion,
  conditionItems: baseline.conditions,
  conditionsVersion: baseline.conditionsVersion,
  measurementsVersion: baseline.measurementsVersion,
);

MedicationSnapshot _snapshotOf(EditorBaseline baseline) => MedicationSnapshot(
  current: baseline.currentMedications,
  past: baseline.pastDeclared,
  listVersion: baseline.medicationsVersion,
);
