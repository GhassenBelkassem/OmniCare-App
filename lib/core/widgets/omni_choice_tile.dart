import 'package:flutter/material.dart';

import '../theme/omni_theme.dart';
import 'omni_pressable.dart';

/// Bundled family (pubspec, weights 500–800). The theme's google_fonts
/// text styles keep their 400 face when only the weight changes.
const String _bundledFont = 'Plus Jakarta Sans';

/// Grid tile for a short choice such as a blood type (G3-ONB1): min height
/// 68, radius 14, label 20 w800; [OmniChoiceTile.wide] fills the row width
/// (e.g. « Je ne sais pas » under the grid).
///
/// Selected: same look as `OmniOptionRow` (deepTeal 1 px border + 1 px
/// ring, mintSoft fill) plus a small deepTeal check badge top-right. Pure
/// UI; announced as a radio button of a mutually exclusive group, so wrap
/// the grid in `Semantics(role: SemanticsRole.radioGroup)`.
class OmniChoiceTile extends StatelessWidget {
  const OmniChoiceTile({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  }) : wide = false;

  /// Full-width variant, same look.
  const OmniChoiceTile.wide({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  }) : wide = true;

  final String label;
  final bool selected;

  /// Null disables the tile.
  final VoidCallback? onTap;

  final bool wide;

  static const double _radius = 14;
  static const double _minHeight = 68;
  static const double _badge = 18;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(_radius);
    final tile = Semantics(
      inMutuallyExclusiveGroup: true,
      checked: selected,
      enabled: onTap != null,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: OmniPressable(
        borderRadius: _radius,
        builder: (context, states) => AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          constraints: const BoxConstraints(minHeight: _minHeight),
          decoration: BoxDecoration(
            color: selected ? OmniColors.mintSoft : OmniColors.surfacePrimary,
            borderRadius: borderRadius,
            border: Border.all(
              color: selected ? OmniColors.deepTeal : OmniColors.borderLight,
            ),
            boxShadow: selected
                ? const [
                    BoxShadow(color: OmniColors.deepTeal, spreadRadius: 1),
                  ]
                : null,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              statesController: states,
              onTap: onTap,
              borderRadius: borderRadius,
              overlayColor: OmniPressable.overlay(OmniColors.deepTeal),
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: OmniSpacing.sm,
                      vertical: OmniSpacing.md,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        minHeight: _minHeight - 2 * OmniSpacing.md - 2,
                      ),
                      child: Center(
                        child: Text(
                          label,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: _bundledFont,
                            fontSize: 20,
                            height: 1.2,
                            fontWeight: FontWeight.w800,
                            color: OmniColors.textPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: AnimatedScale(
                      scale: selected ? 1 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: const DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: OmniColors.deepTeal,
                        ),
                        child: SizedBox.square(
                          dimension: _badge,
                          child: Icon(
                            Icons.check_rounded,
                            size: 12,
                            color: OmniColors.textOnDark,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return wide ? SizedBox(width: double.infinity, child: tile) : tile;
  }
}
