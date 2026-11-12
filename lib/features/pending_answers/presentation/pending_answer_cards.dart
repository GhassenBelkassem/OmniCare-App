import 'package:flutter/material.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/network/api_failure_message.dart';
import '../../../core/theme/omni_theme.dart';
import '../../../l10n/omni_localizations.dart';
import '../application/pending_answer_problem.dart';
import '../application/pending_answers_controller.dart';
import '../data/pending_answers_models.dart';
import 'pending_answers_format.dart';

/// French text of a failed answer (no server text, no code).
String pendingAnswerProblemMessage(
  PendingAnswerProblem problem,
  OmniLocalizations l10n,
) => switch (problem) {
  PendingAnswerProblem.notActive => notActiveMessage,
  PendingAnswerProblem.unavailable => unavailableMessage,
  // The app's existing offline message (api_failure_message.dart).
  PendingAnswerProblem.network => apiFailureMessage(
    const ApiFailure(kind: ApiFailureKind.network),
    l10n,
  ),
  PendingAnswerProblem.versionConflict ||
  PendingAnswerProblem.other => otherProblemMessage,
};

/// « Autoriser l'accès ? » before accepting from « Mes rendez-vous ».
Future<bool> confirmAccessRequest(
  BuildContext context,
  PatientAccessRequest request,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      key: const ValueKey('access-request-confirm-dialog'),
      title: const Text('Autoriser l’accès ?'),
      content: Text(
        '${request.doctor.name} pourra consulter votre dossier médical pendant '
        'cette consultation. L’accès prend fin à la fin de la consultation.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          key: const ValueKey('access-request-confirm'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Autoriser'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// « Refuser ce rendez-vous ? » before declining a follow-up proposal.
Future<bool> confirmProposalDecline(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      key: const ValueKey('follow-up-decline-dialog'),
      title: const Text('Refuser ce rendez-vous ?'),
      content: const Text('Le créneau sera libéré.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          key: const ValueKey('follow-up-decline-confirm'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Refuser'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// « Demande d'accès à votre dossier » card.
class AccessRequestCard extends StatelessWidget {
  const AccessRequestCard({
    super.key,
    required this.request,
    required this.state,
    required this.busy,
    required this.problem,
    required this.onAccept,
    required this.onRefuse,
  });

  final PatientAccessRequest request;
  final PendingCardState state;
  final bool busy;
  final PendingAnswerProblem? problem;
  final VoidCallback onAccept;
  final VoidCallback onRefuse;

  @override
  Widget build(BuildContext context) => _PendingCardFrame(
    cardKey: ValueKey('access-request-card-${request.requestId}'),
    icon: Icons.folder_shared_outlined,
    title: 'Demande d’accès à votre dossier',
    lines: [request.doctor.nameAndSpecialty, request.subject.label],
    state: state,
    outcome: switch (state) {
      PendingCardState.accepted => 'Accès autorisé.',
      PendingCardState.refused => 'Demande refusée.',
      PendingCardState.notActive => notActiveMessage,
      PendingCardState.pending => null,
    },
    busy: busy,
    problem: problem,
    secondaryLabel: 'Refuser',
    primaryLabel: 'Autoriser',
    secondaryKey: ValueKey('access-request-refuse-${request.requestId}'),
    primaryKey: ValueKey('access-request-accept-${request.requestId}'),
    onSecondary: onRefuse,
    onPrimary: onAccept,
  );
}

/// « Rendez-vous de contrôle proposé » card.
class FollowUpProposalCard extends StatelessWidget {
  const FollowUpProposalCard({
    super.key,
    required this.proposal,
    required this.state,
    required this.busy,
    required this.problem,
    required this.onConfirm,
    required this.onDecline,
    this.highlighted = false,
  });

  final FollowUpProposal proposal;
  final PendingCardState state;
  final bool busy;
  final PendingAnswerProblem? problem;
  final VoidCallback onConfirm;
  final VoidCallback onDecline;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final cabinet = [
      proposal.cabinet.name,
      proposal.cabinet.addressLine,
    ].where((value) => value.isNotEmpty).join(' · ');
    final deadline = proposal.proposalExpiresAt;
    return _PendingCardFrame(
      cardKey: ValueKey('follow-up-card-${proposal.appointmentId}'),
      icon: Icons.event_available_outlined,
      title: 'Rendez-vous de contrôle proposé',
      lines: [
        proposal.doctor.nameAndSpecialty,
        formatTunisDayTime(proposal.start),
        cabinet,
        if (deadline != null && state == PendingCardState.pending)
          'À confirmer avant ${formatTunisDayTime(deadline)}',
      ],
      emphasizedLine: 1,
      state: state,
      outcome: switch (state) {
        PendingCardState.accepted =>
          'Rendez-vous confirmé. Il apparaît dans « À venir ».',
        PendingCardState.refused => 'Rendez-vous refusé.',
        PendingCardState.notActive => notActiveMessage,
        PendingCardState.pending => null,
      },
      busy: busy,
      problem: problem,
      highlighted: highlighted,
      secondaryLabel: 'Refuser',
      primaryLabel: 'Confirmer',
      secondaryKey: ValueKey('follow-up-decline-${proposal.appointmentId}'),
      primaryKey: ValueKey('follow-up-confirm-${proposal.appointmentId}'),
      onSecondary: onDecline,
      onPrimary: onConfirm,
    );
  }
}

class _PendingCardFrame extends StatelessWidget {
  const _PendingCardFrame({
    required this.cardKey,
    required this.icon,
    required this.title,
    required this.lines,
    required this.state,
    required this.outcome,
    required this.busy,
    required this.problem,
    required this.secondaryLabel,
    required this.primaryLabel,
    required this.secondaryKey,
    required this.primaryKey,
    required this.onSecondary,
    required this.onPrimary,
    this.emphasizedLine,
    this.highlighted = false,
  });

  final Key cardKey;
  final IconData icon;
  final String title;
  final List<String> lines;
  final int? emphasizedLine;
  final PendingCardState state;
  final String? outcome;
  final bool busy;
  final PendingAnswerProblem? problem;
  final bool highlighted;
  final String secondaryLabel;
  final String primaryLabel;
  final Key secondaryKey;
  final Key primaryKey;
  final VoidCallback onSecondary;
  final VoidCallback onPrimary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final problem = this.problem;
    return Container(
      key: cardKey,
      padding: const EdgeInsets.all(OmniSpacing.base),
      decoration: BoxDecoration(
        color: OmniColors.surfacePrimary,
        borderRadius: BorderRadius.circular(OmniRadii.card),
        border: Border.all(
          color: highlighted ? OmniColors.freshMint : OmniColors.borderLight,
          width: highlighted ? 2 : 1,
        ),
        boxShadow: const [OmniColors.shadowSm],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: OmniColors.mintSoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 20, color: OmniColors.deepTeal),
                ),
              ),
              const SizedBox(width: OmniSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    for (var index = 0; index < lines.length; index++)
                      if (lines[index].isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            lines[index],
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: index == emphasizedLine
                                  ? OmniColors.textPrimary
                                  : OmniColors.textSecondary,
                              fontWeight: index == emphasizedLine
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                          ),
                        ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: OmniSpacing.md),
          if (outcome != null)
            Semantics(
              liveRegion: true,
              child: Row(
                children: [
                  Icon(
                    state == PendingCardState.accepted
                        ? Icons.check_circle_rounded
                        : Icons.info_outline_rounded,
                    size: 20,
                    color: state == PendingCardState.accepted
                        ? OmniColors.success
                        : OmniColors.textSecondary,
                  ),
                  const SizedBox(width: OmniSpacing.sm),
                  Expanded(
                    child: Text(
                      outcome!,
                      key: const ValueKey('pending-card-outcome'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    key: secondaryKey,
                    onPressed: busy ? null : onSecondary,
                    child: Text(secondaryLabel),
                  ),
                ),
                const SizedBox(width: OmniSpacing.sm),
                Expanded(
                  child: FilledButton(
                    key: primaryKey,
                    onPressed: busy ? null : onPrimary,
                    child: busy
                        ? const SizedBox.square(
                            key: ValueKey('pending-card-busy'),
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(primaryLabel),
                  ),
                ),
              ],
            ),
            if (problem != null) ...[
              const SizedBox(height: OmniSpacing.sm),
              Semantics(
                liveRegion: true,
                child: Text(
                  pendingAnswerProblemMessage(
                    problem,
                    OmniLocalizations.of(context),
                  ),
                  key: const ValueKey('pending-card-problem'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: OmniColors.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
