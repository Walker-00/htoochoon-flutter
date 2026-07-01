# Htoo Choon — Design System (Peacock)

The app uses a single Material 3 theme (`lib/Theme/themedata.dart`, class
`AppTheme`) with light + dark parity, driven by `ColorScheme.fromSeed`. **Never
hard-code hex in widgets** — read `Theme.of(context).colorScheme` and the
`AppTheme.*` tokens.

## Brand palette

| Name | Hex | Meaning |
|------|-----|---------|
| Peacock Teal | `#0B6E74` | Primary — trust/depth |
| Emerald | `#1AA179` | Tertiary — growth |
| Gold | `#E4B23C` | Accent — the feather eye (logo) |
| Navy | `#0A2540` | Secondary — text/ink |

## Verified WCAG contrast (measured)

| Pair | Ratio | Verdict |
|------|-------|---------|
| white on **teal** | 6.01:1 | ✅ AA (normal) — primary buttons |
| navy on **gold** | 7.94:1 | ✅ AA — gold accents use navy text |
| white on **navy** | 15.5:1 | ✅ AAA |
| teal on white | 6.01:1 | ✅ AA — teal text/icons on surface |
| white on **emerald** | 3.27:1 | ⚠️ large/decorative only |
| white on **gold** | 1.96:1 | ❌ never — use navy on gold |

**Rules:** emerald and gold are **large/decorative** colors. Always pair them
with **navy** (or near-black) text/icons, **never white** at body size. This is
enforced in the scheme via `onTertiary: navy` (light) and dark-text on-colors
(dark). `onPrimary`/`onSecondary` are white (teal/navy backgrounds).

## Semantic color roles (M3)

| Role | Light | Dark | `on*` |
|------|-------|------|-------|
| primary | teal `#0B6E74` | `#4FD0D9` | white / navy |
| secondary | navy `#0A2540` | `#9FC3FF` | white / navy |
| tertiary | emerald `#1AA179` | `#5FD3A8` | navy / navy |
| surface | `_lightSurface` | `_darkSurface` | onSurface |
| error | `error` | `error` | onError |

Helper getters map to roles: `getTextPrimary→onSurface`,
`getTextSecondary→onSurfaceVariant`, `getBorder→outlineVariant`,
`getSurfaceVariant→surfaceContainerHighest`.

## Typography (M3 roles)

Font: **Inter** (`_fontFamily`), defined in `_baseTextTheme` with the M3 roles:
display · headline · title · body · label.

- **Weights:** headings 700, labels/medium 500, body 400.
- **Line-height:** ~1.5 for body.
- Use the role text styles (`Theme.of(context).textTheme.titleLarge`, etc.),
  not ad-hoc `TextStyle(fontSize: …)`.

## Spacing & radius

4/8 rhythm via `AppTheme` tokens: `spaceXs / spaceSm / spaceMd / spaceLg`
and `borderRadiusSm / borderRadiusMd / borderRadiusLg`. Section vertical rhythm
tiers: 16 / 24 / 32.

## Elevation

`CardThemeData` + M3 surface-container tiers
(`surfaceContainerHighest` > `surfaceContainerHigh` > …). Avoid arbitrary
`BoxShadow` values — use the card theme or container roles.

## Motion

- Micro-interactions **150–300ms**; complex ≤400ms; never >500ms.
- **ease-out** on enter, **ease-in** on exit; exit ~60–70% of enter duration.
- Animate `transform`/`opacity` only.
- Reference: the meeting controls (`meeting_page.dart` `_circleButton`) use
  `AnimatedContainer` (color) + `AnimatedSwitcher` (icon scale).
- Respect reduced-motion where the platform reports it.

## Loading states

Use **skeletons** (`lib/Theme/skeletons.dart`: `SkeletonBox`, `SkeletonTile`,
`SkeletonList`) for loads > 300ms — they reserve layout and reduce perceived
wait vs a spinner. Spinners only for short/inline waits (e.g. a button). The
Notification Center is the reference implementation; roll the pattern out to the
remaining list screens.

## Accessibility checklist

- Touch targets ≥ 44×44; expand hit area for small icons.
- Icon-only buttons get a `Semantics`/`tooltip` label.
- Never convey meaning by color alone (pair with icon/text).
- Support Dynamic Type / text scaling without truncation.
- Verify both light and dark independently (see contrast table).
- Use `withValues(alpha:)` (not the deprecated `withOpacity`).

## Branding assets

- Logo: `lib/Theme/peacock_logo.dart` (`PeacockLogo`, `PeacockLogoLockup`) —
  CustomPainter, crisp at any size, supports `mono`. Used in app bar, login,
  splash/org-loader, and the meeting waiting room.
