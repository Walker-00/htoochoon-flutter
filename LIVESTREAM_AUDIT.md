# LIVESTREAM AUDIT

## Top-line
There are **three** live implementations; only one is real:

| # | Component | Verdict |
|---|---|---|
| A | Main backend `live/live.gateway.ts` (MediaSoup SFU, ~25 socket events) | ✅ **REAL** — what Flutter actually talks to |
| B | Main backend `gateway/meeting.gateway.ts` (WebRTC-mesh, 8 events) | 💀 Dead — imported in `app.module.ts` but **not in `providers[]`**, so never instantiated |
| C | `live_stream_backend/` (whole NestJS service) | 💀 **Orphaned** — stub gateway, no MediaSoup, different schema; nothing connects to it |

## A) The real path — main backend `live/live.gateway.ts`
`@WebSocketGateway({ namespace: '/' })`, `mediasoup.createWorker(...)`. Socket events (selected):
`live-session:join`, `live-session:leave`, `mediasoup:create-transport`, `mediasoup:connect-transport`, `mediasoup:produce`, `mediasoup:consume`, `mediasoup:resume-consumer`, `mediasoup:consumer-request-keyframe`, `mediasoup:screen:start|stop`, `meeting:action` (hand-raise/toggle-camera/record), `media:state-update`, `attendance:mark`, `attendance:mark-all`, `meeting:create`, `room:participants`, `room:validate`, `participant:update`, `ping`.

## B) Flutter `lib/Live-Session`
- Connects via `core/services/socket_service.dart:34` → `https://htoochoon.kargate.site/` (the **main** backend), `setAuth({token, refreshToken})` from `flutter_secure_storage` / `LiveSessionProvider`.
- REST lifecycle through main backend: `POST /live-sessions`, start/end, `GET /student|teacher/live-sessions/:id/join` → `{ meetingCode, accessToken, refreshToken }` feeds `MeetingPage`/`SocketService`.

### Frontend action ↔ real backend event
| Action | Flutter | Event | Matches `live/live.gateway.ts`? |
|---|---|---|---|
| Join / RTP caps | meeting_page.dart:1112 | `live-session:join` | ✅ |
| Create transport | :1182 | `mediasoup:create-transport` | ✅ |
| Connect transport | mediasoup_service.dart:211 | `mediasoup:connect-transport` | ✅ |
| Produce | :286 | `mediasoup:produce` | ✅ |
| Consume / resume | meeting_page:615 / mediasoup_service:907 | `mediasoup:consume` / `:resume-consumer` | ✅ |
| Screen share | mediasoup_service:833/864 | `mediasoup:screen:start/stop` | ✅ |
| Hand / record / camera | meeting_page:573/1037/719 | `meeting:action` | ✅ |
| Attendance | (gateway) | `attendance:mark[-all]` | ✅ |
| Leave | meeting_page:746 | `live-session:leave` | ✅ |

### Frontend-internal bugs (independent of backend)
- Emits `mediasoup:screen:stop` but **listens** on `mediasoup:screenshare:stopped` (asymmetric) — `mediasoup_service.dart:864` vs `meeting_page.dart:519`.
- `stopScreenShare` sets `_isScreenSharing = true` on stop — `mediasoup_service.dart:874`.
- Screen-share passes **transport id** where **producer id** is expected — `mediasoup_service.dart:835/843`.
- **Chat is dead:** `MeetingChatOverlay` never instantiated in `meeting_page.dart`; `chat:message` only in a comment.
- **Attendance/Exam** features = **0-byte empty files** under `Live-Session/features/{attendance,exam}/`.
- Login/lobby/dashboard pages 100% commented; two `AuthService` classes target dead URLs.

## C) `live_stream_backend` — orphaned (per your decision: document only)
- `gateway/gateway.gateway.ts`: **no `@SubscribeMessage` handlers**, sockets unauthenticated.
- **No MediaSoup** anywhere (`grep -ri mediasoup` → empty; not in deps).
- Models HLS **`Stream{streamKey, streamUrl, isEnded}`**, not meetings; `auth/login` returns only `access_token` (no refresh/2FA).
- **Nothing in Flutter references it.**

**Recommendation:** keep documented as dead. If you want to declutter the repo before showing the director, `live_stream_backend/` and `gateway/meeting.gateway.ts` are safe-to-remove candidates (listed in DEAD_CODE_REPORT) — but removal is optional and was **not** performed (your chosen scope = document only).

## Suggested frontend fixes (small, high-value, not yet applied)
1. Align screen-share emit/listen event names.
2. Fix `stopScreenShare` flag and producer-id argument.
3. Either wire `MeetingChatOverlay` to `chat:message` or remove it.
