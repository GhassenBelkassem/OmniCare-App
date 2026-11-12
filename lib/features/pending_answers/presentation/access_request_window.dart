import 'package:flutter/material.dart';

import '../../../core/theme/omni_theme.dart';
import '../../../l10n/omni_localizations.dart';
import '../application/pending_answer_problem.dart';
import '../application/pending_answers_controller.dart';
import '../data/pending_answers_models.dart';
import 'pending_answer_cards.dart';

/// G-1 D2 (B): the access-request window, in the existing sheet style. The
/// sheet is the confirmation: « Autoriser » answers directly. Closing it
/// leaves the request pending in « Mes rendez-vous ».
Future<void> showAccessRequestWindow(
  BuildContext context, {
  required PendingAnswersController controller,
  required PatientAccessRequest request,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  controller.windowOpen = true;
  try {
    final outcome = await showModalBottomSheet<PendingCardState>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          AccessRequestWindow(controller: controller, request: request),
    );
    final message = switch (outcome) {
      PendingCardState.accepted => 'Accès autorisé.',
      PendingCardState.refused => 'Demande refusée.',
      _ => null,
    };
    if (message != null) {
      messenger?.showSnackBar(SnackBar(content: Text(message)));
    }
  } finally {
    controller.windowOpen = false;
  }
}

class AccessRequestWindow extends StatelessWidget {
  const AccessRequestWindow({
    super.key,
    required this.controller,
    required this.request,
  });

  final PendingAnswersController controller;
  final PatientAccessRequest request;

  Future<void> _answer(BuildContext context, bool accept) async {
    final navigator = Navigator.of(context);
    await controller.answerAccessRequest(request.requestId, accept: accept);
    final state = controller.accessRequestState(request.requestId);
    if (state == PendingCardState.accepted ||
        state == PendingCardState.refused) {
      if (navigator.mounted) navigator.pop(state);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final theme = Theme.of(context);
      final current =
          controller.accessRequestById(request.requestId) ?? request;
      final state =
          controller.accessRequestState(request.requestId) ??
          PendingCardState.pending;
      final busy = controller.isBusy(request.requestId);
      final problem = controller.problemOf(request.requestId);
      final notActive = state == PendingCardState.notActive;
      return Container(
        key: const ValueKey('access-request-window'),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.86,
        ),
        decoration: const BoxDecoration(
          color: OmniColors.surfacePrimary,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(OmniRadii.sheet),
          ),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 10, 24, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 56,
                    height: 5,
                    decoration: BoxDecoration(
                      color: OmniColors.borderStrong,
                      borderRadius: BorderRadius.circular(OmniRadii.pill),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(
                        Icons.shield_outlined,
                        color: OmniColors.primaryAction,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Votre médecin demande l’accès à votre dossier',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      key: const ValueKey('access-request-window-close'),
                      tooltip: 'Fermer',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  current.doctor.nameAndSpecialty,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  current.subject.label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: OmniColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  notActive
                      ? notActiveMessage
                      : 'Il pourra consulter votre dossier médical pendant '
                            'cette consultation. L’accès prend fin à la fin de '
                            'la consultation.',
                  key: const ValueKey('access-request-window-text'),
                  style: theme.textTheme.bodyMedium,
                ),
                if (problem != null) ...[
                  const SizedBox(height: 10),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      pendingAnswerProblemMessage(
                        problem,
                        OmniLocalizations.of(context),
                      ),
                      key: const ValueKey('access-request-window-problem'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: OmniColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                if (!notActive)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          key: const ValueKey('access-request-window-refuse'),
                          onPressed: busy
                              ? null
                              : () => _answer(context, false),
                          child: const Text('Refuser'),
                        ),
                      ),
                      const SizedBox(width: OmniSpacing.sm),
                      Expanded(
                        child: FilledButton(
                          key: const ValueKey('access-request-window-accept'),
                          onPressed: busy ? null : () => _answer(context, true),
                          child: busy
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Autoriser'),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
