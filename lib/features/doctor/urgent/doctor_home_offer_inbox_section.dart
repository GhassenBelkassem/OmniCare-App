import 'package:flutter/material.dart';

import '../../../core/theme/omni_theme.dart';
import 'doctor_home_offer.dart';
import 'doctor_home_offer_inbox_controller.dart';
import 'doctor_home_offer_repository.dart';

class DoctorHomeOfferInboxSection extends StatefulWidget {
  const DoctorHomeOfferInboxSection({super.key, required this.controller});

  final DoctorHomeOfferInboxController controller;

  @override
  State<DoctorHomeOfferInboxSection> createState() =>
      _DoctorHomeOfferInboxSectionState();
}

class _DoctorHomeOfferInboxSectionState
    extends State<DoctorHomeOfferInboxSection> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.controller.activate();
    });
  }

  @override
  void didUpdateWidget(covariant DoctorHomeOfferInboxSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.deactivate();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.controller.activate();
      });
    }
  }

  @override
  void dispose() {
    widget.controller.deactivate();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) => _content(context),
  );

  Widget _content(BuildContext context) {
    final controller = widget.controller;
    return Semantics(
      container: true,
      liveRegion: true,
      label: 'Offres HOME, statut et réponses sécurisées',
      child: Container(
        key: const ValueKey('doctor-home-offer-inbox'),
        width: double.infinity,
        padding: const EdgeInsets.all(OmniSpacing.lg),
        decoration: BoxDecoration(
          color: OmniColors.surfacePrimary,
          borderRadius: BorderRadius.circular(OmniRadii.card),
          border: Border.all(color: OmniColors.borderLight),
          boxShadow: const [OmniColors.shadowCard],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: OmniColors.mintSoft,
                  child: Icon(
                    Icons.mark_email_unread_outlined,
                    color: OmniColors.deepTeal,
                  ),
                ),
                const SizedBox(width: OmniSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Offres HOME',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Statut serveur et réponses sécurisées',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: OmniColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: const ValueKey('doctor-home-offer-refresh'),
                  tooltip: 'Actualiser les offres HOME',
                  onPressed:
                      controller.state == DoctorHomeOfferInboxState.loading
                      ? null
                      : controller.refresh,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: OmniSpacing.md),
            Text(
              'La réception d’une offre ne constitue ni une acceptation, ni une sélection par le Patient, ni un engagement.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: OmniColors.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: OmniSpacing.lg),
            switch (controller.state) {
              DoctorHomeOfferInboxState.loading => const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: OmniSpacing.xl),
                  child: CircularProgressIndicator(),
                ),
              ),
              DoctorHomeOfferInboxState.empty => const _InboxMessage(
                icon: Icons.inbox_outlined,
                title: 'Aucune offre HOME en cours',
                message:
                    'Un inbox vide est un état serveur valide. Aucune offre de démonstration n’est ajoutée.',
              ),
              DoctorHomeOfferInboxState.unavailable => _InboxMessage(
                icon: Icons.lock_outline_rounded,
                title: 'Lecture indisponible',
                message:
                    controller.message ??
                    'La lecture HOME n’est pas activée sur cet environnement.',
              ),
              DoctorHomeOfferInboxState.failure => _InboxFailure(
                message:
                    controller.message ??
                    'Les offres HOME ne peuvent pas être chargées.',
                onRetry: controller.refresh,
              ),
              DoctorHomeOfferInboxState.ready => Column(
                children: [
                  for (final offer in controller.offers) ...[
                    _DoctorHomeOfferCard(
                      offer: offer,
                      loadingDetail:
                          controller.detailLoadingOfferId == offer.offerId,
                      onOpen: () => _openDetail(context, offer.offerId),
                    ),
                    if (offer != controller.offers.last)
                      const SizedBox(height: OmniSpacing.md),
                  ],
                  if (controller.message != null) ...[
                    const SizedBox(height: OmniSpacing.md),
                    Text(
                      controller.message!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: OmniColors.urgentCoral,
                      ),
                    ),
                  ],
                  if (controller.canLoadMore || controller.isLoadingMore) ...[
                    const SizedBox(height: OmniSpacing.lg),
                    OutlinedButton.icon(
                      key: const ValueKey('doctor-home-offer-load-more'),
                      onPressed: controller.canLoadMore
                          ? controller.loadMore
                          : null,
                      icon: controller.isLoadingMore
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.expand_more_rounded),
                      label: const Text('Afficher plus'),
                    ),
                  ],
                ],
              ),
              DoctorHomeOfferInboxState.detached ||
              DoctorHomeOfferInboxState.initial => const SizedBox.shrink(),
            },
          ],
        ),
      ),
    );
  }

  Future<void> _openDetail(BuildContext context, String offerId) async {
    final result = await widget.controller.loadDetail(offerId);
    if (!context.mounted) return;
    switch (result) {
      case DoctorHomeOfferDetailLoaded(:final offer):
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (context) => _DoctorHomeOfferDetail(
            initialOffer: offer,
            controller: widget.controller,
          ),
        );
      case DoctorHomeOfferDetailUnavailable(:final message):
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(message)));
    }
  }
}

class _DoctorHomeOfferCard extends StatelessWidget {
  const _DoctorHomeOfferCard({
    required this.offer,
    required this.loadingDetail,
    required this.onOpen,
  });

  final DoctorHomeOffer offer;
  final bool loadingDetail;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final accepted = offer.isAcceptedHold;
    final currentlyValid = accepted && offer.holdCurrentlyValid;
    final accent = offer.isPending
        ? OmniColors.urgentCoral
        : currentlyValid
        ? OmniColors.deepTeal
        : OmniColors.amber;
    final background = offer.isPending
        ? OmniColors.urgentCoralSoft
        : currentlyValid
        ? OmniColors.mintSoft
        : OmniColors.amberSoft;
    final deadline = offer.isPending
        ? offer.responseDeadlineAt
        : offer.holdExpiresAt;
    return Container(
      key: ValueKey('doctor-home-offer-${offer.offerId}'),
      width: double.infinity,
      padding: const EdgeInsets.all(OmniSpacing.md),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(OmniRadii.card),
        border: Border.all(color: accent.withValues(alpha: .35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                offer.isPending
                    ? Icons.schedule_rounded
                    : currentlyValid
                    ? Icons.hourglass_top_rounded
                    : Icons.history_rounded,
                color: accent,
                size: 20,
              ),
              const SizedBox(width: OmniSpacing.sm),
              Expanded(
                child: Text(
                  offer.presentationStatus,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              Text(
                '•${offer.shortIdentity}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: OmniColors.textSecondary,
                ),
              ),
            ],
          ),
          if (accepted) ...[
            const SizedBox(height: OmniSpacing.sm),
            Text(
              currentlyValid
                  ? 'Maintien temporaire uniquement. Le Patient ne vous a pas encore sélectionné.'
                  : 'Ce maintien n’est plus valide. Actualisez pour obtenir l’état courant.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: OmniColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
          if (deadline != null) ...[
            const SizedBox(height: OmniSpacing.sm),
            Text(
              '${offer.isPending ? 'Réponse avant' : 'Maintien jusqu’au'} ${_formatDate(deadline)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (offer.quotedHomeFeeTnd != null) ...[
            const SizedBox(height: OmniSpacing.xs),
            Text(
              '${offer.quotedHomeFeeTnd} ${offer.currency}',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
          const SizedBox(height: OmniSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              key: ValueKey('doctor-home-offer-detail-${offer.offerId}'),
              onPressed: loadingDetail ? null : onOpen,
              icon: loadingDetail
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync_rounded, size: 18),
              label: const Text('Actualiser le statut'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DoctorHomeOfferDetail extends StatelessWidget {
  const _DoctorHomeOfferDetail({
    required this.initialOffer,
    required this.controller,
  });

  final DoctorHomeOffer initialOffer;
  final DoctorHomeOfferInboxController controller;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final offer = controller.offer(initialOffer.offerId) ?? initialOffer;
      final command = controller.commandView?.offerId == offer.offerId
          ? controller.commandView
          : null;
      return SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            OmniSpacing.pageHorizontal,
            OmniSpacing.md,
            OmniSpacing.pageHorizontal,
            OmniSpacing.xl + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Statut actuel de l’offre',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: OmniSpacing.md),
              Text(offer.presentationStatus),
              const SizedBox(height: OmniSpacing.sm),
              Text(
                _detailExplanation(offer),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: OmniColors.textSecondary,
                  height: 1.45,
                ),
              ),
              if (offer.quotedHomeFeeTnd != null) ...[
                const SizedBox(height: OmniSpacing.md),
                Text(
                  '${offer.quotedHomeFeeTnd} ${offer.currency}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
              if (offer.isAcceptedHold && offer.holdExpiresAt != null) ...[
                const SizedBox(height: OmniSpacing.xs),
                Text(
                  'Maintien jusqu’au ${_formatDate(offer.holdExpiresAt!)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: OmniSpacing.md),
              Text(
                'Offre •${offer.shortIdentity} · révision ${offer.revision}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: OmniColors.textSecondary,
                ),
              ),
              Text(
                'État vérifié le ${_formatDate(offer.evaluatedAt)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: OmniColors.textSecondary,
                ),
              ),
              if (offer.withdrawalReason != null) ...[
                const SizedBox(height: OmniSpacing.sm),
                Text(offer.withdrawalReason!.frenchLabel),
              ],
              if (command != null) ...[
                const SizedBox(height: OmniSpacing.lg),
                Semantics(
                  liveRegion: true,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(OmniSpacing.md),
                    decoration: BoxDecoration(
                      color:
                          command.phase == DoctorHomeOfferCommandPhase.succeeded
                          ? OmniColors.mintSoft
                          : OmniColors.amberSoft,
                      borderRadius: BorderRadius.circular(OmniRadii.card),
                    ),
                    child: Text(command.message),
                  ),
                ),
              ],
              if (command?.isBusy == true) ...[
                const SizedBox(height: OmniSpacing.lg),
                const Center(child: CircularProgressIndicator()),
              ] else if (command?.canRetryExact == true) ...[
                const SizedBox(height: OmniSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const ValueKey('doctor-home-offer-retry-command'),
                    onPressed: controller.retryPendingCommand,
                    icon: const Icon(Icons.replay_rounded),
                    label: const Text('Répéter exactement la commande'),
                  ),
                ),
              ] else if (command?.canReconcile == true) ...[
                const SizedBox(height: OmniSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    key: const ValueKey('doctor-home-offer-reconcile-command'),
                    onPressed: controller.reconcilePendingCommand,
                    icon: const Icon(Icons.sync_rounded),
                    label: const Text('Vérifier le statut serveur'),
                  ),
                ),
              ] else if (controller.canRespondTo(offer)) ...[
                const SizedBox(height: OmniSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        key: const ValueKey('doctor-home-offer-decline'),
                        onPressed: () => _confirm(
                          context,
                          offer,
                          DoctorHomeOfferAction.decline,
                        ),
                        child: const Text('Décliner'),
                      ),
                    ),
                    const SizedBox(width: OmniSpacing.md),
                    Expanded(
                      child: FilledButton(
                        key: const ValueKey('doctor-home-offer-accept'),
                        onPressed: () => _confirm(
                          context,
                          offer,
                          DoctorHomeOfferAction.accept,
                        ),
                        child: const Text('Accepter'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      );
    },
  );

  Future<void> _confirm(
    BuildContext context,
    DoctorHomeOffer offer,
    DoctorHomeOfferAction action,
  ) async {
    final accepting = action == DoctorHomeOfferAction.accept;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          accepting
              ? 'Accepter temporairement cette offre ?'
              : 'Décliner cette offre ?',
        ),
        content: Text(
          accepting
              ? 'Cette action crée uniquement un maintien HOME temporaire. Le Patient doit encore vous sélectionner.'
              : 'Cette offre deviendra terminale et ne pourra plus être acceptée.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            key: ValueKey('doctor-home-offer-confirm-${action.name}'),
            onPressed: () => Navigator.pop(context, true),
            child: Text(accepting ? 'Accepter' : 'Décliner'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await controller.respond(offer.offerId, action);
    }
  }

  static String _detailExplanation(DoctorHomeOffer offer) {
    if (offer.status == DoctorHomeOfferStatus.selectedCommitted) {
      return 'Le Patient vous a confirmé. Cet état reste informatif : la mission, la destination, la navigation, le QR et le dossier médical ne sont pas ouverts dans cette version.';
    }
    if (offer.isAcceptedHold) {
      return offer.holdCurrentlyValid
          ? 'Acceptation provisoire uniquement. Le Patient ne vous a pas encore sélectionné.'
          : 'Le maintien temporaire est expiré ou en cours de matérialisation serveur.';
    }
    if (offer.isPending) {
      return 'Cette demande peut être acceptée ou déclinée après une nouvelle vérification serveur.';
    }
    return 'Cet état est terminal et ne permet aucune nouvelle réponse depuis cet écran.';
  }
}

class _InboxMessage extends StatelessWidget {
  const _InboxMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: OmniSpacing.lg),
      child: Column(
        children: [
          Icon(icon, color: OmniColors.slateBlue, size: 32),
          const SizedBox(height: OmniSpacing.sm),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: OmniSpacing.xs),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: OmniColors.textSecondary,
              height: 1.45,
            ),
          ),
        ],
      ),
    ),
  );
}

class _InboxFailure extends StatelessWidget {
  const _InboxFailure({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _InboxMessage(
        icon: Icons.cloud_off_outlined,
        title: 'Chargement impossible',
        message: message,
      ),
      TextButton.icon(
        key: const ValueKey('doctor-home-offer-retry'),
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Réessayer'),
      ),
    ],
  );
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)} à ${two(local.hour)}:${two(local.minute)}';
}
