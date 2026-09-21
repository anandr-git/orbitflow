import 'package:flutter/material.dart';

import '../models/todo.dart';
import '../theme/design_tokens.dart';
import '../utils/task_query.dart';

class StatsCard extends StatelessWidget {
  const StatsCard({
    super.key,
    required this.todos,
    this.dailyGoal = 3,
    this.streak = 0,
    this.onStatTap,
  });

  final List<Todo> todos;
  final int dailyGoal;
  final int streak;
  final ValueChanged<TaskStatusFilter>? onStatTap;

  @override
  Widget build(BuildContext context) {
    final active = todos.where((t) => !t.done && !t.archived).length;
    final overdue = todos.where((t) => t.isOverdue).length;
    final dueToday = todos.where((t) => !t.done && !t.archived && t.isDueToday).length;
    final completedToday = TaskQuery.completedTodayCount(todos);
    final goalProgress = dailyGoal <= 0 ? 0.0 : (completedToday / dailyGoal).clamp(0.0, 1.0);

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    String headline;
    IconData icon;
    Color accent = theme.colorScheme.primary;

    if (todos.isEmpty) {
      headline = 'Create your first task to start your orbit.';
      icon = Icons.rocket_launch_rounded;
    } else if (overdue > 0) {
      headline = '$overdue overdue — clear blockers first.';
      icon = Icons.warning_amber_rounded;
      accent = theme.colorScheme.error;
    } else if (completedToday >= dailyGoal && dailyGoal > 0) {
      headline = 'Daily goal hit. Strong finish.';
      icon = Icons.emoji_events_outlined;
      accent = Colors.green;
    } else if (dueToday > 0) {
      headline = '$dueToday due today. Stay focused.';
      icon = Icons.track_changes_rounded;
    } else {
      headline = 'Inbox clear for now. Plan ahead.';
      icon = Icons.check_circle_outline_rounded;
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: accent),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    headline,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: overdue > 0 ? theme.colorScheme.error : null,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (streak > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.tertiaryContainer.withValues(alpha: 0.55),
                      borderRadius: AppRadius.pillAll,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.local_fire_department_rounded,
                          size: 14,
                          color: theme.colorScheme.tertiary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$streak',
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.tertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Text(
                  'Today $completedToday/$dailyGoal',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const Spacer(),
                Text(
                  '${(goalProgress * 100).round()}%',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            ClipRRect(
              borderRadius: AppRadius.xsAll,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: goalProgress),
                duration: AppMotion.normal,
                curve: AppMotion.standard,
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  minHeight: 8,
                  backgroundColor:
                      isDark ? Colors.white12 : theme.colorScheme.surfaceContainerHighest,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            LayoutBuilder(
              builder: (context, constraints) {
                final useWrap = constraints.maxWidth < 420;
                final items = [
                  _StatTile(
                    label: 'Active',
                    value: '$active',
                    color: theme.colorScheme.primary,
                    onTap: () => onStatTap?.call(TaskStatusFilter.all),
                  ),
                  _StatTile(
                    label: 'Today',
                    value: '$dueToday',
                    color: theme.colorScheme.secondary,
                    onTap: () => onStatTap?.call(TaskStatusFilter.today),
                  ),
                  _StatTile(
                    label: 'Done',
                    value: '$completedToday',
                    color: Colors.green,
                    onTap: () => onStatTap?.call(TaskStatusFilter.completed),
                  ),
                  _StatTile(
                    label: 'Overdue',
                    value: '$overdue',
                    color: overdue > 0 ? theme.colorScheme.error : theme.colorScheme.outline,
                    onTap: () => onStatTap?.call(TaskStatusFilter.overdue),
                  ),
                ];
                if (useWrap) {
                  return Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: items
                        .map((w) => SizedBox(width: (constraints.maxWidth - 8) / 2, child: w))
                        .toList(),
                  );
                }
                return Row(
                  children: [for (final item in items) Expanded(child: item)],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });

  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.smAll,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
