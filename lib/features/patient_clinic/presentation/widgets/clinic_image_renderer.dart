import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/omni_theme.dart';
import '../clinic_presentation_metadata.dart';

/// Central image renderer for clinic images.
///
/// Handles both asset and network sources with a consistent slate placeholder
/// fallback. Use this for hero, thumbnails, full-screen viewer, and any other
/// clinic image display.
class ClinicImageRenderer extends StatelessWidget {
  const ClinicImageRenderer({
    super.key,
    required this.image,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  final ClinicPresentationImage image;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  /// Convenience: render a network URL directly.
  factory ClinicImageRenderer.networkUrl(
    String url, {
    Key? key,
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
    BorderRadius? borderRadius,
  }) {
    return ClinicImageRenderer(
      key: key,
      image: ClinicPresentationImage.network(url),
      width: width,
      height: height,
      fit: fit,
      borderRadius: borderRadius,
    );
  }

  @override
  Widget build(BuildContext context) {
    final child = image.isAsset
        ? _buildAsset(image.value)
        : _buildNetwork(image.value);

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: child);
    }
    return child;
  }

  Widget _buildAsset(String path) {
    return Image.asset(
      path,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (_, _, _) => _placeholder(),
    );
  }

  Widget _buildNetwork(String url) {
    return CachedNetworkImage(
      imageUrl: url,
      width: width,
      height: height,
      fit: fit,
      fadeInDuration: const Duration(milliseconds: 150),
      placeholder: (_, _) => _placeholder(),
      errorWidget: (_, _, _) => _placeholder(),
    );
  }

  static Widget _placeholder() => Container(
    width: 80,
    height: 80,
    color: OmniColors.slateSoft,
    child: const Icon(
      Icons.medical_services_outlined,
      size: 24,
      color: OmniColors.slateBlue,
    ),
  );

  /// Full-size placeholder for hero/gallery use.
  static Widget heroPlaceholder() => Container(
    color: OmniColors.slateSoft,
    child: const Center(
      child: Icon(
        Icons.medical_services_outlined,
        size: 42,
        color: OmniColors.slateBlue,
      ),
    ),
  );

  /// Error placeholder for broken network images.
  static Widget errorPlaceholder() => Container(
    color: OmniColors.slateSoft,
    child: const Center(
      child: Icon(
        Icons.broken_image_outlined,
        size: 42,
        color: OmniColors.slateBlue,
      ),
    ),
  );
}
