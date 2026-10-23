import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/omni_theme.dart';
import '../../data/patient_clinic_models.dart';
import '../clinic_presentation_metadata.dart';

/// A compact horizontal clinic result card in the patient directory.
///
/// The clinic is presented as a scannable row: image on the left, key
/// information on the right. Backend values ([displayName], [city],
/// [governorate], [acceptingRequests], [primaryImageUrl]) stay authoritative;
/// specialties and locality come from isolated presentation metadata.
class ClinicListCard extends StatelessWidget {
  const ClinicListCard({
    super.key,
    required this.clinic,
    required this.selected,
    required this.onTap,
  });

  final PatientClinicListItem clinic;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final metadata = ClinicPresentationCatalog.forClinic(clinic.clinicId);
    final location = _locationLabel(
      clinic.city,
      clinic.governorate,
      metadata.locality,
    );
    final primarySpecialty =
        metadata.specialties.isNotEmpty ? metadata.specialties.first : null;

    // Outer Container holds the shadow decoration — NOT clipped.
    // Inner ClipRRect clips only the image corners and content area.
    return Semantics(
      selected: selected,
      button: true,
      enabled: true,
      label: _semanticLabel(clinic, metadata, location),
      child: Container(
        height: 168,
        decoration: BoxDecoration(
          color: OmniColors.surfacePrimary,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? OmniColors.freshMint : OmniColors.borderLight,
            width: selected ? 1.3 : 1,
          ),
          boxShadow: const [OmniColors.shadowCard],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(17),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _CardImage(
                    imageUrl: _heroImageUrl(clinic, metadata),
                    selected: selected,
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (selected) ...[
                            const _SelectedBadge(),
                            const SizedBox(height: 4),
                          ],
                          Text(
                            clinic.displayName,
                            maxLines: 2,
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
                          if (location != null)
                            _LocationRow(
                              location: location,
                              distance: metadata.distance,
                            ),
                          if (location != null)
                            const SizedBox(height: 6),
                          if (primarySpecialty != null)
                            _SpecialtyRow(specialty: primarySpecialty),
                          if (primarySpecialty != null)
                            const SizedBox(height: 6),
                          _AvailabilityRow(accepting: clinic.acceptingRequests),
                        ],
                      ),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(right: 14),
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
      ),
    );
  }
}

/// Image priority: real backend primary image, then an approved presentation
/// fallback, then the branded neutral fallback.
String? _heroImageUrl(
  PatientClinicListItem clinic,
  ClinicPresentationMetadata metadata,
) {
  final primary = clinic.primaryImageUrl;
  if (primary != null && primary.trim().isNotEmpty) return primary;
  if (metadata.fallbackGallery.isNotEmpty) {
    final first = metadata.fallbackGallery.first.trim();
    if (first.isNotEmpty) return first;
  }
  return null;
}

/// Build the display location from backend city/governorate + presentation
/// locality. Duplicate city/locality is not rendered twice.
String? _locationLabel(
  String? city,
  String? governorate,
  String? locality,
) {
  final c = city?.trim();
  final g = governorate?.trim();
  final l = locality?.trim();

  // If locality exists, prefer "City, Locality" or just "Locality"
  // when locality already contains the city.
  if (l != null && l.isNotEmpty) {
    if (c != null && c.isNotEmpty) {
      if (l.toLowerCase().contains(c.toLowerCase())) return l;
      return '$c, $l';
    }
    return l;
  }

  // Fallback to city/governorate logic.
  if (c != null && c.isNotEmpty && g != null && g.isNotEmpty) {
    if (c.toLowerCase() == g.toLowerCase()) return c;
    return '$c, $g';
  }
  if (c != null && c.isNotEmpty) return c;
  if (g != null && g.isNotEmpty) return g;
  return null;
}

String _semanticLabel(
  PatientClinicListItem clinic,
  ClinicPresentationMetadata metadata,
  String? location,
) {
  final parts = <String>[clinic.displayName];
  if (location != null) parts.add(location);
  parts.add(
    clinic.acceptingRequests ? 'accepting requests' : 'not accepting requests',
  );
  return parts.join(', ');
}

class _CardImage extends StatelessWidget {
  const _CardImage({this.imageUrl, this.selected = false});

  final String? imageUrl;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: 120,
      color: OmniColors.slateSoft,
      child: const Center(
        child: Icon(
          Icons.medical_services_outlined,
          size: 28,
          color: OmniColors.slateBlue,
        ),
      ),
    );

    return SizedBox(
      width: 120,
      child: imageUrl == null
          ? placeholder
          : CachedNetworkImage(
              imageUrl: imageUrl!,
              fit: BoxFit.cover,
              fadeInDuration: const Duration(milliseconds: 150),
              placeholder: (context, url) => placeholder,
              errorWidget: (context, url, error) => placeholder,
            ),
    );
  }
}

class _SelectedBadge extends StatelessWidget {
  const _SelectedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: OmniSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: OmniColors.freshMint,
        borderRadius: BorderRadius.circular(OmniRadii.pill),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_rounded,
            size: 12,
            color: OmniColors.deepTealActive,
          ),
          SizedBox(width: 3),
          Text(
            'Selected',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: OmniColors.deepTealActive,
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({required this.location, this.distance});

  final String location;
  final String? distance;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(
          Icons.location_on_outlined,
          size: 14,
          color: OmniColors.infoBlue,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            location,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 13,
              height: 1.3,
              color: OmniColors.textSecondary,
            ),
          ),
        ),
        if (distance != null) ...[
          const SizedBox(width: 6),
          Text(
            distance!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 13,
              height: 1.3,
              color: OmniColors.textTertiary,
            ),
          ),
        ],
      ],
    );
  }
}

class _AvailabilityRow extends StatelessWidget {
  const _AvailabilityRow({required this.accepting});

  final bool accepting;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          accepting ? Icons.check_circle_rounded : Icons.warning_rounded,
          size: 14,
          color: accepting ? OmniColors.freshMint : OmniColors.warning,
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            accepting ? 'Accepting requests' : 'Not accepting requests',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: 13,
              height: 1.3,
              fontWeight: FontWeight.w600,
              color: accepting ? OmniColors.deepTeal : OmniColors.warning,
            ),
          ),
        ),
      ],
    );
  }
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
