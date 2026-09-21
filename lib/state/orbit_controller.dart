import 'package:flutter/foundation.dart';

import '../analytics/study_analytics.dart';
import '../data/demo_study_data.dart';
import '../models/app_settings.dart';
import '../models/study_session.dart';
import '../models/subject.dart';
import '../models/todo.dart';
import '../services/notification_service.dart';
import '../storage/todo_repository.dart';
import '../utils/date_helpers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Central offline-first app state for OrbitFlow study + tasks.
class OrbitController extends ChangeNotifier {
  OrbitController({TodoRepository? repository, NotificationService? notifications})
      : _repository = repository ?? TodoRepository(),
        _notifications = notifications ?? NotificationService.instance;

  final TodoRepository _repository;
  final NotificationService _notifications;

  List<Todo> todos = [];
  List<Subject> subjects = [];
  List<StudySession> sessions = [];
  AppSettings settings = const AppSettings();
  bool ready = false;
  bool bootstrapping = false;
  String? lastError;

  Future<void> bootstrap() async {
    if (bootstrapping) return;
    bootstrapping = true;
    lastError = null;
    try {
      await _repository.ensureMigrated().timeout(const Duration(seconds: 3));
      try {
        await _notifications.initialize().timeout(const Duration(seconds: 1));
      } catch (_) {}
      todos = await _repository.loadTodos().timeout(const Duration(seconds: 2));
      subjects = await _repository.loadSubjects().timeout(const Duration(seconds: 2));
      sessions = StudyAnalytics.refreshMissed(
        await _repository.loadSessions().timeout(const Duration(seconds: 2)),
      );
      settings = await _repository.loadSettings().timeout(const Duration(seconds: 2));
      await _persistSessions();

      try {
        await _notifications
            .syncAllSessions(
              sessions: sessions,
              subjects: subjects,
              settings: settings.notifications,
            )
            .timeout(const Duration(seconds: 3));
      } catch (_) {}
      ready = true;
      bootstrapping = false;
      notifyListeners();
    } catch (e) {
      lastError = e.toString();
      ready = true;
      bootstrapping = false;
      notifyListeners();
    }
  }

  Future<void> retryBootstrap() async {
    ready = false;
    lastError = null;
    notifyListeners();
    await bootstrap();
  }

  Future<void> updateSettings(AppSettings next) async {
    settings = next;
    await _repository.saveSettings(settings);
    await _notifications.syncAllSessions(
      sessions: sessions,
      subjects: subjects,
      settings: settings.notifications,
    );
    notifyListeners();
  }

  Future<void> _persistTodos() => _repository.saveTodos(todos);
  Future<void> _persistSubjects() => _repository.saveSubjects(subjects);
  Future<void> _persistSessions() => _repository.saveSessions(sessions);

  Future<void> _syncSessionNotifs(StudySession session) {
    final subject = subjects.cast<Subject?>().firstWhere(
          (s) => s?.id == session.subjectId,
          orElse: () => null,
        );
    return _notifications.syncSession(
      session: session,
      subject: subject,
      settings: settings.notifications,
    );
  }

  // —— Subjects ——
  Future<void> upsertSubject(Subject subject) async {
    final i = subjects.indexWhere((s) => s.id == subject.id);
    if (i == -1) {
      subjects = [...subjects, subject];
    } else {
      subjects = [...subjects]..[i] = subject;
    }
    await _persistSubjects();
    notifyListeners();
  }

  Future<void> archiveSubject(String id) async {
    subjects = subjects
        .map((s) => s.id == id ? s.copyWith(archived: true) : s)
        .toList();
    await _persistSubjects();
    notifyListeners();
  }

  // —— Sessions ——
  Future<void> upsertSession(StudySession session, {bool reschedule = false}) async {
    final i = sessions.indexWhere((s) => s.id == session.id);
    if (i == -1) {
      sessions = [session, ...sessions];
    } else {
      sessions = [...sessions]..[i] = session;
    }
    await _persistSessions();
    await _syncSessionNotifs(session);
    notifyListeners();
  }

  Future<void> deleteSession(String id) async {
    final session = sessions.cast<StudySession?>().firstWhere(
          (s) => s?.id == id,
          orElse: () => null,
        );
    sessions = sessions.where((s) => s.id != id).toList();
    await _persistSessions();
    if (session != null) {
      await _notifications.cancelSessionNotifications(session.id);
    }
    notifyListeners();
  }

  Future<void> completeSession(
    String id, {
    int? actualMinutes,
    bool fromTimer = false,
  }) async {
    final i = sessions.indexWhere((s) => s.id == id);
    if (i == -1) return;
    final current = sessions[i];
    final late = DateTime.now().isAfter(current.plannedEnd);
    final minutes = actualMinutes ?? current.plannedMinutes;
    var updated = current.copyWith(
      status: SessionStatus.completed,
      actualMinutes: minutes,
      completedAt: DateTime.now(),
      completedLate: late,
      clearFocusTimer: true,
    );
    sessions = [...sessions]..[i] = updated;

    if (updated.recurrence != RecurrenceRule.none) {
      final next = updated.spawnNextOccurrence();
      sessions = [next, ...sessions];
      await _syncSessionNotifs(next);
    }

    await _bumpStudyStreak();
    await _persistSessions();
    await _syncSessionNotifs(updated);
    notifyListeners();
  }

  Future<void> markMissed(String id) async {
    final i = sessions.indexWhere((s) => s.id == id);
    if (i == -1) return;
    final updated = sessions[i].copyWith(status: SessionStatus.missed);
    sessions = [...sessions]..[i] = updated;
    await _persistSessions();
    await _syncSessionNotifs(updated);
    notifyListeners();
  }

  Future<void> skipSession(String id) async {
    final i = sessions.indexWhere((s) => s.id == id);
    if (i == -1) return;
    final updated = sessions[i].copyWith(
      status: SessionStatus.skipped,
      clearFocusTimer: true,
    );
    sessions = [...sessions]..[i] = updated;
    await _persistSessions();
    await _syncSessionNotifs(updated);
    notifyListeners();
  }

  Future<void> rescheduleSession(String id, DateTime newStart) async {
    final i = sessions.indexWhere((s) => s.id == id);
    if (i == -1) return;
    final current = sessions[i];
    final updated = current.copyWith(
      plannedStart: newStart,
      status: SessionStatus.scheduled,
      rescheduleCount: current.rescheduleCount + 1,
      rescheduledFromId: current.id,
      clearCompletedAt: true,
      clearActual: true,
      clearFocusTimer: true,
      completedLate: false,
    );
    sessions = [...sessions]..[i] = updated;
    await _persistSessions();
    await _syncSessionNotifs(updated);
    notifyListeners();
  }

  Future<void> refreshMissedStatuses() async {
    final next = StudyAnalytics.refreshMissed(sessions);
    final changed = next.length == sessions.length &&
        List.generate(next.length, (i) => next[i].status != sessions[i].status).any((e) => e);
    if (!changed) return;
    sessions = next;
    await _persistSessions();
    await _notifications.syncAllSessions(
      sessions: sessions,
      subjects: subjects,
      settings: settings.notifications,
    );
    notifyListeners();
  }

  Future<void> _bumpStudyStreak() async {
    final today = DateHelpers.dayKey(DateTime.now());
    final last = settings.lastStudyDay;
    var streak = settings.studyStreak;
    if (last == today) {
      // already counted
    } else if (last != null) {
      final yesterday = DateHelpers.dayKey(DateTime.now().subtract(const Duration(days: 1)));
      streak = last == yesterday ? streak + 1 : 1;
    } else {
      streak = 1;
    }
    settings = settings.copyWith(studyStreak: streak, lastStudyDay: today);
    await _repository.saveSettings(settings);
  }

  // —— Todos (preserve existing behaviour) ——
  Future<void> saveTodos(List<Todo> next) async {
    todos = next;
    await _persistTodos();
    notifyListeners();
  }

  Future<String> exportBackup() {
    return _repository.exportAll(
      todos: todos,
      subjects: subjects,
      sessions: sessions,
      settings: settings,
    );
  }

  Future<void> importBackup(String raw) async {
    final data = await _repository.importAll(raw);
    todos = data['todos'] as List<Todo>? ?? todos;
    subjects = data['subjects'] as List<Subject>? ?? subjects;
    sessions = data['sessions'] as List<StudySession>? ?? sessions;
    final importedSettings = data['settings'] as AppSettings?;
    if (importedSettings != null) settings = importedSettings;
    await _persistTodos();
    await _persistSubjects();
    await _persistSessions();
    await _repository.saveSettings(settings);
    await _notifications.syncAllSessions(
      sessions: sessions,
      subjects: subjects,
      settings: settings.notifications,
    );
    notifyListeners();
  }

  Subject? subjectById(String id) {
    for (final s in subjects) {
      if (s.id == id) return s;
    }
    return null;
  }

  Topic? topicById(String subjectId, String? topicId) {
    if (topicId == null) return null;
    final subject = subjectById(subjectId);
    if (subject == null) return null;
    for (final t in subject.topics) {
      if (t.id == topicId) return t;
    }
    return null;
  }

  Future<void> seedDemoData({bool force = false}) async {
    final prefs = await SharedPreferences.getInstance();
    if (!force && (prefs.getBool(DemoStudyData.flagKey) ?? false)) return;

    subjects = DemoStudyData.subjects();
    sessions = StudyAnalytics.refreshMissed(DemoStudyData.sessionsForWeek());
    if (todos.isEmpty) {
      todos = DemoStudyData.sampleTodos();
      await _persistTodos();
    }
    settings = settings.copyWith(
      dailyStudyGoalMinutes: 240,
      weeklyStudyGoalMinutes: 1500,
      studyStreak: StudyAnalytics.studyStreakFromHistory(sessions),
      lastStudyDay: DateHelpers.dayKey(DateTime.now()),
      onboardingComplete: true,
    );
    await _persistSubjects();
    await _persistSessions();
    await _repository.saveSettings(settings);
    await prefs.setBool(DemoStudyData.flagKey, true);
    try {
      await _notifications
          .syncAllSessions(
            sessions: sessions,
            subjects: subjects,
            settings: settings.notifications,
          )
          .timeout(const Duration(seconds: 2));
    } catch (_) {}
    notifyListeners();
  }

  /// Topic progress 0–1 = completed study minutes / planned minutes for that topic.
  double topicProgress(String subjectId, String topicId) {
    final related = sessions.where(
      (s) => s.subjectId == subjectId && s.topicId == topicId && !s.archived,
    );
    var planned = 0;
    var done = 0;
    for (final s in related) {
      if (s.status.countsAsPlanned) planned += s.plannedMinutes;
      if (s.status == SessionStatus.completed) done += s.effectiveActualMinutes;
    }
    if (planned <= 0) return done > 0 ? 1 : 0;
    return (done / planned).clamp(0.0, 1.0);
  }

  /// Subject progress 0–1.
  /// If [Subject.targetHours] is set: actual studied / target hours.
  /// Else: completed minutes / planned minutes for the subject.
  double subjectProgress(String subjectId) {
    final subject = subjectById(subjectId);
    final related = sessions.where((s) => s.subjectId == subjectId && !s.archived);
    var done = 0;
    var planned = 0;
    for (final s in related) {
      if (s.status.countsAsPlanned) planned += s.plannedMinutes;
      if (s.status == SessionStatus.completed) done += s.effectiveActualMinutes;
    }
    final target = subject?.targetHours;
    if (target != null && target > 0) {
      return (done / (target * 60)).clamp(0.0, 1.0);
    }
    if (planned <= 0) return done > 0 ? 1 : 0;
    return (done / planned).clamp(0.0, 1.0);
  }

  Future<void> startFocusTimer(String id) async {
    final i = sessions.indexWhere((s) => s.id == id);
    if (i == -1) return;
    final current = sessions[i];
    if (current.status == SessionStatus.completed ||
        current.status == SessionStatus.cancelled ||
        current.status == SessionStatus.skipped) {
      return;
    }
    final updated = current.copyWith(
      status: SessionStatus.inProgress,
      focusSegmentStartedAt: DateTime.now(),
    );
    sessions = [...sessions]..[i] = updated;
    await _persistSessions();
    await _syncSessionNotifs(updated);
    notifyListeners();
  }

  Future<void> pauseFocusTimer(String id) async {
    final i = sessions.indexWhere((s) => s.id == id);
    if (i == -1) return;
    final current = sessions[i];
    if (!current.isTimerRunning) return;
    final elapsed = current.elapsedFocus();
    final updated = current.copyWith(
      status: SessionStatus.inProgress,
      focusAccumulatedSeconds: elapsed.inSeconds,
      clearFocusSegment: true,
    );
    sessions = [...sessions]..[i] = updated;
    await _persistSessions();
    notifyListeners();
  }

  Future<void> resumeFocusTimer(String id) async {
    final i = sessions.indexWhere((s) => s.id == id);
    if (i == -1) return;
    final current = sessions[i];
    if (current.status != SessionStatus.inProgress) return;
    if (current.isTimerRunning) return;
    final updated = current.copyWith(
      focusSegmentStartedAt: DateTime.now(),
    );
    sessions = [...sessions]..[i] = updated;
    await _persistSessions();
    notifyListeners();
  }

  StudySession? sessionById(String id) {
    for (final s in sessions) {
      if (s.id == id) return s;
    }
    return null;
  }
}
