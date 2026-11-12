import 'package:flutter/material.dart';

import '../../../core/theme/omni_theme.dart';
import '../../../l10n/omni_localizations.dart';

/// Bundled family (pubspec, weights 500–800). The theme's google_fonts
/// text styles keep their 400 face when only the weight changes.
const String _bundledFont = 'Plus Jakarta Sans';

/// « Faire confiance à cet appareil » row with a switch on the right.
///
/// Pure UI: the screen owns [value]; [onChanged] null disables the row
/// (e.g. while a login is submitting). The whole row is tappable and is
/// announced as one toggle (title, subtitle, on/off).
class TrustedDeviceSwitch extends StatelessWidget {
  const TrustedDeviceSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = OmniLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final borderRadius = BorderRadius.circular(OmniRadii.field);
    final change = onChanged;

    return MergeSemantics(
      child: Material(
        color: OmniColors.slateSoft,
        borderRadius: borderRadius,
        child: InkWell(
          borderRadius: borderRadius,
          onTap: change == null ? null : () => change(!value),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: OmniSpacing.md,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.authTrustDeviceTitle,
                        style: textTheme.bodyMedium?.copyWith(
                          fontFamily: _bundledFont,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: OmniColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.authTrustDeviceSubtitle,
                        style: textTheme.bodySmall?.copyWith(
                          fontFamily: _bundledFont,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: OmniColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: OmniSpacing.md),
                Switch(value: value, onChanged: change),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
