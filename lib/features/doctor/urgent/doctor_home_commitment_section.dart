import 'package:flutter/material.dart';

import '../../../core/theme/omni_theme.dart';
import 'doctor_home_commitment.dart';
import 'doctor_home_commitment_controller.dart';
import 'doctor_home_dispatch_context_controller.dart';

class DoctorHomeCommitmentSection extends StatelessWidget {
  const DoctorHomeCommitmentSection({
    super.key,
    required this.controller,
    this.dispatchContextController,
  });

  final DoctorHomeCommitmentController controller;
  final DoctorHomeDispatchContextController? dispatchContextController;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([controller, ?dispatchContextController]),
    builder: (context, _) => Semantics(
      container: true,
      liveRegion: true,
      label: 'Responsabilité HOME, statut serveur',
      child: Container(
        key: const ValueKey('doctor-home-commitment-card'),
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
                CircleAvatar(
                  backgroundColor: _iconBackground,
                  child: Icon(_icon, color: _iconColor),
                ),
                const SizedBox(width: OmniSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Responsabilité HOME',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        _subtitle,
                        key: const ValueKey('doctor-home-commitment-status'),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: OmniColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: const ValueKey('doctor-home-commitment-refresh'),
                  tooltip: 'Actualiser la responsabilité HOME',
                  onPressed: controller.isLoading ? null : controller.refresh,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: OmniSpacing.lg),
            _content(context),
          ],
        ),
      ),
    ),
  );

  Widget _content(BuildContext context) => switch (controller.state) {
    DoctorHomeCommitmentState.initial ||
    DoctorHomeCommitmentState.loading => const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: OmniSpacing.lg),
        child: CircularProgressIndicator(),
      ),
    ),
    DoctorHomeCommitmentState.noActiveCommitment => Text(
      'Aucune mission HOME confirmée.',
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: OmniColors.textSecondary),
    ),
    DoctorHomeCommitmentState.activeCommitment => _commitmentDetails(
      context,
      controller.commitment!,
      active: true,
    ),
    DoctorHomeCommitmentState.terminalCommitment => _commitmentDetails(
      context,
      controller.commitment!,
      active: false,
    ),
    DoctorHomeCommitmentState.unavailable ||
    DoctorHomeCommitmentState.failure => _FailureContent(
      message:
          controller.message ??
          'La responsabilité HOME ne peut pas être vérifiée.',
      onRetry: controller.refresh,
    ),
  };

  Widget _commitmentDetails(
    BuildContext context,
    DoctorHomeCommitment commitment, {
    required bool active,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(OmniSpacing.md),
        decoration: BoxDecoration(
          color: active ? OmniColors.mintSoft : OmniColors.slateSoft,
          borderRadius: BorderRadius.circular(OmniRadii.field),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              commitment.status.frenchLabel,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: active
                    ? OmniColors.deepTealActive
                    : OmniColors.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: OmniSpacing.xs),
            Text(
              active
                  ? 'Le Patient vous a sélectionné et le serveur confirme votre responsabilité.'
                  : 'Cette responsabilité n’est plus active. Aucune disponibilité HOME n’est réactivée automatiquement.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: OmniColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: OmniSpacing.md),
      _FactRow(label: 'Référence', value: commitment.shortIdentity),
      _FactRow(label: 'Révision', value: '${commitment.revision}'),
      _FactRow(
        label: 'Tarif HOME',
        value: '${commitment.quotedHomeFeeTnd} ${commitment.currency}',
      ),
      _FactRow(
        label: active ? 'Confirmé le' : 'Terminé le',
        value: _formatDate(
          active ? commitment.committedAt : commitment.terminalAt!,
        ),
      ),
      if (active && dispatchContextController != null)
        _FactRow(
          key: const ValueKey('doctor-home-dispatch-destination'),
          label: 'Destination',
          value: _destinationValue,
        ),
      const SizedBox(height: OmniSpacing.md),
      Text(
        'Seule l’adresse confirmée peut apparaître après vérification de l’engagement actif. L’identité Patient, la navigation, l’arrivée, le QR et le dossier médical ne sont pas autorisés par ce contrat.',
        key: const ValueKey('doctor-home-commitment-privacy-boundary'),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: OmniColors.textSecondary,
          height: 1.45,
        ),
      ),
    ],
  );

  String get _destinationValue => switch (dispatchContextController!.state) {
    DoctorHomeDispatchContextState.available =>
      dispatchContextController!.dispatchContext!.destination.confirmedAddress,
    DoctorHomeDispatchContextState.loading => 'Vérification en cours…',
    DoctorHomeDispatchContextState.notFound => 'Non disponible',
    DoctorHomeDispatchContextState.unavailable ||
    DoctorHomeDispatchContextState.failure => 'Vérification indisponible',
    DoctorHomeDispatchContextState.initial => 'Vérification requise',
  };

  String get _subtitle => switch (controller.state) {
    DoctorHomeCommitmentState.initial => 'Vérification à démarrer',
    DoctorHomeCommitmentState.loading => 'Vérification en cours',
    DoctorHomeCommitmentState.noActiveCommitment => 'Aucune mission confirmée',
    DoctorHomeCommitmentState.activeCommitment => 'Engagement serveur actif',
    DoctorHomeCommitmentState.terminalCommitment => 'Engagement terminé',
    DoctorHomeCommitmentState.unavailable => 'Vérification indisponible',
    DoctorHomeCommitmentState.failure => 'Vérification échouée',
  };

  IconData get _icon => switch (controller.state) {
    DoctorHomeCommitmentState.activeCommitment => Icons.verified_user_outlined,
    DoctorHomeCommitmentState.terminalCommitment => Icons.event_busy_outlined,
    DoctorHomeCommitmentState.unavailable ||
    DoctorHomeCommitmentState.failure => Icons.cloud_off_outlined,
    _ => Icons.assignment_ind_outlined,
  };

  Color get _iconBackground =>
      controller.state == DoctorHomeCommitmentState.activeCommitment
      ? OmniColors.mintSoft
      : OmniColors.slateSoft;

  Color get _iconColor =>
      controller.state == DoctorHomeCommitmentState.activeCommitment
      ? OmniColors.deepTeal
      : OmniColors.slateBlue;
}

class _FactRow extends StatelessWidget {
  const _FactRow({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: OmniSpacing.xs),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 104,
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: OmniColors.textSecondary),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

class _FailureContent extends StatelessWidget {
  const _FailureContent({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(message, style: Theme.of(context).textTheme.bodyMedium),
      const SizedBox(height: OmniSpacing.sm),
      Text(
        'Cet état n’est pas interprété comme une absence d’engagement.',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: OmniColors.textSecondary),
      ),
      const SizedBox(height: OmniSpacing.sm),
      TextButton.icon(
        key: const ValueKey('doctor-home-commitment-retry'),
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded, size: 18),
        label: const Text('Réessayer'),
      ),
    ],
  );
}

String _formatDate(DateTime value) {
  final local = value.toLocal();
  String two(int part) => part.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} · ${two(local.hour)}:${two(local.minute)}';
}
