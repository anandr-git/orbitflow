# OrbitFlow Study Upgrade Report

**Date:** 2026-09-21  
**Version:** 3.0.0+3  
**Direction:** Personal study planner + study tracker + task manager  

---

## 1. Architecture changes

Orbit now uses a central offline-first controller:

- `lib/state/orbit_controller.dart` — subjects, study sessions, todos, settings, notification sync
- `lib/services/notification_service.dart` — **real** local notifications via `flutter_local_notifications`
- `lib/analytics/study_analytics.dart` — planned vs actual, streaks, week/month aggregates
- `lib/screens/app_shell.dart` — Study / Tasks / Week / Insights / Settings navigation
  - Phone: bottom `NavigationBar`
  - Tablet: `NavigationRail` (+ preserved task master–detail inside Tasks)

Existing task CRUD / themes / design tokens were preserved and remain available under **Tasks**.

### Crash fix (pre-work)

Tablet two-pane showed duplicate `Hero` tags (list + details). Details now skips `Hero` when `embedded: true`, fixing the red-screen `_dependents.isEmpty` assert.

---

## 2. New data models

| Model | File | Purpose |
|---|---|---|
| `Subject` + `Topic` | `lib/models/subject.dart` | Dynamic study hierarchy |
| `StudySession` + `SessionStatus` | `lib/models/study_session.dart` | Planned vs actual sessions |
| Extended `AppSettings` + `NotificationSettings` | `lib/models/app_settings.dart` | Study goals, quiet hours, notification toggles |

### Session statuses

`scheduled` · `inProgress` · `completed` · `missed` · `skipped` · `cancelled`

Missed ≠ deleted. Missed sessions remain for analytics and rescheduling.

### Migration

- Todos still use `todos_v2` (unchanged)
- New keys: `subjects_v1`, `study_sessions_v1`
- Settings schema extended with safe defaults
- Backup `schemaVersion: 3` via `TodoRepository.exportAll`

---

## 3. Study features (P0 + key P1)

- Dynamic subjects/topics
- Plan study sessions (duration, reminder, recurrence)
- Today study dashboard (goal / planned / done / remaining %)
- Up next + Start focus
- Focus mode timer (normal / pomodoro 25-5 / complete without timer)
- Actual minutes recorded on finish
- Missed detection + reschedule/skip/keep
- Week planned vs completed bars
- Insights: heatmap, subject stats, plan-vs-reality
- Daily / weekly study goals
- Study streak tracking
- Real local notifications (reminders, start, missed, evening summary)

---

## 4. Dashboard changes

Study home answers “How am I doing today?”:

- Goal / Planned / Done / Remaining
- Progress %
- Weekly progress line
- Up next card with Start
- Missed banner
- Today’s sessions list
- Plan FAB

---

## 5. Calendar / week / month

- **Week tab:** 7-day planned/completed bars + weekly goal guidance
- **Insights:** 28-day consistency heatmap + subject breakdown + month plan vs actual
- Full agenda calendar deferred to next phase (P2)

---

## 6. Notification implementation (REAL)

Package: `flutter_local_notifications` **22.3.1** + `timezone` + `flutter_timezone`

Android setup completed:

- Permissions: `POST_NOTIFICATIONS`, `SCHEDULE_EXACT_ALARM`, `USE_EXACT_ALARM`, `RECEIVE_BOOT_COMPLETED`, `VIBRATE`, `WAKE_LOCK`
- Receivers: `ScheduledNotificationReceiver`, `ScheduledNotificationBootReceiver`, `FlutterLocalNotificationsReceiver`
- Desugaring enabled in `android/app/build.gradle.kts`

Scheduling API: `zonedSchedule` with `AndroidScheduleMode.inexactAllowWhileIdle` (reliable on emulators / Android 14+ without forcing Play-policy exact-alarm audits).

Service methods:

- `requestPermissions()`
- `showTestNotification()` (immediate)
- `scheduleVerificationPing(seconds: 20)`
- `syncSession` / `syncAllSessions` (cancel + reschedule)
- Quiet-hours gating for non-critical alerts

### NOTIFICATION STATUS

| Check | Result |
|---|---|
| Permissions handled? | **Yes** — Android 13+ runtime request + Settings toggle |
| Actual notifications scheduled? | **Yes** — AlarmManager shows `ScheduledNotificationReceiver` for this package |
| Reminder notifications implemented? | **Yes** — before planned start |
| Start notifications implemented? | **Yes** — at planned start |
| Missed notifications implemented? | **Yes** — plannedEnd + 5 minutes |
| Rescheduling cancels/rebuilds? | **Yes** — `cancelSessionNotifications` then resync |
| Completion cancels future alerts? | **Yes** — completed/skipped/cancelled path cancels |
| Immediate test notification API? | **Yes** — Settings → “Send test notification” |
| Emulator verification? | **Partial** — confirmed scheduled `RTC_WAKEUP` alarm tagged to `flutterlocalnotifications.ScheduledNotificationReceiver` (evening summary at 20:00). Immediate posted notification visibility on emulator shade depends on permission UI interaction; AlarmManager proof confirms device-level scheduling is live. Physical device recommended for shade UX confirmation. |

Evidence excerpt from emulator:

```text
tag=*walarm*:com.example.my_first_testing_app/com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver
type=RTC_WAKEUP ... when=2026-09-21 20:00:00.000
```

This is **not** “reminder field stored in JSON only.”

---

## 7. Missed-session behavior

- Open sessions past `plannedEnd` auto-mark `missed` on refresh/bootstrap
- Dashboard banner + review sheet
- Actions: Complete now / Reschedule (tomorrow, weekend, custom) / Skip / Keep missed
- History preserved for Insights

---

## 8. Timer / focus implementation

`FocusModeScreen`:

- Starts session → `inProgress`
- Pause / Resume
- Finish → confirm actual minutes → `completed` + streak bump + notif cancel + optional recurrence spawn
- Pomodoro 25/5 mode
- Complete without timer (manual duration)

Reduce-motion preference applied via `MediaQuery.disableAnimations` in `MaterialApp.builder`.

---

## 9. Analytics implementation

`StudyAnalytics`:

- Day / week stats
- Subject aggregates
- Streak from completion history
- Format helpers
- Next-up selection
- Refresh missed

---

## 10. Subject / topic system

`SubjectsScreen` — create/edit/archive subjects, add topics, color chips.

---

## 11. Responsive changes

- Shell adapts: bottom nav (phone) / rail (tablet width ≥ 840)
- Existing Tasks two-pane preserved
- Study screens use responsive padding + constrained content width

---

## 12. Accessibility changes

- Semantics retained on key controls
- 48dp-friendly buttons from design tokens
- Reduce motion now actually disables animations globally
- Notification permission flow is opt-in from Settings

---

## 13. Tests added

New/expanded coverage:

- Subject/topic/session serialization
- Missed candidate + recurrence spawn
- Day planned/completed analytics + quiet hours
- Repository subjects/sessions + schema v3 export/import
- Existing todo/query/widget coverage retained

**Result:** `13/13` passed

---

## 14. Bugs fixed

1. Tablet duplicate Hero crash (`_dependents.isEmpty`)
2. Notification init hang risk in widget tests (timeouts)
3. Settings/study goal persistence gaps filled
4. Stale notification risk mitigated via cancel-before-schedule sync

---

## 15. Files changed (high level)

**New**

- `lib/models/subject.dart`
- `lib/models/study_session.dart`
- `lib/analytics/study_analytics.dart`
- `lib/services/notification_service.dart`
- `lib/state/orbit_controller.dart`
- `lib/screens/app_shell.dart`
- `lib/screens/study_home_screen.dart`
- `lib/screens/focus_mode_screen.dart`
- `lib/screens/session_editor_screen.dart`
- `lib/screens/subjects_screen.dart`
- `lib/screens/week_screen.dart`
- `lib/screens/insights_screen.dart`
- `docs/STUDY_UPGRADE_REPORT.md`

**Updated**

- `lib/main.dart`, `lib/models/app_settings.dart`, `lib/storage/todo_repository.dart`
- `lib/screens/settings_screen.dart`, `lib/screens/task_details_screen.dart`
- `android/app/src/main/AndroidManifest.xml`, `android/app/build.gradle.kts`
- `pubspec.yaml`, `test/widget_test.dart`

---

## 16. Commands executed

```bash
export ANDROID_HOME=/home/anand/Android/Sdk
flutter pub add flutter_local_notifications timezone flutter_timezone
flutter analyze
flutter test
flutter build apk --debug
adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-debug.apk
adb -s emulator-5554 shell pm grant com.example.my_first_testing_app android.permission.POST_NOTIFICATIONS
adb -s emulator-5554 shell am start -n com.example.my_first_testing_app/.MainActivity
adb -s emulator-5554 exec-out screencap -p > docs/screenshots/study_home.png
adb -s emulator-5554 shell dumpsys alarm | grep flutterlocalnotifications
```

---

## 17. flutter analyze result

```text
No issues found!
```

---

## 18. flutter test result

```text
13/13 All tests passed!
```

---

## 19. flutter build result

```text
✓ Built build/app/outputs/flutter-apk/app-debug.apk
adb install → Success
```

---

## 20. Emulator / device validation

| Target | Result |
|---|---|
| Pixel_8 emulator (`emulator-5554`) | Study dashboard, nav shell, settings, week/insights screenshots |
| AlarmManager notification schedule | Confirmed for package |
| Tablet two-pane (prior + Hero fix) | Crash fixed |

Screenshots: `docs/screenshots/study_home.png`, `week_view.png`, `insights_view.png`, settings/notif captures, subjects empties.

---

## 21. Screenshots generated

- `docs/screenshots/study_home.png`
- `docs/screenshots/week_view.png`
- `docs/screenshots/insights_view.png`
- `docs/screenshots/study_settings*.png`
- `docs/screenshots/subjects_*.png`
- prior phone/tablet captures retained

---

## 22. Remaining limitations

1. Full drag-and-drop weekly planner board not built (week analytics + reschedule exist)
2. Month calendar agenda grid not yet a dedicated calendar widget
3. Exam/target-date UI is modeled on subjects (`examDate`) but not deeply surfaced
4. Smart “distribute missed hours” automation is confirmation-based reschedule only
5. Exact-alarm mode uses inexact-allow-while-idle for broader emulator reliability; can switch to `alarmClock` if product requires stricter precision
6. Tasks tab still owns its own todo repository instance (disk-shared `todos_v2`); deeper unification possible
7. Physical-device shade confirmation recommended for the 20s verification ping UX

---

## 23. Recommended next steps

1. Dedicated Day/Week/Month agenda calendar
2. Exact `alarmClock` schedule mode + Play policy declaration if publishing
3. Home-screen widget for “Up next”
4. Onboarding (optional subjects + goals)
5. Unified OrbitController ownership of todos (single source of truth)
6. Topic progress derived UI drill-down
7. Natural-language quick plan (“OS scheduling tomorrow 7pm 90m”)

---

## Product principle check

Orbit now surfaces:

> You planned X · completed Y · remaining Z · weekly progress · next session · missed work

not merely “you have N tasks.”
