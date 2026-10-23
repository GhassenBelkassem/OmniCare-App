import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/omni_theme.dart';
import '../../../features/request_core/application/request_submission_controller.dart';
import '../application/patient_clinic_directory_controller.dart';
import '../data/patient_clinic_models.dart';
import 'clinic_presentation_metadata.dart';
import 'widgets/clinic_full_screen_gallery.dart';

/// Page 03 — Clinic detail (normal full-screen route).
///
/// Full-bleed hero gallery at the top with scrollable clinic content below.
/// Back button and image counter float over the hero.
///
/// Backend values ([displayName], [about], [address], [city], [governorate],
/// [primaryImageUrl], [gallery], [acceptingRequests]) stay authoritative.
/// Presentation-only data comes from [ClinicPresentationCatalog] and never
/// mutates the DTO.
class ClinicDetailScreen extends StatefulWidget {
  const ClinicDetailScreen({super.key, required this.clinicId});

  final String clinicId;

  @override
  State<ClinicDetailScreen> createState() => _ClinicDetailScreenState();
}

class _ClinicDetailScreenState extends State<ClinicDetailScreen> {
  bool _detailRequested = false;
  int _heroIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _detailRequested) return;
      _detailRequested = true;
      context.read<PatientClinicDirectoryController>().fetchDetail(
        widget.clinicId,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final directory = context.watch<PatientClinicDirectoryController>();
    final request = context.watch<RequestSubmissionController>();
    final detail = directory.detail;

    final failed = directory.detailError != null && detail == null;
    final loading = detail == null && !failed;

    return Scaffold(
      backgroundColor: Colors.black,
      body: detail == null
          ? (loading
              ? const Center(child: CircularProgressIndicator())
              : _ErrorState(
                  message:
                      directory.detailError?.message ??
                      'Unable to load this clinic.',
                  onRetry: () => directory.fetchDetail(widget.clinicId),
                ))
          : _FullPageDetail(
              detail: detail,
              heroIndex: _heroIndex,
              onPageChanged: (index) => setState(() => _heroIndex = index),
              accepting: detail.acceptingRequests,
              onSelect: () {
                request.selectClinic(detail.clinicId);
                Navigator.of(context).pop();
              },
            ),
    );
  }
}

/// Normal full-screen page: hero at top, scrollable content, sticky CTA.
class _FullPageDetail extends StatelessWidget {
  const _FullPageDetail({
    required this.detail,
    required this.heroIndex,
    required this.onPageChanged,
    required this.accepting,
    required this.onSelect,
  });

  final PatientClinicDetail detail;
  final int heroIndex;
  final ValueChanged<int> onPageChanged;
  final bool accepting;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final metadata = ClinicPresentationCatalog.forClinic(detail.clinicId);
    final heroImages = _resolveHeroImages(detail, metadata);
    final allImages = _allGalleryImages(detail, metadata);
    final heroTotal = heroImages.length + metadata.localDemoImages.length;
    final heroHeight = MediaQuery.sizeOf(context).height * 0.42;

    return Stack(
      children: [
        // Scrollable content (hero + sections)
        Positioned.fill(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              // Hero gallery
              SizedBox(
                height: heroHeight,
                child: _HeroGallery(
                  images: heroImages,
                  localAssets: metadata.localDemoImages,
                  heroIndex: heroIndex,
                  onPageChanged: onPageChanged,
                  onTap: () => _openFullScreenGallery(
                    context,
                    networkImages: allImages,
                    localAssets: metadata.localDemoImages,
                    initialIndex: heroIndex,
                  ),
                ),
              ),
              // Content sections
              _PageContent(
                detail: detail,
                metadata: metadata,
                accepting: accepting,
                onSelect: onSelect,
                allNetworkImages: allImages,
                localAssets: metadata.localDemoImages,
              ),
            ],
          ),
        ),
        // Back button
        Positioned(
          top: MediaQuery.paddingOf(context).top + OmniSpacing.sm,
          left: OmniSpacing.base,
          child: _BackButton(),
        ),
        // Image counter
        if (heroTotal > 1)
          Positioned(
            right: OmniSpacing.base,
            top: MediaQuery.paddingOf(context).top + OmniSpacing.sm,
            child: _ImageCounter(
              index: heroIndex,
              total: heroTotal,
            ),
          ),
        // Sticky bottom bar
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _StickyBottomBar(
            detail: detail,
            accepting: accepting,
            onSelect: onSelect,
          ),
        ),
      ],
    );
  }
}

/// White content section with all clinic details.
class _PageContent extends StatelessWidget {
  const _PageContent({
    required this.detail,
    required this.metadata,
    required this.accepting,
    required this.onSelect,
    required this.allNetworkImages,
    required this.localAssets,
  });

  final PatientClinicDetail detail;
  final ClinicPresentationMetadata metadata;
  final bool accepting;
  final VoidCallback onSelect;
  final List<PatientClinicImage> allNetworkImages;
  final List<ClinicPresentationImage> localAssets;

  static const _sectionSpacing = SizedBox(height: 22);
  static const _contentSpacing = SizedBox(height: 14);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final aboutText = _aboutText(detail, metadata);
    final address = detail.address;
    final locationAddress =
        address != null && address.trim().isNotEmpty ? address.trim() : null;
    final cityGov = _cityGovernorate(detail) ?? '';
    final hasLocation = locationAddress != null || cityGov.isNotEmpty;

    return Container(
      decoration: const BoxDecoration(
        color: OmniColors.surfacePrimary,
      ),
      padding: const EdgeInsets.only(bottom: 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildIdentity(theme),
          _sectionSpacing,
          const _ThinDivider(),
          _buildSpecialties(theme),
          _sectionSpacing,
          const _ThinDivider(),
          if (metadata.availability.isNotEmpty) ...[
            _buildAvailability(theme),
            _sectionSpacing,
            const _ThinDivider(),
          ],
          if (metadata.doctors.isNotEmpty) ...[
            _buildDoctors(theme),
            _sectionSpacing,
            const _ThinDivider(),
          ],
          if (metadata.insurance.isNotEmpty) ...[
            _buildInsurance(theme),
            _sectionSpacing,
            const _ThinDivider(),
          ],
          if (hasLocation) ...[
            _buildLocation(theme, locationAddress, cityGov),
            _sectionSpacing,
            const _ThinDivider(),
          ],
          if (metadata.facilities.isNotEmpty) ...[
            _buildFacilities(theme),
            _sectionSpacing,
            const _ThinDivider(),
          ],
          if (metadata.hours != null) ...[
            _buildHours(theme),
            _sectionSpacing,
            const _ThinDivider(),
          ],
          if (allNetworkImages.length > 1) ...[
            _buildPhotos(theme),
            _sectionSpacing,
            const _ThinDivider(),
          ],
          if (metadata.accessibility.isNotEmpty ||
              metadata.languages.isNotEmpty) ...[
            _buildAccessibilityLanguages(theme),
            _sectionSpacing,
            const _ThinDivider(),
          ],
          if (aboutText.trim().isNotEmpty) ...[
            _buildAbout(theme, aboutText),
            _sectionSpacing,
            const _ThinDivider(),
          ],
          if (metadata.verification != null &&
              metadata.verification!.badges.isNotEmpty) ...[
            _buildVerification(theme),
            _sectionSpacing,
            const _ThinDivider(),
          ],
          _buildNextSteps(theme),
        ],
      ),
    );
  }

  Widget _buildIdentity(ThemeData theme) {
    final cityGov = _cityGovernorate(detail) ?? '';
    final locality = metadata.locality;
    final locationParts = <String>[
      if (detail.city != null && detail.city!.trim().isNotEmpty)
        detail.city!.trim(),
      if (locality != null && locality.trim().isNotEmpty) locality.trim(),
    ];
    final locationLine =
        locationParts.isNotEmpty ? locationParts.join(', ') : cityGov;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        OmniSpacing.pageHorizontal,
        OmniSpacing.lg,
        OmniSpacing.pageHorizontal,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            detail.displayName,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontSize: 25,
              height: 1.18,
              fontWeight: FontWeight.w700,
              color: OmniColors.textPrimary,
              letterSpacing: -0.35,
            ),
          ),
          const SizedBox(height: OmniSpacing.xs + 2),
          Text(
            '${metadata.clinicType}${locationLine.isNotEmpty ? " \u00b7 $locationLine" : ""}',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 14,
              height: 1.3,
              color: OmniColors.textSecondary,
            ),
          ),
          const SizedBox(height: OmniSpacing.sm + 2),
          Row(
            children: [
              _AcceptingPill(accepting: accepting),
              const SizedBox(width: OmniSpacing.sm),
              if (metadata.availability.isNotEmpty &&
                  metadata.availability.first.isOpen)
                _StatusDot(
                  label: 'Open now',
                  color: OmniColors.deepTeal,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSpecialties(ThemeData theme) {
    final extras = metadata.specialties.length > 3
        ? metadata.specialties.length - 3
        : 0;
    final supporting = metadata.specialties.take(3).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        OmniSpacing.pageHorizontal,
        0,
        OmniSpacing.pageHorizontal,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(title: 'Specialties & expertise'),
          _contentSpacing,
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(OmniSpacing.base),
            decoration: BoxDecoration(
              color: OmniColors.violetSoft,
              borderRadius: BorderRadius.circular(OmniRadii.card),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: OmniColors.surfacePrimary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.local_hospital_outlined,
                    size: 19,
                    color: OmniColors.violet,
                  ),
                ),
                const SizedBox(width: OmniSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        metadata.primarySpecialty,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 15,
                          height: 1.3,
                          fontWeight: FontWeight.w700,
                          color: OmniColors.violet,
                        ),
                      ),
                      if (metadata.primarySpecialtyDescription != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          metadata.primarySpecialtyDescription!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 13,
                            height: 1.3,
                            color: OmniColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (supporting.isNotEmpty) ...[
            const SizedBox(height: OmniSpacing.sm + 2),
            Wrap(
              spacing: OmniSpacing.xs + 2,
              runSpacing: OmniSpacing.xs + 2,
              children: [
                for (final s in supporting)
                  Text(
                    s,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 13,
                      height: 1.2,
                      color: OmniColors.textSecondary,
                    ),
                  ),
                if (extras > 0)
                  Text(
                    '+$extras',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 13,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                      color: OmniColors.violet,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAvailability(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        OmniSpacing.pageHorizontal,
        0,
        OmniSpacing.pageHorizontal,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(title: 'Next availability'),
          _contentSpacing,
          Row(
            children: [
              for (var i = 0; i < metadata.availability.length && i < 3; i++) ...[
                if (i > 0) const SizedBox(width: OmniSpacing.md),
                _AvailabilityChip(slot: metadata.availability[i]),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDoctors(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        OmniSpacing.pageHorizontal,
        0,
        OmniSpacing.pageHorizontal,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(title: 'Doctors'),
          _contentSpacing,
          for (var i = 0; i < metadata.doctors.length && i < 3; i++) ...[
            if (i > 0) const SizedBox(height: OmniSpacing.sm),
            _DoctorRow(doctor: metadata.doctors[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildInsurance(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        OmniSpacing.pageHorizontal,
        0,
        OmniSpacing.pageHorizontal,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(title: 'Accepted insurance'),
          _contentSpacing,
          if (metadata.insuranceHighlight != null) ...[
            Row(
              children: [
                Text(
                  metadata.insuranceHighlight!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 14,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                    color: OmniColors.deepTeal,
                  ),
                ),
                const SizedBox(width: OmniSpacing.xs),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: OmniSpacing.sm,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: OmniColors.mintSoft,
                    borderRadius: BorderRadius.circular(OmniRadii.pill),
                  ),
                  child: Text(
                    'Accepted \u2713',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 12,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                      color: OmniColors.deepTeal,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: OmniSpacing.sm),
          ],
          Wrap(
            spacing: OmniSpacing.sm,
            runSpacing: OmniSpacing.sm,
            children: [
              for (final label in metadata.insurance)
                _InfoChip(
                  icon: Icons.shield_outlined,
                  label: label,
                  iconColor: OmniColors.infoBlue,
                  bgColor: OmniColors.infoBlueSoft,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLocation(
    ThemeData theme,
    String? locationAddress,
    String cityGov,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        OmniSpacing.pageHorizontal,
        0,
        OmniSpacing.pageHorizontal,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(title: 'Location'),
          _contentSpacing,
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(OmniSpacing.base),
            decoration: BoxDecoration(
              color: OmniColors.infoBlueSoft,
              borderRadius: BorderRadius.circular(OmniRadii.card),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: OmniColors.surfacePrimary,
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
                      if (metadata.distance != null)
                        Text(
                          '${metadata.distance}${metadata.driveTime != null ? " \u00b7 ${metadata.driveTime}" : ""}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 13,
                            height: 1.3,
                            fontWeight: FontWeight.w600,
                            color: OmniColors.infoBlue,
                          ),
                        ),
                      if (locationAddress != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          locationAddress,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 13,
                            height: 1.4,
                            color: OmniColors.textPrimary,
                          ),
                        ),
                      ],
                      if (cityGov.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          cityGov,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontSize: 13,
                            height: 1.35,
                            color: OmniColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFacilities(ThemeData theme) {
    final show = metadata.facilities.take(4).toList();
    final extra = (metadata.totalFacilitiesCount ?? metadata.facilities.length) -
        metadata.facilities.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        OmniSpacing.pageHorizontal,
        0,
        OmniSpacing.pageHorizontal,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(title: 'Facilities'),
          _contentSpacing,
          Wrap(
            spacing: OmniSpacing.sm,
            runSpacing: OmniSpacing.sm,
            children: [
              for (final f in show) _FacilityChip(facility: f),
              if (extra > 0)
                Text(
                  '+$extra',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 13,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                    color: OmniColors.clinicalCyan,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHours(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        OmniSpacing.pageHorizontal,
        0,
        OmniSpacing.pageHorizontal,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(title: 'Hours'),
          _contentSpacing,
          Row(
            children: [
              const Icon(Icons.circle, size: 8, color: OmniColors.freshMint),
              const SizedBox(width: OmniSpacing.sm),
              Text(
                'Open now',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 14,
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                  color: OmniColors.deepTeal,
                ),
              ),
              const SizedBox(width: OmniSpacing.xs),
              Text(
                '\u00b7 Today \u00b7 ${metadata.hours!.weekday}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 14,
                  height: 1.3,
                  color: OmniColors.textSecondary,
                ),
              ),
            ],
          ),
          if (metadata.emergencyHours != null) ...[
            const SizedBox(height: OmniSpacing.xs + 2),
            Row(
              children: [
                const Icon(
                  Icons.circle,
                  size: 8,
                  color: OmniColors.urgentCoral,
                ),
                const SizedBox(width: OmniSpacing.sm),
                Text(
                  'Emergency',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 14,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                    color: OmniColors.textPrimary,
                  ),
                ),
                const SizedBox(width: OmniSpacing.xs),
                Text(
                  metadata.emergencyHours!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 14,
                    height: 1.3,
                    color: OmniColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPhotos(ThemeData theme) {
    final total = allNetworkImages.length + localAssets.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        OmniSpacing.pageHorizontal,
        0,
        OmniSpacing.pageHorizontal,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _SectionTitle(title: 'Photos'),
              Text(
                'View all $total',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 14,
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                  color: OmniColors.deepTeal,
                ),
              ),
            ],
          ),
          _contentSpacing,
          SizedBox(
            height: 80,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: total,
              separatorBuilder: (_, _) =>
                  const SizedBox(width: OmniSpacing.sm),
              itemBuilder: (context, index) {
                if (index < allNetworkImages.length) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(OmniRadii.field),
                    child: Image.network(
                      allNetworkImages[index].imageUrl,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => _placeholder(),
                    ),
                  );
                }
                final assetIndex = index - allNetworkImages.length;
                return ClipRRect(
                  borderRadius: BorderRadius.circular(OmniRadii.field),
                  child: Image.asset(
                    localAssets[assetIndex].value,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _placeholder(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  static Widget _placeholder() => Container(
    width: 80,
    height: 80,
    color: OmniColors.slateSoft,
    child: const Icon(
      Icons.broken_image_outlined,
      size: 24,
      color: OmniColors.slateBlue,
    ),
  );

  Widget _buildAccessibilityLanguages(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        OmniSpacing.pageHorizontal,
        0,
        OmniSpacing.pageHorizontal,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(title: 'Accessibility & Languages'),
          _contentSpacing,
          if (metadata.accessibility.isNotEmpty) ...[
            Wrap(
              spacing: OmniSpacing.sm,
              runSpacing: OmniSpacing.sm,
              children: [
                for (final f in metadata.accessibility)
                  _InfoChip(
                    icon: Icons.accessibility_new,
                    label: f,
                    iconColor: OmniColors.deepTeal,
                    bgColor: OmniColors.mintSoft,
                  ),
              ],
            ),
          ],
          if (metadata.accessibility.isNotEmpty &&
              metadata.languages.isNotEmpty)
            const SizedBox(height: OmniSpacing.sm),
          if (metadata.languages.isNotEmpty)
            Text(
              metadata.languages.join(' \u00b7 '),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 14,
                height: 1.3,
                color: OmniColors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAbout(ThemeData theme, String aboutText) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        OmniSpacing.pageHorizontal,
        0,
        OmniSpacing.pageHorizontal,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(title: 'About this clinic'),
          _contentSpacing,
          Text(
            aboutText,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 15,
              height: 1.5,
              color: OmniColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerification(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        OmniSpacing.pageHorizontal,
        0,
        OmniSpacing.pageHorizontal,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(title: 'Clinic information'),
          _contentSpacing,
          for (var i = 0; i < metadata.verification!.badges.length; i++) ...[
            if (i > 0) const SizedBox(height: OmniSpacing.sm),
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: OmniColors.mintSoft,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.verified_outlined,
                    size: 15,
                    color: OmniColors.deepTeal,
                  ),
                ),
                const SizedBox(width: OmniSpacing.sm),
                Expanded(
                  child: Text(
                    metadata.verification!.badges[i],
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontSize: 14,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                      color: OmniColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNextSteps(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        OmniSpacing.pageHorizontal,
        0,
        OmniSpacing.pageHorizontal,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(title: 'What happens next'),
          _contentSpacing,
          _NextSteps(),
        ],
      ),
    );
  }
}

/// Sticky bottom bar with clinic summary and CTA.
class _StickyBottomBar extends StatelessWidget {
  const _StickyBottomBar({
    required this.detail,
    required this.accepting,
    required this.onSelect,
  });

  final PatientClinicDetail detail;
  final bool accepting;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final metadata = ClinicPresentationCatalog.forClinic(detail.clinicId);
    final cityGov = _cityGovernorate(detail) ?? '';
    final locality = metadata.locality;
    final locationParts = <String>[];
    if (detail.city != null && detail.city!.trim().isNotEmpty) {
      locationParts.add(detail.city!.trim());
    }
    if (locality != null && locality.trim().isNotEmpty) {
      locationParts.add(locality.trim());
    }
    final locationLine =
        locationParts.isNotEmpty ? locationParts.join(', ') : cityGov;

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: OmniColors.surfacePrimary,
        boxShadow: [
          BoxShadow(
            color: Color(0x0F000000),
            blurRadius: 14,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            OmniSpacing.pageHorizontal,
            OmniSpacing.md,
            OmniSpacing.pageHorizontal,
            OmniSpacing.sm,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      detail.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 14,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                        color: OmniColors.textPrimary,
                      ),
                    ),
                    if (locationLine.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        locationLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 12,
                          height: 1.3,
                          color: OmniColors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          accepting
                              ? Icons.check_circle_outline
                              : Icons.cancel_outlined,
                          size: 12,
                          color: accepting
                              ? OmniColors.freshMint
                              : OmniColors.amber,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          accepting ? 'Accepting' : 'Not accepting',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontSize: 11,
                            height: 1.2,
                            fontWeight: FontWeight.w600,
                            color: accepting
                                ? OmniColors.deepTeal
                                : OmniColors.amber,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: OmniSpacing.md),
              SizedBox(
                width: 160,
                height: 50,
                child: ElevatedButton(
                  onPressed: accepting ? onSelect : null,
                  child: const Text('Select this clinic'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Small reusable widgets ────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontSize: 18,
        height: 1.3,
        fontWeight: FontWeight.w700,
        color: OmniColors.textPrimary,
        letterSpacing: -0.2,
      ),
    );
  }
}

class _ThinDivider extends StatelessWidget {
  const _ThinDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: OmniSpacing.pageHorizontal),
      child: Divider(height: 1),
    );
  }
}

class _AcceptingPill extends StatelessWidget {
  const _AcceptingPill({required this.accepting});

  final bool accepting;

  @override
  Widget build(BuildContext context) {
    final bg = accepting ? OmniColors.mintSoft : OmniColors.amberSoft;
    final fg = accepting ? OmniColors.deepTeal : OmniColors.amber;
    final icon = accepting
        ? Icons.check_circle_outline
        : Icons.cancel_outlined;
    final label = accepting ? 'Accepting requests' : 'Not accepting requests';

    return Semantics(
      label: label,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: OmniSpacing.sm + 2,
          vertical: OmniSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(OmniRadii.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: OmniSpacing.xs),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 12,
                height: 1.2,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.circle, size: 6, color: color),
        const SizedBox(width: OmniSpacing.xs),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontSize: 12,
            height: 1.2,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _AvailabilityChip extends StatelessWidget {
  const _AvailabilityChip({required this.slot});

  final ClinicAvailabilitySlot slot;

  @override
  Widget build(BuildContext context) {
    final fg = slot.isOpen ? OmniColors.deepTeal : OmniColors.amber;
    final bg = slot.isOpen ? OmniColors.mintSoft : OmniColors.amberSoft;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: OmniSpacing.md,
        vertical: OmniSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(OmniRadii.field),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            slot.label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 11,
              height: 1.2,
              color: OmniColors.textSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            slot.time,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 14,
              height: 1.2,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

class _DoctorRow extends StatelessWidget {
  const _DoctorRow({required this.doctor});

  final ClinicDoctorPresentation doctor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: OmniColors.violetSoft,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.person_outline,
            size: 17,
            color: OmniColors.violet,
          ),
        ),
        const SizedBox(width: OmniSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                doctor.name,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 14,
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                  color: OmniColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                doctor.specialty,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 13,
                  height: 1.3,
                  color: OmniColors.textSecondary,
                ),
              ),
              if (doctor.subtitle != null) ...[
                const SizedBox(height: 1),
                Text(
                  doctor.subtitle!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 12,
                    height: 1.3,
                    color: OmniColors.textTertiary,
                  ),
                ),
              ],
              if (doctor.availabilityLabel != null) ...[
                const SizedBox(height: 2),
                Text(
                  doctor.availabilityLabel!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 12,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                    color: OmniColors.deepTeal,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.bgColor,
  });

  final IconData icon;
  final String label;
  final Color iconColor;
  final Color bgColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: OmniSpacing.md,
        vertical: OmniSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(OmniRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: OmniSpacing.xs),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontSize: 13,
              height: 1.2,
              fontWeight: FontWeight.w600,
              color: iconColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _FacilityChip extends StatelessWidget {
  const _FacilityChip({required this.facility});

  final ClinicFacilityPresentation facility;

  @override
  Widget build(BuildContext context) {
    return _InfoChip(
      icon: _facilityIcon(facility.icon),
      label: facility.label,
      iconColor: OmniColors.clinicalCyan,
      bgColor: OmniColors.clinicalCyanSoft,
    );
  }

  IconData _facilityIcon(String icon) {
    switch (icon) {
      case 'radiography':
        return Icons.radio;
      case 'monitor_heart':
        return Icons.monitor_heart_outlined;
      case 'ecg':
        return Icons.monitor_heart_outlined;
      case 'fitness_center':
        return Icons.fitness_center;
      case 'pool':
        return Icons.pool;
      case 'biotech':
        return Icons.biotech;
      case 'airline_seat_flat':
        return Icons.airline_seat_flat_outlined;
      case 'flash_on':
        return Icons.flash_on;
      default:
        return Icons.medical_services_outlined;
    }
  }
}

class _NextSteps extends StatelessWidget {
  const _NextSteps();

  static const _steps = <_ProcessStep>[
    _ProcessStep(
      number: 1,
      title: 'Send your request',
      body: 'Share the care details needed by the clinic.',
    ),
    _ProcessStep(
      number: 2,
      title: 'Administrative review',
      body: 'The clinic team reviews your request.',
    ),
    _ProcessStep(
      number: 3,
      title: 'Receive next steps',
      body: "You'll get the next update in OmniCare.",
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _steps.length; i++) ...[
          if (i > 0) ...[
            const SizedBox(height: OmniSpacing.xs + 2),
            Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Container(
                width: 1.5,
                height: 18,
                color: OmniColors.infoBlueSoft,
              ),
            ),
            const SizedBox(height: OmniSpacing.xs + 2),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: OmniColors.infoBlueSoft,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${_steps[i].number}',
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                    color: OmniColors.infoBlue,
                  ),
                ),
              ),
              const SizedBox(width: OmniSpacing.md),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _steps[i].title,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 14,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                          color: OmniColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _steps[i].body,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 13,
                          height: 1.4,
                          color: OmniColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _ProcessStep {
  const _ProcessStep({
    required this.number,
    required this.title,
    required this.body,
  });

  final int number;
  final String title;
  final String body;
}

class _BackButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Back',
      button: true,
      child: GestureDetector(
        onTap: () => Navigator.of(context).maybePop(),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.arrow_back_rounded,
            size: 22,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _ImageCounter extends StatelessWidget {
  const _ImageCounter({required this.index, required this.total});

  final int index;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: OmniSpacing.sm + 2,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(OmniRadii.pill),
      ),
      child: Semantics(
        label: 'Image ${index + 1} of $total',
        child: Text(
          '${index + 1} / $total',
          style: const TextStyle(
            fontSize: 12,
            height: 1.2,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _HeroGallery extends StatelessWidget {
  const _HeroGallery({
    required this.images,
    required this.localAssets,
    required this.heroIndex,
    required this.onPageChanged,
    required this.onTap,
  });

  final List<PatientClinicImage> images;
  final List<ClinicPresentationImage> localAssets;
  final int heroIndex;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final total = images.length + localAssets.length;

    if (total == 0) {
      return Container(
        color: OmniColors.slateSoft,
        child: const Center(
          child: Icon(
            Icons.medical_services_outlined,
            size: 42,
            color: OmniColors.slateBlue,
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: double.infinity,
        child: PageView.builder(
          itemCount: total,
          onPageChanged: onPageChanged,
          itemBuilder: (context, index) {
            if (index < images.length) {
              return Image.network(
                images[index].imageUrl,
                height: double.infinity,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: OmniColors.slateSoft,
                  child: const Icon(
                    Icons.broken_image_outlined,
                    size: 42,
                    color: OmniColors.slateBlue,
                  ),
                ),
              );
            }
            final assetIndex = index - images.length;
            return Image.asset(
              localAssets[assetIndex].value,
              height: double.infinity,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                color: OmniColors.slateSoft,
                child: const Icon(
                  Icons.broken_image_outlined,
                  size: 42,
                  color: OmniColors.slateBlue,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(OmniSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: OmniColors.errorSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                size: 26,
                color: OmniColors.error,
              ),
            ),
            const SizedBox(height: OmniSpacing.base),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontSize: 15,
                height: 1.4,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: OmniSpacing.base + 4),
            SizedBox(
              width: 160,
              height: 44,
              child: ElevatedButton(
                onPressed: onRetry,
                child: const Text('Try again'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Helpers ───────────────────────────────────────────────────────────

List<PatientClinicImage> _resolveHeroImages(
  PatientClinicDetail detail,
  ClinicPresentationMetadata metadata,
) {
  if (detail.gallery.isNotEmpty) return detail.gallery;
  final primary = detail.primaryImageUrl;
  if (primary != null && primary.trim().isNotEmpty) {
    return [PatientClinicImage(imageUrl: primary.trim())];
  }
  return [
    for (final url in metadata.fallbackGallery)
      if (url.trim().isNotEmpty) PatientClinicImage(imageUrl: url.trim()),
  ];
}

List<PatientClinicImage> _allGalleryImages(
  PatientClinicDetail detail,
  ClinicPresentationMetadata metadata,
) {
  if (detail.gallery.isNotEmpty) return detail.gallery;
  final primary = detail.primaryImageUrl;
  if (primary != null && primary.trim().isNotEmpty) {
    return [PatientClinicImage(imageUrl: primary.trim())];
  }
  return [
    for (final url in metadata.fallbackGallery)
      if (url.trim().isNotEmpty) PatientClinicImage(imageUrl: url.trim()),
  ];
}

String _aboutText(
  PatientClinicDetail detail,
  ClinicPresentationMetadata metadata,
) {
  final about = detail.about;
  if (about != null && about.trim().isNotEmpty) return about.trim();
  return metadata.shortDescription.trim();
}

String? _cityGovernorate(PatientClinicDetail detail) {
  final parts = <String>[
    if (detail.city != null && detail.city!.trim().isNotEmpty)
      detail.city!.trim(),
    if (detail.governorate != null && detail.governorate!.trim().isNotEmpty)
      detail.governorate!.trim(),
  ];
  return parts.isEmpty ? null : parts.join(', ');
}

void _openFullScreenGallery(
  BuildContext context, {
  required List<PatientClinicImage> networkImages,
  required List<ClinicPresentationImage> localAssets,
  required int initialIndex,
}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => ClinicFullScreenGallery(
        images: networkImages,
        localAssets: localAssets,
        initialIndex: initialIndex,
      ),
    ),
  );
}
