import 'package:flutter/material.dart';

import '../../data/doctor_models.dart';
import 'doctor_result_card.dart';

/// Compact horizontal doctor result card in the patient directory.
///
/// Follows the same scannable row pattern as [ClinicListCard]: avatar on the
/// left, key information on the right. Uses a circular avatar with optional
/// asset image and graceful initials fallback.
class DoctorListCard extends StatelessWidget {
  const DoctorListCard({super.key, required this.doctor, required this.onTap});

  final DoctorListItem doctor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DoctorResultCard(
      data: DoctorResultCardData(
        name: doctor.name,
        specialty: doctor.specialty,
        experienceLabel: doctor.experienceLabel,
        address: doctor.address,
        distanceKm: doctor.distanceKm,
        imageAssetPath: doctor.imageAssetPath,
        status: doctor.acceptingNewPatients
            ? null
            : const DoctorResultCardStatus(label: 'Complet'),
      ),
      onTap: onTap,
    );
  }
}
