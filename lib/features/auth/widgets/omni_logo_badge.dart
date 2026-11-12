import 'package:flutter/material.dart';

import '../../../core/theme/omni_theme.dart';

/// OmniCare symbol (no wordmark) in a white circle.
///
/// Uses `assets/images/app_logo.png`, the symbol-only launcher-icon source
/// (pubspec `flutter_launcher_icons.image_path`). That 1024 px canvas has a
/// wide white margin (the symbol spans ~51 % of it), so the image is zoomed
/// to make the symbol fill the inner box; the circle clips the margin.
class OmniLogoBadge extends StatelessWidget {
  const OmniLogoBadge({
    super.key,
    required this.size,
    required this.semanticLabel,
    this.padding = 6,
    this.shadow,
  });

  final double size;
  final String semanticLabel;

  /// White ring between the circle edge and the symbol.
  final double padding;
  final BoxShadow? shadow;

  static const String _asset = 'assets/images/app_logo.png';
  static const double _symbolZoom = 1.95;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: OmniColors.surfacePrimary,
        shape: BoxShape.circle,
        boxShadow: shadow == null ? null : [shadow!],
      ),
      child: ClipOval(
        child: Transform.scale(
          scale: _symbolZoom,
          child: Image.asset(
            _asset,
            fit: BoxFit.contain,
            semanticLabel: semanticLabel,
            errorBuilder: (_, _, _) => Icon(
              Icons.local_hospital_outlined,
              size: (size - 2 * padding) / _symbolZoom,
              color: OmniColors.deepTeal,
              semanticLabel: semanticLabel,
            ),
          ),
        ),
      ),
    );
  }
}
