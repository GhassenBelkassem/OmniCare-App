// G2.1-A4: the « Documents » tab, logic only (CTO testing rule): the list and
// its count, the editor's checks, upload keys, status polling, the page
// viewer, delete and the person switch, against a fake documents API and a
// fake scheduler. No widget, no app run. Every value here is synthetic.
import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';

import 'package:omnicare_mobile/core/network/api_failure.dart';
import 'package:omnicare_mobile/core/result/result.dart';
import 'package:omnicare_mobile/features/patient_passport/application/medical_documents_view_model.dart';
import 'package:omnicare_mobile/features/patient_passport/application/medical_record_view_model.dart';
import 'package:omnicare_mobile/features/patient_passport/data/medical_document_api.dart';
import 'package:omnicare_mobile/features/patient_passport/data/medical_document_models.dart';
import 'package:omnicare_mobile/features/patient_passport/data/medical_document_repository.dart';
import 'package:omnicare_mobile/features/patient_passport/data/medical_record_models.dart';
import 'package:omnicare_mobile/features/patient_passport/data/medical_record_write_models.dart';
import 'package:omnicare_mobile/features/patient_passport/presentation/medical_record_messages.dart';
import 'package:omnicare_mobile/features/patient_passport/presentation/medical_record_presenter.dart';
import 'package:omnicare_mobile/l10n/omni_localizations.dart';

final _fr = lookupOmniLocalizations(const Locale('fr'));
const _self = SelfRecordSubject();
const _family = FamilyRecordSubject('fm-1');
const _secretTitle = 'titre-secret-zz';
const _secretFile = 'fichier-secret-zz.pdf';
final _now = DateTime.utc(2026, 11, 13, 10);

void main() {
  group('list and count', () {
    test('the first page of the person on screen; the count is true', () async {
      final f = _Fixture()..api.listItems = [_doc('d-1'), _doc('d-2')];
      f.vm.select(_family);
      f.vm.ensureLoaded();
      await pumpEventQueue();
      expect(f.api.calls, ['list FAMILY:fm-1 size=20']);
      final state = f.vm.state as SectionReady<List<MedicalDocument>>;
      expect(state.value.map((d) => d.documentId), ['d-1', 'd-2']);
      expect(documentsCountText(f.vm.count, _fr), '2 documents enregistrés');
    });

    test('count rule: one, none, more than the page, not read yet', () {
      expect(documentsCountText(null, _fr), '');
      expect(
        documentsCountText((loaded: 0, more: false), _fr),
        '0 documents enregistrés',
      );
      expect(
        documentsCountText((loaded: 1, more: false), _fr),
        '1 document enregistré',
      );
      expect(
        documentsCountText((loaded: 20, more: true), _fr),
        '20+ documents enregistrés',
      );
    });

    test('a next page makes the count « 20+ »', () async {
      final f = _Fixture()
        ..api.listItems = [for (var i = 0; i < 20; i++) _doc('d-$i')]
        ..api.nextCursor = 'c-2';
      await f.loaded(_self);
      expect(f.vm.count, (loaded: 20, more: true));
    });

    test('a failed list keeps its failure for « Réessayer »', () async {
      final f = _Fixture()..api.failList = _status(503, 'MRS_UNAVAILABLE');
      await f.loaded(_self);
      final failure = (f.vm.state as SectionFailed).failure;
      expect(recordFailureMessage(failure, _fr), _fr.apiCodeMrsUnavailable);
      f.vm.retry();
      await pumpEventQueue();
      expect(f.vm.state, isA<SectionReady<List<MedicalDocument>>>());
    });

    test('documents still analysed are polled one by one', () async {
      final f = _Fixture()
        ..api.listItems = [_doc('d-1', status: 'SCAN_PENDING'), _doc('d-2')];
      await f.loaded(_self);
      expect(f.vm.polling, {'d-1'});
    });
  });

  group('the editor checks, before any request', () {
    Map<String, ApiFieldErrorKind> errors({
      String title = 'Bilan',
      String date = '',
      DocumentFileSource? file,
      bool noFile = false,
    }) => documentFormErrors(
      title: title,
      dateText: date,
      file: noFile ? null : (file ?? _file()),
      now: _now,
    );

    test('15 Mo + 1 byte, a wrong type, no file', () {
      expect(
        errors(file: _file(size: MedicalDocumentRepository.maxFileBytes + 1)),
        {'file': ApiFieldErrorKind.tooLong},
      );
      expect(
        errors(file: _file(size: MedicalDocumentRepository.maxFileBytes)),
        isEmpty,
      );
      expect(errors(file: _file(name: 'scan.docx')), {
        'file': ApiFieldErrorKind.invalidFormat,
      });
      expect(errors(noFile: true), {'file': ApiFieldErrorKind.required});
      expect(
        recordFieldMessage('file', ApiFieldErrorKind.tooLong, _fr),
        'Fichier trop volumineux (15 Mo maximum).',
      );
      expect(
        recordFieldMessage('file', ApiFieldErrorKind.invalidFormat, _fr),
        'Format non accepté : PDF, JPG ou PNG.',
      );
    });

    test('a date in the future or not a date', () {
      expect(errors(date: '14/11/2026'), {
        'documentDate': ApiFieldErrorKind.outOfRange,
      });
      expect(errors(date: '13/11/2026'), isEmpty);
      expect(errors(date: '31/02/2026'), {
        'documentDate': ApiFieldErrorKind.invalidFormat,
      });
      expect(errors(date: 'hier'), {
        'documentDate': ApiFieldErrorKind.invalidFormat,
      });
      expect(
        recordFieldMessage('documentDate', ApiFieldErrorKind.outOfRange, _fr),
        'La date ne peut pas être dans le futur.',
      );
      expect(parseDocumentDate('5.3.2026'), DateTime(2026, 3, 5));
    });

    test('the name: required, 160 characters and 255 bytes, no control', () {
      expect(errors(title: '  '), {'title': ApiFieldErrorKind.required});
      expect(errors(title: 'a' * 161), {'title': ApiFieldErrorKind.tooLong});
      expect(errors(title: 'é' * 128), {'title': ApiFieldErrorKind.tooLong});
      expect(errors(title: 'é' * 127), isEmpty);
      expect(errors(title: 'a\u0007'), {'title': ApiFieldErrorKind.invalid});
    });

    test('a refused file never reaches the server', () async {
      final f = _Fixture();
      await f.loaded(_self);
      final result = await f.vm.upload(
        source: _file(size: MedicalDocumentRepository.maxFileBytes + 1),
        form: _form(),
        attempt: SaveAttempt(),
      );
      expect((result as Err).failure.fieldErrors, {
        'file': ApiFieldErrorKind.tooLong,
      });
      expect(f.api.uploads, isEmpty);
    });
  });

  group('upload', () {
    test(
      '202: the row is first, « En cours d\'analyse », and polled',
      () async {
        final f = _Fixture()..api.listItems = [_doc('d-old')];
        await f.loaded(_family);
        final result = await f.vm.upload(
          source: _file(),
          form: _form(),
          attempt: SaveAttempt(),
        );
        expect(result, isA<Ok<UploadedDocument>>());
        expect(f.api.uploads.single.subject, _family);
        final items = (f.vm.state as SectionReady<List<MedicalDocument>>).value;
        expect(items.map((d) => d.documentId), ['d-new', 'd-old']);
        expect(items.first.status, MedicalDocumentStatus.scanPending);
        expect(f.vm.polling, {'d-new'});
        expect(documentsCountText(f.vm.count, _fr), '2 documents enregistrés');
      },
    );

    test('« Réessayer » sends the same key; an edit makes a new one', () async {
      final f = _Fixture()..api.failUpload = _status(503, 'MRS_UNAVAILABLE');
      await f.loaded(_self);
      final attempt = SaveAttempt();
      final failed = await f.vm.upload(
        source: _file(),
        form: _form(),
        attempt: attempt,
      );
      expect(failed, isA<Err<UploadedDocument>>());
      expect((f.vm.state as SectionReady).value, isEmpty, reason: 'no row');
      await f.vm.upload(source: _file(), form: _form(), attempt: attempt);
      expect(f.api.uploads[1].key, f.api.uploads[0].key);

      attempt.reset(); // the editor's « edited »
      await f.vm.upload(source: _file(), form: _form(), attempt: attempt);
      expect(f.api.uploads[2].key, isNot(f.api.uploads[0].key));
    });
  });

  group('status polling', () {
    test('backoff 2 s → 4 s → 8 s → 16 s, capped at 30 s', () {
      expect(
        [for (var i = 0; i < 7; i++) pollDelay(i).inSeconds],
        [2, 4, 8, 16, 30, 30, 30],
      );
    });

    test(
      'polls until AVAILABLE, then stops; the row takes the status',
      () async {
        final f = _Fixture()
          ..api.listItems = [_doc('d-1', status: 'SCAN_PENDING')]
          ..api.statuses = ['SCAN_PENDING', 'SCAN_PENDING', 'AVAILABLE'];
        await f.loaded(_self);
        for (var i = 0; i < 3; i++) {
          await f.timers.fireNext();
        }
        expect(f.timers.delays.map((d) => d.inSeconds), [2, 4, 8]);
        expect(f.vm.polling, isEmpty);
        expect(f.timers.pending, isEmpty);
        final doc =
            (f.vm.state as SectionReady<List<MedicalDocument>>).value.single;
        expect(doc.status, MedicalDocumentStatus.available);
        expect(
          f.api.calls.where((c) => c.startsWith('list')).length,
          1,
          reason: 'never polls the list',
        );
      },
    );

    test(
      'SCAN_FAILED stops polling; a failed read keeps backing off',
      () async {
        final f = _Fixture()
          ..api.listItems = [_doc('d-1', status: 'SCAN_PENDING')]
          ..api.statuses = ['FAIL', 'SCAN_FAILED'];
        await f.loaded(_self);
        await f.timers.fireNext();
        await f.timers.fireNext();
        expect(f.timers.delays.map((d) => d.inSeconds), [2, 4]);
        expect(f.vm.polling, isEmpty);
        final doc =
            (f.vm.state as SectionReady<List<MedicalDocument>>).value.single;
        expect(doc.status, MedicalDocumentStatus.scanFailed);
      },
    );

    for (final (name, stop)
        in <(String, void Function(MedicalDocumentsViewModel))>[
          ('another person', (vm) => vm.select(_family)),
          ('logout', (vm) => vm.clear()),
          ('dispose', (vm) => vm.dispose()),
        ]) {
      test('$name stops polling and clears the list', () async {
        final f = _Fixture()
          ..api.listItems = [_doc('d-1', status: 'SCAN_PENDING')];
        await f.loaded(_self);
        expect(f.timers.pending, hasLength(1));
        stop(f.vm);
        expect(f.timers.pending, isEmpty);
        if (name != 'dispose') {
          expect(f.vm.state, isA<SectionIdle<List<MedicalDocument>>>());
          expect(f.vm.polling, isEmpty);
        }
      });
    }
  });

  group('the person switch', () {
    test('cancels the list in flight and drops its late answer', () async {
      final f = _Fixture()..api.holdList = Completer<void>();
      f.vm.select(_self);
      f.vm.ensureLoaded();
      await pumpEventQueue();
      final token = f.api.lastCancelToken!;
      f.vm.select(_family);
      expect(token.isCancelled, isTrue);
      f.api.holdList!.complete();
      await pumpEventQueue();
      expect(f.vm.subject, _family);
      expect(f.vm.state, isA<SectionIdle<List<MedicalDocument>>>());
    });
  });

  group('the page viewer', () {
    test('one page at a time: page 1, then the next one on demand', () async {
      final f = _Fixture();
      final pages = f.pages('d-1', _family);
      await pages.open();
      expect(f.api.calls, [
        'session FAMILY:fm-1 d-1',
        'page FAMILY:fm-1 d-1 s-1 1',
      ]);
      expect(
        (pages.page as SectionReady<DocumentPageImage>).value.pageNumber,
        1,
      );
      expect(pages.pageCount, 3);
      expect(pages.hasPrevious, isFalse);

      await pages.next();
      expect(f.api.calls.last, 'page FAMILY:fm-1 d-1 s-1 2');
      expect(
        (pages.page as SectionReady<DocumentPageImage>).value.pageNumber,
        2,
      );
      expect(f.api.calls.where((c) => c.startsWith('page')).length, 2);
      pages.dispose();
      expect(
        pages.page,
        isA<SectionIdle<DocumentPageImage>>(),
        reason: 'the page is freed on close',
      );
    });

    test('410: one new session, silently; a second 410 is a failure', () async {
      final f = _Fixture()..api.expirePages = 1;
      final pages = f.pages('d-1', _self);
      await pages.open();
      expect(f.api.calls.where((c) => c.startsWith('session')).length, 2);
      expect(pages.page, isA<SectionReady<DocumentPageImage>>());

      f.api.expirePages = 2;
      await pages.next();
      expect(
        f.api.calls.where((c) => c.startsWith('session')).length,
        3,
        reason: 'one reopen, no loop',
      );
      expect(pages.page, isA<SectionFailed<DocumentPageImage>>());
    });

    test('DOCUMENT_NOT_READY and 429 keep their French texts', () async {
      final f = _Fixture()
        ..api.failSession = _status(409, 'DOCUMENT_NOT_READY');
      final pages = f.pages('d-1', _self);
      await pages.open();
      final failure = (pages.page as SectionFailed).failure;
      expect(
        recordFailureMessage(failure, _fr),
        _fr.recordCodeDocumentNotReady,
      );
      f.api.failSession = _status(429, 'TOO_MANY_REQUESTS');
      await pages.retry();
      expect(
        recordFailureMessage((pages.page as SectionFailed).failure, _fr),
        _fr.recordCodeTooManyRequests,
      );
    });
  });

  group('delete', () {
    test('the row leaves on 204; its polling stops', () async {
      final f = _Fixture()
        ..api.listItems = [_doc('d-1', status: 'SCAN_PENDING'), _doc('d-2')];
      await f.loaded(_family);
      final result = await f.vm.delete('d-1', SaveAttempt());
      expect(result, isA<Ok<void>>());
      expect(f.api.calls.last, startsWith('delete FAMILY:fm-1 d-1'));
      expect(
        (f.vm.state as SectionReady<List<MedicalDocument>>).value.map(
          (d) => d.documentId,
        ),
        ['d-2'],
      );
      expect(f.vm.polling, isEmpty);
    });

    test('a failure keeps the row; « Réessayer » reuses the key', () async {
      final f = _Fixture()
        ..api.listItems = [_doc('d-1')]
        ..api.failDelete = _status(503, 'MRS_UNAVAILABLE');
      await f.loaded(_self);
      final attempt = SaveAttempt();
      final failed = await f.vm.delete('d-1', attempt);
      expect(failed, isA<Err<void>>());
      expect((f.vm.state as SectionReady).value, hasLength(1));
      await f.vm.delete('d-1', attempt);
      expect(f.api.deleteKeys[1], f.api.deleteKeys[0]);
      expect((f.vm.state as SectionReady).value, isEmpty);
    });
  });

  group('no title or file name in logs', () {
    test('nothing is printed; no toString carries them', () async {
      final printed = <String?>[];
      final original = debugPrint;
      debugPrint = (message, {wrapWidth}) => printed.add(message);
      addTearDown(() => debugPrint = original);
      final f = _Fixture()..api.failUpload = _status(503, 'MRS_UNAVAILABLE');
      await f.loaded(_self);
      final result = await f.vm.upload(
        source: _file(name: _secretFile),
        form: _form(title: _secretTitle),
        attempt: SaveAttempt(),
      );
      expect(printed, isEmpty);
      for (final value in [
        _file(name: _secretFile),
        _form(title: _secretTitle),
        MedicalDocument.fromJson(_doc('d-1', title: _secretTitle)),
        (result as Err).failure.logSummary,
      ]) {
        expect('$value', isNot(contains(_secretTitle)));
        expect('$value', isNot(contains(_secretFile)));
      }
    });
  });
}

// ---- fixtures ----

Map<String, Object?> _doc(
  String id, {
  String status = 'AVAILABLE',
  String title = 'Bilan sanguin',
}) => {
  'documentId': id,
  'documentType': 'LAB_RESULT',
  'status': status,
  'createdAt': '2026-11-12T09:00:00Z',
  'title': title,
  'contentType': 'application/pdf',
  'sizeBytes': 1000,
};

DocumentFileSource _file({String name = 'bilan.pdf', int size = 1000}) =>
    StreamDocumentSource(
      filename: name,
      sizeBytes: size,
      open: () => Stream.value(List.filled(4, 1)),
    );

DocumentUploadForm _form({String title = 'Bilan'}) => DocumentUploadForm(
  title: title,
  type: MedicalDocumentType.labResult,
  documentDate: DateTime(2026, 11, 1),
);

DioException _status(int status, String code) {
  final options = RequestOptions(path: '/me/medical-record/documents');
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response<Object?>(
      requestOptions: options,
      statusCode: status,
      data: {'code': code, 'message': 'server text never shown'},
    ),
  );
}

class _Fixture {
  _Fixture() {
    vm = MedicalDocumentsViewModel(
      repository: MedicalDocumentRepository(api),
      schedule: timers.schedule,
      now: () => _now,
    );
  }

  final _FakeDocumentsApi api = _FakeDocumentsApi();
  final _FakeTimers timers = _FakeTimers();
  late final MedicalDocumentsViewModel vm;

  Future<void> loaded(RecordSubject subject) async {
    vm.select(subject);
    vm.ensureLoaded();
    await pumpEventQueue();
  }

  DocumentPagesController pages(String id, RecordSubject subject) =>
      DocumentPagesController(
        repository: MedicalDocumentRepository(api),
        subject: subject,
        documentId: id,
      );
}

/// A scheduler whose timers fire only when the test says so.
class _FakeTimers {
  final List<Duration> delays = [];
  final List<_FakeTimer> _timers = [];

  List<_FakeTimer> get pending =>
      _timers.where((t) => t.isActive).toList(growable: false);

  Timer schedule(Duration delay, void Function() run) {
    delays.add(delay);
    final timer = _FakeTimer(run);
    _timers.add(timer);
    return timer;
  }

  Future<void> fireNext() async {
    final timer = pending.first;
    timer.fire();
    await pumpEventQueue();
  }
}

class _FakeTimer implements Timer {
  _FakeTimer(this._run);

  final void Function() _run;
  bool _active = true;

  void fire() {
    if (!_active) return;
    _active = false;
    _run();
  }

  @override
  void cancel() => _active = false;

  @override
  bool get isActive => _active;

  @override
  int get tick => 0;
}

class _Upload {
  _Upload(this.subject, this.key);
  final RecordSubject subject;
  final String key;
}

class _FakeDocumentsApi implements MedicalDocumentApiContract {
  final List<String> calls = [];
  final List<_Upload> uploads = [];
  final List<String> deleteKeys = [];
  List<Map<String, Object?>> listItems = [];
  String? nextCursor;
  List<String> statuses = [];
  DioException? failList;
  DioException? failUpload;
  DioException? failDelete;
  DioException? failSession;
  Completer<void>? holdList;
  CancelToken? lastCancelToken;

  /// The next [expirePages] page reads answer 410.
  int expirePages = 0;
  int _sessions = 0;

  @override
  Future<Object?> list(
    RecordSubject subject, {
    required int size,
    String? cursor,
    CancelToken? cancelToken,
  }) async {
    calls.add('list ${subject.queryValue} size=$size');
    lastCancelToken = cancelToken;
    final hold = holdList;
    if (hold != null) await hold.future;
    final failure = failList;
    failList = null;
    if (failure != null) throw failure;
    return {'items': listItems, 'nextCursor': nextCursor};
  }

  @override
  Future<Object?> status(
    RecordSubject subject,
    String documentId, {
    CancelToken? cancelToken,
  }) async {
    calls.add('status ${subject.queryValue} $documentId');
    final next = statuses.isEmpty ? 'SCAN_PENDING' : statuses.removeAt(0);
    if (next == 'FAIL') throw _status(503, 'MRS_UNAVAILABLE');
    return _doc(documentId, status: next);
  }

  @override
  Future<Object?> upload(
    RecordSubject subject, {
    required DocumentFileSource source,
    required String contentType,
    required DocumentUploadForm form,
    required String idempotencyKey,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
  }) async {
    uploads.add(_Upload(subject, idempotencyKey));
    final failure = failUpload;
    failUpload = null;
    if (failure != null) throw failure;
    return {'documentId': 'd-new', 'status': 'SCAN_PENDING'};
  }

  @override
  Future<void> delete(
    RecordSubject subject,
    String documentId, {
    required String idempotencyKey,
    CancelToken? cancelToken,
  }) async {
    calls.add('delete ${subject.queryValue} $documentId');
    deleteKeys.add(idempotencyKey);
    final failure = failDelete;
    failDelete = null;
    if (failure != null) throw failure;
  }

  @override
  Future<Object?> openViewSession(
    RecordSubject subject,
    String documentId, {
    CancelToken? cancelToken,
  }) async {
    calls.add('session ${subject.queryValue} $documentId');
    final failure = failSession;
    failSession = null;
    if (failure != null) throw failure;
    _sessions++;
    return {
      'viewSessionId': 's-$_sessions',
      'pageCount': 3,
      'expiresAt': '2026-11-13T10:05:00Z',
    };
  }

  @override
  Future<Uint8List> page(
    RecordSubject subject,
    String documentId,
    String viewSessionId,
    int pageNumber, {
    CancelToken? cancelToken,
  }) async {
    calls.add(
      'page ${subject.queryValue} $documentId $viewSessionId $pageNumber',
    );
    if (expirePages > 0) {
      expirePages--;
      throw _status(410, 'VIEW_SESSION_EXPIRED');
    }
    return Uint8List.fromList([137, 80, 78, 71]);
  }
}
