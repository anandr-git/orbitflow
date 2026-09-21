# OrbitFlow — Security Audit

Generated: 2026-09-21  
Scope: static review of application source, Android manifests, dependencies, and release APK inspection.

**Summary language:** No known high/critical issues were identified by the performed checks. This is not a claim that Orbit is vulnerability-free.

---

## Severity counts

| Severity | Count |
|----------|------:|
| CRITICAL | 0 |
| HIGH | 0 |
| MEDIUM | 2 |
| LOW | 3 |
| INFORMATIONAL | 5 |

---

## Findings

### MEDIUM

1. **Release APK signed with debug keystore**  
   - `android/app/build.gradle.kts` sets `release { signingConfig = signingConfigs.getByName("debug") }`.  
   - Acceptable for local/device QA; **not** acceptable for Play Store / public distribution.  
   - Remediation: configure a release keystore via CI secrets / local `key.properties` (never commit passwords).

2. **Application ID is still `com.example.my_first_testing_app`**  
   - Fine for personal testing; change before store listing.

### LOW

1. **Android backup defaults (`allowBackup` not explicitly disabled)**  
   - Local study/task JSON may be included in device backups. Data is not highly sensitive by nature, but users should know backups exist.  
   - Optional: set `android:allowBackup="false"` or add a backup rules file if stronger privacy is desired.

2. **Clipboard-based import/export**  
   - Export places full backup JSON on the clipboard. Malware with clipboard access could read it.  
   - Mitigated by: local-only data, confirm dialogs, hardened import parsing.

3. **Exact alarm permission (`SCHEDULE_EXACT_ALARM`)**  
   - Required for session reminders. On Android 12+ users may need to grant “Alarms & reminders”.  
   - Removed unnecessary `USE_EXACT_ALARM` (alarm-clock privilege).

### INFORMATIONAL

1. Offline-first: no app-level HTTP clients, analytics SDKs, or remote config found in `lib/`.  
2. `INTERNET` appears only in **debug/profile** manifests (Flutter tooling); **release APK has no INTERNET permission**.  
3. Notification receivers from `flutter_local_notifications` are `android:exported="false"`.  
4. Only launcher activity is exported (`MAIN`/`LAUNCHER`) — expected.  
5. Sample preview data is explicit and confirm-gated; not auto-seeded into real accounts.

---

## Permission inventory (release)

| Permission | Why | Feature | Necessary |
|------------|-----|---------|-----------|
| `POST_NOTIFICATIONS` | Android 13+ runtime notifications | Session reminders | Yes |
| `SCHEDULE_EXACT_ALARM` | Exact reminder timing | Session reminders | Yes |
| `RECEIVE_BOOT_COMPLETED` | Reschedule after reboot | Notification plugin | Yes |
| `VIBRATE` | Notification feedback | Notifications | Yes |
| `WAKE_LOCK` | Alarm delivery reliability | Notification plugin | Yes (plugin) |
| `USE_EXACT_ALARM` | — | — | **Removed** |
| `INTERNET` | — | — | **Not in release** |

---

## Dependency audit

Direct dependencies (`pubspec.yaml`):

- `shared_preferences`, `intl`, `flutter_local_notifications`, `timezone`, `flutter_timezone`, `cupertino_icons`

`flutter pub outdated`: direct deps up to date; some transitive packages have newer minors (locked by SDK constraints).

**OSV / Trivy:** not installed on this host — vulnerability DB scan **unavailable**. Documented as a remaining process gap.

No abandoned or suspicious direct packages identified.

---

## Secrets scan

Searched `lib/` and `android/app` for credential-like patterns.

**Secrets found:** none.

---

## Import / export hardening (changes this pass)

- Max backup size 8 MB  
- Invalid JSON / empty / unrecognized payloads throw `FormatException`  
- Per-row skip for malformed todos/subjects/sessions  
- Sessions require `id` + `plannedStart`  
- Clamp timer fields; reject absurd future focus segment starts  
- Imported settings force `onboardingComplete: true`  
- Unit tests added under “Backup import hardening”

---

## OWASP MASVS-style notes (lightweight)

| Area | Assessment |
|------|------------|
| M1 credentials | N/A — no account system |
| M2 supply chain | Direct deps current; OSV scanner unavailable |
| M3 auth | N/A |
| M4 validation | Import hardened this pass |
| M5 communication | Offline-first; no cleartext app traffic |
| M6 privacy | Local data; clipboard export risk (LOW) |
| M7 local storage | SharedPreferences JSON — not encrypted (INFORMATIONAL for non-sensitive study data) |
| M8 misconfig | Debug signing for release (MEDIUM for distribution) |
| M9 platform | Manifest reviewed; receivers non-exported |
| M10 crypto | No custom crypto |

---

## Tools used

- `flutter analyze` / `flutter test` / `flutter pub outdated`  
- `aapt dump badging|permissions`  
- `apksigner verify`  
- ripgrep secret patterns  
- Manual manifest / code review  

## Tools unavailable

- OSV-Scanner / Trivy  
- jadx / apktool (not required after aapt/apksigner)  
- Physical Xiaomi Pad 6  

## Remaining risks

- Debug-signed release APK must not be published publicly as “production.”  
- Desktop/web notification parity unverified.  
- SharedPreferences not encrypted at rest.  
- Dependency CVE scan should be added to CI when OSV tooling is available.
