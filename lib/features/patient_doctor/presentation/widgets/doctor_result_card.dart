import 'package:flutter/material.dart';

import '../../../../core/theme/omni_theme.dart';

/// Display-ready values for a doctor result card.
///
/// Business flows are responsible for preparing these values. This model does
/// not depend on directory, booking, or urgent-care domain models.
@immutable
class DoctorResultCardData {
  const DoctorResultCardData({
    required this.name,
    required this.specialty,
    this.experienceLabel = '',
    this.address,
    this.distanceKm,
    this.imageAssetPath,
    this.status,
  });

  final String name;
  final String specialty;
  final String experienceLabel;
  final String? address;
  final double? distanceKm;
  final String? imageAssetPath;
  final DoctorResultCardStatus? status;
}

/// Optional presentation-only status rendered with the card's existing badge.
///
/// The calling flow owns the meaning of the status and supplies its label.
@immutable
class DoctorResultCardStatus {
  const DoctorResultCardStatus({required this.label});

  final String label;
}

/// Backend-independent doctor result presentation.
class DoctorResultCard extends StatelessWidget {
  const DoctorResultCard({super.key, required this.data, required this.onTap});

  final DoctorResultCardData data;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      button: true,
      enabled: true,
      label: _semanticLabel(data),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
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
                _DoctorAvatar(
                  name: data.name,
                  imageAssetPath: data.imageAssetPath,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        data.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontSize: 17,
                          height: 1.2,
                          fontWeight: FontWeight.w700,
                          color: OmniColors.textPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      _SpecialtyRow(specialty: data.specialty),
                      if (data.experienceLabel.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        _ProfileMetaRow(experienceLabel: data.experienceLabel),
                      ],
                      const SizedBox(height: 6),
                      _LocationRow(
                        address: data.address,
                        distanceKm: data.distanceKm,
                      ),
                      if (data.status != null) ...[
                        const SizedBox(height: 6),
                        _StatusBadge(status: data.status!),
                      ],
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 22,
                    color: OmniColors.textTertiary,
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

String _semanticLabel(DoctorResultCardData data) {
  final parts = <String>[
    data.name,
    data.specialty,
    if (data.distanceKm != null) '${data.distanceKm} km',
  ];
  return parts.join(', ');
}

class _DoctorAvatar extends StatelessWidget {
  const _DoctorAvatar({required this.name, this.imageAssetPath});

  final String name;
  final String? imageAssetPath;

  @override
  Widget build(BuildContext context) {
    final hasImage =
        imageAssetPath != null && imageAssetPath!.trim().isNotEmpty;

    return SizedBox(
      width: 72,
      height: 72,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: hasImage ? Colors.transparent : OmniColors.violetSoft,
        ),
        clipBehavior: Clip.antiAlias,
        child: hasImage
            ? Image.asset(
                imageAssetPath!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _InitialsFallback(name: name),
              )
            : _InitialsFallback(name: name),
      ),
    );
  }
}

class _InitialsFallback extends StatelessWidget {
  const _InitialsFallback({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        _initials(name),
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontSize: 24,
          height: 1,
          fontWeight: FontWeight.w700,
          color: OmniColors.slateBlue,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}

String _initials(String name) {
  final cleaned = name.trim();
  if (cleaned.isEmpty) return '?';

  final withoutPrefix = cleaned.replaceFirst(RegExp(r'^Dr\.\s*'), '');
  final parts = withoutPrefix
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();

  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
      .toUpperCase();
}

class _SpecialtyRow extends StatelessWidget {
  const _SpecialtyRow({required this.specialty});

  final String specialty;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.local_hospital_outlined,
          size: 13,
          color: OmniColors.violet,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            specialty,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 13,
              height: 1.3,
              fontWeight: FontWeight.w600,
              color: OmniColors.violet,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileMetaRow extends StatelessWidget {
  const _ProfileMetaRow({required this.experienceLabel});

  final String experienceLabel;

  @override
  Widget build(BuildContext context) {
    if (experienceLabel.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 10,
      runSpacing: 4,
      children: [
        _CardMetaItem(icon: Icons.work_outline_rounded, label: experienceLabel),
      ],
    );
  }
}

class _CardMetaItem extends StatelessWidget {
  const _CardMetaItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  static const _color = OmniColors.textTertiary;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: _color),
        const SizedBox(width: 3),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontSize: 12, color: _color),
        ),
      ],
    );
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({required this.address, required this.distanceKm});

  final String? address;
  final double? distanceKm;

  @override
  Widget build(BuildContext context) {
    final displayText = _buildDisplayText();
    if (displayText == null) return const SizedBox.shrink();

    return Row(
      children: [
        const Icon(
          Icons.location_on_outlined,
          size: 13,
          color: OmniColors.infoBlue,
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            displayText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 12,
              color: OmniColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  String? _buildDisplayText() {
    if (distanceKm != null && address != null) {
      return '$address · ${distanceKm!.toStringAsFixed(1)} km';
    }
    if (distanceKm != null) {
      return '${distanceKm!.toStringAsFixed(1)} km';
    }
    return address;
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final DoctorResultCardStatus status;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: OmniSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: OmniColors.amberSoft,
        borderRadius: BorderRadius.circular(OmniRadii.pill),
      ),
      child: Text(
        status.label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: OmniColors.amber,
        ),
      ),
    );
  }
}
