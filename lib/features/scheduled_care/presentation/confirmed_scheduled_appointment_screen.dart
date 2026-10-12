import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/omni_theme.dart';
import '../application/patient_booking_controller.dart';
import '../data/scheduled_care_failure.dart';
import '../domain/patient_scheduled_care_models.dart';
import '../domain/scheduled_care_models.dart';
import '../realtime/scheduled_care_route_visibility.dart';
import 'booking_review_screen.dart';

class ConfirmedScheduledAppointmentScreen extends StatefulWidget {
  const ConfirmedScheduledAppointmentScreen({
    super.key,
    required this.appointmentId,
  });

  final String appointmentId;

  @override
  State<ConfirmedScheduledAppointmentScreen> createState() =>
      _ConfirmedScheduledAppointmentScreenState();
}

class _ConfirmedScheduledAppointmentScreenState
    extends State<ConfirmedScheduledAppointmentScreen>
    with ScheduledCareRouteVisibility<ConfirmedScheduledAppointmentScreen> {
  bool _leavingProtectedRoute = false;
  late final PatientBookingController _realtimeController;

  @override
  void initState() {
    super.initState();
    _realtimeController = context.read<PatientBookingController>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final booking = context.read<PatientBookingController>();
      if (booking.appointment?.appointmentId != widget.appointmentId) {
        booking.openAppointment(widget.appointmentId);
      }
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
      _realtimeController.activateRealtimeAppointment(widget.appointmentId);
    } else {
      _realtimeController.deactivateRealtimeAppointment(widget.appointmentId);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final booking = context.watch<PatientBookingController>();
    if (!_leavingProtectedRoute &&
        booking.failure?.kind == ScheduledCareFailureKind.forbidden) {
      _leavingProtectedRoute = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
      });
    }
  }

  Future<void> _cancel(
    PatientBookingController booking,
    ConfirmedScheduledAppointment appointment,
  ) async {
    final reason = await showModalBottomSheet<AppointmentCancellationReason?>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(
          OmniSpacing.pageHorizontal,
          0,
          OmniSpacing.pageHorizontal,
          OmniSpacing.base,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Pourquoi annuler ce rendez-vous ?',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: OmniSpacing.sm),
            ListTile(
              title: const Text('Changement de programme'),
              onTap: () => Navigator.pop(
                sheetContext,
                AppointmentCancellationReason.changeOfPlans,
              ),
            ),
            ListTile(
              title: const Text('Je n’ai plus besoin de ce rendez-vous'),
              onTap: () => Navigator.pop(
                sheetContext,
                AppointmentCancellationReason.noLongerNeeded,
              ),
            ),
          ],
        ),
      ),
    );
    if (!mounted || reason == null) return;
    final isLate =
        appointment.slot.start.difference(DateTime.now().toUtc()) <=
        const Duration(hours: 24);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Annuler ce rendez-vous ?'),
        content: Text(
          isLate
              ? 'Ce rendez-vous débute dans moins de 24 heures. '
                    'L’annulation reste possible.'
              : 'Cette action annulera votre rendez-vous.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Retour'),
          ),
          FilledButton(
            key: const ValueKey('confirm-appointment-cancellation'),
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: OmniColors.error),
            child: const Text('Annuler le rendez-vous'),
          ),
        ],
      ),
    );
    if (confirmed == true) await booking.cancelAppointment(reason);
  }

  @override
  Widget build(BuildContext context) {
    final booking = context.watch<PatientBookingController>();
    final appointment = booking.appointment;
    if (appointment == null ||
        appointment.appointmentId != widget.appointmentId) {
      return Scaffold(
        appBar: AppBar(title: const Text('Rendez-vous')),
        body: Center(
          child: booking.isLifecycleBusy
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      booking.failure?.message ??
                          'Le rendez-vous est momentanément indisponible.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: OmniSpacing.sm),
                    TextButton(
                      onPressed: () =>
                          booking.openAppointment(widget.appointmentId),
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: OmniColors.pageBackground,
      appBar: AppBar(title: const Text('Détails du rendez-vous')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(OmniSpacing.pageHorizontal),
          children: [
            const Icon(
              Icons.check_circle_rounded,
              color: OmniColors.deepTeal,
              size: 64,
            ),
            const SizedBox(height: OmniSpacing.md),
            Text(
              _statusLabel(appointment.status),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: OmniColors.textPrimary,
              ),
            ),
            const SizedBox(height: OmniSpacing.xl),
            _AppointmentDetails(appointment: appointment),
            if (booking.failure case final failure?) ...[
              const SizedBox(height: OmniSpacing.md),
              Text(
                failure.message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: OmniColors.error),
              ),
            ],
            if (booking.isLifecycleBusy) ...[
              const SizedBox(height: OmniSpacing.md),
              const LinearProgressIndicator(),
            ],
            if (booking.canCancelAppointment) ...[
              const SizedBox(height: OmniSpacing.lg),
              OutlinedButton.icon(
                key: const ValueKey('cancel-scheduled-appointment'),
                onPressed: () => _cancel(booking, appointment),
                icon: const Icon(Icons.event_busy_outlined),
                label: const Text('Annuler le rendez-vous'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: OmniColors.error,
                  side: const BorderSide(color: OmniColors.error),
                ),
              ),
            ],
            const SizedBox(height: OmniSpacing.xl),
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
                child: const Text('Terminer'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AppointmentDetails extends StatelessWidget {
  const _AppointmentDetails({required this.appointment});

  final ConfirmedScheduledAppointment appointment;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(OmniSpacing.base),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(OmniRadii.card),
      border: Border.all(color: OmniColors.borderLight),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _line(context, 'Médecin', appointment.doctor.displayName),
        if (appointment.doctor.specialty case final specialty?)
          _line(context, 'Spécialité', specialty),
        _line(
          context,
          'Patient',
          appointment.subject.displayName ??
              (appointment.subject.subjectType == CareSubjectType.self
                  ? 'Moi'
                  : 'Membre de la famille'),
        ),
        _line(context, 'Fuseau horaire', appointment.slot.timezone),
        _line(
          context,
          'Cabinet',
          '${appointment.cabinet.name} · ${appointment.cabinet.address}, '
              '${appointment.cabinet.city}',
        ),
        _line(
          context,
          'Date et heure',
          formatSchedulingDateTime(
            appointment.slot.start,
            timezone: appointment.slot.timezone,
          ),
        ),
        _line(
          context,
          'Durée',
          '${appointment.slot.durationMinutes} min',
          last: false,
        ),
        if (appointment.quotedPrice case final price?)
          _line(
            context,
            'Tarif',
            '${price.amount.toStringAsFixed(price.amount.truncateToDouble() == price.amount ? 0 : 2)} '
                '${price.currency}',
            last: false,
          ),
        _line(context, 'Statut', appointment.rawStatus),
        _line(context, 'Version', '${appointment.version}'),
        _line(context, 'Identifiant', appointment.appointmentId),
        _line(
          context,
          'Demande de réservation liée',
          appointment.sourceBookingRequestId,
        ),
        _line(
          context,
          'Confirmé le',
          formatSchedulingDateTime(
            appointment.confirmedAt,
            timezone: appointment.slot.timezone,
          ),
        ),
        _line(
          context,
          'Créé le',
          formatSchedulingDateTime(
            appointment.createdAt,
            timezone: appointment.slot.timezone,
          ),
        ),
        _line(
          context,
          'Mis à jour le',
          formatSchedulingDateTime(
            appointment.updatedAt,
            timezone: appointment.slot.timezone,
          ),
        ),
        if (appointment.intakeStatus case final intakeStatus?)
          _line(context, 'Préparation', intakeStatus),
        if (appointment.cancellation case final cancellation?) ...[
          _line(context, 'Annulé par', cancellation.actor),
          if (cancellation.reasonCode case final reason?)
            _line(context, 'Motif', reason),
          _line(
            context,
            'Annulé le',
            formatSchedulingDateTime(
              cancellation.cancelledAt,
              timezone: appointment.slot.timezone,
            ),
          ),
          _line(
            context,
            'Annulation tardive',
            cancellation.lateCancellation ? 'Oui' : 'Non',
          ),
        ],
        _line(
          context,
          'Actions disponibles',
          appointment.availableActions.isEmpty
              ? 'Aucune'
              : appointment.availableActions
                    .map((action) => action.wireValue)
                    .join(', '),
          last: true,
        ),
      ],
    ),
  );

  Widget _line(
    BuildContext context,
    String label,
    String value, {
    bool last = false,
  }) => Padding(
    padding: EdgeInsets.only(bottom: last ? 0 : OmniSpacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: OmniColors.textTertiary),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: OmniColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

String _statusLabel(ScheduledAppointmentStatus status) => switch (status) {
  ScheduledAppointmentStatus.confirmed => 'Votre rendez-vous est confirmé',
  ScheduledAppointmentStatus.inProgress => 'Rendez-vous en cours',
  ScheduledAppointmentStatus.cancelled => 'Rendez-vous annulé',
  ScheduledAppointmentStatus.completed => 'Rendez-vous terminé',
  ScheduledAppointmentStatus.noShow => 'Rendez-vous manqué',
  ScheduledAppointmentStatus.unknown => 'État du rendez-vous à vérifier',
};
