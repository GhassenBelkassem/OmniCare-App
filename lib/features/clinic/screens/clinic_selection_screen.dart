import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/application/auth_controller.dart';
import '../application/clinic_context_controller.dart';
import '../data/clinic_models.dart';
import '../widgets/clinic_widgets.dart';

/// Clinic selector shown when a professional has more than one active
/// membership and no valid stored hint.
///
/// Active memberships are selectable. Unavailable memberships are listed
/// separately, are never interactive and only show a safe mapped reason.
class ClinicSelectionScreen extends StatelessWidget {
  const ClinicSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final clinic = context.watch<ClinicContextController>();
    final active = clinic.activeMemberships;
    final unavailable = clinic.unavailableMemberships;

    return ClinicPageScaffold(
      title: 'Choose a clinic',
      subtitle: 'Select the clinic you are working in right now.',
      children: [
        if (active.isEmpty)
          const ClinicCard(
            child: Text('No clinic is available for this account.'),
          )
        else
          ...active.map(
            (membership) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ActiveClinicTile(
                membership: membership,
                selected: membership.clinicId == clinic.selectedClinicId,
                enabled: !clinic.isLoading,
                onTap: () => clinic.selectClinic(membership.clinicId),
              ),
            ),
          ),
        if (unavailable.isNotEmpty) ...[
          const SizedBox(height: 14),
          const ClinicSectionTitle(
            'Unavailable',
            subtitle: 'These clinics cannot be opened right now.',
          ),
          const SizedBox(height: 10),
          ...unavailable.map(
            (membership) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _UnavailableClinicTile(membership: membership),
            ),
          ),
        ],
        const SizedBox(height: 12),
        ClinicSecondaryButton(
          label: 'Sign out',
          icon: Icons.logout,
          onPressed: () => context.read<AuthController>().logout(),
        ),
      ],
    );
  }
}

class _ActiveClinicTile extends StatelessWidget {
  const _ActiveClinicTile({
    required this.membership,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final ClinicMembershipSummary membership;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: enabled,
      label:
          'Open ${membership.clinicName} as '
          '${membership.professionalRole.label}',
      child: Material(
        color: ClinicPalette.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected ? ClinicPalette.primary : ClinicPalette.border,
                width: selected ? 1.6 : 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        membership.clinicName,
                        style: clinicTextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        membership.professionalRole.label,
                        style: clinicTextStyle(
                          fontSize: 13,
                          color: ClinicPalette.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: ClinicPalette.textMuted,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _UnavailableClinicTile extends StatelessWidget {
  const _UnavailableClinicTile({required this.membership});

  final ClinicMembershipSummary membership;

  @override
  Widget build(BuildContext context) {
    final reason =
        membership.unavailabilityReason ?? ClinicUnavailabilityReason.unknown;
    return Semantics(
      enabled: false,
      label: '${membership.clinicName}, unavailable. ${reason.message}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ClinicPalette.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ClinicPalette.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    membership.clinicName,
                    style: clinicTextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: ClinicPalette.textSecondary,
                    ),
                  ),
                ),
                const ClinicStatusChip(label: 'Unavailable', active: false),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              reason.message,
              style: clinicTextStyle(
                fontSize: 13,
                color: ClinicPalette.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
