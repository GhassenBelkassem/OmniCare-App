import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/omni_theme.dart';
import '../application/pending_answer_problem.dart';
import '../application/pending_answers_controller.dart';
import 'pending_answer_cards.dart';

/// G-1 D2 / D4: « En attente de votre réponse » at the top of
/// « Mes rendez-vous ». Shown only when something is pending (or was just
/// answered here). Refreshes when the screen opens and when the app resumes;
/// pull down on it to refresh.
class PendingAnswersSection extends StatefulWidget {
  const PendingAnswersSection({super.key, this.onProposalConfirmed});

  /// Called after a follow-up is confirmed, so « À venir » shows it.
  final Future<void> Function()? onProposalConfirmed;

  @override
  State<PendingAnswersSection> createState() => _PendingAnswersSectionState();
}

class _PendingAnswersSectionState extends State<PendingAnswersSection>
    with WidgetsBindingObserver {
  PendingAnswersController? _controller;
  final Map<String, GlobalKey> _proposalKeys = {};
  String? _highlighted;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = context.read<PendingAnswersController?>();
    _controller?.addListener(_onControllerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = _controller;
      if (controller == null) return;
      _showInfo();
      unawaited(controller.refresh(keepAnswered: false));
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.removeListener(_onControllerChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_controller?.refresh());
    }
  }

  void _onControllerChanged() {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _showInfo();
      _scrollToFocus();
    });
  }

  void _showInfo() {
    final message = _controller?.takeInfo();
    if (message == null) return;
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        key: const ValueKey('pending-answers-info'),
        content: Text(message),
      ),
    );
  }

  /// Push « FOLLOW_UP_PROPOSED »: scroll to the proposal, or say it is gone.
  void _scrollToFocus() {
    final controller = _controller;
    final id = controller?.focusProposalId;
    if (controller == null || id == null) return;
    if (!controller.hasLoaded || controller.isLoading) return;
    controller.clearFocus();
    final pending = controller.proposals.any(
      (entry) =>
          entry.item.appointmentId == id &&
          entry.state == PendingCardState.pending,
    );
    if (!pending) {
      controller.showInfo(notActiveMessage);
      return;
    }
    setState(() => _highlighted = id);
    final target = _proposalKeys[id]?.currentContext;
    if (target != null) {
      unawaited(
        Scrollable.ensureVisible(
          target,
          duration: const Duration(milliseconds: 250),
          alignment: 0.1,
        ),
      );
    }
  }

  Future<void> _acceptAccess(PendingAnswersController controller, String id) {
    final request = controller.accessRequestById(id);
    if (request == null) return Future.value();
    return confirmAccessRequest(context, request).then((confirmed) {
      if (confirmed && mounted) {
        return controller.answerAccessRequest(id, accept: true);
      }
    });
  }

  Future<void> _confirmProposal(
    PendingAnswersController controller,
    String id,
  ) async {
    await controller.answerFollowUpProposal(id, accept: true);
    final confirmed = controller.proposals.any(
      (entry) =>
          entry.item.appointmentId == id &&
          entry.state == PendingCardState.accepted,
    );
    if (confirmed) await widget.onProposalConfirmed?.call();
  }

  Future<void> _declineProposal(
    PendingAnswersController controller,
    String id,
  ) async {
    if (!await confirmProposalDecline(context) || !mounted) return;
    await controller.answerFollowUpProposal(id, accept: false);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PendingAnswersController?>();
    if (controller == null || (controller.isEmpty && !controller.loadFailed)) {
      return const SizedBox.shrink(key: ValueKey('pending-answers-hidden'));
    }
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.45,
      ),
      child: RefreshIndicator(
        onRefresh: () => controller.refresh(keepAnswered: false),
        child: SingleChildScrollView(
          key: const ValueKey('pending-answers-section'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            OmniSpacing.pageHorizontal,
            OmniSpacing.xs,
            OmniSpacing.pageHorizontal,
            OmniSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                header: true,
                child: Text(
                  'En attente de votre réponse',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: OmniColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: OmniSpacing.sm),
              if (controller.loadFailed) ...[
                Semantics(
                  liveRegion: true,
                  child: Text(
                    'Impossible de charger vos demandes. Tirez pour actualiser.',
                    key: const ValueKey('pending-answers-load-failed'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: OmniColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: OmniSpacing.sm),
              ],
              for (final entry in controller.accessRequests) ...[
                AccessRequestCard(
                  request: entry.item,
                  state: entry.state,
                  busy: controller.isBusy(entry.item.requestId),
                  problem: controller.problemOf(entry.item.requestId),
                  onAccept: () =>
                      _acceptAccess(controller, entry.item.requestId),
                  onRefuse: () => controller.answerAccessRequest(
                    entry.item.requestId,
                    accept: false,
                  ),
                ),
                const SizedBox(height: OmniSpacing.sm),
              ],
              for (final entry in controller.proposals) ...[
                FollowUpProposalCard(
                  key: _proposalKeys.putIfAbsent(
                    entry.item.appointmentId,
                    GlobalKey.new,
                  ),
                  proposal: entry.item,
                  state: entry.state,
                  busy: controller.isBusy(entry.item.appointmentId),
                  problem: controller.problemOf(entry.item.appointmentId),
                  highlighted: _highlighted == entry.item.appointmentId,
                  onConfirm: () =>
                      _confirmProposal(controller, entry.item.appointmentId),
                  onDecline: () =>
                      _declineProposal(controller, entry.item.appointmentId),
                ),
                const SizedBox(height: OmniSpacing.sm),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
