# Proctoring — current state & future improvements

Phase 5 shipped a **lightweight, dependency-free** exam proctor: focus/app-switch
detection on the exam-taking screen, with violations counted, surfaced to the
student, threshold-auto-submitted, and **persisted** on the submission
(`violationCount`, `flagged`).

- `lib/proctoring/violation.dart` — trimmed `Violation` model (vendored from
  `exam-guardian`).
- `lib/proctoring/focus_monitor.dart` — `ProctorFocusMonitor`
  (`WidgetsBindingObserver` + grace timer), adapted from
  `exam-guardian/lib/services/focus_monitor.dart`.
- Backend: `Submission.violationCount` / `Submission.flagged` (migration
  `20260609020000_submission_proctoring`).

Source module: `exam-guardian/` in this repo (full AI proctoring app).

## Phase 8 — BUILT (2026-06-14)
Anti-cheat upgrade on top of Phase 5, still **dependency-free**:

- **`lib/proctoring/exam_proctor.dart`** — `ExamProctor` orchestrator (slim
  adaptation of exam-guardian's `ExamMonitor`). Policy: normal in-app behaviour
  never interrupts; a SHORT absence (≥ `warnGrace` 2s, < `forceExitAfter` 15s)
  warns + scores; a LONG single absence (≥ 15s, even first time) **force-exits**
  the exam. Computes a 0–100 advisory **cheat score** and `buildReport()`
  timeline. `Violation` gained `durationSeconds`.
- **Wired into** `take_assignment_screen.dart`: pre-exam consent gate, warning
  snackbars, force-exit dialog, and submits `cheatScore` / `forcedExit` /
  `flagged` / `violationCount` / `proctorReport`.
- **Consent + legal**: `lib/proctoring/proctoring_consent_sheet.dart` +
  `lib/Screens/Legal/legal_content.dart` + `legal_screens.dart`
  (`TermsOfServiceScreen` / `PrivacyPolicyScreen`); repo-root
  `TERMS_OF_SERVICE.md` / `PRIVACY_POLICY.md`.
- **Exam-preview toggle**: `Assessment.showContentPreview` (default true). When
  off, students see a locked notice instead of the questions until they start
  (`AssignmentDetailScreen`); creator sets it in `CreateAssignmentScreen`.
- **Backend**: `Submission.cheatScore` / `forcedExit` / `proctorReport` +
  `Assessment.showContentPreview` + `NotificationType.EXAM_INTEGRITY_ALERT`
  (migration `20260614000000_exam_anticheat`). `submissions.service.create`
  persists the signals and fire-and-forget notifies the class teacher + org
  admins when `flagged || forcedExit || cheatScore >= 50`. The cheat score is
  **advisory only — it never changes the grade**.
- **Teacher/admin surfacing**: integrity chip + score bar + flagged/forced tags
  + violation timeline in `GradeSubmissionsScreen` (`_GradeSubmissionTile`).

## Phase 9 — BUILT (2026-06-15): camera + audio behaviour detection
On-device, **silent** camera/microphone proctoring (events go to teacher/admin
at submit — the student is never warned). Adapted from `exam-guardian`, rebuilt
as a clean state machine (the reference fired one violation per frame, losing
duration and flooding the score).

- **Packages**: `camera`, `google_mlkit_face_detection`, `noise_meter`
  (`permission_handler` already present). Android `CAMERA`/`RECORD_AUDIO` and iOS
  `NSCamera/Microphone` usage strings already declared (WebRTC).
- **`lib/proctoring/behavior_event.dart`** — event taxonomy + per-type weights:
  `FACE_MISSING, FACE_LEFT, LOOKING_LEFT/RIGHT/DOWN, MULTIPLE_PERSON,
  PHONE_DETECTED, EARPHONE_DETECTED, VOICE_DETECTED, TAB_SWITCH, WINDOW_BLUR,
  FULLSCREEN_EXIT`.
- **`behavior_score_engine.dart`** — 0–100 score weighting **base severity +
  duration (per-second, capped) + gaze angle + a compounding multiplier** so
  repeated violations of the same type escalate (×1, ×1.2, ×1.4 … capped ×2.5).
- **`camera_face_proctor.dart`** — front camera image stream (~3 fps) + ML Kit
  face detection, EMA-smoothed head angles, condition state machine emitting
  finalized events with duration + worst angle.
- **`audio_voice_proctor.dart`** — `noise_meter` with ambient calibration →
  sustained-speech `VOICE_DETECTED` events (the reference's calibration was a
  no-op dummy reading; rebuilt).
- **`behavior_monitor.dart`** — owns camera+audio+engine, pauses camera while
  backgrounded, exposes `cheatScore`/`buildReport()`.
- **`proctor_permissions.dart`** + **`proctor_setup_screen.dart`** — request
  camera+mic, show preview + brief room-scan countdown before the exam starts.
- **Integration** (`take_assignment_screen.dart`): after consent → setup screen
  starts the monitor; on submit the camera/audio score + timeline are **merged**
  with the lifecycle (`ExamProctor`) report into one `proctorReport` and a
  combined `cheatScore`. Camera/mic denial degrades gracefully (recorded in the
  report `notes`; lifecycle checks still run).
- **Legal**: privacy policy + consent sheet updated — camera/mic ARE used now,
  but analysis is **on-device** and **no images/audio are uploaded**, only the
  derived events.

### Still TODO / known limits (next)
- `PHONE_DETECTED` / `EARPHONE_DETECTED` are in the taxonomy/scoring but **not
  wired to a detector**: ML Kit's base object detector only classifies coarse
  categories and won't reliably label a phone/earphone. Reliable detection needs
  a custom TFLite model — **premium**.
- Head-angle left/right sign can be mirrored on the front camera; magnitude +
  score are what matter, labels are advisory.
- No video/photo evidence is captured (see 1b below — still premium).

## Phase 10 — BUILT (2026-06-15): network guard + back-camera room scan

### Network guard (Android `VpnService`)
- **Native**: `android/.../ExamGuardVpnService.kt` — a `VpnService` that routes
  all traffic into a tun and **drops it**, while `addDisallowedApplication(self)`
  excludes the exam app. Net effect: during the exam **no other app reaches the
  internet** (browser, AI assistants, messaging), so the student can't look up
  answers. Simple + robust — no userspace TCP/DNS stack needed.
- **Channels** (`MainActivity.kt`): MethodChannel `exam_guard/vpn`
  (`isSupported`/`prepare`/`start`/`stop`/`isActive`) + EventChannel
  `exam_guard/vpn_state` (`connected`/`revoked`/`stopped`/`error`). Manifest
  registers the service with `BIND_VPN_SERVICE` + `specialUse` FGS.
- **Flutter** (`lib/proctoring/network_guard.dart`): `ExamNetworkGuard` prepares
  (OS consent) + starts the guard, listens for state, **polls every 8s** as a
  fool-proof re-check, and records **downtime windows** when the student turns
  the VPN off mid-exam.
- **UX**: when the guard goes off, a red **banner** tells the student it's
  recorded (the one intentional student-facing proctor warning). Downtime
  windows become high-weight `NETWORK_GUARD_OFF` scored events + a `network`
  block in `proctorReport`; the grading UI shows a "Network off Nx · Ns" chip.
- **Platform**: Android-only. iOS (`NetworkExtension`) / desktop unsupported →
  guard reports `supported:false` and the exam continues with the other checks.
- Domain-level allow/deny (only block cheat domains, keep others) is the future
  enhancement; this raw version blocks all other apps wholesale.

### Back-camera room scan
- `lib/proctoring/room_scanner.dart` — opens the **back** camera during setup and
  runs ML Kit **face detection** (other people behind the device) + **object
  detection** (best-effort generic objects). Produces `RoomScanResult`
  (`peopleSeen`, `objectLabels`, `framesScanned`) folded into the score as
  `ROOM_PERSON` / `ROOM_OBJECT` events and a `roomScan` report block.
- `proctor_setup_screen.dart` now shows the live back-camera preview + people/
  object counts during the scan (previously it only counted down). Front-camera
  behaviour monitoring starts when the exam begins, as before.
- **Limit**: ML Kit's base object detector labels are coarse, so `objectLabels`
  is best-effort (people detection via faces is the reliable high signal). A
  custom phone/earphone TFLite model is still premium.

## Deferred / future improvements

### 1. Network-level detection — BUILT (Phase 10, Android). iOS/desktop deferred.
Done on Android via `VpnService` (see Phase 10). iOS needs a `NetworkExtension`
Packet Tunnel app-extension + entitlements (App Store review); desktop needs
system-proxy/root. Domain-level filtering (block only cheat domains while
forwarding the rest) needs a userspace DNS/TCP path — revisit for a managed/
kiosk or premium tier.

### 1b. Camera evidence (DEFERRED — premium)
2026-06-14: the user wants front-camera video of the student during the exam, with
clips auto-cut around violation timestamps and uploaded with the submission. Not
built — needs a `camera` package (capture) + ML and/or `ffmpeg` (clip-cutting) +
storage/upload + stronger consent. Belongs with the **Full AI proctoring tier**
(below). The `proctorReport` timeline already carries the timestamps a future
clipper would cut around.

### 2. Full AI proctoring tier
From `exam-guardian`: face/gaze monitoring, multiple-face & object detection,
liveness, audio/noise detection, screen-capture/record prevention, clipboard,
time-tamper, external-display & virtual-camera detection. Pulls heavy deps
(`camera`, `google_mlkit_*`, `face_detection_tflite`, `noise_meter`). Wire via
`exam-guardian`'s `ExamMonitor` orchestrator if/when a full tier is wanted.

### 3. Mobile hardening
- Android `FLAG_SECURE` (block screenshots/recording during exams).
- Screen pinning / kiosk mode; `UsageStatsManager` for real app-switch detection.
- iOS: detect screen recording (`UIScreen.isCaptured`).

### 4. Desktop hardening
`exam-guardian/lib/services/focus_monitor.dart` already has `DesktopFocusMonitor`
(window focus + `tasklist`/`ps` process scanning for Alt-Tab/forbidden apps).
Port it into `ProctorFocusMonitor` behind a platform check when desktop exams
matter.

### 5. Teacher-facing — DONE (Phase 8)
Grading UI now shows an integrity chip + cheat-score bar + flagged/forced tags +
violation timeline (`GradeSubmissionsScreen` / `_GradeSubmissionTile`).
