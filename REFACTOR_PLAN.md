# REFACTOR PLAN

Prioritized, lowest-risk-first. Each phase should end with `flutter analyze` (and ideally `flutter run`) **on your machine** — this environment has no Flutter SDK, so changes here are verified by inspection only.

## ✅ Phase 0 — Make it build (DONE in this audit)
- Recreated `lib/core/token_manager.dart` (centralized token store).
- Recreated `lib/Providers/enrollment_provider.dart` (matches all 12 call sites).
- Fixed 3 API verb/path bugs in `api_service.dart` **and** generated `api_service.g.dart`:
  `updateClass` PUT→PATCH, `deleteProgramCourse` POST→DELETE, `uploadOrganizationLogo` path.
- **Result:** the 98-file runtime graph reachable from `main.dart` has no missing imports.

## ✅ Phase 1 — De-mock user-facing screens (DONE / in progress this audit)
- Home tab greeting + stat cards → `AuthProvider.user` + `EnrollmentProvider` counts.
- Profile tab → real `AuthProvider.user` (name/email/role/avatar).
- Subscription screen `mockPlans` → `SubscriptionProvider` / `GET /plan/available`.
- Remove `DEMO_MODE` gating from `main_scaffold`.

## Phase 2 — Auth consolidation (next)
1. Delete dead auth paths: `Service/auth_service.dart`, `Providers/login_provider.dart`, `Live-Session/.../auth_service.dart` (×2).
2. Fold `UserSessionManager` (static) into `AuthProvider`; expose `userId`/`orgRole` there.
3. Move Live-Session 2FA call into `AuthProvider`.
4. Add **session management UI** (`GET /auth/sessions`, `DELETE /auth/sessions/:id`).

## Phase 3 — Kill duplicates
1. Delete orphan `Theme/theme_provider.dart`, dead `Providers/org_provider.dart`, `Providers/user_provider.dart`, empty `models/api_models/submission_model.dart`.
2. Consolidate model `User`/`Organization`/`Submission`/enums onto the `api_models/*` + `auth/auth_model.dart` canon; drop `hide` clauses in `api_service.dart`.
3. Delete orphan screens/providers per DEAD_CODE_REPORT (one batch at a time + analyze).

## Phase 4 — Layering hygiene
1. Remove direct `ApiService` calls from widgets (`member_detail_screen.dart:44`, `classroom_detail_screen.dart:3153`) — route through a provider.
2. Repoint stale imports in unreachable files (or delete those files).

## Phase 5 — Target architecture (larger, optional)
Introduce a thin **repository** tier and group by feature. Do this incrementally (one feature at a time), not as a big-bang move:
```
lib/
  core/      api/ auth/ network/ storage/ errors/
  features/  auth/ dashboard/ organizations/ programs/ courses/ classes/
             assignments/ attendance/ live_sessions/ subscriptions/
               <feature>/data/{models,services,repositories}
               <feature>/presentation/{screens,widgets,providers}
  shared/    widgets/ theme/ utils/
```
Enforce: `UI → Provider → Repository → ApiService → Backend`. Widgets never call APIs directly.

## Phase 6 — Live-stream polish
Fix screen-share event-name asymmetry, `stopScreenShare` flag, producer-id arg; wire or remove chat overlay (see LIVESTREAM_AUDIT).

## Phase 7 — Backend gaps to consider
- Add `/notifications` endpoint (frontend notifications are hardcoded for lack of one).
- Decide fate of `live_stream_backend/` and dead `meeting.gateway.ts`.

## Risk notes
- `api_service.g.dart` is generated; if you run `dart run build_runner build`, re-apply nothing — the source annotations in `api_service.dart` are already correct, regeneration will reproduce the fixes.
- No SDK here → treat every change as needing a local `flutter analyze` before relying on it.
