# OrbitFlow — Platform Matrix

Generated: 2026-09-21  
Flutter: 3.47.4 · Dart 3.13.3  
Host: Linux (EndeavourOS)

## Platform support overview

| Platform | Source tree | Build on this host | Runtime tested | Status |
|----------|-------------|--------------------|----------------|--------|
| Android phone | Yes (`android/`) | Yes | Yes (emulator + tablet metrics) | **PASS** |
| Android tablet | Same APK | Yes | Yes (Pad-class 1800×2880 / 2880×1800 @ 280dpi) | **PASS** |
| Web | Yes (`web/`) | Yes (`flutter build web --release`) | Smoke (index HTTP 200) | **PASS WITH LIMITATIONS** |
| Linux | Yes (`linux/`) | Yes (`flutter build linux --release`) | Binary built; interactive QA limited | **PASS WITH LIMITATIONS** |
| Windows | Yes (`windows/`) | No (requires Windows/MSVC) | Not tested | **NOT TESTED** |
| macOS | Yes (`macos/`) | No (requires macOS/Xcode) | Not tested | **NOT TESTED** |
| iOS | Yes (`ios/`) | No (requires macOS) | Not tested | **NOT TESTED** |

## Feature matrix

| Feature | Android | Tablet | Web | Linux | Windows | macOS |
|---------|---------|--------|-----|-------|---------|-------|
| Study home | PASS | PASS | PASS WITH LIMITATIONS | PASS WITH LIMITATIONS | NOT TESTED | NOT TESTED |
| Tasks | PASS | PASS | PASS WITH LIMITATIONS | PASS WITH LIMITATIONS | NOT TESTED | NOT TESTED |
| Week planner | PASS | PASS | PASS WITH LIMITATIONS | PASS WITH LIMITATIONS | NOT TESTED | NOT TESTED |
| Insights | PASS | PASS | PASS WITH LIMITATIONS | PASS WITH LIMITATIONS | NOT TESTED | NOT TESTED |
| Focus / timer | PASS | PASS | PASS WITH LIMITATIONS | PASS WITH LIMITATIONS | NOT TESTED | NOT TESTED |
| Local notifications | PASS | PASS | UNSUPPORTED / limited | UNSUPPORTED / limited | NOT TESTED | NOT TESTED |
| Import / export (clipboard JSON) | PASS | PASS | PASS WITH LIMITATIONS | PASS WITH LIMITATIONS | NOT TESTED | NOT TESTED |
| Dark / light / system theme | PASS | PASS | PASS WITH LIMITATIONS | PASS WITH LIMITATIONS | NOT TESTED | NOT TESTED |
| Onboarding | PASS | PASS | PASS WITH LIMITATIONS | PASS WITH LIMITATIONS | NOT TESTED | NOT TESTED |
| Responsive shell (nav bar / rail) | PASS | PASS | PASS WITH LIMITATIONS | PASS WITH LIMITATIONS | NOT TESTED | NOT TESTED |
| Local persistence (SharedPreferences) | PASS | PASS | PASS WITH LIMITATIONS | PASS WITH LIMITATIONS | NOT TESTED | NOT TESTED |

### Legend

- **PASS** — built and exercised on this host  
- **PASS WITH LIMITATIONS** — builds; some plugins (esp. notifications) differ or were only smoke-tested  
- **UNSUPPORTED / limited** — platform plugin may no-op or require extra setup  
- **NOT TESTED** — source present; native host validation required  

## Notes

- Notifications depend on `flutter_local_notifications` + Android receivers; desktop/web behavior is not equivalent to Android.
- Windows/macOS/iOS must be validated on their native toolchains before claiming readiness.
- Tablet validation used display size/density overrides approximating Xiaomi Pad 6 class (not a physical Pad 6).
