import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/omni_theme.dart';
import '../data/doctor_detail_models.dart';
import '../../scheduled_care_prototype/scheduled_booking_review_screen.dart';
import '../../scheduled_care/application/scheduled_care_controller.dart';
import '../../scheduled_care/domain/scheduled_care_models.dart';
import '../../scheduled_care_prototype/scheduled_care_controller.dart';
import '../../scheduled_care_prototype/scheduled_care_models.dart';

/// Large modal bottom sheet showing doctor availability.
///
/// Height: ~50% of screen. Rounded top corners, dismissible.
///
/// Structure:
/// - Drag handle
/// - Title + doctor name
/// - Month navigation with < > arrows
/// - Horizontal day strip
/// - Time slots grouped by Matin / Après-midi / Soir
/// - Sticky Continue CTA at bottom (enabled only after slot selection)
///
/// Booking always reads cabinet-scoped availability and creates a request
/// through the scheduled-care workflow.
class DoctorAvailabilitySheet extends StatefulWidget {
  const DoctorAvailabilitySheet({
    super.key,
    required this.detail,
    required this.cabinet,
    this.scheduledCareController,
    this.prototypeController,
  });

  final DoctorDetail detail;
  final ScheduledCareCabinet cabinet;
  final ScheduledCareController? scheduledCareController;
  final ScheduledCarePrototypeController? prototypeController;

  @override
  State<DoctorAvailabilitySheet> createState() =>
      _DoctorAvailabilitySheetState();
}

class _DoctorAvailabilitySheetState extends State<DoctorAvailabilitySheet> {
  late DateTime _currentMonth;
  DateTime? _selectedDate;
  DoctorAvailabilitySlot? _selectedSlot;

  DateTime get _currentTime =>
      widget.scheduledCareController?.currentTime ??
      widget.prototypeController?.currentTime ??
      DateTime.now();

  int? get _selectedDurationMinutes {
    final slot = _selectedSlot;
    return slot?.end.difference(slot.start).inMinutes;
  }

  @override
  void initState() {
    super.initState();
    widget.scheduledCareController?.addListener(_scheduledCareChanged);
    widget.prototypeController?.addListener(_scheduledCareChanged);
    _selectedDate = _findNextAvailableDate();
    final schedulingNow = displayInTimeZone(
      _currentTime,
      widget.cabinet.timezone.isEmpty
          ? 'Africa/Tunis'
          : widget.cabinet.timezone,
    );
    final anchor =
        _selectedDate ??
        (_availability.isEmpty ? schedulingNow : _availability.first.date);
    _currentMonth = DateTime(anchor.year, anchor.month);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadCurrentMonth();
    });
  }

  bool get _usesScheduledCare => widget.scheduledCareController != null;
  bool get _usesPrototype => widget.prototypeController != null;
  bool get _usesScheduledWorkflow => _usesScheduledCare || _usesPrototype;

  void _scheduledCareChanged() {
    if (!mounted) return;
    setState(() {
      final next = _findNextAvailableDate();
      if (_selectedDate == null && next != null) {
        _selectedDate = next;
        _currentMonth = DateTime(next.year, next.month);
      }
    });
  }

  @override
  void dispose() {
    widget.scheduledCareController?.removeListener(_scheduledCareChanged);
    widget.prototypeController?.removeListener(_scheduledCareChanged);
    super.dispose();
  }

  List<DoctorDayAvailability> get _availability {
    final scheduledCare = widget.scheduledCareController;
    if (scheduledCare == null && !_usesPrototype) {
      return const <DoctorDayAvailability>[];
    }
    final days = <DateTime, List<DoctorAvailabilitySlot>>{};
    final slots =
        scheduledCare?.availability?.slots ??
        widget.prototypeController
            ?.freeSlotsFor(
              CabinetPrototype(
                id: widget.cabinet.practiceLocationId,
                name: widget.cabinet.name,
                address: widget.cabinet.address,
                city: widget.cabinet.city,
              ),
            )
            .map(
              (slot) => ScheduledCareSlot(start: slot.start, end: slot.end),
            ) ??
        const <ScheduledCareSlot>[];
    for (final slot in slots) {
      final day = DateTime(slot.start.year, slot.start.month, slot.start.day);
      days.putIfAbsent(day, () => []).add(_toAvailabilitySlot(slot));
    }
    final result =
        days.entries
            .map(
              (entry) => DoctorDayAvailability(
                date: entry.key,
                slots: entry.value..sort((a, b) => a.start.compareTo(b.start)),
              ),
            )
            .toList(growable: false)
          ..sort((a, b) => a.date.compareTo(b.date));
    return result;
  }

  DoctorAvailabilitySlot _toAvailabilitySlot(ScheduledCareSlot slot) {
    final timezone = widget.scheduledCareController?.availability?.timezone;
    final start = timezone == null
        ? slot.start.toLocal()
        : displayInTimeZone(slot.start, timezone);
    final end = timezone == null
        ? slot.end.toLocal()
        : displayInTimeZone(slot.end, timezone);
    final hour = start.hour;
    final period = hour < 12
        ? 'Matin'
        : hour < 18
        ? 'Après-midi'
        : 'Soir';
    final time =
        '${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}';
    return DoctorAvailabilitySlot(
      time: time,
      timeOfDay: period,
      startIso: slot.start.toIso8601String(),
      endIso: slot.end.toIso8601String(),
      start: start,
      end: end,
    );
  }

  DateTime? _findNextAvailableDate() {
    final now = _currentTime;
    for (final day in _availability) {
      if (day.date.isAfter(now.subtract(const Duration(days: 1))) &&
          _bookableSlots(day).isNotEmpty) {
        return day.date;
      }
    }
    return null;
  }

  List<DoctorAvailabilitySlot> _bookableSlots(DoctorDayAvailability day) {
    return day.slots;
  }

  List<DoctorDayAvailability> get _visibleDays {
    return _availability.where((day) {
      return day.date.year == _currentMonth.year &&
          day.date.month == _currentMonth.month;
    }).toList();
  }

  bool get _canPreviousMonth {
    if (_usesPrototype) {
      return _availability.any((day) {
        final month = DateTime(day.date.year, day.date.month);
        return month.isBefore(_currentMonth);
      });
    }
    final now = displayInTimeZone(
      _currentTime,
      widget.cabinet.timezone.isEmpty
          ? 'Africa/Tunis'
          : widget.cabinet.timezone,
    );
    return _currentMonth.isAfter(DateTime(now.year, now.month));
  }

  bool get _canNextMonth =>
      _usesScheduledCare ||
      _availability.any((day) {
        final month = DateTime(day.date.year, day.date.month);
        return month.isAfter(_currentMonth);
      });

  DoctorDayAvailability? get _selectedDayAvailability {
    if (_selectedDate == null) return null;
    for (final day in _availability) {
      if (day.date.year == _selectedDate!.year &&
          day.date.month == _selectedDate!.month &&
          day.date.day == _selectedDate!.day) {
        return day;
      }
    }
    return null;
  }

  void _previousMonth() {
    if (!_canPreviousMonth) return;
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
      _selectedDate = null;
      _selectedSlot = null;
    });
    _loadCurrentMonth();
  }

  void _nextMonth() {
    if (!_canNextMonth) return;
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
      _selectedDate = null;
      _selectedSlot = null;
    });
    _loadCurrentMonth();
  }

  void _loadCurrentMonth() {
    final controller = widget.scheduledCareController;
    if (controller == null) return;
    controller.loadAvailability(month: _currentMonth);
  }

  void _selectDate(DateTime date) {
    setState(() {
      _selectedDate = date;
      _selectedSlot = null;
    });
  }

  void _selectSlot(DoctorAvailabilitySlot slot) {
    setState(() {
      _selectedSlot = slot;
    });
  }

  String _monthLabel() {
    const months = [
      'Janvier',
      'Février',
      'Mars',
      'Avril',
      'Mai',
      'Juin',
      'Juillet',
      'Août',
      'Septembre',
      'Octobre',
      'Novembre',
      'Décembre',
    ];
    return '${months[_currentMonth.month - 1]} ${_currentMonth.year}';
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final sheetHeight = screenHeight * 0.50;

    return SizedBox(
      height: sheetHeight,
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(
              OmniSpacing.pageHorizontal,
              OmniSpacing.xs,
              OmniSpacing.pageHorizontal,
              0,
            ),
            child: Column(
              children: [
                // Title
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Disponibilités',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: OmniColors.textPrimary,
                            ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, size: 20),
                      color: OmniColors.textSecondary,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 36,
                        minHeight: 36,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                // Doctor name
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    widget.detail.name,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontSize: 11,
                      color: OmniColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${widget.cabinet.name} · ${widget.cabinet.address}, ${widget.cabinet.city}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: OmniColors.textSecondary,
                    ),
                  ),
                ),
                if (_usesScheduledWorkflow) ...[
                  const SizedBox(height: 2),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Pour : ${widget.scheduledCareController?.draft.subject?.displayName ?? widget.prototypeController?.draft.patient?.displayName ?? 'Patient'}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: OmniColors.deepTeal,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: OmniSpacing.xs),

          // Month navigation
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: OmniSpacing.pageHorizontal,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: _canPreviousMonth ? _previousMonth : null,
                  icon: const Icon(Icons.chevron_left_rounded, size: 24),
                  color: OmniColors.textPrimary,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 30,
                    minHeight: 30,
                  ),
                ),
                Text(
                  _monthLabel(),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: OmniColors.textPrimary,
                  ),
                ),
                IconButton(
                  onPressed: _canNextMonth ? _nextMonth : null,
                  icon: const Icon(Icons.chevron_right_rounded, size: 24),
                  color: OmniColors.textPrimary,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 30,
                    minHeight: 30,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: OmniSpacing.xs),

          // Day strip
          SizedBox(
            height: 56,
            child: _visibleDays.isEmpty
                ? Center(
                    child: Text(
                      'Aucune disponibilité ce mois-ci',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 12,
                        color: OmniColors.textTertiary,
                      ),
                    ),
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: OmniSpacing.pageHorizontal,
                    ),
                    itemCount: _visibleDays.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(width: OmniSpacing.sm),
                    itemBuilder: (context, index) {
                      final day = _visibleDays[index];
                      final isSelected =
                          _selectedDate?.year == day.date.year &&
                          _selectedDate?.month == day.date.month &&
                          _selectedDate?.day == day.date.day;
                      return _DayChip(
                        date: day.date,
                        isSelected: isSelected,
                        hasSlots: _bookableSlots(day).isNotEmpty,
                        onTap: () => _selectDate(day.date),
                      );
                    },
                  ),
          ),

          const SizedBox(height: OmniSpacing.xs),

          // Slots section
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                _usesScheduledCare &&
                        widget.scheduledCareController!.isLoadingAvailability &&
                        _availability.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : _usesScheduledCare &&
                          widget.scheduledCareController!.failure != null &&
                          _availability.isEmpty
                    ? Center(
                        child: TextButton(
                          onPressed: () => widget.scheduledCareController!
                              .loadAvailability(month: _currentMonth),
                          child: Text(
                            widget.scheduledCareController!.failure!.message,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : _selectedDate == null
                    ? Center(
                        child: Text(
                          'Sélectionnez une date pour voir les créneaux',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                fontSize: 12,
                                color: OmniColors.textTertiary,
                              ),
                        ),
                      )
                    : _buildSlotsContent(),
                if (_selectedSlot != null)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: IgnorePointer(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: OmniSpacing.pageHorizontal,
                        ),
                        child: _SlotBookingNotice(
                          doctorName: widget.detail.name,
                          cabinetName: widget.cabinet.name,
                          durationMinutes: _selectedDurationMinutes,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Continue CTA
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                OmniSpacing.pageHorizontal,
                OmniSpacing.xs,
                OmniSpacing.pageHorizontal,
                OmniSpacing.xs,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 38,
                child: ElevatedButton(
                  onPressed: _selectedSlot != null ? _onContinue : null,
                  child: const Text('Continuer'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlotsContent() {
    final dayData = _selectedDayAvailability;
    final bookableSlots = dayData == null
        ? const <DoctorAvailabilitySlot>[]
        : _bookableSlots(dayData);
    if (dayData == null || bookableSlots.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: OmniColors.surfaceSecondary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.event_busy_outlined,
                size: 22,
                color: OmniColors.slateBlue,
              ),
            ),
            const SizedBox(height: OmniSpacing.sm),
            Text(
              'Aucun créneau disponible ce jour-là.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: OmniColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: OmniSpacing.sm),
            Text(
              _usesScheduledWorkflow
                  ? 'Choisissez un créneau au moins 4 h à l’avance.'
                  : 'Essayez une autre date.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 12,
                color: OmniColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    final slotsByPeriod = <String, List<DoctorAvailabilitySlot>>{};
    for (final slot in bookableSlots) {
      slotsByPeriod.putIfAbsent(slot.timeOfDay, () => []).add(slot);
    }
    final periodOrder = ['Matin', 'Après-midi', 'Soir'];

    return ListView(
      padding: EdgeInsets.fromLTRB(
        OmniSpacing.pageHorizontal,
        0,
        OmniSpacing.pageHorizontal,
        _selectedSlot == null ? 0 : 52,
      ),
      children: [
        for (final period in periodOrder) ...[
          if (slotsByPeriod.containsKey(period)) ...[
            Text(
              period,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: OmniColors.textSecondary,
              ),
            ),
            const SizedBox(height: OmniSpacing.sm),
            Wrap(
              spacing: OmniSpacing.sm,
              runSpacing: OmniSpacing.sm,
              children: [
                for (final slot in slotsByPeriod[period]!)
                  _TimeSlotChip(
                    time: slot.time,
                    isSelected: _selectedSlot?.startIso == slot.startIso,
                    onTap: () => _selectSlot(slot),
                  ),
              ],
            ),
            const SizedBox(height: OmniSpacing.md),
          ],
        ],
      ],
    );
  }

  Future<void> _onContinue() async {
    final slot = _selectedSlot;
    if (slot == null) return;
    if (_usesScheduledCare) {
      final scheduledCare = widget.scheduledCareController!;
      scheduledCare.selectSlot(
        ScheduledCareSlot(start: slot.start, end: slot.end),
      );
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => ChangeNotifierProvider<ScheduledCareController>.value(
            value: scheduledCare,
            child: const ScheduledBookingReviewScreen(),
          ),
        ),
      );
      return;
    }
    if (_usesPrototype) {
      final prototype = widget.prototypeController!;
      prototype.selectSlot(
        SlotPrototype(
          id: '${widget.cabinet.practiceLocationId}-${slot.startIso}',
          cabinetId: widget.cabinet.practiceLocationId,
          start: slot.start,
          end: slot.end,
        ),
      );
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) =>
              ChangeNotifierProvider<ScheduledCarePrototypeController>.value(
                value: prototype,
                child: const ScheduledBookingReviewScreen(),
              ),
        ),
      );
      return;
    }
  }
}

class _SlotBookingNotice extends StatelessWidget {
  const _SlotBookingNotice({
    required this.doctorName,
    required this.cabinetName,
    required this.durationMinutes,
  });

  final String doctorName;
  final String cabinetName;
  final int? durationMinutes;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: OmniSpacing.sm,
        vertical: OmniSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: OmniColors.warningSubtle,
        border: Border.all(color: OmniColors.warning.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(OmniRadii.field),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: OmniColors.warning,
          ),
          const SizedBox(width: OmniSpacing.xs),
          Expanded(
            child: Text(
              'Créneau de ${durationMinutes ?? 0} min avec $doctorName · $cabinetName. Vous pourrez le vérifier avant d’envoyer la demande.',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 11,
                height: 1.25,
                color: OmniColors.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A single day chip in the horizontal day strip.
class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.date,
    required this.isSelected,
    required this.hasSlots,
    required this.onTap,
  });

  final DateTime date;
  final bool isSelected;
  final bool hasSlots;
  final VoidCallback onTap;

  static const _dayNames = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];

  @override
  Widget build(BuildContext context) {
    final dayIndex = date.weekday - 1;
    final dayName = _dayNames[dayIndex.clamp(0, 6)];
    final dayNumber = date.day;

    final bg = isSelected
        ? OmniColors.primaryAction
        : OmniColors.surfacePrimary;
    final fg = isSelected ? Colors.white : OmniColors.textPrimary;
    final nameFg = isSelected
        ? Colors.white.withValues(alpha: 0.8)
        : OmniColors.textSecondary;

    return GestureDetector(
      onTap: hasSlots ? onTap : null,
      child: Container(
        key: ValueKey(
          "availability-day-${date.year.toString().padLeft(4, '0')}-"
          "${date.month.toString().padLeft(2, '0')}-"
          "${date.day.toString().padLeft(2, '0')}",
        ),
        width: 60,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(OmniRadii.field),
          border: Border.all(
            color: isSelected
                ? OmniColors.primaryAction
                : hasSlots
                ? OmniColors.borderLight
                : OmniColors.borderLight.withValues(alpha: 0.5),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              dayName,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: nameFg,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$dayNumber',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
            if (!hasSlots)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: OmniColors.textTertiary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A single time slot chip.
class _TimeSlotChip extends StatelessWidget {
  const _TimeSlotChip({
    required this.time,
    required this.isSelected,
    required this.onTap,
  });

  final String time;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = isSelected ? OmniColors.primaryAction : OmniColors.mintSoft;
    final fg = isSelected ? Colors.white : OmniColors.deepTeal;

    return Semantics(
      key: ValueKey(
        'availability-slot-$time-${isSelected ? 'selected' : 'available'}',
      ),
      button: true,
      selected: isSelected,
      label: isSelected ? '$time, sélectionné' : time,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: OmniSpacing.sm + 2,
            vertical: OmniSpacing.xs + 2,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(OmniRadii.field),
            border: Border.all(
              color: isSelected
                  ? OmniColors.primaryAction
                  : OmniColors.freshMint,
            ),
          ),
          child: Text(
            time,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }
}
