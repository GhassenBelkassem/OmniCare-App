import 'package:flutter/material.dart';

import '../../../../core/theme/omni_theme.dart';
import '../../data/patient_clinic_models.dart';
import '../clinic_presentation_metadata.dart';

/// Full-screen gallery viewer with horizontal swipe, indicator and close.
///
/// Supports both network images ([PatientClinicImage]) and local
/// [ClinicPresentationImage] assets.
/// The initial [initialIndex] selects which image to show first.
class ClinicFullScreenGallery extends StatefulWidget {
  const ClinicFullScreenGallery({
    super.key,
    required this.images,
    this.localAssets = const [],
    this.initialIndex = 0,
  });

  final List<PatientClinicImage> images;
  final List<ClinicPresentationImage> localAssets;
  final int initialIndex;

  @override
  State<ClinicFullScreenGallery> createState() =>
      _ClinicFullScreenGalleryState();
}

class _ClinicFullScreenGalleryState extends State<ClinicFullScreenGallery> {
  late final PageController _controller;
  late int _currentIndex;

  int get _total => widget.images.length + widget.localAssets.length;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // PageView gallery
          PageView.builder(
            controller: _controller,
            itemCount: _total,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemBuilder: (context, index) {
              if (index < widget.images.length) {
                return _NetworkImageTile(url: widget.images[index].imageUrl);
              }
              final assetIndex = index - widget.images.length;
              return _AssetImageTile(
                image: widget.localAssets[assetIndex],
              );
            },
          ),
          // Close button
          Positioned(
            top: MediaQuery.paddingOf(context).top + OmniSpacing.sm,
            left: OmniSpacing.base,
            child: _GalleryCloseButton(
              onClose: () => Navigator.of(context).pop(),
            ),
          ),
          // Indicator
          if (_total > 1)
            Positioned(
              bottom: MediaQuery.paddingOf(context).bottom + OmniSpacing.xl,
              left: 0,
              right: 0,
              child: Center(
                child: _GalleryIndicator(
                  current: _currentIndex,
                  total: _total,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _NetworkImageTile extends StatelessWidget {
  const _NetworkImageTile({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 4.0,
      child: Center(
        child: Image.network(
          url,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => const Center(
            child: Icon(
              Icons.broken_image_outlined,
              size: 48,
              color: Colors.white38,
            ),
          ),
        ),
      ),
    );
  }
}

class _AssetImageTile extends StatelessWidget {
  const _AssetImageTile({required this.image});

  final ClinicPresentationImage image;

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 4.0,
      child: Center(
        child: Image.asset(
          image.value,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => const Center(
            child: Icon(
              Icons.broken_image_outlined,
              size: 48,
              color: Colors.white38,
            ),
          ),
        ),
      ),
    );
  }
}

class _GalleryCloseButton extends StatelessWidget {
  const _GalleryCloseButton({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Close gallery',
      button: true,
      child: GestureDetector(
        onTap: onClose,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.close_rounded,
            size: 24,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

class _GalleryIndicator extends StatelessWidget {
  const _GalleryIndicator({required this.current, required this.total});

  final int current;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: OmniSpacing.md,
        vertical: OmniSpacing.xs + 2,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(OmniRadii.pill),
      ),
      child: Semantics(
        label: 'Image ${current + 1} of $total',
        child: Text(
          '${current + 1} / $total',
          style: const TextStyle(
            fontSize: 14,
            height: 1.2,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
