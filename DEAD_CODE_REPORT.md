# DEAD CODE REPORT

> **Findings only — nothing here was auto-deleted.** Reachability computed from `main.dart` (98 files reachable at runtime). "Unreachable" = not compiled by `flutter run` but still flagged by `flutter analyze`.

## Stale imports pointing at moved files (analyzer errors, runtime-safe)
All are in **commented-out lines** or **unreachable** files, so they do **not** break `flutter run`. Repoint or delete when cleaning up:
| Importer | Bad import | Real location |
|---|---|---|
| `Screens/LMS/OrgMainScreens/OrgWidgets/premium_sidebar.dart` | `Provider/organisation_provider.dart` | `Providers/AdminProviders/organisation_provider.dart` |
| `Screens/LMS/course_list_screen.dart`, `lms_demo/demo_screens.dart` (commented) | `Screens/LMS/course_detail_screen.dart` | `Screens/Deatiled_Screens/course_detail_screen.dart` |
| `Screens/LMS/OrgMainScreens/org_core_home.dart` | `Screens/OrgScreens/.../create_widgets.dart`, `.../invitation_screen.dart`, `.../org_tabs/members_tab.dart` | `Screens/LMS/OrgMainScreens/...` (members_tab has no equivalent → use `AdminScreens/members_screen.dart`) |
| `Screens/TeacherScreens/*` (commented) | `Screens/ClassroomScreen/classroom_screen.dart` | `Screens/Deatiled_Screens/classroom_detail_screen.dart` |
| `Screens/LMS/live_session_list_screen.dart` | `WEB_RTC/features/lobby/lobby_page.dart` | `Live-Session/features/lobby/lobby_page.dart` (note: lobby_page is itself commented-out) |

## Dead files (commented-out or 0 external refs) — safe to delete
| File | Reason |
|---|---|
| `Providers/login_provider.dart` | 100% commented (duplicate of AuthProvider) |
| `Providers/org_provider.dart` | commented (duplicate of OrganizationProvider) |
| `Providers/user_provider.dart` | commented (duplicate of AuthProvider/UserSessionManager) |
| `Theme/theme_provider.dart` | orphan; 0 importers (active one is `Providers/theme_provider.dart`) |
| `Screens/Deatiled_Screens/classroom_nav_usage.dart` | orphan; 2nd `ClassroomArgs`, all demo data |
| `Screens/TeacherScreens/PATCH_open_org_shell.dart` | a code-patch snippet, not a screen; 0 refs |
| `models/api_models/submission_model.dart` | effectively empty (commented); real `Submission` in `assignment_model.dart` |
| `Service/auth_service.dart` | dead duplicate refresh logic |
| `Live-Session/core/services/auth_service.dart`, `features/auth/auth_service.dart` | dead, hardcoded dead URLs |
| `Live-Session/features/auth/{login_page,two_factor_page}.dart`, `features/dashboard/dashboard_page.dart`, `features/lobby/lobby_page.dart`, `core/services/wrapper/auth_wrapper.dart` | 100% commented |
| `Live-Session/features/attendance/*`, `features/exam/*` (+ models) | 0-byte empty files |

## Orphan providers (registered nowhere, no screen)
- `Providers/progress_provider.dart`, `Providers/student_clr_view_provider.dart`.

## Unused / stub screens
- `Screens/AuthScreens/register_screen.dart` → returns `const Placeholder()`.
- `Screens/Teacher/Home/teacher_dashboard_screen.dart` → likely orphan duplicate of `TeacherScreens/teacher_dashboard_screen.dart`.

## Demo cluster (remove to de-mock)
- `lib/lms_demo/` (`demo_constants.dart` `DEMO_MODE=true`, `demo_services.dart`, `demo_screens.dart`, `models.dart`).

## Whole-directory candidates (optional, NOT performed)
- `live_stream_backend/` — orphaned service (see LIVESTREAM_AUDIT).
- `htoo-chon-backend/src/gateway/meeting.gateway.ts` + `room.service.ts` — dead WebRTC-mesh gateway (not in providers).

## Deletion guidance
Delete in this order, running `flutter analyze` after each batch: (1) commented dead providers, (2) orphan Theme/submission_model, (3) orphan screens, (4) demo cluster (after de-mocking call sites), (5) Live-Session empty/commented files. Keep `Live-Session/core/services/{socket_service,mediasoup_service,screen_service}.dart` and `features/meeting/*` — those are the live path.
