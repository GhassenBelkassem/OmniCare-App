import 'package:flutter_test/flutter_test.dart';
import 'package:omnicare_mobile/features/scheduled_care/application/availability_request_range.dart';
import 'package:timezone/data/latest.dart' as tz;

void main() {
  setUpAll(tz.initializeTimeZones);

  test('current October range starts now and ends at next Tunis month', () {
    final range = AvailabilityRequestRange.forMonth(
      month: DateTime(2026, 10),
      now: DateTime.parse('2026-10-08T22:26:42Z'),
    );

    expect(range.from, DateTime.parse('2026-10-08T22:26:42Z'));
    expect(range.to, DateTime.parse('2026-10-31T23:00:00Z'));
    expect(
      range.to.difference(range.from),
      lessThanOrEqualTo(AvailabilityRequestRange.maximumWindow),
    );
  });

  test('next month navigation loads that month only', () {
    final range = AvailabilityRequestRange.forMonth(
      month: DateTime(2026, 11),
      now: DateTime.parse('2026-10-08T22:26:42Z'),
    );

    expect(range.from, DateTime.parse('2026-10-31T23:00:00Z'));
    expect(range.to, DateTime.parse('2026-11-30T23:00:00Z'));
    expect(range.to.difference(range.from), const Duration(days: 30));
  });

  test('a 31-day displayed month remains within the backend maximum', () {
    final range = AvailabilityRequestRange.forMonth(
      month: DateTime(2026, 12),
      now: DateTime.parse('2026-10-08T22:26:42Z'),
    );

    expect(range.from, DateTime.parse('2026-11-30T23:00:00Z'));
    expect(range.to, DateTime.parse('2026-12-31T23:00:00Z'));
    expect(range.to.difference(range.from), const Duration(days: 31));
  });
}
