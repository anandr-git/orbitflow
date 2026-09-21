import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../analytics/study_analytics.dart';
import '../models/study_session.dart';
import '../state/orbit_controller.dart';
import '../theme/design_tokens.dart';
import '../utils/date_helpers.dart';
import '../utils/responsive.dart';
import 'day_agenda_screen.dart';
import 'subject_detail_screen.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key, required this.controller});

  final OrbitController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);
    final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    final daysInMonth = monthEnd.day;
    final monthCompleted =
        StudyAnalytics.rangeCompletedMinutes(controller.sessions, monthStart, monthEnd);
    final monthPlanned =
        StudyAnalytics.rangePlannedMinutes(controller.sessions, monthStart, monthEnd);
    final monthSessions = controller.sessions.where((s) {
      if (s.archived || s.status == SessionStatus.cancelled) return false;
      return !s.plannedStart.isBefore(monthStart) && !s.plannedStart.isAfter(monthEnd);
    }).toList();
    final completedCount =
        monthSessions.where((s) => s.status == SessionStatus.completed).length;
    final missedCount = monthSessions.where((s) => s.status == SessionStatus.missed).length;
    final rate = monthPlanned <= 0
        ? (monthCompleted > 0 ? 1.0 : 0.0)
        : (monthCompleted / monthPlanned).clamp(0.0, 1.0);
    final streak = StudyAnalytics.studyStreakFromHistory(controller.sessions);
    final longest = _longestStreak(controller.sessions);
    final studiedDays = List.generate(daysInMonth, (i) {
      final day = DateTime(now.year, now.month, i + 1);
      return StudyAnalytics.dayStats(controller.sessions, day).completedMinutes > 0;
    }).where((v) => v).length;
    final subjects = StudyAnalytics.subjectStats(
      controller.sessions,
      controller.subjects,
      from: monthStart,
      to: monthEnd,
    );
    final avgSession = completedCount == 0
        ? 0
        : (monthCompleted / completedCount).round();
    final week = StudyAnalytics.weekStats(
      controller.sessions,
      now,
      mondayStart: controller.settings.weekStartsOnMonday,
    );
    final weekDone = week.fold<int>(0, (a, b) => a + b.completedMinutes);
    final weekPlannedSessions = controller.sessions.where((s) {
      final start = StudyAnalytics.weekStart(now, monday: controller.settings.weekStartsOnMonday);
      final end = start.add(const Duration(days: 7));
      return !s.archived &&
          s.status.countsAsPlanned &&
          !s.plannedStart.isBefore(start) &&
          s.plannedStart.isBefore(end);
    }).toList();
    final weekCompletedSessions =
        weekPlannedSessions.where((s) => s.status == SessionStatus.completed).length;
    final weekCompletionPct = weekPlannedSessions.isEmpty
        ? 0
        : ((weekCompletedSessions / weekPlannedSessions.length) * 100).round();

    final review = subjects
        .where((s) => s.missedCount > 0 || s.completionRate < 0.65 || _gapDays(s.lastStudied) >= 4)
        .toList();

    final diff = monthCompleted - monthPlanned;
    final interpretation = monthPlanned == 0
        ? 'No planned study time recorded this month yet.'
        : diff >= 0
            ? 'Your completed study time is at or above your planned time this month.'
            : 'Your completed study time is below your planned time this month.';

    final r = Responsive.of(context);

    return ListView(
      padding: EdgeInsets.all(r.pageHorizontalPadding),
      children: [
        ConstrainedContent(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
        Text('This month', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          '${StudyAnalytics.formatMinutes(monthCompleted)} studied · '
          '${StudyAnalytics.formatMinutes(monthPlanned)} planned · '
          '${(rate * 100).round()}% completion',
          style: theme.textTheme.bodyLarge,
        ),
        Text(
          '$completedCount sessions · $missedCount missed',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Month', style: theme.textTheme.titleMedium),
        Text(DateFormat('MMMM yyyy').format(now), style: theme.textTheme.bodySmall),
        const SizedBox(height: 8),
        _MonthCalendar(
          year: now.year,
          month: now.month,
          mondayStart: controller.settings.weekStartsOnMonday,
          sessions: controller.sessions,
          onDayTap: (day) => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DayAgendaScreen(controller: controller, day: day),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Consistency', style: theme.textTheme.titleMedium),
        Text('${StudyAnalytics.countLabel(studiedDays, 'day')} of $daysInMonth studied'),
        const SizedBox(height: 8),
        Text('Current streak · ${StudyAnalytics.countLabel(streak, 'day')}'),
        Text('Longest streak · ${StudyAnalytics.countLabel(longest, 'day')}'),
        const SizedBox(height: AppSpacing.md),
        Text('Signals', style: theme.textTheme.titleMedium),
        Text('You studied ${StudyAnalytics.formatMinutes(weekDone)} this week.'),
        Text('You completed $weekCompletionPct% of planned sessions this week.'),
        if (subjects.isNotEmpty)
          Text('${subjects.first.subject.name} has the highest completion rate.'),
        for (final s in subjects.where((x) => x.missedCount > 0).take(2))
          Text('${s.subject.name} has ${s.missedCount} missed session${s.missedCount == 1 ? '' : 's'}.'),
        Text('You studied on ${_studiedLast7(controller.sessions)} of the last 7 days.'),
        if (avgSession > 0)
          Text('Your average session duration is ${avgSession}m.'),
        const SizedBox(height: AppSpacing.lg),
        Text('Subject breakdown', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (subjects.isEmpty)
          Text(
            'Your activity will appear here after you complete sessions.\n'
            'Insights compares planned vs completed time and highlights areas to review.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          )
        else
          for (final s in subjects)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: s.subject.color.withValues(alpha: 0.2),
                child: Icon(s.subject.icon, color: s.subject.color, size: 20),
              ),
              title: Text(s.subject.name),
              subtitle: Text(
                '${StudyAnalytics.formatMinutes(s.completedMinutes)} · '
                '${(s.completionRate * 100).clamp(0, 999).round()}%',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SubjectDetailScreen(
                    controller: controller,
                    subjectId: s.subject.id,
                  ),
                ),
              ),
            ),
        const SizedBox(height: AppSpacing.lg),
        Text('Plan vs reality', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Text('Planned ${StudyAnalytics.formatMinutes(monthPlanned)}'),
        Text('Actual ${StudyAnalytics.formatMinutes(monthCompleted)}'),
        Text(
          'Difference ${diff >= 0 ? '+' : '-'}${StudyAnalytics.formatMinutes(diff.abs())}',
        ),
        const SizedBox(height: 8),
        Text(interpretation, style: theme.textTheme.bodyMedium),
        const SizedBox(height: AppSpacing.lg),
        Text('Areas to review', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (review.isEmpty)
          Text(
            'No weak areas detected from current data.',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          )
        else
          for (final s in review)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(s.subject.name),
              subtitle: Text(
                [
                  if (s.completionRate < 0.65) 'Low completion',
                  if (s.missedCount > 0) '${s.missedCount} missed',
                  if (_gapDays(s.lastStudied) >= 4) 'Gap since last study',
                ].join(' · '),
              ),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SubjectDetailScreen(
                    controller: controller,
                    subjectId: s.subject.id,
                  ),
                ),
              ),
            ),
            ],
          ),
        ),
      ],
    );
  }

  static int _longestStreak(List<StudySession> sessions) {
    final days = <String>{};
    for (final s in sessions) {
      if (s.status != SessionStatus.completed || s.archived) continue;
      final at = s.completedAt ?? s.plannedStart;
      days.add(DateHelpers.dayKey(at));
    }
    if (days.isEmpty) return 0;
    final sorted = days.map(DateTime.parse).toList()..sort();
    var best = 1;
    var cur = 1;
    for (var i = 1; i < sorted.length; i++) {
      final gap = sorted[i].difference(sorted[i - 1]).inDays;
      if (gap == 1) {
        cur++;
        best = best > cur ? best : cur;
      } else if (gap > 1) {
        cur = 1;
      }
    }
    return best;
  }

  static int _gapDays(DateTime? last) {
    if (last == null) return 999;
    return DateHelpers.startOfDay(DateTime.now()).difference(DateHelpers.startOfDay(last)).inDays;
  }

  static int _studiedLast7(List<StudySession> sessions) {
    final now = DateHelpers.startOfDay(DateTime.now());
    var count = 0;
    for (var i = 0; i < 7; i++) {
      final day = now.subtract(Duration(days: i));
      if (StudyAnalytics.dayStats(sessions, day).completedMinutes > 0) count++;
    }
    return count;
  }
}

class _MonthCalendar extends StatelessWidget {
  const _MonthCalendar({
    required this.year,
    required this.month,
    required this.mondayStart,
    required this.sessions,
    required this.onDayTap,
  });

  final int year;
  final int month;
  final bool mondayStart;
  final List<StudySession> sessions;
  final ValueChanged<DateTime> onDayTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final first = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final weekday = first.weekday; // Mon=1
    final leading = mondayStart ? weekday - 1 : weekday % 7;
    final labels = mondayStart
        ? const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
        : const ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final cells = <Widget?>[
      ...List.filled(leading, null),
      for (var dayNum = 1; dayNum <= daysInMonth; dayNum++)
        _DayCell(
          day: DateTime(year, month, dayNum),
          sessions: sessions,
          onDayTap: onDayTap,
        ),
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }

    return Column(
      children: [
        Row(
          children: [
            for (final l in labels)
              Expanded(
                child: Text(
                  l,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelSmall,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        for (var row = 0; row < cells.length ~/ 7; row++)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: SizedBox(
              height: 54,
              child: Row(
                children: [
                  for (var col = 0; col < 7; col++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: cells[row * 7 + col] ?? const SizedBox.shrink(),
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.sessions,
    required this.onDayTap,
  });

  final DateTime day;
  final List<StudySession> sessions;
  final ValueChanged<DateTime> onDayTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stats = StudyAnalytics.dayStats(sessions, day);
    final intensity = stats.completedMinutes;
    final isToday = DateHelpers.isSameDay(day, DateTime.now());
    return InkWell(
      onTap: () => onDayTap(day),
      borderRadius: AppRadius.xsAll,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: AppRadius.xsAll,
          color: _heat(theme, intensity),
          border: isToday
              ? Border.all(color: theme.colorScheme.primary, width: 1.5)
              : stats.missedCount > 0
                  ? Border.all(color: theme.colorScheme.error.withValues(alpha: 0.5))
                  : null,
        ),
        padding: const EdgeInsets.all(4),
        child: Column(
          children: [
            Text('${day.day}', style: theme.textTheme.labelMedium),
            if (intensity > 0)
              Text(
                StudyAnalytics.formatMinutes(intensity),
                style: theme.textTheme.labelSmall?.copyWith(fontSize: 9),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              )
            else if (stats.plannedMinutes > 0)
              Text(
                'plan',
                style: theme.textTheme.labelSmall?.copyWith(fontSize: 9),
              ),
          ],
        ),
      ),
    );
  }

  Color _heat(ThemeData theme, int minutes) {
    if (minutes <= 0) return theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.55);
    if (minutes < 30) return theme.colorScheme.primary.withValues(alpha: 0.2);
    if (minutes < 60) return theme.colorScheme.primary.withValues(alpha: 0.35);
    if (minutes < 120) return theme.colorScheme.primary.withValues(alpha: 0.55);
    return theme.colorScheme.primary.withValues(alpha: 0.75);
  }
}
