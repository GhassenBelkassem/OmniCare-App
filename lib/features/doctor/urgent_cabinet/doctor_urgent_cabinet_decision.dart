import 'package:flutter/foundation.dart';

import 'doctor_urgent_cabinet_commitment.dart';
import 'doctor_urgent_cabinet_request.dart';

enum DoctorUrgentCabinetDecisionAction { accept, refuse }

@immutable
sealed class DoctorUrgentCabinetDecisionState {
  const DoctorUrgentCabinetDecisionState(this.request);

  final DoctorUrgentCabinetRequest request;

  bool get isTerminal => false;
}

final class DoctorUrgentCabinetAwaitingDecision
    extends DoctorUrgentCabinetDecisionState {
  const DoctorUrgentCabinetAwaitingDecision(super.request);
}

final class DoctorUrgentCabinetDecisionInProgress
    extends DoctorUrgentCabinetDecisionState {
  const DoctorUrgentCabinetDecisionInProgress(
    super.request, {
    required this.action,
    required this.operationGeneration,
  });

  final DoctorUrgentCabinetDecisionAction action;
  final int operationGeneration;
}

final class DoctorUrgentCabinetAccepted
    extends DoctorUrgentCabinetDecisionState {
  const DoctorUrgentCabinetAccepted(super.request, {this.commitment});

  final DoctorUrgentCabinetCommitment? commitment;

  @override
  bool get isTerminal => true;
}

final class DoctorUrgentCabinetCapacityBlocked
    extends DoctorUrgentCabinetDecisionState {
  const DoctorUrgentCabinetCapacityBlocked(
    super.request, {
    required this.message,
  });

  final String message;
}

final class DoctorUrgentCabinetDeclined
    extends DoctorUrgentCabinetDecisionState {
  const DoctorUrgentCabinetDeclined(super.request);

  @override
  bool get isTerminal => true;
}

final class DoctorUrgentCabinetUnavailable
    extends DoctorUrgentCabinetDecisionState {
  const DoctorUrgentCabinetUnavailable(super.request);

  @override
  bool get isTerminal => true;
}

final class DoctorUrgentCabinetDecisionFailed
    extends DoctorUrgentCabinetDecisionState {
  const DoctorUrgentCabinetDecisionFailed(
    super.request, {
    required this.action,
    required this.message,
  });

  final DoctorUrgentCabinetDecisionAction action;
  final String message;
}

final class DoctorUrgentCabinetDecisionOutcomeUnknown
    extends DoctorUrgentCabinetDecisionState {
  const DoctorUrgentCabinetDecisionOutcomeUnknown(
    super.request, {
    required this.action,
    required this.message,
  });

  final DoctorUrgentCabinetDecisionAction action;
  final String message;
}
