# UI/UX Pro Max — Feature Improvement Appendix

## 1. Per-Assignment Q&A / Threaded Discussion + DM

**DB Schema** (additive, 002-safe):
| Table | Columns |
|-------|---------|
| `discussions` | id, assignment_id, author_id, title, body, is_private, solved_at, created_at |
| `discussion_messages` | id, discussion_id, parent_id, author_id, body, created_at, updated_at |
| `discussion_mentions` | id, message_id, mentioned_user_id |
| `direct_messages` | id, sender_id, receiver_id, assignment_id, body, is_read, created_at |

**UI Pattern**:
- Assignment detail page → floating "Ask Question" FAB (or "Q&A" tab)
- Q&A tab shows: open questions (solved dimmed), filter by "My Questions", "Unanswered"
- Thread view: tree indent (max 3 levels), collapse/expand, "Best Answer" badge
- DM teacher button: opens 1:1 sheet inside assignment context
- @mention: autocomplete teacher names + mod names, typeahead popup
- Badge counter on Q&A tab when unresolved questions

**UX Flow**:
```
Student opens assignment → sees Q&A tab → types question → @mentions teacher → teacher gets push noti → teacher replies inline → student gets reply noti → can mark solved
```

---

## 2. Chat Per Course (Not Just Program)

**DB**: `course_chat_rooms (id, course_id, is_enabled, created_at)` + `course_chat_members (id, room_id, user_id, role, joined_at)`

**UI**:
- Course detail tab: "Chat" as 3rd tab (after Materials, Assignments)
- Same chat UI as program chat, scoped to course
- Auto-enroll all enrolled students + teacher
- Teacher can toggle `is_enabled` from course settings

**UX Flow**:
```
Course page → Chat tab → shows course-scoped message list → send message → only visible to course members
```

---

## 3. Click @Mentioned User → Show Info Popup

**Implementation**:
- Parse `@username` pattern in chat/message body → linkify
- Tap on mentioned text → `showModalBottomSheet` with user card
- User card data: name, avatar, role, bio, DM button

**UX Detail**:
```
Sheet appear: avatar (circle), name, role badge, bio (if any), [DM] [View Profile]
Tap outside → dismiss. Pull down → dismiss.
Gesture: swipe down to close.
```

---

## 4. Replace print() — Structured Logging

**Stack**: `logger` package (colored terminal output, log levels) + file fallback

```dart
// No more print(). Use:
final log = Logger('ChatProvider');
log.d('sendMessage: ${msg.id}');    // debug
log.i('Message sent: ${msg.id}');   // info
log.w('Retry attempt $i');           // warning
log.e('Failed to send', e, s);       // error + stacktrace
```

**Terminal output**: colored by level, timestamp, caller file:line.
**Release mode**: strip debug logs, keep warn/error.

---

## 5. Analytics — PostHog

**Events to track**:
```
- $pageview (screen name, duration)
- session_join (session_id, role, latency_ms)
- message_sent (scope, has_attachment)
- assignment_opened (assignment_id, time_to_deadline)
- submission_graded (score, delta_from_avg)
- notification_clicked (type, source_screen)
- student_at_risk (risk_score, triggers)
```

**Implementation**: PostHog singleton, call `posthog.capture('event_name', properties: {})` in key provider methods. No bloat, self-hostable.

---

## 6. Unify Theme — Single Peacock System

**Kill**: `lib/Live-Session/theme/app_theme.dart` (pink)
**Keep**: `lib/Theme/themedata.dart` (Peacock)

**Migration**:
- All Live-Session screens that import old theme → switch to `Theme.of(context)`
- Remove `app_theme.dart`, `app_colors.dart` (legacy)
- Delete duplicate widget directories (lowercase `widgets/` vs capitalized `Widgets/` → pick one)

**Screens affected**: MeetingPage, LobbyPage, WhiteboardPage, NotesPage, AttendancePage, ExamPage, DashboardPage, LoginPage, TwoFactorPage.

---

## 7. At-Risk Student Flags

**Algorithm** (server-side in Rust):
```rust
risk_score = (
    (1.0 - attendance_rate) * 0.3 +     // 30% weight
    (1.0 - submission_rate) * 0.3 +     // 30% weight
    avg_grade_drop * 0.2 +               // 20% weight
    inactivity_days_ratio * 0.2          // 20% weight
) * 100
```
Thresholds: >70 = red, 40-70 = yellow, <40 = green.

**UI — Teacher Dashboard**:
- New "At Risk" section: list of students with red/yellow/green dot
- Each row: name, avatar, risk score, trigger reason ("3 missed submissions", "5 days inactive")
- Tap → student overview with trend sparkline
- Export as CSV button

**UX Pattern**: Google Classroom "Review" tab style — cards with status badges.

---

## 8. Attendance Export (CSV/PDF)

**Backend**: `GET /attendance/export?live_session_id=X&format=csv|pdf`

**UI**:
- Live session detail → "Export" button in app bar
- Bottom sheet: choose format (CSV / PDF), date range picker
- Share sheet after download

**CSV columns**: Student Name, Email, Status, Joined At, Left At, Attention Score

**UX Detail**: Progress indicator during export generation (might take 5-10s for large classes).

---

## 9. Per-Student Engagement Graphs

**Data source**: `attention_events` + `attendance` + `activity_sessions` tables

**Graph types**:
- **Bar chart** (per session): Focus lost count, away seconds, camera off seconds
- **Line chart** (over time): Daily active minutes trend
- **Pie chart**: Present vs Late vs Absent distribution

**UI — Student Overview Screen**:
- New "Engagement" tab beside "Grades", "Attendance"
- `fl_chart` bar chart: x-axis = session dates, y-axis = attention_score
- Toggleable metrics: focus score / away time / camera off time
- Compare vs class average (ghost line overlay)

---

## 10. Notification Deep Linking — Click → Related Page

**Payload Structure**:
```json
{
  "type": "chat_mention",
  "screen": "chat",
  "params": { "programId": "uuid", "messageId": "uuid" }
}
```

**Routes Map**:
| Notification Type | Route Target |
|---|---|
| `chat_mention` | ChatScreen → scroll to message |
| `assignment_grade` | AssignmentDetailScreen |
| `session_live` | Meeting LobbyPage |
| `session_scheduled` | Program detail → Session card |
| `submission_returned` | Submission Feedback Screen |
| `material_new` | Course Material tab |
| `exam_alert` | Exam Proctoring overlay |

**Implementation**:
1. `app_links` handles cold start deep link → extract payload → `GoRouter.go(payload.screen, extra: payload.params)`
2. `FirebaseMessaging.onMessageOpenedApp` → same handler
3. `FirebaseMessaging.getInitialMessage()` → cold start handler
4. Notification tap → read payload.screen → navigate

**UX Detail**: If app in foreground, show banner + auto-scroll. If background, open directly. If killed, deep link through splash.

---

## 11. Consistent Loading States

**Standard pattern**:
```dart
buildBody() {
  return switch (provider.state) {
    Loading()   => const ShimmerList(),      // skeleton
    Error(:var msg) => ErrorRetry(msg, onRetry: provider.load),
    Loaded(:var data) => ActualContent(data),
  };
}
```

**Shimmer variants**:
- `ShimmerList` (3-5 rows) — for list screens
- `ShimmerCard` (2 columns) — for grid screens
- `ShimmerDetail` (header + body) — for detail screens
- `ShimmerChart` (axes + bars) — for analytics

**All screens must implement**: Loading, Error, Loaded states. No exceptions.

---

## 12. Consistent Pull-to-Refresh

**Every scrollable screen**: `RefreshIndicator(onRefresh: provider.load)`
**Pattern**: wrap all list/grid content in `RefreshIndicator`, top-level key so swipe gesture works.

**Exception**: non-scrollable screens (empty state) → no indicator needed.

---

## 13. Navigation — Replace Navigator.push with GoRouter

**GoRouter routes**:
```
/                       → MainScaffold (shell)
/auth/login             → LoginScreen
/auth/register          → RegisterScreen
/auth/otp               → OtpScreen
/course/:id             → CourseDetailScreen (nested tabs)
/course/:id/assignment/:aid → AssignmentDetailScreen
/program/:id            → ProgramDetailScreen
/chat/program/:pid      → ChatScreen
/chat/course/:cid       → CourseChatScreen
/meeting/:sessionId     → MeetingPage
/settings               → SettingsScreen
/notifications          → NotificationCenterScreen
/admin                  → AdminShell (nested routes)
/teacher                → TeacherShell (nested routes)
```

**Benefits**: Named routes, redirect guards (auth check), deep link support, browser back button, state restoration.

**Migration strategy**: Keep existing Navigator.push working, add GoRouter incrementally. Start with 10 most-used routes.

---

## 14. Global Search

**UI**: Magnifying glass icon in app bar → tap → full-screen search overlay

**Scopes**: All Courses, Materials, People, Messages, Assignments

**Behavior**:
- Debounce 300ms after typing
- Show recent searches on empty query (from shared_prefs)
- Results grouped by scope with "View all" links
- Tap result → navigate to detail
- Empty state: "Search across courses, materials, people, and messages"

**Backend**: `GET /search?q=term&scope=all|courses|materials|users|messages&page=1&limit=20`
**Rust**: Full-text search with `to_tsvector` indexes (already have `search_vector` column pattern from research).

---

## 15. Virtual Background / Blur

**Approach** (per research):

| Platform | Solution |
|---|---|
| **Web** | `flutter_virtual_background` package (MediaPipe 60fps) |
| **Android** | Custom video processor via `flutter-webrtc` insertable streams + MediaPipe Selfie Segmentation |
| **iOS** | VisionKit `VNGeneratePersonInstanceMaskRequest` (native) |

**UI**:
- Meeting control bar → "Effects" button → bottom sheet
- Options: Blur (light/heavy) / Image (pick from gallery) / None
- Preview thumbnail (background-image composited with camera feed)
- Toggle on/off mid-call

**Performance**: MediaPipe runs at 30-60fps on modern devices. Show warning on low-end devices.

---

## 16. Host Controls

**UI — Host-only control bar**:
```
[✋ Mute All] [🔒 Lock Meeting] [✂️ Remove User] [⭐ Spotlight]
```

**Actions**:
- **Mute All**: Sends `audio:disable` through socket to all participants
- **Lock Meeting**: Prevents new joins (toggle)
- **Remove User**: Opens participant roster → slide to remove → confirmation → disconnect
- **Spotlight**: Pins selected user as main video (overrides auto-switching)

**UX Pattern**: Zoom-style "Security" menu → sub-actions with confirmation for destructive ops.

---

## 17. Gallery vs Speaker View Toggle

**Gallery view**: Grid of tiles (2×2 for 4, 3×3 for 9, scrollable for more)
**Speaker view**: Large main tile + strip of thumbnails at bottom

**Toggle button**: Bottom of meeting screen (or double-tap to switch)
**State persistence**: Save preference to shared_prefs per session

---

## 18. Meeting Reactions — Emoji Rain

**UI**: Floating reaction button → opens emoji picker row (❤️ 🎉 👍 👏 😂 🙌)
**Socket event**: `{ type: "reaction", data: { emoji: "❤️", userId: "uuid" } }`
**Display**: Animated emoji slides up from bottom, random x-offset, fades after 2s
**Backend**: Broadcast to all participants in room

---

## 19. Private Comments + Notes on Submissions

**Concept** (Google Classroom parity):
- Teacher can add private note on submission → only teacher sees
- Student can add private comment → teacher + student see
- Thread replies within each private note

**UI**:
- Submission detail → "Notes" tab
- Two columns: "Teacher Notes" (teacher only), "Private Comments" (shared)
- Rich text supported (bold, italic, bullet)
- Audio/video recording feedback (Classroom feature parity)

---

## 20. Return Status Tracking

**Status flow**:
```
Submitted → Under Review → Graded → Returned
```

**DB field**: `submissions.returned_at TIMESTAMPTZ`

**UI — Student**:
- Assignment card shows status badge: Submitted (gray) / Graded (green) / Returned (blue)
- When returned → notification + badge + "View Feedback" CTA
- Returned items appear in "Recently Returned" section on home tab

**UI — Teacher**:
- Roster shows "not returned" count
- Bulk return: select multiple students → "Return Work" button
- Email notification on return? Optional.

---

## 21. Page Transitions / Micro-interactions / Animations

**Implement**:
- `CupertinoPageTransition` for iOS, `ZoomPageTransition` for material (overrides default)
- Hero animation for avatar/card tap → detail
- Staggered list animation: items fade-in one by one (50ms delay each)
- Skeleton shimmer: `shimmer` package pulse
- Pull-to-refresh: custom refresh indicator (peacock logo spin)
- Bottom sheet: spring animation, drag handle
- Tab switch: `AnimatedSwitcher(duration: 200ms)`
- FAB press: scale-down ripple effect
- Like/reaction: heart bounce animation
- Toast/snackbar: slide-up + fade
- Page transition duration: 250ms standard, 350ms for modals

---

## 22. Multi-language — Myanmar + Thai

**Implementation**: Flutter `l10n` (`.arb` files)

**Strategy**:
1. Extract all hardcoded strings → `lib/l10n/app_en.arb`
2. Create `app_my.arb` (Myanmar/Burmese) + `app_th.arb` (Thai)
3. Translate: Google Translate first pass → native speaker review
4. Locale detection: device locale → fallback to English
5. Manual override: Settings → Language dropdown

**Priority screens**: Auth flow, Home tab, Course detail, Chat, Meeting lobby (highest impact first).

---

## 23. Mobile Widgets (iOS Today / Android App Widget)

**iOS Today Widget** (Swift, separate target):
- Shows: next live session countdown, upcoming assignment deadline, streak days
- Tap → opens app to relevant screen
- Refresh: every 15 min via `TimelineProvider`

**Android App Widget** (Kotlin, `android.appwidget`):
- Same content as iOS
- Refresh via `WorkManager` periodic task
- Dark mode support

**Alternative (cross-platform)**: `home_widget` package — single codebase for both platforms.

---

## Implementation Priority Matrix

| # | Feature | Effort | User Impact |
|---|---------|--------|-------------|
| 1 | Noti deep linking | Low | High |
| 2 | Consistent loading + pull-to-refresh | Low | High |
| 3 | Unify theme | Low | Medium |
| 4 | Replace print() w/ logger | Low | Low (dev) |
| 5 | Add PostHog analytics | Low | Medium |
| 6 | Chat per course | Medium | High |
| 7 | Per-assignment Q&A | Medium | High |
| 8 | @mention → user popup | Low | Medium |
| 9 | GoRouter migration | High | High |
| 10 | Engagement graphs | Medium | Medium |
| 11 | At-risk flags | Medium | Medium |
| 12 | Attendance export | Low | Medium |
| 13 | Submissions: return status + private notes | Medium | Medium |
| 14 | Global search | Medium | High |
| 15 | Page transitions + animations | Medium | Medium |
| 16 | Meeting reactions + host controls | Medium | Medium |
| 17 | Gallery/speaker toggle | Low | Medium |
| 18 | Multi-language | High | High |
| 19 | Virtual backgrounds | High | Medium |
| 20 | Mobile widgets | Medium | Low |
