/// Opaque, UI-only reference. It is never an account, Patient, Doctor, or MRS
/// identifier and must not be treated as authorization evidence.
abstract base class UrgentUiRef {
  const UrgentUiRef(this.value) : assert(value != '');

  final String value;

  @override
  bool operator ==(Object other) =>
      other.runtimeType == runtimeType &&
      other is UrgentUiRef &&
      other.value == value;

  @override
  int get hashCode => Object.hash(runtimeType, value);

  @override
  String toString() => value;
}

final class JourneyUiRef extends UrgentUiRef {
  const JourneyUiRef(super.value);
}

final class AttemptUiRef extends UrgentUiRef {
  const AttemptUiRef(super.value);
}

final class OfferUiRef extends UrgentUiRef {
  const OfferUiRef(super.value);
}

final class HoldUiRef extends UrgentUiRef {
  const HoldUiRef(super.value);
}

final class CommitmentUiRef extends UrgentUiRef {
  const CommitmentUiRef(super.value);
}

final class SubjectSelectionUiRef extends UrgentUiRef {
  const SubjectSelectionUiRef(super.value);
}

final class AccountScopeUiRef extends UrgentUiRef {
  const AccountScopeUiRef(super.value);
}

final class DoctorPublicUiRef extends UrgentUiRef {
  const DoctorPublicUiRef(super.value);
}

final class CabinetPublicUiRef extends UrgentUiRef {
  const CabinetPublicUiRef(super.value);
}

enum UrgentAttemptMode { home, cabinet }

enum UrgentViewerScope { patientAccount, offeredDoctor, committedDoctor }

enum CareSubjectKind { self, familyMember }

enum CareSubjectAccess { authorized, unauthorized, ownershipChanged }

enum UrgentAttemptStage {
  triageSetup,
  homeDestinationSetup,
  setupReview,
  matching,
  waitingPatientSelection,
  cabinetTargetSelection,
  awaitingCabinetDoctor,
  committed,
  failed,
  cancelled,
  clinicalHandoffPending,
}

enum DoctorAdmissionState {
  available,
  homeHold,
  homeCommitted,
  cabinetCommitted,
  p5ClinicalBusy,
  postHandoffUnavailable,
  dependencyUnavailable,
}

enum UrgentRecoveryChoice {
  retryHome,
  chooseAnotherCabinet,
  fallbackToHome,
  fallbackToCabinet,
  cancel,
}

enum UrgentPatientAction {
  chooseSubject,
  continueHomeTriage,
  saveStructuredTriage,
  confirmHomeDestination,
  chooseCabinetTarget,
  selectHomeHold,
  createFallbackAttempt,
  cancelJourney,
}

enum UrgentSafeErrorCode {
  subjectNotAvailable,
  ownershipChanged,
  resourceNotVisible,
  staleProjection,
  actorScopeMismatch,
  modeMismatch,
  holdRequired,
  holdExpired,
  selectionConflict,
  cabinetTargetRequired,
  admissionUnavailable,
  duplicateActionConflict,
  transitionNotAllowed,
  triageUnavailable,
  triageValidationFailed,
  destinationNotConfirmed,
}

enum UrgentFeeContext { home, cabinet }

final class UrgentSafeError {
  const UrgentSafeError({
    required this.code,
    required this.messageKey,
    required this.retryable,
  });

  final UrgentSafeErrorCode code;
  final String messageKey;
  final bool retryable;
}

final class UrgentFeeQuote {
  const UrgentFeeQuote({
    required this.context,
    required this.amountMinor,
    required this.currency,
    required this.feeVersion,
  }) : assert(amountMinor >= 0),
       assert(currency.length == 3),
       assert(feeVersion > 0);

  final int amountMinor;
  final UrgentFeeContext context;
  final String currency;
  final int feeVersion;

  String get displayAmount =>
      '${(amountMinor / 100).toStringAsFixed(2)} ${currency.toUpperCase()}';

  @override
  bool operator ==(Object other) =>
      other is UrgentFeeQuote &&
      other.context == context &&
      other.amountMinor == amountMinor &&
      other.currency == currency &&
      other.feeVersion == feeVersion;

  @override
  int get hashCode => Object.hash(context, amountMinor, currency, feeVersion);
}

enum TriageVocabularyStatus { pendingClinicalPrivacyApproval }

final class StructuredTriageMinimumProjection {
  StructuredTriageMinimumProjection({
    required Iterable<String> bodyAreaCodes,
    required this.painIntensity,
    required this.painBandCode,
    required this.painBandDisplayKey,
    this.vocabularyStatus =
        TriageVocabularyStatus.pendingClinicalPrivacyApproval,
  }) : bodyAreaCodes = List.unmodifiable(bodyAreaCodes);

  final List<String> bodyAreaCodes;
  final int painIntensity;
  final String painBandCode;
  final String painBandDisplayKey;
  final TriageVocabularyStatus vocabularyStatus;

  bool get isValid =>
      bodyAreaCodes.isNotEmpty && painIntensity >= 1 && painIntensity <= 10;

  /// Deliberately no free text, voice, Patient identity, or MRS fields.
  Map<String, Object> get safeFields => Map.unmodifiable({
    'bodyAreaCodes': bodyAreaCodes,
    'painIntensity': painIntensity,
    'painBandCode': painBandCode,
  });
}

enum PatientNarrativePolicy { pendingApproval }

final class PatientPrivateNarrativeProjection {
  const PatientPrivateNarrativeProjection({
    required this.value,
    this.policy = PatientNarrativePolicy.pendingApproval,
  });

  final String value;
  final PatientNarrativePolicy policy;
  bool get canDiscloseToOfferedDoctor => false;
}

final class PatientTriageProjection {
  const PatientTriageProjection({required this.minimum, this.privateNarrative});

  final StructuredTriageMinimumProjection minimum;
  final PatientPrivateNarrativeProjection? privateNarrative;
  bool get isValid => minimum.isValid;
}

final class CareSubjectChoiceProjection {
  const CareSubjectChoiceProjection({
    required this.selectionRef,
    required this.accountScopeRef,
    required this.kind,
    required this.displayLabel,
    required this.relationshipLabel,
    required this.access,
  });

  final SubjectSelectionUiRef selectionRef;
  final AccountScopeUiRef accountScopeRef;
  final CareSubjectKind kind;
  final String displayLabel;
  final String relationshipLabel;
  final CareSubjectAccess access;

  bool get canStartJourney => access == CareSubjectAccess.authorized;
}

enum HomeLocationPermission { notRequested, granted, denied, deniedForever }

enum HomeLocationService { available, unavailable }

enum HomeDestinationSource { syntheticGps, manualAddress }

enum HomeLocationQuality { none, acquiring, fresh, lowAccuracy, stale }

enum HomeDestinationStatus { empty, draft, confirmed, offlineUnsent }

final class HomeDestinationDraft {
  const HomeDestinationDraft({
    required this.permission,
    required this.service,
    required this.quality,
    required this.status,
    this.source,
    this.displayAddress,
    this.latitude,
    this.longitude,
    this.accuracyMeters,
    this.capturedAt,
    this.mapSearchAvailable = true,
  });

  final HomeLocationPermission permission;
  final HomeLocationService service;
  final HomeLocationQuality quality;
  final HomeDestinationStatus status;
  final HomeDestinationSource? source;
  final String? displayAddress;
  final double? latitude;
  final double? longitude;
  final double? accuracyMeters;
  final DateTime? capturedAt;
  final bool mapSearchAvailable;

  bool get hasExactLocation => latitude != null && longitude != null;
  bool get canConfirm =>
      status == HomeDestinationStatus.draft &&
      displayAddress != null &&
      hasExactLocation &&
      quality != HomeLocationQuality.stale;
}

final class PatientHomeOfferProjection {
  PatientHomeOfferProjection({
    required this.offerRef,
    required this.doctorRef,
    required this.doctorDisplayName,
    required this.specialtyLabel,
    required this.coarseEtaLabel,
    required this.quote,
    required this.offerVersion,
  }) : assert(
         quote.context == UrgentFeeContext.home,
         'A HOME offer requires a HOME fee quote.',
       );

  final OfferUiRef offerRef;
  final DoctorPublicUiRef doctorRef;
  final String doctorDisplayName;
  final String specialtyLabel;
  final String coarseEtaLabel;
  final UrgentFeeQuote quote;
  final int offerVersion;
}

final class AcceptedHomeHoldProjection {
  const AcceptedHomeHoldProjection({
    required this.holdRef,
    required this.offerRef,
    required this.attemptRef,
    required this.acceptedAt,
    required this.expiresAt,
    required this.version,
  });

  final HoldUiRef holdRef;
  final OfferUiRef offerRef;
  final AttemptUiRef attemptRef;
  final DateTime acceptedAt;
  final DateTime expiresAt;
  final int version;

  bool isLiveAt(DateTime serverNow) => serverNow.isBefore(expiresAt);
}

final class CabinetTargetProjection {
  CabinetTargetProjection({
    required this.doctorRef,
    required this.cabinetRef,
    required this.doctorDisplayName,
    required this.cabinetDisplayName,
    required this.publicAddress,
    required this.specialtyLabel,
    required this.urgentCapabilityLabel,
    required this.quote,
  }) : assert(
         quote.context == UrgentFeeContext.cabinet,
         'A CABINET target requires a CABINET fee quote.',
       );

  final DoctorPublicUiRef doctorRef;
  final CabinetPublicUiRef cabinetRef;
  final String doctorDisplayName;
  final String cabinetDisplayName;
  final String publicAddress;
  final String specialtyLabel;
  final String urgentCapabilityLabel;
  final UrgentFeeQuote quote;
}

sealed class UrgentAttemptProjection {
  const UrgentAttemptProjection({
    required this.attemptRef,
    required this.ordinal,
    required this.version,
    required this.stage,
    required this.policyFixtureName,
    required this.triage,
  }) : assert(ordinal > 0),
       assert(version > 0);

  final AttemptUiRef attemptRef;
  final int ordinal;
  final int version;
  final UrgentAttemptStage stage;
  final String policyFixtureName;
  final PatientTriageProjection triage;
  UrgentAttemptMode get mode;
}

final class HomeAttemptProjection extends UrgentAttemptProjection {
  HomeAttemptProjection({
    required super.attemptRef,
    required super.ordinal,
    required super.version,
    required super.stage,
    required super.policyFixtureName,
    required super.triage,
    required this.matchingEpoch,
    required Iterable<PatientHomeOfferProjection> offers,
    required Iterable<AcceptedHomeHoldProjection> acceptedHolds,
    this.destination,
  }) : offers = List.unmodifiable(offers),
       acceptedHolds = List.unmodifiable(acceptedHolds),
       assert(matchingEpoch > 0);

  @override
  UrgentAttemptMode get mode => UrgentAttemptMode.home;

  final int matchingEpoch;
  final List<PatientHomeOfferProjection> offers;
  final List<AcceptedHomeHoldProjection> acceptedHolds;
  final HomeDestinationDraft? destination;

  HomeAttemptProjection copyWith({
    int? version,
    UrgentAttemptStage? stage,
    int? matchingEpoch,
    Iterable<PatientHomeOfferProjection>? offers,
    Iterable<AcceptedHomeHoldProjection>? acceptedHolds,
    HomeDestinationDraft? destination,
    PatientTriageProjection? triage,
  }) => HomeAttemptProjection(
    attemptRef: attemptRef,
    ordinal: ordinal,
    version: version ?? this.version,
    stage: stage ?? this.stage,
    policyFixtureName: policyFixtureName,
    triage: triage ?? this.triage,
    matchingEpoch: matchingEpoch ?? this.matchingEpoch,
    offers: offers ?? this.offers,
    acceptedHolds: acceptedHolds ?? this.acceptedHolds,
    destination: destination ?? this.destination,
  );
}

final class CabinetAttemptProjection extends UrgentAttemptProjection {
  CabinetAttemptProjection({
    required super.attemptRef,
    required super.ordinal,
    required super.version,
    required super.stage,
    required super.policyFixtureName,
    required super.triage,
    required Iterable<UrgentRecoveryChoice> recoveryChoices,
    this.target,
  }) : recoveryChoices = Set.unmodifiable(recoveryChoices),
       assert(
         stage != UrgentAttemptStage.awaitingCabinetDoctor || target != null,
         'CABINET Doctor acceptance cannot be requested before target choice.',
       );

  @override
  UrgentAttemptMode get mode => UrgentAttemptMode.cabinet;

  final CabinetTargetProjection? target;
  final Set<UrgentRecoveryChoice> recoveryChoices;

  CabinetAttemptProjection copyWith({
    int? version,
    UrgentAttemptStage? stage,
    CabinetTargetProjection? target,
    Iterable<UrgentRecoveryChoice>? recoveryChoices,
    PatientTriageProjection? triage,
  }) => CabinetAttemptProjection(
    attemptRef: attemptRef,
    ordinal: ordinal,
    version: version ?? this.version,
    stage: stage ?? this.stage,
    policyFixtureName: policyFixtureName,
    triage: triage ?? this.triage,
    target: target ?? this.target,
    recoveryChoices: recoveryChoices ?? this.recoveryChoices,
  );
}

final class UrgentCommitmentProjection {
  UrgentCommitmentProjection({
    required this.commitmentRef,
    required this.sourceAttemptRef,
    required this.mode,
    required this.doctorRef,
    required this.approvedQuote,
    required this.version,
    required this.committedAt,
  }) : assert(
         (mode == UrgentAttemptMode.home &&
                 approvedQuote.context == UrgentFeeContext.home) ||
             (mode == UrgentAttemptMode.cabinet &&
                 approvedQuote.context == UrgentFeeContext.cabinet),
         'The approved fee must belong to the committed attempt mode.',
       );

  final CommitmentUiRef commitmentRef;
  final AttemptUiRef sourceAttemptRef;
  final UrgentAttemptMode mode;
  final DoctorPublicUiRef doctorRef;
  final UrgentFeeQuote approvedQuote;
  final int version;
  final DateTime committedAt;
}

final class DoctorAdmissionSnapshot {
  const DoctorAdmissionSnapshot({
    required this.state,
    required this.version,
    required this.observedAt,
    required this.dependencyCertain,
  });

  final DoctorAdmissionState state;
  final int version;
  final DateTime observedAt;
  final bool dependencyCertain;

  bool get canAccept =>
      dependencyCertain && state == DoctorAdmissionState.available;
}

final class PatientUrgentJourneyProjection {
  PatientUrgentJourneyProjection({
    required this.journeyRef,
    required this.requestingAccountScopeRef,
    required this.subject,
    required Iterable<UrgentAttemptProjection> attempts,
    required this.activeAttemptRef,
    required this.version,
    required Iterable<UrgentPatientAction> availableActions,
    this.activeCommitment,
    this.safeError,
  }) : attempts = List.unmodifiable(attempts),
       availableActions = Set.unmodifiable(availableActions),
       assert(subject.access == CareSubjectAccess.authorized),
       assert(version > 0),
       assert(
         attempts.any((attempt) => attempt.attemptRef == activeAttemptRef),
         'The active attempt must belong to the journey projection.',
       );

  final JourneyUiRef journeyRef;
  final AccountScopeUiRef requestingAccountScopeRef;
  final CareSubjectChoiceProjection subject;
  final List<UrgentAttemptProjection> attempts;
  final AttemptUiRef activeAttemptRef;
  final int version;
  final Set<UrgentPatientAction> availableActions;
  final UrgentCommitmentProjection? activeCommitment;
  final UrgentSafeError? safeError;

  UrgentAttemptProjection get activeAttempt =>
      attempts.firstWhere((attempt) => attempt.attemptRef == activeAttemptRef);

  PatientUrgentJourneyProjection copyWith({
    Iterable<UrgentAttemptProjection>? attempts,
    AttemptUiRef? activeAttemptRef,
    int? version,
    Iterable<UrgentPatientAction>? availableActions,
    UrgentCommitmentProjection? activeCommitment,
    UrgentSafeError? safeError,
    bool clearSafeError = false,
  }) => PatientUrgentJourneyProjection(
    journeyRef: journeyRef,
    requestingAccountScopeRef: requestingAccountScopeRef,
    subject: subject,
    attempts: attempts ?? this.attempts,
    activeAttemptRef: activeAttemptRef ?? this.activeAttemptRef,
    version: version ?? this.version,
    availableActions: availableActions ?? this.availableActions,
    activeCommitment: activeCommitment ?? this.activeCommitment,
    safeError: clearSafeError ? null : safeError ?? this.safeError,
  );
}

/// Minimum projection for a Doctor who owns one offer but is not committed.
/// Its type cannot represent Patient identity, exact destination, contact,
/// free text, voice, family relation, or peer offers.
final class OfferedDoctorUrgentProjection {
  const OfferedDoctorUrgentProjection({
    required this.offerRef,
    required this.attemptRef,
    required this.mode,
    required this.version,
    required this.triage,
    required this.coarseZoneOrEta,
    required this.applicableQuote,
    required this.respondBy,
    required this.admission,
  });

  final OfferUiRef offerRef;
  final AttemptUiRef attemptRef;
  final UrgentAttemptMode mode;
  final int version;
  final StructuredTriageMinimumProjection triage;
  final String coarseZoneOrEta;
  final UrgentFeeQuote applicableQuote;
  final DateTime respondBy;
  final DoctorAdmissionSnapshot admission;
}

/// Purpose-limited projection available only after a fenced commitment.
final class CommittedDoctorUrgentProjection {
  CommittedDoctorUrgentProjection({
    required this.commitment,
    required this.subjectDisplayLabel,
    required this.triage,
    required this.admission,
    this.homeDestination,
    this.contactRelayLabel,
  }) : assert(
         commitment.mode != UrgentAttemptMode.home || homeDestination != null,
         'A committed HOME projection requires its protected destination.',
       ),
       assert(
         commitment.mode != UrgentAttemptMode.cabinet ||
             homeDestination == null,
         'A CABINET projection must never contain a HOME destination.',
       );

  final UrgentCommitmentProjection commitment;
  final String subjectDisplayLabel;
  final StructuredTriageMinimumProjection triage;
  final DoctorAdmissionSnapshot admission;
  final HomeDestinationDraft? homeDestination;
  final String? contactRelayLabel;
}
