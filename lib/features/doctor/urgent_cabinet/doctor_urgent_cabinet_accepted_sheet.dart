import 'package:flutter/material.dart';

import '../../../core/theme/omni_theme.dart';
import 'doctor_urgent_cabinet_request.dart';

enum DoctorUrgentCabinetAcceptedSheetAction { verifyArrival, startConsultation }

@visibleForTesting
bool canVerifyDoctorUrgentCabinetArrival(DoctorUrgentCabinetRequest request) =>
    request.isDevelopmentFixture;

Future<DoctorUrgentCabinetAcceptedSheetAction?>
showDoctorUrgentCabinetAcceptedSheet(
  BuildContext context, {
  required DoctorUrgentCabinetRequest request,
  bool arrivalVerificationEnabled = false,
  bool consultationStartEnabled = false,
  bool arrivedWaitingForCapacity = false,
  ValueChanged<BuildContext>? onSheetContextReady,
}) {
  var transitionStarted = false;
  return showModalBottomSheet<DoctorUrgentCabinetAcceptedSheetAction>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) {
      onSheetContextReady?.call(sheetContext);
      return DoctorUrgentCabinetAcceptedSheet(
        request: request,
        onVerifyArrival:
            (arrivalVerificationEnabled ||
                canVerifyDoctorUrgentCabinetArrival(request))
            ? () {
                if (transitionStarted) return;
                transitionStarted = true;
                Navigator.of(
                  sheetContext,
                ).pop(DoctorUrgentCabinetAcceptedSheetAction.verifyArrival);
              }
            : null,
        onStartConsultation: consultationStartEnabled
            ? () {
                if (transitionStarted) return;
                transitionStarted = true;
                Navigator.of(
                  sheetContext,
                ).pop(DoctorUrgentCabinetAcceptedSheetAction.startConsultation);
              }
            : null,
        arrivedWaitingForCapacity: arrivedWaitingForCapacity,
        onClose: () => Navigator.of(sheetContext).pop(),
      );
    },
  );
}

class DoctorUrgentCabinetAcceptedSheet extends StatelessWidget {
  const DoctorUrgentCabinetAcceptedSheet({
    super.key,
    required this.request,
    required this.onVerifyArrival,
    required this.onStartConsultation,
    required this.arrivedWaitingForCapacity,
    required this.onClose,
  });

  final DoctorUrgentCabinetRequest request;
  final VoidCallback? onVerifyArrival;
  final VoidCallback? onStartConsultation;
  final bool arrivedWaitingForCapacity;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final provenance = request.isDevelopmentFixture
        ? "Simulation locale — aucune demande réelle n'a été reçue."
        : 'Donnée synthétique de développement issue du service.';
    final feeLabel = request.isDevelopmentFixture
        ? 'Tarif urgent de démonstration'
        : 'Tarif de consultation urgente';

    return ConstrainedBox(
      key: ValueKey(
        'doctor-urgent-cabinet-accepted-sheet-${request.stableIdentity}',
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .88,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: SingleChildScrollView(
              key: const ValueKey(
                'doctor-urgent-cabinet-accepted-sheet-scroll',
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.check_circle_outline_rounded,
                        color: OmniColors.deepTeal,
                      ),
                      const SizedBox(width: OmniSpacing.sm),
                      Expanded(
                        child: Text(
                          'Demande acceptée',
                          style: textTheme.labelLarge?.copyWith(
                            color: OmniColors.deepTeal,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        key: const ValueKey(
                          'doctor-urgent-cabinet-accepted-sheet-close-icon',
                        ),
                        tooltip: 'Fermer',
                        onPressed: onClose,
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                  Text(
                    'Patient attendu au cabinet',
                    style: textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: OmniSpacing.sm),
                  Text(
                    "La demande a été acceptée. L'arrivée du patient n'a pas encore été confirmée.",
                    style: textTheme.bodyMedium?.copyWith(
                      color: OmniColors.textSecondary,
                      height: 1.5,
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
                  _AcceptedSheetSection(
                    icon: Icons.medical_services_outlined,
                    eyebrow: 'CABINET ACCEPTÉ',
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
                          style: textTheme.bodyMedium?.copyWith(height: 1.45),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: OmniSpacing.md),
                  _AcceptedSheetSection(
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
                          feeLabel,
                          style: textTheme.bodySmall?.copyWith(
                            color: OmniColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: OmniSpacing.md),
                  const _AcceptedNotice(
                    icon: Icons.info_outline_rounded,
                    message:
                        "Aucun déplacement, arrivée ou début de consultation n'est confirmé.",
                  ),
                  if (arrivedWaitingForCapacity) ...[
                    const SizedBox(height: OmniSpacing.md),
                    const _AcceptedNotice(
                      icon: Icons.schedule_rounded,
                      message:
                          'Patient arrivé. Terminez la consultation en cours puis actualisez pour démarrer celle-ci.',
                    ),
                  ],
                  const SizedBox(height: OmniSpacing.md),
                  _AcceptedNotice(
                    icon: Icons.science_outlined,
                    message: provenance,
                    positive: request.isDevelopmentFixture,
                  ),
                ],
              ),
            ),
          ),
          DecoratedBox(
            decoration: const BoxDecoration(
              color: OmniColors.surfacePrimary,
              border: Border(top: BorderSide(color: OmniColors.borderLight)),
            ),
            child: SafeArea(
              top: false,
              minimum: const EdgeInsets.fromLTRB(
                OmniSpacing.pageHorizontal,
                OmniSpacing.md,
                OmniSpacing.pageHorizontal,
                OmniSpacing.base,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      key: ValueKey(
                        onStartConsultation != null
                            ? 'doctor-urgent-cabinet-accepted-sheet-start-consultation'
                            : 'doctor-urgent-cabinet-accepted-sheet-verify-arrival',
                      ),
                      style: buildOmniPrimaryButtonStyle(),
                      onPressed: onStartConsultation ?? onVerifyArrival,
                      child: SizedBox(
                        height: 48,
                        child: Center(
                          child: Text(
                            onStartConsultation != null
                                ? 'Démarrer la consultation'
                                : arrivedWaitingForCapacity
                                ? 'En attente de disponibilité'
                                : "Vérifier l'arrivée",
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: OmniSpacing.sm),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      key: const ValueKey(
                        'doctor-urgent-cabinet-accepted-sheet-close',
                      ),
                      onPressed: onClose,
                      child: const SizedBox(
                        height: 48,
                        child: Center(child: Text('Fermer')),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AcceptedSheetSection extends StatelessWidget {
  const _AcceptedSheetSection({
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

class _AcceptedNotice extends StatelessWidget {
  const _AcceptedNotice({
    required this.icon,
    required this.message,
    this.positive = false,
  });

  final IconData icon;
  final String message;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final foreground = positive ? OmniColors.deepTeal : OmniColors.slateBlue;
    final background = positive ? OmniColors.mintSoft : OmniColors.slateSoft;
    return Semantics(
      label: message,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(OmniSpacing.md),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(OmniRadii.field),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 19, color: foreground),
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
}
