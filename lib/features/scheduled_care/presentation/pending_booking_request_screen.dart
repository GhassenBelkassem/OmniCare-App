import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/omni_theme.dart';
import '../application/patient_booking_controller.dart';
import '../data/scheduled_care_failure.dart';
import '../domain/scheduled_care_models.dart';
import '../realtime/scheduled_care_route_visibility.dart';
import 'booking_review_screen.dart';
import 'confirmed_scheduled_appointment_screen.dart';

class PendingBookingRequestScreen extends StatefulWidget {
  const PendingBookingRequestScreen({super.key, required this.requestId});

  final String requestId;

  @override
  State<PendingBookingRequestScreen> createState() =>
      _PendingBookingRequestScreenState();
}

class _PendingBookingRequestScreenState
    extends State<PendingBookingRequestScreen>
    with ScheduledCareRouteVisibility<PendingBookingRequestScreen> {
  Timer? _deadlineTimer;
  DateTime? _scheduledDeadline;
  bool _leavingProtectedRoute = false;
  late final PatientBookingController _realtimeController;

  @override
  void initState() {
    super.initState();
    _realtimeController = context.read<PatientBookingController>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final booking = context.read<PatientBookingController>();
      if (booking.result?.requestId != widget.requestId) {
        booking.openRequest(widget.requestId);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final booking = context.watch<PatientBookingController>();
    _scheduleDeadline(booking);
    if (!_leavingProtectedRoute &&
        booking.failure?.kind == ScheduledCareFailureKind.forbidden) {
      _leavingProtectedRoute = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
      });
    }
  }

  void _scheduleDeadline(PatientBookingController booking) {
    final deadline = booking.authoritativeDeadline;
    if (deadline == _scheduledDeadline) return;
    _deadlineTimer?.cancel();
    _scheduledDeadline = deadline;
    if (deadline == null) return;
    final delay = deadline.difference(DateTime.now().toUtc());
    _deadlineTimer = Timer(delay.isNegative ? Duration.zero : delay, () {
      if (mounted) booking.refreshAtDeadline();
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
      _realtimeController.activateRealtimeRequest(widget.requestId);
    } else {
      _realtimeController.deactivateRealtimeRequest(widget.requestId);
    }
  }

  Future<void> _cancel(PatientBookingController booking) async {
    final reason = await showDialog<PatientCancellationReason>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Pourquoi annuler cette demande ?'),
        children: [
          SimpleDialogOption(
            onPressed: () =>
                Navigator.pop(context, PatientCancellationReason.changeOfPlans),
            child: const Text('Changement de programme'),
          ),
          SimpleDialogOption(
            onPressed: () => Navigator.pop(
              context,
              PatientCancellationReason.noLongerNeeded,
            ),
            child: const Text('Je n’ai plus besoin de ce rendez-vous'),
          ),
        ],
      ),
    );
    if (reason != null) await booking.cancelRequest(reason);
  }

  Future<void> _accept(PatientBookingController booking) async {
    await booking.acceptProposal();
    if (!mounted) return;
    final appointment = booking.appointment;
    if (appointment != null) {
      await Navigator.of(context).pushReplacement<void, void>(
        MaterialPageRoute(
          builder: (_) => ConfirmedScheduledAppointmentScreen(
            appointmentId: appointment.appointmentId,
          ),
        ),
      );
    }
  }

  Future<void> _openAppointment(PatientBookingController booking) async {
    if (booking.appointment == null) {
      await booking.loadConfirmedAppointment();
    }
    if (!mounted) return;
    final appointment = booking.appointment;
    if (appointment == null) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => ConfirmedScheduledAppointmentScreen(
          appointmentId: appointment.appointmentId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final booking = context.watch<PatientBookingController>();
    final request = booking.result;
    if (request == null || request.requestId != widget.requestId) {
      return Scaffold(
        body: Center(
          child: booking.isLifecycleBusy
              ? const CircularProgressIndicator()
              : const Text('Demande indisponible.'),
        ),
      );
    }
    final presentation = _presentationFor(request);
    return Scaffold(
      backgroundColor: OmniColors.pageBackground,
      appBar: AppBar(
        backgroundColor: OmniColors.pageBackground,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(presentation.appBarTitle),
        actions: [
          IconButton(
            key: const ValueKey('scheduled-care-refresh'),
            tooltip: 'Actualiser',
            onPressed: booking.isLifecycleBusy ? null : booking.refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(OmniSpacing.pageHorizontal),
          child: Column(
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: presentation.background,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  presentation.icon,
                  size: 32,
                  color: presentation.color,
                ),
              ),
              const SizedBox(height: OmniSpacing.md),
              Text(
                presentation.heading,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: OmniColors.textPrimary,
                ),
              ),
              const SizedBox(height: OmniSpacing.sm),
              Text(
                presentation.message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: OmniColors.textSecondary,
                ),
              ),
              const SizedBox(height: OmniSpacing.xl),
              _RequestDetails(request: request),
              if (booking.failure case final failure?) ...[
                const SizedBox(height: OmniSpacing.md),
                _InlineMessage(message: failure.message),
              ],
              if (booking.isLifecycleBusy) ...[
                const SizedBox(height: OmniSpacing.md),
                const LinearProgressIndicator(),
              ],
              const SizedBox(height: OmniSpacing.xl),
              if (request.status ==
                  BookingRequestStatus.pendingPatientTimeConfirmation) ...[
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    key: const ValueKey('accept-proposed-time'),
                    onPressed: booking.canAcceptProposal
                        ? () => _accept(booking)
                        : null,
                    child: const Text('Accepter ce créneau'),
                  ),
                ),
                const SizedBox(height: OmniSpacing.sm),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    key: const ValueKey('decline-proposed-time'),
                    onPressed: booking.canDeclineProposal
                        ? booking.declineProposal
                        : null,
                    child: const Text('Refuser la proposition'),
                  ),
                ),
              ],
              if (booking.canCancel) ...[
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton(
                    key: const ValueKey('cancel-booking-request'),
                    onPressed: () => _cancel(booking),
                    child: const Text('Annuler la demande'),
                  ),
                ),
                const SizedBox(height: OmniSpacing.sm),
              ],
              if (request.status == BookingRequestStatus.fulfilled) ...[
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    key: const ValueKey('open-confirmed-appointment'),
                    onPressed: booking.isLifecycleBusy
                        ? null
                        : () => _openAppointment(booking),
                    child: const Text('Voir le rendez-vous'),
                  ),
                ),
                const SizedBox(height: OmniSpacing.sm),
              ],
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: booking.isLifecycleBusy
                      ? null
                      : () => Navigator.of(
                          context,
                        ).popUntil((route) => route.isFirst),
                  child: const Text('Terminer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RequestDetails extends StatelessWidget {
  const _RequestDetails({required this.request});
  final PatientBookingRequestDetail request;

  @override
  Widget build(BuildContext context) {
    final proposal = request.proposedSlot;
    final deadline =
        request.status == BookingRequestStatus.pendingPatientTimeConfirmation
        ? proposal?.patientResponseDeadline ?? request.responseDeadline
        : request.responseDeadline;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(OmniSpacing.base),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(OmniRadii.card),
        border: Border.all(color: OmniColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _line(context, 'Médecin', request.doctor.displayName),
          _line(
            context,
            'Patient',
            request.subject.displayName ??
                (request.subject.subjectType == CareSubjectType.self
                    ? 'Moi'
                    : 'Membre de la famille'),
          ),
          _line(
            context,
            'Cabinet',
            '${request.cabinet.name} · ${request.cabinet.address}, '
                '${request.cabinet.city}',
          ),
          _line(
            context,
            'Créneau demandé',
            formatSchedulingDateTime(
              request.originalRequestedSlot.start,
              timezone: request.cabinet.timezone,
            ),
          ),
          if (proposal != null)
            _line(
              context,
              'Créneau proposé par le médecin',
              formatSchedulingDateTime(
                proposal.start,
                timezone: request.cabinet.timezone,
              ),
            ),
          if (request.status == BookingRequestStatus.pendingDoctor ||
              request.status ==
                  BookingRequestStatus.pendingPatientTimeConfirmation)
            _line(
              context,
              request.status ==
                      BookingRequestStatus.pendingPatientTimeConfirmation
                  ? 'Répondre avant'
                  : 'Réponse attendue avant',
              formatSchedulingDateTime(
                deadline,
                timezone: request.cabinet.timezone,
              ),
              last: true,
            ),
        ],
      ),
    );
  }

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
            fontWeight: FontWeight.w700,
            color: OmniColors.textPrimary,
          ),
        ),
      ],
    ),
  );
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(OmniSpacing.md),
    decoration: BoxDecoration(
      color: OmniColors.amberSoft,
      borderRadius: BorderRadius.circular(OmniRadii.field),
    ),
    child: Text(message),
  );
}

class _RequestPresentation {
  const _RequestPresentation({
    required this.appBarTitle,
    required this.heading,
    required this.message,
    required this.icon,
    required this.color,
    required this.background,
  });

  final String appBarTitle;
  final String heading;
  final String message;
  final IconData icon;
  final Color color;
  final Color background;
}

_RequestPresentation _presentationFor(PatientBookingRequestDetail request) =>
    switch (request.status) {
      BookingRequestStatus.pendingDoctor => const _RequestPresentation(
        appBarTitle: 'Demande envoyée',
        heading: 'En attente de la réponse du médecin',
        message: 'Demande en attente du médecin',
        icon: Icons.schedule_send_outlined,
        color: OmniColors.deepTeal,
        background: OmniColors.mintSoft,
      ),
      BookingRequestStatus.pendingPatientTimeConfirmation =>
        const _RequestPresentation(
          appBarTitle: 'Nouvelle proposition',
          heading: 'Le médecin propose un autre créneau',
          message: 'Vérifiez le nouvel horaire avant de répondre.',
          icon: Icons.update_rounded,
          color: OmniColors.slateBlue,
          background: OmniColors.slateSoft,
        ),
      BookingRequestStatus.fulfilled => const _RequestPresentation(
        appBarTitle: 'Demande traitée',
        heading: 'Rendez-vous confirmé',
        message: 'Votre demande a donné lieu à un rendez-vous confirmé.',
        icon: Icons.check_circle_outline_rounded,
        color: OmniColors.deepTeal,
        background: OmniColors.mintSoft,
      ),
      BookingRequestStatus.cancelledByPatient => _RequestPresentation(
        appBarTitle: 'Demande annulée',
        heading: 'Demande annulée',
        message: _patientCancellationMessage(request.cancellation?.reasonCode),
        icon: Icons.cancel_outlined,
        color: OmniColors.textSecondary,
        background: OmniColors.surfaceSecondary,
      ),
      BookingRequestStatus.cancelledByDoctor => const _RequestPresentation(
        appBarTitle: 'Demande refusée',
        heading: 'Le médecin n’a pas pu accepter',
        message: 'Vous pouvez choisir un autre créneau depuis le Cabinet.',
        icon: Icons.event_busy_outlined,
        color: OmniColors.warning,
        background: OmniColors.amberSoft,
      ),
      BookingRequestStatus.expired => _RequestPresentation(
        appBarTitle: 'Demande expirée',
        heading: 'Le délai de réponse est terminé',
        message: _expiryMessage(request.expiryReason),
        icon: Icons.timer_off_outlined,
        color: OmniColors.warning,
        background: OmniColors.amberSoft,
      ),
      BookingRequestStatus.unknown => const _RequestPresentation(
        appBarTitle: 'État de la demande',
        heading: 'État en cours de vérification',
        message: 'Actualisez la demande avant d’effectuer une action.',
        icon: Icons.help_outline_rounded,
        color: OmniColors.textSecondary,
        background: OmniColors.surfaceSecondary,
      ),
    };

String _patientCancellationMessage(String? reasonCode) => switch (reasonCode) {
  'CHANGE_OF_PLANS' =>
    'La demande a été annulée après votre changement de programme.',
  'NO_LONGER_NEEDED' =>
    'La demande a été annulée car elle n’était plus nécessaire.',
  'PROPOSAL_DECLINED' => 'La proposition du médecin a été refusée.',
  _ => 'Cette demande a été annulée.',
};

String _expiryMessage(String? reason) => switch (reason) {
  'DOCTOR_RESPONSE_TIMEOUT' =>
    'Le médecin n’a pas répondu avant la fin du délai.',
  'PATIENT_PROPOSAL_RESPONSE_TIMEOUT' =>
    'La proposition n’a pas reçu de réponse avant la fin du délai.',
  _ => 'Cette demande n’est plus active.',
};
