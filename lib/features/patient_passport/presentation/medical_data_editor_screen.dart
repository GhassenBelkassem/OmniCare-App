import 'package:flutter/material.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/theme/omni_theme.dart';
import '../../../l10n/omni_localizations.dart';
import '../application/medical_data_editor_draft.dart';
import '../application/medical_data_editor_view_model.dart';
import '../application/medical_record_view_model.dart';
import '../application/medical_reference_values.dart';
import '../data/medical_record_models.dart';
import '../data/medical_record_write_models.dart';
import 'medical_record_messages.dart';
import 'medical_record_presenter.dart';
import 'widgets/chronic_conditions_editor.dart';
import 'widgets/medical_measurements_editor_card.dart';
import 'widgets/medication_editor_card.dart';
import 'widgets/passport_card_status.dart';
import 'widgets/passport_medications_card.dart';

const _editorPageBackground = Color(0xFFF4F5F7);
const _editorSaveTeal = Color(0xFF5BBC9C);

/// « Modifier / Ajouter les Données de … » for the person on screen
/// (G2.1-A2). Every save goes to [viewModel]'s subject only. What the user
/// types stays on screen until the editor closes: a failed section shows its
/// French text and « Réessayer »; sections that saved stay saved.
class MedicalDataEditorScreen extends StatefulWidget {
  final MedicalDataEditorViewModel viewModel;

  /// The name of the person whose record is edited (title only).
  final String memberName;

  const MedicalDataEditorScreen({
    super.key,
    required this.viewModel,
    required this.memberName,
  });

  @override
  State<MedicalDataEditorScreen> createState() =>
      _MedicalDataEditorScreenState();
}

class _MedicalDataEditorScreenState extends State<MedicalDataEditorScreen> {
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final _allergies = _ChipDraft(allergyPresetRows);
  final _conditions = _ChipDraft(conditionPresetRows);
  final List<MedicationEditorDraft> _medications = [];
  String? _bloodType;
  int _nextMedicationKey = 0;
  bool _seeded = false;

  MedicalDataEditorViewModel get _viewModel => widget.viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel.addListener(_onViewModelChanged);
    _viewModel.load();
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
    _heightController.dispose();
    _weightController.dispose();
    _allergies.dispose();
    _conditions.dispose();
    for (final medication in _medications) {
      medication.dispose();
    }
    super.dispose();
  }

  /// Fills the fields once, from the first successful read. Later reads
  /// (after a conflict or a partial save) never overwrite what was typed.
  void _onViewModelChanged() {
    final baseline = _viewModel.baseline;
    if (!_seeded && baseline != null) {
      _seeded = true;
      final draft = EditorDraft.of(baseline);
      _bloodType = draft.bloodType;
      _heightController.text = draft.heightText;
      _weightController.text = draft.weightText;
      _allergies.seed(draft.allergyLabels);
      _conditions.seed(draft.conditionLabels);
      for (final input in draft.medications) {
        _medications.add(MedicationEditorDraft.fromInput(input));
      }
      _nextMedicationKey = draft.medications.length;
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final l10n = OmniLocalizations.of(context);
    final baseline = _viewModel.baseline;
    final firstName = widget.memberName.trim().split(RegExp(r'\s+')).first;
    final title = (baseline?.hasAnyValue ?? true)
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
                    child: switch (_viewModel.state) {
                      SectionReady(:final value) => _buildForm(
                        context,
                        l10n,
                        value,
                      ),
                      SectionFailed(:final failure) => PassportCardStatusBody(
                        status: PassportCardFailed(
                          message: sectionFailureMessage(failure, l10n),
                          onRetry: _viewModel.load,
                        ),
                      ),
                      SectionIdle() ||
                      SectionLoading() => const PassportCardStatusBody(
                        status: PassportCardLoading(),
                      ),
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _SaveFooter(
        onSave: baseline == null || _viewModel.saving ? null : _save,
      ),
    );
  }

  Widget _buildForm(
    BuildContext context,
    OmniLocalizations l10n,
    EditorBaseline baseline,
  ) {
    final height = parseMeasurement(_heightController.text);
    final weight = parseMeasurement(_weightController.text);
    final bmi = displayedBmi(height, weight);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel('Groupe Sanguin *'),
        _BloodGroupField(
          value: _bloodType,
          dontKnowLabel: l10n.recordBloodTypeDontKnow,
          notRecordedLabel: l10n.medicalRecordNotRecorded,
          onChanged: baseline.bloodTypeLocked
              ? null
              : (value) =>
                    _edit(RecordSection.bloodType, () => _bloodType = value),
        ),
        _sectionStatus(RecordSection.bloodType, l10n),
        const SizedBox(height: 18),
        MedicalMeasurementsEditorCard(
          heightController: _heightController,
          weightController: _weightController,
          bmi: bmi,
          bmiCategory: _bmiCategoryText(bmiCategoryOf(bmi), l10n),
          heightError: _fieldMessage('measurements:heightCm', l10n),
          weightError: _fieldMessage('measurements:weightKg', l10n),
          onHeightChanged: (_) => _edit(RecordSection.measurements),
          onWeightChanged: (_) => _edit(RecordSection.measurements),
        ),
        _sectionStatus(RecordSection.measurements, l10n),
        const SizedBox(height: 26),
        _chipsEditor(
          RecordSection.allergies,
          _allergies,
          baseline.allergies,
          title: l10n.recordAllergiesTitle,
          subtitle: l10n.recordAllergiesSubtitle,
          hintText: l10n.recordAllergiesOtherHint,
          l10n: l10n,
        ),
        _sectionStatus(RecordSection.allergies, l10n),
        const SizedBox(height: 26),
        _chipsEditor(
          RecordSection.conditions,
          _conditions,
          baseline.conditions,
          title: 'Conditions Chroniques',
          subtitle: 'Sélectionnez toutes les conditions applicables',
          hintText: 'Autre condition...',
          l10n: l10n,
        ),
        _sectionStatus(RecordSection.conditions, l10n),
        const SizedBox(height: 28),
        _MedicationsHeader(onAdd: _addMedication),
        if (_fieldMessage('medications', l10n) case final message?)
          _FieldMessage(message),
        const SizedBox(height: 14),
        for (final item in baseline.readOnlyCurrentMedications)
          PassportMedicationRow(
            medication: passportMedication(item, current: true, l10n: l10n),
          ),
        if (baseline.readOnlyCurrentMedications.isNotEmpty &&
            _medications.isNotEmpty)
          const SizedBox(height: 20),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: Column(
            children: [
              for (var index = 0; index < _medications.length; index++) ...[
                MedicationEditorCard(
                  key: ObjectKey(_medications[index]),
                  draft: _medications[index],
                  declaredLabel: l10n.passportDeclaredByPatient,
                  errors: _medicationErrors(_medications[index], l10n),
                  onTimesPerDayChanged: (times) => _edit(
                    RecordSection.declaredMedications,
                    () => _medications[index].timesPerDay = times,
                  ),
                  onDurationUnitChanged: (unit) => _edit(
                    RecordSection.declaredMedications,
                    () => _medications[index].durationUnit = unit,
                  ),
                  onTextChanged: () => _edit(RecordSection.declaredMedications),
                  onDelete: () => _removeMedication(_medications[index]),
                ),
                if (index < _medications.length - 1) const SizedBox(height: 20),
              ],
            ],
          ),
        ),
        _sectionStatus(RecordSection.declaredMedications, l10n),
      ],
    );
  }

  Widget _chipsEditor(
    RecordSection section,
    _ChipDraft chips,
    List<RecordItem> items, {
    required String title,
    required String subtitle,
    required String hintText,
    required OmniLocalizations l10n,
  }) {
    final professional = [
      for (final item in items)
        if (!item.author.isEditableByPatient) item.label,
    ];
    final presetKeys = chips.presetKeys;
    final addError = chips.addError;
    return MedicalChipsEditor(
      title: title,
      subtitle: subtitle,
      hintText: hintText,
      presetRows: chips.presetRows,
      customLabels: chips.custom,
      readOnlyLabels: [
        for (final label in professional)
          if (!presetKeys.contains(labelKey(label))) label,
      ],
      selectedKeys: chips.selectedKeys,
      readOnlyKeys: professional.map(labelKey).toSet(),
      keyOf: labelKey,
      customController: chips.controller,
      onToggle: (label) => _edit(section, () => chips.toggle(label)),
      onCustomChanged: (_) => setState(() => chips.addError = null),
      onAddCustom: chips.controller.text.trim().isEmpty
          ? null
          : () => _edit(section, () => chips.addCustom(professional)),
      errorText: addError == null
          ? _fieldMessage(_sectionKey(section), l10n)
          : recordFieldMessage('label', addError, l10n),
    );
  }

  /// A failed save of [section]: its French text and « Réessayer » (the same
  /// content resends with the same key).
  Widget _sectionStatus(RecordSection section, OmniLocalizations l10n) {
    final failure = _viewModel.failureOf(section);
    if (failure == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: PassportCardStatusBody(
        status: PassportCardFailed(
          message: recordFailureMessage(
            failure,
            l10n,
            fallback: l10n.saveGeneric,
          ),
          onRetry: _save,
        ),
      ),
    );
  }

  Map<String, String> _medicationErrors(
    MedicationEditorDraft draft,
    OmniLocalizations l10n,
  ) => {
    for (final field in const [
      'name',
      'dosageText',
      'timesPerDay',
      'duration',
      'startedOn',
    ])
      field: ?_fieldMessage('medications:${draft.key}.$field', l10n),
  };

  String? _fieldMessage(String key, OmniLocalizations l10n) {
    final error = _viewModel.fieldError(key);
    return error == null
        ? null
        : recordFieldMessage(error.path, error.kind, l10n);
  }

  /// A change in [section]: its next save is a new action (new key).
  void _edit(RecordSection section, [VoidCallback? change]) {
    setState(() => change?.call());
    _viewModel.edited(section);
  }

  void _addMedication() {
    _edit(
      RecordSection.declaredMedications,
      () => _medications.add(MedicationEditorDraft.empty(_nextMedicationKey++)),
    );
  }

  void _removeMedication(MedicationEditorDraft medication) {
    _edit(
      RecordSection.declaredMedications,
      () => _medications.remove(medication),
    );
    medication.dispose();
  }

  Future<void> _save() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final outcome = await _viewModel.save(
      EditorDraft(
        bloodType: _bloodType,
        heightText: _heightController.text,
        weightText: _weightController.text,
        allergyLabels: List.unmodifiable(_allergies.selected),
        conditionLabels: List.unmodifiable(_conditions.selected),
        medications: List.unmodifiable(
          _medications.map((draft) => draft.toInput()),
        ),
      ),
    );
    if (!mounted || outcome != EditorSaveOutcome.done) return;
    Navigator.of(context).pop();
  }

  static String? _bmiCategoryText(
    BmiCategory? category,
    OmniLocalizations l10n,
  ) => switch (category) {
    null => null,
    BmiCategory.underweight => l10n.bmiCategoryUnderweight,
    BmiCategory.normal => l10n.bmiCategoryNormal,
    BmiCategory.overweight => l10n.bmiCategoryOverweight,
    BmiCategory.obese => l10n.bmiCategoryObese,
  };

  static String _sectionKey(RecordSection section) =>
      section == RecordSection.allergies ? 'allergies' : 'conditions';
}

/// The chips of one list as the user sets them: presets, the patient's own
/// labels (selected or not), and the « Autre… » field.
class _ChipDraft {
  _ChipDraft(this.presetRows)
    : presetKeys = {
        for (final row in presetRows)
          for (final label in row) labelKey(label),
      };

  final List<List<String>> presetRows;
  final Set<String> presetKeys;
  final TextEditingController controller = TextEditingController();

  /// Selected labels, in the order they were chosen.
  final List<String> selected = [];

  /// The patient's labels that are not presets; they stay listed when
  /// unselected so they can be chosen again.
  final List<String> custom = [];

  /// The instant message of the « Autre… » field.
  ApiFieldErrorKind? addError;

  Set<String> get selectedKeys => selected.map(labelKey).toSet();

  void seed(List<String> ownLabels) {
    selected.addAll(ownLabels);
    custom.addAll(ownLabels.where((l) => !presetKeys.contains(labelKey(l))));
  }

  void toggle(String label) {
    final key = labelKey(label);
    if (selected.any((other) => labelKey(other) == key)) {
      selected.removeWhere((other) => labelKey(other) == key);
    } else {
      selected.add(label);
    }
  }

  /// Adds the typed label, or selects the chip that already has it. A label
  /// a professional recorded, or one the server would refuse, is not added:
  /// its message shows on the field.
  void addCustom(List<String> professional) {
    final label = controller.text.trim();
    final error = newChipError(label, professional);
    if (error != null) {
      addError = error;
      return;
    }
    final key = labelKey(label);
    final existing = [
      for (final row in presetRows) ...row,
      ...custom,
    ].where((other) => labelKey(other) == key);
    if (existing.isEmpty) custom.add(label);
    if (!selected.any((other) => labelKey(other) == key)) {
      selected.add(existing.isEmpty ? label : existing.first);
    }
    addError = null;
    controller.clear();
  }

  void dispose() => controller.dispose();
}

/// A list-level field message (for example « 50 éléments maximum. »), in the
/// theme's input error style.
class _FieldMessage extends StatelessWidget {
  final String message;

  const _FieldMessage(this.message);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        message,
        style:
            theme.inputDecorationTheme.errorStyle ??
            theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
      ),
    );
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

/// The blood type selector: the eight groups and « Je ne sais pas »
/// (UNKNOWN). No default: without a value it reads « Non renseigné ». A
/// blood type set by a professional is shown disabled ([onChanged] null).
class _BloodGroupField extends StatelessWidget {
  final String? value;
  final String dontKnowLabel;
  final String notRecordedLabel;
  final ValueChanged<String>? onChanged;

  const _BloodGroupField({
    required this.value,
    required this.dontKnowLabel,
    required this.notRecordedLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;
    final value = this.value;
    final hint = Text(
      value == null
          ? notRecordedLabel
          : (value == bloodTypeUnknown ? dontKnowLabel : value),
    );
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
          hint: hint,
          disabledHint: hint,
          isExpanded: true,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: OmniColors.textSecondary,
          ),
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: OmniColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
          items: [
            for (final bloodGroup in bloodTypeValues)
              DropdownMenuItem<String>(
                value: bloodGroup,
                child: Text(bloodGroup),
              ),
            DropdownMenuItem<String>(
              value: bloodTypeUnknown,
              child: Text(dontKnowLabel),
            ),
          ],
          onChanged: onChanged == null
              ? null
              : (next) {
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
  /// `null` while loading or saving (the button is disabled).
  final VoidCallback? onSave;

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
