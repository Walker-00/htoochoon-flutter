# SYSTEM MAP — HTOO CHOON LMS

> Generated during full technical audit. Source of truth = backend implementation + Prisma schema + NestJS controllers (the OpenAPI `docs-json.json` is generated at runtime by Swagger and is **not committed**, so the route surface below was extracted directly from the controllers).

## 1. Codebases

| Codebase | Stack | Size | Role |
|---|---|---|---|
| `lib/` | Flutter (Provider state mgmt) | 174 Dart files, ~65k LOC | Mobile/web client |
| `htoo-chon-backend/` | NestJS + Prisma + PostgreSQL | 17 controllers, ~90 REST endpoints, 24 models | **Main LMS backend (source of truth)** |
| `live_stream_backend/` | NestJS + Prisma + socket.io | 31 files | **Orphaned** stub (see §6) |

## 2. Main backend — modules & responsibilities

Bootstrapping (`src/main.ts`): global `ValidationPipe` (whitelist + transform), `AllExceptionsFilter`, static `/uploads`, Swagger. Global guards (`app.module.ts`): `JwtAuthGuard` (APP_GUARD) + `PlanLimitGuard` (APP_GUARD).

| Module | Controller base | Purpose |
|---|---|---|
| Auth | `/auth` | register/login, OTP, 2FA (TOTP), JWT access + DB-backed refresh sessions |
| Admin | `/admin` | platform stats, user status, create program/course |
| Users | `/users` | profile, role, avatar upload, invitations, leave org, change password |
| Organizations | `/organizations` | org CRUD, members, transfer ownership, usage |
| Subscriptions | `/organizations/:organizationId/plan` | plan get/update/check/usage/available |
| Programs | `/programs` | program CRUD + program↔course links |
| Courses | `/courses` | course CRUD |
| Classes | `/classes` | class CRUD + students |
| Assignments | `/assignments` | assessment CRUD + details by class |
| Attendance | `/attendance` | mark + query by class/student |
| Enrollment | `/enrollment` | program & course enrollment CRUD + status |
| Live-sessions | `/live-sessions` | session CRUD + start/end |
| Student | `/student` | classes, join class, submit, invitations, join live session |
| Teacher | `/teacher` | assignments, publish, live sessions, submissions, grade |
| Submissions | `/submissions` | submit, grade, query, delete |
| Questions | `/questions` | question attachments |
| **Live gateway** | socket.io `/` | `live/live.gateway.ts` — **MediaSoup SFU** (~25 events) — the REAL realtime layer |
| Meeting gateway | socket.io | `gateway/meeting.gateway.ts` — WebRTC-mesh signaling (8 events) — **imported but NOT registered in providers → dead** |

### Prisma data model (24 models)
`Organization, OrganizationMember, User, Session, UserSubscription, OrganizationPlan, Program, ProgramCourse, Course, ProgramEnrollment, CourseEnrollment, Class, ClassMember, Assessment, Question, QuestionOption, QuestionAttachment, Submission, SubmissionAnswer, SubmissionAttachment, Invitation, LiveSession, Attendance, Otp, Campaign`.

Roles: `PlatformRole {USER, ADMIN}`, `OrgRole {ORG_ADMIN, TEACHER, STUDENT, STAFF}`.
Auth sessions: `Session{refreshJti, refreshHash, deviceId, revoked}` — supports multi-device + revocation.

## 3. Flutter architecture (as-is)

```
Entry: main.dart  ->  builds Dio (baseUrl https://htoochoon.kargate.site/) + interceptor
                  ->  ApiService (Retrofit)  ->  MultiProvider (14 ChangeNotifiers)
                  ->  MyApp  ->  AuthWrapper (switch on AuthProvider.status)
                                 |- authenticated  -> MainScaffold (IndexedStack: Home / MyLearning / Courses / Settings)
                                 |- needsOtp        -> OtpScreen
                                 |- unauthenticated -> PremiumLoginScreen
```

- **State mgmt:** Provider only (`ChangeNotifier`). No GoRouter — imperative `Navigator.push`.
- **No repository layer.** Layering is `UI -> Provider -> ApiService(Retrofit) -> Dio`. Provider tier substitutes for repositories.
- **Token flow:** `TokenManager` (centralized, recreated in this audit) ↔ `SharedPreferences` (`access_token`/`refresh_token`/`user_id`) ↔ Dio interceptor (auto-attach bearer + 401 refresh via `POST /auth/refresh`).

### Provider → backend wiring (high level)
| Provider | Talks to |
|---|---|
| AuthProvider | `/auth/*`, `/users/me`, `/users/:id` |
| OrganizationProvider | `/organizations/*` |
| SubscriptionProvider / DashboardProvider | `/organizations/:id/plan*`, `/live-sessions` |
| ProgramsProvider / CoursesProvider / ClassProvider | `/programs`, `/courses`, `/classes` |
| EnrollmentProvider | `/enrollment/*` |
| AssignmentProvider | `/assignments`, `/submissions` |
| LiveSessionProvider | `/live-sessions`, `/teacher|student/live-sessions/:id/join` |
| InvitationProvider | org members (partly local) |

## 4. Realtime / live session flow (the working one)

```
Flutter (LiveSessionProvider) --REST--> main backend /teacher|student/live-sessions/{id}/join
   -> returns { meetingCode, accessToken, refreshToken }
Flutter SocketService (socket.io, https://htoochoon.kargate.site/) --setAuth(token)-->
   main backend live/live.gateway.ts (MediaSoup SFU)
   events: live-session:join, mediasoup:create-transport/connect-transport/produce/consume,
           mediasoup:screen:start/stop, meeting:action (hand-raise/record/toggle), attendance:mark, ...
```

## 5. Secondary backends / parallel sub-apps in Flutter

- **`lib/lms/forms/`** — a Firebase **Firestore**-backed forms/quiz feature (own models/providers/services). Architecturally divergent from the REST app.
- **`lib/lms_demo/`** — demo scaffolding wired into production (`DEMO_MODE=true`, `DemoServices` registered in MultiProvider, hardcoded LAN URL).

## 6. `live_stream_backend` — orphaned

Separate NestJS service modelling **HLS "streams"** (`Stream{streamKey, streamUrl, isEnded}`), NOT meetings. Its `gateway.gateway.ts` has **zero `@SubscribeMessage` handlers**, **no MediaSoup**, unauthenticated sockets, and `auth/login` returns only `access_token` (no refresh/2FA). **Nothing in the Flutter client points at it.** The real realtime layer is the main backend's `live/live.gateway.ts`. → **Document only / candidate for removal** (see `LIVESTREAM_AUDIT.md`).
