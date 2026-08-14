import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../data/patient_clinic_models.dart';

/// A clinic row in the patient directory.
///
/// Healthcare selection, not a commercial marketplace: name, location,
/// availability and an image. No ratings, prices, reviews or recommendation
/// badges. When the clinic is not accepting requests it is shown as available
/// but disabled, with clear non-commercial wording.
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
    final accepting = clinic.acceptingRequests;

    return Semantics(
      selected: selected,
      button: true,
      enabled: true,
      label:
          '${clinic.displayName}${accepting ? '' : ', not accepting requests'}',
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? theme.colorScheme.primary
                : Colors.grey.withOpacity(0.18),
            width: selected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            // An unavailable clinic remains readable; selection is prevented
            // by the detail screen's disabled CTA.
            onTap: onTap,
            child: Opacity(
              opacity: accepting ? 1 : 0.6,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    _ClinicThumbnail(imageUrl: clinic.primaryImageUrl),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            clinic.displayName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF1D2939),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          if (clinic.city != null || clinic.governorate != null)
                            Row(
                              children: [
                                const Icon(
                                  Icons.location_on_outlined,
                                  size: 16,
                                  color: Color(0xFF667085),
                                ),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    [clinic.city, clinic.governorate]
                                        .where(
                                          (part) =>
                                              part != null && part!.isNotEmpty,
                                        )
                                        .join(', '),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: const Color(0xFF667085),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 8),
                          _AvailabilityChip(
                            accepting: clinic.acceptingRequests,
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Color(0xFF98A2B3)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ClinicThumbnail extends StatelessWidget {
  const _ClinicThumbnail({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    const size = 64.0;
    final placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF1FBF9A).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Icon(
        Icons.local_hospital_outlined,
        color: Color(0xFF1FBF9A),
        size: 28,
      ),
    );

    if (imageUrl == null || imageUrl!.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: placeholder,
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: CachedNetworkImage(
        imageUrl: imageUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 150),
        placeholder: (context, url) => placeholder,
        errorWidget: (context, url, error) => placeholder,
        // Never log the image URL; it is personal-adjacent operational data.
      ),
    );
  }
}

class _AvailabilityChip extends StatelessWidget {
  const _AvailabilityChip({required this.accepting});

  final bool accepting;

  @override
  Widget build(BuildContext context) {
    final color = accepting ? const Color(0xFF1FBF9A) : const Color(0xFFD0A21A);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          accepting ? 'Accepting requests' : 'Not accepting requests',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF475467),
          ),
        ),
      ],
    );
  }
}
