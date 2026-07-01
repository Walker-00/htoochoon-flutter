# PROMPT: Htoo Choon Flutter LMS — COMPLETE V3 REDESIGN

## CRITICAL INSTRUCTION

**DO NOT just change colors or tweak layouts. REDESIGN EVERYTHING from scratch.**

Every single screen must be **completely rebuilt** to match the `html-v3/` reference pages. Not "inspired by." Not "similar to." **IDENTICAL in design language.**

If a screen has a card, the card must look exactly like the HTML card. If a screen has a badge, it must look exactly like the HTML badge. If a screen has a list, it must look exactly like the HTML list. **Copy the design system completely.**

---

## BEFORE YOU START

1. Read `/data/projects/htoo-choon-full/MEMORY.md` for persistent decisions
2. Read 3-4 HTML files in `html-v3/` to UNDERSTAND the full design system before writing any code
3. Understand: glassmorphism cards, gradient badges, pill buttons, lime accents, dark surfaces, Space Grotesk headings, Nunito body, animated counters, shimmer effects, slide-up animations

---

## THE V3 DESIGN SYSTEM — COPY THIS EXACTLY

### Colors (exact values)
```
Background:     #0b0b0f
Surface:        #1a1a24
Surface Hover:  #22222e
Border:         rgba(255,255,255,0.06)
Border Bright:  rgba(255,255,255,0.12)
Lime:           #c3f53c
Coral:          #ff6b6b
Sky:            #38bdf8
Violet:         #a78bfa
Amber:          #fbbf24
Teal:           #2dd4bf
Rose:           #fb7185
Text:           #f0f0f5
Text Dim:       #8b8b9e
Text Muted:     #55556a
```

### Typography
```
Headings:  Space Grotesk, weight 700-900
Body:      Nunito, weight 400-700
```

### Cards
```dart
// EVERY card must have this exact style:
Container(
  decoration: BoxDecoration(
    color: Color(0xFF1a1a24),
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: Colors.white.withOpacity(0.06)),
    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 32, offset: Offset(0, 8))],
  ),
)
```

### Glassmorphism Cards (for special sections)
```dart
// Streak card, AI mentor, achievement showcase:
Container(
  decoration: BoxDecoration(
    color: Color(0xFF1a1a24),
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: Colors.white.withOpacity(0.06)),
    gradient: LinearGradient(
      colors: [Color(0x14c3f53c), Color(0x0a2dd4bf)], // lime to teal at low opacity
    ),
  ),
)
```

### Buttons
```dart
// Primary: Lime pill
ElevatedButton(
  style: ElevatedButton.styleFrom(
    backgroundColor: Color(0xFFc3f53c),
    foregroundColor: Color(0xFF0b0b0f),
    shape: StadiumBorder(),
    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    textStyle: TextStyle(fontFamily: 'Nunito', fontWeight: FontWeight.w700),
  ),
)

// Secondary: Dark pill with border
OutlinedButton(
  style: OutlinedButton.styleFrom(
    foregroundColor: Color(0xFFf0f0f5),
    side: BorderSide(color: Colors.white.withOpacity(0.12)),
    shape: StadiumBorder(),
    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
  ),
)
```

### Badges
```dart
// Lime badge
Container(
  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  decoration: BoxDecoration(
    color: Color(0x1ac3f53c), // lime at 10% opacity
    borderRadius: BorderRadius.circular(50),
  ),
  child: Text('Active', style: TextStyle(color: Color(0xFFc3f53c), fontSize: 11, fontWeight: FontWeight.w800)),
)

// Other colors: same pattern with different color at 10% opacity background
```

### Avatars
```dart
// Initials avatar with colored background
Container(
  width: 40, height: 40,
  decoration: BoxDecoration(
    color: Color(0x1ac3f53c), // lime bg
    shape: BoxShape.circle,
  ),
  child: Center(child: Text('TA', style: TextStyle(color: Color(0xFFc3f53c), fontWeight: FontWeight.w800, fontSize: 14))),
)
```

### Level Badge
```dart
Container(
  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  decoration: BoxDecoration(
    gradient: LinearGradient(colors: [Color(0xFFc3f53c), Color(0xFF2dd4bf)]),
    borderRadius: BorderRadius.circular(50),
  ),
  child: Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(Icons.bolt, color: Color(0xFF0b0b0f), size: 16),
    SizedBox(width: 4),
    Text('Level 12 — Data Explorer', style: TextStyle(color: Color(0xFF0b0b0f), fontWeight: FontWeight.w800, fontSize: 12)),
  ]),
)
```

### XP Progress Bar
```dart
Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text('Experience Points', style: TextStyle(color: Color(0xFF8b8b9e), fontSize: 12)),
      Text('2,450 / 3,000 XP', style: TextStyle(color: Color(0xFFf0f0f5), fontSize: 12, fontWeight: FontWeight.w700)),
    ]),
    SizedBox(height: 8),
    ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(value: 0.817, minHeight: 8, backgroundColor: Color(0xFF1a1a24), valueColor: AlwaysStoppedAnimation(Color(0xFFc3f53c))),
    ),
  ],
)
```

### Section Header
```dart
Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
  Text('Section Title', style: TextStyle(fontFamily: 'Space Grotesk', fontSize: 18, fontWeight: FontWeight.w800)),
  Text('View All →', style: TextStyle(color: Color(0xFF8b8b9e), fontSize: 12, fontWeight: FontWeight.w600)),
])
```

### Stat Pill (2x2 grid)
```dart
Container(
  padding: EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: Color(0xFF1a1a24),
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: Colors.white.withOpacity(0.06)),
  ),
  child: Row(children: [
    Container(width: 40, height: 40, decoration: BoxDecoration(color: Color(0x0ac3f53c), borderRadius: BorderRadius.circular(8)), child: Center(child: Text('📚', style: TextStyle(fontSize: 18)))),
    SizedBox(width: 12),
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('5', style: TextStyle(color: Color(0xFFc3f53c), fontSize: 20, fontWeight: FontWeight.w800)),
      Text('Active Courses', style: TextStyle(color: Color(0xFF8b8b9e), fontSize: 11)),
    ]),
  ]),
)
```

### Topbar
```dart
Container(
  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Text('Page Title', style: TextStyle(fontFamily: 'Space Grotesk', fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFFc3f53c))),
    Row(children: [
      // Theme toggle, notifications, profile buttons
      _iconButton(Icons.light_mode), // theme
      _iconButton(Icons.notifications_outlined), // notifications
      _iconButton(Icons.person_outline), // profile
    ]),
  ]),
)
```

### Sidebar (Desktop)
```dart
Container(
  width: 260,
  color: Color(0xFF0e0e14),
  padding: EdgeInsets.all(24),
  child: Column(children: [
    // Logo: "HC" mark + "Htoo Choon" text
    Row(children: [
      Container(width: 36, height: 36, decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFc3f53c), Color(0xFF2dd4bf)]), borderRadius: BorderRadius.circular(10)), child: Center(child: Text('HC', style: TextStyle(color: Color(0xFF0b0b0f), fontWeight: FontWeight.w900, fontSize: 14)))),
      SizedBox(width: 10),
      Text('Htoo Choon', style: TextStyle(fontFamily: 'Space Grotesk', fontWeight: FontWeight.w700, fontSize: 16)),
    ]),
    SizedBox(height: 32),
    // Nav items
    _navItem(Icons.home_outlined, 'Dashboard', active: true),
    _navItem(Icons.book_outlined, 'My Courses'),
    _navItem(Icons.assignment_outlined, 'Assignments'),
    // ... more items
    Spacer(),
    // User section at bottom
    Row(children: [
      CircleAvatar(backgroundColor: Color(0xFFc3f53c), child: Text('T', style: TextStyle(color: Color(0xFF0b0b0f), fontWeight: FontWeight.w800))),
      SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Thura Aung', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        Text('Level 12', style: TextStyle(color: Color(0xFF8b8b9e), fontSize: 11)),
      ]),
    ]),
  ]),
)
```

---

## WHAT TO REBUILD

### Each screen must have:

1. **V3 color scheme** — #0b0b0f background, #1a1a24 surfaces, lime accents
2. **V3 typography** — Space Grotesk headings, Nunito body
3. **V3 cards** — 14px radius, subtle border, glassmorphism where appropriate
4. **V3 buttons** — Pill-shaped, lime primary, dark secondary
5. **V3 badges** — Colored background at 10% opacity, colored text
6. **V3 avatars** — Circular, colored background, initials
7. **V3 spacing** — Generous padding (16-24px), consistent gaps (8-12px)
8. **V3 animations** — Slide-up on appear, animated counters, shimmer on load
9. **V3 empty states** — Centered illustration + text
10. **V3 section headers** — Title left, "View All →" right

### Screens to COMPLETELY REBUILD:

| Screen | File | Must match HTML exactly |
|---|---|---|
| Login | `login_screen.dart` | `html-v3/login.html` |
| Register | `register_screen.dart` | `html-v3/login.html` register mode |
| OTP | `otp_screen.dart` | `html-v3/otp.html` |
| Onboarding | `onboarding_screen.dart` | `html-v3/onboarding.html` |
| Home Dashboard | `home_tab.dart` | `html-v3/home.html` |
| My Learning | `classes_tab.dart` | `html-v3/my-learning.html` |
| Courses | `courses_tab.dart` | `html-v3/courses.html` |
| Profile | `profile_tab.dart` | `html-v3/profile.html` |
| Notifications | `notification_center_screen.dart` | `html-v3/notifications.html` |
| Admin Dashboard | `dashboard_screen.dart` | `html-v3/admin-dashboard.html` |
| Admin Members | `members_screen.dart` | `html-v3/admin-members.html` |
| Meeting | `meeting_page.dart` | `html-v3/meeting.html` |
| Chat | `program_chat_screen.dart` | `html-v3/chat.html` |
| Subscription | `subscription_screen.dart` | `html-v3/subscription.html` |
| Form Builder | `form_builder_screen.dart` | `html-v3/form-builder.html` |
| Schedule | `schedule_screen.dart` | `html-v3/schedule.html` |

### What "COMPLETELY REBUILD" means:

- **READ** the HTML file first
- **DELETE** the old styling (not the logic)
- **REWRITE** all Container, Card, Text, Button widgets with V3 design tokens
- **ADD** the missing sections from HTML (if HTML has leaderboard and Flutter doesn't, ADD it)
- **MATCH** every visual element — colors, sizes, spacing, typography, borders, shadows
- **DO NOT** keep old Color(0xFF2196F3) blue theme colors
- **DO NOT** keep old BorderRadius.circular(8) small radius cards
- **DO NOT** keep old flat buttons without pill shape
- **DO NOT** keep old plain text without proper typography

---

## MEMORY NOTES (from MEMORY.md)

- XP is display-only — show it, celebrate it, but don't gate anything
- Leaderboard is a teaser — show top 3, don't build competitions
- Badges are static — don't build seasonal/social badges
- AI Mentor is placeholder — show static text, don't build ML
- Parent portal and DMs are deferred — don't implement

---

## PROCESS FOR EACH SCREEN

1. Read the HTML reference file completely
2. Read the existing Flutter screen file completely
3. Identify ALL visual differences (not just colors — layout, spacing, typography, components, missing sections)
4. Rewrite the screen's UI code from scratch using V3 design tokens
5. Keep all existing LOGIC (API calls, state management, navigation)
6. Only change WIDGETS and STYLING
7. Verify by comparing visual output with HTML reference
8. Move to next screen

---

## RULES

1. **Read MEMORY.md first** — Persistent decisions (XP, deferred features)
2. **READ THE HTML BEFORE WRITING** — You cannot match a design you haven't read
3. **REDESIGN, DON'T TWEAK** — Change everything, not just colors
4. **KEEP LOGIC, REPLACE WIDGETS** — Don't break API calls, state, navigation
5. **USE EXISTING PROVIDERS** — Don't create duplicates
6. **DART ANALYZE** — Fix lint errors after each screen
7. **ONE SCREEN AT A TIME** — Finish one completely before starting the next
8. **COMPARE WITH HTML** — After each screen, verify it matches the reference
