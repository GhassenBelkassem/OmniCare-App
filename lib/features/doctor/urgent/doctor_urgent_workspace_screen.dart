import 'package:flutter/material.dart';

import '../../../core/theme/omni_theme.dart';
import '../urgent_cabinet/doctor_urgent_cabinet_controller.dart';
import '../urgent_cabinet/doctor_urgent_cabinet_screen.dart';
import '../active_consultation/doctor_active_consultation_controller.dart';
import '../workspace/doctor_workspace_config.dart';
import 'doctor_home_offer_inbox_controller.dart';
import 'doctor_home_offer_inbox_section.dart';
import 'doctor_home_commitment_controller.dart';
import 'doctor_home_commitment_section.dart';
import 'doctor_home_dispatch_context_controller.dart';
import 'doctor_urgent_controller.dart';
import 'doctor_home_presence_controller.dart';
import 'doctor_urgent_runtime_controller.dart';
import 'doctor_urgent_screen.dart';

enum DoctorUrgentMode { home, cabinet }

/// Capability-driven content for the single Doctor Urgences destination.
///
/// Global navigation and mode selection remain owned by [DoctorAppShell]. This
/// widget deliberately mounts only the visible mode so a hidden HOME map does
/// not continue doing presentation work.
class DoctorUrgentWorkspaceScreen extends StatelessWidget {
  const DoctorUrgentWorkspaceScreen({
    super.key,
    required this.capabilities,
    required this.workspaceConfig,
    required this.selectedMode,
    required this.onModeChanged,
    required this.homeController,
    required this.urgentCabinetController,
    this.activeConsultationController,
    this.onOpenHomeQr,
    this.homeOperationalMessage,
    this.cabinetOperationalMessage,
    this.runtimeController,
    this.homePresenceController,
    this.homeOfferController,
    this.homeCommitmentController,
    this.homeDispatchContextController,
  });

  final Set<DoctorCapability> capabilities;
  final DoctorWorkspaceConfig? workspaceConfig;
  final DoctorUrgentMode selectedMode;
  final ValueChanged<DoctorUrgentMode> onModeChanged;
  final DoctorUrgentController homeController;
  final DoctorUrgentCabinetController urgentCabinetController;
  final DoctorActiveConsultationController? activeConsultationController;
  final VoidCallback? onOpenHomeQr;
  final String? homeOperationalMessage;
  final String? cabinetOperationalMessage;
  final DoctorUrgentRuntimeController? runtimeController;
  final DoctorHomePresenceController? homePresenceController;
  final DoctorHomeOfferInboxController? homeOfferController;
  final DoctorHomeCommitmentController? homeCommitmentController;
  final DoctorHomeDispatchContextController? homeDispatchContextController;

  bool get _hasHome =>
      capabilities.contains(DoctorCapability.urgentHomeRequests) ||
      homeCommitmentController?.hasVisibleResponsibility == true;

  bool get _hasConfiguredHome =>
      capabilities.contains(DoctorCapability.urgentHomeRequests);

  bool get _hasCabinet =>
      capabilities.contains(DoctorCapability.urgentCabinetRequests);

  @override
  Widget build(BuildContext context) {
    if (_hasHome && !_hasCabinet) {
      return _modeContent(DoctorUrgentMode.home);
    }
    if (_hasCabinet && !_hasHome) {
      return _modeContent(DoctorUrgentMode.cabinet);
    }
    if (!_hasHome || !_hasCabinet) return const SizedBox.shrink();

    final effectiveMode = switch (selectedMode) {
      DoctorUrgentMode.home when _hasHome => DoctorUrgentMode.home,
      DoctorUrgentMode.cabinet when _hasCabinet => DoctorUrgentMode.cabinet,
      _ when _hasHome => DoctorUrgentMode.home,
      _ => DoctorUrgentMode.cabinet,
    };
    final motion = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 200);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            OmniSpacing.pageHorizontal,
            OmniSpacing.md,
            OmniSpacing.pageHorizontal,
            0,
          ),
          child: Semantics(
            label: 'Mode des urgences',
            container: true,
            child: SegmentedButton<DoctorUrgentMode>(
              key: const ValueKey('doctor-urgent-mode-selector'),
              segments: const [
                ButtonSegment(
                  value: DoctorUrgentMode.home,
                  label: Text(
                    'À domicile',
                    key: ValueKey('doctor-urgent-mode-home'),
                    textAlign: TextAlign.center,
                  ),
                ),
                ButtonSegment(
                  value: DoctorUrgentMode.cabinet,
                  label: Text(
                    'Au cabinet',
                    key: ValueKey('doctor-urgent-mode-cabinet'),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
              selected: {effectiveMode},
              showSelectedIcon: false,
              expandedInsets: EdgeInsets.zero,
              style: ButtonStyle(
                minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
                foregroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? OmniColors.deepTealActive
                      : OmniColors.textSecondary,
                ),
                backgroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? OmniColors.mintSoft
                      : OmniColors.surfacePrimary,
                ),
                side: WidgetStateProperty.resolveWith(
                  (states) => BorderSide(
                    color: states.contains(WidgetState.selected)
                        ? OmniColors.freshMint
                        : OmniColors.borderLight,
                  ),
                ),
                textStyle: const WidgetStatePropertyAll(
                  TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              onSelectionChanged: (selection) {
                if (selection.isNotEmpty) onModeChanged(selection.first);
              },
            ),
          ),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: motion,
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: switch (effectiveMode) {
              DoctorUrgentMode.home => KeyedSubtree(
                key: const ValueKey('doctor-urgent-home-content'),
                child: _modeContent(DoctorUrgentMode.home),
              ),
              DoctorUrgentMode.cabinet => KeyedSubtree(
                key: const ValueKey('doctor-urgent-cabinet-content'),
                child: _modeContent(DoctorUrgentMode.cabinet),
              ),
            },
          ),
        ),
      ],
    );
  }

  Widget _modeContent(DoctorUrgentMode mode) {
    final message = switch (mode) {
      DoctorUrgentMode.home => homeOperationalMessage,
      DoctorUrgentMode.cabinet => cabinetOperationalMessage,
    };
    if (message != null ||
        (mode == DoctorUrgentMode.home &&
            (homeOfferController != null ||
                homeCommitmentController != null))) {
      return _DoctorUrgentBackendGate(
        key: ValueKey('doctor-urgent-${mode.name}-backend-gate'),
        mode: mode,
        message:
            message ??
            'Les commandes HOME restent désactivées dans cette version Flutter.',
        runtimeController: runtimeController,
        homePresenceController: homePresenceController,
        homeOfferController: mode == DoctorUrgentMode.home
            ? homeOfferController
            : null,
        homeCommitmentController: mode == DoctorUrgentMode.home
            ? homeCommitmentController
            : null,
        homeDispatchContextController: mode == DoctorUrgentMode.home
            ? homeDispatchContextController
            : null,
        homeCapabilityConfigured:
            mode != DoctorUrgentMode.home || _hasConfiguredHome,
      );
    }
    return switch (mode) {
      DoctorUrgentMode.home => DoctorUrgentScreen(
        controller: homeController,
        onOpenQr: onOpenHomeQr,
      ),
      DoctorUrgentMode.cabinet => DoctorUrgentCabinetScreen(
        workspaceConfig: workspaceConfig,
        controller: urgentCabinetController,
        activeConsultationController: activeConsultationController,
      ),
    };
  }
}

class _DoctorUrgentBackendGate extends StatelessWidget {
  const _DoctorUrgentBackendGate({
    super.key,
    required this.mode,
    required this.message,
    this.runtimeController,
    this.homePresenceController,
    this.homeOfferController,
    this.homeCommitmentController,
    this.homeDispatchContextController,
    required this.homeCapabilityConfigured,
  });

  final DoctorUrgentMode mode;
  final String message;
  final DoctorUrgentRuntimeController? runtimeController;
  final DoctorHomePresenceController? homePresenceController;
  final DoctorHomeOfferInboxController? homeOfferController;
  final DoctorHomeCommitmentController? homeCommitmentController;
  final DoctorHomeDispatchContextController? homeDispatchContextController;
  final bool homeCapabilityConfigured;

  DoctorUrgentRuntimeMode get _runtimeMode => switch (mode) {
    DoctorUrgentMode.home => DoctorUrgentRuntimeMode.home,
    DoctorUrgentMode.cabinet => DoctorUrgentRuntimeMode.cabinet,
  };

  @override
  Widget build(BuildContext context) {
    final controller = runtimeController;
    if (controller == null) return _content(context, null);
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => _content(context, controller),
    );
  }

  Widget _content(
    BuildContext context,
    DoctorUrgentRuntimeController? controller,
  ) {
    final rolloutUnavailable =
        controller?.state == DoctorUrgentRuntimeState.unavailable;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        OmniSpacing.pageHorizontal,
        OmniSpacing.pageVertical,
        OmniSpacing.pageHorizontal,
        OmniSpacing.xxl,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                mode == DoctorUrgentMode.home
                    ? 'Urgences à domicile'
                    : 'Urgences au cabinet',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: OmniSpacing.sm),
              Text(
                mode == DoctorUrgentMode.home
                    ? 'Pour les urgences à domicile, la distance routière est calculée à partir de la position que vous activez dans l’application.'
                    : 'Le lieu est celui du cabinet actif enregistré dans votre espace professionnel.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: OmniColors.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: OmniSpacing.xl),
              if (mode == DoctorUrgentMode.home &&
                  homeCommitmentController != null &&
                  (!rolloutUnavailable ||
                      homeCommitmentController!.hasVisibleResponsibility)) ...[
                DoctorHomeCommitmentSection(
                  controller: homeCommitmentController!,
                  dispatchContextController: homeDispatchContextController,
                ),
                const SizedBox(height: OmniSpacing.lg),
              ],
              if (controller != null && homeCapabilityConfigured) ...[
                _DoctorRuntimeAvailabilityCard(
                  mode: _runtimeMode,
                  controller: controller,
                  homePresenceController: homePresenceController,
                ),
                const SizedBox(height: OmniSpacing.lg),
                if (!rolloutUnavailable &&
                    mode == DoctorUrgentMode.home &&
                    homePresenceController != null) ...[
                  _DoctorHomePresenceCard(controller: homePresenceController!),
                  const SizedBox(height: OmniSpacing.lg),
                ],
              ],
              if (!rolloutUnavailable &&
                  mode == DoctorUrgentMode.home &&
                  homeCapabilityConfigured &&
                  homeOfferController != null) ...[
                DoctorHomeOfferInboxSection(controller: homeOfferController!),
                const SizedBox(height: OmniSpacing.lg),
              ],
              if (!rolloutUnavailable)
                Semantics(
                  liveRegion: true,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(OmniSpacing.lg),
                    decoration: BoxDecoration(
                      color: OmniColors.amberSoft,
                      borderRadius: BorderRadius.circular(OmniRadii.card),
                      border: Border.all(
                        color: OmniColors.amber.withValues(alpha: .4),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: OmniColors.amber,
                        ),
                        const SizedBox(width: OmniSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                mode == DoctorUrgentMode.home &&
                                        homeCapabilityConfigured &&
                                        homeOfferController != null
                                    ? 'Commandes HOME indisponibles'
                                    : 'Actions opérationnelles indisponibles',
                                style: Theme.of(context).textTheme.titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: OmniSpacing.xs),
                              Text(
                                mode == DoctorUrgentMode.home &&
                                        homeCapabilityConfigured &&
                                        homeOfferController != null
                                    ? 'La consultation de l’inbox serveur est active en lecture seule. Accepter, décliner ou retirer un maintien n’est pas disponible.'
                                    : message,
                              ),
                              const SizedBox(height: OmniSpacing.sm),
                              Text(
                                mode == DoctorUrgentMode.home &&
                                        homeCapabilityConfigured &&
                                        homeOfferController != null
                                    ? 'Chaque ouverture de statut relit l’autorité serveur. Aucun contenu Patient, trajet ou mission n’est déduit localement.'
                                    : controller == null
                                    ? 'La configuration permanente reste gérée dans les paramètres professionnels. Aucune disponibilité, position ou mission n’est activée ici.'
                                    : mode == DoctorUrgentMode.cabinet
                                    ? 'La réception CABINET reste pilotée par la capacité et l’autorité serveur. Actualisez après avoir corrigé la configuration indiquée.'
                                    : 'Cette commande enregistre uniquement votre intention de disponibilité. Elle n’active ni GPS, ni réception de demandes, ni mission.',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(color: OmniColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DoctorRuntimeAvailabilityCard extends StatelessWidget {
  const _DoctorRuntimeAvailabilityCard({
    required this.mode,
    required this.controller,
    this.homePresenceController,
  });

  final DoctorUrgentRuntimeMode mode;
  final DoctorUrgentRuntimeController controller;
  final DoctorHomePresenceController? homePresenceController;

  @override
  Widget build(BuildContext context) {
    final enabled = controller.isEnabled(mode);
    final saving = controller.isSaving(mode);
    final canChange = controller.canChange(mode);
    final isHome = mode == DoctorUrgentRuntimeMode.home;
    final rolloutUnavailable =
        controller.state == DoctorUrgentRuntimeState.unavailable;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        key: ValueKey('doctor-urgent-${mode.name}-runtime-card'),
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
                  backgroundColor: enabled
                      ? OmniColors.mintSoft
                      : OmniColors.slateSoft,
                  child: Icon(
                    Icons.power_settings_new_rounded,
                    color: enabled ? OmniColors.deepTeal : OmniColors.slateBlue,
                  ),
                ),
                const SizedBox(width: OmniSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isHome
                            ? 'Disponibilité à domicile'
                            : 'Disponibilité au cabinet',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        rolloutUnavailable
                            ? 'Fonction indisponible dans cet environnement'
                            : enabled
                            ? 'Intention activée côté serveur'
                            : 'Intention désactivée côté serveur',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: OmniColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (saving)
                  const SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                else
                  Switch(
                    key: ValueKey('doctor-urgent-${mode.name}-runtime-switch'),
                    value: enabled,
                    onChanged: canChange
                        ? (value) {
                            if (mode == DoctorUrgentRuntimeMode.home &&
                                !value) {
                              homePresenceController?.stopForRuntimeOff();
                            }
                            controller.setEnabled(mode, value);
                          }
                        : null,
                  ),
              ],
            ),
            const SizedBox(height: OmniSpacing.md),
            Text(
              controller.modeMessage(mode),
              key: ValueKey('doctor-urgent-${mode.name}-runtime-message'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: OmniColors.textSecondary,
                height: 1.45,
              ),
            ),
            if (controller.feedback case final feedback?) ...[
              const SizedBox(height: OmniSpacing.sm),
              Text(
                feedback,
                key: const ValueKey('doctor-urgent-runtime-feedback'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: switch (controller.state) {
                    DoctorUrgentRuntimeState.failure => OmniColors.urgentCoral,
                    DoctorUrgentRuntimeState.unavailable =>
                      OmniColors.textSecondary,
                    _ => OmniColors.deepTeal,
                  },
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            if (controller.state == DoctorUrgentRuntimeState.failure ||
                controller.state == DoctorUrgentRuntimeState.unavailable) ...[
              const SizedBox(height: OmniSpacing.sm),
              TextButton.icon(
                key: const ValueKey('doctor-urgent-runtime-refresh'),
                onPressed: controller.savingMode == null
                    ? controller.refresh
                    : null,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Actualiser'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DoctorHomePresenceCard extends StatelessWidget {
  const _DoctorHomePresenceCard({required this.controller});

  final DoctorHomePresenceController controller;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final active = controller.isForegroundPublicationActive;
      return Semantics(
        container: true,
        liveRegion: true,
        label: 'Présence GPS HOME, ${controller.statusLabel}',
        child: Container(
          key: const ValueKey('doctor-home-presence-card'),
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
                    backgroundColor: active
                        ? OmniColors.mintSoft
                        : OmniColors.slateSoft,
                    child: Icon(
                      active
                          ? Icons.my_location_rounded
                          : Icons.location_searching_rounded,
                      color: active
                          ? OmniColors.deepTeal
                          : OmniColors.slateBlue,
                    ),
                  ),
                  const SizedBox(width: OmniSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Position pour les urgences à domicile',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          controller.statusLabel,
                          key: const ValueKey('doctor-home-presence-status'),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: OmniColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  if (controller.isPublishing)
                    const SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                ],
              ),
              const SizedBox(height: OmniSpacing.md),
              Text(
                controller.message ??
                    'La position est transmise uniquement après votre action, au premier plan.',
                key: const ValueKey('doctor-home-presence-message'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: OmniColors.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: OmniSpacing.md),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const ValueKey('doctor-home-presence-action'),
                  onPressed: controller.canStart
                      ? controller.startOrRefresh
                      : null,
                  icon: const Icon(Icons.gps_fixed_rounded, size: 18),
                  label: Text(
                    active
                        ? 'Actualiser maintenant'
                        : 'Partager ma position pour HOME',
                  ),
                ),
              ),
              const SizedBox(height: OmniSpacing.sm),
              Text(
                'Premier plan uniquement. Cette position n’active ni demande, ni mission, ni suivi Patient.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: OmniColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
