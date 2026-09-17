import 'package:flutter/material.dart';

import '../../../core/theme/omni_theme.dart';
import '../../patient_clinic/presentation/widgets/clinic_full_screen_gallery.dart';
import '../../patient_clinic/presentation/clinic_presentation_metadata.dart'
    as clinic;
import '../../patient_clinic/presentation/widgets/clinic_image_renderer.dart';
import '../data/doctor_detail_mock_data.dart';
import '../data/doctor_detail_models.dart';
import 'doctor_availability_sheet.dart';
import 'doctor_presentation_metadata.dart';

/// Doctor detail / profile screen.
///
/// The profile keeps the existing navigation and availability flow, while
/// presenting the doctor as a person first and their clinical metadata second.
class DoctorDetailScreen extends StatelessWidget {
  const DoctorDetailScreen({super.key, required this.doctorId});

  final String doctorId;

  @override
  Widget build(BuildContext context) {
    final detail = getDoctorDetail(doctorId);
    if (detail == null) {
      return Scaffold(
        backgroundColor: OmniColors.pageBackground,
        appBar: AppBar(title: const Text('Profil du médecin')),
        body: const Center(child: Text('Médecin introuvable')),
      );
    }
    return _DoctorDetailBody(detail: detail);
  }
}

class _DoctorDetailBody extends StatefulWidget {
  const _DoctorDetailBody({required this.detail});

  final DoctorDetail detail;

  @override
  State<_DoctorDetailBody> createState() => _DoctorDetailBodyState();
}

class _DoctorDetailBodyState extends State<_DoctorDetailBody> {
  static const _tabLabels = ['À propos', 'Disponibilités', 'Cabinet'];
  int _selectedTab = 0;

  DoctorDetail get detail => widget.detail;

  PracticeLocation? get location => detail.practiceLocations.isNotEmpty
      ? detail.practiceLocations.first
      : null;

  void _openAvailabilitySheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => DoctorAvailabilitySheet(detail: detail),
    );
  }

  Widget _tabContent() {
    final metadata = DoctorPresentationCatalog.forDoctor(detail.id);
    return switch (_selectedTab) {
      0 => _AboutTab(detail: detail),
      1 => _AvailabilityTab(detail: detail, onSeeAll: _openAvailabilitySheet),
      2 => _CabinetTab(location: location, metadata: metadata),
      _ => _AboutTab(detail: detail),
    };
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: OmniColors.pageBackground,
      body: Stack(
        children: [
          Positioned.fill(
            child: Column(
              children: [
                SizedBox(height: topInset),
                _DoctorIdentityHeader(
                  detail: detail,
                  location: location,
                  metadata: DoctorPresentationCatalog.forDoctor(detail.id),
                ),
                _SegmentedTabBar(
                  labels: _tabLabels,
                  selectedIndex: _selectedTab,
                  onTabSelected: (index) =>
                      setState(() => _selectedTab = index),
                ),
                Expanded(child: _tabContent()),
              ],
            ),
          ),
          Positioned(
            top: topInset + OmniSpacing.sm,
            left: OmniSpacing.base,
            child: const _BackButton(),
          ),
        ],
      ),
    );
  }
}

class _DoctorIdentityHeader extends StatelessWidget {
  const _DoctorIdentityHeader({
    required this.detail,
    required this.location,
    required this.metadata,
  });

  final DoctorDetail detail;
  final PracticeLocation? location;
  final DoctorPresentationMetadata metadata;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      color: OmniColors.surfacePrimary,
      padding: const EdgeInsets.fromLTRB(
        OmniSpacing.pageHorizontal,
        56,
        OmniSpacing.pageHorizontal,
        OmniSpacing.md,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final portraitSize = constraints.maxWidth < 360 ? 84.0 : 104.0;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DoctorPortrait(
                    name: detail.name,
                    image: metadata.portrait,
                    size: portraitSize,
                  ),
                  const SizedBox(width: OmniSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                detail.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontSize: 22,
                                  height: 1.15,
                                  fontWeight: FontWeight.w700,
                                  color: OmniColors.textPrimary,
                                  letterSpacing: -0.4,
                                ),
                              ),
                            ),
                            if (detail.verified) ...[
                              const SizedBox(width: OmniSpacing.xs),
                              const Padding(
                                padding: EdgeInsets.only(top: 2),
                                child: Icon(
                                  Icons.verified,
                                  size: 18,
                                  color: OmniColors.freshMint,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          detail.specialty,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 14,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                            color: OmniColors.violet,
                          ),
                        ),
                        if (detail.subSpecialties.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            detail.subSpecialties.join(' · '),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 12,
                              height: 1.35,
                              color: OmniColors.textSecondary,
                            ),
                          ),
                        ],
                        const SizedBox(height: OmniSpacing.sm),
                        _HeaderMetaLine(
                          icon: Icons.work_outline_rounded,
                          label: '${detail.experienceYears} ans d\'expérience',
                        ),
                        if (location != null)
                          _HeaderMetaLine(
                            icon: Icons.location_on_outlined,
                            label: _locationLabel(location!),
                          ),
                        if (detail.languages.isNotEmpty)
                          _HeaderMetaLine(
                            icon: Icons.language_outlined,
                            label: detail.languages.join(' · '),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: OmniSpacing.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    detail.acceptingNewPatients
                        ? Icons.check_circle_outline
                        : Icons.cancel_outlined,
                    size: 17,
                    color: detail.acceptingNewPatients
                        ? OmniColors.deepTeal
                        : OmniColors.amber,
                  ),
                  const SizedBox(width: OmniSpacing.xs),
                  Expanded(
                    child: Text(
                      detail.acceptingNewPatients
                          ? 'Accepte de nouveaux patients'
                          : 'Nouveaux patients non acceptés',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                        color: detail.acceptingNewPatients
                            ? OmniColors.deepTeal
                            : OmniColors.amber,
                      ),
                    ),
                  ),
                ],
              ),
              if (detail.nextAvailableLabel != null) ...[
                const SizedBox(height: OmniSpacing.md),
                _NextAvailabilitySummary(label: detail.nextAvailableLabel!),
              ],
            ],
          );
        },
      ),
    );
  }

  String _locationLabel(PracticeLocation location) {
    final distance = location.distanceKm;
    if (distance == null) return location.city;
    return '${location.city} · ${distance.toStringAsFixed(1)} km';
  }
}

class _DoctorPortrait extends StatelessWidget {
  const _DoctorPortrait({
    required this.name,
    required this.image,
    required this.size,
  });

  final String name;
  final DoctorPresentationImage image;
  final double size;

  @override
  Widget build(BuildContext context) {
    final hasAsset = image.isAsset && image.value.trim().isNotEmpty;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: OmniColors.slateSoft,
        border: Border.all(color: OmniColors.borderLight, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasAsset
          ? Image.asset(
              image.value,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _InitialsFallback(name: name),
            )
          : _InitialsFallback(name: name),
    );
  }
}

class _HeaderMetaLine extends StatelessWidget {
  const _HeaderMetaLine({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          Icon(icon, size: 14, color: OmniColors.textTertiary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 12,
                height: 1.3,
                color: OmniColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NextAvailabilitySummary extends StatelessWidget {
  const _NextAvailabilitySummary({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: OmniSpacing.md,
        vertical: OmniSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: OmniColors.mintSoft,
        borderRadius: BorderRadius.circular(OmniRadii.field),
        border: Border.all(color: OmniColors.freshMint.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.schedule_outlined,
            size: 18,
            color: OmniColors.deepTeal,
          ),
          const SizedBox(width: OmniSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Disponibilité suivante',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: 11,
                    color: OmniColors.deepTeal,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: OmniColors.deepTealActive,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SegmentedTabBar extends StatelessWidget {
  const _SegmentedTabBar({
    required this.labels,
    required this.selectedIndex,
    required this.onTabSelected,
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: OmniColors.surfacePrimary,
      padding: const EdgeInsets.fromLTRB(
        OmniSpacing.pageHorizontal,
        0,
        OmniSpacing.pageHorizontal,
        OmniSpacing.sm,
      ),
      child: Container(
        height: 44,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: OmniColors.surfaceSecondary,
          borderRadius: BorderRadius.circular(OmniRadii.field),
        ),
        child: Row(
          children: [
            for (var i = 0; i < labels.length; i++)
              Expanded(
                child: GestureDetector(
                  onTap: () => onTabSelected(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: selectedIndex == i
                          ? OmniColors.surfacePrimary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(9),
                      border: selectedIndex == i
                          ? Border.all(color: OmniColors.borderLight)
                          : null,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: Text(
                        labels[i],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 12,
                          fontWeight: selectedIndex == i
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: selectedIndex == i
                              ? OmniColors.textPrimary
                              : OmniColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AboutTab extends StatefulWidget {
  const _AboutTab({required this.detail});

  final DoctorDetail detail;

  @override
  State<_AboutTab> createState() => _AboutTabState();
}

class _AboutTabState extends State<_AboutTab> {
  bool _showFullBiography = false;

  DoctorDetail get detail => widget.detail;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        OmniSpacing.pageHorizontal,
        OmniSpacing.md,
        OmniSpacing.pageHorizontal,
        OmniSpacing.pageVertical,
      ),
      children: [
        if (detail.areasOfCare.isNotEmpty) ...[
          const _SectionTitle(title: 'Domaines de prise en charge'),
          const SizedBox(height: OmniSpacing.sm),
          _TagWrap(
            labels: detail.areasOfCare,
            background: OmniColors.mintSoft,
            foreground: OmniColors.deepTeal,
            icon: Icons.check_circle_outline,
          ),
        ],
        if (detail.expertise.isNotEmpty) ...[
          const SizedBox(height: OmniSpacing.lg),
          const _SectionTitle(title: 'Expertises'),
          const SizedBox(height: OmniSpacing.sm),
          _TagWrap(
            labels: detail.expertise,
            background: OmniColors.violetSoft,
            foreground: OmniColors.violet,
            icon: Icons.auto_awesome_outlined,
          ),
        ],
        if (detail.visitReasons.isNotEmpty) ...[
          const SizedBox(height: OmniSpacing.lg),
          const _SectionTitle(title: 'Motifs de consultation'),
          const SizedBox(height: OmniSpacing.sm),
          _BulletList(labels: detail.visitReasons),
        ],
        if (detail.patientAgeGroups.isNotEmpty) ...[
          const SizedBox(height: OmniSpacing.lg),
          const _SectionTitle(title: 'Patients pris en charge'),
          const SizedBox(height: OmniSpacing.sm),
          _CompactRows(
            labels: detail.patientAgeGroups,
            icon: Icons.person_outline,
          ),
        ],
        if (detail.consultationTypes.isNotEmpty) ...[
          const SizedBox(height: OmniSpacing.lg),
          const _SectionTitle(title: 'Options de consultation'),
          const SizedBox(height: OmniSpacing.sm),
          _CompactRows(
            labels: detail.consultationTypes,
            iconForLabel: _consultationIcon,
          ),
        ],
        if (detail.biography != null && detail.biography!.isNotEmpty) ...[
          const SizedBox(height: OmniSpacing.lg),
          const _SectionTitle(title: 'À propos du médecin'),
          const SizedBox(height: OmniSpacing.sm),
          Text(
            detail.biography!,
            maxLines: _showFullBiography ? null : 4,
            overflow: _showFullBiography ? null : TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 14,
              height: 1.6,
              color: OmniColors.textSecondary,
            ),
          ),
          if (!_showFullBiography && detail.biography!.length > 240)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() => _showFullBiography = true),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.only(top: OmniSpacing.xs),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Voir plus'),
              ),
            ),
        ],
      ],
    );
  }

  IconData _consultationIcon(String label) {
    if (label.contains('Télé')) return Icons.videocam_outlined;
    if (label.contains('domicile')) return Icons.home_outlined;
    return Icons.local_hospital_outlined;
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: OmniColors.textPrimary,
      ),
    );
  }
}

class _TagWrap extends StatelessWidget {
  const _TagWrap({
    required this.labels,
    required this.background,
    required this.foreground,
    required this.icon,
  });

  final List<String> labels;
  final Color background;
  final Color foreground;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: OmniSpacing.sm,
      runSpacing: OmniSpacing.sm,
      children: [
        for (final label in labels)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: OmniSpacing.sm,
              vertical: OmniSpacing.xs + 2,
            ),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(OmniRadii.field),
              border: Border.all(color: foreground.withValues(alpha: 0.12)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 14, color: foreground),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: foreground,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _BulletList extends StatelessWidget {
  const _BulletList({required this.labels});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final label in labels)
          Padding(
            padding: const EdgeInsets.only(bottom: OmniSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 7),
                  child: Icon(
                    Icons.circle,
                    size: 6,
                    color: OmniColors.textTertiary,
                  ),
                ),
                const SizedBox(width: OmniSpacing.sm),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 13,
                      height: 1.35,
                      color: OmniColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _CompactRows extends StatelessWidget {
  const _CompactRows({required this.labels, this.icon, this.iconForLabel});

  final List<String> labels;
  final IconData? icon;
  final IconData Function(String label)? iconForLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final label in labels)
          Padding(
            padding: const EdgeInsets.only(bottom: OmniSpacing.sm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  iconForLabel?.call(label) ?? icon ?? Icons.circle_outlined,
                  size: 17,
                  color: OmniColors.textTertiary,
                ),
                const SizedBox(width: OmniSpacing.sm),
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 13,
                      height: 1.35,
                      color: OmniColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _AvailabilityTab extends StatelessWidget {
  const _AvailabilityTab({required this.detail, required this.onSeeAll});

  final DoctorDetail detail;
  final VoidCallback onSeeAll;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final nextDays = <_DayPreview>[];

    for (final day in detail.availability) {
      if (day.date.isAfter(today.subtract(const Duration(days: 1))) &&
          day.hasSlots &&
          nextDays.length < 2) {
        nextDays.add(
          _DayPreview(
            label: _dayLabel(day.date, today, tomorrow),
            slots: day.slots.take(3).map((slot) => slot.time).toList(),
          ),
        );
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        OmniSpacing.pageHorizontal,
        OmniSpacing.md,
        OmniSpacing.pageHorizontal,
        OmniSpacing.pageVertical,
      ),
      children: [
        const _SectionTitle(title: 'Prochaine disponibilité'),
        const SizedBox(height: OmniSpacing.sm),
        if (nextDays.isEmpty)
          _SoftPanel(
            child: Text(
              'Aucune disponibilité proche trouvée.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 14,
                color: OmniColors.textSecondary,
              ),
            ),
          )
        else
          for (final day in nextDays) ...[
            _AvailabilityDayPreview(day: day),
            const SizedBox(height: OmniSpacing.sm),
          ],
        const SizedBox(height: OmniSpacing.md),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: onSeeAll,
            icon: const Icon(Icons.calendar_today_outlined, size: 18),
            label: const Text('Voir tous les créneaux'),
          ),
        ),
      ],
    );
  }

  static String _dayLabel(DateTime date, DateTime today, DateTime tomorrow) {
    if (date.year == today.year &&
        date.month == today.month &&
        date.day == today.day) {
      return 'Aujourd\'hui';
    }
    if (date.year == tomorrow.year &&
        date.month == tomorrow.month &&
        date.day == tomorrow.day) {
      return 'Demain';
    }
    const months = [
      '',
      'janvier',
      'février',
      'mars',
      'avril',
      'mai',
      'juin',
      'juillet',
      'août',
      'septembre',
      'octobre',
      'novembre',
      'décembre',
    ];
    return '${date.day} ${months[date.month]}';
  }
}

class _DayPreview {
  const _DayPreview({required this.label, required this.slots});

  final String label;
  final List<String> slots;
}

class _AvailabilityDayPreview extends StatelessWidget {
  const _AvailabilityDayPreview({required this.day});

  final _DayPreview day;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(OmniSpacing.base),
      decoration: BoxDecoration(
        color: OmniColors.surfacePrimary,
        borderRadius: BorderRadius.circular(OmniRadii.card),
        border: Border.all(color: OmniColors.borderLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              day.label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: OmniColors.textPrimary,
              ),
            ),
          ),
          Wrap(
            spacing: OmniSpacing.sm,
            children: [
              for (final slot in day.slots.take(2))
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: OmniSpacing.sm,
                    vertical: OmniSpacing.xs + 2,
                  ),
                  decoration: BoxDecoration(
                    color: OmniColors.mintSoft,
                    borderRadius: BorderRadius.circular(OmniRadii.field),
                  ),
                  child: Text(
                    slot,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: OmniColors.deepTeal,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CabinetTab extends StatelessWidget {
  const _CabinetTab({required this.location, required this.metadata});

  final PracticeLocation? location;
  final DoctorPresentationMetadata metadata;

  @override
  Widget build(BuildContext context) {
    final cabinet = location;
    if (cabinet == null) {
      return const Center(
        child: Text('Aucune information cabinet disponible.'),
      );
    }

    final gallery = cabinet.galleryImages.isNotEmpty
        ? [
            for (final path in cabinet.galleryImages)
              DoctorPresentationImage.asset(path),
          ]
        : metadata.cabinetGallery;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        OmniSpacing.pageHorizontal,
        OmniSpacing.md,
        OmniSpacing.pageHorizontal,
        OmniSpacing.pageVertical,
      ),
      children: [
        if (gallery.isNotEmpty) ...[
          _CabinetGallery(images: gallery),
          const SizedBox(height: OmniSpacing.sm),
          Text(
            'Images de démonstration du cabinet',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: 11,
              color: OmniColors.textTertiary,
            ),
          ),
          const SizedBox(height: OmniSpacing.lg),
        ],
        const _SectionTitle(title: 'Localisation'),
        const SizedBox(height: OmniSpacing.sm),
        _LocationCard(location: cabinet),
        const SizedBox(height: OmniSpacing.sm),
        SizedBox(
          width: double.infinity,
          height: 46,
          child: OutlinedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.directions_outlined, size: 18),
            label: const Text('Itinéraire'),
          ),
        ),
        if (cabinet.equipment.isNotEmpty) ...[
          const SizedBox(height: OmniSpacing.lg),
          const _SectionTitle(title: 'Équipements et examens disponibles'),
          const SizedBox(height: OmniSpacing.sm),
          _TagWrap(
            labels: [
              for (final equipment in cabinet.equipment) equipment.label,
            ],
            background: OmniColors.clinicalCyanSoft,
            foreground: OmniColors.clinicalCyan,
            icon: Icons.medical_services_outlined,
          ),
        ],
        if (cabinet.openingHours.isNotEmpty) ...[
          const SizedBox(height: OmniSpacing.lg),
          const _SectionTitle(title: 'Horaires'),
          const SizedBox(height: OmniSpacing.sm),
          _HoursTable(hours: cabinet.openingHours),
        ],
        if (cabinet.accessibility.isNotEmpty ||
            cabinet.coverage.isNotEmpty) ...[
          const SizedBox(height: OmniSpacing.lg),
          const _SectionTitle(title: 'Informations pratiques'),
          const SizedBox(height: OmniSpacing.sm),
          _CompactRows(
            labels: [...cabinet.accessibility, ...cabinet.coverage],
            icon: Icons.check_circle_outline,
          ),
        ],
        if (cabinet.appointmentInstructions != null) ...[
          const SizedBox(height: OmniSpacing.lg),
          _SoftPanel(
            color: OmniColors.amberSoft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 18,
                  color: OmniColors.amber,
                ),
                const SizedBox(width: OmniSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Avant votre rendez-vous',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: OmniColors.amber,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        cabinet.appointmentInstructions!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 13,
                          height: 1.5,
                          color: OmniColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _CabinetGallery extends StatefulWidget {
  const _CabinetGallery({required this.images});

  final List<DoctorPresentationImage> images;

  @override
  State<_CabinetGallery> createState() => _CabinetGalleryState();
}

class _CabinetGalleryState extends State<_CabinetGallery> {
  late final PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 220,
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(OmniRadii.cardLarge),
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: widget.images.length,
                  onPageChanged: (index) =>
                      setState(() => _currentIndex = index),
                  itemBuilder: (context, index) => GestureDetector(
                    onTap: () => _openFullScreen(context, index),
                    child: _CabinetImage(
                      image: widget.images[index],
                      width: double.infinity,
                      height: 220,
                      borderRadius: BorderRadius.circular(OmniRadii.cardLarge),
                    ),
                  ),
                ),
              ),
              Positioned(
                right: OmniSpacing.sm,
                top: OmniSpacing.sm,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: OmniSpacing.sm,
                    vertical: OmniSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(OmniRadii.pill),
                  ),
                  child: Text(
                    '${_currentIndex + 1} / ${widget.images.length}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: OmniSpacing.sm),
        SizedBox(
          height: 64,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: widget.images.length,
            separatorBuilder: (_, _) => const SizedBox(width: OmniSpacing.sm),
            itemBuilder: (context, index) {
              final isSelected = index == _currentIndex;
              return GestureDetector(
                onTap: () {
                  _pageController.animateToPage(
                    index,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                  );
                },
                child: Container(
                  width: 78,
                  height: 64,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(OmniRadii.field),
                    border: Border.all(
                      color: isSelected
                          ? OmniColors.freshMint
                          : OmniColors.borderLight,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _CabinetImage(
                    image: widget.images[index],
                    width: 78,
                    height: 64,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _openFullScreen(BuildContext context, int initialIndex) {
    final localAssets = widget.images
        .where((image) => image.isAsset && image.value.trim().isNotEmpty)
        .map((image) => clinic.ClinicPresentationImage.asset(image.value))
        .toList(growable: false);
    if (localAssets.isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ClinicFullScreenGallery(
          images: const [],
          localAssets: localAssets,
          initialIndex: initialIndex.clamp(0, localAssets.length - 1).toInt(),
        ),
      ),
    );
  }
}

class _CabinetImage extends StatelessWidget {
  const _CabinetImage({
    required this.image,
    this.width,
    this.height,
    this.borderRadius,
  });

  final DoctorPresentationImage image;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    if (image.isAsset) {
      return ClinicImageRenderer(
        image: clinic.ClinicPresentationImage.asset(image.value),
        width: width,
        height: height,
        fit: BoxFit.cover,
        borderRadius: borderRadius,
      );
    }
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: Image.network(
        image.value,
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _galleryPlaceholder(width, height),
      ),
    );
  }

  static Widget _galleryPlaceholder(double? width, double? height) {
    return Container(
      width: width,
      height: height,
      color: OmniColors.slateSoft,
      child: const Icon(
        Icons.photo_outlined,
        size: 32,
        color: OmniColors.slateBlue,
      ),
    );
  }
}

class _LocationCard extends StatelessWidget {
  const _LocationCard({required this.location});

  final PracticeLocation location;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(OmniSpacing.base),
      decoration: BoxDecoration(
        color: OmniColors.surfacePrimary,
        borderRadius: BorderRadius.circular(OmniRadii.card),
        border: Border.all(color: OmniColors.borderLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: OmniColors.infoBlueSoft,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.location_on_outlined,
              size: 19,
              color: OmniColors.infoBlue,
            ),
          ),
          const SizedBox(width: OmniSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  location.name,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: OmniColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  location.address,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 13,
                    height: 1.4,
                    color: OmniColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  location.distanceKm == null
                      ? location.city
                      : '${location.city} · ${location.distanceKm!.toStringAsFixed(1)} km',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontSize: 13,
                    color: OmniColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HoursTable extends StatelessWidget {
  const _HoursTable({required this.hours});

  final List<PracticeOpeningHours> hours;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: OmniSpacing.xs),
      decoration: BoxDecoration(
        color: OmniColors.surfacePrimary,
        borderRadius: BorderRadius.circular(OmniRadii.card),
        border: Border.all(color: OmniColors.borderLight),
      ),
      child: Column(
        children: [
          for (final entry in hours)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: OmniSpacing.base,
                vertical: OmniSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.label,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 13,
                        color: OmniColors.textSecondary,
                      ),
                    ),
                  ),
                  Text(
                    entry.hours,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: OmniColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SoftPanel extends StatelessWidget {
  const _SoftPanel({
    required this.child,
    this.color = OmniColors.surfaceSecondary,
  });

  final Widget child;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(OmniSpacing.base),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(OmniRadii.card),
      ),
      child: child,
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Retour',
      button: true,
      child: GestureDetector(
        onTap: () => Navigator.of(context).maybePop(),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: OmniColors.surfacePrimary,
            shape: BoxShape.circle,
            border: Border.all(color: OmniColors.borderLight),
            boxShadow: const [OmniColors.shadowSm],
          ),
          child: const Icon(
            Icons.arrow_back_rounded,
            size: 22,
            color: OmniColors.textPrimary,
          ),
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
    return Center(
      child: Text(
        _initials(name),
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontSize: 28,
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
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return '${parts.first.substring(0, 1)}${parts.last.substring(0, 1)}'
      .toUpperCase();
}
