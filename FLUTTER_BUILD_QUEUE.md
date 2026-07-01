# Flutter Build Queue — UX Improvement Epic

Companion to `UX_IMPROVEMENT_APPENDIX.md` (design spec) and
`backend-rust/AGENT_SUPERPROMPT.md` (backend parity). This file = concrete,
ordered, ready-to-execute tasks with real file paths. Backup commit `b877693`.

## DONE (committed `c21bed2`)
- ✅ **Structured logging** — `lib/core/log/app_logger.dart` (`AppLog` + `logD/logI/logW/logE`).
  All 34 raw `print()` replaced. Use `final _log = AppLog('Tag');` in new code.
- ✅ **Notification deep-linking** — `lib/services/notification_router.dart`. Wired:
  `push_service.dart` (FCM `getInitialMessage`+`onMessageOpenedApp`),
  `local_notification_service.dart` (`onDidReceiveNotificationResponse`),
  `main.dart` (`NotificationRouter.instance.attach(navigatorKey)`).
  EXTEND: add `case`s in `_dispatch` as target screens gain id-only constructors.
- ✅ **@mention → user info sheet** — `lib/Widgets/user_info_sheet.dart`
  (`showUserInfoSheet`). Wired in `program_chat_screen.dart` `_buildText`.
- ✅ **Backend migrations** — `backend-rust/migrations/003_qa_coursechat.sql`
  (Q&A/DM, course chat, submission return-status + notes). 002 already adds core sync.

---

## QUEUE (ordered by effort/impact; each is additive + independently shippable)

### 1. Notification router — finish per-type targets  (LOW, HIGH)
File: `lib/services/notification_router.dart`. Existing screens & ctors:
- `assignment_grade`/`submission_returned` → needs an id-based AssignmentDetail (current
  `assignment_detail_screen.dart` ctor is COMMENTED OUT — re-enable with `{assignmentId}` ctor
  that fetches via `assignment_provider.dart`).
- `session_live` → MeetingPage (check `lib/Live-Session/features/meeting/meeting_page.dart` ctor).
- `material_new` → course material tab (`course_detail_screen.dart`).
Add a loader screen pattern: push a screen that takes only an id, shows shimmer, fetches, renders.

### 2. Consistent loading + pull-to-refresh  (LOW, HIGH) — appendix §11,§12
- Create `lib/Widgets/shimmer/` : `ShimmerList`, `ShimmerCard`, `ShimmerDetail`, `ShimmerChart`
  (use `shimmer` package — ADD to pubspec). 
- Create `lib/Widgets/async_view.dart`: `AsyncView<T>({loading, error, loaded})` switch helper.
- Wrap every scrollable list/grid in `RefreshIndicator(onRefresh: provider.load)`.
  Target screens: home tabs, course/program detail, chat, notification center, assignment list.

### 3. Unify theme → kill pink  (LOW, MEDIUM) — appendix §6  ⚠️ test visually
- Keep `lib/Theme/themedata.dart` (Peacock). DELETE `lib/Live-Session/theme/app_theme.dart`.
- Find importers: `grep -rl "Live-Session/theme/app_theme" lib` → switch each to `Theme.of(context)`.
- Reconcile duplicate dirs: `lib/Widgets/` (cap) vs `lib/widgets/` (lower) — pick `Widgets/`, update imports.
- Affected: MeetingPage, LobbyPage, WhiteboardPage, NotesPage, AttendancePage, ExamPage.
- RISK: visual regressions. Do last among low-effort; eyeball each Live-Session screen.

### 4. Per-assignment Q&A / DM  (MED, HIGH) — appendix §1  [needs backend 003 + Rust routes]
- Backend (Rust, see superprompt): routes `discussions`, `discussion_messages`,
  `direct_messages` CRUD. Tables in `003_qa_coursechat.sql`.
- Flutter: `lib/Screens/Discussion/` — `discussion_list_screen.dart` (Q&A tab on assignment
  detail, FAB "Ask Question"), `discussion_thread_screen.dart` (tree indent ≤3, Best Answer),
  `dm_thread_screen.dart` (1:1). Provider `lib/Providers/discussion_provider.dart`.
  API methods in `api_service.dart`. Reuse @mention autocomplete from `program_chat_screen.dart`.

### 5. Chat per course  (MED, HIGH) — appendix §2  [needs backend 003 + Rust routes]
- Backend: `course_chat_rooms/members/messages` routes; auto-enroll course students+teacher;
  teacher toggles `is_enabled`.
- Flutter: add "Chat" tab to `course_detail_screen.dart`; reuse `program_chat_screen.dart` UI
  parameterized by room scope (refactor it to accept a `ChatScope{programId|courseId}`), OR
  clone to `course_chat_screen.dart`. Wire socket room join.

### 6. At-risk student flags  (MED, MED) — appendix §7  [backend risk_score]
- Backend (Rust): `GET /analytics/at-risk?org=` computing weighted score (formula in appendix).
- Flutter: "At Risk" section on teacher dashboard (`lib/Screens/TeacherScreens/`), red/yellow/green
  dot rows, tap → student overview (`student_overview_screen.dart` already exists). CSV export btn.

### 7. Attendance export CSV/PDF  (LOW, MED) — appendix §8  [backend export]
- Backend: `GET /attendance/export?live_session_id=&format=csv|pdf`.
- Flutter: export button in live-session detail appbar → format sheet → `share_plus` the file.
  Use `csv` + `pdf`/`printing` packages (ADD to pubspec).

### 8. Per-student engagement graphs  (MED, MED) — appendix §9
- Data from `attention_events`+`attendance`+`activity_sessions` (backend analytics endpoint).
- Flutter: "Engagement" tab on `student_overview_screen.dart` using `fl_chart` (ADD to pubspec):
  bar (per session attention), line (daily active mins), pie (present/late/absent). Ghost line = class avg.

### 9. Submission return-status + private notes  (MED, MED) — appendix §19,§20  [backend 003]
- Backend: `submissions.review_status` + `returned_at` (in 003); `submission_notes` table CRUD;
  bulk "Return Work" endpoint.
- Flutter: status badge on assignment cards (Submitted/Graded/Returned); "Notes" tab on submission
  detail (Teacher Notes vs shared Private Comments). Notify on return (uses notification router).

### 10. Global search  (MED, HIGH) — appendix §14  [backend full-text]
- Backend: `GET /search?q=&scope=all|courses|materials|users|messages`. Postgres `to_tsvector`.
- Flutter: appbar search icon → full-screen overlay, 300ms debounce, recent searches in
  `shared_preferences`, results grouped by scope. New `lib/Screens/Search/global_search_screen.dart`.

### 11. Meeting reactions (emoji rain) + host controls  (MED, MED) — appendix §16,§18
- Socket events `reaction` + `audio:disable`/lock/remove/spotlight (backend SFU, see superprompt).
- Flutter (`meeting_page.dart`): reaction button → emoji row; floating animated emoji (overlay,
  rises + fades 2s, random x). Host-only control bar: Mute All / Lock / Remove / Spotlight.
  `HandRaiseIndicator` already exists — extend.

### 12. Gallery vs speaker view toggle  (LOW, MED) — appendix §17
- `meeting_page.dart`: toggle button (or double-tap) switches grid ↔ main+filmstrip. Persist
  pref in `shared_preferences` per session.

### 13. Page transitions + micro-interactions + haptics  (MED, MED) — appendix §21
- `lib/core/nav/fade_route.dart` + `zoom_route.dart`; `lib/core/haptics.dart` (`Haptics.light()`
  wrapping `HapticFeedback`). Apply on FAB/buttons. Hero on avatar→detail. Staggered list fade.
  AnimatedSwitcher 200ms on tab switch.

### 14. Multi-language MY + TH  (HIGH, HIGH) — appendix §22
- Flutter `gen-l10n`: `lib/l10n/app_en.arb` (extract hardcoded strings), `app_my.arb`, `app_th.arb`.
  `flutter_localizations` in pubspec; locale from device + Settings override dropdown.
  Priority screens first: auth, home, course detail, chat, meeting lobby.

### 15. GoRouter migration  (HIGH, HIGH) — appendix §13  ⚠️ touches everything
- ADD `go_router`. Define routes (table in appendix §13). Migrate incrementally — keep
  `Navigator.push` working, convert 10 most-used routes first. Enables deep-link targets in #1.

### 16. Virtual background / blur  (HIGH, MED) — appendix §15
- `flutter-webrtc` insertable streams + MediaPipe Selfie Segmentation (Android), VisionKit (iOS).
  Meeting "Effects" sheet: Blur/Image/None. Platform-gated; warn on low-end.

### 17. Mobile widgets (iOS Today / Android)  (MED, LOW) — appendix §23
- `home_widget` package; show next session countdown + next deadline. Native targets.

---

## Conventions for any new code
- Logging: `AppLog('Tag')` — never `print`.
- Loading: use `AsyncView` + shimmer (after #2 lands).
- Navigation deep-link: register the type in `notification_router.dart`.
- New deps go in `pubspec.yaml`; run `flutter pub get` + `dart run build_runner build` if codegen.
- Verify each chunk: `flutter analyze lib` → 0 errors before commit.
- Commit per feature, not per file.

## Verify gate
`flutter analyze lib` must show **0 errors** (warnings/info pre-exist, ~500 baseline).
