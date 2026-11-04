import 'package:flutter/material.dart';

import '../workspace/doctor_workspace_config.dart';

/// The one presentation-level definition of a Doctor workspace destination.
///
/// D2 intentionally maps only existing capabilities to placeholder screens.
/// Future features can use [requiredCapability] through [canAccessDoctorFeature]
/// before attempting internal navigation.
class DoctorNavigationDestination {
  const DoctorNavigationDestination({
    required this.id,
    required this.label,
    required this.icon,
    required this.selectedIcon,
    this.requiredCapability,
  });

  final DoctorNavigationDestinationId id;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final DoctorCapability? requiredCapability;

  bool isAvailable(Set<DoctorCapability> capabilities) =>
      requiredCapability == null || capabilities.contains(requiredCapability);
}

enum DoctorNavigationDestinationId { home, agenda, urgent, patients, profile }

/// Derives the exact destination list consumed by both the Doctor body and
/// bottom navigation. It deliberately has no practice-mode knowledge.
List<DoctorNavigationDestination> deriveDoctorNavigationDestinations(
  Set<DoctorCapability> capabilities,
) {
  return _allDestinations
      .where((destination) => destination.isAvailable(capabilities))
      .toList(growable: false);
}

/// Reusable D2 gate for a future internal Doctor feature entry point.
bool canAccessDoctorFeature(
  Set<DoctorCapability> capabilities,
  DoctorCapability capability,
) => capabilities.contains(capability);

const _allDestinations = <DoctorNavigationDestination>[
  DoctorNavigationDestination(
    id: DoctorNavigationDestinationId.home,
    label: 'Accueil',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home_rounded,
  ),
  DoctorNavigationDestination(
    id: DoctorNavigationDestinationId.agenda,
    label: 'Agenda',
    icon: Icons.calendar_month_outlined,
    selectedIcon: Icons.calendar_month_rounded,
    requiredCapability: DoctorCapability.agenda,
  ),
  DoctorNavigationDestination(
    id: DoctorNavigationDestinationId.urgent,
    label: 'Urgences',
    icon: Icons.emergency_outlined,
    selectedIcon: Icons.emergency_rounded,
    requiredCapability: DoctorCapability.urgentWorkspace,
  ),
  DoctorNavigationDestination(
    id: DoctorNavigationDestinationId.patients,
    label: 'Patients',
    icon: Icons.people_alt_outlined,
    selectedIcon: Icons.people_alt_rounded,
    requiredCapability: DoctorCapability.patientManagement,
  ),
  DoctorNavigationDestination(
    id: DoctorNavigationDestinationId.profile,
    label: 'Profil',
    icon: Icons.account_circle_outlined,
    selectedIcon: Icons.account_circle_rounded,
  ),
];
