import 'package:flutter/foundation.dart';

import 'urgent_cabinet_request_review.dart';
import 'urgent_cabinet_request_state.dart';

enum UrgentCabinetDevelopmentSubmissionScenario {
  acknowledged,
  definitelyNotSubmitted,
  unknownOutcome,
}

@immutable
sealed class UrgentCabinetSubmissionOutcome {
  const UrgentCabinetSubmissionOutcome();
}

final class UrgentCabinetSubmissionAcknowledged
    extends UrgentCabinetSubmissionOutcome {
  const UrgentCabinetSubmissionAcknowledged();
}

final class UrgentCabinetSubmissionRejected
    extends UrgentCabinetSubmissionOutcome {
  const UrgentCabinetSubmissionRejected({
    required this.kind,
    required this.message,
  });

  final UrgentCabinetSubmissionFailureKind kind;
  final String message;
}

/// Injectable P4-only boundary for the static submission acknowledgement.
///
/// No implementation in P4-UI-06 performs HTTP, WebSocket, notification, or
/// persistence work.
abstract class UrgentCabinetRequestSource {
  const UrgentCabinetRequestSource();

  bool get isDevelopmentFixture;

  Future<UrgentCabinetSubmissionOutcome> submit(
    UrgentCabinetRequestReview review,
  );
}

class UrgentCabinetDevelopmentRequestSource extends UrgentCabinetRequestSource {
  const UrgentCabinetDevelopmentRequestSource({
    this.scenario = UrgentCabinetDevelopmentSubmissionScenario.acknowledged,
  });

  final UrgentCabinetDevelopmentSubmissionScenario scenario;

  @override
  bool get isDevelopmentFixture => true;

  @override
  Future<UrgentCabinetSubmissionOutcome> submit(
    UrgentCabinetRequestReview review,
  ) {
    return Future.value(switch (scenario) {
      UrgentCabinetDevelopmentSubmissionScenario.acknowledged =>
        const UrgentCabinetSubmissionAcknowledged(),
      UrgentCabinetDevelopmentSubmissionScenario.definitelyNotSubmitted =>
        const UrgentCabinetSubmissionRejected(
          kind: UrgentCabinetSubmissionFailureKind.definitelyNotSubmitted,
          message:
              "La simulation n'a pas pu démarrer. Aucune demande réelle n'a été créée.",
        ),
      UrgentCabinetDevelopmentSubmissionScenario.unknownOutcome =>
        const UrgentCabinetSubmissionRejected(
          kind: UrgentCabinetSubmissionFailureKind.unknownOutcome,
          message:
              "Le résultat de cette tentative locale ne peut pas être vérifié. N'envoyez pas une nouvelle demande.",
        ),
    });
  }
}

class UrgentCabinetUnavailableRequestSource extends UrgentCabinetRequestSource {
  const UrgentCabinetUnavailableRequestSource();

  @override
  bool get isDevelopmentFixture => false;

  @override
  Future<UrgentCabinetSubmissionOutcome> submit(
    UrgentCabinetRequestReview review,
  ) async {
    return const UrgentCabinetSubmissionRejected(
      kind: UrgentCabinetSubmissionFailureKind.definitelyNotSubmitted,
      message:
          "L'envoi d'une demande urgente n'est pas disponible dans cet environnement. Aucune demande n'a été créée.",
    );
  }
}

abstract final class UrgentCabinetRequestSources {
  static UrgentCabinetRequestSource forCurrentBuild() {
    return forBuild(enableDevelopmentFixtures: kDebugMode);
  }

  @visibleForTesting
  static UrgentCabinetRequestSource forBuild({
    required bool enableDevelopmentFixtures,
  }) {
    return enableDevelopmentFixtures
        ? const UrgentCabinetDevelopmentRequestSource()
        : const UrgentCabinetUnavailableRequestSource();
  }
}
