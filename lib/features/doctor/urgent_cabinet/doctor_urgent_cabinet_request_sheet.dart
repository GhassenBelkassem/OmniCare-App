import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/omni_theme.dart';
import 'doctor_urgent_cabinet_controller.dart';
import 'doctor_urgent_cabinet_decision.dart';
import 'doctor_urgent_cabinet_request.dart';

Future<void> showDoctorUrgentCabinetRequestSheet(
  BuildContext context, {
  required DoctorUrgentCabinetRequest request,
  required DoctorUrgentCabinetController controller,
  ValueChanged<BuildContext>? onSheetContextReady,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (sheetContext) {
    onSheetContextReady?.call(sheetContext);
    return DoctorUrgentCabinetRequestSheet(
      request: request,
      controller: controller,
      onClose: () => Navigator.of(sheetContext).pop(),
    );
  },
);

class DoctorUrgentCabinetRequestSheet extends StatelessWidget {
  const DoctorUrgentCabinetRequestSheet({
    super.key,
    required this.request,
    required this.controller,
    required this.onClose,
  });

  final DoctorUrgentCabinetRequest request;
  final DoctorUrgentCabinetController controller;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final feeProvenance = request.isDevelopmentFixture
        ? 'Tarif de démonstration locale'
        : 'Tarif confirmé par le service';
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final state = controller.stateFor(request.stableIdentity);
        final deciding = state is DoctorUrgentCabinetDecisionInProgress;
        return PopScope<void>(
          canPop: !deciding,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * .88,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: SingleChildScrollView(
                    key: const ValueKey(
                      'doctor-urgent-cabinet-request-sheet-scroll',
                    ),
                    padding: const EdgeInsets.fromLTRB(
                      OmniSpacing.pageHorizontal,
                      OmniSpacing.sm,
                      OmniSpacing.pageHorizontal,
                      OmniSpacing.lg,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              color: OmniColors.urgentCoral,
                            ),
                            const SizedBox(width: OmniSpacing.sm),
                            Expanded(
                              child: Text(
                                'URGENCE AU CABINET',
                                style: textTheme.labelLarge?.copyWith(
                                  color: OmniColors.urgentCoral,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            IconButton(
                              key: const ValueKey(
                                'doctor-urgent-cabinet-sheet-close-icon',
                              ),
                              tooltip: 'Fermer',
                              onPressed: deciding ? null : onClose,
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                        Text(
                          'Nouvelle demande urgente',
                          style: textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: OmniSpacing.lg),
                        Semantics(
                          label:
                              '${request.patient.label}. ${request.patient.disclosure}.',
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const CircleAvatar(
                                backgroundColor: OmniColors.slateSoft,
                                foregroundColor: OmniColors.slateBlue,
                                child: Icon(Icons.person_outline_rounded),
                              ),
                              const SizedBox(width: OmniSpacing.md),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      request.patient.label,
                                      style: textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: OmniSpacing.xs),
                                    Text(
                                      request.patient.disclosure,
                                      style: textTheme.bodyMedium?.copyWith(
                                        color: OmniColors.textSecondary,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: OmniSpacing.lg),
                        _SheetSection(
                          icon: Icons.medical_services_outlined,
                          eyebrow: 'CABINET SÉLECTIONNÉ',
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                request.cabinet.name,
                                style: textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: OmniSpacing.xs),
                              Text(
                                '${request.cabinet.address}\n'
                                '${request.cabinet.city}, ${request.cabinet.governorate}',
                                style: textTheme.bodyMedium?.copyWith(
                                  height: 1.45,
                                ),
                              ),
                              const SizedBox(height: OmniSpacing.sm),
                              Text(
                                request.isDevelopmentFixture
                                    ? 'Configuration locale de démonstration non vérifiée'
                                    : 'Cabinet ciblé par la demande autorisée',
                                style: textTheme.bodySmall?.copyWith(
                                  color: OmniColors.textSecondary,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: OmniSpacing.md),
                        Semantics(
                          label:
                              'Tarif de consultation urgente. ${request.fee.formattedAmount}. $feeProvenance.',
                          child: _SheetSection(
                            icon: Icons.payments_outlined,
                            eyebrow: 'TARIF DE CONSULTATION URGENTE',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  request.fee.formattedAmount,
                                  style: textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: OmniSpacing.xs),
                                Text(
                                  feeProvenance,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: OmniColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: OmniSpacing.md),
                        _Notice(
                          icon: Icons.info_outline_rounded,
                          message: request.isDevelopmentFixture
                              ? "Aucun motif médical n'a été recueilli dans ce parcours."
                              : request.structuredTriageLabel,
                        ),
                        if (!request.isDevelopmentFixture) ...[
                          const SizedBox(height: OmniSpacing.md),
                          _SheetSection(
                            icon: Icons.notes_rounded,
                            eyebrow: 'DESCRIPTION DU SYMPTÔME',
                            child: Text(
                              request.shortDescription!,
                              key: const ValueKey(
                                'doctor-urgent-cabinet-short-description',
                              ),
                              style: textTheme.bodyMedium?.copyWith(height: 1.45),
                            ),
                          ),
                        ],
                        const SizedBox(height: OmniSpacing.md),
                        _Notice(
                          icon: Icons.science_outlined,
                          message: request.isDevelopmentFixture
                              ? "Simulation locale — aucune demande réelle n'a été reçue."
                              : 'Demande reçue du service CABINET autorisé.',
                        ),
                      ],
                    ),
                  ),
                ),
                SafeArea(
                  top: false,
                  minimum: const EdgeInsets.fromLTRB(
                    OmniSpacing.pageHorizontal,
                    OmniSpacing.sm,
                    OmniSpacing.pageHorizontal,
                    OmniSpacing.base,
                  ),
                  child: _DecisionFooter(
                    state: state,
                    onAccept: () =>
                        unawaited(controller.accept(request.stableIdentity)),
                    onRefuse: () => unawaited(_confirmRefusal(context, state)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmRefusal(
    BuildContext context,
    DoctorUrgentCabinetDecisionState? state,
  ) async {
    final authoritativeRequest = state?.request;
    final canRefuse =
        authoritativeRequest?.canDecline == true &&
        (state is DoctorUrgentCabinetAwaitingDecision ||
            (state is DoctorUrgentCabinetDecisionFailed &&
                state.action == DoctorUrgentCabinetDecisionAction.refuse));
    if (!canRefuse) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        key: const ValueKey('doctor-urgent-cabinet-refuse-dialog'),
        title: const Text('Refuser cette demande ?'),
        content: const Text(
          'Cette demande sera retirée de vos nouvelles demandes.',
        ),
        actions: [
          TextButton(
            key: const ValueKey('doctor-urgent-cabinet-refuse-cancel'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            key: const ValueKey('doctor-urgent-cabinet-refuse-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Confirmer le refus'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await controller.refuse(request.stableIdentity);
    }
  }
}

class _DecisionFooter extends StatelessWidget {
  const _DecisionFooter({
    required this.state,
    required this.onAccept,
    required this.onRefuse,
  });

  final DoctorUrgentCabinetDecisionState? state;
  final VoidCallback onAccept;
  final VoidCallback onRefuse;

  @override
  Widget build(BuildContext context) {
    final inProgress = state is DoctorUrgentCabinetDecisionInProgress;
    final failed = state is DoctorUrgentCabinetDecisionFailed
        ? state! as DoctorUrgentCabinetDecisionFailed
        : null;
    final unknown = state is DoctorUrgentCabinetDecisionOutcomeUnknown
        ? state! as DoctorUrgentCabinetDecisionOutcomeUnknown
        : null;
    final capacityBlocked = state is DoctorUrgentCabinetCapacityBlocked
        ? state! as DoctorUrgentCabinetCapacityBlocked
        : null;
    final activeAction = inProgress
        ? (state! as DoctorUrgentCabinetDecisionInProgress).action
        : null;
    final authoritativeRequest = state?.request;
    final acceptEnabled =
        authoritativeRequest?.canAccept == true &&
        (state is DoctorUrgentCabinetAwaitingDecision ||
            failed?.action == DoctorUrgentCabinetDecisionAction.accept);
    final refuseEnabled =
        authoritativeRequest?.canDecline == true &&
        (state is DoctorUrgentCabinetAwaitingDecision ||
            failed?.action == DoctorUrgentCabinetDecisionAction.refuse);
    final message =
        failed?.message ?? unknown?.message ?? capacityBlocked?.message;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (message != null) ...[
          Semantics(
            liveRegion: true,
            label: message,
            child: Container(
              key: ValueKey(
                unknown == null && capacityBlocked == null
                    ? 'doctor-urgent-cabinet-decision-error'
                    : capacityBlocked != null
                    ? 'doctor-urgent-cabinet-capacity-blocked'
                    : 'doctor-urgent-cabinet-decision-unknown',
              ),
              padding: const EdgeInsets.all(OmniSpacing.sm),
              decoration: BoxDecoration(
                color: unknown == null && capacityBlocked == null
                    ? OmniColors.errorSoft
                    : OmniColors.infoBlueSoft,
                borderRadius: BorderRadius.circular(OmniRadii.field),
              ),
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: OmniColors.textPrimary,
                  height: 1.4,
                ),
              ),
            ),
          ),
          const SizedBox(height: OmniSpacing.sm),
        ],
        if (inProgress)
          Semantics(
            liveRegion: true,
            label: activeAction == DoctorUrgentCabinetDecisionAction.accept
                ? "Acceptation de la demande en cours"
                : 'Refus de la demande en cours',
            child: const SizedBox.shrink(),
          ),
        LayoutBuilder(
          builder: (context, constraints) {
            final stack =
                constraints.maxWidth < 330 ||
                MediaQuery.textScalerOf(context).scale(1) > 1.5;
            final refuse = _DecisionButton(
              key: const ValueKey('doctor-urgent-cabinet-refuse'),
              filled: false,
              label: failed?.action == DoctorUrgentCabinetDecisionAction.refuse
                  ? 'Réessayer le refus'
                  : 'Refuser',
              loading: activeAction == DoctorUrgentCabinetDecisionAction.refuse,
              onPressed: !inProgress && refuseEnabled ? onRefuse : null,
            );
            final accept = _DecisionButton(
              key: const ValueKey('doctor-urgent-cabinet-accept'),
              filled: true,
              label: failed?.action == DoctorUrgentCabinetDecisionAction.accept
                  ? "Réessayer l'acceptation"
                  : 'Accepter',
              loading: activeAction == DoctorUrgentCabinetDecisionAction.accept,
              onPressed: !inProgress && acceptEnabled ? onAccept : null,
            );
            if (stack) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  accept,
                  const SizedBox(height: OmniSpacing.sm),
                  refuse,
                ],
              );
            }
            return Row(
              children: [
                Expanded(child: refuse),
                const SizedBox(width: OmniSpacing.sm),
                Expanded(child: accept),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _DecisionButton extends StatelessWidget {
  const _DecisionButton({
    super.key,
    required this.filled,
    required this.label,
    required this.loading,
    required this.onPressed,
  });

  final bool filled;
  final String label;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final child = SizedBox(
      height: 48,
      child: Center(
        child: loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            : Text(label, textAlign: TextAlign.center),
      ),
    );
    return filled
        ? FilledButton(onPressed: onPressed, child: child)
        : OutlinedButton(onPressed: onPressed, child: child);
  }
}

class _SheetSection extends StatelessWidget {
  const _SheetSection({
    required this.icon,
    required this.eyebrow,
    required this.child,
  });

  final IconData icon;
  final String eyebrow;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
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
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: OmniColors.slateBlue),
            const SizedBox(width: OmniSpacing.sm),
            Expanded(
              child: Text(
                eyebrow,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: OmniColors.slateBlue,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: OmniSpacing.md),
        child,
      ],
    ),
  );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
    label: message,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(OmniSpacing.md),
      decoration: BoxDecoration(
        color: OmniColors.slateSoft,
        borderRadius: BorderRadius.circular(OmniRadii.field),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: OmniColors.slateBlue),
          const SizedBox(width: OmniSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: OmniColors.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
