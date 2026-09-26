import 'package:flutter/material.dart';

import '../../../core/theme/omni_theme.dart';
import '../demo/doctor_demo_profile.dart';
import '../agenda/doctor_agenda_controller.dart';
import '../agenda/doctor_agenda_screen.dart';
import '../home/doctor_home_screen.dart';
import '../medical_record/doctor_medical_record_access.dart';
import '../medical_record/doctor_medical_record_screen.dart';
import '../urgent/doctor_urgent_controller.dart';
import '../urgent/doctor_urgent_qr_scanner_screen.dart';
import '../urgent/doctor_urgent_screen.dart';
import '../workspace/doctor_workspace_config.dart';
import 'doctor_navigation_destination.dart';
import 'doctor_placeholder_tab.dart';

/// Shared, feature-neutral frame for the Doctor mobile experience.
///
/// The header and navigation are intentionally outside each tab's scroll
/// surface. Each destination owns exactly one vertical scroll view.
class DoctorAppShell extends StatefulWidget {
  const DoctorAppShell({
    super.key,
    required this.profile,
    required this.onLogout,
    this.workspaceConfig,
    this.onResetDemo,
    this.urgentController,
  });

  static const profileTabKey = ValueKey('doctor-tab-profile');

  final DoctorDemoProfile profile;
  final Future<void> Function() onLogout;
  final DoctorWorkspaceConfig? workspaceConfig;
  final Future<void> Function()? onResetDemo;
  final DoctorUrgentController? urgentController;

  @override
  State<DoctorAppShell> createState() => _DoctorAppShellState();
}

class _DoctorAppShellState extends State<DoctorAppShell> {
  DoctorNavigationDestinationId _selectedDestination =
      DoctorNavigationDestinationId.home;
  bool _isLoggingOut = false;
  _DoctorUrgentWorkflow _urgentWorkflow = _DoctorUrgentWorkflow.urgent;
  late final DoctorAgendaController _agendaController =
      DoctorAgendaController();
  late final DoctorUrgentController _urgentController =
      widget.urgentController ?? DoctorUrgentController();

  @override
  void dispose() {
    _agendaController.dispose();
    if (widget.urgentController == null) {
      _urgentController.dispose();
    }
    super.dispose();
  }

  Set<DoctorCapability> get _capabilities => widget.workspaceConfig == null
      ? const <DoctorCapability>{}
      : deriveDoctorCapabilities(widget.workspaceConfig!);

  List<DoctorNavigationDestination> get _destinations =>
      deriveDoctorNavigationDestinations(_capabilities);

  @override
  void didUpdateWidget(covariant DoctorAppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_destinations.any(
      (destination) => destination.id == _selectedDestination,
    )) {
      _selectedDestination = DoctorNavigationDestinationId.home;
    }
  }

  Future<void> _logout() async {
    if (_isLoggingOut) return;
    setState(() => _isLoggingOut = true);
    try {
      await widget.onLogout();
    } finally {
      if (mounted) setState(() => _isLoggingOut = false);
    }
  }

  void _selectDestination(DoctorNavigationDestinationId destination) {
    if (!_destinations.any((item) => item.id == destination) ||
        _selectedDestination == destination) {
      return;
    }
    setState(() {
      _selectedDestination = destination;
      if (destination != DoctorNavigationDestinationId.urgent) {
        _urgentWorkflow = _DoctorUrgentWorkflow.urgent;
      }
    });
  }

  void _showUrgentWorkflow(_DoctorUrgentWorkflow workflow) {
    setState(() {
      _selectedDestination = DoctorNavigationDestinationId.urgent;
      _urgentWorkflow = workflow;
    });
  }

  @override
  Widget build(BuildContext context) {
    final destinations = _destinations;
    final selectedDestination = destinations.firstWhere(
      (destination) => destination.id == _selectedDestination,
      orElse: () => destinations.first,
    );
    return Scaffold(
      backgroundColor: OmniColors.pageBackground,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _DoctorTopBar(profile: widget.profile),
            Expanded(child: _selectedContent(selectedDestination.id)),
          ],
        ),
      ),
      bottomNavigationBar: _DoctorBottomNavigation(
        destinations: destinations,
        selectedDestination: selectedDestination.id,
        onSelected: (destination) => _selectDestination(destination.id),
      ),
    );
  }

  Widget _selectedContent(DoctorNavigationDestinationId destination) {
    return switch (destination) {
      DoctorNavigationDestinationId.home => DoctorHomeScreen(
        profile: widget.profile,
        capabilities: _capabilities,
        workspaceConfig: widget.workspaceConfig,
        agendaNextAppointment: _agendaController.nextAppointment,
        urgentController: _urgentController,
        onOpenAgenda: () =>
            _selectDestination(DoctorNavigationDestinationId.agenda),
        onOpenUrgencies: () =>
            _selectDestination(DoctorNavigationDestinationId.urgent),
      ),
      DoctorNavigationDestinationId.agenda => DoctorAgendaScreen(
        controller: _agendaController,
      ),
      DoctorNavigationDestinationId.urgent => _UrgentWorkflowContent(
        workflow: _urgentWorkflow,
        urgentController: _urgentController,
        onOpenQr: () => _showUrgentWorkflow(_DoctorUrgentWorkflow.qr),
        onBackToUrgent: () => _showUrgentWorkflow(_DoctorUrgentWorkflow.urgent),
        onOpenMedicalRecord: () =>
            _showUrgentWorkflow(_DoctorUrgentWorkflow.medicalRecord),
        onBackToQr: () => _showUrgentWorkflow(_DoctorUrgentWorkflow.qr),
      ),
      DoctorNavigationDestinationId.patients => const DoctorPlaceholderTab(
        title: 'Patients',
        icon: Icons.people_alt_outlined,
      ),
      DoctorNavigationDestinationId.profile => DoctorPlaceholderTab(
        title: 'Profil',
        icon: Icons.account_circle_outlined,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _LogoutButton(isLoggingOut: _isLoggingOut, onPressed: _logout),
            if (widget.onResetDemo != null) ...[
              const SizedBox(height: OmniSpacing.md),
              TextButton.icon(
                key: const ValueKey('doctor-reset-demo-button'),
                onPressed: widget.onResetDemo,
                icon: const Icon(Icons.restart_alt_rounded, size: 18),
                label: const Text('Réinitialiser la démo'),
              ),
            ],
          ],
        ),
      ),
    };
  }
}

enum _DoctorUrgentWorkflow { urgent, qr, medicalRecord }

/// Keeps the D5/D6 urgent journey in the shell's content region. IndexedStack
/// preserves both the shell-owned controller and the verified QR state while a
/// doctor views the record and returns.
class _UrgentWorkflowContent extends StatelessWidget {
  const _UrgentWorkflowContent({
    required this.workflow,
    required this.urgentController,
    required this.onOpenQr,
    required this.onBackToUrgent,
    required this.onOpenMedicalRecord,
    required this.onBackToQr,
  });

  final _DoctorUrgentWorkflow workflow;
  final DoctorUrgentController urgentController;
  final VoidCallback onOpenQr;
  final VoidCallback onBackToUrgent;
  final VoidCallback onOpenMedicalRecord;
  final VoidCallback onBackToQr;

  @override
  Widget build(BuildContext context) => IndexedStack(
    index: workflow.index,
    children: [
      DoctorUrgentScreen(controller: urgentController, onOpenQr: onOpenQr),
      DoctorUrgentQrScannerScreen(
        request: urgentController.request,
        embedded: true,
        onBack: onBackToUrgent,
        onOpenMedicalRecord: onOpenMedicalRecord,
      ),
      DoctorMedicalRecordScreen(
        access: DoctorMedicalRecordAccess.fullDemo(urgentController.request),
        embedded: true,
        onBack: onBackToQr,
      ),
    ],
  );
}

class _DoctorTopBar extends StatelessWidget {
  const _DoctorTopBar({required this.profile});

  final DoctorDemoProfile profile;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      key: const ValueKey('doctor-top-bar'),
      height: 72,
      decoration: const BoxDecoration(
        color: OmniColors.surfacePrimary,
        border: Border(bottom: BorderSide(color: OmniColors.borderLight)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: OmniSpacing.base),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'OmniCare',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleMedium?.copyWith(
                          color: OmniColors.deepTeal,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.35,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Espace médecin',
                        style: textTheme.labelMedium?.copyWith(
                          color: OmniColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Semantics(
                  label: 'Profil de ${profile.fullName}',
                  child: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: OmniColors.mintSoft,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      profile.initials,
                      style: textTheme.labelLarge?.copyWith(
                        color: OmniColors.deepTeal,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DoctorBottomNavigation extends StatelessWidget {
  const _DoctorBottomNavigation({
    required this.destinations,
    required this.selectedDestination,
    required this.onSelected,
  });

  final List<DoctorNavigationDestination> destinations;
  final DoctorNavigationDestinationId selectedDestination;
  final ValueChanged<DoctorNavigationDestination> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('doctor-bottom-navigation'),
      decoration: const BoxDecoration(
        color: OmniColors.surfacePrimary,
        border: Border(top: BorderSide(color: OmniColors.borderLight)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 14,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: OmniSpacing.sm),
                child: Row(
                  children: List.generate(
                    destinations.length,
                    (index) => Expanded(
                      child: _DoctorNavigationButton(
                        key:
                            destinations[index].id ==
                                DoctorNavigationDestinationId.profile
                            ? DoctorAppShell.profileTabKey
                            : ValueKey(
                                'doctor-tab-${destinations[index].id.name}',
                              ),
                        destination: destinations[index],
                        isSelected:
                            selectedDestination == destinations[index].id,
                        onTap: () => onSelected(destinations[index]),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DoctorNavigationButton extends StatelessWidget {
  const _DoctorNavigationButton({
    super.key,
    required this.destination,
    required this.isSelected,
    required this.onTap,
  });

  final DoctorNavigationDestination destination;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final color = isSelected
        ? OmniColors.primaryAction
        : OmniColors.textTertiary;
    return Semantics(
      button: true,
      selected: isSelected,
      label: destination.label,
      child: InkWell(
        borderRadius: BorderRadius.circular(OmniRadii.field),
        onTap: onTap,
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            constraints: const BoxConstraints(minWidth: 48),
            padding: const EdgeInsets.symmetric(vertical: OmniSpacing.xs),
            decoration: BoxDecoration(
              color: isSelected ? OmniColors.mintSoft : Colors.transparent,
              borderRadius: BorderRadius.circular(OmniRadii.field),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSelected ? destination.selectedIcon : destination.icon,
                  color: color,
                  size: 23,
                ),
                const SizedBox(height: 3),
                Text(
                  destination.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.labelSmall?.copyWith(
                    color: color,
                    fontSize: 10,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.isLoggingOut, required this.onPressed});

  final bool isLoggingOut;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        key: const ValueKey('doctor-logout-button'),
        onPressed: isLoggingOut ? null : onPressed,
        icon: isLoggingOut
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.logout_rounded, size: 19),
        label: const Text('Se déconnecter'),
      ),
    );
  }
}
