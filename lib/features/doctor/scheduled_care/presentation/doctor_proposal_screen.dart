import 'dart:async';

import 'package:flutter/material.dart';
import '../../../../core/theme/omni_theme.dart';
import '../../../patient_doctor/application/doctor_directory_controller.dart';
import '../../../patient_doctor/data/doctor_detail_models.dart';
import '../../../scheduled_care/presentation/booking_review_screen.dart';
import '../application/doctor_proposal_controller.dart';
import '../domain/doctor_scheduled_care_models.dart';

class DoctorProposalScreen extends StatefulWidget {
  const DoctorProposalScreen({
    super.key,
    required this.request,
    required this.controller,
  });

  final DoctorBookingRequestDetail request;
  final DoctorProposalController controller;

  @override
  State<DoctorProposalScreen> createState() => _DoctorProposalScreenState();
}

class _DoctorProposalScreenState extends State<DoctorProposalScreen> {
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(widget.controller.begin(widget.request));
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) => PopScope(
      canPop: !widget.controller.isSubmitting,
      child: Scaffold(
        backgroundColor: OmniColors.pageBackground,
        appBar: AppBar(title: const Text('Proposer un autre horaire')),
        body: _body(context),
      ),
    ),
  );

  Widget _body(BuildContext context) {
    final controller = widget.controller;
    final request = controller.request ?? widget.request;
    if (!request.canPropose) {
      return _TerminalState(request: request);
    }
    final selectedDay = _selectedDay(controller.days);
    return SafeArea(
      top: false,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              key: const ValueKey('doctor-proposal-selector'),
              padding: const EdgeInsets.fromLTRB(
                OmniSpacing.pageHorizontal,
                OmniSpacing.pageVertical,
                OmniSpacing.pageHorizontal,
                OmniSpacing.xl,
              ),
              children: [
                _ContextCard(request: request),
                const SizedBox(height: OmniSpacing.lg),
                _MonthNavigation(
                  month: controller.month,
                  onPrevious: _canGoPrevious(controller.month)
                      ? () => _moveMonth(-1)
                      : null,
                  onNext: () => _moveMonth(1),
                ),
                const SizedBox(height: OmniSpacing.md),
                _availability(controller, selectedDay),
                if (controller.submissionFailure != null) ...[
                  const SizedBox(height: OmniSpacing.md),
                  _MessageCard(
                    key: const ValueKey('doctor-proposal-submit-error'),
                    message: controller.submissionFailure!.message,
                  ),
                ],
              ],
            ),
          ),
          _SubmitBar(
            slot: controller.selectedSlot,
            timezone: request.cabinet.timezone,
            isSubmitting: controller.isSubmitting,
            onPressed: controller.canSubmit ? _reviewAndSubmit : null,
          ),
        ],
      ),
    );
  }

  Widget _availability(
    DoctorProposalController controller,
    DoctorDayAvailability? selectedDay,
  ) {
    switch (controller.availabilityState) {
      case DoctorProposalAvailabilityState.initial:
      case DoctorProposalAvailabilityState.loading:
        return const Center(
          child: Padding(
            padding: EdgeInsets.all(OmniSpacing.xl),
            child: CircularProgressIndicator(),
          ),
        );
      case DoctorProposalAvailabilityState.failed:
        return _AvailabilityFailure(
          message:
              controller.availabilityFailure?.message ??
              'Les disponibilités sont momentanément indisponibles.',
          onRetry: controller.retryAvailability,
        );
      case DoctorProposalAvailabilityState.ready:
        if (controller.days.isEmpty) {
          return const _MessageCard(
            key: ValueKey('doctor-proposal-empty'),
            message: 'Aucun autre créneau disponible pour ce mois.',
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: controller.days.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: OmniSpacing.sm),
                itemBuilder: (context, index) {
                  final day = controller.days[index];
                  final selected = _sameDay(day.date, selectedDay?.date);
                  return ChoiceChip(
                    key: ValueKey('doctor-proposal-day-${_dateKey(day.date)}'),
                    selected: selected,
                    onSelected: (_) => setState(() {
                      _selectedDate = day.date;
                      widget.controller.clearSelection();
                    }),
                    label: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_shortWeekday(day.date)),
                        Text('${day.date.day}'),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: OmniSpacing.lg),
            if (selectedDay != null)
              ...selectedDay.slotsByPeriod.entries.map(
                (entry) => _SlotPeriod(
                  title: entry.key,
                  slots: entry.value,
                  selected: controller.selectedSlot,
                  onSelected: controller.selectSlot,
                ),
              ),
          ],
        );
    }
  }

  DoctorDayAvailability? _selectedDay(List<DoctorDayAvailability> days) {
    if (days.isEmpty) return null;
    final date = _selectedDate;
    if (date == null || !days.any((day) => _sameDay(day.date, date))) {
      return days.first;
    }
    return days.firstWhere((day) => _sameDay(day.date, date));
  }

  bool _canGoPrevious(DateTime? month) {
    if (month == null) return false;
    final current = tunisCalendarMonth(DateTime.now());
    return month.isAfter(current);
  }

  void _moveMonth(int delta) {
    final month = widget.controller.month;
    if (month == null) return;
    setState(() => _selectedDate = null);
    unawaited(
      widget.controller.loadMonth(DateTime(month.year, month.month + delta)),
    );
  }

  Future<void> _reviewAndSubmit() async {
    final request = widget.controller.request;
    final slot = widget.controller.selectedSlot;
    if (request == null || slot == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const ValueKey('doctor-proposal-review'),
        title: const Text('Vérifier la proposition'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ReviewLine('Patient', request.subject.displayName ?? 'Patient'),
            _ReviewLine('Cabinet', request.cabinet.name),
            _ReviewLine(
              'Horaire demandé',
              formatSchedulingDateTime(
                request.originalRequestedSlot.start,
                timezone: request.cabinet.timezone,
              ),
            ),
            _ReviewLine(
              'Nouvel horaire',
              formatSchedulingDateTime(
                slot.start,
                timezone: request.cabinet.timezone,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Retour'),
          ),
          FilledButton(
            key: const ValueKey('doctor-proposal-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Envoyer la proposition'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final completed = await widget.controller.submit();
    if (!mounted) return;
    if (completed) {
      Navigator.of(context).pop(true);
    } else if (!(widget.controller.request?.canPropose ?? false)) {
      Navigator.of(context).pop(false);
    }
  }
}

class _ContextCard extends StatelessWidget {
  const _ContextCard({required this.request});
  final DoctorBookingRequestDetail request;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(OmniSpacing.base),
    decoration: BoxDecoration(
      color: OmniColors.slateSoft,
      borderRadius: BorderRadius.circular(OmniRadii.card),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          request.subject.displayName ?? 'Patient',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: OmniSpacing.xs),
        Text(request.cabinet.name),
        const SizedBox(height: OmniSpacing.sm),
        Text(
          'Horaire demandé : ${formatSchedulingDateTime(request.originalRequestedSlot.start, timezone: request.cabinet.timezone)}',
          key: const ValueKey('doctor-proposal-original-slot'),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: OmniColors.textSecondary),
        ),
      ],
    ),
  );
}

class _MonthNavigation extends StatelessWidget {
  const _MonthNavigation({
    required this.month,
    required this.onPrevious,
    required this.onNext,
  });
  final DateTime? month;
  final VoidCallback? onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      IconButton(
        key: const ValueKey('doctor-proposal-previous-month'),
        onPressed: onPrevious,
        icon: const Icon(Icons.chevron_left_rounded),
      ),
      Expanded(
        child: Text(
          month == null ? 'Disponibilités' : _monthLabel(month!),
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      IconButton(
        key: const ValueKey('doctor-proposal-next-month'),
        onPressed: onNext,
        icon: const Icon(Icons.chevron_right_rounded),
      ),
    ],
  );
}

class _SlotPeriod extends StatelessWidget {
  const _SlotPeriod({
    required this.title,
    required this.slots,
    required this.selected,
    required this.onSelected,
  });
  final String title;
  final List<DoctorAvailabilitySlot> slots;
  final DoctorAvailabilitySlot? selected;
  final ValueChanged<DoctorAvailabilitySlot> onSelected;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: OmniSpacing.lg),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: OmniSpacing.sm),
        Wrap(
          spacing: OmniSpacing.sm,
          runSpacing: OmniSpacing.sm,
          children: slots
              .map((slot) {
                final isSelected =
                    selected?.startIso == slot.startIso &&
                    selected?.endIso == slot.endIso;
                return ChoiceChip(
                  key: ValueKey(
                    'doctor-proposal-slot-${slot.startIso}-${slot.endIso}',
                  ),
                  selected: isSelected,
                  onSelected: (_) => onSelected(slot),
                  label: Text(slot.time),
                );
              })
              .toList(growable: false),
        ),
      ],
    ),
  );
}

class _SubmitBar extends StatelessWidget {
  const _SubmitBar({
    required this.slot,
    required this.timezone,
    required this.isSubmitting,
    required this.onPressed,
  });
  final DoctorAvailabilitySlot? slot;
  final String timezone;
  final bool isSubmitting;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(
      OmniSpacing.pageHorizontal,
      OmniSpacing.md,
      OmniSpacing.pageHorizontal,
      OmniSpacing.base,
    ),
    decoration: const BoxDecoration(
      color: OmniColors.surfacePrimary,
      border: Border(top: BorderSide(color: OmniColors.borderLight)),
    ),
    child: SafeArea(
      top: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (slot != null) ...[
            Text(
              formatSchedulingDateTime(slot!.start, timezone: timezone),
              key: const ValueKey('doctor-proposal-selected-summary'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: OmniSpacing.sm),
          ],
          FilledButton.icon(
            key: const ValueKey('doctor-proposal-review-button'),
            onPressed: onPressed,
            icon: isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.arrow_forward_rounded),
            label: const Text('Vérifier la proposition'),
          ),
        ],
      ),
    ),
  );
}

class _AvailabilityFailure extends StatelessWidget {
  const _AvailabilityFailure({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => _MessageCard(
    key: const ValueKey('doctor-proposal-availability-error'),
    message: message,
    action: OutlinedButton(
      key: const ValueKey('doctor-proposal-availability-retry'),
      onPressed: onRetry,
      child: const Text('Réessayer'),
    ),
  );
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({super.key, required this.message, this.action});
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(OmniSpacing.base),
    decoration: BoxDecoration(
      color: OmniColors.amberSoft,
      borderRadius: BorderRadius.circular(OmniRadii.card),
    ),
    child: Column(
      children: [
        Text(message, textAlign: TextAlign.center),
        if (action != null) ...[
          const SizedBox(height: OmniSpacing.sm),
          action!,
        ],
      ],
    ),
  );
}

class _ReviewLine extends StatelessWidget {
  const _ReviewLine(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: OmniSpacing.md),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: OmniColors.textSecondary),
        ),
        const SizedBox(height: OmniSpacing.xs),
        Text(value),
      ],
    ),
  );
}

class _TerminalState extends StatelessWidget {
  const _TerminalState({required this.request});
  final DoctorBookingRequestDetail request;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(OmniSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.info_outline_rounded, size: 36),
          const SizedBox(height: OmniSpacing.md),
          const Text(
            'Cette action n’est plus disponible pour cette demande.',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: OmniSpacing.md),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Retour à la demande'),
          ),
        ],
      ),
    ),
  );
}

bool _sameDay(DateTime left, DateTime? right) =>
    right != null &&
    left.year == right.year &&
    left.month == right.month &&
    left.day == right.day;

String _dateKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

String _shortWeekday(DateTime value) => const [
  'lun.',
  'mar.',
  'mer.',
  'jeu.',
  'ven.',
  'sam.',
  'dim.',
][value.weekday - 1];

String _monthLabel(DateTime value) =>
    '${const ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'][value.month - 1]} ${value.year}';
