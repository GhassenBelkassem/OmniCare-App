import 'package:flutter/foundation.dart';

import '../../../core/utils/uuid_v4.dart';
import 'doctor_urgent_cabinet_request.dart';
import 'doctor_urgent_cabinet_request_source.dart';

enum DoctorUrgentCabinetCommitmentStatus {
  active,
  cancelled,
  invalidated;

  static DoctorUrgentCabinetCommitmentStatus parse(String value) =>
      switch (value) {
        'ACTIVE' => active,
        'CANCELLED' => cancelled,
        'INVALIDATED' => invalidated,
        _ => throw FormatException(
          'Unknown urgent CABINET commitment status: $value.',
        ),
      };
}

@immutable
class DoctorUrgentCabinetCommitment {
  const DoctorUrgentCabinetCommitment({
    required this.commitmentId,
    required this.requestId,
    required this.practiceLocationId,
    required this.status,
    required this.revision,
    required this.quotedFeeMilliTnd,
    required this.currency,
    required this.quoteConfigurationRevision,
    required this.committedAt,
    this.arrivalVerifiedAt,
    required this.updatedAt,
    required this.allowedActions,
    required this.evaluatedAt,
    this.terminalAt,
  });

  final String commitmentId;
  final String requestId;
  final String practiceLocationId;
  final DoctorUrgentCabinetCommitmentStatus status;
  final int revision;
  final int quotedFeeMilliTnd;
  final String currency;
  final int quoteConfigurationRevision;
  final DateTime committedAt;
  final DateTime? arrivalVerifiedAt;
  final DateTime? terminalAt;
  final DateTime updatedAt;
  final List<String> allowedActions;
  final DateTime evaluatedAt;

  bool get isActive => status == DoctorUrgentCabinetCommitmentStatus.active;
  bool get canVerifyArrival =>
      isActive &&
      arrivalVerifiedAt == null &&
      allowedActions.contains('VERIFY_ARRIVAL');

  DoctorUrgentCabinetRequest toRecoveredRequest(
    DoctorUrgentCabinetRequestContext context,
  ) {
    final cabinet = context.cabinet;
    if (!context.hasCommitmentRecoveryContext || cabinet == null) {
      throw const FormatException(
        'A complete Doctor CABINET context is required for recovery.',
      );
    }
    return DoctorUrgentCabinetRequest(
      developmentFixtureKey: null,
      targetDoctorId: context.doctorId,
      targetCabinetIdentity: DoctorUrgentCabinetServerTargetIdentity(
        practiceLocationId,
      ),
      cabinet: cabinet,
      patient: const DoctorUrgentCabinetPatientProjection.masked(),
      fee: DoctorUrgentCabinetFeeSnapshot(
        amountMilliTnd: quotedFeeMilliTnd,
        currencyCode: currency,
        provenance: DoctorUrgentCabinetFeeProvenance.service,
      ),
      dataProvenance: DoctorUrgentCabinetDataProvenance.service,
      status: DoctorUrgentCabinetRequestStatus.committed,
      serverRequestReference: requestId,
      evaluatedAt: evaluatedAt,
      serverCommitmentReference: commitmentId,
    );
  }
}

DoctorUrgentCabinetCommitment parseDoctorUrgentCabinetCommitment(
  Object? value,
) {
  if (value is! Map) {
    throw const FormatException(
      'Expected an urgent CABINET commitment object.',
    );
  }
  final json = value.cast<Object?, Object?>();
  final status = DoctorUrgentCabinetCommitmentStatus.parse(
    _requiredString(json, 'status'),
  );
  final terminalAt = _nullableDateTime(json, 'terminalAt');
  final arrivalVerifiedAt = _nullableDateTime(json, 'arrivalVerifiedAt');
  if ((status == DoctorUrgentCabinetCommitmentStatus.active) !=
      (terminalAt == null)) {
    throw const FormatException('Invalid urgent CABINET terminal shape.');
  }
  final actions = _stringList(json, 'allowedActions');
  if (actions.toSet().length != actions.length ||
      actions.any((action) => action != 'VERIFY_ARRIVAL') ||
      (arrivalVerifiedAt != null && actions.isNotEmpty) ||
      (status != DoctorUrgentCabinetCommitmentStatus.active &&
          actions.isNotEmpty)) {
    throw const FormatException(
      'Unsupported urgent CABINET commitment action.',
    );
  }
  final revision = _nonnegativeInt(json, 'revision');
  final configurationRevision = _nonnegativeInt(
    json,
    'quoteConfigurationRevision',
  );
  final committedAt = _requiredDateTime(json, 'committedAt');
  final updatedAt = _requiredDateTime(json, 'updatedAt');
  if (updatedAt.isBefore(committedAt) ||
      (terminalAt != null && terminalAt.isBefore(committedAt))) {
    throw const FormatException(
      'Invalid urgent CABINET commitment timestamps.',
    );
  }
  return DoctorUrgentCabinetCommitment(
    commitmentId: _requiredUuid(json, 'commitmentId'),
    requestId: _requiredUuid(json, 'requestId'),
    practiceLocationId: _requiredUuid(json, 'practiceLocationId'),
    status: status,
    revision: revision,
    quotedFeeMilliTnd: parseUrgentCabinetFeeMilliTnd(json['quotedFeeTnd']),
    currency: _requiredTnd(json),
    quoteConfigurationRevision: configurationRevision,
    committedAt: committedAt,
    arrivalVerifiedAt: arrivalVerifiedAt,
    terminalAt: terminalAt,
    updatedAt: updatedAt,
    allowedActions: actions,
    evaluatedAt: _requiredDateTime(json, 'evaluatedAt'),
  );
}

List<DoctorUrgentCabinetCommitment> parseDoctorUrgentCabinetCommitmentList(
  Object? value, {
  required int limit,
}) {
  if (value is! List || value.length > limit) {
    throw const FormatException(
      'Expected a bounded urgent CABINET commitment list.',
    );
  }
  final identities = <String>{};
  final requestIds = <String>{};
  final commitments = List<DoctorUrgentCabinetCommitment>.unmodifiable(
    value.map((item) {
      final commitment = parseDoctorUrgentCabinetCommitment(item);
      if (!identities.add(commitment.commitmentId) ||
          !requestIds.add(commitment.requestId)) {
        throw const FormatException(
          'Duplicate urgent CABINET commitment authority.',
        );
      }
      return commitment;
    }),
  );
  if (commitments.where((item) => item.isActive).length > 1) {
    throw const FormatException(
      'Conflicting active urgent CABINET commitments.',
    );
  }
  return commitments;
}

int parseUrgentCabinetFeeMilliTnd(Object? value) {
  final raw = switch (value) {
    String text => text.trim(),
    num number => number.toString(),
    _ => '',
  };
  final match = RegExp(r'^(\d{1,8})(?:\.(\d{1,3}))?$').firstMatch(raw);
  if (match == null) {
    throw const FormatException('Invalid urgent CABINET fee.');
  }
  final whole = int.parse(match.group(1)!);
  final fraction = (match.group(2) ?? '').padRight(3, '0');
  return whole * 1000 + int.parse(fraction.isEmpty ? '0' : fraction);
}

String _requiredUuid(Map<Object?, Object?> json, String field) {
  final value = _requiredString(json, field);
  if (!isCanonicalUuid(value)) {
    throw FormatException('Invalid urgent CABINET $field.');
  }
  return value;
}

String _requiredString(Map<Object?, Object?> json, String field) {
  final value = json[field];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Missing urgent CABINET $field.');
  }
  return value.trim();
}

String _requiredTnd(Map<Object?, Object?> json) {
  if (json['currency'] != 'TND') {
    throw const FormatException('Invalid urgent CABINET currency.');
  }
  return 'TND';
}

int _nonnegativeInt(Map<Object?, Object?> json, String field) {
  final value = json[field];
  if (value is! int || value < 0) {
    throw FormatException('Invalid urgent CABINET $field.');
  }
  return value;
}

DateTime _requiredDateTime(Map<Object?, Object?> json, String field) {
  final value = _requiredString(json, field);
  final parsed = DateTime.tryParse(value);
  if (parsed == null || !parsed.isUtc) {
    throw FormatException('Invalid urgent CABINET $field.');
  }
  return parsed;
}

DateTime? _nullableDateTime(Map<Object?, Object?> json, String field) {
  if (json[field] == null) return null;
  return _requiredDateTime(json, field);
}

List<String> _stringList(Map<Object?, Object?> json, String field) {
  final value = json[field];
  if (value is! List || value.any((item) => item is! String)) {
    throw FormatException('Invalid urgent CABINET $field.');
  }
  return List.unmodifiable(value.cast<String>());
}
