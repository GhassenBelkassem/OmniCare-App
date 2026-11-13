import 'package:flutter/material.dart';

import '../../../../core/theme/omni_theme.dart';

const _selectedConditionMint = Color(0xFF8BE0B5);

/// A chip list of the « Modifier les données » editor: presets, the
/// patient's own labels, and an « Autre… » field (G2.1-A2). Used for the
/// conditions and, with the same look, for the allergies (ADR-012 §8 D2).
///
/// Labels are matched without case ([keyOf]). A professional item is shown
/// with the read-only chip of the Résumé card and can't be toggled.
class MedicalChipsEditor extends StatelessWidget {
  final String title;
  final String subtitle;
  final String hintText;

  /// The preset chips, by row.
  final List<List<String>> presetRows;

  /// The patient's labels that are not presets (selected or not), in order.
  final List<String> customLabels;

  /// Professional labels that are not presets.
  final List<String> readOnlyLabels;
  final Set<String> selectedKeys;
  final Set<String> readOnlyKeys;
  final String Function(String label) keyOf;
  final TextEditingController customController;
  final ValueChanged<String> onToggle;
  final ValueChanged<String> onCustomChanged;
  final VoidCallback? onAddCustom;

  /// Shown under the « Autre… » field (a French field message).
  final String? errorText;

  const MedicalChipsEditor({
    super.key,
    required this.title,
    required this.subtitle,
    required this.hintText,
    required this.presetRows,
    required this.customLabels,
    required this.readOnlyLabels,
    required this.selectedKeys,
    required this.readOnlyKeys,
    required this.keyOf,
    required this.customController,
    required this.onToggle,
    required this.onCustomChanged,
    required this.onAddCustom,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    Widget chip(String label) => readOnlyKeys.contains(keyOf(label))
        ? _ReadOnlyChip(label: label)
        : _ConditionChip(
            label: label,
            selected: selectedKeys.contains(keyOf(label)),
            onTap: () => onToggle(label),
          );
    final extraLabels = [...readOnlyLabels, ...customLabels];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: OmniColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: OmniColors.textSecondary),
        ),
        const SizedBox(height: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < presetRows.length; index++) ...[
              _ConditionLine(
                spacing: switch (index) {
                  0 => 18,
                  1 => 20,
                  2 => 14,
                  _ => 8,
                },
                children: presetRows[index].map(chip).toList(growable: false),
              ),
              if (index < presetRows.length - 1) const SizedBox(height: 3),
            ],
            if (extraLabels.isNotEmpty) ...[
              const SizedBox(height: 3),
              Wrap(
                spacing: 8,
                runSpacing: 3,
                children: extraLabels.map(chip).toList(growable: false),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: customController,
                onChanged: onCustomChanged,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => onAddCustom?.call(),
                decoration: InputDecoration(
                  hintText: hintText,
                  errorText: errorText,
                  errorMaxLines: 3,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 15,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: OmniColors.borderLight),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: OmniColors.borderFocus,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            TextButton.icon(
              onPressed: onAddCustom,
              icon: const Icon(Icons.add_rounded, size: 19),
              label: const Text('Ajouter'),
              style: TextButton.styleFrom(
                minimumSize: const Size(108, 49),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                foregroundColor: OmniColors.primaryAction,
                disabledForegroundColor: OmniColors.textTertiary,
                backgroundColor: OmniColors.mintSoft,
                disabledBackgroundColor: OmniColors.surfaceSecondary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ConditionLine extends StatelessWidget {
  final double spacing;
  final List<Widget> children;

  const _ConditionLine({required this.spacing, required this.children});

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: spacing, runSpacing: 3, children: children);
  }
}

/// A professional item: the read-only chip of the Résumé card
/// (`PassportEssentialInfoCard`), not tappable.
class _ReadOnlyChip extends StatelessWidget {
  final String label;

  const _ReadOnlyChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      readOnly: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: OmniColors.slateSoft,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: OmniColors.borderLight),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: OmniColors.slateBlue,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _ConditionChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ConditionChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: selected ? _selectedConditionMint : Colors.transparent,
          borderRadius: BorderRadius.circular(OmniRadii.pill),
          boxShadow: selected ? const [OmniColors.shadowSm] : null,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(OmniRadii.pill),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: selected ? 16 : 8,
                vertical: 9,
              ),
              child: AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                style: Theme.of(context).textTheme.labelMedium!.copyWith(
                  color: selected ? Colors.white : OmniColors.textPrimary,
                  fontSize: 16,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                ),
                child: Text(label),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
