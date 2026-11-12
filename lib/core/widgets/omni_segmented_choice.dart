import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';

import '../theme/omni_theme.dart';

/// Bundled family (pubspec, weights 500–800). The theme's google_fonts
/// text styles keep their 400 face when only the weight changes.
const String _bundledFont = 'Plus Jakarta Sans';

/// One option of an [OmniSegmentedChoice].
class OmniChoiceOption<T> {
  const OmniChoiceOption({required this.value, required this.label});

  final T value;
  final String label;
}

/// Segmented control for 2–3 mutually exclusive options (e.g. gender).
///
/// Pure UI: the screen owns [value] and reacts in [onChanged]. Announced to
/// screen readers as a radio group (`SemanticsRole.radioGroup`, each option
/// checked/unchecked in a mutually exclusive group).
class OmniSegmentedChoice<T> extends StatelessWidget {
  const OmniSegmentedChoice({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.errorText,
    this.semanticLabel,
  }) : assert(
         options.length >= 2 && options.length <= 3,
         'OmniSegmentedChoice supports 2 or 3 options',
       );

  final List<OmniChoiceOption<T>> options;

  /// Selected value, or null when nothing is chosen yet.
  final T? value;

  /// Null disables the control.
  final ValueChanged<T>? onChanged;

  /// Message below the control; also draws the error border.
  final String? errorText;

  /// Name of the group for screen readers (e.g. « Genre »).
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          role: SemanticsRole.radioGroup,
          label: semanticLabel,
          container: true,
          child: Container(
            padding: const EdgeInsets.all(OmniSpacing.xs),
            decoration: BoxDecoration(
              color: OmniColors.slateSoft,
              borderRadius: BorderRadius.circular(OmniRadii.field),
              border: hasError
                  ? Border.all(color: OmniColors.error, width: 1.75)
                  : null,
            ),
            child: Row(
              children: [
                for (final option in options)
                  Expanded(
                    child: _Segment(
                      label: option.label,
                      selected: option.value == value,
                      onTap: onChanged == null
                          ? null
                          : () => onChanged!(option.value),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          Text(
            errorText!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontFamily: _bundledFont,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: OmniColors.error,
            ),
          ),
        ],
      ],
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  static const double _radius = 10;

  final String label;
  final bool selected;
  final VoidCallback? onTap;

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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        constraints: const BoxConstraints(minHeight: 44),
        decoration: BoxDecoration(
          color: selected ? OmniColors.surfacePrimary : Colors.transparent,
          borderRadius: borderRadius,
          boxShadow: selected ? const [OmniColors.shadowSm] : null,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: onTap,
            borderRadius: borderRadius,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: OmniSpacing.sm,
                vertical: OmniSpacing.sm,
              ),
              child: Center(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontFamily: _bundledFont,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? OmniColors.textPrimary
                        : OmniColors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
