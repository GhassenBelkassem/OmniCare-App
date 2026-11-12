import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/omni_theme.dart';
import 'omni_pressable.dart';

/// Bundled family (pubspec, weights 500–800). The theme's google_fonts
/// text styles keep their 400 face when only the weight changes.
const String _bundledFont = 'Plus Jakarta Sans';

/// Full-width choice row (G3-ONB1): min height 64, radius 14, leading 36 px
/// icon tile, label 16 w600, trailing 22 px radio.
///
/// Selected: deepTeal 1 px border + 1 px ring, mintSoft fill, white icon
/// tile. Pure UI; announced as a radio button of a mutually exclusive group
/// (use it inside [OmniOptionGroup]).
class OmniOptionRow extends StatelessWidget {
  const OmniOptionRow({
    super.key,
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;

  /// Null disables the row.
  final VoidCallback? onTap;

  static const double _radius = 14;
  static const double _minHeight = 64;
  static const double _iconTile = 36;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(_radius);
    return Semantics(
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
            // 1 px ring outside the border when selected.
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
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: OmniSpacing.md,
                  vertical: OmniSpacing.md,
                ),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: _iconTile,
                      height: _iconTile,
                      decoration: BoxDecoration(
                        color: selected
                            ? OmniColors.surfacePrimary
                            : OmniColors.slateSoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, size: 20, color: OmniColors.deepTeal),
                    ),
                    const SizedBox(width: OmniSpacing.md),
                    Expanded(
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontFamily: _bundledFont,
                          fontSize: 16,
                          height: 1.3,
                          fontWeight: FontWeight.w600,
                          color: OmniColors.textPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(width: OmniSpacing.md),
                    _Radio(selected: selected),
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

/// 22 px radio: borderStrong ring, or deepTeal ring + 10 px dot.
class _Radio extends StatelessWidget {
  const _Radio({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: OmniColors.surfacePrimary,
        border: Border.all(
          color: selected ? OmniColors.deepTeal : OmniColors.borderStrong,
          width: 2,
        ),
      ),
      child: AnimatedScale(
        scale: selected ? 1 : 0,
        duration: const Duration(milliseconds: 180),
        child: const DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: OmniColors.deepTeal,
          ),
          child: SizedBox.square(dimension: 10),
        ),
      ),
    );
  }
}

/// One option of an [OmniOptionGroup].
class OmniOption<T> {
  const OmniOption({
    required this.value,
    required this.label,
    required this.icon,
  });

  final T value;
  final String label;
  final IconData icon;
}

/// Vertical list of [OmniOptionRow]s with radio-group semantics. The screen
/// owns [value] (null = nothing chosen) and reacts in [onChanged]; a
/// selection click haptic plays when the value changes.
class OmniOptionGroup<T> extends StatelessWidget {
  const OmniOptionGroup({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.semanticLabel,
  });

  final List<OmniOption<T>> options;
  final T? value;

  /// Null disables every row.
  final ValueChanged<T>? onChanged;

  /// Name of the group for screen readers.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final changed = onChanged;
    return Semantics(
      role: SemanticsRole.radioGroup,
      label: semanticLabel,
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) const SizedBox(height: OmniSpacing.md),
            OmniOptionRow(
              label: options[i].label,
              icon: options[i].icon,
              selected: options[i].value == value,
              onTap: changed == null
                  ? null
                  : () {
                      final next = options[i].value;
                      if (next == value) return;
                      HapticFeedback.selectionClick();
                      changed(next);
                    },
            ),
          ],
        ],
      ),
    );
  }
}
