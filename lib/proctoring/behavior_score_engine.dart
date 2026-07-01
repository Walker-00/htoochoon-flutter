import 'dart:math' as math;
import 'behavior_event.dart';

/// Accumulates [BehaviorEvent]s and produces a single advisory cheat score
/// (0–100) plus a report for the teacher/admin.
///
/// Scoring per event:
///   points = base
///          + min(duration, cap) * perSecond          // longer = worse
///          + angleBonus * clamp((angle-thr)/thr,0,1)  // wider gaze = worse
///   points *= compound(nth occurrence of this type)   // repeats compound
///
/// `compound` escalates each repeat: the 1st costs ×1, then ×1.2, ×1.4, …
/// capped at [_compoundMax]. So violating many times piles up faster than a
/// single long event — matching "violating many times can compound the score".
class BehaviorScoreEngine {
  BehaviorScoreEngine({
    this.gazeThresholdDeg = 25.0,
    double compoundStep = 0.2,
    double compoundMax = 2.5,
  })  : _compoundStep = compoundStep,
        _compoundMax = compoundMax;

  /// Head-angle threshold (deg) used to scale the gaze angle bonus.
  final double gazeThresholdDeg;
  final double _compoundStep;
  final double _compoundMax;

  final List<BehaviorEvent> _events = [];
  final Map<BehaviorEventType, int> _counts = {};
  double _rawScore = 0;

  List<BehaviorEvent> get events => List.unmodifiable(_events);
  int get eventCount => _events.length;
  Map<BehaviorEventType, int> get countsByType => Map.unmodifiable(_counts);

  /// Advisory cheat score 0–100 (higher = more likely cheating).
  int get cheatScore => _rawScore.clamp(0, 100).round();

  void add(BehaviorEvent e) {
    _events.add(e);
    final n = (_counts[e.type] ?? 0) + 1;
    _counts[e.type] = n;
    _rawScore += _pointsFor(e, n);
  }

  double _pointsFor(BehaviorEvent e, int occurrence) {
    final w = e.weight;
    var points = w.base;

    if (w.perSecond > 0 && e.durationSeconds > 0) {
      points += math.min(e.durationSeconds, w.durationCapSeconds) * w.perSecond;
    }

    if (w.angleBonus > 0 && e.angle > 0) {
      final over =
          ((e.angle - gazeThresholdDeg) / gazeThresholdDeg).clamp(0.0, 1.0);
      points += w.angleBonus * over;
    }

    final compound =
        (1 + _compoundStep * (occurrence - 1)).clamp(1.0, _compoundMax);
    return points * compound;
  }

  /// Per-type tallies for the teacher summary, e.g.
  /// `{ "LOOKING_DOWN": 4, "FACE_MISSING": 2 }`.
  Map<String, int> get breakdown => {
        for (final entry in _counts.entries) entry.key.code: entry.value,
      };

  /// Report merged into the submission's `proctorReport`. The `violations`
  /// list intentionally matches the existing teacher timeline renderer
  /// (each item has `timestamp` + `description`).
  Map<String, dynamic> buildReport() => {
        'cameraCheatScore': cheatScore,
        'cameraEventCount': eventCount,
        'breakdown': breakdown,
        'violations': _events.map((e) => e.toJson()).toList(),
        'generatedAt': DateTime.now().toUtc().toIso8601String(),
      };

  void reset() {
    _events.clear();
    _counts.clear();
    _rawScore = 0;
  }
}
