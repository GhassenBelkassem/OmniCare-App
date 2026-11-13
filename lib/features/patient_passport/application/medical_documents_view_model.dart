import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/result/result.dart';
import '../data/medical_document_models.dart';
import '../data/medical_document_repository.dart';
import '../data/medical_record_models.dart';
import '../data/medical_record_write_models.dart';
import 'medical_data_editor_draft.dart';
import 'medical_record_view_model.dart';

/// The « Documents » tab of « Dossier médical » (G2.1-A4), for the person on
/// screen: the first page of the list, upload, status polling of the
/// documents being analysed, and delete. Nothing is logged; no title or file
/// name reaches `toString` or a failure.

/// Starts a delayed callback; [Timer.new] in the app, a fake in tests.
typedef DelayScheduler = Timer Function(Duration delay, void Function() run);

/// Polling of one document's status: 2 s, 4 s, 8 s, 16 s, then every 30 s.
const pollFirstDelay = Duration(seconds: 2);
const pollMaxDelay = Duration(seconds: 30);

/// The wait before status read number [attempt] (0-based).
Duration pollDelay(int attempt) {
  final seconds = pollFirstDelay.inSeconds << (attempt.clamp(0, 5));
  return seconds >= pollMaxDelay.inSeconds
      ? pollMaxDelay
      : Duration(seconds: seconds);
}

/// What the « N documents enregistrés » line can truthfully say: the
/// server gives no total, so with a next page the count is « [loaded]+ ».
typedef DocumentsCount = ({int loaded, bool more});

/// Title rule of the server (SB3 §4): 1–160 characters, at most 255 bytes
/// in UTF-8, no control or direction character.
const maxDocumentTitleBytes = 255;

/// The document date as typed in « Date du Document » (`jj/mm/aaaa`, also
/// `-` or `.`); `null` when it is not a real date.
DateTime? parseDocumentDate(String text) {
  final match = RegExp(
    r'^(\d{1,2})[/.\-](\d{1,2})[/.\-](\d{4})$',
  ).firstMatch(text.trim());
  if (match == null) return null;
  final day = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final year = int.parse(match.group(3)!);
  final date = DateTime(year, month, day);
  return date.year == year && date.month == month && date.day == day
      ? date
      : null;
}

/// The editor's checks before any request, by server field name (`title`,
/// `documentDate`, `file`), so local and server refusals share one French
/// text (`recordFieldMessage`). [now] is the clock (Tunis date).
Map<String, ApiFieldErrorKind> documentFormErrors({
  required String title,
  required String dateText,
  required DocumentFileSource? file,
  required DateTime now,
}) {
  final errors = <String, ApiFieldErrorKind>{};
  final trimmed = title.trim();
  if (trimmed.isEmpty) {
    errors['title'] = ApiFieldErrorKind.required;
  } else if (trimmed.runes.length > maxLabelLength ||
      utf8.encode(trimmed).length > maxDocumentTitleBytes) {
    errors['title'] = ApiFieldErrorKind.tooLong;
  } else if (hasForbiddenCharacter(trimmed)) {
    errors['title'] = ApiFieldErrorKind.invalid;
  }
  if (dateText.trim().isNotEmpty) {
    final date = parseDocumentDate(dateText);
    if (date == null) {
      errors['documentDate'] = ApiFieldErrorKind.invalidFormat;
    } else if (date.isAfter(tunisToday(now))) {
      errors['documentDate'] = ApiFieldErrorKind.outOfRange;
    }
  }
  if (file == null) {
    errors['file'] = ApiFieldErrorKind.required;
  } else if (MedicalDocumentRepository.fileRefusal(file) case final refusal?) {
    errors.addAll(refusal.fieldErrors);
  }
  return errors;
}

class MedicalDocumentsViewModel extends ChangeNotifier {
  MedicalDocumentsViewModel({
    required MedicalDocumentRepository repository,
    DelayScheduler schedule = Timer.new,
    DateTime Function() now = DateTime.now,
  }) : _repository = repository,
       _schedule = schedule,
       _now = now;

  final MedicalDocumentRepository _repository;
  final DelayScheduler _schedule;
  final DateTime Function() _now;

  RecordSubject? _subject;
  SectionState<List<MedicalDocument>> _state = const SectionIdle();
  bool _hasMore = false;
  CancelToken _cancel = CancelToken();
  final Map<String, Timer> _polls = {};

  /// Bumped on every subject change and clear: an older answer is dropped.
  int _generation = 0;
  bool _disposed = false;

  RecordSubject? get subject => _subject;
  SectionState<List<MedicalDocument>> get state => _state;

  /// The documents being polled (tests).
  @visibleForTesting
  Set<String> get polling => _polls.keys.toSet();

  DocumentsCount? get count => switch (_state) {
    SectionReady(:final value) => (loaded: value.length, more: _hasMore),
    _ => null,
  };

  /// The person on screen. Another person cancels what is in flight, stops
  /// polling and clears the list; nothing is read until [ensureLoaded].
  void select(RecordSubject subject) {
    if (_disposed || _subject == subject) return;
    _reset();
    _subject = subject;
    notifyListeners();
  }

  /// Reads the first page when the tab is shown (once per person).
  void ensureLoaded() {
    if (_state is SectionIdle) _load();
  }

  void retry() => _load();

  /// Drops everything (logout, account change).
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

  /// Sends a new document for the person on screen. On success it is put
  /// first in the list as sent (status from the answer) and its status is
  /// polled. A failure changes nothing: the editor keeps everything.
  Future<Result<UploadedDocument>> upload({
    required DocumentFileSource source,
    required DocumentUploadForm form,
    required SaveAttempt attempt,
  }) async {
    final subject = _subject;
    if (subject == null || _disposed) {
      return const Err(ApiFailure(kind: ApiFailureKind.unknown));
    }
    final generation = _generation;
    final result = await _repository.upload(
      subject: subject,
      source: source,
      form: form,
      attempt: attempt,
      cancelToken: _cancel,
    );
    if (result case Ok(
      :final value,
    ) when generation == _generation && !_disposed) {
      final added = MedicalDocument(
        documentId: value.documentId,
        type: form.type,
        status: value.status,
        createdAt: _now().toUtc(),
        title: form.title.trim(),
      );
      final current = switch (_state) {
        SectionReady(:final value) => value,
        _ => const <MedicalDocument>[],
      };
      _state = SectionReady(List.unmodifiable([added, ...current]));
      if (added.status.isProcessing) _startPolling(added.documentId);
      notifyListeners();
    }
    return result;
  }

  /// Deletes one document of the person on screen; it leaves the list only
  /// once the server confirmed (204).
  Future<Result<void>> delete(String documentId, SaveAttempt attempt) async {
    final subject = _subject;
    if (subject == null || _disposed) {
      return const Err(ApiFailure(kind: ApiFailureKind.unknown));
    }
    final generation = _generation;
    final result = await _repository.delete(
      subject: subject,
      documentId: documentId,
      attempt: attempt,
      cancelToken: _cancel,
    );
    if (result is Ok && generation == _generation && !_disposed) {
      _polls.remove(documentId)?.cancel();
      if (_state case SectionReady(:final value)) {
        _state = SectionReady(
          List.unmodifiable(value.where((d) => d.documentId != documentId)),
        );
      }
      notifyListeners();
    }
    return result;
  }

  void _reset() {
    _generation++;
    _cancel.cancel();
    _cancel = CancelToken();
    for (final timer in _polls.values) {
      timer.cancel();
    }
    _polls.clear();
    _state = const SectionIdle();
    _hasMore = false;
  }

  Future<void> _load() async {
    final subject = _subject;
    if (_disposed || subject == null) return;
    final generation = _generation;
    _state = const SectionLoading();
    notifyListeners();
    final result = await _repository.documents(subject, cancelToken: _cancel);
    if (_disposed || generation != _generation) return;
    switch (result) {
      case Ok(:final value):
        _state = SectionReady(value.items);
        _hasMore = value.nextCursor != null;
        for (final document in value.items) {
          if (document.status.isProcessing) _startPolling(document.documentId);
        }
      case Err(:final failure):
        _state = SectionFailed(failure);
    }
    notifyListeners();
  }

  /// One document at a time, never the list (roadmap §5).
  void _startPolling(String documentId) {
    if (_polls.containsKey(documentId)) return;
    _poll(documentId, 0);
  }

  void _poll(String documentId, int attempt) {
    final subject = _subject;
    if (subject == null || _disposed) return;
    final generation = _generation;
    _polls[documentId] = _schedule(pollDelay(attempt), () async {
      final result = await _repository.status(
        subject,
        documentId,
        cancelToken: _cancel,
      );
      if (_disposed || generation != _generation) return;
      if (!_polls.containsKey(documentId)) return; // deleted meanwhile
      switch (result) {
        case Ok(:final value):
          _replace(value);
          if (value.status.isProcessing) {
            _poll(documentId, attempt + 1);
          } else {
            _polls.remove(documentId);
          }
          notifyListeners();
        case Err(:final failure):
          if (failure.kind == ApiFailureKind.notFound) {
            _polls.remove(documentId);
          } else {
            _poll(documentId, attempt + 1);
          }
      }
    });
  }

  void _replace(MedicalDocument fresh) {
    if (_state case SectionReady(:final value)) {
      _state = SectionReady(
        List.unmodifiable([
          for (final document in value)
            if (document.documentId == fresh.documentId)
              MedicalDocument(
                documentId: fresh.documentId,
                type: fresh.type == MedicalDocumentType.unknown
                    ? document.type
                    : fresh.type,
                status: fresh.status,
                createdAt: document.createdAt,
                title: fresh.title ?? document.title,
                contentType: fresh.contentType ?? document.contentType,
                sizeBytes: fresh.sizeBytes ?? document.sizeBytes,
                pageCount: fresh.pageCount ?? document.pageCount,
              )
            else
              document,
        ]),
      );
    }
  }
}

/// Opens one AVAILABLE document page by page (G2.1-A4, D3): a watermarked
/// view session, then one PNG at a time. Only the page on screen is kept;
/// moving to another page or closing frees it. An expired session (410) is
/// renewed once by the repository.
class DocumentPagesController extends ChangeNotifier {
  DocumentPagesController({
    required MedicalDocumentRepository repository,
    required this.subject,
    required this.documentId,
  }) : _repository = repository;

  final MedicalDocumentRepository _repository;
  final RecordSubject subject;
  final String documentId;
  final CancelToken _cancel = CancelToken();

  DocumentViewSession? _session;
  SectionState<DocumentPageImage> _page = const SectionIdle();
  int _pageNumber = 1;
  bool _disposed = false;

  SectionState<DocumentPageImage> get page => _page;
  int get pageNumber => _pageNumber;
  int? get pageCount => _session?.pageCount;
  bool get hasNext => pageCount != null && _pageNumber < pageCount!;
  bool get hasPrevious => _pageNumber > 1;

  /// Opens the session and shows page 1.
  Future<void> open() async {
    _set(const SectionLoading());
    final opened = await _repository.openViewSession(
      subject,
      documentId,
      cancelToken: _cancel,
    );
    if (_disposed) return;
    switch (opened) {
      case Ok(:final value):
        _session = value;
        await _show(1);
      case Err(:final failure):
        _set(SectionFailed(failure));
    }
  }

  Future<void> next() async {
    if (hasNext) await _show(_pageNumber + 1);
  }

  Future<void> previous() async {
    if (hasPrevious) await _show(_pageNumber - 1);
  }

  /// « Réessayer »: the same page, or the session if it never opened.
  Future<void> retry() => _session == null ? open() : _show(_pageNumber);

  @override
  void dispose() {
    _disposed = true;
    _cancel.cancel();
    _page = const SectionIdle();
    super.dispose();
  }

  Future<void> _show(int pageNumber) async {
    final session = _session;
    if (session == null) return;
    _pageNumber = pageNumber;
    _set(const SectionLoading()); // the previous page is freed here
    final fetched = await _repository.fetchPage(
      subject: subject,
      documentId: documentId,
      session: session,
      pageNumber: pageNumber,
      cancelToken: _cancel,
    );
    if (_disposed) return;
    switch (fetched) {
      case Ok(:final value):
        _session = value.session;
        _set(SectionReady(value.page));
      case Err(:final failure):
        _set(SectionFailed(failure));
    }
  }

  void _set(SectionState<DocumentPageImage> state) {
    if (_disposed) return;
    _page = state;
    notifyListeners();
  }
}
