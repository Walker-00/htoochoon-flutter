# STATE DEPENDENCY GRAPH

Pattern (all providers): `Screen → context.read/watch<Provider> → Provider(ApiService) → ApiService(Retrofit) → Dio → Backend`. There is **no repository tier** (provider doubles as repository).

## Registered providers (main.dart MultiProvider)
```
AuthProvider(apiService, dio) ─────────► /auth/*, /users/me, /users/:id
EnrollmentProvider(apiService) ────────► /enrollment/* (RECREATED in this audit)
DashboardProvider(apiService) ─────────► /organizations/:id/plan, /plan/usage, /live-sessions
OrganizationProvider(apiService) ──────► /organizations/*
CoursesProvider(apiService) ───────────► /courses/*
ProgramsProvider(apiService) ──────────► /programs/*
ClassProvider(apiService) ─────────────► /classes/*
LiveSessionProvider(apiService) ───────► /live-sessions/*, /teacher|student/live-sessions/:id/join
StructureProvider(apiService) ─────────► program↔course structure
SubscriptionProvider(apiService) ──────► /organizations/:id/plan*
InvitationProvider(apiService) ────────► org members (partly local)
AssignmentProvider(apiService) ────────► /assignments/*, /submissions/*
DemoServices(dio) ─────────────────────► hardcoded LAN URL (DEMO — remove)
ThemeProvider() ───────────────────────► SharedPreferences
ApiService (Provider.value)
SocketService (Provider) ──────────────► live/live.gateway.ts (socket.io)
```

## Screen → provider map (selected)
| Screen | Providers consumed |
|---|---|
| `Home/home_tab.dart` | AuthProvider, EnrollmentProvider, LiveSessionProvider |
| `Classes/classes_tab.dart` | EnrollmentProvider |
| `Courses/courses_tab.dart` | CoursesProvider, ProgramsProvider, EnrollmentProvider, StructureProvider |
| `AdminScreens/dashboard_screen.dart` | DashboardProvider, SubscriptionProvider |
| `AdminScreens/enrollment_tab.dart` | EnrollmentProvider |
| `Deatiled_Screens/course_detail_screen.dart` | EnrollmentProvider, ClassProvider |
| `Deatiled_Screens/program_detail_screen.dart` | StructureProvider, EnrollmentProvider |
| `Profile/profile_tab.dart` | AuthProvider |

## Problems

### Orphan providers (defined, never registered, no screen)
- `Providers/progress_provider.dart` (`ProgressProvider`) — attendance/submissions.
- `Providers/student_clr_view_provider.dart` (`StudentClassroomProvider`).
- `lms/forms/providers/form_builder_provider.dart` (Firestore feature, isolated).

### Dead providers (commented out)
- `Providers/login_provider.dart`, `Providers/org_provider.dart`, `Providers/user_provider.dart`.

### Duplicate state
- Auth/user: `AuthProvider` ⨉ `UserSessionManager` (static) ⨉ dead `LoginProvider`/`UserProvider`.
- Theme: `Providers/theme_provider.dart` (active) ⨉ `Theme/theme_provider.dart` (orphan).
- Org: `OrganizationProvider` ⨉ dead `OrgProvider`.

### Direct-API-in-UI (skips provider)
- `member_detail_screen.dart:44`, `classroom_detail_screen.dart:3153`.

### No circular provider dependencies detected
(Providers depend only on `ApiService`/`Dio`, not on each other.)

## Target
1 provider per domain, registered once; static `UserSessionManager` folded into `AuthProvider`; orphan/dead providers deleted; optional repository tier inserted between provider and `ApiService` (see REFACTOR_PLAN).
