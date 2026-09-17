import 'package:flutter/material.dart';

import '../../../core/theme/omni_theme.dart';
import '../models/patient_passport_view_models.dart';
import 'widgets/chronic_conditions_editor.dart';
import 'widgets/medical_measurements_editor_card.dart';
import 'widgets/medication_editor_card.dart';

const _editorPageBackground = Color(0xFFF4F5F7);
const _editorSaveTeal = Color(0xFF5BBC9C);

class MedicalDataEditorScreen extends StatefulWidget {
  final PatientPassportViewData initialData;

  const MedicalDataEditorScreen({super.key, required this.initialData});

  @override
  State<MedicalDataEditorScreen> createState() =>
      _MedicalDataEditorScreenState();
}

class _MedicalDataEditorScreenState extends State<MedicalDataEditorScreen> {
  static const _bloodGroups = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
  ];

  static const _predefinedConditions = [
    'Diabète Type 2',
    'Diabète Type 1',
    'Hypertension',
    'Asthme',
    'Allergie Pénicilline',
    'Maladie Cardiaque',
    'Cholestérol Élevé',
    'Arthrite',
    'Migraine',
    'Thyroïde',
  ];

  late String _bloodGroup;
  late final TextEditingController _heightController;
  late final TextEditingController _weightController;
  final TextEditingController _customConditionController =
      TextEditingController();
  late final Set<String> _selectedConditions;
  late final List<String> _customConditions;
  late final List<MedicationEditorDraft> _medications;
  late double _bmi;

  @override
  void initState() {
    super.initState();
    _bloodGroup = _bloodGroups.contains(widget.initialData.bloodGroup)
        ? widget.initialData.bloodGroup
        : _bloodGroups.first;
    _heightController = TextEditingController(
      text: _formatMeasurement(widget.initialData.heightCm),
    );
    _weightController = TextEditingController(
      text: _formatMeasurement(widget.initialData.weightKg),
    );
    _bmi = _calculateBmi(
      widget.initialData.heightCm,
      widget.initialData.weightKg,
    );
    _selectedConditions = widget.initialData.chronicConditions.toSet();
    _customConditions = widget.initialData.chronicConditions
        .where((condition) => !_predefinedConditions.contains(condition))
        .toList();
    _medications = widget.initialData.medications
        .where((medication) => medication.isCurrent)
        .map(MedicationEditorDraft.fromMedication)
        .toList();
  }

  @override
  void dispose() {
    _heightController.dispose();
    _weightController.dispose();
    _customConditionController.dispose();
    for (final medication in _medications) {
      medication.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final firstName = widget.initialData.name
        .trim()
        .split(RegExp(r'\s+'))
        .first;
    final hasMedicalData =
        widget.initialData.bloodGroup.trim().isNotEmpty ||
        widget.initialData.chronicConditions.isNotEmpty ||
        widget.initialData.medications.isNotEmpty ||
        widget.initialData.heightCm > 0 ||
        widget.initialData.weightKg > 0;
    final title = hasMedicalData
        ? 'Modifier les Données de $firstName'
        : 'Ajouter les Données de $firstName';

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: _editorPageBackground,
      body: Column(
        children: [
          _EditorHeader(
            title: title,
            onClose: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  24,
                  18,
                  24,
                  32 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const _FieldLabel('Groupe Sanguin *'),
                        _BloodGroupField(
                          value: _bloodGroup,
                          values: _bloodGroups,
                          onChanged: (value) {
                            setState(() => _bloodGroup = value);
                          },
                        ),
                        const SizedBox(height: 18),
                        MedicalMeasurementsEditorCard(
                          heightController: _heightController,
                          weightController: _weightController,
                          bmi: _bmi,
                          onHeightChanged: (_) => _refreshBmi(),
                          onWeightChanged: (_) => _refreshBmi(),
                        ),
                        const SizedBox(height: 26),
                        ChronicConditionsEditor(
                          conditions: [
                            ..._predefinedConditions,
                            ..._customConditions,
                          ],
                          selectedConditions: _selectedConditions,
                          customConditionController: _customConditionController,
                          onToggle: _toggleCondition,
                          onCustomChanged: (_) => setState(() {}),
                          onAddCustom:
                              _customConditionController.text.trim().isEmpty
                              ? null
                              : _addCustomCondition,
                        ),
                        const SizedBox(height: 28),
                        _MedicationsHeader(onAdd: _addMedication),
                        const SizedBox(height: 14),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.easeOutCubic,
                          alignment: Alignment.topCenter,
                          child: Column(
                            children: [
                              for (
                                var index = 0;
                                index < _medications.length;
                                index++
                              ) ...[
                                MedicationEditorCard(
                                  key: ObjectKey(_medications[index]),
                                  draft: _medications[index],
                                  onFrequencyChanged: (frequency) {
                                    setState(
                                      () => _medications[index].frequency =
                                          frequency,
                                    );
                                  },
                                  onDurationUnitChanged: (unit) {
                                    setState(
                                      () => _medications[index].durationUnit =
                                          unit,
                                    );
                                  },
                                  onDelete: () =>
                                      _removeMedication(_medications[index]),
                                ),
                                if (index < _medications.length - 1)
                                  const SizedBox(height: 20),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _SaveFooter(onSave: _save),
    );
  }

  void _refreshBmi() {
    final height = _parseMeasurement(_heightController.text);
    final weight = _parseMeasurement(_weightController.text);
    if (height <= 0 || weight <= 0) return;
    setState(() => _bmi = _calculateBmi(height, weight));
  }

  void _toggleCondition(String condition) {
    setState(() {
      if (!_selectedConditions.add(condition)) {
        _selectedConditions.remove(condition);
      }
    });
  }

  void _addCustomCondition() {
    final condition = _customConditionController.text.trim();
    if (condition.isEmpty) return;
    setState(() {
      if (!_predefinedConditions.contains(condition) &&
          !_customConditions.contains(condition)) {
        _customConditions.add(condition);
      }
      _selectedConditions.add(condition);
      _customConditionController.clear();
    });
  }

  void _addMedication() {
    setState(() => _medications.add(MedicationEditorDraft.empty()));
  }

  void _removeMedication(MedicationEditorDraft medication) {
    setState(() => _medications.remove(medication));
    medication.dispose();
  }

  void _save() {
    FocusManager.instance.primaryFocus?.unfocus();
    final height = _parseMeasurement(_heightController.text);
    final weight = _parseMeasurement(_weightController.text);
    final previousMedications = widget.initialData.medications.where(
      (medication) => !medication.isCurrent,
    );
    final currentMedications = _medications
        .where((draft) => draft.nameController.text.trim().isNotEmpty)
        .map((draft) => draft.toMedication());

    final updatedData = widget.initialData.copyWith(
      bloodGroup: _bloodGroup,
      heightCm: height > 0 ? height : widget.initialData.heightCm,
      weightKg: weight > 0 ? weight : widget.initialData.weightKg,
      chronicConditions: _selectedConditions.toList(growable: false),
      medications: [...currentMedications, ...previousMedications],
    );
    Navigator.of(context).pop(updatedData);
  }

  static String _formatMeasurement(double value) {
    return value == value.roundToDouble()
        ? value.toInt().toString()
        : value.toStringAsFixed(1);
  }

  static double _parseMeasurement(String value) {
    return double.tryParse(value.trim().replaceAll(',', '.')) ?? 0;
  }

  static double _calculateBmi(double heightCm, double weightKg) {
    if (heightCm <= 0 || weightKg <= 0) return 0;
    final heightMeters = heightCm / 100;
    return weightKg / (heightMeters * heightMeters);
  }
}

class _EditorHeader extends StatelessWidget {
  final String title;
  final VoidCallback onClose;

  const _EditorHeader({required this.title, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: OmniColors.surfacePrimary,
      child: SafeArea(
        bottom: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 10, 12, 10),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: OmniColors.borderLight)),
          ),
          child: Row(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    maxLines: 1,
                    softWrap: false,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: OmniColors.textPrimary,
                      fontSize: 25,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.45,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Fermer sans enregistrer',
                style: IconButton.styleFrom(
                  minimumSize: const Size(44, 44),
                  foregroundColor: OmniColors.textSecondary,
                  iconSize: 24,
                ),
              ),
            ],
          ),
        ),
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: OmniColors.textPrimary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _BloodGroupField extends StatelessWidget {
  final String value;
  final List<String> values;
  final ValueChanged<String> onChanged;

  const _BloodGroupField({
    required this.value,
    required this.values,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: OmniColors.surfacePrimary,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: OmniColors.borderLight),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: OmniColors.textSecondary,
          ),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: OmniColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
          items: values
              .map(
                (bloodGroup) => DropdownMenuItem<String>(
                  value: bloodGroup,
                  child: Text(bloodGroup),
                ),
              )
              .toList(growable: false),
          onChanged: (next) {
            if (next != null) onChanged(next);
          },
        ),
      ),
    );
  }
}

class _MedicationsHeader extends StatelessWidget {
  final VoidCallback onAdd;

  const _MedicationsHeader({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Médicaments Actuels',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: OmniColors.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        TextButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.add_rounded, size: 19),
          label: const Text('Ajouter'),
          style: TextButton.styleFrom(
            foregroundColor: OmniColors.primaryAction,
            backgroundColor: OmniColors.mintSoft,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _SaveFooter extends StatelessWidget {
  final VoidCallback onSave;

  const _SaveFooter({required this.onSave});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: OmniColors.surfacePrimary,
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: OmniColors.borderLight)),
            boxShadow: [OmniColors.shadowSm],
          ),
          child: ElevatedButton.icon(
            onPressed: onSave,
            icon: const Icon(Icons.save_outlined, size: 21),
            label: const Text('Enregistrer les Modifications'),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(58),
              backgroundColor: _editorSaveTeal,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(17),
              ),
              elevation: 0,
            ),
          ),
        ),
      ),
    );
  }
}
