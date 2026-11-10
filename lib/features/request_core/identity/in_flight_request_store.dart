import 'dart:convert';

import '../../../core/storage/secure_token_store.dart';
import '../domain/request_subject.dart';
import '../domain/request_vocabulary.dart';
import 'request_operation_id.dart';

enum InFlightRequestDispatchState { prepared, dispatchAttempted }

/// Minimal durable identity for an unresolved clinic-request command.
///
/// It deliberately cannot contain the submission situation, pickup location,
/// address, coordinates, profile data, or any other business payload. Recovery
/// is GET-first by [operationId]; this record is never restored as business
/// truth and is never sufficient for a blind POST replay after process death.
class InFlightRequestOperation {
  const InFlightRequestOperation({
    required this.accountScope,
    required this.operationId,
    required this.clinicId,
    required this.subject,
    required this.dispatchState,
    required this.createdAt,
    this.requiresOwnerValidation = false,
  });

  /// Null only for a quarantined schema-v2 migration. Such a record may be
  /// used for one owner-authorized GET, but never for replay.
  final String? accountScope;
  final RequestOperationId operationId;
  final String clinicId;
  final RequestSubject subject;
  final InFlightRequestDispatchState dispatchState;
  final DateTime createdAt;
  final bool requiresOwnerValidation;

  bool belongsTo(String accountId) =>
      accountScope != null && accountScope == accountId.trim();

  InFlightRequestOperation copyWith({
    String? accountScope,
    InFlightRequestDispatchState? dispatchState,
    bool? requiresOwnerValidation,
  }) => InFlightRequestOperation(
    accountScope: accountScope ?? this.accountScope,
    operationId: operationId,
    clinicId: clinicId,
    subject: subject,
    dispatchState: dispatchState ?? this.dispatchState,
    createdAt: createdAt,
    requiresOwnerValidation:
        requiresOwnerValidation ?? this.requiresOwnerValidation,
  );

  @override
  String toString() => 'InFlightRequestOperation(CLINIC)';
}

enum InFlightRequestReadStatus { absent, available, ownerMismatch }

class InFlightRequestReadResult {
  const InFlightRequestReadResult._(this.status, this.operation);

  const InFlightRequestReadResult.absent()
    : this._(InFlightRequestReadStatus.absent, null);
  const InFlightRequestReadResult.available(InFlightRequestOperation operation)
    : this._(InFlightRequestReadStatus.available, operation);
  const InFlightRequestReadResult.ownerMismatch()
    : this._(InFlightRequestReadStatus.ownerMismatch, null);

  final InFlightRequestReadStatus status;
  final InFlightRequestOperation? operation;
}

class InFlightRequestStorageException implements Exception {
  const InFlightRequestStorageException();

  @override
  String toString() => 'InFlightRequestStorageException';
}

typedef InFlightRequestClock = DateTime Function();

/// Versioned secure store for the one unresolved clinic submission.
class InFlightRequestStore {
  InFlightRequestStore({
    SecureTokenStorageBackend? backend,
    InFlightRequestClock? clock,
  }) : _backend = backend ?? const FlutterSecureTokenStorageBackend(),
       _clock = clock ?? _utcNow;

  static const String storageKey = 'omnicare_request_inflight_v1';
  static const int schemaVersion = 3;
  static const int legacySchemaVersion = 2;

  final SecureTokenStorageBackend _backend;
  final InFlightRequestClock _clock;

  /// Required durability boundary. A caller must not dispatch if this throws.
  Future<void> save(InFlightRequestOperation operation) async {
    final account = operation.accountScope?.trim();
    final clinic = operation.clinicId.trim();
    if (account == null || account.isEmpty || clinic.isEmpty) {
      throw const InFlightRequestStorageException();
    }
    try {
      await _write(operation);
    } catch (_) {
      throw const InFlightRequestStorageException();
    }
  }

  Future<void> markDispatchAttempted(InFlightRequestOperation operation) =>
      save(
        operation.copyWith(
          dispatchState: InFlightRequestDispatchState.dispatchAttempted,
        ),
      );

  /// Reads only a record that can safely be considered for [accountId].
  ///
  /// A v3 record owned by another account is left untouched and not exposed.
  /// A v2 record is migrated to an opaque, unscoped quarantine: its GPS,
  /// address, pickup, and situation are discarded before GET-first recovery.
  Future<InFlightRequestReadResult> readForAccount(String accountId) async {
    final owner = accountId.trim();
    if (owner.isEmpty) return const InFlightRequestReadResult.absent();
    String? raw;
    try {
      raw = await _backend.read(key: storageKey);
    } catch (_) {
      return const InFlightRequestReadResult.absent();
    }
    if (raw == null || raw.trim().isEmpty) {
      return const InFlightRequestReadResult.absent();
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return _discard();
      final json = decoded.cast<String, dynamic>();
      final version = json['schemaVersion'];
      if (version == schemaVersion) {
        final operation = _readV3(json);
        if (operation == null) return _discard();
        if (operation.accountScope != null && !operation.belongsTo(owner)) {
          return const InFlightRequestReadResult.ownerMismatch();
        }
        return InFlightRequestReadResult.available(operation);
      }
      if (version == legacySchemaVersion) {
        final migrated = _readLegacyV2(json);
        if (migrated == null) return _discard();
        // Strip the legacy sensitive payload immediately. The unscoped marker
        // prevents replay; the backend GET is the only ownership proof.
        try {
          await _write(migrated);
        } catch (_) {
          // Keep the legacy operation untouched for a later migration attempt;
          // never delete a possibly committed identity because secure storage
          // was temporarily unavailable.
          return const InFlightRequestReadResult.absent();
        }
        return InFlightRequestReadResult.available(migrated);
      }
      return _discard();
    } catch (_) {
      return _discard();
    }
  }

  Future<void> clear() async {
    try {
      await _backend.delete(key: storageKey);
    } catch (_) {
      // Clearing is best-effort; owner scoping still prevents cross-account use.
    }
  }

  Future<void> _write(InFlightRequestOperation operation) {
    final subject = operation.subject;
    return _backend.write(
      key: storageKey,
      value: jsonEncode({
        'schemaVersion': schemaVersion,
        'accountScope': operation.accountScope,
        'requestId': operation.operationId.value,
        'clinicId': operation.clinicId,
        'subjectType': subject.type.wireValue,
        'familyMemberId': subject.familyMemberId,
        'dispatchState': operation.dispatchState.name,
        'createdAt': operation.createdAt.toUtc().toIso8601String(),
        if (operation.requiresOwnerValidation) 'ownerValidationRequired': true,
      }),
    );
  }

  InFlightRequestOperation? _readV3(Map<String, dynamic> json) {
    final operationId = RequestOperationId.tryParse(
      json['requestId'] as String?,
    );
    final clinicId = (json['clinicId'] as String?)?.trim();
    final accountScope = (json['accountScope'] as String?)?.trim();
    final subject = _readSubject(json);
    final createdAt = DateTime.tryParse((json['createdAt'] as String?) ?? '');
    final dispatchState = switch (json['dispatchState']) {
      'prepared' => InFlightRequestDispatchState.prepared,
      'dispatchAttempted' => InFlightRequestDispatchState.dispatchAttempted,
      _ => null,
    };
    final requiresOwnerValidation = json['ownerValidationRequired'] == true;
    if (operationId == null ||
        clinicId == null ||
        clinicId.isEmpty ||
        subject == null ||
        createdAt == null ||
        dispatchState == null ||
        ((accountScope == null || accountScope.isEmpty) &&
            !requiresOwnerValidation)) {
      return null;
    }
    return InFlightRequestOperation(
      accountScope: accountScope == null || accountScope.isEmpty
          ? null
          : accountScope,
      operationId: operationId,
      clinicId: clinicId,
      subject: subject,
      dispatchState: dispatchState,
      createdAt: createdAt.toUtc(),
      requiresOwnerValidation: requiresOwnerValidation,
    );
  }

  InFlightRequestOperation? _readLegacyV2(Map<String, dynamic> json) {
    if (RequestKind.parse(json['kind'] as String?) != RequestKind.clinic) {
      return null;
    }
    final operationId = RequestOperationId.tryParse(
      json['requestId'] as String?,
    );
    final clinicId = (json['clinicId'] as String?)?.trim();
    final subject = _readSubject(json);
    if (operationId == null ||
        clinicId == null ||
        clinicId.isEmpty ||
        subject == null) {
      return null;
    }
    return InFlightRequestOperation(
      accountScope: null,
      operationId: operationId,
      clinicId: clinicId,
      subject: subject,
      dispatchState: InFlightRequestDispatchState.dispatchAttempted,
      createdAt: _clock().toUtc(),
      requiresOwnerValidation: true,
    );
  }

  static RequestSubject? _readSubject(Map<String, dynamic> json) {
    final familyMemberId = (json['familyMemberId'] as String?)?.trim();
    return switch (RequestSubjectType.parse(json['subjectType'] as String?)) {
      RequestSubjectType.self =>
        familyMemberId == null || familyMemberId.isEmpty
            ? const RequestSubject.self()
            : null,
      RequestSubjectType.familyMember =>
        familyMemberId == null || familyMemberId.isEmpty
            ? null
            : RequestSubject.familyMember(familyMemberId),
      RequestSubjectType.unknown => null,
    };
  }

  Future<InFlightRequestReadResult> _discard() async {
    await clear();
    return const InFlightRequestReadResult.absent();
  }

  static DateTime _utcNow() => DateTime.now().toUtc();
}
