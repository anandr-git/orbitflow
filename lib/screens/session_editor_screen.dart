import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/study_session.dart';
import '../models/todo.dart';
import '../state/orbit_controller.dart';
import '../theme/design_tokens.dart';
import '../utils/date_helpers.dart';
import '../utils/responsive.dart';

class SessionEditorScreen extends StatefulWidget {
  const SessionEditorScreen({
    super.key,
    required this.controller,
    this.existing,
    this.initialSubjectId,
    this.initialTopicId,
    this.initialStart,
    this.initialMinutes,
  });

  final OrbitController controller;
  final StudySession? existing;
  final String? initialSubjectId;
  final String? initialTopicId;
  final DateTime? initialStart;
  final int? initialMinutes;

  @override
  State<SessionEditorScreen> createState() => _SessionEditorScreenState();
}

class _SessionEditorScreenState extends State<SessionEditorScreen> {
  late String _subjectId;
  String? _topicId;
  late DateTime _plannedStart;
  late int _plannedMinutes;
  late int? _reminderMinutes;
  late RecurrenceRule _recurrence;
  late TaskPriority _priority;
  late final TextEditingController _notes;
  late final TextEditingController _title;
  bool _showAdvanced = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final subjects = widget.controller.subjects.where((s) => !s.archived).toList();
    _subjectId = e?.subjectId ??
        widget.initialSubjectId ??
        (subjects.isNotEmpty ? subjects.first.id : '');
    _topicId = e?.topicId ?? widget.initialTopicId;
    _plannedStart = e?.plannedStart ??
        widget.initialStart ??
        DateTime.now().add(const Duration(hours: 1)).copyWith(minute: 0, second: 0);
    _plannedMinutes =
        e?.plannedMinutes ?? widget.initialMinutes ?? widget.controller.settings.defaultSessionMinutes;
    _reminderMinutes =
        e?.reminderMinutes ?? widget.controller.settings.notifications.reminderMinutesBefore;
    _recurrence = e?.recurrence ?? RecurrenceRule.none;
    _priority = e?.priority ?? TaskPriority.medium;
    _notes = TextEditingController(text: e?.notes ?? '');
    _title = TextEditingController(text: e?.title ?? '');
  }

  @override
  void dispose() {
    _notes.dispose();
    _title.dispose();
    super.dispose();
  }

  String get _autoTitle {
    final topic = widget.controller.topicById(_subjectId, _topicId);
    final subject = widget.controller.subjectById(_subjectId);
    if (topic != null) return topic.name;
    return subject?.name ?? 'Study session';
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _plannedStart,
      firstDate: DateTime.now().subtract(const Duration(days: 7)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null) return;
    setState(() {
      _plannedStart = DateTime(
        date.year,
        date.month,
        date.day,
        _plannedStart.hour,
        _plannedStart.minute,
      );
    });
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_plannedStart),
    );
    if (time == null) return;
    setState(() {
      _plannedStart = DateTime(
        _plannedStart.year,
        _plannedStart.month,
        _plannedStart.day,
        time.hour,
        time.minute,
      );
    });
  }

  void _setDayOffset(int days) {
    final base = DateHelpers.startOfDay(DateTime.now()).add(Duration(days: days));
    setState(() {
      _plannedStart = DateTime(
        base.year,
        base.month,
        base.day,
        _plannedStart.hour,
        _plannedStart.minute,
      );
    });
  }

  void _save() {
    if (_subjectId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create a subject first')),
      );
      return;
    }
    final title = _title.text.trim().isEmpty ? _autoTitle : _title.text.trim();
    final session = widget.existing == null
        ? StudySession(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            title: title,
            subjectId: _subjectId,
            topicId: _topicId,
            notes: _notes.text.trim(),
            plannedStart: _plannedStart,
            plannedMinutes: _plannedMinutes,
            reminderMinutes: _reminderMinutes,
            recurrence: _recurrence,
            priority: _priority,
          )
        : widget.existing!.copyWith(
            title: title,
            subjectId: _subjectId,
            topicId: _topicId,
            clearTopic: _topicId == null,
            notes: _notes.text.trim(),
            plannedStart: _plannedStart,
            plannedMinutes: _plannedMinutes,
            reminderMinutes: _reminderMinutes,
            clearReminder: _reminderMinutes == null,
            recurrence: _recurrence,
            priority: _priority,
            status: SessionStatus.scheduled,
          );
    Navigator.pop(context, session);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subjects = widget.controller.subjects.where((s) => !s.archived).toList();
    final subject = widget.controller.subjectById(_subjectId);
    final topics = subject?.topics ?? [];
    final today = DateHelpers.isSameDay(_plannedStart, DateTime.now());
    final tomorrow =
        DateHelpers.isSameDay(_plannedStart, DateTime.now().add(const Duration(days: 1)));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Plan session' : 'Edit session'),
        actions: [
          TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: ConstrainedContent(
        maxWidth: AppContentWidth.form,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            Text('What are you studying?', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            if (subjects.isEmpty)
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.info_outline),
                title: Text('No subjects yet'),
                subtitle: Text('Add a subject before planning sessions.'),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in subjects)
                    ChoiceChip(
                      label: Text(s.name),
                      selected: _subjectId == s.id,
                      onSelected: (_) => setState(() {
                        _subjectId = s.id;
                        _topicId = null;
                      }),
                    ),
                ],
              ),
            if (topics.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              Text('What topic?', style: theme.textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final t in topics)
                    ChoiceChip(
                      label: Text(t.name),
                      selected: _topicId == t.id,
                      onSelected: (_) => setState(() => _topicId = t.id),
                    ),
                ],
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Text('When?', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Today'),
                  selected: today,
                  onSelected: (_) => _setDayOffset(0),
                ),
                ChoiceChip(
                  label: const Text('Tomorrow'),
                  selected: tomorrow,
                  onSelected: (_) => _setDayOffset(1),
                ),
                ActionChip(
                  label: Text(DateFormat('MMM d').format(_plannedStart)),
                  onPressed: _pickDate,
                ),
              ],
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Time'),
              subtitle: Text(DateFormat('h:mm a').format(_plannedStart)),
              trailing: const Icon(Icons.schedule),
              onTap: _pickTime,
            ),
            const SizedBox(height: 4),
            Text('Duration', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final m in [25, 50, 90])
                  ChoiceChip(
                    label: Text('${m}m'),
                    selected: _plannedMinutes == m,
                    onSelected: (_) => setState(() => _plannedMinutes = m),
                  ),
                ActionChip(
                  label: Text(
                    [25, 50, 90].contains(_plannedMinutes)
                        ? 'Custom'
                        : '${_plannedMinutes}m',
                  ),
                  onPressed: () async {
                    final ctrl = TextEditingController(text: '$_plannedMinutes');
                    final v = await showDialog<int>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Custom duration'),
                        content: TextField(
                          controller: ctrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(suffixText: 'min'),
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                          FilledButton(
                            onPressed: () =>
                                Navigator.pop(ctx, int.tryParse(ctrl.text.trim())),
                            child: const Text('Set'),
                          ),
                        ],
                      ),
                    );
                    ctrl.dispose();
                    if (v != null && v > 0) setState(() => _plannedMinutes = v);
                  },
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text('Reminder', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('None'),
                  selected: _reminderMinutes == null,
                  onSelected: (_) => setState(() => _reminderMinutes = null),
                ),
                for (final m in [10, 30, 60])
                  ChoiceChip(
                    label: Text('${m}m'),
                    selected: _reminderMinutes == m,
                    onSelected: (_) => setState(() => _reminderMinutes = m),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            TextButton.icon(
              onPressed: () => setState(() => _showAdvanced = !_showAdvanced),
              icon: Icon(_showAdvanced ? Icons.expand_less : Icons.expand_more),
              label: Text(_showAdvanced ? 'Hide advanced' : 'Advanced'),
            ),
            if (_showAdvanced) ...[
              TextField(
                controller: _title,
                decoration: InputDecoration(
                  labelText: 'Title',
                  hintText: _autoTitle,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<RecurrenceRule>(
                initialValue: _recurrence,
                decoration: const InputDecoration(labelText: 'Repeat'),
                items: [
                  for (final r in RecurrenceRule.values)
                    DropdownMenuItem(value: r, child: Text(r.label)),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _recurrence = v);
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<TaskPriority>(
                initialValue: _priority,
                decoration: const InputDecoration(labelText: 'Priority'),
                items: [
                  for (final p in TaskPriority.values)
                    DropdownMenuItem(value: p, child: Text(p.label)),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _priority = v);
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _notes,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  alignLabelWithHint: true,
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check_rounded),
              label: Text(widget.existing == null ? 'Schedule session' : 'Update session'),
            ),
          ],
        ),
      ),
    );
  }
}
