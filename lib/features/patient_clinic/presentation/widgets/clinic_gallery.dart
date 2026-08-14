import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../../data/patient_clinic_models.dart';

/// Swipeable clinic gallery with a page indicator.
///
/// Shows up to the images the backend returns, in order, with a graceful
/// placeholder when an image is missing or fails to load. No fake gallery
/// items: when [images] is empty the widget renders only the placeholder.
class ClinicGallery extends StatefulWidget {
  const ClinicGallery({super.key, required this.images, this.height = 240});

  final List<PatientClinicImage> images;
  final double height;

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
    final placeholder = Container(
      height: widget.height,
      color: const Color(0xFF1FBF9A).withOpacity(0.08),
      child: const Center(
        child: Icon(
          Icons.local_hospital_outlined,
          size: 64,
          color: Color(0xFF1FBF9A),
        ),
      ),
    );

    if (widget.images.isEmpty) {
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
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
          ),
        )
        .toList(growable: false);

    return Column(
      children: [
        SizedBox(
          height: widget.height,
          child: PageView(controller: _pageController, children: pages),
        ),
        if (_pageController != null) ...[
          const SizedBox(height: 12),
          SmoothPageIndicator(
            controller: _pageController!,
            count: pages.length,
            effect: const ExpandingDotsEffect(
              dotHeight: 6,
              dotWidth: 6,
              expansionFactor: 3,
              spacing: 4,
              activeDotColor: Color(0xFF1FBF9A),
              dotColor: Color(0xFFD0D5DD),
            ),
          ),
        ],
      ],
    );
  }
}
