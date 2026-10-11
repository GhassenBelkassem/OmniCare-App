import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/features/urgent_journey/data/synthetic_urgent_journey_fixture_source.dart';
import 'package:omnicare_mobile/features/urgent_journey/domain/urgent_journey_intents.dart';
import 'package:omnicare_mobile/features/urgent_journey/domain/urgent_journey_models.dart';

void main() {
  group('P4 synthetic urgent journey command contract', () {
    test('starts SELF and FAMILY_MEMBER journeys with immutable modes', () {
      for (final entry in <(SubjectSelectionUiRef, UrgentAttemptMode)>[
        (
          SyntheticUrgentJourneyFixtureSource.selfSubject,
          UrgentAttemptMode.home,
        ),
        (
          SyntheticUrgentJourneyFixtureSource.familySubject,
          UrgentAttemptMode.cabinet,
        ),
      ]) {
        final source = SyntheticUrgentJourneyFixtureSource();
        final result = source.execute(
          StartUrgentJourneyIntent(
            actionId: 'start-${entry.$1.value}',
            accountScopeRef: SyntheticUrgentJourneyFixtureSource.patientAccount,
            subjectSelectionRef: entry.$1,
            initialMode: entry.$2,
          ),
        );

        expect(result, isA<UrgentUiCommandSuccess>());
        final journey = (result as UrgentUiCommandSuccess).projection;
        expect(journey.subject.selectionRef, entry.$1);
        expect(journey.activeAttempt.mode, entry.$2);
        expect(journey.attempts, hasLength(1));
      }
    });

    test('canonical subject equivalence never grants cross-account access', () {
      final source = SyntheticUrgentJourneyFixtureSource(
        scenario: SyntheticUrgentScenario.unauthorizedSubject,
      );
      final result = source.execute(
        const StartUrgentJourneyIntent(
          actionId: 'cross-account',
          accountScopeRef: SyntheticUrgentJourneyFixtureSource.patientAccount,
          subjectSelectionRef:
              SyntheticUrgentJourneyFixtureSource.restrictedSubject,
          initialMode: UrgentAttemptMode.home,
        ),
      );

      expect(_errorCode(result), UrgentSafeErrorCode.resourceNotVisible);
      expect(source.snapshot().patientJourney, isNull);
    });

    test('ownership change revokes journey creation', () {
      final source = SyntheticUrgentJourneyFixtureSource(
        scenario: SyntheticUrgentScenario.ownershipChangedSubject,
      );
      final result = source.execute(
        const StartUrgentJourneyIntent(
          actionId: 'ownership-changed',
          accountScopeRef: SyntheticUrgentJourneyFixtureSource.patientAccount,
          subjectSelectionRef:
              SyntheticUrgentJourneyFixtureSource.restrictedSubject,
          initialMode: UrgentAttemptMode.home,
        ),
      );

      expect(_errorCode(result), UrgentSafeErrorCode.ownershipChanged);
    });

    test('HOME commitment requires the live accepted hold and versions', () {
      final source = SyntheticUrgentJourneyFixtureSource(
        scenario: SyntheticUrgentScenario.staleVersion,
      );
      final before = source.snapshot().patientJourney!;
      final attempt = before.activeAttempt as HomeAttemptProjection;
      expect(source.snapshot().offeredDoctor, isNotNull);
      expect(source.snapshot().committedDoctor, isNull);

      final missingHold = source.execute(
        SelectHomeHoldIntent(
          actionId: 'missing-hold',
          accountScopeRef: before.requestingAccountScopeRef,
          journeyRef: before.journeyRef,
          attemptRef: attempt.attemptRef,
          holdRef: const HoldUiRef('unknown-hold'),
          expectedJourneyVersion: before.version,
          expectedAttemptVersion: attempt.version,
        ),
      );
      expect(_errorCode(missingHold), UrgentSafeErrorCode.holdRequired);

      final stale = source.execute(
        SelectHomeHoldIntent(
          actionId: 'stale-selection',
          accountScopeRef: before.requestingAccountScopeRef,
          journeyRef: before.journeyRef,
          attemptRef: attempt.attemptRef,
          holdRef: attempt.acceptedHolds.single.holdRef,
          expectedJourneyVersion: before.version - 1,
          expectedAttemptVersion: attempt.version,
        ),
      );
      expect(_errorCode(stale), UrgentSafeErrorCode.staleProjection);

      final selected = source.execute(
        SelectHomeHoldIntent(
          actionId: 'valid-selection',
          accountScopeRef: before.requestingAccountScopeRef,
          journeyRef: before.journeyRef,
          attemptRef: attempt.attemptRef,
          holdRef: attempt.acceptedHolds.single.holdRef,
          expectedJourneyVersion: before.version,
          expectedAttemptVersion: attempt.version,
        ),
      );
      expect(selected, isA<UrgentUiCommandSuccess>());
      final committed = (selected as UrgentUiCommandSuccess).projection;
      expect(committed.activeCommitment, isNotNull);
      expect(
        committed.activeCommitment!.approvedQuote,
        attempt.offers.single.quote,
      );
      expect(committed.activeCommitment!.sourceAttemptRef, attempt.attemptRef);
      expect(source.snapshot().offeredDoctor, isNull);
      expect(source.snapshot().committedDoctor, isNotNull);
      expect(source.snapshot().committedDoctor!.homeDestination, isNotNull);
    });

    test('an expired hold loses exactly at its expiry boundary', () {
      final clock = MutableUrgentFixtureClock(DateTime.utc(2026, 10, 10, 9));
      final source = SyntheticUrgentJourneyFixtureSource(
        scenario: SyntheticUrgentScenario.staleVersion,
        clock: clock,
      );
      final journey = source.snapshot().patientJourney!;
      final attempt = journey.activeAttempt as HomeAttemptProjection;
      clock.advance(const Duration(seconds: 90));

      final result = source.execute(
        SelectHomeHoldIntent(
          actionId: 'at-expiry',
          accountScopeRef: journey.requestingAccountScopeRef,
          journeyRef: journey.journeyRef,
          attemptRef: attempt.attemptRef,
          holdRef: attempt.acceptedHolds.single.holdRef,
          expectedJourneyVersion: journey.version,
          expectedAttemptVersion: attempt.version,
        ),
      );

      expect(_errorCode(result), UrgentSafeErrorCode.holdExpired);
    });

    test('K and TTL remain injectable fixture parameters', () {
      const policy = SyntheticUrgentPolicyFixture(
        name: 'test-only-k1-ttl30',
        maximumLiveHolds: 1,
        holdTtl: Duration(seconds: 30),
      );
      final source = SyntheticUrgentJourneyFixtureSource(
        scenario: SyntheticUrgentScenario.staleVersion,
        policy: policy,
      );
      final attempt =
          source.snapshot().patientJourney!.activeAttempt
              as HomeAttemptProjection;

      expect(attempt.policyFixtureName, policy.name);
      expect(attempt.acceptedHolds, hasLength(policy.maximumLiveHolds));
      expect(
        attempt.acceptedHolds.single.expiresAt.difference(
          attempt.acceptedHolds.single.acceptedAt,
        ),
        policy.holdTtl,
      );
    });

    test('a second HOME selection conflicts after commitment', () {
      final source = SyntheticUrgentJourneyFixtureSource(
        scenario: SyntheticUrgentScenario.conflictingSelection,
      );
      final journey = source.snapshot().patientJourney!;
      final attempt = journey.activeAttempt as HomeAttemptProjection;

      final result = source.execute(
        SelectHomeHoldIntent(
          actionId: 'second-selection',
          accountScopeRef: journey.requestingAccountScopeRef,
          journeyRef: journey.journeyRef,
          attemptRef: attempt.attemptRef,
          holdRef: attempt.acceptedHolds.single.holdRef,
          expectedJourneyVersion: journey.version,
          expectedAttemptVersion: attempt.version,
        ),
      );

      expect(_errorCode(result), UrgentSafeErrorCode.selectionConflict);
    });

    test('CABINET target choice must precede Doctor acceptance', () {
      final source = SyntheticUrgentJourneyFixtureSource();
      final started =
          source.execute(
                const StartUrgentJourneyIntent(
                  actionId: 'start-cabinet',
                  accountScopeRef:
                      SyntheticUrgentJourneyFixtureSource.patientAccount,
                  subjectSelectionRef:
                      SyntheticUrgentJourneyFixtureSource.selfSubject,
                  initialMode: UrgentAttemptMode.cabinet,
                ),
              )
              as UrgentUiCommandSuccess;
      final first = started.projection;
      final draft = first.activeAttempt as CabinetAttemptProjection;

      final premature = source.execute(
        AcceptCabinetTargetIntent(
          actionId: 'premature-accept',
          accountScopeRef: SyntheticUrgentJourneyFixtureSource.doctorAccount,
          journeyRef: first.journeyRef,
          attemptRef: draft.attemptRef,
          doctorRef: SyntheticUrgentJourneyFixtureSource
              .syntheticCabinetTarget
              .doctorRef,
          expectedJourneyVersion: first.version,
          expectedAttemptVersion: draft.version,
        ),
      );
      expect(_errorCode(premature), UrgentSafeErrorCode.cabinetTargetRequired);

      final triaged =
          source.execute(
                SaveStructuredTriageIntent(
                  actionId: 'cabinet-triage',
                  accountScopeRef: first.requestingAccountScopeRef,
                  journeyRef: first.journeyRef,
                  attemptRef: draft.attemptRef,
                  triage: PatientTriageProjection(
                    minimum: StructuredTriageMinimumProjection(
                      bodyAreaCodes: const ['CHEST'],
                      painIntensity: 5,
                      painBandCode: 'SYNTHETIC_MODERATE_PENDING_APPROVAL',
                      painBandDisplayKey: 'p4_pain_medium',
                    ),
                  ),
                  expectedJourneyVersion: first.version,
                  expectedAttemptVersion: draft.version,
                ),
              )
              as UrgentUiCommandSuccess;
      final ready = triaged.projection;
      final readyAttempt = ready.activeAttempt as CabinetAttemptProjection;

      final targeted =
          source.execute(
                ChooseCabinetTargetIntent(
                  actionId: 'patient-target',
                  accountScopeRef: ready.requestingAccountScopeRef,
                  journeyRef: ready.journeyRef,
                  attemptRef: readyAttempt.attemptRef,
                  target: SyntheticUrgentJourneyFixtureSource
                      .syntheticCabinetTarget,
                  expectedJourneyVersion: ready.version,
                  expectedAttemptVersion: readyAttempt.version,
                ),
              )
              as UrgentUiCommandSuccess;
      final waiting = targeted.projection;
      final waitingAttempt = waiting.activeAttempt as CabinetAttemptProjection;
      final accepted = source.execute(
        AcceptCabinetTargetIntent(
          actionId: 'doctor-accept',
          accountScopeRef: SyntheticUrgentJourneyFixtureSource.doctorAccount,
          journeyRef: waiting.journeyRef,
          attemptRef: waitingAttempt.attemptRef,
          doctorRef: waitingAttempt.target!.doctorRef,
          expectedJourneyVersion: waiting.version,
          expectedAttemptVersion: waitingAttempt.version,
        ),
      );

      expect(accepted, isA<UrgentUiCommandSuccess>());
      final commitment =
          (accepted as UrgentUiCommandSuccess).projection.activeCommitment!;
      expect(commitment.mode, UrgentAttemptMode.cabinet);
      expect(commitment.approvedQuote, waitingAttempt.target!.quote);
      expect(source.snapshot().offeredDoctor, isNull);
      expect(source.snapshot().committedDoctor, isNotNull);
      expect(source.snapshot().committedDoctor!.homeDestination, isNull);
    });

    test('uncertain Doctor admission fails closed', () {
      final source = SyntheticUrgentJourneyFixtureSource(
        scenario: SyntheticUrgentScenario.unavailableAdmission,
      );
      final journey = source.snapshot().patientJourney!;
      final attempt = journey.activeAttempt as CabinetAttemptProjection;
      final result = source.execute(
        AcceptCabinetTargetIntent(
          actionId: 'uncertain-admission',
          accountScopeRef: SyntheticUrgentJourneyFixtureSource.doctorAccount,
          journeyRef: journey.journeyRef,
          attemptRef: attempt.attemptRef,
          doctorRef: attempt.target!.doctorRef,
          expectedJourneyVersion: journey.version,
          expectedAttemptVersion: attempt.version,
        ),
      );

      expect(_errorCode(result), UrgentSafeErrorCode.admissionUnavailable);
      expect(source.snapshot().patientJourney!.activeCommitment, isNull);
    });

    test('fallback creates a linked attempt without mutating prior mode', () {
      final source = SyntheticUrgentJourneyFixtureSource();
      final started =
          source.execute(
                const StartUrgentJourneyIntent(
                  actionId: 'start-home',
                  accountScopeRef:
                      SyntheticUrgentJourneyFixtureSource.patientAccount,
                  subjectSelectionRef:
                      SyntheticUrgentJourneyFixtureSource.selfSubject,
                  initialMode: UrgentAttemptMode.home,
                ),
              )
              as UrgentUiCommandSuccess;
      final first = started.projection;
      final result =
          source.execute(
                CreateFallbackAttemptIntent(
                  actionId: 'fallback-cabinet',
                  accountScopeRef: first.requestingAccountScopeRef,
                  journeyRef: first.journeyRef,
                  fromAttemptRef: first.activeAttemptRef,
                  toMode: UrgentAttemptMode.cabinet,
                  expectedJourneyVersion: first.version,
                ),
              )
              as UrgentUiCommandSuccess;

      expect(result.projection.journeyRef, first.journeyRef);
      expect(result.projection.attempts, hasLength(2));
      expect(result.projection.attempts.first.mode, UrgentAttemptMode.home);
      expect(result.projection.attempts.first.stage, UrgentAttemptStage.failed);
      expect(result.projection.activeAttempt.mode, UrgentAttemptMode.cabinet);
    });

    test('same action is replayed; changed payload with same ID conflicts', () {
      final source = SyntheticUrgentJourneyFixtureSource();
      const first = StartUrgentJourneyIntent(
        actionId: 'stable-action',
        accountScopeRef: SyntheticUrgentJourneyFixtureSource.patientAccount,
        subjectSelectionRef: SyntheticUrgentJourneyFixtureSource.selfSubject,
        initialMode: UrgentAttemptMode.home,
      );

      expect(source.execute(first), isA<UrgentUiCommandSuccess>());
      final replay = source.execute(first) as UrgentUiCommandSuccess;
      expect(replay.replayed, isTrue);
      final conflict = source.execute(
        const StartUrgentJourneyIntent(
          actionId: 'stable-action',
          accountScopeRef: SyntheticUrgentJourneyFixtureSource.patientAccount,
          subjectSelectionRef: SyntheticUrgentJourneyFixtureSource.selfSubject,
          initialMode: UrgentAttemptMode.cabinet,
        ),
      );
      expect(_errorCode(conflict), UrgentSafeErrorCode.duplicateActionConflict);
    });

    test('reconstruction preserves authoritative fixture snapshot', () {
      final source = SyntheticUrgentJourneyFixtureSource(
        scenario: SyntheticUrgentScenario.disconnectedReconstructed,
      );
      final before = source.snapshot();
      expect(before.connected, isFalse);

      final after = source.reconstruct();
      expect(after.connected, isTrue);
      expect(
        after.patientJourney!.journeyRef,
        before.patientJourney!.journeyRef,
      );
      expect(after.patientJourney!.version, before.patientJourney!.version);
      expect(
        after.patientJourney!.activeAttemptRef,
        before.patientJourney!.activeAttemptRef,
      );
    });
  });
}

UrgentSafeErrorCode? _errorCode(UrgentUiCommandResult result) =>
    switch (result) {
      UrgentUiCommandFailure(:final error) => error.code,
      UrgentUiCommandSuccess() => null,
    };
