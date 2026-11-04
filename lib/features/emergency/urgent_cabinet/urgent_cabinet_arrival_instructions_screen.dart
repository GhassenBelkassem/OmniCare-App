import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/omni_theme.dart';
import 'urgent_cabinet_flow_controller.dart';
import 'urgent_cabinet_request_review.dart';
import 'urgent_cabinet_request_state.dart';

bool canOpenUrgentCabinetArrivalInstructions(
  UrgentCabinetFlowController flow, {
  UrgentCabinetRequestReview? expectedReview,
  String? expectedAuthoritativeRequestId,
  int? expectedAttemptGeneration,
  String? expectedAccountId,
}) {
  final state = flow.requestState;
  if (state is! UrgentCabinetRequestAccepted ||
      flow.accountId == null ||
      flow.accountId!.trim().isEmpty ||
      flow.selectedSubject != state.review.careSubject ||
      flow.selectedDoctorId != state.review.doctorId ||
      flow.selectedCabinetId != state.review.cabinetId) {
    return false;
  }
  final authorizedPresentation =
      state.isAuthoritative ||
      (kDebugMode &&
          state.isDevelopmentSimulation &&
          state.review.isDevelopmentFixture &&
          state.review.feeQuote.isDevelopmentFixture);
  if (!authorizedPresentation) return false;

  final currentRequestId = state.authoritativeSnapshot?.requestId;
  return (expectedReview == null ||
          (state.review.careSubject == expectedReview.careSubject &&
              state.review.doctorId == expectedReview.doctorId &&
              state.review.cabinetId == expectedReview.cabinetId &&
              state.review.provenance == expectedReview.provenance)) &&
      (expectedAuthoritativeRequestId == null ||
          currentRequestId == expectedAuthoritativeRequestId) &&
      (expectedAttemptGeneration == null ||
          state.localAttemptGeneration == expectedAttemptGeneration) &&
      (expectedAccountId == null || flow.accountId == expectedAccountId);
}

class UrgentCabinetArrivalInstructionsScreen extends StatefulWidget {
  const UrgentCabinetArrivalInstructionsScreen({
    super.key,
    required this.review,
    required this.localAttemptGeneration,
    required this.accountId,
    this.authoritativeRequestId,
    this.onOpenPatientQrPreview,
  });

  final UrgentCabinetRequestReview review;
  final int localAttemptGeneration;
  final String accountId;
  final String? authoritativeRequestId;
  final Future<void> Function()? onOpenPatientQrPreview;

  @override
  State<UrgentCabinetArrivalInstructionsScreen> createState() =>
      _UrgentCabinetArrivalInstructionsScreenState();
}

class _UrgentCabinetArrivalInstructionsScreenState
    extends State<UrgentCabinetArrivalInstructionsScreen> {
  UrgentCabinetFlowController? _flow;
  bool _dismissScheduled = false;
  bool _previewNavigationOpen = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final flow = context.read<UrgentCabinetFlowController>();
    if (!identical(_flow, flow)) {
      _flow?.removeListener(_handleAuthorityChanged);
      _flow = flow..addListener(_handleAuthorityChanged);
    }
    _handleAuthorityChanged();
  }

  bool _isCurrent() {
    final flow = _flow;
    return flow != null &&
        canOpenUrgentCabinetArrivalInstructions(
          flow,
          expectedReview: widget.review,
          expectedAuthoritativeRequestId: widget.authoritativeRequestId,
          expectedAttemptGeneration: widget.localAttemptGeneration,
          expectedAccountId: widget.accountId,
        );
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

  Future<void> _openPatientQrPreview() async {
    final callback = widget.onOpenPatientQrPreview;
    if (callback == null || _previewNavigationOpen || !_isCurrent()) return;
    _previewNavigationOpen = true;
    try {
      await callback();
    } finally {
      _previewNavigationOpen = false;
    }
  }

  @override
  void dispose() {
    _flow?.removeListener(_handleAuthorityChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('urgent-cabinet-arrival-instructions-screen'),
      backgroundColor: OmniColors.pageBackground,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leading: IconButton(
          key: const ValueKey('urgent-cabinet-arrival-back'),
          tooltip: 'Retour à la demande acceptée',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text("Instructions d'arrivée"),
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
                  'urgent-cabinet-arrival-instructions-scroll',
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
                    child: _ArrivalInstructionsContent(
                      review: widget.review,
                      onOpenPatientQrPreview:
                          widget.onOpenPatientQrPreview == null
                          ? null
                          : _openPatientQrPreview,
                    ),
                  ),
                ),
              )
            : const _ArrivalContextUnavailable(),
      ),
    );
  }
}

class _ArrivalInstructionsContent extends StatelessWidget {
  const _ArrivalInstructionsContent({
    required this.review,
    required this.onOpenPatientQrPreview,
  });

  final UrgentCabinetRequestReview review;
  final Future<void> Function()? onOpenPatientQrPreview;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Préparez votre arrivée au cabinet',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: OmniColors.textPrimary,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: OmniSpacing.sm),
        Text(
          "Consultez les informations de votre demande acceptée et les étapes prévues pour une future vérification de présence.",
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: OmniColors.textSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: OmniSpacing.xl),
        _ConsultationInformation(review: review),
        const SizedBox(height: OmniSpacing.xl),
        Text(
          "Instructions d'arrivée",
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: OmniColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: OmniSpacing.md),
        const _InstructionStep(
          number: '1',
          title: 'Rendez-vous au cabinet',
          description:
              "Présentez-vous à l'adresse indiquée dans votre demande acceptée.",
        ),
        const SizedBox(height: OmniSpacing.md),
        const _InstructionStep(
          number: '2',
          title: 'Préparez la vérification',
          description:
              'Lorsque le service sera disponible, un code sécurisé associé à votre demande permettra de vérifier votre présence.',
        ),
        const SizedBox(height: OmniSpacing.md),
        const _InstructionStep(
          number: '3',
          title: 'Attendez la validation',
          description:
              'Votre présence devra être confirmée par le médecin avant la suite de votre prise en charge.',
        ),
        const SizedBox(height: OmniSpacing.xl),
        const _SecurityNotice(),
        if (onOpenPatientQrPreview != null) ...[
          const SizedBox(height: OmniSpacing.lg),
          _PatientQrPreviewEntryCard(onOpen: onOpenPatientQrPreview!),
        ],
      ],
    );
  }
}

class _PatientQrPreviewEntryCard extends StatelessWidget {
  const _PatientQrPreviewEntryCard({required this.onOpen});

  final Future<void> Function() onOpen;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('urgent-cabinet-patient-qr-entry-card'),
      padding: const EdgeInsets.all(OmniSpacing.base),
      decoration: BoxDecoration(
        color: OmniColors.mintSoft,
        borderRadius: BorderRadius.circular(OmniRadii.card),
        border: Border.all(color: OmniColors.freshMint.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: OmniColors.surfacePrimary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.shield_outlined,
                  color: OmniColors.deepTeal,
                  size: 22,
                ),
              ),
              const SizedBox(width: OmniSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Votre futur QR de présence',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: OmniColors.deepTealActive,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: OmniSpacing.xs),
                    Text(
                      'Découvrez comment votre code sécurisé sera présenté au médecin pour vérifier votre arrivée.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: OmniColors.textSecondary,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: OmniSpacing.md),
          Text(
            "Démonstration — aucun code réel n'est généré.",
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: OmniColors.deepTeal,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: OmniSpacing.md),
          OutlinedButton.icon(
            key: const ValueKey('urgent-cabinet-open-patient-qr-preview'),
            onPressed: onOpen,
            icon: const Icon(Icons.visibility_outlined),
            label: const Text("Voir l'aperçu du QR"),
          ),
        ],
      ),
    );
  }
}

class _ConsultationInformation extends StatelessWidget {
  const _ConsultationInformation({required this.review});

  final UrgentCabinetRequestReview review;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('urgent-cabinet-arrival-consultation'),
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
            'Informations de consultation',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: OmniColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: OmniSpacing.base),
          _InformationRow(
            icon: Icons.person_outline_rounded,
            label: 'Patient concerné',
            value: review.patientDisplayName,
          ),
          _InformationRow(
            icon: Icons.medical_services_outlined,
            label: 'Médecin',
            value: review.doctorDisplayName,
            detail: review.specialty,
          ),
          _InformationRow(
            icon: Icons.location_on_outlined,
            label: 'Cabinet sélectionné',
            value: review.cabinetName,
            detail: _arrivalCabinetAddress(review),
          ),
          _InformationRow(
            icon: Icons.payments_outlined,
            label: 'Tarif urgent de démonstration',
            value: formatUrgentCabinetFee(review.feeQuote),
            last: true,
          ),
          const SizedBox(height: OmniSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(OmniSpacing.md),
            decoration: BoxDecoration(
              color: OmniColors.infoBlueSoft,
              borderRadius: BorderRadius.circular(OmniRadii.field),
            ),
            child: const Text(
              "Ce montant reste une donnée de démonstration. Il ne constitue pas une demande de paiement.",
              style: TextStyle(color: OmniColors.textPrimary, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _InformationRow extends StatelessWidget {
  const _InformationRow({
    required this.icon,
    required this.label,
    required this.value,
    this.detail,
    this.last = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? detail;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : OmniSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: OmniColors.slateBlue),
          const SizedBox(width: OmniSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: OmniColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: OmniColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (detail != null && detail!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    detail!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: OmniColors.textSecondary,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InstructionStep extends StatelessWidget {
  const _InstructionStep({
    required this.number,
    required this.title,
    required this.description,
  });

  final String number;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(OmniSpacing.base),
      decoration: BoxDecoration(
        color: OmniColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(OmniRadii.card),
        border: Border.all(color: OmniColors.borderLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            label: 'Étape $number sur 3',
            child: ExcludeSemantics(
              child: Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: OmniColors.deepTeal,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  number,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: OmniSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: OmniColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: OmniSpacing.xs),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: OmniColors.textSecondary,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SecurityNotice extends StatelessWidget {
  const _SecurityNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('urgent-cabinet-arrival-security-notice'),
      padding: const EdgeInsets.all(OmniSpacing.base),
      decoration: BoxDecoration(
        color: OmniColors.warningSubtle,
        borderRadius: BorderRadius.circular(OmniRadii.card),
        border: Border.all(color: OmniColors.warning.withValues(alpha: 0.24)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, color: OmniColors.warning, size: 22),
          SizedBox(width: OmniSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Important',
                  style: TextStyle(
                    color: OmniColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: OmniSpacing.xs),
                Text(
                  "Signaler sa présence ne démarre pas la consultation et ne donne pas accès au dossier médical.",
                  style: TextStyle(color: OmniColors.textPrimary, height: 1.45),
                ),
                SizedBox(height: OmniSpacing.sm),
                Text(
                  "Démonstration — aucune présence réelle n'est enregistrée.",
                  style: TextStyle(
                    color: OmniColors.amber,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ArrivalContextUnavailable extends StatelessWidget {
  const _ArrivalContextUnavailable();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(OmniSpacing.xl),
        child: Text(
          "Ces instructions ne sont plus disponibles pour cette demande.",
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

String _arrivalCabinetAddress(UrgentCabinetRequestReview review) {
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
