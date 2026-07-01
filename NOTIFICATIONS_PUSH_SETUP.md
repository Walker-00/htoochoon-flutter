# Notifications & Background Push — Setup / Deployment

This covers the FCM background-push pipeline and the new notification behaviour
added on top of the existing in-app (WebSocket) notification center.

## What changed

### App (Flutter)
- **Permission prompt fix** — the OS notification-permission request now fires on
  every entry to the authenticated shell (`main_scaffold.dart`). It used to live
  only inside `loadMe()`, which the normal login path skips, so the prompt never
  appeared and system heads-up notifications were silently dropped.
- **FCM wired** (`push_service.dart`, `main.dart`):
  - `Firebase.initializeApp()` enabled (was commented out).
  - Background isolate handler registered (`firebaseMessagingBackgroundHandler`).
  - Foreground messages → shown via `LocalNotificationService` (FCM doesn't show
    those itself).
  - Device token registered with the backend after login (`POST /notifications/devices`)
    and on token refresh; unregistered on logout (`DELETE /notifications/devices`).
- **Notification settings screen** (gear icon in the notification center): choose
  chat mode (All / Only when mentioned / Off) and toggle background push.

### Backend (NestJS)
- `DeviceToken` + `NotificationPreference` tables (migration
  `20260613000000_push_and_notify_prefs`).
- `PushService` (firebase-admin) — sends to a user's device tokens, prunes dead
  tokens. **No-ops safely if no credential is configured** (server still runs;
  in-app WS notifications unaffected).
- `NotificationsService.createForUsers` now also pushes (respecting each user's
  `pushEnabled`).
- New endpoints on `/notifications`: `POST /devices`, `DELETE /devices`,
  `GET /preferences`, `PATCH /preferences`.
- **New notification events**: assignment/exam published, enrollment confirmed
  (program & course), added-to-organization (surfaces in the announcements feed).
- **Chat is mention-only by default** — group chat only notifies you when you're
  `@`-mentioned, unless you switch to "All" (or "Off"). Mentions deliver per
  message; "All" is rate-limited to one ping per 10 min per program.
- **Session reminder cron** (`@nestjs/schedule`) — every 5 min, reminds
  participants (incl. host) of sessions starting within ~15 min, exactly once.

## You must do these (require your access)

### 1. Run the migration on the server
```bash
cd /root/htoo_choon/htoo-chon-backend
npx prisma migrate deploy
npx prisma generate
```

### 2. Provide a Firebase Admin service account (enables background push)
Firebase Console → Project **htoochoon-13840** → Project settings → Service
accounts → **Generate new private key** → download the JSON.

Put it on the server and point the backend at it via **one** of:
```bash
# Option A: file path (recommended)
FIREBASE_SERVICE_ACCOUNT_PATH=/root/htoo_choon/secrets/firebase-admin.json

# Option B: raw JSON in the env
FIREBASE_SERVICE_ACCOUNT_JSON='{"type":"service_account","project_id":"htoochoon-13840", ...}'

# Option C: Google ADC
GOOGLE_APPLICATION_CREDENTIALS=/path/to/firebase-admin.json
```
Restart the backend. On boot you should see `✅ FCM push initialized`. If the
credential is missing you'll instead see a one-line warning and push stays off
(everything else keeps working).

> Keep the JSON out of git. Add `secrets/` (or the file) to `.gitignore`.

### 3. Rebuild & install the app
The APKs are built with `flutter build apk --split-per-abi`. The Android
`google-services.json` and the `com.google.gms.google-services` Gradle plugin are
already in place.

## Test plan
1. **Permission** — fresh login → OS asks for notification permission.
2. **Foreground** — trigger an event (publish an assignment, grade a submission,
   start a session) → heads-up shows while the app is open.
3. **Background/terminated** — close the app → trigger an event → system push
   arrives (requires step 2 credential + a registered token).
4. **Chat default** — send a normal group message → mentioned-only users (none by
   default) are notified; send `@<name>` → that user is notified. Switch a user to
   "All" in settings → they get every message (rate-limited).
5. **Reminder** — schedule a session ~10 min out → within 5 min a "starting soon"
   notification arrives once.

## Notes / limitations
- There's no standalone "announcements" feature; "Announcements" here means the
  org-membership/invitation events the announcements tab already shows. A true
  broadcast/announcement composer would be a separate build.
- `@`-mention matching is name-based (`@<name>` / `@<firstName>`, case-insensitive)
  — pragmatic for now; a real mention picker (storing mentioned user IDs) would be
  more precise.
- iOS background push additionally needs an APNs key uploaded in Firebase and the
  Push Notifications capability — out of scope for the current Android focus.
