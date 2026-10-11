import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme/omni_theme.dart';
import '../scheduled_care/application/scheduled_care_controller.dart';
import 'scheduled_care_controller.dart';
import 'scheduled_request_status_screen.dart';

class ScheduledBookingReviewScreen extends StatelessWidget {
  const ScheduledBookingReviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ScheduledCareController?>();
    if (controller == null) return const _LegacyBookingReview();
    final draft = controller.draft;
    if (!draft.canReview) {
      return Scaffold(
        appBar: AppBar(title: const Text('Vérifier la demande')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(OmniSpacing.xl),
            child: Text(
              controller.failure?.message ??
                  'La demande est incomplète. Revenez au choix du créneau.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    final slot = draft.slot!;
    return Scaffold(
      backgroundColor: OmniColors.pageBackground,
      appBar: AppBar(title: const Text('Vérifier la demande')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(OmniSpacing.pageHorizontal),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Votre créneau, avant envoi',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: OmniSpacing.xs),
                    Text(
                      'Le médecin devra confirmer. Le créneau sera réservé provisoirement pendant sa réponse.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: OmniColors.textSecondary,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: OmniSpacing.lg),
                    _ReviewPanel(
                      children: [
                        _ReviewRow(
                          label: 'Patient',
                          value:
                              '${draft.subject!.displayName} · ${draft.subject!.relationship}',
                        ),
                        _ReviewRow(
                          label: 'Médecin',
                          value:
                              '${draft.doctorName}\n${draft.doctorSpecialty}',
                        ),
                        _ReviewRow(
                          label: 'Cabinet',
                          value:
                              '${draft.cabinet!.name}\n${draft.cabinet!.address}, ${draft.cabinet!.city}',
                        ),
                        _ReviewRow(
                          label: 'Date',
                          value: DateFormat(
                            'EEEE d MMMM yyyy',
                            'fr_FR',
                          ).format(slot.start),
                        ),
                        _ReviewRow(
                          label: 'Horaire',
                          value:
                              '${DateFormat('HH:mm').format(slot.start)} – ${DateFormat('HH:mm').format(slot.end)} · ${slot.durationMinutes} min',
                        ),
                        if (draft.consultationPriceTnd case final price?)
                          _ReviewRow(
                            label: 'Tarif',
                            value: '${price.toStringAsFixed(2)} TND',
                          ),
                      ],
                    ),
                    const SizedBox(height: OmniSpacing.base),
                    Container(
                      padding: const EdgeInsets.all(OmniSpacing.base),
                      decoration: BoxDecoration(
                        color: OmniColors.warningSubtle,
                        borderRadius: BorderRadius.circular(OmniRadii.card),
                        border: Border.all(color: OmniColors.amber),
                      ),
                      child: const Text(
                        'Annulation possible à tout moment. À moins de 24 h, un avertissement sera affiché, sans pénalité financière en V1.',
                      ),
                    ),
                    if (controller.failure != null) ...[
                      const SizedBox(height: OmniSpacing.sm),
                      Text(
                        controller.failure!.message,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: OmniColors.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(OmniSpacing.pageHorizontal),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey('submit-scheduled-request'),
                  onPressed: controller.isSubmitting
                      ? null
                      : () async {
                          final request = await controller.submitDraft();
                          if (!context.mounted || request == null) return;
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(
                              builder: (_) =>
                                  ChangeNotifierProvider<
                                    ScheduledCareController
                                  >.value(
                                    value: controller,
                                    child: ScheduledRequestStatusScreen(
                                      recordId: request.requestId,
                                    ),
                                  ),
                            ),
                          );
                        },
                  child: controller.isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('DEMANDER CE CRÉNEAU'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegacyBookingReview extends StatelessWidget {
  const _LegacyBookingReview();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ScheduledCarePrototypeController>();
    final draft = controller.draft;
    if (!draft.canReview) {
      return Scaffold(
        appBar: AppBar(title: const Text('Vérifier la demande')),
        body: const Center(child: Text('La demande est incomplète.')),
      );
    }
    final slot = draft.slot!;
    return Scaffold(
      backgroundColor: OmniColors.pageBackground,
      appBar: AppBar(title: const Text('Vérifier la demande')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(OmniSpacing.pageHorizontal),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Votre créneau, avant envoi',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: OmniSpacing.xs),
                    const Text(
                      'Le médecin devra confirmer. Le créneau sera réservé provisoirement pendant sa réponse.',
                    ),
                    const SizedBox(height: OmniSpacing.lg),
                    _ReviewPanel(
                      children: [
                        _ReviewRow(
                          label: 'Patient',
                          value:
                              '${draft.patient!.displayName} · ${draft.patient!.relationshipLabel}',
                        ),
                        _ReviewRow(
                          label: 'Médecin',
                          value:
                              '${draft.doctorName}\n${draft.doctorSpecialty}',
                        ),
                        _ReviewRow(
                          label: 'Cabinet',
                          value:
                              '${draft.cabinet!.name}\n${draft.cabinet!.address}, ${draft.cabinet!.city}',
                        ),
                        _ReviewRow(
                          label: 'Date',
                          value: DateFormat(
                            'EEEE d MMMM yyyy',
                            'fr_FR',
                          ).format(slot.start),
                        ),
                        _ReviewRow(
                          label: 'Horaire',
                          value:
                              '${DateFormat('HH:mm').format(slot.start)} – ${DateFormat('HH:mm').format(slot.end)} · ${slot.durationMinutes} min',
                        ),
                        if (draft.consultationPriceTnd case final price?)
                          _ReviewRow(
                            label: 'Tarif',
                            value: '${price.toStringAsFixed(2)} TND',
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(OmniSpacing.pageHorizontal),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey('submit-scheduled-request'),
                  onPressed: () {
                    final request = controller.submitDraft();
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) =>
                            ChangeNotifierProvider<
                              ScheduledCarePrototypeController
                            >.value(
                              value: controller,
                              child: ScheduledRequestStatusScreen(
                                recordId: request.id,
                              ),
                            ),
                      ),
                    );
                  },
                  child: const Text('DEMANDER CE CRÉNEAU'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewPanel extends StatelessWidget {
  const _ReviewPanel({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(OmniSpacing.base),
    decoration: BoxDecoration(
      color: OmniColors.surfacePrimary,
      borderRadius: BorderRadius.circular(OmniRadii.card),
      border: Border.all(color: OmniColors.borderLight),
    ),
    child: Column(children: children),
  );
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: OmniSpacing.sm),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 88,
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: OmniColors.textSecondary),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}
