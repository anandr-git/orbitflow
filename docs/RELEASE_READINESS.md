# OrbitFlow — Release Readiness

Generated: 2026-09-21  
Decision: **Android (+ tablet) release APK approved for local / sideload QA**  
Not a claim of universal multi-platform production readiness.

---

## Release gates

| Gate | Status |
|------|--------|
| Phone UI validated | [x] |
| Tablet portrait validated | [x] |
| Tablet landscape validated | [x] |
| Dark theme tablet validated | [x] |
| Light theme validated | [x] |
| Accessibility checks (labels, reduce motion, large text sample) | [x] |
| `flutter analyze` clean | [x] |
| `flutter test` passing (27/27) | [x] |
| Android release build passing | [x] |
| APK signature verified (`apksigner`) | [x] |
| Android manifest audited | [x] |
| Permissions audited | [x] |
| Dependencies audited (`pub outdated`; OSV unavailable) | [x] |
| Secrets scan completed | [x] |
| Import/export validation completed | [x] |
| Notification validation completed (Android) | [x] |
| Web build validated OR marked limited | [x] build + smoke |
| Linux build validated OR marked limited | [x] build |
| Windows validated OR marked platform-limited | [x] **NOT TESTED** (needs Windows) |
| macOS validated OR marked platform-limited | [x] **NOT TESTED** (needs macOS) |

**Final APK built:** yes (after tablet + security gates).

---

## A. Tablet status

| Check | Result |
|-------|--------|
| Phone | **PASS** |
| Tablet portrait | **PASS** (NavigationRail + constrained Study content) |
| Tablet landscape | **PASS** (extended NavigationRail) |
| Dark tablet | **PASS** |
| Light tablet | **PASS** |
| Realistic sample data | **PASS** (landscape Study/Week/Insights) |
| Large text (1.3×) | **PASS** (smoke capture) |
| Overflow / overlapping controls | **PASS** on exercised screens |

Method: Android emulator with Pad-class overrides `1800×2880` / `2880×1800` @ density `280` (Xiaomi Pad 6-class approximation). Screenshots: `docs/screenshots/tablet/`.

---

## B. Platform status

| Platform | Status |
|----------|--------|
| Android | **PASS** (phone + tablet metrics) |
| Web | **PASS WITH LIMITATIONS** (`flutter build web --release`; index served HTTP 200) |
| Linux | **PASS WITH LIMITATIONS** (release bundle built) |
| Windows | **NOT TESTED** — source present; native Windows validation required |
| macOS | **NOT TESTED** — source present; macOS/Xcode validation required |

Honest summary: **Android + tablet release ready for sideload QA; web/Linux built with limitations; Windows/macOS require native host validation.**

---

## C. Security status

| Category | Count |
|----------|------:|
| Critical | 0 |
| High | 0 |
| Medium | 2 (debug signing; example applicationId) |
| Low | 3 |
| Dependency CVEs (OSV) | Scanner unavailable |
| Secrets found | 0 |
| Manifest concerns | Resolved `USE_EXACT_ALARM`; release has no `INTERNET` |

Details: `docs/SECURITY_AUDIT.md`

---

## D. Testing / builds

| Command | Result |
|---------|--------|
| `flutter analyze` | No issues found |
| `flutter test` | **27/27 passed** |
| `flutter build web --release` | Success → `build/web` |
| `flutter build linux --release` | Success → `build/linux/x64/release/bundle/` |
| `flutter build apk --release` | Success |

---

## E. APK

| Field | Value |
|-------|--------|
| Path | `build/app/outputs/flutter-apk/app-release.apk` |
| Size | ~54 MB |
| SHA256 | `dc0d5fc251480d9815d496b841a5471a0a353c483e2f22a7e4937c8d7f4beebe` (also `app-release.apk.sha256`) |
| Package | `com.example.my_first_testing_app` |
| versionName / versionCode | `3.1.0` / `4` |
| minSdk / targetSdk / compileSdk | 24 / 36 / 36 |
| Signing | Verifies (v2); **debug keystore** |
| Debuggable | No (release build) |
| INTERNET | Not present in release |

---

## F. Remaining limitations

1. Publish to Play Store requires a **production keystore** and a non-`com.example` applicationId.  
2. Physical Xiaomi Pad 6 not available — Pad-class emulator metrics used.  
3. Web/Linux: notifications and some plugin behaviors differ; full interactive desktop QA not exhaustive.  
4. Windows / macOS / iOS: not validated on this Linux host.  
5. OSV dependency vulnerability scanning not available in environment — add to CI.  
6. Local SharedPreferences storage is not encrypted (acceptable for ordinary study/task data).

---

## Changes in this readiness pass

- Removed `USE_EXACT_ALARM`  
- Hardened backup import + tests  
- Constrained Study/Insights width; widened tablet Week grid  
- Web branding (`Orbit` title/description)  
- Version bump to `3.1.0+4`  
- Platform / security / readiness documents under `docs/`
