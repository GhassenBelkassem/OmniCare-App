import 'package:flutter/foundation.dart';

import 'urgent_cabinet_request_review.dart';
import 'urgent_cabinet_targeted_request_models.dart';

enum UrgentCabinetRequestPhase {
  draft,
  submitting,
  pendingDoctorResponse,
  accepted,
  declined,
  cancelled,
  expired,
  unavailable,
  submissionFailed,
}

enum UrgentCabinetSubmissionFailureKind {
  definitelyNotSubmitted,
  unknownOutcome,
}

/// P4-only presentation state for one urgent CABINET request attempt.
///
/// Development fixtures remain local, while service-backed states retain the
/// exact immutable backend snapshot used to build the frozen presentation.
@immutable
sealed class UrgentCabinetRequestState {
  const UrgentCabinetRequestState();

  UrgentCabinetRequestPhase get phase;

  UrgentCabinetRequestReview? get review => null;

  int? get localAttemptGeneration => null;
}

final class UrgentCabinetRequestDraft extends UrgentCabinetRequestState {
  const UrgentCabinetRequestDraft();

  @override
  UrgentCabinetRequestPhase get phase => UrgentCabinetRequestPhase.draft;
}

final class UrgentCabinetRequestAuthorityUnavailable
    extends UrgentCabinetRequestState {
  const UrgentCabinetRequestAuthorityUnavailable({required this.message});

  final String message;

  @override
  UrgentCabinetRequestPhase get phase => UrgentCabinetRequestPhase.unavailable;
}

@immutable
sealed class UrgentCabinetRequestAttemptState
    extends UrgentCabinetRequestState {
  const UrgentCabinetRequestAttemptState({
    required this.review,
    required this.localAttemptGeneration,
    required this.isDevelopmentSimulation,
    this.authoritativeSnapshot,
  });

  @override
  final UrgentCabinetRequestReview review;

  @override
  final int localAttemptGeneration;

  final bool isDevelopmentSimulation;

  final UrgentCabinetTargetedRequestSnapshot? authoritativeSnapshot;

  bool get isAuthoritative =>
      !isDevelopmentSimulation && authoritativeSnapshot != null;
}

final class UrgentCabinetRequestSubmitting
    extends UrgentCabinetRequestAttemptState {
  const UrgentCabinetRequestSubmitting({
    required super.review,
    required super.localAttemptGeneration,
    required super.isDevelopmentSimulation,
    super.authoritativeSnapshot,
  });

  @override
  UrgentCabinetRequestPhase get phase => UrgentCabinetRequestPhase.submitting;
}

final class UrgentCabinetRequestPendingDoctorResponse
    extends UrgentCabinetRequestAttemptState {
  const UrgentCabinetRequestPendingDoctorResponse({
    required super.review,
    required super.localAttemptGeneration,
    required super.isDevelopmentSimulation,
    super.authoritativeSnapshot,
  });

  @override
  UrgentCabinetRequestPhase get phase =>
      UrgentCabinetRequestPhase.pendingDoctorResponse;
}

final class UrgentCabinetRequestSubmissionFailed
    extends UrgentCabinetRequestAttemptState {
  const UrgentCabinetRequestSubmissionFailed({
    required super.review,
    required super.localAttemptGeneration,
    required super.isDevelopmentSimulation,
    super.authoritativeSnapshot,
    required this.kind,
    required this.message,
  });

  final UrgentCabinetSubmissionFailureKind kind;
  final String message;

  @override
  UrgentCabinetRequestPhase get phase =>
      UrgentCabinetRequestPhase.submissionFailed;
}

/// Reserved typed states for later P4 steps. No UI transition creates them in
/// P4-UI-06.
final class UrgentCabinetRequestAccepted
    extends UrgentCabinetRequestAttemptState {
  const UrgentCabinetRequestAccepted({
    required super.review,
    required super.localAttemptGeneration,
    required super.isDevelopmentSimulation,
    super.authoritativeSnapshot,
  });

  @override
  UrgentCabinetRequestPhase get phase => UrgentCabinetRequestPhase.accepted;
}

final class UrgentCabinetRequestDeclined
    extends UrgentCabinetRequestAttemptState {
  const UrgentCabinetRequestDeclined({
    required super.review,
    required super.localAttemptGeneration,
    required super.isDevelopmentSimulation,
    super.authoritativeSnapshot,
  });

  @override
  UrgentCabinetRequestPhase get phase => UrgentCabinetRequestPhase.declined;
}

final class UrgentCabinetRequestCancelled
    extends UrgentCabinetRequestAttemptState {
  const UrgentCabinetRequestCancelled({
    required super.review,
    required super.localAttemptGeneration,
    required super.isDevelopmentSimulation,
    required super.authoritativeSnapshot,
  });

  @override
  UrgentCabinetRequestPhase get phase => UrgentCabinetRequestPhase.cancelled;
}

final class UrgentCabinetRequestExpired
    extends UrgentCabinetRequestAttemptState {
  const UrgentCabinetRequestExpired({
    required super.review,
    required super.localAttemptGeneration,
    required super.isDevelopmentSimulation,
    required super.authoritativeSnapshot,
  });

  @override
  UrgentCabinetRequestPhase get phase => UrgentCabinetRequestPhase.expired;
}

final class UrgentCabinetRequestUnavailable
    extends UrgentCabinetRequestAttemptState {
  const UrgentCabinetRequestUnavailable({
    required super.review,
    required super.localAttemptGeneration,
    required super.isDevelopmentSimulation,
  });

  @override
  UrgentCabinetRequestPhase get phase => UrgentCabinetRequestPhase.unavailable;
}
