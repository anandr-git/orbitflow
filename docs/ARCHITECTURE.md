# OrbitFlow architecture

OrbitFlow is a Flutter / Dart app with an offline-first design.

## Layers

| Layer | Path | Responsibility |
|-------|------|----------------|
| Models | `lib/models/` | Subjects, sessions, todos, settings |
| State | `lib/state/` | `OrbitController` — centralized app state |
| Storage | `lib/storage/` | Local persistence (`SharedPreferences`) |
| Services | `lib/services/` | Local notifications |
| Analytics | `lib/analytics/` | Study progress / insights helpers |
| Screens | `lib/screens/` | Study, Tasks, Week, Insights, Focus, Settings, … |
| Theme | `lib/theme/` | Material 3 themes & design tokens |
| Widgets / utils | `lib/widgets/`, `lib/utils/` | Shared UI and helpers |

## Layout

```text
lib/
├── analytics/
├── data/          # Sample preview data (confirm-gated)
├── models/
├── screens/
├── services/
├── state/
├── storage/
├── theme/
├── utils/
├── widgets/
└── main.dart
```

Platform folders: `android/`, `ios/`, `linux/`, `macos/`, `windows/`, `web/`.

## Notes

- No OrbitFlow cloud sync account in the current build.
- Android `applicationId` remains `com.example.my_first_testing_app` for install continuity until a deliberate package-id migration.
