import '../models/study_session.dart';
import '../models/subject.dart';
import '../utils/date_helpers.dart';

class DayStudyStats {
  const DayStudyStats({
    required this.day,
    required this.plannedMinutes,
    required this.completedMinutes,
    required this.sessionCount,
    required this.missedCount,
    required this.completedCount,
  });

  final DateTime day;
  final int plannedMinutes;
  final int completedMinutes;
  final int sessionCount;
  final int missedCount;
  final int completedCount;

  double get completionRate {
    if (plannedMinutes <= 0) return completedMinutes > 0 ? 1 : 0;
    return (completedMinutes / plannedMinutes).clamp(0.0, 2.0);
  }
}

class SubjectStudyStats {
  const SubjectStudyStats({
    required this.subject,
    required this.plannedMinutes,
    required this.completedMinutes,
    required this.sessionCount,
    required this.missedCount,
    required this.lastStudied,
  });

  final Subject subject;
  final int plannedMinutes;
  final int completedMinutes;
  final int sessionCount;
  final int missedCount;
  final DateTime? lastStudied;

  double get completionRate {
    if (plannedMinutes <= 0) return completedMinutes > 0 ? 1 : 0;
    return (completedMinutes / plannedMinutes).clamp(0.0, 2.0);
  }
}

abstract final class StudyAnalytics {
  static List<StudySession> refreshMissed(List<StudySession> sessions, {DateTime? now}) {
    now ??= DateTime.now();
    return sessions.map((s) {
      if (s.isMissedCandidate(now: now)) {
        return s.copyWith(status: SessionStatus.missed);
      }
      return s;
    }).toList();
  }

  static DayStudyStats dayStats(List<StudySession> sessions, DateTime day) {
    final start = DateHelpers.startOfDay(day);
    final relevant = sessions.where((s) {
      if (s.archived || s.status == SessionStatus.cancelled) return false;
      return DateHelpers.isSameDay(s.plannedStart, start);
    }).toList();

    var planned = 0;
    var completed = 0;
    var missed = 0;
    var done = 0;
    for (final s in relevant) {
      if (s.status.countsAsPlanned) planned += s.plannedMinutes;
      if (s.status == SessionStatus.completed) {
        completed += s.effectiveActualMinutes;
        done++;
      }
      if (s.status == SessionStatus.missed) missed++;
    }
    return DayStudyStats(
      day: start,
      plannedMinutes: planned,
      completedMinutes: completed,
      sessionCount: relevant.length,
      missedCount: missed,
      completedCount: done,
    );
  }

  static int rangeCompletedMinutes(List<StudySession> sessions, DateTime from, DateTime to) {
    var total = 0;
    for (final s in sessions) {
      if (s.status != SessionStatus.completed || s.archived) continue;
      final at = s.completedAt ?? s.plannedStart;
      if (!at.isBefore(from) && !at.isAfter(to)) {
        total += s.effectiveActualMinutes;
      }
    }
    return total;
  }

  static int rangePlannedMinutes(List<StudySession> sessions, DateTime from, DateTime to) {
    var total = 0;
    for (final s in sessions) {
      if (s.archived || s.status == SessionStatus.cancelled) continue;
      if (!s.status.countsAsPlanned) continue;
      if (!s.plannedStart.isBefore(from) && !s.plannedStart.isAfter(to)) {
        total += s.plannedMinutes;
      }
    }
    return total;
  }

  static DateTime weekStart(DateTime day, {bool monday = true}) {
    final d = DateHelpers.startOfDay(day);
    final weekday = d.weekday; // Mon=1 ... Sun=7
    final offset = monday ? weekday - 1 : weekday % 7;
    return d.subtract(Duration(days: offset));
  }

  static List<DayStudyStats> weekStats(
    List<StudySession> sessions,
    DateTime anyDayInWeek, {
    bool mondayStart = true,
  }) {
    final start = weekStart(anyDayInWeek, monday: mondayStart);
    return List.generate(7, (i) => dayStats(sessions, start.add(Duration(days: i))));
  }

  static List<SubjectStudyStats> subjectStats(
    List<StudySession> sessions,
    List<Subject> subjects, {
    DateTime? from,
    DateTime? to,
  }) {
    return subjects.where((s) => !s.archived).map((subject) {
      final list = sessions.where((s) {
        if (s.subjectId != subject.id || s.archived) return false;
        if (from != null && s.plannedStart.isBefore(from)) return false;
        if (to != null && s.plannedStart.isAfter(to)) return false;
        return true;
      }).toList();

      var planned = 0;
      var completed = 0;
      var missed = 0;
      DateTime? last;
      for (final s in list) {
        if (s.status.countsAsPlanned) planned += s.plannedMinutes;
        if (s.status == SessionStatus.completed) {
          completed += s.effectiveActualMinutes;
          final at = s.completedAt ?? s.plannedStart;
          if (last == null || at.isAfter(last)) last = at;
        }
        if (s.status == SessionStatus.missed) missed++;
      }
      return SubjectStudyStats(
        subject: subject,
        plannedMinutes: planned,
        completedMinutes: completed,
        sessionCount: list.length,
        missedCount: missed,
        lastStudied: last,
      );
    }).toList()
      ..sort((a, b) => b.completedMinutes.compareTo(a.completedMinutes));
  }

  static int studyStreakFromHistory(List<StudySession> sessions, {DateTime? now}) {
    now ??= DateTime.now();
    final days = <String>{};
    for (final s in sessions) {
      if (s.status != SessionStatus.completed || s.archived) continue;
      final at = s.completedAt ?? s.plannedStart;
      days.add(DateHelpers.dayKey(at));
    }
    var streak = 0;
    var cursor = DateHelpers.startOfDay(now);
    // Allow today or yesterday as streak anchor.
    if (!days.contains(DateHelpers.dayKey(cursor))) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    while (days.contains(DateHelpers.dayKey(cursor))) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  static String formatMinutes(int minutes) {
    final h = minutes ~/ 60;
    final m = minutes % 60;
    if (h <= 0) return '${m}m';
    if (m == 0) return '${h}h';
    return '${h}h ${m.toString().padLeft(2, '0')}m';
  }

  static String countLabel(int count, String singular, [String? plural]) {
    final p = plural ?? '${singular}s';
    return count == 1 ? '1 $singular' : '$count $p';
  }

  static StudySession? nextUp(List<StudySession> sessions, {DateTime? now}) {
    now ??= DateTime.now();
    final open = sessions
        .where((s) => !s.archived && s.status.isOpen && s.plannedEnd.isAfter(now!))
        .toList()
      ..sort((a, b) => a.plannedStart.compareTo(b.plannedStart));
    return open.isEmpty ? null : open.first;
  }

  static List<StudySession> todaySessions(List<StudySession> sessions, {DateTime? now}) {
    now ??= DateTime.now();
    return sessions
        .where((s) => !s.archived && s.status != SessionStatus.cancelled && s.isDueToday)
        .toList()
      ..sort((a, b) => a.plannedStart.compareTo(b.plannedStart));
  }
}
