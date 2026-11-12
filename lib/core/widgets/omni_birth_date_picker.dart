import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../l10n/omni_localizations.dart';
import '../theme/omni_theme.dart';

/// Bundled family (pubspec, weights 500–800). The theme's google_fonts
/// text styles keep their 400 face when only the weight changes.
const String _bundledFont = 'Plus Jakarta Sans';

/// Opens the OmniCare birth-date wheel picker (three wheels: day, month,
/// year) in a modal bottom sheet styled by `bottomSheetTheme`.
///
/// Pure UI: the screen passes every limit from its own rule.
/// * Years run from [firstDate] to [lastDate].
/// * A composed date after [lastDate] shows [lastDateError] (when given) and
///   disables « Valider »; a date before [firstDate] only disables it.
///
/// Returns the chosen date (time part zero), or null when closed.
///
/// Wheels: `ListWheelScrollView.useDelegate` with a
/// `FixedExtentScrollController` and `FixedExtentScrollPhysics`
/// (api.flutter.dev/flutter/widgets/ListWheelScrollView-class.html).
/// Month names come from `intl` for the app locale (French), loaded by
/// `GlobalMaterialLocalizations` (docs.flutter.dev/ui/internationalization).
Future<DateTime?> showOmniBirthDatePicker(
  BuildContext context, {
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String? lastDateError,
}) {
  assert(
    !DateUtils.dateOnly(firstDate).isAfter(DateUtils.dateOnly(lastDate)),
    'firstDate must not be after lastDate',
  );
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _BirthDatePickerSheet(
      initialDate: initialDate,
      firstDate: DateUtils.dateOnly(firstDate),
      lastDate: DateUtils.dateOnly(lastDate),
      lastDateError: lastDateError,
    ),
  );
}

class _BirthDatePickerSheet extends StatefulWidget {
  const _BirthDatePickerSheet({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.lastDateError,
  });

  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final String? lastDateError;

  @override
  State<_BirthDatePickerSheet> createState() => _BirthDatePickerSheetState();
}

class _BirthDatePickerSheetState extends State<_BirthDatePickerSheet> {
  static const double _itemExtent = 44;
  static const int _visibleRows = 5;

  late int _year;
  late int _month;
  late int _day;
  late final FixedExtentScrollController _dayController;
  late final FixedExtentScrollController _monthController;
  late final FixedExtentScrollController _yearController;

  int get _firstYear => widget.firstDate.year;
  int get _lastYear => widget.lastDate.year;
  int get _daysInMonth => DateUtils.getDaysInMonth(_year, _month);
  DateTime get _composed => DateTime(_year, _month, _day);
  bool get _isAfterLast => _composed.isAfter(widget.lastDate);
  bool get _isBeforeFirst => _composed.isBefore(widget.firstDate);

  @override
  void initState() {
    super.initState();
    final initial = widget.initialDate;
    _year = initial.year.clamp(_firstYear, _lastYear);
    _month = initial.month;
    _day = math.min(initial.day, _daysInMonth);
    _dayController = FixedExtentScrollController(initialItem: _day - 1);
    _monthController = FixedExtentScrollController(initialItem: _month - 1);
    _yearController = FixedExtentScrollController(
      initialItem: _year - _firstYear,
    );
  }

  @override
  void dispose() {
    _dayController.dispose();
    _monthController.dispose();
    _yearController.dispose();
    super.dispose();
  }

  /// Keeps the day inside the new month length (31 → 30 / 29 / 28).
  void _clampDay() {
    final maxDay = _daysInMonth;
    if (_day <= maxDay) return;
    _day = maxDay;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _dayController.hasClients) {
        _dayController.jumpToItem(_day - 1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = OmniLocalizations.of(context);
    final textTheme = Theme.of(context).textTheme;
    final locale = Localizations.localeOf(context).toString();
    final monthFormat = DateFormat.MMMM(locale);
    final showError = _isAfterLast && widget.lastDateError != null;
    final canConfirm = !_isAfterLast && !_isBeforeFirst;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        OmniSpacing.pageHorizontal,
        0,
        OmniSpacing.pageHorizontal,
        OmniSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.birthDatePickerTitle,
                  style: textTheme.titleLarge?.copyWith(
                    fontFamily: _bundledFont,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: OmniColors.textPrimary,
                  ),
                ),
              ),
              IconButton(
                tooltip: l10n.commonClose,
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(
                  Icons.close_rounded,
                  color: OmniColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: OmniSpacing.base),
          Row(
            children: [
              _columnLabel(context, l10n.birthDatePickerDay, 2),
              _columnLabel(context, l10n.birthDatePickerMonth, 3),
              _columnLabel(context, l10n.birthDatePickerYear, 2),
            ],
          ),
          const SizedBox(height: OmniSpacing.sm),
          SizedBox(
            height: _itemExtent * _visibleRows,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  height: _itemExtent,
                  decoration: BoxDecoration(
                    color: OmniColors.mintSoft,
                    borderRadius: BorderRadius.circular(OmniRadii.field),
                  ),
                ),
                Row(
                  children: [
                    _wheel(
                      flex: 2,
                      controller: _dayController,
                      count: _daysInMonth,
                      selectedIndex: _day - 1,
                      label: (i) => '${i + 1}',
                      onSelected: (i) => setState(() => _day = i + 1),
                    ),
                    _wheel(
                      flex: 3,
                      controller: _monthController,
                      count: 12,
                      selectedIndex: _month - 1,
                      label: (i) => monthFormat.format(DateTime(2000, i + 1)),
                      onSelected: (i) => setState(() {
                        _month = i + 1;
                        _clampDay();
                      }),
                    ),
                    _wheel(
                      flex: 2,
                      controller: _yearController,
                      count: _lastYear - _firstYear + 1,
                      selectedIndex: _year - _firstYear,
                      label: (i) => '${_firstYear + i}',
                      onSelected: (i) => setState(() {
                        _year = _firstYear + i;
                        _clampDay();
                      }),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (showError) ...[
            const SizedBox(height: OmniSpacing.base),
            Semantics(
              liveRegion: true,
              child: Container(
                padding: const EdgeInsets.all(OmniSpacing.md),
                decoration: BoxDecoration(
                  color: OmniColors.errorSoft,
                  borderRadius: BorderRadius.circular(OmniRadii.field),
                ),
                child: Text(
                  widget.lastDateError!,
                  style: textTheme.bodySmall?.copyWith(
                    fontFamily: _bundledFont,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: OmniColors.error,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: OmniSpacing.xl),
          ElevatedButton(
            onPressed: canConfirm
                ? () => Navigator.of(context).pop(_composed)
                : null,
            child: Text(l10n.birthDatePickerConfirm),
          ),
        ],
      ),
    );
  }

  Widget _columnLabel(BuildContext context, String text, int flex) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          fontFamily: _bundledFont,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: OmniColors.textSecondary,
        ),
      ),
    );
  }

  Widget _wheel({
    required int flex,
    required FixedExtentScrollController controller,
    required int count,
    required int selectedIndex,
    required String Function(int index) label,
    required ValueChanged<int> onSelected,
  }) {
    return Expanded(
      flex: flex,
      child: ListWheelScrollView.useDelegate(
        controller: controller,
        itemExtent: _itemExtent,
        physics: const FixedExtentScrollPhysics(),
        diameterRatio: 1.6,
        onSelectedItemChanged: onSelected,
        childDelegate: ListWheelChildBuilderDelegate(
          childCount: count,
          builder: (context, index) => _WheelItem(
            text: label(index),
            distance: (index - selectedIndex).abs(),
          ),
        ),
      ),
    );
  }
}

/// One wheel row; style depends on its distance from the selected row.
class _WheelItem extends StatelessWidget {
  const _WheelItem({required this.text, required this.distance});

  final String text;
  final int distance;

  @override
  Widget build(BuildContext context) {
    final (size, weight, color) = switch (distance) {
      0 => (22.0, FontWeight.w700, OmniColors.textPrimary),
      1 => (18.0, FontWeight.w500, OmniColors.textSecondary),
      _ => (16.0, FontWeight.w500, OmniColors.textTertiary),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: OmniSpacing.xs),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            text,
            maxLines: 1,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontFamily: _bundledFont,
              fontSize: size,
              fontWeight: weight,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}
