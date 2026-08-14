/// Clinic directory models for the patient-facing Clinic request.

library;

import '../domain/request_vocabulary.dart';

/// One clinic a patient may currently target, as the backend exposes it.

///
/// The contract is deliberately minimal: an opaque [clinicId] and a
/// [displayName]. There is no status, no contact detail, no capability and no
/// configuration here — Module 05 needs only the identifier it stores in
/// `appointment_requests.target_id`, and the human-readable name to render.
///
/// Parsing is strict in the Clinic tradition: a missing [clinicId] or
/// [displayName] is a contract violation, not a value to guess at.
class ClinicTarget {
  const ClinicTarget({required this.clinicId, required this.displayName});

  final String clinicId;
  final String displayName;

  factory ClinicTarget.fromJson(Map<String, dynamic> json) {
    return ClinicTarget(
      clinicId: _requiredString(json, 'clinicId'),
      displayName: _requiredString(json, 'displayName'),
    );
  }

  /// Renders neither the clinic identifier nor the name.
  @override
  String toString() => 'ClinicTarget(<redacted>)';
}

/// The response of `GET /appointment-requests/clinic-targets`.
///
/// Mirrors the backend's `Map.of("items", ..., "hasNext", false)`. There is no
/// `contractVersion`, no `page` and no `pageSize`: this directory is a single,
/// bounded snapshot, and [hasNext] is the only paging fact it reports.
class ClinicTargetDirectory {
  const ClinicTargetDirectory({required this.clinics, required this.hasNext});

  final List<ClinicTarget> clinics;
  final bool hasNext;

  factory ClinicTargetDirectory.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    if (rawItems != null && rawItems is! List) {
      throw const RequestContractException('Clinic directory is malformed.');
    }
    final clinics = <ClinicTarget>[];
    for (final item in (rawItems as List? ?? const [])) {
      if (item is! Map) {
        throw const RequestContractException('Clinic entry is malformed.');
      }
      clinics.add(ClinicTarget.fromJson(item.cast<String, dynamic>()));
    }
    return ClinicTargetDirectory(
      clinics: List.unmodifiable(clinics),
      hasNext: json['hasNext'] == true,
    );
  }

  @override
  String toString() => 'ClinicTargetDirectory(${clinics.length} clinics)';
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) return value.trim();
  throw RequestContractException('Missing required field "$key".');
}
