import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/omni_theme.dart';
import '../agenda/doctor_demo_appointment.dart';
import '../demo/doctor_demo_profile.dart';
import '../workspace/doctor_workspace_config.dart';
import '../urgent/doctor_urgent_controller.dart';
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
  });

  final DoctorDemoProfile profile;
  final Set<DoctorCapability> capabilities;
  final DoctorWorkspaceConfig? workspaceConfig;
  final DoctorHomeDemoState demoState;
  final DoctorDemoAppointment? agendaNextAppointment;
  final VoidCallback? onOpenAgenda;
  final VoidCallback? onOpenUrgencies;
  final DoctorUrgentController? urgentController;

  @override
  Widget build(BuildContext context) {
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

  final DoctorDemoProfile profile;

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
  });

  final DoctorHomeAppointment appointment;
  final VoidCallback? onOpenAgenda;

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
          TextButton.icon(
            onPressed: onOpenAgenda,
            icon: const Icon(Icons.calendar_month_rounded, size: 18),
            label: const Text('Voir dans l’agenda'),
          ),
        ],
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
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _SectionHeader(title: 'Votre activité'),
      const SizedBox(height: OmniSpacing.md),
      Wrap(
        spacing: OmniSpacing.sm,
        runSpacing: OmniSpacing.sm,
        children: config.practiceModes
            .map(
              (mode) => Chip(
                label: Text(mode.label),
                visualDensity: VisualDensity.compact,
              ),
            )
            .toList(growable: false),
      ),
    ],
  );
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
