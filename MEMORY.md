# MEMORY.md — Htoo Choon LMS Project Memory

Claude Code: Read this file at the start of every session. These are persistent project decisions.

---

## XP System — Display Only (for now)

- XP values (earning, display, level calculations) are **display-only**
- Students see XP, levels, streaks — but nothing is gated behind XP
- **DO NOT** build any feature that requires XP to unlock something
- **REASON:** We will build a rewards store later where XP can be spent on: profile customization, course discounts, badge upgrades, virtual gifts
- **ACTION:** Store XP values, show them with celebration animations, but don't use them as access control
- **STATUS:** Remember for later implementation

## Leaderboard — Teaser Only (for now)

- The leaderboard section exists in home_tab as a teaser
- Shows top 3 students with XP
- **DO NOT** build weekly/monthly competitions, team rankings, or department leaderboards yet
- **REASON:** Need stable enrollment and engagement metrics first
- **STATUS:** Remember for later implementation

## Badges — Static Set (for now)

- Current badges are static (First Assignment, 7-Day Streak, Data Wizard, Perfect Score, Bookworm, Speed Learner, Top Performer, Champion)
- **DO NOT** build seasonal badges, community-voted badges, or share-to-social badges yet
- **STATUS:** Remember for later implementation

## AI Recommendations — Placeholder Card (for now)

- The AI Mentor card exists in home_tab as a static placeholder
- Shows "Great progress! You're ahead of 78% of students..."
- **DO NOT** build personalized course paths, skill gap analysis, or predictive timelines yet
- **STATUS:** Remember for later implementation — needs ML pipeline

## Parent Portal — Deferred

- `logister_parent.dart` exists but is minimal
- Needs: parent-child linking model, permission system, separate dashboard
- **DO NOT** implement until backend supports parent role
- **STATUS:** Deferred — needs backend support

## DMs / Private Messages — Deferred

- Current chat is program/course group chat only (via WebSocket)
- Individual 1:1 DMs need: separate chat room model, message persistence, read receipts, online status
- **DO NOT** implement until group chat is stable and tested
- **STATUS:** Deferred — build after group chat is proven

---

## Brand Colors

- Lime: #c3f53c (primary accent, buttons, active states)
- Coral: #ff6b6b (danger, errors, streaks)
- Sky: #38bdf8 (info, links)
- Violet: #a78bfa (badges, teacher role)
- Amber: #fbbf24 (warnings, XP, medals)
- Teal: #2dd4bf (secondary accent)
- Rose: #fb7185 (notifications, female avatars)
- Navy: #0A2540 (dark mode text)
- Background Dark: #0b0b0f
- Surface Dark: #1a1a24

## Fonts

- Display/Headings: Space Grotesk
- Body: Nunito

## Backend API

- Base URL: `https://htoochoon.kargate.site/`
- Auth: JWT Bearer tokens (access + refresh)
- Pattern: REST API with Dio + Retrofit
