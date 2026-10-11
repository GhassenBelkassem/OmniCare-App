import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/omni_theme.dart';
import '../application/patient_appointments_controller.dart';
import '../data/patient_appointment_models.dart';
import 'widgets/appointment_formatters.dart';
import 'widgets/appointment_status_chip.dart';
import 'widgets/patient_appointment_card.dart';

class PatientAppointmentDetailScreen extends StatelessWidget {
  const PatientAppointmentDetailScreen({
    super.key,
    required this.appointmentId,
    this.controller,
    this.prototypeController,
  });

  final String appointmentId;
  final PatientAppointmentsController? controller;
  final Object? prototypeController;

  @override
  Widget build(BuildContext context) {
    if (controller != null) {
      return AnimatedBuilder(
        animation: controller!,
        builder: (context, _) => _buildContent(context, controller!),
      );
    }
    return _buildContent(
      context,
      context.watch<PatientAppointmentsController>(),
    );
  }

  Widget _buildContent(
    BuildContext context,
    PatientAppointmentsController appointmentsController,
  ) {
    final appointment = appointmentsController.byId(appointmentId);
    if (appointment == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Rendez-vous')),
        body: const Center(child: Text('Rendez-vous introuvable.')),
      );
    }

    return Scaffold(
      backgroundColor: OmniColors.pageBackground,
      appBar: AppBar(title: const Text('Détails du rendez-vous')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            OmniSpacing.pageHorizontal,
            OmniSpacing.md,
            OmniSpacing.pageHorizontal,
            OmniSpacing.xxl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _statusHeader(appointment),
              const SizedBox(height: OmniSpacing.base),
              _providerPanel(appointment),
              const SizedBox(height: OmniSpacing.base),
              _datePanel(appointment),
              const SizedBox(height: OmniSpacing.base),
              _informationPanel(appointment),
              if (appointment.status ==
                      PatientAppointmentStatus.pendingPatientTimeConfirmation &&
                  appointment.requestedStartAt != null) ...[
                const SizedBox(height: OmniSpacing.base),
                _PreparationPanel(
                  text:
                      'Demande initiale : ${formatAppointmentDate(appointment.requestedStartAt!)} · ${formatAppointmentTimeRange(appointment.requestedStartAt!, appointment.requestedEndAt!)}\nLe nouveau créneau attend votre confirmation.',
                ),
              ],
              if (appointment.preparationInstructions != null) ...[
                const SizedBox(height: OmniSpacing.base),
                _PreparationPanel(text: appointment.preparationInstructions!),
              ],
              if (appointment.status ==
                  PatientAppointmentStatus.pendingPatientTimeConfirmation) ...[
                const SizedBox(height: OmniSpacing.lg),
                FilledButton(
                  key: const ValueKey('appointment-accept-counterproposal'),
                  onPressed: () => appointmentsController.acceptCounterproposal(
                    appointment.resourceId,
                  ),
                  child: const Text('ACCEPTER CE CRÉNEAU'),
                ),
                const SizedBox(height: OmniSpacing.sm),
                OutlinedButton(
                  key: const ValueKey('appointment-decline-counterproposal'),
                  onPressed: () => appointmentsController
                      .declineCounterproposal(appointment.resourceId),
                  child: const Text('Refuser'),
                ),
              ],
              if (appointment.cancelledAt != null) ...[
                const SizedBox(height: OmniSpacing.base),
                _PreparationPanel(
                  text:
                      '${appointment.cancellationReason ?? 'Rendez-vous annulé'}${appointment.lateCancellation ? '\nAnnulation à moins de 24 h, sans pénalité financière.' : ''}',
                ),
              ],
              if (appointment.canCancel) ...[
                const SizedBox(height: OmniSpacing.lg),
                OutlinedButton.icon(
                  key: const ValueKey('cancel-appointment'),
                  onPressed: () => _confirmCancellation(
                    context,
                    appointmentsController,
                    appointment,
                  ),
                  icon: const Icon(Icons.event_busy_outlined),
                  label: const Text('Annuler le rendez-vous'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: OmniColors.error,
                    side: const BorderSide(color: OmniColors.error),
                  ),
                ),
              ],
              if (appointment.canReportProblem) ...[
                const SizedBox(height: OmniSpacing.sm),
                OutlinedButton(
                  key: const ValueKey('report-appointment-problem'),
                  onPressed: () => _showReportSheet(context),
                  child: const Text('Signaler un problème'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusHeader(PatientAppointment appointment) {
    final title = switch (appointment.status) {
      PatientAppointmentStatus.pendingDoctor =>
        'En attente de confirmation du médecin',
      PatientAppointmentStatus.pendingPatientTimeConfirmation =>
        'Nouveau créneau proposé',
      PatientAppointmentStatus.confirmed => 'Rendez-vous confirmé',
      PatientAppointmentStatus.completed => 'Rendez-vous terminé',
      PatientAppointmentStatus.cancelledByPatient ||
      PatientAppointmentStatus.cancelledByDoctor => 'Rendez-vous annulé',
      PatientAppointmentStatus.expired => 'Demande expirée',
    };
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: OmniColors.textPrimary,
            ),
          ),
        ),
        AppointmentStatusChip(status: appointment.status),
      ],
    );
  }

  Widget _providerPanel(PatientAppointment appointment) {
    return Container(
      padding: const EdgeInsets.all(OmniSpacing.base),
      decoration: BoxDecoration(
        color: OmniColors.surfacePrimary,
        borderRadius: BorderRadius.circular(OmniRadii.card),
        border: Border.all(color: OmniColors.borderLight),
      ),
      child: Row(
        children: [
          AppointmentProviderAvatar(appointment: appointment, size: 64),
          const SizedBox(width: OmniSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appointment.providerDisplayName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: OmniColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  appointment.providerSubtitle,
                  style: const TextStyle(color: OmniColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _datePanel(PatientAppointment appointment) {
    return Container(
      padding: const EdgeInsets.all(OmniSpacing.base),
      decoration: BoxDecoration(
        color: OmniColors.mintSoft,
        borderRadius: BorderRadius.circular(OmniRadii.card),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_month_outlined, color: OmniColors.deepTeal),
          const SizedBox(width: OmniSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatAppointmentDate(appointment.startAt),
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: OmniColors.deepTealActive,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  formatAppointmentTimeRange(
                    appointment.startAt,
                    appointment.endAt,
                  ),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: OmniColors.deepTealActive,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _informationPanel(PatientAppointment appointment) {
    return _DetailPanel(
      children: [
        _InfoRow(
          icon: Icons.person_outline_rounded,
          label: 'Patient',
          value: appointment.subjectDisplayName,
        ),
        _InfoRow(
          icon: Icons.location_on_outlined,
          label: 'Cabinet / lieu',
          value:
              '${appointment.locationName}\n${appointment.address}, ${appointment.city}',
        ),
        _InfoRow(
          icon: Icons.medical_services_outlined,
          label: 'Type de consultation',
          value: appointment.consultationType,
        ),
        _InfoRow(
          icon: Icons.tag_outlined,
          label: 'Référence',
          value: appointment.appointmentReference,
        ),
      ],
    );
  }

  Future<void> _confirmCancellation(
    BuildContext context,
    PatientAppointmentsController appointmentsController,
    PatientAppointment appointment,
  ) async {
    var reason = '';
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Annuler ce rendez-vous ?'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${appointment.providerDisplayName}\n${formatAppointmentDate(appointment.startAt)} · ${formatAppointmentTimeRange(appointment.startAt, appointment.endAt)}\n\n${appointment.startAt.difference(DateTime.now()) < const Duration(hours: 24) ? 'Ce rendez-vous commence dans moins de 24 h. Vous pouvez toujours annuler, sans pénalité financière.' : 'Cette action libérera le créneau.'}',
              ),
              const SizedBox(height: OmniSpacing.base),
              TextField(
                key: const ValueKey('patient-cancellation-reason'),
                onChanged: (value) => reason = value,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Motif (facultatif)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Retour'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: OmniColors.error),
            child: const Text('Annuler le rendez-vous'),
          ),
        ],
      ),
    );
    if (accepted == true && context.mounted) {
      final cancelled = await appointmentsController.cancelAppointment(
        appointment.resourceId,
        reason: reason.trim().isEmpty ? null : reason.trim(),
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            cancelled
                ? 'Rendez-vous annulé.'
                : 'Impossible d’annuler. Les informations ont été actualisées.',
          ),
        ),
      );
    }
  }

  Future<void> _showReportSheet(BuildContext context) {
    const categories = [
      'Problème avec le rendez-vous',
      'Médecin ou clinique indisponible',
      'Informations incorrectes',
      'Problème sur place',
      'Autre',
    ];
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * .7,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              OmniSpacing.pageHorizontal,
              OmniSpacing.xs,
              OmniSpacing.pageHorizontal,
              OmniSpacing.base,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Besoin d’aide ?',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: OmniSpacing.sm),
                for (final category in categories)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.help_outline_rounded),
                    title: Text(category),
                    onTap: () => Navigator.of(sheetContext).pop(),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailPanel extends StatelessWidget {
  const _DetailPanel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(OmniSpacing.base),
      decoration: BoxDecoration(
        color: OmniColors.surfacePrimary,
        borderRadius: BorderRadius.circular(OmniRadii.card),
        border: Border.all(color: OmniColors.borderLight),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1) const Divider(height: OmniSpacing.lg),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: OmniColors.slateBlue),
        const SizedBox(width: OmniSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
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
            ],
          ),
        ),
      ],
    );
  }
}

class _PreparationPanel extends StatelessWidget {
  const _PreparationPanel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(OmniSpacing.base),
      decoration: BoxDecoration(
        color: OmniColors.infoBlueSoft,
        borderRadius: BorderRadius.circular(OmniRadii.card),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded, color: OmniColors.infoBlue),
          const SizedBox(width: OmniSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Préparation',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(text),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
