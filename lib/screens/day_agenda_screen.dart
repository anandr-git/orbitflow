import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../analytics/study_analytics.dart';
import '../models/study_session.dart';
import '../state/orbit_controller.dart';
import '../theme/design_tokens.dart';
import '../utils/date_helpers.dart';
import 'focus_mode_screen.dart';
import 'session_editor_screen.dart';

class DayAgendaScreen extends StatelessWidget {
  const DayAgendaScreen({
    super.key,
    required this.controller,
    required this.day,
  });

  final OrbitController controller;
  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final stats = StudyAnalytics.dayStats(controller.sessions, day);
    final sessions = controller.sessions
        .where((s) => !s.archived && DateHelpers.isSameDay(s.plannedStart, day))
        .toList()
      ..sort((a, b) => a.plannedStart.compareTo(b.plannedStart));

    return Scaffold(
      appBar: AppBar(
        title: Text(DateFormat('EEEE, MMM d').format(day)),
        actions: [
          IconButton(
            tooltip: 'Add session',
            onPressed: () async {
              final created = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SessionEditorScreen(
                    controller: controller,
                    initialStart: DateTime(day.year, day.month, day.day, 19),
                  ),
                ),
              );
              if (created != null) await controller.upsertSession(created);
            },
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(
            '${StudyAnalytics.formatMinutes(stats.completedMinutes)} completed · '
            '${StudyAnalytics.formatMinutes(stats.plannedMinutes)} planned · '
            '${stats.missedCount} missed',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Timeline', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          ..._buildTimeline(context, sessions),
        ],
      ),
    );
  }

  List<Widget> _buildTimeline(BuildContext context, List<StudySession> sessions) {
    final isToday = DateHelpers.isSameDay(day, DateTime.now());
    final nowHour = DateTime.now().hour;
    final hoursWithSessions = sessions.map((s) => s.plannedStart.hour).toSet();
    var start = hoursWithSessions.isEmpty ? 8 : (hoursWithSessions.reduce((a, b) => a < b ? a : b) - 1).clamp(6, 22);
    var end = hoursWithSessions.isEmpty ? 20 : (hoursWithSessions.reduce((a, b) => a > b ? a : b) + 1).clamp(7, 23);
    if (isToday) {
      start = (start < nowHour - 1 ? start : nowHour - 1).clamp(6, 22);
      end = (end > nowHour + 2 ? end : nowHour + 2).clamp(7, 23);
    }
    return [
      for (var hour = start; hour <= end; hour++) ...[
        if (isToday && hour == nowHour)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                const SizedBox(width: 52),
                Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.circle, size: 8, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 6),
                      Text('Now', style: Theme.of(context).textTheme.labelMedium),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Divider(color: Theme.of(context).colorScheme.primary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        _HourRow(
          hour: hour,
          sessions: sessions.where((s) => s.plannedStart.hour == hour).toList(),
          controller: controller,
        ),
      ],
    ];
  }
}

class _HourRow extends StatelessWidget {
  const _HourRow({
    required this.hour,
    required this.sessions,
    required this.controller,
  });

  final int hour;
  final List<StudySession> sessions;
  final OrbitController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 52,
            child: Text(
              '${hour.toString().padLeft(2, '0')}:00',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Container(
              constraints: const BoxConstraints(minHeight: 40),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.45),
                  ),
                ),
              ),
              child: sessions.isEmpty
                  ? const SizedBox(height: 36)
                  : Column(
                      children: [
                        for (final s in sessions)
                          _SessionBlock(session: s, controller: controller),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionBlock extends StatelessWidget {
  const _SessionBlock({required this.session, required this.controller});

  final StudySession session;
  final OrbitController controller;

  Color _statusColor(ThemeData theme) {
    return switch (session.status) {
      SessionStatus.completed => theme.colorScheme.tertiary,
      SessionStatus.missed => theme.colorScheme.error,
      SessionStatus.inProgress => theme.colorScheme.primary,
      _ => controller.subjectById(session.subjectId)?.color ?? theme.colorScheme.primary,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subject = controller.subjectById(session.subjectId);
    final topic = controller.topicById(session.subjectId, session.topicId);
    final color = _statusColor(theme);

    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 4),
      child: Material(
        color: color.withValues(alpha: 0.14),
        borderRadius: AppRadius.smAll,
        child: InkWell(
          borderRadius: AppRadius.smAll,
          onTap: () async {
            if (session.status.isOpen) {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FocusModeScreen(controller: controller, session: session),
                ),
              );
            } else {
              final edited = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SessionEditorScreen(controller: controller, existing: session),
                ),
              );
              if (edited != null) await controller.upsertSession(edited);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: AppRadius.pillAll,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${DateFormat('h:mm a').format(session.plannedStart)} · '
                        '${StudyAnalytics.formatMinutes(session.plannedMinutes)}',
                        style: theme.textTheme.labelMedium,
                      ),
                      Text(
                        '${subject?.name ?? 'Subject'}${topic == null ? '' : ' · ${topic.name}'}',
                        style: theme.textTheme.titleSmall,
                      ),
                      Text(session.status.label, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
