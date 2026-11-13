import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/models/blood_type.dart';
import '../../core/widgets/medication_search_field.dart';
import '../../l10n/omni_localizations.dart';
import '../patient_passport/application/medical_data_editor_draft.dart';
import '../patient_passport/application/medical_data_editor_view_model.dart';
import '../patient_passport/application/medical_record_view_model.dart';
import '../patient_passport/data/medical_record_write_models.dart';
import '../patient_passport/presentation/medical_record_messages.dart';
import '../patient_passport/presentation/medical_record_presenter.dart';
import '../patient_passport/presentation/widgets/passport_card_status.dart';
import '../patient_passport/presentation/widgets/passport_medications_card.dart';
import 'medical_data_edit_mapping.dart';

class Medication {
  String? medicationId;
  String name;
  String dosage;
  String frequency;

  Medication({
    this.medicationId,
    required this.name,
    required this.dosage,
    required this.frequency,
  });
}

class MedicalDocument {
  String id;
  String name;
  String type;
  String date;
  String fileUrl;

  MedicalDocument({
    required this.id,
    required this.name,
    required this.type,
    required this.date,
    required this.fileUrl,
  });
}

/// What the screen showed when every change was saved (handed back on
/// close, so a caller can show it without a new read).
class MedicalDataEditResult {
  const MedicalDataEditResult({required this.documents, this.saved});

  /// The documents block (local to the screen, as before).
  final List<MedicalDocument> documents;

  /// The saved values; `null` when the screen closed without saving all.
  final ({
    BloodType? bloodType,
    List<String> conditions,
    List<Medication> medications,
  })?
  saved;
}

/// « Modifier Mes Données Médicales » for Ma Santé (SELF) and the
/// family-member screen (FAMILY:{id}) (G2.1-A3). It reads the record and
/// saves through the same section saves and rules as the record editor
/// ([MedicalDataEditorViewModel]): only changed sections, one key per
/// section, professional items read-only and never sent, no A+ default,
/// « Je ne sais pas », 409 keeps what was typed, « Réessayer » with the same
/// key. Height, weight and allergies have no field here and are never sent.
class EditMedicalDataScreen extends StatefulWidget {
  /// The editor of the person whose data this screen edits.
  final MedicalDataEditorViewModel viewModel;

  /// The documents block (not saved by this screen, as before).
  final List<MedicalDocument> documents;

  const EditMedicalDataScreen({
    super.key,
    required this.viewModel,
    this.documents = const [],
  });

  @override
  State<EditMedicalDataScreen> createState() => _EditMedicalDataScreenState();
}

/// One medication row: the patient's own declared item (or a new one).
/// Duration and start date have no field here: they are kept as read.
class _MedicationRowDraft {
  _MedicationRowDraft(this.input)
    : name = TextEditingController(text: input.name),
      dosage = TextEditingController(text: input.dosageText),
      frequency = TextEditingController(
        text: frequencyTextOf(input.timesPerDay),
      );

  final MedicationInput input;
  final TextEditingController name;
  final TextEditingController dosage;
  final TextEditingController frequency;

  MedicationInput toInput() => MedicationInput(
    key: input.key,
    itemId: input.itemId,
    name: name.text,
    dosageText: dosage.text,
    timesPerDay: timesPerDayOfText(frequency.text),
    durationText: input.durationText,
    durationUnit: input.durationUnit,
    startedOn: input.startedOn,
  );

  void dispose() {
    name.dispose();
    dosage.dispose();
    frequency.dispose();
  }
}

class _EditMedicalDataScreenState extends State<EditMedicalDataScreen> {
  /// Value of the "-" option: nothing chosen (never sent).
  static const String _notProvided = '-';

  final List<String> _bloodTypes = [
    _notProvided,
    'A+',
    'A-',
    'B+',
    'B-',
    'O+',
    'O-',
    'AB+',
    'AB-',
    bloodTypeUnknown,
  ];

  final List<Map<String, dynamic>> _documentTypes = [
    {'value': 'blood-test', 'label': 'Analyse de Sang'},
    {'value': 'xray', 'label': 'Radio / Radiographie'},
    {'value': 'scan', 'label': 'Scanner / IRM'},
    {'value': 'prescription', 'label': 'Ordonnance'},
    {'value': 'report', 'label': 'Rapport Médical'},
    {'value': 'other', 'label': 'Autre'},
  ];

  String _bloodType = _notProvided;

  /// The patient's own conditions, as chosen (professional ones are never
  /// part of what is sent).
  final List<String> _chronicConditions = [];
  final List<_MedicationRowDraft> _medications = [];
  late List<MedicalDocument> _documents;
  int _nextMedicationKey = 0;
  bool _seeded = false;

  MedicalDataEditorViewModel get _viewModel => widget.viewModel;
  bool get _isSaving => _viewModel.saving;

  @override
  void initState() {
    super.initState();
    _documents = List.from(widget.documents);
    _viewModel.addListener(_onViewModelChanged);
    _viewModel.load();
  }

  @override
  void dispose() {
    _viewModel.removeListener(_onViewModelChanged);
    for (final row in _medications) {
      row.dispose();
    }
    super.dispose();
  }

  /// Fills the fields once, from the first successful read. Later reads
  /// (after a conflict or a partial save) never replace what was typed.
  void _onViewModelChanged() {
    final baseline = _viewModel.baseline;
    if (!_seeded && baseline != null) {
      _seeded = true;
      final draft = EditorDraft.of(baseline);
      _bloodType = draft.bloodType ?? _notProvided;
      _chronicConditions.addAll(draft.conditionLabels);
      for (final input in draft.medications) {
        _medications.add(_MedicationRowDraft(input));
      }
      _nextMedicationKey = draft.medications.length;
    }
    if (mounted) setState(() {});
  }

  void _toggleCondition(String condition, Set<String> professional) {
    final key = labelKey(condition);
    if (professional.contains(key)) {
      _showError(OmniLocalizations.of(context).recordCodeItemLocked);
      return;
    }
    setState(() {
      if (_chronicConditions.any((c) => labelKey(c) == key)) {
        _chronicConditions.removeWhere((c) => labelKey(c) == key);
      } else {
        _chronicConditions.add(condition);
      }
    });
    _viewModel.edited(RecordSection.conditions);
  }

  void _addMedication() {
    setState(() {
      _medications.add(
        _MedicationRowDraft(
          MedicationInput(key: _nextMedicationKey++, name: ''),
        ),
      );
    });
    _viewModel.edited(RecordSection.declaredMedications);
  }

  void _removeMedication(int index) {
    setState(() => _medications.removeAt(index).dispose());
    _viewModel.edited(RecordSection.declaredMedications);
  }

  void _addDocument() {
    setState(() {
      _documents.add(
        MedicalDocument(
          id: 'doc-${DateTime.now().millisecondsSinceEpoch}',
          name: '',
          type: 'other',
          date: '',
          fileUrl: '',
        ),
      );
    });
  }

  void _removeDocument(int index) {
    setState(() {
      _documents.removeAt(index);
    });
  }

  /// One « Enregistrer » (or « Réessayer »): the changed sections only.
  /// Every failure keeps the screen open with what was typed.
  Future<void> _handleSave() async {
    final baseline = _viewModel.baseline;
    if (_isSaving || baseline == null) return;
    final medications = [for (final row in _medications) row.toInput()];
    final outcome = await _viewModel.save(
      editMedicalDataDraft(
        baseline: baseline,
        bloodType: _bloodType == _notProvided ? null : _bloodType,
        conditions: _chronicConditions,
        medications: medications,
      ),
    );
    if (!mounted) return;
    switch (outcome) {
      case EditorSaveOutcome.done:
        Navigator.pop(
          context,
          MedicalDataEditResult(
            documents: List.unmodifiable(_documents),
            saved: (
              bloodType: _bloodType == _notProvided
                  ? null
                  : BloodType.fromWire(
                      _bloodType == bloodTypeUnknown ? 'unknown' : _bloodType,
                    ),
              conditions: List.unmodifiable(_chronicConditions),
              medications: [
                for (final row in medications)
                  Medication(
                    name: row.name.trim(),
                    dosage: row.dosageText.trim(),
                    frequency: frequencyTextOf(row.timesPerDay),
                  ),
              ],
            ),
          ),
        );
      case EditorSaveOutcome.invalid:
        final message = _sectionFieldMessage();
        if (message != null) _showError(message);
      case EditorSaveOutcome.failed:
        final message = _firstFailureMessage() ?? _sectionFieldMessage();
        if (message != null) _showError(message, retry: true);
    }
  }

  /// The text of the first failed section (in save order).
  String? _firstFailureMessage() {
    final l10n = OmniLocalizations.of(context);
    for (final section in editorSections) {
      final failure = _viewModel.failureOf(section);
      if (failure != null) {
        return recordFailureMessage(failure, l10n, fallback: l10n.saveGeneric);
      }
    }
    return null;
  }

  /// A refusal with no field of its own on screen (blood type, conditions,
  /// the medication list).
  String? _sectionFieldMessage() =>
      _fieldMessage('bloodType') ??
      _fieldMessage('conditions') ??
      _fieldMessage('medications');

  String? _fieldMessage(String key) {
    final error = _viewModel.fieldError(key);
    return error == null
        ? null
        : recordFieldMessage(
            error.path,
            error.kind,
            OmniLocalizations.of(context),
          );
  }

  SnackBar _errorSnackBar(String message, {bool retry = false}) => SnackBar(
    content: Text(message, style: GoogleFonts.plusJakartaSans(fontSize: 13)),
    backgroundColor: const Color(0xFFEF4444),
    action: retry
        ? SnackBarAction(
            label: OmniLocalizations.of(context).passportRetry,
            textColor: Colors.white,
            onPressed: _handleSave,
          )
        : null,
  );

  void _showError(String message, {bool retry = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(_errorSnackBar(message, retry: retry));
  }

  /// Closing with ✕ hands back the documents block, as before.
  void _close() => Navigator.pop(
    context,
    MedicalDataEditResult(documents: List.unmodifiable(_documents)),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Color(0xFF1A202C)),
          onPressed: _isSaving ? null : _close,
        ),
        title: Text(
          'Modifier Mes Données Médicales',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1A202C),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: switch (_viewModel.state) {
                SectionReady(:final value) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBloodTypeSection(value),
                    const SizedBox(height: 24),
                    _buildChronicConditionsSection(value),
                    const SizedBox(height: 24),
                    _buildMedicationsSection(value),
                    const SizedBox(height: 24),
                    _buildDocumentsSection(),
                    const SizedBox(height: 100),
                  ],
                ),
                SectionFailed(:final failure) => PassportCardStatusBody(
                  status: PassportCardFailed(
                    message: sectionFailureMessage(
                      failure,
                      OmniLocalizations.of(context),
                    ),
                    onRetry: _viewModel.load,
                  ),
                ),
                SectionIdle() || SectionLoading() =>
                  const PassportCardStatusBody(status: PassportCardLoading()),
              },
            ),
          ),
          _buildSaveButton(),
        ],
      ),
    );
  }

  Widget _buildBloodTypeSection(EditorBaseline baseline) {
    final l10n = OmniLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Groupe Sanguin *',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1A202C),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonFormField<String>(
            initialValue: _bloodTypes.contains(_bloodType)
                ? _bloodType
                : _notProvided,
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              border: InputBorder.none,
            ),
            hint: Text(
              'Sélectionner',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: const Color(0xFF667085),
              ),
            ),
            items: _bloodTypes.map((type) {
              return DropdownMenuItem(
                value: type,
                child: Text(
                  type == bloodTypeUnknown
                      ? l10n.recordBloodTypeDontKnow
                      : type,
                  style: GoogleFonts.plusJakartaSans(fontSize: 14),
                ),
              );
            }).toList(),
            // A blood type set by a professional is read-only (disabled).
            onChanged: baseline.bloodTypeLocked
                ? null
                : (value) {
                    setState(() {
                      _bloodType = (value == null || value.trim().isEmpty)
                          ? _notProvided
                          : value;
                    });
                    _viewModel.edited(RecordSection.bloodType);
                  },
          ),
        ),
      ],
    );
  }

  Widget _buildChronicConditionsSection(EditorBaseline baseline) {
    final professional = professionalLabelKeys(baseline.conditions);
    final selected = _chronicConditions.map(labelKey).toSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Conditions Chroniques',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1A202C),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Sélectionnez toutes les conditions applicables',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            color: const Color(0xFF667085),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: conditionChipLabels(baseline.conditions).map((condition) {
            final key = labelKey(condition);
            final isSelected =
                selected.contains(key) || professional.contains(key);
            return GestureDetector(
              onTap: () => _toggleCondition(condition, professional),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF0F6F73)
                      : const Color(0xFFF4F5F7),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF0F6F73)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Text(
                  condition,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : const Color(0xFF1A202C),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMedicationsSection(EditorBaseline baseline) {
    final l10n = OmniLocalizations.of(context);
    final prescriptions = baseline.readOnlyCurrentMedications;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Médicaments Actuels',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A202C),
              ),
            ),
            TextButton.icon(
              onPressed: _addMedication,
              icon: const Icon(Icons.add, size: 18, color: Color(0xFF1FBF9A)),
              label: Text(
                'Ajouter',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1FBF9A),
                ),
              ),
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFF1FBF9A).withOpacity(0.1),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // OmniCare prescriptions: read-only, never sent (the Résumé row).
        for (final item in prescriptions)
          PassportMedicationRow(
            medication: passportMedication(item, current: true, l10n: l10n),
          ),
        if (prescriptions.isNotEmpty) const SizedBox(height: 12),
        if (_medications.isEmpty && prescriptions.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFE2E8F0),
                style: BorderStyle.solid,
              ),
            ),
            child: Center(
              child: Text(
                'Aucun médicament. Cliquez sur "Ajouter" pour commencer.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: const Color(0xFF667085),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          Column(
            children: _medications.asMap().entries.map((entry) {
              final index = entry.key;
              final med = entry.value;
              String? error(String field) =>
                  _fieldMessage('medications:${med.input.key}.$field');
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nom du Médicament',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF667085),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.passportDeclaredByPatient,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: const Color(0xFF667085),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Free text: the catalog never blocks a save.
                    MedicationSearchField(
                      controller: med.name,
                      dosageController: med.dosage,
                      hintText: 'Ex: Metformine',
                      onChanged: (_) => _edited(),
                    ),
                    if (error('name') case final message?) _FieldError(message),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Dosage',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF667085),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: med.dosage,
                                onChanged: (_) => _edited(),
                                decoration: InputDecoration(
                                  hintText: 'Ex: 500mg',
                                  errorText: error('dosageText'),
                                  errorMaxLines: 3,
                                  hintStyle: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    color: const Color(0xFF667085),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF1FBF9A),
                                      width: 2,
                                    ),
                                  ),
                                ),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Fréquence',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFF667085),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: med.frequency,
                                onChanged: (_) => _edited(),
                                decoration: InputDecoration(
                                  hintText: 'Ex: 2x/jour',
                                  errorText: error('timesPerDay'),
                                  errorMaxLines: 3,
                                  hintStyle: GoogleFonts.plusJakartaSans(
                                    fontSize: 13,
                                    color: const Color(0xFF667085),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE2E8F0),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF1FBF9A),
                                      width: 2,
                                    ),
                                  ),
                                ),
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () => _removeMedication(index),
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 16,
                        color: Color(0xFFEF4444),
                      ),
                      label: Text(
                        'Supprimer ce médicament',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFEF4444),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  /// A medication field changed: the next save of that list is a new action.
  void _edited() => _viewModel.edited(RecordSection.declaredMedications);

  Widget _buildDocumentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Documents Médicaux',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1A202C),
              ),
            ),
            TextButton.icon(
              onPressed: _addDocument,
              icon: const Icon(Icons.add, size: 18, color: Color(0xFF1FBF9A)),
              label: Text(
                'Ajouter',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1FBF9A),
                ),
              ),
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFF1FBF9A).withOpacity(0.1),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_documents.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFE2E8F0),
                style: BorderStyle.solid,
              ),
            ),
            child: Center(
              child: Text(
                'Aucun document. Cliquez sur "Ajouter" pour commencer.',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: const Color(0xFF667085),
                ),
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          Column(
            children: _documents.asMap().entries.map((entry) {
              final index = entry.key;
              final doc = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Nom du Document',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF667085),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: TextEditingController(text: doc.name)
                        ..selection = TextSelection.collapsed(
                          offset: doc.name.length,
                        ),
                      onChanged: (value) => doc.name = value,
                      decoration: InputDecoration(
                        hintText: 'Ex: Rapport d\'Analyse de Sang',
                        hintStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: const Color(0xFF667085),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFF1FBF9A),
                            width: 2,
                          ),
                        ),
                      ),
                      style: GoogleFonts.plusJakartaSans(fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Type de Document',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF667085),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),

                      // Ensure DropdownButton value is always present in items to avoid assertion crash
                      child: DropdownButtonFormField<String>(
                        initialValue:
                            _documentTypes.any((t) => t['value'] == doc.type)
                            ? doc.type
                            : (_documentTypes.first['value'] as String),
                        decoration: const InputDecoration(
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          border: InputBorder.none,
                        ),
                        items: _documentTypes.map((type) {
                          return DropdownMenuItem<String>(
                            value: type['value'] as String,
                            child: Text(
                              type['label'] as String,
                              style: GoogleFonts.plusJakartaSans(fontSize: 13),
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            doc.type = value ?? 'other';
                          });
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Date du Document',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF667085),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: TextEditingController(text: doc.date)
                        ..selection = TextSelection.collapsed(
                          offset: doc.date.length,
                        ),
                      onChanged: (value) => doc.date = value,
                      decoration: InputDecoration(
                        hintText: 'JJ/MM/AAAA',
                        hintStyle: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: const Color(0xFF667085),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFFE2E8F0),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                            color: Color(0xFF1FBF9A),
                            width: 2,
                          ),
                        ),
                        suffixIcon: const Icon(
                          Icons.calendar_today,
                          size: 18,
                          color: Color(0xFF667085),
                        ),
                      ),
                      style: GoogleFonts.plusJakartaSans(fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () => _removeDocument(index),
                      icon: const Icon(
                        Icons.delete_outline,
                        size: 16,
                        color: Color(0xFFEF4444),
                      ),
                      label: Text(
                        'Supprimer ce document',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFEF4444),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: const Color(0xFFE2E8F0))),
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: _isSaving ? null : _handleSave,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1FBF9A),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isSaving)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                else
                  const Icon(Icons.save, size: 20),
                const SizedBox(width: 8),
                Text(
                  _isSaving
                      ? 'Enregistrement...'
                      : 'Enregistrer les Modifications',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
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

/// A field message under a field, in the theme's input error style.
class _FieldError extends StatelessWidget {
  const _FieldError(this.message);

  final String message;

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
