import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/application/auth_controller.dart';
import '../application/clinic_context_controller.dart';
import '../data/clinic_models.dart';
import '../widgets/clinic_widgets.dart';

/// Phase 1 landing screen for operational mobile clinic roles
/// (`CLINIC_MEDECIN`, `CLINIC_INFIRMIERE`, `CLINIC_KINE`).
///
/// It only shows the authenticated clinic context. No patients, tasks, alerts,
/// statistics or medical content are invented here, and every future module is
/// rendered as unavailable because all Phase 1 feature flags are false.
class ClinicProfessionalHomeScreen extends StatelessWidget {
  const ClinicProfessionalHomeScreen({super.key});

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
    final capabilities = bootstrap.capabilities;

    return ClinicPageScaffold(
      title: bootstrap.clinic.clinicName,
      subtitle: 'Signed in as ${membership.professionalRole.label}.',
      children: [
        ClinicCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(child: ClinicSectionTitle('Clinic')),
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
                label: 'Clinic status',
                value: bootstrap.clinic.clinicStatus.label,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ClinicCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ClinicSectionTitle('My membership'),
              const SizedBox(height: 6),
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
              const ClinicSectionTitle(
                'Access',
                subtitle: 'Read-only access granted for this clinic.',
              ),
              const SizedBox(height: 10),
              if (capabilities.isEmpty)
                Text(
                  'No read access is granted for this clinic yet.',
                  style: clinicTextStyle(
                    fontSize: 13,
                    color: ClinicPalette.textSecondary,
                  ),
                )
              else
                ...capabilities.map(
                  (capability) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.visibility_outlined,
                          size: 16,
                          color: ClinicPalette.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            capability.label,
                            style: clinicTextStyle(fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        ClinicCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ClinicSectionTitle(
                'Clinic modules',
                subtitle: 'These modules are not part of this release.',
              ),
              const SizedBox(height: 10),
              ...ClinicFeatureModule.values.map(
                (module) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ClinicUnavailableModuleTile(label: module.label),
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
