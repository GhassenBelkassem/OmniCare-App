import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/theme/omni_theme.dart';
import 'doctor_agenda_controller.dart';
import 'doctor_demo_appointment.dart';

final _agendaToday = DateTime(2026, 9, 24);
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
        final items = controller.appointmentsFor(controller.selectedDate);
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
        TableCalendar<DoctorDemoAppointment>(
          locale: 'fr_FR',
          firstDay: DateTime(2026, 1, 1),
          lastDay: DateTime(2027, 12, 31),
          focusedDay: controller.focusedDate,
          currentDay: _agendaToday,
          startingDayOfWeek: StartingDayOfWeek.monday,
          calendarFormat: CalendarFormat.month,
          availableCalendarFormats: const {CalendarFormat.month: 'Mois'},
          headerVisible: false,
          selectedDayPredicate: (day) =>
              DateUtils.isSameDay(day, controller.selectedDate),
          eventLoader: controller.appointmentsFor,
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
          calendarBuilders: CalendarBuilders<DoctorDemoAppointment>(
            selectedBuilder: (context, day, _) =>
                _CalendarDayCell(day: day, state: _CalendarDayState.selected),
            todayBuilder: (context, day, _) =>
                _CalendarDayCell(day: day, state: _CalendarDayState.today),
            defaultBuilder: (context, day, _) => _CalendarDayCell(day: day),
            outsideBuilder: (context, day, _) =>
                _CalendarDayCell(day: day, state: _CalendarDayState.outside),
            markerBuilder: (context, day, events) => events.isEmpty
                ? null
                : _EventMarkers(day: day, count: events.length),
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
  const _EventMarkers({required this.day, required this.count});

  final DateTime day;
  final int count;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.bottomCenter,
    child: Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Semantics(
        label: '$count rendez-vous',
        child: Row(
          key: ValueKey(
            'agenda-marker-${day.toIso8601String().substring(0, 10)}',
          ),
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            count.clamp(1, 3).toInt(),
            (_) => Container(
              width: 4,
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              decoration: const BoxDecoration(
                color: OmniColors.freshMint,
                shape: BoxShape.circle,
              ),
            ),
          ),
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
  final List<DoctorDemoAppointment> items;
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
  final DoctorDemoAppointment item;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label:
        '${DateFormat('HH:mm').format(item.dateTime)}, ${item.patientName}, ${_statusLabel(item.status)}',
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
            border: Border.all(color: OmniColors.borderLight),
            borderRadius: BorderRadius.circular(OmniRadii.card),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 46,
                child: Text(
                  DateFormat('HH:mm').format(item.dateTime),
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
                      item.patientName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.reason,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: OmniColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      item.locationName,
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
  final DoctorAppointmentStatus status;
  @override
  Widget build(BuildContext context) {
    final (color, background) = switch (status) {
      DoctorAppointmentStatus.scheduled => (
        OmniColors.amber,
        OmniColors.amberSoft,
      ),
      DoctorAppointmentStatus.arrived => (
        OmniColors.deepTeal,
        OmniColors.mintSoft,
      ),
      DoctorAppointmentStatus.inConsultation => (
        OmniColors.clinicalCyan,
        OmniColors.clinicalCyanSoft,
      ),
      DoctorAppointmentStatus.completed => (
        OmniColors.slateBlue,
        OmniColors.slateSoft,
      ),
      DoctorAppointmentStatus.cancelled => (
        OmniColors.error,
        OmniColors.errorSoft,
      ),
    };
    return Semantics(
      label: 'Statut : ${_statusLabel(status)}',
      child: Container(
        constraints: const BoxConstraints(minWidth: 68),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(OmniRadii.pill),
        ),
        child: Text(
          _statusLabel(status),
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
  DoctorDemoAppointment item,
  DoctorAgendaController controller,
) {
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
        height: 460,
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
              final current = controller.appointments.firstWhere(
                (value) => value.id == item.id,
              );
              return SingleChildScrollView(
                key: const ValueKey('doctor-appointment-detail-scroll'),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      current.patientName,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    Text(
                      '${current.patientAge} ans',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: OmniColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      current.reason,
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
                      ).format(current.dateTime),
                    ),
                    _DetailLine(
                      'Heure',
                      DateFormat('HH:mm').format(current.dateTime),
                    ),
                    _DetailLine('Lieu', current.locationName),
                    _DetailLine('Statut', _statusLabel(current.status)),
                    const SizedBox(height: 20),
                    AnimatedSwitcher(
                      duration: _motionDuration(context),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeOutCubic,
                      child: _AppointmentDetailAction(
                        key: ValueKey('agenda-detail-${current.status.name}'),
                        status: current.status,
                        onArrived: () => controller.markArrived(current.id),
                        onScanQr: () => _showQrPlaceholder(context),
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
    required this.status,
    required this.onArrived,
    required this.onScanQr,
  });

  final DoctorAppointmentStatus status;
  final VoidCallback onArrived;
  final VoidCallback onScanQr;

  @override
  Widget build(BuildContext context) => switch (status) {
    DoctorAppointmentStatus.scheduled => FilledButton(
      onPressed: onArrived,
      child: const Text('Patient arrivé'),
    ),
    DoctorAppointmentStatus.arrived => FilledButton(
      onPressed: onScanQr,
      child: const Text('Scanner le QR'),
    ),
    DoctorAppointmentStatus.completed => const Text(
      'Consultation terminée\nLe résumé clinique sera disponible après l’implémentation de la consultation.',
    ),
    _ => const SizedBox.shrink(),
  };
}

void _showQrPlaceholder(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => const Padding(
      padding: EdgeInsets.all(24),
      child: Text(
        'La vérification QR sera ajoutée à l’étape suivante de la démo.',
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

String _statusLabel(DoctorAppointmentStatus status) => switch (status) {
  DoctorAppointmentStatus.scheduled => 'À venir',
  DoctorAppointmentStatus.arrived => 'Patient arrivé',
  DoctorAppointmentStatus.inConsultation => 'En consultation',
  DoctorAppointmentStatus.completed => 'Terminée',
  DoctorAppointmentStatus.cancelled => 'Annulée',
};
