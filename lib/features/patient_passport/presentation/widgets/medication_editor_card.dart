import 'package:flutter/material.dart';

import '../../../../core/theme/omni_theme.dart';
import '../../models/patient_passport_view_models.dart';

class MedicationEditorDraft {
  final TextEditingController nameController;
  final TextEditingController dosageController;
  final TextEditingController durationController;
  String frequency;
  String durationUnit;

  MedicationEditorDraft({
    required String name,
    required String dosage,
    required this.frequency,
    String duration = '0',
    this.durationUnit = 'Jour(s)',
  }) : nameController = TextEditingController(text: name),
       dosageController = TextEditingController(text: dosage),
       durationController = TextEditingController(text: duration);

  factory MedicationEditorDraft.fromMedication(PassportMedication medication) {
    final frequency = switch (medication.frequency) {
      final value when value.contains('3×') => '3×/jour',
      final value when value.contains('2×') => '2×/jour',
      _ => '1×/jour',
    };
    return MedicationEditorDraft(
      name: medication.name,
      dosage: medication.dosage,
      frequency: frequency,
    );
  }

  factory MedicationEditorDraft.empty() {
    return MedicationEditorDraft(name: '', dosage: '', frequency: '1×/jour');
  }

  PassportMedication toMedication() {
    return PassportMedication(
      name: nameController.text.trim(),
      dosage: dosageController.text.trim(),
      frequency: frequency.replaceFirst('×/jour', '× par jour'),
      isCurrent: true,
    );
  }

  void dispose() {
    nameController.dispose();
    dosageController.dispose();
    durationController.dispose();
  }
}

class MedicationEditorCard extends StatelessWidget {
  static const frequencies = ['1×/jour', '2×/jour', '3×/jour'];
  static const durationUnits = ['Jour(s)', 'Semaine(s)', 'Mois'];

  final MedicationEditorDraft draft;
  final ValueChanged<String> onFrequencyChanged;
  final ValueChanged<String> onDurationUnitChanged;
  final VoidCallback onDelete;

  const MedicationEditorCard({
    super.key,
    required this.draft,
    required this.onFrequencyChanged,
    required this.onDurationUnitChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: OmniColors.surfacePrimary,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: OmniColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _FieldLabel('Nom du Médicament'),
          TextField(
            controller: draft.nameController,
            textCapitalization: TextCapitalization.sentences,
            decoration: _fieldDecoration(hintText: 'Nom du médicament'),
          ),
          const SizedBox(height: 14),
          const _FieldLabel('Dosage'),
          TextField(
            controller: draft.dosageController,
            decoration: _fieldDecoration(hintText: 'Ex: 500mg'),
          ),
          const SizedBox(height: 16),
          const _FieldLabel('Fréquence'),
          Row(
            children: frequencies
                .map(
                  (frequency) => Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                        right: frequency == frequencies.last ? 0 : 7,
                      ),
                      child: _FrequencyChoice(
                        label: frequency,
                        selected: draft.frequency == frequency,
                        onTap: () => onFrequencyChanged(frequency),
                      ),
                    ),
                  ),
                )
                .toList(growable: false),
          ),
          const SizedBox(height: 16),
          const _FieldLabel('Durée'),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: draft.durationController,
                  keyboardType: TextInputType.number,
                  decoration: _fieldDecoration(hintText: '0'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 13),
                  decoration: BoxDecoration(
                    color: OmniColors.surfacePrimary,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: OmniColors.borderLight),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: draft.durationUnit,
                      isExpanded: true,
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: OmniColors.textSecondary,
                      ),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: OmniColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      items: durationUnits
                          .map(
                            (unit) => DropdownMenuItem<String>(
                              value: unit,
                              child: Text(unit),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value != null) onDurationUnitChanged(value);
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline_rounded, size: 20),
            label: const Text('Supprimer ce médicament'),
            style: TextButton.styleFrom(
              foregroundColor: OmniColors.error,
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  static InputDecoration _fieldDecoration({required String hintText}) {
    return InputDecoration(
      hintText: hintText,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: OmniColors.borderLight),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: OmniColors.borderFocus, width: 1.5),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;

  const _FieldLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: OmniColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _FrequencyChoice extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FrequencyChoice({
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
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(OmniRadii.pill),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? OmniColors.mintSoft : Colors.white,
            borderRadius: BorderRadius.circular(OmniRadii.pill),
            border: Border.all(
              color: selected ? OmniColors.freshMint : OmniColors.borderStrong,
            ),
          ),
          child: Text(
            label,
            maxLines: 1,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: selected
                  ? OmniColors.primaryAction
                  : OmniColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
