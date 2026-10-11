import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/omni_theme.dart';
import '../patient_appointments/presentation/patient_appointments_screen.dart';
import '../scheduled_care/application/scheduled_care_controller.dart';
import '../scheduled_care/domain/scheduled_care_models.dart';
import 'scheduled_care_controller.dart';
import 'scheduled_care_models.dart';
import 'scheduled_intake_screen.dart';

class ScheduledRequestStatusScreen extends StatefulWidget {
  const ScheduledRequestStatusScreen({super.key, required this.recordId});
  final String recordId;

  @override
  State<ScheduledRequestStatusScreen> createState() =>
      _ScheduledRequestStatusScreenState();
}

class _ScheduledRequestStatusScreenState
    extends State<ScheduledRequestStatusScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ScheduledCareController?>()?.loadRequest(widget.recordId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ScheduledCareController?>();
    if (controller == null) {
      return _LegacyRequestStatus(recordId: widget.recordId);
    }
    final record = controller.request;
    if (record == null || record.requestId != widget.recordId) {
      return Scaffold(
        appBar: AppBar(title: const Text('Demande de rendez-vous')),
        body: Center(
          child: controller.failure == null
              ? const CircularProgressIndicator()
              : Text(controller.failure!.message),
        ),
      );
    }
    return Scaffold(
      backgroundColor: OmniColors.pageBackground,
      appBar: AppBar(title: const Text('Demande de rendez-vous')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(OmniSpacing.pageHorizontal),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StatusHero(record: record),
              const SizedBox(height: OmniSpacing.base),
              _RecordSummary(record: record),
              if (controller.failure != null) ...[
                const SizedBox(height: OmniSpacing.base),
                _Explanation(text: controller.failure!.message),
              ],
              const SizedBox(height: OmniSpacing.base),
              if (record.status == 'PENDING_PATIENT_TIME_CONFIRMATION')
                _CounterproposalActions(record: record)
              else if (record.status == 'FULFILLED')
                const _ConfirmedActions()
              else if (record.status == 'PENDING_DOCTOR')
                _PendingActions(record: record)
              else
                _Explanation(text: _statusLabel(record.status)),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusHero extends StatelessWidget {
  const _StatusHero({required this.record});
  final PatientBookingRequest record;

  @override
  Widget build(BuildContext context) {
    final (icon, title, subtitle) = switch (record.status) {
      'PENDING_DOCTOR' => (
        Icons.schedule_rounded,
        'En attente de confirmation du médecin',
        'Le créneau est réservé provisoirement.',
      ),
      'PENDING_PATIENT_TIME_CONFIRMATION' => (
        Icons.event_repeat_rounded,
        'Le médecin propose un autre créneau',
        'Votre confirmation est requise.',
      ),
      'FULFILLED' => (
        Icons.check_circle_outline_rounded,
        'Rendez-vous confirmé',
        'Le créneau est confirmé pour le patient sélectionné.',
      ),
      'EXPIRED' => (
        Icons.timer_off_outlined,
        'Demande expirée',
        'Le créneau a été libéré.',
      ),
      _ => (
        Icons.event_busy_outlined,
        'Rendez-vous annulé',
        _statusLabel(record.status),
      ),
    };
    return Container(
      padding: const EdgeInsets.all(OmniSpacing.lg),
      decoration: BoxDecoration(
        color: OmniColors.surfacePrimary,
        borderRadius: BorderRadius.circular(OmniRadii.card),
        border: Border.all(color: OmniColors.borderLight),
      ),
      child: Column(
        children: [
          Icon(icon, size: 42, color: OmniColors.deepTeal),
          const SizedBox(height: OmniSpacing.sm),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: OmniSpacing.xs),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: OmniColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _RecordSummary extends StatelessWidget {
  const _RecordSummary({required this.record});
  final PatientBookingRequest record;

  @override
  Widget build(BuildContext context) {
    final slot = record.activeSlot;
    final start = displayInTimeZone(slot.start, record.cabinet.timezone);
    final end = displayInTimeZone(slot.end, record.cabinet.timezone);
    return Container(
      padding: const EdgeInsets.all(OmniSpacing.base),
      decoration: BoxDecoration(
        color: OmniColors.surfacePrimary,
        borderRadius: BorderRadius.circular(OmniRadii.card),
        border: Border.all(color: OmniColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _line(
            'Patient',
            '${record.subject.displayName} · ${record.subject.relationship}',
          ),
          _line(
            'Médecin',
            '${record.doctor.displayName} · ${record.doctor.specialty}',
          ),
          _line(
            'Cabinet',
            '${record.cabinet.name}\n${record.cabinet.address}, ${record.cabinet.city}',
          ),
          _line(
            'Créneau',
            '${DateFormat('EEEE d MMMM', 'fr_FR').format(start)} · ${DateFormat('HH:mm').format(start)}–${DateFormat('HH:mm').format(end)} · ${slot.durationMinutes} min',
          ),
          if (record.status == 'PENDING_DOCTOR')
            _line(
              'Réponse avant',
              DateFormat('d MMM · HH:mm', 'fr_FR').format(
                displayInTimeZone(
                  record.responseDeadline,
                  record.cabinet.timezone,
                ),
              ),
            ),
          if (record.proposedSlot case final proposal?)
            _line(
              'Répondre avant',
              DateFormat('d MMM · HH:mm', 'fr_FR').format(
                displayInTimeZone(
                  proposal.patientResponseDeadline,
                  record.cabinet.timezone,
                ),
              ),
            ),
          if (record.proposedSlot != null)
            _line(
              'Demande initiale',
              '${DateFormat('d MMM · HH:mm', 'fr_FR').format(displayInTimeZone(record.originalRequestedSlot.start, record.cabinet.timezone))}–${DateFormat('HH:mm').format(displayInTimeZone(record.originalRequestedSlot.end, record.cabinet.timezone))}',
            ),
          if (record.cancellation case final cancellation?)
            _line(
              'Annulé le',
              DateFormat('d MMM · HH:mm', 'fr_FR').format(
                displayInTimeZone(
                  cancellation.cancelledAt,
                  record.cabinet.timezone,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _line(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: OmniSpacing.xs),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 96,
          child: Text(
            label,
            style: const TextStyle(color: OmniColors.textSecondary),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

class _PendingActions extends StatelessWidget {
  const _PendingActions({required this.record});
  final PatientBookingRequest record;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Text(
        'Réponse idéale sous 2 h',
        textAlign: TextAlign.center,
        style: TextStyle(color: OmniColors.textSecondary),
      ),
      const SizedBox(height: OmniSpacing.base),
      if (record.can('CANCEL_REQUEST'))
        OutlinedButton(
          key: const ValueKey('cancel-scheduled-request'),
          onPressed: () => _confirmRequestCancellation(context),
          child: const Text('Annuler la demande'),
        ),
    ],
  );
}

class _CounterproposalActions extends StatelessWidget {
  const _CounterproposalActions({required this.record});
  final PatientBookingRequest record;

  @override
  Widget build(BuildContext context) {
    final controller = context.read<ScheduledCareController>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (record.can('ACCEPT_PROPOSED_TIME'))
          FilledButton(
            key: const ValueKey('accept-counterproposal'),
            onPressed: controller.isSubmitting
                ? null
                : () => controller.acceptProposal(),
            child: const Text('ACCEPTER CE CRÉNEAU'),
          ),
        const SizedBox(height: OmniSpacing.sm),
        if (record.can('DECLINE_PROPOSED_TIME'))
          OutlinedButton(
            key: const ValueKey('decline-counterproposal'),
            onPressed: controller.isSubmitting
                ? null
                : () => controller.declineProposal(),
            child: const Text('Refuser'),
          ),
      ],
    );
  }
}

class _ConfirmedActions extends StatelessWidget {
  const _ConfirmedActions();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      FilledButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PatientAppointmentsScreen()),
        ),
        child: const Text('Voir mes rendez-vous'),
      ),
    ],
  );
}

class _Explanation extends StatelessWidget {
  const _Explanation({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(OmniSpacing.base),
    decoration: BoxDecoration(
      color: OmniColors.surfaceSecondary,
      borderRadius: BorderRadius.circular(OmniRadii.card),
    ),
    child: Text(text),
  );
}

Future<void> _confirmRequestCancellation(BuildContext context) async {
  final accepted = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Annuler ?'),
      content: const Text('Le créneau sera libéré et le médecin sera informé.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Retour'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Confirmer l’annulation'),
        ),
      ],
    ),
  );
  if (accepted == true && context.mounted) {
    await context.read<ScheduledCareController>().cancelRequest();
  }
}

class _LegacyRequestStatus extends StatelessWidget {
  const _LegacyRequestStatus({required this.recordId});
  final String recordId;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ScheduledCarePrototypeController>();
    final record = controller.byId(recordId);
    if (record == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Demande de rendez-vous')),
        body: const Center(child: Text('Demande introuvable.')),
      );
    }
    final title = switch (record.status) {
      ScheduledCareStatus.pendingDoctor =>
        'En attente de confirmation du médecin',
      ScheduledCareStatus.pendingPatientTimeConfirmation =>
        'Le médecin propose un autre créneau',
      ScheduledCareStatus.confirmed => 'Rendez-vous confirmé',
      ScheduledCareStatus.expired => 'Demande expirée',
      ScheduledCareStatus.cancelledByPatient ||
      ScheduledCareStatus.cancelledByDoctor => 'Rendez-vous annulé',
    };
    return Scaffold(
      backgroundColor: OmniColors.pageBackground,
      appBar: AppBar(title: const Text('Demande de rendez-vous')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(OmniSpacing.pageHorizontal),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(OmniSpacing.lg),
                decoration: BoxDecoration(
                  color: OmniColors.surfacePrimary,
                  borderRadius: BorderRadius.circular(OmniRadii.card),
                ),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: OmniSpacing.base),
              Text(
                '${record.patient.displayName} · ${record.patient.relationshipLabel}\n'
                '${record.doctorName} · ${record.doctorSpecialty}\n'
                '${record.cabinet.name} · ${record.cabinet.city}\n'
                '${DateFormat('d MMM · HH:mm', 'fr_FR').format(record.activeSlot.start)}–${DateFormat('HH:mm').format(record.activeSlot.end)}',
              ),
              if (record.proposedSlot != null) ...[
                const SizedBox(height: OmniSpacing.sm),
                const Text('Demande initiale'),
              ],
              const SizedBox(height: OmniSpacing.lg),
              if (record.status ==
                  ScheduledCareStatus.pendingPatientTimeConfirmation) ...[
                FilledButton(
                  key: const ValueKey('accept-counterproposal'),
                  onPressed: () => controller.acceptProposalByPatient(recordId),
                  child: const Text('ACCEPTER CE CRÉNEAU'),
                ),
                OutlinedButton(
                  key: const ValueKey('decline-counterproposal'),
                  onPressed: () =>
                      controller.declineProposalByPatient(recordId),
                  child: const Text('Refuser'),
                ),
              ],
              if (record.status == ScheduledCareStatus.confirmed) ...[
                FilledButton(
                  key: const ValueKey('prepare-consultation'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ScheduledIntakeScreen(
                        recordId: recordId,
                        controller: controller,
                      ),
                    ),
                  ),
                  child: Text(
                    record.intake.status == ScheduledIntakeStatus.submitted
                        ? 'Modifier ma préparation'
                        : 'Préparer ma consultation',
                  ),
                ),
                TextButton(
                  onPressed: () => _legacyCancel(context, record),
                  child: const Text('Annuler le rendez-vous'),
                ),
              ],
              if (record.status == ScheduledCareStatus.pendingDoctor)
                OutlinedButton(
                  key: const ValueKey('cancel-scheduled-request'),
                  onPressed: () => _legacyCancel(context, record),
                  child: const Text('Annuler la demande'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _legacyCancel(
  BuildContext context,
  ScheduledCareRecordPrototype record,
) async {
  final controller = context.read<ScheduledCarePrototypeController>();
  final late =
      record.activeSlot.start.difference(controller.currentTime) <
      const Duration(hours: 24);
  var reason = '';
  final accepted = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Annuler ?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            late
                ? 'Ce rendez-vous commence dans moins de 24 h. Vous pouvez toujours annuler, sans pénalité financière.'
                : 'Le créneau sera libéré et le médecin sera informé.',
          ),
          TextField(
            key: const ValueKey('scheduled-cancellation-reason'),
            onChanged: (value) => reason = value,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Retour'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Confirmer l’annulation'),
        ),
      ],
    ),
  );
  if (accepted == true && context.mounted) {
    controller.cancelByPatient(
      record.id,
      reason: reason.trim().isEmpty ? null : reason.trim(),
    );
  }
}

String _statusLabel(String status) => switch (status) {
  'PENDING_DOCTOR' => 'En attente du médecin',
  'PENDING_PATIENT_TIME_CONFIRMATION' => 'Votre confirmation est requise',
  'FULFILLED' => 'Confirmé',
  'EXPIRED' => 'Expiré',
  'CANCELLED_BY_PATIENT' => 'Annulé par le patient',
  'CANCELLED_BY_DOCTOR' => 'Annulé par le médecin',
  _ => status,
};
