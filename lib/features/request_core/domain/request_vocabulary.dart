/// Module 05 patient-request vocabulary, mirrored from the backend enums.
///
/// Every value carries its exact wire string. Conversion is always explicit —
/// never `EnumName.values.byName`, never `describeEnum`, never `.toString()` —
/// so renaming a Dart constant can never silently change what is sent to, or
/// accepted from, the server.
///
/// Unknown-value policy follows the established Clinic model pattern:
///
/// * A **status** the app does not know is tolerated as `unknown`. A backend
///   that adds a lifecycle state must not crash a shipped app.
/// * An **action** the app does not know is *dropped*. An unrecognised action
///   can never be rendered as a button, so an unknown value can never grant a
///   capability.
///
/// This vocabulary is deliberately independent from the legacy reservation and
/// consultation status strings; they describe a different (demo) domain.
library;

/// Thrown when a Module 05 payload cannot be trusted. Developer-facing only:
/// its [reason] is never rendered to a patient.
class RequestContractException implements Exception {
  const RequestContractException(this.reason);

  final String reason;

  @override
  String toString() => 'RequestContractException: $reason';
}

/// The kind of care a request asks for.
///
/// All four kinds exist on the wire. Only [clinic] is usable by this app: no
/// Module 05 code path constructs a DOCTOR, KINE or NURSE submission.
enum RequestKind {
  clinic('CLINIC'),
  doctor('DOCTOR'),
  kine('KINE'),
  nurse('NURSE'),

  /// A kind this app version does not know. Never submitted.
  unknown('UNKNOWN');

  const RequestKind(this.wireValue);

  final String wireValue;

  /// True only for the kind this milestone can actually submit.
  bool get isSubmittable => this == clinic;

  static RequestKind parse(String? value) => _parseOrUnknown(
    value,
    RequestKind.values,
    (kind) => kind.wireValue,
    RequestKind.unknown,
  );
}

/// Operational target family behind a request.
enum RequestTargetType {
  clinic('CLINIC'),
  professional('PROFESSIONAL'),
  unknown('UNKNOWN');

  const RequestTargetType(this.wireValue);

  final String wireValue;

  static RequestTargetType parse(String? value) => _parseOrUnknown(
    value,
    RequestTargetType.values,
    (target) => target.wireValue,
    RequestTargetType.unknown,
  );
}

/// The only status vocabulary a patient client may render.
enum PatientRequestStatus {
  requestReceived('REQUEST_RECEIVED'),
  underReview('UNDER_REVIEW'),
  informationRequired('INFORMATION_REQUIRED'),
  schedulingInProgress('SCHEDULING_IN_PROGRESS'),
  waitingForConfirmation('WAITING_FOR_CONFIRMATION'),
  confirmed('CONFIRMED'),
  careInProgress('CARE_IN_PROGRESS'),
  completed('COMPLETED'),
  declined('DECLINED'),
  cancelled('CANCELLED'),

  /// A status introduced after this app version shipped.
  unknown('UNKNOWN');

  const PatientRequestStatus(this.wireValue);

  final String wireValue;

  /// Mirrors `PatientRequestStatus.isTerminal()` on the server.
  ///
  /// [unknown] is deliberately *not* terminal: guessing that an unrecognised
  /// state is final would hide a live request from the patient.
  bool get isTerminal =>
      this == completed || this == declined || this == cancelled;

  static PatientRequestStatus parse(String? value) => _parseOrUnknown(
    value,
    PatientRequestStatus.values,
    (status) => status.wireValue,
    PatientRequestStatus.unknown,
  );
}

enum PatientRequestListFilter {
  all('ALL', 'All'), active('ACTIVE', 'Active'), needsAction('NEEDS_ACTION', 'Needs action'), completed('COMPLETED', 'Completed'), cancelledDeclined('CANCELLED_DECLINED', 'Cancelled');
  const PatientRequestListFilter(this.wireValue, this.label);
  final String wireValue;
  final String label;
}

/// The patient-selected operational situation of a clinic request.
///
/// Exactly three wire values, mirroring the backend `RequestSituation` enum:
/// `APPOINTMENT`, `URGENT`, `AMBULANCE`. This is an operational request type
/// chosen explicitly by the patient — it is not medical triage and must never
/// be inferred from age, history, symptoms or any client algorithm. The value
/// is immutable after the first submission attempt; a deliberate change
/// requires a new logical `requestId`.
enum RequestSituation {
  appointment('APPOINTMENT'),
  urgent('URGENT'),
  ambulance('AMBULANCE'),

  /// A situation this app version does not know. Never submitted.
  unknown('UNKNOWN');

  const RequestSituation(this.wireValue);

  final String wireValue;

  static RequestSituation parse(String? value) => _parseOrUnknown(
    value,
    RequestSituation.values,
    (situation) => situation.wireValue,
    RequestSituation.unknown,
  );
}

/// How the patient explicitly confirmed an operational ambulance pickup.
enum PickupLocationSource {
  deviceGps('DEVICE_GPS'),
  mapSelection('MAP_SELECTION'),
  manualAddress('MANUAL_ADDRESS'),

  /// A source this app version does not know. Never submitted.
  unknown('UNKNOWN');

  const PickupLocationSource(this.wireValue);

  final String wireValue;

  static PickupLocationSource parse(String? value) => _parseOrUnknown(
    value,
    PickupLocationSource.values,
    (source) => source.wireValue,
    PickupLocationSource.unknown,
  );
}

/// What the server says the patient may currently do with a request.
///
/// The client never derives this from a status; it renders exactly what the
/// server advertises, and the server re-checks the rule on the command anyway.
enum PatientRequestAction {
  cancel('CANCEL'),
  provideInformation('PROVIDE_INFORMATION');

  const PatientRequestAction(this.wireValue);

  final String wireValue;

  /// Returns `null` for an unknown action so it can be dropped rather than
  /// surfaced as an unlabelled control.
  static PatientRequestAction? tryParse(String? value) {
    final normalized = _normalize(value);
    if (normalized == null) return null;
    for (final action in PatientRequestAction.values) {
      if (action.wireValue == normalized) return action;
    }
    return null;
  }
}

/// Who a request is for.
///
/// There is no "other person" mode in Module 05: a request is either for the
/// authenticated account holder or for one of their own family members.
enum RequestSubjectType {
  self('SELF'),
  familyMember('FAMILY_MEMBER'),

  /// Only ever produced when reading; never submitted.
  unknown('UNKNOWN');

  const RequestSubjectType(this.wireValue);

  final String wireValue;

  static RequestSubjectType parse(String? value) => _parseOrUnknown(
    value,
    RequestSubjectType.values,
    (subject) => subject.wireValue,
    RequestSubjectType.unknown,
  );
}

/// Whether a submission created a new request or replayed an existing one.
///
/// Decided from the HTTP status code (201 vs 200), exactly as the backend
/// intends — the body is identical for both, on purpose.
enum RequestSubmissionOutcome {
  created,
  replayed;

  bool get isCreated => this == created;
}

enum InformationRequestReasonCode {
  contactInformation('CONTACT_INFORMATION'),
  patientIdentityInformation('PATIENT_IDENTITY_INFORMATION'),
  familyMemberInformation('FAMILY_MEMBER_INFORMATION'),
  requestAdministrativeDetails('REQUEST_ADMINISTRATIVE_DETAILS'),
  availabilityInformation('AVAILABILITY_INFORMATION'),
  otherAdministrative('OTHER_ADMINISTRATIVE'),
  unknown('UNKNOWN');

  const InformationRequestReasonCode(this.wireValue);
  final String wireValue;

  static InformationRequestReasonCode parse(String? value) => _parseOrUnknown(
    value,
    InformationRequestReasonCode.values,
    (reason) => reason.wireValue,
    InformationRequestReasonCode.unknown,
  );
}

enum InformationResponseType {
  confirmation('CONFIRMATION'),
  contactPreference('CONTACT_PREFERENCE'),
  availabilityWindows('AVAILABILITY_WINDOWS'),
  /// Legacy parse-only value; never submitted by the P2.5-A renderer.
  weekdayAvailability('WEEKDAY_AVAILABILITY'),
  identityConfirmation('IDENTITY_CONFIRMATION'),
  familyInformationConfirmation('FAMILY_INFORMATION_CONFIRMATION'),
  administrativeSelection('ADMINISTRATIVE_SELECTION'),
  unknown('UNKNOWN');

  const InformationResponseType(this.wireValue);
  final String wireValue;

  static InformationResponseType parse(String? value) => _parseOrUnknown(
    value,
    InformationResponseType.values,
    (type) => type.wireValue,
    InformationResponseType.unknown,
  );
}

enum InformationRequestStatus {
  open('OPEN'),
  responded('RESPONDED'),
  cancelled('CANCELLED'),
  unknown('UNKNOWN');

  const InformationRequestStatus(this.wireValue);
  final String wireValue;

  static InformationRequestStatus parse(String? value) => _parseOrUnknown(
    value,
    InformationRequestStatus.values,
    (status) => status.wireValue,
    InformationRequestStatus.unknown,
  );
}

enum OperationalWeekday {
  monday('MONDAY'),
  tuesday('TUESDAY'),
  wednesday('WEDNESDAY'),
  thursday('THURSDAY'),
  friday('FRIDAY'),
  saturday('SATURDAY'),
  sunday('SUNDAY');

  const OperationalWeekday(this.wireValue);
  final String wireValue;
}

String? _normalize(String? value) {
  final trimmed = value?.trim().toUpperCase();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}

T _parseOrUnknown<T>(
  String? value,
  List<T> values,
  String Function(T) wireValueOf,
  T fallback,
) {
  final normalized = _normalize(value);
  if (normalized == null) return fallback;
  for (final candidate in values) {
    if (wireValueOf(candidate) == normalized) return candidate;
  }
  return fallback;
}
