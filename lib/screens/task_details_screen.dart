import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/todo.dart';
import '../theme/design_tokens.dart';
import '../utils/date_helpers.dart';
import '../utils/responsive.dart';
import 'add_task_screen.dart';

class TaskDetailsScreen extends StatefulWidget {
  const TaskDetailsScreen({
    super.key,
    required this.todo,
    this.embedded = false,
    this.onChanged,
  });

  final Todo todo;
  final bool embedded;
  final ValueChanged<Map<String, dynamic>>? onChanged;

  @override
  State<TaskDetailsScreen> createState() => _TaskDetailsScreenState();
}

class _TaskDetailsScreenState extends State<TaskDetailsScreen> {
  late Todo _todo;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _todo = widget.todo;
  }

  @override
  void didUpdateWidget(covariant TaskDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.todo.id != widget.todo.id || oldWidget.todo.updatedAt != widget.todo.updatedAt) {
      _todo = widget.todo;
      _hasChanges = false;
    }
  }

  void _emit(String action) {
    final payload = {'action': action, 'todo': _todo, 'changed': _hasChanges};
    if (widget.embedded) {
      widget.onChanged?.call(payload);
    } else if (action == 'delete' || action == 'archive') {
      Navigator.pop(context, payload);
    }
  }

  void _toggleDone() {
    HapticFeedback.lightImpact();
    setState(() {
      final done = !_todo.done;
      _todo = _todo.copyWith(
        done: done,
        completedAt: done ? DateTime.now() : null,
        clearCompletedAt: !done,
      );
      _hasChanges = true;
    });
    if (widget.embedded) _emit('update');
  }

  void _toggleSubtask(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      final subs = _todo.subtasks.map((s) => s.copyWith()).toList();
      subs[index] = subs[index].copyWith(isDone: !subs[index].isDone);
      _todo = _todo.copyWith(subtasks: subs);
      _hasChanges = true;
    });
    if (widget.embedded) _emit('update');
  }

  Future<void> _edit() async {
    final updated = await Navigator.push<Todo>(
      context,
      MaterialPageRoute(builder: (_) => AddTaskScreen(existing: _todo)),
    );
    if (updated != null && mounted) {
      setState(() {
        _todo = updated;
        _hasChanges = true;
      });
      if (widget.embedded) _emit('update');
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete task'),
        content: Text('Delete "${_todo.title}"? You can undo from the snackbar on the home screen.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      HapticFeedback.mediumImpact();
      _emit('delete');
      if (!widget.embedded) {
        // already popped in _emit for non-embedded delete
      }
    }
  }

  void _archive() {
    setState(() {
      _todo = _todo.copyWith(archived: true, done: true, completedAt: DateTime.now());
      _hasChanges = true;
    });
    _emit('archive');
  }

  void _onWillPop() {
    Navigator.pop(context, {'action': 'update', 'todo': _todo, 'changed': _hasChanges});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final responsive = Responsive.of(context);

    final body = ListView(
      padding: EdgeInsets.fromLTRB(
        responsive.pageHorizontalPadding,
        AppSpacing.md,
        responsive.pageHorizontalPadding,
        AppSpacing.xxxl,
      ),
      children: [
        InkWell(
          onTap: _toggleDone,
          borderRadius: AppRadius.mdAll,
          child: AnimatedContainer(
            duration: AppMotion.fast,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: _todo.done
                  ? Colors.green.withValues(alpha: 0.12)
                  : theme.colorScheme.primaryContainer.withValues(alpha: 0.28),
              borderRadius: AppRadius.mdAll,
              border: Border.all(
                color: _todo.done
                    ? Colors.green
                    : theme.colorScheme.primary.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _todo.done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  color: _todo.done ? Colors.green : theme.colorScheme.primary,
                  size: 28,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _todo.done ? 'Completed' : 'Pending',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: _todo.done ? Colors.green : theme.colorScheme.primary,
                        ),
                      ),
                      Text(
                        _todo.done ? 'Tap to reopen' : 'Tap to mark done',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        // Avoid duplicate Hero tags when embedded beside TaskCard in tablet two-pane.
        if (widget.embedded)
          Text(
            _todo.title,
            style: theme.textTheme.headlineSmall?.copyWith(
              decoration: _todo.done ? TextDecoration.lineThrough : null,
              color: _todo.done ? theme.colorScheme.onSurfaceVariant : null,
            ),
          )
        else
          Hero(
            tag: 'todo-${_todo.id}',
            child: Material(
              color: Colors.transparent,
              child: Text(
                _todo.title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  decoration: _todo.done ? TextDecoration.lineThrough : null,
                  color: _todo.done ? theme.colorScheme.onSurfaceVariant : null,
                ),
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(
              avatar: Icon(_todo.category.icon, color: Colors.white, size: 16),
              label: Text(_todo.category.label),
              backgroundColor: _todo.category.color,
              labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              side: BorderSide.none,
            ),
            Chip(
              avatar: Icon(_todo.priority.icon, color: Colors.white, size: 16),
              label: Text('${_todo.priority.label} priority'),
              backgroundColor: _todo.priority.color,
              labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              side: BorderSide.none,
            ),
            if (_todo.isOverdue)
              const Chip(
                avatar: Icon(Icons.warning_amber_rounded, color: Colors.white, size: 16),
                label: Text('Overdue'),
                backgroundColor: Colors.red,
                labelStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                side: BorderSide.none,
              ),
            if (_todo.isRecurring)
              Chip(
                avatar: const Icon(Icons.repeat_rounded, size: 16),
                label: Text(_todo.recurrence.label),
              ),
            for (final tag in _todo.tags) Chip(label: Text('#$tag')),
          ],
        ),
        if (_todo.hasNotes) ...[
          const SizedBox(height: AppSpacing.lg),
          Text('Notes', style: theme.textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
              borderRadius: AppRadius.smAll,
            ),
            child: Text(_todo.description, style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Text('Timeline', style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.xs),
        Card(
          margin: EdgeInsets.zero,
          child: Column(
            children: [
              if (_todo.dueDate != null) ...[
                ListTile(
                  leading: Icon(
                    Icons.event_available_rounded,
                    color: _todo.isOverdue ? theme.colorScheme.error : theme.colorScheme.primary,
                  ),
                  title: const Text('Due'),
                  subtitle: Text(
                    DateHelpers.formatFull(_todo.dueDate!),
                    style: TextStyle(
                      color: _todo.isOverdue ? theme.colorScheme.error : null,
                      fontWeight: _todo.isOverdue ? FontWeight.bold : null,
                    ),
                  ),
                ),
                const Divider(height: 1),
              ],
              if (_todo.reminderMinutes != null) ...[
                ListTile(
                  leading: const Icon(Icons.notifications_active_outlined),
                  title: const Text('Reminder'),
                  subtitle: Text(_reminderLabel(_todo.reminderMinutes!)),
                ),
                const Divider(height: 1),
              ],
              if (_todo.estimatedMinutes != null) ...[
                ListTile(
                  leading: const Icon(Icons.timer_outlined),
                  title: const Text('Estimate'),
                  subtitle: Text('${_todo.estimatedMinutes} minutes'),
                ),
                const Divider(height: 1),
              ],
              ListTile(
                leading: const Icon(Icons.schedule_rounded),
                title: const Text('Created'),
                subtitle: Text(DateHelpers.formatFull(_todo.createdAt)),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.update_rounded),
                title: const Text('Updated'),
                subtitle: Text(DateHelpers.formatFull(_todo.updatedAt)),
              ),
              if (_todo.completedAt != null) ...[
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.check_circle_outline),
                  title: const Text('Completed'),
                  subtitle: Text(DateHelpers.formatFull(_todo.completedAt!)),
                ),
              ],
            ],
          ),
        ),
        if (_todo.subtasks.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Text(
                'Subtasks (${_todo.completedSubtasksCount}/${_todo.subtasks.length})',
                style: theme.textTheme.titleSmall,
              ),
              const Spacer(),
              Text(
                '${(_todo.subtaskProgress * 100).round()}%',
                style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: AppRadius.xsAll,
            child: LinearProgressIndicator(
              value: _todo.subtaskProgress,
              minHeight: 6,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (int i = 0; i < _todo.subtasks.length; i++)
            Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: CheckboxListTile(
                value: _todo.subtasks[i].isDone,
                onChanged: (_) => _toggleSubtask(i),
                title: Text(
                  _todo.subtasks[i].title,
                  style: TextStyle(
                    decoration: _todo.subtasks[i].isDone ? TextDecoration.lineThrough : null,
                    color: _todo.subtasks[i].isDone ? theme.colorScheme.onSurfaceVariant : null,
                  ),
                ),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ),
        ],
        const SizedBox(height: AppSpacing.xl),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: _edit,
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit'),
            ),
            if (!_todo.archived)
              OutlinedButton.icon(
                onPressed: _archive,
                icon: const Icon(Icons.inventory_2_outlined),
                label: const Text('Archive'),
              ),
            OutlinedButton.icon(
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
              label: const Text('Delete'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
            ),
          ],
        ),
      ],
    );

    if (widget.embedded) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: Row(
              children: [
                Text('Task details', style: theme.textTheme.titleLarge),
                const Spacer(),
                IconButton(tooltip: 'Edit', onPressed: _edit, icon: const Icon(Icons.edit_outlined)),
                IconButton(
                  tooltip: 'Delete',
                  onPressed: _delete,
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                ),
              ],
            ),
          ),
          Expanded(child: body),
        ],
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onWillPop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Task details'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _onWillPop,
          ),
          actions: [
            IconButton(tooltip: 'Edit', icon: const Icon(Icons.edit_outlined), onPressed: _edit),
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
              onPressed: _delete,
            ),
          ],
        ),
        body: ConstrainedContent(child: body),
      ),
    );
  }

  String _reminderLabel(int minutes) {
    if (minutes < 60) return '$minutes minutes before';
    if (minutes < 1440) return '${minutes ~/ 60} hour(s) before';
    return '1 day before';
  }
}
