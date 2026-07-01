# Premium Roadmap — Paid Features for Schools & Orgs

This document tracks features intentionally **deferred** to a paid tier. Each is gated behind the
existing organization **plan-limit** mechanism (see `PlanLimitGuard` in the backend). The free tier
stays fully functional; paid features add engagement, scale, and white-glove polish.

> Status legend: 🔲 not started · 🟡 partially scaffolded · ✅ shipped (free)

## Free vs Paid — guiding principle
Anything required to **run a class** (auth, classes, assignments, exams + grading, live sessions,
program chat, in-app + local notifications, program progress) is **free**. Paid features are
**amplifiers**: deeper reach (push), deeper insight (analytics), and brand/scale/SLA.

| Feature | Tier | Status |
|---|---|---|
| Auth, classes, courses, programs, enrollment | Free | ✅ |
| Assignments / exams / auto-grading / breakdown | Free | ✅ |
| Live sessions (mediasoup) + recurrence scheduler | Free | ✅ |
| Program chat + in-app & local notifications | Free | ✅ |
| **Program progress bar** (start/end dates) | Free | ✅ |
| Program photo / cover upload | **Premium** | 🔲 |
| Advanced analytics dashboards | **Premium** | 🔲 |
| FCM push (terminated-state) | **Premium** | 🟡 |
| Cron-based reminders (15-min session, 24h exam) | **Premium** | 🔲 |
| Custom branding per institution | **Premium** | 🔲 |
| Priority support SLA | **Premium** | 🔲 |

---

## 1. Program photo / cover upload  🔲
Optional branded cover image per program (cards + detail header). Free tier uses the generated
text/gradient header (already shipped). Reuses the existing materials/avatar upload infra
(`MaterialsService` disk storage + `/uploads` static serving) — add a `coverImageUrl String?` to
`Program` and an upload endpoint. **Rationale:** cosmetic, not required to run a cohort.

## 2. Advanced analytics dashboards  🔲
Org-level dashboards: enrollment funnels, attendance trends, exam score distributions, at-risk
learners, live-session engagement. Backend already persists the raw signals (submissions,
attendance, sessions); this is aggregation + visualization (charts). **Rationale:** high-value
insight for administrators; heavy to build and run.

## 3. FCM push notifications (terminated-state)  🟡
Deliver notifications when the app is killed. Needs `firebase_messaging`, device-token
registration (a `DeviceToken` model + endpoint), and a backend Firebase Admin SDK sender.
Firebase init is currently commented out (`lib/main.dart`). The shipped **local + in-app**
notification path (`LocalNotificationService`, fired from `NotificationProvider`) is the free
stand-in. See the `notifications-premium-roadmap` memory. **Rationale:** real infra + cost.

## 4. Cron-based reminders  🔲
"Live session starting in 15 minutes" and "exam due in 24 hours" via a scheduler
(`@nestjs/schedule`) scanning upcoming `LiveSession`/`Assessment` rows → `NotificationsService
.createForUsers`. Event-driven notifications (chat, graded, material) are already free.
**Rationale:** always-on background compute; an engagement driver worth charging for.

## 5. Custom branding per institution  🔲
Per-org theme override (logo, primary/accent colors, app name) layered on the Peacock design
system. The theme is already centralized (`lib/Theme/themedata.dart`, `ColorScheme.fromSeed`), so
this is a per-org seed/asset override. **Rationale:** white-label is a classic paid upgrade.

## 6. Priority support SLA  🔲
Tiered response-time guarantees, a dedicated channel, and onboarding assistance. Operational, not
code — tracked here for completeness.

---

## Related
- `notifications-premium-roadmap` (memory) — FCM + cron reminders detail.
- `premium-program-video-room` (memory) — always-on per-program video room (plan-limit gated).
