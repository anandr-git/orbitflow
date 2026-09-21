import 'todo.dart';

enum SessionStatus {
  scheduled,
  inProgress,
  completed,
  missed,
  skipped,
  cancelled,
}

extension SessionStatusX on SessionStatus {
  String get label => switch (this) {
        SessionStatus.scheduled => 'Scheduled',
        SessionStatus.inProgress => 'In progress',
        SessionStatus.completed => 'Completed',
        SessionStatus.missed => 'Missed',
        SessionStatus.skipped => 'Skipped',
        SessionStatus.cancelled => 'Cancelled',
      };

  bool get countsAsPlanned =>
      this == SessionStatus.scheduled ||
      this == SessionStatus.inProgress ||
      this == SessionStatus.completed ||
      this == SessionStatus.missed;

  bool get isOpen =>
      this == SessionStatus.scheduled || this == SessionStatus.inProgress;
}

class StudySession {
  StudySession({
    required this.id,
    required this.title,
    required this.subjectId,
    this.topicId,
    this.notes = '',
    required this.plannedStart,
    required this.plannedMinutes,
    this.actualMinutes,
    this.status = SessionStatus.scheduled,
    this.priority = TaskPriority.medium,
    List<String>? tags,
    this.reminderMinutes = 30,
    this.recurrence = RecurrenceRule.none,
    this.completedAt,
    this.completedLate = false,
    this.rescheduledFromId,
    this.rescheduleCount = 0,
    this.archived = false,
    this.focusAccumulatedSeconds = 0,
    this.focusSegmentStartedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : tags = tags ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? createdAt ?? DateTime.now();

  final String id;
  String title;
  String subjectId;
  String? topicId;
  String notes;
  DateTime plannedStart;
  int plannedMinutes;
  int? actualMinutes;
  SessionStatus status;
  TaskPriority priority;
  List<String> tags;
  int? reminderMinutes;
  RecurrenceRule recurrence;
  DateTime? completedAt;
  bool completedLate;
  String? rescheduledFromId;
  int rescheduleCount;
  bool archived;

  /// Seconds already banked while paused (or before the current running segment).
  int focusAccumulatedSeconds;

  /// When the current running segment began. Null means not actively ticking.
  DateTime? focusSegmentStartedAt;

  final DateTime createdAt;
  DateTime updatedAt;

  DateTime get plannedEnd => plannedStart.add(Duration(minutes: plannedMinutes));

  bool get isDueToday {
    final now = DateTime.now();
    return plannedStart.year == now.year &&
        plannedStart.month == now.month &&
        plannedStart.day == now.day;
  }

  bool isMissedCandidate({DateTime? now}) {
    now ??= DateTime.now();
    if (!status.isOpen || archived) return false;
    // In-progress sessions are never auto-missed.
    if (status == SessionStatus.inProgress) return false;
    return now.isAfter(plannedEnd);
  }

  bool get isTimerRunning =>
      status == SessionStatus.inProgress && focusSegmentStartedAt != null;

  bool get isTimerPaused =>
      status == SessionStatus.inProgress && focusSegmentStartedAt == null;

  /// Elapsed focus time derived from timestamps (survives rebuilds / app resume).
  Duration elapsedFocus({DateTime? now}) {
    now ??= DateTime.now();
    var seconds = focusAccumulatedSeconds;
    final started = focusSegmentStartedAt;
    if (started != null) {
      seconds += now.difference(started).inSeconds.clamp(0, 24 * 3600);
    }
    return Duration(seconds: seconds.clamp(0, 24 * 3600));
  }

  int get effectiveActualMinutes =>
      actualMinutes ?? (status == SessionStatus.completed ? plannedMinutes : 0);

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subjectId': subjectId,
        'topicId': topicId,
        'notes': notes,
        'plannedStart': plannedStart.toIso8601String(),
        'plannedMinutes': plannedMinutes,
        'actualMinutes': actualMinutes,
        'status': status.name,
        'priority': priority.name,
        'tags': tags,
        'reminderMinutes': reminderMinutes,
        'recurrence': recurrence.name,
        'completedAt': completedAt?.toIso8601String(),
        'completedLate': completedLate,
        'rescheduledFromId': rescheduledFromId,
        'rescheduleCount': rescheduleCount,
        'archived': archived,
        'focusAccumulatedSeconds': focusAccumulatedSeconds,
        'focusSegmentStartedAt': focusSegmentStartedAt?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory StudySession.fromJson(Map<String, dynamic> json) {
    final rawFocusStart = json['focusSegmentStartedAt'] as String?;
    DateTime? focusStart;
    if (rawFocusStart != null) {
      final parsed = DateTime.tryParse(rawFocusStart);
      if (parsed != null && !parsed.isAfter(DateTime.now().add(const Duration(minutes: 5)))) {
        focusStart = parsed;
      }
    }
    return StudySession(
      id: (json['id'] as String?)?.trim().isNotEmpty == true
          ? json['id'] as String
          : DateTime.now().microsecondsSinceEpoch.toString(),
      title: json['title'] as String? ?? 'Study session',
      subjectId: json['subjectId'] as String? ?? '',
      topicId: json['topicId'] as String?,
      notes: json['notes'] as String? ?? '',
      plannedStart: DateTime.tryParse(json['plannedStart'] as String? ?? '') ?? DateTime.now(),
      plannedMinutes: ((json['plannedMinutes'] as num?)?.toInt() ?? 60).clamp(1, 24 * 60).toInt(),
      actualMinutes: () {
        final raw = json['actualMinutes'];
        if (raw is! num) return null;
        return raw.toInt().clamp(0, 24 * 60).toInt();
      }(),
      status: SessionStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => SessionStatus.scheduled,
      ),
      priority: TaskPriority.values.firstWhere(
        (p) => p.name == json['priority'],
        orElse: () => TaskPriority.medium,
      ),
      tags: json['tags'] == null
          ? <String>[]
          : (json['tags'] as List).map((e) => e.toString()).toList(),
      reminderMinutes: (json['reminderMinutes'] as num?)?.toInt(),
      recurrence: RecurrenceRule.values.firstWhere(
        (r) => r.name == json['recurrence'],
        orElse: () => RecurrenceRule.none,
      ),
      completedAt:
          json['completedAt'] == null ? null : DateTime.tryParse(json['completedAt'] as String),
      completedLate: json['completedLate'] as bool? ?? false,
      rescheduledFromId: json['rescheduledFromId'] as String?,
      rescheduleCount: (json['rescheduleCount'] as num?)?.toInt() ?? 0,
      archived: json['archived'] as bool? ?? false,
      focusAccumulatedSeconds:
          ((json['focusAccumulatedSeconds'] as num?)?.toInt() ?? 0).clamp(0, 24 * 3600).toInt(),
      focusSegmentStartedAt: focusStart,
      createdAt: json['createdAt'] == null
          ? DateTime.now()
          : DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now(),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.tryParse(json['updatedAt'] as String),
    );
  }

  StudySession copyWith({
    String? title,
    String? subjectId,
    String? topicId,
    bool clearTopic = false,
    String? notes,
    DateTime? plannedStart,
    int? plannedMinutes,
    int? actualMinutes,
    bool clearActual = false,
    SessionStatus? status,
    TaskPriority? priority,
    List<String>? tags,
    int? reminderMinutes,
    bool clearReminder = false,
    RecurrenceRule? recurrence,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    bool? completedLate,
    String? rescheduledFromId,
    int? rescheduleCount,
    bool? archived,
    int? focusAccumulatedSeconds,
    DateTime? focusSegmentStartedAt,
    bool clearFocusSegment = false,
    bool clearFocusTimer = false,
    DateTime? updatedAt,
  }) {
    return StudySession(
      id: id,
      title: title ?? this.title,
      subjectId: subjectId ?? this.subjectId,
      topicId: clearTopic ? null : (topicId ?? this.topicId),
      notes: notes ?? this.notes,
      plannedStart: plannedStart ?? this.plannedStart,
      plannedMinutes: plannedMinutes ?? this.plannedMinutes,
      actualMinutes: clearActual ? null : (actualMinutes ?? this.actualMinutes),
      status: status ?? this.status,
      priority: priority ?? this.priority,
      tags: tags ?? List<String>.from(this.tags),
      reminderMinutes: clearReminder ? null : (reminderMinutes ?? this.reminderMinutes),
      recurrence: recurrence ?? this.recurrence,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      completedLate: completedLate ?? this.completedLate,
      rescheduledFromId: rescheduledFromId ?? this.rescheduledFromId,
      rescheduleCount: rescheduleCount ?? this.rescheduleCount,
      archived: archived ?? this.archived,
      focusAccumulatedSeconds: clearFocusTimer
          ? 0
          : (focusAccumulatedSeconds ?? this.focusAccumulatedSeconds),
      focusSegmentStartedAt: clearFocusTimer || clearFocusSegment
          ? null
          : (focusSegmentStartedAt ?? this.focusSegmentStartedAt),
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  StudySession spawnNextOccurrence() {
    final nextStart = switch (recurrence) {
      RecurrenceRule.daily => plannedStart.add(const Duration(days: 1)),
      RecurrenceRule.weekly => plannedStart.add(const Duration(days: 7)),
      RecurrenceRule.monthly => DateTime(
          plannedStart.year,
          plannedStart.month + 1,
          plannedStart.day,
          plannedStart.hour,
          plannedStart.minute,
        ),
      RecurrenceRule.none => plannedStart,
    };
    return StudySession(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      subjectId: subjectId,
      topicId: topicId,
      notes: notes,
      plannedStart: nextStart,
      plannedMinutes: plannedMinutes,
      priority: priority,
      tags: List<String>.from(tags),
      reminderMinutes: reminderMinutes,
      recurrence: recurrence,
    );
  }
}
