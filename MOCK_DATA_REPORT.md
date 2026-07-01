# MOCK / STATIC DATA REPORT

Search terms: `mock`, `demo`, `sample`, `dummy`, `placeholder`, `fake`, `hardcoded`, plus inline literal lists in dashboard/home/profile/subscription screens.

| # | File : line | What's hardcoded | Replace with |
|---|---|---|---|
| 1 | `lms_demo/demo_constants.dart:1` | `const bool DEMO_MODE = true` global flag | Remove flag / set false; stop gating UI on it |
| 2 | `lms_demo/demo_services.dart:14` | base URL `http://192.168.100.157:3000` | `ApiService` (real base URL) |
| 3 | `lms_demo/demo_services.dart:31` | `organizations` list (Demo Academy, Tech Institute) | `OrganizationProvider` → `GET /organizations` |
| 4 | `lms_demo/demo_services.dart:36` | `classrooms` list (Grade 10 A/B, Web Dev Basics) | `ClassProvider` → `GET /classes` |
| 5 | `Screens/Subsciption/subscription_screen.dart:55` | `mockPlans` (4 plans) rendered at 412–434 | `SubscriptionProvider` → `GET /organizations/:id/plan/available` |
| 6 | `Screens/Notification/notification.dart:74` | `_all` notifications list; filters (71); message/icon lists (904/928) | No backend notification endpoint yet — keep static but isolate, or add endpoint (see note) |
| 7 | `Screens/Deatiled_Screens/classroom_nav_usage.dart` | `_demoExams`/`_demoMaterials`/`_demoSessions`/`_demoPeople` (orphan file) | Delete file (dead, see DEAD_CODE_REPORT) |
| 8 | `Screens/AuthScreens/register_screen.dart:14` | returns `const Placeholder()` | Implement or remove route |
| 9 | `Screens/Teacher/Home/teacher_dashboard_screen.dart:732` | `_CalendarSectionPlaceholder` | Real schedule data or hide |
| 10 | `Live-Session/features/dashboard/dashboard_page.dart` | mock classes + room `'full-stack-webrtc-101'`, host `'Dr. Mila'` (commented) | Dead — remove |
| 11 | `Live-Session/features/meeting/meeting_page.dart:280,569,633,803` | `"Remote Peer"`, `_isUserTeacher()=>false`, empty-email `UserModel`s | Wire participant identity from join payload |

## Dashboard / Home / Profile — data-source audit (Phase 5)

| Surface | Current source | Correct source |
|---|---|---|
| **Home tab** (`Screens/Home/home_tab.dart`) | Mix: real (`EnrollmentProvider.myCourse/Program`), but greeting/stat cards static | `AuthProvider.user` + `EnrollmentProvider` counts (de-mock applied in this audit) |
| **Profile tab** (`Screens/Profile/profile_tab.dart`) | Mostly static labels | `AuthProvider.user` (name/email/avatar/role) |
| **Org/Admin dashboard** (`AdminScreens/dashboard_screen.dart` ← `DashboardProvider`) | Real: `GET /organizations/:id/plan` + `/plan/usage` + `/live-sessions` | OK — already real |
| **Subscription screen** | `mockPlans` | `GET /organizations/:id/plan/available` |
| **Platform-admin stats** | n/a (not built) | `GET /admin/stats` → `{totalUsers, totalPrograms, invitationStats}` |

> Backend dashboard sources confirmed: `/admin/stats` returns `{ totalUsers, totalPrograms, invitationStats }`; `/organizations/:id/usage` returns `{ plan, usage: { key: { current, max, percentage } } }`; `findOne` already attaches `usagePercentage`.

**Note (notifications):** there is no notification endpoint in the backend (the `Otp`/`Campaign` models aside). The hardcoded notification list is therefore the only option until a `/notifications` route is added — flagged as a backend gap, not a quick frontend fix.
