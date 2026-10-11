import 'package:flutter/material.dart';

import '../../../../core/theme/omni_theme.dart';
import '../../data/patient_appointment_models.dart';

class AppointmentStatusChip extends StatelessWidget {
  const AppointmentStatusChip({super.key, required this.status});

  final PatientAppointmentStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, icon, color, background) = switch (status) {
      PatientAppointmentStatus.pendingDoctor => (
        'Médecin à confirmer',
        Icons.schedule_rounded,
        OmniColors.amber,
        OmniColors.warningSubtle,
      ),
      PatientAppointmentStatus.pendingPatientTimeConfirmation => (
        'Votre réponse',
        Icons.event_repeat_rounded,
        OmniColors.violet,
        OmniColors.violetSoft,
      ),
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
      PatientAppointmentStatus.cancelledByPatient => (
        'Annulé par vous',
        Icons.cancel_outlined,
        OmniColors.error,
        OmniColors.errorSoft,
      ),
      PatientAppointmentStatus.cancelledByDoctor => (
        'Annulé par le médecin',
        Icons.cancel_outlined,
        OmniColors.error,
        OmniColors.errorSoft,
      ),
      PatientAppointmentStatus.expired => (
        'Expiré',
        Icons.timer_off_outlined,
        OmniColors.textSecondary,
        OmniColors.surfaceSecondary,
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
