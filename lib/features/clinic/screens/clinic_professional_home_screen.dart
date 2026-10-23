import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/application/auth_controller.dart';
import '../application/clinic_context_controller.dart';
import '../data/clinic_models.dart';
import '../widgets/clinic_widgets.dart';

/// Lightweight operational landing surface for any active Clinic membership
/// whose backend bootstrap grants task-read capability.
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
    final canReadTasks = bootstrap.canReadTasks;
    final canReadHandovers = bootstrap.canReadHandovers;

    return ClinicPageScaffold(
      title: 'Clinic work',
      subtitle:
          '${bootstrap.clinic.clinicName} · ${membership.professionalRole.label}',
      children: [
        ClinicCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: ClinicSectionTitle('What needs your attention?'),
                  ),
                  ClinicStatusChip(
                    label: bootstrap.clinic.clinicStatus.label,
                    active: bootstrap.clinic.clinicStatus.isActive,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Open the work list that needs action. Counts are not shown unless the backend provides them.',
                style: clinicTextStyle(
                  fontSize: 13,
                  color: ClinicPalette.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 10),
              ClinicInfoRow(
                label: 'Professional role',
                value: membership.professionalRole.label,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (canReadTasks) ...[
          _ClinicWorkspaceLink(
            icon: Icons.inbox_outlined,
            title: 'Position queue',
            subtitle: 'Work waiting in a position you can cover.',
            onTap: () => Navigator.of(context).pushNamed('/clinic/queue'),
          ),
          const SizedBox(height: 10),
          _ClinicWorkspaceLink(
            icon: Icons.assignment_outlined,
            title: 'My tasks',
            subtitle: 'Active work currently assigned to you.',
            onTap: () => Navigator.of(context).pushNamed('/clinic/tasks'),
          ),
        ],
        if (canReadHandovers) ...[
          const SizedBox(height: 10),
          _ClinicWorkspaceLink(
            icon: Icons.swap_horiz_outlined,
            title: 'Handovers',
            subtitle: 'Incoming requests and outgoing pending handovers.',
            onTap: () => Navigator.of(context).pushNamed('/clinic/handovers'),
          ),
        ],
        if (!canReadTasks)
          const ClinicCard(
            child: Text(
              'Operational work is not enabled for this clinic membership.',
            ),
          ),
        const SizedBox(height: 12),
        ClinicCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ClinicSectionTitle(
                'Other Clinic modules',
                subtitle: 'Not part of this mobile foundation release.',
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

class _ClinicWorkspaceLink extends StatelessWidget {
  const _ClinicWorkspaceLink({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title. $subtitle',
      child: Material(
        color: ClinicPalette.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            constraints: const BoxConstraints(minHeight: 76),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: ClinicPalette.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: ClinicPalette.primarySoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: ClinicPalette.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: clinicTextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: clinicTextStyle(
                          fontSize: 12,
                          color: ClinicPalette.textSecondary,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: ClinicPalette.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
