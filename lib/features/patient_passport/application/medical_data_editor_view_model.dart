import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/result/result.dart';
import '../data/medical_record_models.dart';
import '../data/medical_record_repository.dart';
import '../data/medical_record_write_models.dart';
import '../data/medical_record_write_repository.dart';
import 'medical_data_editor_draft.dart';
import 'medical_record_view_model.dart';

/// How one « Enregistrer » ended.
enum EditorSaveOutcome {
  /// Every changed section is saved (or nothing changed): close the editor.
  done,

  /// Refused on the device: nothing was sent; the fields show why.
  invalid,

  /// At least one section failed: the editor stays open with everything
  /// typed; sections that saved stay saved.
  failed,
}

/// The « Modifier les données de … » editor for one subject (G2.1-A2).
///
/// - [load] reads the medical data and every medication page (the save of the
///   declared medications replaces the whole own list).
/// - [save] sends the changed sections only, in [editorSections] order, each
///   with its own [SaveAttempt]: « Réessayer » with the same content reuses
///   the key; [edited] drops it.
/// - A 409 `RECORD_VERSION_CONFLICT` reloads that section only; the screen
///   keeps the user's draft on top and shows the conflict text.
/// - Errors are kept by field location ([fieldError]) as path + kind; the
///   screen turns them into French text.
///
/// Logs nothing; failures carry codes only.
class MedicalDataEditorViewModel extends ChangeNotifier {
  MedicalDataEditorViewModel({
    required MedicalRecordRepository reads,
    required MedicalRecordWriteRepository writes,
    required this.subject,
    DateTime Function() now = DateTime.now,
  }) : _reads = reads,
       _writes = writes,
       _now = now;

  final MedicalRecordRepository _reads;
  final MedicalRecordWriteRepository _writes;
  final DateTime Function() _now;

  /// Every save goes to this subject only (ADR-012 rule 2).
  final RecordSubject subject;

  final Map<RecordSection, SaveAttempt> _attempts = {
    for (final section in editorSections) section: SaveAttempt(),
  };
  final Map<RecordSection, ApiFailure> _failures = {};
  final Map<String, EditorFieldError> _fieldErrors = {};
  final List<RecordWarning> _warnings = [];
  final CancelToken _cancel = CancelToken();

  SectionState<EditorBaseline> _state = const SectionIdle();
  bool _saving = false;
  bool _savedSomething = false;
  bool _disposed = false;

  SectionState<EditorBaseline> get state => _state;

  EditorBaseline? get baseline => switch (_state) {
    SectionReady(:final value) => value,
    _ => null,
  };

  bool get saving => _saving;

  /// True once any section saved: the record must reload when the editor
  /// closes, even after a partial failure.
  bool get savedSomething => _savedSomething;

  /// The warnings of the saves so far (they never block).
  List<RecordWarning> get warnings => List.unmodifiable(_warnings);

  /// The failure of [section]'s last save (shown with « Réessayer »).
  ApiFailure? failureOf(RecordSection section) => _failures[section];

  /// The error of one field location (see [fieldKey]).
  EditorFieldError? fieldError(String key) => _fieldErrors[key];

  /// The idempotency key [section] would reuse on « Réessayer » (tests).
  @visibleForTesting
  String? pendingKeyOf(RecordSection section) => _attempts[section]!.pendingKey;

  Future<void> load() async {
    if (_disposed) return;
    _state = const SectionLoading();
    notifyListeners();
    final record = _reads.medicalData(subject, cancelToken: _cancel);
    final medications = _reads.editorMedications(subject, cancelToken: _cancel);
    final recordResult = await record;
    final medicationResult = await medications;
    if (_disposed) return;
    _state = switch ((recordResult, medicationResult)) {
      (Ok(value: final r), Ok(value: final m)) => SectionReady(
        EditorBaseline.read(r, m),
      ),
      (Err(:final failure), _) ||
      (_, Err(:final failure)) => SectionFailed(failure),
    };
    notifyListeners();
  }

  /// The user changed something in [section]: its next save is a new action
  /// (new key), and its old messages go away.
  void edited(RecordSection section) {
    _attempts[section]!.reset();
    final hadFailure = _failures.remove(section) != null;
    final hadFieldErrors = _clearFieldErrors(section);
    if ((hadFailure || hadFieldErrors) && !_disposed) notifyListeners();
  }

  /// One « Enregistrer » (or « Réessayer »): changed sections only, in
  /// order. A section that saved stays saved if a later one fails.
  Future<EditorSaveOutcome> save(EditorDraft draft) async {
    final baseline = this.baseline;
    if (_disposed || _saving || baseline == null) {
      return EditorSaveOutcome.failed;
    }
    final plans = planSections(baseline, draft, now: _now());
    _fieldErrors.clear();
    final rowKeys = [for (final row in draft.medications) row.key];
    for (final entry in plans.entries) {
      if (entry.value case SectionInvalid(:final errors)) {
        _failures.remove(entry.key);
        _putFieldErrors(entry.key, errors, rowKeys);
      }
    }
    if (_fieldErrors.isNotEmpty) {
      notifyListeners();
      return EditorSaveOutcome.invalid;
    }

    _saving = true;
    notifyListeners();
    final saved = <RecordSection>{};
    for (final section in editorSections) {
      final plan = plans[section];
      if (plan is! SectionReadyToSave) {
        _failures.remove(section);
        continue;
      }
      final result = await _send(section, plan, baseline);
      if (_disposed) return EditorSaveOutcome.failed;
      switch (result) {
        case Ok(:final value):
          _failures.remove(section);
          _warnings.addAll(value.warnings);
          saved.add(section);
          _savedSomething = true;
        case Err(:final failure):
          _recordFailure(section, failure, plan);
          if (failure is RecordVersionConflictFailure) {
            await _reload({section});
          }
      }
    }
    final failed = _failures.isNotEmpty || _fieldErrors.isNotEmpty;
    // The editor stays open: read back what saved, so new items get their
    // ids and the next save compares with the server.
    if (failed && saved.isNotEmpty) await _reload(saved);
    _saving = false;
    if (!_disposed) notifyListeners();
    return failed ? EditorSaveOutcome.failed : EditorSaveOutcome.done;
  }

  @override
  void dispose() {
    _disposed = true;
    _cancel.cancel();
    super.dispose();
  }

  Future<Result<SectionSaved>> _send(
    RecordSection section,
    SectionReadyToSave plan,
    EditorBaseline baseline,
  ) {
    final attempt = _attempts[section]!;
    return switch (section) {
      RecordSection.bloodType => _writes.saveBloodType(
        subject: subject,
        bloodType: plan.bloodType!,
        expectedVersion: baseline.bloodTypeVersion,
        attempt: attempt,
        cancelToken: _cancel,
      ),
      RecordSection.measurements => _writes.saveMeasurements(
        subject: subject,
        heightCm: plan.heightCm,
        weightKg: plan.weightKg,
        expectedVersion: baseline.measurementsVersion,
        attempt: attempt,
        cancelToken: _cancel,
      ),
      RecordSection.allergies => _writes.saveAllergies(
        subject: subject,
        items: plan.allergies!,
        expectedVersion: baseline.allergiesVersion,
        attempt: attempt,
        cancelToken: _cancel,
      ),
      RecordSection.conditions => _writes.saveConditions(
        subject: subject,
        items: plan.conditions!,
        expectedVersion: baseline.conditionsVersion,
        attempt: attempt,
        cancelToken: _cancel,
      ),
      RecordSection.declaredMedications => _writes.saveDeclaredMedications(
        subject: subject,
        items: plan.medications!,
        expectedVersion: baseline.medicationsVersion,
        attempt: attempt,
        cancelToken: _cancel,
      ),
    };
  }

  /// A rejected field is shown on its field; any other failure on the
  /// section, with « Réessayer ».
  void _recordFailure(
    RecordSection section,
    ApiFailure failure,
    SectionPlan plan,
  ) {
    final fields = [
      for (final entry in failure.fieldErrors.entries)
        EditorFieldError(_bracketed(entry.key), entry.value),
    ];
    if (failure.code == 'VALIDATION_ERROR' && fields.isNotEmpty) {
      _failures.remove(section);
      _putFieldErrors(
        section,
        fields,
        plan is SectionReadyToSave ? plan.medicationKeys : const [],
      );
    } else {
      _failures[section] = failure;
    }
  }

  /// Reads [sections] again and takes them into the baseline. A failed read
  /// leaves the baseline as it was (the next save then meets the conflict
  /// again and reloads).
  Future<void> _reload(Set<RecordSection> sections) async {
    var current = baseline;
    if (current == null) return;
    final needsRecord = sections.any(
      (s) => s != RecordSection.declaredMedications,
    );
    if (needsRecord) {
      final read = await _reads.medicalData(subject, cancelToken: _cancel);
      if (read case Ok(:final value)) {
        for (final section in sections) {
          if (section == RecordSection.declaredMedications) continue;
          current = current!.withSection(section, record: value);
        }
      }
    }
    if (sections.contains(RecordSection.declaredMedications)) {
      final read = await _reads.editorMedications(
        subject,
        cancelToken: _cancel,
      );
      if (read case Ok(:final value)) {
        current = current!.withSection(
          RecordSection.declaredMedications,
          medications: value,
        );
      }
    }
    if (!_disposed && current != null) _state = SectionReady(current);
  }

  /// [rowKeys]: the medication row of each list index (`null` for a past
  /// item sent back unchanged).
  void _putFieldErrors(
    RecordSection section,
    List<EditorFieldError> errors,
    List<int?> rowKeys,
  ) {
    for (final error in errors) {
      _fieldErrors.putIfAbsent(
        fieldKey(section, error.path, rowKeys: rowKeys),
        () => error,
      );
    }
  }

  bool _clearFieldErrors(RecordSection section) {
    final prefix = _sectionPrefix(section);
    final before = _fieldErrors.length;
    _fieldErrors.removeWhere(
      (key, _) => key == prefix || key.startsWith('$prefix:'),
    );
    return _fieldErrors.length != before;
  }
}

/// The screen location of an error at API [path] in [section]:
/// - `bloodType`;
/// - `measurements:heightCm`, `measurements:weightKg`;
/// - `allergies` / `conditions` (shown on the « Autre… » field);
/// - `medications:<row key>.<field>` for a row (`name`, `dosageText`,
///   `timesPerDay`, `duration`, `startedOn`), or `medications` for the list
///   (or a past item, which has no row).
///
/// [rowKeys] maps a list index to its medication row.
String fieldKey(
  RecordSection section,
  String path, {
  List<int?> rowKeys = const [],
}) {
  final prefix = _sectionPrefix(section);
  switch (section) {
    case RecordSection.bloodType:
      return prefix;
    case RecordSection.measurements:
      return path == 'weightKg' ? '$prefix:weightKg' : '$prefix:heightCm';
    case RecordSection.allergies || RecordSection.conditions:
      return prefix;
    case RecordSection.declaredMedications:
      final match = RegExp(r'^items\[(\d+)\]\.?([A-Za-z]*)').firstMatch(path);
      if (match == null) return prefix;
      final index = int.parse(match.group(1)!);
      final row = index < rowKeys.length ? rowKeys[index] : null;
      if (row == null) return prefix;
      final field = match.group(2)!;
      return '$prefix:$row.${field.isEmpty ? 'name' : field}';
  }
}

String _sectionPrefix(RecordSection section) => switch (section) {
  RecordSection.bloodType => 'bloodType',
  RecordSection.measurements => 'measurements',
  RecordSection.allergies => 'allergies',
  RecordSection.conditions => 'conditions',
  RecordSection.declaredMedications => 'medications',
};

/// `items.2.label` (MRS style) → `items[2].label` (the API style).
String _bracketed(String path) =>
    path.replaceAllMapped(RegExp(r'\.(\d+)(?=\.|$)'), (m) => '[${m[1]}]');

/// Makes the editor of one subject (wired in `main.dart`: constructor
/// injection of the shared repositories).
class MedicalDataEditorFactory {
  const MedicalDataEditorFactory({
    required MedicalRecordRepository reads,
    required MedicalRecordWriteRepository writes,
  }) : _reads = reads,
       _writes = writes;

  final MedicalRecordRepository _reads;
  final MedicalRecordWriteRepository _writes;

  MedicalDataEditorViewModel create(RecordSubject subject) =>
      MedicalDataEditorViewModel(
        reads: _reads,
        writes: _writes,
        subject: subject,
      );
}
