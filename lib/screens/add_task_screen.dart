import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/app_settings.dart';
import '../models/todo.dart';
import '../theme/design_tokens.dart';
import '../utils/responsive.dart';

class AddTaskScreen extends StatefulWidget {
  const AddTaskScreen({
    super.key,
    this.existing,
    this.defaults,
  });

  final Todo? existing;
  final AppSettings? defaults;

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descController;
  late final TextEditingController _subtaskController;
  late final TextEditingController _tagController;

  late TaskCategory _category;
  late TaskPriority _priority;
  DateTime? _dueDate;
  late List<Subtask> _subtasks;
  late List<String> _tags;
  late RecurrenceRule _recurrence;
  int? _reminderMinutes;
  int? _estimatedMinutes;
  bool _showAdvanced = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    final defaults = widget.defaults;
    _titleController = TextEditingController(text: existing?.title ?? '');
    _descController = TextEditingController(text: existing?.description ?? '');
    _subtaskController = TextEditingController();
    _tagController = TextEditingController();
    _category = existing?.category ?? defaults?.defaultCategory ?? TaskCategory.personal;
    _priority = existing?.priority ?? defaults?.defaultPriority ?? TaskPriority.medium;
    _dueDate = existing?.dueDate;
    _subtasks = existing?.subtasks.map((s) => s.copyWith()).toList() ?? [];
    _tags = List<String>.from(existing?.tags ?? const []);
    _recurrence = existing?.recurrence ?? RecurrenceRule.none;
    _reminderMinutes = existing?.reminderMinutes;
    _estimatedMinutes = existing?.estimatedMinutes;
    _showAdvanced = existing != null &&
        (existing.description.isNotEmpty ||
            existing.tags.isNotEmpty ||
            existing.recurrence != RecurrenceRule.none ||
            existing.reminderMinutes != null ||
            existing.estimatedMinutes != null);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _subtaskController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _markDirty() {
    if (!_dirty) setState(() => _dirty = true);
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 3)),
    );
    if (date == null || !mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: _dueDate != null ? TimeOfDay.fromDateTime(_dueDate!) : TimeOfDay.now(),
    );
    if (!mounted) return;

    setState(() {
      _dueDate = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? 18,
        time?.minute ?? 0,
      );
      _dirty = true;
    });
  }

  void _setQuickDate(int daysFromNow, {int hour = 18, int minute = 0}) {
    final target = DateTime.now().add(Duration(days: daysFromNow));
    setState(() {
      _dueDate = DateTime(target.year, target.month, target.day, hour, minute);
      _dirty = true;
    });
  }

  void _addSubtask() {
    final text = _subtaskController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _subtasks.add(Subtask(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        title: text,
      ));
      _subtaskController.clear();
      _dirty = true;
    });
  }

  void _addTag() {
    final text = _tagController.text.trim().replaceAll('#', '');
    if (text.isEmpty) return;
    if (_tags.any((t) => t.toLowerCase() == text.toLowerCase())) {
      _tagController.clear();
      return;
    }
    setState(() {
      _tags.add(text);
      _tagController.clear();
      _dirty = true;
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.lightImpact();

    final title = _titleController.text.trim();
    final desc = _descController.text.trim();

    final todo = widget.existing != null
        ? widget.existing!.copyWith(
            title: title,
            description: desc,
            category: _category,
            priority: _priority,
            dueDate: _dueDate,
            clearDueDate: _dueDate == null,
            subtasks: _subtasks,
            tags: _tags,
            recurrence: _recurrence,
            reminderMinutes: _reminderMinutes,
            clearReminder: _reminderMinutes == null,
            estimatedMinutes: _estimatedMinutes,
            clearEstimated: _estimatedMinutes == null,
          )
        : Todo(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            title: title,
            description: desc,
            category: _category,
            priority: _priority,
            dueDate: _dueDate,
            subtasks: _subtasks,
            tags: _tags,
            recurrence: _recurrence,
            reminderMinutes: _reminderMinutes,
            estimatedMinutes: _estimatedMinutes,
          );

    Navigator.pop(context, todo);
  }

  Future<bool> _confirmDiscard() async {
    if (!_dirty) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('You have unsaved edits on this task.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Keep editing')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Discard')),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _handlePop() async {
    if (await _confirmDiscard() && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.existing != null;
    final responsive = Responsive.of(context);

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _handlePop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(isEditing ? 'Edit Task' : 'New Task'),
          actions: [
            TextButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check_rounded),
              label: const Text('Save'),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: Form(
          key: _formKey,
          child: ConstrainedContent(
            maxWidth: AppContentWidth.form,
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                responsive.pageHorizontalPadding,
                AppSpacing.md,
                responsive.pageHorizontalPadding,
                AppSpacing.xxxl,
              ),
              children: [
                TextFormField(
                  controller: _titleController,
                  autofocus: !isEditing,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    labelText: 'Task title',
                    hintText: 'What needs to be done?',
                    prefixIcon: const Icon(Icons.check_box_outlined),
                    suffixIcon: _titleController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 20),
                            onPressed: () => setState(() {
                              _titleController.clear();
                              _dirty = true;
                            }),
                          )
                        : null,
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a task title';
                    }
                    return null;
                  },
                  onChanged: (_) {
                    _markDirty();
                    setState(() {});
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Priority', style: theme.textTheme.titleSmall),
                const SizedBox(height: AppSpacing.xs),
                SegmentedButton<TaskPriority>(
                  showSelectedIcon: false,
                  segments: [
                    for (final p in TaskPriority.values)
                      ButtonSegment<TaskPriority>(
                        value: p,
                        label: Text(p.label, style: const TextStyle(fontSize: 12)),
                        icon: Icon(p.icon, color: p.color, size: 14),
                      ),
                  ],
                  selected: {_priority},
                  onSelectionChanged: (s) => setState(() {
                    _priority = s.first;
                    _dirty = true;
                  }),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Category', style: theme.textTheme.titleSmall),
                const SizedBox(height: AppSpacing.xs),
                DropdownButtonFormField<TaskCategory>(
                  initialValue: _category,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.category_rounded),
                  ),
                  items: [
                    for (final c in TaskCategory.values)
                      DropdownMenuItem(
                        value: c,
                        child: Row(
                          children: [
                            Icon(c.icon, color: c.color, size: 20),
                            const SizedBox(width: 10),
                            Text(c.label),
                          ],
                        ),
                      ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _category = val;
                        _dirty = true;
                      });
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Text('Due date', style: theme.textTheme.titleSmall),
                    const Spacer(),
                    if (_dueDate != null)
                      TextButton(
                        onPressed: () => setState(() {
                          _dueDate = null;
                          _dirty = true;
                        }),
                        child: const Text('Clear'),
                      ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.today_rounded, size: 16),
                      label: const Text('Today'),
                      onPressed: () => _setQuickDate(0),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.wb_sunny_outlined, size: 16),
                      label: const Text('Tomorrow'),
                      onPressed: () => _setQuickDate(1),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.next_week_rounded, size: 16),
                      label: const Text('In 3 days'),
                      onPressed: () => _setQuickDate(3),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.calendar_month_rounded, size: 16),
                      label: const Text('Pick date'),
                      onPressed: _pickDueDate,
                    ),
                  ],
                ),
                if (_dueDate != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
                      borderRadius: AppRadius.smAll,
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.alarm_rounded, size: 18, color: theme.colorScheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            DateFormat('EEE, MMM d, y · h:mm a').format(_dueDate!),
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                Text('Subtasks', style: theme.textTheme.titleSmall),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _subtaskController,
                        decoration: const InputDecoration(
                          hintText: 'Add a checklist item',
                          prefixIcon: Icon(Icons.add_task_rounded, size: 20),
                        ),
                        onSubmitted: (_) => _addSubtask(),
                        onChanged: (_) => _markDirty(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      icon: const Icon(Icons.add_rounded),
                      onPressed: _addSubtask,
                      tooltip: 'Add subtask',
                    ),
                  ],
                ),
                if (_subtasks.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _subtasks.length,
                    onReorderItem: (oldIndex, newIndex) {
                      setState(() {
                        final item = _subtasks.removeAt(oldIndex);
                        _subtasks.insert(newIndex, item);
                        _dirty = true;
                      });
                    },
                    itemBuilder: (context, i) {
                      final s = _subtasks[i];
                      return Card(
                        key: ValueKey(s.id),
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          dense: true,
                          leading: Checkbox(
                            value: s.isDone,
                            onChanged: (val) => setState(() {
                              s.isDone = val ?? false;
                              _dirty = true;
                            }),
                          ),
                          title: Text(
                            s.title,
                            style: TextStyle(
                              decoration: s.isDone ? TextDecoration.lineThrough : null,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ReorderableDragStartListener(
                                index: i,
                                child: const Icon(Icons.drag_handle_rounded),
                              ),
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline_rounded, size: 20),
                                onPressed: () => setState(() {
                                  _subtasks.removeAt(i);
                                  _dirty = true;
                                }),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _showAdvanced = !_showAdvanced),
                    icon: Icon(_showAdvanced ? Icons.expand_less : Icons.expand_more),
                    label: Text(_showAdvanced ? 'Hide details' : 'More details'),
                  ),
                ),
                AnimatedCrossFade(
                  firstChild: const SizedBox.shrink(),
                  secondChild: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _descController,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          labelText: 'Notes',
                          hintText: 'Context, links, acceptance criteria…',
                          prefixIcon: Icon(Icons.notes_rounded),
                          alignLabelWithHint: true,
                        ),
                        onChanged: (_) => _markDirty(),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text('Tags', style: theme.textTheme.titleSmall),
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _tagController,
                              decoration: const InputDecoration(
                                hintText: 'Add tag',
                                prefixIcon: Icon(Icons.tag_rounded),
                              ),
                              onSubmitted: (_) => _addTag(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filledTonal(
                            onPressed: _addTag,
                            icon: const Icon(Icons.add_rounded),
                          ),
                        ],
                      ),
                      if (_tags.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final tag in _tags)
                              InputChip(
                                label: Text(tag),
                                onDeleted: () => setState(() {
                                  _tags.remove(tag);
                                  _dirty = true;
                                }),
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: AppSpacing.lg),
                      Text('Repeat', style: theme.textTheme.titleSmall),
                      const SizedBox(height: AppSpacing.xs),
                      DropdownButtonFormField<RecurrenceRule>(
                        initialValue: _recurrence,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.repeat_rounded),
                        ),
                        items: [
                          for (final r in RecurrenceRule.values)
                            DropdownMenuItem(value: r, child: Text(r.label)),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setState(() {
                              _recurrence = v;
                              _dirty = true;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text('Reminder', style: theme.textTheme.titleSmall),
                      const SizedBox(height: AppSpacing.xs),
                      Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('None'),
                            selected: _reminderMinutes == null,
                            onSelected: (_) => setState(() {
                              _reminderMinutes = null;
                              _dirty = true;
                            }),
                          ),
                          for (final mins in [15, 60, 180, 1440])
                            ChoiceChip(
                              label: Text(mins < 60
                                  ? '$mins min'
                                  : mins < 1440
                                      ? '${mins ~/ 60}h'
                                      : '1 day'),
                              selected: _reminderMinutes == mins,
                              onSelected: (_) => setState(() {
                                _reminderMinutes = mins;
                                _dirty = true;
                              }),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text('Estimated time', style: theme.textTheme.titleSmall),
                      const SizedBox(height: AppSpacing.xs),
                      Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('None'),
                            selected: _estimatedMinutes == null,
                            onSelected: (_) => setState(() {
                              _estimatedMinutes = null;
                              _dirty = true;
                            }),
                          ),
                          for (final mins in [15, 30, 60, 120])
                            ChoiceChip(
                              label: Text(mins < 60 ? '${mins}m' : '${mins ~/ 60}h'),
                              selected: _estimatedMinutes == mins,
                              onSelected: (_) => setState(() {
                                _estimatedMinutes = mins;
                                _dirty = true;
                              }),
                            ),
                        ],
                      ),
                    ],
                  ),
                  crossFadeState:
                      _showAdvanced ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                  duration: AppMotion.fast,
                ),
                const SizedBox(height: AppSpacing.xl),
                FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check_rounded),
                  label: Text(isEditing ? 'Update task' : 'Create task'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
