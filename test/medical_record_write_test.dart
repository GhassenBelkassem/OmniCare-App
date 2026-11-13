// G2.1-A1: the « Dossier médical » data layer for writes (SB1) and documents
// (FT-2, SB3). Logic only (CTO testing rule): models, request building through
// the real API classes against a scripted Dio adapter, repositories, French
// messages. No widget, no app run. Every value here is synthetic.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:omnicare_mobile/core/network/api_failure.dart';
import 'package:omnicare_mobile/core/network/app_http_client.dart';
import 'package:omnicare_mobile/core/network/request_replay_policy.dart';
import 'package:omnicare_mobile/core/result/result.dart';
import 'package:omnicare_mobile/core/storage/secure_token_store.dart';
import 'package:omnicare_mobile/features/patient_passport/data/medical_document_api.dart';
import 'package:omnicare_mobile/features/patient_passport/data/medical_document_models.dart';
import 'package:omnicare_mobile/features/patient_passport/data/medical_document_repository.dart';
import 'package:omnicare_mobile/features/patient_passport/data/medical_record_models.dart';
import 'package:omnicare_mobile/features/patient_passport/data/medical_record_write_api.dart';
import 'package:omnicare_mobile/features/patient_passport/data/medical_record_write_models.dart';
import 'package:omnicare_mobile/features/patient_passport/data/medical_record_write_repository.dart';
import 'package:omnicare_mobile/features/patient_passport/presentation/medical_record_messages.dart';
import 'package:omnicare_mobile/l10n/omni_localizations.dart';

final _fr = lookupOmniLocalizations(const Locale('fr'));
const _self = SelfRecordSubject();
const _family = FamilyRecordSubject('fam-1');
const _base = '/api/v1/me/medical-record';
const _secretLabel = 'allergie-synthetique-zz';
const _secretTitle = 'titre-synthetique-zz';
const _secretFile = 'fichier-synthetique-zz.pdf';

void main() {
  group('read models: the recorded SB1 §4b bodies', () {
    test('medical-data: items, authors, severity and versions', () {
      final record = MedicalDataRecord.fromJson(_medicalDataV3);
      expect(record.bloodType, 'A+');
      expect(record.bloodTypeAuthor, RecordAuthor.professional);
      expect(record.bloodTypeAuthor.isEditableByPatient, isFalse);
      expect(record.bloodTypeVersion, 2);
      expect(record.allergies, ['Pollen', 'Arachide']);
      expect(record.allergiesVersion, 4);
      expect(record.allergyItems.map((i) => i.itemId), ['a-1', 'a-2']);
      expect(record.allergyItems[0].author, RecordAuthor.patient);
      expect(record.allergyItems[0].severity, AllergySeverity.severe);
      expect(record.allergyItems[1].author, RecordAuthor.unknown);
      expect(record.allergyItems[1].author.isEditableByPatient, isFalse);
      expect(record.allergyItems[1].severity, AllergySeverity.unknown);
      expect(record.conditionItems.single.severity, isNull);
      expect(record.conditionItems.single.author, RecordAuthor.professional);
      expect(record.conditionsVersion, 1);
      expect(record.measurementsAuthor, RecordAuthor.patient);
      expect(record.measurementsVersion, 3);
      expect(record.heightCm, 172);
      expect(record.allergyItems[0].toString(), isNot(contains('Pollen')));
    });

    test('a body without the SB1 fields reads as never recorded', () {
      final record = MedicalDataRecord.fromJson({
        'lifeSafety': {'bloodType': null, 'allergiesStatus': 'UNKNOWN'},
        'bodyMeasurements': <String, Object?>{},
      });
      expect(record.bloodTypeVersion, 0);
      expect(record.allergiesVersion, 0);
      expect(record.allergyItems, isEmpty);
      expect(record.bloodTypeAuthor, RecordAuthor.unknown);
      expect(record.measurementsVersion, 0);
    });

    test('an item without id or label fails the whole read', () {
      final body =
          jsonDecode(jsonEncode(_medicalDataV3)) as Map<String, Object?>;
      ((body['lifeSafety']! as Map)['allergyItems'] as List)[0] = {
        'label': 'x',
        'authorType': 'PATIENT',
      };
      expect(
        () => MedicalDataRecord.fromJson(body),
        throwsA(isA<FormatException>()),
      );
    });

    test(
      'medications: declared and prescribed items, list status and version',
      () {
        final page = RecordPage.fromJson(
          _medicationsPage,
          MedicationRecord.fromJson,
        );
        expect(page.listStatus, RecordListStatus.list);
        expect(page.listVersion, 5);
        final declared = page.items[0];
        expect(declared.id, 'd-1');
        expect(declared.itemId, 'd-1');
        expect(declared.source, MedicationSource.patientDeclared);
        expect(declared.author, RecordAuthor.patient);
        expect(declared.isDeclaredByPatient, isTrue);
        expect(
          declared.duration,
          const MedicationDuration(value: 5, unit: DurationUnit.day),
        );
        expect(declared.startedOn, '2026-11-01');
        final prescribed = page.items[1];
        expect(prescribed.source, MedicationSource.prescription);
        expect(prescribed.author, RecordAuthor.professional);
        expect(prescribed.isDeclaredByPatient, isFalse);
        expect(prescribed.itemId, isNull);
        expect(page.items[2].source, MedicationSource.unknown);
        expect(page.items[2].duration?.unit, DurationUnit.unknown);
      },
    );

    test('other lists carry no list status', () {
      final page = RecordPage.fromJson({
        'items': <Object?>[],
        'nextCursor': null,
      }, MedicationRecord.fromJson);
      expect(page.listStatus, isNull);
      expect(page.listVersion, isNull);
    });
  });

  group('document models: the recorded FT-2 / SB3 bodies', () {
    test('list page, unknown values, status polling', () {
      final page = MedicalDocumentPage.fromJson(_documentsPage);
      expect(page.nextCursor, 'cur_2');
      expect(page.items[0].type, MedicalDocumentType.labResult);
      expect(page.items[0].status, MedicalDocumentStatus.available);
      expect(page.items[0].title, 'Bilan');
      expect(page.items[0].createdAt, DateTime.utc(2026, 11, 10, 9));
      expect(page.items[1].type, MedicalDocumentType.unknown);
      expect(page.items[1].status, MedicalDocumentStatus.unknown);
      expect(
        MedicalDocumentStatus.fromServer('SCAN_PENDING').isProcessing,
        isTrue,
      );
      expect(page.items[0].toString(), isNot(contains('Bilan')));
    });

    test('a document without id fails the read', () {
      expect(
        () => MedicalDocument.fromJson({'createdAt': '2026-11-10T09:00:00Z'}),
        throwsA(isA<FormatException>()),
      );
    });

    test('view session', () {
      final session = DocumentViewSession.fromJson(_session('s-1', 3));
      expect(session.viewSessionId, 's-1');
      expect(session.pageCount, 3);
      expect(session.expiresAt.isUtc, isTrue);
      expect(
        () => DocumentViewSession.fromJson(_session('s-1', 0)),
        throwsA(isA<FormatException>()),
      );
    });

    test('the document types sent are exactly the server ones', () {
      expect(
        MedicalDocumentType.values
            .where((type) => type != MedicalDocumentType.unknown)
            .map((type) => type.serverValue),
        [
          'LAB_RESULT',
          'IMAGING',
          'PRESCRIPTION_DOCUMENT',
          'REFERRAL',
          'DISCHARGE_SUMMARY',
          'VACCINATION',
          'OTHER_MEDICAL_DOCUMENT',
        ],
      );
    });
  });

  group('section saves: the requests (SB1 §4a)', () {
    late _Server server;
    late MedicalRecordWriteRepository repository;

    setUp(() {
      server = _Server();
      repository = MedicalRecordWriteRepository(
        MedicalRecordWriteApi(_client(server)),
      );
    });

    final cases =
        <
          String,
          (
            String,
            Future<Result<SectionSaved>> Function(
              MedicalRecordWriteRepository,
              SaveAttempt,
            ),
            Map<String, Object?>,
          )
        >{
          'blood type': (
            'life-safety/blood-type',
            (repo, attempt) => repo.saveBloodType(
              subject: _family,
              bloodType: 'O-',
              expectedVersion: 2,
              attempt: attempt,
            ),
            {'value': 'O-', 'expectedVersion': 2},
          ),
          'allergies': (
            'life-safety/allergies',
            (repo, attempt) => repo.saveAllergies(
              subject: _family,
              items: const [
                AllergyDraft(
                  itemId: 'a-1',
                  label: 'Pollen',
                  severity: AllergySeverity.mild,
                ),
                AllergyDraft(
                  label: 'Arachide',
                  severity: AllergySeverity.unknown,
                ),
                AllergyDraft(label: 'Latex'),
              ],
              expectedVersion: 4,
              attempt: attempt,
            ),
            {
              'items': [
                {'itemId': 'a-1', 'label': 'Pollen', 'severity': 'MILD'},
                {'label': 'Arachide'},
                {'label': 'Latex'},
              ],
              'expectedVersion': 4,
            },
          ),
          'conditions': (
            'life-safety/conditions',
            (repo, attempt) => repo.saveConditions(
              subject: _family,
              items: const [ConditionDraft(itemId: 'c-1', label: 'Asthme')],
              expectedVersion: 1,
              attempt: attempt,
            ),
            {
              'items': [
                {'itemId': 'c-1', 'label': 'Asthme'},
              ],
              'expectedVersion': 1,
            },
          ),
          'measurements': (
            'body-measurements',
            (repo, attempt) => repo.saveMeasurements(
              subject: _family,
              heightCm: null,
              weightKg: 64.5,
              expectedVersion: 0,
              attempt: attempt,
            ),
            {'weightKg': 64.5, 'expectedVersion': 0},
          ),
          'declared medications': (
            'medications/declared',
            (repo, attempt) => repo.saveDeclaredMedications(
              subject: _family,
              items: [
                DeclaredMedicationDraft(
                  itemId: 'd-1',
                  name: 'Doliprane',
                  dosageText: '1 cp',
                  timesPerDay: 3,
                  duration: const MedicationDuration(
                    value: 5,
                    unit: DurationUnit.week,
                  ),
                  startedOn: DateTime(2026, 3, 7, 23, 59),
                ),
                const DeclaredMedicationDraft(name: 'Vitamine D'),
              ],
              expectedVersion: 5,
              attempt: attempt,
            ),
            {
              'items': [
                {
                  'itemId': 'd-1',
                  'name': 'Doliprane',
                  'dosageText': '1 cp',
                  'timesPerDay': 3,
                  'duration': {'value': 5, 'unit': 'WEEK'},
                  'startedOn': '2026-03-07',
                },
                {'name': 'Vitamine D'},
              ],
              'expectedVersion': 5,
            },
          ),
        };

    for (final entry in cases.entries) {
      test(
        '${entry.key}: route, subject, key, exact body, no author',
        () async {
          final (path, save, body) = entry.value;
          server.answer(
            200,
            _saved(entry.key, 3, const ['HEIGHT_UNUSUAL', 'NEW_ONE']),
          );
          final attempt = SaveAttempt(newKey: _keys());
          final result = await save(repository, attempt);

          final saved = (result as Ok<SectionSaved>).value;
          expect(saved.version, 3);
          expect(saved.warnings, [
            RecordWarning.heightUnusual,
            RecordWarning.unknown,
          ]);
          final request = server.requests.single;
          expect(request.method, 'PUT');
          expect(request.uri.path, '$_base/$path');
          expect(request.uri.queryParameters, {'subject': 'FAMILY:fam-1'});
          expect(request.headers['Idempotency-Key'], 'key-1');
          expect(jsonDecode(jsonEncode(request.data)), body);
          final sent = jsonEncode(request.data);
          for (final serverOwned in [
            'authorType',
            'authorId',
            'source',
            'author',
          ]) {
            expect(sent, isNot(contains('"$serverOwned"')));
          }
          expect(
            declaredReplayPolicy(request),
            RequestReplayPolicy.declaredIdempotentWrite,
          );
          expect(attempt.pendingKey, isNull, reason: 'dropped on success');
        },
      );
    }

    test('SELF is sent as SELF', () async {
      server.answer(200, _saved('BLOOD_TYPE', 1));
      await repository.saveBloodType(
        subject: _self,
        bloodType: 'UNKNOWN',
        expectedVersion: 0,
        attempt: SaveAttempt(),
      );
      expect(server.requests.single.uri.queryParameters['subject'], 'SELF');
    });

    test('a malformed success answer is a failure', () async {
      server.answer(200, {'section': 'BLOOD_TYPE'});
      final result = await repository.saveBloodType(
        subject: _self,
        bloodType: 'A+',
        expectedVersion: 0,
        attempt: SaveAttempt(),
      );
      expect(result, isA<Err<SectionSaved>>());
    });
  });

  group('SaveAttempt: one key per « Enregistrer »', () {
    late _Server server;
    late MedicalRecordWriteRepository repository;
    late SaveAttempt attempt;

    setUp(() {
      server = _Server();
      repository = MedicalRecordWriteRepository(
        MedicalRecordWriteApi(_client(server)),
      );
      attempt = SaveAttempt(newKey: _keys());
    });

    Future<Result<SectionSaved>> save(
      String label, {
      RecordSubject subject = _self,
      int version = 4,
    }) => repository.saveAllergies(
      subject: subject,
      items: [AllergyDraft(label: label)],
      expectedVersion: version,
      attempt: attempt,
    );

    List<Object?> keys() =>
        server.requests.map((r) => r.headers['Idempotency-Key']).toList();

    test(
      '« Réessayer » after a failure reuses the key; success drops it',
      () async {
        server
          ..answer(503, _error('MRS_UNAVAILABLE'))
          ..answer(200, _saved('ALLERGIES', 5))
          ..answer(200, _saved('ALLERGIES', 6));
        expect(await save('Pollen'), isA<Err<SectionSaved>>());
        expect(attempt.pendingKey, 'key-1');
        expect(await save('Pollen'), isA<Ok<SectionSaved>>());
        expect(attempt.pendingKey, isNull);
        await save('Pollen', version: 5);
        expect(keys(), ['key-1', 'key-1', 'key-2']);
      },
    );

    test(
      'changing the content, the subject or the version makes a new key',
      () async {
        for (var i = 0; i < 4; i++) {
          server.answer(503, _error('MRS_UNAVAILABLE'));
        }
        await save('Pollen');
        await save('Pollen et acariens');
        await save('Pollen et acariens', subject: _family);
        await save('Pollen et acariens', subject: _family, version: 9);
        expect(keys(), ['key-1', 'key-2', 'key-3', 'key-4']);
      },
    );

    test(
      'a key the server says was used for other content is dropped',
      () async {
        server
          ..answer(409, _error('IDEMPOTENCY_CONFLICT'))
          ..answer(200, _saved('ALLERGIES', 5));
        final result = await save('Pollen');
        expect((result as Err).failure.code, 'IDEMPOTENCY_CONFLICT');
        expect(
          (result as Err).failure,
          isNot(isA<RecordVersionConflictFailure>()),
        );
        expect(attempt.pendingKey, isNull);
        await save('Pollen');
        expect(keys(), ['key-1', 'key-2']);
      },
    );

    test('a gateway error keeps the key for « Réessayer »', () async {
      server.answer(504, '<html>gateway</html>');
      await save('Pollen');
      expect(attempt.pendingKey, 'key-1');
    });

    test('reset() is the "user changed the content" signal', () {
      expect(attempt.keyFor('content-zz'), 'key-1');
      expect(attempt.keyFor('content-zz'), 'key-1');
      attempt.reset();
      expect(attempt.keyFor('content-zz'), 'key-2');
      expect(attempt.toString(), isNot(contains('content-zz')));
    });
  });

  group('409 RECORD_VERSION_CONFLICT', () {
    late _Server server;
    late MedicalRecordWriteRepository repository;

    setUp(() {
      server = _Server();
      repository = MedicalRecordWriteRepository(
        MedicalRecordWriteApi(_client(server)),
      );
    });

    Future<Result<SectionSaved>> save() => repository.saveConditions(
      subject: _self,
      items: const [ConditionDraft(label: 'Asthme')],
      expectedVersion: 1,
      attempt: SaveAttempt(),
    );

    test('is a typed failure carrying the current version', () async {
      server.answer(409, {
        'code': 'RECORD_VERSION_CONFLICT',
        'message': 'The section changed since it was read.',
        'timestamp': '2026-11-12T10:00:00Z',
        'fieldErrors': <String, Object?>{},
        'currentVersion': 7,
      });
      final failure = ((await save()) as Err).failure;
      expect(failure, isA<RecordVersionConflictFailure>());
      expect((failure as RecordVersionConflictFailure).currentVersion, 7);
      expect(failure.kind, ApiFailureKind.conflict);
      expect(failure.statusCode, 409);
      expect(failure.logSummary, contains('currentVersion=7'));
      expect(recordFailureMessage(failure, _fr), _fr.recordCodeVersionConflict);
    });

    test('without a version it stays a plain conflict', () async {
      server.answer(409, _error('RECORD_VERSION_CONFLICT'));
      final failure = ((await save()) as Err).failure;
      expect(failure, isNot(isA<RecordVersionConflictFailure>()));
      expect(failure.kind, ApiFailureKind.conflict);
    });
  });

  group('documents: upload', () {
    late _Server server;
    late MedicalDocumentRepository repository;

    setUp(() {
      server = _Server();
      repository = MedicalDocumentRepository(
        MedicalDocumentApi(_client(server)),
      );
    });

    Future<Result<UploadedDocument>> upload(
      DocumentFileSource source, {
      SaveAttempt? attempt,
    }) => repository.upload(
      subject: _family,
      source: source,
      form: DocumentUploadForm(
        title: 'Bilan',
        type: MedicalDocumentType.labResult,
        documentDate: DateTime(2026, 1, 15),
      ),
      attempt: attempt ?? SaveAttempt(newKey: _keys()),
    );

    test('15 MB + 1 byte is refused before any request', () async {
      final result = await upload(
        _stream('scan.pdf', MedicalDocumentRepository.maxFileBytes + 1),
      );
      final failure = (result as Err).failure;
      expect(failure.fieldErrors, {'file': ApiFieldErrorKind.tooLong});
      expect(failure.kind, ApiFailureKind.validation);
      expect(server.requests, isEmpty);
      expect(
        recordFieldMessage('file', failure.fieldErrors['file']!, _fr),
        'Fichier trop volumineux (15 Mo maximum).',
      );
    });

    test('exactly 15 MB is sent', () async {
      server.answer(202, {'documentId': 'doc-1', 'status': 'SCAN_PENDING'});
      final result = await upload(
        _stream('scan.pdf', MedicalDocumentRepository.maxFileBytes),
      );
      expect(result, isA<Ok<UploadedDocument>>());
      expect(server.requests, hasLength(1));
    });

    test(
      'a file that is not PDF, JPG or PNG, or is empty, is refused before any request',
      () async {
        final cases = {
          'photo.gif': ApiFieldErrorKind.invalidFormat,
          'lettre.docx': ApiFieldErrorKind.invalidFormat,
          'scan': ApiFieldErrorKind.invalidFormat,
          'scan.': ApiFieldErrorKind.invalidFormat,
          'scan.pdf.exe': ApiFieldErrorKind.invalidFormat,
        };
        for (final entry in cases.entries) {
          final failure =
              ((await upload(_stream(entry.key, 10))) as Err).failure;
          expect(failure.fieldErrors, {'file': entry.value}, reason: entry.key);
        }
        final empty = ((await upload(_stream('scan.pdf', 0))) as Err).failure;
        expect(empty.fieldErrors, {'file': ApiFieldErrorKind.required});
        expect(server.requests, isEmpty);
        expect(
          recordFieldMessage('file', ApiFieldErrorKind.invalidFormat, _fr),
          'Format non accepté : PDF, JPG ou PNG.',
        );
      },
    );

    test(
      'the request: multipart, subject, key, fields, file part, upload timeouts',
      () async {
        server.answer(202, {'documentId': 'doc-1', 'status': 'SCAN_PENDING'});
        final result = await upload(_stream('Photo.JPG', 3));

        final uploaded = (result as Ok<UploadedDocument>).value;
        expect(uploaded.documentId, 'doc-1');
        expect(uploaded.status, MedicalDocumentStatus.scanPending);
        final request = server.requests.single;
        expect(request.method, 'POST');
        expect(request.uri.path, '$_base/documents');
        expect(request.uri.queryParameters, {'subject': 'FAMILY:fam-1'});
        expect(request.headers['Idempotency-Key'], 'key-1');
        expect(request.contentType, startsWith('multipart/form-data'));
        expect(request.sendTimeout, const Duration(minutes: 2));
        final form = request.data as FormData;
        expect(Map.fromEntries(form.fields), {
          'title': 'Bilan',
          'documentType': 'LAB_RESULT',
          'documentDate': '2026-01-15',
        });
        final file = form.files.single;
        expect(file.key, 'file');
        expect(file.value.filename, 'Photo.JPG');
        expect(file.value.contentType.toString(), 'image/jpeg');
        expect(file.value.length, 3);
      },
    );

    test('a file on disk is streamed from its path', () async {
      final directory = await Directory.systemTemp.createTemp('a1_upload');
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/scan.pdf')
        ..writeAsBytesSync([1, 2, 3, 4]);
      server.answer(202, {'documentId': 'doc-1', 'status': 'SCAN_PENDING'});

      await upload(
        PathDocumentSource(path: file.path, filename: 'scan.pdf', sizeBytes: 4),
      );

      final part = (server.requests.single.data as FormData).files.single.value;
      expect(part.contentType.toString(), 'application/pdf');
      expect(part.length, 4);
    });

    test(
      'server refusals keep their field codes; « Réessayer » reuses the key',
      () async {
        final attempt = SaveAttempt(newKey: _keys());
        server
          ..answer(
            400,
            _error(
              'VALIDATION_ERROR',
              fields: {'title': 'TOO_LONG', 'documentDate': 'OUT_OF_RANGE'},
            ),
          )
          ..answer(503, _error('MRS_UNAVAILABLE'))
          ..answer(202, {'documentId': 'doc-1', 'status': 'SCAN_PENDING'});
        final refused =
            ((await upload(_stream('a.png', 3), attempt: attempt)) as Err)
                .failure;
        expect(recordFieldMessages(refused.fieldErrors, _fr), {
          'title': '160 caractères maximum.',
          'documentDate': 'La date ne peut pas être dans le futur.',
        });
        await upload(_stream('a.png', 3), attempt: attempt);
        await upload(_stream('a.png', 3), attempt: attempt);
        expect(server.requests.map((r) => r.headers['Idempotency-Key']), [
          'key-1',
          'key-1',
          'key-1',
        ]);
        expect(attempt.pendingKey, isNull);
      },
    );
  });

  group('documents: list, status, delete', () {
    late _Server server;
    late MedicalDocumentRepository repository;

    setUp(() {
      server = _Server();
      repository = MedicalDocumentRepository(
        MedicalDocumentApi(_client(server)),
      );
    });

    test('list: one page of 20 with the cursor', () async {
      server.answer(200, _documentsPage);
      final page = await repository.documents(_self, cursor: 'cur_1');
      expect((page as Ok<MedicalDocumentPage>).value.items, hasLength(2));
      final request = server.requests.single;
      expect(request.uri.path, '$_base/documents');
      expect(request.uri.queryParameters, {
        'subject': 'SELF',
        'size': '20',
        'cursor': 'cur_1',
      });
    });

    test('status', () async {
      server.answer(200, (_documentsPage['items']! as List).first);
      final document = await repository.status(_family, 'doc-1');
      expect(
        (document as Ok<MedicalDocument>).value.status,
        MedicalDocumentStatus.available,
      );
      expect(server.requests.single.uri.path, '$_base/documents/doc-1/status');
    });

    test(
      'delete: DELETE with subject and key, 204 → Ok, key dropped',
      () async {
        server.answer(204, null);
        final attempt = SaveAttempt(newKey: _keys());
        final result = await repository.delete(
          subject: _family,
          documentId: 'doc-1',
          attempt: attempt,
        );
        expect(result, isA<Ok<void>>());
        final request = server.requests.single;
        expect(request.method, 'DELETE');
        expect(request.uri.path, '$_base/documents/doc-1');
        expect(request.uri.queryParameters, {'subject': 'FAMILY:fam-1'});
        expect(request.headers['Idempotency-Key'], 'key-1');
        expect(attempt.pendingKey, isNull);
      },
    );

    test('delete: an unknown document is not found', () async {
      server.answer(404, _error('RESOURCE_NOT_FOUND'));
      final result = await repository.delete(
        subject: _self,
        documentId: 'doc-x',
        attempt: SaveAttempt(),
      );
      expect((result as Err).failure.kind, ApiFailureKind.notFound);
    });
  });

  group('documents: viewing one page at a time', () {
    late _Server server;
    late MedicalDocumentRepository repository;
    final first = DocumentViewSession.fromJson(_session('s-1', 3));

    setUp(() {
      server = _Server();
      repository = MedicalDocumentRepository(
        MedicalDocumentApi(_client(server)),
      );
    });

    Future<Result<FetchedDocumentPage>> fetch(int page) => repository.fetchPage(
      subject: _family,
      documentId: 'doc-1',
      session: first,
      pageNumber: page,
    );

    List<String> paths() =>
        server.requests.map((r) => '${r.method} ${r.uri.path}').toList();

    test('open a session, then one PNG page', () async {
      server.answer(201, _session('s-1', 3));
      final session = await repository.openViewSession(_family, 'doc-1');
      expect((session as Ok<DocumentViewSession>).value.pageCount, 3);
      expect(server.requests.single.method, 'POST');
      expect(
        server.requests.single.uri.path,
        '$_base/documents/doc-1/view-sessions',
      );
      expect(server.requests.single.uri.queryParameters, {
        'subject': 'FAMILY:fam-1',
      });

      server.answerBytes(200, _png);
      final page = await fetch(2);
      final fetched = (page as Ok<FetchedDocumentPage>).value;
      expect(fetched.page.png, _png);
      expect(fetched.page.pageNumber, 2);
      expect(fetched.session.viewSessionId, 's-1');
      final request = server.requests.last;
      expect(
        request.uri.path,
        '$_base/documents/doc-1/view-sessions/s-1/pages/2',
      );
      expect(request.uri.queryParameters, {'subject': 'FAMILY:fam-1'});
      expect(request.responseType, ResponseType.bytes);
    });

    test('410: one new session, silently, then the page', () async {
      server
        ..answer(410, _error('VIEW_SESSION_EXPIRED'))
        ..answer(201, _session('s-2', 3))
        ..answerBytes(200, _png);
      final fetched = ((await fetch(1)) as Ok<FetchedDocumentPage>).value;
      expect(fetched.session.viewSessionId, 's-2');
      expect(paths(), [
        'GET $_base/documents/doc-1/view-sessions/s-1/pages/1',
        'POST $_base/documents/doc-1/view-sessions',
        'GET $_base/documents/doc-1/view-sessions/s-2/pages/1',
      ]);
    });

    test('410 twice: a failure, never a second reopen', () async {
      server
        ..answer(410, _error('VIEW_SESSION_EXPIRED'))
        ..answer(201, _session('s-2', 3))
        ..answer(410, _error('VIEW_SESSION_EXPIRED'))
        ..answer(201, _session('s-3', 3));
      final failure = ((await fetch(1)) as Err).failure;
      expect(failure.code, 'VIEW_SESSION_EXPIRED');
      expect(server.requests, hasLength(3));
    });

    test('the reopen failing is returned as is', () async {
      server
        ..answer(410, _error('VIEW_SESSION_EXPIRED'))
        ..answer(409, _error('DOCUMENT_NOT_READY'));
      final failure = ((await fetch(1)) as Err).failure;
      expect(failure.code, 'DOCUMENT_NOT_READY');
      expect(server.requests, hasLength(2));
    });

    test(
      'a page beyond the new session is not found, without asking',
      () async {
        server
          ..answer(410, _error('VIEW_SESSION_EXPIRED'))
          ..answer(201, _session('s-2', 1));
        final failure = ((await fetch(3)) as Err).failure;
        expect(failure.kind, ApiFailureKind.notFound);
        expect(server.requests, hasLength(2));
      },
    );

    test(
      'error codes of a page are read although the page is binary',
      () async {
        server.answer(409, _error('DOCUMENT_NOT_READY'));
        expect(((await fetch(1)) as Err).failure.code, 'DOCUMENT_NOT_READY');
        server.answer(429, _error('TOO_MANY_REQUESTS'), retryAfter: '60');
        final limited = ((await fetch(1)) as Err).failure;
        expect(limited.code, 'TOO_MANY_REQUESTS');
        expect(limited.retryAfter, const Duration(seconds: 60));
        expect(
          server.requests,
          hasLength(2),
          reason: 'no reopen on other errors',
        );
      },
    );
  });

  group('French messages (code + field)', () {
    test('every code of the contract has its text; others fall back', () {
      final codes = {
        'ITEM_LOCKED':
            'Cet élément a été ajouté par un professionnel de santé et ne peut pas être modifié.',
        'BLOOD_TYPE_LOCKED':
            'Votre groupe sanguin a été renseigné par un professionnel de santé.',
        'RECORD_VERSION_CONFLICT':
            'Votre dossier a été modifié ailleurs. Rechargez pour voir la dernière version ; vos saisies sont conservées.',
        'IDEMPOTENCY_IN_PROGRESS':
            'Enregistrement en cours, patientez un instant.',
        'DOCUMENT_NOT_READY':
            "Document en cours d'analyse. Réessayez dans quelques instants.",
        'TOO_MANY_REQUESTS': 'Trop de demandes. Patientez une minute.',
      };
      for (final entry in codes.entries) {
        expect(
          recordFailureMessage(
            ApiFailure(kind: ApiFailureKind.conflict, code: entry.key),
            _fr,
          ),
          entry.value,
          reason: entry.key,
        );
      }
      expect(
        recordFailureMessage(
          const ApiFailure(
            kind: ApiFailureKind.server,
            code: 'MRS_UNAVAILABLE',
          ),
          _fr,
        ),
        _fr.apiCodeMrsUnavailable,
      );
      expect(
        recordFailureMessage(
          const ApiFailure(
            kind: ApiFailureKind.conflict,
            code: 'SOMETHING_NEW',
          ),
          _fr,
        ),
        _fr.apiErrorConflict,
      );
      expect(
        recordFailureMessage(
          const ApiFailure(kind: ApiFailureKind.unknown, code: 'SOMETHING_NEW'),
          _fr,
          fallback: 'Impossible.',
        ),
        'Impossible.',
      );
    });

    test('every field rule of the contract has its text', () {
      const required = 'Ce champ est obligatoire.';
      const cases = <(String, ApiFieldErrorKind, String)>[
        ('items[0].label', ApiFieldErrorKind.required, required),
        ('Idempotency-Key', ApiFieldErrorKind.required, required),
        ('heightCm', ApiFieldErrorKind.required, required),
        (
          'items[1].label',
          ApiFieldErrorKind.tooLong,
          '160 caractères maximum.',
        ),
        ('items[0].name', ApiFieldErrorKind.tooLong, '160 caractères maximum.'),
        ('title', ApiFieldErrorKind.tooLong, '160 caractères maximum.'),
        (
          'items[2].dosageText',
          ApiFieldErrorKind.tooLong,
          '80 caractères maximum.',
        ),
        ('items', ApiFieldErrorKind.tooLong, '50 éléments maximum.'),
        (
          'items[0].label',
          ApiFieldErrorKind.invalid,
          'Ce texte contient des caractères non autorisés.',
        ),
        (
          'items[0].name',
          ApiFieldErrorKind.invalid,
          'Ce texte contient des caractères non autorisés.',
        ),
        (
          'items[0].dosageText',
          ApiFieldErrorKind.invalid,
          'Ce texte contient des caractères non autorisés.',
        ),
        (
          'title',
          ApiFieldErrorKind.invalid,
          'Ce texte contient des caractères non autorisés.',
        ),
        (
          'items[3].label',
          ApiFieldErrorKind.duplicate,
          'Cet élément figure déjà dans la liste.',
        ),
        (
          'items[0].itemId',
          ApiFieldErrorKind.duplicate,
          'Cet élément figure déjà dans la liste.',
        ),
        (
          'value',
          ApiFieldErrorKind.invalidFormat,
          'Groupe sanguin non valide.',
        ),
        (
          'heightCm',
          ApiFieldErrorKind.outOfRange,
          'La taille doit être comprise entre 30 et 300 cm.',
        ),
        (
          'weightKg',
          ApiFieldErrorKind.outOfRange,
          'Le poids doit être compris entre 0 et 500 kg.',
        ),
        (
          'items[0].timesPerDay',
          ApiFieldErrorKind.outOfRange,
          'Entre 1 et 6 prises par jour.',
        ),
        (
          'items[0].duration.value',
          ApiFieldErrorKind.outOfRange,
          'Entre 1 et 365.',
        ),
        (
          'items[0].startedOn',
          ApiFieldErrorKind.outOfRange,
          'La date ne peut pas être dans le futur.',
        ),
        (
          'items[0].startedOn',
          ApiFieldErrorKind.invalidFormat,
          'Date non valide.',
        ),
        (
          'documentDate',
          ApiFieldErrorKind.outOfRange,
          'La date ne peut pas être dans le futur.',
        ),
        ('documentDate', ApiFieldErrorKind.invalidFormat, 'Date non valide.'),
        (
          'file',
          ApiFieldErrorKind.tooLong,
          'Fichier trop volumineux (15 Mo maximum).',
        ),
        (
          'file',
          ApiFieldErrorKind.invalidFormat,
          'Format non accepté : PDF, JPG ou PNG.',
        ),
        ('file', ApiFieldErrorKind.required, required),
        // Not in the contract: the shared generic texts.
        (
          'items[0].duration.unit',
          ApiFieldErrorKind.invalid,
          'Vérifiez ce champ.',
        ),
        (
          'items[0].severity',
          ApiFieldErrorKind.invalidFormat,
          'Format invalide.',
        ),
        (
          'expectedVersion',
          ApiFieldErrorKind.outOfRange,
          'Valeur hors limites.',
        ),
        (
          'items[0].itemId',
          ApiFieldErrorKind.invalidFormat,
          'Format invalide.',
        ),
        ('page', ApiFieldErrorKind.outOfRange, 'Valeur hors limites.'),
        (
          'items[0].label',
          ApiFieldErrorKind.tooShort,
          'Ce texte est trop court.',
        ),
      ];
      for (final (field, kind, text) in cases) {
        expect(
          recordFieldMessage(field, kind, _fr),
          text,
          reason: '$field ${kind.name}',
        );
      }
      // Every kind has a text on any field (no gap in the map).
      for (final kind in ApiFieldErrorKind.values) {
        expect(recordFieldMessage('anything', kind, _fr), isNotEmpty);
      }
    });

    test('the field codes of a server answer reach the right texts', () {
      final failure = ApiFailure.fromResponse(
        statusCode: 400,
        body: {
          'code': 'VALIDATION_ERROR',
          'message': 'server text never shown',
          'fieldErrors': {'items[1].name': 'x', 'items[0].timesPerDay': 'x'},
          'fieldErrorCodes': {
            'items[1].name': 'DUPLICATE',
            'items[0].timesPerDay': 'OUT_OF_RANGE',
          },
        },
      );
      expect(recordFieldMessages(failure.fieldErrors, _fr), {
        'items[1].name': 'Cet élément figure déjà dans la liste.',
        'items[0].timesPerDay': 'Entre 1 et 6 prises par jour.',
      });
      expect(
        recordFailureMessage(failure, _fr),
        isNot(contains('server text')),
      );
    });

    test('warnings: one text, unknown ones are not shown', () {
      expect(
        recordWarningMessage(RecordWarning.heightUnusual, _fr),
        'Valeur inhabituelle : vérifiez-la.',
      );
      expect(
        recordWarningMessage(RecordWarning.weightUnusual, _fr),
        'Valeur inhabituelle : vérifiez-la.',
      );
      expect(recordWarningMessage(RecordWarning.unknown, _fr), isNull);
    });
  });

  test('no health value reaches a log or a toString', () async {
    final logged = <String>[];
    final previous = debugPrint;
    debugPrint = (message, {wrapWidth}) => logged.add('$message');
    addTearDown(() => debugPrint = previous);
    final server = _Server()
      ..answer(503, _error('MRS_UNAVAILABLE'))
      ..answer(409, _error('ITEM_LOCKED'))
      ..answer(400, _error('VALIDATION_ERROR', fields: {'title': 'INVALID'}));
    final writes = MedicalRecordWriteRepository(
      MedicalRecordWriteApi(_client(server)),
    );
    final documents = MedicalDocumentRepository(
      MedicalDocumentApi(_client(server)),
    );

    final results = <Object>[];
    await runZoned(
      () async {
        results
          ..add(
            await writes.saveAllergies(
              subject: _self,
              items: const [AllergyDraft(label: _secretLabel)],
              expectedVersion: 0,
              attempt: SaveAttempt(),
            ),
          )
          ..add(
            await writes.saveDeclaredMedications(
              subject: _self,
              items: const [
                DeclaredMedicationDraft(
                  name: _secretLabel,
                  dosageText: _secretLabel,
                ),
              ],
              expectedVersion: 0,
              attempt: SaveAttempt(),
            ),
          )
          ..add(
            await documents.upload(
              subject: _self,
              source: _stream(_secretFile, 3),
              form: const DocumentUploadForm(
                title: _secretTitle,
                type: MedicalDocumentType.other,
              ),
              attempt: SaveAttempt(),
            ),
          );
      },
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) => logged.add(line),
      ),
    );

    final everything = [
      ...logged,
      ...results.map((r) => r.toString()),
      for (final r in results) (r as Err).failure.logSummary,
      const AllergyDraft(label: _secretLabel).toString(),
      const ConditionDraft(label: _secretLabel).toString(),
      const DeclaredMedicationDraft(name: _secretLabel).toString(),
      const DocumentUploadForm(
        title: _secretTitle,
        type: MedicalDocumentType.other,
      ).toString(),
      _stream(_secretFile, 3).toString(),
    ].join('\n');
    for (final secret in [_secretLabel, _secretTitle, _secretFile]) {
      expect(everything, isNot(contains(secret)));
    }
  });
}

// ------------------------------------------------------------------ fixtures

final _png = Uint8List.fromList([0x89, 0x50, 0x4e, 0x47, 1, 2, 3]);

/// `GET …/medical-data` as SB1 §4b returns it (synthetic values).
final Map<String, Object?> _medicalDataV3 = {
  'lifeSafety': {
    'bloodType': 'A+',
    'allergies': ['Pollen', 'Arachide'],
    'allergiesStatus': 'LIST',
    'criticalConditions': ['Asthme'],
    'conditionsStatus': 'LIST',
    'bloodTypeAuthorType': 'PROFESSIONAL',
    'bloodTypeVersion': 2,
    'allergyItems': [
      {
        'itemId': 'a-1',
        'label': 'Pollen',
        'authorType': 'PATIENT',
        'severity': 'SEVERE',
      },
      {
        'itemId': 'a-2',
        'label': 'Arachide',
        'authorType': 'ROBOT',
        'severity': 'EXTREME',
      },
    ],
    'allergiesVersion': 4,
    'conditionItems': [
      {
        'itemId': 'c-1',
        'label': 'Asthme',
        'authorType': 'PROFESSIONAL',
        'severity': null,
      },
    ],
    'conditionsVersion': 1,
  },
  'bodyMeasurements': {
    'heightCm': 172,
    'weightKg': 64.5,
    'bmi': 21.8,
    'measuredAt': '2026-11-01T10:00:00Z',
    'authorType': 'PATIENT',
    'version': 3,
  },
};

/// `GET …/medications?group=CURRENT` with a declared and a prescribed item.
final Map<String, Object?> _medicationsPage = {
  'items': [
    {
      'medicationStatementId': 'd-1',
      'consultationId': null,
      'name': 'Doliprane',
      'dosageText': '1 cp',
      'timesPerDay': 3,
      'startedOn': '2026-11-01',
      'displayStatus': null,
      'source': 'PATIENT_DECLARED',
      'authorType': 'PATIENT',
      'itemId': 'd-1',
      'duration': {'value': 5, 'unit': 'DAY'},
    },
    {
      'medicationStatementId': 'p-1',
      'consultationId': 'cons-1',
      'name': 'Amoxicilline',
      'doseAmount': 1,
      'doseUnit': 'TABLET',
      'displayStatus': 'ACTIVE',
      'source': 'PRESCRIPTION',
      'authorType': 'PROFESSIONAL',
      'itemId': null,
      'duration': null,
    },
    {
      'medicationStatementId': 'x-1',
      'source': 'SOMETHING_NEW',
      'duration': {'value': 2, 'unit': 'YEAR'},
    },
  ],
  'nextCursor': null,
  'listStatus': 'LIST',
  'listVersion': 5,
};

/// `GET …/documents` (FT-2 §6).
final Map<String, Object?> _documentsPage = {
  'items': [
    {
      'documentId': 'doc-1',
      'documentType': 'LAB_RESULT',
      'title': 'Bilan',
      'status': 'AVAILABLE',
      'contentType': 'application/pdf',
      'sizeBytes': 1200,
      'pageCount': 2,
      'createdAt': '2026-11-10T09:00:00Z',
      'updatedAt': '2026-11-10T09:01:00Z',
    },
    {
      'documentId': 'doc-2',
      'documentType': 'NEW_TYPE',
      'status': 'NEW_STATUS',
      'createdAt': '2026-11-09T09:00:00Z',
    },
  ],
  'nextCursor': 'cur_2',
};

Map<String, Object?> _session(String id, int pages) => {
  'viewSessionId': id,
  'pageCount': pages,
  'expiresAt': '2026-11-12T10:05:00Z',
};

Map<String, Object?> _saved(
  String section,
  int version, [
  List<String> warnings = const [],
]) => {'section': section, 'version': version, 'warnings': warnings};

Map<String, Object?> _error(String code, {Map<String, String>? fields}) => {
  'code': code,
  'message': 'English server text, never shown.',
  'timestamp': '2026-11-12T10:00:00Z',
  'fieldErrors': {for (final key in fields?.keys ?? const <String>[]) key: 'x'},
  'fieldErrorCodes': ?fields,
};

StreamDocumentSource _stream(String filename, int size) => StreamDocumentSource(
  open: () => Stream.value(List<int>.filled(size.clamp(0, 16), 0)),
  filename: filename,
  sizeBytes: size,
);

String Function() _keys() {
  var next = 0;
  return () => 'key-${++next}';
}

AppHttpClient _client(HttpClientAdapter adapter) => AppHttpClient(
  tokenStore: SecureTokenStore(backend: _MemoryTokenBackend()),
  baseUrl: 'https://api.test',
  dio: Dio()..httpClientAdapter = adapter,
  refreshDio: Dio(),
);

/// Answers requests in order and records them.
class _Server implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  final _answers = <ResponseBody Function()>[];

  void answer(int status, Object? body, {String? retryAfter}) => _answers.add(
    () => ResponseBody.fromString(
      body == null ? '' : (body is String ? body : jsonEncode(body)),
      status,
      headers: {
        Headers.contentTypeHeader: [
          body is String ? 'text/html' : Headers.jsonContentType,
        ],
        'retry-after': ?(retryAfter == null ? null : [retryAfter]),
      },
    ),
  );

  void answerBytes(int status, Uint8List bytes) => _answers.add(
    () => ResponseBody.fromBytes(
      bytes,
      status,
      headers: {
        Headers.contentTypeHeader: ['image/png'],
      },
    ),
  );

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (_answers.isEmpty) throw StateError('unexpected request ${options.uri}');
    return _answers.removeAt(0)();
  }

  @override
  void close({bool force = false}) {}
}

class _MemoryTokenBackend implements SecureTokenStorageBackend {
  final values = <String, String>{};
  @override
  Future<void> delete({required String key}) async => values.remove(key);
  @override
  Future<String?> read({required String key}) async => values[key];
  @override
  Future<void> write({required String key, required String value}) async =>
      values[key] = value;
}
