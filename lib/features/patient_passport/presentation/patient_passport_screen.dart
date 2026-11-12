import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/platform/secure_screen.dart';
import '../../../core/theme/omni_theme.dart';
import '../../../l10n/omni_localizations.dart';
import '../../../providers/family_provider.dart';
import '../../../providers/user_provider.dart';
import '../../home/qr_code_modal.dart';
import '../application/medical_record_view_model.dart';
import '../application/passport_identity.dart';
import '../data/medical_record_models.dart';
import '../models/patient_passport_view_models.dart';
import '../sharing/medical_sharing_controller.dart';
import '../sharing/medical_sharing_models.dart';
import '../sharing/direct_patient_authorization_controller.dart';
import 'medical_document_editor_screen.dart';
import 'medical_record_presenter.dart';
import 'widgets/family_passport_selector_sheet.dart';
import 'widgets/passport_documents_tab.dart';
import 'widgets/passport_essential_info_card.dart';
import 'widgets/passport_header.dart';
import 'widgets/passport_history_filter_sheet.dart';
import 'widgets/passport_history_tab.dart';
import 'widgets/passport_identity_card.dart';
import 'widgets/medical_sharing_settings_sheet.dart';
import 'widgets/passport_measurements_card.dart';
import 'widgets/passport_medications_card.dart';
import 'widgets/passport_segmented_nav.dart';
import 'widgets/passport_card.dart';

/// « Dossier médical » (G-2 FT-3, G2.1-S1). The header, the identity card and
/// G-1's sharing and secure-QR actions come from the real profile and family;
/// the medical cards are bound to `/api/v1/me/medical-record/*`, each with its
/// own loading, failure and retry. Screenshots are blocked while it is shown.
class PatientPassportScreen extends StatefulWidget {
  const PatientPassportScreen({super.key, this.medicalSharingController});

  final MedicalSharingController? medicalSharingController;

  @override
  State<PatientPassportScreen> createState() => _PatientPassportScreenState();
}

class _PatientPassportScreenState extends State<PatientPassportScreen> {
  final ScrollController _passportScrollController = ScrollController();
  PassportSection _selectedSection = PassportSection.summary;
  MedicationGroup _medicationGroup = MedicationGroup.current;

  /// The family member on screen; null is the account holder.
  String? _selectedFamilyMemberId;
  PassportHistoryFilters _historyFilters = const PassportHistoryFilters();
  MedicalSharingController? _sharingController;
  DirectPatientAuthorizationController? _directAuthorizationController;
  FamilyProvider? _familyProvider;
  UserProvider? _userProvider;
  MedicalRecordViewModel? _record;
  Listenable? _sources;
  bool _dependenciesResolved = false;

  @override
  void initState() {
    super.initState();
    SecureScreen.enable();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dependenciesResolved) return;
    _dependenciesResolved = true;
    _sharingController = widget.medicalSharingController;
    try {
      _sharingController ??= context.read<MedicalSharingController>();
    } catch (_) {
      // Standalone visual tests may intentionally omit the production provider.
    }
    try {
      _directAuthorizationController = context
          .read<DirectPatientAuthorizationController>();
    } catch (_) {
      // Standalone visual tests may intentionally omit the production provider.
    }
    try {
      _familyProvider = context.read<FamilyProvider>();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _familyProvider?.loadFamilyMembers();
      });
    } catch (_) {
      // Outside the authenticated shell the holder is shown alone.
    }
    try {
      _userProvider = context.read<UserProvider>();
    } catch (_) {
      // Outside the authenticated shell the identity reads « Non renseigné ».
    }
    try {
      _record = context.read<MedicalRecordViewModel>();
    } catch (_) {
      // No record source: the cards stay in their loading state.
    }
    _sources = Listenable.merge([?_familyProvider, ?_userProvider, ?_record]);
  }

  @override
  void dispose() {
    SecureScreen.disable();
    _passportScrollController.dispose();
    super.dispose();
  }

  List<PassportFamilyMember> get _members => passportMembers(
    profile: _userProvider?.profile,
    family: _familyProvider?.members ?? const [],
    l10n: OmniLocalizations.of(context),
  );

  PassportFamilyMember get _selectedMember =>
      selectedPassportMember(_members, _selectedFamilyMemberId);

  /// Asks the record for the subject on screen. A no-op when it already holds
  /// that subject.
  void _syncRecordSubject() {
    final record = _record;
    if (record == null) return;
    final subject = recordSubjectOf(_selectedMember);
    if (record.subject == subject) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) record.show(subject);
    });
  }

  @override
  Widget build(BuildContext context) {
    final sources = _sources;
    return sources == null
        ? _buildPage(context)
        : ListenableBuilder(
            listenable: sources,
            builder: (context, _) => _buildPage(context),
          );
  }

  Widget _buildPage(BuildContext context) {
    _syncRecordSubject();
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
    // The edit pencil stays hidden until the editor is wired to the record
    // (G2-FT-3 decision 4; a later G-2.1 step).
    final header = PassportHeader(
      selectedMember: _selectedMember,
      onSelectPassport: _openFamilySelector,
      onShare: _showShareDialog,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        header,
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

  Widget _buildIdentityCard() => PassportIdentityCard(
    data: passportIdentity(
      member: _selectedMember,
      profile: _userProvider?.profile,
      l10n: OmniLocalizations.of(context),
    ),
    onShowSecureQr: _selectedMedicalSharingSubject == null
        ? null
        : _openSecureQr,
  );

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
      PassportSection.history => _buildHistory(),
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
    if (section == PassportSection.history) {
      _record?.ensureLoaded(MedicalRecordSection.consultations);
    }
  }

  /// The record state of [state] for the subject on screen: while the record
  /// still holds another subject, every card shows its loading state.
  SectionState<T> _onScreen<T>(SectionState<T> state) {
    final record = _record;
    if (record == null || record.subject != recordSubjectOf(_selectedMember)) {
      return const SectionLoading();
    }
    return state;
  }

  Widget _buildSummary(BuildContext context, double availableWidth) {
    final l10n = OmniLocalizations.of(context);
    final record = _record;
    final identity = passportIdentity(
      member: _selectedMember,
      profile: _userProvider?.profile,
      l10n: l10n,
    );
    final medicalData = _onScreen(record?.medicalData ?? const SectionIdle());
    final isCurrent = _medicationGroup == MedicationGroup.current;
    final medications = _onScreen(
      record?.medications(current: isCurrent) ?? const SectionIdle(),
    );
    final medicalStatus = cardStatus(
      medicalData,
      l10n,
      () => record?.retry(MedicalRecordSection.medicalData),
    );
    final medicalValue = medicalData is SectionReady<MedicalDataRecord>
        ? medicalData.value
        : null;
    final medicationPage =
        medications is SectionReady<RecordPage<MedicationRecord>>
        ? medications.value
        : null;
    return Column(
      children: [
        _buildIdentityCard(),
        const SizedBox(height: 12),
        PassportEssentialInfoCard(
          data: medicalValue == null
              ? identity
              : identity.copyWith(
                  bloodGroup: bloodTypeText(medicalValue, l10n),
                  allergies: allergiesText(medicalValue, l10n),
                  chronicConditions: conditionChips(medicalValue),
                ),
          conditionsText: medicalValue == null
              ? null
              : conditionsText(medicalValue, l10n),
          status: medicalStatus,
        ),
        const SizedBox(height: 12),
        PassportMedicationsCard(
          selectedGroup: _medicationGroup,
          medications: [
            for (final item
                in medicationPage?.items ?? const <MedicationRecord>[])
              passportMedication(item, current: isCurrent, l10n: l10n),
          ],
          hasMore: medicationPage?.hasMore ?? false,
          emptyText: medicationsEmptyText(current: isCurrent, l10n: l10n),
          status: cardStatus(
            medications,
            l10n,
            () => record?.retry(
              isCurrent
                  ? MedicalRecordSection.currentMedications
                  : MedicalRecordSection.pastMedications,
            ),
          ),
          onGroupChanged: _selectMedicationGroup,
        ),
        const SizedBox(height: 12),
        PassportMeasurementsCard(
          heightCm: medicalValue?.heightCm,
          weightKg: medicalValue?.weightKg,
          bmi: medicalValue?.bmi,
          status: medicalStatus,
        ),
        const SizedBox(height: 18),
        const PassportPrivacyNote(),
      ],
    );
  }

  void _selectMedicationGroup(MedicationGroup group) {
    setState(() => _medicationGroup = group);
    if (group == MedicationGroup.previous) {
      _record?.ensureLoaded(MedicalRecordSection.pastMedications);
    }
  }

  Widget _buildHistory() {
    final l10n = OmniLocalizations.of(context);
    final record = _record;
    final state = _onScreen(record?.consultations ?? const SectionIdle());
    final page = state is SectionReady<RecordPage<ConsultationRecord>>
        ? state.value
        : null;
    return PassportHistoryTab(
      consultations: _filtered([
        for (final item in page?.items ?? const <ConsultationRecord>[])
          passportConsultation(item, l10n),
      ]),
      onOpenFilters: _openHistoryFilters,
      onToggleSharing: _toggleConsultationSharing,
      status: cardStatus(
        state,
        l10n,
        () => record?.retry(MedicalRecordSection.consultations),
      ),
    );
  }

  /// The history filters, applied to the loaded first page only.
  List<PassportConsultation> _filtered(
    List<PassportConsultation> consultations,
  ) {
    final filters = _historyFilters;
    return consultations
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
      familyMembers: _members,
      selectedName: _selectedMember.name,
    );
    if (!mounted || selected == null) return;
    setState(() {
      _selectedFamilyMemberId = selected.isSelf
          ? null
          : selected.familyMemberId;
      _medicationGroup = MedicationGroup.current;
    });
  }

  Future<void> _openHistoryFilters() async {
    final result = await showPassportHistoryFilterSheet(
      context,
      initialFilters: _historyFilters,
    );
    if (!mounted || result == null) return;
    setState(() => _historyFilters = result);
  }

  Future<void> _toggleConsultationSharing(
    PassportConsultation consultation,
  ) async {
    final controller = _sharingController;
    final consultationId = consultation.consultationId;
    final version = consultation.sharingVersion;
    if (controller == null || consultationId == null || version == null) return;
    final subject = _selectedMedicalSharingSubject;
    if (subject == null) return;
    await controller.selectSubject(subject);
    final canonical = await controller.updateConsultationSharing(
      consultationId: consultationId,
      expectedVersion: version,
      currentState: consultation.isShareable
          ? ConsultationSharingState.shareable
          : ConsultationSharingState.locked,
      desiredState: consultation.isShareable
          ? ConsultationSharingState.locked
          : ConsultationSharingState.shareable,
    );
    if (!mounted || canonical == null) return;
    _record?.applyConsultationSharing(
      consultationId: consultationId,
      isShareable: canonical.state == ConsultationSharingState.shareable,
      sharingVersion: canonical.version,
    );
  }

  Future<void> _openDocumentEditor() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            MedicalDocumentEditorScreen(patientName: _selectedMember.name),
      ),
    );
  }

  void _showShareDialog() {
    final controller = _sharingController;
    if (controller == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paramètres de partage indisponibles.')),
      );
      return;
    }
    final subject = _selectedMedicalSharingSubject;
    if (subject == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ce passeport familial n’est pas encore disponible.'),
        ),
      );
      return;
    }
    showMedicalSharingSettingsSheet(
      context,
      controller: controller,
      subject: subject,
      directAuthorizationController: _directAuthorizationController,
      subjectDisplayName: _selectedMember.name,
      onShowQr: () {
        Navigator.of(context).pop();
        WidgetsBinding.instance.addPostFrameCallback((_) => _openSecureQr());
      },
    );
  }

  MedicalSharingSubject? get _selectedMedicalSharingSubject {
    if (_selectedMember.isSelf) {
      return const MedicalSharingSubject.self();
    }
    final familyMemberId = _selectedMember.familyMemberId?.trim();
    if (familyMemberId == null || familyMemberId.isEmpty) return null;
    return MedicalSharingSubject.family(familyMemberId);
  }

  void _openSecureQr() {
    final subject = _selectedMedicalSharingSubject;
    if (subject == null) return;
    showDialog<void>(
      context: context,
      builder: (_) => QRCodeModal(
        patientName: _selectedMember.name,
        subject: subject,
        isFamilyMember: subject.type == MedicalSharingSubjectType.familyMember,
      ),
    );
  }
}
