import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/core/api/documents_api.dart';
import 'package:omnicare_mobile/core/network/api_exception.dart';
import 'package:omnicare_mobile/core/storage/secure_token_store.dart';
import 'package:omnicare_mobile/features/profile/medical_document_upload_controller.dart';

const _accountA = 'account-a';
const _accountB = 'account-b';
const _patientA = 'patient-a';
const _operationKey = 'upload:11111111111111111111111111111111';

class _MemoryStorage implements SecureTokenStorageBackend {
  final Map<String, String> values = {};
  final List<String> events = [];

  @override
  Future<void> delete({required String key}) async {
    events.add('delete');
    values.remove(key);
  }

  @override
  Future<String?> read({required String key}) async => values[key];

  @override
  Future<void> write({required String key, required String value}) async {
    events.add('write');
    values[key] = value;
  }
}

class _FakeDocumentsApi extends DocumentsApi {
  _FakeDocumentsApi({
    this.uploadError,
    this.recoveryResult,
    this.recoveryError,
    this.uploadGate,
    this.events,
  });

  Object? uploadError;
  DocumentUploadRecoveryResult? recoveryResult;
  Object? recoveryError;
  Completer<void>? uploadGate;
  List<String>? events;
  int uploadCalls = 0;
  int recoveryCalls = 0;
  final List<String> recoveryKeys = [];

  @override
  Future<MedicalDocumentRecord> upload(
    DocumentUploadOperation operation, {
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    void Function()? onRequestDispatched,
  }) async {
    uploadCalls++;
    events?.add('upload');
    if (cancelToken?.isCancelled ?? false) {
      throw const ApiException(
        'cancelled before dispatch',
        code: 'UPLOAD_CANCELLED_LOCAL',
      );
    }
    onRequestDispatched?.call();
    await uploadGate?.future;
    if (uploadError != null) throw uploadError!;
    return _document('SCAN_PENDING');
  }

  @override
  Future<DocumentUploadRecoveryResult> recoverUpload({
    required String patientId,
    required String idempotencyKey,
  }) async {
    recoveryCalls++;
    recoveryKeys.add(idempotencyKey);
    if (recoveryError != null) throw recoveryError!;
    return recoveryResult ??
        DocumentUploadRecoveryResult(
          state: DocumentUploadRecoveryState.succeeded,
          document: _document('AVAILABLE'),
        );
  }

  @override
  Future<MedicalDocumentPage> listDocuments(String patientId) async {
    final document = recoveryResult?.document;
    return MedicalDocumentPage(
      documents: document == null ? const [] : [document],
    );
  }
}

MedicalDocumentRecord _document(String status) => MedicalDocumentRecord(
  id: 'document-1',
  patientId: _patientA,
  documentType: 'LAB_RESULT',
  status: status,
  createdAt: DateTime.utc(2026, 11, 9),
);

DocumentUploadOperation _operation(DocumentsApi api) => api.startUpload(
  patientId: _patientA,
  fileSizeBytes: 1,
  bytes: Uint8List.fromList([1]),
  filename: 'never-persist-this.pdf',
  mimeType: 'application/pdf',
  displayName: 'Never persist this title',
  documentType: 'LAB_RESULT',
  documentDate: DateTime.utc(2026, 11, 9),
);

MedicalDocumentUploadReceipt _receipt({DateTime? createdAt}) =>
    MedicalDocumentUploadReceipt(
      accountId: _accountA,
      patientId: _patientA,
      idempotencyKey: _operationKey,
      createdAt: createdAt ?? DateTime.utc(2026, 11, 9, 10),
    );

void main() {
  group('secure upload receipt', () {
    test('stores only versioned opaque recovery identity', () async {
      final backend = _MemoryStorage();
      final store = SecureMedicalDocumentUploadReceiptStore(backend: backend);
      await store.save(_receipt());

      final raw =
          backend.values[SecureMedicalDocumentUploadReceiptStore.storageKey]!;
      final json = (jsonDecode(raw) as Map).cast<String, dynamic>();
      expect(json.keys, {
        'schemaVersion',
        'accountScope',
        'patientId',
        'operationKey',
        'createdAt',
      });
      expect(raw, isNot(contains('never-persist-this')));
      expect(raw, isNot(contains('filename')));
      expect(raw, isNot(contains('filePath')));
      expect(raw, isNot(contains('mime')));
      expect(raw, isNot(contains('accessToken')));
      expect(raw, isNot(contains('refreshToken')));
    });

    test('validates schema, malformed records, and account scope', () async {
      final backend = _MemoryStorage();
      final store = SecureMedicalDocumentUploadReceiptStore(backend: backend);
      await store.save(_receipt());

      expect(await store.readForAccount(_accountB), isNull);
      expect(await store.readForAccount(_accountA), isNotNull);

      backend.values[SecureMedicalDocumentUploadReceiptStore.storageKey] =
          '{not-json';
      expect(await store.readForAccount(_accountA), isNull);
      expect(backend.values, isEmpty);

      backend.values[SecureMedicalDocumentUploadReceiptStore.storageKey] =
          jsonEncode({'schemaVersion': 999});
      expect(await store.readForAccount(_accountA), isNull);
      expect(backend.values, isEmpty);
    });

    test('24-hour boundary is isolated and deterministic', () {
      final receipt = _receipt();
      expect(
        receipt.isOutsideRecoveryHorizon(
          receipt.createdAt.add(const Duration(hours: 23, minutes: 59)),
        ),
        isFalse,
      );
      expect(
        receipt.isOutsideRecoveryHorizon(
          receipt.createdAt.add(const Duration(hours: 24)),
        ),
        isTrue,
      );
    });
  });

  group('upload recovery controller', () {
    test(
      'persists receipt before multipart dispatch and clears on success',
      () async {
        final backend = _MemoryStorage();
        final events = backend.events;
        final api = _FakeDocumentsApi(events: events);
        final controller = MedicalDocumentUploadController(
          api: api,
          receiptStore: SecureMedicalDocumentUploadReceiptStore(
            backend: backend,
          ),
          now: () => DateTime.utc(2026, 11, 9, 10),
        );

        final result = await controller.upload(
          accountId: _accountA,
          operation: _operation(api),
        );

        expect(result.id, 'document-1');
        expect(events.indexOf('write'), lessThan(events.indexOf('upload')));
        expect(backend.values, isEmpty);
        expect(controller.phase, MedicalDocumentUploadPhase.processing);
      },
    );

    test(
      'response loss recovers success with no second multipart send',
      () async {
        final backend = _MemoryStorage();
        final api = _FakeDocumentsApi(
          uploadError: const ApiException('response lost', code: 'TIMEOUT'),
          recoveryResult: DocumentUploadRecoveryResult(
            state: DocumentUploadRecoveryState.succeeded,
            document: _document('AVAILABLE'),
          ),
        );
        final controller = MedicalDocumentUploadController(
          api: api,
          receiptStore: SecureMedicalDocumentUploadReceiptStore(
            backend: backend,
          ),
          now: () => DateTime.utc(2026, 11, 9, 10),
        );

        final result = await controller.upload(
          accountId: _accountA,
          operation: _operation(api),
        );

        expect(result.id, 'document-1');
        expect(api.uploadCalls, 1);
        expect(api.recoveryCalls, 1);
        expect(backend.values, isEmpty);
        expect(controller.phase, MedicalDocumentUploadPhase.success);
      },
    );

    test(
      'cold restart restores success without original file source',
      () async {
        final backend = _MemoryStorage();
        final store = SecureMedicalDocumentUploadReceiptStore(backend: backend);
        await store.save(_receipt());
        final api = _FakeDocumentsApi(
          recoveryResult: DocumentUploadRecoveryResult(
            state: DocumentUploadRecoveryState.succeeded,
            document: _document('AVAILABLE'),
          ),
        );

        final restarted = MedicalDocumentUploadController(
          api: api,
          receiptStore: SecureMedicalDocumentUploadReceiptStore(
            backend: backend,
          ),
          now: () => DateTime.utc(2026, 11, 9, 11),
        );
        await restarted.recoverForOwner(
          accountId: _accountA,
          patientId: _patientA,
        );

        expect(api.uploadCalls, 0);
        expect(api.recoveryKeys, [_operationKey]);
        expect(restarted.lastDocument!.id, 'document-1');
        expect(restarted.phase, MedicalDocumentUploadPhase.success);
        expect(backend.values, isEmpty);
      },
    );

    test(
      'in progress retains receipt and terminal status later clears it',
      () async {
        final backend = _MemoryStorage();
        final store = SecureMedicalDocumentUploadReceiptStore(backend: backend);
        await store.save(_receipt());
        final api = _FakeDocumentsApi(
          recoveryResult: DocumentUploadRecoveryResult(
            state: DocumentUploadRecoveryState.inProgress,
            document: _document('SCAN_PENDING'),
          ),
        );
        final controller = MedicalDocumentUploadController(
          api: api,
          receiptStore: store,
          now: () => DateTime.utc(2026, 11, 9, 11),
        );

        await controller.recoverForOwner(
          accountId: _accountA,
          patientId: _patientA,
        );
        expect(controller.phase, MedicalDocumentUploadPhase.processing);
        expect(await store.readForAccount(_accountA), isNotNull);
        expect(api.uploadCalls, 0);
        expect(controller.reconciledDocuments!.single.id, 'document-1');

        await controller.acceptAuthoritativeStatus(_document('AVAILABLE'));
        expect(await store.readForAccount(_accountA), isNull);
        expect(controller.phase, MedicalDocumentUploadPhase.success);
      },
    );

    test('failed and not-found are terminal and never resend', () async {
      for (final missing in [false, true]) {
        final backend = _MemoryStorage();
        final store = SecureMedicalDocumentUploadReceiptStore(backend: backend);
        await store.save(_receipt());
        final api = _FakeDocumentsApi(
          recoveryResult: missing
              ? null
              : const DocumentUploadRecoveryResult(
                  state: DocumentUploadRecoveryState.failed,
                  failureCode: 'DOCUMENT_SCAN_FAILED',
                ),
          recoveryError: missing
              ? const ApiException(
                  'not found',
                  code: 'DOCUMENT_UPLOAD_RECOVERY_NOT_FOUND',
                  statusCode: 404,
                )
              : null,
        );
        final controller = MedicalDocumentUploadController(
          api: api,
          receiptStore: store,
          now: () => DateTime.utc(2026, 11, 9, 11),
        );

        await controller.recoverForOwner(
          accountId: _accountA,
          patientId: _patientA,
        );
        expect(controller.phase, MedicalDocumentUploadPhase.terminalFailure);
        expect(await store.readForAccount(_accountA), isNull);
        expect(api.uploadCalls, 0);
      }
    });

    test('temporary recovery failure retains receipt', () async {
      final backend = _MemoryStorage();
      final store = SecureMedicalDocumentUploadReceiptStore(backend: backend);
      final api = _FakeDocumentsApi(
        uploadError: const ApiException('response lost', code: 'TIMEOUT'),
        recoveryError: const ApiException('offline', code: 'NO_CONNECTION'),
      );
      final controller = MedicalDocumentUploadController(
        api: api,
        receiptStore: store,
        now: () => DateTime.utc(2026, 11, 9, 11),
      );

      await expectLater(
        controller.upload(accountId: _accountA, operation: _operation(api)),
        throwsA(isA<ApiException>()),
      );
      expect(controller.phase, MedicalDocumentUploadPhase.recoverableFailure);
      expect(api.uploadCalls, 1);
      expect(api.recoveryCalls, 1);
      expect(await store.readForAccount(_accountA), isNotNull);
    });

    test('expired receipt resolves without recovery or resubmission', () async {
      final backend = _MemoryStorage();
      final store = SecureMedicalDocumentUploadReceiptStore(backend: backend);
      await store.save(_receipt());
      final api = _FakeDocumentsApi();
      final controller = MedicalDocumentUploadController(
        api: api,
        receiptStore: store,
        now: () => DateTime.utc(2026, 11, 10, 10),
      );

      await controller.recoverForOwner(
        accountId: _accountA,
        patientId: _patientA,
      );
      expect(controller.failureCode, 'DOCUMENT_UPLOAD_RECOVERY_EXPIRED');
      expect(api.recoveryCalls, 0);
      expect(api.uploadCalls, 0);
      expect(await store.readForAccount(_accountA), isNull);
    });

    test(
      'wrong account does not recover and logout clears its receipt',
      () async {
        final backend = _MemoryStorage();
        final store = SecureMedicalDocumentUploadReceiptStore(backend: backend);
        await store.save(_receipt());
        final api = _FakeDocumentsApi();
        final controller = MedicalDocumentUploadController(
          api: api,
          receiptStore: store,
          now: () => DateTime.utc(2026, 11, 9, 11),
        );

        await controller.recoverForOwner(
          accountId: _accountB,
          patientId: 'patient-b',
        );
        expect(api.recoveryCalls, 0);
        expect(await store.readForAccount(_accountA), isNotNull);

        await controller.endAccount(_accountB);
        expect(await store.readForAccount(_accountA), isNotNull);
        await controller.endAccount(_accountA);
        expect(await store.readForAccount(_accountA), isNull);
      },
    );

    test('cancel before dispatch clears the receipt safely', () async {
      final backend = _MemoryStorage();
      final store = SecureMedicalDocumentUploadReceiptStore(backend: backend);
      final api = _FakeDocumentsApi();
      final controller = MedicalDocumentUploadController(
        api: api,
        receiptStore: store,
        now: () => DateTime.utc(2026, 11, 9, 11),
      );
      final token = CancelToken()..cancel('before send');

      await expectLater(
        controller.upload(
          accountId: _accountA,
          operation: _operation(api),
          cancelToken: token,
        ),
        throwsA(isA<ApiException>()),
      );
      expect(await store.readForAccount(_accountA), isNull);
      expect(api.recoveryCalls, 0);
    });

    test(
      'terminal failed or not-found operation requires explicit new key and upload',
      () async {
        for (final missing in [false, true]) {
          final backend = _MemoryStorage();
          final store = SecureMedicalDocumentUploadReceiptStore(
            backend: backend,
          );
          await store.save(_receipt());
          final api = _FakeDocumentsApi(
            recoveryResult: missing
                ? null
                : const DocumentUploadRecoveryResult(
                    state: DocumentUploadRecoveryState.failed,
                    failureCode: 'DOCUMENT_SCAN_FAILED',
                  ),
            recoveryError: missing
                ? const ApiException(
                    'not found',
                    code: 'DOCUMENT_UPLOAD_RECOVERY_NOT_FOUND',
                    statusCode: 404,
                  )
                : null,
          );
          final controller = MedicalDocumentUploadController(
            api: api,
            receiptStore: store,
            now: () => DateTime.utc(2026, 11, 9, 11),
          );
          await controller.recoverForOwner(
            accountId: _accountA,
            patientId: _patientA,
          );

          api.recoveryError = null;
          final firstNewOperation = _operation(api);
          final secondNewOperation = _operation(api);
          expect(firstNewOperation.idempotencyKey, isNot(_operationKey));
          expect(
            secondNewOperation.idempotencyKey,
            isNot(firstNewOperation.idempotencyKey),
          );
          await controller.upload(
            accountId: _accountA,
            operation: firstNewOperation,
          );
          expect(api.uploadCalls, 1);
        }
      },
    );

    test('account end fences a late upload callback', () async {
      final gate = Completer<void>();
      final backend = _MemoryStorage();
      final api = _FakeDocumentsApi(uploadGate: gate);
      final controller = MedicalDocumentUploadController(
        api: api,
        receiptStore: SecureMedicalDocumentUploadReceiptStore(backend: backend),
        now: () => DateTime.utc(2026, 11, 9, 11),
      );

      final pending = controller.upload(
        accountId: _accountA,
        operation: _operation(api),
      );
      await Future<void>.delayed(Duration.zero);
      await controller.endAccount(_accountA);
      gate.complete();

      await expectLater(pending, throwsA(isA<ApiException>()));
      expect(controller.currentAccountId, isNull);
      expect(controller.lastDocument, isNull);
      expect(
        await SecureMedicalDocumentUploadReceiptStore(
          backend: backend,
        ).readForAccount(_accountA),
        isNull,
      );
    });
  });
}
