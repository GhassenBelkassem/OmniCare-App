import 'package:flutter/material.dart';

import '../../../../core/theme/omni_theme.dart';

const _selectedConditionMint = Color(0xFF8BE0B5);

class ChronicConditionsEditor extends StatelessWidget {
  final List<String> conditions;
  final Set<String> selectedConditions;
  final TextEditingController customConditionController;
  final ValueChanged<String> onToggle;
  final ValueChanged<String> onCustomChanged;
  final VoidCallback? onAddCustom;

  const ChronicConditionsEditor({
    super.key,
    required this.conditions,
    required this.selectedConditions,
    required this.customConditionController,
    required this.onToggle,
    required this.onCustomChanged,
    required this.onAddCustom,
  });

  @override
  Widget build(BuildContext context) {
    const referenceRows = [
      ['Diabète Type 2', 'Diabète Type 1'],
      ['Hypertension', 'Asthme'],
      ['Allergie Pénicilline', 'Maladie Cardiaque'],
      ['Cholestérol Élevé', 'Arthrite', 'Migraine'],
      ['Thyroïde'],
    ];
    final referenceConditions = referenceRows.expand((row) => row).toSet();
    final customConditions = conditions
        .where((condition) => !referenceConditions.contains(condition))
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Conditions Chroniques',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: OmniColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Sélectionnez toutes les conditions applicables',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: OmniColors.textSecondary),
        ),
        const SizedBox(height: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < referenceRows.length; index++) ...[
              _ConditionLine(
                labels: referenceRows[index]
                    .where(conditions.contains)
                    .toList(growable: false),
                spacing: switch (index) {
                  0 => 18,
                  1 => 20,
                  2 => 14,
                  _ => 8,
                },
                selectedConditions: selectedConditions,
                onToggle: onToggle,
              ),
              if (index < referenceRows.length - 1) const SizedBox(height: 3),
            ],
            if (customConditions.isNotEmpty) ...[
              const SizedBox(height: 3),
              Wrap(
                spacing: 8,
                runSpacing: 3,
                children: customConditions
                    .map(
                      (condition) => _ConditionChip(
                        label: condition,
                        selected: selectedConditions.contains(condition),
                        onTap: () => onToggle(condition),
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: customConditionController,
                onChanged: onCustomChanged,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => onAddCustom?.call(),
                decoration: InputDecoration(
                  hintText: 'Autre condition...',
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
  final List<String> labels;
  final double spacing;
  final Set<String> selectedConditions;
  final ValueChanged<String> onToggle;

  const _ConditionLine({
    required this.labels,
    required this.spacing,
    required this.selectedConditions,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: spacing,
      runSpacing: 3,
      children: labels
          .map(
            (label) => _ConditionChip(
              label: label,
              selected: selectedConditions.contains(label),
              onTap: () => onToggle(label),
            ),
          )
          .toList(growable: false),
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
