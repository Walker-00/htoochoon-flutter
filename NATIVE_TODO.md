# Native TODO — Virtual Background + Home-Screen Widgets

These two features have **no pure-Dart cross-platform path**. The Dart-side
foundation is in place; the native code must be added + built on a Mac (iOS) and
with the Android toolchain. Confirmed by research (sources at bottom).

---

## 1. Virtual Background / Blur (meeting camera)

**Why not done in Dart:** `flutter_webrtc` on mobile does not expose Insertable
Streams (that API is web-only: `MediaStreamTrackProcessor`/`Generator`, Chrome/Edge
only). On mobile the camera frame pipeline must be intercepted natively.

### Android
- Use a custom `VideoProcessor` on the local `VideoTrack` (libwebrtc
  `VideoProcessor` / `VideoSink` interception) feeding frames to **MediaPipe
  Selfie Segmentation** (`com.google.mediapipe:tasks-vision`).
- Per frame: get segmentation mask → composite camera over blurred copy (or a
  chosen image) on a GL surface → push processed frame back into the track.
- Reference: 100ms "WebRTC Virtual Background in Android" (below).

### iOS
- `RTCVideoProcessor`-style hook on the capturer; run **VisionKit**
  `VNGeneratePersonInstanceMaskRequest` (iOS 17+) or `VNGeneratePersonSegmentation
  Request` for the mask; composite with Core Image (`CIBlendWithMask`,
  `CIGaussianBlur`).

### Dart integration point (when native lands)
- Add a `MethodChannel('htoochoon/video_effects')` with
  `setBackground(mode: none|blur|image, imagePath?)`.
- Add an "Effects" action to the meeting control bar that calls it. Gate behind a
  `PlatformSupport.supportsVideoEffects` flag (Android+iOS only) — do NOT show a
  non-functional button on desktop/web.
- Warn on low-end devices (MediaPipe ~30fps; older devices drop frames).

---

## 2. Home-Screen Widgets (upcoming session / deadline / streak)

**Dart side: DONE** — `lib/services/home_widget_service.dart`
(`HomeWidgetService.instance.updateUpcoming(...)`), package `home_widget`.
`home_widget` shares data + triggers refresh but the widget UI itself is native.

### Wire-up (Dart, quick)
Call `HomeWidgetService.instance.updateUpcoming(...)` whenever the dashboard /
live-session list loads, e.g. in the sessions provider after fetch:
```dart
HomeWidgetService.instance.updateUpcoming(
  nextSessionTitle: next?.topic,
  nextSessionAt: next?.startTime,
);
```

### Android (`android/app/src/main/`)
- `res/layout/htoochoon_widget.xml` — widget layout (title, countdown, streak).
- `res/xml/htoochoon_widget_info.xml` — `appwidget-provider` metadata.
- `kotlin/.../HtooChoonWidgetProvider.kt` — `extends HomeWidgetProvider`; read
  `next_session_title` / `next_session_at` / `streak_days` from prefs, render.
- Register provider in `AndroidManifest.xml` (`<receiver android:name=
  ".HtooChoonWidgetProvider">` + `APPWIDGET_UPDATE` intent-filter).

### iOS (`ios/`)
- New **Widget Extension** target (`HtooChoonWidget`) using **WidgetKit + SwiftUI**.
- Enable **App Groups** (`group.com.example.htoochoon_flutter`) on BOTH the app and
  the widget target (already the group id used in `HomeWidgetService`).
- `TimelineProvider` reads shared `UserDefaults(suiteName: appGroup)` keys
  (`next_session_title`, etc.); refresh every ~15 min.

### Names (must match `HomeWidgetService`)
- App Group: `group.com.example.htoochoon_flutter`
- Android provider class: `HtooChoonWidgetProvider`
- iOS widget kind: `HtooChoonWidget`

---

## Sources
- 100ms — WebRTC Virtual Background in Android: https://www.100ms.live/blog/webrtc-virtual-background-android
- WebRTC.ventures — Background Removal Using Insertable Streams: https://webrtc.ventures/2023/02/background-removal-using-insertable-streams/
- webrtcHacks — Transparent virtual backgrounds in WebRTC: https://webrtchacks.com/how-to-make-virtual-backgrounds-transparent-in-webrtc/
- home_widget package: https://pub.dev/packages/home_widget
- Flutter home-screen widgets codelab: https://codelabs.developers.google.com/flutter-home-screen-widgets
