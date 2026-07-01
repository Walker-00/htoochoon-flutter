# Deployment Readiness — Phases 1–5

Generated at Phase 6 (final validation). Covers the work delivered in this
protocol: socket/auth lifecycle, recurring live sessions, waiting room + join
races, real-time notifications, and exam proctoring.

## ✅ Validation results

| Gate | Command | Result |
|------|---------|--------|
| Backend build | `npm run build` (nest build) | **PASS** (exit 0) |
| Backend typecheck | `npx tsc --noEmit` | **PASS** (0 errors) |
| Prisma schema | `npx prisma validate` | **valid 🚀** |
| Flutter analyze | `flutter analyze` | **0 errors** (1161 info/warning — pre-existing lint debt: `withOpacity`, `print`, naming) |
| Backend tests | `npm test` (jest) | ⚠️ 1 pre-existing failure — see below |
| Flutter tests | `flutter test` | ⚠️ no test files in `test/` |

### Test caveats (honest)
- The only backend spec is the **default Nest scaffold** `app.controller.spec.ts`,
  which asserts `getHello()` returns `"Hello World!"`. The app intentionally
  changed `getHello()` to throw `ImATeapotException` (a joke), so the scaffold
  test fails. **This is pre-existing and unrelated to Phases 1–5** (no phase
  touched `app.service.ts`/`app.controller.ts`). Either delete/adjust that spec
  or restore the greeting.
- There are **no feature/unit tests** for the LMS. Phases 1–5 were validated by
  compile + static analysis (0 errors both stacks) and code-level tracing.
  Adding a test harness is recommended before scaling (see "Recommended next").

## 🗄️ Database migrations — run order

Apply **in this order** on the target DB (timestamps already order them):

```bash
cd htoo-chon-backend
npx prisma migrate deploy
npx prisma generate
```

Pending migrations bundled in this branch:

| Migration | Phase | Adds |
|-----------|-------|------|
| `20260607000000_program_chat_and_scheduling` | (prior: D) | program chat rooms + messages, LiveSession program/timezone cols |
| `20260608000000_course_materials` | (prior: F) | course materials |
| `20260609000000_live_session_recurrence` | **2A** | `LiveSessionSeries` + `LiveSession.seriesId/isDetached` |
| `20260609010000_notifications` | **4A** | `Notification` + `NotificationType` enum + `User.notifications` |
| `20260609020000_submission_proctoring` | **5** | `Submission.violationCount` / `flagged` |

All five are **additive & non-destructive** (new tables/enums + nullable/defaulted
columns) — safe to `migrate deploy` against existing data.

## 📦 Dependencies

- Backend gained **`rrule ^2.8.1`** (Phase 2A). Run `npm install` on deploy.
  - ⚠️ `mediasoup`'s postinstall builds a native worker via Python/`pip`. In CI/
    deploy ensure Python + pip are available, or the existing worker binary is
    present. (Pre-existing requirement; locally we used `npm install --ignore-scripts`.)
- Flutter: **no new packages** (notifications reuse `dio`/`shared_preferences`/
  `socket_io_client`; proctoring is dependency-free).

## 🚀 Deploy checklist

1. `git pull` the `rust` branch (Phases 1–5 commits `d5a4df9` … `4be0496`).
2. Backend: `npm install` → `npx prisma migrate deploy` → `npx prisma generate`
   → `npm run build` → restart (`npm run start:prod`).
3. Flutter: `flutter pub get` → build per target (Waydroid/APK/etc.).
4. Smoke test (needs a running gateway + DB + device):
   - **Auth/socket (P1):** login → one socket id; logout disconnects; resume reconnects.
   - **Scheduling (P2):** teacher schedules one-off + recurring; edit-split (this/following/all); students see flattened instances.
   - **Waiting room (P3):** student before host → waiting screen; teacher joins → student proceeds; host drops → students re-park.
   - **Notifications (P4):** start a session → enrolled students get a push + badge; center lists/marks-read.
   - **Proctoring (P5):** during an exam, background the app > 2s → violation snackbar; 3 → auto-submit; submission shows `flagged`/`violationCount`.

## ⚠️ Known gaps / deferred (flagged across phases)

- **Program-targeted recurring sessions (2B)** — the Flutter `LiveSession` model
  has non-null `classId`; the wizard is class-scoped. Program scope + a recurrence
  badge need a model nullability pass + `seriesId` field.
- **Notification deep-link (4B)** — tapping a `SESSION_LIVE` notification marks
  read; auto-join needs the student/teacher join-token flow.
- **Network-level proctoring (5)** — local proxy/VPN interception is **documented
  but not built** (heavy: `VpnService`/`NetworkExtension`/root). See
  `PROCTORING_NOTES.md`.
- **Full AI proctoring tier (5)** — face/gaze/audio/object detection from
  exam-guardian (heavy deps), deferred.
- **Lint debt** — ~1161 Flutter info/warnings (`withOpacity → withValues`,
  `avoid_print`, naming). Cosmetic; 0 errors.
- **Pre-existing:** `meeting_chat_overlay` stub; `LiveGateway`/`MeetingGateway`
  namespace overlap (P2P vs SFU); the teapot scaffold test.

## 🔧 Recommended next (not in scope)

- Add a minimal test harness (gateway unit tests for the join race/waiting room;
  service tests for recurrence expansion and notification fan-out).
- Surface `flagged` submissions in the teacher grading UI.
- Burn down the `withOpacity → withValues` lint sweep.
