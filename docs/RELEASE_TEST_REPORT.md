# OrbitFlow — Release Test Report

**Date:** 2026-09-22  
**Host:** Linux (EndeavourOS) · Flutter 3.47.4 · Dart 3.13.3  
**Product:** OrbitFlow — Personal Productivity & Study OS  

---

## 1. Project rename

| Item | Value |
|------|--------|
| Previous folder | `~/AndroidStudioProjects/my_first_testing_app` |
| New folder | `~/AndroidStudioProjects/OrbitFlow` |
| Pub package | `orbitflow` |
| Visible name | OrbitFlow |
| Android label | OrbitFlow |
| Git | `.git` preserved (`master`, no commits yet) |

---

## 2. New project path

```text
/home/anand/AndroidStudioProjects/OrbitFlow
```

Verified with `pwd` after rename.

---

## 3. Emulator used

| Field | Value |
|-------|--------|
| AVD | Pixel_8 |
| Device id | emulator-5554 |
| Model | sdk_gphone16k_x86_64 |
| Notes | Earlier emulator exits were recovered by cold relaunch with `swiftshader_indirect`, `QT_QPA_PLATFORM=xcb`, clearing AVD locks, and waiting for `sys.boot_completed=1`. |

---

## 4. Emulator Android version

| Field | Value |
|-------|--------|
| Android version | 17 |
| API level | 37 |

---

## 5. Device resolution / density

| Mode | Size | Density |
|------|------|---------|
| Phone (default) | 1080 × 2400 | 420 |
| Tablet portrait metrics | 1800 × 2880 | 280 |
| Tablet landscape metrics | 2880 × 1800 | 280 |
| Phone landscape smoke | 2400 × 1080 | (then reset) |

---

## 6. Test scenarios (phone · release APK after install)

| Scenario | Result |
|----------|--------|
| First launch / splash | PASS — OrbitFlow branding |
| Onboarding Welcome / Continue / Start using OrbitFlow | PASS |
| Usage focus steps (Study / Work / Study+Work / Personal UI) | PASS (flow exercised) |
| Study home with sample preview data | PASS |
| Subject / topic navigation | PASS (OS → Processes) |
| Focus start / pause / resume | PASS |
| Tasks list + New Task entry | PASS |
| Week planner | PASS |
| Insights month / consistency | PASS |
| Settings theme Light/Dark | PASS |
| Sample preview load (confirm dialog) | PASS |
| App force-stop + restart persistence | PASS (sessions/missed/progress retained) |
| Portrait | PASS |
| Landscape (phone) | PASS (smoke screenshot) |

---

## 7. Light theme results

PASS on Study / Tasks / Week / Insights / Settings captures after switching to Light. Contrast and navigation remained usable.

---

## 8. Dark theme results

PASS on Study (with Up Next / Missed / progress), Focus, Tasks, Week, Insights, Settings. Missed card remains text-labeled (not color-only).

---

## 9. Task manager results

PASS — Tasks destination opens; sample/general tasks available after preview seed; New Task FAB opens composer (smoke).

---

## 10. Study results

PASS — Subjects, session Up Next, missed recovery actions, today’s plan visible with demo data.

---

## 11. Focus results

PASS — Focus screen opens from Start; Start / Pause / Resume controls respond.

---

## 12. Notifications results

| Check | Result |
|-------|--------|
| POST_NOTIFICATIONS grant via `pm grant` | Done for test |
| Settings → Enable notifications + Send test notification | Exercised |
| Active notification record for package | Observed in `dumpsys notification` (1 record) |
| Shade visual confirmation | Partial — ticker/title extraction limited; channel wiring present in release |

**Note:** Notification UX depends on runtime permission + channel enablement. Defaults were not permanently changed beyond enabling notifications for the test path.

---

## 13. Tablet results

| Check | Result |
|-------|--------|
| Pad-class portrait metrics | PASS (screenshot `docs/screenshots/readme/tablet-portrait.png`) |
| Pad-class landscape metrics | PASS (`tablet-landscape.png`); expanded layout engaged |
| Same release APK | Yes — no separate tablet build |

Physical Xiaomi Pad 6 was not available; validation used size/density overrides on Pixel_8 AVD.

---

## 14. Release APK results

| Field | Value |
|-------|--------|
| Artifact | `dist/OrbitFlow-Android.apk` |
| Size | 54 MB |
| versionName | 3.1.0 |
| versionCode | 4 |
| applicationId | `com.example.my_first_testing_app` (intentionally unchanged) |
| application-label | OrbitFlow |
| Build type | release |
| Signing | Verifies (APK Signature Scheme v2) — **debug keystore** per project Gradle config |
| Installed on emulator | `adb install -r` **Success** |
| Launched | Success — OrbitFlow UI visible |

---

## 15. APK SHA-256

```text
d50169ebb6d1ae72f3a3abf73a405012c3a07beecdd7638116ca42ba6f4f348a
```

File: `dist/OrbitFlow-Android.apk.sha256`

---

## 16. flutter analyze

```text
No issues found!
```

---

## 17. flutter test

```text
All tests passed! (27)
```

---

## 18. flutter build apk --release

```text
✓ Built build/app/outputs/flutter-apk/app-release.apk
```

Copied to `dist/OrbitFlow-Android.apk`.

---

## 19. Remaining known issues

1. Release signing still uses the **debug keystore** — fine for local sideload; not for Play Store.  
2. `applicationId` still `com.example.my_first_testing_app` — intentional until a migration plan exists.  
3. Emulator cold boot on this host is fragile (occasional early process exit); relaunch + wait for boot is required.  
4. Automated notification title assertion in shade was limited; package notification record confirmed.  
5. Large APK in `dist/` should preferably be published via GitHub Releases rather than long-term git history.

---

## 20. Platform limitations

| Platform | Status |
|----------|--------|
| Android phone | Validated this pass |
| Android tablet metrics | Validated this pass |
| Web / Linux | Previously built; not re-validated end-to-end this pass |
| Windows / macOS / iOS | Source present; not validated on this host |

---

## Artifacts

```text
OrbitFlow/
├── README.md
├── dist/
│   ├── OrbitFlow-Android.apk
│   └── OrbitFlow-Android.apk.sha256
├── docs/
│   ├── RELEASE_TEST_REPORT.md
│   ├── PLATFORM_MATRIX.md
│   ├── SECURITY_AUDIT.md
│   └── screenshots/
│       ├── readme/          # numbered + dark captures
│       ├── study-home-demo.png
│       ├── focus.png
│       ├── tasks.png
│       └── …
└── …
```

**Git:** no commit / no push performed.
