import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/omni_theme.dart';
import '../agenda/doctor_demo_appointment.dart';
import '../../scheduled_care/domain/patient_scheduled_care_models.dart';
import '../../scheduled_care/presentation/booking_review_screen.dart';
import '../profile/doctor_display_profile.dart';
import '../scheduled_care/application/doctor_home_controller.dart';
import '../workspace/doctor_workspace_config.dart';
import '../urgent/doctor_urgent_controller.dart';
import '../active_consultation/doctor_active_consultation.dart';
import '../active_consultation/doctor_active_consultation_controller.dart';
import 'doctor_home_demo_state.dart';

DoctorHomeUrgentStatus _homeUrgentStatus(DoctorUrgentState state) =>
    switch (state) {
      DoctorUrgentState.offline => DoctorHomeUrgentStatus.offline,
      DoctorUrgentState.available => DoctorHomeUrgentStatus.available,
      DoctorUrgentState.offerReceived => DoctorHomeUrgentStatus.requestPending,
      DoctorUrgentState.acceptedWaitingPatient ||
      DoctorUrgentState.selected ||
      DoctorUrgentState.enRoute ||
      DoctorUrgentState.arrived => DoctorHomeUrgentStatus.missionInProgress,
    };

/// Local D3 Doctor Home. It surfaces immediate operational context only; the
/// underlying consultation, agenda, urgent, and work-queue features arrive in
/// later phases.
class DoctorHomeScreen extends StatelessWidget {
  const DoctorHomeScreen({
    super.key,
    required this.profile,
    required this.capabilities,
    this.workspaceConfig,
    this.demoState = DoctorHomeDemoState.normalDay,
    this.agendaNextAppointment,
    this.onOpenAgenda,
    this.onOpenUrgencies,
    this.urgentController,
    this.homeController,
    this.onOpenBookingRequest,
    this.activeConsultationController,
    this.onOpenActiveConsultation,
    this.onOpenAppointment,
  });

  final DoctorDisplayProfile profile;
  final Set<DoctorCapability> capabilities;
  final DoctorWorkspaceConfig? workspaceConfig;
  final DoctorHomeDemoState demoState;
  final DoctorDemoAppointment? agendaNextAppointment;
  final VoidCallback? onOpenAgenda;
  final VoidCallback? onOpenUrgencies;
  final DoctorUrgentController? urgentController;
  final DoctorHomeController? homeController;
  final ValueChanged<String>? onOpenBookingRequest;
  final DoctorActiveConsultationController? activeConsultationController;
  final VoidCallback? onOpenActiveConsultation;
  final ValueChanged<String>? onOpenAppointment;

  @override
  Widget build(BuildContext context) {
    final realController = homeController;
    if (realController != null) {
      if (realController.state == DoctorHomeLoadState.initial) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (realController.state == DoctorHomeLoadState.initial) {
            realController.load();
          }
        });
      }
      return AnimatedBuilder(
        animation: realController,
        builder: (context, _) => _buildReal(context, realController),
      );
    }
    final hasAgenda = capabilities.contains(DoctorCapability.agenda);
    final hasUrgentRequests = capabilities.contains(
      DoctorCapability.urgentRequests,
    );
    final hasHomeVisits = capabilities.contains(DoctorCapability.homeVisits);
    final hasAttention =
        capabilities.contains(DoctorCapability.workQueue) &&
        demoState.attentionItems.isNotEmpty;
    final nextAppointment = agendaNextAppointment == null
        ? demoState.nextAppointment
        : DoctorHomeAppointment(
            time: DateFormat('HH:mm').format(agendaNextAppointment!.dateTime),
            patientName: agendaNextAppointment!.patientName,
            reason: agendaNextAppointment!.reason,
            location: agendaNextAppointment!.locationName,
            relativeTime: 'Dans 45 min',
          );
    final hasNextAppointment = hasAgenda && nextAppointment != null;
    final urgentStatus = urgentController == null
        ? demoState.urgentStatus
        : _homeUrgentStatus(urgentController!.state);
    final hasUrgentStatus = hasUrgentRequests && urgentStatus != null;
    final hasActiveConsultation = demoState.activeConsultation != null;
    final hasHomeVisitContext = hasHomeVisits && !hasUrgentRequests;
    final isQuietDay =
        !hasActiveConsultation &&
        !hasAttention &&
        !hasNextAppointment &&
        !hasUrgentStatus;

    return SingleChildScrollView(
      key: const ValueKey('doctor-home-scroll'),
      padding: const EdgeInsets.fromLTRB(
        OmniSpacing.pageHorizontal,
        OmniSpacing.pageVertical,
        OmniSpacing.pageHorizontal,
        OmniSpacing.xxl,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Greeting(profile: profile),
              if (hasActiveConsultation) ...[
                const SizedBox(height: OmniSpacing.xl),
                _ActiveConsultationBanner(
                  consultation: demoState.activeConsultation!,
                  onResume: () => _showUpcomingFeatureSheet(
                    context,
                    'La consultation sera ajoutée dans une prochaine étape de la démo.',
                  ),
                ),
              ],
              if (hasAttention) ...[
                const SizedBox(height: OmniSpacing.xxl),
                _SectionHeader(
                  title: 'À traiter',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Semantics(
                        label:
                            '${demoState.attentionItems.length} actions à traiter',
                        child: Text(
                          '${demoState.attentionItems.length}',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: OmniColors.textSecondary,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => _showUpcomingFeatureSheet(
                          context,
                          'La liste complète des actions sera ajoutée dans une prochaine étape de la démo.',
                        ),
                        child: const Text('Voir tout'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: OmniSpacing.md),
                _AttentionPreview(items: demoState.attentionItems.take(3)),
              ],
              if (hasNextAppointment) ...[
                const SizedBox(height: OmniSpacing.xxl),
                _SectionHeader(title: 'Prochain rendez-vous'),
                const SizedBox(height: OmniSpacing.md),
                _NextAppointmentCard(
                  appointment: nextAppointment,
                  onOpenAgenda: onOpenAgenda,
                ),
              ],
              if (hasUrgentStatus) ...[
                const SizedBox(height: OmniSpacing.xxl),
                _SectionHeader(title: 'Urgences à domicile'),
                const SizedBox(height: OmniSpacing.md),
                _UrgentAvailabilityCard(
                  status: urgentStatus,
                  onOpenUrgencies: onOpenUrgencies,
                ),
              ] else if (hasHomeVisitContext && !isQuietDay) ...[
                const SizedBox(height: OmniSpacing.xxl),
                const _HomeVisitContext(),
              ],
              if (isQuietDay) ...[
                const SizedBox(height: OmniSpacing.xxl),
                const _QuietDayState(),
              ],
              if (workspaceConfig != null) ...[
                const SizedBox(height: OmniSpacing.xxl),
                _ActivitySummary(config: workspaceConfig!),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReal(BuildContext context, DoctorHomeController controller) {
    final summary = controller.summary;
    final activeConsultation = activeConsultationController?.active;
    final activeAuthorityReady =
        activeConsultationController == null ||
        activeConsultationController?.state ==
            DoctorActiveConsultationLoadState.ready;
    final nextRequest = summary?.nextPendingRequest;
    final nextAppointment = summary?.nextConfirmedAppointment;
    final hasUrgentRequests = capabilities.contains(
      DoctorCapability.urgentRequests,
    );
    final urgentStatus = urgentController == null
        ? null
        : _homeUrgentStatus(urgentController!.state);
    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: SingleChildScrollView(
        key: const ValueKey('doctor-home-scroll'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          OmniSpacing.pageHorizontal,
          OmniSpacing.pageVertical,
          OmniSpacing.pageHorizontal,
          OmniSpacing.xxl,
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Greeting(profile: profile),
                if (activeConsultation != null) ...[
                  const SizedBox(height: OmniSpacing.xl),
                  _CanonicalActiveConsultationCard(
                    consultation: activeConsultation,
                    onContinue: onOpenActiveConsultation,
                  ),
                ] else if (activeConsultationController?.isLoading == true) ...[
                  const SizedBox(height: OmniSpacing.xl),
                  const LinearProgressIndicator(),
                ] else if (!activeAuthorityReady) ...[
                  const SizedBox(height: OmniSpacing.xl),
                  const _HomeNeutralCard(
                    icon: Icons.sync_problem_outlined,
                    message: 'Synchronisation de la consultation indisponible.',
                  ),
                ],
                if (controller.state == DoctorHomeLoadState.loading &&
                    summary == null) ...[
                  const SizedBox(height: OmniSpacing.xxl),
                  const Center(child: CircularProgressIndicator()),
                ] else if (controller.state == DoctorHomeLoadState.failed &&
                    summary == null) ...[
                  const SizedBox(height: OmniSpacing.xxl),
                  _HomeFailure(
                    message:
                        controller.failure?.message ??
                        'Le résumé est momentanément indisponible.',
                    onRetry: controller.refresh,
                  ),
                ] else ...[
                  const SizedBox(height: OmniSpacing.xxl),
                  _SectionHeader(
                    title: 'À traiter',
                    trailing: Semantics(
                      label:
                          '${summary?.pendingRequestCount ?? 0} demandes à traiter',
                      child: Text(
                        '${summary?.pendingRequestCount ?? 0}',
                        key: const ValueKey('doctor-pending-request-count'),
                        style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: OmniColors.textSecondary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: OmniSpacing.md),
                  if (nextRequest == null)
                    const _HomeNeutralCard(
                      key: ValueKey('doctor-no-pending-request'),
                      icon: Icons.check_circle_outline_rounded,
                      message: 'Aucune demande en attente.',
                    )
                  else
                    _ScheduledRequestCard(
                      request: nextRequest,
                      onTap: nextRequest.requestId == null
                          ? null
                          : () => onOpenBookingRequest?.call(
                              nextRequest.requestId!,
                            ),
                    ),
                  if (activeConsultation == null && activeAuthorityReady) ...[
                    const SizedBox(height: OmniSpacing.xxl),
                    const _SectionHeader(title: 'Rendez-vous à démarrer'),
                    const SizedBox(height: OmniSpacing.md),
                    if (nextAppointment == null)
                      const _HomeNeutralCard(
                        key: ValueKey('doctor-no-next-appointment'),
                        icon: Icons.event_available_outlined,
                        message: 'Aucun rendez-vous confirmé.',
                      )
                    else
                      _NextAppointmentCard(
                        appointment: DoctorHomeAppointment(
                          time: DateFormat('HH:mm').format(
                            schedulingWallClock(
                              nextAppointment.start,
                              timezone: nextAppointment.timezone,
                            ),
                          ),
                          patientName: nextAppointment.subject.displayName,
                          reason: 'Rendez-vous confirmé',
                          location: nextAppointment.cabinet.name,
                        ),
                        onOpenAgenda: onOpenAgenda,
                        onStart: nextAppointment.appointmentId == null
                            ? null
                            : () => onOpenAppointment?.call(
                                nextAppointment.appointmentId!,
                              ),
                      ),
                  ],
                  if (controller.failure != null) ...[
                    const SizedBox(height: OmniSpacing.md),
                    _HomeFailure(
                      message: controller.failure!.message,
                      onRetry: controller.refresh,
                    ),
                  ],
                ],
                if (hasUrgentRequests && urgentStatus != null) ...[
                  const SizedBox(height: OmniSpacing.xxl),
                  const _SectionHeader(title: 'Urgences à domicile'),
                  const SizedBox(height: OmniSpacing.md),
                  _UrgentAvailabilityCard(
                    status: urgentStatus,
                    onOpenUrgencies: onOpenUrgencies,
                  ),
                ],
                if (workspaceConfig != null) ...[
                  const SizedBox(height: OmniSpacing.xxl),
                  _ActivitySummary(config: workspaceConfig!),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void _showUpcomingFeatureSheet(BuildContext context, String message) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          OmniSpacing.xl,
          OmniSpacing.sm,
          OmniSpacing.xl,
          OmniSpacing.xxl,
        ),
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: OmniColors.textSecondary,
            height: 1.45,
          ),
        ),
      ),
    ),
  );
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.profile});

  final DoctorDisplayProfile profile;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Bonjour ${profile.greetingName}',
          style: textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: OmniSpacing.xs),
        Text(
          profile.todayLabel,
          style: textTheme.bodyMedium?.copyWith(
            color: OmniColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
      ),
      trailing ?? const SizedBox.shrink(),
    ],
  );
}

class _ActiveConsultationBanner extends StatelessWidget {
  const _ActiveConsultationBanner({
    required this.consultation,
    required this.onResume,
  });

  final DoctorHomeActiveConsultation consultation;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: 'Consultation en cours avec ${consultation.patientName}',
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(OmniSpacing.base),
      decoration: BoxDecoration(
        color: OmniColors.clinicalCyanSoft,
        borderRadius: BorderRadius.circular(OmniRadii.card),
        border: Border.all(
          color: OmniColors.clinicalCyan.withValues(alpha: .2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _IconCircle(
            icon: Icons.medical_services_rounded,
            background: OmniColors.surfacePrimary,
            color: OmniColors.clinicalCyan,
          ),
          const SizedBox(width: OmniSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Consultation en cours',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: OmniColors.clinicalCyan,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: OmniSpacing.xs),
                Text(
                  consultation.patientName,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  '${consultation.reason} · ${consultation.elapsedLabel}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: OmniColors.textSecondary,
                  ),
                ),
                const SizedBox(height: OmniSpacing.md),
                TextButton.icon(
                  onPressed: onResume,
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: const Text('Reprendre'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _AttentionPreview extends StatelessWidget {
  const _AttentionPreview({required this.items});

  final Iterable<DoctorHomeAttentionItem> items;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: OmniColors.surfacePrimary,
      borderRadius: BorderRadius.circular(OmniRadii.card),
      border: Border.all(color: OmniColors.borderLight),
      boxShadow: const [OmniColors.shadowSm],
    ),
    child: Column(
      children: items
          .map(
            (item) =>
                _AttentionRow(item: item, isLast: identical(item, items.last)),
          )
          .toList(growable: false),
    ),
  );
}

class _AttentionRow extends StatelessWidget {
  const _AttentionRow({required this.item, required this.isLast});

  final DoctorHomeAttentionItem item;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final treatment = _attentionTreatment(item.kind);
    return Semantics(
      label: '${item.title}, ${item.patientName}, ${item.dueLabel}',
      child: Container(
        padding: const EdgeInsets.all(OmniSpacing.base),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : const Border(bottom: BorderSide(color: OmniColors.borderLight)),
        ),
        child: Row(
          children: [
            _IconCircle(
              icon: treatment.icon,
              background: treatment.background,
              color: treatment.color,
            ),
            const SizedBox(width: OmniSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.patientName,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: OmniColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              item.dueLabel,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: treatment.color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NextAppointmentCard extends StatelessWidget {
  const _NextAppointmentCard({
    required this.appointment,
    required this.onOpenAgenda,
    this.onStart,
  });

  final DoctorHomeAppointment appointment;
  final VoidCallback? onOpenAgenda;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
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
        Row(
          children: [
            Text(
              appointment.time,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: OmniColors.deepTeal,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            if (appointment.relativeTime != null)
              Text(
                appointment.relativeTime!,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: OmniColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
        const SizedBox(height: OmniSpacing.sm),
        Text(
          appointment.patientName,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 2),
        Text(
          appointment.reason,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: OmniColors.textSecondary),
        ),
        if (appointment.location != null) ...[
          const SizedBox(height: OmniSpacing.xs),
          Text(
            appointment.location!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: OmniColors.slateBlue,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        if (onOpenAgenda != null) ...[
          const SizedBox(height: OmniSpacing.md),
          Wrap(
            spacing: OmniSpacing.sm,
            runSpacing: OmniSpacing.sm,
            children: [
              if (onStart != null)
                FilledButton.icon(
                  key: const ValueKey('doctor-home-start-consultation'),
                  onPressed: onStart,
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: const Text('Démarrer la consultation'),
                ),
              TextButton.icon(
                onPressed: onOpenAgenda,
                icon: const Icon(Icons.calendar_month_rounded, size: 18),
                label: const Text('Voir dans l’agenda'),
              ),
            ],
          ),
        ],
      ],
    ),
  );
}

class _CanonicalActiveConsultationCard extends StatelessWidget {
  const _CanonicalActiveConsultationCard({
    required this.consultation,
    required this.onContinue,
  });

  final DoctorActiveConsultation consultation;
  final VoidCallback? onContinue;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
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
          'Consultation en cours',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: OmniSpacing.xs),
        Text(
          'Épisode ${consultation.consultationId}',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: OmniColors.textSecondary),
        ),
        const SizedBox(height: OmniSpacing.md),
        FilledButton.icon(
          key: const ValueKey('doctor-home-continue-consultation'),
          onPressed: onContinue,
          icon: const Icon(Icons.medical_services_outlined),
          label: const Text('Continuer la consultation'),
        ),
      ],
    ),
  );
}

class _ScheduledRequestCard extends StatelessWidget {
  const _ScheduledRequestCard({required this.request, this.onTap});

  final PatientScheduledCareItem request;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: OmniColors.surfacePrimary,
    borderRadius: BorderRadius.circular(OmniRadii.card),
    child: InkWell(
      key: const ValueKey('doctor-next-pending-request'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(OmniRadii.card),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(OmniSpacing.base),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(OmniRadii.card),
          border: Border.all(color: OmniColors.borderLight),
          boxShadow: const [OmniColors.shadowSm],
        ),
        child: Row(
          children: [
            const _IconCircle(
              icon: Icons.calendar_month_outlined,
              background: OmniColors.infoBlueSoft,
              color: OmniColors.infoBlue,
            ),
            const SizedBox(width: OmniSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Demande de rendez-vous',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    request.subject.displayName,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: OmniColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${DateFormat('dd/MM/yyyy').format(schedulingWallClock(request.start, timezone: request.timezone))} · '
                    '${DateFormat('HH:mm').format(schedulingWallClock(request.start, timezone: request.timezone))}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: OmniColors.infoBlue,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    ),
  );
}

class _HomeNeutralCard extends StatelessWidget {
  const _HomeNeutralCard({
    super.key,
    required this.icon,
    required this.message,
  });

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(OmniSpacing.base),
    decoration: BoxDecoration(
      color: OmniColors.slateSoft,
      borderRadius: BorderRadius.circular(OmniRadii.card),
      border: Border.all(color: OmniColors.borderLight),
    ),
    child: Row(
      children: [
        Icon(icon, color: OmniColors.deepTeal),
        const SizedBox(width: OmniSpacing.md),
        Expanded(child: Text(message)),
      ],
    ),
  );
}

class _HomeFailure extends StatelessWidget {
  const _HomeFailure({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(OmniSpacing.base),
    decoration: BoxDecoration(
      color: OmniColors.urgentCoralSoft,
      borderRadius: BorderRadius.circular(OmniRadii.card),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(message),
        const SizedBox(height: OmniSpacing.sm),
        TextButton(
          key: const ValueKey('doctor-home-retry'),
          onPressed: onRetry,
          child: const Text('Réessayer'),
        ),
      ],
    ),
  );
}

class _UrgentAvailabilityCard extends StatelessWidget {
  const _UrgentAvailabilityCard({
    required this.status,
    required this.onOpenUrgencies,
  });

  final DoctorHomeUrgentStatus status;
  final VoidCallback? onOpenUrgencies;

  @override
  Widget build(BuildContext context) {
    final details = switch (status) {
      DoctorHomeUrgentStatus.offline => (
        label: 'Indisponible',
        description: 'Vous ne recevez pas de demandes urgentes pour le moment.',
        color: OmniColors.textSecondary,
        background: OmniColors.slateSoft,
      ),
      DoctorHomeUrgentStatus.available => (
        label: 'Disponible',
        description: 'Vous pouvez recevoir des demandes urgentes.',
        color: OmniColors.deepTeal,
        background: OmniColors.mintSoft,
      ),
      DoctorHomeUrgentStatus.requestPending => (
        label: 'Demande en attente',
        description: 'Une demande urgente attend votre attention.',
        color: OmniColors.urgentCoral,
        background: OmniColors.urgentCoralSoft,
      ),
      DoctorHomeUrgentStatus.missionInProgress => (
        label: 'Intervention urgente en cours',
        description: 'Votre mission urgente est toujours active.',
        color: OmniColors.urgentCoral,
        background: OmniColors.urgentCoralSoft,
      ),
    };
    return Semantics(
      label: 'Urgences à domicile : ${details.label}',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(OmniSpacing.base),
        decoration: BoxDecoration(
          color: details.background,
          borderRadius: BorderRadius.circular(OmniRadii.card),
          border: Border.all(color: details.color.withValues(alpha: .2)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _IconCircle(
              icon: Icons.emergency_rounded,
              background: OmniColors.surfacePrimary,
              color: details.color,
            ),
            const SizedBox(width: OmniSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    details.label,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: details.color,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: OmniSpacing.xs),
                  Text(
                    details.description,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: OmniColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  if (onOpenUrgencies != null) ...[
                    const SizedBox(height: OmniSpacing.md),
                    TextButton.icon(
                      onPressed: onOpenUrgencies,
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      label: const Text('Voir les urgences'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeVisitContext extends StatelessWidget {
  const _HomeVisitContext();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(OmniSpacing.base),
    decoration: BoxDecoration(
      color: OmniColors.slateSoft,
      borderRadius: BorderRadius.circular(OmniRadii.card),
      border: Border.all(color: OmniColors.borderLight),
    ),
    child: const Row(
      children: [
        _IconCircle(
          icon: Icons.home_work_outlined,
          background: OmniColors.surfacePrimary,
          color: OmniColors.slateBlue,
        ),
        SizedBox(width: OmniSpacing.md),
        Expanded(child: Text('Visites à domicile · Disponible aujourd’hui')),
      ],
    ),
  );
}

class _QuietDayState extends StatelessWidget {
  const _QuietDayState();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(OmniSpacing.lg),
    decoration: BoxDecoration(
      color: OmniColors.slateSoft,
      borderRadius: BorderRadius.circular(OmniRadii.card),
      border: Border.all(color: OmniColors.borderLight),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _IconCircle(
          icon: Icons.check_circle_outline_rounded,
          background: OmniColors.surfacePrimary,
          color: OmniColors.deepTeal,
        ),
        SizedBox(width: OmniSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tout est à jour'),
              SizedBox(height: OmniSpacing.xs),
              Text('Vos prochains rendez-vous et actions apparaîtront ici.'),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ActivitySummary extends StatelessWidget {
  const _ActivitySummary({required this.config});

  final DoctorWorkspaceConfig config;

  @override
  Widget build(BuildContext context) {
    final labels = <String>{
      ...config.practiceModes.map((mode) => mode.label),
      if (config.services.contains(
        DoctorWorkspaceService.urgentCabinetConsultations,
      ))
        'Urgences au cabinet',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'Votre activité'),
        const SizedBox(height: OmniSpacing.md),
        Wrap(
          spacing: OmniSpacing.sm,
          runSpacing: OmniSpacing.sm,
          children: labels
              .map(
                (label) => Chip(
                  label: Text(label),
                  visualDensity: VisualDensity.compact,
                ),
              )
              .toList(growable: false),
        ),
      ],
    );
  }
}

class _IconCircle extends StatelessWidget {
  const _IconCircle({
    required this.icon,
    required this.background,
    required this.color,
  });

  final IconData icon;
  final Color background;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(color: background, shape: BoxShape.circle),
    child: Icon(icon, color: color, size: 20),
  );
}

({IconData icon, Color background, Color color}) _attentionTreatment(
  DoctorHomeAttentionKind kind,
) => switch (kind) {
  DoctorHomeAttentionKind.urgent => (
    icon: Icons.priority_high_rounded,
    background: OmniColors.urgentCoralSoft,
    color: OmniColors.urgentCoral,
  ),
  DoctorHomeAttentionKind.result => (
    icon: Icons.science_outlined,
    background: OmniColors.clinicalCyanSoft,
    color: OmniColors.clinicalCyan,
  ),
  DoctorHomeAttentionKind.followUp => (
    icon: Icons.follow_the_signs_outlined,
    background: OmniColors.mintSoft,
    color: OmniColors.deepTeal,
  ),
  DoctorHomeAttentionKind.appointmentRequest => (
    icon: Icons.calendar_month_outlined,
    background: OmniColors.infoBlueSoft,
    color: OmniColors.infoBlue,
  ),
  DoctorHomeAttentionKind.incompleteConsultation => (
    icon: Icons.medical_services_outlined,
    background: OmniColors.amberSoft,
    color: OmniColors.amber,
  ),
  DoctorHomeAttentionKind.message => (
    icon: Icons.chat_bubble_outline_rounded,
    background: OmniColors.slateSoft,
    color: OmniColors.slateBlue,
  ),
};
