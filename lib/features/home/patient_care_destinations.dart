import 'package:flutter/material.dart';

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
  });

  final PatientCareType type;
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;

  bool get isClinic => type == PatientCareType.clinic;
  String get route => isClinic ? '/m05/request' : '/emergency-step0';
}

const patientCareDestinations = <PatientCareDestination>[
  PatientCareDestination(
    type: PatientCareType.doctor,
    label: 'Médecin',
    subtitle: 'Consultation à domicile ou rendez-vous',
    icon: Icons.medical_services_outlined,
    color: Color(0xFF1FBF9A),
  ),
  PatientCareDestination(
    type: PatientCareType.nurse,
    label: 'Infirmier',
    subtitle: 'Soins infirmiers à domicile',
    icon: Icons.vaccines_outlined,
    color: Color(0xFF8B5CF6),
  ),
  PatientCareDestination(
    type: PatientCareType.kine,
    label: 'Kinésithérapeute',
    subtitle: 'Demande et suivi de rééducation',
    icon: Icons.accessibility_new_rounded,
    color: Color(0xFFF59E0B),
  ),
  PatientCareDestination(
    type: PatientCareType.clinic,
    label: 'Clinique',
    subtitle: 'Envoyer une demande à une clinique',
    icon: Icons.local_hospital_outlined,
    color: Color(0xFF087A65),
  ),
];

PatientCareDestination patientCareDestination(PatientCareType type) =>
    patientCareDestinations.firstWhere(
      (destination) => destination.type == type,
    );
