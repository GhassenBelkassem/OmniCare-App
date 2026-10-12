import 'package:flutter/material.dart';

import '../../../../core/theme/omni_theme.dart';
import '../../../scheduled_care/domain/scheduled_care_models.dart';
import '../../../scheduled_care/presentation/booking_review_screen.dart';
import '../application/doctor_appointment_controller.dart';
import '../domain/doctor_scheduled_care_models.dart';
import '../../../scheduled_care/realtime/scheduled_care_route_visibility.dart';

Future<void> showDoctorAppointmentDetail(
  BuildContext context, {
  required String appointmentId,
  required DoctorAppointmentController controller,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  builder: (_) => DoctorAppointmentDetailSheet(
    appointmentId: appointmentId,
    controller: controller,
  ),
);

class DoctorAppointmentDetailSheet extends StatefulWidget {
  const DoctorAppointmentDetailSheet({
    super.key,
    required this.appointmentId,
    required this.controller,
  });

  final String appointmentId;
  final DoctorAppointmentController controller;

  @override
  State<DoctorAppointmentDetailSheet> createState() =>
      _DoctorAppointmentDetailSheetState();
}

class _DoctorAppointmentDetailSheetState
    extends State<DoctorAppointmentDetailSheet>
    with ScheduledCareRouteVisibility<DoctorAppointmentDetailSheet> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.controller.open(widget.appointmentId);
    });
  }

  @override
  void dispose() {
    onScheduledCareRouteVisibilityChanged(false);
    super.dispose();
  }

  @override
  void onScheduledCareRouteVisibilityChanged(bool visible) {
    if (visible) {
      widget.controller.activateRealtime(widget.appointmentId);
    } else {
      widget.controller.deactivateRealtime(widget.appointmentId);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) => PopScope(
      canPop: !widget.controller.isCancelling,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .82,
        child: _body(context),
      ),
    ),
  );

  Widget _body(BuildContext context) {
    final controller = widget.controller;
    final appointment = controller.appointment;
    if (controller.state == DoctorAppointmentLoadState.loading &&
        appointment == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (appointment == null) {
      return _FailureState(
        message:
            controller.failure?.message ??
            'Ce rendez-vous est momentanément indisponible.',
        onRetry: () => controller.open(widget.appointmentId),
      );
    }
    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView(
        key: const ValueKey('doctor-appointment-detail'),
        padding: EdgeInsets.fromLTRB(
          OmniSpacing.pageHorizontal,
          OmniSpacing.sm,
          OmniSpacing.pageHorizontal,
          OmniSpacing.xxl + MediaQuery.viewPaddingOf(context).bottom,
        ),
        children: [
          Text(
            appointment.subject.displayName ?? 'Patient',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          if (appointment.subject.relationship != null)
            Text(
              appointment.subject.relationship!,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: OmniColors.textSecondary),
            ),
          const SizedBox(height: OmniSpacing.lg),
          _StatusCard(appointment: appointment),
          const SizedBox(height: OmniSpacing.md),
          _DetailCard(
            icon: Icons.tag_outlined,
            title: 'Référence du rendez-vous',
            lines: [
              'Identifiant : ${appointment.appointmentId}',
              'Demande source : ${appointment.sourceBookingRequestId}',
              'Version : ${appointment.version}',
              'Confirmé le ${formatSchedulingDateTime(appointment.confirmedAt, timezone: appointment.slot.timezone)}',
              'Créé le ${formatSchedulingDateTime(appointment.createdAt, timezone: appointment.slot.timezone)}',
              'Mis à jour le ${formatSchedulingDateTime(appointment.updatedAt, timezone: appointment.slot.timezone)}',
            ],
          ),
          const SizedBox(height: OmniSpacing.md),
          _DetailCard(
            icon: Icons.calendar_month_outlined,
            title: formatSchedulingDateTime(
              appointment.slot.start,
              timezone: appointment.slot.timezone,
            ),
            lines: [
              '${appointment.slot.durationMinutes} min',
              'Fuseau : ${appointment.slot.timezone}',
            ],
          ),
          const SizedBox(height: OmniSpacing.md),
          _DetailCard(
            icon: Icons.location_on_outlined,
            title: appointment.cabinet.name,
            lines: [
              appointment.cabinet.address,
              '${appointment.cabinet.city}, ${appointment.cabinet.governorate}',
              'Référence cabinet : ${appointment.cabinet.practiceLocationId}',
            ],
          ),
          const SizedBox(height: OmniSpacing.md),
          _DetailCard(
            icon: Icons.medical_services_outlined,
            title: appointment.doctor.displayName,
            lines: [
              if (appointment.doctor.specialty != null)
                appointment.doctor.specialty!,
              'Identifiant médecin : ${appointment.doctor.doctorId}',
              'Patient : ${appointment.subject.subjectType.wireValue}',
              if (appointment.subject.familyMemberId != null)
                'Identifiant proche : ${appointment.subject.familyMemberId}',
              if (appointment.intakeStatus != null)
                'Préparation : ${appointment.intakeStatus}',
            ],
          ),
          if (appointment.quotedPrice != null) ...[
            const SizedBox(height: OmniSpacing.md),
            _DetailCard(
              icon: Icons.payments_outlined,
              title:
                  '${appointment.quotedPrice!.amount.toStringAsFixed(2)} ${appointment.quotedPrice!.currency}',
              lines: const ['Tarif confirmé'],
            ),
          ],
          if (appointment.cancellation != null) ...[
            const SizedBox(height: OmniSpacing.md),
            _DetailCard(
              icon: Icons.event_busy_outlined,
              title: 'Rendez-vous annulé',
              lines: [
                if (appointment.cancellation!.reasonCode != null)
                  'Motif : ${appointment.cancellation!.reasonCode}',
                'Annulé le ${formatSchedulingDateTime(appointment.cancellation!.cancelledAt, timezone: appointment.slot.timezone)}',
                if (appointment.cancellation!.lateCancellation)
                  'Annulation effectuée moins de 24 h avant le rendez-vous.',
              ],
            ),
          ],
          if (controller.failure != null) ...[
            const SizedBox(height: OmniSpacing.md),
            Text(
              controller.failure!.message,
              key: const ValueKey('doctor-appointment-cancel-error'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: OmniColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (controller.canCancel || controller.isCancelling) ...[
            const SizedBox(height: OmniSpacing.xl),
            OutlinedButton.icon(
              key: const ValueKey('doctor-cancel-appointment'),
              onPressed: controller.canCancel ? _showCancellationReasons : null,
              icon: controller.isCancelling
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.event_busy_outlined),
              label: const Text('Annuler le rendez-vous'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showCancellationReasons() async {
    final reason =
        await showModalBottomSheet<DoctorAppointmentCancellationReason>(
          context: context,
          showDragHandle: true,
          builder: (context) => SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(OmniSpacing.base),
                  child: Text(
                    'Motif de l’annulation',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                ...DoctorAppointmentCancellationReason.values.map(
                  (value) => ListTile(
                    key: ValueKey(
                      'doctor-appointment-cancel-${value.wireValue}',
                    ),
                    title: Text(value.label),
                    onTap: () => Navigator.of(context).pop(value),
                  ),
                ),
                const SizedBox(height: OmniSpacing.sm),
              ],
            ),
          ),
        );
    if (reason != null && mounted) await widget.controller.cancel(reason);
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.appointment});
  final ConfirmedScheduledAppointment appointment;

  @override
  Widget build(BuildContext context) {
    final presentation = _statusPresentation(
      appointment.status,
      appointment.rawStatus,
    );
    return Container(
      padding: const EdgeInsets.all(OmniSpacing.base),
      decoration: BoxDecoration(
        color: presentation.background,
        borderRadius: BorderRadius.circular(OmniRadii.card),
      ),
      child: Row(
        children: [
          Icon(presentation.icon, color: presentation.color),
          const SizedBox(width: OmniSpacing.md),
          Expanded(
            child: Text(
              presentation.label,
              key: const ValueKey('doctor-appointment-status'),
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
            key: const ValueKey('doctor-appointment-retry'),
            onPressed: onRetry,
            child: const Text('Réessayer'),
          ),
        ],
      ),
    ),
  );
}

({String label, IconData icon, Color color, Color background})
_statusPresentation(ScheduledAppointmentStatus status, String rawStatus) =>
    switch (status) {
      ScheduledAppointmentStatus.confirmed => (
        label: 'Confirmé',
        icon: Icons.event_available_rounded,
        color: OmniColors.deepTeal,
        background: OmniColors.mintSoft,
      ),
      ScheduledAppointmentStatus.inProgress => (
        label: 'En cours',
        icon: Icons.medical_services_outlined,
        color: OmniColors.clinicalCyan,
        background: OmniColors.clinicalCyanSoft,
      ),
      ScheduledAppointmentStatus.cancelled => (
        label: 'Annulé',
        icon: Icons.event_busy_outlined,
        color: OmniColors.error,
        background: OmniColors.errorSoft,
      ),
      ScheduledAppointmentStatus.completed => (
        label: 'Terminé',
        icon: Icons.check_circle_outline_rounded,
        color: OmniColors.slateBlue,
        background: OmniColors.slateSoft,
      ),
      ScheduledAppointmentStatus.noShow => (
        label: 'Patient absent',
        icon: Icons.person_off_outlined,
        color: OmniColors.amber,
        background: OmniColors.amberSoft,
      ),
      ScheduledAppointmentStatus.unknown => (
        label: 'État indisponible ($rawStatus)',
        icon: Icons.help_outline_rounded,
        color: OmniColors.textSecondary,
        background: OmniColors.slateSoft,
      ),
    };
