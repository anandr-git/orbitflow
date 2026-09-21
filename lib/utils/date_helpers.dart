import 'package:intl/intl.dart';

abstract final class DateHelpers {
  static DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime endOfDay(DateTime d) => DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

  static bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String greeting(DateTime now) {
    final hour = now.hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  static String formatDue(DateTime date, {DateTime? now}) {
    now ??= DateTime.now();
    final today = startOfDay(now);
    final taskDay = startOfDay(date);
    final diffDays = taskDay.difference(today).inDays;
    final timeStr = DateFormat('h:mm a').format(date);

    if (diffDays == 0) return 'Today · $timeStr';
    if (diffDays == 1) return 'Tomorrow · $timeStr';
    if (diffDays == -1) return 'Yesterday · $timeStr';
    if (diffDays < -1) return '${-diffDays}d overdue · $timeStr';
    if (diffDays <= 7) return '${DateFormat('EEE').format(date)} · $timeStr';
    return DateFormat('MMM d · h:mm a').format(date);
  }

  static String formatFull(DateTime date) => DateFormat('EEEE, MMM d, y · h:mm a').format(date);

  static String formatShortDate(DateTime date) => DateFormat('EEE, MMM d').format(date);
}
