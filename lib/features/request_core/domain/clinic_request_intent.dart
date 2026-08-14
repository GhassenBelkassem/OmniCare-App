import 'pickup_location.dart';
import 'request_subject.dart';
import 'request_vocabulary.dart';

/// The complete, non-medical description of what one CLINIC submission asks
/// for: which clinic, for whom, in which operational situation, and — only for
/// an ambulance request — from where the patient must be picked up.
///
/// This is the whole payload semantics of Module 05 V1. There is no free-text
/// field, no symptom, no reason and no attachment — not because the form has
/// not been built yet, but because the backend command has nowhere to put
/// them. Any future medical intake is a separate, separately-secured concern.
///
/// Value equality is the client-side "fingerprint": two intents that compare
/// equal are the same logical submission, so a retry may reuse its operation
/// id. That is deliberately structural rather than a hash — a digest would add
/// a hashing dependency and an opaque value to persist, and would answer
/// exactly the same question this `==` already answers. The server keeps its
/// own authoritative SHA-256 fingerprint; the client never tries to recompute
/// it (it cannot: the server salts it with the authenticated requester).
class ClinicRequestIntent {
  const ClinicRequestIntent({
    required this.clinicId,
    required this.subject,
    required this.situation,
    this.pickupLocation,
  });

  /// Opaque clinic identifier supplied by the patient clinic directory API.
  /// Never hardcoded, never taken from `/me/clinics`.
  final String clinicId;

  final RequestSubject subject;

  /// The patient-selected operational situation. Never inferred.
  final RequestSituation situation;

  /// Required exactly when [situation] is [RequestSituation.ambulance];
  /// otherwise must be `null`. The frozen pickup is reused verbatim on every
  /// retry so a resend never reacquires GPS.
  final PickupLocationSelection? pickupLocation;

  RequestKind get kind => RequestKind.clinic;

  @override
  bool operator ==(Object other) =>
      other is ClinicRequestIntent &&
      other.clinicId == clinicId &&
      other.subject == subject &&
      other.situation == situation &&
      other.pickupLocation == pickupLocation;

  @override
  int get hashCode => Object.hash(clinicId, subject, situation, pickupLocation);

  /// Renders neither the clinic identifier nor the subject identifier.
  @override
  String toString() => 'ClinicRequestIntent(CLINIC)';
}
