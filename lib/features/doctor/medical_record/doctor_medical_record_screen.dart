import 'package:flutter/material.dart';

import '../../../core/theme/omni_theme.dart';
import '../../patient_passport/models/patient_passport_view_models.dart';
import '../../patient_passport/presentation/widgets/passport_card.dart';
import '../../patient_passport/presentation/widgets/passport_essential_info_card.dart';
import '../../patient_passport/presentation/widgets/passport_history_filter_sheet.dart';
import '../../patient_passport/presentation/widgets/passport_measurements_card.dart';
import '../../patient_passport/presentation/widgets/passport_medications_card.dart';
import '../../patient_passport/presentation/widgets/passport_segmented_nav.dart';
import 'doctor_medical_record_access.dart';

/// Focused, read-only Doctor view of a patient passport for a D6 care event.
///
/// It intentionally has no Doctor bottom navigation and exposes no Patient
/// editing, sharing, family-selection, or document-management controls.
class DoctorMedicalRecordScreen extends StatefulWidget {
  const DoctorMedicalRecordScreen({
    super.key,
    required this.access,
    this.embedded = false,
    this.onBack,
  });

  final DoctorMedicalRecordAccess access;
  final bool embedded;
  final VoidCallback? onBack;

  @override
  State<DoctorMedicalRecordScreen> createState() =>
      _DoctorMedicalRecordScreenState();
}

class _DoctorMedicalRecordScreenState extends State<DoctorMedicalRecordScreen> {
  final ScrollController _scrollController = ScrollController();
  PassportSection _section = PassportSection.summary;
  MedicationGroup _medicationGroup = MedicationGroup.current;
  PassportHistoryFilters _historyFilters = const PassportHistoryFilters();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _selectSection(PassportSection section) {
    if (_section == section) return;
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }
    setState(() => _section = section);
  }

  void _continueConsultation() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => const Padding(
        padding: EdgeInsets.fromLTRB(24, 4, 24, 32),
        child: Text('La consultation sera ajoutée à l’étape suivante.'),
      ),
    );
  }

  Future<void> _openHistoryFilters() async {
    final filters = await showPassportHistoryFilterSheet(
      context,
      initialFilters: _historyFilters,
    );
    if (!mounted || filters == null) return;
    setState(() => _historyFilters = filters);
  }

  List<PassportConsultation> get _filteredConsultations {
    final filters = _historyFilters;
    return widget.access.passport.consultations
        .where((consultation) {
          final statusMatches =
              filters.status == 'Tous' ||
              (filters.status == 'Terminée' &&
                  consultation.status ==
                      PassportConsultationStatus.completed) ||
              (filters.status == 'Annulée' &&
                  consultation.status == PassportConsultationStatus.cancelled);
          final doctorMatches =
              filters.doctor == 'Tous les médecins' ||
              consultation.doctor == filters.doctor;
          final sharingMatches =
              filters.sharing == 'Tous' ||
              (filters.sharing == 'Partageables' && consultation.isShareable) ||
              (filters.sharing == 'Privées' && !consultation.isShareable);
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
              doctorMatches &&
              sharingMatches &&
              specialtyMatches &&
              yearMatches &&
              monthMatches;
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final content = _content();
    if (widget.embedded) return content;
    return Scaffold(
      backgroundColor: OmniColors.pageBackground,
      appBar: AppBar(
        title: const Text('Dossier médical'),
        leading: IconButton(
          tooltip: 'Retour',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: SafeArea(top: false, child: content),
    );
  }

  Widget _content() => SingleChildScrollView(
    controller: _scrollController,
    padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.embedded) ...[
              _ContextNavigationRow(
                title: 'Dossier médical',
                onBack: widget.onBack!,
              ),
              const SizedBox(height: 12),
            ],
            _AccessBanner(access: widget.access),
            const SizedBox(height: 16),
            _DoctorRecordSectionNav(
              selectedSection: _section,
              onChanged: _selectSection,
            ),
            const SizedBox(height: 18),
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                reverseDuration: const Duration(milliseconds: 160),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                layoutBuilder: (currentChild, previousChildren) =>
                    currentChild ?? const SizedBox.shrink(),
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                  child: child,
                ),
                child: KeyedSubtree(
                  key: ValueKey<PassportSection>(_section),
                  child: _sectionContent(),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _continueConsultation,
                child: const Text('Continuer la consultation'),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _sectionContent() => switch (_section) {
    PassportSection.summary => _SummarySection(
      access: widget.access,
      medicationGroup: _medicationGroup,
      onMedicationGroupChanged: (group) =>
          setState(() => _medicationGroup = group),
    ),
    PassportSection.history =>
      widget.access.summariesShared
          ? _DoctorHistorySection(
              consultations: _filteredConsultations,
              onOpenFilters: _openHistoryFilters,
              canonical: widget.access.canonical,
            )
          : const _NotSharedCard(
              label: 'Historique non partagé par le patient',
            ),
    PassportSection.documents =>
      widget.access.canonical
          ? const _NotSharedCard(
              label:
                  'Consultation sécurisée des documents prévue au jalon P5-17',
            )
          : widget.access.hasFullPassport
          ? _DocumentsSection(documents: widget.access.documents)
          : const _NotSharedCard(
              label: 'Documents non partagés par le patient',
            ),
  };
}

class _ContextNavigationRow extends StatelessWidget {
  const _ContextNavigationRow({required this.title, required this.onBack});

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      IconButton(
        tooltip: 'Retour',
        onPressed: onBack,
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      const SizedBox(width: 4),
      Expanded(
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
    ],
  );
}

class _DoctorHistorySection extends StatelessWidget {
  const _DoctorHistorySection({
    required this.consultations,
    required this.onOpenFilters,
    required this.canonical,
  });

  final List<PassportConsultation> consultations;
  final VoidCallback onOpenFilters;
  final bool canonical;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Historique des consultations',
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 5),
      Text(
        'Consultations partagées pour cette prise en charge.',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: OmniColors.textSecondary),
      ),
      const SizedBox(height: 14),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: onOpenFilters,
          icon: const Icon(Icons.tune_rounded, size: 18),
          label: const Text('Filtrer'),
        ),
      ),
      const SizedBox(height: 4),
      if (consultations.isEmpty)
        const PassportCard(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: Text('Aucune consultation trouvée.')),
          ),
        )
      else
        ...consultations.map(
          (consultation) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _DoctorConsultationCard(
              consultation: consultation,
              canonical: canonical,
            ),
          ),
        ),
    ],
  );
}

class _DoctorConsultationCard extends StatelessWidget {
  const _DoctorConsultationCard({
    required this.consultation,
    required this.canonical,
  });

  final PassportConsultation consultation;
  final bool canonical;

  void _showDetails(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * .78,
        ),
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [OmniColors.shadowCard],
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              OmniSpacing.xl,
              OmniSpacing.base,
              OmniSpacing.xl,
              MediaQuery.paddingOf(sheetContext).bottom + OmniSpacing.xl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: OmniColors.borderStrong,
                      borderRadius: BorderRadius.circular(OmniRadii.pill),
                    ),
                  ),
                ),
                const SizedBox(height: OmniSpacing.base),
                Text(
                  'Détail de la consultation',
                  style: Theme.of(
                    sheetContext,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: OmniSpacing.base),
                Wrap(
                  spacing: OmniSpacing.lg,
                  runSpacing: OmniSpacing.md,
                  children: [
                    _ConsultationMetadata(
                      icon: Icons.calendar_month_outlined,
                      label: consultation.date,
                    ),
                    _ConsultationMetadata(
                      icon: Icons.medical_services_outlined,
                      label: consultation.doctorType,
                    ),
                  ],
                ),
                const SizedBox(height: OmniSpacing.lg),
                const Divider(height: 1),
                const SizedBox(height: OmniSpacing.xl),
                _ConsultationDetailSection(
                  title: 'Motif',
                  child: Text(
                    consultation.reason,
                    style: Theme.of(sheetContext).textTheme.bodyLarge?.copyWith(
                      color: OmniColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: OmniSpacing.xl),
                if (consultation.diagnosis.isNotEmpty)
                  _ConsultationDetailSection(
                    title: 'Diagnostic',
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(OmniSpacing.base),
                      decoration: BoxDecoration(
                        color: OmniColors.mintSoft,
                        borderRadius: BorderRadius.circular(OmniRadii.card),
                        border: Border.all(color: OmniColors.borderLight),
                      ),
                      child: Text(
                        consultation.diagnosis,
                        style: Theme.of(sheetContext).textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                if (consultation.assessment != null) ...[
                  const SizedBox(height: OmniSpacing.xl),
                  _ConsultationDetailSection(
                    title: 'Évaluation',
                    child: Text(consultation.assessment!),
                  ),
                ],
                if (consultation.treatmentPlan.isNotEmpty) ...[
                  const SizedBox(height: OmniSpacing.xl),
                  _ConsultationDetailSection(
                    title: 'Traitement',
                    child: Text(consultation.treatmentPlan.join(', ')),
                  ),
                ],
                if (consultation.notes != null) ...[
                  const SizedBox(height: OmniSpacing.xl),
                  _ConsultationDetailSection(
                    title: 'Notes',
                    child: Text(consultation.notes!),
                  ),
                ],
                if (!canonical) ...[
                  const SizedBox(height: OmniSpacing.xl),
                  _ConsultationDetailSection(
                    title: 'Médicaments',
                    child: consultation.medications.isEmpty
                        ? Text(
                            'Aucun médicament prescrit',
                            style: Theme.of(sheetContext).textTheme.bodyMedium
                                ?.copyWith(color: OmniColors.textSecondary),
                          )
                        : Column(
                            children: consultation.medications
                                .map(
                                  (medication) => Padding(
                                    padding: const EdgeInsets.only(
                                      bottom: OmniSpacing.md,
                                    ),
                                    child: _ConsultationMedicationRow(
                                      medication: medication,
                                    ),
                                  ),
                                )
                                .toList(growable: false),
                          ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cancelled =
        consultation.status == PassportConsultationStatus.cancelled;
    final accent = cancelled ? OmniColors.error : OmniColors.primaryAction;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showDetails(context),
        borderRadius: BorderRadius.circular(OmniRadii.card),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cancelled ? OmniColors.errorSoft : Colors.white,
            borderRadius: BorderRadius.circular(OmniRadii.card),
            border: Border.all(
              color: cancelled
                  ? OmniColors.error.withValues(alpha: .28)
                  : OmniColors.borderLight,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: cancelled ? OmniColors.errorSoft : OmniColors.mintSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.calendar_month_outlined,
                  color: accent,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      consultation.date,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: OmniColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      consultation.reason,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      consultation.doctorType,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: OmniColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.keyboard_arrow_right_rounded,
                color: OmniColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConsultationMetadata extends StatelessWidget {
  const _ConsultationMetadata({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 18, color: OmniColors.primaryAction),
      const SizedBox(width: OmniSpacing.sm),
      ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 220),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: OmniColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    ],
  );
}

class _ConsultationDetailSection extends StatelessWidget {
  const _ConsultationDetailSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
          color: OmniColors.textSecondary,
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: OmniSpacing.md),
      child,
    ],
  );
}

class _ConsultationMedicationRow extends StatelessWidget {
  const _ConsultationMedicationRow({required this.medication});

  final PassportConsultationMedication medication;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(OmniSpacing.base),
    decoration: BoxDecoration(
      border: Border.all(color: OmniColors.borderLight),
      borderRadius: BorderRadius.circular(OmniRadii.card),
    ),
    child: Row(
      children: [
        Container(
          height: 36,
          width: 36,
          decoration: BoxDecoration(
            color: OmniColors.infoBlueSoft,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.medication_outlined,
            size: 19,
            color: OmniColors.infoBlue,
          ),
        ),
        const SizedBox(width: OmniSpacing.md),
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
              const SizedBox(height: OmniSpacing.xs + 2),
              Text(
                medication.instruction,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: OmniColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Keeps the Patient Passport navigation unchanged while retaining readable
/// labels in the Doctor's 320dp content width on compact phones.
class _DoctorRecordSectionNav extends StatelessWidget {
  const _DoctorRecordSectionNav({
    required this.selectedSection,
    required this.onChanged,
  });

  final PassportSection selectedSection;
  final ValueChanged<PassportSection> onChanged;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth >= 340) {
        return PassportSegmentedNav(
          selectedSection: selectedSection,
          onChanged: onChanged,
        );
      }
      return Container(
        height: 48,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: OmniColors.slateSoft,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            _CompactRecordSegment(
              label: 'Résumé',
              selected: selectedSection == PassportSection.summary,
              onTap: () => onChanged(PassportSection.summary),
            ),
            _CompactRecordSegment(
              label: 'Historique',
              selected: selectedSection == PassportSection.history,
              onTap: () => onChanged(PassportSection.history),
            ),
            _CompactRecordSegment(
              label: 'Documents',
              selected: selectedSection == PassportSection.documents,
              onTap: () => onChanged(PassportSection.documents),
            ),
          ],
        ),
      );
    },
  );
}

class _CompactRecordSegment extends StatelessWidget {
  const _CompactRecordSegment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Semantics(
      button: true,
      selected: selected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: selected ? const [OmniColors.shadowSm] : null,
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: selected
                  ? OmniColors.primaryAction
                  : OmniColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    ),
  );
}

class _AccessBanner extends StatelessWidget {
  const _AccessBanner({required this.access});

  final DoctorMedicalRecordAccess access;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: OmniColors.mintSoft,
      borderRadius: BorderRadius.circular(OmniRadii.cardLarge),
      border: Border.all(color: OmniColors.freshMint.withValues(alpha: .32)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: Colors.white,
              child: Text(
                access.patientName
                    .split(' ')
                    .where((part) => part.isNotEmpty)
                    .take(2)
                    .map((part) => part[0])
                    .join(),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: OmniColors.deepTeal,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    access.canonical
                        ? 'Dossier Patient autorisé'
                        : '${access.patientName} · ${access.patientAge} ans',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    access.canonical
                        ? access.sourceLabel
                        : '${access.sourceLabel} · ${access.requestId}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: OmniColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const Row(
          children: [
            Icon(
              Icons.verified_user_outlined,
              size: 18,
              color: OmniColors.deepTeal,
            ),
            SizedBox(width: 8),
            Expanded(child: Text('Accès médical autorisé')),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          access.hasFullPassport
              ? 'Accès temporaire pour cette consultation.'
              : 'Accès limité aux informations vitales pour cette consultation.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: OmniColors.deepTeal,
            height: 1.35,
          ),
        ),
      ],
    ),
  );
}

class _SummarySection extends StatelessWidget {
  const _SummarySection({
    required this.access,
    required this.medicationGroup,
    required this.onMedicationGroupChanged,
  });

  final DoctorMedicalRecordAccess access;
  final MedicationGroup medicationGroup;
  final ValueChanged<MedicationGroup> onMedicationGroupChanged;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      if (access.hasFullPassport) ...[
        if (access.essentialShared)
          PassportEssentialInfoCard(data: access.passport)
        else
          const _NotSharedCard(
            label: 'Informations essentielles non partagées',
          ),
        const SizedBox(height: 12),
        if (access.medicationsShared)
          PassportMedicationsCard(
            selectedGroup: medicationGroup,
            medications: access.passport.medicationsFor(medicationGroup),
            onGroupChanged: onMedicationGroupChanged,
          )
        else
          const _NotSharedCard(label: 'Médicaments actuels non partagés'),
        if (!access.canonical) ...[
          const SizedBox(height: 12),
          PassportMeasurementsCard(
            heightCm: access.passport.heightCm,
            weightKg: access.passport.weightKg,
          ),
        ],
      ] else
        _LifeSafetyCard(access: access),
      if (!access.canonical) ...[
        const SizedBox(height: 12),
        _TriageCard(summary: access.triageSummary),
      ],
    ],
  );
}

class _LifeSafetyCard extends StatelessWidget {
  const _LifeSafetyCard({required this.access});

  final DoctorMedicalRecordAccess access;

  @override
  Widget build(BuildContext context) => PassportCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PassportSectionHeading(
          icon: Icons.health_and_safety_outlined,
          title: 'Informations vitales',
          subtitle: 'Informations partagées pour la prise en charge urgente',
          iconColor: OmniColors.clinicalCyan,
          iconBackground: OmniColors.clinicalCyanSoft,
        ),
        const SizedBox(height: 18),
        _SafetyRow(
          icon: Icons.bloodtype_outlined,
          label: 'Groupe sanguin',
          value: access.passport.bloodGroup,
          color: OmniColors.error,
          background: OmniColors.errorSoft,
        ),
        const Divider(height: 24),
        _SafetyRow(
          icon: Icons.warning_amber_rounded,
          label: 'Allergies et réactions',
          value: access.passport.allergies,
          color: OmniColors.amber,
          background: OmniColors.amberSoft,
        ),
      ],
    ),
  );
}

class _SafetyRow extends StatelessWidget {
  const _SafetyRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.background,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        height: 38,
        width: 38,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: OmniColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    ],
  );
}

class _TriageCard extends StatelessWidget {
  const _TriageCard({required this.summary});

  final String summary;

  @override
  Widget build(BuildContext context) => PassportCard(
    color: OmniColors.urgentCoralSoft,
    border: Border.all(color: OmniColors.urgentCoral.withValues(alpha: .2)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PassportSectionHeading(
          icon: Icons.emergency_outlined,
          title: 'Contexte urgent',
          subtitle: 'Informations de triage de cette intervention',
          iconColor: OmniColors.urgentCoral,
          iconBackground: Colors.white,
        ),
        const SizedBox(height: 14),
        Text(
          summary,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
            height: 1.4,
          ),
        ),
      ],
    ),
  );
}

class _NotSharedCard extends StatelessWidget {
  const _NotSharedCard({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => PassportCard(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
    border: Border.all(color: OmniColors.borderLight),
    child: Column(
      children: [
        Container(
          height: 50,
          width: 50,
          decoration: const BoxDecoration(
            color: OmniColors.slateSoft,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.lock_outline_rounded,
            color: OmniColors.slateBlue,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          'Non partagé par le patient',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: OmniColors.textSecondary),
        ),
      ],
    ),
  );
}

class _DocumentsSection extends StatelessWidget {
  const _DocumentsSection({required this.documents});

  final List<DoctorMedicalRecordDocument> documents;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Documents médicaux',
        style: Theme.of(
          context,
        ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 4),
      Text(
        '${documents.length} documents partagés',
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: OmniColors.textSecondary),
      ),
      const SizedBox(height: 18),
      ...documents.map(
        (document) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: PassportCard(
            child: Row(
              children: [
                Container(
                  height: 40,
                  width: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: OmniColors.violetSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    document.icon,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: OmniColors.violet,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        document.title,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        document.detail,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: OmniColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Aperçu du document',
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    showDragHandle: true,
                    builder: (_) => Padding(
                      padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
                      child: Text(
                        '${document.title}\n\nAperçu en lecture seule disponible dans cette démo.',
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.visibility_outlined),
                ),
              ],
            ),
          ),
        ),
      ),
    ],
  );
}
