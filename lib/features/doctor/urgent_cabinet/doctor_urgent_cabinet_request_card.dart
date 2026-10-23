import 'package:flutter/material.dart';

import '../../../core/theme/omni_theme.dart';
import 'doctor_urgent_cabinet_request.dart';

class DoctorUrgentCabinetRequestCard extends StatelessWidget {
  const DoctorUrgentCabinetRequestCard({
    super.key,
    required this.request,
    required this.onOpen,
  });

  final DoctorUrgentCabinetRequest request;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final feeProvenance = request.isDevelopmentFixture
        ? 'tarif de démonstration locale'
        : 'tarif confirmé par le service';
    return Semantics(
      container: true,
      label:
          'Urgence au cabinet. Nouvelle demande. ${request.patient.label}. '
          '${request.patient.disclosure}. Cabinet ${request.cabinet.name}. '
          'Tarif ${request.fee.formattedAmount}, $feeProvenance.',
      child: Container(
        key: ValueKey(
          'doctor-urgent-cabinet-request-${request.stableIdentity}',
        ),
        width: double.infinity,
        decoration: BoxDecoration(
          color: OmniColors.surfacePrimary,
          borderRadius: BorderRadius.circular(OmniRadii.cardLarge),
          border: Border.all(
            color: OmniColors.urgentCoral.withValues(alpha: .22),
          ),
          boxShadow: const [OmniColors.shadowCard],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(OmniRadii.cardLarge - 1),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(width: 3, color: OmniColors.urgentCoral),
              ),
              Padding(
                padding: const EdgeInsets.all(OmniSpacing.base),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: OmniColors.urgentCoral,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'URGENCE AU CABINET',
                            softWrap: true,
                            style: textTheme.labelSmall?.copyWith(
                              color: OmniColors.urgentCoral,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: OmniSpacing.sm),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: OmniSpacing.sm,
                          vertical: OmniSpacing.xs,
                        ),
                        decoration: BoxDecoration(
                          color: OmniColors.urgentCoralSoft,
                          borderRadius: BorderRadius.circular(OmniRadii.pill),
                        ),
                        child: Text(
                          'Nouvelle demande',
                          softWrap: true,
                          style: textTheme.labelSmall?.copyWith(
                            color: OmniColors.urgentCoral,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: OmniSpacing.base),
                    _DetailRow(
                      icon: Icons.person_outline_rounded,
                      title: request.patient.label,
                      detail: request.patient.disclosure,
                    ),
                    const SizedBox(height: OmniSpacing.md),
                    _DetailRow(
                      icon: Icons.medical_services_outlined,
                      title: request.cabinet.name,
                      detail:
                          '${request.cabinet.address}\n'
                          '${request.cabinet.city}, ${request.cabinet.governorate}',
                    ),
                    const SizedBox(height: OmniSpacing.md),
                    Semantics(
                      label:
                          'Tarif ${request.fee.formattedAmount}. $feeProvenance.',
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(OmniSpacing.md),
                        decoration: BoxDecoration(
                          color: OmniColors.slateSoft,
                          borderRadius: BorderRadius.circular(OmniRadii.field),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              request.fee.formattedAmount,
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: OmniSpacing.xs),
                            Text(
                              request.isDevelopmentFixture
                                  ? 'Tarif de démonstration locale'
                                  : 'Tarif confirmé',
                              style: textTheme.bodySmall?.copyWith(
                                color: OmniColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: OmniSpacing.base),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        key: ValueKey(
                          'doctor-urgent-cabinet-open-${request.stableIdentity}',
                        ),
                        onPressed: onOpen,
                        icon: const Icon(Icons.visibility_outlined, size: 18),
                        label: const Text('Voir la demande'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 38,
        height: 38,
        decoration: const BoxDecoration(
          color: OmniColors.slateSoft,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 20, color: OmniColors.slateBlue),
      ),
      const SizedBox(width: OmniSpacing.md),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: OmniSpacing.xs),
            Text(
              detail,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: OmniColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
