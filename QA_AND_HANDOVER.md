# QA & Handover Report

Covers Phases 2–4 of the LMS hardening effort: Exam System fix, Program-centric
Enrollment redesign, and a cross-cutting QA audit against the product vision
(Google Classroom + Forms + Meet + Anti-Cheating).

---

## 1. Bugs Fixed

### Exam system ("create succeeds, exam never appears")
Root cause was a chain, not one fault:
1. **`dueDate` contract mismatch (primary).** Backend `Assessment.dueDate` is
   nullable; the Flutter list model parsed it as non-null `DateTime.parse(...)`.
   One null-dueDate row crashed the whole class list → "no exams".
   *Fix:* `Assignment.dueDate` → `DateTime?` (model + generated parser/serializer);
   all `_formatDate` / `isOverdue` call sites null-guarded.
2. **Silent false success.** Create screen showed "Exam created!" without
   checking the (nullable) result. *Fix:* check result, surface real error.
3. **Optimistic-append shape drift.** Provider appended the POST response
   (shape with `questions`) into a list of a different shape (`_count`).
   *Fix:* `createAssignment` now reconciles from the server after create.
4. **Unreachable enum values.** Exam tab matched only `type == TEST`; `QUIZ`/`EXAM`
   were invisible. *Fix:* exam tab filter is now `type != ASSIGNMENT`.
5. **Visibility (teacher vs student).** Both roles fetched identically. *Fix:*
   `getAssignmentsByClass` gained `publishedOnly`; students fetch published-only,
   teachers/admins see drafts.

Latent edit/delete bugs also fixed:
- `UpdateAssessmentDto.type` was **required** → editing a title would 400.
  *Fix:* made optional (the update service never reads it).
- `deleteAssessment` did a bare delete → an exam **with submissions** failed on a
  FK constraint. *Fix:* transactional delete (remove submissions first).

### Enrollment desync (the Phase-1 audit's Flaw #1)
Program enrollment granted no access; all student gates used `ClassMember`, so
program-enrolled students couldn't see classes, submit, or join live sessions
until manually added per class. **Fixed** by the redesign below.

### Earlier session fix
- `EnrollmentProvider.acceptProgramEnrollment` was missing (compile error in
  the admin enrollment tab) — added.
- Android `mipmap/launcher_icon` missing → build failure. Generated via
  `flutter_launcher_icons`. App builds and runs on Waydroid.

---

## 2. Architecture Improvements (Program-centric Enrollment)

**Single source of truth:** an ACTIVE `ProgramEnrollment` now grants access to
**every** course and class under the program (current and future), derived via
`Program → ProgramCourse → Course → Class`.

**New table — `ClassExclusion`** (the only schema addition): per-class opt-out.
`@@unique([classId, userId])`, FK-cascade on class/user delete.

**`ClassMember`** is deprecated for students (retained for teacher-in-class
assignment and as a transition-window legacy fallback).

**One helper owns the rule** — `EnrollmentAccessService` (`@Global`):
- `canAccessClass(userId, classId)` — exclusion ❌, else program-derived ✅, else
  legacy ClassMember fallback.
- `getAccessibleClassIds(userId)` and `getClassStudentIds(classId)` (derived roster).

Rewired to use it: `student.service` (`getJoinedClasses`, `submitWork`,
`joinLiveSession`), `classes.service.findAllStudents` (derived roster),
`live.gateway` (`live-session:join` now gated), `enrollment.service`
(program enrollments return all inherited classes minus exclusions).

**API changes:**
- `POST /classes/:id/students` → **deprecated** (403; use program enrollment).
- `DELETE /classes/:id/students/:userId` → now creates a **ClassExclusion** (back-compat).
- `POST /classes/:id/exclusions`, `DELETE /classes/:id/exclusions/:userId` → explicit opt-out.

**UI changes:**
- Class detail: "Add Student" removed; roster is read-only; "remove" is now a
  clearly-labelled per-class **exclusion** (student stays program-enrolled).
- Program detail: **"Enroll student" FAB** (admin/teacher) with a member picker
  enrolling directly as ACTIVE; Members/Pending tabs remain the management surface.

---

## 3. Edge Cases Handled
- **Exclude from one class** → `ClassExclusion`; re-include by deleting it.
- **Future class added to a program** → inherited automatically (no action).
- **Mid-program enrollment** → instant access to all existing classes.
- **Dropped from program** → loses access to all program classes at once.
- **Course in multiple programs** → access via any containing program.
- **Standalone (non-program) course** → `CourseEnrollment` lane retained.
- **No data loss on migration** → idempotent backfill creates ACTIVE program
  enrollments for existing class members; legacy fallback covers orphans.

---

## 4. Product-Vision / Live-Streaming / Anti-Cheating Conflict Analysis
- **Live sessions ↔ inherited access:** consistent and improved. Both the REST
  (`student.service.joinLiveSession`) and socket (`live-session:join`) paths now
  gate on `canAccessClass`, so program-enrolled students can join their classes'
  sessions — and only those. Attendance upsert is unaffected.
- **Exams ↔ inherited access:** a program student can now access/take exams in
  every inherited class. Exam *visibility* is correctly gated (published-only for
  students). ⚠️ See residual risk #1 — the primary submission endpoint is not
  access-gated.
- **Anti-cheating:** NOT implemented anywhere (all references are commented-out
  UI stubs). The wider exam surface from inheritance makes proctoring more
  important — see recommendations.

---

## 5. Residual Technical Debt & Recommendations

1. **`POST /submissions` lacks authorization (HIGH).** The create route has no
   `@RequireOrgRole` and no class-access check — any authenticated user can
   submit to any assessment by id, and `studentId` is taken from the body.
   *Recommend:* gate with `canAccessClass(req.user.id, assessment.classId)` and
   force `studentId = req.user.id`.
2. **Anti-cheating is absent (HIGH for vision).** Design a proctoring event
   channel (tab/focus loss, multi-face, copy/paste, fullscreen exit) on the live
   gateway + an exam-session lockdown, persisted as violations per submission.
3. **Migration prerequisites (deploy).** Run `prisma generate` then
   `prisma migrate deploy` against the target DB. Backfill uses
   `gen_random_uuid()` (Postgres 13+ core). Review the logged orphan list (class
   members whose course is in no program) for manual program assignment.
4. **Legacy fallback cleanup.** After verifying derived access in production,
   remove the `ClassMember` fallback in `EnrollmentAccessService` (search
   "legacy fallback") and retire the deprecated class-add route.
5. **Dead client surface (LOW).** `ApiService.addStudentToClass` /
   `ClassProvider.addStudentToClass` are now unreachable from the UI; remove in a
   follow-up (requires regenerating `api_service.g.dart`). Also the unused
   `/schools/*` declarations from the earlier audit.
6. **`student.service.submitWork` is still a stub** (validates access, never
   persists). Either implement or route everything through `POST /submissions`.

---

## 6. Verification Status
- **Flutter:** `flutter analyze` → **0 errors** across all phases. App builds and
  launches on Waydroid (login screen verified earlier).
- **Backend:** no toolchain in this workspace (`node_modules` absent), so no
  `tsc`/`prisma` run. Changes were reviewed against the actual Prisma client API,
  composite-key names (`classId_userId`), the `NotFoundException(resource, id?)`
  signature, and module/DI wiring (`@Global` access module). `tsconfig` does not
  enable `noUnusedLocals`, so deprecated-but-unused imports are non-blocking.
- **End-to-end caveat:** the Flutter app points at the deployed
  `htoochoon.kargate.site` backend, which does **not** yet contain these backend
  changes. Full E2E validation requires deploying the backend and applying the
  migration first.

---

## 7. Suggested Deployment Order
1. Backend: `npm install` → `npx prisma generate` → `npx prisma migrate deploy`.
2. Review migration's orphan log; assign any orphaned students to programs.
3. Deploy backend; smoke-test: program enroll → student sees inherited classes →
   join live session → take published exam → exclude from one class.
4. Ship the Flutter build.
5. After a verification window, remove the legacy ClassMember fallback (debt #4).
