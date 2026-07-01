// Vendored & trimmed from exam-guardian
// (/data/projects/anti_cheat_workspace/exam-guardian/lib/models/violation.dart).
// Only the dependency-free types we use today; the fuller enum (face/gaze/audio/
// network) is documented in PROCTORING_NOTES.md for the future AI tier.

enum ViolationType {
  focusLoss,
  appSwitch,
  fullscreenBypass,
}

enum ViolationSeverity {
  low(1.0),
  medium(2.0),
  high(4.0),
  critical(8.0);

  final double value;
  const ViolationSeverity(this.value);
}

class Violation {
  final ViolationType type;
  final String description;
  final DateTime timestamp;
  final double severity;
  final ViolationSeverity severityLevel;

  /// How long the student was away from the exam for this violation (0 for
  /// instantaneous events). Drives the cheat score and the teacher timeline.
  final int durationSeconds;
  final List<String> tags;

  Violation({
    required this.type,
    required this.description,
    required this.timestamp,
    this.severity = 2.0,
    this.severityLevel = ViolationSeverity.medium,
    this.durationSeconds = 0,
    this.tags = const [],
  });

  Map<String, dynamic> toJson() => {
        'type': type.name,
        'description': description,
        'timestamp': timestamp.toIso8601String(),
        'severity': severity,
        'durationSeconds': durationSeconds,
        'tags': tags,
      };
}
