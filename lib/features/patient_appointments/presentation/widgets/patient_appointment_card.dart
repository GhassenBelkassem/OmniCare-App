import 'package:flutter/material.dart';

import '../../../../core/theme/omni_theme.dart';
import '../../data/patient_appointment_models.dart';
import 'appointment_formatters.dart';
import 'appointment_status_chip.dart';

class PatientAppointmentCard extends StatelessWidget {
  const PatientAppointmentCard({
    super.key,
    required this.appointment,
    required this.onTap,
    this.emphasized = false,
  });

  final PatientAppointment appointment;
  final VoidCallback onTap;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label:
          '${appointment.providerDisplayName}, ${formatAppointmentDate(appointment.startAt)}, ${appointment.subjectDisplayName}',
      child: Material(
        color: OmniColors.surfacePrimary,
        borderRadius: BorderRadius.circular(OmniRadii.card),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(OmniRadii.card),
          child: Container(
            padding: const EdgeInsets.all(OmniSpacing.base),
            decoration: BoxDecoration(
              color: emphasized ? OmniColors.mintSoft : null,
              borderRadius: BorderRadius.circular(OmniRadii.card),
              border: Border.all(
                color: emphasized
                    ? OmniColors.freshMint
                    : OmniColors.borderLight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        formatAppointmentDate(appointment.startAt),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: OmniColors.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: OmniSpacing.sm),
                    AppointmentStatusChip(status: appointment.status),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  formatAppointmentTimeRange(
                    appointment.startAt,
                    appointment.endAt,
                  ),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: OmniColors.deepTealActive,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: OmniSpacing.base),
                Row(
                  children: [
                    AppointmentProviderAvatar(appointment: appointment),
                    const SizedBox(width: OmniSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            appointment.providerDisplayName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(
                                  color: OmniColors.textPrimary,
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            appointment.providerSubtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: OmniColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: OmniColors.textTertiary,
                    ),
                  ],
                ),
                const SizedBox(height: OmniSpacing.base),
                _AppointmentMetaRow(
                  icon: Icons.location_on_outlined,
                  value: '${appointment.locationName} · ${appointment.city}',
                ),
                const SizedBox(height: OmniSpacing.xs),
                _AppointmentMetaRow(
                  icon: Icons.person_outline_rounded,
                  value: 'Pour : ${appointment.subjectDisplayName}',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AppointmentProviderAvatar extends StatelessWidget {
  const AppointmentProviderAvatar({
    super.key,
    required this.appointment,
    this.size = 52,
  });

  final PatientAppointment appointment;
  final double size;

  @override
  Widget build(BuildContext context) {
    final fallback =
        appointment.providerType == PatientAppointmentProviderType.clinic
        ? Icons.local_hospital_outlined
        : Icons.person_outline_rounded;
    final initials = appointment.providerDisplayName
        .replaceFirst(RegExp(r'^Dr\.\s*'), '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
    return ClipRRect(
      borderRadius: BorderRadius.circular(OmniRadii.field),
      child: SizedBox(
        width: size,
        height: size,
        child: appointment.providerImageAssetPath == null
            ? _fallback(fallback, initials)
            : Image.asset(
                appointment.providerImageAssetPath!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _fallback(fallback, initials),
              ),
      ),
    );
  }

  Widget _fallback(IconData icon, String initials) {
    return Container(
      color: OmniColors.mintSoft,
      alignment: Alignment.center,
      child: initials.isEmpty
          ? Icon(icon, color: OmniColors.deepTeal, size: size * .42)
          : Text(
              initials,
              style: TextStyle(
                color: OmniColors.deepTealActive,
                fontSize: size * .28,
                fontWeight: FontWeight.w800,
              ),
            ),
    );
  }
}

class _AppointmentMetaRow extends StatelessWidget {
  const _AppointmentMetaRow({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: OmniColors.slateBlue),
        const SizedBox(width: OmniSpacing.sm),
        Expanded(
          child: Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: OmniColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
