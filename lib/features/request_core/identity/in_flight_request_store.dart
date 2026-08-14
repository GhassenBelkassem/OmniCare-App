import 'dart:convert';

import '../../../core/storage/secure_token_store.dart';
import '../domain/clinic_request_intent.dart';
import '../domain/pickup_location.dart';
import '../domain/request_subject.dart';
import '../domain/request_vocabulary.dart';
import 'request_operation_id.dart';

/// One submission that was started but whose outcome is not yet known.
///
/// Persisted so the operation identity survives process death mid-submit. If
/// the OS kills the app while a POST is in flight, the next launch can retry
/// with the *same* operation id instead of creating a duplicate request.
class InFlightRequestOperation {
  const InFlightRequestOperation({
    required this.operationId,
    required this.intent,
  });

  final RequestOperationId operationId;
  final ClinicRequestIntent intent;

  /// True when a restored operation still describes what the user is asking
  /// for now. A mismatch means the persisted id belongs to a *different*
  /// logical submission and must not be reused: the server would answer
  /// `REQUEST_IDEMPOTENCY_CONFLICT`.
  bool matches(ClinicRequestIntent current) => intent == current;

  @override
  String toString() => 'InFlightRequestOperation(CLINIC)';
}

/// Versioned secure store for the in-flight submission.
///
/// # What is stored
///
/// Operational retry state only: the operation id, the request kind, the
/// target clinic id, the subject type and — for a family-member subject — the
/// family member id. That is exactly the set needed to decide "may I reuse
/// this operation id?" and nothing more.
///
/// # What is never stored
///
/// No medical text, no symptoms, no diagnosis, no documents, no patient
/// profile, no `patientId`, no `mrsPatientId`, no token. `flutter_secure_storage`
/// is used rather than `SharedPreferences` because even a clinic/family-member
/// pairing is personal data and must not sit in plaintext preferences.
///
/// Modelled on `ClinicSelectionStore`: one JSON record under one key, a schema
/// version, and any unreadable or unexpected record is deleted rather than
/// partially trusted.
class InFlightRequestStore {
  InFlightRequestStore({SecureTokenStorageBackend? backend})
    : _backend = backend ?? const FlutterSecureTokenStorageBackend();

  static const String storageKey = 'omnicare_request_inflight_v1';
  static const int schemaVersion = 2;

  final SecureTokenStorageBackend _backend;

  /// Persists the operation. Storage failures are tolerated and never surfaced:
  /// losing the record costs at most one duplicate-prevention opportunity, and
  /// must not fail the submission the patient is waiting on.
  Future<void> save(InFlightRequestOperation operation) async {
    final subject = operation.intent.subject;
    final intent = operation.intent;
    try {
      await _backend.write(
        key: storageKey,
        value: jsonEncode({
          'schemaVersion': schemaVersion,
          'requestId': operation.operationId.value,
          'kind': intent.kind.wireValue,
          'clinicId': intent.clinicId,
          'subjectType': subject.type.wireValue,
          'familyMemberId': subject.familyMemberId,
          'situation': intent.situation.wireValue,
          if (intent.pickupLocation != null)
            'pickup': intent.pickupLocation!.toJson(),
        }),
      );
    } catch (_) {
      // Best effort by design; see the doc comment above.
    }
  }

  /// Returns the stored operation, or `null` when absent, unreadable, of a
  /// different schema version, or structurally invalid. Invalid records are
  /// deleted so a corrupt value cannot be retried forever.
  Future<InFlightRequestOperation?> read() async {
    String? raw;
    try {
      raw = await _backend.read(key: storageKey);
    } catch (_) {
      return null;
    }
    if (raw == null || raw.trim().isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return _discard();
      final json = decoded.cast<String, dynamic>();

      if (json['schemaVersion'] != schemaVersion) return _discard();

      final operationId = RequestOperationId.tryParse(
        json['requestId'] as String?,
      );
      if (operationId == null) return _discard();

      // Only CLINIC operations exist in this milestone. Anything else is a
      // record this app version cannot act on.
      if (RequestKind.parse(json['kind'] as String?) != RequestKind.clinic) {
        return _discard();
      }

      final clinicId = (json['clinicId'] as String?)?.trim();
      if (clinicId == null || clinicId.isEmpty) return _discard();

      final subject = _readSubject(json);
      if (subject == null) return _discard();

      final situation = RequestSituation.parse(json['situation'] as String?);
      if (situation == RequestSituation.unknown) return _discard();

      final pickup = _readPickup(json);

      // An ambulance operation without a pickup is structurally incomplete.
      if (situation == RequestSituation.ambulance && pickup == null) {
        return _discard();
      }
      // A non-ambulance operation must never carry pickup coordinates.
      if (situation != RequestSituation.ambulance && pickup != null) {
        return _discard();
      }

      return InFlightRequestOperation(
        operationId: operationId,
        intent: ClinicRequestIntent(
          clinicId: clinicId,
          subject: subject,
          situation: situation,
          pickupLocation: pickup,
        ),
      );
    } catch (_) {
      return _discard();
    }
  }

  Future<void> clear() async {
    try {
      await _backend.delete(key: storageKey);
    } catch (_) {
      // Nothing else can be done safely here.
    }
  }

  static RequestSubject? _readSubject(Map<String, dynamic> json) {
    final familyMemberId = (json['familyMemberId'] as String?)?.trim();
    switch (RequestSubjectType.parse(json['subjectType'] as String?)) {
      case RequestSubjectType.self:
        // A SELF record that carries an identifier is inconsistent; refuse it
        // rather than repair it.
        return (familyMemberId == null || familyMemberId.isEmpty)
            ? const RequestSubject.self()
            : null;
      case RequestSubjectType.familyMember:
        if (familyMemberId == null || familyMemberId.isEmpty) return null;
        return RequestSubject.familyMember(familyMemberId);
      case RequestSubjectType.unknown:
        return null;
    }
  }

  static PickupLocationSelection? _readPickup(Map<String, dynamic> json) {
    final raw = json['pickup'];
    if (raw is! Map) return null;
    try {
      return PickupLocationSelection.fromJson(raw.cast<String, dynamic>());
    } on RequestContractException {
      return null;
    }
  }

  Future<InFlightRequestOperation?> _discard() async {
    await clear();
    return null;
  }
}
