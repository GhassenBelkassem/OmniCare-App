import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/utils/uuid_v4.dart';
import 'urgent_cabinet_anatomical_mapping.dart';
import 'urgent_cabinet_care_subject.dart';
import 'urgent_cabinet_clinical_intake_draft.dart';
import 'urgent_cabinet_request_review.dart';

enum UrgentCabinetSubmissionIssue {
  invalidSubject,
  invalidDoctorId,
  invalidPracticeLocationId,
  targetMismatch,
  invalidClinicalIntake,
  unknownAnatomicalIdentifier,
  unresolvedAnatomicalIdentifier,
  invalidQuote,
  incompleteQuoteAuthority,
  developmentFixture,
}

@immutable
class UrgentCabinetTargetedSubmissionValidation {
  const UrgentCabinetTargetedSubmissionValidation.valid(this.submission)
    : issue = null,
      identifiers = const [];

  const UrgentCabinetTargetedSubmissionValidation.invalid(
    this.issue, {
    this.identifiers = const [],
  }) : submission = null;

  final UrgentCabinetTargetedSubmission? submission;
  final UrgentCabinetSubmissionIssue? issue;
  final List<String> identifiers;

  bool get isValid => submission != null && issue == null;
}

/// Exact immutable body accepted by POST /me/urgent-cabinet/requests.
@immutable
class UrgentCabinetTargetedSubmission {
  const UrgentCabinetTargetedSubmission._({
    required this.careSubject,
    required this.doctorId,
    required this.practiceLocationId,
    required this.bodyAreaCodes,
    required this.painScore,
    required this.shortDescription,
    required this.amountMilliTnd,
    required this.configurationRevision,
    required this.runtimeRevision,
    required this.practiceLocationVersion,
  });

  final UrgentCabinetCareSubject careSubject;
  final String doctorId;
  final String practiceLocationId;
  final List<UrgentCabinetBodyAreaCode> bodyAreaCodes;
  final int painScore;
  final String shortDescription;
  final int amountMilliTnd;
  final int configurationRevision;
  final int runtimeRevision;
  final int practiceLocationVersion;

  Map<String, Object?> toJson() => <String, Object?>{
    'subjectType': careSubject.isSelf ? 'SELF' : 'FAMILY_MEMBER',
    if (!careSubject.isSelf) 'familyMemberId': careSubject.familyMemberId,
    'doctorId': doctorId,
    'practiceLocationId': practiceLocationId,
    'intent': 'URGENT_CABINET_TARGETED',
    'bodyAreaCodes': bodyAreaCodes
        .map((code) => code.wireValue)
        .toList(growable: false),
    'painScore': painScore,
    'shortDescription': shortDescription,
    'acknowledgedQuote': <String, Object>{
      'amountTnd': amountMilliTnd / 1000,
      'currency': 'TND',
      'configurationRevision': configurationRevision,
      'runtimeRevision': runtimeRevision,
      'practiceLocationVersion': practiceLocationVersion,
    },
  };

  /// Stable only for comparing immutable logical requests inside one client.
  String get logicalFingerprint => jsonEncode(toJson());
}

UrgentCabinetTargetedSubmissionValidation
prepareUrgentCabinetTargetedSubmission({
  required UrgentCabinetClinicalIntakeDraft clinicalIntake,
  required UrgentCabinetFeeQuote quote,
}) {
  final subject = clinicalIntake.careSubject;
  final familyMemberId = subject.familyMemberId;
  final normalizedFamilyMemberId = familyMemberId?.toLowerCase();
  if ((subject.isSelf && familyMemberId != null) ||
      (!subject.isSelf &&
          (normalizedFamilyMemberId == null ||
              !isCanonicalUuid(normalizedFamilyMemberId)))) {
    return const UrgentCabinetTargetedSubmissionValidation.invalid(
      UrgentCabinetSubmissionIssue.invalidSubject,
    );
  }
  final doctorId = clinicalIntake.doctorId.toLowerCase();
  final cabinetId = clinicalIntake.cabinetId.toLowerCase();
  if (!isCanonicalUuid(doctorId)) {
    return const UrgentCabinetTargetedSubmissionValidation.invalid(
      UrgentCabinetSubmissionIssue.invalidDoctorId,
    );
  }
  if (!isCanonicalUuid(cabinetId)) {
    return const UrgentCabinetTargetedSubmissionValidation.invalid(
      UrgentCabinetSubmissionIssue.invalidPracticeLocationId,
    );
  }
  if (quote.doctorId.toLowerCase() != doctorId ||
      quote.cabinetId.toLowerCase() != cabinetId) {
    return const UrgentCabinetTargetedSubmissionValidation.invalid(
      UrgentCabinetSubmissionIssue.targetMismatch,
    );
  }
  if (!clinicalIntake.isValid) {
    return const UrgentCabinetTargetedSubmissionValidation.invalid(
      UrgentCabinetSubmissionIssue.invalidClinicalIntake,
    );
  }
  final mapped = mapUrgentCabinetAnatomy(clinicalIntake.rawAnatomicalRegionIds);
  if (mapped.unknownIdentifiers.isNotEmpty) {
    return UrgentCabinetTargetedSubmissionValidation.invalid(
      UrgentCabinetSubmissionIssue.unknownAnatomicalIdentifier,
      identifiers: mapped.unknownIdentifiers,
    );
  }
  if (mapped.unresolvedIdentifiers.isNotEmpty) {
    return UrgentCabinetTargetedSubmissionValidation.invalid(
      UrgentCabinetSubmissionIssue.unresolvedAnatomicalIdentifier,
      identifiers: mapped.unresolvedIdentifiers,
    );
  }
  if (!mapped.isComplete) {
    return const UrgentCabinetTargetedSubmissionValidation.invalid(
      UrgentCabinetSubmissionIssue.invalidClinicalIntake,
    );
  }
  if (quote.provenance != UrgentCabinetFeeProvenance.service) {
    return const UrgentCabinetTargetedSubmissionValidation.invalid(
      UrgentCabinetSubmissionIssue.developmentFixture,
    );
  }
  if (!quote.isStructurallyValid()) {
    return const UrgentCabinetTargetedSubmissionValidation.invalid(
      UrgentCabinetSubmissionIssue.invalidQuote,
    );
  }
  if (!quote.hasCompleteAuthority) {
    return const UrgentCabinetTargetedSubmissionValidation.invalid(
      UrgentCabinetSubmissionIssue.incompleteQuoteAuthority,
    );
  }

  return UrgentCabinetTargetedSubmissionValidation.valid(
    UrgentCabinetTargetedSubmission._(
      careSubject: subject.isSelf
          ? subject
          : UrgentCabinetCareSubject.familyMember(normalizedFamilyMemberId!),
      doctorId: doctorId,
      practiceLocationId: cabinetId,
      bodyAreaCodes: mapped.bodyAreaCodes,
      painScore: clinicalIntake.painScore,
      shortDescription: clinicalIntake.shortDescription,
      amountMilliTnd: quote.amountMilliTnd,
      configurationRevision: quote.configurationRevision!,
      runtimeRevision: quote.runtimeRevision!,
      practiceLocationVersion: quote.practiceLocationVersion!,
    ),
  );
}

enum UrgentCabinetPatientResponseStatus {
  pending('PENDING'),
  accepted('ACCEPTED'),
  declined('DECLINED'),
  cancelled('CANCELLED'),
  expired('EXPIRED');

  const UrgentCabinetPatientResponseStatus(this.wireValue);
  final String wireValue;

  static UrgentCabinetPatientResponseStatus parse(String value) =>
      values.firstWhere(
        (status) => status.wireValue == value,
        orElse: () => throw FormatException(
          'Unsupported urgent CABINET response status: $value.',
        ),
      );
}

enum UrgentCabinetPatientAttemptState {
  cabinetPending('CABINET_PENDING'),
  cabinetCommitted('CABINET_COMMITTED'),
  cabinetCancelled('CABINET_CANCELLED');

  const UrgentCabinetPatientAttemptState(this.wireValue);
  final String wireValue;

  static UrgentCabinetPatientAttemptState parse(String value) =>
      values.firstWhere(
        (state) => state.wireValue == value,
        orElse: () => throw FormatException(
          'Unsupported urgent CABINET attempt state: $value.',
        ),
      );
}

enum UrgentCabinetPatientCommitmentStatus {
  active('ACTIVE'),
  cancelled('CANCELLED'),
  invalidated('INVALIDATED');

  const UrgentCabinetPatientCommitmentStatus(this.wireValue);
  final String wireValue;

  static UrgentCabinetPatientCommitmentStatus parse(String value) =>
      values.firstWhere(
        (status) => status.wireValue == value,
        orElse: () => throw FormatException(
          'Unsupported urgent CABINET commitment status: $value.',
        ),
      );
}

enum UrgentCabinetPatientTerminalReason {
  doctorDeclined('DOCTOR_DECLINED'),
  patientCancelled('PATIENT_CANCELLED'),
  patientWithdrewAfterAcceptance('PATIENT_WITHDREW_AFTER_ACCEPTANCE'),
  responseDeadlineElapsed('RESPONSE_DEADLINE_ELAPSED');

  const UrgentCabinetPatientTerminalReason(this.wireValue);
  final String wireValue;

  static UrgentCabinetPatientTerminalReason parse(String value) =>
      values.firstWhere(
        (reason) => reason.wireValue == value,
        orElse: () => throw FormatException(
          'Unsupported urgent CABINET terminal reason: $value.',
        ),
      );
}

@immutable
class UrgentCabinetTargetedRequestSnapshot {
  const UrgentCabinetTargetedRequestSnapshot._({
    required this.requestId,
    required this.journeyId,
    required this.careSubject,
    required this.doctorId,
    required this.practiceLocationId,
    required this.doctorDisplayName,
    required this.specialty,
    required this.cabinetName,
    required this.cabinetAddress,
    required this.governorate,
    required this.city,
    required this.cabinetLatitude,
    required this.cabinetLongitude,
    required this.quotedFeeMilliTnd,
    required this.configurationRevision,
    required this.runtimeRevision,
    required this.practiceLocationVersion,
    required this.responseStatus,
    required this.responseRevision,
    required this.respondedAt,
    required this.commitmentId,
    required this.commitmentStatus,
    required this.commitmentRevision,
    required this.committedAt,
    required this.arrivalVerifiedAt,
    required this.attemptState,
    required this.requestRevision,
    required this.journeyRevision,
    required this.createdAt,
    required this.responseDeadlineAt,
    required this.terminalAt,
    required this.terminalReason,
    required this.allowedActions,
    required this.replayed,
    required this.evaluatedAt,
  });

  final String requestId;
  final String journeyId;
  final UrgentCabinetCareSubject careSubject;
  final String doctorId;
  final String practiceLocationId;
  final String doctorDisplayName;
  final String specialty;
  final String cabinetName;
  final String cabinetAddress;
  final String governorate;
  final String city;
  final double? cabinetLatitude;
  final double? cabinetLongitude;
  final int quotedFeeMilliTnd;
  final int configurationRevision;
  final int runtimeRevision;
  final int practiceLocationVersion;
  final UrgentCabinetPatientResponseStatus responseStatus;
  final int responseRevision;
  final DateTime? respondedAt;
  final String? commitmentId;
  final UrgentCabinetPatientCommitmentStatus? commitmentStatus;
  final int? commitmentRevision;
  final DateTime? committedAt;
  final DateTime? arrivalVerifiedAt;
  final UrgentCabinetPatientAttemptState attemptState;
  final int requestRevision;
  final int journeyRevision;
  final DateTime createdAt;
  final DateTime responseDeadlineAt;
  final DateTime? terminalAt;
  final UrgentCabinetPatientTerminalReason? terminalReason;
  final List<String> allowedActions;
  final bool replayed;
  final DateTime evaluatedAt;

  bool get isTerminal =>
      responseStatus == UrgentCabinetPatientResponseStatus.declined ||
      responseStatus == UrgentCabinetPatientResponseStatus.cancelled ||
      responseStatus == UrgentCabinetPatientResponseStatus.expired;

  factory UrgentCabinetTargetedRequestSnapshot.fromJson(
    Map<String, dynamic> json,
  ) {
    final subjectType = _requiredString(json, 'subjectType');
    final familyMemberId = _nullableUuid(json, 'familyMemberId');
    final UrgentCabinetCareSubject subject;
    if (subjectType == 'SELF' && familyMemberId == null) {
      subject = const UrgentCabinetCareSubject.self();
    } else if (subjectType == 'FAMILY_MEMBER' && familyMemberId != null) {
      subject = UrgentCabinetCareSubject.familyMember(familyMemberId);
    } else {
      throw const FormatException('Invalid urgent CABINET care subject.');
    }

    final responseStatus = UrgentCabinetPatientResponseStatus.parse(
      _requiredString(json, 'responseStatus'),
    );
    final attemptState = UrgentCabinetPatientAttemptState.parse(
      _requiredString(json, 'state'),
    );
    final respondedAt = _nullableInstant(json, 'respondedAt');
    final commitmentId = _nullableUuid(json, 'commitmentId');
    final commitmentStatus = _nullableEnum(
      json,
      'commitmentStatus',
      UrgentCabinetPatientCommitmentStatus.parse,
    );
    final commitmentRevision = _nullableNonnegativeInt(
      json,
      'commitmentRevision',
    );
    final committedAt = _nullableInstant(json, 'committedAt');
    final arrivalVerifiedAt = _nullableInstant(json, 'arrivalVerifiedAt');
    final terminalAt = _nullableInstant(json, 'terminalAt');
    final terminalReason = _nullableEnum(
      json,
      'terminalReason',
      UrgentCabinetPatientTerminalReason.parse,
    );
    final actions = _requiredStringList(json, 'allowedActions');
    final createdAt = _requiredInstant(json, 'createdAt');
    final deadline = _requiredInstant(json, 'responseDeadlineAt');
    final evaluatedAt = _requiredInstant(json, 'evaluatedAt');
    final cabinetLatitude = _nullableCoordinate(
      json,
      'cabinetLatitude',
      min: -90,
      max: 90,
    );
    final cabinetLongitude = _nullableCoordinate(
      json,
      'cabinetLongitude',
      min: -180,
      max: 180,
    );
    if ((cabinetLatitude == null) != (cabinetLongitude == null)) {
      throw const FormatException(
        'Urgent CABINET coordinates must be supplied as a pair.',
      );
    }
    if (!deadline.isAfter(createdAt) || evaluatedAt.isBefore(createdAt)) {
      throw const FormatException('Invalid urgent CABINET timestamps.');
    }

    _validateStateCombination(
      responseStatus: responseStatus,
      attemptState: attemptState,
      respondedAt: respondedAt,
      commitmentId: commitmentId,
      commitmentStatus: commitmentStatus,
      commitmentRevision: commitmentRevision,
      committedAt: committedAt,
      arrivalVerifiedAt: arrivalVerifiedAt,
      terminalAt: terminalAt,
      terminalReason: terminalReason,
      allowedActions: actions,
      deadline: deadline,
      evaluatedAt: evaluatedAt,
    );

    final currency = _requiredString(json, 'currency');
    final fee = _parseMilliTnd(json['quotedFeeTnd']);
    if (currency != 'TND' || fee < 0) {
      throw const FormatException('Invalid urgent CABINET fee.');
    }

    return UrgentCabinetTargetedRequestSnapshot._(
      requestId: _requiredUuid(json, 'requestId'),
      journeyId: _requiredUuid(json, 'journeyId'),
      careSubject: subject,
      doctorId: _requiredUuid(json, 'doctorId'),
      practiceLocationId: _requiredUuid(json, 'practiceLocationId'),
      doctorDisplayName: _requiredString(json, 'doctorDisplayName'),
      specialty: _requiredString(json, 'specialty'),
      cabinetName: _requiredString(json, 'cabinetName'),
      cabinetAddress: _requiredString(json, 'cabinetAddress'),
      governorate: _requiredString(json, 'governorate'),
      city: _requiredString(json, 'city'),
      cabinetLatitude: cabinetLatitude,
      cabinetLongitude: cabinetLongitude,
      quotedFeeMilliTnd: fee,
      configurationRevision: _requiredNonnegativeInt(
        json,
        'configurationRevision',
      ),
      runtimeRevision: _requiredNonnegativeInt(json, 'runtimeRevision'),
      practiceLocationVersion: _requiredNonnegativeInt(
        json,
        'practiceLocationVersion',
      ),
      responseStatus: responseStatus,
      responseRevision: _requiredNonnegativeInt(json, 'responseRevision'),
      respondedAt: respondedAt,
      commitmentId: commitmentId,
      commitmentStatus: commitmentStatus,
      commitmentRevision: commitmentRevision,
      committedAt: committedAt,
      arrivalVerifiedAt: arrivalVerifiedAt,
      attemptState: attemptState,
      requestRevision: _requiredNonnegativeInt(json, 'requestRevision'),
      journeyRevision: _requiredNonnegativeInt(json, 'journeyRevision'),
      createdAt: createdAt,
      responseDeadlineAt: deadline,
      terminalAt: terminalAt,
      terminalReason: terminalReason,
      allowedActions: List.unmodifiable(actions),
      replayed: _requiredBool(json, 'replayed'),
      evaluatedAt: evaluatedAt,
    );
  }
}

@immutable
class UrgentCabinetPatientCancellation {
  const UrgentCabinetPatientCancellation({
    required this.expectedResponseRevision,
    required this.expectedRequestRevision,
    required this.expectedJourneyRevision,
  });

  final int expectedResponseRevision;
  final int expectedRequestRevision;
  final int expectedJourneyRevision;

  Map<String, Object> toJson() => {
    'expectedResponseRevision': expectedResponseRevision,
    // Backend calls the attempt revision expectedAttemptRevision while its
    // read DTO exposes the same authority as requestRevision.
    'expectedAttemptRevision': expectedRequestRevision,
    'expectedJourneyRevision': expectedJourneyRevision,
  };
}

@immutable
class UrgentCabinetPatientWithdrawal {
  const UrgentCabinetPatientWithdrawal({
    required this.expectedResponseRevision,
    required this.expectedRequestRevision,
    required this.expectedJourneyRevision,
    required this.expectedCommitmentRevision,
  });

  final int expectedResponseRevision;
  final int expectedRequestRevision;
  final int expectedJourneyRevision;
  final int expectedCommitmentRevision;

  Map<String, Object> toJson() => {
    'expectedResponseRevision': expectedResponseRevision,
    'expectedAttemptRevision': expectedRequestRevision,
    'expectedJourneyRevision': expectedJourneyRevision,
    'expectedCommitmentRevision': expectedCommitmentRevision,
  };
}

@immutable
class UrgentCabinetArrivalHandoff {
  const UrgentCabinetArrivalHandoff({
    required this.handoffId,
    required this.commitmentId,
    required this.requestId,
    required this.token,
    required this.issuedAt,
    required this.expiresAt,
    required this.replayed,
  });

  final String handoffId;
  final String commitmentId;
  final String requestId;
  final String token;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final bool replayed;

  factory UrgentCabinetArrivalHandoff.fromJson(Map<String, dynamic> json) {
    final issuedAt = _requiredInstant(json, 'issuedAt');
    final expiresAt = _requiredInstant(json, 'expiresAt');
    final token = _requiredString(json, 'token');
    if (!expiresAt.isAfter(issuedAt) || token.length > 2048) {
      throw const FormatException('Invalid CABINET arrival handoff.');
    }
    return UrgentCabinetArrivalHandoff(
      handoffId: _requiredUuid(json, 'handoffId'),
      commitmentId: _requiredUuid(json, 'commitmentId'),
      requestId: _requiredUuid(json, 'requestId'),
      token: token,
      issuedAt: issuedAt,
      expiresAt: expiresAt,
      replayed: _requiredBool(json, 'replayed'),
    );
  }
}

void _validateStateCombination({
  required UrgentCabinetPatientResponseStatus responseStatus,
  required UrgentCabinetPatientAttemptState attemptState,
  required DateTime? respondedAt,
  required String? commitmentId,
  required UrgentCabinetPatientCommitmentStatus? commitmentStatus,
  required int? commitmentRevision,
  required DateTime? committedAt,
  required DateTime? arrivalVerifiedAt,
  required DateTime? terminalAt,
  required UrgentCabinetPatientTerminalReason? terminalReason,
  required List<String> allowedActions,
  required DateTime deadline,
  required DateTime evaluatedAt,
}) {
  if (allowedActions.toSet().length != allowedActions.length ||
      allowedActions.any(
        (action) =>
            action != 'CANCEL' &&
            action != 'WITHDRAW' &&
            action != 'ISSUE_ARRIVAL_QR',
      )) {
    throw const FormatException('Invalid urgent CABINET patient actions.');
  }
  final hasCommitment =
      commitmentId != null ||
      commitmentStatus != null ||
      commitmentRevision != null ||
      committedAt != null;
  switch (responseStatus) {
    case UrgentCabinetPatientResponseStatus.pending:
      if (attemptState != UrgentCabinetPatientAttemptState.cabinetPending ||
          respondedAt != null ||
          hasCommitment ||
          terminalAt != null ||
          terminalReason != null ||
          allowedActions.length != 1 ||
          !allowedActions.contains('CANCEL') ||
          !deadline.isAfter(evaluatedAt)) {
        throw const FormatException('Invalid pending urgent CABINET state.');
      }
    case UrgentCabinetPatientResponseStatus.accepted:
      if (attemptState != UrgentCabinetPatientAttemptState.cabinetCommitted ||
          respondedAt == null ||
          commitmentId == null ||
          commitmentStatus != UrgentCabinetPatientCommitmentStatus.active ||
          commitmentRevision == null ||
          committedAt == null ||
          terminalAt == null ||
          terminalReason != null ||
          (arrivalVerifiedAt == null
              ? !(allowedActions.isEmpty ||
                    (allowedActions.length == 2 &&
                        allowedActions.contains('WITHDRAW') &&
                        allowedActions.contains('ISSUE_ARRIVAL_QR')))
              : allowedActions.isNotEmpty)) {
        throw const FormatException('Invalid accepted urgent CABINET state.');
      }
    case UrgentCabinetPatientResponseStatus.declined:
      if (attemptState != UrgentCabinetPatientAttemptState.cabinetCancelled ||
          respondedAt == null ||
          hasCommitment ||
          terminalAt == null ||
          terminalReason != UrgentCabinetPatientTerminalReason.doctorDeclined ||
          allowedActions.isNotEmpty) {
        throw const FormatException('Invalid declined urgent CABINET state.');
      }
    case UrgentCabinetPatientResponseStatus.cancelled:
      final pendingCancellation =
          respondedAt == null &&
          !hasCommitment &&
          terminalReason == UrgentCabinetPatientTerminalReason.patientCancelled;
      final acceptedWithdrawal =
          respondedAt != null &&
          commitmentId != null &&
          commitmentStatus == UrgentCabinetPatientCommitmentStatus.cancelled &&
          commitmentRevision != null &&
          committedAt != null &&
          arrivalVerifiedAt == null &&
          terminalReason ==
              UrgentCabinetPatientTerminalReason.patientWithdrewAfterAcceptance;
      if (attemptState != UrgentCabinetPatientAttemptState.cabinetCancelled ||
          (!pendingCancellation && !acceptedWithdrawal) ||
          terminalAt == null ||
          allowedActions.isNotEmpty) {
        throw const FormatException('Invalid cancelled urgent CABINET state.');
      }
    case UrgentCabinetPatientResponseStatus.expired:
      if (attemptState != UrgentCabinetPatientAttemptState.cabinetCancelled ||
          respondedAt != null ||
          hasCommitment ||
          terminalAt == null ||
          terminalReason !=
              UrgentCabinetPatientTerminalReason.responseDeadlineElapsed ||
          allowedActions.isNotEmpty) {
        throw const FormatException('Invalid expired urgent CABINET state.');
      }
  }
}

String _requiredString(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Invalid urgent CABINET $field.');
  }
  return value.trim();
}

String _requiredUuid(Map<String, dynamic> json, String field) {
  final value = _requiredString(json, field).toLowerCase();
  if (!isCanonicalUuid(value)) {
    throw FormatException('Invalid urgent CABINET $field.');
  }
  return value;
}

String? _nullableUuid(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value == null) return null;
  if (value is! String || !isCanonicalUuid(value.trim().toLowerCase())) {
    throw FormatException('Invalid urgent CABINET $field.');
  }
  return value.trim().toLowerCase();
}

int _requiredNonnegativeInt(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is! int || value < 0) {
    throw FormatException('Invalid urgent CABINET $field.');
  }
  return value;
}

int? _nullableNonnegativeInt(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value == null) return null;
  if (value is! int || value < 0) {
    throw FormatException('Invalid urgent CABINET $field.');
  }
  return value;
}

double? _nullableCoordinate(
  Map<String, dynamic> json,
  String field, {
  required double min,
  required double max,
}) {
  final value = json[field];
  if (value == null) return null;
  if (value is! num) {
    throw FormatException('Invalid urgent CABINET $field.');
  }
  final coordinate = value.toDouble();
  if (!coordinate.isFinite || coordinate < min || coordinate > max) {
    throw FormatException('Invalid urgent CABINET $field.');
  }
  return coordinate;
}

bool _requiredBool(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is! bool) throw FormatException('Invalid urgent CABINET $field.');
  return value;
}

DateTime _requiredInstant(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is! String) throw FormatException('Invalid urgent CABINET $field.');
  final parsed = DateTime.tryParse(value);
  if (parsed == null || !value.endsWith('Z')) {
    throw FormatException('Invalid urgent CABINET $field.');
  }
  return parsed.toUtc();
}

DateTime? _nullableInstant(Map<String, dynamic> json, String field) {
  if (json[field] == null) return null;
  return _requiredInstant(json, field);
}

List<String> _requiredStringList(Map<String, dynamic> json, String field) {
  final value = json[field];
  if (value is! List) throw FormatException('Invalid urgent CABINET $field.');
  return value
      .map((item) {
        if (item is! String || item.trim().isEmpty) {
          throw FormatException('Invalid urgent CABINET $field.');
        }
        return item.trim();
      })
      .toList(growable: false);
}

T? _nullableEnum<T>(
  Map<String, dynamic> json,
  String field,
  T Function(String value) parser,
) {
  final value = json[field];
  if (value == null) return null;
  if (value is! String) throw FormatException('Invalid urgent CABINET $field.');
  return parser(value);
}

int _parseMilliTnd(Object? value) {
  final text = switch (value) {
    int number => number.toString(),
    double number when number.isFinite => number.toString(),
    String string => string.trim(),
    _ => throw const FormatException('Invalid urgent CABINET fee.'),
  };
  final match = RegExp(r'^(\d{1,8})(?:\.(\d{1,3}))?$').firstMatch(text);
  if (match == null) throw const FormatException('Invalid urgent CABINET fee.');
  final fraction = (match.group(2) ?? '').padRight(3, '0');
  return int.parse(match.group(1)!) * 1000 + int.parse(fraction);
}
