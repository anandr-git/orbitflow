<div align="center">

# OrbitFlow

### Personal Productivity & Study OS

**Plan. Focus. Complete. Improve.**

OrbitFlow is an offline-first Flutter app that combines study planning, focus sessions, tasks, reminders, and progress insights — for students, professionals, and hybrid users.

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Android](https://img.shields.io/badge/Android-validated-3DDC84?logo=android&logoColor=white)](#platform-status)
[![Tests](https://img.shields.io/badge/tests-27%2F27-success)](#quality)

[Download Android APK](https://github.com/anandr-git/orbitflow/releases/latest) · [Features](#features) · [Screenshots](#screenshots)

</div>

---

## Download

**[Download the latest Android APK](https://github.com/anandr-git/orbitflow/releases/latest)**

Validated on Android phone and Pad-class tablet layouts.

---

## Why OrbitFlow?

Most people juggle a planner, a to-do list, a timer, and scattered notes. OrbitFlow keeps study planning, focused work, tasks, reminders, and progress tracking in one personal productivity system — useful for exam prep, work deadlines, or both in the same day.

```text
Plan → Schedule → Get reminded → Focus → Complete → Review → Improve
```

---

## Features

| Study | Productivity |
|---|---|
| Subjects & topics | Tasks & priorities |
| Study sessions | Deadlines |
| Focus mode | Search / filters |
| Goals & streaks | Recurring tasks |
| Progress insights | Subtasks |
| Missed-session recovery | Archive |

| Planning | Notifications |
|---|---|
| Today | Session reminders |
| Week | Start alerts |
| Day agenda | Missed-session alerts |
| Monthly insights | Quiet hours |

Themes: light / dark / system · accent colors · reduce motion · local backup import/export

---

## Screenshots

Sample preview data — not real user history.

<table>
  <tr>
    <td align="center" width="50%">
      <strong>Study Dashboard</strong><br><br>
      <img src="docs/screenshots/readme/study-home.png" width="300" alt="Study Dashboard">
    </td>
    <td align="center" width="50%">
      <strong>Focus Mode</strong><br><br>
      <img src="docs/screenshots/readme/focus.png" width="300" alt="Focus Mode">
    </td>
  </tr>
  <tr>
    <td align="center" width="50%">
      <strong>Task Management</strong><br><br>
      <img src="docs/screenshots/readme/tasks.png" width="300" alt="Tasks">
    </td>
    <td align="center" width="50%">
      <strong>Weekly Planning</strong><br><br>
      <img src="docs/screenshots/readme/week.png" width="300" alt="Week Planner">
    </td>
  </tr>
  <tr>
    <td align="center" width="50%">
      <strong>Insights</strong><br><br>
      <img src="docs/screenshots/readme/insights.png" width="300" alt="Insights">
    </td>
    <td align="center" width="50%">
      <strong>Subjects & Topics</strong><br><br>
      <img src="docs/screenshots/readme/subjects.png" width="300" alt="Subjects">
    </td>
  </tr>
</table>

### Dark Mode

<table>
  <tr>
    <td align="center" width="50%">
      <strong>Study</strong><br><br>
      <img src="docs/screenshots/readme/dark-study.png" width="300" alt="Dark Study">
    </td>
    <td align="center" width="50%">
      <strong>Insights</strong><br><br>
      <img src="docs/screenshots/readme/dark-insights.png" width="300" alt="Dark Insights">
    </td>
  </tr>
</table>

More captures: [`docs/screenshots/testing/`](docs/screenshots/testing/)

---

## Development

```bash
git clone https://github.com/anandr-git/orbitflow.git
cd OrbitFlow
flutter pub get
flutter run
```

```bash
flutter analyze
flutter test
flutter build apk --release
```

---

## Platform Status

| Platform | Status |
|---|---|
| Android phone | Validated |
| Android tablet | Validated |
| Web | Smoke-tested |
| Linux | Build validated |
| Windows | Not yet tested |
| macOS | Not yet tested |
| iOS | Not yet tested |

[Platform matrix →](docs/PLATFORM_MATRIX.md)

---

## Architecture

OrbitFlow is built with Flutter/Dart using an offline-first architecture with structured models, centralized state, local persistence, Material 3 theming, responsive layouts, and local notifications.

[View architecture documentation →](docs/ARCHITECTURE.md)

---

## Privacy

OrbitFlow is currently offline-first. Core tasks, sessions, subjects, and settings are stored locally. There is no OrbitFlow cloud account in the current build.

[Privacy / data details →](docs/SECURITY_AUDIT.md)

---

## Quality

- `flutter analyze` — clean
- `flutter test` — 27/27 passed
- Android release APK tested on Pixel-class emulator
- Android tablet layout validated

[Release test report →](docs/RELEASE_TEST_REPORT.md)

---

## Roadmap

- Richer desktop layouts
- Deeper calendar planning
- Broader cross-platform validation
- Additional productivity workflows

---

## Contributing

Fork → branch → change → `flutter analyze` / `flutter test` → PR. Keep changes focused and preserve offline-first behavior.

---

## License

License: **not yet specified**
