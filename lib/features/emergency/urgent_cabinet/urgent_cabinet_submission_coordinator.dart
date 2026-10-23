import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/utils/uuid_v4.dart';
import 'urgent_cabinet_care_subject.dart';
import 'urgent_cabinet_targeted_request_models.dart';
import 'urgent_cabinet_targeted_request_repository.dart';

@immutable
class UrgentCabinetRecoveryReceipt {
  const UrgentCabinetRecoveryReceipt({
    required this.accountId,
    required this.idempotencyKey,
  });

  final String accountId;
  final String idempotencyKey;
}

abstract interface class UrgentCabinetRecoveryReceiptStore {
  Future<void> save(UrgentCabinetRecoveryReceipt receipt);
  Future<UrgentCabinetRecoveryReceipt?> readForAccount(String accountId);
  Future<void> clearForAccount(String accountId);
}

abstract interface class UrgentCabinetReceiptStorageBackend {
  Future<String?> read({required String key});
  Future<void> write({required String key, required String value});
  Future<void> delete({required String key});
}

class FlutterUrgentCabinetReceiptStorageBackend
    implements UrgentCabinetReceiptStorageBackend {
  const FlutterUrgentCabinetReceiptStorageBackend([
    FlutterSecureStorage storage = const FlutterSecureStorage(),
  ]) : _storage = storage;

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read({required String key}) => _storage.read(key: key);

  @override
  Future<void> write({required String key, required String value}) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete({required String key}) => _storage.delete(key: key);
}

/// Secure, single-account receipt storage.
///
/// The record contains only the authenticated account scope and a random
/// idempotency key. It never contains symptoms, anatomy, description, target,
/// family-member identity, fee, or server medical identifiers.
class SecureUrgentCabinetRecoveryReceiptStore
    implements UrgentCabinetRecoveryReceiptStore {
  SecureUrgentCabinetRecoveryReceiptStore({
    UrgentCabinetReceiptStorageBackend? backend,
  }) : _backend = backend ?? const FlutterUrgentCabinetReceiptStorageBackend();

  static const _storageKey = 'omnicare_urgent_cabinet_recovery_receipt_v1';
  static const _schemaVersion = 1;

  final UrgentCabinetReceiptStorageBackend _backend;

  @override
  Future<void> save(UrgentCabinetRecoveryReceipt receipt) async {
    final accountId = _normalizeAccount(receipt.accountId);
    final key = _normalizeIdempotencyKey(receipt.idempotencyKey);
    await _backend.write(
      key: _storageKey,
      value: jsonEncode({
        'schemaVersion': _schemaVersion,
        'accountScope': accountId,
        'receiptKey': key,
      }),
    );
  }

  @override
  Future<UrgentCabinetRecoveryReceipt?> readForAccount(String accountId) async {
    final normalizedAccount = _normalizeAccount(accountId);
    final raw = await _backend.read(key: _storageKey);
    if (raw == null || raw.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map || decoded['schemaVersion'] != _schemaVersion) {
        await _backend.delete(key: _storageKey);
        return null;
      }
      final storedAccount = decoded['accountScope'];
      final receiptKey = decoded['receiptKey'];
      if (storedAccount is! String || receiptKey is! String) {
        await _backend.delete(key: _storageKey);
        return null;
      }
      if (storedAccount != normalizedAccount) return null;
      return UrgentCabinetRecoveryReceipt(
        accountId: normalizedAccount,
        idempotencyKey: _normalizeIdempotencyKey(receiptKey),
      );
    } catch (_) {
      await _backend.delete(key: _storageKey);
      return null;
    }
  }

  @override
  Future<void> clearForAccount(String accountId) async {
    final normalizedAccount = _normalizeAccount(accountId);
    final raw = await _backend.read(key: _storageKey);
    if (raw == null) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map && decoded['accountScope'] != normalizedAccount) {
        return;
      }
    } catch (_) {
      // A malformed record cannot be safely assigned to another account.
    }
    await _backend.delete(key: _storageKey);
  }
}

enum UrgentCabinetSubmissionResultKind {
  acknowledged,
  recovered,
  noActiveRequest,
  definiteFailure,
  unknownOutcome,
  obsolete,
}

@immutable
class UrgentCabinetSubmissionResult {
  const UrgentCabinetSubmissionResult._({
    required this.kind,
    this.snapshot,
    this.failure,
  });

  const UrgentCabinetSubmissionResult.acknowledged(
    UrgentCabinetTargetedRequestSnapshot snapshot,
  ) : this._(
        kind: UrgentCabinetSubmissionResultKind.acknowledged,
        snapshot: snapshot,
      );

  const UrgentCabinetSubmissionResult.recovered(
    UrgentCabinetTargetedRequestSnapshot snapshot,
  ) : this._(
        kind: UrgentCabinetSubmissionResultKind.recovered,
        snapshot: snapshot,
      );

  const UrgentCabinetSubmissionResult.noActiveRequest()
    : this._(kind: UrgentCabinetSubmissionResultKind.noActiveRequest);

  const UrgentCabinetSubmissionResult.definiteFailure(
    UrgentCabinetPatientRequestFailure failure,
  ) : this._(
        kind: UrgentCabinetSubmissionResultKind.definiteFailure,
        failure: failure,
      );

  const UrgentCabinetSubmissionResult.unknownOutcome(
    UrgentCabinetPatientRequestFailure failure,
  ) : this._(
        kind: UrgentCabinetSubmissionResultKind.unknownOutcome,
        failure: failure,
      );

  const UrgentCabinetSubmissionResult.obsolete()
    : this._(kind: UrgentCabinetSubmissionResultKind.obsolete);

  final UrgentCabinetSubmissionResultKind kind;
  final UrgentCabinetTargetedRequestSnapshot? snapshot;
  final UrgentCabinetPatientRequestFailure? failure;
}

/// Owns one Patient account's submission receipt and network generation.
class UrgentCabinetSubmissionCoordinator {
  UrgentCabinetSubmissionCoordinator({
    required UrgentCabinetTargetedRequestRepository repository,
    required UrgentCabinetRecoveryReceiptStore receiptStore,
    String Function() idempotencyKeyFactory = generateUuidV4,
  }) : _repository = repository,
       _receiptStore = receiptStore,
       _idempotencyKeyFactory = idempotencyKeyFactory;

  final UrgentCabinetTargetedRequestRepository _repository;
  final UrgentCabinetRecoveryReceiptStore _receiptStore;
  final String Function() _idempotencyKeyFactory;

  int _generation = 0;
  bool _disposed = false;
  String? _accountId;
  String? _logicalFingerprint;
  String? _idempotencyKey;
  bool _outcomeUncertain = false;
  CancelToken? _cancelToken;
  Future<UrgentCabinetSubmissionResult>? _inFlight;

  Future<UrgentCabinetSubmissionResult> submit({
    required String accountId,
    required UrgentCabinetTargetedSubmission submission,
  }) {
    final normalizedAccount = _normalizeAccount(accountId);
    final fingerprint = submission.logicalFingerprint;
    final active = _inFlight;
    if (active != null) {
      if (_accountId == normalizedAccount &&
          _logicalFingerprint == fingerprint) {
        return active;
      }
      return Future.value(
        const UrgentCabinetSubmissionResult.definiteFailure(
          UrgentCabinetPatientRequestFailure(
            kind: UrgentCabinetPatientRequestFailureKind.activeJourneyExists,
            message: 'Une autre soumission CABINET est déjà en cours.',
          ),
        ),
      );
    }
    if (_disposed) {
      return Future.value(const UrgentCabinetSubmissionResult.obsolete());
    }
    if (_accountId != null && _accountId != normalizedAccount) {
      return Future.value(
        const UrgentCabinetSubmissionResult.definiteFailure(
          UrgentCabinetPatientRequestFailure(
            kind: UrgentCabinetPatientRequestFailureKind.sessionRejected,
            message: 'Le compte Patient a changé.',
          ),
        ),
      );
    }
    if (_logicalFingerprint != null && _logicalFingerprint != fingerprint) {
      if (_outcomeUncertain) {
        return Future.value(
          const UrgentCabinetSubmissionResult.unknownOutcome(
            UrgentCabinetPatientRequestFailure(
              kind: UrgentCabinetPatientRequestFailureKind.commandInProgress,
              message:
                  'Le résultat de la demande précédente doit être récupéré '
                  'avant de modifier la demande.',
            ),
          ),
        );
      }
      _idempotencyKey = null;
      _outcomeUncertain = false;
    }
    _accountId = normalizedAccount;
    _logicalFingerprint = fingerprint;
    _idempotencyKey ??= _newIdempotencyKey();
    final generation = ++_generation;
    final token = CancelToken();
    _cancelToken = token;
    final future = _outcomeUncertain
        ? _recoverOnly(
            accountId: normalizedAccount,
            generation: generation,
            cancelToken: token,
          )
        : _submitAndRecover(
            accountId: normalizedAccount,
            submission: submission,
            generation: generation,
            cancelToken: token,
          );
    _inFlight = future;
    future.then((_) {
      if (identical(_inFlight, future)) {
        _inFlight = null;
        if (identical(_cancelToken, token)) _cancelToken = null;
      }
    });
    return future;
  }

  Future<UrgentCabinetSubmissionResult> recoverAfterRestart({
    required String accountId,
    required UrgentCabinetCareSubject subject,
  }) async {
    if (_disposed) return const UrgentCabinetSubmissionResult.obsolete();
    final normalizedAccount = _normalizeAccount(accountId);
    _accountId = normalizedAccount;
    final generation = ++_generation;
    _cancelToken?.cancel('urgent-cabinet-recovery-replaced');
    final token = CancelToken();
    _cancelToken = token;
    try {
      final receipt = await _receiptStore.readForAccount(normalizedAccount);
      if (!_isCurrent(generation, normalizedAccount)) {
        return const UrgentCabinetSubmissionResult.obsolete();
      }
      if (receipt != null) {
        _idempotencyKey = receipt.idempotencyKey;
        try {
          final recovered = await _repository.recover(
            receipt.idempotencyKey,
            cancelToken: token,
          );
          if (!_isCurrent(generation, normalizedAccount)) {
            return const UrgentCabinetSubmissionResult.obsolete();
          }
          _outcomeUncertain = false;
          return UrgentCabinetSubmissionResult.recovered(recovered);
        } on UrgentCabinetPatientRequestFailure catch (failure) {
          if (!failure.isAuthoritativeRequestAbsence) {
            return failure.hasAmbiguousSubmissionOutcome
                ? UrgentCabinetSubmissionResult.unknownOutcome(failure)
                : UrgentCabinetSubmissionResult.definiteFailure(failure);
          }
        }
      }
      final active = await _repository.active(subject, cancelToken: token);
      if (!_isCurrent(generation, normalizedAccount)) {
        return const UrgentCabinetSubmissionResult.obsolete();
      }
      return UrgentCabinetSubmissionResult.recovered(active);
    } on UrgentCabinetPatientRequestFailure catch (failure) {
      if (!_isCurrent(generation, normalizedAccount) ||
          failure.kind == UrgentCabinetPatientRequestFailureKind.cancelled) {
        return const UrgentCabinetSubmissionResult.obsolete();
      }
      if (failure.isAuthoritativeRequestAbsence) {
        // A subject-scoped active read returning 404 is authoritative absence,
        // not a fabricated failure state. Remove any stale opaque receipt so
        // later re-entry does not repeatedly recover a request that is absent.
        try {
          await _receiptStore.clearForAccount(normalizedAccount);
        } catch (error) {
          return UrgentCabinetSubmissionResult.definiteFailure(
            UrgentCabinetPatientRequestFailure.from(error),
          );
        }
        _idempotencyKey = null;
        _logicalFingerprint = null;
        _outcomeUncertain = false;
        return const UrgentCabinetSubmissionResult.noActiveRequest();
      }
      return failure.hasAmbiguousSubmissionOutcome
          ? UrgentCabinetSubmissionResult.unknownOutcome(failure)
          : UrgentCabinetSubmissionResult.definiteFailure(failure);
    } catch (error) {
      if (!_isCurrent(generation, normalizedAccount)) {
        return const UrgentCabinetSubmissionResult.obsolete();
      }
      return UrgentCabinetSubmissionResult.definiteFailure(
        UrgentCabinetPatientRequestFailure.from(error),
      );
    }
  }

  Future<void> invalidateSession(String accountId) async {
    final normalizedAccount = _normalizeAccount(accountId);
    _generation++;
    _cancelToken?.cancel('urgent-cabinet-session-invalidated');
    _cancelToken = null;
    _inFlight = null;
    _accountId = null;
    _logicalFingerprint = null;
    _idempotencyKey = null;
    _outcomeUncertain = false;
    await _receiptStore.clearForAccount(normalizedAccount);
  }

  /// Releases recovery metadata only after the lifecycle controller has
  /// verified a precommitment terminal outcome and the Patient deliberately
  /// starts a new journey. This is not a cancellation command.
  Future<void> releaseTerminalForNewJourney(String accountId) async {
    final normalizedAccount = _normalizeAccount(accountId);
    if (_accountId != null && _accountId != normalizedAccount) {
      throw StateError('The urgent CABINET account scope changed.');
    }
    _generation++;
    _cancelToken?.cancel('urgent-cabinet-terminal-released');
    _cancelToken = null;
    _inFlight = null;
    _accountId = normalizedAccount;
    _logicalFingerprint = null;
    _idempotencyKey = null;
    _outcomeUncertain = false;
    await _receiptStore.clearForAccount(normalizedAccount);
  }

  Future<UrgentCabinetSubmissionResult> _submitAndRecover({
    required String accountId,
    required UrgentCabinetTargetedSubmission submission,
    required int generation,
    required CancelToken cancelToken,
  }) async {
    final key = _idempotencyKey!;
    try {
      await _receiptStore.save(
        UrgentCabinetRecoveryReceipt(accountId: accountId, idempotencyKey: key),
      );
      if (!_isCurrent(generation, accountId)) {
        return const UrgentCabinetSubmissionResult.obsolete();
      }
      final snapshot = await _repository.submit(
        submission: submission,
        idempotencyKey: key,
        cancelToken: cancelToken,
      );
      if (!_isCurrent(generation, accountId)) {
        return const UrgentCabinetSubmissionResult.obsolete();
      }
      _outcomeUncertain = false;
      return UrgentCabinetSubmissionResult.acknowledged(snapshot);
    } on UrgentCabinetPatientRequestFailure catch (failure) {
      if (!_isCurrent(generation, accountId) ||
          failure.kind == UrgentCabinetPatientRequestFailureKind.cancelled) {
        return const UrgentCabinetSubmissionResult.obsolete();
      }
      if (!failure.hasAmbiguousSubmissionOutcome) {
        await _receiptStore.clearForAccount(accountId);
        return UrgentCabinetSubmissionResult.definiteFailure(failure);
      }
      _outcomeUncertain = true;
      return _recoverOnly(
        accountId: accountId,
        generation: generation,
        cancelToken: cancelToken,
        originalFailure: failure,
      );
    } catch (error) {
      if (!_isCurrent(generation, accountId)) {
        return const UrgentCabinetSubmissionResult.obsolete();
      }
      await _receiptStore.clearForAccount(accountId);
      return UrgentCabinetSubmissionResult.definiteFailure(
        UrgentCabinetPatientRequestFailure.from(error),
      );
    }
  }

  Future<UrgentCabinetSubmissionResult> _recoverOnly({
    required String accountId,
    required int generation,
    required CancelToken cancelToken,
    UrgentCabinetPatientRequestFailure? originalFailure,
  }) async {
    try {
      final snapshot = await _repository.recover(
        _idempotencyKey!,
        cancelToken: cancelToken,
      );
      if (!_isCurrent(generation, accountId)) {
        return const UrgentCabinetSubmissionResult.obsolete();
      }
      _outcomeUncertain = false;
      return UrgentCabinetSubmissionResult.recovered(snapshot);
    } on UrgentCabinetPatientRequestFailure catch (recoveryFailure) {
      if (!_isCurrent(generation, accountId) ||
          recoveryFailure.kind ==
              UrgentCabinetPatientRequestFailureKind.cancelled) {
        return const UrgentCabinetSubmissionResult.obsolete();
      }
      _outcomeUncertain = true;
      return UrgentCabinetSubmissionResult.unknownOutcome(
        originalFailure ?? recoveryFailure,
      );
    } catch (error) {
      if (!_isCurrent(generation, accountId)) {
        return const UrgentCabinetSubmissionResult.obsolete();
      }
      _outcomeUncertain = true;
      return UrgentCabinetSubmissionResult.unknownOutcome(
        originalFailure ?? UrgentCabinetPatientRequestFailure.from(error),
      );
    }
  }

  bool _isCurrent(int generation, String accountId) =>
      !_disposed && generation == _generation && _accountId == accountId;

  String _newIdempotencyKey() =>
      _normalizeIdempotencyKey(_idempotencyKeyFactory());

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    _cancelToken?.cancel('urgent-cabinet-coordinator-disposed');
    _cancelToken = null;
    _inFlight = null;
    _accountId = null;
    _logicalFingerprint = null;
    _idempotencyKey = null;
    _outcomeUncertain = false;
  }
}

String _normalizeAccount(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) throw ArgumentError('Patient account is required.');
  return normalized;
}

String _normalizeIdempotencyKey(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty || normalized.length > 128) {
    throw StateError('Invalid urgent CABINET idempotency key.');
  }
  return normalized;
}
