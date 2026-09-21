import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../models/app_settings.dart';
import '../models/todo.dart';
import '../storage/todo_repository.dart';
import '../theme/app_theme.dart';
import '../theme/design_tokens.dart';
import '../utils/date_helpers.dart';
import '../utils/responsive.dart';
import '../utils/task_query.dart';
import '../widgets/empty_state.dart';
import '../widgets/stats_card.dart';
import '../widgets/task_card.dart';
import 'add_task_screen.dart';
import 'settings_screen.dart';
import 'task_details_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
    this.onTodosChanged,
    this.initialTodos,
  });

  final AppSettings settings;
  final ValueChanged<AppSettings> onSettingsChanged;
  final ValueChanged<List<Todo>>? onTodosChanged;
  final List<Todo>? initialTodos;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _repository = TodoRepository();
  final _searchController = TextEditingController();

  List<Todo> _todos = [];
  bool _loading = true;
  bool _searching = false;
  Todo? _selectedTodo;

  late TaskQuery _query;

  @override
  void initState() {
    super.initState();
    _query = TaskQuery(status: _mapDefaultView(widget.settings.defaultView));
    _load();
    _searchController.addListener(() {
      setState(() => _query = _query.copyWith(search: _searchController.text));
    });
  }

  TaskStatusFilter _mapDefaultView(DefaultView view) => switch (view) {
        DefaultView.today => TaskStatusFilter.today,
        DefaultView.all => TaskStatusFilter.all,
        DefaultView.upcoming => TaskStatusFilter.upcoming,
        DefaultView.overdue => TaskStatusFilter.overdue,
      };

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (widget.initialTodos != null) {
      if (!mounted) return;
      setState(() {
        _todos = List<Todo>.from(widget.initialTodos!);
        _loading = false;
      });
      return;
    }
    final todos = await _repository.loadTodos();
    if (!mounted) return;
    setState(() {
      _todos = todos;
      _loading = false;
    });
  }

  Future<void> _persist() async {
    await _repository.saveTodos(_todos);
    widget.onTodosChanged?.call(_todos);
  }

  List<Todo> get _filtered => _query.apply(_todos);

  Future<void> _addTodo({Todo? seed}) async {
    final todo = await Navigator.push<Todo>(
      context,
      MaterialPageRoute(
        builder: (_) => AddTaskScreen(
          defaults: widget.settings,
          existing: seed,
        ),
      ),
    );
    if (todo == null) return;
    setState(() => _todos.insert(0, todo));
    await _persist();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Created "${todo.title}"')),
      );
    }
  }

  Future<void> _quickAdd() async {
    final controller = TextEditingController();
    final title = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: AppSpacing.md,
            right: AppSpacing.md,
            top: AppSpacing.md,
            bottom: MediaQuery.viewInsetsOf(ctx).bottom + AppSpacing.md,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Quick add', style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: controller,
                autofocus: true,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  hintText: 'Task title',
                  prefixIcon: Icon(Icons.bolt_rounded),
                ),
                onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
              ),
              const SizedBox(height: AppSpacing.sm),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                child: const Text('Add'),
              ),
            ],
          ),
        );
      },
    );
    controller.dispose();
    if (title == null || title.isEmpty) return;

    final todo = Todo(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      category: widget.settings.defaultCategory,
      priority: widget.settings.defaultPriority,
      dueDate: DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
        18,
      ),
    );
    setState(() => _todos.insert(0, todo));
    await _persist();
  }

  void _toggleDone(Todo todo) {
    HapticFeedback.lightImpact();
    final becomingDone = !todo.done;
    setState(() {
      final index = _todos.indexWhere((t) => t.id == todo.id);
      if (index == -1) return;

      var updated = _todos[index].copyWith(
        done: becomingDone,
        completedAt: becomingDone ? DateTime.now() : null,
        clearCompletedAt: !becomingDone,
      );
      _todos[index] = updated;

      if (becomingDone && updated.isRecurring) {
        _todos.insert(0, updated.spawnNextOccurrence());
      }
    });
    _persist();
    if (becomingDone) _bumpStreak();
  }

  void _bumpStreak() {
    final today = DateHelpers.dayKey(DateTime.now());
    final last = widget.settings.lastCompletionDay;
    var streak = widget.settings.completionStreak;
    if (last == today) {
      // already counted today
    } else if (last != null) {
      final yesterday = DateHelpers.dayKey(DateTime.now().subtract(const Duration(days: 1)));
      streak = last == yesterday ? streak + 1 : 1;
    } else {
      streak = 1;
    }
    widget.onSettingsChanged(
      widget.settings.copyWith(completionStreak: streak, lastCompletionDay: today),
    );
  }

  void _removeTodo(Todo todo, {bool showUndo = true}) {
    final index = _todos.indexWhere((t) => t.id == todo.id);
    if (index == -1) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _todos.removeAt(index);
      if (_selectedTodo?.id == todo.id) _selectedTodo = null;
    });
    _persist();

    if (showUndo && mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deleted "${todo.title}"'),
          action: SnackBarAction(
            label: 'UNDO',
            onPressed: () {
              setState(() => _todos.insert(index.clamp(0, _todos.length), todo));
              _persist();
            },
          ),
        ),
      );
    }
  }

  void _clearCompleted() {
    final removed = _todos.where((t) => t.done && !t.archived).toList();
    if (removed.isEmpty) return;
    setState(() => _todos.removeWhere((t) => t.done && !t.archived));
    _persist();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cleared ${removed.length} completed tasks'),
          action: SnackBarAction(
            label: 'UNDO',
            onPressed: () {
              setState(() => _todos.addAll(removed));
              _persist();
            },
          ),
        ),
      );
    }
  }

  Future<void> _openDetails(Todo todo) async {
    final responsive = Responsive.of(context);
    if (responsive.useTwoPane) {
      setState(() => _selectedTodo = todo);
      return;
    }

    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => TaskDetailsScreen(todo: todo)),
    );
    _applyDetailResult(result);
  }

  void _applyDetailResult(Map<String, dynamic>? result) {
    if (result == null) return;
    final action = result['action'] as String?;
    final resultTodo = result['todo'] as Todo?;
    if (action == 'delete' && resultTodo != null) {
      _removeTodo(resultTodo);
    } else if (action == 'update' && resultTodo != null) {
      final index = _todos.indexWhere((t) => t.id == resultTodo.id);
      if (index != -1) {
        final wasDone = _todos[index].done;
        setState(() {
          _todos[index] = resultTodo;
          _selectedTodo = resultTodo;
          if (!wasDone && resultTodo.done && resultTodo.isRecurring) {
            final alreadySpawned = _todos.any(
              (t) =>
                  !t.done &&
                  t.title == resultTodo.title &&
                  t.recurrence == resultTodo.recurrence &&
                  t.id != resultTodo.id &&
                  t.createdAt.isAfter(resultTodo.updatedAt.subtract(const Duration(seconds: 2))),
            );
            if (!alreadySpawned) {
              _todos.insert(0, resultTodo.spawnNextOccurrence());
            }
          }
        });
        _persist();
        if (!wasDone && resultTodo.done) _bumpStreak();
      }
    } else if (action == 'archive' && resultTodo != null) {
      final index = _todos.indexWhere((t) => t.id == resultTodo.id);
      if (index != -1) {
        setState(() {
          _todos[index] = resultTodo;
          _selectedTodo = resultTodo;
        });
        _persist();
      }
    }
  }

  void _showSortSheet() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text('Sort', style: Theme.of(context).textTheme.titleMedium),
              ),
              for (final option in TaskSortOption.values.where((o) => o != TaskSortOption.manual))
                ListTile(
                  leading: Icon(switch (option) {
                    TaskSortOption.dueDate => Icons.event_outlined,
                    TaskSortOption.priority => Icons.flag_outlined,
                    TaskSortOption.newest => Icons.access_time_rounded,
                    TaskSortOption.alphabetical => Icons.sort_by_alpha_rounded,
                    TaskSortOption.manual => Icons.drag_indicator_rounded,
                  }),
                  title: Text(switch (option) {
                    TaskSortOption.dueDate => 'Due date',
                    TaskSortOption.priority => 'Priority',
                    TaskSortOption.newest => 'Newest first',
                    TaskSortOption.alphabetical => 'Alphabetical',
                    TaskSortOption.manual => 'Manual',
                  }),
                  trailing: _query.sort == option
                      ? Icon(Icons.check_rounded, color: Theme.of(context).colorScheme.primary)
                      : null,
                  onTap: () {
                    setState(() => _query = _query.copyWith(sort: option));
                    Navigator.pop(ctx);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModal) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Filters', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    Text('Priority', style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilterChip(
                          label: const Text('Any'),
                          selected: _query.priority == null,
                          onSelected: (_) {
                            setState(() => _query = _query.copyWith(clearPriority: true));
                            setModal(() {});
                          },
                        ),
                        for (final p in TaskPriority.values)
                          FilterChip(
                            label: Text(p.label),
                            selected: _query.priority == p,
                            onSelected: (_) {
                              setState(() => _query = _query.copyWith(priority: p));
                              setModal(() {});
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text('Tags', style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilterChip(
                          label: const Text('Any'),
                          selected: _query.tag == null,
                          onSelected: (_) {
                            setState(() => _query = _query.copyWith(clearTag: true));
                            setModal(() {});
                          },
                        ),
                        for (final tag in TaskQuery.allTags(_todos))
                          FilterChip(
                            label: Text(tag),
                            selected: _query.tag == tag,
                            onSelected: (_) {
                              setState(() => _query = _query.copyWith(tag: tag));
                              setModal(() {});
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          setState(() {
                            _query = _query.copyWith(
                              clearPriority: true,
                              clearTag: true,
                              clearCategory: true,
                            );
                          });
                          Navigator.pop(ctx);
                        },
                        child: const Text('Reset filters'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsScreen(
          settings: widget.settings,
          onSettingsChanged: widget.onSettingsChanged,
          onClearCompleted: _clearCompleted,
          todos: _todos,
          onImportTodos: (imported) async {
            setState(() => _todos = imported);
            await _persist();
          },
          onExport: () => _repository.exportTodosJson(_todos),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final responsive = Responsive.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : responsive.useTwoPane
                ? Row(
                    children: [
                      SizedBox(
                        width: responsive.masterPaneWidth,
                        child: _buildMasterPane(theme, responsive, compactCards: true),
                      ),
                      VerticalDivider(
                        width: 1,
                        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                      Expanded(
                        child: _selectedTodo == null
                            ? EmptyState(
                                icon: Icons.touch_app_rounded,
                                title: 'Select a task',
                                message: 'Choose a task from the list to inspect details.',
                                actionLabel: 'New task',
                                onAction: _addTodo,
                              )
                            : TaskDetailsScreen(
                                key: ValueKey(_selectedTodo!.id),
                                todo: _selectedTodo!,
                                embedded: true,
                                onChanged: (result) => _applyDetailResult(result),
                              ),
                      ),
                    ],
                  )
                : _buildMasterPane(theme, responsive, compactCards: false),
      ),
      floatingActionButton: responsive.useTwoPane
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _addTodo(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('New Task'),
            ),
    );
  }

  Widget _buildMasterPane(ThemeData theme, Responsive responsive, {required bool compactCards}) {
    final displayed = _filtered;
    final now = DateTime.now();

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            responsive.pageHorizontalPadding,
            AppSpacing.sm,
            responsive.pageHorizontalPadding / 2,
            0,
          ),
          child: Row(
            children: [
              Expanded(
                child: _searching
                    ? TextField(
                        controller: _searchController,
                        autofocus: true,
                        decoration: const InputDecoration(
                          hintText: 'Search title, notes, tags…',
                          border: InputBorder.none,
                          filled: false,
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            DateHelpers.greeting(now),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            AppTheme.appName,
                            style: theme.textTheme.headlineSmall,
                          ),
                          Text(
                            DateFormat('EEEE, MMMM d').format(now),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
              ),
              IconButton(
                tooltip: _searching ? 'Close search' : 'Search',
                icon: Icon(_searching ? Icons.close_rounded : Icons.search_rounded),
                onPressed: () => setState(() {
                  _searching = !_searching;
                  if (!_searching) _searchController.clear();
                }),
              ),
              IconButton(
                tooltip: 'Filters',
                icon: Badge(
                  isLabelVisible: _query.priority != null || _query.tag != null,
                  child: const Icon(Icons.filter_list_rounded),
                ),
                onPressed: _showFilterSheet,
              ),
              IconButton(
                tooltip: 'Sort',
                icon: const Icon(Icons.sort_rounded),
                onPressed: _showSortSheet,
              ),
              if (responsive.useTwoPane)
                IconButton(
                  tooltip: 'New task',
                  icon: const Icon(Icons.add_rounded),
                  onPressed: () => _addTodo(),
                ),
              PopupMenuButton<String>(
                tooltip: 'More',
                onSelected: (val) {
                  if (val == 'quick') _quickAdd();
                  if (val == 'clear') _clearCompleted();
                  if (val == 'settings') _openSettings();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'quick',
                    child: ListTile(
                      leading: Icon(Icons.bolt_rounded),
                      title: Text('Quick add'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'clear',
                    child: ListTile(
                      leading: Icon(Icons.cleaning_services_outlined),
                      title: Text('Clear completed'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'settings',
                    child: ListTile(
                      leading: Icon(Icons.settings_outlined),
                      title: Text('Settings'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  responsive.pageHorizontalPadding,
                  AppSpacing.sm,
                  responsive.pageHorizontalPadding,
                  0,
                ),
                sliver: SliverToBoxAdapter(
                  child: StatsCard(
                    todos: _todos,
                    dailyGoal: widget.settings.dailyGoal,
                    streak: widget.settings.completionStreak,
                    onStatTap: (status) => setState(() => _query = _query.copyWith(status: status)),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    responsive.pageHorizontalPadding,
                    AppSpacing.md,
                    responsive.pageHorizontalPadding,
                    AppSpacing.xs,
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final status in [
                          TaskStatusFilter.today,
                          TaskStatusFilter.upcoming,
                          TaskStatusFilter.overdue,
                          TaskStatusFilter.all,
                          TaskStatusFilter.completed,
                          TaskStatusFilter.archived,
                        ])
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(_statusLabel(status)),
                              selected: _query.status == status,
                              onSelected: (_) =>
                                  setState(() => _query = _query.copyWith(status: status)),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: responsive.pageHorizontalPadding),
                    children: [
                      FilterChip(
                        label: const Text('All'),
                        selected: _query.category == null,
                        onSelected: (_) =>
                            setState(() => _query = _query.copyWith(clearCategory: true)),
                      ),
                      const SizedBox(width: 8),
                      for (final c in TaskCategory.values) ...[
                        FilterChip(
                          avatar: Icon(c.icon, size: 16, color: c.color),
                          label: Text(
                            '${c.label} (${_todos.where((t) => t.category == c && !t.archived).length})',
                          ),
                          selected: _query.category == c,
                          onSelected: (_) => setState(() {
                            _query = _query.category == c
                                ? _query.copyWith(clearCategory: true)
                                : _query.copyWith(category: c);
                          }),
                        ),
                        const SizedBox(width: 8),
                      ],
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 8)),
              if (displayed.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: EmptyState(
                    icon: _emptyIcon(),
                    title: _emptyTitle(),
                    message: _emptyMessage(),
                    actionLabel: _query.status == TaskStatusFilter.overdue ? null : 'Add task',
                    onAction: _query.status == TaskStatusFilter.overdue ? null : () => _addTodo(),
                  ),
                )
              else if (_query.status == TaskStatusFilter.today && _query.search.isEmpty)
                ..._buildGroupedSlivers(displayed, compactCards)
              else
                SliverPadding(
                  padding: EdgeInsets.only(bottom: responsive.useTwoPane ? 24 : 96),
                  sliver: SliverList.builder(
                    itemCount: displayed.length,
                    itemBuilder: (context, index) {
                      final todo = displayed[index];
                      return TaskCard(
                        todo: todo,
                        compact: compactCards,
                        selected: _selectedTodo?.id == todo.id,
                        onTap: () => _openDetails(todo),
                        onToggle: () => _toggleDone(todo),
                        onDelete: () => _removeTodo(todo),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildGroupedSlivers(List<Todo> displayed, bool compactCards) {
    final groups = TaskQuery.groupForToday(displayed);
    final slivers = <Widget>[];
    for (final entry in groups.entries) {
      if (entry.value.isEmpty) continue;
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Text(
              '${entry.key} (${entry.value.length})',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        ),
      );
      slivers.add(
        SliverList.builder(
          itemCount: entry.value.length,
          itemBuilder: (context, index) {
            final todo = entry.value[index];
            return TaskCard(
              todo: todo,
              compact: compactCards,
              selected: _selectedTodo?.id == todo.id,
              onTap: () => _openDetails(todo),
              onToggle: () => _toggleDone(todo),
              onDelete: () => _removeTodo(todo),
            );
          },
        ),
      );
    }
    slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 96)));
    return slivers;
  }

  String _statusLabel(TaskStatusFilter status) => switch (status) {
        TaskStatusFilter.today => 'Today',
        TaskStatusFilter.upcoming => 'Upcoming',
        TaskStatusFilter.overdue => 'Overdue',
        TaskStatusFilter.all => 'All',
        TaskStatusFilter.completed => 'Done',
        TaskStatusFilter.archived => 'Archive',
      };

  IconData _emptyIcon() {
    if (_searching || _query.search.isNotEmpty) return Icons.search_off_rounded;
    return switch (_query.status) {
      TaskStatusFilter.completed => Icons.check_circle_outline_rounded,
      TaskStatusFilter.overdue => Icons.done_all_rounded,
      TaskStatusFilter.upcoming => Icons.event_available_rounded,
      TaskStatusFilter.archived => Icons.inventory_2_outlined,
      _ => Icons.rocket_launch_outlined,
    };
  }

  String _emptyTitle() {
    if (_searching || _query.search.isNotEmpty) return 'No matches';
    return switch (_query.status) {
      TaskStatusFilter.completed => 'No completed tasks',
      TaskStatusFilter.overdue => 'Nothing overdue',
      TaskStatusFilter.upcoming => 'No upcoming tasks',
      TaskStatusFilter.archived => 'Archive is empty',
      TaskStatusFilter.today => 'Your day is clear',
      TaskStatusFilter.all => 'No tasks yet',
    };
  }

  String _emptyMessage() {
    if (_searching || _query.search.isNotEmpty) {
      return 'Nothing matched "${_searchController.text.trim()}".';
    }
    return switch (_query.status) {
      TaskStatusFilter.completed => 'Completed work will appear here.',
      TaskStatusFilter.overdue => 'You are caught up. Nice work.',
      TaskStatusFilter.upcoming => 'Schedule tasks ahead to fill this view.',
      TaskStatusFilter.archived => 'Archived tasks will show up here.',
      TaskStatusFilter.today => 'Add a task or schedule something for today.',
      TaskStatusFilter.all => 'Create your first task to get started.',
    };
  }
}
