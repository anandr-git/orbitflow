import 'package:flutter/material.dart';

import '../models/todo.dart';
import '../theme/design_tokens.dart';
import '../utils/date_helpers.dart';

class TaskCard extends StatelessWidget {
  const TaskCard({
    super.key,
    required this.todo,
    required this.onTap,
    required this.onToggle,
    required this.onDelete,
    this.selected = false,
    this.compact = false,
  });

  final Todo todo;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final bool selected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Dismissible(
      key: ValueKey('dismiss-${todo.id}'),
      direction: DismissDirection.horizontal,
      background: _SwipeBg(
        alignment: Alignment.centerLeft,
        color: Colors.green.shade600,
        icon: todo.done ? Icons.restart_alt_rounded : Icons.check_rounded,
        label: todo.done ? 'Reopen' : 'Complete',
      ),
      secondaryBackground: const _SwipeBg(
        alignment: Alignment.centerRight,
        color: Color(0xFFDC2626),
        icon: Icons.delete_outline_rounded,
        label: 'Delete',
        reverse: true,
      ),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          onToggle();
          return false;
        }
        onDelete();
        return true;
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.symmetric(
          horizontal: compact ? 0 : AppSpacing.md,
          vertical: 5,
        ),
        color: selected
            ? theme.colorScheme.primaryContainer.withValues(alpha: 0.35)
            : null,
        child: InkWell(
          onTap: onTap,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: todo.priority.color),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 8, 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Semantics(
                          label: todo.done ? 'Mark as incomplete' : 'Mark as complete',
                          button: true,
                          child: Checkbox(
                            value: todo.done,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                            onChanged: (_) => onToggle(),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 10),
                              Hero(
                                tag: 'todo-${todo.id}',
                                child: Material(
                                  color: Colors.transparent,
                                  child: Text(
                                    todo.title,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      decoration:
                                          todo.done ? TextDecoration.lineThrough : null,
                                      color: todo.done ? muted : null,
                                    ),
                                  ),
                                ),
                              ),
                              if (todo.hasNotes) ...[
                                const SizedBox(height: 4),
                                Text(
                                  todo.description,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: muted,
                                    decoration:
                                        todo.done ? TextDecoration.lineThrough : null,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  _MetaChip(
                                    icon: todo.category.icon,
                                    label: todo.category.label,
                                    color: todo.category.color,
                                  ),
                                  if (todo.priority == TaskPriority.high ||
                                      todo.priority == TaskPriority.urgent)
                                    _MetaChip(
                                      icon: todo.priority.icon,
                                      label: todo.priority.label,
                                      color: todo.priority.color,
                                    ),
                                  if (todo.dueDate != null)
                                    _MetaChip(
                                      icon: todo.isOverdue
                                          ? Icons.warning_amber_rounded
                                          : Icons.schedule_rounded,
                                      label: DateHelpers.formatDue(todo.dueDate!),
                                      color: todo.isOverdue
                                          ? theme.colorScheme.error
                                          : muted,
                                      emphasized: todo.isOverdue,
                                    ),
                                  if (todo.subtasks.isNotEmpty)
                                    _MetaChip(
                                      icon: Icons.checklist_rounded,
                                      label: todo.subtasksSummary,
                                      color: muted,
                                    ),
                                  if (todo.isRecurring)
                                    _MetaChip(
                                      icon: Icons.repeat_rounded,
                                      label: todo.recurrence.label,
                                      color: muted,
                                    ),
                                  if (todo.hasTags)
                                    ...todo.tags.take(2).map(
                                          (tag) => _MetaChip(
                                            icon: Icons.tag_rounded,
                                            label: tag,
                                            color: theme.colorScheme.tertiary,
                                          ),
                                        ),
                                  if (todo.hasNotes)
                                    _MetaChip(
                                      icon: Icons.sticky_note_2_outlined,
                                      label: 'Notes',
                                      color: muted,
                                    ),
                                ],
                              ),
                              if (todo.subtasks.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: AppRadius.xsAll,
                                  child: LinearProgressIndicator(
                                    value: todo.subtaskProgress,
                                    minHeight: 4,
                                    backgroundColor:
                                        theme.colorScheme.surfaceContainerHighest,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Delete task',
                          icon: Icon(Icons.delete_outline_rounded, color: muted, size: 20),
                          onPressed: () async {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Delete task'),
                                content: Text('Delete "${todo.title}"?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: const Text('Cancel'),
                                  ),
                                  FilledButton(
                                    style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );
                            if (ok == true) onDelete();
                          },
                        ),
                      ],
                    ),
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

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    required this.color,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.xsAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: emphasized ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SwipeBg extends StatelessWidget {
  const _SwipeBg({
    required this.alignment,
    required this.color,
    required this.icon,
    required this.label,
    this.reverse = false,
  });

  final Alignment alignment;
  final Color color;
  final IconData icon;
  final String label;
  final bool reverse;

  @override
  Widget build(BuildContext context) {
    final children = [
      Icon(icon, color: Colors.white),
      const SizedBox(width: 8),
      Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    ];
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      color: color,
      child: Row(
        mainAxisAlignment: reverse ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: reverse ? children.reversed.toList() : children,
      ),
    );
  }
}
