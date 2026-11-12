import 'package:flutter/material.dart';

import '../../../core/theme/omni_theme.dart';
import '../../../l10n/omni_localizations.dart';

/// Bundled family (pubspec, weights 500–800). The theme's google_fonts
/// text styles keep their 400 face when only the weight changes.
const String _bundledFont = 'Plus Jakarta Sans';

/// Visual state of one password rule, decided by the screen.
enum PasswordRuleState { idle, met, failed }

/// Pill that shows one password rule (e.g. « 12 caractères minimum »).
///
/// Pure UI: the screen evaluates the rule and passes [state]. Screen readers
/// hear « label, respecté » or « label, non respecté » (idle = not met yet).
class PasswordRuleChip extends StatelessWidget {
  const PasswordRuleChip({super.key, required this.label, required this.state});

  final String label;
  final PasswordRuleState state;

  @override
  Widget build(BuildContext context) {
    final l10n = OmniLocalizations.of(context);
    final (background, foreground, icon) = switch (state) {
      PasswordRuleState.idle => (
        OmniColors.slateSoft,
        OmniColors.textSecondary,
        Icons.radio_button_unchecked_rounded,
      ),
      PasswordRuleState.met => (
        OmniColors.mintSoft,
        OmniColors.deepTeal,
        Icons.check_circle_rounded,
      ),
      PasswordRuleState.failed => (
        OmniColors.errorSoft,
        OmniColors.error,
        Icons.cancel_rounded,
      ),
    };
    final stateLabel = state == PasswordRuleState.met
        ? l10n.passwordRuleMet
        : l10n.passwordRuleNotMet;

    return Semantics(
      container: true,
      label: '$label, $stateLabel',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
          horizontal: OmniSpacing.md,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(OmniRadii.pill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: foreground),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: _bundledFont,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: foreground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
