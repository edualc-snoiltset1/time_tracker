// lib/utils/monthly_usage.dart
import 'package:time_tracker/database/database.dart';

/// Share of the monthly limit at which a project counts as nearing it.
const double nearingLimitThreshold = 0.8;

enum LimitStatus { noLimit, withinLimit, nearingLimit, limitReached }

/// The calendar month containing [now]: start inclusive, end exclusive.
({DateTime start, DateTime end}) monthRange(DateTime now) {
  return (
    start: DateTime(now.year, now.month, 1),
    end: DateTime(now.year, now.month + 1, 1),
  );
}

/// Hours of [entries] that fall inside [start]..[end]. Entries crossing a
/// boundary are clipped to it, and a running entry (no end time) counts up
/// to [now].
double hoursInRange(
  Iterable<TimeEntry> entries,
  DateTime start,
  DateTime end,
  DateTime now,
) {
  var minutes = 0;
  for (final entry in entries) {
    final entryEnd = entry.endTime ?? now;
    final from = entry.startTime.isAfter(start) ? entry.startTime : start;
    final to = entryEnd.isBefore(end) ? entryEnd : end;
    if (to.isAfter(from)) {
      minutes += to.difference(from).inMinutes;
    }
  }
  return minutes / 60.0;
}

LimitStatus limitStatus(double usedHours, int? limitHours) {
  if (limitHours == null || limitHours <= 0) return LimitStatus.noLimit;
  final ratio = usedHours / limitHours;
  if (ratio >= 1) return LimitStatus.limitReached;
  if (ratio >= nearingLimitThreshold) return LimitStatus.nearingLimit;
  return LimitStatus.withinLimit;
}
