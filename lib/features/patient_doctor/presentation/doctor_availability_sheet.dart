import 'package:flutter/material.dart';

import '../../../core/theme/omni_theme.dart';
import '../data/doctor_detail_models.dart';

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
class DoctorAvailabilitySheet extends StatefulWidget {
  const DoctorAvailabilitySheet({super.key, required this.detail});

  final DoctorDetail detail;

  @override
  State<DoctorAvailabilitySheet> createState() =>
      _DoctorAvailabilitySheetState();
}

class _DoctorAvailabilitySheetState extends State<DoctorAvailabilitySheet> {
  late DateTime _currentMonth;
  DateTime? _selectedDate;
  String? _selectedTime;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentMonth = DateTime(now.year, now.month);
    _selectedDate = _findNextAvailableDate();
  }

  DateTime? _findNextAvailableDate() {
    final now = DateTime.now();
    for (final day in widget.detail.availability) {
      if (day.date.isAfter(now.subtract(const Duration(days: 1))) &&
          day.hasSlots) {
        return day.date;
      }
    }
    return null;
  }

  List<DoctorDayAvailability> get _visibleDays {
    return widget.detail.availability.where((day) {
      return day.date.year == _currentMonth.year &&
          day.date.month == _currentMonth.month;
    }).toList();
  }

  DoctorDayAvailability? get _selectedDayAvailability {
    if (_selectedDate == null) return null;
    for (final day in widget.detail.availability) {
      if (day.date.year == _selectedDate!.year &&
          day.date.month == _selectedDate!.month &&
          day.date.day == _selectedDate!.day) {
        return day;
      }
    }
    return null;
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
      _selectedDate = null;
      _selectedTime = null;
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
      _selectedDate = null;
      _selectedTime = null;
    });
  }

  void _selectDate(DateTime date) {
    setState(() {
      _selectedDate = date;
      _selectedTime = null;
    });
  }

  void _selectTime(String time) {
    setState(() {
      _selectedTime = time;
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
                  onPressed: _previousMonth,
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
                  onPressed: _nextMonth,
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
                        hasSlots: day.hasSlots,
                        onTap: () => _selectDate(day.date),
                      );
                    },
                  ),
          ),

          const SizedBox(height: OmniSpacing.xs),

          // Slots section
          Expanded(
            child: _selectedDate == null
                ? Center(
                    child: Text(
                      'Sélectionnez une date pour voir les créneaux',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 12,
                        color: OmniColors.textTertiary,
                      ),
                    ),
                  )
                : _buildSlotsContent(),
          ),

          if (_selectedTime != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                OmniSpacing.pageHorizontal,
                2,
                OmniSpacing.pageHorizontal,
                0,
              ),
              child: _SlotBookingNotice(doctorName: widget.detail.name),
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
                  onPressed: _selectedTime != null ? _onContinue : null,
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
    if (dayData == null || !dayData.hasSlots) {
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
              'Essayez une autre date.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 12,
                color: OmniColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    final slotsByPeriod = dayData.slotsByPeriod;
    final periodOrder = ['Matin', 'Après-midi', 'Soir'];

    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: OmniSpacing.pageHorizontal,
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
                    isSelected: _selectedTime == slot.time,
                    onTap: () => _selectTime(slot.time),
                  ),
              ],
            ),
            const SizedBox(height: OmniSpacing.md),
          ],
        ],
      ],
    );
  }

  void _onContinue() {
    if (_selectedTime == null || _selectedDate == null) return;
    // This UI phase has no reservation API. Close the picker after the
    // patient's explicit intent, leaving the real booking contract to the
    // future availability/reservation flow.
    Navigator.of(context).pop();
  }
}

class _SlotBookingNotice extends StatelessWidget {
  const _SlotBookingNotice({required this.doctorName});

  final String doctorName;

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
              'En continuant, vous réservez ce créneau avec $doctorName.',
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
