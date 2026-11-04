import 'package:flutter/foundation.dart';

enum DoctorHomeCommitmentStatus {
  active,
  cancelled,
  invalidated;

  static DoctorHomeCommitmentStatus parse(String value) => switch (value) {
    'ACTIVE' => DoctorHomeCommitmentStatus.active,
    'CANCELLED' => DoctorHomeCommitmentStatus.cancelled,
    'INVALIDATED' => DoctorHomeCommitmentStatus.invalidated,
    _ => throw const FormatException('Unknown HOME commitment status.'),
  };

  String get frenchLabel => switch (this) {
    active => 'Engagement confirmé',
    cancelled => 'Engagement annulé',
    invalidated => 'Engagement invalidé',
  };
}

enum DoctorHomeActiveCommitmentResult {
  activeCommitment,
  noActiveCommitment;

  static DoctorHomeActiveCommitmentResult parse(
    String value,
  ) => switch (value) {
    'ACTIVE_COMMITMENT' => DoctorHomeActiveCommitmentResult.activeCommitment,
    'NO_ACTIVE_COMMITMENT' =>
      DoctorHomeActiveCommitmentResult.noActiveCommitment,
    _ => throw const FormatException('Unknown active HOME commitment result.'),
  };
}

@immutable
class DoctorHomeCommitment {
  const DoctorHomeCommitment({
    required this.commitmentId,
    required this.journeyId,
    required this.selectedOfferId,
    required this.status,
    required this.revision,
    required this.quotedHomeFeeTnd,
    required this.currency,
    required this.committedAt,
    required this.updatedAt,
    required this.evaluatedAt,
    required this.availableActions,
    this.terminalAt,
  });

  final String commitmentId;
  final String journeyId;
  final String selectedOfferId;
  final DoctorHomeCommitmentStatus status;
  final int revision;
  final String quotedHomeFeeTnd;
  final String currency;
  final DateTime committedAt;
  final DateTime? terminalAt;
  final DateTime updatedAt;
  final List<String> availableActions;
  final DateTime evaluatedAt;

  bool get isActive => status == DoctorHomeCommitmentStatus.active;

  bool get isTerminal => !isActive;

  String get shortIdentity {
    final compact = commitmentId.replaceAll('-', '');
    return compact.length <= 8
        ? compact.toUpperCase()
        : compact.substring(compact.length - 8).toUpperCase();
  }
}

@immutable
class DoctorHomeActiveCommitment {
  const DoctorHomeActiveCommitment({
    required this.result,
    required this.evaluatedAt,
    this.commitment,
  });

  final DoctorHomeActiveCommitmentResult result;
  final DoctorHomeCommitment? commitment;
  final DateTime evaluatedAt;
}

DoctorHomeCommitment parseDoctorHomeCommitment(Object? value) {
  if (value is! Map) {
    throw const FormatException('Expected a HOME commitment object.');
  }
  final json = value.cast<Object?, Object?>();
  final commitmentId = _requiredUuid(json, 'commitmentId');
  final journeyId = _requiredUuid(json, 'journeyId');
  final selectedOfferId = _requiredUuid(json, 'selectedOfferId');
  final status = DoctorHomeCommitmentStatus.parse(
    _requiredString(json, 'status'),
  );
  final revision = json['revision'];
  if (revision is! int || revision < 0) {
    throw const FormatException('Invalid HOME commitment revision.');
  }
  final fee = _fee(json['quotedHomeFeeTnd']);
  if (json['currency'] != 'TND') {
    throw const FormatException('Invalid HOME commitment currency.');
  }
  final terminalAt = _nullableDateTime(json, 'terminalAt');
  if ((status == DoctorHomeCommitmentStatus.active) != (terminalAt == null)) {
    throw const FormatException('Invalid HOME commitment terminal shape.');
  }
  final rawActions = json['availableActions'];
  if (rawActions is! List || rawActions.any((action) => action is! String)) {
    throw const FormatException('Invalid HOME commitment actions.');
  }
  final actions = List<String>.unmodifiable(rawActions.cast<String>());
  if (actions.isNotEmpty) {
    throw const FormatException('Unsupported HOME commitment action.');
  }

  return DoctorHomeCommitment(
    commitmentId: commitmentId,
    journeyId: journeyId,
    selectedOfferId: selectedOfferId,
    status: status,
    revision: revision,
    quotedHomeFeeTnd: fee,
    currency: 'TND',
    committedAt: _requiredDateTime(json, 'committedAt'),
    terminalAt: terminalAt,
    updatedAt: _requiredDateTime(json, 'updatedAt'),
    availableActions: actions,
    evaluatedAt: _requiredDateTime(json, 'evaluatedAt'),
  );
}

DoctorHomeActiveCommitment parseDoctorHomeActiveCommitment(Object? value) {
  if (value is! Map) {
    throw const FormatException('Expected an active HOME commitment response.');
  }
  final json = value.cast<Object?, Object?>();
  final result = DoctorHomeActiveCommitmentResult.parse(
    _requiredString(json, 'result'),
  );
  final commitment = json['commitment'] == null
      ? null
      : parseDoctorHomeCommitment(json['commitment']);
  if (result == DoctorHomeActiveCommitmentResult.activeCommitment &&
      (commitment == null || !commitment.isActive)) {
    throw const FormatException('Invalid active HOME commitment shape.');
  }
  if (result == DoctorHomeActiveCommitmentResult.noActiveCommitment &&
      commitment != null) {
    throw const FormatException('Invalid empty HOME commitment shape.');
  }
  return DoctorHomeActiveCommitment(
    result: result,
    commitment: commitment,
    evaluatedAt: _requiredDateTime(json, 'evaluatedAt'),
  );
}

String _requiredUuid(Map<Object?, Object?> json, String field) {
  final value = _requiredString(json, field);
  if (!_uuidPattern.hasMatch(value)) {
    throw FormatException('Invalid $field.');
  }
  return value;
}

String _requiredString(Map<Object?, Object?> json, String field) {
  final value = json[field];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Missing $field.');
  }
  return value;
}

DateTime _requiredDateTime(Map<Object?, Object?> json, String field) {
  final value = _requiredString(json, field);
  return DateTime.tryParse(value)?.toUtc() ??
      (throw FormatException('Invalid $field.'));
}

DateTime? _nullableDateTime(Map<Object?, Object?> json, String field) {
  if (json[field] == null) return null;
  return _requiredDateTime(json, field);
}

String _fee(Object? value) {
  if (value is! num || !value.isFinite || value < 0) {
    throw const FormatException('Invalid HOME commitment fee.');
  }
  final scaled = value * 1000;
  if ((scaled - scaled.round()).abs() > 0.000001 || value > 99999999.999) {
    throw const FormatException('Invalid HOME commitment fee scale.');
  }
  return value.toStringAsFixed(3);
}

final RegExp _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
);
