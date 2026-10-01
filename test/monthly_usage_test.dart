import 'package:flutter_test/flutter_test.dart';
import 'package:time_tracker/database/database.dart';
import 'package:time_tracker/utils/monthly_usage.dart';

TimeEntry _entry(DateTime start, DateTime? end) => TimeEntry(
      id: 1,
      projectId: 1,
      description: 'Work',
      startTime: start,
      endTime: end,
      category: 'Dev',
      isBillable: true,
      isBilled: false,
      isLogged: false,
    );

void main() {
  final now = DateTime(2026, 10, 15, 12);
  final month = monthRange(now);

  test('monthRange covers the calendar month, including December', () {
    expect(month.start, DateTime(2026, 10, 1));
    expect(month.end, DateTime(2026, 11, 1));
    final december = monthRange(DateTime(2026, 12, 31));
    expect(december.end, DateTime(2027, 1, 1));
  });

  group('hoursInRange', () {
    test('sums completed entries inside the month', () {
      final entries = [
        _entry(DateTime(2026, 10, 2, 9), DateTime(2026, 10, 2, 11)),
        _entry(DateTime(2026, 10, 3, 9), DateTime(2026, 10, 3, 9, 30)),
      ];
      expect(hoursInRange(entries, month.start, month.end, now), 2.5);
    });

    test('clips entries that cross the month boundary', () {
      final entries = [
        _entry(DateTime(2026, 9, 30, 22), DateTime(2026, 10, 1, 1)),
        _entry(DateTime(2026, 10, 31, 23), DateTime(2026, 11, 1, 2)),
      ];
      expect(hoursInRange(entries, month.start, month.end, now), 2);
    });

    test('ignores entries outside the month', () {
      final entries = [
        _entry(DateTime(2026, 9, 1, 9), DateTime(2026, 9, 1, 17)),
      ];
      expect(hoursInRange(entries, month.start, month.end, now), 0);
    });

    test('counts a running entry up to now', () {
      final entries = [_entry(DateTime(2026, 10, 15, 10), null)];
      expect(hoursInRange(entries, month.start, month.end, now), 2);
    });
  });

  group('limitStatus', () {
    test('no limit when unset or zero', () {
      expect(limitStatus(5, null), LimitStatus.noLimit);
      expect(limitStatus(5, 0), LimitStatus.noLimit);
    });

    test('classifies usage against the limit', () {
      expect(limitStatus(7.9, 10), LimitStatus.withinLimit);
      expect(limitStatus(8, 10), LimitStatus.nearingLimit);
      expect(limitStatus(10, 10), LimitStatus.limitReached);
      expect(limitStatus(12, 10), LimitStatus.limitReached);
    });
  });
}
