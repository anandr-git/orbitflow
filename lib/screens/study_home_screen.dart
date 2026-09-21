import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../analytics/study_analytics.dart';
import '../models/study_session.dart';
import '../models/subject.dart';
import '../state/orbit_controller.dart';
import '../theme/app_theme.dart';
import '../theme/design_tokens.dart';
import '../utils/date_helpers.dart';
import '../utils/responsive.dart';
import 'focus_mode_screen.dart';
import 'session_editor_screen.dart';
import 'subject_detail_screen.dart';
import 'subjects_screen.dart';

class StudyHomeScreen extends StatelessWidget {
  const StudyHomeScreen({super.key, required this.controller});

  final OrbitController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = Responsive.of(context);
    final now = DateTime.now();
    final today = StudyAnalytics.dayStats(controller.sessions, now);
    final goal = controller.settings.dailyStudyGoalMinutes;
    final remainingGoal = (goal - today.completedMinutes).clamp(0, goal);
    final pct = goal <= 0 ? 0.0 : (today.completedMinutes / goal).clamp(0.0, 1.0);
    final todays = StudyAnalytics.todaySessions(controller.sessions);
    final active = todays.where((s) => s.status == SessionStatus.inProgress).toList();
    final next = active.isNotEmpty ? active.first : StudyAnalytics.nextUp(todays);
    final missed = controller.sessions
        .where((s) => s.status == SessionStatus.missed && !s.archived)
        .toList();
    final week = StudyAnalytics.weekStats(
      controller.sessions,
      now,
      mondayStart: controller.settings.weekStartsOnMonday,
    );
    final weekDone = week.fold<int>(0, (a, b) => a + b.completedMinutes);

    return RefreshIndicator(
      onRefresh: controller.refreshMissedStatuses,
      child: ListView(
        padding: EdgeInsets.fromLTRB(r.pageHorizontalPadding, AppSpacing.sm, r.pageHorizontalPadding, 120),
        children: [
          ConstrainedContent(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(DateHelpers.greeting(now),
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    Text(AppTheme.appName, style: theme.textTheme.headlineSmall),
                    Text(DateFormat('EEEE, MMMM d').format(now),
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Subjects',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => SubjectsScreen(controller: controller)),
                ),
                icon: const Icon(Icons.menu_book_rounded),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (controller.subjects.where((s) => !s.archived).isEmpty) ...[
            Card(
              margin: EdgeInsets.zero,
              child: ListTile(
                leading: Icon(Icons.lightbulb_outline, color: theme.colorScheme.primary),
                title: const Text('Start with a subject'),
                subtitle: const Text(
                  'A subject organizes topics (e.g. Networks → TCP/IP). Then plan a session and press Start.',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => SubjectsScreen(controller: controller)),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          _UpNextPanel(
            session: next,
            controller: controller,
            hadActivityToday: todays.any((s) => s.status == SessionStatus.completed),
            onStart: next == null ? null : () => _openFocus(context, next),
            onPlan: () => _quickPlan(context),
            onOpenFocus: next == null ? null : () => _openFocus(context, next),
          ),
          const SizedBox(height: AppSpacing.md),
          _TodayCommandCard(
            goal: goal,
            planned: today.plannedMinutes,
            completed: today.completedMinutes,
            goalRemaining: remainingGoal,
            plannedRemaining: (today.plannedMinutes - today.completedMinutes).clamp(0, today.plannedMinutes),
            percent: pct,
            weekDone: weekDone,
            weekGoal: controller.settings.weeklyStudyGoalMinutes,
            streak: controller.settings.studyStreak,
            reduceMotion: controller.settings.reduceMotion,
          ),
          if (missed.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _MissedCard(
              sessions: missed,
              controller: controller,
              onChanged: () {},
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Text("Today's plan", style: theme.textTheme.titleMedium),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _openEditor(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Plan'),
              ),
            ],
          ),
          if (todays.isEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'No sessions planned yet.\nA session is a timed block for one topic or task.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            FilledButton.tonalIcon(
              onPressed: () => _openEditor(context),
              icon: const Icon(Icons.edit_calendar_outlined),
              label: const Text("Plan today's session"),
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Quick plan', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in [25, 50, 90])
                  ActionChip(
                    label: Text('+$m min'),
                    onPressed: () => _quickPlan(context, minutes: m),
                  ),
                ActionChip(
                  label: const Text('+ Custom'),
                  onPressed: () => _openEditor(context),
                ),
              ],
            ),
          ] else
            for (final session in todays)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _TodaySessionCard(
                  session: session,
                  subject: controller.subjectById(session.subjectId),
                  topic: controller.topicById(session.subjectId, session.topicId),
                  onTap: () => _openActions(context, session),
                  onStart: () => _openFocus(context, session),
                ),
              ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openEditor(BuildContext context, {StudySession? existing, int? minutes}) async {
    if (controller.subjects.where((s) => !s.archived).isEmpty) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => SubjectsScreen(controller: controller)),
      );
      return;
    }
    final session = await Navigator.push<StudySession>(
      context,
      MaterialPageRoute(
        builder: (_) => SessionEditorScreen(
          controller: controller,
          existing: existing,
          initialMinutes: minutes,
        ),
      ),
    );
    if (session != null) await controller.upsertSession(session);
  }

  Future<void> _quickPlan(BuildContext context, {int minutes = 50}) =>
      _openEditor(context, minutes: minutes);

  Future<void> _openFocus(BuildContext context, StudySession session) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FocusModeScreen(controller: controller, session: session),
      ),
    );
  }

  Future<void> _openActions(BuildContext context, StudySession session) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.play_circle_outline),
              title: const Text('Start / open focus'),
              onTap: () {
                Navigator.pop(ctx);
                _openFocus(context, session);
              },
            ),
            ListTile(
              leading: const Icon(Icons.check_circle_outline),
              title: const Text('Mark complete'),
              onTap: () async {
                Navigator.pop(ctx);
                await controller.completeSession(session.id);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(ctx);
                _openEditor(context, existing: session);
              },
            ),
            ListTile(
              leading: const Icon(Icons.menu_book_outlined),
              title: const Text('Open subject'),
              onTap: () {
                Navigator.pop(ctx);
                final subject = controller.subjectById(session.subjectId);
                if (subject == null) return;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SubjectDetailScreen(
                      controller: controller,
                      subjectId: subject.id,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayCommandCard extends StatelessWidget {
  const _TodayCommandCard({
    required this.goal,
    required this.planned,
    required this.completed,
    required this.goalRemaining,
    required this.plannedRemaining,
    required this.percent,
    required this.weekDone,
    required this.weekGoal,
    required this.streak,
    required this.reduceMotion,
  });

  final int goal, planned, completed, goalRemaining, plannedRemaining, weekDone, weekGoal, streak;
  final double percent;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Today's progress", style: theme.textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _kv(theme, 'Goal', StudyAnalytics.formatMinutes(goal)),
              _kv(theme, 'Planned', StudyAnalytics.formatMinutes(planned)),
              _kv(theme, 'Done', StudyAnalytics.formatMinutes(completed), theme.colorScheme.tertiary),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Goal remaining ${StudyAnalytics.formatMinutes(goalRemaining)} · '
            'Plan remaining ${StudyAnalytics.formatMinutes(plannedRemaining)}',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('${(percent * 100).round()}% of goal', style: theme.textTheme.labelLarge),
              const Spacer(),
              if (streak > 0)
                Text(
                  '$streak-day streak',
                  style: theme.textTheme.labelMedium,
                ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: AppRadius.xsAll,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: percent),
              duration: reduceMotion ? Duration.zero : AppMotion.normal,
              builder: (context, v, child) => LinearProgressIndicator(value: v, minHeight: 8),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This week ${StudyAnalytics.formatMinutes(weekDone)} / ${StudyAnalytics.formatMinutes(weekGoal)}',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _kv(ThemeData theme, String k, String v, [Color? c]) {
    return Expanded(
      child: Column(
        children: [
          Text(v, style: TextStyle(fontWeight: FontWeight.w700, color: c, fontSize: 16)),
          Text(k, style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _UpNextPanel extends StatelessWidget {
  const _UpNextPanel({
    required this.session,
    required this.controller,
    required this.hadActivityToday,
    required this.onStart,
    required this.onPlan,
    required this.onOpenFocus,
  });

  final StudySession? session;
  final OrbitController controller;
  final bool hadActivityToday;
  final VoidCallback? onStart;
  final VoidCallback onPlan;
  final VoidCallback? onOpenFocus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (session == null) {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          borderRadius: AppRadius.mdAll,
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.28),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hadActivityToday ? "You're done for today" : 'Nothing planned yet',
                    style: theme.textTheme.titleMedium,
                  ),
                  Text(
                    hadActivityToday
                        ? 'Plan another session to keep momentum.'
                        : 'Plan a session to see your next focus block here.',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            FilledButton(onPressed: onPlan, child: const Text('Plan')),
          ],
        ),
      );
    }

    final subject = controller.subjectById(session!.subjectId);
    final topic = controller.topicById(session!.subjectId, session!.topicId);
    final active = session!.status == SessionStatus.inProgress;
    final delta = session!.plannedStart.difference(DateTime.now());
    final timing = active
        ? 'In progress'
        : delta.isNegative
            ? 'Ready now'
            : delta.inMinutes < 60
                ? 'Starts in ${delta.inMinutes} min'
                : 'Starts at ${DateFormat('h:mm a').format(session!.plannedStart)}';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: AppRadius.mdAll,
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(active ? 'Current session' : 'Up next', style: theme.textTheme.labelLarge),
                const SizedBox(height: 4),
                Text(subject?.name ?? 'Subject', style: theme.textTheme.titleMedium),
                Text(
                  topic == null ? session!.title : '${topic.name} · ${session!.title}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$timing · ${StudyAnalytics.formatMinutes(session!.plannedMinutes)}',
                  style: theme.textTheme.labelMedium,
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: active ? onOpenFocus : onStart,
            icon: Icon(active ? Icons.timelapse : Icons.play_arrow_rounded),
            label: Text(active ? 'Focus' : 'Start'),
          ),
        ],
      ),
    );
  }
}

class _MissedCard extends StatelessWidget {
  const _MissedCard({
    required this.sessions,
    required this.controller,
    required this.onChanged,
  });

  final List<StudySession> sessions;
  final OrbitController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final first = sessions.first;
    final subject = controller.subjectById(first.subjectId);
    return Material(
      color: theme.colorScheme.errorContainer.withValues(alpha: 0.45),
      borderRadius: AppRadius.mdAll,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Missed session', style: theme.textTheme.titleSmall),
            Text('${subject?.name ?? 'Subject'} · ${first.title}'),
            Text(
              'Planned ${DateFormat('h:mm a').format(first.plannedStart)} · ${StudyAnalytics.formatMinutes(first.plannedMinutes)}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: () => controller.completeSession(first.id),
                  child: const Text('Complete now'),
                ),
                OutlinedButton(
                  onPressed: () => _reschedule(context, first),
                  child: const Text('Reschedule'),
                ),
                TextButton(
                  onPressed: () => controller.skipSession(first.id),
                  child: const Text('Skip'),
                ),
                TextButton(
                  onPressed: onChanged,
                  child: const Text('Keep missed'),
                ),
              ],
            ),
            if (sessions.length > 1)
              Text('${sessions.length - 1} more missed', style: theme.textTheme.labelSmall),
          ],
        ),
      ),
    );
  }

  Future<void> _reschedule(BuildContext context, StudySession session) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: const Text('Tomorrow'), onTap: () => Navigator.pop(ctx, 't')),
            ListTile(title: const Text('This weekend'), onTap: () => Navigator.pop(ctx, 'w')),
            ListTile(
              title: const Text('Choose date'),
              onTap: () => Navigator.pop(ctx, 'd'),
            ),
            ListTile(title: const Text('Keep missed'), onTap: () => Navigator.pop(ctx, 'k')),
          ],
        ),
      ),
    );
    if (choice == null || choice == 'k' || !context.mounted) return;
    if (choice == 't') {
      await controller.rescheduleSession(
        session.id,
        session.plannedStart.add(const Duration(days: 1)),
      );
    } else if (choice == 'd') {
      final date = await showDatePicker(
        context: context,
        initialDate: DateTime.now().add(const Duration(days: 1)),
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 365)),
      );
      if (date == null || !context.mounted) return;
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(session.plannedStart),
      );
      if (time == null) return;
      await controller.rescheduleSession(
        session.id,
        DateTime(date.year, date.month, date.day, time.hour, time.minute),
      );
    } else {
      final now = DateTime.now();
      var d = DateTime.saturday - now.weekday;
      if (d <= 0) d += 7;
      final sat = DateHelpers.startOfDay(now).add(Duration(days: d));
      await controller.rescheduleSession(
        session.id,
        DateTime(sat.year, sat.month, sat.day, session.plannedStart.hour, session.plannedStart.minute),
      );
    }
  }
}

class _TodaySessionCard extends StatelessWidget {
  const _TodaySessionCard({
    required this.session,
    required this.subject,
    required this.topic,
    required this.onTap,
    required this.onStart,
  });

  final StudySession session;
  final Subject? subject;
  final Topic? topic;
  final VoidCallback onTap;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = subject?.color ?? theme.colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.mdAll,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: AppRadius.mdAll,
          border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.55)),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(width: 4, color: color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${DateFormat('h:mm a').format(session.plannedStart)} · ${session.status.label}',
                        style: theme.textTheme.labelMedium,
                      ),
                      Text(
                        '${subject?.name ?? 'Subject'}${topic == null ? '' : ' · ${topic!.name}'}',
                        style: theme.textTheme.titleSmall,
                      ),
                      Text(
                        '${session.title} · ${StudyAnalytics.formatMinutes(session.plannedMinutes)}'
                        '${session.reminderMinutes == null ? '' : ' · 🔔 ${session.reminderMinutes}m'}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (session.status.isOpen)
                IconButton.filledTonal(
                  onPressed: onStart,
                  icon: const Icon(Icons.play_arrow_rounded),
                ),
              const SizedBox(width: 6),
            ],
          ),
        ),
      ),
    );
  }
}
