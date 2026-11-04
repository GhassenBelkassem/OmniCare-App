import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/omni_theme.dart';
import 'urgent_cabinet_arrival_instructions_screen.dart';
import 'urgent_cabinet_flow_controller.dart';
import 'urgent_cabinet_patient_lifecycle_controller.dart';
import 'urgent_cabinet_request_review.dart';
import 'urgent_cabinet_request_state.dart';
import 'urgent_cabinet_targeted_request_models.dart';

class UrgentCabinetRequestAcceptedScreen extends StatefulWidget {
  const UrgentCabinetRequestAcceptedScreen({
    super.key,
    required this.onExitJourney,
    this.onOpenArrivalInstructions,
  });

  final VoidCallback onExitJourney;
  final Future<void> Function()? onOpenArrivalInstructions;

  @override
  State<UrgentCabinetRequestAcceptedScreen> createState() =>
      _UrgentCabinetRequestAcceptedScreenState();
}

class _UrgentCabinetRequestAcceptedScreenState
    extends State<UrgentCabinetRequestAcceptedScreen> {
  static const double _minimumRenderableWidth = 200;
  static const double _compactViewportHeight = 560;

  bool _exitDialogOpen = false;
  bool _exiting = false;
  bool _openingArrivalInstructions = false;
  bool _withdrawDialogOpen = false;

  Future<void> _openArrivalInstructions() async {
    if (_openingArrivalInstructions || _exiting || !mounted) return;
    final open = widget.onOpenArrivalInstructions;
    if (open == null) return;
    final flow = context.read<UrgentCabinetFlowController>();
    if (!canOpenUrgentCabinetArrivalInstructions(flow)) return;
    setState(() => _openingArrivalInstructions = true);
    try {
      await open();
    } finally {
      if (mounted) {
        setState(() => _openingArrivalInstructions = false);
      }
    }
  }

  Future<void> _confirmExit() async {
    if (_exitDialogOpen || _exiting) return;
    final state = context.read<UrgentCabinetFlowController>().requestState;
    final authoritative =
        state is UrgentCabinetRequestAccepted && state.isAuthoritative;
    _exitDialogOpen = true;
    final shouldExit = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        key: const ValueKey('urgent-cabinet-accepted-exit-dialog'),
        title: Text(
          authoritative
              ? 'Fermer la confirmation ?'
              : 'Terminer la démonstration ?',
        ),
        content: Text(
          authoritative
              ? "Fermer cet écran n'annule pas l'engagement confirmé avec le médecin."
              : "Cette action termine uniquement la simulation locale de développement. Aucune demande médicale réelle n'a été créée ni acceptée.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Rester'),
          ),
          TextButton(
            key: const ValueKey('urgent-cabinet-confirm-accepted-exit'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Terminer'),
          ),
        ],
      ),
    );
    _exitDialogOpen = false;
    if (!mounted || shouldExit != true || _exiting) return;
    setState(() => _exiting = true);
    widget.onExitJourney();
  }

  Future<void> _confirmWithdrawal() async {
    if (_withdrawDialogOpen || _exiting) return;
    final lifecycle = context.read<UrgentCabinetPatientLifecycleController?>();
    if (lifecycle?.canWithdraw != true) return;
    _withdrawDialogOpen = true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const ValueKey('urgent-cabinet-withdraw-dialog'),
        title: const Text('Vous ne pouvez plus venir ?'),
        content: const Text(
          "Cette action informe le médecin et libère l'engagement CABINET. Elle ne peut pas être annulée.",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Retour'),
          ),
          TextButton(
            key: const ValueKey('urgent-cabinet-confirm-withdraw'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    _withdrawDialogOpen = false;
    if (!mounted || confirmed != true) return;
    await lifecycle!.withdrawAcceptedCommitment();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<UrgentCabinetFlowController>().requestState;
    final accepted = state is UrgentCabinetRequestAccepted ? state : null;
    final lifecycle = context.watch<UrgentCabinetPatientLifecycleController?>();
    final content = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: accepted == null
            ? const _AcceptedUnavailable()
            : _AcceptedContent(
                review: accepted.review,
                authoritative: accepted.isAuthoritative,
                showArrivalEntry:
                    widget.onOpenArrivalInstructions != null &&
                    (!accepted.isAuthoritative ||
                        lifecycle?.canIssueArrivalHandoff == true) &&
                    canOpenUrgentCabinetArrivalInstructions(
                      context.read<UrgentCabinetFlowController>(),
                    ),
                arrivalOpening: _openingArrivalInstructions,
                onOpenArrival: _openArrivalInstructions,
                clinicalPhase: lifecycle?.snapshot?.clinicalPhase,
              ),
      ),
    );
    final footer = _AcceptedFooter(
      enabled: accepted != null,
      authoritative: accepted?.isAuthoritative == true,
      canWithdraw:
          accepted?.isAuthoritative == true && lifecycle?.canWithdraw == true,
      withdrawing:
          lifecycle?.phase == UrgentCabinetPatientLifecyclePhase.withdrawing,
      onWithdraw: _confirmWithdrawal,
      onExit: _confirmExit,
    );

    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        key: const ValueKey('urgent-cabinet-request-accepted-screen'),
        backgroundColor: OmniColors.pageBackground,
        body: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Chrome can briefly report an unusable ~1 px wide surface while
              // resizing. Laying out interactive mobile controls in that frame
              // has no meaningful presentation and causes horizontal/vertical
              // flex overflows. The full screen is restored on the next valid
              // constraints pass.
              if (constraints.maxWidth < _minimumRenderableWidth) {
                return const SizedBox.expand(
                  key: ValueKey('urgent-cabinet-accepted-transient-viewport'),
                );
              }

              if (constraints.maxHeight < _compactViewportHeight) {
                return SingleChildScrollView(
                  key: const PageStorageKey(
                    'urgent-cabinet-accepted-compact-scroll',
                  ),
                  child: Column(
                    children: [
                      _AcceptedHeader(onBack: _confirmExit),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          OmniSpacing.pageHorizontal,
                          OmniSpacing.lg,
                          OmniSpacing.pageHorizontal,
                          OmniSpacing.xxl,
                        ),
                        child: content,
                      ),
                      footer,
                    ],
                  ),
                );
              }

              return Column(
                children: [
                  _AcceptedHeader(onBack: _confirmExit),
                  Expanded(
                    child: SingleChildScrollView(
                      key: const PageStorageKey(
                        'urgent-cabinet-accepted-scroll',
                      ),
                      padding: const EdgeInsets.fromLTRB(
                        OmniSpacing.pageHorizontal,
                        OmniSpacing.lg,
                        OmniSpacing.pageHorizontal,
                        OmniSpacing.xxl,
                      ),
                      child: content,
                    ),
                  ),
                  footer,
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _AcceptedHeader extends StatelessWidget {
  const _AcceptedHeader({required this.onBack});

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

class _AcceptedContent extends StatelessWidget {
  const _AcceptedContent({
    required this.review,
    required this.authoritative,
    required this.showArrivalEntry,
    required this.arrivalOpening,
    required this.onOpenArrival,
    required this.clinicalPhase,
  });

  final UrgentCabinetRequestReview review;
  final bool authoritative;
  final bool showArrivalEntry;
  final bool arrivalOpening;
  final VoidCallback onOpenArrival;
  final UrgentCabinetPatientClinicalPhase? clinicalPhase;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          liveRegion: true,
          label: authoritative
              ? 'Votre demande urgente au cabinet a été acceptée'
              : 'Votre demande urgente au cabinet a été acceptée dans la simulation',
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: OmniColors.successSubtle,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  size: 38,
                  color: OmniColors.deepTeal,
                ),
              ),
              const SizedBox(height: OmniSpacing.lg),
              Text(
                _title,
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
                _description,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.5,
                  color: OmniColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        if (!authoritative) ...[
          const SizedBox(height: OmniSpacing.lg),
          const _SimulationNotice(),
        ],
        const SizedBox(height: OmniSpacing.xl),
        _AcceptedSummary(review: review, authoritative: authoritative),
        const SizedBox(height: OmniSpacing.md),
        _FeeNotice(authoritative: authoritative),
        if (showArrivalEntry) ...[
          const SizedBox(height: OmniSpacing.md),
          _ArrivalPreparationCard(
            opening: arrivalOpening,
            onOpen: onOpenArrival,
          ),
        ],
        const SizedBox(height: OmniSpacing.md),
        _DirectionsCard(review: review, authoritative: authoritative),
      ],
    );
  }

  String get _title => switch (clinicalPhase) {
    UrgentCabinetPatientClinicalPhase.arrivedWaitingForDoctor =>
      'Arrivé au cabinet',
    UrgentCabinetPatientClinicalPhase.consultationInProgress =>
      'Consultation en cours',
    UrgentCabinetPatientClinicalPhase.careCompleted =>
      'Prise en charge terminée',
    _ => 'Votre demande a été acceptée',
  };

  String get _description => switch (clinicalPhase) {
    UrgentCabinetPatientClinicalPhase.arrivedWaitingForDoctor =>
      'En attente du médecin. Votre présence est confirmée et la consultation sera démarrée lorsqu’il sera disponible.',
    UrgentCabinetPatientClinicalPhase.consultationInProgress =>
      'Votre consultation urgente au cabinet est maintenant en cours.',
    UrgentCabinetPatientClinicalPhase.careCompleted =>
      'Votre prise en charge au cabinet est terminée. Vos documents restent disponibles dans les parcours habituels.',
    _ =>
      'Le médecin a accepté votre demande de consultation urgente au cabinet.',
  };
}

class _ArrivalPreparationCard extends StatelessWidget {
  const _ArrivalPreparationCard({required this.opening, required this.onOpen});

  final bool opening;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('urgent-cabinet-arrival-entry-card'),
      width: double.infinity,
      padding: const EdgeInsets.all(OmniSpacing.base),
      decoration: BoxDecoration(
        color: OmniColors.infoBlueSoft,
        borderRadius: BorderRadius.circular(OmniRadii.card),
        border: Border.all(color: OmniColors.infoBlue.withValues(alpha: 0.2)),
        boxShadow: const [OmniColors.shadowSm],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: OmniColors.surfacePrimary,
                  borderRadius: BorderRadius.circular(OmniRadii.field),
                ),
                child: const Icon(
                  Icons.location_on_outlined,
                  color: OmniColors.infoBlue,
                  size: 24,
                ),
              ),
              const SizedBox(width: OmniSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ARRIVÉE AU CABINET',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: OmniColors.infoBlueStrong,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: OmniSpacing.xs),
                    Text(
                      'Préparez votre arrivée',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: OmniColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: OmniSpacing.md),
          Text(
            'Retrouvez les informations utiles pour vous présenter au cabinet et découvrir comment la vérification de présence fonctionnera.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: OmniColors.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: OmniSpacing.sm),
          Text(
            "Aperçu de développement — aucune arrivée réelle n'est enregistrée.",
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: OmniColors.deepTeal,
              fontWeight: FontWeight.w600,
              height: 1.4,
            ),
          ),
          const SizedBox(height: OmniSpacing.md),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              key: const ValueKey('urgent-cabinet-open-arrival-instructions'),
              onPressed: opening ? null : onOpen,
              icon: const Icon(Icons.arrow_forward_rounded, size: 20),
              label: const Text("Voir les instructions d'arrivée"),
              style: OutlinedButton.styleFrom(
                foregroundColor: OmniColors.primaryAction,
                side: const BorderSide(color: OmniColors.primaryAction),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(OmniRadii.field),
                ),
                textStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontFamily: 'Plus Jakarta Sans',
                ),
              ),
            ),
          ),
        ],
      ),
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
        key: const ValueKey('urgent-cabinet-accepted-simulation'),
        padding: const EdgeInsets.all(OmniSpacing.md),
        decoration: BoxDecoration(
          color: OmniColors.successSubtle,
          borderRadius: BorderRadius.circular(OmniRadii.field),
          border: Border.all(color: OmniColors.success.withValues(alpha: 0.24)),
        ),
        child: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.science_outlined, color: OmniColors.deepTeal, size: 20),
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

class _AcceptedSummary extends StatelessWidget {
  const _AcceptedSummary({required this.review, required this.authoritative});

  final UrgentCabinetRequestReview review;
  final bool authoritative;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('urgent-cabinet-accepted-summary'),
      width: double.infinity,
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
            'Consultation urgente au cabinet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: OmniColors.textPrimary,
            ),
          ),
          const SizedBox(height: OmniSpacing.base),
          _SummaryRow(
            label: 'Patient concerné',
            value: review.patientDisplayName,
          ),
          _SummaryRow(
            label: 'Médecin',
            value: review.doctorDisplayName,
            detail: review.specialty,
          ),
          _SummaryRow(
            label: 'Cabinet sélectionné',
            value: review.cabinetName,
            detail: _cabinetAddress(review),
          ),
          _SummaryRow(
            label: authoritative
                ? 'Tarif urgent confirmé'
                : 'Tarif urgent de démonstration',
            value: formatUrgentCabinetFee(review.feeQuote),
            last: true,
          ),
        ],
      ),
    );
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
  const _FeeNotice({required this.authoritative});

  final bool authoritative;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('urgent-cabinet-accepted-fee-notice'),
      padding: const EdgeInsets.all(OmniSpacing.md),
      decoration: BoxDecoration(
        color: OmniColors.infoBlueSoft,
        borderRadius: BorderRadius.circular(OmniRadii.field),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: OmniColors.infoBlue,
            size: 20,
          ),
          const SizedBox(width: OmniSpacing.sm),
          Expanded(
            child: Text(
              authoritative
                  ? "Ce tarif est celui confirmé avec la demande acceptée. Aucun paiement n'est effectué sur cet écran."
                  : "Ce montant est une donnée de démonstration, pas un tarif réellement confirmé. Aucun paiement n'a été effectué.",
              style: const TextStyle(
                color: OmniColors.textPrimary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DirectionsCard extends StatelessWidget {
  const _DirectionsCard({required this.review, required this.authoritative});

  final UrgentCabinetRequestReview review;
  final bool authoritative;

  bool get _hasCoordinates =>
      authoritative &&
      review.cabinetLatitude != null &&
      review.cabinetLongitude != null;

  Future<void> _openDirections(BuildContext context) async {
    final latitude = review.cabinetLatitude;
    final longitude = review.cabinetLongitude;
    if (latitude == null || longitude == null) return;
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '$latitude,$longitude',
      'travelmode': 'driving',
    });
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Impossible d'ouvrir l'itinéraire.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: ValueKey(
        _hasCoordinates
            ? 'urgent-cabinet-directions-available'
            : 'urgent-cabinet-directions-unavailable',
      ),
      width: double.infinity,
      padding: const EdgeInsets.all(OmniSpacing.base),
      decoration: BoxDecoration(
        color: OmniColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(OmniRadii.card),
        border: Border.all(color: OmniColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.directions_outlined,
                color: OmniColors.slateBlue,
                size: 22,
              ),
              const SizedBox(width: OmniSpacing.sm),
              Expanded(
                child: Text(
                  'Itinéraire',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: OmniColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: OmniSpacing.sm),
          if (_hasCoordinates)
            OutlinedButton.icon(
              key: const ValueKey('urgent-cabinet-open-directions'),
              onPressed: () => _openDirections(context),
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text("Ouvrir l'itinéraire"),
            )
          else
            Text(
              authoritative
                  ? "L'itinéraire externe est indisponible pour cette demande."
                  : 'Itinéraire indisponible pour les adresses de démonstration.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                height: 1.45,
                color: OmniColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}

class _AcceptedUnavailable extends StatelessWidget {
  const _AcceptedUnavailable();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: OmniSpacing.xxl),
      child: Column(
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: OmniColors.textSecondary,
            size: 40,
          ),
          SizedBox(height: OmniSpacing.md),
          Text(
            'Cette acceptation ne peut plus être affichée.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _AcceptedFooter extends StatelessWidget {
  const _AcceptedFooter({
    required this.enabled,
    required this.authoritative,
    required this.canWithdraw,
    required this.withdrawing,
    required this.onWithdraw,
    required this.onExit,
  });

  final bool enabled;
  final bool authoritative;
  final bool canWithdraw;
  final bool withdrawing;
  final VoidCallback onWithdraw;
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
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 50),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (authoritative) ...[
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      key: const ValueKey('urgent-cabinet-withdraw'),
                      onPressed: canWithdraw && !withdrawing
                          ? onWithdraw
                          : null,
                      child: SizedBox(
                        height: 48,
                        child: Center(
                          child: withdrawing
                              ? const CircularProgressIndicator(strokeWidth: 2)
                              : const Text('Je ne peux plus venir'),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: OmniSpacing.sm),
                ],
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    key: const ValueKey('urgent-cabinet-accepted-exit'),
                    onPressed: enabled ? onExit : null,
                    child: Text(
                      authoritative
                          ? 'Fermer la confirmation'
                          : 'Terminer la démonstration',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
