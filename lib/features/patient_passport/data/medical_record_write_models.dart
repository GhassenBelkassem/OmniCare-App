import 'package:flutter/foundation.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/utils/uuid_v4.dart';
import 'medical_record_models.dart';

/// What the patient sends when saving a « Dossier médical » section
/// (G2.1-SB1 §4a). Immutable. The server sets the author: no draft carries an
/// author, a source or any other server-owned field (R1). `toString` never
/// shows a label, a name or a value (no medical text in logs).

/// The five sections the patient can save, with their route under
/// `/me/medical-record/`.
enum RecordSection {
  bloodType('life-safety/blood-type'),
  allergies('life-safety/allergies'),
  conditions('life-safety/conditions'),
  measurements('body-measurements'),
  declaredMedications('medications/declared');

  const RecordSection(this.path);

  final String path;
}

/// One allergy as sent. [itemId] keeps or edits an existing own item; without
/// it the item is new. An own item left out of the list is deleted.
@immutable
class AllergyDraft {
  const AllergyDraft({required this.label, this.itemId, this.severity});

  final String? itemId;
  final String label;

  /// `null` or [AllergySeverity.unknown]: no severity is sent.
  final AllergySeverity? severity;

  Map<String, Object?> toJson() => {
    if (itemId != null) 'itemId': itemId,
    'label': label,
    if (severity != null && severity != AllergySeverity.unknown)
      'severity': severity!.serverValue,
  };

  @override
  String toString() => 'AllergyDraft';
}

/// One condition as sent (no severity: the server refuses it).
@immutable
class ConditionDraft {
  const ConditionDraft({required this.label, this.itemId});

  final String? itemId;
  final String label;

  Map<String, Object?> toJson() => {
    if (itemId != null) 'itemId': itemId,
    'label': label,
  };

  @override
  String toString() => 'ConditionDraft';
}

/// One patient-declared medication (outside OmniCare) as sent.
@immutable
class DeclaredMedicationDraft {
  const DeclaredMedicationDraft({
    required this.name,
    this.itemId,
    this.dosageText,
    this.timesPerDay,
    this.duration,
    this.startedOn,
  });

  final String? itemId;
  final String name;
  final String? dosageText;
  final int? timesPerDay;
  final MedicationDuration? duration;

  /// A calendar date (only year, month and day are sent).
  final DateTime? startedOn;

  Map<String, Object?> toJson() => {
    if (itemId != null) 'itemId': itemId,
    'name': name,
    if (dosageText != null) 'dosageText': dosageText,
    if (timesPerDay != null) 'timesPerDay': timesPerDay,
    if (duration != null)
      'duration': {
        'value': duration!.value,
        'unit': duration!.unit.serverValue,
      },
    if (startedOn != null) 'startedOn': calendarDate(startedOn!),
  };

  @override
  String toString() => 'DeclaredMedicationDraft';
}

/// `YYYY-MM-DD` from the date's own fields (no time zone conversion).
String calendarDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

/// A warning returned with a successful save. Warnings never block a save.
enum RecordWarning {
  heightUnusual,
  weightUnusual,
  unknown;

  static RecordWarning fromServer(Object? value) => switch (value) {
    'HEIGHT_UNUSUAL' => heightUnusual,
    'WEIGHT_UNUSUAL' => weightUnusual,
    _ => unknown,
  };
}

/// The answer to a save: the section and its new version (send it as the next
/// `expectedVersion`). No value is echoed.
@immutable
class SectionSaved {
  const SectionSaved({
    required this.section,
    required this.version,
    required this.warnings,
  });

  final String section;
  final int version;
  final List<RecordWarning> warnings;

  factory SectionSaved.fromJson(Map<String, Object?> json) {
    final section = json['section'];
    final version = json['version'];
    if (section is! String || section.isEmpty) {
      throw const FormatException('section is missing');
    }
    if (version is! int || version < 1) {
      throw const FormatException('version is missing');
    }
    final warnings = json['warnings'];
    return SectionSaved(
      section: section,
      version: version,
      warnings: warnings is List
          ? List.unmodifiable(warnings.map(RecordWarning.fromServer))
          : const [],
    );
  }
}

/// 409 `RECORD_VERSION_CONFLICT`: the section changed since it was read. The
/// screen reloads the section, keeps what the user typed, and lets them save
/// again with [currentVersion] (SB1 §3d). Carries no value.
class RecordVersionConflictFailure extends ApiFailure {
  const RecordVersionConflictFailure({
    required this.currentVersion,
    super.requestId,
  }) : super(
         kind: ApiFailureKind.conflict,
         code: recordVersionConflictCode,
         statusCode: 409,
       );

  static const recordVersionConflictCode = 'RECORD_VERSION_CONFLICT';

  final int currentVersion;

  @override
  String get logSummary => '${super.logSummary} currentVersion=$currentVersion';
}

/// The Idempotency-Key of one « Enregistrer » (roadmap §5, SB1 §3e).
///
/// - The first save of some content makes a new UUID v4.
/// - « Réessayer » with the same content reuses it, so the server applies the
///   change once even if the first answer was lost.
/// - It is dropped on success, when the content changes, or on [reset] (for
///   example after the server said the key was used for other content).
///
/// The content is compared through a fingerprint built by the repository
/// (route, subject and body). It stays in memory only and is never logged.
class SaveAttempt {
  SaveAttempt({String Function() newKey = generateUuidV4}) : _newKey = newKey;

  final String Function() _newKey;
  String? _key;
  String? _fingerprint;

  /// The key in use, if a save of some content has started and not succeeded.
  String? get pendingKey => _key;

  /// The key for this content: the pending one when the content is the same,
  /// otherwise a new one.
  String keyFor(String fingerprint) {
    final key = _key;
    if (key != null && _fingerprint == fingerprint) return key;
    _fingerprint = fingerprint;
    return _key = _newKey();
  }

  /// The save succeeded, or the user changed the content: the next save is a
  /// new action with a new key.
  void reset() {
    _key = null;
    _fingerprint = null;
  }

  @override
  String toString() => 'SaveAttempt(pending: ${_key != null})';
}
