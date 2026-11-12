import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/result/result.dart';
import '../data/medical_record_models.dart';
import '../data/medical_record_repository.dart';

/// The cards of the « Dossier médical », each loaded and retried on its own.
enum MedicalRecordSection {
  medicalData,
  currentMedications,
  pastMedications,
  consultations,
}

/// The state of one section. [SectionIdle] means "not requested yet".
@immutable
sealed class SectionState<T> {
  const SectionState();
}

final class SectionIdle<T> extends SectionState<T> {
  const SectionIdle();
}

final class SectionLoading<T> extends SectionState<T> {
  const SectionLoading();
}

final class SectionReady<T> extends SectionState<T> {
  const SectionReady(this.value);
  final T value;
}

final class SectionFailed<T> extends SectionState<T> {
  const SectionFailed(this.failure);
  final ApiFailure failure;
}

/// Holds the record of the subject on screen (G2-FT-3). Medical data and the
/// current treatments load when a subject is shown; past treatments and the
/// history load on first use. A subject change cancels in-flight requests and
/// clears every section before reloading; [clear] (logout, account change)
/// drops everything.
class MedicalRecordViewModel extends ChangeNotifier {
  MedicalRecordViewModel({required MedicalRecordRepository repository})
    : _repository = repository;

  final MedicalRecordRepository _repository;
  final Map<MedicalRecordSection, CancelToken> _inFlight = {};

  RecordSubject? _subject;

  /// Bumped on every subject change and clear: a response from an older
  /// generation is dropped, whatever its outcome.
  int _generation = 0;
  bool _disposed = false;

  SectionState<MedicalDataRecord> _medicalData = const SectionIdle();
  SectionState<RecordPage<MedicationRecord>> _currentMedications =
      const SectionIdle();
  SectionState<RecordPage<MedicationRecord>> _pastMedications =
      const SectionIdle();
  SectionState<RecordPage<ConsultationRecord>> _consultations =
      const SectionIdle();

  RecordSubject? get subject => _subject;
  SectionState<MedicalDataRecord> get medicalData => _medicalData;
  SectionState<RecordPage<MedicationRecord>> medications({
    required bool current,
  }) => current ? _currentMedications : _pastMedications;
  SectionState<RecordPage<ConsultationRecord>> get consultations =>
      _consultations;

  /// Shows [subject]. The same subject keeps its data; another one cancels
  /// what is in flight, clears every section, then loads the first cards.
  void show(RecordSubject subject) {
    if (_disposed) return;
    if (_subject == subject) return;
    _reset();
    _subject = subject;
    notifyListeners();
    _load(MedicalRecordSection.medicalData);
    _load(MedicalRecordSection.currentMedications);
  }

  /// Loads [section] the first time it is needed (past treatments, history).
  void ensureLoaded(MedicalRecordSection section) {
    if (_stateOf(section) is SectionIdle) _load(section);
  }

  /// Reloads [section] only.
  void retry(MedicalRecordSection section) => _load(section);

  /// Applies a sharing change already confirmed by the server to one
  /// consultation of the loaded page.
  void applyConsultationSharing({
    required String consultationId,
    required bool isShareable,
    required int sharingVersion,
  }) {
    final state = _consultations;
    if (state is! SectionReady<RecordPage<ConsultationRecord>>) return;
    _consultations = SectionReady(
      RecordPage(
        items: List.unmodifiable(
          state.value.items.map(
            (item) => item.id == consultationId
                ? item.withSharing(
                    isShareable: isShareable,
                    sharingVersion: sharingVersion,
                  )
                : item,
          ),
        ),
        hasMore: state.value.hasMore,
      ),
    );
    notifyListeners();
  }

  /// Drops every record value and cancels what is in flight (logout, account
  /// change). Medical data must not outlive the session.
  void clear() {
    _reset();
    _subject = null;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _reset();
    super.dispose();
  }

  void _reset() {
    _generation++;
    for (final token in _inFlight.values) {
      token.cancel();
    }
    _inFlight.clear();
    _medicalData = const SectionIdle();
    _currentMedications = const SectionIdle();
    _pastMedications = const SectionIdle();
    _consultations = const SectionIdle();
  }

  SectionState<Object?> _stateOf(MedicalRecordSection section) =>
      switch (section) {
        MedicalRecordSection.medicalData => _medicalData,
        MedicalRecordSection.currentMedications => _currentMedications,
        MedicalRecordSection.pastMedications => _pastMedications,
        MedicalRecordSection.consultations => _consultations,
      };

  Future<void> _load(MedicalRecordSection section) async {
    final subject = _subject;
    if (_disposed || subject == null) return;
    _inFlight.remove(section)?.cancel();
    final token = CancelToken();
    _inFlight[section] = token;
    final generation = _generation;
    _set(section, loading: true);
    notifyListeners();

    final result = await _fetch(section, subject, token);
    if (_disposed || generation != _generation || token.isCancelled) return;
    _inFlight.remove(section);
    _set(section, result: result);
    notifyListeners();
  }

  Future<Result<Object>> _fetch(
    MedicalRecordSection section,
    RecordSubject subject,
    CancelToken token,
  ) => switch (section) {
    MedicalRecordSection.medicalData => _repository.medicalData(
      subject,
      cancelToken: token,
    ),
    MedicalRecordSection.currentMedications => _repository.medications(
      subject,
      current: true,
      cancelToken: token,
    ),
    MedicalRecordSection.pastMedications => _repository.medications(
      subject,
      current: false,
      cancelToken: token,
    ),
    MedicalRecordSection.consultations => _repository.consultations(
      subject,
      cancelToken: token,
    ),
  };

  void _set(
    MedicalRecordSection section, {
    bool loading = false,
    Result<Object>? result,
  }) {
    switch (section) {
      case MedicalRecordSection.medicalData:
        _medicalData = _next(loading, result);
      case MedicalRecordSection.currentMedications:
        _currentMedications = _next(loading, result);
      case MedicalRecordSection.pastMedications:
        _pastMedications = _next(loading, result);
      case MedicalRecordSection.consultations:
        _consultations = _next(loading, result);
    }
  }

  static SectionState<T> _next<T>(bool loading, Result<Object>? result) {
    if (loading || result == null) return SectionLoading<T>();
    return switch (result) {
      Ok(:final value) => SectionReady<T>(value as T),
      Err(:final failure) => SectionFailed<T>(failure),
    };
  }
}
