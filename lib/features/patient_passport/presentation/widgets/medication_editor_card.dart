import 'package:flutter/material.dart';

import '../../../../core/theme/omni_theme.dart';
import '../../application/medical_data_editor_draft.dart';
import '../../data/medical_record_models.dart';

/// One medication row of the editor: its text fields and choices. [key] is
/// the row's local identity; [itemId] is set for the patient's own declared
/// item (G2.1-A2). The start date has no field and is kept as read.
class MedicationEditorDraft {
  final int key;
  final String? itemId;
  final String? startedOn;
  final TextEditingController nameController;
  final TextEditingController dosageController;
  final TextEditingController durationController;

  /// 1, 2 or 3 from the chips; a stored value outside them stays until a
  /// chip is chosen; `null` when not given.
  int? timesPerDay;
  DurationUnit durationUnit;

  MedicationEditorDraft._({
    required this.key,
    required this.itemId,
    required this.startedOn,
    required String name,
    required String dosage,
    required String duration,
    required this.timesPerDay,
    required this.durationUnit,
  }) : nameController = TextEditingController(text: name),
       dosageController = TextEditingController(text: dosage),
       durationController = TextEditingController(text: duration);

  factory MedicationEditorDraft.fromInput(MedicationInput input) =>
      MedicationEditorDraft._(
        key: input.key,
        itemId: input.itemId,
        startedOn: input.startedOn,
        name: input.name,
        dosage: input.dosageText,
        duration: input.durationText,
        timesPerDay: input.timesPerDay,
        durationUnit: input.durationUnit,
      );

  factory MedicationEditorDraft.empty(int key) => MedicationEditorDraft._(
    key: key,
    itemId: null,
    startedOn: null,
    name: '',
    dosage: '',
    duration: '',
    timesPerDay: null,
    durationUnit: DurationUnit.day,
  );

  MedicationInput toInput() => MedicationInput(
    key: key,
    itemId: itemId,
    name: nameController.text,
    dosageText: dosageController.text,
    timesPerDay: timesPerDay,
    durationText: durationController.text,
    durationUnit: durationUnit,
    startedOn: startedOn,
  );

  void dispose() {
    nameController.dispose();
    dosageController.dispose();
    durationController.dispose();
  }

  @override
  String toString() => 'MedicationEditorDraft(key: $key)';
}

class MedicationEditorCard extends StatelessWidget {
  static const frequencies = ['1×/jour', '2×/jour', '3×/jour'];
  static const durationUnits = {
    DurationUnit.day: 'Jour(s)',
    DurationUnit.week: 'Semaine(s)',
    DurationUnit.month: 'Mois',
  };

  final MedicationEditorDraft draft;

  /// « Déclaré par le patient » (ADR-012 rule 5); every editable row is one.
  final String declaredLabel;

  /// French field messages by field (`name`, `dosageText`, `timesPerDay`,
  /// `duration`, `startedOn`).
  final Map<String, String> errors;
  final ValueChanged<int> onTimesPerDayChanged;
  final ValueChanged<DurationUnit> onDurationUnitChanged;
  final VoidCallback onTextChanged;
  final VoidCallback onDelete;

  const MedicationEditorCard({
    super.key,
    required this.draft,
    required this.declaredLabel,
    required this.errors,
    required this.onTimesPerDayChanged,
    required this.onDurationUnitChanged,
    required this.onTextChanged,
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
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              declaredLabel,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: OmniColors.textSecondary),
            ),
          ),
          const _FieldLabel('Nom du Médicament'),
          TextField(
            controller: draft.nameController,
            textCapitalization: TextCapitalization.sentences,
            onChanged: (_) => onTextChanged(),
            decoration: _fieldDecoration(
              hintText: 'Nom du médicament',
              errorText: errors['name'],
            ),
          ),
          const SizedBox(height: 14),
          const _FieldLabel('Dosage'),
          TextField(
            controller: draft.dosageController,
            onChanged: (_) => onTextChanged(),
            decoration: _fieldDecoration(
              hintText: 'Ex: 500mg',
              errorText: errors['dosageText'],
            ),
          ),
          const SizedBox(height: 16),
          const _FieldLabel('Fréquence'),
          Row(
            children: [
              for (var index = 0; index < frequencies.length; index++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: index == frequencies.length - 1 ? 0 : 7,
                    ),
                    child: _FrequencyChoice(
                      label: frequencies[index],
                      selected: draft.timesPerDay == index + 1,
                      onTap: () => onTimesPerDayChanged(index + 1),
                    ),
                  ),
                ),
            ],
          ),
          if (errors['timesPerDay'] case final error?) _ErrorLine(error),
          const SizedBox(height: 16),
          const _FieldLabel('Durée'),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: draft.durationController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => onTextChanged(),
                  decoration: _fieldDecoration(
                    hintText: '0',
                    errorText: errors['duration'],
                  ),
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
                    child: DropdownButton<DurationUnit>(
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
                      items: durationUnits.entries
                          .map(
                            (unit) => DropdownMenuItem<DurationUnit>(
                              value: unit.key,
                              child: Text(unit.value),
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
          if (errors['startedOn'] case final error?) _ErrorLine(error),
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

  static InputDecoration _fieldDecoration({
    required String hintText,
    String? errorText,
  }) {
    return InputDecoration(
      hintText: hintText,
      errorText: errorText,
      errorMaxLines: 3,
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

/// A field message under a choice row, in the theme's input error style.
class _ErrorLine extends StatelessWidget {
  final String message;

  const _ErrorLine(this.message);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 12),
      child: Text(
        message,
        style:
            theme.inputDecorationTheme.errorStyle ??
            theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
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
