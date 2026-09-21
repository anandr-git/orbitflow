import '../models/todo.dart';
import 'date_helpers.dart';

enum TaskStatusFilter { all, today, upcoming, overdue, completed, archived }

enum TaskSortOption { dueDate, priority, newest, alphabetical, manual }

class TaskQuery {
  const TaskQuery({
    this.status = TaskStatusFilter.today,
    this.category,
    this.priority,
    this.tag,
    this.search = '',
    this.sort = TaskSortOption.dueDate,
    this.includeArchived = false,
  });

  final TaskStatusFilter status;
  final TaskCategory? category;
  final TaskPriority? priority;
  final String? tag;
  final String search;
  final TaskSortOption sort;
  final bool includeArchived;

  TaskQuery copyWith({
    TaskStatusFilter? status,
    TaskCategory? category,
    bool clearCategory = false,
    TaskPriority? priority,
    bool clearPriority = false,
    String? tag,
    bool clearTag = false,
    String? search,
    TaskSortOption? sort,
    bool? includeArchived,
  }) {
    return TaskQuery(
      status: status ?? this.status,
      category: clearCategory ? null : (category ?? this.category),
      priority: clearPriority ? null : (priority ?? this.priority),
      tag: clearTag ? null : (tag ?? this.tag),
      search: search ?? this.search,
      sort: sort ?? this.sort,
      includeArchived: includeArchived ?? this.includeArchived,
    );
  }

  List<Todo> apply(List<Todo> source) {
    final query = search.trim().toLowerCase();
    final list = source.where((t) {
      if (!includeArchived && t.archived && status != TaskStatusFilter.archived) {
        return false;
      }

      final matchesStatus = switch (status) {
        TaskStatusFilter.all => !t.archived,
        TaskStatusFilter.today =>
          !t.archived && !t.done && (t.isDueToday || t.isOverdue || (t.dueDate == null && !t.done)),
        TaskStatusFilter.upcoming => !t.archived && t.isUpcoming,
        TaskStatusFilter.overdue => t.isOverdue,
        TaskStatusFilter.completed => !t.archived && t.done,
        TaskStatusFilter.archived => t.archived,
      };

      final matchesCategory = category == null || t.category == category;
      final matchesPriority = priority == null || t.priority == priority;
      final matchesTag = tag == null || t.tags.any((x) => x.toLowerCase() == tag!.toLowerCase());

      final matchesQuery = query.isEmpty ||
          t.title.toLowerCase().contains(query) ||
          t.description.toLowerCase().contains(query) ||
          t.category.label.toLowerCase().contains(query) ||
          t.priority.label.toLowerCase().contains(query) ||
          t.tags.any((tag) => tag.toLowerCase().contains(query)) ||
          t.subtasks.any((s) => s.title.toLowerCase().contains(query));

      return matchesStatus && matchesCategory && matchesPriority && matchesTag && matchesQuery;
    }).toList();

    switch (sort) {
      case TaskSortOption.dueDate:
        list.sort((a, b) {
          if (a.dueDate == null && b.dueDate == null) {
            return b.priority.sortOrder.compareTo(a.priority.sortOrder);
          }
          if (a.dueDate == null) return 1;
          if (b.dueDate == null) return -1;
          final cmp = a.dueDate!.compareTo(b.dueDate!);
          if (cmp != 0) return cmp;
          return b.priority.sortOrder.compareTo(a.priority.sortOrder);
        });
      case TaskSortOption.priority:
        list.sort((a, b) {
          final cmp = b.priority.sortOrder.compareTo(a.priority.sortOrder);
          if (cmp != 0) return cmp;
          if (a.dueDate == null && b.dueDate == null) return 0;
          if (a.dueDate == null) return 1;
          if (b.dueDate == null) return -1;
          return a.dueDate!.compareTo(b.dueDate!);
        });
      case TaskSortOption.newest:
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case TaskSortOption.alphabetical:
        list.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      case TaskSortOption.manual:
        break;
    }

    return list;
  }

  static Map<String, List<Todo>> groupForToday(List<Todo> todos) {
    final overdue = <Todo>[];
    final dueToday = <Todo>[];
    final unscheduled = <Todo>[];

    for (final t in todos) {
      if (t.done || t.archived) continue;
      if (t.isOverdue) {
        overdue.add(t);
      } else if (t.isDueToday) {
        dueToday.add(t);
      } else if (t.dueDate == null) {
        unscheduled.add(t);
      }
    }

    overdue.sort(_byPriorityThenDue);
    dueToday.sort(_byPriorityThenDue);
    unscheduled.sort(_byPriorityThenDue);

    return {
      'Overdue': overdue,
      'Due today': dueToday,
      'Unscheduled': unscheduled,
    };
  }

  static int _byPriorityThenDue(Todo a, Todo b) {
    final p = b.priority.sortOrder.compareTo(a.priority.sortOrder);
    if (p != 0) return p;
    if (a.dueDate == null && b.dueDate == null) return 0;
    if (a.dueDate == null) return 1;
    if (b.dueDate == null) return -1;
    return a.dueDate!.compareTo(b.dueDate!);
  }

  static int completedTodayCount(List<Todo> todos, {DateTime? now}) {
    now ??= DateTime.now();
    return todos.where((t) {
      if (!t.done) return false;
      final at = t.completedAt ?? t.updatedAt;
      return DateHelpers.isSameDay(at, now!);
    }).length;
  }

  static Set<String> allTags(List<Todo> todos) {
    final tags = <String>{};
    for (final t in todos) {
      tags.addAll(t.tags);
    }
    return tags;
  }
}
