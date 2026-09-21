# OrbitFlow Final QA Report

Date: 2026-09-21  
Phase: Pre-release correctness + polish (no large feature set)

## 1. Bugs found

| Severity | Issue |
|----------|--------|
| **High** | Opening Focus Mode immediately set `inProgress` while timer stayed at `00:00` with Start still shown — Study Home “Current session” contradicted Focus UI |
| **High** | Timer elapsed lived only in widget memory; leave/reopen Focus reset to `00:00` |
| **High** | Subject % used planned-session completion while subjects have `targetHours` (e.g. 2h05m / 40h shown as ~52%) |
| **High** | Demo data marked future weekdays as completed — Insights falsified history |
| **Medium** | “Left” mixed goal-remaining with planned workload |
| **Medium** | Grammar: “1 sessions”, “1 days” |
| **Medium** | Blank spinner boot screen with no branding/error path |
| **Medium** | Tasks tab used a separate `TodoRepository` vs controller (stale risk after import) |
| **Medium** | Notification `pendingNotificationRequests` could hang bootstrap/tests |
| **Low** | Day agenda rendered every hour 7–22 even when empty |
| **Low** | In-progress sessions could be auto-marked missed after planned end |

## 2. Bugs fixed

- Focus no longer auto-starts; Start → `inProgress` + timestamp segment
- Pause banks `focusAccumulatedSeconds`; resume continues from timestamps
- Elapsed survives reopen / lifecycle via persisted timer fields
- In-progress sessions excluded from auto-missed
- Subject progress = studied ÷ target hours when target set
- Demo data v2: past completed/missed, today mixed, future scheduled only
- Goal remaining vs plan remaining labeled explicitly
- Pluralization helper for counts
- Branded loading + error/retry boot screens
- Tasks sync through `OrbitController.saveTodos`
- Notification sync timeouts; miss alerts not scheduled for active in-progress the same way as open scheduled

## 3. UX improvements

- Study Home order: **Up next → progress → missed → plan**
- Explicit “Goal remaining” / “Plan remaining” / “% of goal”
- Topic detail: Start + Plan actions (not a dead end)
- Day agenda: adaptive hour range + **Now** marker
- Week: “Today” label; singular/plural session counts
- Focus: state-driven Start/Pause/Resume/Finish (Finish disabled until work started)

## 4. Timer / state fixes

Persisted on `StudySession` (backward-compatible JSON):

- `focusAccumulatedSeconds`
- `focusSegmentStartedAt`

Controller API: `startFocusTimer` / `pauseFocusTimer` / `resumeFocusTimer`  
Authoritative elapsed: `session.elapsedFocus()`

## 5. Loading fixes

- Boot: Orbit branding + “Loading your study plan…”
- Error: message + Retry (`retryBootstrap`)
- Bootstrap timeouts so the UI cannot hang indefinitely on notification init

## 6. Notification fixes

- Concise copy for upcoming / start / missed / evening
- Evening body uses current day stats at schedule/sync time
- Cancel-before-reschedule unchanged; pending query timed out
- In-progress: start/reminder only while `status.isOpen`; missed scheduling narrowed

**Verified:** scheduling/cancellation code paths + AlarmManager registration pattern (prior pass).  
**Not fully re-verified this pass:** shade delivery at exact fire times after every edit.

## 7. Analytics fixes

- Documented formulas:
  - **Topic %** = completed minutes ÷ planned minutes for that topic
  - **Subject %** = completed minutes ÷ (`targetHours` × 60) when target set; else completed ÷ planned
- Demo future sessions no longer inflate “completed” history

## 8. Data correctness fixes

- Demo flag `orbit_demo_seeded_v2`
- Timer fields survive export/import via session JSON
- Reload demo from Settings → Data still available

## 9. Responsive fixes

- Existing phone/tablet shell retained
- Widget test still covers NavigationBar vs NavigationRail

## 10. Accessibility fixes

- Boot/error text readable; icon button tooltips retained
- Finish disabled (not contradictory) when session not started

## 11. Tests added

Now **24** tests (+4 focus/timer/progress/demo semantics). Covers:

- Timer pause/resume/timestamp elapsed
- No auto-start without `startFocusTimer`
- Subject progress vs target hours
- In-progress not auto-missed
- Future demo sessions stay scheduled

## 12. Files modified (primary)

- `lib/models/study_session.dart`
- `lib/state/orbit_controller.dart`
- `lib/screens/focus_mode_screen.dart`
- `lib/main.dart`
- `lib/data/demo_study_data.dart`
- `lib/screens/study_home_screen.dart`
- `lib/screens/subject_detail_screen.dart`
- `lib/screens/topic_detail_screen.dart`
- `lib/screens/day_agenda_screen.dart`
- `lib/screens/week_screen.dart`
- `lib/screens/insights_screen.dart`
- `lib/screens/home_screen.dart` / `app_shell.dart`
- `lib/services/notification_service.dart`
- `lib/analytics/study_analytics.dart`
- `test/widget_test.dart`

## 13. Commands executed

```
flutter analyze
flutter test
flutter build apk --debug
adb install / launch / uiautomator spot-check
```

## 14. flutter analyze

```
No issues found!
```

## 15. flutter test

```
00:04 +24: All tests passed!
```

## 16. flutter build apk

```
✓ Built build/app/outputs/flutter-apk/app-debug.apk
```

## 17. Device / emulator validation

- Clean reinstall after this pass (demo v2 seed on empty store)
- Spot-check Study home for Up next / progress labels via UI dump

**Not exhaustively re-run this pass:** full pause→background→kill→restore timer E2E on device (covered by unit timestamp tests + lifecycle observer in Focus).

## 18. Notification verification

| Check | Status |
|-------|--------|
| Schedule on create/sync | Code + prior AlarmManager evidence |
| Cancel on complete/skip | Code path present |
| Quiet hours | Unchanged logic |
| Shade fire after edit | Not re-timed this pass |

## 19. Remaining issues

### High severity
- **None known** after the Focus/timer/progress/demo fixes.

### Medium / residual
- Evening summary snapshot is computed at sync time, not at fire time (can drift if user studies after sync).
- Tablet week grid still tap-to-edit (no drag-drop) by design for stability.
- Tasks still write via both repository + controller callback; single write path could be tightened further.
- Device kill/restore of a *running* segment relies on persisted `focusSegmentStartedAt` — unit-tested; long device soak not repeated this pass.

### Low
- Subject icons still share school glyph (color differentiates).
- Pomodoro mode timer is UI-local (not persisted across Focus exits).

---

**Bottom line:** The critical Study Home ↔ Focus contradiction is fixed; timer state is timestamp-backed; demo/history math is time-honest; boot is intentional; **analyze clean, 24/24 tests, debug APK builds**.
