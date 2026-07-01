# ARCHITECTURE AUDIT — Flutter

## Summary
Single state-management library (Provider / `ChangeNotifier`) — good. But the codebase carries a **refactor scar**: an older structure (`Provider/`, `Screens/OrgScreens/`, `WEB_RTC/`) was partially migrated to a newer one (`Providers/`, `Screens/LMS/OrgMainScreens/`, `Live-Session/`), leaving duplicate/dead artifacts, stale imports, and two build-breaking missing files.

## Severity-ranked findings

### 🔴 P0 — Build-breaking (FIXED in this audit)
| Issue | Detail | Resolution |
|---|---|---|
| Missing `lib/core/token_manager.dart` | `TokenManager` referenced by main.dart + 3 files; absent from repo | Recreated as centralized SharedPreferences-backed store |
| Missing `lib/Providers/enrollment_provider.dart` | `EnrollmentProvider` referenced by main.dart + 7 screens; absent | Recreated matching all call-site signatures |

### 🟠 P1 — Duplicate state holders
| Concept | Holders | Recommended |
|---|---|---|
| Auth/user | `AuthProvider` (active) + `LoginProvider` (dead, commented) + `UserSessionManager` (static global) + `UserProvider` (dead) | Keep `AuthProvider`; delete `LoginProvider`,`UserProvider`; fold `UserSessionManager` into `AuthProvider` |
| Theme | `Providers/theme_provider.dart` (active) + `Theme/theme_provider.dart` (orphan, 0 imports) | Delete orphan |
| Organization | `OrganizationProvider` (active) + `OrgProvider` (`Providers/org_provider.dart`, dead) | Delete `OrgProvider` |

### 🟠 P1 — Duplicate models (same concept, multiple files)
| Concept | Locations |
|---|---|
| User | `models/auth/auth_model.dart#User` (canonical) · `api_models/user_model.dart#UserResponse` · `api_models/organization_model.dart#OrgUser` · `Live-Session/models/user_model.dart#UserModel` |
| Submission | `api_models/assignment_model.dart#Submission` · `api_models/submission_model.dart` (empty) · `lms/forms/models/submission_model.dart` (Firestore) |
| Organization | `auth/auth_model.dart#Organization` · `api_models/organization_model.dart#OrganizationResponse` · `lms_demo/models.dart#DemoOrganization` |
| Enums (`AttendanceStatus`,`LiveSessionStatus`,`QuestionType`,`EnrollmentStatus`) | duplicated across `api_models/enums.dart`, `api_models/attendance_model.dart`, `Live-Session/models/*`, `lms/forms/models/*` — forces `hide` clauses on imports in `api_service.dart` |
| Course/Class/LiveSession/Attendance | real in `api_models/` + demo variants in `lms_demo/models.dart` + `Live-Session/models/` (3rd attendance model in `Live-Session/features/attendance/models/`) |

### 🟡 P2 — Layering violations (widgets call API directly)
- `Screens/Deatiled_Screens/member_detail_screen.dart:44` — `context.read<ApiService>()`
- `Screens/Deatiled_Screens/classroom_detail_screen.dart:3153` — `context.read<ApiService>().getMembers(...)`
- `lib/lms/forms/*` — bypasses `ApiService`, talks to Firestore directly.

### 🟡 P2 — Demo code in production path
- `lms_demo/demo_constants.dart` → `const bool DEMO_MODE = true`
- `DemoServices` (hardcoded `http://192.168.100.157:3000`) registered in `main.dart` MultiProvider.
- Referenced from `main_scaffold.dart`.

### 🟡 P2 — Two backends inside one app
REST (`ApiService`/Dio) for the LMS vs Firestore (`FormService`) for `lms/forms`. Pick one source of truth for forms or isolate the Firestore feature behind a flag.

## Target layering (enforced going forward)
```
UI (widget)  ->  Provider  ->  (Repository)  ->  ApiService  ->  Dio  ->  Backend
```
Widgets must never call `ApiService` directly. See `REFACTOR_PLAN.md` for the staged migration.
