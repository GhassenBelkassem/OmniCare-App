import 'package:flutter/material.dart';

import '../../../../core/theme/omni_theme.dart';
import '../../models/patient_passport_view_models.dart';

class PassportSegmentedNav extends StatelessWidget {
  final PassportSection selectedSection;
  final ValueChanged<PassportSection> onChanged;

  const PassportSegmentedNav({
    super.key,
    required this.selectedSection,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: OmniColors.slateSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth = constraints.maxWidth / 3;
          return SizedBox(
            height: 48,
            child: Stack(
              children: [
                AnimatedAlign(
                  alignment: _alignmentFor(selectedSection),
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  child: Container(
                    width: tabWidth,
                    height: 48,
                    decoration: BoxDecoration(
                      color: OmniColors.surfacePrimary,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [OmniColors.shadowSm],
                    ),
                  ),
                ),
                Row(
                  children: [
                    _Segment(
                      label: 'Résumé',
                      icon: Icons.dashboard_outlined,
                      isSelected: selectedSection == PassportSection.summary,
                      onTap: () => onChanged(PassportSection.summary),
                    ),
                    _Segment(
                      label: 'Historique',
                      icon: Icons.history_rounded,
                      isSelected: selectedSection == PassportSection.history,
                      onTap: () => onChanged(PassportSection.history),
                    ),
                    _Segment(
                      label: 'Documents',
                      icon: Icons.description_outlined,
                      isSelected: selectedSection == PassportSection.documents,
                      onTap: () => onChanged(PassportSection.documents),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Alignment _alignmentFor(PassportSection section) {
    return switch (section) {
      PassportSection.summary => Alignment.centerLeft,
      PassportSection.history => Alignment.center,
      PassportSection.documents => Alignment.centerRight,
    };
  }
}

class _Segment extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _Segment({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        selected: isSelected,
        label: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: SizedBox(
            height: 48,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: isSelected
                      ? OmniColors.primaryAction
                      : OmniColors.slateBlue,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? OmniColors.primaryAction
                          : OmniColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
