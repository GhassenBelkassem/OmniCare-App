import 'package:flutter/material.dart';

import '../../../core/theme/omni_theme.dart';
import '../../../core/widgets/omni_pressable.dart';
import '../../../l10n/omni_localizations.dart';

/// Bundled family (pubspec, weights 500–800). The theme's google_fonts
/// text styles keep their 400 face when only the weight changes.
const String _bundledFont = 'Plus Jakarta Sans';

/// One row of an [OnboardingSummaryList]. [onEdit] null hides « Modifier ».
class OnboardingSummaryItem {
  const OnboardingSummaryItem({
    required this.label,
    required this.value,
    this.onEdit,
  });

  final String label;
  final String value;
  final VoidCallback? onEdit;
}

/// Final-screen card (G3-ONB1): label / value rows separated by borderLight
/// lines, each with an optional « Modifier » (announced as « Modifier :
/// label »). Pure UI: the screen formats every value.
class OnboardingSummaryList extends StatelessWidget {
  const OnboardingSummaryList({super.key, required this.items});

  final List<OnboardingSummaryItem> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: OmniSpacing.base,
        vertical: OmniSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: OmniColors.surfacePrimary,
        borderRadius: BorderRadius.circular(OmniRadii.card),
        border: Border.all(color: OmniColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: OmniColors.borderLight),
            _SummaryRow(item: items[i]),
          ],
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.item});

  final OnboardingSummaryItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = OmniLocalizations.of(context);
    final edit = item.onEdit;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: OmniSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: MergeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    style: const TextStyle(
                      fontFamily: _bundledFont,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: OmniColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.value,
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
          ),
          if (edit != null) ...[
            const SizedBox(width: OmniSpacing.sm),
            OmniPressable(
              borderRadius: OmniRadii.field,
              builder: (context, states) => Semantics(
                label: l10n.commonEditItem(item.label),
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
                    overlayColor: OmniPressable.overlay(OmniColors.deepTeal),
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
    );
  }
}
