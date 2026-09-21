# OrbitFlow — Final UI/UX, Dark Theme & Onboarding Report

**Date:** 2026-09-21  
**Scope:** Visual polish, dark theme first-class, onboarding, accessibility/microcopy, empty states — no large feature expansion.

---

## 1. Dark-theme issues found

| Area | Issue |
|------|--------|
| Palette | Risk of flat “black + light widgets” without surface ladder |
| Study home | Empty Up Next previously said “You're done for today” with zero completed sessions |
| Progress metrics | Hardcoded `Colors.green` for Done could read neon on dark surfaces |
| Streak copy | `countLabel(n, 'day streak')` → “4 day streaks” |
| Demo data | Silent auto-seed could look like real history |
| Screenshots | Earlier “dark_*” captures were still light until Settings → Dark was tapped correctly |

---

## 2. Dark-theme fixes

- Deliberate dark ladder in `app_theme.dart`: bg `#12141A` → surface `#1A1D26` → elevated `#222632` → borders `#2E3444`; softened primary; tertiary for success.
- Component themes (cards, chips, inputs, nav, FABs, switches) share the same ladder — not pure inversions.
- Up Next empty copy: **Nothing planned yet** when no activity; **You're done for today** only after real completions.
- Done metric uses `colorScheme.tertiary` (calm green in dark).
- Focus mode stays minimal: large timer, soft accents, no glow/noise.
- Insights calendar: studied days (filled purple), today (outline), planned (“plan”) remain readable on dark tiles.
- Missed card uses deep maroon + explicit **Missed session** label (not color alone).

---

## 3. Light-theme regressions checked

- Side-by-side captures: Study, Tasks, Week, Insights, Subjects, Settings, notifications.
- Light keeps white cards on soft grey canvas; purple accents unchanged.
- Segmented System/Light/Dark and accent swatches verified in both modes.
- No intentional light-only features.

---

## 4. Accessibility issues

**Addressed / present**

- Nav destinations use icon **and** label; tooltips on Study/Tasks/Week/Insights/Settings.
- Icon-only app-bar actions (search/filter/sort/subjects) have tooltips.
- Status uses text + color (Missed, Completed, Ready to start).
- Reduce motion setting + `MediaQuery.disableAnimations` when enabled.
- Semantics-rich cards (Up Next, progress, missed).

**Remaining / watch**

- Some secondary grey text is calm by design; verify WCAG AA on very large text scale.
- Charts/calendar still primarily color-coded with supporting labels; consider longer a11y descriptions later.
- Assistive keyboard overlays can briefly obscure onboarding fields (device-level, not Orbit).

---

## 5. Responsive issues

- Phone portrait (1080×2400 emulator): no clipped FAB/nav; scroll regions clear.
- Compact shell: labeled bottom navigation.
- Expanded shell: NavigationRail (existing); prior tablet captures retained under `docs/screenshots/tablet_*.png`.
- Category chips on Tasks scroll horizontally (Fitness may clip at edge — intentional scroll).

---

## 6. New-user usability issues

| Friction | Fix |
|----------|-----|
| “What is Orbit?” | Lightweight 3-step onboarding + Skip |
| Study vs Tasks | Welcome + focus choice + nav tooltips |
| Empty Study home | Starter tip card, Up Next Plan CTA, session definition |
| Fake history | No auto-seed; Settings “Load sample preview data” with confirm |
| Goal vs plan | Explicit Goal / Planned / Done + remaining lines |

---

## 7. Student UX improvements

- Onboarding: Study / Study+Work → optional first subject + daily focus goal.
- Subjects empty: “courses, certifications, or learning goals.”
- Study home tip: subject → topic → session → Start.
- Preview seed still includes OS / Networks / Algorithms scenarios for review.

---

## 8. Professional UX improvements

- Welcome copy: work, projects, deadlines, everyday tasks.
- Work / Personal usage focus; Tasks remain first-class.
- Session / focus / plan wording preferred over “study-only” on shared CTAs (`Plan today's session`).
- Tasks empty: “Your day is clear” + Add task.

---

## 9. Navigation changes

- Tooltips on bottom destinations and Plan FAB.
- Labels retained (no icon-only primary nav).
- First-run tip on Study home; not permanent nav descriptions.

---

## 10. Empty-state improvements

| Screen | Empty copy direction |
|--------|----------------------|
| Study / Up Next | Nothing planned yet + Plan |
| Today's plan | Explains what a session is |
| Subjects | No subjects yet + Add subject |
| Tasks | Your day is clear + Add task |
| Insights subjects | Activity appears after completed sessions |

---

## 11. Microcopy improvements

- Goals: “how much focused time you want today” / weekly target.
- Notifications: value blurb + per-toggle subtitles (reminders, start, missed, evening, quiet hours).
- Demo: “not real history” / confirm dialog.
- Grammar: `N-day streak` (not “day streaks”).

---

## 12. Onboarding changes

New `OnboardingScreen` gated by `settings.onboardingComplete`:

1. **Welcome** — brand + hybrid positioning + Skip  
2. **Usage focus** — Study / Work / Study+Work / Personal (defaults only)  
3. **Optional setup** — subject + daily goal → Start using Orbit  

Persists focus → default task category; optional subject with “Getting started” topic. Does **not** invent sessions.

---

## 13. Notification UX changes

- Intro paragraph explaining reminders / start / missed.
- Clear subtitles on each toggle; quiet hours shown as `22:30 → 07:00`.
- Enable path still requests permission only when user turns notifications on (not aggressive on first launch).

---

## 14. Visual polish changes

- Dark surface hierarchy + softened indigo primary  
- Up Next empty-state honesty  
- Streak label  
- Done color via tertiary  
- “Plan today's session”  
- Sample preview confirm + non-auto seed  

---

## 15. Files modified (this phase)

Primary:

- `lib/theme/app_theme.dart`
- `lib/models/app_settings.dart` (`UsageFocus`, `onboardingComplete`)
- `lib/screens/onboarding_screen.dart` (new)
- `lib/main.dart`
- `lib/screens/study_home_screen.dart`
- `lib/screens/settings_screen.dart`
- `lib/screens/app_shell.dart`
- `lib/screens/subjects_screen.dart` / empty-state related screens
- `lib/screens/insights_screen.dart`
- `lib/state/orbit_controller.dart` (demo seed only via Settings; marks onboarding complete when preview loaded)
- `lib/data/demo_study_data.dart` (time-honest seed; no silent production inject)

Plus supporting empty/microcopy touches across study/week/tasks/focus as needed.

---

## 16. Tests added

- Existing suite updated for boot/onboarding (Skip / wait for Study).
- **flutter test: 25/25 passed** (includes prior study/focus/UI coverage).

---

## 17. flutter analyze

```
No issues found!
```

---

## 18. flutter test

```
All tests passed! (25)
```

---

## 19. flutter build apk

```
flutter build apk --debug → success
```

---

## 20. Phone validation

Emulator 1080×2400:

- Light + Dark Study / Tasks / Week / Insights / Subjects / Settings / Focus  
- Theme switch live (no restart)  
- Onboarding full path after `pm clear`  
- Sample preview → Up Next / Missed / Progress / Insights heatmap  

---

## 21. Tablet validation

- Existing NavigationRail / two-pane behavior retained.
- Prior tablet portrait/landscape captures in `docs/screenshots/tablet_*.png`.
- Full dark re-capture on tablet not repeated this pass; phone dark parity is the primary validation.

---

## 22. Dark-theme screenshots

Under `docs/screenshots/`:

| File | Notes |
|------|--------|
| `dark_settings.png` | Appearance + goals |
| `dark_study_home.png` | Empty first-run |
| `dark_study_home_with_data.png` | Up Next / missed / progress |
| `dark_focus_mode.png` | Calm timer |
| `dark_week.png` / `dark_week_with_data.png` | Planner |
| `dark_insights.png` / `dark_insights_with_data.png` | Month + signals |
| `dark_tasks.png` | Empty tasks |
| `dark_subjects.png` / `dark_subjects_with_data.png` | Subjects |
| `dark_settings_notifications.png` | Notification section |

Light counterparts: `light_study_home.png`, `light_tasks.png`, `light_week.png`, `light_insights.png`, `light_subjects.png`, `light_settings.png`, `light_settings_notifications.png`.

Onboarding: `light_onboarding_welcome.png`, `light_onboarding_focus.png`, `light_onboarding_setup.png`.

---

## 23. Remaining issues

1. **Tablet dark re-sweep** — recommend one more pass on Pad-class portrait/landscape with preview data.  
2. **Large font / TalkBack** — deeper pass with 200% text scale still valuable.  
3. **Study home CTA density** — multiple Plan entry points (Up Next, section, FAB); acceptable for discovery, could later progressive-disclose Quick plan.  
4. **Insights metric info taps** — formulas are in copy; dedicated info sheets not added (avoid feature creep).  
5. **System theme OS toggle** — Flutter `ThemeMode.system` wired; OS live flip depends on host; preference persistence verified via Settings.

---

## Acceptance (Users A/B/C)

| User | Verdict |
|------|---------|
| **A Student** | Subjects → topics → sessions → Focus → Insights/Week clear; onboarding Study path optional subject |
| **B Professional** | Tasks first-class; Work focus; session/plan language not exam-only |
| **C Hybrid** | Study + Work defaults; shared Week/Insights; Tasks + Study coexist |

**Product standard check:** Simple at first glance (Today / Up Next / Start / Plan / Progress); powerful underneath (subjects, analytics, notifications, preview data). Premium/calm in both themes — not neon or dashboard-heavy.
