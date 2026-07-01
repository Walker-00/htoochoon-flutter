import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/widgets.dart' show BuildContext, MediaQuery;

/// Single source of truth for *what the current platform can do*.
///
/// Uses [defaultTargetPlatform] (not `dart:io Platform`) so this file stays
/// web-safe and compiles for every target. All capability gates in the app
/// route through here — never sprinkle raw `Platform.isX` checks for feature
/// availability, ask the matching `supports*` getter instead.
///
/// Form factors covered: Android / iOS phones + tablets (mobile), Windows /
/// macOS / Linux (desktop), and web.
class PlatformSupport {
  PlatformSupport._();

  // ── Raw platform identity ────────────────────────────────────────────────
  static bool get isWeb => kIsWeb;
  static bool get isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static bool get isIOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  static bool get isMacOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;
  static bool get isWindows =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
  static bool get isLinux =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.linux;

  /// A phone or tablet (Android / iOS). Tablets share the mobile codebase and
  /// all of its sensors, so they count as mobile here.
  static bool get isMobile => isAndroid || isIOS;

  /// A desktop OS (Windows / macOS / Linux).
  static bool get isDesktop => isWindows || isMacOS || isLinux;

  /// Large-screen layout hint (tablet / desktop / wide window). Needs a
  /// [BuildContext]; use for *responsive layout* decisions, not capabilities.
  static bool isWideLayout(BuildContext context) =>
      MediaQuery.sizeOf(context).shortestSide >= 600;

  // ── Feature capabilities ─────────────────────────────────────────────────

  /// Full exam proctoring — front-camera face/behaviour (ML Kit) + microphone
  /// voice detection. The `camera`, `google_mlkit_*` and `noise_meter` plugins
  /// only have mobile implementations, so this is mobile-only. Lifecycle/focus
  /// proctoring ([ExamProctor]) still runs on every platform regardless.
  static bool get supportsExamProctoring => isMobile;

  /// Pre-exam room scan — back-camera pan with gyroscope verification
  /// (`sensors_plus` + `camera`). Mobile-only; explicitly forbidden on desktop
  /// and web (no rear camera / device gyroscope to pan).
  static bool get supportsRoomScan => isMobile;

  /// Local exam network guard (`VpnService`) that actively BLOCKS other apps'
  /// traffic. Android-only by design.
  static bool get supportsNetworkGuard => isAndroid;

  /// Passive proxy / VPN DETECTION ([NetworkIntegrity]). Pure `dart:io`, so it
  /// runs on every native platform (mobile + desktop) — only web has no socket
  /// / NetworkInterface access.
  static bool get supportsNetworkIntegrity => !isWeb;

  /// Active network BLOCKING. Android via `VpnService` (no root); desktop via an
  /// elevated hosts-file lockdown ([NetworkLockdown], needs admin/sudo at exam
  /// start). iOS can't (no sudo, needs an Apple Network-Extension entitlement);
  /// web can't. Used by EXTREME-safety exams.
  static bool get supportsNetworkBlock => isAndroid || isDesktop;

  /// Desktop front-camera behaviour proctoring via a bundled TFLite face model
  /// (Windows / macOS / Linux), as an alternative to the mobile ML Kit path.
  ///
  /// OFF until the `.tflite` face model + `tflite_flutter` and the desktop
  /// `camera_*` plugins are wired in and verified ON A REAL DESKTOP — see
  /// `lib/proctoring/DESKTOP_FACE_PROCTOR.md`. Kept false so beta builds never
  /// pull unverified native deps. Flip to `isDesktop` once that ships.
  static bool get supportsDesktopFaceProctor => false;

  /// Live-session screen sharing / screen recording
  /// (`flutter_screen_recording`). The desktop path is handled separately by
  /// the live screen service; this flag covers the mobile recorder.
  static bool get supportsScreenRecording => isMobile;

  /// Firebase core init. firebase_core ships Android / iOS / web / macOS /
  /// Windows implementations — but NOT Linux, where `initializeApp` throws.
  static bool get supportsFirebaseCore =>
      isWeb || isAndroid || isIOS || isMacOS || isWindows;

  /// FCM push messaging. `firebase_messaging` supports Android / iOS / web /
  /// macOS only (no Windows or Linux).
  static bool get supportsPushMessaging =>
      isWeb || isAndroid || isIOS || isMacOS;
}
