import 'package:flutter/material.dart';

import '../../../core/theme/omni_theme.dart';
import '../../home/qr_code_modal.dart';
import '../data/patient_passport_static_data.dart';
import '../models/patient_passport_view_models.dart';
import 'medical_data_editor_screen.dart';
import 'medical_document_editor_screen.dart';
import 'widgets/family_passport_selector_sheet.dart';
import 'widgets/passport_documents_tab.dart';
import 'widgets/passport_essential_info_card.dart';
import 'widgets/passport_header.dart';
import 'widgets/passport_history_filter_sheet.dart';
import 'widgets/passport_history_tab.dart';
import 'widgets/passport_identity_card.dart';
import 'widgets/passport_measurements_card.dart';
import 'widgets/passport_medications_card.dart';
import 'widgets/passport_segmented_nav.dart';
import 'widgets/passport_card.dart';

class PatientPassportScreen extends StatefulWidget {
  const PatientPassportScreen({super.key});

  @override
  State<PatientPassportScreen> createState() => _PatientPassportScreenState();
}

class _PatientPassportScreenState extends State<PatientPassportScreen> {
  PatientPassportViewData _data = PatientPassportStaticData.current;
  final ScrollController _passportScrollController = ScrollController();
  PassportSection _selectedSection = PassportSection.summary;
  MedicationGroup _medicationGroup = MedicationGroup.current;
  late PassportFamilyMember _selectedMember;
  PassportHistoryFilters _historyFilters = const PassportHistoryFilters();

  @override
  void initState() {
    super.initState();
    _selectedMember = _data.familyMembers.first;
  }

  @override
  void dispose() {
    _passportScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: OmniColors.slateSoft,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            controller: _passportScrollController,
            padding: const EdgeInsets.fromLTRB(
              OmniSpacing.pageHorizontal,
              12,
              OmniSpacing.pageHorizontal,
              32,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: _buildPassportContent(context, constraints.maxWidth),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPassportContent(BuildContext context, double availableWidth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PassportHeader(
          selectedMember: _selectedMember,
          onSelectPassport: _openFamilySelector,
          onEdit: _openMedicalDataEditor,
          onShare: _showShareDialog,
        ),
        const SizedBox(height: 12),
        PassportSegmentedNav(
          selectedSection: _selectedSection,
          onChanged: _selectSection,
        ),
        const SizedBox(height: 18),
        _buildAnimatedSection(context, availableWidth),
      ],
    );
  }

  Widget _buildAnimatedSection(BuildContext context, double availableWidth) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        reverseDuration: const Duration(milliseconds: 160),
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
        child: KeyedSubtree(
          key: ValueKey<PassportSection>(_selectedSection),
          child: _buildSectionContent(context, availableWidth),
        ),
      ),
    );
  }

  Widget _buildSectionContent(BuildContext context, double availableWidth) {
    return switch (_selectedSection) {
      PassportSection.summary => _buildSummary(context, availableWidth),
      PassportSection.history => PassportHistoryTab(
        consultations: _filteredConsultations,
        onOpenFilters: _openHistoryFilters,
      ),
      PassportSection.documents => PassportDocumentsTab(
        onAddDocument: _openDocumentEditor,
      ),
    };
  }

  void _selectSection(PassportSection section) {
    if (_selectedSection == section) return;
    if (_passportScrollController.hasClients) {
      _passportScrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }
    setState(() => _selectedSection = section);
  }

  Widget _buildSummary(BuildContext context, double availableWidth) {
    return Column(
      children: [
        PassportIdentityCard(data: _displayedData),
        const SizedBox(height: 12),
        PassportEssentialInfoCard(data: _displayedData),
        const SizedBox(height: 12),
        PassportMedicationsCard(
          selectedGroup: _medicationGroup,
          medications: _data.medicationsFor(_medicationGroup),
          onGroupChanged: (group) => setState(() => _medicationGroup = group),
        ),
        const SizedBox(height: 12),
        PassportMeasurementsCard(
          heightCm: _data.heightCm,
          weightKg: _data.weightKg,
        ),
        const SizedBox(height: 18),
        const PassportPrivacyNote(),
      ],
    );
  }

  PatientPassportViewData get _displayedData {
    return PatientPassportViewData(
      name: _selectedMember.name,
      relationship: _selectedMember.relationship,
      phone: _data.phone,
      email: _data.email,
      omniCareId: _data.omniCareId,
      bloodGroup: _data.bloodGroup,
      allergies: _data.allergies,
      chronicConditions: _data.chronicConditions,
      medications: _data.medications,
      consultations: _data.consultations,
      familyMembers: _data.familyMembers,
      heightCm: _data.heightCm,
      weightKg: _data.weightKg,
    );
  }

  List<PassportConsultation> get _filteredConsultations {
    final filters = _historyFilters;
    return _data.consultations
        .where((consultation) {
          final statusMatches =
              filters.status == 'Tous' ||
              (filters.status == 'Terminée' &&
                  consultation.status ==
                      PassportConsultationStatus.completed) ||
              (filters.status == 'Annulée' &&
                  consultation.status == PassportConsultationStatus.cancelled);
          final sharingMatches =
              filters.sharing == 'Tous' ||
              (filters.sharing == 'Partageables' && consultation.isShareable) ||
              (filters.sharing == 'Privées' && !consultation.isShareable);
          final doctorMatches =
              filters.doctor == 'Tous les médecins' ||
              consultation.doctor == filters.doctor;
          final specialtyMatches =
              filters.specialty == 'Toutes les spécialités' ||
              consultation.specialty == filters.specialty;
          final yearMatches =
              filters.year == 'Toutes les années' ||
              consultation.date.contains(filters.year);
          final monthMatches =
              filters.month == 'Tous les Mois' ||
              consultation.date.toLowerCase().contains(
                filters.month.substring(0, 3).toLowerCase(),
              );
          return statusMatches &&
              sharingMatches &&
              doctorMatches &&
              specialtyMatches &&
              yearMatches &&
              monthMatches;
        })
        .toList(growable: false);
  }

  Future<void> _openFamilySelector() async {
    final selected = await showFamilyPassportSelector(
      context,
      familyMembers: _data.familyMembers,
      selectedName: _selectedMember.name,
    );
    if (!mounted || selected == null) return;
    setState(() => _selectedMember = selected);
  }

  Future<void> _openHistoryFilters() async {
    final result = await showPassportHistoryFilterSheet(
      context,
      initialFilters: _historyFilters,
    );
    if (!mounted || result == null) return;
    setState(() => _historyFilters = result);
  }

  Future<void> _openDocumentEditor() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            MedicalDocumentEditorScreen(patientName: _selectedMember.name),
      ),
    );
  }

  Future<void> _openMedicalDataEditor() async {
    final updatedData = await Navigator.of(context)
        .push<PatientPassportViewData>(
          MaterialPageRoute(
            builder: (_) =>
                MedicalDataEditorScreen(initialData: _displayedData),
          ),
        );
    if (!mounted || updatedData == null) return;
    setState(() {
      _data = updatedData;
      _selectedSection = PassportSection.summary;
      _medicationGroup = MedicationGroup.current;
    });
  }

  void _showShareDialog() {
    showDialog<void>(
      context: context,
      builder: (_) => QRCodeModal(
        patientName: _selectedMember.name,
        patientId: _data.omniCareId,
      ),
    );
  }
}
