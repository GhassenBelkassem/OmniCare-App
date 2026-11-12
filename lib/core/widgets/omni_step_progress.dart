import 'package:flutter/material.dart';

import '../../l10n/omni_localizations.dart';
import '../theme/omni_theme.dart';

/// Bundled family (pubspec, weights 500–800). The theme's google_fonts
/// text styles keep their 400 face when only the weight changes.
const String _bundledFont = 'Plus Jakarta Sans';

/// Segmented step indicator with « Étape {current} sur {total} · {name} ».
///
/// Pure UI: the screen passes the 1-based [current] step, [total] and the
/// current step's [stepName]. Done and current segments are mint.
class OmniStepProgress extends StatelessWidget {
  const OmniStepProgress({
    super.key,
    required this.current,
    required this.total,
    required this.stepName,
  }) : assert(total > 0, 'total must be positive'),
       assert(current >= 1 && current <= total, 'current must be 1..total');

  final int current;
  final int total;
  final String stepName;

  static const double _height = 4;
  static const double _gap = 6;

  @override
  Widget build(BuildContext context) {
    final l10n = OmniLocalizations.of(context);
    final label = l10n.stepProgressLabel(current, total, stepName);

    return Semantics(
      container: true,
      label: label,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              for (var step = 1; step <= total; step++) ...[
                if (step > 1) const SizedBox(width: _gap),
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    height: _height,
                    decoration: BoxDecoration(
                      color: step <= current
                          ? OmniColors.freshMint
                          : OmniColors.borderLight,
                      borderRadius: BorderRadius.circular(_height / 2),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: OmniSpacing.sm),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontFamily: _bundledFont,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: OmniColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
