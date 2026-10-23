// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/omni_theme.dart';
import '../../request_core/data/request_failure.dart';
import '../../request_core/data/request_models.dart';
import '../../request_core/domain/request_vocabulary.dart';
import '../../request_core/identity/request_operation_id.dart';
import '../application/patient_requests_controller.dart';
import 'patient_request_journey.dart';
import 'request_status_copy.dart';

class PatientRequestDetailScreen extends StatefulWidget {
  const PatientRequestDetailScreen({super.key, required this.requestId});
  final RequestOperationId requestId;
  @override
  State<PatientRequestDetailScreen> createState() => _DetailState();
}

class _DetailState extends State<PatientRequestDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<PatientRequestsController>().loadDetail(widget.requestId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<PatientRequestsController>();
    final request = controller.detail;
    if (request == null) {
      final isNotFound =
          controller.detailFailure?.kind == RequestFailureKind.notFound;
      final failed = controller.detailFailure != null;
      return Scaffold(
        backgroundColor: OmniColors.pageBackground,
        appBar: AppBar(title: const Text('Clinic request')),
        body: Center(
          child: failed
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 40, color: OmniColors.textTertiary),
                    const SizedBox(height: 12),
                    Text(
                      isNotFound ? 'Request not found' : 'We could not load this request.',
                      style: const TextStyle(color: OmniColors.textSecondary),
                    ),
                    TextButton(
                      onPressed: () => controller.loadDetail(widget.requestId),
                      child: const Text('Retry'),
                    ),
                  ],
                )
              : const CircularProgressIndicator(),
        ),
      );
    }
    final status = RequestStatusCopy.of(request.patientStatus);
    final journey = PatientRequestJourneyMapper.fromStatus(request.patientStatus);

    final showInformationFirst = request.canProvideInformation &&
        request.informationRequest != null;

    return Scaffold(
      backgroundColor: OmniColors.pageBackground,
      appBar: AppBar(
        title: const Text('Clinic request'),
        actions: [
          IconButton(
            tooltip: 'Refresh request status',
            onPressed: controller.isLoadingDetail
                ? null
                : () => controller.loadDetail(widget.requestId),
            icon: const Icon(Icons.refresh, color: OmniColors.slateBlue),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => controller.loadDetail(widget.requestId),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (controller.cancellationNotice != null)
                _NoticeBanner(message: controller.cancellationNotice!),
              // 1. Current status hero
              _StatusHeroCard(status: status, request: request),
              // 2. Information required (action-first, above journey)
              if (showInformationFirst)
                InformationRequiredSection(
                  request: request,
                  submitting: controller.isSubmittingInformation,
                  onSubmit: (payload) =>
                      controller.submitInformationResponse(payload: payload),
                ),
              // 3. Waiting for confirmation gap
              if (request.patientStatus ==
                  PatientRequestStatus.waitingForConfirmation)
                const _WaitingForConfirmationGap(),
              // 4. Request journey — the visual centerpiece
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  OmniSpacing.pageHorizontal, OmniSpacing.lg,
                  OmniSpacing.pageHorizontal, 0,
                ),
                child: PatientRequestJourneyWidget(
                  journey: journey,
                  submittedAt: request.submittedAt,
                  currentStatusAccent: status.accent,
                ),
              ),
              // 5. Request summary card
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  OmniSpacing.pageHorizontal, OmniSpacing.lg,
                  OmniSpacing.pageHorizontal, 0,
                ),
                child: _RequestSummaryCard(request: request),
              ),
              // 6. What happens next (non-terminal only)
              if (!request.patientStatus.isTerminal)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    OmniSpacing.pageHorizontal, OmniSpacing.lg,
                    OmniSpacing.pageHorizontal, 0,
                  ),
                  child: _WhatHappensNextCard(status: request.patientStatus),
                ),
              // 7. Cancel action (server-driven, never green)
              if (request.availableActions
                  .contains(PatientRequestAction.cancel))
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    OmniSpacing.pageHorizontal, OmniSpacing.lg,
                    OmniSpacing.pageHorizontal, 0,
                  ),
                  child: OutlinedButton.icon(
                    onPressed: controller.isCancelling
                        ? null
                        : () => _confirmCancel(controller),
                    icon: const Icon(Icons.cancel_outlined, size: 18),
                    label: const Text('Cancel request'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: OmniColors.error,
                      side: const BorderSide(color: OmniColors.error),
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(OmniRadii.field),
                      ),
                    ),
                  ),
                ),
              if (controller.detailFailure != null && !controller.isCancelling)
                Padding(
                  padding: const EdgeInsets.only(top: OmniSpacing.base),
                  child: TextButton(
                    onPressed: () => controller.loadDetail(widget.requestId),
                    child: const Text('Refresh latest status'),
                  ),
                ),
              const SizedBox(height: OmniSpacing.xxxl),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmCancel(PatientRequestsController controller) async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel this request?'),
        content: const Text(
          'The clinic will stop processing this request.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep request'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: OmniColors.error,
            ),
            child: const Text('Cancel request'),
          ),
        ],
      ),
    );
    if (accepted == true && mounted) await controller.cancelDetail();
  }
}

// ---------------------------------------------------------------------------
// Status hero card — premium treatment with semantic colors
// ---------------------------------------------------------------------------

class _StatusHeroCard extends StatelessWidget {
  const _StatusHeroCard({required this.status, required this.request});
  final RequestStatusCopy status;
  final PatientRequest request;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    final local = request.submittedAt.toLocal();
    final submittedLabel =
        '${localizations.formatMediumDate(local)} \u00b7 '
        '${localizations.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        OmniSpacing.pageHorizontal, OmniSpacing.base,
        OmniSpacing.pageHorizontal, 0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Current status',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: OmniColors.textTertiary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: status.softBackground,
              borderRadius: BorderRadius.circular(OmniRadii.cardLarge),
              border: Border.all(
                color: status.accent.withValues(alpha: 0.15),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: status.accent.withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: status.accent.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(status.icon, size: 20, color: status.accent),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        status.label,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: status.accent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  status.description,
                  style: const TextStyle(
                    fontSize: 14,
                    color: OmniColors.textSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: status.accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(OmniRadii.pill),
                  ),
                  child: Text(
                    status.actionMessage,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: status.accent,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.schedule, size: 14, color: OmniColors.textTertiary),
                    const SizedBox(width: 6),
                    Text(
                      'Submitted $submittedLabel',
                      style: const TextStyle(
                        fontSize: 12,
                        color: OmniColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Waiting for confirmation gap
// ---------------------------------------------------------------------------

class _WaitingForConfirmationGap extends StatelessWidget {
  const _WaitingForConfirmationGap();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        OmniSpacing.pageHorizontal, OmniSpacing.base,
        OmniSpacing.pageHorizontal, 0,
      ),
      padding: const EdgeInsets.all(OmniSpacing.base),
      decoration: BoxDecoration(
        color: OmniColors.amberSoft,
        borderRadius: BorderRadius.circular(OmniRadii.card),
        border: Border.all(
          color: OmniColors.amber.withValues(alpha: 0.25),
        ),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: OmniColors.amber),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Confirmation details are not available yet. Refresh for the latest update.',
              style: TextStyle(
                fontSize: 13,
                color: OmniColors.amber,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Notice banner
// ---------------------------------------------------------------------------

class _NoticeBanner extends StatelessWidget {
  const _NoticeBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        OmniSpacing.pageHorizontal, OmniSpacing.base,
        OmniSpacing.pageHorizontal, 0,
      ),
      padding: const EdgeInsets.all(OmniSpacing.base),
      decoration: BoxDecoration(
        color: OmniColors.infoBlueSoft,
        borderRadius: BorderRadius.circular(OmniRadii.card),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: OmniColors.infoBlue),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                color: OmniColors.infoBlue,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Request summary card — compact premium 2-column
// ---------------------------------------------------------------------------

class _RequestSummaryCard extends StatelessWidget {
  const _RequestSummaryCard({required this.request});
  final PatientRequest request;

  @override
  Widget build(BuildContext context) {
    final subjectLabel = request.subjectType == RequestSubjectType.self
        ? 'Me'
        : 'Family member';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: OmniColors.surfacePrimary,
        borderRadius: BorderRadius.circular(OmniRadii.cardLarge),
        border: Border.all(color: OmniColors.borderLight, width: 1),
        boxShadow: [OmniColors.shadowSm],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Request summary',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: OmniColors.textTertiary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          _SummaryRow(
            icon: Icons.person_outline,
            iconColor: OmniColors.violet,
            iconBg: OmniColors.violetSoft,
            label: 'Subject',
            value: subjectLabel,
          ),
          const SizedBox(height: 14),
          _SummaryRow(
            icon: Icons.local_hospital_outlined,
            iconColor: OmniColors.clinicalCyan,
            iconBg: OmniColors.clinicalCyanSoft,
            label: 'Care type',
            value: situationLabel(request.situation),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: OmniColors.textTertiary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: OmniColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// What happens next — state-aware premium card
// ---------------------------------------------------------------------------

class _WhatHappensNextCard extends StatelessWidget {
  const _WhatHappensNextCard({required this.status});
  final PatientRequestStatus status;

  @override
  Widget build(BuildContext context) {
    final items = _nextStepsFor(status);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: OmniColors.surfacePrimary,
        borderRadius: BorderRadius.circular(OmniRadii.cardLarge),
        border: Border.all(color: OmniColors.borderLight, width: 1),
        boxShadow: [OmniColors.shadowSm],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: OmniColors.infoBlueSoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.lightbulb_outline, size: 16, color: OmniColors.infoBlue),
              ),
              const SizedBox(width: 10),
              Text(
                'What happens next',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: OmniColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: OmniColors.infoBlue,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(
                        fontSize: 13,
                        color: OmniColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  List<String> _nextStepsFor(PatientRequestStatus status) => switch (status) {
    PatientRequestStatus.requestReceived => [
      'The clinic team reviews your request.',
      'If they need more information, you\u2019ll be notified in the app.',
      'The request will move forward when review is complete.',
    ],
    PatientRequestStatus.underReview => [
      'The clinic team is reviewing your request.',
      'If they need more information, you\u2019ll be notified in the app.',
      'The request will move forward when review is complete.',
    ],
    PatientRequestStatus.informationRequired => [
      'Send the requested information.',
      'The clinic will continue reviewing once it receives your response.',
    ],
    PatientRequestStatus.schedulingInProgress => [
      'The clinic is arranging the next step.',
      'You\u2019ll see an update when the request progresses.',
    ],
    PatientRequestStatus.waitingForConfirmation => [
      'The clinic is waiting for your confirmation.',
      'Refresh for the latest status.',
    ],
    PatientRequestStatus.confirmed => [
      'Your request has been confirmed.',
      'Care will begin as arranged by the clinic.',
    ],
    PatientRequestStatus.careInProgress => [
      'Your care is in progress.',
      'You\u2019ll see an update when care is complete.',
    ],
    PatientRequestStatus.completed ||
    PatientRequestStatus.declined ||
    PatientRequestStatus.cancelled ||
    PatientRequestStatus.unknown => [],
  };
}

// ---------------------------------------------------------------------------
// Information required section (public for testing access)
// ---------------------------------------------------------------------------

class InformationRequiredSection extends StatelessWidget {
  const InformationRequiredSection({
    super.key,
    required this.request,
    required this.submitting,
    required this.onSubmit,
  });

  final PatientRequest request;
  final bool submitting;
  final ValueChanged<PatientInformationResponsePayload> onSubmit;

  @override
  Widget build(BuildContext context) {
    final information = request.informationRequest!;
    return Container(
      margin: const EdgeInsets.fromLTRB(
        OmniSpacing.pageHorizontal, OmniSpacing.base,
        OmniSpacing.pageHorizontal, 0,
      ),
      padding: const EdgeInsets.all(OmniSpacing.base),
      decoration: BoxDecoration(
        color: OmniColors.amberSoft,
        borderRadius: BorderRadius.circular(OmniRadii.card),
        border: Border.all(
          color: OmniColors.amber.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, size: 18, color: OmniColors.amber),
              const SizedBox(width: 8),
              Text(
                'Action required',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: OmniColors.amber,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'The clinic needs more information',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: OmniColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _reasonLabel(information.reasonCode),
            style: const TextStyle(
              fontSize: 13,
              color: OmniColors.textSecondary,
            ),
          ),
          if (information.patientInstruction?.isNotEmpty == true) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: OmniColors.surfacePrimary,
                borderRadius: BorderRadius.circular(OmniRadii.field),
              ),
              child: Text(
                information.patientInstruction!,
                style: const TextStyle(
                  fontSize: 13,
                  color: OmniColors.textSecondary,
                  height: 1.4,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          _informationForm(
            information: information,
            request: request,
            submitting: submitting,
            onSubmit: onSubmit,
          ),
        ],
      ),
    );
  }

  Widget _informationForm({
    required PatientInformationRequest information,
    required PatientRequest request,
    required bool submitting,
    required ValueChanged<PatientInformationResponsePayload> onSubmit,
  }) {
    return switch (information.responseType) {
      InformationResponseType.confirmation => _ConfirmationResponseForm(
        request: request,
        submitting: submitting,
        onSubmit: onSubmit,
      ),
      InformationResponseType.contactPreference =>
        _ContactPreferenceResponseForm(
          request: request,
          submitting: submitting,
          onSubmit: onSubmit,
        ),
      InformationResponseType.availabilityWindows =>
        _AvailabilityResponseForm(
          request: request,
          submitting: submitting,
          onSubmit: onSubmit,
        ),
      InformationResponseType.identityConfirmation =>
        _IdentityResponseForm(
          request: request,
          submitting: submitting,
          onSubmit: onSubmit,
        ),
      InformationResponseType.familyInformationConfirmation =>
        _FamilyResponseForm(
          request: request,
          submitting: submitting,
          onSubmit: onSubmit,
        ),
      InformationResponseType.administrativeSelection ||
      InformationResponseType.weekdayAvailability ||
      InformationResponseType.unknown =>
        const _UnsupportedInformationResponse(),
    };
  }
}

// ---------------------------------------------------------------------------
// Response forms — all preserved unchanged from original
// ---------------------------------------------------------------------------

class _ConfirmationResponseForm extends StatefulWidget {
  const _ConfirmationResponseForm({
    required this.request,
    required this.submitting,
    required this.onSubmit,
  });
  final PatientRequest request;
  final bool submitting;
  final ValueChanged<PatientInformationResponsePayload> onSubmit;
  @override
  State<_ConfirmationResponseForm> createState() =>
      _ConfirmationResponseFormState();
}

class _ConfirmationResponseFormState extends State<_ConfirmationResponseForm> {
  bool confirmed = false;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: confirmed,
        onChanged: widget.submitting
            ? null
            : (value) => setState(() => confirmed = value ?? false),
        title: const Text(
          'I confirm I have provided or updated this administrative information.',
        ),
        controlAffinity: ListTileControlAffinity.leading,
      ),
      _SubmitButton(
        enabled: confirmed,
        submitting: widget.submitting,
        onPressed: () => widget.onSubmit(
          ConfirmationInformationResponsePayload(
            informationRequestId:
                widget.request.informationRequest!.informationRequestId,
            expectedVersion: widget.request.version,
          ),
        ),
      ),
    ],
  );
}

class _IdentityResponseForm extends _ConfirmationResponseForm {
  const _IdentityResponseForm({
    required super.request,
    required super.submitting,
    required super.onSubmit,
  });
  @override
  State<_IdentityResponseForm> createState() => _IdentityResponseFormState();
}

class _IdentityResponseFormState extends State<_IdentityResponseForm> {
  bool confirmed = false;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: confirmed,
        onChanged: widget.submitting
            ? null
            : (value) => setState(() => confirmed = value ?? false),
        title: const Text('I confirm my identity information is current.'),
        controlAffinity: ListTileControlAffinity.leading,
      ),
      _SubmitButton(
        enabled: confirmed,
        submitting: widget.submitting,
        onPressed: () => widget.onSubmit(
          IdentityConfirmationInformationResponsePayload(
            informationRequestId:
                widget.request.informationRequest!.informationRequestId,
            expectedVersion: widget.request.version,
            identityInformationConfirmed: true,
          ),
        ),
      ),
    ],
  );
}

class _FamilyResponseForm extends _ConfirmationResponseForm {
  const _FamilyResponseForm({
    required super.request,
    required super.submitting,
    required super.onSubmit,
  });
  @override
  State<_FamilyResponseForm> createState() => _FamilyResponseFormState();
}

class _FamilyResponseFormState extends State<_FamilyResponseForm> {
  bool confirmed = false;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: confirmed,
        onChanged: widget.submitting
            ? null
            : (value) => setState(() => confirmed = value ?? false),
        title: const Text(
          'I confirm the family member information is current.',
        ),
        controlAffinity: ListTileControlAffinity.leading,
      ),
      _SubmitButton(
        enabled: confirmed,
        submitting: widget.submitting,
        onPressed: () => widget.onSubmit(
          FamilyInformationConfirmationResponsePayload(
            informationRequestId:
                widget.request.informationRequest!.informationRequestId,
            expectedVersion: widget.request.version,
            familyInformationConfirmed: true,
          ),
        ),
      ),
    ],
  );
}

class _ContactPreferenceResponseForm extends StatefulWidget {
  const _ContactPreferenceResponseForm({
    required this.request,
    required this.submitting,
    required this.onSubmit,
  });
  final PatientRequest request;
  final bool submitting;
  final ValueChanged<PatientInformationResponsePayload> onSubmit;
  @override
  State<_ContactPreferenceResponseForm> createState() =>
      _ContactPreferenceResponseFormState();
}

class _ContactPreferenceResponseFormState
    extends State<_ContactPreferenceResponseForm> {
  PreferredContactMethod? method;
  bool confirmed = false;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        'Choose how the clinic should contact you. This does not change your verified phone number or email.',
      ),
      RadioListTile<PreferredContactMethod>(
        dense: true,
        value: PreferredContactMethod.phone,
        groupValue: method,
        onChanged: widget.submitting
            ? null
            : (value) => setState(() => method = value),
        title: const Text('Phone'),
      ),
      RadioListTile<PreferredContactMethod>(
        dense: true,
        value: PreferredContactMethod.email,
        groupValue: method,
        onChanged: widget.submitting
            ? null
            : (value) => setState(() => method = value),
        title: const Text('Email'),
      ),
      CheckboxListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        value: confirmed,
        onChanged: widget.submitting
            ? null
            : (value) => setState(() => confirmed = value ?? false),
        title: const Text('My current contact information is accurate.'),
        controlAffinity: ListTileControlAffinity.leading,
      ),
      _SubmitButton(
        enabled: method != null && confirmed,
        submitting: widget.submitting,
        onPressed: () => widget.onSubmit(
          ContactPreferenceInformationResponsePayload(
            informationRequestId:
                widget.request.informationRequest!.informationRequestId,
            expectedVersion: widget.request.version,
            preferredContactMethod: method!,
            contactDetailsConfirmed: true,
          ),
        ),
      ),
    ],
  );
}

class _AvailabilityResponseForm extends StatefulWidget {
  const _AvailabilityResponseForm({
    required this.request,
    required this.submitting,
    required this.onSubmit,
  });
  final PatientRequest request;
  final bool submitting;
  final ValueChanged<PatientInformationResponsePayload> onSubmit;
  @override
  State<_AvailabilityResponseForm> createState() =>
      _AvailabilityResponseFormState();
}

class _AvailabilityResponseFormState extends State<_AvailabilityResponseForm> {
  final windows = <_AvailabilityDraft>[];

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Your availability is a local wall-clock preference, not an appointment time.',
        style: const TextStyle(
          fontSize: 13,
          color: OmniColors.textSecondary,
          height: 1.4,
        ),
      ),
      const SizedBox(height: 12),
      if (windows.isEmpty)
        _EmptyAvailabilityState(submitting: widget.submitting, onAdd: _addWindow),
      for (var index = 0; index < windows.length; index++) ...[
        if (index > 0) const SizedBox(height: 10),
        _AvailabilityWindowCard(
          index: index,
          draft: windows[index],
          submitting: widget.submitting,
          canRemove: windows.length > 1,
          onDayChanged: (day) => setState(() => windows[index].day = day),
          onStartChanged: (time) => setState(() => windows[index].start = time),
          onEndChanged: (time) => setState(() => windows[index].end = time),
          onRemove: () => setState(() => windows.removeAt(index)),
        ),
      ],
      if (windows.isNotEmpty) ...[
        const SizedBox(height: 12),
        _AddTimePeriodButton(
          submitting: widget.submitting,
          limit: windows.length >= 14,
          onPressed: _addWindow,
        ),
      ],
      const SizedBox(height: 4),
      _SubmitButton(
        enabled: _valid,
        submitting: widget.submitting,
        onPressed: () => widget.onSubmit(
          AvailabilityInformationResponsePayload(
            informationRequestId:
                widget.request.informationRequest!.informationRequestId,
            expectedVersion: widget.request.version,
            availabilityWindows: windows
                .map(
                  (item) => AvailabilityWindow(
                    dayOfWeek: item.day!,
                    startLocalTime: AvailabilityLocalTime(
                      item.start!.hour,
                      item.start!.minute,
                    ),
                    endLocalTime: AvailabilityLocalTime(
                      item.end!.hour,
                      item.end!.minute,
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    ],
  );

  void _addWindow() => setState(() => windows.add(_AvailabilityDraft()));

  bool get _valid {
    if (windows.isEmpty) return false;
    for (final item in windows) {
      if (item.day == null ||
          item.start == null ||
          item.end == null ||
          _minutes(item.start!) >= _minutes(item.end!)) {
        return false;
      }
    }
    final sorted = [...windows]
      ..sort(
        (a, b) => a.day!.index != b.day!.index
            ? a.day!.index.compareTo(b.day!.index)
            : _minutes(a.start!).compareTo(_minutes(b.start!)),
      );
    for (var i = 1; i < sorted.length; i++) {
      if (sorted[i - 1].day == sorted[i].day &&
          _minutes(sorted[i - 1].end!) > _minutes(sorted[i].start!)) {
        return false;
      }
    }
    return true;
  }

  static int _minutes(TimeOfDay time) => time.hour * 60 + time.minute;
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyAvailabilityState extends StatelessWidget {
  const _EmptyAvailabilityState({
    required this.submitting,
    required this.onAdd,
  });
  final bool submitting;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: OmniColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(OmniRadii.card),
        border: Border.all(color: OmniColors.borderLight),
      ),
      child: Column(
        children: [
          Icon(
            Icons.event_available_outlined,
            size: 32,
            color: OmniColors.textTertiary,
          ),
          const SizedBox(height: 10),
          const Text(
            'No time periods added yet',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: OmniColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Add when you are available each week',
            style: TextStyle(
              fontSize: 13,
              color: OmniColors.textTertiary,
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: submitting ? null : onAdd,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add time period'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Availability window card
// ---------------------------------------------------------------------------

class _AvailabilityWindowCard extends StatelessWidget {
  const _AvailabilityWindowCard({
    required this.index,
    required this.draft,
    required this.submitting,
    required this.canRemove,
    required this.onDayChanged,
    required this.onStartChanged,
    required this.onEndChanged,
    required this.onRemove,
  });

  final int index;
  final _AvailabilityDraft draft;
  final bool submitting;
  final bool canRemove;
  final ValueChanged<OperationalWeekday?> onDayChanged;
  final ValueChanged<TimeOfDay> onStartChanged;
  final ValueChanged<TimeOfDay> onEndChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: OmniColors.surfacePrimary,
        borderRadius: BorderRadius.circular(OmniRadii.field),
        border: Border.all(color: OmniColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: label + delete
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: OmniColors.infoBlueSoft,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: OmniColors.infoBlue,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Time period',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: OmniColors.textPrimary,
                  ),
                ),
              ),
              if (canRemove)
                _DeleteIconButton(
                  onPressed: submitting ? null : onRemove,
                  tooltip: 'Remove period ${index + 1}',
                ),
            ],
          ),
          const SizedBox(height: 10),
          // Day selector
          _DayDropdown(
            value: draft.day,
            enabled: !submitting,
            onChanged: onDayChanged,
          ),
          const SizedBox(height: 10),
          // Time row: Start + End
          Row(
            children: [
              Expanded(
                child: _TimeField(
                  label: 'Start',
                  time: draft.start,
                  defaultHour: 9,
                  enabled: !submitting,
                  onTap: () => _pickTime(
                    context,
                    label: 'Start time',
                    initial: draft.start ?? const TimeOfDay(hour: 9, minute: 0),
                    onPicked: onStartChanged,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _TimeField(
                  label: 'End',
                  time: draft.end,
                  defaultHour: 17,
                  enabled: !submitting,
                  onTap: () => _pickTime(
                    context,
                    label: 'End time',
                    initial: draft.end ?? const TimeOfDay(hour: 17, minute: 0),
                    onPicked: onEndChanged,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickTime(
    BuildContext context, {
    required String label,
    required TimeOfDay initial,
    required ValueChanged<TimeOfDay> onPicked,
  }) async {
    final picked = await _showOmniTimePicker(
      context: context,
      initialTime: initial,
      title: label,
    );
    if (picked != null) onPicked(picked);
  }
}

// ---------------------------------------------------------------------------
// Day dropdown
// ---------------------------------------------------------------------------

class _DayDropdown extends StatelessWidget {
  const _DayDropdown({
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final OperationalWeekday? value;
  final bool enabled;
  final ValueChanged<OperationalWeekday?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: OmniColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(OmniRadii.field),
        border: Border.all(color: OmniColors.borderLight),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<OperationalWeekday>(
          value: value,
          isExpanded: true,
          hint: const Text(
            'Select day',
            style: TextStyle(
              fontSize: 14,
              color: OmniColors.textTertiary,
            ),
          ),
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: OmniColors.textPrimary,
          ),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: OmniColors.textTertiary,
            size: 20,
          ),
          items: OperationalWeekday.values
              .map(
                (day) => DropdownMenuItem(
                  value: day,
                  child: Text(_weekdayLabel(day)),
                ),
              )
              .toList(),
          onChanged: enabled ? onChanged : null,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Time field (tappable pill/card style)
// ---------------------------------------------------------------------------

class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.label,
    required this.time,
    required this.defaultHour,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final TimeOfDay? time;
  final int defaultHour;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasValue = time != null;
    final displayText = hasValue ? time!.format(context) : label;

    return Material(
      color: enabled ? OmniColors.surfaceSecondary : OmniColors.surfaceSecondary,
      borderRadius: BorderRadius.circular(OmniRadii.field),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(OmniRadii.field),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(OmniRadii.field),
            border: Border.all(
              color: hasValue
                  ? OmniColors.infoBlue.withValues(alpha: 0.3)
                  : OmniColors.borderLight,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.access_time_rounded,
                size: 16,
                color: hasValue
                    ? OmniColors.infoBlue
                    : OmniColors.textTertiary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: hasValue
                            ? OmniColors.infoBlue
                            : OmniColors.textTertiary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      displayText,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: hasValue ? FontWeight.w600 : FontWeight.w500,
                        color: hasValue
                            ? OmniColors.textPrimary
                            : OmniColors.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 18,
                color: enabled
                    ? OmniColors.textTertiary
                    : OmniColors.textDisabled,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Delete icon button (destructive)
// ---------------------------------------------------------------------------

class _DeleteIconButton extends StatelessWidget {
  const _DeleteIconButton({
    required this.onPressed,
    required this.tooltip,
  });

  final VoidCallback? onPressed;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: onPressed != null
                  ? OmniColors.error.withValues(alpha: 0.08)
                  : OmniColors.error.withValues(alpha: 0.04),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.delete_outline_rounded,
              size: 16,
              color: onPressed != null
                  ? OmniColors.error
                  : OmniColors.textDisabled,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Add time period button
// ---------------------------------------------------------------------------

class _AddTimePeriodButton extends StatelessWidget {
  const _AddTimePeriodButton({
    required this.submitting,
    required this.limit,
    required this.onPressed,
  });

  final bool submitting;
  final bool limit;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = !submitting && !limit;
    return Center(
      child: OutlinedButton.icon(
        onPressed: enabled ? onPressed : null,
        icon: Icon(
          Icons.add_circle_outline_rounded,
          size: 18,
          color: enabled ? OmniColors.primaryAction : OmniColors.textDisabled,
        ),
        label: Text(
          limit ? 'Maximum 14 periods' : 'Add another time period',
          style: TextStyle(
            color: enabled ? OmniColors.primaryAction : OmniColors.textDisabled,
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(OmniRadii.pill),
          ),
          side: BorderSide(
            color: enabled
                ? OmniColors.primaryAction.withValues(alpha: 0.3)
                : OmniColors.borderLight,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Omni-style time picker bottom sheet
// ---------------------------------------------------------------------------

Future<TimeOfDay?> _showOmniTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
  required String title,
}) async {
  return showModalBottomSheet<TimeOfDay>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _OmniTimePickerSheet(
      initialTime: initialTime,
      title: title,
    ),
  );
}

class _OmniTimePickerSheet extends StatefulWidget {
  const _OmniTimePickerSheet({
    required this.initialTime,
    required this.title,
  });

  final TimeOfDay initialTime;
  final String title;

  @override
  State<_OmniTimePickerSheet> createState() => _OmniTimePickerSheetState();
}

class _OmniTimePickerSheetState extends State<_OmniTimePickerSheet> {
  late int _selectedHour;
  late int _selectedMinute;
  late FixedExtentScrollController _hourController;
  late FixedExtentScrollController _minuteController;

  @override
  void initState() {
    super.initState();
    _selectedHour = widget.initialTime.hour;
    _selectedMinute = widget.initialTime.minute;
    _hourController = FixedExtentScrollController(
      initialItem: _selectedHour,
    );
    _minuteController = FixedExtentScrollController(
      initialItem: _selectedMinute ~/ 5,
    );
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: EdgeInsets.only(bottom: bottomPadding),
      decoration: const BoxDecoration(
        color: OmniColors.surfacePrimary,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(OmniRadii.sheet),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: OmniColors.borderStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: OmniColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: OmniColors.textSecondary,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Time display
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: OmniColors.surfaceSecondary,
                borderRadius: BorderRadius.circular(OmniRadii.card),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _TimeDisplayChip(
                    value: _selectedHour.toString().padLeft(2, '0'),
                    isSelected: true,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      ':',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: OmniColors.textPrimary.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                  _TimeDisplayChip(
                    value: _selectedMinute.toString().padLeft(2, '0'),
                    isSelected: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Wheel pickers
            SizedBox(
              height: 180,
              child: Row(
                children: [
                  Expanded(
                    child: _OmniWheelPicker(
                      controller: _hourController,
                      itemCount: 24,
                      itemBuilder: (index) => Text(
                        index.toString().padLeft(2, '0'),
                      ),
                      onChanged: (index) =>
                          setState(() => _selectedHour = index),
                    ),
                  ),
                  Container(
                    width: 2,
                    height: 40,
                    color: OmniColors.borderLight,
                  ),
                  Expanded(
                    child: _OmniWheelPicker(
                      controller: _minuteController,
                      itemCount: 12,
                      itemBuilder: (index) => Text(
                        (index * 5).toString().padLeft(2, '0'),
                      ),
                      onChanged: (index) =>
                          setState(() => _selectedMinute = index * 5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Confirm CTA
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(
                      context,
                      TimeOfDay(
                        hour: _selectedHour,
                        minute: _selectedMinute,
                      ),
                    );
                  },
                  child: const Text('Done'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeDisplayChip extends StatelessWidget {
  const _TimeDisplayChip({
    required this.value,
    required this.isSelected,
  });

  final String value;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? OmniColors.primaryAction.withValues(alpha: 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(OmniRadii.field),
        border: Border.all(
          color: isSelected
              ? OmniColors.primaryAction.withValues(alpha: 0.3)
              : OmniColors.borderLight,
        ),
      ),
      child: Text(
        value,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: isSelected ? OmniColors.primaryAction : OmniColors.textTertiary,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _OmniWheelPicker extends StatelessWidget {
  const _OmniWheelPicker({
    required this.controller,
    required this.itemCount,
    required this.itemBuilder,
    required this.onChanged,
  });

  final FixedExtentScrollController controller;
  final int itemCount;
  final Widget Function(int index) itemBuilder;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListWheelScrollView.useDelegate(
      controller: controller,
      itemExtent: 40,
      physics: const FixedExtentScrollPhysics(),
      diameterRatio: 1.5,
      perspective: 0.003,
      onSelectedItemChanged: onChanged,
      childDelegate: ListWheelChildBuilderDelegate(
        childCount: itemCount,
        builder: (context, index) {
          return Center(
            child: itemBuilder(index),
          );
        },
      ),
    );
  }
}

class _AvailabilityDraft {
  OperationalWeekday? day;
  TimeOfDay? start;
  TimeOfDay? end;
}

class _SubmitButton extends StatelessWidget {
  const _SubmitButton({
    required this.enabled,
    required this.submitting,
    required this.onPressed,
  });
  final bool enabled;
  final bool submitting;
  final VoidCallback onPressed;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: ElevatedButton.icon(
      onPressed: enabled && !submitting ? onPressed : null,
      icon: submitting
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.send_outlined),
      label: const Text('Submit information'),
    ),
  );
}

class _UnsupportedInformationResponse extends StatelessWidget {
  const _UnsupportedInformationResponse();
  @override
  Widget build(BuildContext context) => const Text(
    'This request needs an app update before it can be completed. Please contact the clinic.',
  );
}

String _reasonLabel(InformationRequestReasonCode reason) => switch (reason) {
  InformationRequestReasonCode.contactInformation => 'Contact information',
  InformationRequestReasonCode.patientIdentityInformation =>
    'Patient identity information',
  InformationRequestReasonCode.familyMemberInformation =>
    'Family member information',
  InformationRequestReasonCode.requestAdministrativeDetails =>
    'Request administrative details',
  InformationRequestReasonCode.availabilityInformation =>
    'Availability information',
  InformationRequestReasonCode.otherAdministrative =>
    'Other administrative information',
  InformationRequestReasonCode.unknown => 'Administrative information',
};

String _weekdayLabel(OperationalWeekday day) =>
    const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][day.index];
