import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/theme/omni_theme.dart';
import 'urgent_cabinet_arrival_instructions_screen.dart';
import 'urgent_cabinet_check_in_presentation.dart';
import 'urgent_cabinet_flow_controller.dart';
import 'urgent_cabinet_patient_lifecycle_controller.dart';
import 'urgent_cabinet_request_review.dart';
import 'urgent_cabinet_request_state.dart';
import 'urgent_cabinet_targeted_request_models.dart';

const bool _patientCheckInScenariosRequested = bool.fromEnvironment(
  'P4_PATIENT_CHECK_IN_SCENARIOS',
  defaultValue: false,
);

bool canOpenUrgentCabinetPatientQrPreview(
  UrgentCabinetFlowController flow, {
  UrgentCabinetRequestReview? expectedReview,
  String? expectedAuthoritativeRequestId,
  int? expectedAttemptGeneration,
  String? expectedAccountId,
}) {
  return canOpenUrgentCabinetArrivalInstructions(
    flow,
    expectedReview: expectedReview,
    expectedAuthoritativeRequestId: expectedAuthoritativeRequestId,
    expectedAttemptGeneration: expectedAttemptGeneration,
    expectedAccountId: expectedAccountId,
  );
}

@visibleForTesting
bool canShowUrgentCabinetPatientCheckInScenarios(
  UrgentCabinetFlowController flow, {
  required bool isDebugBuild,
  required bool flagEnabled,
  UrgentCabinetRequestReview? expectedReview,
  String? expectedAuthoritativeRequestId,
  int? expectedAttemptGeneration,
  String? expectedAccountId,
}) {
  return isDebugBuild &&
      flagEnabled &&
      canOpenUrgentCabinetPatientQrPreview(
        flow,
        expectedReview: expectedReview,
        expectedAuthoritativeRequestId: expectedAuthoritativeRequestId,
        expectedAttemptGeneration: expectedAttemptGeneration,
        expectedAccountId: expectedAccountId,
      );
}

class UrgentCabinetPatientQrPreviewScreen extends StatefulWidget {
  const UrgentCabinetPatientQrPreviewScreen({
    super.key,
    required this.review,
    required this.localAttemptGeneration,
    required this.accountId,
    this.authoritativeRequestId,
  });

  final UrgentCabinetRequestReview review;
  final int localAttemptGeneration;
  final String accountId;
  final String? authoritativeRequestId;

  @override
  State<UrgentCabinetPatientQrPreviewScreen> createState() =>
      _UrgentCabinetPatientQrPreviewScreenState();
}

class _UrgentCabinetPatientQrPreviewScreenState
    extends State<UrgentCabinetPatientQrPreviewScreen> {
  UrgentCabinetFlowController? _flow;
  bool _dismissScheduled = false;
  bool _scenariosExpanded = false;
  UrgentCabinetPatientCheckInPreviewState _selectedScenario =
      UrgentCabinetPatientCheckInPreviewState.ready;
  UrgentCabinetPatientCheckInPresentation? _visiblePresentation;
  bool _issueScheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final flow = context.read<UrgentCabinetFlowController>();
    if (!identical(_flow, flow)) {
      _flow?.removeListener(_handleAuthorityChanged);
      _flow = flow..addListener(_handleAuthorityChanged);
    }
    _handleAuthorityChanged();
    _scheduleAuthoritativeIssue(flow);
  }

  void _scheduleAuthoritativeIssue(UrgentCabinetFlowController flow) {
    final state = flow.requestState;
    final lifecycle = context.read<UrgentCabinetPatientLifecycleController?>();
    if (_issueScheduled ||
        state is! UrgentCabinetRequestAccepted ||
        !state.isAuthoritative ||
        lifecycle?.arrivalHandoff != null ||
        lifecycle?.canIssueArrivalHandoff != true) {
      return;
    }
    _issueScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !_isCurrent()) return;
      await lifecycle!.issueArrivalHandoff();
      if (mounted) setState(() {});
    });
  }

  bool _isCurrent() {
    final flow = _flow;
    return flow != null &&
        canOpenUrgentCabinetPatientQrPreview(
          flow,
          expectedReview: widget.review,
          expectedAuthoritativeRequestId: widget.authoritativeRequestId,
          expectedAttemptGeneration: widget.localAttemptGeneration,
          expectedAccountId: widget.accountId,
        );
  }

  bool _canShowScenarios() {
    final flow = _flow;
    return flow != null &&
        canShowUrgentCabinetPatientCheckInScenarios(
          flow,
          isDebugBuild: kDebugMode,
          flagEnabled: _patientCheckInScenariosRequested,
          expectedReview: widget.review,
          expectedAuthoritativeRequestId: widget.authoritativeRequestId,
          expectedAttemptGeneration: widget.localAttemptGeneration,
          expectedAccountId: widget.accountId,
        );
  }

  void _showSelectedScenario() {
    if (!_canShowScenarios()) return;
    setState(() {
      _visiblePresentation = UrgentCabinetPatientCheckInPresentation(
        _selectedScenario,
      );
    });
  }

  void _clearScenario() {
    if (_visiblePresentation == null) return;
    setState(() => _visiblePresentation = null);
  }

  void _handleAuthorityChanged() {
    if (!mounted || _isCurrent() || _dismissScheduled) return;
    _dismissScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _dismissScheduled = false;
      if (!mounted || _isCurrent()) return;
      Navigator.of(context).maybePop();
    });
  }

  @override
  void dispose() {
    _flow?.removeListener(_handleAuthorityChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lifecycle = context.watch<UrgentCabinetPatientLifecycleController?>();
    final authoritative =
        context.watch<UrgentCabinetFlowController>().requestState
            is UrgentCabinetRequestAccepted &&
        (context.watch<UrgentCabinetFlowController>().requestState
                as UrgentCabinetRequestAccepted)
            .isAuthoritative;
    return Scaffold(
      key: const ValueKey('urgent-cabinet-patient-qr-preview-screen'),
      backgroundColor: OmniColors.pageBackground,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          key: const ValueKey('urgent-cabinet-patient-qr-preview-back'),
          tooltip: "Retour aux instructions d'arrivée",
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('QR de présence'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: OmniColors.borderLight),
        ),
      ),
      body: SafeArea(
        top: false,
        child: _isCurrent()
            ? SingleChildScrollView(
                key: const PageStorageKey(
                  'urgent-cabinet-patient-qr-preview-scroll',
                ),
                padding: const EdgeInsets.fromLTRB(
                  OmniSpacing.pageHorizontal,
                  OmniSpacing.lg,
                  OmniSpacing.pageHorizontal,
                  OmniSpacing.xxl,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: _PatientQrPreviewContent(
                      review: widget.review,
                      authoritative: authoritative,
                      handoff: lifecycle?.arrivalHandoff,
                      issuing:
                          lifecycle?.phase ==
                          UrgentCabinetPatientLifecyclePhase
                              .issuingArrivalHandoff,
                      showDebugScenarios: _canShowScenarios(),
                      scenariosExpanded: _scenariosExpanded,
                      selectedScenario: _selectedScenario,
                      visiblePresentation: _visiblePresentation,
                      onScenariosExpandedChanged: (value) {
                        setState(() => _scenariosExpanded = value);
                      },
                      onScenarioSelected: (value) {
                        if (value == null) return;
                        setState(() => _selectedScenario = value);
                      },
                      onShowSelectedScenario: _showSelectedScenario,
                      onClearScenario: _clearScenario,
                    ),
                  ),
                ),
              )
            : const _PatientQrContextUnavailable(),
      ),
    );
  }
}

class _PatientQrPreviewContent extends StatelessWidget {
  const _PatientQrPreviewContent({
    required this.review,
    required this.authoritative,
    required this.handoff,
    required this.issuing,
    required this.showDebugScenarios,
    required this.scenariosExpanded,
    required this.selectedScenario,
    required this.visiblePresentation,
    required this.onScenariosExpandedChanged,
    required this.onScenarioSelected,
    required this.onShowSelectedScenario,
    required this.onClearScenario,
  });

  final UrgentCabinetRequestReview review;
  final bool authoritative;
  final UrgentCabinetArrivalHandoff? handoff;
  final bool issuing;
  final bool showDebugScenarios;
  final bool scenariosExpanded;
  final UrgentCabinetPatientCheckInPreviewState selectedScenario;
  final UrgentCabinetPatientCheckInPresentation? visiblePresentation;
  final ValueChanged<bool> onScenariosExpandedChanged;
  final ValueChanged<UrgentCabinetPatientCheckInPreviewState?>
  onScenarioSelected;
  final VoidCallback onShowSelectedScenario;
  final VoidCallback onClearScenario;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          authoritative ? 'Votre QR sécurisé' : 'Votre futur QR sécurisé',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: OmniColors.textPrimary,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: OmniSpacing.sm),
        Text(
          authoritative
              ? "Présentez ce code au médecin pour confirmer uniquement votre arrivée."
              : 'Ce visuel montre où votre code apparaîtra lorsque le service sécurisé sera disponible.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: OmniColors.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: OmniSpacing.lg),
        _AcceptedContextCard(review: review),
        const SizedBox(height: OmniSpacing.lg),
        if (handoff != null)
          _ScannableArrivalQr(handoff: handoff!)
        else if (authoritative)
          _ArrivalQrUnavailable(issuing: issuing)
        else
          const _NonScannablePreview(),
        const SizedBox(height: OmniSpacing.lg),
        const _PatientQrSecurityNotice(),
        if (showDebugScenarios) ...[
          const SizedBox(height: OmniSpacing.lg),
          _PatientCheckInScenarioSection(
            expanded: scenariosExpanded,
            selected: selectedScenario,
            onExpandedChanged: onScenariosExpandedChanged,
            onSelected: onScenarioSelected,
            onShow: onShowSelectedScenario,
          ),
          AnimatedSwitcher(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeOutCubic,
            child: visiblePresentation == null
                ? const SizedBox.shrink(
                    key: ValueKey('urgent-cabinet-patient-no-scenario-result'),
                  )
                : Padding(
                    key: ValueKey(
                      'urgent-cabinet-patient-scenario-result-${visiblePresentation!.state.name}',
                    ),
                    padding: const EdgeInsets.only(top: OmniSpacing.md),
                    child: _PatientCheckInResultPanel(
                      presentation: visiblePresentation!,
                      onClear: onClearScenario,
                    ),
                  ),
          ),
        ],
      ],
    );
  }
}

class _ScannableArrivalQr extends StatelessWidget {
  const _ScannableArrivalQr({required this.handoff});

  final UrgentCabinetArrivalHandoff handoff;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    image: true,
    label:
        "QR de présence à usage unique. N'expire pas avant ${handoff.expiresAt.toLocal()}.",
    child: Container(
      key: const ValueKey('urgent-cabinet-arrival-qr'),
      padding: const EdgeInsets.all(OmniSpacing.lg),
      decoration: BoxDecoration(
        color: OmniColors.mintSoft,
        borderRadius: BorderRadius.circular(OmniRadii.cardLarge),
        border: Border.all(color: OmniColors.freshMint.withValues(alpha: .35)),
      ),
      child: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(OmniSpacing.md),
            child: QrImageView(data: handoff.token, size: 220),
          ),
          const SizedBox(height: OmniSpacing.md),
          const Text(
            'QR à usage unique et durée limitée',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    ),
  );
}

class _ArrivalQrUnavailable extends StatelessWidget {
  const _ArrivalQrUnavailable({required this.issuing});
  final bool issuing;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('urgent-cabinet-arrival-qr-unavailable'),
    padding: const EdgeInsets.all(OmniSpacing.xl),
    alignment: Alignment.center,
    child: issuing
        ? const CircularProgressIndicator()
        : const Text(
            "Le QR n'a pas pu être émis. Revenez à la confirmation puis réessayez après avoir vérifié la connexion.",
            textAlign: TextAlign.center,
          ),
  );
}

class _AcceptedContextCard extends StatelessWidget {
  const _AcceptedContextCard({required this.review});

  final UrgentCabinetRequestReview review;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('urgent-cabinet-patient-qr-context'),
      padding: const EdgeInsets.all(OmniSpacing.base),
      decoration: BoxDecoration(
        color: OmniColors.surfacePrimary,
        borderRadius: BorderRadius.circular(OmniRadii.card),
        border: Border.all(color: OmniColors.borderLight),
        boxShadow: const [OmniColors.shadowSm],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'DEMANDE ACCEPTÉE',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: OmniColors.deepTeal,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: OmniSpacing.md),
          _ContextRow(
            icon: Icons.person_outline_rounded,
            label: 'Patient concerné',
            value: review.patientDisplayName,
          ),
          const SizedBox(height: OmniSpacing.md),
          _ContextRow(
            icon: Icons.medical_services_outlined,
            label: 'Médecin',
            value: review.doctorDisplayName,
            detail: review.specialty,
          ),
          const SizedBox(height: OmniSpacing.md),
          _ContextRow(
            icon: Icons.location_on_outlined,
            label: 'Cabinet',
            value: review.cabinetName,
            detail: _patientQrCabinetAddress(review),
          ),
        ],
      ),
    );
  }
}

class _ContextRow extends StatelessWidget {
  const _ContextRow({
    required this.icon,
    required this.label,
    required this.value,
    this.detail,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: OmniColors.slateSoft,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 21, color: OmniColors.slateBlue),
        ),
        const SizedBox(width: OmniSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: OmniColors.textTertiary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: OmniColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (detail != null && detail!.trim().isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  detail!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: OmniColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _NonScannablePreview extends StatelessWidget {
  const _NonScannablePreview();

  static const semanticLabel =
      "Aperçu non scannable. Aucun code sécurisé n'a été émis.";

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      image: true,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: Container(
          key: const ValueKey('urgent-cabinet-non-scannable-preview'),
          padding: const EdgeInsets.all(OmniSpacing.lg),
          decoration: BoxDecoration(
            color: OmniColors.mintSoft,
            borderRadius: BorderRadius.circular(OmniRadii.cardLarge),
            border: Border.all(
              color: OmniColors.freshMint.withValues(alpha: 0.35),
            ),
            boxShadow: const [OmniColors.shadowCard],
          ),
          child: Column(
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 240),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: OmniSpacing.lg,
                    vertical: OmniSpacing.xxl,
                  ),
                  decoration: BoxDecoration(
                    color: OmniColors.surfacePrimary,
                    borderRadius: BorderRadius.circular(OmniRadii.cardLarge),
                    border: Border.all(color: OmniColors.borderLight),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 88,
                        height: 88,
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: OmniColors.deepTeal,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.shield_outlined,
                          size: 48,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: OmniSpacing.base),
                      Text(
                        'APERÇU NON SCANNABLE',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: OmniColors.deepTealActive,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: OmniSpacing.base),
              Text(
                "Aucun code sécurisé n'a été émis.",
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: OmniColors.deepTealActive,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PatientQrSecurityNotice extends StatelessWidget {
  const _PatientQrSecurityNotice();

  static const primaryMessage =
      'Ce visuel ne confirme pas votre présence et ne donne accès à aucune donnée médicale.';
  static const secondaryMessage =
      'La présence devra être vérifiée par le médecin. Cette étape ne démarre pas la consultation.';

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: '$primaryMessage $secondaryMessage',
      child: ExcludeSemantics(
        child: Container(
          key: const ValueKey('urgent-cabinet-patient-qr-security-notice'),
          padding: const EdgeInsets.all(OmniSpacing.base),
          decoration: BoxDecoration(
            color: OmniColors.infoBlueSoft,
            borderRadius: BorderRadius.circular(OmniRadii.card),
            border: Border.all(
              color: OmniColors.infoBlue.withValues(alpha: 0.2),
            ),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.lock_outline_rounded,
                color: OmniColors.infoBlueStrong,
                size: 22,
              ),
              SizedBox(width: OmniSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      primaryMessage,
                      style: TextStyle(
                        color: OmniColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        height: 1.45,
                      ),
                    ),
                    SizedBox(height: OmniSpacing.sm),
                    Text(
                      secondaryMessage,
                      style: TextStyle(
                        color: OmniColors.textSecondary,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PatientCheckInScenarioSection extends StatelessWidget {
  const _PatientCheckInScenarioSection({
    required this.expanded,
    required this.selected,
    required this.onExpandedChanged,
    required this.onSelected,
    required this.onShow,
  });

  static const scenarios = UrgentCabinetPatientCheckInPreviewState.values;

  final bool expanded;
  final UrgentCabinetPatientCheckInPreviewState selected;
  final ValueChanged<bool> onExpandedChanged;
  final ValueChanged<UrgentCabinetPatientCheckInPreviewState?> onSelected;
  final VoidCallback onShow;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('urgent-cabinet-patient-debug-scenarios'),
      decoration: BoxDecoration(
        color: OmniColors.surfacePrimary,
        borderRadius: BorderRadius.circular(OmniRadii.card),
        border: Border.all(color: OmniColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: expanded,
            label: 'Scénarios de démonstration',
            child: InkWell(
              key: const ValueKey('urgent-cabinet-patient-scenarios-toggle'),
              borderRadius: BorderRadius.circular(OmniRadii.card),
              onTap: () => onExpandedChanged(!expanded),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: OmniSpacing.base,
                    vertical: OmniSpacing.md,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.science_outlined,
                        color: OmniColors.slateBlue,
                      ),
                      const SizedBox(width: OmniSpacing.sm),
                      Expanded(
                        child: Text(
                          'Scénarios de démonstration',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      Icon(
                        expanded
                            ? Icons.expand_less_rounded
                            : Icons.expand_more_rounded,
                        color: OmniColors.slateBlue,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (expanded) ...[
            const Divider(height: 1, color: OmniColors.borderLight),
            Padding(
              padding: const EdgeInsets.all(OmniSpacing.base),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    "Sélectionnez un rendu local. Aucun QR n'est vérifié et aucune donnée n'est transmise.",
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: OmniColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: OmniSpacing.md),
                  DropdownButtonFormField<
                    UrgentCabinetPatientCheckInPreviewState
                  >(
                    key: const ValueKey(
                      'urgent-cabinet-patient-scenario-selector',
                    ),
                    initialValue: selected,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Scénario à afficher',
                    ),
                    items: [
                      for (final scenario in scenarios)
                        DropdownMenuItem(
                          value: scenario,
                          child: Text(
                            UrgentCabinetPatientCheckInPresentation(
                              scenario,
                            ).title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: onSelected,
                  ),
                  const SizedBox(height: OmniSpacing.md),
                  FilledButton(
                    key: const ValueKey(
                      'urgent-cabinet-patient-show-selected-scenario',
                    ),
                    style: buildOmniPrimaryButtonStyle(),
                    onPressed: onShow,
                    child: const SizedBox(
                      height: 48,
                      child: Center(child: Text('Afficher ce scénario')),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PatientCheckInResultPanel extends StatelessWidget {
  const _PatientCheckInResultPanel({
    required this.presentation,
    required this.onClear,
  });

  final UrgentCabinetPatientCheckInPresentation presentation;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final palette = _PatientCheckInResultPalette.forTreatment(
      presentation.visualTreatment,
    );
    return Semantics(
      container: true,
      liveRegion: true,
      label: presentation.accessibilityAnnouncement,
      child: ExcludeSemantics(
        child: Container(
          key: const ValueKey('urgent-cabinet-patient-scenario-result'),
          width: double.infinity,
          padding: const EdgeInsets.all(OmniSpacing.base),
          decoration: BoxDecoration(
            color: palette.background,
            borderRadius: BorderRadius.circular(OmniRadii.card),
            border: Border.all(
              color: palette.foreground.withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(palette.icon, color: palette.foreground, size: 24),
                  const SizedBox(width: OmniSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          presentation.title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: palette.foreground,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: OmniSpacing.xs),
                        Text(
                          presentation.description,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: OmniColors.textPrimary,
                                height: 1.45,
                              ),
                        ),
                        if (presentation.guidance != null) ...[
                          const SizedBox(height: OmniSpacing.sm),
                          Text(
                            presentation.guidance!,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: OmniColors.textSecondary,
                                  height: 1.45,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: OmniSpacing.md),
              Text(
                UrgentCabinetPatientCheckInPresentation.demonstrationDisclosure,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: OmniColors.textSecondary,
                  height: 1.45,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: OmniSpacing.md),
              OutlinedButton(
                key: const ValueKey(
                  'urgent-cabinet-patient-clear-scenario-result',
                ),
                onPressed: onClear,
                child: const SizedBox(
                  height: 48,
                  child: Center(child: Text("Revenir à l'aperçu")),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PatientCheckInResultPalette {
  const _PatientCheckInResultPalette({
    required this.background,
    required this.foreground,
    required this.icon,
  });

  final Color background;
  final Color foreground;
  final IconData icon;

  factory _PatientCheckInResultPalette.forTreatment(
    UrgentCabinetPatientCheckInVisualTreatment treatment,
  ) => switch (treatment) {
    UrgentCabinetPatientCheckInVisualTreatment.neutral =>
      const _PatientCheckInResultPalette(
        background: OmniColors.slateSoft,
        foreground: OmniColors.slateBlue,
        icon: Icons.shield_outlined,
      ),
    UrgentCabinetPatientCheckInVisualTreatment.information =>
      const _PatientCheckInResultPalette(
        background: OmniColors.infoBlueSoft,
        foreground: OmniColors.infoBlueStrong,
        icon: Icons.hourglass_top_rounded,
      ),
    UrgentCabinetPatientCheckInVisualTreatment.warning =>
      const _PatientCheckInResultPalette(
        background: OmniColors.amberSoft,
        foreground: OmniColors.amber,
        icon: Icons.warning_amber_rounded,
      ),
    UrgentCabinetPatientCheckInVisualTreatment.critical =>
      const _PatientCheckInResultPalette(
        background: OmniColors.errorSoft,
        foreground: OmniColors.error,
        icon: Icons.error_outline_rounded,
      ),
  };
}

class _PatientQrContextUnavailable extends StatelessWidget {
  const _PatientQrContextUnavailable();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(OmniSpacing.xl),
        child: Text(
          "Cet aperçu n'est plus disponible pour cette demande.",
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

String _patientQrCabinetAddress(UrgentCabinetRequestReview review) {
  final parts = <String>[];
  final address = review.cabinetAddress?.trim();
  if (address != null && address.isNotEmpty) parts.add(address);
  if (review.cabinetLocality.trim().isNotEmpty) {
    parts.add(review.cabinetLocality.trim());
  }
  final region = [review.cabinetCity, review.cabinetGovernorate]
      .map((part) => part.trim())
      .where((part) => part.isNotEmpty)
      .toSet()
      .join(', ');
  if (region.isNotEmpty && !parts.contains(region)) parts.add(region);
  return parts.join(' · ');
}
