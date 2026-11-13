import 'package:flutter/material.dart';

import '../../../core/theme/omni_theme.dart';
import '../../../core/widgets/omni_pressable.dart';
import '../../../l10n/omni_localizations.dart';

/// Bundled family (pubspec, weights 500–800). The theme's google_fonts
/// text styles keep their 400 face when only the weight changes.
const String _bundledFont = 'Plus Jakarta Sans';

/// One label / value row of a [ProfileSummaryCard].
class ProfileSummaryRow {
  const ProfileSummaryRow({required this.label, required this.value});

  final String label;
  final String value;
}

/// Profile confirmation card (G3-ONB1): initials avatar (56 px), full name,
/// sub-label, « Modifier » ([onEdit]; hidden when null), then label / value
/// rows separated by borderLight lines. Pure UI: the screen formats every
/// value (dates, gender labels…).
class ProfileSummaryCard extends StatelessWidget {
  const ProfileSummaryCard({
    super.key,
    required this.fullName,
    required this.rows,
    this.subLabel,
    this.onEdit,
  });

  final String fullName;
  final String? subLabel;
  final List<ProfileSummaryRow> rows;
  final VoidCallback? onEdit;

  static const double _avatar = 56;

  /// Up to two initials from the name's words (« Amel Ben Ali » → « AB »).
  static String _initials(String name) {
    final words = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) return '';
    final first = words.first.characters.first;
    final second = words.length > 1 ? words[1].characters.first : '';
    return (first + second).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = OmniLocalizations.of(context);
    final edit = onEdit;
    return Container(
      padding: const EdgeInsets.all(OmniSpacing.base),
      decoration: BoxDecoration(
        color: OmniColors.surfacePrimary,
        borderRadius: BorderRadius.circular(OmniRadii.card),
        border: Border.all(color: OmniColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ExcludeSemantics(
                child: Container(
                  width: _avatar,
                  height: _avatar,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: OmniColors.mintSoft,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    _initials(fullName),
                    maxLines: 1,
                    style: const TextStyle(
                      fontFamily: _bundledFont,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: OmniColors.deepTeal,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: OmniSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName,
                      style: const TextStyle(
                        fontFamily: _bundledFont,
                        fontSize: 18,
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                        color: OmniColors.textPrimary,
                      ),
                    ),
                    if (subLabel != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subLabel!,
                        style: const TextStyle(
                          fontFamily: _bundledFont,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: OmniColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (edit != null) ...[
                const SizedBox(width: OmniSpacing.sm),
                OmniPressable(
                  borderRadius: OmniRadii.field,
                  builder: (context, states) => Semantics(
                    label: l10n.commonEditItem(fullName),
                    button: true,
                    excludeSemantics: true,
                    child: TextButton(
                      statesController: states,
                      onPressed: edit,
                      style: ButtonStyle(
                        minimumSize: const WidgetStatePropertyAll(Size(44, 44)),
                        foregroundColor: const WidgetStatePropertyAll(
                          OmniColors.deepTeal,
                        ),
                        overlayColor: OmniPressable.overlay(
                          OmniColors.deepTeal,
                        ),
                      ),
                      child: Text(
                        l10n.commonEdit,
                        style: const TextStyle(
                          fontFamily: _bundledFont,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          for (final row in rows) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: OmniSpacing.md),
              child: Divider(height: 1, color: OmniColors.borderLight),
            ),
            MergeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.label,
                    style: const TextStyle(
                      fontFamily: _bundledFont,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: OmniColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    row.value,
                    style: const TextStyle(
                      fontFamily: _bundledFont,
                      fontSize: 15,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                      color: OmniColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
