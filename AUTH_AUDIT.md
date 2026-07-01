# AUTHENTICATION AUDIT

## How many auth systems exist?
**Four code paths, one of which is real:**

| # | Location | Status |
|---|---|---|
| 1 | `Providers/auth_provider.dart` + `lib/main.dart` interceptor + `core/token_manager.dart` | ✅ **ACTIVE / canonical** |
| 2 | `Service/auth_service.dart` | ⚠️ Dead — refresh logic duplicated from the interceptor; constructor `AuthService(dio, tokenManager)`; not registered |
| 3 | `Providers/login_provider.dart` | 💀 Dead — 100% commented |
| 4 | `Live-Session/core/services/auth_service.dart` + `Live-Session/features/auth/auth_service.dart` | 💀 Dead — duplicate Dio clients, hardcoded `localhost:3000` / `192.168.1.112:3000` |

Plus `core/userorgrole_manager.dart#UserSessionManager` — a static global mirroring `user`/`userId`/org-roles, read by the interceptor (`UserSessionManager.userId`).

## Backend auth surface (verified)
| Route | Implemented in client? |
|---|---|
| `POST /auth/login` | ✅ |
| `POST /auth/register` | ✅ |
| `POST /auth/request-otp` | ✅ |
| `POST /auth/verify-otp` | ✅ |
| `POST /auth/reset-password` | ✅ |
| `GET /auth/me` | ❌ (uses `GET /users/me`) |
| `POST /auth/refresh` | ✅ (interceptor) |
| `POST /auth/rotate-refresh` | ❌ |
| `GET /auth/sessions`, `/sessions/count`, `DELETE /auth/sessions/:id` | ❌ no UI |
| `POST /auth/2fa/enable`, `/2fa/verify-setup` | ❌ |
| `POST /auth/2fa/verify-login` | ⚠️ direct dio in a Live-Session page |

Backend design (from `auth.service.ts` + `Session` model): JWT **access token** + **DB-backed refresh sessions** (`Session{refreshJti, refreshHash, deviceId, revoked}`) → supports multi-device login, per-session revocation, and rotation. Passwords bcrypt-hashed. 2FA = TOTP with `twoFactorSecret`.

## Token storage — before vs after this audit
**Before:** three stores in play — `SharedPreferences` (AuthProvider, keys `access_token`/`refresh_token`/`user_id`/`user`), the **missing** `TokenManager` (build break), and `flutter_secure_storage` (Live-Session SocketService).

**After (this audit):** `TokenManager` recreated as the **single source of truth**, backed by `SharedPreferences` using the *same keys AuthProvider already uses*, with a shared singleton so the interceptor's `isRefreshing`/pending-token coordination is consistent app-wide. Provides: `init`, `getToken`/`setToken`, `getRefreshToken`/`setRefreshToken`, `getUserId`/`setUserId`, `clearToken`, `isRefreshing`/`setRefreshing`, `setPendingToken`.

## Refresh / recovery flow (active)
```
request -> interceptor attaches Bearer (TokenManager.getToken)
401 (non-/auth/refresh) && !isRefreshing
    -> setRefreshing(true)
    -> POST /auth/refresh { refreshToken, userId } (X-Refresh-Token header)
    -> on success: TokenManager.setToken/​setRefreshToken, retry original request
    -> on failure: clearToken + redirect to PremiumLoginScreen (shared navigatorKey)
```

## Recommendations (prioritized)
1. ✅ **Done:** centralize token storage in `TokenManager`; recreate so app compiles.
2. **Delete** dead auth paths (#2,#3,#4) — eliminates confusion + stale localhost URLs.
3. **Fold** `UserSessionManager` into `AuthProvider` (single user/role source).
4. **Add session-management UI** using `GET /auth/sessions` + `DELETE /auth/sessions/:id` (backend already supports it — a strong feature to show the director: "log out other devices").
5. Move the Live-Session 2FA call out of the page into `AuthProvider`.
6. Stop logging raw access tokens in the interceptor (`main.dart:137`).
