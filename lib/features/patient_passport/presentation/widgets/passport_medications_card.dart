import 'package:flutter/material.dart';

import '../../../../core/theme/omni_theme.dart';
import '../../models/patient_passport_view_models.dart';
import 'passport_card.dart';
import 'passport_card_status.dart';

class PassportMedicationsCard extends StatelessWidget {
  final MedicationGroup selectedGroup;
  final ValueChanged<MedicationGroup> onGroupChanged;
  final List<PassportMedication> medications;

  /// Shown in the body when [medications] is empty (G2-FT-3).
  final String? emptyText;

  /// True when the server has more than the first page: the count reads "20+".
  final bool hasMore;

  /// Loading or failure in place of the list (G2-FT-3).
  final PassportCardStatus? status;

  const PassportMedicationsCard({
    super.key,
    required this.selectedGroup,
    required this.onGroupChanged,
    required this.medications,
    this.emptyText,
    this.hasMore = false,
    this.status,
  });

  @override
  Widget build(BuildContext context) {
    final isCurrent = selectedGroup == MedicationGroup.current;
    final count = '${medications.length}${hasMore ? '+' : ''}';
    final emptyText = this.emptyText;
    return PassportCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PassportSectionHeading(
            icon: Icons.medication_outlined,
            title: 'Médicaments',
            subtitle: isCurrent
                ? '$count traitement(s) actif(s)'
                : '$count ancien(s) traitement(s)',
            iconColor: OmniColors.infoBlue,
            iconBackground: OmniColors.infoBlueSoft,
          ),
          const SizedBox(height: 18),
          _MedicationSegmentedControl(
            selectedGroup: selectedGroup,
            onChanged: onGroupChanged,
          ),
          const SizedBox(height: 8),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              reverseDuration: const Duration(milliseconds: 150),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              layoutBuilder: (currentChild, previousChildren) {
                return currentChild ?? const SizedBox.shrink();
              },
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                  child: child,
                );
              },
              child: Column(
                key: ValueKey<MedicationGroup>(selectedGroup),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (status case final status?)
                    PassportCardStatusBody(status: status)
                  else if (medications.isEmpty && emptyText != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        emptyText,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    )
                  else
                    ...medications.map(
                      (medication) => _MedicationRow(medication: medication),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MedicationSegmentedControl extends StatelessWidget {
  final MedicationGroup selectedGroup;
  final ValueChanged<MedicationGroup> onChanged;

  const _MedicationSegmentedControl({
    required this.selectedGroup,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: OmniColors.slateSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              AnimatedAlign(
                alignment: selectedGroup == MedicationGroup.current
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                child: Container(
                  width: constraints.maxWidth / 2,
                  height: constraints.maxHeight,
                  decoration: BoxDecoration(
                    color: OmniColors.surfacePrimary,
                    borderRadius: BorderRadius.circular(9),
                    boxShadow: const [OmniColors.shadowSm],
                  ),
                ),
              ),
              Row(
                children: [
                  _MedicationSegment(
                    label: 'Actuels',
                    selected: selectedGroup == MedicationGroup.current,
                    onTap: () => onChanged(MedicationGroup.current),
                  ),
                  _MedicationSegment(
                    label: 'Anciens',
                    selected: selectedGroup == MedicationGroup.previous,
                    onTap: () => onChanged(MedicationGroup.previous),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MedicationSegment extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _MedicationSegment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: onTap,
          child: SizedBox(
            height: double.infinity,
            child: Center(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: selected
                      ? OmniColors.primaryAction
                      : OmniColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MedicationRow extends StatelessWidget {
  final PassportMedication medication;

  const _MedicationRow({required this.medication});

  @override
  Widget build(BuildContext context) {
    final badgeColor = medication.isCurrent
        ? OmniColors.mintSoft
        : OmniColors.errorSoft;
    final badgeTextColor = medication.isCurrent
        ? OmniColors.deepTeal
        : OmniColors.error;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: OmniColors.borderLight)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: OmniColors.infoBlueSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.medication_rounded,
              color: OmniColors.infoBlue,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  medication.name,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 3),
                Text(
                  medication.instruction,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: OmniColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                medication.isCurrent
                    ? 'Actif'
                    : medication.stoppedLabel ?? 'Arrêté',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: badgeTextColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
