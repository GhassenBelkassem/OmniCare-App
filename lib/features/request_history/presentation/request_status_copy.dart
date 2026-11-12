import 'package:flutter/material.dart';

import '../../../core/theme/omni_theme.dart';
import '../../../l10n/omni_localizations.dart';
import '../../request_core/domain/request_vocabulary.dart';

class RequestStatusCopy {
  const RequestStatusCopy({
    required this.label,
    required this.description,
    required this.icon,
    required this.accent,
    required this.softBackground,
    required this.actionMessage,
  });

  final String label;
  final String description;
  final IconData icon;

  /// Semantic accent color for status-specific treatment (icon tint, pill bg).
  final Color accent;

  /// Soft tinted background for the status card.
  final Color softBackground;

  /// Patient-facing action/state message below the description.
  final String actionMessage;

  static RequestStatusCopy of(
    PatientRequestStatus status,
    OmniLocalizations l10n,
  ) => switch (status) {
    PatientRequestStatus.requestReceived => const RequestStatusCopy(
      label: 'Request received',
      description:
          'The clinic has received your request and will review it shortly.',
      icon: Icons.mark_email_read_outlined,
      accent: OmniColors.infoBlue,
      softBackground: OmniColors.infoBlueSoft,
      actionMessage: 'No action needed right now',
    ),
    PatientRequestStatus.underReview => const RequestStatusCopy(
      label: 'Under review',
      description:
          'The clinic has received your request and will review it shortly.',
      icon: Icons.hourglass_top_outlined,
      accent: OmniColors.infoBlue,
      softBackground: OmniColors.infoBlueSoft,
      actionMessage: 'No action needed right now',
    ),
    PatientRequestStatus.informationRequired => const RequestStatusCopy(
      label: 'More information needed',
      description: 'The clinic needs more information before continuing.',
      icon: Icons.info_outline,
      accent: OmniColors.amber,
      softBackground: OmniColors.amberSoft,
      actionMessage: 'Your response is needed',
    ),
    PatientRequestStatus.schedulingInProgress => const RequestStatusCopy(
      label: 'Scheduling',
      description: 'The clinic is arranging the next step.',
      icon: Icons.event_outlined,
      accent: OmniColors.clinicalCyan,
      softBackground: OmniColors.clinicalCyanSoft,
      actionMessage: 'The clinic is arranging the next step',
    ),
    PatientRequestStatus.waitingForConfirmation => const RequestStatusCopy(
      label: 'Waiting for confirmation',
      description: 'The clinic is waiting for your confirmation.',
      icon: Icons.pending_actions_outlined,
      accent: OmniColors.amber,
      softBackground: OmniColors.amberSoft,
      actionMessage: 'Your confirmation is needed',
    ),
    PatientRequestStatus.confirmed => const RequestStatusCopy(
      label: 'Confirmed',
      description: 'Your request has been confirmed.',
      icon: Icons.check_circle_outline,
      accent: OmniColors.freshMint,
      softBackground: OmniColors.mintSoft,
      actionMessage: 'Your request is confirmed',
    ),
    PatientRequestStatus.careInProgress => const RequestStatusCopy(
      label: 'Care in progress',
      description: 'Your care is currently in progress.',
      icon: Icons.medical_services_outlined,
      accent: OmniColors.clinicalCyan,
      softBackground: OmniColors.clinicalCyanSoft,
      actionMessage: 'Care is in progress',
    ),
    PatientRequestStatus.completed => const RequestStatusCopy(
      label: 'Completed',
      description: 'This request has been completed.',
      icon: Icons.task_alt_outlined,
      accent: OmniColors.freshMint,
      softBackground: OmniColors.mintSoft,
      actionMessage: 'Request completed',
    ),
    PatientRequestStatus.declined => const RequestStatusCopy(
      label: 'Request declined',
      description: 'The clinic could not proceed with this request.',
      icon: Icons.cancel_outlined,
      accent: OmniColors.urgentCoral,
      softBackground: OmniColors.urgentCoralSoft,
      actionMessage: 'Request ended',
    ),
    PatientRequestStatus.cancelled => const RequestStatusCopy(
      label: 'Cancelled',
      description: 'This request has been cancelled.',
      icon: Icons.do_not_disturb_on_outlined,
      accent: OmniColors.slateBlue,
      softBackground: OmniColors.slateSoft,
      actionMessage: 'Request cancelled',
    ),
    PatientRequestStatus.noShow => RequestStatusCopy(
      label: l10n.requestNoShowLabel,
      description: l10n.requestNoShowDescription,
      icon: Icons.event_busy_outlined,
      accent: OmniColors.slateBlue,
      softBackground: OmniColors.slateSoft,
      actionMessage: l10n.requestNoShowActionMessage,
    ),
    PatientRequestStatus.unknown => const RequestStatusCopy(
      label: 'Status updated',
      description: 'Check back for the latest request update.',
      icon: Icons.info_outline,
      accent: OmniColors.slateBlue,
      softBackground: OmniColors.slateSoft,
      actionMessage: 'Refresh for the latest status',
    ),
  };
}

String situationLabel(RequestSituation situation) => switch (situation) {
  RequestSituation.appointment => 'Planned care',
  RequestSituation.urgent => 'Urgent care',
  RequestSituation.ambulance => 'Medical transport',
  RequestSituation.unknown => 'Clinic request',
};
