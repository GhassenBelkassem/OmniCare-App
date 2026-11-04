import 'package:flutter/material.dart';

import '../../../core/theme/omni_theme.dart';
import 'doctor_urgent_cabinet_request.dart';

class DoctorUrgentCabinetAcceptedCard extends StatelessWidget {
  const DoctorUrgentCabinetAcceptedCard({
    super.key,
    required this.request,
    required this.onOpen,
  });

  final DoctorUrgentCabinetRequest request;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final provenance = request.isDevelopmentFixture
        ? 'Simulation locale — aucune demande réelle'
        : 'Donnée synthétique issue du service';
    final feeLabel = request.isDevelopmentFixture
        ? 'Tarif urgent de démonstration'
        : 'Tarif de consultation urgente';

    return Semantics(
      container: true,
      label:
          'Demande acceptée. Patient attendu au cabinet. '
          "L'arrivée du patient n'a pas encore été confirmée. "
          '${request.patient.label}. ${request.patient.disclosure}. '
          'Cabinet ${request.cabinet.name}. '
          'Tarif ${request.fee.formattedAmount}. $provenance.',
      child: Container(
        key: ValueKey(
          'doctor-urgent-cabinet-accepted-${request.stableIdentity}',
        ),
        width: double.infinity,
        padding: const EdgeInsets.all(OmniSpacing.base),
        decoration: BoxDecoration(
          color: OmniColors.surfacePrimary,
          borderRadius: BorderRadius.circular(OmniRadii.cardLarge),
          border: Border.all(
            color: OmniColors.freshMint.withValues(alpha: .28),
          ),
          boxShadow: const [OmniColors.shadowCard],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: OmniColors.mintSoft,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_outline_rounded,
                    color: OmniColors.deepTeal,
                    size: 23,
                  ),
                ),
                const SizedBox(width: OmniSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'DEMANDE ACCEPTÉE',
                        style: textTheme.labelSmall?.copyWith(
                          color: OmniColors.deepTeal,
                          fontWeight: FontWeight.w800,
                          letterSpacing: .4,
                        ),
                      ),
                      const SizedBox(height: OmniSpacing.xs),
                      Text(
                        'Patient attendu au cabinet',
                        style: textTheme.titleMedium?.copyWith(
                          color: OmniColors.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: OmniSpacing.md),
            Text(
              "La demande a été acceptée. L'arrivée du patient n'a pas encore été confirmée.",
              style: textTheme.bodyMedium?.copyWith(
                color: OmniColors.textSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: OmniSpacing.base),
            _AcceptedDetail(
              icon: Icons.person_outline_rounded,
              title: request.patient.label,
              detail: request.patient.disclosure,
            ),
            const SizedBox(height: OmniSpacing.md),
            _AcceptedDetail(
              icon: Icons.medical_services_outlined,
              title: request.cabinet.name,
              detail:
                  '${request.cabinet.address}\n'
                  '${request.cabinet.city}, ${request.cabinet.governorate}',
            ),
            const SizedBox(height: OmniSpacing.base),
            Container(
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
                    feeLabel,
                    style: textTheme.bodySmall?.copyWith(
                      color: OmniColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: OmniSpacing.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(OmniSpacing.sm),
              decoration: BoxDecoration(
                color: OmniColors.mintSoft,
                borderRadius: BorderRadius.circular(OmniRadii.field),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.science_outlined,
                    color: OmniColors.deepTeal,
                    size: 18,
                  ),
                  const SizedBox(width: OmniSpacing.sm),
                  Expanded(
                    child: Text(
                      provenance,
                      style: textTheme.bodySmall?.copyWith(
                        color: OmniColors.textPrimary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: OmniSpacing.base),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: ValueKey(
                  'doctor-urgent-cabinet-accepted-open-${request.stableIdentity}',
                ),
                onPressed: onOpen,
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: const Text('Voir les détails'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AcceptedDetail extends StatelessWidget {
  const _AcceptedDetail({
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
        alignment: Alignment.center,
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
