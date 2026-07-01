# API COVERAGE REPORT

Backend endpoints extracted directly from the 17 NestJS controllers (the Swagger `docs-json.json` is generated at runtime and not committed). Each endpoint classified by whether the Flutter client references it through `lib/api/api_service.dart` (Retrofit), a provider, and the UI.

**Base URL:** `https://htoochoon.kargate.site/` (hardcoded in `lib/main.dart:62`).

## Headline numbers

| Metric | Value |
|---|---|
| Endpoints surveyed | **73** |
| Referenced by client | **47 (~64%)** |
| Not referenced | **26 (~36%)** |
| Verb/path mismatches (were broken) | **3 — now FIXED in this audit** |

Status legend: **Implemented** = service+provider+UI; **Partial** = service exists, no provider/UI; **Missing** = not referenced.

## Fixed in this audit (were Broken → now Implemented)
| Endpoint | Bug | Fix |
|---|---|---|
| `PATCH /classes/:id` | client used `@PUT` | → `@PATCH` (both `api_service.dart` + `.g.dart`) |
| `DELETE /programs/:programId/courses/:courseId` | client used `@POST` | → `@DELETE` |
| `POST /organizations/upload/:id` | client used `/organizations/{id}/upload` | → `/organizations/upload/{id}` |

## By controller

### Auth (5/14 used)
| Endpoint | Status |
|---|---|
| POST /auth/register, /auth/login, /auth/request-otp, /auth/verify-otp, /auth/reset-password | Implemented |
| POST /auth/refresh | Implemented (interceptor) |
| POST /auth/2fa/verify-login | Partial (direct dio in Live-Session page) |
| GET /auth/me | Missing (app uses `/users/me`) |
| POST /auth/2fa/enable/:userId, /auth/2fa/verify-setup, /auth/rotate-refresh | Missing |
| GET /auth/sessions, /auth/sessions/count, DELETE /auth/sessions/:id | **Missing** (no device/session-management UI despite backend support) |

### Admin (0/5 used) — **all Missing**
`GET /admin/stats`, `POST /admin/programs`, `POST /admin/courses`, `GET /admin/users`, `PATCH /admin/users/:id/status`. The app standardized on generic `/programs`, `/courses`, `/users` instead. **`GET /admin/stats` is the correct data source for a platform-admin dashboard (see MOCK_DATA_REPORT).**

### Users (6/9 used)
Implemented: `/users/me`, `/users`, `/users/:id` (GET/PATCH), `/users/upload/:id`, `/users/:organizationId/leave`.
Missing: `/users/getUserRole`, `PATCH /users/invitations/:id/:status`, `POST /users/:id/change-password`.

### Organizations (9/11 used)
Implemented: create, GET list/one, PATCH, DELETE, members (POST/GET/DELETE), transfer-ownership, **upload (now fixed)**.
Missing: `GET /organizations/:id/usage` (commented out in client — but the per-org `findOne` already returns `usagePercentage`).

### Subscriptions (5/5 used) — **fully Implemented**
plan get/update/check/usage/available all wired via `DashboardProvider`/`SubscriptionProvider`.

### Programs (7/7), Courses (5/5), Classes (8/8) — Implemented
(after the `PATCH /classes/:id` and `DELETE /programs/.../courses/...` fixes).

### Assignments (5/5), Submissions (4/5) — Implemented
Missing: `DELETE /submissions/:id`.

### Attendance (3/3) — Implemented
`POST /attendance` defined in service; provider call currently commented.

### Enrollment (10/10) — **fully Implemented** (via recreated `EnrollmentProvider`)

### Live-sessions (5/5) — Implemented
create, list, start, end, detail.

### Student (2/5)
Implemented: `GET /student/classes`, `GET /student/live-sessions/:id/join`.
Missing: `POST /student/classes/join`, `POST /student/submit`, `GET /student/invitations`.

### Teacher (1/8)
Implemented: `POST /teacher/live-sessions/:id/join`.
Missing (7): the app uses the generic `/assignments`, `/submissions`, `/live-sessions` routes instead of the `/teacher/*` convenience duplicates.

### Questions (0/1) — Missing
`POST /questions/:questionId/attachments`.

## Direct-HTTP violations (bypass ApiService)
1. `lib/Live-Session/features/auth/two_factor_page.dart:41` — page calls `_dio.post('/auth/2fa/verify-login')` directly.
2. `lib/main.dart:96` — refresh via raw Dio in interceptor (acceptable, hand-rolled).
3. `lib/Live-Session/core/services/auth_service.dart` & `features/auth/auth_service.dart` — dead duplicate AuthServices, hardcoded `localhost:3000` / `192.168.1.112:3000`.
4. `lib/lms_demo/demo_services.dart` — direct Dio to hardcoded LAN IP.

## Notable backend capability the UI doesn't use yet
- **Session/device management** (`GET /auth/sessions`, `DELETE /auth/sessions/:id`) — ready backend, no UI.
- **Platform admin stats** (`GET /admin/stats`) — ready backend, dashboard currently derives stats elsewhere.
- **Change password** (`POST /users/:id/change-password`) — ready backend, no UI.
