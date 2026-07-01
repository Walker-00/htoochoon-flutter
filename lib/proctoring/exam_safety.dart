import '../utils/platform_support.dart';

/// Teacher-chosen anti-cheat policy for an exam, resolved against the CURRENT
/// platform into a concrete set of proctoring capabilities.
///
/// Levels:
///  * NONE    — no monitoring at all.
///  * MID     — app-switch / leave-app detection only (all native platforms).
///  * HIGH    — MID **plus exactly one** measure (CAMERA or NETWORK), enforced
///              on the platforms named by [scope].
///  * EXTREME — MID plus BOTH camera + network, room scan, and active network
///              BLOCK (hosts-file lockdown / Android VpnService) — everything
///              the running platform can do, on the platforms named by [scope].
///
/// [scope] (ALL / DESKTOP / MOBILE) limits which platforms the HIGH/EXTREME
/// measures apply to. The MID baseline (app-switch + the kick-out lockout) runs
/// on every native platform regardless of scope.
enum ExamSafetyLevel { none, mid, high, extreme }

enum ExamSafetyScope { all, desktop, mobile }

enum ExamSafetyMeasure { camera, network }

class ExamSafety {
  final ExamSafetyLevel level;
  final ExamSafetyScope scope;
  final ExamSafetyMeasure measure; // only meaningful when level == high

  const ExamSafety({
    required this.level,
    required this.scope,
    required this.measure,
  });

  static const ExamSafety defaults = ExamSafety(
    level: ExamSafetyLevel.mid,
    scope: ExamSafetyScope.mobile,
    measure: ExamSafetyMeasure.camera,
  );

  factory ExamSafety.fromStrings(String? level, String? scope, String? measure) {
    return ExamSafety(
      level: _level(level),
      scope: _scope(scope),
      measure: _measure(measure),
    );
  }

  static ExamSafetyLevel _level(String? s) {
    switch ((s ?? '').toUpperCase()) {
      case 'NONE':
        return ExamSafetyLevel.none;
      case 'HIGH':
        return ExamSafetyLevel.high;
      case 'EXTREME':
        return ExamSafetyLevel.extreme;
      case 'MID':
      default:
        return ExamSafetyLevel.mid;
    }
  }

  static ExamSafetyScope _scope(String? s) {
    switch ((s ?? '').toUpperCase()) {
      case 'ALL':
        return ExamSafetyScope.all;
      case 'DESKTOP':
        return ExamSafetyScope.desktop;
      case 'MOBILE':
      default:
        return ExamSafetyScope.mobile;
    }
  }

  static ExamSafetyMeasure _measure(String? s) {
    switch ((s ?? '').toUpperCase()) {
      case 'NETWORK':
        return ExamSafetyMeasure.network;
      case 'CAMERA':
      default:
        return ExamSafetyMeasure.camera;
    }
  }

  String get levelString => level.name.toUpperCase();
  String get scopeString => scope.name.toUpperCase();
  String get measureString => measure.name.toUpperCase();

  // ── Resolved capabilities for the device running RIGHT NOW ────────────────

  /// Does [scope] include the current platform? Governs HIGH/EXTREME measures.
  bool get _scopeApplies {
    switch (scope) {
      case ExamSafetyScope.all:
        return true;
      case ExamSafetyScope.desktop:
        return PlatformSupport.isDesktop;
      case ExamSafetyScope.mobile:
        return PlatformSupport.isMobile;
    }
  }

  bool get _wantsCamera =>
      level == ExamSafetyLevel.extreme ||
      (level == ExamSafetyLevel.high && measure == ExamSafetyMeasure.camera);

  bool get _wantsNetwork =>
      level == ExamSafetyLevel.extreme ||
      (level == ExamSafetyLevel.high && measure == ExamSafetyMeasure.network);

  /// App-switch / leave-app proctor (drives the kick-out → lockout). Baseline
  /// for everything except NONE; runs on every native platform.
  bool get appSwitchProctor =>
      level != ExamSafetyLevel.none && !PlatformSupport.isWeb;

  /// Front-camera face + microphone behaviour monitoring (mobile only).
  bool get cameraProctor =>
      _scopeApplies && _wantsCamera && PlatformSupport.supportsExamProctoring;

  /// Pre-exam back-camera room scan (mobile only).
  bool get roomScan =>
      _scopeApplies && _wantsCamera && PlatformSupport.supportsRoomScan;

  /// Passive proxy / VPN / public-IP detection (all native platforms).
  bool get networkDetect =>
      _scopeApplies && _wantsNetwork && PlatformSupport.supportsNetworkIntegrity;

  /// Active network BLOCK — Android VpnService or desktop hosts-file lockdown.
  /// Only at EXTREME, and only where the platform supports blocking.
  bool get networkBlock =>
      _scopeApplies &&
      level == ExamSafetyLevel.extreme &&
      PlatformSupport.supportsNetworkBlock;

  /// True when nothing at all runs on this device for this exam.
  bool get isInert => !appSwitchProctor && !cameraProctor && !networkDetect;

  Map<String, dynamic> toReport() => {
        'level': levelString,
        'scope': scopeString,
        'measure': measureString,
        'resolved': {
          'appSwitch': appSwitchProctor,
          'camera': cameraProctor,
          'roomScan': roomScan,
          'networkDetect': networkDetect,
          'networkBlock': networkBlock,
        },
      };
}
