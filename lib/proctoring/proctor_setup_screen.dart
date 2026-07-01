import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import 'proctor_permissions.dart';
import 'room_scanner.dart';

/// What the setup screen hands back to the exam screen.
class ProctorSetupResult {
  final bool ready;
  final ProctorPermissions perms;
  final RoomScanResult? roomScan;
  const ProctorSetupResult({
    required this.ready,
    required this.perms,
    this.roomScan,
  });
}

/// Pre-exam setup: permissions + a real **back-camera room scan** (ML Kit face
/// + object detection). Front-camera behaviour monitoring starts later, when
/// the exam itself begins. Returns a [ProctorSetupResult].
class ProctorSetupScreen extends StatefulWidget {
  const ProctorSetupScreen({super.key});

  @override
  State<ProctorSetupScreen> createState() => _ProctorSetupScreenState();
}

class _ProctorSetupScreenState extends State<ProctorSetupScreen> {
  final RoomScanner _scanner = RoomScanner();

  bool _loading = true;
  ProctorPermissions? _perms;
  int _scanSeconds = 5;
  Timer? _scanTimer;
  int _peopleNow = 0;
  int _objectsNow = 0;
  double _panProgress = 0; // 0..1 of the required physical sweep
  bool _gyroFallback = false; // device has no gyroscope → timed scan only

  @override
  void initState() {
    super.initState();
    _scanner.onUpdate = (people, objects) {
      if (!mounted) return;
      setState(() {
        _peopleNow = people;
        _objectsNow = objects;
      });
    };
    _scanner.onPanProgress = (p) {
      if (mounted) setState(() => _panProgress = p);
    };
    _scanner.onCameraReady = (_) {
      if (mounted) setState(() {});
    };
    _init();
  }

  Future<void> _init() async {
    final perms = await requestProctorPermissions();
    if (!mounted) return;
    setState(() {
      _perms = perms;
      _loading = false;
    });
    if (perms.camera) {
      await _scanner.start();
      if (mounted) _startScanCountdown();
    }
  }

  void _startScanCountdown() {
    _scanTimer?.cancel();
    _scanTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => _scanSeconds = (_scanSeconds - 1).clamp(0, 5));
      if (_scanSeconds == 0) {
        t.cancel();
        // Grace period is over: if the gyroscope never produced a reading, this
        // device can't measure panning, so accept a timed sweep instead.
        if (!_scanner.hadGyroscope && mounted) {
          setState(() => _gyroFallback = true);
        }
      }
    });
  }

  Future<void> _finish(bool ready) async {
    final result = _perms?.camera ?? false ? _scanner.result() : null;
    await _scanner.stop();
    if (!mounted) return;
    Navigator.of(context).pop(
      ProctorSetupResult(
        ready: ready,
        perms: _perms ??
            const ProctorPermissions(camera: false, microphone: false),
        roomScan: ready ? result : null,
      ),
    );
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    _scanner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final controller = _scanner.controller;
    final cameraReady = (_perms?.camera ?? false) &&
        controller != null &&
        controller.value.isInitialized;
    final cameraOn = _perms?.camera ?? false;
    // A real sweep = the grace timer elapsed AND the student physically panned
    // the phone enough (measured by the gyroscope). On devices without a
    // gyroscope, panComplete falls back to the timed sweep.
    final panComplete = _gyroFallback || _panProgress >= 1.0;
    final scanDone = !cameraOn || (_scanSeconds == 0 && panComplete);
    final useGyro = cameraOn && !_gyroFallback && _scanner.hadGyroscope;
    final foundSomething = _peopleNow > 0 || _objectsNow > 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Room scan')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (cameraReady)
                    Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: AspectRatio(
                            aspectRatio: 3 / 4,
                            child: CameraPreview(controller),
                          ),
                        ),
                        if (!scanDone)
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.threesixty,
                                    color: Colors.white, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  useGyro
                                      ? 'Turn slowly… ${(_panProgress * 100).round()}%'
                                      : 'Scanning… $_scanSeconds',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ],
                            ),
                          ),
                      ],
                    )
                  else
                    _cameraUnavailable(cs),
                  const SizedBox(height: 20),

                  Text(
                    cameraReady ? 'Scan your surroundings' : 'Camera not available',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    cameraReady
                        ? 'Slowly turn yourself around with the back camera so we can see your whole desk and room — that you are alone and there are no notes, phones, or other devices. Keep turning until the bar is full. This is shared with your teacher.'
                        : 'Camera access was not granted, so the room scan and face monitoring are off for this attempt. The exam will continue and other integrity checks still apply.',
                    style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.7), height: 1.5),
                  ),
                  const SizedBox(height: 12),
                  if (useGyro) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: _panProgress,
                        minHeight: 8,
                        backgroundColor: cs.surfaceContainerHighest,
                        color: _panProgress >= 1.0 ? Colors.green : cs.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _panProgress >= 1.0
                          ? 'Great — full sweep captured.'
                          : 'Keep turning to scan the whole room…',
                      style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurface.withValues(alpha: 0.6)),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (cameraReady)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: foundSomething
                            ? Colors.orange.withValues(alpha: 0.12)
                            : Colors.green.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            foundSomething
                                ? Icons.warning_amber_rounded
                                : Icons.check_circle_outline,
                            size: 18,
                            color: foundSomething ? Colors.orange : Colors.green,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              foundSomething
                                  ? 'In view now: $_peopleNow person(s), $_objectsNow object(s). Make sure you are alone with a clear desk.'
                                  : 'Looks clear. Keep panning to finish the scan.',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 12),
                  _sensorRow(cs, Icons.videocam_outlined, 'Camera',
                      _perms?.camera ?? false),
                  const SizedBox(height: 6),
                  _sensorRow(cs, Icons.mic_none_rounded, 'Microphone',
                      _perms?.microphone ?? false),
                  const SizedBox(height: 16),
                  if (!(_perms?.camera ?? false))
                    OutlinedButton.icon(
                      onPressed: () => openAppSettings(),
                      icon: const Icon(Icons.settings),
                      label: const Text('Open settings'),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _finish(false),
                          style: OutlinedButton.styleFrom(
                              minimumSize: const Size(0, 50)),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton(
                          onPressed: scanDone ? () => _finish(true) : null,
                          style: FilledButton.styleFrom(
                              minimumSize: const Size(0, 50)),
                          child: Text(
                            scanDone
                                ? 'Start exam'
                                : useGyro
                                    ? 'Turn to scan… ${(_panProgress * 100).round()}%'
                                    : 'Scanning… $_scanSeconds',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
    );
  }

  Widget _cameraUnavailable(ColorScheme cs) => AspectRatio(
        aspectRatio: 3 / 4,
        child: Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.videocam_off_outlined,
                  size: 48, color: cs.onSurface.withValues(alpha: 0.4)),
              const SizedBox(height: 8),
              Text('No camera preview',
                  style: TextStyle(color: cs.onSurface.withValues(alpha: 0.6))),
            ],
          ),
        ),
      );

  Widget _sensorRow(ColorScheme cs, IconData icon, String label, bool ok) {
    return Row(
      children: [
        Icon(icon, size: 18, color: cs.onSurface.withValues(alpha: 0.7)),
        const SizedBox(width: 8),
        Text(label),
        const Spacer(),
        Icon(ok ? Icons.check_circle : Icons.cancel,
            size: 18, color: ok ? Colors.green : Colors.redAccent),
        const SizedBox(width: 4),
        Text(ok ? 'On' : 'Off',
            style: TextStyle(
                color: ok ? Colors.green : Colors.redAccent,
                fontWeight: FontWeight.w600)),
      ],
    );
  }
}
