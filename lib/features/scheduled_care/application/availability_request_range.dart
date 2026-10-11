import 'package:timezone/timezone.dart' as tz;

const scheduledCareTimezone = 'Africa/Tunis';

/// A single displayed-month query accepted by the backend availability API.
///
/// Month boundaries are computed in the scheduling timezone and then sent as
/// instants. The explicit clamp protects the backend's inclusive 31-day limit
/// even if a future scheduling timezone introduces an offset transition.
class AvailabilityRequestRange {
  const AvailabilityRequestRange({required this.from, required this.to});

  static const maximumWindow = Duration(days: 31);

  final DateTime from;
  final DateTime to;

  factory AvailabilityRequestRange.forMonth({
    required DateTime month,
    required DateTime now,
    String timezone = scheduledCareTimezone,
  }) {
    final location = tz.getLocation(timezone);
    final nowInZone = tz.TZDateTime.from(now.toUtc(), location);
    final monthStart = tz.TZDateTime(location, month.year, month.month);
    final nextMonthStart = tz.TZDateTime(
      location,
      month.month == 12 ? month.year + 1 : month.year,
      month.month == 12 ? 1 : month.month + 1,
    );
    final isCurrentMonth =
        monthStart.year == nowInZone.year &&
        monthStart.month == nowInZone.month;
    final start = (isCurrentMonth && nowInZone.isAfter(monthStart))
        ? nowInZone.toUtc()
        : monthStart.toUtc();
    final monthEnd = nextMonthStart.toUtc();
    final maximumEnd = start.add(maximumWindow);

    return AvailabilityRequestRange(
      from: start,
      to: monthEnd.isAfter(maximumEnd) ? maximumEnd : monthEnd,
    );
  }
}
