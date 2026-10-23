import 'package:flutter/material.dart';

import '../../core/theme/omni_theme.dart';

/// The patient-visible care destinations supported by the current app.
///
/// This is presentation/navigation metadata only. It deliberately contains no
/// request payload or workflow logic, so Home and the care chooser cannot drift.
enum PatientCareType { doctor, nurse, kine, clinic }

class PatientCareDestination {
  const PatientCareDestination({
    required this.type,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.illustration,
  });

  final PatientCareType type;
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String illustration;

  bool get isClinic => type == PatientCareType.clinic;
  String get route => isClinic ? '/m05/request' : '/emergency-step0';
}

const patientCareDestinations = <PatientCareDestination>[
  PatientCareDestination(
    type: PatientCareType.doctor,
    label: 'Médecin',
    subtitle: 'Consultation à domicile ou en cabinet',
    icon: Icons.medical_services_outlined,
    color: OmniColors.freshMint,
    illustration: 'assets/illustrations/services/doctor.png',
  ),
  PatientCareDestination(
    type: PatientCareType.clinic,
    label: 'Clinique',
    subtitle: 'Consultations et soins en clinique',
    icon: Icons.account_balance_outlined,
    color: OmniColors.infoBlue,
    illustration: 'assets/illustrations/services/clinic.png',
  ),
  PatientCareDestination(
    type: PatientCareType.kine,
    label: 'Kinésithérapeute',
    subtitle: 'Rééducation et suivi thérapeutique',
    icon: Icons.accessibility_new_rounded,
    color: OmniColors.amber,
    illustration: 'assets/illustrations/services/kine.png',
  ),
  PatientCareDestination(
    type: PatientCareType.nurse,
    label: 'Infirmier',
    subtitle: 'Soins infirmiers à domicile',
    icon: Icons.vaccines_outlined,
    color: OmniColors.violet,
    illustration: 'assets/illustrations/services/nurse.png',
  ),
];

PatientCareDestination patientCareDestination(PatientCareType type) =>
    patientCareDestinations.firstWhere(
      (destination) => destination.type == type,
    );
