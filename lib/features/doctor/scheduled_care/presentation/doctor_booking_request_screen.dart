import 'dart:async';

import 'package:flutter/material.dart';
import '../../../../core/theme/omni_theme.dart';
import '../../../scheduled_care/domain/scheduled_care_models.dart';
import '../../../scheduled_care/presentation/booking_review_screen.dart';
import '../application/doctor_booking_request_controller.dart';
import '../application/doctor_proposal_controller.dart';
import '../domain/doctor_scheduled_care_models.dart';
import '../../../scheduled_care/realtime/scheduled_care_route_visibility.dart';
import 'doctor_proposal_screen.dart';

class DoctorBookingRequestScreen extends StatefulWidget {
  const DoctorBookingRequestScreen({
    super.key,
    required this.requestId,
    required this.controller,
    this.proposalController,
  });

  final String requestId;
  final DoctorBookingRequestController controller;
  final DoctorProposalController? proposalController;

  @override
  State<DoctorBookingRequestScreen> createState() =>
      _DoctorBookingRequestScreenState();
}

class _DoctorBookingRequestScreenState extends State<DoctorBookingRequestScreen>
    with ScheduledCareRouteVisibility<DoctorBookingRequestScreen> {
  Timer? _deadlineTimer;
  String? _deadlineIdentity;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.controller.open(widget.requestId);
    });
  }

  @override
  void dispose() {
    _deadlineTimer?.cancel();
    onScheduledCareRouteVisibilityChanged(false);
    super.dispose();
  }

  @override
  void onScheduledCareRouteVisibilityChanged(bool visible) {
    if (visible) {
      widget.controller.activateRealtime(widget.requestId);
    } else {
      widget.controller.deactivateRealtime(widget.requestId);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: OmniColors.pageBackground,
    appBar: AppBar(title: const Text('Demande de rendez-vous')),
    body: AnimatedBuilder(
      animation: Listenable.merge([
        widget.controller,
        if (widget.proposalController != null) widget.proposalController!,
      ]),
      builder: (context, _) => _body(context),
    ),
  );

  Widget _body(BuildContext context) {
    final controller = widget.controller;
    final request = controller.request;
    if (controller.state == DoctorBookingRequestLoadState.loading &&
        request == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (request == null) {
      return _FailureState(
        message:
            controller.failure?.message ?? 'Cette demande est indisponible.',
        onRetry: () => controller.open(widget.requestId),
      );
    }
    _scheduleDeadlineRefresh(request);
    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView(
        key: const ValueKey('doctor-booking-request-detail'),
        padding: const EdgeInsets.fromLTRB(
          OmniSpacing.pageHorizontal,
          OmniSpacing.pageVertical,
          OmniSpacing.pageHorizontal,
          OmniSpacing.xxl,
        ),
        children: [
          _StatusCard(request: request),
          const SizedBox(height: OmniSpacing.lg),
          _DetailCard(
            icon: Icons.person_outline_rounded,
            title: request.subject.displayName ?? 'Patient',
            lines: [
              if (request.subject.subjectType == CareSubjectType.familyMember)
                request.subject.relationship ?? 'Membre de la famille',
            ],
          ),
          const SizedBox(height: OmniSpacing.md),
          _DetailCard(
            icon: Icons.calendar_month_outlined,
            title: formatSchedulingDateTime(
              request.originalRequestedSlot.start,
              timezone: request.cabinet.timezone,
            ),
            lines: [
              'Fuseau : ${request.cabinet.timezone}',
              'Répondre avant le ${formatSchedulingDateTime(request.responseDeadline, timezone: request.cabinet.timezone)}',
            ],
          ),
          const SizedBox(height: OmniSpacing.md),
          _DetailCard(
            icon: Icons.location_on_outlined,
            title: request.cabinet.name,
            lines: [
              request.cabinet.address,
              '${request.cabinet.city}, ${request.cabinet.governorate}',
            ],
          ),
          if (request.confirmedAppointmentId != null) ...[
            const SizedBox(height: OmniSpacing.md),
            const _NoticeCard(
              icon: Icons.event_available_rounded,
              message: 'Un rendez-vous confirmé a été créé.',
            ),
          ],
          if (request.status ==
                  BookingRequestStatus.pendingPatientTimeConfirmation &&
              request.proposedSlot != null) ...[
            const SizedBox(height: OmniSpacing.md),
            _DetailCard(
              icon: Icons.schedule_send_rounded,
              title: formatSchedulingDateTime(
                request.proposedSlot!.start,
                timezone: request.cabinet.timezone,
              ),
              lines: [
                'Nouvel horaire proposé',
                'Réponse du patient avant le ${formatSchedulingDateTime(request.patientResponseDeadline ?? request.proposedSlot!.patientResponseDeadline, timezone: request.cabinet.timezone)}',
              ],
            ),
          ],
          if (request.canPropose) ...[
            const SizedBox(height: OmniSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                key: const ValueKey('doctor-propose-new-time'),
                onPressed:
                    !controller.isMutating &&
                        widget.proposalController != null &&
                        !widget.proposalController!.isSubmitting
                    ? () => _openProposal(request)
                    : null,
                icon: const Icon(Icons.schedule_send_rounded),
                label: const Text('Proposer un autre horaire'),
              ),
            ),
          ],
          if (controller.failure != null) ...[
            const SizedBox(height: OmniSpacing.md),
            _InlineFailure(message: controller.failure!.message),
          ],
          if (request.canAccept || request.canDecline) ...[
            const SizedBox(height: OmniSpacing.xl),
            if (request.canAccept)
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const ValueKey('doctor-accept-request'),
                  onPressed: controller.canAccept ? controller.accept : null,
                  icon: controller.isMutating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_rounded),
                  label: const Text('Accepter'),
                ),
              ),
            if (request.canAccept && request.canDecline)
              const SizedBox(height: OmniSpacing.sm),
            if (request.canDecline)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  key: const ValueKey('doctor-decline-request'),
                  onPressed: controller.canDecline
                      ? () => _showDeclineReasons(context)
                      : null,
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Refuser'),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _openProposal(DoctorBookingRequestDetail request) async {
    final proposalController = widget.proposalController;
    if (proposalController == null ||
        widget.controller.isMutating ||
        proposalController.isSubmitting) {
      return;
    }
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => DoctorProposalScreen(
          request: request,
          controller: proposalController,
        ),
      ),
    );
  }

  void _scheduleDeadlineRefresh(DoctorBookingRequestDetail request) {
    final deadline =
        request.status == BookingRequestStatus.pendingPatientTimeConfirmation
        ? request.patientResponseDeadline ??
              request.proposedSlot?.patientResponseDeadline ??
              request.responseDeadline
        : request.responseDeadline;
    final identity =
        '${request.requestId}:${request.version}:${deadline.toUtc().toIso8601String()}';
    if (_deadlineIdentity == identity) return;
    _deadlineIdentity = identity;
    _deadlineTimer?.cancel();
    final delay = deadline.difference(DateTime.now());
    _deadlineTimer = Timer(delay.isNegative ? Duration.zero : delay, () {
      if (mounted) widget.controller.refreshIfDeadlinePassed();
    });
  }

  Future<void> _showDeclineReasons(BuildContext context) async {
    final reason = await showModalBottomSheet<DoctorDeclineReason>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: OmniSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: OmniSpacing.base,
                  vertical: OmniSpacing.sm,
                ),
                child: Text(
                  'Motif du refus',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              ...DoctorDeclineReason.values.map(
                (value) => ListTile(
                  key: ValueKey('doctor-decline-${value.wireValue}'),
                  title: Text(value.label),
                  onTap: () => Navigator.of(context).pop(value),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (reason != null && mounted) await widget.controller.decline(reason);
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.request});
  final DoctorBookingRequestDetail request;

  @override
  Widget build(BuildContext context) {
    final presentation = _statusPresentation(request.status, request.rawStatus);
    return Container(
      padding: const EdgeInsets.all(OmniSpacing.base),
      decoration: BoxDecoration(
        color: presentation.background,
        borderRadius: BorderRadius.circular(OmniRadii.card),
        border: Border.all(color: presentation.color.withValues(alpha: .25)),
      ),
      child: Row(
        children: [
          Icon(presentation.icon, color: presentation.color),
          const SizedBox(width: OmniSpacing.md),
          Expanded(
            child: Text(
              presentation.label,
              key: const ValueKey('doctor-booking-request-status'),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: presentation.color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({
    required this.icon,
    required this.title,
    required this.lines,
  });
  final IconData icon;
  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(OmniSpacing.base),
    decoration: BoxDecoration(
      color: OmniColors.surfacePrimary,
      borderRadius: BorderRadius.circular(OmniRadii.card),
      border: Border.all(color: OmniColors.borderLight),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: OmniColors.deepTeal),
        const SizedBox(width: OmniSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              ...lines
                  .where((line) => line.trim().isNotEmpty)
                  .map(
                    (line) => Padding(
                      padding: const EdgeInsets.only(top: OmniSpacing.xs),
                      child: Text(
                        line,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: OmniColors.textSecondary,
                        ),
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

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(OmniSpacing.base),
    decoration: BoxDecoration(
      color: OmniColors.slateSoft,
      borderRadius: BorderRadius.circular(OmniRadii.card),
    ),
    child: Row(
      children: [
        Icon(icon, color: OmniColors.slateBlue),
        const SizedBox(width: OmniSpacing.md),
        Expanded(child: Text(message)),
      ],
    ),
  );
}

class _InlineFailure extends StatelessWidget {
  const _InlineFailure({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => Text(
    message,
    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: OmniColors.urgentCoral,
      fontWeight: FontWeight.w600,
    ),
  );
}

class _FailureState extends StatelessWidget {
  const _FailureState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(OmniSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: OmniSpacing.md),
          OutlinedButton(
            key: const ValueKey('doctor-booking-request-retry'),
            onPressed: onRetry,
            child: const Text('Réessayer'),
          ),
        ],
      ),
    ),
  );
}

({String label, IconData icon, Color color, Color background})
_statusPresentation(BookingRequestStatus status, String rawStatus) =>
    switch (status) {
      BookingRequestStatus.pendingDoctor => (
        label: 'En attente de votre réponse',
        icon: Icons.schedule_rounded,
        color: OmniColors.amber,
        background: OmniColors.amberSoft,
      ),
      BookingRequestStatus.pendingPatientTimeConfirmation => (
        label: 'En attente de la réponse du patient',
        icon: Icons.schedule_send_rounded,
        color: OmniColors.infoBlue,
        background: OmniColors.infoBlueSoft,
      ),
      BookingRequestStatus.fulfilled => (
        label: 'Rendez-vous confirmé',
        icon: Icons.event_available_rounded,
        color: OmniColors.deepTeal,
        background: OmniColors.mintSoft,
      ),
      BookingRequestStatus.cancelledByPatient => (
        label: 'Annulée par le patient',
        icon: Icons.event_busy_outlined,
        color: OmniColors.textSecondary,
        background: OmniColors.slateSoft,
      ),
      BookingRequestStatus.cancelledByDoctor => (
        label: 'Demande refusée',
        icon: Icons.block_outlined,
        color: OmniColors.textSecondary,
        background: OmniColors.slateSoft,
      ),
      BookingRequestStatus.expired => (
        label: 'Demande expirée',
        icon: Icons.timer_off_outlined,
        color: OmniColors.textSecondary,
        background: OmniColors.slateSoft,
      ),
      BookingRequestStatus.unknown => (
        label: 'État indisponible ($rawStatus)',
        icon: Icons.help_outline_rounded,
        color: OmniColors.textSecondary,
        background: OmniColors.slateSoft,
      ),
    };
