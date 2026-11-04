import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/omni_theme.dart';
import 'urgent_cabinet_flow_controller.dart';
import 'urgent_cabinet_request_review.dart';
import 'urgent_cabinet_request_state.dart';

class UrgentCabinetRequestRecoveryScreen extends StatefulWidget {
  const UrgentCabinetRequestRecoveryScreen({
    super.key,
    required this.onChooseAnotherDoctor,
    required this.onExitJourney,
    this.authorizeNewJourney,
  });

  final VoidCallback onChooseAnotherDoctor;
  final VoidCallback onExitJourney;
  final Future<bool> Function()? authorizeNewJourney;

  @override
  State<UrgentCabinetRequestRecoveryScreen> createState() =>
      _UrgentCabinetRequestRecoveryScreenState();
}

class _UrgentCabinetRequestRecoveryScreenState
    extends State<UrgentCabinetRequestRecoveryScreen> {
  bool _exitDialogOpen = false;
  bool _leavingForDirectory = false;

  Future<void> _confirmExit() async {
    if (_exitDialogOpen || _leavingForDirectory) return;
    final state = context.read<UrgentCabinetFlowController>().requestState;
    final authoritative =
        (state is UrgentCabinetRequestAttemptState && state.isAuthoritative) ||
        state is UrgentCabinetRequestAuthorityUnavailable;
    _exitDialogOpen = true;
    final shouldExit = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        key: const ValueKey('urgent-cabinet-recovery-exit-dialog'),
        title: Text(
          authoritative
              ? 'Fermer ce résultat ?'
              : 'Quitter la demande urgente ?',
        ),
        content: Text(
          authoritative
              ? "Fermer cet écran ne modifie pas le résultat confirmé de la demande."
              : "Cette action termine uniquement la simulation locale de développement. Aucune demande médicale réelle n'a été créée ni annulée.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Rester'),
          ),
          TextButton(
            key: const ValueKey('urgent-cabinet-confirm-recovery-exit'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Quitter'),
          ),
        ],
      ),
    );
    _exitDialogOpen = false;
    if (!mounted || shouldExit != true) return;
    widget.onExitJourney();
  }

  Future<void> _chooseAnotherDoctor() async {
    if (_leavingForDirectory) return;
    final current = context.read<UrgentCabinetFlowController>().requestState;
    if (current is UrgentCabinetRequestAttemptState &&
        current.isAuthoritative) {
      final authorize = widget.authorizeNewJourney;
      if (authorize == null || !await authorize() || !mounted) return;
    }
    final result = context
        .read<UrgentCabinetFlowController>()
        .prepareDoctorRetry();
    if (result != UrgentCabinetDoctorRetryTransition.prepared) return;

    // PopScope must allow the deliberate multi-route pop performed by the
    // flow shell. Waiting and confirmation remain protected from user Back.
    setState(() => _leavingForDirectory = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onChooseAnotherDoctor();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<UrgentCabinetFlowController>().requestState;
    final presentation = _RecoveryPresentation.fromState(state);

    return PopScope<void>(
      canPop: _leavingForDirectory,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        key: const ValueKey('urgent-cabinet-request-recovery-screen'),
        backgroundColor: OmniColors.pageBackground,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              _RecoveryHeader(onBack: _confirmExit),
              Expanded(
                child: SingleChildScrollView(
                  key: const PageStorageKey('urgent-cabinet-recovery-scroll'),
                  padding: const EdgeInsets.fromLTRB(
                    OmniSpacing.pageHorizontal,
                    OmniSpacing.lg,
                    OmniSpacing.pageHorizontal,
                    OmniSpacing.xxl,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 680),
                      child: _RecoveryContent(presentation: presentation),
                    ),
                  ),
                ),
              ),
              _RecoveryFooter(
                retryEnabled: presentation.review != null,
                onRetry: _chooseAnotherDoctor,
                onExit: _confirmExit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecoveryHeader extends StatelessWidget {
  const _RecoveryHeader({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        OmniSpacing.sm,
        OmniSpacing.sm,
        OmniSpacing.pageHorizontal,
        OmniSpacing.sm,
      ),
      decoration: const BoxDecoration(
        color: OmniColors.surfacePrimary,
        border: Border(bottom: BorderSide(color: OmniColors.borderLight)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Retour',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: OmniSpacing.xs),
          Expanded(
            child: Text(
              'Demande urgente',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: OmniColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecoveryContent extends StatelessWidget {
  const _RecoveryContent({required this.presentation});

  final _RecoveryPresentation presentation;

  @override
  Widget build(BuildContext context) {
    final review = presentation.review;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          liveRegion: true,
          label: presentation.semanticLabel,
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: OmniColors.amberSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  presentation.icon,
                  size: 34,
                  color: OmniColors.amber,
                ),
              ),
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
        if (presentation.isDevelopmentSimulation) ...[
          const SizedBox(height: OmniSpacing.lg),
          const _SimulationNotice(),
        ],
        if (review != null) ...[
          const SizedBox(height: OmniSpacing.xl),
          _RecoverySummary(review: review),
          const SizedBox(height: OmniSpacing.md),
          const _FeeNotice(),
        ],
      ],
    );
  }
}

class _SimulationNotice extends StatelessWidget {
  const _SimulationNotice();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: "Simulation, aucune demande réelle n'a été envoyée",
      child: Container(
        key: const ValueKey('urgent-cabinet-recovery-simulation'),
        padding: const EdgeInsets.all(OmniSpacing.md),
        decoration: BoxDecoration(
          color: OmniColors.amberSoft,
          borderRadius: BorderRadius.circular(OmniRadii.field),
          border: Border.all(color: OmniColors.amber.withValues(alpha: 0.2)),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.science_outlined, color: OmniColors.amber, size: 20),
            SizedBox(width: OmniSpacing.sm),
            Expanded(
              child: Text(
                "Simulation — aucune demande réelle n'a été envoyée.",
                style: TextStyle(color: OmniColors.textPrimary, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecoverySummary extends StatelessWidget {
  const _RecoverySummary({required this.review});

  final UrgentCabinetRequestReview review;

  @override
  Widget build(BuildContext context) {
    final address = _cabinetAddress(review);
    return Container(
      key: const ValueKey('urgent-cabinet-recovery-summary'),
      width: double.infinity,
      padding: const EdgeInsets.all(OmniSpacing.base),
      decoration: BoxDecoration(
        color: OmniColors.surfacePrimary,
        borderRadius: BorderRadius.circular(OmniRadii.card),
        border: Border.all(color: OmniColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Demande non acceptée',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: OmniColors.textPrimary,
            ),
          ),
          const SizedBox(height: OmniSpacing.base),
          _SummaryRow(label: 'Patient', value: review.patientDisplayName),
          _SummaryRow(
            label: 'Médecin précédent',
            value: review.doctorDisplayName,
            detail: review.specialty,
          ),
          _SummaryRow(
            label: 'Cabinet précédent',
            value: review.cabinetName,
            detail: address,
          ),
          _SummaryRow(
            label: 'Tarif urgent indicatif',
            value: formatUrgentCabinetFee(review.feeQuote),
            last: true,
          ),
        ],
      ),
    );
  }

  String _cabinetAddress(UrgentCabinetRequestReview review) {
    final parts = <String>[];
    final address = review.cabinetAddress?.trim();
    if (address != null && address.isNotEmpty) parts.add(address);
    if (review.cabinetLocality.trim().isNotEmpty) {
      parts.add(review.cabinetLocality.trim());
    }
    final region = [review.cabinetCity, review.cabinetGovernorate]
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toSet()
        .join(', ');
    if (region.isNotEmpty && !parts.contains(region)) parts.add(region);
    return parts.join(' · ');
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.detail,
    this.last = false,
  });

  final String label;
  final String value;
  final String? detail;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : OmniSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: OmniColors.textTertiary),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: OmniColors.textPrimary,
            ),
          ),
          if (detail != null && detail!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              detail!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                height: 1.35,
                color: OmniColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FeeNotice extends StatelessWidget {
  const _FeeNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('urgent-cabinet-recovery-fee-notice'),
      padding: const EdgeInsets.all(OmniSpacing.md),
      decoration: BoxDecoration(
        color: OmniColors.infoBlueSoft,
        borderRadius: BorderRadius.circular(OmniRadii.field),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: OmniColors.infoBlue,
            size: 20,
          ),
          SizedBox(width: OmniSpacing.sm),
          Expanded(
            child: Text(
              "Ce tarif est affiché uniquement à titre informatif. Aucun montant n'a été facturé.",
              style: TextStyle(color: OmniColors.textPrimary, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecoveryFooter extends StatelessWidget {
  const _RecoveryFooter({
    required this.retryEnabled,
    required this.onRetry,
    required this.onExit,
  });

  final bool retryEnabled;
  final VoidCallback onRetry;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: OmniColors.surfacePrimary,
        border: Border(top: BorderSide(color: OmniColors.borderLight)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            OmniSpacing.pageHorizontal,
            OmniSpacing.md,
            OmniSpacing.pageHorizontal,
            OmniSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  key: const ValueKey('urgent-cabinet-choose-another-doctor'),
                  onPressed: retryEnabled ? onRetry : null,
                  child: const Text('Choisir un autre médecin'),
                ),
              ),
              const SizedBox(height: OmniSpacing.sm),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  key: const ValueKey('urgent-cabinet-recovery-exit'),
                  onPressed: onExit,
                  child: const Text('Quitter la demande urgente'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

@immutable
class _RecoveryPresentation {
  const _RecoveryPresentation({
    required this.title,
    required this.message,
    required this.semanticLabel,
    required this.icon,
    required this.review,
    required this.isDevelopmentSimulation,
  });

  factory _RecoveryPresentation.fromState(UrgentCabinetRequestState state) {
    return switch (state) {
      UrgentCabinetRequestDeclined() => _RecoveryPresentation(
        title: "Le médecin n'a pas accepté votre demande",
        message:
            'Vous pouvez choisir un autre médecin disponible sans recommencer votre demande depuis le début.',
        semanticLabel: "Le médecin n'a pas accepté la demande urgente",
        icon: Icons.event_busy_outlined,
        review: state.review,
        isDevelopmentSimulation: state.isDevelopmentSimulation,
      ),
      UrgentCabinetRequestUnavailable() => _RecoveryPresentation(
        title: "Ce médecin n'est plus disponible",
        message:
            'Ce médecin ne peut plus recevoir votre demande urgente au cabinet. Vous pouvez en sélectionner un autre.',
        semanticLabel:
            "Le médecin n'est plus disponible pour la demande urgente",
        icon: Icons.person_off_outlined,
        review: state.review,
        isDevelopmentSimulation: state.isDevelopmentSimulation,
      ),
      UrgentCabinetRequestCancelled() => _RecoveryPresentation(
        title: 'Votre demande a été annulée',
        message:
            'L’annulation a été confirmée. Vous pouvez choisir un autre médecin et commencer une nouvelle demande urgente.',
        semanticLabel: 'Demande urgente annulée par le Patient',
        icon: Icons.cancel_outlined,
        review: state.review,
        isDevelopmentSimulation: false,
      ),
      UrgentCabinetRequestExpired() => _RecoveryPresentation(
        title: 'Le délai de réponse est dépassé',
        message:
            'Aucune acceptation n’a été confirmée avant la fin du délai. Vous pouvez choisir un autre médecin.',
        semanticLabel: 'Délai de réponse de la demande urgente dépassé',
        icon: Icons.timer_off_outlined,
        review: state.review,
        isDevelopmentSimulation: false,
      ),
      UrgentCabinetRequestAuthorityUnavailable(:final message) =>
        _RecoveryPresentation(
          title: 'Demande temporairement indisponible',
          message: message,
          semanticLabel: 'Statut de la demande urgente indisponible',
          icon: Icons.sync_problem_outlined,
          review: null,
          isDevelopmentSimulation: false,
        ),
      _ => const _RecoveryPresentation(
        title: 'Demande indisponible',
        message: 'Cette tentative ne peut plus être affichée.',
        semanticLabel: 'Demande urgente indisponible',
        icon: Icons.info_outline_rounded,
        review: null,
        isDevelopmentSimulation: false,
      ),
    };
  }

  final String title;
  final String message;
  final String semanticLabel;
  final IconData icon;
  final UrgentCabinetRequestReview? review;
  final bool isDevelopmentSimulation;
}
