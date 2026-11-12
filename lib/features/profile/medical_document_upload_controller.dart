import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/api/documents_api.dart';
import '../../core/network/api_exception.dart';
import '../../core/storage/secure_token_store.dart';
import '../auth/application/auth_controller.dart';

@immutable
class MedicalDocumentUploadReceipt {
  const MedicalDocumentUploadReceipt({
    required this.accountId,
    required this.patientId,
    required this.idempotencyKey,
    required this.createdAt,
  });

  static const recoveryHorizon = Duration(hours: 24);

  final String accountId;
  final String patientId;
  final String idempotencyKey;
  final DateTime createdAt;

  bool isOutsideRecoveryHorizon(DateTime now) {
    return !now.toUtc().isBefore(createdAt.toUtc().add(recoveryHorizon));
  }
}

abstract interface class MedicalDocumentUploadReceiptStore {
  Future<void> save(MedicalDocumentUploadReceipt receipt);
  Future<MedicalDocumentUploadReceipt?> readForAccount(String accountId);
  Future<void> clearIfMatches(MedicalDocumentUploadReceipt receipt);
  Future<void> clearForAccount(String accountId);
}

/// One versioned, secure, account-scoped upload receipt.
///
/// Only opaque recovery identity is stored. File bytes, paths, names, MIME,
/// document metadata, medical content, and credentials are deliberately absent.
class SecureMedicalDocumentUploadReceiptStore
    implements MedicalDocumentUploadReceiptStore {
  SecureMedicalDocumentUploadReceiptStore({SecureTokenStorageBackend? backend})
    : _backend = backend ?? const FlutterSecureTokenStorageBackend();

  static const storageKey = 'omnicare_document_upload_recovery_v1';
  static const schemaVersion = 1;

  static final RegExp _operationKey = RegExp(r'^[A-Za-z0-9._:-]{8,128}$');

  final SecureTokenStorageBackend _backend;

  @override
  Future<void> save(MedicalDocumentUploadReceipt receipt) async {
    final normalized = _validated(receipt);
    await _backend.write(
      key: storageKey,
      value: jsonEncode({
        'schemaVersion': schemaVersion,
        'accountScope': normalized.accountId,
        'patientId': normalized.patientId,
        'operationKey': normalized.idempotencyKey,
        'createdAt': normalized.createdAt.toUtc().toIso8601String(),
      }),
    );
  }

  @override
  Future<MedicalDocumentUploadReceipt?> readForAccount(String accountId) async {
    final normalizedAccount = _required(accountId, 'accountId');
    final raw = await _backend.read(key: storageKey);
    if (raw == null || raw.trim().isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map || decoded['schemaVersion'] != schemaVersion) {
        await _backend.delete(key: storageKey);
        return null;
      }
      final storedAccount = decoded['accountScope'];
      final patientId = decoded['patientId'];
      final operationKey = decoded['operationKey'];
      final createdAt = DateTime.tryParse(
        decoded['createdAt']?.toString() ?? '',
      );
      if (storedAccount is! String ||
          patientId is! String ||
          operationKey is! String ||
          createdAt == null) {
        await _backend.delete(key: storageKey);
        return null;
      }
      if (storedAccount.trim() != normalizedAccount) return null;

      return _validated(
        MedicalDocumentUploadReceipt(
          accountId: storedAccount,
          patientId: patientId,
          idempotencyKey: operationKey,
          createdAt: createdAt.toUtc(),
        ),
      );
    } catch (_) {
      await _backend.delete(key: storageKey);
      return null;
    }
  }

  @override
  Future<void> clearIfMatches(MedicalDocumentUploadReceipt receipt) async {
    final expected = _validated(receipt);
    final current = await readForAccount(expected.accountId);
    if (current == null ||
        current.patientId != expected.patientId ||
        current.idempotencyKey != expected.idempotencyKey) {
      return;
    }
    await _backend.delete(key: storageKey);
  }

  @override
  Future<void> clearForAccount(String accountId) async {
    final normalizedAccount = _required(accountId, 'accountId');
    final raw = await _backend.read(key: storageKey);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map && decoded['accountScope'] != normalizedAccount) {
        return;
      }
    } catch (_) {
      // A malformed receipt cannot be safely assigned to another account.
    }
    await _backend.delete(key: storageKey);
  }

  static MedicalDocumentUploadReceipt _validated(
    MedicalDocumentUploadReceipt receipt,
  ) {
    final accountId = _required(receipt.accountId, 'accountId');
    final patientId = _required(receipt.patientId, 'patientId');
    final operationKey = _required(receipt.idempotencyKey, 'operationKey');
    if (!_operationKey.hasMatch(operationKey)) {
      throw const FormatException('Invalid operation key.');
    }
    return MedicalDocumentUploadReceipt(
      accountId: accountId,
      patientId: patientId,
      idempotencyKey: operationKey,
      createdAt: receipt.createdAt.toUtc(),
    );
  }

  static String _required(String value, String field) {
    final normalized = value.trim();
    if (normalized.isEmpty) throw FormatException('Invalid $field.');
    return normalized;
  }
}

enum MedicalDocumentUploadPhase {
  idle,
  preparing,
  uploading,
  recovering,
  processing,
  success,
  recoverableFailure,
  terminalFailure,
}

/// Owns upload recovery identity, account fencing, and authoritative recovery.
/// It never owns file contents after the live upload call returns.
class MedicalDocumentUploadController extends ChangeNotifier {
  MedicalDocumentUploadController({
    required DocumentsApi api,
    required MedicalDocumentUploadReceiptStore receiptStore,
    AuthController? authController,
    DateTime Function()? now,
  }) : _api = api,
       _receiptStore = receiptStore,
       _authController = authController,
       _now = now ?? DateTime.now {
    authController?.addListener(_handleAuthChanged);
    _handleAuthChanged();
  }

  final DocumentsApi _api;
  final MedicalDocumentUploadReceiptStore _receiptStore;
  final AuthController? _authController;
  final DateTime Function() _now;

  DocumentsApi get api => _api;
  MedicalDocumentUploadPhase get phase => _phase;
  MedicalDocumentRecord? get lastDocument => _lastDocument;
  List<MedicalDocumentRecord>? get reconciledDocuments => _reconciledDocuments;
  String? get failureCode => _failureCode;
  String? get currentAccountId => _accountId;
  String? get currentPatientId => _patientId;

  MedicalDocumentUploadPhase _phase = MedicalDocumentUploadPhase.idle;
  MedicalDocumentRecord? _lastDocument;
  List<MedicalDocumentRecord>? _reconciledDocuments;
  String? _failureCode;
  String? _accountId;
  String? _patientId;
  MedicalDocumentUploadReceipt? _activeReceipt;
  String? _activeDocumentId;
  CancelToken? _cancelToken;
  Future<MedicalDocumentRecord?>? _inFlight;
  int _generation = 0;
  bool _disposed = false;

  Future<void> recoverForOwner({
    required String accountId,
    required String patientId,
  }) async {
    final generation = await _activateOwner(accountId, patientId);
    final receipt = await _receiptStore.readForAccount(accountId.trim());
    if (!_isCurrent(generation, accountId, patientId) || receipt == null) {
      return;
    }
    if (receipt.patientId != patientId.trim()) return;
    await _recoverSafely(receipt, generation);
  }

  Future<MedicalDocumentRecord> upload({
    required String accountId,
    required DocumentUploadOperation operation,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
  }) {
    final active = _inFlight;
    if (active != null) {
      return active.then((value) {
        if (value == null) throw _recoveryRequired();
        return value;
      });
    }
    final started = _upload(
      accountId: accountId,
      operation: operation,
      cancelToken: cancelToken,
      onSendProgress: onSendProgress,
    );
    _inFlight = started;
    return started
        .whenComplete(() {
          if (identical(_inFlight, started)) _inFlight = null;
        })
        .then((value) {
          if (value == null) throw _recoveryRequired();
          return value;
        });
  }

  Future<MedicalDocumentRecord?> _upload({
    required String accountId,
    required DocumentUploadOperation operation,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
  }) async {
    final generation = await _activateOwner(accountId, operation.patientId);
    final existing = await _receiptStore.readForAccount(accountId.trim());
    if (!_isCurrent(generation, accountId, operation.patientId)) return null;
    if (existing != null) {
      if (existing.patientId != operation.patientId) {
        _setFailure(
          MedicalDocumentUploadPhase.terminalFailure,
          'UPLOAD_OWNER_CHANGED',
        );
        throw const ApiException(
          'A previous document operation belongs to another patient.',
          code: 'UPLOAD_OWNER_CHANGED',
        );
      }
      return _recover(existing, generation);
    }

    final receipt = MedicalDocumentUploadReceipt(
      accountId: accountId,
      patientId: operation.patientId,
      idempotencyKey: operation.idempotencyKey,
      createdAt: _now().toUtc(),
    );
    _setPhase(MedicalDocumentUploadPhase.preparing);
    try {
      // This write intentionally precedes any multipart dispatch.
      await _receiptStore.save(receipt);
    } catch (error) {
      _setFailure(
        MedicalDocumentUploadPhase.terminalFailure,
        'UPLOAD_RECEIPT_STORAGE_FAILED',
      );
      throw ApiException(
        'The upload could not start safely. Please try again.',
        code: 'UPLOAD_RECEIPT_STORAGE_FAILED',
        cause: error,
      );
    }
    if (!_isCurrent(generation, accountId, operation.patientId)) return null;

    _activeReceipt = receipt;
    var requestMayHaveBeenSent = false;
    final activeToken = cancelToken ?? CancelToken();
    _cancelToken = activeToken;
    _setPhase(MedicalDocumentUploadPhase.uploading);
    try {
      final document = await _api.upload(
        operation,
        cancelToken: activeToken,
        onSendProgress: onSendProgress,
        onRequestDispatched: () => requestMayHaveBeenSent = true,
      );
      if (!_isCurrent(generation, accountId, operation.patientId)) return null;
      await _acceptDocument(receipt, document, clearReceipt: true);
      return document;
    } catch (error) {
      if (!_isCurrent(generation, accountId, operation.patientId)) return null;
      if (!requestMayHaveBeenSent) {
        await _receiptStore.clearIfMatches(receipt);
        _activeReceipt = null;
        _setFailure(
          MedicalDocumentUploadPhase.terminalFailure,
          error is ApiException ? error.code : 'UPLOAD_NOT_DISPATCHED',
        );
        rethrow;
      }
      // Once dispatch is possible, read authority before any multipart resend.
      return _recover(receipt, generation);
    } finally {
      if (identical(_cancelToken, activeToken)) _cancelToken = null;
    }
  }

  Future<MedicalDocumentRecord?> _recover(
    MedicalDocumentUploadReceipt receipt,
    int generation,
  ) async {
    if (receipt.isOutsideRecoveryHorizon(_now())) {
      await _receiptStore.clearIfMatches(receipt);
      _activeReceipt = null;
      _setFailure(
        MedicalDocumentUploadPhase.terminalFailure,
        'DOCUMENT_UPLOAD_RECOVERY_EXPIRED',
      );
      throw const ApiException(
        'The previous upload can no longer be recovered. Start a new upload if needed.',
        code: 'DOCUMENT_UPLOAD_RECOVERY_EXPIRED',
      );
    }

    _activeReceipt = receipt;
    _setPhase(MedicalDocumentUploadPhase.recovering);
    try {
      final result = await _api.recoverUpload(
        patientId: receipt.patientId,
        idempotencyKey: receipt.idempotencyKey,
      );
      if (!_isCurrent(generation, receipt.accountId, receipt.patientId)) {
        return null;
      }
      switch (result.state) {
        case DocumentUploadRecoveryState.succeeded:
          final document = result.document!;
          await _acceptDocument(receipt, document, clearReceipt: true);
          return document;
        case DocumentUploadRecoveryState.inProgress:
          final document = result.document;
          _lastDocument = document;
          _activeDocumentId = document?.id;
          await _reconcile(receipt.patientId);
          _setPhase(MedicalDocumentUploadPhase.processing);
          return document;
        case DocumentUploadRecoveryState.failed:
          _lastDocument = result.document;
          _activeDocumentId = result.document?.id;
          await _reconcile(receipt.patientId);
          await _receiptStore.clearIfMatches(receipt);
          _activeReceipt = null;
          _setFailure(
            MedicalDocumentUploadPhase.terminalFailure,
            result.failureCode ?? 'DOCUMENT_UPLOAD_FAILED',
          );
          throw const ApiException(
            'The previous upload did not complete. Start a new upload if needed.',
            code: 'DOCUMENT_UPLOAD_FAILED',
          );
      }
    } on ApiException catch (error) {
      if (error.code == 'DOCUMENT_UPLOAD_RECOVERY_NOT_FOUND') {
        await _receiptStore.clearIfMatches(receipt);
        _activeReceipt = null;
        _setFailure(MedicalDocumentUploadPhase.terminalFailure, error.code);
        rethrow;
      }
      if (_phase != MedicalDocumentUploadPhase.terminalFailure) {
        _setFailure(
          MedicalDocumentUploadPhase.recoverableFailure,
          error.code ?? 'UPLOAD_RECOVERY_REQUIRED',
        );
      }
      rethrow;
    } catch (error) {
      _setFailure(
        MedicalDocumentUploadPhase.recoverableFailure,
        'UPLOAD_RECOVERY_REQUIRED',
      );
      throw ApiException(
        'The upload result could not be recovered yet. Refresh when the connection is available.',
        code: 'UPLOAD_RECOVERY_REQUIRED',
        cause: error,
      );
    }
  }

  Future<void> _recoverSafely(
    MedicalDocumentUploadReceipt receipt,
    int generation,
  ) async {
    try {
      await _recover(receipt, generation);
    } catch (_) {
      // State is exposed safely through this controller; startup is not blocked.
    }
  }

  Future<void> acceptAuthoritativeStatus(MedicalDocumentRecord document) async {
    final receipt = _activeReceipt;
    if (receipt == null ||
        (_activeDocumentId != null && _activeDocumentId != document.id)) {
      return;
    }
    _lastDocument = document;
    _activeDocumentId = document.id;
    if (!document.isTerminal) {
      _setPhase(MedicalDocumentUploadPhase.processing);
      return;
    }
    await _receiptStore.clearIfMatches(receipt);
    _activeReceipt = null;
    _setPhase(
      document.status == 'AVAILABLE'
          ? MedicalDocumentUploadPhase.success
          : MedicalDocumentUploadPhase.terminalFailure,
    );
  }

  Future<void> endAccount(String accountId) async {
    final normalized = accountId.trim();
    if (normalized.isEmpty) return;
    _generation++;
    _cancelToken?.cancel('medical document account ended');
    _cancelToken = null;
    _inFlight = null;
    await _receiptStore.clearForAccount(normalized);
    if (_accountId == normalized) {
      _accountId = null;
      _patientId = null;
      _activeReceipt = null;
      _activeDocumentId = null;
      _lastDocument = null;
      _reconciledDocuments = null;
      _failureCode = null;
      _setPhase(MedicalDocumentUploadPhase.idle);
    }
  }

  Future<int> _activateOwner(String accountId, String patientId) async {
    final normalizedAccount = accountId.trim();
    final normalizedPatient = patientId.trim();
    if (normalizedAccount.isEmpty || normalizedPatient.isEmpty) {
      throw const ApiException(
        'The authenticated document owner is unavailable.',
        code: 'UPLOAD_OWNER_UNAVAILABLE',
      );
    }
    if (_accountId == normalizedAccount && _patientId == normalizedPatient) {
      return _generation;
    }
    final previous = _accountId;
    _generation++;
    _cancelToken?.cancel('medical document owner changed');
    _cancelToken = null;
    _inFlight = null;
    _accountId = normalizedAccount;
    _patientId = normalizedPatient;
    _activeReceipt = null;
    _activeDocumentId = null;
    _lastDocument = null;
    _reconciledDocuments = null;
    _failureCode = null;
    _setPhase(MedicalDocumentUploadPhase.idle);
    if (previous != null && previous != normalizedAccount) {
      await _receiptStore.clearForAccount(previous);
    }
    return _generation;
  }

  Future<void> _acceptDocument(
    MedicalDocumentUploadReceipt receipt,
    MedicalDocumentRecord document, {
    required bool clearReceipt,
  }) async {
    _lastDocument = document;
    _activeDocumentId = document.id;
    await _reconcile(receipt.patientId);
    if (clearReceipt) {
      await _receiptStore.clearIfMatches(receipt);
      _activeReceipt = null;
    }
    _setPhase(
      document.isTerminal
          ? (document.status == 'AVAILABLE'
                ? MedicalDocumentUploadPhase.success
                : MedicalDocumentUploadPhase.terminalFailure)
          : MedicalDocumentUploadPhase.processing,
    );
  }

  Future<void> _reconcile(String patientId) async {
    try {
      final page = await _api.listDocuments(patientId);
      _reconciledDocuments = page.documents;
    } catch (_) {
      // The recovery projection remains authoritative even if this refresh is
      // temporarily unavailable. Foreground refresh can reconcile later.
    }
  }

  bool _isCurrent(int generation, String accountId, String patientId) {
    return !_disposed &&
        generation == _generation &&
        _accountId == accountId.trim() &&
        _patientId == patientId.trim();
  }

  void _handleAuthChanged() {
    if (_disposed) return;
    final auth = _authController;
    if (auth == null) return;
    final accountId = auth.currentUser?.id.trim();
    final patientId = auth.patientProfile?.patientId?.trim();
    if (accountId != null &&
        accountId.isNotEmpty &&
        patientId != null &&
        patientId.isNotEmpty) {
      if (_accountId == accountId && _patientId == patientId) return;
      unawaited(recoverForOwner(accountId: accountId, patientId: patientId));
      return;
    }
    final previous = _accountId;
    if (previous != null && auth.status == AuthStatus.unauthenticated) {
      unawaited(endAccount(previous));
    }
  }

  void _setPhase(MedicalDocumentUploadPhase value) {
    _phase = value;
    if (value != MedicalDocumentUploadPhase.recoverableFailure &&
        value != MedicalDocumentUploadPhase.terminalFailure) {
      _failureCode = null;
    }
    if (!_disposed) notifyListeners();
  }

  void _setFailure(MedicalDocumentUploadPhase value, String? code) {
    _failureCode = code;
    _setPhase(value);
  }

  ApiException _recoveryRequired() => const ApiException(
    'The upload result must be recovered before another upload can start.',
    code: 'UPLOAD_RECOVERY_REQUIRED',
  );

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _authController?.removeListener(_handleAuthChanged);
    _cancelToken?.cancel('medical document upload controller disposed');
    super.dispose();
  }
}
