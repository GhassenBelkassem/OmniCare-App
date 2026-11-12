import 'package:flutter/material.dart';

import '../../../core/theme/omni_theme.dart';

/// Decorative background circles of the dark auth screens (welcome,
/// splash); no semantics, no hit testing. Moved from login_screen.dart
/// unchanged, G3-P2c.
class AuthDecorativeCircles extends StatelessWidget {
  const AuthDecorativeCircles({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ExcludeSemantics(
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            _circle(top: -90, right: -110, size: 300, color: OmniColors.deepTeal),
            _circle(
              top: 220,
              left: -140,
              size: 240,
              color: OmniColors.deepTealHover,
            ),
            _circle(
              top: 120,
              right: -40,
              size: 120,
              color: OmniColors.freshMint.withValues(alpha: 0.16),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _circle({
    double? top,
    double? left,
    double? right,
    required double size,
    required Color color,
  }) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: color.a * 0.55),
        ),
      ),
    );
  }
}
