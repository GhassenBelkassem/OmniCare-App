import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/application/auth_controller.dart';
import '../application/clinic_context_controller.dart';
import '../widgets/clinic_widgets.dart';

/// Phase 1 destination for web-first clinic roles (`CLINIC_ADMIN`,
/// `CLINIC_ASSISTANT`).
///
/// It confirms the authenticated clinic identity and explains that clinic
/// coordination and configuration happen in the web portal. It deliberately
/// exposes no operational module, real or fake.
class ClinicWebWorkspaceScreen extends StatelessWidget {
  const ClinicWebWorkspaceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final clinic = context.watch<ClinicContextController>();
    final bootstrap = clinic.bootstrap;

    if (bootstrap == null) {
      return const ClinicPageScaffold(
        title: 'Clinic workspace',
        subtitle: 'Your clinic context is not loaded.',
        children: [],
      );
    }

    final membership = bootstrap.membership;

    return ClinicPageScaffold(
      title: bootstrap.clinic.clinicName,
      subtitle:
          'The mobile operational workspace is not enabled for this clinic '
          'access. Administrative work remains on the OmniCare web portal.',
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: ClinicPalette.primarySoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.desktop_windows_outlined,
          color: ClinicPalette.primary,
          size: 22,
        ),
      ),
      children: [
        ClinicCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(child: ClinicSectionTitle('Signed in')),
                  ClinicStatusChip(
                    label: bootstrap.clinic.clinicStatus.label,
                    active: bootstrap.clinic.clinicStatus.isActive,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClinicInfoRow(
                label: 'Clinic name',
                value: bootstrap.clinic.clinicName,
              ),
              ClinicInfoRow(
                label: 'Professional role',
                value: membership.professionalRole.label,
              ),
              ClinicInfoRow(
                label: 'Membership status',
                value: membership.membershipStatus.label,
              ),
              ClinicInfoRow(
                label: 'Membership version',
                value: membership.version.toString(),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ClinicCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ClinicSectionTitle('Where to work'),
              const SizedBox(height: 10),
              Text(
                'Your current backend capabilities do not include the mobile '
                'task workspace. Clinic administration and configuration are '
                'handled in the OmniCare web portal.',
                style: clinicTextStyle(
                  fontSize: 13,
                  color: ClinicPalette.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'This mobile app does not expose administrative Clinic '
                'configuration or task commands in this release.',
                style: clinicTextStyle(
                  fontSize: 13,
                  color: ClinicPalette.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ClinicPrimaryButton(
          label: 'Refresh clinic context',
          icon: Icons.refresh,
          onPressed: clinic.isLoading ? null : () => clinic.refreshBootstrap(),
        ),
        if (clinic.canSwitchClinic) ...[
          const SizedBox(height: 10),
          ClinicSecondaryButton(
            label: 'Switch clinic',
            icon: Icons.swap_horiz,
            onPressed: clinic.isLoading
                ? null
                : () => clinic.requestClinicSelection(),
          ),
        ],
        const SizedBox(height: 10),
        ClinicSecondaryButton(
          label: 'Sign out',
          icon: Icons.logout,
          onPressed: () => context.read<AuthController>().logout(),
        ),
      ],
    );
  }
}
