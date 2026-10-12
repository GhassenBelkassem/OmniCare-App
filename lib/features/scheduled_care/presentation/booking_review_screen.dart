import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/omni_theme.dart';
import '../../patient_doctor/application/doctor_directory_controller.dart';
import '../../patient_doctor/data/doctor_detail_models.dart';
import '../../request_core/domain/request_vocabulary.dart';
import '../../request_flow/screens/who_needs_care_screen.dart';
import '../application/patient_booking_controller.dart';
import '../data/scheduled_care_failure.dart';
import '../domain/scheduled_care_models.dart';
import 'pending_booking_request_screen.dart';

class BookingReviewScreen extends StatelessWidget {
  const BookingReviewScreen({super.key});

  Future<void> _submit(BuildContext context) async {
    final booking = context.read<PatientBookingController>();
    await booking.submit();
    if (!context.mounted || booking.result == null) return;
    await Navigator.of(context).pushReplacement<void, void>(
      MaterialPageRoute(
        builder: (_) =>
            PendingBookingRequestScreen(requestId: booking.result!.requestId),
      ),
    );
  }

  Future<void> _recoverSlot(BuildContext context) async {
    final directory = context.read<DoctorDirectoryController>();
    await directory.retryFetchAvailability();
    if (context.mounted) Navigator.of(context).pop();
  }

  Future<void> _recoverContext(BuildContext context) async {
    final booking = context.read<PatientBookingController>();
    final directory = context.read<DoctorDirectoryController>();
    final doctorId = booking.intent?.doctor.doctorId;
    if (doctorId == null) return;
    await directory.fetchDetail(doctorId);
    if (!context.mounted) return;
    Navigator.of(context).pop();
  }

  void _recoverSubject(BuildContext context) {
    context.read<PatientBookingController>().abandonIntent();
    Navigator.of(context).pushAndRemoveUntil<void>(
      MaterialPageRoute(
        builder: (_) =>
            const WhoNeedsCareScreen(requestKind: RequestKind.doctor),
      ),
      (route) => route.isFirst,
    );
  }

  void _restartIntent(BuildContext context) {
    context.read<PatientBookingController>().abandonIntent();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final booking = context.watch<PatientBookingController>();
    final intent = booking.intent;
    if (intent == null) {
      return const Scaffold(
        body: Center(child: Text('Aucune demande à vérifier.')),
      );
    }
    final failure = booking.failure;
    return Scaffold(
      backgroundColor: OmniColors.pageBackground,
      appBar: AppBar(
        backgroundColor: OmniColors.pageBackground,
        elevation: 0,
        leading: IconButton(
          onPressed: booking.isSubmitting
              ? null
              : () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Vérifier la demande'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(OmniSpacing.pageHorizontal),
                children: [
                  Text(
                    'Votre demande de rendez-vous',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: OmniColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: OmniSpacing.sm),
                  Text(
                    'Le médecin devra confirmer ce créneau.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: OmniColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: OmniSpacing.xl),
                  _ReviewCard(
                    rows: [
                      _ReviewRow(
                        icon: Icons.person_outline_rounded,
                        label: 'Patient',
                        value:
                            intent.subject.displayName ??
                            (intent.subject.subjectType == CareSubjectType.self
                                ? 'Moi'
                                : 'Membre de la famille'),
                      ),
                      _ReviewRow(
                        icon: Icons.medical_services_outlined,
                        label: 'Médecin',
                        value: intent.doctor.displayName,
                        detail: intent.doctor.specialty,
                      ),
                      _ReviewRow(
                        icon: Icons.location_on_outlined,
                        label: 'Cabinet',
                        value: intent.cabinet.name,
                        detail:
                            '${intent.cabinet.address}, ${intent.cabinet.city}',
                      ),
                      _ReviewRow(
                        icon: Icons.event_outlined,
                        label: 'Créneau demandé',
                        value: formatSchedulingDateTime(
                          intent.requestedSlot.start,
                          timezone: intent.cabinet.timezone,
                        ),
                        detail:
                            '${intent.requestedSlot.durationMinutes} min · ${intent.cabinet.timezone}',
                      ),
                      if (intent.preSubmitPrice case final quote?)
                        _ReviewRow(
                          icon: Icons.payments_outlined,
                          label: 'Tarif',
                          value:
                              '${quote.amount.toStringAsFixed(quote.amount.truncateToDouble() == quote.amount ? 0 : 2)} ${quote.currency}',
                        ),
                    ],
                  ),
                  if (failure != null) ...[
                    const SizedBox(height: OmniSpacing.md),
                    _FailureCard(
                      failure: failure,
                      actionLabel: switch (failure.kind) {
                        ScheduledCareFailureKind.slotNoLongerAvailable =>
                          'Actualiser les disponibilités',
                        ScheduledCareFailureKind.bookingContextUnavailable =>
                          'Actualiser le médecin et le Cabinet',
                        ScheduledCareFailureKind.subjectUnavailable =>
                          'Choisir une autre personne',
                        ScheduledCareFailureKind.idempotencyConflict =>
                          'Recommencer depuis les disponibilités',
                        _ => null,
                      },
                      onAction: switch (failure.kind) {
                        ScheduledCareFailureKind.slotNoLongerAvailable =>
                          () => _recoverSlot(context),
                        ScheduledCareFailureKind.bookingContextUnavailable =>
                          () => _recoverContext(context),
                        ScheduledCareFailureKind.subjectUnavailable =>
                          () => _recoverSubject(context),
                        ScheduledCareFailureKind.idempotencyConflict =>
                          () => _restartIntent(context),
                        _ => null,
                      },
                    ),
                  ],
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(
                OmniSpacing.pageHorizontal,
                OmniSpacing.md,
                OmniSpacing.pageHorizontal,
                OmniSpacing.md,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: OmniColors.borderLight)),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed:
                      booking.isSubmitting ||
                          failure?.kind ==
                              ScheduledCareFailureKind.idempotencyConflict
                      ? null
                      : () => _submit(context),
                  child: booking.isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          failure?.retryable == true
                              ? 'Vérifier et réessayer'
                              : 'Envoyer la demande',
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.rows});
  final List<_ReviewRow> rows;

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(OmniRadii.card),
      border: Border.all(color: OmniColors.borderLight),
    ),
    child: Column(
      children: [
        for (var index = 0; index < rows.length; index++) ...[
          rows[index],
          if (index != rows.length - 1)
            const Divider(height: 1, color: OmniColors.borderLight),
        ],
      ],
    ),
  );
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({
    required this.icon,
    required this.label,
    required this.value,
    this.detail,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? detail;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(OmniSpacing.base),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: OmniColors.deepTeal),
        const SizedBox(width: OmniSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: OmniColors.textTertiary),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: OmniColors.textPrimary,
                ),
              ),
              if (detail != null) ...[
                const SizedBox(height: 2),
                Text(
                  detail!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: OmniColors.textSecondary,
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

class _FailureCard extends StatelessWidget {
  const _FailureCard({required this.failure, this.actionLabel, this.onAction});
  final ScheduledCareFailure failure;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(OmniSpacing.md),
    decoration: BoxDecoration(
      color: OmniColors.amberSoft,
      borderRadius: BorderRadius.circular(OmniRadii.field),
      border: Border.all(color: OmniColors.warning.withValues(alpha: 0.2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          failure.message,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: OmniColors.textPrimary),
        ),
        if (onAction != null && actionLabel != null) ...[
          const SizedBox(height: OmniSpacing.sm),
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ],
    ),
  );
}

String formatSchedulingDateTime(DateTime instant, {required String timezone}) {
  const weekdays = [
    'lundi',
    'mardi',
    'mercredi',
    'jeudi',
    'vendredi',
    'samedi',
    'dimanche',
  ];
  const months = [
    'janvier',
    'février',
    'mars',
    'avril',
    'mai',
    'juin',
    'juillet',
    'août',
    'septembre',
    'octobre',
    'novembre',
    'décembre',
  ];
  // Africa/Tunis is the current backend scheduling authority and has UTC+01
  // throughout the supported horizon. Unknown future zones remain visibly
  // UTC rather than being silently presented as Tunis local time.
  final wallClock = schedulingWallClock(instant, timezone: timezone);
  final hour = wallClock.hour.toString().padLeft(2, '0');
  final minute = wallClock.minute.toString().padLeft(2, '0');
  return '${weekdays[wallClock.weekday - 1]} ${wallClock.day} '
      '${months[wallClock.month - 1]} ${wallClock.year} · $hour:$minute';
}

/// Converts a backend instant to the resource's display wall clock.
///
/// Africa/Tunis is the only scheduling timezone currently supported by the
/// backend. Unknown future zones deliberately stay in UTC rather than falling
/// back to the device timezone.
DateTime schedulingWallClock(DateTime instant, {required String timezone}) =>
    timezone == doctorSchedulingTimezone
    ? instant.toUtc().add(const Duration(hours: 1))
    : instant.toUtc();
