import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../../../../core/theme/omni_theme.dart';
import '../../data/patient_clinic_models.dart';

/// Swipeable clinic gallery with an optional page indicator.
///
/// Shows the images the backend returns, in order, with a graceful branded
/// placeholder when an image is missing or fails to load. No fake gallery
/// items: when [images] is empty the widget renders only the placeholder.
///
/// [onPageChanged] reports the current page so callers can render a "N / M"
/// counter; [showIndicator] toggles the dot indicator below the carousel;
/// [topRadius] controls the top corner rounding (the hero variant is flush
/// to the top of the screen).
class ClinicGallery extends StatefulWidget {
  const ClinicGallery({
    super.key,
    required this.images,
    this.height = 240,
    this.showIndicator = true,
    this.onPageChanged,
    this.topRadius = OmniRadii.card,
  });

  final List<PatientClinicImage> images;
  final double height;
  final bool showIndicator;
  final ValueChanged<int>? onPageChanged;
  final double topRadius;

  @override
  State<ClinicGallery> createState() => _ClinicGalleryState();
}

class _ClinicGalleryState extends State<ClinicGallery> {
  PageController? _pageController;

  @override
  void initState() {
    super.initState();
    if (widget.images.length > 1) {
      _pageController = PageController();
    }
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Neutral structural fallback: a missing image is not an availability or
    // success moment, so the placeholder is slate, never mint.
    final placeholder = Container(
      height: widget.height,
      color: OmniColors.slateSoft,
      child: const Center(
        child: Icon(
          Icons.medical_services_outlined,
          size: 42,
          color: OmniColors.slateBlue,
        ),
      ),
    );

    if (widget.images.isEmpty) {
      return widget.topRadius == 0
          ? placeholder
          : ClipRRect(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(widget.topRadius),
              ),
              child: placeholder,
            );
    }

    final pages = widget.images
        .map(
          (image) => CachedNetworkImage(
            imageUrl: image.imageUrl,
            height: widget.height,
            width: double.infinity,
            fit: BoxFit.cover,
            fadeInDuration: const Duration(milliseconds: 150),
            placeholder: (context, url) => placeholder,
            errorWidget: (context, url, error) => placeholder,
            // Never log the image URL; it is personal-adjacent data.
          ),
        )
        .toList(growable: false);

    final carousel = SizedBox(
      height: widget.height,
      child: PageView(
        controller: _pageController,
        onPageChanged: widget.onPageChanged,
        children: pages,
      ),
    );

    if (!widget.showIndicator || _pageController == null) {
      return widget.topRadius == 0
          ? carousel
          : ClipRRect(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(widget.topRadius),
              ),
              child: carousel,
            );
    }

    return ClipRRect(
      borderRadius: BorderRadius.vertical(top: Radius.circular(widget.topRadius)),
      child: Column(
        children: [
          carousel,
          Container(
            width: double.infinity,
            color: widget.topRadius == 0
                ? OmniColors.surfacePrimary
                : Colors.transparent,
            padding: const EdgeInsets.only(top: OmniSpacing.md),
            child: SmoothPageIndicator(
              controller: _pageController!,
              count: pages.length,
              effect: const ExpandingDotsEffect(
                dotHeight: 6,
                dotWidth: 6,
                expansionFactor: 3,
                spacing: 4,
                activeDotColor: OmniColors.freshMint,
                dotColor: OmniColors.borderStrong,
              ),
            ),
          ),
        ],
      ),
    );
  }
}