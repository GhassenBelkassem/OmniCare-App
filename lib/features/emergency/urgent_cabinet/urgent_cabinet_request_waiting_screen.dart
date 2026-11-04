import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/omni_theme.dart';
import 'urgent_cabinet_flow_controller.dart';
import 'urgent_cabinet_request_review.dart';
import 'urgent_cabinet_request_state.dart';
import 'urgent_cabinet_targeted_request_models.dart';

class UrgentCabinetRequestWaitingScreen extends StatefulWidget {
  const UrgentCabinetRequestWaitingScreen({
    super.key,
    required this.onEndSimulation,
    this.onCancelAuthoritativeRequest,
    this.onSimulateAcceptance,
  });

  final VoidCallback onEndSimulation;
  final Future<void> Function()? onCancelAuthoritativeRequest;
  final VoidCallback? onSimulateAcceptance;

  @override
  State<UrgentCabinetRequestWaitingScreen> createState() =>
      _UrgentCabinetRequestWaitingScreenState();
}

class _UrgentCabinetRequestWaitingScreenState
    extends State<UrgentCabinetRequestWaitingScreen> {
  bool _exitDialogOpen = false;
  bool _cancelling = false;

  Future<void> _confirmEndSimulation() async {
    if (_exitDialogOpen) return;
    _exitDialogOpen = true;
    final shouldEnd = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        key: const ValueKey('urgent-cabinet-end-simulation-dialog'),
        title: const Text('Terminer la simulation ?'),
        content: const Text(
          "Cette action termine uniquement la simulation locale de développement. Aucune demande médicale réelle n'a été créée ni annulée.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Rester'),
          ),
          TextButton(
            key: const ValueKey('urgent-cabinet-confirm-end-simulation'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Terminer'),
          ),
        ],
      ),
    );
    _exitDialogOpen = false;
    if (!mounted || shouldEnd != true) return;
    context.read<UrgentCabinetFlowController>().endDevelopmentSimulation();
    widget.onEndSimulation();
  }

  Future<void> _confirmCancellation() async {
    if (_exitDialogOpen || _cancelling) return;
    final state = context.read<UrgentCabinetFlowController>().requestState;
    if (state is! UrgentCabinetRequestPendingDoctorResponse ||
        !state.isAuthoritative ||
        !state.authoritativeSnapshot!.allowedActions.contains('CANCEL')) {
      return;
    }
    _exitDialogOpen = true;
    final shouldCancel = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        key: const ValueKey('urgent-cabinet-cancel-request-dialog'),
        title: const Text('Annuler la demande urgente ?'),
        content: const Text(
          "La demande ne sera annulée qu'après confirmation du serveur. Si le médecin l'accepte en même temps, son acceptation peut rester prioritaire.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Garder la demande'),
          ),
          TextButton(
            key: const ValueKey('urgent-cabinet-confirm-cancel-request'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Annuler la demande'),
          ),
        ],
      ),
    );
    _exitDialogOpen = false;
    if (!mounted || shouldCancel != true) return;
    setState(() => _cancelling = true);
    try {
      await widget.onCancelAuthoritativeRequest?.call();
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<UrgentCabinetFlowController>().requestState;
    final review = state.review;

    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final current = context
            .read<UrgentCabinetFlowController>()
            .requestState;
        if (current is UrgentCabinetRequestAttemptState &&
            current.isAuthoritative) {
          widget.onEndSimulation();
        } else {
          _confirmEndSimulation();
        }
      },
      child: Scaffold(
        key: const ValueKey('urgent-cabinet-request-waiting-screen'),
        backgroundColor: OmniColors.pageBackground,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const _WaitingHeader(),
              Expanded(
                child: SingleChildScrollView(
                  key: const PageStorageKey('urgent-cabinet-waiting-scroll'),
                  padding: const EdgeInsets.fromLTRB(
                    OmniSpacing.pageHorizontal,
                    OmniSpacing.lg,
                    OmniSpacing.pageHorizontal,
                    OmniSpacing.xxl,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 680),
                      child: _WaitingContent(
                        state: state,
                        review: review,
                        onSimulateAcceptance: widget.onSimulateAcceptance,
                      ),
                    ),
                  ),
                ),
              ),
              _WaitingFooter(
                authoritative:
                    state is UrgentCabinetRequestAttemptState &&
                    state.isAuthoritative,
                authoritativePending:
                    state is UrgentCabinetRequestPendingDoctorResponse &&
                    state.isAuthoritative,
                cancellationEnabled:
                    state is UrgentCabinetRequestPendingDoctorResponse &&
                    state.isAuthoritative &&
                    state.authoritativeSnapshot!.allowedActions.contains(
                      'CANCEL',
                    ) &&
                    widget.onCancelAuthoritativeRequest != null &&
                    !_cancelling,
                onAction:
                    state is UrgentCabinetRequestPendingDoctorResponse &&
                        state.isAuthoritative
                    ? _confirmCancellation
                    : _confirmEndSimulation,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WaitingHeader extends StatelessWidget {
  const _WaitingHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        OmniSpacing.pageHorizontal,
        OmniSpacing.base,
        OmniSpacing.pageHorizontal,
        OmniSpacing.base,
      ),
      decoration: const BoxDecoration(
        color: OmniColors.surfacePrimary,
        border: Border(bottom: BorderSide(color: OmniColors.borderLight)),
      ),
      child: Text(
        'Demande urgente',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          color: OmniColors.textPrimary,
        ),
      ),
    );
  }
}

class _WaitingContent extends StatelessWidget {
  const _WaitingContent({
    required this.state,
    required this.review,
    required this.onSimulateAcceptance,
  });

  final UrgentCabinetRequestState state;
  final UrgentCabinetRequestReview? review;
  final VoidCallback? onSimulateAcceptance;

  @override
  Widget build(BuildContext context) {
    final attemptState = state is UrgentCabinetRequestAttemptState
        ? state as UrgentCabinetRequestAttemptState
        : null;
    final isDevelopment = attemptState?.isDevelopmentSimulation == true;
    final authoritativeSnapshot = attemptState?.authoritativeSnapshot;
    final showDevelopmentDecisionControls =
        onSimulateAcceptance != null &&
        state is UrgentCabinetRequestPendingDoctorResponse &&
        isDevelopment &&
        review?.isDevelopmentFixture == true &&
        review?.feeQuote.isDevelopmentFixture == true;
    final presentation = _presentationFor(state);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          liveRegion: true,
          label: presentation.semanticLabel,
          child: Column(
            children: [
              _StatusIndicator(state: state),
              const SizedBox(height: OmniSpacing.lg),
              Text(
                presentation.title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontSize: 25,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                  color: OmniColors.textPrimary,
                  letterSpacing: -0.35,
                ),
              ),
              const SizedBox(height: OmniSpacing.sm),
              Text(
                presentation.message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.5,
                  color: OmniColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        if (isDevelopment) ...[
          const SizedBox(height: OmniSpacing.lg),
          const _DevelopmentIndicator(),
        ],
        if (showDevelopmentDecisionControls) ...[
          const SizedBox(height: OmniSpacing.md),
          _DevelopmentDecisionControls(
            onSimulateAcceptance: onSimulateAcceptance!,
          ),
        ],
        if (review != null) ...[
          const SizedBox(height: OmniSpacing.xl),
          _RequestSummary(review: review!),
        ],
        if (state is UrgentCabinetRequestPendingDoctorResponse &&
            authoritativeSnapshot != null) ...[
          const SizedBox(height: OmniSpacing.md),
          _AuthoritativeDeadline(snapshot: authoritativeSnapshot),
        ],
        if (state is UrgentCabinetRequestPendingDoctorResponse ||
            state is UrgentCabinetRequestSubmitting) ...[
          const SizedBox(height: OmniSpacing.lg),
          const _NoTravelNotice(),
        ],
        if (state case UrgentCabinetRequestSubmissionFailed(
          kind: UrgentCabinetSubmissionFailureKind.unknownOutcome,
        )) ...[
          const SizedBox(height: OmniSpacing.lg),
          const _UnknownOutcomeNotice(),
        ],
      ],
    );
  }
}

class _AuthoritativeDeadline extends StatelessWidget {
  const _AuthoritativeDeadline({required this.snapshot});

  final UrgentCabinetTargetedRequestSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final deadline = snapshot.responseDeadlineAt;
    final hour = deadline.toLocal().hour.toString().padLeft(2, '0');
    final minute = deadline.toLocal().minute.toString().padLeft(2, '0');
    return Text(
      'Réponse attendue avant $hour:$minute. Le statut affiché reste confirmé par le serveur.',
      key: const ValueKey('urgent-cabinet-response-deadline'),
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: OmniColors.textSecondary,
        height: 1.4,
      ),
    );
  }
}

class _DevelopmentDecisionControls extends StatelessWidget {
  const _DevelopmentDecisionControls({required this.onSimulateAcceptance});

  final VoidCallback onSimulateAcceptance;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('urgent-cabinet-development-decision-controls'),
      padding: const EdgeInsets.all(OmniSpacing.base),
      decoration: BoxDecoration(
        color: OmniColors.violetSoft,
        borderRadius: BorderRadius.circular(OmniRadii.card),
        border: Border.all(color: OmniColors.violet.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Contrôles de développement',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: OmniColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: OmniSpacing.xs),
          Text(
            'Simulez une réponse du médecin pour tester la suite du parcours.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              height: 1.45,
              color: OmniColors.textSecondary,
            ),
          ),
          const SizedBox(height: OmniSpacing.md),
          OutlinedButton.icon(
            key: const ValueKey('urgent-cabinet-simulate-acceptance'),
            onPressed: onSimulateAcceptance,
            icon: const Icon(Icons.science_outlined),
            label: const Text("Simuler l'acceptation"),
          ),
        ],
      ),
    );
  }
}

class _StatusIndicator extends StatelessWidget {
  const _StatusIndicator({required this.state});

  final UrgentCabinetRequestState state;

  @override
  Widget build(BuildContext context) {
    final isInProgress =
        state is UrgentCabinetRequestSubmitting ||
        state is UrgentCabinetRequestPendingDoctorResponse;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final isFailure = state is UrgentCabinetRequestSubmissionFailed;

    return Container(
      key: const ValueKey('urgent-cabinet-waiting-status-indicator'),
      width: 72,
      height: 72,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isFailure ? OmniColors.errorSoft : OmniColors.amberSoft,
        shape: BoxShape.circle,
      ),
      child: isInProgress && !reduceMotion
          ? const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: OmniColors.amber,
              ),
            )
          : Icon(
              isFailure ? Icons.info_outline_rounded : Icons.schedule_rounded,
              color: isFailure ? OmniColors.error : OmniColors.amber,
              size: 34,
            ),
    );
  }
}

class _DevelopmentIndicator extends StatelessWidget {
  const _DevelopmentIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('urgent-cabinet-development-indicator'),
      padding: const EdgeInsets.all(OmniSpacing.md),
      decoration: BoxDecoration(
        color: OmniColors.violetSoft,
        borderRadius: BorderRadius.circular(OmniRadii.field),
        border: Border.all(color: OmniColors.violet.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.science_outlined,
            color: OmniColors.violet,
            size: 20,
          ),
          const SizedBox(width: OmniSpacing.sm),
          Expanded(
            child: Text(
              "Simulation — aucune demande réelle n'a été envoyée.",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                height: 1.45,
                color: OmniColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestSummary extends StatelessWidget {
  const _RequestSummary({required this.review});

  final UrgentCabinetRequestReview review;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('urgent-cabinet-waiting-summary'),
      padding: const EdgeInsets.all(OmniSpacing.base),
      decoration: BoxDecoration(
        color: OmniColors.surfacePrimary,
        borderRadius: BorderRadius.circular(OmniRadii.card),
        border: Border.all(color: OmniColors.borderLight),
        boxShadow: const [OmniColors.shadowSm],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Récapitulatif de la demande',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: OmniColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: OmniSpacing.base),
          _SummaryRow(
            icon: Icons.person_outline_rounded,
            label: 'Patient concerné',
            value: review.patientDisplayName,
          ),
          const Divider(height: OmniSpacing.xl, color: OmniColors.borderLight),
          _SummaryRow(
            icon: Icons.medical_services_outlined,
            label: 'Médecin',
            value: review.doctorDisplayName,
            detail: review.specialty,
          ),
          const Divider(height: OmniSpacing.xl, color: OmniColors.borderLight),
          _SummaryRow(
            icon: Icons.location_on_outlined,
            label: 'Cabinet',
            value: review.cabinetName,
            detail: _cabinetAddress(review),
          ),
          const Divider(height: OmniSpacing.xl, color: OmniColors.borderLight),
          _SummaryRow(
            icon: Icons.payments_outlined,
            label: 'Tarif de consultation urgente',
            value: formatUrgentCabinetFee(review.feeQuote),
          ),
        ],
      ),
    );
  }

  static String _cabinetAddress(UrgentCabinetRequestReview review) {
    final parts = <String>[];
    final address = review.cabinetAddress?.trim();
    if (address != null && address.isNotEmpty) parts.add(address);
    if (review.cabinetLocality.trim().isNotEmpty) {
      parts.add(review.cabinetLocality.trim());
    }
    final region = review.cabinetCity == review.cabinetGovernorate
        ? review.cabinetCity
        : '${review.cabinetCity}, ${review.cabinetGovernorate}';
    if (region.trim().isNotEmpty && !parts.contains(region)) parts.add(region);
    return parts.join(' · ');
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
    this.detail,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 21, color: OmniColors.slateBlue),
        const SizedBox(width: OmniSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: OmniColors.textTertiary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: OmniSpacing.xs),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: OmniColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (detail != null && detail!.trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  detail!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    height: 1.4,
                    color: OmniColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _NoTravelNotice extends StatelessWidget {
  const _NoTravelNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('urgent-cabinet-waiting-no-travel'),
      padding: const EdgeInsets.all(OmniSpacing.base),
      decoration: BoxDecoration(
        color: OmniColors.amberSoft,
        borderRadius: BorderRadius.circular(OmniRadii.card),
        border: Border.all(color: OmniColors.amber.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.directions_walk_outlined, color: OmniColors.amber),
          const SizedBox(width: OmniSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ne vous déplacez pas encore',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: OmniColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: OmniSpacing.xs),
                Text(
                  'Attendez que le médecin accepte votre demande avant de vous rendre au cabinet.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    height: 1.5,
                    color: OmniColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UnknownOutcomeNotice extends StatelessWidget {
  const _UnknownOutcomeNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('urgent-cabinet-unknown-outcome-notice'),
      padding: const EdgeInsets.all(OmniSpacing.base),
      decoration: BoxDecoration(
        color: OmniColors.infoBlueSoft,
        borderRadius: BorderRadius.circular(OmniRadii.card),
        border: Border.all(color: OmniColors.infoBlue.withValues(alpha: 0.2)),
      ),
      child: Text(
        "Ne renvoyez pas la demande. Une future connexion au service devra d'abord vérifier son état.",
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          height: 1.5,
          color: OmniColors.textPrimary,
        ),
      ),
    );
  }
}

class _WaitingFooter extends StatelessWidget {
  const _WaitingFooter({
    required this.authoritative,
    required this.authoritativePending,
    required this.cancellationEnabled,
    required this.onAction,
  });

  final bool authoritative;
  final bool authoritativePending;
  final bool cancellationEnabled;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(
          OmniSpacing.pageHorizontal,
          OmniSpacing.sm,
          OmniSpacing.pageHorizontal,
          OmniSpacing.md,
        ),
        decoration: const BoxDecoration(
          color: OmniColors.surfacePrimary,
          border: Border(top: BorderSide(color: OmniColors.borderLight)),
        ),
        child: OutlinedButton(
          key: const ValueKey('urgent-cabinet-end-simulation'),
          onPressed: authoritativePending
              ? (cancellationEnabled ? onAction : null)
              : onAction,
          child: Text(
            authoritativePending
                ? 'Annuler la demande'
                : authoritative
                ? 'Fermer'
                : 'Terminer la simulation',
          ),
        ),
      ),
    );
  }
}

_WaitingPresentation _presentationFor(UrgentCabinetRequestState state) {
  return switch (state) {
    UrgentCabinetRequestSubmitting() => const _WaitingPresentation(
      title: 'Envoi de la demande…',
      message: 'Préparation de la simulation locale en cours.',
      semanticLabel: 'Envoi de la demande urgente en cours',
    ),
    UrgentCabinetRequestPendingDoctorResponse() => const _WaitingPresentation(
      title: 'En attente de la réponse du médecin',
      message: 'Votre demande attend la confirmation du médecin sélectionné.',
      semanticLabel: 'Demande en attente de la réponse du médecin',
    ),
    UrgentCabinetRequestSubmissionFailed(
      kind: UrgentCabinetSubmissionFailureKind.definitelyNotSubmitted,
      :final message,
    ) =>
      _WaitingPresentation(
        title: 'Simulation non démarrée',
        message: message,
        semanticLabel: "La simulation de la demande n'a pas démarré",
      ),
    UrgentCabinetRequestSubmissionFailed(:final message) =>
      _WaitingPresentation(
        title: 'Vérification nécessaire',
        message: message,
        semanticLabel: 'La demande urgente nécessite une vérification',
      ),
    _ => const _WaitingPresentation(
      title: 'Simulation terminée',
      message: "Aucune demande médicale réelle n'a été créée.",
      semanticLabel: 'Simulation terminée',
    ),
  };
}

@immutable
class _WaitingPresentation {
  const _WaitingPresentation({
    required this.title,
    required this.message,
    required this.semanticLabel,
  });

  final String title;
  final String message;
  final String semanticLabel;
}
