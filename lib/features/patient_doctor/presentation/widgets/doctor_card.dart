import 'package:flutter/material.dart';

import '../../../../core/theme/omni_theme.dart';
import '../../application/doctor_directory_filters.dart';
import '../../data/doctor_models.dart';

class DoctorListCard extends StatelessWidget {
  const DoctorListCard({super.key, required this.doctor, required this.onTap});

  final DoctorListItem doctor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: _semanticLabel(doctor),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(OmniRadii.card),
        child: Ink(
          decoration: BoxDecoration(
            color: OmniColors.surfacePrimary,
            borderRadius: BorderRadius.circular(OmniRadii.card),
            border: Border.all(color: OmniColors.borderLight),
            boxShadow: const [OmniColors.shadowCard],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _DoctorAvatar(name: doctor.name, photoUrl: doctor.photoUrl),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              doctor.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontSize: 17,
                                height: 1.2,
                                fontWeight: FontWeight.w700,
                                color: OmniColors.textPrimary,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 22,
                            color: OmniColors.textTertiary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        doctor.displaySpecialty,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: doctor.specialty == null
                              ? OmniColors.textTertiary
                              : OmniColors.violet,
                        ),
                      ),
                      if (doctor.experienceLabel.isNotEmpty ||
                          doctor.consultationPriceTnd != null) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          children: [
                            if (doctor.experienceLabel.isNotEmpty)
                              _Meta(
                                icon: Icons.work_outline_rounded,
                                label: doctor.experienceLabel,
                              ),
                            if (doctor.consultationPriceTnd case final price?)
                              _Meta(
                                icon: Icons.payments_outlined,
                                label: '${_formatPrice(price)} TND',
                              ),
                          ],
                        ),
                      ],
                      if (doctor.matchingPracticeLocation != null ||
                          doctor.distanceKm != null) ...[
                        const SizedBox(height: 7),
                        _MatchingLocation(doctor: doctor),
                      ],
                      if (doctor.careCapabilities.isNotEmpty ||
                          !doctor.acceptingNewPatients) ...[
                        const SizedBox(height: 9),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final capability
                                in doctor.careCapabilities.take(2))
                              _Badge(
                                label: doctorCapabilityLabel(capability),
                                color: OmniColors.infoBlue,
                                background: OmniColors.infoBlueSoft,
                              ),
                            if (!doctor.acceptingNewPatients)
                              const _Badge(
                                label: 'Nouveaux patients non acceptés',
                                color: OmniColors.amber,
                                background: OmniColors.amberSoft,
                              ),
                          ],
                        ),
                      ],
                    ],
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

String _semanticLabel(DoctorListItem doctor) {
  final location = doctor.matchingPracticeLocation;
  return [
    doctor.name,
    doctor.displaySpecialty,
    if (location != null) location.name,
    if (doctor.distanceKm != null)
      '${doctor.distanceKm!.toStringAsFixed(1)} kilomètres',
  ].join(', ');
}

String _formatPrice(double value) {
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);
}

class _DoctorAvatar extends StatelessWidget {
  const _DoctorAvatar({required this.name, this.photoUrl});

  final String name;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final url = photoUrl?.trim();
    return SizedBox(
      width: 72,
      height: 72,
      child: ClipOval(
        child: url == null || url.isEmpty
            ? _InitialsFallback(name: name)
            : Image.network(
                url,
                key: const ValueKey('doctor-network-photo'),
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _InitialsFallback(name: name),
              ),
      ),
    );
  }
}

class _InitialsFallback extends StatelessWidget {
  const _InitialsFallback({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      key: const ValueKey('doctor-photo-fallback'),
      color: OmniColors.violetSoft,
      child: Center(
        child: Text(
          _initials(name),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: OmniColors.slateBlue,
          ),
        ),
      ),
    );
  }
}

String _initials(String name) {
  final parts = name
      .trim()
      .replaceFirst(RegExp(r'^Dr\.?\s*', caseSensitive: false), '')
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: OmniColors.textTertiary),
        const SizedBox(width: 3),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontSize: 12,
            color: OmniColors.textTertiary,
          ),
        ),
      ],
    );
  }
}

class _MatchingLocation extends StatelessWidget {
  const _MatchingLocation({required this.doctor});

  final DoctorListItem doctor;

  @override
  Widget build(BuildContext context) {
    final location = doctor.matchingPracticeLocation;
    final placeParts = <String>[];
    if (location?.city case final city?) placeParts.add(city);
    if (location?.governorate case final governorate?) {
      placeParts.add(governorate);
    }
    final place = placeParts.join(', ');
    final distance = location?.distanceKm ?? doctor.distanceKm;
    final detail = [
      if (place.isNotEmpty) place,
      if (distance != null) '${distance.toStringAsFixed(1)} km',
    ].join(' · ');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 2),
          child: Icon(
            Icons.location_on_outlined,
            size: 14,
            color: OmniColors.infoBlue,
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (location != null)
                Text(
                  location.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: OmniColors.textSecondary,
                  ),
                ),
              if (detail.isNotEmpty)
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: OmniColors.textTertiary,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.color,
    required this.background,
  });

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(OmniRadii.pill),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
