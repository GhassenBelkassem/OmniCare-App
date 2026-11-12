import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';

import '../../../core/theme/omni_theme.dart';

/// Bundled family (pubspec, weights 500–800). The theme's google_fonts
/// text styles keep their 400 face when only the weight changes.
const String _bundledFont = 'Plus Jakarta Sans';

/// Calm information box (G3-ONB1): mintSoft, radius 16, info icon, title
/// 15 w700 and body 14 w500 in deepTeal. Announced with the status role
/// (polite, not an alert). Pure UI.
class OnboardingNote extends StatelessWidget {
  const OnboardingNote({
    super.key,
    required this.title,
    required this.body,
    this.icon = Icons.info_outline_rounded,
  });

  final String title;
  final String body;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      role: SemanticsRole.status,
      container: true,
      child: Container(
        padding: const EdgeInsets.all(OmniSpacing.base),
        decoration: BoxDecoration(
          color: OmniColors.mintSoft,
          borderRadius: BorderRadius.circular(OmniRadii.card),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Icon(icon, size: 22, color: OmniColors.deepTeal),
            ),
            const SizedBox(width: OmniSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: _bundledFont,
                      fontSize: 15,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                      color: OmniColors.deepTeal,
                    ),
                  ),
                  const SizedBox(height: OmniSpacing.xs),
                  Text(
                    body,
                    style: const TextStyle(
                      fontFamily: _bundledFont,
                      fontSize: 14,
                      height: 1.45,
                      fontWeight: FontWeight.w500,
                      color: OmniColors.deepTeal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
