// assignment_model.dart
// flutter pub run build_runner build --delete-conflicting-outputs
// take_assignment_screen.dart
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:htoochoon_flutter/Providers/assignment_provider.dart';
import 'package:htoochoon_flutter/Theme/themedata.dart';

import 'package:flutter/material.dart';
import 'package:htoochoon_flutter/widgets/rich_content.dart';
import 'package:htoochoon_flutter/widgets/lms_dialog.dart';
import 'package:htoochoon_flutter/models/api_models/assignment_model.dart';
import 'package:htoochoon_flutter/models/api_models/enums.dart';
import 'package:htoochoon_flutter/proctoring/exam_proctor.dart';
import 'package:htoochoon_flutter/proctoring/proctoring_consent_sheet.dart';
import 'package:htoochoon_flutter/proctoring/behavior_monitor.dart';
import 'package:htoochoon_flutter/proctoring/behavior_score_engine.dart';
import 'package:htoochoon_flutter/proctoring/network_guard.dart';
import 'package:htoochoon_flutter/proctoring/network_integrity.dart';
import 'package:htoochoon_flutter/proctoring/network_lockdown.dart';
import 'package:htoochoon_flutter/proctoring/exam_safety.dart';
import 'package:htoochoon_flutter/proctoring/exam_safety_notice.dart';
import 'package:htoochoon_flutter/proctoring/proctor_setup_screen.dart';
import 'package:htoochoon_flutter/utils/platform_support.dart';
import 'package:provider/provider.dart';
import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart';

const _kBaseUrl = 'https://backend.htoochoon.com';

// ─────────────────────────────────────────────────────────────────────────────
// TAKE ASSIGNMENT / EXAM SCREEN  (student)
// ─────────────────────────────────────────────────────────────────────────────

class TakeAssignmentScreen extends StatefulWidget {
  final Assignment accessment;
  final String studentId;
  final bool alreadySubmitted;
  const TakeAssignmentScreen({
    super.key,
    required this.accessment,
    required this.studentId,
    this.alreadySubmitted = false,
  });

  @override
  State<TakeAssignmentScreen> createState() => _TakeAssignmentScreenState();
}

class _TakeAssignmentScreenState extends State<TakeAssignmentScreen> {
  // questionId → AnswerRequest being built
  final Map<String, AnswerRequest> _answers = {};

  bool _submitting = false;
  bool _submitted = false;

  // Proctoring: lightweight anti-cheat engine (adapted from exam-guardian).
  // Short absences only warn + score; a long absence force-ends the exam.
  final ExamProctor _proctor = ExamProctor();

  // Silent camera (face/behaviour) + microphone (voice) proctoring. Its score
  // and timeline are sent to the teacher/admin on submit; the student is never
  // warned about these signals.
  final BehaviorMonitor _monitor = BehaviorMonitor();

  // Local network guard (Android VPN) — blocks other apps' internet during the
  // exam. Its downtime (if the student disables it) is reported to the teacher.
  final ExamNetworkGuard _net = ExamNetworkGuard();

  // True while the network guard is supposed to be on but is currently off —
  // drives the warning banner.
  bool _networkOff = false;

  // Gates the exam behind the pre-exam consent prompt.
  bool _consented = false;

  // Teacher-chosen safety policy for THIS exam, resolved against the current
  // platform (see exam_safety.dart). All proctor gates below derive from it, so
  // a NONE exam runs nothing and an EXTREME exam runs everything the platform
  // can do. Set in initState from the Assignment.
  late final ExamSafety _safety;

  // Camera/mic/room-scan: only when the policy asks for camera AND the platform
  // can (mobile). Network guard (Android VpnService block) + desktop hosts
  // lockdown gate on the policy's network-block flag.
  late final bool _fullProctor; // camera/mic/room-scan
  late final bool _netGuard; // Android VpnService block
  late final bool _netIntegrity; // passive proxy/VPN/IP detection
  late final bool _lockdownOn; // desktop hosts-file block (EXTREME)

  // Desktop active network block (hosts file, elevated).
  final NetworkLockdown _lockdown = NetworkLockdown();
  bool _netBlocked = false; // drives a "network locked" banner

  // Passive proxy/VPN detection.
  final NetworkIntegrity _netCheck = NetworkIntegrity();
  // True while a proxy or VPN is currently detected — drives a warning banner.
  bool _proxyOrVpn = false;

  // Timer
  Timer? _timer;
  int _remainingSeconds = 0;
  late final DateTime _startedAt;

  // Full assignment with questions (loaded via /details)
  Assignment? _full;
  bool _loadingDetail = true;

  @override
  void initState() {
    super.initState();
    _startedAt = DateTime.now();

    // Resolve the exam's safety policy for this device → concrete proctor gates.
    _safety = ExamSafety.fromStrings(
      widget.accessment.safetyLevel,
      widget.accessment.safetyScope,
      widget.accessment.safetyMeasure,
    );
    _fullProctor = _safety.cameraProctor;
    _netGuard = _safety.networkBlock && PlatformSupport.isAndroid;
    _netIntegrity = _safety.networkDetect;
    _lockdownOn = _safety.networkBlock && PlatformSupport.isDesktop;

    if (widget.alreadySubmitted) {
      // Nothing to proctor — just show the "already submitted" view.
      _consented = true;
      _loadDetail();
    } else {
      // Ask for consent before anything is monitored or shown.
      WidgetsBinding.instance.addPostFrameCallback((_) => _beginExam());
    }
  }

  Future<void> _beginExam() async {
    // 🔒 Lockout gate: if a prior kick-out locked this exam, the student cannot
    // re-enter until a teacher approves a retake. Checked before anything else.
    final locked =
        await context.read<AssignmentProvider>().isExamLocked(widget.accessment.id);
    if (!mounted) return;
    if (locked) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          icon: const Icon(Icons.lock_outline, color: Colors.red, size: 40),
          title: const Text('Exam locked'),
          content: const Text(
            'This exam was locked after you were removed for a flagged exit. '
            'Ask your teacher to approve a retake before trying again.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.of(context).pop();
      return;
    }

    // Transparency + consent: show the safety level and EXACTLY what will be
    // monitored on this device BEFORE anything starts (incl. the desktop admin
    // prompt). Proceeding is the agreement. Skipped only when nothing runs.
    if (!_safety.isInert) {
      final agreed = await ExamSafetyNotice.show(context, _safety);
      if (!mounted) return;
      if (!agreed) {
        Navigator.of(context).pop(); // declined → don't start the exam
        return;
      }
    }

    // Passive proxy/VPN detection runs on every native platform, regardless of
    // whether the camera/mic proctor is available. Start it first so desktop and
    // iOS get a network integrity signal even on the lightweight branch below.
    if (_netIntegrity) {
      _netCheck.onChange = (clean) {
        if (!mounted) return;
        setState(() => _proxyOrVpn = !clean);
      };
      await _netCheck.start();
      if (mounted) setState(() => _proxyOrVpn = !_netCheck.clean);
    }

    // EXTREME on desktop: actively BLOCK answer/AI/chat sites via the elevated
    // hosts-file lockdown. Best-effort — if the student denies the admin prompt
    // we keep going with detection only (never trap them out of the exam).
    if (_lockdownOn) {
      final ok = await _lockdown.apply();
      if (mounted) setState(() => _netBlocked = ok);
    }

    // No camera proctoring on this device (desktop, web, or the policy didn't
    // ask for camera): skip the camera consent + setup and run with whatever the
    // policy DOES enable (app-switch + network), no camera.
    if (!_fullProctor) {
      if (!mounted) return;
      setState(() => _consented = true);
      if (_safety.appSwitchProctor) _startProctoring();
      _loadDetail();
      return;
    }

    // Consent already captured by ExamSafetyNotice above. Go straight to
    // permissions + back-camera room scan (people/objects).
    final setup = await Navigator.of(context).push<ProctorSetupResult>(
      MaterialPageRoute(
        builder: (_) => const ProctorSetupScreen(),
        fullscreenDialog: true,
      ),
    );
    if (!mounted) return;
    if (setup == null || !setup.ready) {
      if (mounted) Navigator.of(context).pop(); // backed out of setup
      return;
    }

    // Fold the room-scan findings in, then start the silent front-camera +
    // microphone monitoring for the exam itself.
    if (setup.roomScan != null) _monitor.ingestRoomScan(setup.roomScan!);
    await _monitor.start(
      withCamera: setup.perms.camera,
      withAudio: setup.perms.microphone,
    );

    // Start the local network guard (OS VPN consent prompt) and watch its state.
    // Android-only — skipped elsewhere.
    if (_netGuard) {
      _net.onStateChange = (connected) {
        if (!mounted) return;
        setState(() => _networkOff = _net.currentlyDown);
      };
      await _net.start();
      if (mounted) setState(() => _networkOff = _net.currentlyDown);
    }

    if (!mounted) return;
    setState(() => _consented = true);
    if (_safety.appSwitchProctor) _startProctoring();
    _loadDetail();
  }

  void _startProctoring() {
    _proctor.onWarn = (v) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text(
            'Proctoring alert: ${v.description}. Leaving the exam is recorded '
            'and added to your integrity score.',
          ),
        ),
      );
    };
    _proctor.onForceExit = () {
      if (!mounted) return;
      _handleForceExit();
    };
    _proctor.start();
  }

  Future<void> _handleForceExit() async {
    // Lock the exam FIRST — independent of the submission. A forced exit early on
    // (no/partial answers) makes the submission throw, so locking here is what
    // guarantees the student can't just re-enter and retake. Teacher is notified
    // server-side and must approve before the student can try again.
    if (mounted) {
      await context.read<AssignmentProvider>().lockExamForcedExit(
            widget.accessment.id,
            reason: 'left the app during the exam',
            cheatScore: _proctor.cheatScore,
          );
    }
    // Submit whatever exists, flagged as a forced exit, then tell the student.
    await _submit(autoSubmit: true, forced: true);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        icon: const Icon(Icons.gpp_bad_outlined, color: Colors.red, size: 40),
        title: const Text('Exam ended'),
        content: const Text(
          'You left the app for too long during the exam. Your exam has been '
          'submitted and your teacher has been notified.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (mounted) Navigator.of(context).maybePop();
  }

  Future<void> _loadDetail() async {
    final detail = await context
        .read<AssignmentProvider>()
        .fetchAssignmentDetail(widget.accessment.id);
    if (!mounted) return;
    setState(() {
      _full = detail ?? widget.accessment;
      _loadingDetail = false;
    });
    _startTimer();
  }

  void _startTimer() {
    final dur = _full?.duration ?? widget.accessment.duration;
    if (dur == null || dur <= 0) return;

    _remainingSeconds = dur * 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _remainingSeconds--);
      if (_remainingSeconds <= 0) {
        t.cancel();
        _submit(autoSubmit: true);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _proctor.dispose();
    // Camera/mic + VPN guard are only ever started on mobile — only tear them
    // down there (their teardown touches mobile-only plugin channels).
    if (_fullProctor) _monitor.dispose();
    if (_netGuard) _net.stop();
    if (_netIntegrity) _netCheck.stop();
    // Always lift the desktop network block, even on an unexpected teardown, so
    // the student's machine isn't left with answer sites blocked.
    if (_lockdownOn) _lockdown.restore();
    super.dispose();
  }

  String get _timerLabel {
    final m = _remainingSeconds ~/ 60;
    final s = _remainingSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  bool get _hasTimer {
    final dur = _full?.duration ?? widget.accessment.duration;
    return dur != null && dur > 0;
  }

  void _onOptionSelected(Question q, String optionId) {
    setState(() {
      _answers[q.id] = AnswerRequest(
        questionId: q.id,
        // type: q.type.name,
        selectedOptionId: optionId,
      );
    });
  }

  void _onTextChanged(Question q, String text) {
    _answers[q.id] = AnswerRequest(
      questionId: q.id,
      // type: q.type.name,
      textAnswer: text,
    );
  }

  //Open if you're no longer uusing submitworkraw and use normal submitwork from assignment provider
  Future<void> _submit({bool autoSubmit = false, bool forced = false}) async {
    if (_submitted || _submitting) return;

    final questions = _full?.questions ?? widget.accessment.questions;

    // Check required unanswered
    if (!autoSubmit) {
      final unanswered = questions
          .where((q) => q.isRequired && !_answers.containsKey(q.id))
          .toList();
      if (unanswered.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please answer question ${unanswered.first.order} (required)',
            ),
          ),
        );
        return;
      }
    }

    final confirmed = autoSubmit || await _confirmSubmit();
    if (!confirmed) return;

    _timer?.cancel();
    setState(() => _submitting = true);

    try {
      final List<AnswerRequest> formattedAnswers = [];

      // Cleanly build the exact AnswerRequest objects needed
      for (var entry in _answers.entries) {
        final qId = entry.key;
        final answerData = entry.value;

        final q = questions.firstWhere((element) => element.id == qId);

        // ✅ IMPORTANT: Compare against the Enum, not a String!
        if (q.type == QuestionType.SHORT_ANSWER ||
            q.type == QuestionType.ESSAY) {
          if (answerData.textAnswer != null &&
              answerData.textAnswer!.trim().isNotEmpty) {
            // ONLY provide textAnswer, leave selectedOptionId completely out
            formattedAnswers.add(
              AnswerRequest(
                questionId: qId,
                textAnswer: answerData.textAnswer!.trim(),
              ),
            );
          }
        } else {
          // MULTIPLE_CHOICE or TRUE_FALSE
          if (answerData.selectedOptionId != null) {
            // ONLY provide selectedOptionId, leave textAnswer completely out
            formattedAnswers.add(
              AnswerRequest(
                questionId: qId,
                selectedOptionId: answerData.selectedOptionId,
              ),
            );
          }
        }
      }

      // Stop the silent camera/audio monitor + network guard and fold their
      // scores + timelines into the combined report sent to the teacher/admin.
      // Both are mobile-only; on desktop/web their scores stay empty (0).
      if (_fullProctor) await _monitor.stop();
      if (_netGuard) await _net.stop();
      if (_netIntegrity) await _netCheck.stop();
      // Capture the desktop block result for the report, then lift it.
      final lockdownReport = _lockdown.report();
      if (_lockdownOn) await _lockdown.restore();
      final lifecycleReport = _proctor.buildReport();
      final cameraReport = _monitor.buildReport();

      // Network downtime (Android guard) + passive proxy/VPN detection (all
      // platforms) → their own scored events on one engine.
      final netEngine = BehaviorScoreEngine();
      for (final e in _net.toEvents()) {
        netEngine.add(e);
      }
      for (final e in _netCheck.toEvents()) {
        netEngine.add(e);
      }
      final networkReport = _net.downtimeReport();
      final networkIntegrityReport = _netCheck.report();

      final combinedScore =
          (_proctor.cheatScore + _monitor.cheatScore + netEngine.cheatScore)
              .clamp(0, 100);
      final combinedCount =
          _proctor.violationCount + _monitor.eventCount + netEngine.eventCount;
      final combinedFlagged = _proctor.flagged ||
          forced ||
          _monitor.cheatScore >= 40 ||
          netEngine.cheatScore >= 40;

      // Unified timeline for the existing teacher renderer (each item has
      // `timestamp` + `description`); ISO timestamps sort chronologically.
      final mergedViolations = <dynamic>[
        ...((lifecycleReport['violations'] as List?) ?? const []),
        ...((cameraReport['violations'] as List?) ?? const []),
        ...netEngine.events.map((e) => e.toJson()),
      ]..sort((a, b) => '${(a as Map)['timestamp']}'
          .compareTo('${(b as Map)['timestamp']}'));

      // Raw-map payload so we can attach proctoring signals without
      // regenerating the typed model. Anti-cheat values are advisory and never
      // change the grade server-side.
      final payload = <String, dynamic>{
        'studentId': widget.studentId,
        'assessmentId': widget.accessment.id,
        'startedAt': _startedAt.toUtc().toIso8601String(),
        'answers': formattedAnswers.map((a) => a.toJson()).toList(),
        'violationCount': combinedCount,
        'flagged': combinedFlagged,
        'cheatScore': combinedScore,
        'forcedExit': _proctor.forcedExit || forced,
        'proctorReport': {
          'cheatScore': combinedScore,
          'violationCount': combinedCount,
          'flagged': combinedFlagged,
          'forcedExit': _proctor.forcedExit || forced,
          'violations': mergedViolations,
          'breakdown': cameraReport['breakdown'],
          'lifecycle': lifecycleReport,
          'camera': cameraReport,
          'network': networkReport,
          'networkIntegrity': networkIntegrityReport,
          'networkLockdown': lockdownReport,
          'safety': _safety.toReport(),
          'generatedAt': DateTime.now().toUtc().toIso8601String(),
        },
      };

      final result = await context
          .read<AssignmentProvider>()
          .submitAssignmentRaw(payload);

      if (!mounted) return;
      if (result != null) {
        setState(() => _submitted = true);
        // On a forced exit, _handleForceExit owns the messaging + navigation.
        if (!forced) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ Submitted successfully!')),
          );
          Navigator.pop(context);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.read<AssignmentProvider>().error ?? 'Submission failed',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
  // Future<void> _submit({bool autoSubmit = false}) async {
  //   if (_submitted || _submitting) return;
  //
  //   final questions = _full?.questions ?? widget.accessment.questions;
  //
  //   // Check required unanswered
  //   if (!autoSubmit) {
  //     final unanswered = questions
  //         .where((q) => q.isRequired && !_answers.containsKey(q.id))
  //         .toList();
  //     if (unanswered.isNotEmpty) {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Text(
  //             'Please answer question ${unanswered.first.order} (required)',
  //           ),
  //         ),
  //       );
  //       return;
  //     }
  //   }
  //
  //   final confirmed = autoSubmit || await _confirmSubmit();
  //   if (!confirmed) return;
  //
  //   _timer?.cancel();
  //   setState(() => _submitting = true);
  //
  //   try {
  //     final List<Map<String, dynamic>> formattedAnswers = [];
  //
  //     for (var entry in _answers.entries) {
  //       final qId = entry.key;
  //       final answerData = entry.value;
  //
  //       final q = questions.firstWhere((element) => element.id == qId);
  //
  //       // ✅ FIX 1: Compare against the Enum, not a String!
  //       if (q.type == QuestionType.SHORT_ANSWER ||
  //           q.type == QuestionType.ESSAY) {
  //         if (answerData.textAnswer != null &&
  //             answerData.textAnswer!.trim().isNotEmpty) {
  //           formattedAnswers.add({
  //             "questionId": qId,
  //             "textAnswer": answerData.textAnswer!.trim(),
  //           });
  //         }
  //       } else {
  //         // MULTIPLE_CHOICE or TRUE_FALSE
  //         if (answerData.selectedOptionId != null) {
  //           formattedAnswers.add({
  //             "questionId": qId,
  //             "selectedOptionId": answerData.selectedOptionId,
  //           });
  //         }
  //       }
  //     }
  //
  //     // ✅ FIX 2: Keep it as a standard Map, let Dio encode it.
  //     final Map<String, dynamic> payload = {
  //       "studentId": widget.studentId,
  //       "assessmentId": widget.accessment.id,
  //       "startedAt": _startedAt.toUtc().toIso8601String(),
  //       "answers": formattedAnswers,
  //     };
  //
  //     // Pass the map payload safely
  //     final result = await context
  //         .read<AssignmentProvider>()
  //         .submitAssignmentRaw(payload);
  //
  //     if (!mounted) return;
  //     if (result != null) {
  //       setState(() => _submitted = true);
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         const SnackBar(content: Text('✅ Submitted successfully!')),
  //       );
  //       Navigator.pop(context);
  //     } else {
  //       ScaffoldMessenger.of(context).showSnackBar(
  //         SnackBar(
  //           content: Text(
  //             context.read<AssignmentProvider>().error ?? 'Submission failed',
  //           ),
  //         ),
  //       );
  //     }
  //   } finally {
  //     if (mounted) setState(() => _submitting = false);
  //   }
  // }

  Future<bool> _confirmSubmit() {
    return LMSConfirmDialog.show(
      context,
      icon: Icons.assignment_turned_in_outlined,
      title: 'Submit exam?',
      message: 'You cannot change your answers after submitting.',
      confirmLabel: 'Submit',
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final a = _full ?? widget.accessment;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              a.title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            Text(
              a.type == AssignmentType.TEST ? 'Exam' : 'Assignment',
              style: TextStyle(
                fontSize: 11,
                color: cs.onPrimary.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
        actions: [
          // Timer chip
          if (_hasTimer && !_loadingDetail)
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: _remainingSeconds < 300
                    ? Colors.red.withValues(alpha: 0.2)
                    : cs.onPrimary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.timer_outlined,
                    size: 14,
                    color: _remainingSeconds < 300
                        ? Colors.red[200]
                        : cs.onPrimary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _timerLabel,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: _remainingSeconds < 300
                          ? Colors.red[200]
                          : cs.onPrimary,
                    ),
                  ),
                ],
              ),
            ),

          // Submit button
          _submitting
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                )
              : TextButton(
                  onPressed: () => _submit(),
                  child: const Text(
                    'Submit',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
        ],
      ),
      body: (!_consented || _loadingDetail)
          ? const Center(child: CircularProgressIndicator())
          : widget
                .alreadySubmitted // ← safety net
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 64),
                  const SizedBox(height: 16),
                  Text(
                    'Already submitted',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'You have already submitted this exam.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          : Column(
              children: [
                // Network guard OFF warning. This is the one student-facing
                // proctoring warning — it tells them the disconnect is recorded.
                if (_networkOff)
                  Material(
                    color: Colors.red.shade700,
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        child: Row(
                          children: const [
                            Icon(Icons.wifi_off_rounded,
                                color: Colors.white, size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Network protection is OFF. Turn the exam VPN back '
                                'on — this gap is recorded and reported to your teacher.',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 12.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                if (_proxyOrVpn)
                  Material(
                    color: Colors.deepOrange.shade700,
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        child: Row(
                          children: const [
                            Icon(Icons.vpn_lock_rounded,
                                color: Colors.white, size: 18),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'A proxy or VPN connection was detected. Disconnect '
                                'it — this is recorded and reported to your teacher.',
                                style: TextStyle(
                                    color: Colors.white, fontSize: 12.5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Progress bar
                _ProgressBar(
                  answered: _answers.length,
                  total: a.questions.length,
                ),

                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(AppTheme.spaceLg),
                    itemCount: a.questions.length,
                    itemBuilder: (context, i) {
                      final q = a.questions[i];
                      return _QuestionAnswerCard(
                        question: q,
                        index: i,
                        selectedOptionId: _answers[q.id]?.selectedOptionId,
                        textAnswer: _answers[q.id]?.textAnswer,
                        onOptionSelected: (optId) =>
                            _onOptionSelected(q, optId),
                        onTextChanged: (text) => _onTextChanged(q, text),
                      );
                    },
                  ),
                ),

                // Bottom submit bar
                _SubmitBar(
                  answered: _answers.length,
                  total: a.questions.length,
                  submitting: _submitting,
                  onSubmit: () => _submit(),
                ),
              ],
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROGRESS BAR
// ─────────────────────────────────────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  final int answered;
  final int total;

  const _ProgressBar({required this.answered, required this.total});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final progress = total == 0 ? 0.0 : answered / total;

    return Container(
      color: cs.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '$answered / $total answered',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.getTextSecondary(context),
                ),
              ),
              const Spacer(),
              Text(
                '${(progress * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: cs.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: cs.primary.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation(cs.primary),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// QUESTION ANSWER CARD
// ─────────────────────────────────────────────────────────────────────────────

class _QuestionAnswerCard extends StatelessWidget {
  final Question question;
  final int index;
  final String? selectedOptionId;
  final String? textAnswer;
  final void Function(String) onOptionSelected;
  final void Function(String) onTextChanged;

  const _QuestionAnswerCard({
    required this.question,
    required this.index,
    this.selectedOptionId,
    this.textAnswer,
    required this.onOptionSelected,
    required this.onTextChanged,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final answered =
        selectedOptionId != null || (textAnswer?.isNotEmpty ?? false);

    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceLg),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: AppTheme.borderRadiusLg,
        border: Border.all(
          color: answered
              ? cs.primary.withValues(alpha: 0.4)
              : AppTheme.getBorder(context),
          width: answered ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ─────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spaceMd,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: answered
                  ? cs.primary.withValues(alpha: 0.05)
                  : AppTheme.getSurfaceVariant(context),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: answered ? cs.primary : cs.outline.withValues(alpha: 0.2),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: answered ? Colors.white : cs.onSurface,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _typeBadge(context, question.type),
                const Spacer(),
                Text(
                  '${question.points} pts',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: cs.primary,
                    fontSize: 13,
                  ),
                ),
                if (question.isRequired) ...[
                  const SizedBox(width: 6),
                  Text(
                    '*',
                    style: TextStyle(
                      color: Colors.red[400],
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // ── Question HTML ───────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spaceMd,
              AppTheme.spaceSm,
              AppTheme.spaceMd,
              0,
            ),
            child: RichContent(question.text),
          ),

          // ── Attachments ─────────────────────────────────
          if (question.attachments != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spaceMd,
                0,
                AppTheme.spaceMd,
                AppTheme.spaceSm,
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: question.attachments!.map((att) {
                  final isImage = att.fileType.startsWith('image/');
                  final url = '$_kBaseUrl${att.fileUrl}';
                  return GestureDetector(
                    onTap: () => _showImageFull(context, url, att.fileName),
                    child: Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.getBorder(context)),
                      ),
                      child: isImage
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(7),
                              child: CachedNetworkImage(
                                imageUrl: url,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                                errorWidget: (_, __, ___) =>
                                    const Icon(Icons.broken_image),
                              ),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.insert_drive_file, size: 32),
                                const SizedBox(height: 4),
                                Text(
                                  att.fileName,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(fontSize: 9),
                                ),
                              ],
                            ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          const Divider(height: 1),

          // ── Answer area ─────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(AppTheme.spaceMd),
            child: _buildAnswerArea(context),
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerArea(BuildContext context) {
    switch (question.type) {
      case QuestionType.MULTIPLE_CHOICE:
        return Column(
          children: question.options.map((opt) {
            final selected = selectedOptionId == opt.id;
            return _OptionTile(
              opt: opt,
              selected: selected,
              onTap: () => onOptionSelected(opt.id),
            );
          }).toList(),
        );

      case QuestionType.TRUE_FALSE:
        // TRUE_FALSE uses the options list (True/False options from backend)
        // Fall back to manual True/False if options are empty
        if (question.options.isNotEmpty) {
          return Column(
            children: question.options.map((opt) {
              final selected = selectedOptionId == opt.id;
              return _OptionTile(
                opt: opt,
                selected: selected,
                onTap: () => onOptionSelected(opt.id),
              );
            }).toList(),
          );
        }
        // Manual True / False buttons
        return Row(
          children: ['True', 'False'].map((label) {
            final selected = selectedOptionId == label;
            final cs = Theme.of(context).colorScheme;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: GestureDetector(
                  onTap: () => onOptionSelected(label),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: selected
                          ? (label == 'True'
                                ? Colors.green.withValues(alpha: 0.1)
                                : Colors.red.withValues(alpha: 0.1))
                          : AppTheme.getSurfaceVariant(context),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected
                            ? (label == 'True' ? Colors.green : Colors.red)
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          label == 'True'
                              ? Icons.check_circle_outline
                              : Icons.cancel_outlined,
                          color: selected
                              ? (label == 'True' ? Colors.green : Colors.red)
                              : AppTheme.getTextSecondary(context),
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          label,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: selected
                                ? (label == 'True' ? Colors.green : Colors.red)
                                : AppTheme.getTextSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );

      case QuestionType.SHORT_ANSWER:
        return TextField(
          maxLines: 3,
          onChanged: onTextChanged,
          // ✅ Keep SHORT_ANSWER as plain text — it's a short factual response
          controller: TextEditingController(text: textAnswer)
            ..selection = TextSelection.collapsed(
              offset: textAnswer?.length ?? 0,
            ),
          decoration: const InputDecoration(
            hintText: 'Type your answer here…',
            border: OutlineInputBorder(),
          ),
        );

      case QuestionType.ESSAY:
        // ✅ Rich HTML editor — output is an HTML string stored in textAnswer
        return _EssayField(
          initialHtml: textAnswer,
          onChanged: onTextChanged, // saves HTML string back to _answers map
          minLines: 8,
        );
    }
  }

  Widget _typeBadge(BuildContext context, QuestionType type) {
    final labels = {
      QuestionType.MULTIPLE_CHOICE: 'Multiple Choice',
      QuestionType.TRUE_FALSE: 'True / False',
      QuestionType.SHORT_ANSWER: 'Short Answer',
      QuestionType.ESSAY: 'Essay',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.getSurfaceVariant(context),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        labels[type] ?? type.name,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
      ),
    );
  }

  void _showImageFull(BuildContext context, String url, String name) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              title: Text(name, style: const TextStyle(fontSize: 13)),
            ),
            CachedNetworkImage(imageUrl: url),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// OPTION TILE
// ─────────────────────────────────────────────────────────────────────────────

class _OptionTile extends StatelessWidget {
  final Option opt;
  final bool selected;
  final VoidCallback onTap;

  const _OptionTile({
    required this.opt,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? cs.primary.withValues(alpha: 0.08)
              : AppTheme.getSurfaceVariant(context),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? cs.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? cs.primary : cs.outline.withValues(alpha: 0.15),
              ),
              child: Center(
                child: Text(
                  opt.label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: selected ? Colors.white : cs.onSurface,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                opt.text,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            if (selected) Icon(Icons.check_circle, color: cs.primary, size: 18),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOTTOM SUBMIT BAR
// ─────────────────────────────────────────────────────────────────────────────

class _SubmitBar extends StatelessWidget {
  final int answered;
  final int total;
  final bool submitting;
  final VoidCallback onSubmit;

  const _SubmitBar({
    required this.answered,
    required this.total,
    required this.submitting,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final allDone = answered >= total;

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(top: BorderSide(color: AppTheme.getBorder(context))),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: FilledButton(
          onPressed: submitting ? null : onSubmit,
          style: FilledButton.styleFrom(
            backgroundColor: allDone ? cs.primary : cs.primary.withValues(alpha: 0.6),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: submitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  allDone
                      ? 'Submit Answers'
                      : 'Submit ($answered / $total answered)',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
        ),
      ),
    );
  }
}

class _EssayField extends StatefulWidget {
  final String? initialHtml;
  final void Function(String html) onChanged;
  final int minLines;

  const _EssayField({
    this.initialHtml,
    required this.onChanged,
    this.minLines = 8,
  });

  @override
  State<_EssayField> createState() => _EssayFieldState();
}

class _EssayFieldState extends State<_EssayField> {
  late final QuillController _controller;
  late final FocusNode _focusNode;
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();

    // Seed with existing HTML if re-entering the screen
    if (widget.initialHtml != null && widget.initialHtml!.isNotEmpty) {
      // Convert HTML → Delta (best-effort; plain text fallback)
      try {
        final delta = _htmlToDelta(widget.initialHtml!);
        _controller = QuillController(
          document: Document.fromDelta(delta),
          selection: const TextSelection.collapsed(offset: 0),
        );
      } catch (_) {
        _controller = QuillController.basic();
      }
    } else {
      _controller = QuillController.basic();
    }

    _controller.addListener(_onDocChanged);
  }

  void _onDocChanged() {
    final html = _deltaToHtml(_controller.document.toDelta());
    widget.onChanged(html);
  }

  /// Delta → HTML via vsc_quill_delta_to_html
  String _deltaToHtml(Delta delta) {
    final converter = QuillDeltaToHtmlConverter(
      delta.toJson() as List<Map<String, dynamic>>,
      ConverterOptions.forEmail(),
    );
    return converter.convert();
  }

  /// Naive HTML → plain-text Delta (Quill has no built-in HTML parser in Dart)
  Delta _htmlToDelta(String html) {
    // Strip tags for a safe fallback; replace with a proper parser if needed
    final plain = html
        .replaceAll(RegExp(r'<br\s*/?>'), '\n')
        .replaceAll(RegExp(r'<[^>]+>'), '');
    return Delta()..insert('$plain\n');
  }

  @override
  void dispose() {
    _controller.removeListener(_onDocChanged);
    _controller.dispose();
    _focusNode.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Toolbar ───────────────────────────────────────────────
        Container(
          decoration: BoxDecoration(
            color: AppTheme.getSurfaceVariant(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            border: Border.all(color: AppTheme.getBorder(context)),
          ),
          child: QuillSimpleToolbar(
            controller: _controller,
            config: QuillSimpleToolbarConfig(
              // Keep it lean — essays don't need tables/images
              toolbarIconAlignment: WrapAlignment.start,
              showBoldButton: true,
              showItalicButton: true,
              showUnderLineButton: true,
              showListBullets: true,
              showListNumbers: true,
              showStrikeThrough: false,
              showColorButton: false,
              showBackgroundColorButton: false,
              showClearFormat: true,
              showHeaderStyle: false,
              showLink: false,
              showSearchButton: false,
              showSubscript: false,
              showSuperscript: false,
              showInlineCode: false,
              showCodeBlock: false,
              showQuote: false,
              showIndent: false,
              showAlignmentButtons: false,
              showDirection: false,
              showFontFamily: false,
              showFontSize: false,
              showDividers: false,
              multiRowsDisplay: false,
            ),
          ),
        ),

        // ── Editor ────────────────────────────────────────────────
        Container(
          constraints: BoxConstraints(
            minHeight: widget.minLines * 22.0,
            maxHeight: 320,
          ),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(10),
            ),
            border: Border(
              left: BorderSide(color: AppTheme.getBorder(context)),
              right: BorderSide(color: AppTheme.getBorder(context)),
              bottom: BorderSide(color: AppTheme.getBorder(context)),
            ),
          ),
          child: QuillEditor(
            controller: _controller,
            focusNode: _focusNode,
            scrollController: _scroll,
            config: const QuillEditorConfig(
              scrollable: true,
              padding: EdgeInsets.all(12),
              autoFocus: false,
              expands: false,
              placeholder: 'Write your essay here…',
            ),
          ),
        ),

        // ── Character hint ─────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(top: 4, left: 4),
          child: Text(
            'Supports bold, italic, lists',
            style: TextStyle(
              fontSize: 11,
              color: cs.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ),
      ],
    );
  }
}
