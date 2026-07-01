/// Camera/audio/system behaviour events detected during a proctored exam, plus
/// the per-type scoring configuration.
///
/// Adapted (not copied) from `exam-guardian`'s violation model — re-built around
/// a single 0–100 advisory cheat score that weights each event by its base
/// severity, how LONG it lasted, the head ANGLE (for gaze events), and a
/// COMPOUNDING multiplier so the same violation happening many times hurts more
/// than one long event. The score is advisory only and never changes the grade.
library;

enum BehaviorEventType {
  // Camera / vision
  faceMissing, // FACE_MISSING — no face in frame
  faceLeft, // FACE_LEFT — face moved out to the frame edge
  lookingLeft, // LOOKING_LEFT
  lookingRight, // LOOKING_RIGHT
  lookingDown, // LOOKING_DOWN — classic "reading notes on the desk"
  multiplePerson, // MULTIPLE_PERSON — more than one face
  phoneDetected, // PHONE_DETECTED (object detection — premium/future)
  earphoneDetected, // EARPHONE_DETECTED (premium/future)

  // Audio
  voiceDetected, // VOICE_DETECTED — sustained speech / talking

  // System / focus
  tabSwitch, // TAB_SWITCH
  windowBlur, // WINDOW_BLUR — app lost focus / backgrounded
  fullscreenExit, // FULLSCREEN_EXIT

  // Network
  networkGuardOff, // NETWORK_GUARD_OFF — VPN/proxy guard was disabled mid-exam
  proxyDetected, // PROXY_DETECTED — system HTTP(S) proxy active during the exam
  vpnDetected, // VPN_DETECTED — a VPN-like network interface (tun/utun/ppp/wg…)

  // Pre-exam room scan (back camera)
  roomPerson, // ROOM_PERSON — another person seen during the room scan
  roomObject, // ROOM_OBJECT — suspicious object seen during the room scan
}

/// Maps an event type to the wire code (the SCREAMING_SNAKE names the user
/// referenced), used in the report sent to the teacher/admin.
extension BehaviorEventCode on BehaviorEventType {
  String get code {
    switch (this) {
      case BehaviorEventType.faceMissing:
        return 'FACE_MISSING';
      case BehaviorEventType.faceLeft:
        return 'FACE_LEFT';
      case BehaviorEventType.lookingLeft:
        return 'LOOKING_LEFT';
      case BehaviorEventType.lookingRight:
        return 'LOOKING_RIGHT';
      case BehaviorEventType.lookingDown:
        return 'LOOKING_DOWN';
      case BehaviorEventType.multiplePerson:
        return 'MULTIPLE_PERSON';
      case BehaviorEventType.phoneDetected:
        return 'PHONE_DETECTED';
      case BehaviorEventType.earphoneDetected:
        return 'EARPHONE_DETECTED';
      case BehaviorEventType.voiceDetected:
        return 'VOICE_DETECTED';
      case BehaviorEventType.tabSwitch:
        return 'TAB_SWITCH';
      case BehaviorEventType.windowBlur:
        return 'WINDOW_BLUR';
      case BehaviorEventType.fullscreenExit:
        return 'FULLSCREEN_EXIT';
      case BehaviorEventType.networkGuardOff:
        return 'NETWORK_GUARD_OFF';
      case BehaviorEventType.proxyDetected:
        return 'PROXY_DETECTED';
      case BehaviorEventType.vpnDetected:
        return 'VPN_DETECTED';
      case BehaviorEventType.roomPerson:
        return 'ROOM_PERSON';
      case BehaviorEventType.roomObject:
        return 'ROOM_OBJECT';
    }
  }

  String get label {
    switch (this) {
      case BehaviorEventType.faceMissing:
        return 'Face not visible';
      case BehaviorEventType.faceLeft:
        return 'Face left the frame';
      case BehaviorEventType.lookingLeft:
        return 'Looking left';
      case BehaviorEventType.lookingRight:
        return 'Looking right';
      case BehaviorEventType.lookingDown:
        return 'Looking down';
      case BehaviorEventType.multiplePerson:
        return 'Multiple people detected';
      case BehaviorEventType.phoneDetected:
        return 'Phone detected';
      case BehaviorEventType.earphoneDetected:
        return 'Earphone detected';
      case BehaviorEventType.voiceDetected:
        return 'Voice / talking detected';
      case BehaviorEventType.tabSwitch:
        return 'Switched tab/app';
      case BehaviorEventType.windowBlur:
        return 'Left the exam window';
      case BehaviorEventType.fullscreenExit:
        return 'Exited full screen';
      case BehaviorEventType.networkGuardOff:
        return 'Network protection disabled';
      case BehaviorEventType.proxyDetected:
        return 'Proxy connection detected';
      case BehaviorEventType.vpnDetected:
        return 'VPN connection detected';
      case BehaviorEventType.roomPerson:
        return 'Another person in the room';
      case BehaviorEventType.roomObject:
        return 'Suspicious object in the room';
    }
  }
}

/// Per-type scoring weights. Tuned so a clean exam scores ~0 and clear cheating
/// (phone, another person, long absence) climbs quickly toward 100.
class BehaviorWeight {
  final double base; // points for a single, instantaneous occurrence
  final double perSecond; // added per second of duration …
  final int durationCapSeconds; // … capped at this many seconds
  final double angleBonus; // extra points scaled by how far past threshold (gaze)
  final BehaviorSeverity severity;

  const BehaviorWeight({
    required this.base,
    this.perSecond = 0,
    this.durationCapSeconds = 20,
    this.angleBonus = 0,
    this.severity = BehaviorSeverity.medium,
  });
}

enum BehaviorSeverity { low, medium, high, critical }

/// The single source of truth for how much each behaviour costs.
const Map<BehaviorEventType, BehaviorWeight> kBehaviorWeights = {
  BehaviorEventType.multiplePerson: BehaviorWeight(
      base: 18, perSecond: 0.6, severity: BehaviorSeverity.critical),
  BehaviorEventType.phoneDetected:
      BehaviorWeight(base: 18, severity: BehaviorSeverity.critical),
  BehaviorEventType.earphoneDetected:
      BehaviorWeight(base: 12, severity: BehaviorSeverity.high),
  BehaviorEventType.faceMissing: BehaviorWeight(
      base: 5, perSecond: 0.8, durationCapSeconds: 20, severity: BehaviorSeverity.high),
  BehaviorEventType.faceLeft: BehaviorWeight(
      base: 5, perSecond: 0.8, durationCapSeconds: 20, severity: BehaviorSeverity.high),
  BehaviorEventType.lookingDown: BehaviorWeight(
      base: 3,
      perSecond: 0.5,
      durationCapSeconds: 15,
      angleBonus: 3,
      severity: BehaviorSeverity.medium),
  BehaviorEventType.lookingLeft: BehaviorWeight(
      base: 2,
      perSecond: 0.4,
      durationCapSeconds: 15,
      angleBonus: 3,
      severity: BehaviorSeverity.medium),
  BehaviorEventType.lookingRight: BehaviorWeight(
      base: 2,
      perSecond: 0.4,
      durationCapSeconds: 15,
      angleBonus: 3,
      severity: BehaviorSeverity.medium),
  BehaviorEventType.voiceDetected: BehaviorWeight(
      base: 6, perSecond: 0.5, durationCapSeconds: 20, severity: BehaviorSeverity.medium),
  BehaviorEventType.tabSwitch:
      BehaviorWeight(base: 12, severity: BehaviorSeverity.high),
  BehaviorEventType.windowBlur: BehaviorWeight(
      base: 8, perSecond: 0.6, durationCapSeconds: 20, severity: BehaviorSeverity.high),
  BehaviorEventType.fullscreenExit:
      BehaviorWeight(base: 10, severity: BehaviorSeverity.high),
  BehaviorEventType.networkGuardOff: BehaviorWeight(
      base: 20, perSecond: 0.5, durationCapSeconds: 30, severity: BehaviorSeverity.critical),
  BehaviorEventType.proxyDetected:
      BehaviorWeight(base: 14, severity: BehaviorSeverity.high),
  BehaviorEventType.vpnDetected:
      BehaviorWeight(base: 16, severity: BehaviorSeverity.critical),
  BehaviorEventType.roomPerson:
      BehaviorWeight(base: 16, severity: BehaviorSeverity.critical),
  BehaviorEventType.roomObject:
      BehaviorWeight(base: 6, severity: BehaviorSeverity.high),
};

/// One finalized behaviour event (the condition started and ended, so we know
/// its duration).
class BehaviorEvent {
  final BehaviorEventType type;
  final DateTime timestamp; // when the event started
  final int durationSeconds;

  /// For gaze events, |head angle| in degrees at the worst point (0 otherwise).
  final double angle;

  BehaviorEvent({
    required this.type,
    required this.timestamp,
    this.durationSeconds = 0,
    this.angle = 0,
  });

  BehaviorWeight get weight =>
      kBehaviorWeights[type] ??
      const BehaviorWeight(base: 2, severity: BehaviorSeverity.low);

  BehaviorSeverity get severity => weight.severity;

  /// Human-readable timeline line, e.g. "Looking down for 6s (34°)".
  String get description {
    final parts = <String>[type.label];
    if (durationSeconds > 0) parts.add('for ${durationSeconds}s');
    if (angle > 0) parts.add('(${angle.toStringAsFixed(0)}°)');
    return parts.join(' ');
  }

  Map<String, dynamic> toJson() => {
        'type': type.code,
        'description': description,
        'timestamp': timestamp.toIso8601String(),
        'durationSeconds': durationSeconds,
        'angle': angle,
        'severity': severity.name,
      };
}
