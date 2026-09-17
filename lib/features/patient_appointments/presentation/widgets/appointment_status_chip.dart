import 'package:flutter/material.dart';

import '../../../../core/theme/omni_theme.dart';
import '../../data/patient_appointment_models.dart';

class AppointmentStatusChip extends StatelessWidget {
  const AppointmentStatusChip({super.key, required this.status});

  final PatientAppointmentStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, icon, color, background) = switch (status) {
      PatientAppointmentStatus.confirmed => (
        'Confirmé',
        Icons.check_circle_outline_rounded,
        OmniColors.deepTeal,
        OmniColors.mintSoft,
      ),
      PatientAppointmentStatus.completed => (
        'Terminé',
        Icons.task_alt_rounded,
        OmniColors.slateBlue,
        OmniColors.slateSoft,
      ),
      PatientAppointmentStatus.cancelled => (
        'Annulé',
        Icons.cancel_outlined,
        OmniColors.error,
        OmniColors.errorSoft,
      ),
    };
    return Semantics(
      label: 'Statut : $label',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(OmniRadii.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
