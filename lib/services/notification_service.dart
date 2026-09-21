import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/app_settings.dart';
import '../models/study_session.dart';
import '../models/subject.dart';
import '../analytics/study_analytics.dart';

/// Real device local notifications for OrbitFlow study sessions.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _channelId = 'orbit_study';
  static const _channelName = 'OrbitFlow Study';
  static const _channelDesc = 'Study session reminders and progress alerts';

  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    if (_initialized) return;
    try {
      tzdata.initializeTimeZones();
      try {
        final info = await FlutterTimezone.getLocalTimezone()
            .timeout(const Duration(milliseconds: 800));
        tz.setLocalLocation(tz.getLocation(info.identifier));
      } catch (_) {
        tz.setLocalLocation(tz.UTC);
      }

      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const darwin = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const init = InitializationSettings(android: android, iOS: darwin, macOS: darwin);

      await _plugin.initialize(settings: init).timeout(const Duration(seconds: 2));
    } catch (_) {
      // Tests / unsupported platforms — keep app usable offline.
    }
    _initialized = true;
  }

  Future<bool> requestPermissions() async {
    if (kIsWeb) return false;
    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final notif = await android?.requestNotificationsPermission() ?? false;
      await android?.requestExactAlarmsPermission();
      return notif;
    }
    if (Platform.isIOS || Platform.isMacOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final mac = _plugin.resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin>();
      final result = await ios?.requestPermissions(alert: true, badge: true, sound: true) ??
          await mac?.requestPermissions(alert: true, badge: true, sound: true) ??
          false;
      return result;
    }
    return false;
  }

  Future<bool> areNotificationsEnabled() async {
    if (kIsWeb) return false;
    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await android?.areNotificationsEnabled() ?? false;
    }
    return true;
  }

  /// Immediate test notification — used to verify the pipeline really works.
  Future<void> showTestNotification() async {
    await _plugin.show(
      id: 900001,
      title: 'OrbitFlow notifications ready',
      body: 'Local device notifications are working on this device.',
      notificationDetails: _details(),
      payload: 'test',
    );
  }

  /// Schedule a notification ~N seconds from now for emulator verification.
  Future<void> scheduleVerificationPing({int seconds = 15}) async {
    final when = tz.TZDateTime.now(tz.local).add(Duration(seconds: seconds));
    await _plugin.zonedSchedule(
      id: 900002,
      scheduledDate: when,
      title: 'OrbitFlow schedule check',
      body: 'This scheduled ping fired after ${seconds}s.',
      notificationDetails: _details(),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: 'verify',
    );
  }

  Future<void> cancelSessionNotifications(String sessionId) async {
    try {
      final base = _stableId(sessionId);
      await _plugin.cancel(id: base);
      await _plugin.cancel(id: base + 1);
      await _plugin.cancel(id: base + 2);
    } catch (_) {}
  }

  Future<void> cancelAllOrbit() async {
    try {
      await _plugin.cancelAll();
    } catch (_) {}
  }

  Future<void> syncSession({
    required StudySession session,
    required Subject? subject,
    required NotificationSettings settings,
  }) async {
    try {
      await cancelSessionNotifications(session.id);
      if (!settings.enabled) return;
      if (session.archived) return;
      if (session.status == SessionStatus.completed ||
          session.status == SessionStatus.cancelled ||
          session.status == SessionStatus.skipped) {
        return;
      }

      final subjectName = subject?.name ?? 'Study';
      final base = _stableId(session.id);

      // Reminder before start
      if (settings.sessionReminders &&
          session.reminderMinutes != null &&
          session.status.isOpen) {
        final remindAt = session.plannedStart.subtract(
          Duration(minutes: session.reminderMinutes!),
        );
        await _scheduleIfFuture(
          id: base,
          when: remindAt,
          title: 'Upcoming study',
          body:
              '$subjectName — ${session.title} starts in ${session.reminderMinutes} minutes.',
          settings: settings,
          critical: false,
          payload: 'session:${session.id}:remind',
        );
      }

      // Start notification
      if (settings.startNotifications && session.status.isOpen) {
        await _scheduleIfFuture(
          id: base + 1,
          when: session.plannedStart,
          title: 'Study session starting',
          body: 'Study session starting: $subjectName — ${session.title}.',
          settings: settings,
          critical: true,
          payload: 'session:${session.id}:start',
        );
      }

      // Missed notification shortly after planned end
      if (settings.missedNotifications &&
          (session.status == SessionStatus.scheduled ||
              session.status == SessionStatus.missed)) {
        final missedAt = session.plannedEnd.add(const Duration(minutes: 5));
        await _scheduleIfFuture(
          id: base + 2,
          when: missedAt,
          title: 'Missed study session',
          body: 'You missed $subjectName — ${session.title}. Reschedule it?',
          settings: settings,
          critical: false,
          payload: 'session:${session.id}:missed',
        );
      }
    } catch (_) {}
  }

  Future<void> syncAllSessions({
    required List<StudySession> sessions,
    required List<Subject> subjects,
    required NotificationSettings settings,
  }) async {
    try {
      // Cancel everything then re-schedule open sessions + evening summary.
      final pending = await _plugin
          .pendingNotificationRequests()
          .timeout(const Duration(seconds: 1));
      for (final p in pending) {
        if (p.id == 900001 || p.id == 900002) continue;
        await _plugin.cancel(id: p.id);
      }

      if (!settings.enabled) return;

      final byId = {for (final s in subjects) s.id: s};
      for (final session in sessions) {
        await syncSession(
          session: session,
          subject: byId[session.subjectId],
          settings: settings,
        );
      }

      if (settings.eveningSummary) {
        await _scheduleEveningSummary(
          settings,
          sessions: sessions,
        );
      }
    } catch (_) {}
  }

  Future<void> _scheduleEveningSummary(
    NotificationSettings settings, {
    required List<StudySession> sessions,
  }) async {
    final now = tz.TZDateTime.now(tz.local);
    var when = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      settings.eveningHour,
      settings.eveningMinute,
    );
    if (!when.isAfter(now)) {
      when = when.add(const Duration(days: 1));
    }
    if (settings.isQuietAt(when)) return;

    final day = StudyAnalytics.dayStats(sessions, DateTime.now());
    final body =
        "Today's study: ${StudyAnalytics.formatMinutes(day.completedMinutes)} completed of ${StudyAnalytics.formatMinutes(day.plannedMinutes)} planned.";

    try {
      await _plugin.zonedSchedule(
        id: 800001,
        scheduledDate: when,
        title: "Today's study summary",
        body: body,
        notificationDetails: _details(),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'evening',
      );
    } catch (_) {}
  }

  Future<void> _scheduleIfFuture({
    required int id,
    required DateTime when,
    required String title,
    required String body,
    required NotificationSettings settings,
    required bool critical,
    String? payload,
  }) async {
    try {
      final localWhen = tz.TZDateTime.from(when, tz.local);
      if (!localWhen.isAfter(tz.TZDateTime.now(tz.local))) return;
      if (!critical && settings.isQuietAt(localWhen)) return;

      await _plugin.zonedSchedule(
        id: id,
        scheduledDate: localWhen,
        title: title,
        body: body,
        notificationDetails: _details(),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: payload,
      );
    } catch (_) {}
  }

  NotificationDetails _details() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.high,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  int _stableId(String sessionId) {
    // Keep in a safe positive 32-bit-ish range for plugin IDs.
    var hash = sessionId.hashCode & 0x3fffffff;
    if (hash < 1000) hash += 1000;
    // Reserve 800000+ for system OrbitFlow notifications.
    return hash % 700000 + 1000;
  }

  Future<List<PendingNotificationRequest>> pending() => _plugin.pendingNotificationRequests();
}
