import '../models/study_session.dart';
import '../models/subject.dart';
import '../models/todo.dart';
import '../utils/date_helpers.dart';

/// Realistic seeded study data for UX validation.
/// Time semantics: past = completed/missed, today = mix, future = scheduled only.
abstract final class DemoStudyData {
  static const flagKey = 'orbit_demo_seeded_v2';

  static List<Subject> subjects() {
    final exam = DateTime(2027, 2, 8);
    return [
      Subject(
        id: 'sub_os',
        name: 'Operating Systems',
        colorValue: 0xFF4F46E5,
        targetHours: 40,
        examDate: exam,
        topics: [
          Topic(id: 'os_proc', name: 'Processes'),
          Topic(id: 'os_sched', name: 'Scheduling'),
          Topic(id: 'os_mem', name: 'Memory'),
        ],
      ),
      Subject(
        id: 'sub_cn',
        name: 'Computer Networks',
        colorValue: 0xFF0284C7,
        targetHours: 35,
        examDate: exam,
        topics: [
          Topic(id: 'cn_tcp', name: 'TCP/IP'),
          Topic(id: 'cn_route', name: 'Routing'),
        ],
      ),
      Subject(
        id: 'sub_dbms',
        name: 'DBMS',
        colorValue: 0xFF0D9488,
        targetHours: 30,
        examDate: exam,
        topics: [
          Topic(id: 'db_tx', name: 'Transactions'),
          Topic(id: 'db_idx', name: 'Indexing'),
        ],
      ),
      Subject(
        id: 'sub_algo',
        name: 'Algorithms',
        colorValue: 0xFFEA580C,
        targetHours: 40,
        examDate: exam,
        topics: [
          Topic(id: 'al_graph', name: 'Graphs'),
          Topic(id: 'al_dp', name: 'Dynamic Programming'),
        ],
      ),
    ];
  }

  static List<StudySession> sessionsForWeek({DateTime? now}) {
    now ??= DateTime.now();
    final today = DateHelpers.startOfDay(now);

    StudySession s({
      required String id,
      required String title,
      required String subjectId,
      required String topicId,
      required DateTime start,
      required int minutes,
      SessionStatus status = SessionStatus.scheduled,
      int? actual,
      bool late = false,
    }) {
      return StudySession(
        id: id,
        title: title,
        subjectId: subjectId,
        topicId: topicId,
        plannedStart: start,
        plannedMinutes: minutes,
        status: status,
        actualMinutes: actual,
        completedAt: status == SessionStatus.completed
            ? start.add(Duration(minutes: actual ?? minutes))
            : null,
        completedLate: late,
        reminderMinutes: 30,
        notes: 'Demo seeded session',
        priority: TaskPriority.medium,
      );
    }

    DateTime at(DateTime day, int hour, [int minute = 0]) =>
        DateTime(day.year, day.month, day.day, hour, minute);

    final list = <StudySession>[];

    // —— Past days (relative to today) ——
    final d3 = today.subtract(const Duration(days: 3));
    final d2 = today.subtract(const Duration(days: 2));
    final d1 = today.subtract(const Duration(days: 1));

    list.addAll([
      s(
        id: 'past_os_1',
        title: 'Process concepts',
        subjectId: 'sub_os',
        topicId: 'os_proc',
        start: at(d3, 10),
        minutes: 60,
        status: SessionStatus.completed,
        actual: 55,
      ),
      s(
        id: 'past_cn_1',
        title: 'TCP handshake deep dive',
        subjectId: 'sub_cn',
        topicId: 'cn_tcp',
        start: at(d3, 16),
        minutes: 90,
        status: SessionStatus.completed,
        actual: 80,
      ),
      s(
        id: 'past_db_1',
        title: 'ACID & isolation',
        subjectId: 'sub_dbms',
        topicId: 'db_tx',
        start: at(d2, 11),
        minutes: 90,
        status: SessionStatus.completed,
        actual: 95,
        late: true,
      ),
      s(
        id: 'past_algo_miss',
        title: 'Graph traversal',
        subjectId: 'sub_algo',
        topicId: 'al_graph',
        start: at(d2, 19),
        minutes: 60,
        status: SessionStatus.missed,
      ),
      s(
        id: 'past_os_2',
        title: 'CPU Scheduling',
        subjectId: 'sub_os',
        topicId: 'os_sched',
        start: at(d1, 19),
        minutes: 90,
        status: SessionStatus.completed,
        actual: 70,
      ),
    ]);

    // —— Today ——
    // Morning completed (only if hour is late enough; otherwise schedule earlier completed at 7–8).
    final morningHour = now.hour >= 10 ? 9 : 7;
    if (now.hour > morningHour + 1) {
      list.add(
        s(
          id: 'today_done',
          title: 'Morning revision',
          subjectId: 'sub_os',
          topicId: 'os_proc',
          start: at(today, morningHour),
          minutes: 60,
          status: SessionStatus.completed,
          actual: 50,
        ),
      );
    }

    // Past-due today → will refresh to missed if still open.
    if (now.hour >= 12) {
      list.add(
        s(
          id: 'today_miss',
          title: 'Quick revision',
          subjectId: 'sub_cn',
          topicId: 'cn_tcp',
          start: at(today, (now.hour - 3).clamp(7, 11)),
          minutes: 45,
          status: SessionStatus.scheduled,
        ),
      );
    }

    // Upcoming today.
    final nextHour = (now.hour + 1).clamp(8, 21);
    list.add(
      s(
        id: 'today_next',
        title: 'Focus block',
        subjectId: 'sub_os',
        topicId: 'os_sched',
        start: at(today, nextHour),
        minutes: 90,
        status: SessionStatus.scheduled,
      ),
    );

    if (nextHour + 2 <= 22) {
      list.add(
        s(
          id: 'today_later',
          title: 'Evening review',
          subjectId: 'sub_dbms',
          topicId: 'db_idx',
          start: at(today, nextHour + 2),
          minutes: 60,
          status: SessionStatus.scheduled,
        ),
      );
    }

    // —— Future (scheduled only) ——
    final t1 = today.add(const Duration(days: 1));
    final t2 = today.add(const Duration(days: 2));
    final t3 = today.add(const Duration(days: 3));
    list.addAll([
      s(
        id: 'fut_cn',
        title: 'Routing protocols',
        subjectId: 'sub_cn',
        topicId: 'cn_route',
        start: at(t1, 10),
        minutes: 60,
      ),
      s(
        id: 'fut_db',
        title: 'B+ trees',
        subjectId: 'sub_dbms',
        topicId: 'db_idx',
        start: at(t1, 18),
        minutes: 60,
      ),
      s(
        id: 'fut_algo',
        title: 'DP patterns',
        subjectId: 'sub_algo',
        topicId: 'al_dp',
        start: at(t2, 17),
        minutes: 90,
      ),
      s(
        id: 'fut_os',
        title: 'Memory management',
        subjectId: 'sub_os',
        topicId: 'os_mem',
        start: at(t3, 11),
        minutes: 75,
      ),
    ]);

    return list;
  }

  static List<Todo> sampleTodos() {
    return [
      Todo(
        id: 'todo_demo_1',
        title: 'Revise OS notes before mock',
        category: TaskCategory.study,
        priority: TaskPriority.high,
        dueDate: DateTime.now().add(const Duration(days: 2)),
        tags: const ['exam'],
      ),
      Todo(
        id: 'todo_demo_2',
        title: 'Buy notebook',
        category: TaskCategory.personal,
        priority: TaskPriority.low,
      ),
    ];
  }
}
