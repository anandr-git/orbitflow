import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../analytics/study_analytics.dart';
import '../models/study_session.dart';
import '../state/orbit_controller.dart';
import '../theme/design_tokens.dart';
import '../utils/date_helpers.dart';
import '../utils/responsive.dart';
import 'day_agenda_screen.dart';
import 'focus_mode_screen.dart';
import 'session_editor_screen.dart';

class WeekScreen extends StatelessWidget {
  const WeekScreen({super.key, required this.controller});

  final OrbitController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = Responsive.of(context);
    final now = DateTime.now();
    final week = StudyAnalytics.weekStats(
      controller.sessions,
      now,
      mondayStart: controller.settings.weekStartsOnMonday,
    );
    final planned = week.fold<int>(0, (a, b) => a + b.plannedMinutes);
    final completed = week.fold<int>(0, (a, b) => a + b.completedMinutes);
    final goal = controller.settings.weeklyStudyGoalMinutes;
    final remaining = (goal - completed).clamp(0, goal);
    final start = StudyAnalytics.weekStart(now, monday: controller.settings.weekStartsOnMonday);

    return ListView(
      padding: EdgeInsets.all(r.pageHorizontalPadding),
      children: [
        ConstrainedContent(
          maxWidth: r.useTwoPane ? double.infinity : AppContentWidth.readable,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
        Text('This week', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        _WeekSummary(
          completed: completed,
          planned: planned,
          goal: goal,
          remaining: remaining,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Week planner', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        if (r.useTwoPane)
          _TabletWeekGrid(controller: controller, weekStart: start)
        else
          for (final day in week)
            _ExpandableDay(
              controller: controller,
              stats: day,
              onOpenAgenda: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DayAgendaScreen(controller: controller, day: day.day),
                ),
              ),
            ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WeekSummary extends StatelessWidget {
  const _WeekSummary({
    required this.completed,
    required this.planned,
    required this.goal,
    required this.remaining,
  });

  final int completed, planned, goal, remaining;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${StudyAnalytics.formatMinutes(completed)} / ${StudyAnalytics.formatMinutes(goal)}',
            style: theme.textTheme.titleLarge,
          ),
          Text(
            'Planned ${StudyAnalytics.formatMinutes(planned)} · Remaining ${StudyAnalytics.formatMinutes(remaining)}',
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: goal <= 0 ? 0 : (completed / goal).clamp(0.0, 1.0),
            minHeight: 8,
          ),
          const SizedBox(height: 8),
          Text(
            remaining == 0
                ? 'Weekly target reached.'
                : 'You are ${StudyAnalytics.formatMinutes(remaining)} away from this week\'s target.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _ExpandableDay extends StatelessWidget {
  const _ExpandableDay({
    required this.controller,
    required this.stats,
    required this.onOpenAgenda,
  });

  final OrbitController controller;
  final DayStudyStats stats;
  final VoidCallback onOpenAgenda;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sessions = controller.sessions
        .where((s) => !s.archived && DateHelpers.isSameDay(s.plannedStart, stats.day))
        .toList()
      ..sort((a, b) => a.plannedStart.compareTo(b.plannedStart));
    final rate = stats.plannedMinutes == 0
        ? (stats.completedMinutes > 0 ? 1.0 : 0.0)
        : (stats.completedMinutes / stats.plannedMinutes).clamp(0.0, 1.0);
    final isToday = DateHelpers.isSameDay(stats.day, DateTime.now());

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isToday ? theme.colorScheme.primaryContainer.withValues(alpha: 0.22) : null,
      child: ExpansionTile(
        title: Text(DateFormat('EEE d').format(stats.day)),
        subtitle: Text(
          '${StudyAnalytics.countLabel(sessions.length, 'session')} · ${StudyAnalytics.formatMinutes(stats.plannedMinutes)} planned · ${StudyAnalytics.formatMinutes(stats.completedMinutes)} done',
        ),
        trailing: Text('${(rate * 100).round()}%'),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: LinearProgressIndicator(value: rate, minHeight: 6),
          ),
          if (isToday)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Today', style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)),
              ),
            ),
          if (sessions.isEmpty)
            ListTile(
              dense: true,
              title: Text(stats.day.isAfter(DateTime.now()) ? 'No sessions scheduled' : 'No sessions'),
            )
          else
            for (final s in sessions)
              ListTile(
                dense: true,
                leading: Text(DateFormat('HH:mm').format(s.plannedStart)),
                title: Text(
                  '${controller.subjectById(s.subjectId)?.name ?? 'Subject'} · ${s.title}',
                ),
                subtitle: Text(
                  '${StudyAnalytics.formatMinutes(s.plannedMinutes)} · ${s.status.label}',
                ),
                onTap: () async {
                  if (s.status.isOpen) {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FocusModeScreen(controller: controller, session: s),
                      ),
                    );
                  } else {
                    final edited = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SessionEditorScreen(controller: controller, existing: s),
                      ),
                    );
                    if (edited != null) await controller.upsertSession(edited);
                  }
                },
              ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: onOpenAgenda, child: const Text('Open day agenda')),
          ),
        ],
      ),
    );
  }
}

class _TabletWeekGrid extends StatelessWidget {
  const _TabletWeekGrid({required this.controller, required this.weekStart});

  final OrbitController controller;
  final DateTime weekStart;

  static const slots = [
    (label: 'Morning', start: 6, end: 12),
    (label: 'Afternoon', start: 12, end: 17),
    (label: 'Evening', start: 17, end: 21),
    (label: 'Night', start: 21, end: 24),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final gridWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth.clamp(720.0, 1400.0)
            : 980.0;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: gridWidth < 900 ? 980 : gridWidth,
            child: Column(
              children: [
                Row(
                  children: [
                    const SizedBox(width: 90),
                    for (var i = 0; i < 7; i++)
                      Expanded(
                        child: InkWell(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => DayAgendaScreen(
                                controller: controller,
                                day: weekStart.add(Duration(days: i)),
                              ),
                            ),
                          ),
                          child: Text(
                            DateFormat('EEE d').format(weekStart.add(Duration(days: i))),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelLarge,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                for (final slot in slots)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 90,
                          child: Text(slot.label, style: theme.textTheme.labelMedium),
                        ),
                        for (var i = 0; i < 7; i++)
                          Expanded(
                            child: _SlotCell(
                              controller: controller,
                              day: weekStart.add(Duration(days: i)),
                              startHour: slot.start,
                              endHour: slot.end,
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SlotCell extends StatelessWidget {
  const _SlotCell({
    required this.controller,
    required this.day,
    required this.startHour,
    required this.endHour,
  });

  final OrbitController controller;
  final DateTime day;
  final int startHour;
  final int endHour;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sessions = controller.sessions.where((s) {
      if (s.archived) return false;
      if (!DateHelpers.isSameDay(s.plannedStart, day)) return false;
      final h = s.plannedStart.hour;
      return h >= startHour && h < endHour;
    }).toList();

    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        borderRadius: AppRadius.smAll,
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45)),
      ),
      child: Column(
        children: [
          for (final s in sessions)
            InkWell(
              onTap: () async {
                final edited = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SessionEditorScreen(controller: controller, existing: s),
                  ),
                );
                if (edited != null) await controller.upsertSession(edited);
              },
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: (controller.subjectById(s.subjectId)?.color ?? theme.colorScheme.primary)
                      .withValues(alpha: 0.18),
                  borderRadius: AppRadius.xsAll,
                ),
                child: Text(
                  '${controller.subjectById(s.subjectId)?.name.split(' ').first ?? 'Study'}\n'
                  '${StudyAnalytics.formatMinutes(s.plannedMinutes)}',
                  style: theme.textTheme.labelSmall,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
