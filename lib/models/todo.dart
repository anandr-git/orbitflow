import 'package:flutter/material.dart';

enum TaskCategory { study, work, fitness, personal }

extension TaskCategoryX on TaskCategory {
  String get label => switch (this) {
        TaskCategory.study => 'Study',
        TaskCategory.work => 'Work',
        TaskCategory.fitness => 'Fitness',
        TaskCategory.personal => 'Personal',
      };

  IconData get icon => switch (this) {
        TaskCategory.study => Icons.menu_book_rounded,
        TaskCategory.work => Icons.work_rounded,
        TaskCategory.fitness => Icons.fitness_center_rounded,
        TaskCategory.personal => Icons.person_rounded,
      };

  Color get color => switch (this) {
        TaskCategory.study => const Color(0xFF2563EB),
        TaskCategory.work => const Color(0xFFEA580C),
        TaskCategory.fitness => const Color(0xFF16A34A),
        TaskCategory.personal => const Color(0xFF9333EA),
      };
}

enum TaskPriority { low, medium, high, urgent }

extension TaskPriorityX on TaskPriority {
  String get label => switch (this) {
        TaskPriority.low => 'Low',
        TaskPriority.medium => 'Medium',
        TaskPriority.high => 'High',
        TaskPriority.urgent => 'Urgent',
      };

  Color get color => switch (this) {
        TaskPriority.low => const Color(0xFF64748B),
        TaskPriority.medium => const Color(0xFF2563EB),
        TaskPriority.high => const Color(0xFFEA580C),
        TaskPriority.urgent => const Color(0xFFDC2626),
      };

  IconData get icon => switch (this) {
        TaskPriority.low => Icons.arrow_downward_rounded,
        TaskPriority.medium => Icons.remove_rounded,
        TaskPriority.high => Icons.arrow_upward_rounded,
        TaskPriority.urgent => Icons.priority_high_rounded,
      };

  int get sortOrder => switch (this) {
        TaskPriority.urgent => 4,
        TaskPriority.high => 3,
        TaskPriority.medium => 2,
        TaskPriority.low => 1,
      };
}

enum RecurrenceRule { none, daily, weekly, monthly }

extension RecurrenceRuleX on RecurrenceRule {
  String get label => switch (this) {
        RecurrenceRule.none => 'Does not repeat',
        RecurrenceRule.daily => 'Daily',
        RecurrenceRule.weekly => 'Weekly',
        RecurrenceRule.monthly => 'Monthly',
      };

  IconData get icon => switch (this) {
        RecurrenceRule.none => Icons.event_busy_rounded,
        RecurrenceRule.daily => Icons.today_rounded,
        RecurrenceRule.weekly => Icons.date_range_rounded,
        RecurrenceRule.monthly => Icons.calendar_month_rounded,
      };
}

class Subtask {
  Subtask({
    required this.id,
    required this.title,
    this.isDone = false,
  });

  final String id;
  String title;
  bool isDone;

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'isDone': isDone,
      };

  factory Subtask.fromJson(Map<String, dynamic> json) => Subtask(
        id: json['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString(),
        title: json['title'] as String? ?? '',
        isDone: json['isDone'] as bool? ?? false,
      );

  Subtask copyWith({String? title, bool? isDone}) {
    return Subtask(
      id: id,
      title: title ?? this.title,
      isDone: isDone ?? this.isDone,
    );
  }
}

class Todo {
  Todo({
    required this.id,
    required this.title,
    this.description = '',
    this.category = TaskCategory.personal,
    this.priority = TaskPriority.medium,
    this.dueDate,
    this.done = false,
    List<Subtask>? subtasks,
    List<String>? tags,
    this.recurrence = RecurrenceRule.none,
    this.reminderMinutes,
    this.estimatedMinutes,
    this.archived = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.completedAt,
  })  : subtasks = subtasks ?? [],
        tags = tags ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? createdAt ?? DateTime.now();

  final String id;
  String title;
  String description;
  TaskCategory category;
  TaskPriority priority;
  DateTime? dueDate;
  bool done;
  List<Subtask> subtasks;
  List<String> tags;
  RecurrenceRule recurrence;
  int? reminderMinutes;
  int? estimatedMinutes;
  bool archived;
  final DateTime createdAt;
  DateTime updatedAt;
  DateTime? completedAt;

  bool get isOverdue {
    if (done || archived || dueDate == null) return false;
    return dueDate!.isBefore(DateTime.now());
  }

  bool get isDueToday {
    if (dueDate == null) return false;
    final now = DateTime.now();
    return dueDate!.year == now.year &&
        dueDate!.month == now.month &&
        dueDate!.day == now.day;
  }

  bool get isUpcoming {
    if (done || archived || dueDate == null) return false;
    final now = DateTime.now();
    final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59);
    return dueDate!.isAfter(todayEnd);
  }

  int get completedSubtasksCount => subtasks.where((s) => s.isDone).length;

  double get subtaskProgress =>
      subtasks.isEmpty ? 0 : completedSubtasksCount / subtasks.length;

  String get subtasksSummary =>
      subtasks.isEmpty ? '' : '$completedSubtasksCount/${subtasks.length}';

  bool get hasNotes => description.trim().isNotEmpty;

  bool get hasTags => tags.isNotEmpty;

  bool get isRecurring => recurrence != RecurrenceRule.none;

  DateTime? nextOccurrenceAfter(DateTime from) {
    if (recurrence == RecurrenceRule.none) return null;
    var cursor = from;
    final now = DateTime.now();
    // Catch up so next occurrence is at/after today when completing overdue work.
    while (cursor.isBefore(DateTime(now.year, now.month, now.day))) {
      cursor = _advance(cursor);
    }
    if (!cursor.isAfter(from)) {
      cursor = _advance(from);
    }
    return cursor;
  }

  DateTime _advance(DateTime from) {
    return switch (recurrence) {
      RecurrenceRule.daily => from.add(const Duration(days: 1)),
      RecurrenceRule.weekly => from.add(const Duration(days: 7)),
      RecurrenceRule.monthly => DateTime(
          from.year,
          from.month + 1,
          from.day,
          from.hour,
          from.minute,
        ),
      RecurrenceRule.none => from,
    };
  }

  /// Creates the follow-up instance after completing a recurring task.
  Todo spawnNextOccurrence() {
    final base = dueDate ?? DateTime.now();
    final nextDue = nextOccurrenceAfter(base) ?? _advance(base);
    return Todo(
      id: '${DateTime.now().microsecondsSinceEpoch}',
      title: title,
      description: description,
      category: category,
      priority: priority,
      dueDate: nextDue,
      done: false,
      subtasks: subtasks
          .map((s) => Subtask(id: '${s.id}-next', title: s.title, isDone: false))
          .toList(),
      tags: List<String>.from(tags),
      recurrence: recurrence,
      reminderMinutes: reminderMinutes,
      estimatedMinutes: estimatedMinutes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'category': category.name,
        'priority': priority.name,
        'dueDate': dueDate?.toIso8601String(),
        'done': done,
        'subtasks': subtasks.map((s) => s.toJson()).toList(),
        'tags': tags,
        'recurrence': recurrence.name,
        'reminderMinutes': reminderMinutes,
        'estimatedMinutes': estimatedMinutes,
        'archived': archived,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
      };

  factory Todo.fromJson(Map<String, dynamic> json) {
    List<Subtask> parsedSubtasks = [];
    if (json['subtasks'] != null) {
      parsedSubtasks = (json['subtasks'] as List)
          .map((item) => Subtask.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    List<String> parsedTags = [];
    if (json['tags'] != null) {
      parsedTags = (json['tags'] as List).map((e) => e.toString()).toList();
    }

    return Todo(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      category: TaskCategory.values.firstWhere(
        (c) => c.name == json['category'],
        orElse: () => TaskCategory.personal,
      ),
      priority: TaskPriority.values.firstWhere(
        (p) => p.name == json['priority'],
        orElse: () => TaskPriority.medium,
      ),
      dueDate: json['dueDate'] == null ? null : DateTime.tryParse(json['dueDate'] as String),
      done: json['done'] as bool? ?? false,
      subtasks: parsedSubtasks,
      tags: parsedTags,
      recurrence: RecurrenceRule.values.firstWhere(
        (r) => r.name == json['recurrence'],
        orElse: () => RecurrenceRule.none,
      ),
      reminderMinutes: json['reminderMinutes'] as int?,
      estimatedMinutes: json['estimatedMinutes'] as int?,
      archived: json['archived'] as bool? ?? false,
      createdAt: json['createdAt'] == null
          ? DateTime.now()
          : DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now(),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.tryParse(json['updatedAt'] as String),
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.tryParse(json['completedAt'] as String),
    );
  }

  Todo copyWith({
    String? title,
    String? description,
    TaskCategory? category,
    TaskPriority? priority,
    DateTime? dueDate,
    bool clearDueDate = false,
    bool? done,
    List<Subtask>? subtasks,
    List<String>? tags,
    RecurrenceRule? recurrence,
    int? reminderMinutes,
    bool clearReminder = false,
    int? estimatedMinutes,
    bool clearEstimated = false,
    bool? archived,
    DateTime? updatedAt,
    DateTime? completedAt,
    bool clearCompletedAt = false,
  }) {
    return Todo(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      done: done ?? this.done,
      subtasks: subtasks ?? this.subtasks.map((s) => s.copyWith()).toList(),
      tags: tags ?? List<String>.from(this.tags),
      recurrence: recurrence ?? this.recurrence,
      reminderMinutes: clearReminder ? null : (reminderMinutes ?? this.reminderMinutes),
      estimatedMinutes: clearEstimated ? null : (estimatedMinutes ?? this.estimatedMinutes),
      archived: archived ?? this.archived,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
    );
  }
}
