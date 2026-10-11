import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/theme/omni_theme.dart';
import '../../scheduled_care/domain/scheduled_care_models.dart';
import '../scheduled_care/doctor_scheduled_care_models.dart';
import 'doctor_agenda_controller.dart';

const _agendaMotion = Duration(milliseconds: 200);

Duration _motionDuration(BuildContext context) =>
    MediaQuery.maybeOf(context)?.disableAnimations ?? false
    ? Duration.zero
    : _agendaMotion;

class DoctorAgendaScreen extends StatelessWidget {
  const DoctorAgendaScreen({super.key, required this.controller});
  final DoctorAgendaController controller;

  @override
  Widget build(BuildContext context) {
    _ensureFrenchDateFormatting();
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final items = controller.recordsFor(controller.selectedDate);
        final motionDuration = _motionDuration(context);
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            OmniSpacing.pageHorizontal,
            OmniSpacing.pageVertical,
            OmniSpacing.pageHorizontal,
            OmniSpacing.xxl + OmniSpacing.base,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Agenda',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (controller.failure != null) ...[
                    const SizedBox(height: OmniSpacing.md),
                    _FailureBanner(
                      message: controller.failure!.message,
                      onRetry: controller.loadFocusedMonth,
                    ),
                  ],
                  if (controller.isLoading) ...[
                    const SizedBox(height: OmniSpacing.sm),
                    const LinearProgressIndicator(),
                  ],
                  const SizedBox(height: OmniSpacing.lg),
                  _AgendaViewSelector(
                    value: controller.view,
                    onChanged: controller.setView,
                  ),
                  const SizedBox(height: OmniSpacing.lg),
                  AnimatedSwitcher(
                    duration: motionDuration,
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeOutCubic,
                    transitionBuilder: (child, animation) =>
                        FadeTransition(opacity: animation, child: child),
                    child: controller.view == DoctorAgendaView.month
                        ? _MonthView(
                            key: const ValueKey('agenda-month-view'),
                            controller: controller,
                          )
                        : _DayHeader(
                            key: const ValueKey('agenda-day-view'),
                            controller: controller,
                          ),
                  ),
                  const SizedBox(height: OmniSpacing.xl),
                  AnimatedSwitcher(
                    duration: motionDuration,
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeOutCubic,
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: animation.drive(
                          Tween(begin: const Offset(0, .015), end: Offset.zero),
                        ),
                        child: child,
                      ),
                    ),
                    child: _AgendaList(
                      key: ValueKey(
                        'agenda-list-${controller.selectedDate.toIso8601String()}',
                      ),
                      date: controller.selectedDate,
                      items: items,
                      controller: controller,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

void _ensureFrenchDateFormatting() {
  unawaited(initializeDateFormatting('fr_FR'));
}

class _AgendaViewSelector extends StatelessWidget {
  const _AgendaViewSelector({required this.value, required this.onChanged});

  final DoctorAgendaView value;
  final ValueChanged<DoctorAgendaView> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    height: 44,
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: OmniColors.surfaceSecondary,
      border: Border.all(color: OmniColors.borderLight),
      borderRadius: BorderRadius.circular(OmniRadii.field),
    ),
    child: Row(
      children: DoctorAgendaView.values
          .map(
            (view) => Expanded(
              child: _AgendaViewOption(
                key: ValueKey('agenda-view-${view.name}'),
                label: view == DoctorAgendaView.month ? 'Mois' : 'Jour',
                selected: value == view,
                onTap: () => onChanged(view),
              ),
            ),
          )
          .toList(),
    ),
  );
}

class _AgendaViewOption extends StatelessWidget {
  const _AgendaViewOption({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: label,
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(OmniRadii.field - 3),
        onTap: onTap,
        child: AnimatedContainer(
          duration: _motionDuration(context),
          curve: Curves.easeOutCubic,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? OmniColors.primaryAction : Colors.transparent,
            borderRadius: BorderRadius.circular(OmniRadii.field - 3),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: selected ? Colors.white : OmniColors.textSecondary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    ),
  );
}

class _MonthView extends StatelessWidget {
  const _MonthView({super.key, required this.controller});
  final DoctorAgendaController controller;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(OmniRadii.card),
      border: Border.all(color: OmniColors.borderLight),
    ),
    padding: const EdgeInsets.fromLTRB(
      OmniSpacing.sm,
      OmniSpacing.xs,
      OmniSpacing.sm,
      OmniSpacing.sm,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MonthHeader(day: controller.focusedDate, controller: controller),
        TableCalendar<DoctorScheduledCareItem>(
          locale: 'fr_FR',
          firstDay: DateTime.now().subtract(const Duration(days: 365)),
          lastDay: DateTime.now().add(const Duration(days: 730)),
          focusedDay: controller.focusedDate,
          currentDay: DateTime.now(),
          startingDayOfWeek: StartingDayOfWeek.monday,
          calendarFormat: CalendarFormat.month,
          availableCalendarFormats: const {CalendarFormat.month: 'Mois'},
          headerVisible: false,
          selectedDayPredicate: (day) =>
              DateUtils.isSameDay(day, controller.selectedDate),
          eventLoader: controller.recordsFor,
          onDaySelected: (selected, focused) =>
              controller.selectDate(selected, focusedDate: focused),
          onPageChanged: controller.focusMonth,
          pageAnimationEnabled:
              !(MediaQuery.maybeOf(context)?.disableAnimations ?? false),
          pageAnimationDuration: _motionDuration(context),
          pageAnimationCurve: Curves.easeOutCubic,
          rowHeight: 46,
          daysOfWeekHeight: 28,
          daysOfWeekStyle: DaysOfWeekStyle(
            weekdayStyle: Theme.of(
              context,
            ).textTheme.labelSmall!.copyWith(color: OmniColors.textSecondary),
            weekendStyle: Theme.of(
              context,
            ).textTheme.labelSmall!.copyWith(color: OmniColors.textSecondary),
          ),
          calendarStyle: const CalendarStyle(
            outsideDaysVisible: false,
            isTodayHighlighted: true,
            canMarkersOverflow: false,
            cellMargin: EdgeInsets.zero,
            cellPadding: EdgeInsets.zero,
            markersMaxCount: 3,
          ),
          calendarBuilders: CalendarBuilders<DoctorScheduledCareItem>(
            selectedBuilder: (context, day, _) =>
                _CalendarDayCell(day: day, state: _CalendarDayState.selected),
            todayBuilder: (context, day, _) =>
                _CalendarDayCell(day: day, state: _CalendarDayState.today),
            defaultBuilder: (context, day, _) => _CalendarDayCell(day: day),
            outsideBuilder: (context, day, _) =>
                _CalendarDayCell(day: day, state: _CalendarDayState.outside),
            markerBuilder: (context, day, events) => events.isEmpty
                ? null
                : _EventMarkers(day: day, records: events),
          ),
        ),
      ],
    ),
  );
}

enum _CalendarDayState { normal, selected, today, outside }

class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({
    required this.day,
    this.state = _CalendarDayState.normal,
  });

  final DateTime day;
  final _CalendarDayState state;

  @override
  Widget build(BuildContext context) {
    final selected = state == _CalendarDayState.selected;
    final today = state == _CalendarDayState.today;
    final outside = state == _CalendarDayState.outside;
    return Center(
      child: AnimatedContainer(
        key: ValueKey('agenda-day-${day.toIso8601String().substring(0, 10)}'),
        duration: _motionDuration(context),
        curve: Curves.easeOutCubic,
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? OmniColors.primaryAction : Colors.transparent,
          border: today
              ? Border.all(color: OmniColors.freshMint, width: 1.5)
              : null,
          shape: BoxShape.circle,
        ),
        child: Text(
          '${day.day}',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: selected
                ? Colors.white
                : outside
                ? OmniColors.textDisabled
                : OmniColors.textPrimary,
            fontWeight: selected || today ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _EventMarkers extends StatelessWidget {
  const _EventMarkers({required this.day, required this.records});

  final DateTime day;
  final List<DoctorScheduledCareItem> records;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.bottomCenter,
    child: Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Semantics(
        label: '${records.length} demandes ou rendez-vous',
        child: Row(
          key: ValueKey(
            'agenda-marker-${day.toIso8601String().substring(0, 10)}',
          ),
          mainAxisSize: MainAxisSize.min,
          children: records
              .take(3)
              .map(
                (record) => Container(
                  width: 4,
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  decoration: BoxDecoration(
                    color: _statusColor(record.status),
                    shape: BoxShape.circle,
                  ),
                ),
              )
              .toList(growable: false),
        ),
      ),
    ),
  );
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({required this.day, required this.controller});
  final DateTime day;
  final DoctorAgendaController controller;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      IconButton(
        tooltip: 'Mois précédent',
        onPressed: () =>
            controller.focusMonth(DateTime(day.year, day.month - 1)),
        icon: const Icon(Icons.chevron_left_rounded, size: 22),
      ),
      Expanded(
        child: Text(
          DateFormat('MMMM yyyy', 'fr_FR').format(day),
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      IconButton(
        tooltip: 'Mois suivant',
        onPressed: () =>
            controller.focusMonth(DateTime(day.year, day.month + 1)),
        icon: const Icon(Icons.chevron_right_rounded, size: 22),
      ),
    ],
  );
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({super.key, required this.controller});
  final DoctorAgendaController controller;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      IconButton(
        tooltip: 'Jour précédent',
        onPressed: () => controller.changeDay(-1),
        icon: const Icon(Icons.chevron_left_rounded),
      ),
      Expanded(
        child: Text(
          DateFormat('d MMMM yyyy', 'fr_FR').format(controller.selectedDate),
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
      ),
      IconButton(
        tooltip: 'Jour suivant',
        onPressed: () => controller.changeDay(1),
        icon: const Icon(Icons.chevron_right_rounded),
      ),
    ],
  );
}

class _AgendaList extends StatelessWidget {
  const _AgendaList({
    super.key,
    required this.date,
    required this.items,
    required this.controller,
  });
  final DateTime date;
  final List<DoctorScheduledCareItem> items;
  final DoctorAgendaController controller;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        DateFormat('EEEE d MMMM', 'fr_FR').format(date),
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: OmniSpacing.md),
      if (items.isEmpty)
        const _EmptyDay()
      else
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: OmniSpacing.sm),
            child: _AppointmentRow(
              item: item,
              onTap: () => _showAppointmentDetail(context, item, controller),
            ),
          ),
        ),
    ],
  );
}

class _EmptyDay extends StatelessWidget {
  const _EmptyDay();
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(OmniSpacing.lg),
    decoration: BoxDecoration(
      color: OmniColors.slateSoft,
      borderRadius: BorderRadius.circular(OmniRadii.card),
    ),
    child: const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Aucun rendez-vous'),
        SizedBox(height: 4),
        Text('Vous n’avez aucun rendez-vous prévu ce jour.'),
      ],
    ),
  );
}

class _AppointmentRow extends StatelessWidget {
  const _AppointmentRow({required this.item, required this.onTap});
  final DoctorScheduledCareItem item;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label:
        '${DateFormat('HH:mm').format(_displayStart(item))}, ${item.patientDisplayName}, ${doctorScheduledCareStatusLabel(item.status)}',
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(OmniRadii.card),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: OmniSpacing.md,
            vertical: OmniSpacing.md,
          ),
          decoration: BoxDecoration(
            color: _statusColor(item.status).withValues(alpha: .04),
            border: Border.all(
              color: _statusColor(item.status).withValues(alpha: .28),
            ),
            borderRadius: BorderRadius.circular(OmniRadii.card),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 46,
                child: Text(
                  DateFormat('HH:mm').format(_displayStart(item)),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: OmniColors.deepTeal,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: OmniSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.patientDisplayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.relationshipLabel} · ${item.activeSlot.durationMinutes} min',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: OmniColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      item.cabinet.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: OmniColors.slateBlue,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: OmniSpacing.sm),
              _StatusChip(status: item.status),
            ],
          ),
        ),
      ),
    ),
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final DoctorScheduledCareStatus status;
  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    final background = color.withValues(alpha: .12);
    return Semantics(
      label: 'Statut : ${doctorScheduledCareStatusLabel(status)}',
      child: Container(
        constraints: const BoxConstraints(minWidth: 68),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(OmniRadii.pill),
        ),
        child: Text(
          doctorScheduledCareStatusLabel(status),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

Future<void> _showAppointmentDetail(
  BuildContext context,
  DoctorScheduledCareItem item,
  DoctorAgendaController controller,
) async {
  final refreshed = await controller.refreshItem(item);
  if (refreshed == null || !context.mounted) return;
  item = refreshed;
  final animationsDisabled =
      MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    sheetAnimationStyle: animationsDisabled
        ? AnimationStyle.noAnimation
        : const AnimationStyle(
            duration: Duration(milliseconds: 220),
            reverseDuration: Duration(milliseconds: 180),
          ),
    builder: (context) => SafeArea(
      top: false,
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * .78,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            8,
            20,
            20 + MediaQuery.viewPaddingOf(context).bottom,
          ),
          child: AnimatedBuilder(
            animation: controller,
            builder: (context, child) {
              final current =
                  controller.itemByIdentity(
                    item.resourceType,
                    item.resourceId,
                  ) ??
                  item;
              return SingleChildScrollView(
                key: const ValueKey('doctor-appointment-detail-scroll'),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      current.patientDisplayName,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      current.relationshipLabel,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: OmniColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      current.resourceType ==
                              ScheduledCareResourceType.appointment
                          ? 'Rendez-vous confirmé'
                          : 'Demande de rendez-vous',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _DetailLine(
                      'Date',
                      DateFormat(
                        'd MMMM yyyy',
                        'fr_FR',
                      ).format(_displayStart(current)),
                    ),
                    _DetailLine(
                      'Heure',
                      '${DateFormat('HH:mm').format(_displayStart(current))}–${DateFormat('HH:mm').format(_displayEnd(current))}',
                    ),
                    _DetailLine(
                      'Durée',
                      '${current.activeSlot.durationMinutes} min',
                    ),
                    _DetailLine('Cabinet', current.cabinet.name),
                    _DetailLine(
                      'Adresse',
                      '${current.cabinet.address}, ${current.cabinet.city}',
                    ),
                    _DetailLine(
                      'Statut',
                      doctorScheduledCareStatusLabel(current.status),
                    ),
                    if (current.status ==
                            DoctorScheduledCareStatus.pendingDoctor &&
                        current.responseDeadline != null)
                      _DetailLine(
                        'Échéance',
                        DateFormat(
                          'd MMM · HH:mm',
                          'fr_FR',
                        ).format(current.responseDeadline!),
                      ),
                    if (current.status ==
                            DoctorScheduledCareStatus
                                .pendingPatientTimeConfirmation &&
                        current.patientResponseDeadline != null)
                      _DetailLine(
                        'Échéance',
                        DateFormat(
                          'd MMM · HH:mm',
                          'fr_FR',
                        ).format(current.patientResponseDeadline!),
                      ),
                    if (current.proposedSlot != null) ...[
                      const SizedBox(height: OmniSpacing.sm),
                      _ProposalSummary(record: current),
                    ],
                    if (current.resourceType ==
                        ScheduledCareResourceType.appointment) ...[
                      const SizedBox(height: OmniSpacing.lg),
                      _IntakeSummary(status: current.intakeStatus),
                    ],
                    if (current.status ==
                        DoctorScheduledCareStatus.expired) ...[
                      const SizedBox(height: OmniSpacing.md),
                      const _StateNotice(
                        text:
                            'Cette demande n’est plus active. Le créneau a été libéré.',
                      ),
                    ],
                    if (current.status ==
                            DoctorScheduledCareStatus.cancelledByPatient ||
                        current.status ==
                            DoctorScheduledCareStatus.cancelledByDoctor ||
                        current.status ==
                            DoctorScheduledCareStatus.cancelled) ...[
                      const SizedBox(height: OmniSpacing.md),
                      _StateNotice(text: _cancellationDescription(current)),
                    ],
                    const SizedBox(height: 20),
                    if (controller.failure != null) ...[
                      _FailureBanner(
                        message: controller.failure!.message,
                        onRetry: () => controller.refreshItem(current),
                      ),
                      const SizedBox(height: OmniSpacing.md),
                    ],
                    AnimatedSwitcher(
                      duration: _motionDuration(context),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeOutCubic,
                      child: _AppointmentDetailAction(
                        key: ValueKey('agenda-detail-${current.status.name}'),
                        record: current,
                        onAccept: () => unawaited(controller.accept(current)),
                        onPropose: () =>
                            _showSlotSelector(context, current, controller),
                        onDecline: () =>
                            current.resourceType ==
                                ScheduledCareResourceType.appointment
                            ? _askForCancellationReason(
                                context,
                                current,
                                controller,
                              )
                            : _askForDeclineReason(
                                context,
                                current,
                                controller,
                              ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}

class _AppointmentDetailAction extends StatelessWidget {
  const _AppointmentDetailAction({
    super.key,
    required this.record,
    required this.onAccept,
    required this.onPropose,
    required this.onDecline,
  });

  final DoctorScheduledCareItem record;
  final VoidCallback onAccept;
  final VoidCallback onPropose;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    if (record.can(ScheduledCareAction.acceptRequest) ||
        record.can(ScheduledCareAction.proposeNewTime) ||
        record.can(ScheduledCareAction.declineRequest)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (record.can(ScheduledCareAction.acceptRequest))
            FilledButton(onPressed: onAccept, child: const Text('Accepter')),
          if (record.can(ScheduledCareAction.proposeNewTime)) ...[
            const SizedBox(height: OmniSpacing.sm),
            OutlinedButton(
              onPressed: onPropose,
              child: const Text('Proposer un autre créneau'),
            ),
          ],
          if (record.can(ScheduledCareAction.declineRequest))
            TextButton(onPressed: onDecline, child: const Text('Refuser')),
        ],
      );
    }
    if (record.can(ScheduledCareAction.cancelAppointment)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextButton(
            onPressed: onDecline,
            child: const Text('Annuler le rendez-vous'),
          ),
        ],
      );
    }
    if (record.status ==
        DoctorScheduledCareStatus.pendingPatientTimeConfirmation) {
      return const _StateNotice(
        text: 'Le nouveau créneau est réservé en attendant le patient.',
      );
    }
    return const SizedBox.shrink();
  }
}

class _ProposalSummary extends StatelessWidget {
  const _ProposalSummary({required this.record});

  final DoctorScheduledCareItem record;

  @override
  Widget build(BuildContext context) {
    final proposal = record.proposedSlot!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(OmniSpacing.md),
      decoration: BoxDecoration(
        color: OmniColors.infoBlueSoft,
        borderRadius: BorderRadius.circular(OmniRadii.field),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Créneau proposé au patient',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: OmniColors.infoBlue,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: OmniSpacing.xs),
          Text(
            DateFormat('EEEE d MMMM · HH:mm', 'fr_FR').format(proposal.start),
          ),
          Text(
            'Demande initiale : ${DateFormat('d MMM · HH:mm', 'fr_FR').format(record.requestedSlot.start)}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: OmniColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _IntakeSummary extends StatelessWidget {
  const _IntakeSummary({required this.status});

  final String? status;

  @override
  Widget build(BuildContext context) {
    if (status == null || status == 'NOT_SUBMITTED') {
      return const _StateNotice(
        text: 'Aucune information de préparation envoyée.',
      );
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(OmniSpacing.md),
      decoration: BoxDecoration(
        color: OmniColors.mintSoft,
        borderRadius: BorderRadius.circular(OmniRadii.field),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Préparation envoyée par le patient',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: OmniColors.deepTeal,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: OmniSpacing.sm),
          const Text(
            'Les informations cliniques seront accessibles dans le dossier médical autorisé.',
          ),
        ],
      ),
    );
  }
}

class _StateNotice extends StatelessWidget {
  const _StateNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(OmniSpacing.md),
    decoration: BoxDecoration(
      color: OmniColors.slateSoft,
      borderRadius: BorderRadius.circular(OmniRadii.field),
    ),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: OmniColors.textSecondary),
    ),
  );
}

class _FailureBanner extends StatelessWidget {
  const _FailureBanner({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(OmniSpacing.md),
    decoration: BoxDecoration(
      color: OmniColors.error.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(OmniRadii.field),
      border: Border.all(color: OmniColors.error.withValues(alpha: .25)),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline_rounded, color: OmniColors.error),
        const SizedBox(width: OmniSpacing.sm),
        Expanded(child: Text(message)),
        TextButton(onPressed: onRetry, child: const Text('Réessayer')),
      ],
    ),
  );
}

Future<void> _showSlotSelector(
  BuildContext context,
  DoctorScheduledCareItem record,
  DoctorAgendaController controller,
) async {
  await controller.loadProposalAvailability(record);
  if (!context.mounted) return;
  record =
      controller.itemByIdentity(record.resourceType, record.resourceId) ??
      record;
  final slots = controller.proposalSlots;
  await showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          OmniSpacing.xl,
          OmniSpacing.sm,
          OmniSpacing.xl,
          OmniSpacing.xxl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Proposer un autre créneau',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: OmniSpacing.xs),
            Text(
              '${record.cabinet.name} · disponibilités des 21 prochains jours',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: OmniColors.textSecondary),
            ),
            const SizedBox(height: OmniSpacing.lg),
            if (slots.isEmpty)
              const _StateNotice(
                text: 'Aucun autre créneau libre dans la période chargée.',
              )
            else
              ...slots.map(
                (slot) => ListTile(
                  key: ValueKey(
                    'doctor-proposal-slot-${slot.start.toIso8601String()}',
                  ),
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.schedule_rounded),
                  title: Text(
                    DateFormat('EEEE d MMMM', 'fr_FR').format(slot.start),
                  ),
                  subtitle: Text(
                    '${DateFormat('HH:mm').format(slot.start)}–${DateFormat('HH:mm').format(slot.end)} · ${slot.durationMinutes} min',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    final confirmed = await showDialog<bool>(
                      context: sheetContext,
                      builder: (dialogContext) => AlertDialog(
                        title: const Text('Confirmer la proposition'),
                        content: Text(
                          '${record.cabinet.name}\n${DateFormat('EEEE d MMMM · HH:mm', 'fr_FR').format(slot.start)}',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.pop(dialogContext, false),
                            child: const Text('Retour'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.pop(dialogContext, true),
                            child: const Text('Proposer'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed != true || !sheetContext.mounted) return;
                    await controller.propose(record, slot);
                    if (!sheetContext.mounted) return;
                    Navigator.pop(sheetContext);
                  },
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _askForDeclineReason(
  BuildContext context,
  DoctorScheduledCareItem record,
  DoctorAgendaController controller,
) => _askForControlledReason<DoctorDeclineReason>(
  context,
  title: 'Refuser la demande',
  actionLabel: 'Refuser',
  values: DoctorDeclineReason.values,
  label: (reason) => reason.label,
  onSubmit: (reason) => controller.decline(record, reason),
);

Future<void> _askForCancellationReason(
  BuildContext context,
  DoctorScheduledCareItem record,
  DoctorAgendaController controller,
) => _askForControlledReason<DoctorAppointmentCancellationReason>(
  context,
  title: 'Annuler le rendez-vous',
  actionLabel: 'Annuler',
  values: DoctorAppointmentCancellationReason.values,
  label: (reason) => reason.label,
  onSubmit: (reason) => controller.cancel(record, reason),
);

Future<void> _askForControlledReason<T>(
  BuildContext context, {
  required String title,
  required String actionLabel,
  required List<T> values,
  required String Function(T value) label,
  required Future<bool> Function(T value) onSubmit,
}) async {
  var selected = values.first;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(title),
        content: DropdownButtonFormField<T>(
          key: const ValueKey('doctor-controlled-reason'),
          initialValue: selected,
          decoration: const InputDecoration(labelText: 'Motif requis'),
          items: values
              .map(
                (value) => DropdownMenuItem<T>(
                  value: value,
                  child: Text(label(value)),
                ),
              )
              .toList(growable: false),
          onChanged: (value) {
            if (value != null) setDialogState(() => selected = value);
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Retour'),
          ),
          FilledButton(
            onPressed: () async {
              final succeeded = await onSubmit(selected);
              if (succeeded && dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }
            },
            child: Text(actionLabel),
          ),
        ],
      ),
    ),
  );
}

class _DetailLine extends StatelessWidget {
  const _DetailLine(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        SizedBox(
          width: 80,
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

Color _statusColor(DoctorScheduledCareStatus status) => switch (status) {
  DoctorScheduledCareStatus.pendingDoctor => OmniColors.amber,
  DoctorScheduledCareStatus.pendingPatientTimeConfirmation =>
    OmniColors.infoBlue,
  DoctorScheduledCareStatus.confirmed ||
  DoctorScheduledCareStatus.inProgress => OmniColors.deepTeal,
  DoctorScheduledCareStatus.fulfilled ||
  DoctorScheduledCareStatus.completed => OmniColors.freshMint,
  DoctorScheduledCareStatus.expired ||
  DoctorScheduledCareStatus.noShow => OmniColors.slateBlue,
  DoctorScheduledCareStatus.cancelled ||
  DoctorScheduledCareStatus.cancelledByPatient ||
  DoctorScheduledCareStatus.cancelledByDoctor => OmniColors.error,
};

String _cancellationDescription(DoctorScheduledCareItem record) {
  final actor = record.status == DoctorScheduledCareStatus.cancelledByDoctor
      ? 'Annulé par le médecin'
      : record.status == DoctorScheduledCareStatus.cancelledByPatient
      ? 'Annulé par le patient'
      : 'Rendez-vous annulé';
  final when = record.cancelledAt == null
      ? ''
      : ' le ${DateFormat('d MMM à HH:mm', 'fr_FR').format(record.cancelledAt!)}';
  final reason = record.cancellationReason?.trim();
  return '$actor$when${reason == null || reason.isEmpty ? '' : ' · $reason'}';
}

DateTime _displayStart(DoctorScheduledCareItem item) =>
    displayInTimeZone(item.activeSlot.start, item.cabinet.timezone);

DateTime _displayEnd(DoctorScheduledCareItem item) =>
    displayInTimeZone(item.activeSlot.end, item.cabinet.timezone);
