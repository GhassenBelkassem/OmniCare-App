/// Immutable wire models for `/api/v1/appointment-requests`.
///
/// Verified field-by-field against the backend records rather than inferred:
/// `SubmitClinicRequestRequest`, `RequestSubjectRequest`,
/// `SubmitClinicRequestResponse`, `PatientRequestResponse`,
/// `PatientRequestListResponse` and `CancelRequestRequest`.
///
/// Parsing is strict in the Clinic-model tradition: a missing identifier, a
/// malformed timestamp or a non-object payload throws
/// [RequestContractException] instead of degrading into a half-valid object.
/// The single deliberate exception is enum values, where an unknown *status*
/// is tolerated and an unknown *action* is dropped (see `request_vocabulary`).
///
/// No `Map<String, dynamic>` leaves this layer.
library;

import '../domain/clinic_request_intent.dart';
import '../domain/request_subject.dart';
import '../domain/request_vocabulary.dart';
import '../identity/request_operation_id.dart';

/// Body of `POST /appointment-requests/clinic`.
///
/// Exactly three fields, mirroring the backend record. There is no string
/// component at all beyond identifiers, so this type cannot carry medical free
/// text even by accident.
class SubmitClinicRequestPayload {
  const SubmitClinicRequestPayload({
    required this.requestId,
    required this.intent,
  });

  final RequestOperationId requestId;
  final ClinicRequestIntent intent;

  String get clinicId => intent.clinicId;

  RequestSubject get subject => intent.subject;

  Map<String, dynamic> toJson() {
    final pickup = intent.pickupLocation;
    if (intent.situation == RequestSituation.unknown) {
      throw const RequestContractException(
        'Unknown situation cannot be submitted.',
      );
    }
    if (intent.situation == RequestSituation.ambulance && pickup == null) {
      throw const RequestContractException(
        'Ambulance requests require a confirmed pickup location.',
      );
    }
    if (intent.situation != RequestSituation.ambulance && pickup != null) {
      throw const RequestContractException(
        'Only ambulance requests may include a pickup location.',
      );
    }
    return {
      'requestId': requestId.value,
      'clinicId': intent.clinicId,
      'situation': intent.situation.wireValue,
      'subject': intent.subject.toJson(),
      if (pickup != null) 'pickupLocation': pickup.toJson(),
    };
  }

  /// Carries no identifiers.
  @override
  String toString() => 'SubmitClinicRequestPayload(CLINIC)';
}

/// Response of `POST /appointment-requests/clinic`.
///
/// The body is byte-identical for a first write and for a replay; only the
/// status code differs, so [outcome] is supplied by the transport layer from
/// the HTTP status and is never read out of the payload.
class SubmitClinicRequestResult {
  const SubmitClinicRequestResult({
    required this.requestId,
    required this.clinicId,
    required this.kind,
    required this.situation,
    required this.patientStatus,
    required this.submittedAt,
    required this.version,
    required this.outcome,
  });

  final RequestOperationId requestId;
  final String clinicId;
  final RequestKind kind;
  final RequestSituation situation;
  final PatientRequestStatus patientStatus;
  final DateTime submittedAt;

  /// Optimistic-lock token. Echoed back as `expectedVersion` when cancelling,
  /// which is why the submit response carries it: cancelling immediately after
  /// submitting needs no extra round trip.
  final int version;

  final RequestSubmissionOutcome outcome;

  bool get isReplay => outcome == RequestSubmissionOutcome.replayed;

  factory SubmitClinicRequestResult.fromJson(
    Map<String, dynamic> json, {
    required RequestSubmissionOutcome outcome,
  }) {
    return SubmitClinicRequestResult(
      requestId: RequestOperationId.parse(_requiredString(json, 'requestId')),
      clinicId: _requiredString(json, 'clinicId'),
      kind: RequestKind.parse(_optionalString(json['kind'])),
      situation: RequestSituation.parse(_optionalString(json['situation'])),
      patientStatus: PatientRequestStatus.parse(
        _optionalString(json['patientStatus']),
      ),
      submittedAt: _requiredInstant(json, 'submittedAt'),
      version: _requiredInt(json, 'version'),
      outcome: outcome,
    );
  }

  @override
  String toString() => 'SubmitClinicRequestResult(${outcome.name})';
}

/// One request as the patient is allowed to see it.
///
/// Safe by omission on the server side too: there is no `mrsPatientId`, no
/// family member identifier, no internal lifecycle status, no fingerprint and
/// no medical content in this contract.
class PatientRequest {
  const PatientRequest({
    required this.requestId,
    required this.kind,
    required this.targetType,
    required this.targetId,
    required this.subjectType,
    required this.situation,
    required this.patientStatus,
    required this.submittedAt,
    required this.cancelledAt,
    required this.version,
    required this.availableActions,
    required this.informationRequest,
  });

  final RequestOperationId requestId;
  final RequestKind kind;
  final RequestTargetType targetType;

  /// Opaque provider reference. Resolving it to a clinic name belongs to the
  /// Clinic read API, not to Module 05.
  final String targetId;

  final RequestSubjectType subjectType;
  final RequestSituation situation;
  final PatientRequestStatus patientStatus;
  final DateTime submittedAt;
  final DateTime? cancelledAt;

  /// The value to send back as `expectedVersion`.
  final int version;

  /// Server-decided. The client renders these and never derives its own.
  final Set<PatientRequestAction> availableActions;
  final PatientInformationRequest? informationRequest;

  bool get canCancel => availableActions.contains(PatientRequestAction.cancel);
  bool get canProvideInformation =>
      availableActions.contains(PatientRequestAction.provideInformation) &&
      informationRequest != null;

  factory PatientRequest.fromJson(Map<String, dynamic> json) {
    return PatientRequest(
      requestId: RequestOperationId.parse(_requiredString(json, 'requestId')),
      kind: RequestKind.parse(_optionalString(json['kind'])),
      targetType: RequestTargetType.parse(_optionalString(json['targetType'])),
      targetId: _requiredString(json, 'targetId'),
      subjectType: RequestSubjectType.parse(
        _optionalString(json['subjectType']),
      ),
      situation: RequestSituation.parse(_optionalString(json['situation'])),
      patientStatus: PatientRequestStatus.parse(
        _optionalString(json['patientStatus']),
      ),
      submittedAt: _requiredInstant(json, 'submittedAt'),
      cancelledAt: _optionalInstant(json['cancelledAt']),
      version: _requiredInt(json, 'version'),
      availableActions: _parseActions(json['availableActions']),
      informationRequest: PatientInformationRequest.tryParse(
        json['informationRequest'],
      ),
    );
  }

  static Set<PatientRequestAction> _parseActions(Object? value) {
    if (value == null) return const {};
    if (value is! List) {
      throw const RequestContractException('Action list is malformed.');
    }
    final actions = <PatientRequestAction>{};
    for (final item in value) {
      // Unknown actions are dropped: an unrecognised value must never become a
      // control the patient can press.
      final action = PatientRequestAction.tryParse(_optionalString(item));
      if (action != null) actions.add(action);
    }
    return Set.unmodifiable(actions);
  }

  @override
  String toString() => 'PatientRequest(${patientStatus.wireValue})';
}

class PatientInformationRequest {
  const PatientInformationRequest({
    required this.informationRequestId,
    required this.reasonCode,
    required this.patientInstruction,
    required this.responseType,
    required this.status,
    this.responseSummary,
  });

  final String informationRequestId;
  final InformationRequestReasonCode reasonCode;
  final String? patientInstruction;
  final InformationResponseType responseType;
  final InformationRequestStatus status;
  final String? responseSummary;

  factory PatientInformationRequest.fromJson(Map<String, dynamic> json) {
    return PatientInformationRequest(
      informationRequestId: _requiredString(json, 'informationRequestId'),
      reasonCode: InformationRequestReasonCode.parse(
        _optionalString(json['reasonCode']),
      ),
      patientInstruction: _optionalString(json['patientInstruction']),
      responseType: InformationResponseType.parse(
        _optionalString(json['responseType']),
      ),
      status: InformationRequestStatus.parse(_optionalString(json['status'])),
      responseSummary: _optionalString(json['responseSummary']),
    );
  }

  static PatientInformationRequest? tryParse(Object? value) {
    if (value == null) return null;
    if (value is! Map) {
      throw const RequestContractException('Information request is malformed.');
    }
    return PatientInformationRequest.fromJson(value.cast<String, dynamic>());
  }
}

sealed class PatientInformationResponsePayload {
  const PatientInformationResponsePayload({
    required this.informationRequestId,
    required this.expectedVersion,
  });

  final String informationRequestId;
  final int expectedVersion;
  InformationResponseType get responseType;
  Set<OperationalWeekday> get availabilityWeekdays => const {};
  Map<String, dynamic> toJson();
}

class ConfirmationInformationResponsePayload
    extends PatientInformationResponsePayload {
  const ConfirmationInformationResponsePayload({
    required super.informationRequestId,
    required super.expectedVersion,
    this.confirmed = true,
  });
  final bool confirmed;
  @override
  InformationResponseType get responseType =>
      InformationResponseType.confirmation;
  @override
  Map<String, dynamic> toJson() => {
    'informationRequestId': informationRequestId,
    'expectedVersion': expectedVersion,
    'responseType': responseType.wireValue,
    'confirmed': confirmed,
  };
}

class ContactPreferenceInformationResponsePayload
    extends PatientInformationResponsePayload {
  const ContactPreferenceInformationResponsePayload({
    required super.informationRequestId,
    required super.expectedVersion,
    required this.preferredContactMethod,
    required this.contactDetailsConfirmed,
  });
  final PreferredContactMethod preferredContactMethod;
  final bool contactDetailsConfirmed;
  @override
  InformationResponseType get responseType =>
      InformationResponseType.contactPreference;
  @override
  Map<String, dynamic> toJson() => {
    'informationRequestId': informationRequestId,
    'expectedVersion': expectedVersion,
    'responseType': responseType.wireValue,
    'preferredContactMethod': preferredContactMethod.wireValue,
    'contactDetailsConfirmed': contactDetailsConfirmed,
  };
}

class AvailabilityInformationResponsePayload
    extends PatientInformationResponsePayload {
  const AvailabilityInformationResponsePayload({
    required super.informationRequestId,
    required super.expectedVersion,
    required this.availabilityWindows,
  });
  final List<AvailabilityWindow> availabilityWindows;
  @override
  Set<OperationalWeekday> get availabilityWeekdays =>
      availabilityWindows.map((window) => window.dayOfWeek).toSet();
  @override
  InformationResponseType get responseType =>
      InformationResponseType.availabilityWindows;
  @override
  Map<String, dynamic> toJson() => {
    'informationRequestId': informationRequestId,
    'expectedVersion': expectedVersion,
    'responseType': responseType.wireValue,
    'availabilityWindows': availabilityWindows
        .map((window) => window.toJson())
        .toList(growable: false),
  };
}

class IdentityConfirmationInformationResponsePayload
    extends PatientInformationResponsePayload {
  const IdentityConfirmationInformationResponsePayload({
    required super.informationRequestId,
    required super.expectedVersion,
    required this.identityInformationConfirmed,
  });
  final bool identityInformationConfirmed;
  @override
  InformationResponseType get responseType =>
      InformationResponseType.identityConfirmation;
  @override
  Map<String, dynamic> toJson() => {
    'informationRequestId': informationRequestId,
    'expectedVersion': expectedVersion,
    'responseType': responseType.wireValue,
    'identityInformationConfirmed': identityInformationConfirmed,
  };
}

class FamilyInformationConfirmationResponsePayload
    extends PatientInformationResponsePayload {
  const FamilyInformationConfirmationResponsePayload({
    required super.informationRequestId,
    required super.expectedVersion,
    required this.familyInformationConfirmed,
  });
  final bool familyInformationConfirmed;
  @override
  InformationResponseType get responseType =>
      InformationResponseType.familyInformationConfirmation;
  @override
  Map<String, dynamic> toJson() => {
    'informationRequestId': informationRequestId,
    'expectedVersion': expectedVersion,
    'responseType': responseType.wireValue,
    'familyInformationConfirmed': familyInformationConfirmed,
  };
}

enum PreferredContactMethod {
  phone('PHONE'),
  email('EMAIL');

  const PreferredContactMethod(this.wireValue);
  final String wireValue;
}

class AvailabilityWindow {
  const AvailabilityWindow({
    required this.dayOfWeek,
    required this.startLocalTime,
    required this.endLocalTime,
  });
  final OperationalWeekday dayOfWeek;
  final AvailabilityLocalTime startLocalTime;
  final AvailabilityLocalTime endLocalTime;
  Map<String, dynamic> toJson() => {
    'dayOfWeek': dayOfWeek.wireValue,
    'startLocalTime': _format(startLocalTime),
    'endLocalTime': _format(endLocalTime),
  };
  static String _format(AvailabilityLocalTime time) =>
      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
}

class AvailabilityLocalTime {
  const AvailabilityLocalTime(this.hour, this.minute);
  final int hour;
  final int minute;
}

/// Bounded page of `GET /appointment-requests`.
///
/// The backend returns a `Slice`, so there is deliberately no total count and
/// no total page number: [hasNext] is the only paging fact a mobile list needs
/// and the only one that costs no unbounded aggregate.
class PatientRequestListItem {
  const PatientRequestListItem({
    required this.requestId,
    required this.clinicDisplayName,
    required this.subjectType,
    required this.subjectDisplayName,
    required this.relationship,
    required this.situation,
    required this.patientStatus,
    required this.submittedAt,
    required this.requiresPatientAction,
    this.version,
  });
  final RequestOperationId requestId;
  final String clinicDisplayName;
  final RequestSubjectType subjectType;
  final String subjectDisplayName;
  final String? relationship;
  final RequestSituation situation;
  final PatientRequestStatus patientStatus;
  final DateTime submittedAt;
  final bool requiresPatientAction;
  final int? version;
  factory PatientRequestListItem.fromJson(Map<String, dynamic> json) =>
      PatientRequestListItem(
        requestId: RequestOperationId.parse(_requiredString(json, 'requestId')),
        clinicDisplayName: _requiredString(json, 'clinicDisplayName'),
        subjectType: RequestSubjectType.parse(
          _optionalString(json['subjectType']),
        ),
        subjectDisplayName: _requiredString(json, 'subjectDisplayName'),
        relationship: _optionalString(json['relationship']),
        situation: RequestSituation.parse(_optionalString(json['situation'])),
        patientStatus: PatientRequestStatus.parse(
          _optionalString(json['patientStatus']),
        ),
        submittedAt: _requiredInstant(json, 'submittedAt'),
        requiresPatientAction: json['requiresPatientAction'] == true,
      );
}

class PatientRequestPage {
  const PatientRequestPage({
    required this.contractVersion,
    required this.items,
    required this.page,
    required this.pageSize,
    required this.hasNext,
  });

  /// Currently `"1.0"`. Kept so a shape change is detectable without probing
  /// individual fields.
  final String contractVersion;

  final List<PatientRequestListItem> items;
  final int page;
  final int pageSize;
  final bool hasNext;

  factory PatientRequestPage.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    if (rawItems != null && rawItems is! List) {
      throw const RequestContractException('Request list is malformed.');
    }
    final items = <PatientRequestListItem>[];
    for (final item in (rawItems as List? ?? const [])) {
      if (item is! Map) {
        throw const RequestContractException('Request entry is malformed.');
      }
      items.add(PatientRequestListItem.fromJson(item.cast<String, dynamic>()));
    }
    return PatientRequestPage(
      contractVersion: _requiredString(json, 'contractVersion'),
      items: List.unmodifiable(items),
      page: _requiredInt(json, 'page'),
      pageSize: _requiredInt(json, 'pageSize'),
      hasNext: json['hasNext'] == true,
    );
  }

  @override
  String toString() => 'PatientRequestPage(${items.length} items)';
}

/// Body of `POST /appointment-requests/{requestId}/cancel`.
///
/// `expectedVersion` is mandatory on the server (boxed `@NotNull`), precisely
/// so an omitted version cannot default to `0` and accidentally succeed
/// against a freshly submitted request.
class CancelRequestPayload {
  const CancelRequestPayload({required this.expectedVersion});

  final int expectedVersion;

  Map<String, dynamic> toJson() => {'expectedVersion': expectedVersion};

  @override
  String toString() => 'CancelRequestPayload()';
}

// ---------------------------------------------------------------------------
// Strict primitives
// ---------------------------------------------------------------------------

String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) return value.trim();
  throw RequestContractException('Missing required field "$key".');
}

String? _optionalString(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is int) return value;
  if (value is num && value == value.roundToDouble()) return value.toInt();
  throw RequestContractException('Missing required numeric field "$key".');
}

/// Java `Instant` over Jackson with Spring Boot's default configuration, i.e.
/// `WRITE_DATES_AS_TIMESTAMPS` disabled: an ISO-8601 string such as
/// `2026-08-07T09:15:00Z`, optionally with fractional seconds. A non-string or
/// unparseable value is a contract violation, not something to guess at.
DateTime _requiredInstant(Map<String, dynamic> json, String key) {
  final parsed = _optionalInstant(json[key]);
  if (parsed == null) {
    throw RequestContractException('Missing required timestamp "$key".');
  }
  return parsed;
}

DateTime? _optionalInstant(Object? value) {
  if (value == null) return null;
  if (value is! String) {
    throw const RequestContractException(
      'Timestamp is not an ISO-8601 string.',
    );
  }
  final text = value.trim();
  if (text.isEmpty) return null;
  final parsed = DateTime.tryParse(text);
  if (parsed == null) {
    throw const RequestContractException('Timestamp is not ISO-8601.');
  }
  return parsed.toUtc();
}
