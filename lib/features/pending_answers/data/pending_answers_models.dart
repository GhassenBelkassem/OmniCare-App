/// G-1 D2 / D4 (patient side): what the patient has to answer.
///
/// Holds ids, names, cabinet and dates only: these responses carry no medical
/// content, and nothing here is written to disk or to logs.
library;

/// Raised when a response does not match the contract. Carries no server text.
class PendingAnswersContractException implements Exception {
  const PendingAnswersContractException(this.field);

  final String field;

  @override
  String toString() => 'PendingAnswersContractException($field)';
}

/// « Pour vous » or the family member's name.
class PendingAnswerSubject {
  const PendingAnswerSubject({
    required this.isSelf,
    required this.displayName,
    this.familyMemberId,
  });

  final bool isSelf;
  final String displayName;
  final String? familyMemberId;

  String get label => isSelf ? 'Pour vous' : 'Pour $displayName';

  factory PendingAnswerSubject.fromJson(Map<String, dynamic> json) {
    final type = json['subjectType'];
    return PendingAnswerSubject(
      isSelf: type != 'FAMILY_MEMBER',
      displayName: _optionalString(json['displayName']) ?? 'votre proche',
      familyMemberId: _optionalString(json['familyMemberId']),
    );
  }
}

class PendingAnswerDoctor {
  const PendingAnswerDoctor({required this.displayName, this.specialty});

  final String displayName;
  final String? specialty;

  /// « Dr Ahmed Ben Salah » (the server sends the name without the title).
  String get name {
    final trimmed = displayName.trim();
    if (trimmed.isEmpty) return 'Votre médecin';
    final lower = trimmed.toLowerCase();
    if (lower.startsWith('dr ') || lower.startsWith('dr.')) return trimmed;
    return 'Dr $trimmed';
  }

  /// « Dr Ahmed Ben Salah · Cardiologie »
  String get nameAndSpecialty {
    final value = specialty?.trim();
    return value == null || value.isEmpty ? name : '$name · $value';
  }

  factory PendingAnswerDoctor.fromJson(Map<String, dynamic>? json) =>
      PendingAnswerDoctor(
        displayName: _optionalString(json?['displayName']) ?? '',
        specialty: _optionalString(json?['specialty']),
      );
}

/// GET /api/v1/me/access-requests item.
class PatientAccessRequest {
  const PatientAccessRequest({
    required this.requestId,
    required this.version,
    required this.status,
    required this.consultationId,
    required this.createdAt,
    required this.subject,
    required this.doctor,
  });

  final String requestId;
  final int version;

  /// PENDING, ACCEPTED, REFUSED, CANCELLED or ENDED.
  final String status;
  final String consultationId;
  final DateTime createdAt;
  final PendingAnswerSubject subject;
  final PendingAnswerDoctor doctor;

  bool get isPending => status == 'PENDING';

  factory PatientAccessRequest.fromJson(Map<String, dynamic> json) =>
      PatientAccessRequest(
        requestId: _requiredString(json, 'requestId'),
        version: _requiredInt(json, 'version'),
        status: _requiredString(json, 'status'),
        consultationId: _optionalString(json['consultationId']) ?? '',
        createdAt: _requiredInstant(json, 'createdAt'),
        subject: PendingAnswerSubject.fromJson(_object(json['subject'])),
        doctor: PendingAnswerDoctor.fromJson(_objectOrNull(json['doctor'])),
      );
}

class FollowUpCabinet {
  const FollowUpCabinet({required this.name, this.address, this.city});

  final String name;
  final String? address;
  final String? city;

  /// « 12 rue X, Tunis » (empty parts dropped).
  String get addressLine => [address, city]
      .whereType<String>()
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .join(', ');

  factory FollowUpCabinet.fromJson(Map<String, dynamic>? json) =>
      FollowUpCabinet(
        name: _optionalString(json?['name']) ?? 'Cabinet',
        address: _optionalString(json?['address']),
        city: _optionalString(json?['city']),
      );
}

/// GET /api/v1/me/follow-up-proposals item.
class FollowUpProposal {
  const FollowUpProposal({
    required this.appointmentId,
    required this.version,
    required this.status,
    required this.start,
    required this.proposalExpiresAt,
    required this.cabinet,
    required this.subject,
    required this.doctor,
  });

  final String appointmentId;
  final int version;

  /// PROPOSED while it waits; CONFIRMED or CANCELLED once answered.
  final String status;
  final DateTime start;
  final DateTime? proposalExpiresAt;
  final FollowUpCabinet cabinet;
  final PendingAnswerSubject subject;
  final PendingAnswerDoctor doctor;

  bool get isPending => status == 'PROPOSED';

  factory FollowUpProposal.fromJson(Map<String, dynamic> json) =>
      FollowUpProposal(
        appointmentId: _requiredString(json, 'appointmentId'),
        version: _requiredInt(json, 'version'),
        status: _requiredString(json, 'status'),
        start: _requiredInstant(json, 'start'),
        proposalExpiresAt: _optionalInstant(json['proposalExpiresAt']),
        cabinet: FollowUpCabinet.fromJson(_objectOrNull(json['cabinet'])),
        subject: PendingAnswerSubject.fromJson(_object(json['subject'])),
        doctor: PendingAnswerDoctor.fromJson(_objectOrNull(json['doctor'])),
      );
}

List<T> parseItems<T>(
  Object? body,
  T Function(Map<String, dynamic> json) parse,
) {
  final items = body is Map ? body['items'] : null;
  if (items is! List) throw const PendingAnswersContractException('items');
  return [for (final item in items) parse(_object(item))];
}

Map<String, dynamic> parseObject(Object? body) => _object(body);

String _requiredString(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is String && value.trim().isNotEmpty) return value.trim();
  throw PendingAnswersContractException(field);
}

int _requiredInt(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is int) return value;
  if (value is num && value == value.roundToDouble()) return value.toInt();
  throw PendingAnswersContractException(field);
}

DateTime _requiredInstant(Map<String, dynamic> json, String field) {
  final value = _optionalInstant(json[field]);
  if (value == null) throw PendingAnswersContractException(field);
  return value;
}

DateTime? _optionalInstant(Object? value) {
  if (value is! String || value.trim().isEmpty) return null;
  return DateTime.tryParse(value.trim())?.toUtc();
}

String? _optionalString(Object? value) {
  if (value is! String) return null;
  final trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

Map<String, dynamic> _object(Object? value) {
  if (value is Map) return value.cast<String, dynamic>();
  throw const PendingAnswersContractException('object');
}

Map<String, dynamic>? _objectOrNull(Object? value) =>
    value is Map ? value.cast<String, dynamic>() : null;
