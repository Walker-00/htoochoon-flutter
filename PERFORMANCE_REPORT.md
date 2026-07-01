# PERFORMANCE REPORT — Flutter

> Static review (no profiler available in this environment). Findings ranked by likely impact.

## 🟠 Rebuild scope
- **`context.watch` / `Consumer` at screen root** rebuilds the whole subtree on any provider change. `courses_tab.dart`, `home_tab.dart`, `classes_tab.dart` watch multiple providers high in the tree. → Push `Consumer`/`Selector` down to the smallest widget that needs the data; use `Selector` for single fields (e.g. `isLoading`).
- **`classroom_detail_screen.dart` (~3000+ lines)** and `home_tab.dart` are oversized `build` methods → extract `const` sub-widgets to bound rebuilds.

## 🟠 Repeated / duplicate network calls
- Several screens call `fetch...()` directly inside `build` or unguarded `initState` without a "already loaded" guard, re-hitting the API on every navigation. Add a `_loaded`/`if (list.isEmpty)` guard or load in `initState` once.
- `course_detail_screen.dart` paginates via `fetchEnrollmentsByCourseId` (good — the recreated provider supports `loadMore` + `hasMore` + `isFetchingMore` so the infinite list won't double-fetch).
- The Dio interceptor logs **every** request body + token (`main.dart:133-138`) — disable in release (string interpolation cost + log spam + security).

## 🟡 Lists
- Long lists should use `ListView.builder` with `itemExtent`/keys where possible. Verify member/enrollment lists are builders, not `Column(children: [...map])`.
- `IndexedStack` in `MainScaffold` keeps all 4 tabs alive (intended for state retention) but means all tab subtrees build eagerly — acceptable, but keep each tab's root cheap.

## 🟡 Memory / lifecycle
- `SocketService` + MediaSoup transports/consumers must be disposed on meeting exit. Verify `dispose()` closes the socket, transports, consumers and stops local tracks (camera/mic) — a missed track stop keeps the camera LED on and leaks native resources.
- Providers that start timers/streams (e.g. live polling) must cancel in `dispose()`.

## 🟢 Good
- Single Dio instance reused app-wide (connection pooling).
- Provider (no heavy reactive framework) keeps baseline light.

## Quick wins for the demo
1. Wrap release build to silence interceptor `print`s.
2. Add load-guards so tabs don't refetch on every switch.
3. Ensure camera/mic tracks stop on leaving a live session (visible to the director if the camera stays on).
