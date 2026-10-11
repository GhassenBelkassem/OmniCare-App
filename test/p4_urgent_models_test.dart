import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/features/urgent_journey/domain/urgent_journey_models.dart';

void main() {
  test('offered Doctor projection contains only the pre-commit allowlist', () {
    final projection = OfferedDoctorUrgentProjection(
      offerRef: const OfferUiRef('offer-ui'),
      attemptRef: const AttemptUiRef('attempt-ui'),
      mode: UrgentAttemptMode.home,
      version: 3,
      triage: StructuredTriageMinimumProjection(
        bodyAreaCodes: const ['CHEST'],
        painIntensity: 8,
        painBandCode: 'SEVERE_PENDING_APPROVAL',
        painBandDisplayKey: 'p4_pain_severe',
      ),
      coarseZoneOrEta: 'Zone Nord · 10–15 min',
      applicableQuote: const UrgentFeeQuote(
        context: UrgentFeeContext.home,
        amountMinor: 12000,
        currency: 'TND',
        feeVersion: 4,
      ),
      respondBy: DateTime.utc(2026, 10, 10, 9, 2),
      admission: DoctorAdmissionSnapshot(
        state: DoctorAdmissionState.available,
        version: 8,
        observedAt: DateTime.utc(2026, 10, 10, 9),
        dependencyCertain: true,
      ),
    );

    expect(projection.triage.safeFields.keys, {
      'bodyAreaCodes',
      'painIntensity',
      'painBandCode',
    });
    expect(projection.coarseZoneOrEta, isNotEmpty);
    expect(projection.applicableQuote.feeVersion, 4);
  });

  test('HOME and CABINET quotes remain independent versioned snapshots', () {
    const home = UrgentFeeQuote(
      context: UrgentFeeContext.home,
      amountMinor: 12000,
      currency: 'TND',
      feeVersion: 4,
    );
    const cabinet = UrgentFeeQuote(
      context: UrgentFeeContext.cabinet,
      amountMinor: 8000,
      currency: 'TND',
      feeVersion: 2,
    );

    expect(home, isNot(cabinet));
    expect(home.displayAmount, '120.00 TND');
    expect(cabinet.displayAmount, '80.00 TND');
  });

  test('admission uncertainty never implies Doctor availability', () {
    final snapshot = DoctorAdmissionSnapshot(
      state: DoctorAdmissionState.available,
      version: 2,
      observedAt: DateTime.utc(2026, 10, 10, 9),
      dependencyCertain: false,
    );

    expect(snapshot.canAccept, isFalse);
  });

  test('CABINET Doctor-waiting state cannot exist without Patient target', () {
    expect(
      () => CabinetAttemptProjection(
        attemptRef: const AttemptUiRef('attempt-ui'),
        ordinal: 1,
        version: 1,
        stage: UrgentAttemptStage.awaitingCabinetDoctor,
        policyFixtureName: 'synthetic-policy',
        triage: PatientTriageProjection(
          minimum: StructuredTriageMinimumProjection(
            bodyAreaCodes: const ['CHEST'],
            painIntensity: 8,
            painBandCode: 'SEVERE_PENDING_APPROVAL',
            painBandDisplayKey: 'p4_pain_severe',
          ),
        ),
        recoveryChoices: const {UrgentRecoveryChoice.cancel},
      ),
      throwsAssertionError,
    );
  });

  test('committed CABINET projection cannot expose HOME destination', () {
    const quote = UrgentFeeQuote(
      context: UrgentFeeContext.cabinet,
      amountMinor: 8000,
      currency: 'TND',
      feeVersion: 2,
    );
    final commitment = UrgentCommitmentProjection(
      commitmentRef: const CommitmentUiRef('commitment-ui'),
      sourceAttemptRef: const AttemptUiRef('attempt-ui'),
      mode: UrgentAttemptMode.cabinet,
      doctorRef: const DoctorPublicUiRef('doctor-ui'),
      approvedQuote: quote,
      version: 1,
      committedAt: DateTime.utc(2026, 10, 10, 9),
    );

    expect(
      () => CommittedDoctorUrgentProjection(
        commitment: commitment,
        subjectDisplayLabel: 'Sujet synthétique',
        triage: StructuredTriageMinimumProjection(
          bodyAreaCodes: const ['CHEST'],
          painIntensity: 8,
          painBandCode: 'SEVERE_PENDING_APPROVAL',
          painBandDisplayKey: 'p4_pain_severe',
        ),
        admission: DoctorAdmissionSnapshot(
          state: DoctorAdmissionState.cabinetCommitted,
          version: 3,
          observedAt: DateTime.utc(2026, 10, 10, 9),
          dependencyCertain: true,
        ),
        homeDestination: HomeDestinationDraft(
          permission: HomeLocationPermission.granted,
          service: HomeLocationService.available,
          quality: HomeLocationQuality.fresh,
          status: HomeDestinationStatus.confirmed,
          source: HomeDestinationSource.syntheticGps,
          displayAddress: 'Adresse synthétique',
          latitude: 36.8,
          longitude: 10.18,
          capturedAt: DateTime.utc(2026, 10, 10, 9),
        ),
      ),
      throwsAssertionError,
    );
  });
}
