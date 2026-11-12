import 'package:flutter/material.dart';

import '../../../core/network/api_failure.dart';
import '../../patient_appointments/presentation/patient_appointments_screen.dart';
import '../application/pending_answer_problem.dart';
import '../application/pending_answers_controller.dart';
import 'access_request_window.dart';

/// Info shown by « Mes rendez-vous » after a FOLLOW_UP_WITHDRAWN push.
const String followUpWithdrawnMessage =
    'Un rendez-vous de contrôle proposé a été annulé par le cabinet.';

/// G-1 D2 / D4 entry points: app open / resume (window B) and the three
/// pushes (E). Push payloads are ids only; every state is read from the API.
abstract final class PendingAnswersEntry {
  /// App opened or back in the foreground: show the newest pending access
  /// request not shown yet in this app session.
  static Future<void> offerAccessRequestWindow(
    NavigatorState navigator,
    PendingAnswersController controller,
  ) async {
    if (controller.isWindowOpen) return;
    await controller.refresh();
    if (!navigator.mounted) return;
    final request = controller.takeWindowCandidate();
    if (request == null) return;
    await showAccessRequestWindow(
      navigator.context,
      controller: controller,
      request: request,
    );
  }

  /// ACCESS_REQUESTED: the window if still pending, else « Mes rendez-vous »
  /// with « Cette demande n'est plus active. ».
  static Future<void> openAccessRequest(
    NavigatorState navigator,
    PendingAnswersController controller,
    String requestId,
  ) async {
    try {
      final request = await controller.readAccessRequest(requestId);
      if (!navigator.mounted) return;
      if (request.isPending) {
        if (controller.isWindowOpen) return;
        controller.markOffered(request.requestId);
        await showAccessRequestWindow(
          navigator.context,
          controller: controller,
          request: controller.accessRequestById(request.requestId) ?? request,
        );
        return;
      }
      controller.showInfo(notActiveMessage);
    } catch (error) {
      if (pendingAnswerProblemOf(ApiFailure.from(error)) ==
          PendingAnswerProblem.notActive) {
        controller.showInfo(notActiveMessage);
      }
    }
    if (navigator.mounted) await openAppointments(navigator);
  }

  /// FOLLOW_UP_PROPOSED: « Mes rendez-vous » scrolled to the proposal.
  static Future<void> openFollowUpProposal(
    NavigatorState navigator,
    PendingAnswersController controller,
    String appointmentId,
  ) {
    controller.focusProposal(appointmentId);
    return openAppointments(navigator);
  }

  /// FOLLOW_UP_WITHDRAWN: « Mes rendez-vous » with an info message.
  static Future<void> openFollowUpWithdrawn(
    NavigatorState navigator,
    PendingAnswersController controller,
  ) {
    controller.showInfo(followUpWithdrawnMessage);
    return openAppointments(navigator);
  }

  /// The same screen as Profil → Activité → « Mes rendez-vous ».
  static Future<void> openAppointments(NavigatorState navigator) =>
      navigator.push<void>(
        MaterialPageRoute(builder: (_) => const PatientAppointmentsScreen()),
      );
}
