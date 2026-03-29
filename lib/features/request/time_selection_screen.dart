import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../providers/reservation_provider.dart';
import '../../core/api/reservations_api.dart';
import 'request_submitted_screen.dart';

enum TimeWindowUi { morning, afternoon, other }

enum TimeWindowBackend { MORNING, AFTERNOON, EVENING, ANYTIME }

class SelectedIntent {
  final DateTime date;
  final TimeWindowBackend timeWindow;
  final TimeOfDay? exactTime;

  const SelectedIntent({
    required this.date,
    required this.timeWindow,
    this.exactTime,
  });

  String get label {
    final d = '${date.day}/${date.month}';
    if (exactTime != null) {
      final h = exactTime!.hour.toString().padLeft(2, '0');
      final m = exactTime!.minute.toString().padLeft(2, '0');
      return '$d $h:$m';
    }
    return '$d ${timeWindow.name.toLowerCase()}';
  }

  Map<String, dynamic> toApiIntent() {
    return {
      'dayOfWeek': null,
      'specificDate': _isoDate(date),
      'timeWindow': timeWindow.name,
      'exactTime': exactTime == null ? null : _isoTime(exactTime!),
    };
  }
}

class TimeSelectionScreen extends StatefulWidget {
  final String providerId;
  final String? visitType;
  final bool isEmergency;
  final Map<DateTime, Set<TimeOfDay>> blockedExactTimes;

  const TimeSelectionScreen({
    super.key,
    required this.providerId,
    this.visitType,
    this.isEmergency = false,
    this.blockedExactTimes = const {},
  });

  @override
  State<TimeSelectionScreen> createState() => _TimeSelectionScreenState();
}

class _TimeSelectionScreenState extends State<TimeSelectionScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedDay = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );

  TimeWindowUi _mode = TimeWindowUi.morning;
  final List<SelectedIntent> _selected = [];

  bool get _canSubmit => _selected.length == 3;

  Future<bool> _promptSwitchToClinic() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Consultation physique requise',
            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
          ),
          content: Text(
            "Conformément à la réglementation, votre première consultation avec ce médecin doit être effectuée en cabinet/clinique. Voulez-vous basculer vers une visite en clinique ?",
            style: GoogleFonts.plusJakartaSans(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                'Annuler',
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF667085),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1FBF9A),
              ),
              child: Text(
                'Passer en clinique',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );
    return result == true;
  }

  Future<bool> _promptEmergencyDeclaration() async {
    bool declared = false;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'Urgent Intervention',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'This home visit is treated as an urgent intervention. A follow-up clinic visit may be required.',
                    style: GoogleFonts.plusJakartaSans(),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Checkbox(
                        value: declared,
                        activeColor: const Color(0xFF1FBF9A),
                        onChanged: (v) => setState(() => declared = v == true),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'I declare that this is an urgent request requiring immediate medical attention at home, and I understand that a follow-up clinic visit may be required.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF667085),
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF667085),
                    ),
                  ),
                ),
                ElevatedButton(
                  onPressed: declared
                      ? () => Navigator.pop(context, true)
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1FBF9A),
                    disabledBackgroundColor: const Color(
                      0xFF1FBF9A,
                    ).withOpacity(0.5),
                  ),
                  child: Text(
                    'Continue',
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    final reservationProvider = context.watch<ReservationProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1D2939)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Select 3 Time Slots',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1D2939),
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: _MonthHeader(
                month: _month,
                onPrev: () => setState(
                  () => _month = DateTime(_month.year, _month.month - 1),
                ),
                onNext: () => setState(
                  () => _month = DateTime(_month.year, _month.month + 1),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _CalendarGrid(
                month: _month,
                selectedDay: _selectedDay,
                onSelectDay: (d) => setState(() {
                  _selectedDay = d;
                }),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _ModeSelector(
                value: _mode,
                onChanged: (v) => setState(() => _mode = v),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildModeBody(context),
              ),
            ),
            if (_selected.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: _SelectedChips(
                  selected: _selected,
                  onRemove: (i) => setState(() => _selected.remove(i)),
                ),
              ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (!_canSubmit || reservationProvider.isLoading)
                        ? null
                        : () async {
                            final searchStart = _selected
                                .map((e) => e.date)
                                .reduce(_minDate);
                            final searchEnd = _selected
                                .map((e) => e.date)
                                .reduce(_maxDate);
                            final intents = _selected
                                .map((e) => e.toApiIntent())
                                .toList(growable: false);

                            final provider = context
                                .read<ReservationProvider>();
                            String? visitType = widget.visitType;
                            bool isEmergency = widget.isEmergency;
                            try {
                              await provider.submitRequest(
                                providerId: widget.providerId,
                                visitType: visitType,
                                isEmergency: isEmergency,
                                searchStartDate: searchStart,
                                searchEndDate: searchEnd,
                                intents: intents,
                              );
                            } on ReservationApiException catch (e) {
                              if (e.code ==
                                  'ERR_EMERGENCY_DECLARATION_REQUIRED') {
                                final confirm =
                                    await _promptEmergencyDeclaration();
                                if (!confirm) {
                                  final switchToClinic =
                                      await _promptSwitchToClinic();
                                  if (!switchToClinic) return;
                                  visitType = 'CLINIC';
                                  await provider.submitRequest(
                                    providerId: widget.providerId,
                                    visitType: visitType,
                                    isEmergency: false,
                                    searchStartDate: searchStart,
                                    searchEndDate: searchEnd,
                                    intents: intents,
                                  );
                                  return;
                                }
                                isEmergency = true;
                                await provider.submitRequest(
                                  providerId: widget.providerId,
                                  visitType: visitType,
                                  isEmergency: true,
                                  searchStartDate: searchStart,
                                  searchEndDate: searchEnd,
                                  intents: intents,
                                );
                              } else if (e.code ==
                                  'ERR_PHYSICAL_EXAM_REQUIRED') {
                                final confirm = await _promptSwitchToClinic();
                                if (!confirm) {
                                  return;
                                }
                                visitType = 'CLINIC';
                                await provider.submitRequest(
                                  providerId: widget.providerId,
                                  visitType: visitType,
                                  isEmergency: false,
                                  searchStartDate: searchStart,
                                  searchEndDate: searchEnd,
                                  intents: intents,
                                );
                              } else {
                                rethrow;
                              }
                            }

                            if (!context.mounted) return;
                            Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const RequestSubmittedScreen(
                                      providerCount: 1,
                                      providerType: 'doctor',
                                    ),
                              ),
                            );
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1FBF9A),
                      disabledBackgroundColor: const Color(
                        0xFF1FBF9A,
                      ).withOpacity(0.5),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      reservationProvider.isLoading
                          ? 'Submitting...'
                          : 'SUBMIT REQUEST (${_selected.length}/3)',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeBody(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: switch (_mode) {
        TimeWindowUi.morning => _WindowPicker(
          title: 'Morning',
          subtitle: 'Your provider will respond with an exact time',
          icon: Icons.wb_sunny_outlined,
          onPick: () => _toggleWindow(TimeWindowBackend.MORNING),
          isSelected: _selected.any(
            (e) =>
                _sameDay(e.date, _selectedDay) &&
                e.timeWindow == TimeWindowBackend.MORNING &&
                e.exactTime == null,
          ),
        ),
        TimeWindowUi.afternoon => _WindowPicker(
          title: 'Afternoon',
          subtitle: 'Your provider will respond with an exact time',
          icon: Icons.wb_twilight_outlined,
          onPick: () => _toggleWindow(TimeWindowBackend.AFTERNOON),
          isSelected: _selected.any(
            (e) =>
                _sameDay(e.date, _selectedDay) &&
                e.timeWindow == TimeWindowBackend.AFTERNOON &&
                e.exactTime == null,
          ),
        ),
        TimeWindowUi.other => _ExactTimeList(
          selectedDay: _selectedDay,
          blocked:
              widget.blockedExactTimes[_dateOnly(_selectedDay)] ??
              const <TimeOfDay>{},
          isPicked: (t) => _selected.any(
            (e) =>
                _sameDay(e.date, _selectedDay) &&
                e.exactTime != null &&
                _sameTime(e.exactTime!, t),
          ),
          onPick: (t) => _toggleExactTime(t),
        ),
      },
    );
  }

  void _toggleWindow(TimeWindowBackend window) {
    if (_selected.length >= 3 &&
        !_selected.any(
          (e) =>
              _sameDay(e.date, _selectedDay) &&
              e.timeWindow == window &&
              e.exactTime == null,
        )) {
      return;
    }

    final existing = _selected.indexWhere(
      (e) =>
          _sameDay(e.date, _selectedDay) &&
          e.timeWindow == window &&
          e.exactTime == null,
    );
    setState(() {
      if (existing >= 0) {
        _selected.removeAt(existing);
      } else {
        _selected.add(SelectedIntent(date: _selectedDay, timeWindow: window));
      }
    });
  }

  void _toggleExactTime(TimeOfDay time) {
    if (_selected.length >= 3 &&
        !_selected.any(
          (e) =>
              _sameDay(e.date, _selectedDay) &&
              e.exactTime != null &&
              _sameTime(e.exactTime!, time),
        )) {
      return;
    }

    final existing = _selected.indexWhere(
      (e) =>
          _sameDay(e.date, _selectedDay) &&
          e.exactTime != null &&
          _sameTime(e.exactTime!, time),
    );
    setState(() {
      if (existing >= 0) {
        _selected.removeAt(existing);
      } else {
        _selected.add(
          SelectedIntent(
            date: _selectedDay,
            timeWindow: TimeWindowBackend.ANYTIME,
            exactTime: time,
          ),
        );
      }
    });
  }
}

class _MonthHeader extends StatelessWidget {
  final DateTime month;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  const _MonthHeader({
    required this.month,
    required this.onPrev,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final label = '${_monthName(month.month)} ${month.year}';
    return Row(
      children: [
        IconButton(
          onPressed: onPrev,
          icon: const Icon(Icons.chevron_left, color: Color(0xFF1D2939)),
        ),
        Expanded(
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1D2939),
            ),
          ),
        ),
        IconButton(
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right, color: Color(0xFF1D2939)),
        ),
      ],
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  final DateTime month;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onSelectDay;

  const _CalendarGrid({
    required this.month,
    required this.selectedDay,
    required this.onSelectDay,
  });

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final startWeekday = (first.weekday % 7);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;

    final cells = <Widget>[];

    for (int i = 0; i < startWeekday; i++) {
      cells.add(const SizedBox.shrink());
    }

    for (int day = 1; day <= daysInMonth; day++) {
      final date = DateTime(month.year, month.month, day);
      final isSelected = _sameDay(date, selectedDay);
      final isToday = _sameDay(date, DateTime.now());

      cells.add(
        GestureDetector(
          onTap: () => onSelectDay(date),
          child: Container(
            margin: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF1FBF9A) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF1FBF9A)
                    : (isToday
                          ? const Color(0xFF1FBF9A)
                          : const Color(0xFFE5E7EB)),
              ),
            ),
            child: Center(
              child: Text(
                day.toString(),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFF1D2939),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: cells,
    );
  }
}

class _ModeSelector extends StatelessWidget {
  final TimeWindowUi value;
  final ValueChanged<TimeWindowUi> onChanged;

  const _ModeSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ModeChip(
              label: 'Morning',
              selected: value == TimeWindowUi.morning,
              onTap: () => onChanged(TimeWindowUi.morning),
            ),
          ),
          Expanded(
            child: _ModeChip(
              label: 'Afternoon',
              selected: value == TimeWindowUi.afternoon,
              onTap: () => onChanged(TimeWindowUi.afternoon),
            ),
          ),
          Expanded(
            child: _ModeChip(
              label: 'Other',
              selected: value == TimeWindowUi.other,
              onTap: () => onChanged(TimeWindowUi.other),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF1FBF9A).withOpacity(0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected
                  ? const Color(0xFF1FBF9A)
                  : const Color(0xFF667085),
            ),
          ),
        ),
      ),
    );
  }
}

class _WindowPicker extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onPick;
  final bool isSelected;

  const _WindowPicker({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onPick,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPick,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF1FBF9A).withOpacity(0.08)
              : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF1FBF9A)
                : const Color(0xFFE5E7EB),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF1FBF9A).withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF1FBF9A)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1D2939),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF667085),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: Color(0xFF1FBF9A)),
          ],
        ),
      ),
    );
  }
}

class _ExactTimeList extends StatelessWidget {
  final DateTime selectedDay;
  final Set<TimeOfDay> blocked;
  final bool Function(TimeOfDay time) isPicked;
  final ValueChanged<TimeOfDay> onPick;

  const _ExactTimeList({
    required this.selectedDay,
    required this.blocked,
    required this.isPicked,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final times = _buildIntervals(
      start: const TimeOfDay(hour: 8, minute: 0),
      end: const TimeOfDay(hour: 20, minute: 0),
      stepMinutes: 30,
    );

    return ListView.separated(
      itemCount: times.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final t = times[index];
        final disabled = blocked.any((b) => _sameTime(b, t));
        final selected = isPicked(t);

        return GestureDetector(
          onTap: disabled ? null : () => onPick(t),
          child: Opacity(
            opacity: disabled ? 0.45 : 1,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: selected
                      ? const Color(0xFF1FBF9A)
                      : const Color(0xFFE5E7EB),
                  width: selected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: selected
                          ? const Color(0xFF1FBF9A).withOpacity(0.12)
                          : const Color(0xFFF4F5F7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.schedule,
                      color: selected
                          ? const Color(0xFF1FBF9A)
                          : const Color(0xFF667085),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _formatTimeOfDay(t),
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: disabled
                            ? const Color(0xFF667085)
                            : (selected
                                  ? const Color(0xFF1FBF9A)
                                  : const Color(0xFF1D2939)),
                      ),
                    ),
                  ),
                  if (selected)
                    const Icon(Icons.check_circle, color: Color(0xFF1FBF9A)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SelectedChips extends StatelessWidget {
  final List<SelectedIntent> selected;
  final ValueChanged<SelectedIntent> onRemove;

  const _SelectedChips({required this.selected, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: selected
          .map(
            (i) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1FBF9A).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF1FBF9A).withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    i.label,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F6F73),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => onRemove(i),
                    child: const Icon(
                      Icons.close,
                      size: 16,
                      color: Color(0xFF0F6F73),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

List<TimeOfDay> _buildIntervals({
  required TimeOfDay start,
  required TimeOfDay end,
  required int stepMinutes,
}) {
  final out = <TimeOfDay>[];
  int minutes = start.hour * 60 + start.minute;
  final endMinutes = end.hour * 60 + end.minute;
  while (minutes <= endMinutes) {
    out.add(TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60));
    minutes += stepMinutes;
  }
  return out;
}

String _formatTimeOfDay(TimeOfDay t) {
  final h = t.hour.toString().padLeft(2, '0');
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

String _isoDate(DateTime dt) {
  final y = dt.year.toString().padLeft(4, '0');
  final m = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

String _isoTime(TimeOfDay t) {
  final h = t.hour.toString().padLeft(2, '0');
  final m = t.minute.toString().padLeft(2, '0');
  return '$h:$m:00';
}

bool _sameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

bool _sameTime(TimeOfDay a, TimeOfDay b) {
  return a.hour == b.hour && a.minute == b.minute;
}

DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

DateTime _minDate(DateTime a, DateTime b) => a.isBefore(b) ? a : b;

DateTime _maxDate(DateTime a, DateTime b) => a.isAfter(b) ? a : b;

String _monthName(int month) {
  return switch (month) {
    1 => 'January',
    2 => 'February',
    3 => 'March',
    4 => 'April',
    5 => 'May',
    6 => 'June',
    7 => 'July',
    8 => 'August',
    9 => 'September',
    10 => 'October',
    11 => 'November',
    12 => 'December',
    _ => '',
  };
}
