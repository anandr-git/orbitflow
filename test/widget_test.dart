import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbitflow/analytics/study_analytics.dart';
import 'package:orbitflow/data/demo_study_data.dart';
import 'package:orbitflow/main.dart';
import 'package:orbitflow/models/app_settings.dart';
import 'package:orbitflow/models/study_session.dart';
import 'package:orbitflow/models/subject.dart';
import 'package:orbitflow/models/todo.dart';
import 'package:orbitflow/screens/add_task_screen.dart';
import 'package:orbitflow/screens/onboarding_screen.dart';
import 'package:orbitflow/screens/app_shell.dart';
import 'package:orbitflow/screens/insights_screen.dart';
import 'package:orbitflow/screens/study_home_screen.dart';
import 'package:orbitflow/screens/subject_detail_screen.dart';
import 'package:orbitflow/screens/task_details_screen.dart';
import 'package:orbitflow/screens/week_screen.dart';
import 'package:orbitflow/state/orbit_controller.dart';
import 'package:orbitflow/storage/todo_repository.dart';
import 'package:orbitflow/theme/app_theme.dart';
import 'package:orbitflow/utils/date_helpers.dart';
import 'package:orbitflow/utils/task_query.dart';
import 'package:orbitflow/widgets/empty_state.dart';
import 'package:orbitflow/widgets/stats_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Todo model', () {
    test('serializes with backward-compatible defaults', () {
      final todo = Todo(
        id: '123',
        title: 'Ship Orbit',
        tags: const ['release'],
        recurrence: RecurrenceRule.weekly,
      );
      final restored = Todo.fromJson(todo.toJson());
      expect(restored.tags, ['release']);
      expect(restored.recurrence, RecurrenceRule.weekly);
    });

    test('legacy JSON without new keys still loads', () {
      final todo = Todo.fromJson({
        'id': 'legacy',
        'title': 'Old task',
        'category': 'personal',
        'priority': 'medium',
        'done': false,
      });
      expect(todo.tags, isEmpty);
      expect(todo.recurrence, RecurrenceRule.none);
    });
  });

  group('Study models', () {
    test('subject/topic/session round-trip', () {
      final subject = Subject(
        id: 's1',
        name: 'Operating Systems',
        topics: [Topic(id: 't1', name: 'CPU Scheduling')],
      );
      final session = StudySession(
        id: 'sess1',
        title: 'Scheduling deep dive',
        subjectId: subject.id,
        topicId: 't1',
        plannedStart: DateTime(2026, 9, 22, 19),
        plannedMinutes: 90,
        reminderMinutes: 30,
        recurrence: RecurrenceRule.weekly,
      );

      final s2 = Subject.fromJson(subject.toJson());
      final sess2 = StudySession.fromJson(session.toJson());
      expect(s2.name, 'Operating Systems');
      expect(s2.topics.single.name, 'CPU Scheduling');
      expect(sess2.plannedMinutes, 90);
      expect(sess2.reminderMinutes, 30);
      expect(sess2.recurrence, RecurrenceRule.weekly);
    });

    test('missed candidate and spawn next', () {
      final overdue = StudySession(
        id: '1',
        title: 'Late',
        subjectId: 's',
        plannedStart: DateTime.now().subtract(const Duration(hours: 3)),
        plannedMinutes: 60,
      );
      expect(overdue.isMissedCandidate(), isTrue);
      final next = overdue.copyWith(recurrence: RecurrenceRule.daily).spawnNextOccurrence();
      expect(next.id, isNot(equals(overdue.id)));
      expect(next.status, SessionStatus.scheduled);
    });
  });

  group('Study analytics', () {
    test('day/week planned vs completed + streak', () {
      // Pin clock so refreshMissed assertions are stable across wall-clock hours.
      final now = DateTime(2026, 9, 22, 18, 0);
      final todayStart = DateTime(now.year, now.month, now.day, 10);
      final sessions = [
        StudySession(
          id: '1',
          title: 'A',
          subjectId: 's',
          plannedStart: todayStart,
          plannedMinutes: 90,
          status: SessionStatus.completed,
          actualMinutes: 70,
          completedAt: todayStart.add(const Duration(hours: 2)),
        ),
        StudySession(
          id: '2',
          title: 'B',
          subjectId: 's',
          plannedStart: todayStart.add(const Duration(hours: 4)),
          plannedMinutes: 60,
          status: SessionStatus.scheduled,
        ),
        StudySession(
          id: '3',
          title: 'C',
          subjectId: 's',
          plannedStart: todayStart.subtract(const Duration(days: 1)),
          plannedMinutes: 60,
          status: SessionStatus.missed,
        ),
      ];

      final day = StudyAnalytics.dayStats(sessions, now);
      expect(day.plannedMinutes, 150);
      expect(day.completedMinutes, 70);

      final refreshed = StudyAnalytics.refreshMissed(sessions, now: now);
      expect(refreshed[1].status, SessionStatus.missed);

      expect(StudyAnalytics.studyStreakFromHistory(sessions), greaterThanOrEqualTo(1));
      expect(StudyAnalytics.formatMinutes(90), '1h 30m');
    });

    test('quiet hours wrap midnight', () {
      const n = NotificationSettings(
        quietStartHour: 22,
        quietStartMinute: 30,
        quietEndHour: 7,
        quietEndMinute: 0,
      );
      expect(n.isQuietAt(DateTime(2026, 9, 21, 23, 0)), isTrue);
      expect(n.isQuietAt(DateTime(2026, 9, 21, 6, 0)), isTrue);
      expect(n.isQuietAt(DateTime(2026, 9, 21, 12, 0)), isFalse);
    });
  });

  group('Repository migration', () {
    test('settings and study collections persist', () async {
      SharedPreferences.setMockInitialValues({'dark_mode': true, 'theme_color_index': 1});
      final repo = TodoRepository();
      final settings = await repo.loadSettings();
      expect(settings.themePreference, ThemePreference.dark);

      final subject = Subject(id: 's', name: 'Networks');
      await repo.saveSubjects([subject]);
      final session = StudySession(
        id: 'x',
        title: 'TCP',
        subjectId: 's',
        plannedStart: DateTime.now(),
        plannedMinutes: 45,
      );
      await repo.saveSessions([session]);
      expect((await repo.loadSubjects()).single.name, 'Networks');
      expect((await repo.loadSessions()).single.title, 'TCP');

      final backup = await repo.exportAll(
        todos: [],
        subjects: [subject],
        sessions: [session],
        settings: settings,
      );
      final imported = await repo.importAll(backup);
      expect((imported['subjects'] as List).length, 1);
      expect((imported['sessions'] as List).length, 1);
    });
  });

  group('TaskQuery', () {
    test('search and overdue filter', () {
      final todos = [
        Todo(
          id: '1',
          title: 'Fix',
          description: 'analyzer',
          dueDate: DateTime.now().subtract(const Duration(hours: 1)),
          tags: const ['qa'],
        ),
      ];
      expect(const TaskQuery(status: TaskStatusFilter.overdue).apply(todos).length, 1);
      expect(const TaskQuery(status: TaskStatusFilter.all, search: 'qa').apply(todos).length, 1);
    });
  });

  group('Widgets', () {
    testWidgets('StatsCard and EmptyState', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                StatsCard(todos: [Todo(id: '1', title: 'A', done: true, completedAt: DateTime.now())]),
                EmptyState(
                  icon: Icons.inbox,
                  title: 'Empty',
                  message: 'None',
                  actionLabel: 'Go',
                  onAction: () {},
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.text('Empty'), findsOneWidget);
    });

    testWidgets('MyApp shows Orbit study shell', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const MyApp());
      await tester.pump(const Duration(seconds: 6));
      await tester.pump();
      // Complete onboarding if shown.
      if (find.text('Skip').evaluate().isNotEmpty) {
        await tester.tap(find.text('Skip'));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.pump();
      }
      expect(find.text(AppTheme.appName), findsWidgets);
      expect(find.text('Study'), findsOneWidget);
    });

    testWidgets('Onboarding welcome is skippable', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final c = OrbitController();
      await c.bootstrap();
      await tester.pumpWidget(
        MaterialApp(home: OnboardingScreen(controller: c)),
      );
      await tester.pump();
      expect(find.textContaining('Welcome'), findsOneWidget);
      await tester.tap(find.text('Skip'));
      await tester.pump();
      expect(c.settings.onboardingComplete, isTrue);
    });

    testWidgets('AddTaskScreen validates title', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: AddTaskScreen()));
      await tester.tap(find.text('Save'));
      await tester.pump();
      expect(find.text('Please enter a task title'), findsOneWidget);
    });

    testWidgets('TaskDetailsScreen toggles completion', (tester) async {
      final todo = Todo(id: '9', title: 'Review', priority: TaskPriority.urgent);
      await tester.pumpWidget(MaterialApp(home: TaskDetailsScreen(todo: todo)));
      expect(find.text('Pending'), findsOneWidget);
      await tester.tap(find.text('Pending'));
      await tester.pump();
      expect(find.text('Tap to reopen'), findsOneWidget);
    });
  });

  group('DateHelpers', () {
    test('greeting', () {
      expect(DateHelpers.greeting(DateTime(2026, 1, 1, 9)), 'Good morning');
    });
  });

  group('Demo study data', () {
    test('seeds subjects topics and mixed statuses', () {
      final subjects = DemoStudyData.subjects();
      expect(subjects.length, 4);
      expect(subjects.map((s) => s.name), contains('Operating Systems'));
      final now = DateTime(2026, 9, 21, 15);
      final sessions = DemoStudyData.sessionsForWeek(now: now);
      expect(sessions.length, greaterThanOrEqualTo(8));
      expect(sessions.any((s) => s.status == SessionStatus.completed), isTrue);
      expect(sessions.any((s) => s.status == SessionStatus.missed), isTrue);
      // Future-dated sessions must not be completed.
      for (final s in sessions) {
        if (s.plannedStart.isAfter(now.add(const Duration(hours: 1)))) {
          expect(s.status, SessionStatus.scheduled);
        }
      }
    });
  });

  group('Focus timer state machine', () {
    test('elapsed uses timestamps across pause/resume', () async {
      SharedPreferences.setMockInitialValues({});
      final c = OrbitController();
      await c.bootstrap();
      final session = StudySession(
        id: 'timer1',
        title: 'Timer',
        subjectId: 's',
        plannedStart: DateTime.now(),
        plannedMinutes: 60,
      );
      await c.upsertSession(session);
      expect(c.sessionById('timer1')!.status, SessionStatus.scheduled);

      await c.startFocusTimer('timer1');
      final running = c.sessionById('timer1')!;
      expect(running.status, SessionStatus.inProgress);
      expect(running.isTimerRunning, isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      await c.pauseFocusTimer('timer1');
      final paused = c.sessionById('timer1')!;
      expect(paused.isTimerPaused, isTrue);
      expect(paused.focusAccumulatedSeconds, greaterThanOrEqualTo(0));

      await c.resumeFocusTimer('timer1');
      expect(c.sessionById('timer1')!.isTimerRunning, isTrue);

      await c.pauseFocusTimer('timer1');
      final banked = c.sessionById('timer1')!.focusAccumulatedSeconds;
      final restored = c.sessionById('timer1')!.copyWith(
        focusAccumulatedSeconds: banked + 120,
        clearFocusSegment: true,
      );
      await c.upsertSession(restored);
      expect(c.sessionById('timer1')!.elapsedFocus().inSeconds, greaterThanOrEqualTo(120));
    });

    test('opening focus does not auto-start without startFocusTimer', () async {
      SharedPreferences.setMockInitialValues({});
      final c = OrbitController();
      await c.bootstrap();
      final session = StudySession(
        id: 'nos',
        title: 'No auto',
        subjectId: 's',
        plannedStart: DateTime.now().add(const Duration(hours: 1)),
        plannedMinutes: 45,
      );
      await c.upsertSession(session);
      expect(c.sessionById('nos')!.status, SessionStatus.scheduled);
      expect(c.sessionById('nos')!.isTimerRunning, isFalse);
    });

    test('subject progress uses target hours when set', () async {
      SharedPreferences.setMockInitialValues({});
      final c = OrbitController();
      await c.bootstrap();
      await c.seedDemoData(force: true);
      final p = c.subjectProgress('sub_os');
      expect(p, lessThan(0.5));
      expect(StudyAnalytics.countLabel(1, 'session'), '1 session');
      expect(StudyAnalytics.countLabel(2, 'session'), '2 sessions');
    });

    test('in-progress sessions are not auto-missed', () {
      final s = StudySession(
        id: 'ip',
        title: 'Running',
        subjectId: 's',
        plannedStart: DateTime.now().subtract(const Duration(hours: 3)),
        plannedMinutes: 60,
        status: SessionStatus.inProgress,
        focusSegmentStartedAt: DateTime.now().subtract(const Duration(minutes: 10)),
      );
      expect(s.isMissedCandidate(), isFalse);
      final refreshed = StudyAnalytics.refreshMissed([s]).single;
      expect(refreshed.status, SessionStatus.inProgress);
    });
  });

  group('OrbitController study flow', () {
    test('create complete reschedule and topic progress', () async {
      SharedPreferences.setMockInitialValues({});
      final c = OrbitController();
      await c.bootstrap();
      await c.seedDemoData(force: true);

      expect(c.subjects.length, 4);
      expect(c.sessions, isNotEmpty);
      expect(c.topicProgress('sub_os', 'os_proc'), greaterThan(0));

      final session = StudySession(
        id: 'flow1',
        title: 'CPU Scheduling',
        subjectId: 'sub_os',
        topicId: 'os_sched',
        plannedStart: DateTime.now().add(const Duration(hours: 2)),
        plannedMinutes: 90,
        reminderMinutes: 30,
      );
      await c.upsertSession(session);
      expect(c.sessions.any((s) => s.id == 'flow1'), isTrue);

      await c.completeSession('flow1', actualMinutes: 84, fromTimer: true);
      expect(c.sessions.firstWhere((s) => s.id == 'flow1').status, SessionStatus.completed);
      expect(c.sessions.firstWhere((s) => s.id == 'flow1').actualMinutes, 84);

      final open = StudySession(
        id: 'flow2',
        title: 'TCP',
        subjectId: 'sub_cn',
        topicId: 'cn_tcp',
        plannedStart: DateTime.now().add(const Duration(hours: 3)),
        plannedMinutes: 60,
      );
      await c.upsertSession(open);
      final newStart = DateTime.now().add(const Duration(days: 1, hours: 1));
      await c.rescheduleSession('flow2', newStart);
      final moved = c.sessions.firstWhere((s) => s.id == 'flow2');
      expect(moved.status, SessionStatus.scheduled);
      expect(moved.rescheduleCount, 1);

      await c.skipSession('flow2');
      expect(c.sessions.firstWhere((s) => s.id == 'flow2').status, SessionStatus.skipped);

      final backup = await c.exportBackup();
      expect(backup.contains('Operating Systems'), isTrue);
      SharedPreferences.setMockInitialValues({});
      final c2 = OrbitController();
      await c2.bootstrap();
      await c2.importBackup(backup);
      expect(c2.subjects.any((s) => s.name == 'Operating Systems'), isTrue);
      expect(c2.sessions.any((s) => s.id == 'flow1'), isTrue);
    });
  });

  group('Study UI screens', () {
    testWidgets('Study home shows today command center', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final c = OrbitController();
      await c.bootstrap();
      await c.seedDemoData(force: true);
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: StudyHomeScreen(controller: c))),
      );
      await tester.pump();
      expect(find.textContaining("Today"), findsWidgets);
      expect(find.textContaining('Up next'), findsWidgets);
    });

    testWidgets('Week planner shows summary', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final c = OrbitController();
      await c.bootstrap();
      await c.seedDemoData(force: true);
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: WeekScreen(controller: c))),
      );
      await tester.pump();
      expect(find.text('This week'), findsOneWidget);
      expect(find.text('Week planner'), findsOneWidget);
    });

    testWidgets('Insights month and subjects', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final c = OrbitController();
      await c.bootstrap();
      await c.seedDemoData(force: true);
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: InsightsScreen(controller: c))),
      );
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('This month'), findsOneWidget);
    });

    testWidgets('Subject detail shows topics', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final c = OrbitController();
      await c.bootstrap();
      await c.seedDemoData(force: true);
      await tester.pumpWidget(
        MaterialApp(
          home: SubjectDetailScreen(controller: c, subjectId: 'sub_os'),
        ),
      );
      await tester.pump();
      expect(find.text('Operating Systems'), findsWidgets);
      expect(find.text('Scheduling'), findsOneWidget);
    });

    testWidgets('compact and expanded shells layout', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final c = OrbitController();
      await c.bootstrap();

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: MaterialApp(home: AppShell(controller: c)),
        ),
      );
      await tester.pump();
      expect(find.byType(NavigationBar), findsOneWidget);

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(1024, 768)),
          child: MaterialApp(home: AppShell(controller: c)),
        ),
      );
      await tester.pump();
      expect(find.byType(NavigationRail), findsOneWidget);
    });
  });

  group('Backup import hardening', () {
    test('rejects empty and non-json', () async {
      final repo = TodoRepository();
      expect(() => repo.importAll(''), throwsFormatException);
      expect(() => repo.importAll('not-json'), throwsFormatException);
    });

    test('skips malformed session rows and forces onboardingComplete', () async {
      final repo = TodoRepository();
      final raw = '''
{
  "schemaVersion": 3,
  "todos": [],
  "subjects": [{"id":"s1","name":"OS","topics":[]}],
  "sessions": [
    {"id":"ok","title":"Good","subjectId":"s1","plannedStart":"2026-09-21T10:00:00.000","plannedMinutes":60},
    {"bad": true},
    {"id":"evil","subjectId":"s1","plannedStart":"2026-09-21T11:00:00.000","plannedMinutes":-999999,"focusAccumulatedSeconds":-50,"focusSegmentStartedAt":"2099-01-01T00:00:00.000"}
  ],
  "settings": {"onboardingComplete": false, "dailyStudyGoalMinutes": 120}
}
''';
      final data = await repo.importAll(raw);
      final sessions = data['sessions'] as List<StudySession>;
      expect(sessions.length, 2);
      expect(sessions.first.plannedMinutes, 60);
      final evil = sessions.last;
      expect(evil.plannedMinutes, greaterThan(0));
      expect(evil.focusAccumulatedSeconds, greaterThanOrEqualTo(0));
      expect(evil.focusSegmentStartedAt, isNull);
      final settings = data['settings'] as AppSettings;
      expect(settings.onboardingComplete, isTrue);
    });
  });
}
