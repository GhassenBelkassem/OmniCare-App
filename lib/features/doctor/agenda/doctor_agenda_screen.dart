import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/theme/omni_theme.dart';
import '../../scheduled_care/domain/patient_scheduled_care_models.dart';
import '../../scheduled_care/domain/scheduled_care_models.dart';
import 'doctor_agenda_controller.dart';
import '../../scheduled_care/realtime/scheduled_care_route_visibility.dart';

const _agendaMotion = Duration(milliseconds: 200);

Duration _motionDuration(BuildContext context) =>
    MediaQuery.maybeOf(context)?.disableAnimations ?? false
    ? Duration.zero
    : _agendaMotion;

class DoctorAgendaScreen extends StatefulWidget {
  const DoctorAgendaScreen({
    super.key,
    required this.controller,
    this.onOpenBookingRequest,
    this.onOpenAppointment,
  });

  final DoctorAgendaController controller;
  final ValueChanged<String>? onOpenBookingRequest;
  final ValueChanged<String>? onOpenAppointment;

  @override
  State<DoctorAgendaScreen> createState() => _DoctorAgendaScreenState();
}

class _DoctorAgendaScreenState extends State<DoctorAgendaScreen>
    with ScheduledCareRouteVisibility<DoctorAgendaScreen> {
  @override
  void initState() {
    super.initState();
    _loadOnEntry();
  }

  @override
  void didUpdateWidget(covariant DoctorAgendaScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) {
      oldWidget.controller.setRealtimeActive(false);
      onScheduledCareRouteVisibilityChanged(
        ModalRoute.of(context)?.isCurrent ?? true,
      );
      _loadOnEntry();
    }
  }

  @override
  void dispose() {
    onScheduledCareRouteVisibilityChanged(false);
    super.dispose();
  }

  @override
  void onScheduledCareRouteVisibilityChanged(bool visible) {
    widget.controller.setRealtimeActive(visible);
  }

  void _loadOnEntry() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        widget.controller.state == DoctorAgendaLoadState.initial
            ? widget.controller.load()
            : widget.controller.refresh(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    _ensureFrenchDateFormatting();
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        if (controller.state == DoctorAgendaLoadState.loading &&
            controller.items.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.state == DoctorAgendaLoadState.failed &&
            controller.items.isEmpty) {
          return _AgendaFailure(
            message:
                controller.failure?.message ??
                'L’agenda est momentanément indisponible.',
            onRetry: controller.load,
          );
        }
        final items = controller.itemsFor(controller.selectedDate);
        return RefreshIndicator(
          onRefresh: controller.refresh,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
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
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    if (controller.isRefreshing) ...[
                      const SizedBox(height: OmniSpacing.sm),
                      const LinearProgressIndicator(
                        key: ValueKey('doctor-agenda-refreshing'),
                      ),
                    ],
                    if (controller.failure != null) ...[
                      const SizedBox(height: OmniSpacing.sm),
                      _InlineFailure(
                        message: controller.failure!.message,
                        onRetry: controller.refresh,
                      ),
                    ],
                    const SizedBox(height: OmniSpacing.lg),
                    _AgendaViewSelector(
                      value: controller.view,
                      onChanged: controller.setView,
                    ),
                    const SizedBox(height: OmniSpacing.lg),
                    AnimatedSwitcher(
                      duration: _motionDuration(context),
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
                    _AgendaList(
                      date: controller.selectedDate,
                      items: items,
                      onOpenBookingRequest: widget.onOpenBookingRequest,
                      onOpenAppointment: widget.onOpenAppointment,
                    ),
                  ],
                ),
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

class _AgendaFailure extends StatelessWidget {
  const _AgendaFailure({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

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
            key: const ValueKey('doctor-agenda-retry'),
            onPressed: onRetry,
            child: const Text('Réessayer'),
          ),
        ],
      ),
    ),
  );
}

class _InlineFailure extends StatelessWidget {
  const _InlineFailure({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('doctor-agenda-inline-error'),
    width: double.infinity,
    padding: const EdgeInsets.all(OmniSpacing.sm),
    decoration: BoxDecoration(
      color: OmniColors.errorSoft,
      borderRadius: BorderRadius.circular(OmniRadii.field),
    ),
    child: Row(
      children: [
        Expanded(
          child: Text(
            message,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: OmniColors.error,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        TextButton(onPressed: onRetry, child: const Text('Réessayer')),
      ],
    ),
  );
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
              child: Semantics(
                button: true,
                selected: value == view,
                child: InkWell(
                  key: ValueKey('agenda-view-${view.name}'),
                  borderRadius: BorderRadius.circular(OmniRadii.field - 3),
                  onTap: () => onChanged(view),
                  child: AnimatedContainer(
                    duration: _motionDuration(context),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: value == view
                          ? OmniColors.primaryAction
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(OmniRadii.field - 3),
                    ),
                    child: Text(
                      view == DoctorAgendaView.month ? 'Mois' : 'Jour',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: value == view
                            ? Colors.white
                            : OmniColors.textSecondary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          )
          .toList(),
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
        TableCalendar<PatientScheduledCareItem>(
          locale: 'fr_FR',
          firstDay: DateTime(2020),
          lastDay: DateTime(2100, 12, 31),
          focusedDay: controller.focusedDate,
          currentDay: DateUtils.dateOnly(
            doctorAgendaWallClock(DateTime.now(), timezone: 'Africa/Tunis'),
          ),
          startingDayOfWeek: StartingDayOfWeek.monday,
          calendarFormat: CalendarFormat.month,
          availableCalendarFormats: const {CalendarFormat.month: 'Mois'},
          headerVisible: false,
          selectedDayPredicate: (day) =>
              DateUtils.isSameDay(day, controller.selectedDate),
          eventLoader: controller.itemsFor,
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
          calendarBuilders: CalendarBuilders<PatientScheduledCareItem>(
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
      child: Row(
        key: ValueKey(
          'agenda-marker-${day.toIso8601String().substring(0, 10)}',
        ),
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          count.clamp(1, 3),
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
    required this.date,
    required this.items,
    required this.onOpenBookingRequest,
    required this.onOpenAppointment,
  });
  final DateTime date;
  final List<PatientScheduledCareItem> items;
  final ValueChanged<String>? onOpenBookingRequest;
  final ValueChanged<String>? onOpenAppointment;

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
            child: _ScheduledCareRow(
              item: item,
              onTap: () {
                switch (item.resourceType) {
                  case ScheduledCareResourceType.bookingRequest:
                    final requestId = item.requestId;
                    if (requestId != null) {
                      onOpenBookingRequest?.call(requestId);
                    }
                  case ScheduledCareResourceType.appointment:
                    final appointmentId = item.appointmentId;
                    if (appointmentId != null) {
                      onOpenAppointment?.call(appointmentId);
                    }
                }
              },
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
        Text('Aucun élément prévu'),
        SizedBox(height: 4),
        Text('Vous n’avez aucune demande ni rendez-vous prévu ce jour.'),
      ],
    ),
  );
}

class _ScheduledCareRow extends StatelessWidget {
  const _ScheduledCareRow({required this.item, required this.onTap});
  final PatientScheduledCareItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final wallClock = doctorAgendaWallClock(
      item.start,
      timezone: item.timezone,
    );
    final isRequest =
        item.resourceType == ScheduledCareResourceType.bookingRequest;
    final status = _scheduledCareStatus(item);
    return Semantics(
      button: true,
      label:
          '${DateFormat('HH:mm').format(wallClock)}, ${item.subject.displayName}, ${status.label}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          key: ValueKey('doctor-agenda-item-${item.identityKey}'),
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
                    DateFormat('HH:mm').format(wallClock),
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
                        item.subject.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        isRequest ? 'Demande de rendez-vous' : 'Rendez-vous',
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
                _StatusChip(presentation: status),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.presentation});
  final _AgendaStatusPresentation presentation;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 68, maxWidth: 112),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: presentation.background,
      borderRadius: BorderRadius.circular(OmniRadii.pill),
    ),
    child: Text(
      presentation.label,
      maxLines: 2,
      textAlign: TextAlign.center,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: presentation.color,
        fontSize: 10,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _AgendaStatusPresentation {
  const _AgendaStatusPresentation(this.label, this.color, this.background);
  final String label;
  final Color color;
  final Color background;
}

_AgendaStatusPresentation _scheduledCareStatus(PatientScheduledCareItem item) {
  if (item.resourceType == ScheduledCareResourceType.bookingRequest) {
    return switch (BookingRequestStatus.parse(item.status)) {
      BookingRequestStatus.pendingDoctor => const _AgendaStatusPresentation(
        'À traiter',
        OmniColors.amber,
        OmniColors.amberSoft,
      ),
      BookingRequestStatus.pendingPatientTimeConfirmation =>
        const _AgendaStatusPresentation(
          'Réponse patient',
          OmniColors.clinicalCyan,
          OmniColors.clinicalCyanSoft,
        ),
      BookingRequestStatus.fulfilled => const _AgendaStatusPresentation(
        'Confirmée',
        OmniColors.deepTeal,
        OmniColors.mintSoft,
      ),
      BookingRequestStatus.cancelledByPatient ||
      BookingRequestStatus.cancelledByDoctor => const _AgendaStatusPresentation(
        'Annulée',
        OmniColors.error,
        OmniColors.errorSoft,
      ),
      BookingRequestStatus.expired => const _AgendaStatusPresentation(
        'Expirée',
        OmniColors.textSecondary,
        OmniColors.slateSoft,
      ),
      BookingRequestStatus.unknown => _AgendaStatusPresentation(
        'État indisponible (${item.status})',
        OmniColors.textSecondary,
        OmniColors.slateSoft,
      ),
    };
  }
  return switch (ScheduledAppointmentStatus.parse(item.status)) {
    ScheduledAppointmentStatus.confirmed => const _AgendaStatusPresentation(
      'Confirmé',
      OmniColors.deepTeal,
      OmniColors.mintSoft,
    ),
    ScheduledAppointmentStatus.inProgress => const _AgendaStatusPresentation(
      'En cours',
      OmniColors.clinicalCyan,
      OmniColors.clinicalCyanSoft,
    ),
    ScheduledAppointmentStatus.cancelled => const _AgendaStatusPresentation(
      'Annulé',
      OmniColors.error,
      OmniColors.errorSoft,
    ),
    ScheduledAppointmentStatus.completed => const _AgendaStatusPresentation(
      'Terminé',
      OmniColors.slateBlue,
      OmniColors.slateSoft,
    ),
    ScheduledAppointmentStatus.noShow => const _AgendaStatusPresentation(
      'Patient absent',
      OmniColors.amber,
      OmniColors.amberSoft,
    ),
    ScheduledAppointmentStatus.unknown => _AgendaStatusPresentation(
      'État indisponible (${item.status})',
      OmniColors.textSecondary,
      OmniColors.slateSoft,
    ),
  };
}
