import '../../../core/utils/uuid_v4.dart';
import '../domain/request_vocabulary.dart';

/// The durable identity of **one logical submission**.
///
/// The backend anchors idempotency on this value: it is what makes a retry a
/// retry instead of a second request. The lifecycle rules are therefore not a
/// detail of the controller, they are part of the protocol:
///
/// | Event | Operation id |
/// |---|---|
/// | a new logical request is started | **new** |
/// | HTTP timeout | **same** |
/// | connection failure | **same** |
/// | 401 → refresh → retry | **same** (Dio replays the original body) |
/// | 200 replay / 201 created | **same**, then the operation is finished |
/// | 409 `REQUEST_IDEMPOTENCY_CONFLICT` | **same**, and it is burned: the app never silently rotates it |
///
/// Silently generating a fresh id after a conflict would convert "your retry
/// asked for something different" into "here is a second request the patient
/// never made", which is the one failure mode idempotency exists to prevent.
class RequestOperationId {
  const RequestOperationId._(this.value);

  final String value;

  /// Accepts only a canonical lowercase UUID, so a corrupted persisted record
  /// can never be interpolated into a request body or a URL path.
  static RequestOperationId? tryParse(String? value) {
    final candidate = value?.trim().toLowerCase();
    if (candidate == null || candidate.isEmpty) return null;
    if (!isCanonicalUuid(candidate)) return null;
    return RequestOperationId._(candidate);
  }

  static RequestOperationId parse(String? value) {
    final parsed = tryParse(value);
    if (parsed == null) {
      throw const RequestContractException('Invalid request identifier.');
    }
    return parsed;
  }

  @override
  bool operator ==(Object other) =>
      other is RequestOperationId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  /// Does not render the identifier: an operation id in a log line is a
  /// correlation handle to a patient's request.
  @override
  String toString() => 'RequestOperationId(<redacted>)';
}

/// Creates operation identifiers.
///
/// An abstraction rather than a bare function so a test can make a submission
/// sequence deterministic without reaching into the controller.
abstract class RequestOperationIdFactory {
  const RequestOperationIdFactory();

  RequestOperationId next();
}

/// Production factory: UUID v4 over `Random.secure()`.
class SecureRequestOperationIdFactory extends RequestOperationIdFactory {
  const SecureRequestOperationIdFactory();

  @override
  RequestOperationId next() => RequestOperationId.parse(generateUuidV4());
}
