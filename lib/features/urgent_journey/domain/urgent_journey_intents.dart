import 'urgent_journey_models.dart';

sealed class UrgentUiIntent {
  const UrgentUiIntent({required this.actionId, required this.accountScopeRef});

  final String actionId;
  final AccountScopeUiRef accountScopeRef;
  String get fingerprint;
}

final class StartUrgentJourneyIntent extends UrgentUiIntent {
  const StartUrgentJourneyIntent({
    required super.actionId,
    required super.accountScopeRef,
    required this.subjectSelectionRef,
    required this.initialMode,
  });

  final SubjectSelectionUiRef subjectSelectionRef;
  final UrgentAttemptMode initialMode;

  @override
  String get fingerprint =>
      'start:${accountScopeRef.value}:${subjectSelectionRef.value}:${initialMode.name}';
}

final class SaveStructuredTriageIntent extends UrgentUiIntent {
  const SaveStructuredTriageIntent({
    required super.actionId,
    required super.accountScopeRef,
    required this.journeyRef,
    required this.attemptRef,
    required this.triage,
    required this.expectedJourneyVersion,
    required this.expectedAttemptVersion,
  });

  final JourneyUiRef journeyRef;
  final AttemptUiRef attemptRef;
  final PatientTriageProjection triage;
  final int expectedJourneyVersion;
  final int expectedAttemptVersion;

  @override
  String get fingerprint =>
      'triage:${journeyRef.value}:${attemptRef.value}:'
      '${triage.minimum.bodyAreaCodes.join("|")}:'
      '${triage.minimum.painIntensity}:${triage.privateNarrative?.value ?? ""}:'
      '$expectedJourneyVersion:$expectedAttemptVersion';
}

final class ConfirmHomeDestinationIntent extends UrgentUiIntent {
  const ConfirmHomeDestinationIntent({
    required super.actionId,
    required super.accountScopeRef,
    required this.journeyRef,
    required this.attemptRef,
    required this.destination,
    required this.expectedJourneyVersion,
    required this.expectedAttemptVersion,
  });

  final JourneyUiRef journeyRef;
  final AttemptUiRef attemptRef;
  final HomeDestinationDraft destination;
  final int expectedJourneyVersion;
  final int expectedAttemptVersion;

  @override
  String get fingerprint =>
      'destination:${journeyRef.value}:${attemptRef.value}:'
      '${destination.source?.name}:${destination.latitude}:'
      '${destination.longitude}:$expectedJourneyVersion:$expectedAttemptVersion';
}

final class SelectHomeHoldIntent extends UrgentUiIntent {
  const SelectHomeHoldIntent({
    required super.actionId,
    required super.accountScopeRef,
    required this.journeyRef,
    required this.attemptRef,
    required this.holdRef,
    required this.expectedJourneyVersion,
    required this.expectedAttemptVersion,
  });

  final JourneyUiRef journeyRef;
  final AttemptUiRef attemptRef;
  final HoldUiRef holdRef;
  final int expectedJourneyVersion;
  final int expectedAttemptVersion;

  @override
  String get fingerprint =>
      'select:${journeyRef.value}:${attemptRef.value}:${holdRef.value}:'
      '$expectedJourneyVersion:$expectedAttemptVersion';
}

final class ChooseCabinetTargetIntent extends UrgentUiIntent {
  const ChooseCabinetTargetIntent({
    required super.actionId,
    required super.accountScopeRef,
    required this.journeyRef,
    required this.attemptRef,
    required this.target,
    required this.expectedJourneyVersion,
    required this.expectedAttemptVersion,
  });

  final JourneyUiRef journeyRef;
  final AttemptUiRef attemptRef;
  final CabinetTargetProjection target;
  final int expectedJourneyVersion;
  final int expectedAttemptVersion;

  @override
  String get fingerprint =>
      'target:${journeyRef.value}:${attemptRef.value}:'
      '${target.doctorRef.value}:${target.cabinetRef.value}:'
      '$expectedJourneyVersion:$expectedAttemptVersion';
}

final class AcceptCabinetTargetIntent extends UrgentUiIntent {
  const AcceptCabinetTargetIntent({
    required super.actionId,
    required super.accountScopeRef,
    required this.journeyRef,
    required this.attemptRef,
    required this.doctorRef,
    required this.expectedJourneyVersion,
    required this.expectedAttemptVersion,
  });

  final JourneyUiRef journeyRef;
  final AttemptUiRef attemptRef;
  final DoctorPublicUiRef doctorRef;
  final int expectedJourneyVersion;
  final int expectedAttemptVersion;

  @override
  String get fingerprint =>
      'cabinet-accept:${journeyRef.value}:${attemptRef.value}:'
      '${doctorRef.value}:$expectedJourneyVersion:$expectedAttemptVersion';
}

final class CreateFallbackAttemptIntent extends UrgentUiIntent {
  const CreateFallbackAttemptIntent({
    required super.actionId,
    required super.accountScopeRef,
    required this.journeyRef,
    required this.fromAttemptRef,
    required this.toMode,
    required this.expectedJourneyVersion,
  });

  final JourneyUiRef journeyRef;
  final AttemptUiRef fromAttemptRef;
  final UrgentAttemptMode toMode;
  final int expectedJourneyVersion;

  @override
  String get fingerprint =>
      'fallback:${journeyRef.value}:${fromAttemptRef.value}:${toMode.name}:'
      '$expectedJourneyVersion';
}

sealed class UrgentUiCommandResult {
  const UrgentUiCommandResult();
}

final class UrgentUiCommandSuccess extends UrgentUiCommandResult {
  const UrgentUiCommandSuccess({
    required this.projection,
    this.replayed = false,
  });

  final PatientUrgentJourneyProjection projection;
  final bool replayed;
}

final class UrgentUiCommandFailure extends UrgentUiCommandResult {
  const UrgentUiCommandFailure({required this.error, this.latestProjection});

  final UrgentSafeError error;
  final PatientUrgentJourneyProjection? latestProjection;
}
