import '../domain/urgent_journey_intents.dart';
import '../domain/urgent_journey_models.dart';

enum SyntheticUrgentScenario {
  basicEntry,
  familyMember,
  unauthorizedSubject,
  ownershipChangedSubject,
  linkedFallback,
  expiredHold,
  staleVersion,
  conflictingSelection,
  unavailableAdmission,
  disconnectedReconstructed,
}

enum SyntheticTriageAvailability { ready, loading, unavailable }

abstract interface class UrgentFixtureClock {
  DateTime now();
}

final class FixedUrgentFixtureClock implements UrgentFixtureClock {
  const FixedUrgentFixtureClock(this.value);

  final DateTime value;

  @override
  DateTime now() => value;
}

final class MutableUrgentFixtureClock implements UrgentFixtureClock {
  MutableUrgentFixtureClock(this.value);

  DateTime value;

  void advance(Duration duration) => value = value.add(duration);

  @override
  DateTime now() => value;
}

final class SyntheticUrgentPolicyFixture {
  const SyntheticUrgentPolicyFixture({
    required this.name,
    required this.maximumLiveHolds,
    required this.holdTtl,
  }) : assert(maximumLiveHolds > 0);

  final String name;
  final int maximumLiveHolds;
  final Duration holdTtl;

  static const developmentCandidate = SyntheticUrgentPolicyFixture(
    name: 'development-candidate-m2-k2-ttl120',
    maximumLiveHolds: 2,
    holdTtl: Duration(seconds: 120),
  );
}

final class SyntheticUrgentFixtureSnapshot {
  SyntheticUrgentFixtureSnapshot({
    required Iterable<CareSubjectChoiceProjection> subjectChoices,
    required this.patientJourney,
    required this.offeredDoctor,
    required this.committedDoctor,
    required this.admission,
    required this.connected,
  }) : subjectChoices = List.unmodifiable(subjectChoices);

  final List<CareSubjectChoiceProjection> subjectChoices;
  final PatientUrgentJourneyProjection? patientJourney;
  final OfferedDoctorUrgentProjection? offeredDoctor;
  final CommittedDoctorUrgentProjection? committedDoctor;
  final DoctorAdmissionSnapshot admission;
  final bool connected;
}

/// Deterministic, in-memory P4 UI fixture source.
///
/// It performs no I/O, owns no production identifier, and does not simulate
/// success with timers. Every state change is the result of a typed command.
final class SyntheticUrgentJourneyFixtureSource {
  SyntheticUrgentJourneyFixtureSource({
    this.scenario = SyntheticUrgentScenario.basicEntry,
    UrgentFixtureClock? clock,
    this.policy = SyntheticUrgentPolicyFixture.developmentCandidate,
    SyntheticTriageAvailability triageAvailability =
        SyntheticTriageAvailability.ready,
  }) : _triageAvailability = triageAvailability,
       clock =
           clock ?? FixedUrgentFixtureClock(DateTime.utc(2026, 10, 10, 9, 0)) {
    _initializeScenario();
  }

  static const patientAccount = AccountScopeUiRef('syn_account_patient_a');
  static const otherAccount = AccountScopeUiRef('syn_account_patient_b');
  static const doctorAccount = AccountScopeUiRef('syn_account_doctor_a');
  static const selfSubject = SubjectSelectionUiRef('syn_subject_self');
  static const familySubject = SubjectSelectionUiRef('syn_subject_family_1');
  static const restrictedSubject = SubjectSelectionUiRef(
    'syn_subject_restricted',
  );

  final SyntheticUrgentScenario scenario;
  final UrgentFixtureClock clock;
  final SyntheticUrgentPolicyFixture policy;
  SyntheticTriageAvailability _triageAvailability;
  SyntheticTriageAvailability get triageAvailability => _triageAvailability;
  final Map<String, _SyntheticCommandReceipt> _receipts = {};

  late List<CareSubjectChoiceProjection> _subjects;
  late DoctorAdmissionSnapshot _admission;
  PatientUrgentJourneyProjection? _patientJourney;
  OfferedDoctorUrgentProjection? _offeredDoctor;
  CommittedDoctorUrgentProjection? _committedDoctor;
  bool _connected = true;

  SyntheticUrgentFixtureSnapshot snapshot() => SyntheticUrgentFixtureSnapshot(
    subjectChoices: _subjects,
    patientJourney: _patientJourney,
    offeredDoctor: _offeredDoctor,
    committedDoctor: _committedDoctor,
    admission: _admission,
    connected: _connected,
  );

  /// Reconstructs from the current immutable fixture snapshot. It never
  /// replays local actions or advances lifecycle state.
  SyntheticUrgentFixtureSnapshot reconstruct() {
    _connected = true;
    return snapshot();
  }

  void retryTriage() {
    if (_triageAvailability != SyntheticTriageAvailability.loading) {
      _triageAvailability = SyntheticTriageAvailability.ready;
    }
  }

  UrgentUiCommandResult execute(UrgentUiIntent intent) {
    final prior = _receipts[intent.actionId];
    if (prior != null) {
      if (prior.fingerprint != intent.fingerprint) {
        return const UrgentUiCommandFailure(
          error: UrgentSafeError(
            code: UrgentSafeErrorCode.duplicateActionConflict,
            messageKey: 'urgent.error.duplicate_action_conflict',
            retryable: false,
          ),
        );
      }
      final result = prior.result;
      if (result case UrgentUiCommandSuccess(:final projection)) {
        return UrgentUiCommandSuccess(projection: projection, replayed: true);
      }
      return result;
    }

    final result = switch (intent) {
      StartUrgentJourneyIntent value => _start(value),
      SaveStructuredTriageIntent value => _saveTriage(value),
      ConfirmHomeDestinationIntent value => _confirmDestination(value),
      SelectHomeHoldIntent value => _selectHomeHold(value),
      ChooseCabinetTargetIntent value => _chooseCabinetTarget(value),
      AcceptCabinetTargetIntent value => _acceptCabinetTarget(value),
      CreateFallbackAttemptIntent value => _createFallback(value),
    };
    _receipts[intent.actionId] = _SyntheticCommandReceipt(
      fingerprint: intent.fingerprint,
      result: result,
    );
    return result;
  }

  UrgentUiCommandResult _saveTriage(SaveStructuredTriageIntent intent) {
    final journey = _patientJourney;
    final commonFailure = _validatePatientJourney(
      intent.accountScopeRef,
      intent.journeyRef,
      intent.expectedJourneyVersion,
    );
    if (commonFailure != null) return commonFailure;
    final attempt = journey!.activeAttempt;
    if (attempt.attemptRef != intent.attemptRef) {
      return _failure(UrgentSafeErrorCode.staleProjection, latest: journey);
    }
    if (attempt.version != intent.expectedAttemptVersion) {
      return _failure(UrgentSafeErrorCode.staleProjection, latest: journey);
    }
    if (triageAvailability != SyntheticTriageAvailability.ready) {
      return _failure(UrgentSafeErrorCode.triageUnavailable, latest: journey);
    }
    if (!intent.triage.isValid) {
      return _failure(
        UrgentSafeErrorCode.triageValidationFailed,
        latest: journey,
      );
    }
    final updated = switch (attempt) {
      HomeAttemptProjection value => value.copyWith(
        version: value.version + 1,
        stage: UrgentAttemptStage.homeDestinationSetup,
        triage: intent.triage,
      ),
      CabinetAttemptProjection value => value.copyWith(
        version: value.version + 1,
        stage: UrgentAttemptStage.cabinetTargetSelection,
        triage: intent.triage,
      ),
    };
    _patientJourney = journey.copyWith(
      attempts: _replaceActiveAttempt(journey, updated),
      version: journey.version + 1,
      availableActions: attempt.mode == UrgentAttemptMode.home
          ? const {
              UrgentPatientAction.confirmHomeDestination,
              UrgentPatientAction.cancelJourney,
            }
          : const {
              UrgentPatientAction.chooseCabinetTarget,
              UrgentPatientAction.cancelJourney,
            },
      clearSafeError: true,
    );
    return UrgentUiCommandSuccess(projection: _patientJourney!);
  }

  UrgentUiCommandResult _confirmDestination(
    ConfirmHomeDestinationIntent intent,
  ) {
    final journey = _patientJourney;
    final commonFailure = _validatePatientJourney(
      intent.accountScopeRef,
      intent.journeyRef,
      intent.expectedJourneyVersion,
    );
    if (commonFailure != null) return commonFailure;
    final attempt = journey!.activeAttempt;
    if (attempt is! HomeAttemptProjection ||
        attempt.attemptRef != intent.attemptRef) {
      return _failure(UrgentSafeErrorCode.modeMismatch, latest: journey);
    }
    if (attempt.version != intent.expectedAttemptVersion) {
      return _failure(UrgentSafeErrorCode.staleProjection, latest: journey);
    }
    if ((attempt.stage != UrgentAttemptStage.homeDestinationSetup &&
            attempt.stage != UrgentAttemptStage.setupReview) ||
        intent.destination.status != HomeDestinationStatus.confirmed ||
        !intent.destination.hasExactLocation) {
      return _failure(
        UrgentSafeErrorCode.destinationNotConfirmed,
        latest: journey,
      );
    }
    final updated = attempt.copyWith(
      version: attempt.version + 1,
      stage: UrgentAttemptStage.setupReview,
      destination: intent.destination,
    );
    _patientJourney = journey.copyWith(
      attempts: _replaceActiveAttempt(journey, updated),
      version: journey.version + 1,
      availableActions: const {UrgentPatientAction.cancelJourney},
      clearSafeError: true,
    );
    return UrgentUiCommandSuccess(projection: _patientJourney!);
  }

  UrgentUiCommandResult _start(StartUrgentJourneyIntent intent) {
    if (intent.accountScopeRef != patientAccount) {
      return _failure(UrgentSafeErrorCode.resourceNotVisible);
    }
    final matching = _subjects.where(
      (subject) => subject.selectionRef == intent.subjectSelectionRef,
    );
    if (matching.isEmpty) {
      return _failure(UrgentSafeErrorCode.subjectNotAvailable);
    }
    final subject = matching.single;
    if (subject.accountScopeRef != intent.accountScopeRef) {
      return _failure(UrgentSafeErrorCode.resourceNotVisible);
    }
    if (subject.access == CareSubjectAccess.ownershipChanged) {
      return _failure(UrgentSafeErrorCode.ownershipChanged);
    }
    if (!subject.canStartJourney) {
      return _failure(UrgentSafeErrorCode.subjectNotAvailable);
    }
    if (_patientJourney != null) {
      return _failure(
        UrgentSafeErrorCode.selectionConflict,
        latest: _patientJourney,
      );
    }

    final attempt = _newAttempt(intent.initialMode, ordinal: 1);
    _patientJourney = PatientUrgentJourneyProjection(
      journeyRef: const JourneyUiRef('syn_journey_active_1'),
      requestingAccountScopeRef: intent.accountScopeRef,
      subject: subject,
      attempts: [attempt],
      activeAttemptRef: attempt.attemptRef,
      version: 1,
      availableActions: _entryActions(intent.initialMode),
    );
    return UrgentUiCommandSuccess(projection: _patientJourney!);
  }

  UrgentUiCommandResult _selectHomeHold(SelectHomeHoldIntent intent) {
    final journey = _patientJourney;
    final commonFailure = _validatePatientJourney(
      intent.accountScopeRef,
      intent.journeyRef,
      intent.expectedJourneyVersion,
    );
    if (commonFailure != null) return commonFailure;
    if (journey!.activeCommitment != null) {
      return _failure(UrgentSafeErrorCode.selectionConflict, latest: journey);
    }
    final attempt = journey.activeAttempt;
    if (attempt is! HomeAttemptProjection ||
        attempt.attemptRef != intent.attemptRef) {
      return _failure(UrgentSafeErrorCode.modeMismatch, latest: journey);
    }
    if (attempt.version != intent.expectedAttemptVersion) {
      return _failure(UrgentSafeErrorCode.staleProjection, latest: journey);
    }
    final holds = attempt.acceptedHolds.where(
      (hold) => hold.holdRef == intent.holdRef,
    );
    if (holds.isEmpty) {
      return _failure(UrgentSafeErrorCode.holdRequired, latest: journey);
    }
    final hold = holds.single;
    if (!hold.isLiveAt(clock.now())) {
      return _failure(UrgentSafeErrorCode.holdExpired, latest: journey);
    }
    final offer = attempt.offers.firstWhere(
      (candidate) => candidate.offerRef == hold.offerRef,
    );
    final commitment = UrgentCommitmentProjection(
      commitmentRef: const CommitmentUiRef('syn_commitment_home_1'),
      sourceAttemptRef: attempt.attemptRef,
      mode: UrgentAttemptMode.home,
      doctorRef: offer.doctorRef,
      approvedQuote: offer.quote,
      version: 1,
      committedAt: clock.now(),
    );
    final updatedAttempt = attempt.copyWith(
      version: attempt.version + 1,
      stage: UrgentAttemptStage.committed,
      acceptedHolds: [hold],
    );
    _patientJourney = journey.copyWith(
      attempts: _replaceActiveAttempt(journey, updatedAttempt),
      version: journey.version + 1,
      availableActions: const {UrgentPatientAction.cancelJourney},
      activeCommitment: commitment,
      clearSafeError: true,
    );
    _admission = DoctorAdmissionSnapshot(
      state: DoctorAdmissionState.homeCommitted,
      version: _admission.version + 1,
      observedAt: clock.now(),
      dependencyCertain: true,
    );
    _offeredDoctor = null;
    _committedDoctor = _committedHomeDoctor(_patientJourney!, _admission);
    return UrgentUiCommandSuccess(projection: _patientJourney!);
  }

  UrgentUiCommandResult _chooseCabinetTarget(ChooseCabinetTargetIntent intent) {
    final journey = _patientJourney;
    final commonFailure = _validatePatientJourney(
      intent.accountScopeRef,
      intent.journeyRef,
      intent.expectedJourneyVersion,
    );
    if (commonFailure != null) return commonFailure;
    final attempt = journey!.activeAttempt;
    if (attempt is! CabinetAttemptProjection ||
        attempt.attemptRef != intent.attemptRef) {
      return _failure(UrgentSafeErrorCode.modeMismatch, latest: journey);
    }
    if (attempt.version != intent.expectedAttemptVersion) {
      return _failure(UrgentSafeErrorCode.staleProjection, latest: journey);
    }
    if (attempt.stage != UrgentAttemptStage.cabinetTargetSelection ||
        intent.target.quote.context != UrgentFeeContext.cabinet) {
      return _failure(
        UrgentSafeErrorCode.transitionNotAllowed,
        latest: journey,
      );
    }
    final updated = attempt.copyWith(
      version: attempt.version + 1,
      stage: UrgentAttemptStage.awaitingCabinetDoctor,
      target: intent.target,
    );
    _patientJourney = journey.copyWith(
      attempts: _replaceActiveAttempt(journey, updated),
      version: journey.version + 1,
      availableActions: const {UrgentPatientAction.cancelJourney},
      clearSafeError: true,
    );
    _offeredDoctor = _cabinetDoctorOffer(updated);
    return UrgentUiCommandSuccess(projection: _patientJourney!);
  }

  UrgentUiCommandResult _acceptCabinetTarget(AcceptCabinetTargetIntent intent) {
    final journey = _patientJourney;
    if (intent.accountScopeRef != doctorAccount) {
      return _failure(UrgentSafeErrorCode.actorScopeMismatch, latest: journey);
    }
    if (journey == null || journey.journeyRef != intent.journeyRef) {
      return _failure(UrgentSafeErrorCode.resourceNotVisible);
    }
    if (journey.version != intent.expectedJourneyVersion) {
      return _failure(UrgentSafeErrorCode.staleProjection, latest: journey);
    }
    final attempt = journey.activeAttempt;
    if (attempt is! CabinetAttemptProjection ||
        attempt.attemptRef != intent.attemptRef) {
      return _failure(UrgentSafeErrorCode.modeMismatch, latest: journey);
    }
    if (attempt.version != intent.expectedAttemptVersion) {
      return _failure(UrgentSafeErrorCode.staleProjection, latest: journey);
    }
    final target = attempt.target;
    if (target == null ||
        attempt.stage != UrgentAttemptStage.awaitingCabinetDoctor) {
      return _failure(
        UrgentSafeErrorCode.cabinetTargetRequired,
        latest: journey,
      );
    }
    if (target.doctorRef != intent.doctorRef) {
      return _failure(UrgentSafeErrorCode.resourceNotVisible, latest: journey);
    }
    if (!_admission.canAccept) {
      return _failure(
        UrgentSafeErrorCode.admissionUnavailable,
        latest: journey,
      );
    }
    final commitment = UrgentCommitmentProjection(
      commitmentRef: const CommitmentUiRef('syn_commitment_cabinet_1'),
      sourceAttemptRef: attempt.attemptRef,
      mode: UrgentAttemptMode.cabinet,
      doctorRef: target.doctorRef,
      approvedQuote: target.quote,
      version: 1,
      committedAt: clock.now(),
    );
    final updated = attempt.copyWith(
      version: attempt.version + 1,
      stage: UrgentAttemptStage.committed,
    );
    _patientJourney = journey.copyWith(
      attempts: _replaceActiveAttempt(journey, updated),
      version: journey.version + 1,
      availableActions: const {UrgentPatientAction.cancelJourney},
      activeCommitment: commitment,
      clearSafeError: true,
    );
    _admission = DoctorAdmissionSnapshot(
      state: DoctorAdmissionState.cabinetCommitted,
      version: _admission.version + 1,
      observedAt: clock.now(),
      dependencyCertain: true,
    );
    _offeredDoctor = null;
    _committedDoctor = _committedCabinetDoctor(_patientJourney!, _admission);
    return UrgentUiCommandSuccess(projection: _patientJourney!);
  }

  UrgentUiCommandResult _createFallback(CreateFallbackAttemptIntent intent) {
    final journey = _patientJourney;
    final commonFailure = _validatePatientJourney(
      intent.accountScopeRef,
      intent.journeyRef,
      intent.expectedJourneyVersion,
    );
    if (commonFailure != null) return commonFailure;
    final active = journey!.activeAttempt;
    if (active.attemptRef != intent.fromAttemptRef) {
      return _failure(UrgentSafeErrorCode.staleProjection, latest: journey);
    }
    if (active.mode == intent.toMode || journey.activeCommitment != null) {
      return _failure(
        UrgentSafeErrorCode.transitionNotAllowed,
        latest: journey,
      );
    }
    final closed = switch (active) {
      HomeAttemptProjection value => value.copyWith(
        version: value.version + 1,
        stage: UrgentAttemptStage.failed,
      ),
      CabinetAttemptProjection value => value.copyWith(
        version: value.version + 1,
        stage: UrgentAttemptStage.failed,
      ),
    };
    final next = _newAttempt(
      intent.toMode,
      ordinal: journey.attempts.length + 1,
    );
    final attempts = journey.attempts
        .map(
          (attempt) =>
              attempt.attemptRef == active.attemptRef ? closed : attempt,
        )
        .followedBy([next]);
    _patientJourney = journey.copyWith(
      attempts: attempts,
      activeAttemptRef: next.attemptRef,
      version: journey.version + 1,
      availableActions: _entryActions(intent.toMode),
      clearSafeError: true,
    );
    return UrgentUiCommandSuccess(projection: _patientJourney!);
  }

  UrgentUiCommandFailure? _validatePatientJourney(
    AccountScopeUiRef accountScope,
    JourneyUiRef journeyRef,
    int expectedVersion,
  ) {
    final journey = _patientJourney;
    if (journey == null || journey.journeyRef != journeyRef) {
      return _failure(UrgentSafeErrorCode.resourceNotVisible);
    }
    if (accountScope != journey.requestingAccountScopeRef) {
      return _failure(UrgentSafeErrorCode.resourceNotVisible);
    }
    if (journey.version != expectedVersion) {
      return _failure(UrgentSafeErrorCode.staleProjection, latest: journey);
    }
    return null;
  }

  UrgentUiCommandFailure _failure(
    UrgentSafeErrorCode code, {
    PatientUrgentJourneyProjection? latest,
  }) {
    final retryable = switch (code) {
      UrgentSafeErrorCode.staleProjection ||
      UrgentSafeErrorCode.holdExpired ||
      UrgentSafeErrorCode.selectionConflict ||
      UrgentSafeErrorCode.admissionUnavailable => true,
      _ => false,
    };
    return UrgentUiCommandFailure(
      error: UrgentSafeError(
        code: code,
        messageKey: 'urgent.error.${code.name}',
        retryable: retryable,
      ),
      latestProjection: latest,
    );
  }

  List<UrgentAttemptProjection> _replaceActiveAttempt(
    PatientUrgentJourneyProjection journey,
    UrgentAttemptProjection replacement,
  ) => journey.attempts
      .map(
        (attempt) => attempt.attemptRef == journey.activeAttemptRef
            ? replacement
            : attempt,
      )
      .toList(growable: false);

  Set<UrgentPatientAction> _entryActions(UrgentAttemptMode mode) => const {
    UrgentPatientAction.saveStructuredTriage,
    UrgentPatientAction.cancelJourney,
  };

  UrgentAttemptProjection _newAttempt(
    UrgentAttemptMode mode, {
    required int ordinal,
  }) {
    final ref = AttemptUiRef('syn_attempt_$ordinal');
    final triage = PatientTriageProjection(
      minimum: StructuredTriageMinimumProjection(
        bodyAreaCodes: const [],
        painIntensity: 0,
        painBandCode: 'PENDING_APPROVAL',
        painBandDisplayKey: 'p4_pain_pending',
      ),
    );
    return switch (mode) {
      UrgentAttemptMode.home => HomeAttemptProjection(
        attemptRef: ref,
        ordinal: ordinal,
        version: 1,
        stage: UrgentAttemptStage.triageSetup,
        policyFixtureName: policy.name,
        triage: triage,
        matchingEpoch: 1,
        offers: const [],
        acceptedHolds: const [],
      ),
      UrgentAttemptMode.cabinet => CabinetAttemptProjection(
        attemptRef: ref,
        ordinal: ordinal,
        version: 1,
        stage: UrgentAttemptStage.triageSetup,
        policyFixtureName: policy.name,
        triage: triage,
        recoveryChoices: const {UrgentRecoveryChoice.cancel},
      ),
    };
  }

  void _initializeScenario() {
    _subjects = [
      const CareSubjectChoiceProjection(
        selectionRef: selfSubject,
        accountScopeRef: patientAccount,
        kind: CareSubjectKind.self,
        displayLabel: 'Patient démo',
        relationshipLabel: 'Moi',
        access: CareSubjectAccess.authorized,
      ),
      const CareSubjectChoiceProjection(
        selectionRef: familySubject,
        accountScopeRef: patientAccount,
        kind: CareSubjectKind.familyMember,
        displayLabel: 'Proche démo',
        relationshipLabel: 'Famille',
        access: CareSubjectAccess.authorized,
      ),
    ];
    _admission = DoctorAdmissionSnapshot(
      state: DoctorAdmissionState.available,
      version: 1,
      observedAt: clock.now(),
      dependencyCertain: true,
    );

    switch (scenario) {
      case SyntheticUrgentScenario.basicEntry:
      case SyntheticUrgentScenario.familyMember:
        return;
      case SyntheticUrgentScenario.unauthorizedSubject:
        _subjects = [
          ..._subjects,
          const CareSubjectChoiceProjection(
            selectionRef: restrictedSubject,
            accountScopeRef: otherAccount,
            kind: CareSubjectKind.familyMember,
            displayLabel: 'Sujet indisponible',
            relationshipLabel: 'Accès indisponible',
            access: CareSubjectAccess.unauthorized,
          ),
        ];
        return;
      case SyntheticUrgentScenario.ownershipChangedSubject:
        _subjects = [
          ..._subjects,
          const CareSubjectChoiceProjection(
            selectionRef: restrictedSubject,
            accountScopeRef: patientAccount,
            kind: CareSubjectKind.familyMember,
            displayLabel: 'Sujet indisponible',
            relationshipLabel: 'Accès modifié',
            access: CareSubjectAccess.ownershipChanged,
          ),
        ];
        return;
      case SyntheticUrgentScenario.linkedFallback:
        _patientJourney = _linkedFallbackJourney();
        return;
      case SyntheticUrgentScenario.expiredHold:
        _patientJourney = _homeChoiceJourney(expired: true);
        _offeredDoctor = _homeDoctorOffer(
          _patientJourney!.activeAttempt as HomeAttemptProjection,
        );
        return;
      case SyntheticUrgentScenario.staleVersion:
        _patientJourney = _homeChoiceJourney(
          journeyVersion: 7,
          attemptVersion: 4,
        );
        _offeredDoctor = _homeDoctorOffer(
          _patientJourney!.activeAttempt as HomeAttemptProjection,
        );
        return;
      case SyntheticUrgentScenario.conflictingSelection:
        _patientJourney = _committedHomeJourney();
        _admission = DoctorAdmissionSnapshot(
          state: DoctorAdmissionState.homeCommitted,
          version: 4,
          observedAt: clock.now(),
          dependencyCertain: true,
        );
        _committedDoctor = _committedHomeDoctor(_patientJourney!, _admission);
        return;
      case SyntheticUrgentScenario.unavailableAdmission:
        _admission = DoctorAdmissionSnapshot(
          state: DoctorAdmissionState.dependencyUnavailable,
          version: 3,
          observedAt: clock.now(),
          dependencyCertain: false,
        );
        _patientJourney = _cabinetAwaitingJourney();
        _offeredDoctor = _cabinetDoctorOffer(
          _patientJourney!.activeAttempt as CabinetAttemptProjection,
        );
        return;
      case SyntheticUrgentScenario.disconnectedReconstructed:
        _patientJourney = _homeChoiceJourney(
          journeyVersion: 9,
          attemptVersion: 5,
        );
        _offeredDoctor = _homeDoctorOffer(
          _patientJourney!.activeAttempt as HomeAttemptProjection,
        );
        _connected = false;
        return;
    }
  }

  PatientUrgentJourneyProjection _homeChoiceJourney({
    bool expired = false,
    int journeyVersion = 3,
    int attemptVersion = 2,
  }) {
    final acceptedAt = clock.now().subtract(const Duration(seconds: 30));
    final expiresAt = expired
        ? clock.now().subtract(const Duration(seconds: 1))
        : acceptedAt.add(policy.holdTtl);
    const attemptRef = AttemptUiRef('syn_attempt_home_1');
    const offerRef = OfferUiRef('syn_offer_home_1');
    const quote = UrgentFeeQuote(
      context: UrgentFeeContext.home,
      amountMinor: 12000,
      currency: 'TND',
      feeVersion: 4,
    );
    final attempt = HomeAttemptProjection(
      attemptRef: attemptRef,
      ordinal: 1,
      version: attemptVersion,
      stage: UrgentAttemptStage.waitingPatientSelection,
      policyFixtureName: policy.name,
      triage: PatientTriageProjection(
        minimum: StructuredTriageMinimumProjection(
          bodyAreaCodes: const ['CHEST'],
          painIntensity: 8,
          painBandCode: 'SYNTHETIC_SEVERE_PENDING_APPROVAL',
          painBandDisplayKey: 'p4_pain_severe',
        ),
      ),
      matchingEpoch: 1,
      offers: [
        PatientHomeOfferProjection(
          offerRef: offerRef,
          doctorRef: DoctorPublicUiRef('syn_doctor_public_1'),
          doctorDisplayName: 'Dr Démo Un',
          specialtyLabel: 'Médecine générale',
          coarseEtaLabel: 'Environ 10–15 min',
          quote: quote,
          offerVersion: 1,
        ),
      ],
      acceptedHolds: [
        AcceptedHomeHoldProjection(
          holdRef: const HoldUiRef('syn_hold_home_1'),
          offerRef: offerRef,
          attemptRef: attemptRef,
          acceptedAt: acceptedAt,
          expiresAt: expiresAt,
          version: 1,
        ),
      ],
    );
    return PatientUrgentJourneyProjection(
      journeyRef: const JourneyUiRef('syn_journey_active_1'),
      requestingAccountScopeRef: patientAccount,
      subject: _subjects.first,
      attempts: [attempt],
      activeAttemptRef: attemptRef,
      version: journeyVersion,
      availableActions: const {
        UrgentPatientAction.selectHomeHold,
        UrgentPatientAction.cancelJourney,
      },
    );
  }

  PatientUrgentJourneyProjection _committedHomeJourney() {
    final base = _homeChoiceJourney();
    final attempt = base.activeAttempt as HomeAttemptProjection;
    final offer = attempt.offers.single;
    final commitment = UrgentCommitmentProjection(
      commitmentRef: const CommitmentUiRef('syn_commitment_home_existing'),
      sourceAttemptRef: attempt.attemptRef,
      mode: UrgentAttemptMode.home,
      doctorRef: offer.doctorRef,
      approvedQuote: offer.quote,
      version: 2,
      committedAt: clock.now().subtract(const Duration(minutes: 1)),
    );
    return base.copyWith(
      attempts: [
        attempt.copyWith(
          version: attempt.version + 1,
          stage: UrgentAttemptStage.committed,
        ),
      ],
      version: base.version + 1,
      availableActions: const {UrgentPatientAction.cancelJourney},
      activeCommitment: commitment,
    );
  }

  PatientUrgentJourneyProjection _linkedFallbackJourney() {
    final home =
        _newAttempt(UrgentAttemptMode.home, ordinal: 1)
            as HomeAttemptProjection;
    final failedHome = home.copyWith(
      stage: UrgentAttemptStage.failed,
      version: 2,
    );
    final cabinet = _newAttempt(UrgentAttemptMode.cabinet, ordinal: 2);
    return PatientUrgentJourneyProjection(
      journeyRef: const JourneyUiRef('syn_journey_fallback_1'),
      requestingAccountScopeRef: patientAccount,
      subject: _subjects.first,
      attempts: [failedHome, cabinet],
      activeAttemptRef: cabinet.attemptRef,
      version: 4,
      availableActions: _entryActions(UrgentAttemptMode.cabinet),
    );
  }

  PatientUrgentJourneyProjection _cabinetAwaitingJourney() {
    final base =
        _newAttempt(UrgentAttemptMode.cabinet, ordinal: 1)
            as CabinetAttemptProjection;
    final targeted = base.copyWith(
      version: 2,
      stage: UrgentAttemptStage.awaitingCabinetDoctor,
      target: syntheticCabinetTarget,
    );
    return PatientUrgentJourneyProjection(
      journeyRef: const JourneyUiRef('syn_journey_cabinet_1'),
      requestingAccountScopeRef: patientAccount,
      subject: _subjects.first,
      attempts: [targeted],
      activeAttemptRef: targeted.attemptRef,
      version: 2,
      availableActions: const {UrgentPatientAction.cancelJourney},
    );
  }

  OfferedDoctorUrgentProjection _cabinetDoctorOffer(
    CabinetAttemptProjection attempt,
  ) => OfferedDoctorUrgentProjection(
    offerRef: const OfferUiRef('syn_offer_cabinet_target_1'),
    attemptRef: attempt.attemptRef,
    mode: UrgentAttemptMode.cabinet,
    version: attempt.version,
    triage: attempt.triage.minimum,
    coarseZoneOrEta: 'Cabinet sélectionné par le Patient',
    applicableQuote: attempt.target?.quote ?? syntheticCabinetTarget.quote,
    respondBy: clock.now().add(const Duration(minutes: 2)),
    admission: _admission,
  );

  OfferedDoctorUrgentProjection _homeDoctorOffer(
    HomeAttemptProjection attempt,
  ) {
    final offer = attempt.offers.single;
    final hold = attempt.acceptedHolds.single;
    return OfferedDoctorUrgentProjection(
      offerRef: offer.offerRef,
      attemptRef: attempt.attemptRef,
      mode: UrgentAttemptMode.home,
      version: attempt.version,
      triage: attempt.triage.minimum,
      coarseZoneOrEta: 'Zone synthétique · ${offer.coarseEtaLabel}',
      applicableQuote: offer.quote,
      respondBy: hold.expiresAt,
      admission: DoctorAdmissionSnapshot(
        state: DoctorAdmissionState.homeHold,
        version: _admission.version,
        observedAt: clock.now(),
        dependencyCertain: true,
      ),
    );
  }

  CommittedDoctorUrgentProjection _committedHomeDoctor(
    PatientUrgentJourneyProjection journey,
    DoctorAdmissionSnapshot admission,
  ) => CommittedDoctorUrgentProjection(
    commitment: journey.activeCommitment!,
    subjectDisplayLabel: 'Patient démo',
    triage: journey.activeAttempt.triage.minimum,
    admission: admission,
    homeDestination: HomeDestinationDraft(
      permission: HomeLocationPermission.granted,
      service: HomeLocationService.available,
      quality: HomeLocationQuality.fresh,
      status: HomeDestinationStatus.confirmed,
      source: HomeDestinationSource.syntheticGps,
      displayAddress: 'Adresse synthétique, Tunis',
      latitude: 36.8000,
      longitude: 10.1800,
      capturedAt: clock.now(),
    ),
    contactRelayLabel: 'Relais de contact synthétique',
  );

  CommittedDoctorUrgentProjection _committedCabinetDoctor(
    PatientUrgentJourneyProjection journey,
    DoctorAdmissionSnapshot admission,
  ) => CommittedDoctorUrgentProjection(
    commitment: journey.activeCommitment!,
    subjectDisplayLabel: 'Patient démo',
    triage: journey.activeAttempt.triage.minimum,
    admission: admission,
    contactRelayLabel: 'Relais de contact synthétique',
  );

  static final syntheticCabinetTarget = CabinetTargetProjection(
    doctorRef: DoctorPublicUiRef('syn_doctor_public_cabinet_1'),
    cabinetRef: CabinetPublicUiRef('syn_cabinet_public_1'),
    doctorDisplayName: 'Dr Démo Cabinet',
    cabinetDisplayName: 'Cabinet démo',
    publicAddress: 'Adresse publique synthétique, Tunis',
    specialtyLabel: 'Médecine générale',
    urgentCapabilityLabel: 'Urgences au cabinet',
    quote: UrgentFeeQuote(
      context: UrgentFeeContext.cabinet,
      amountMinor: 8000,
      currency: 'TND',
      feeVersion: 2,
    ),
  );
}

final class _SyntheticCommandReceipt {
  const _SyntheticCommandReceipt({
    required this.fingerprint,
    required this.result,
  });

  final String fingerprint;
  final UrgentUiCommandResult result;
}
