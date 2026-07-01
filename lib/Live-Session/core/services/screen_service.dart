import 'package:htoochoon_flutter/core/log/app_logger.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
// 🔄 Swapped out old plugin for the modern one
import 'package:flutter_screen_recording/flutter_screen_recording.dart';
import 'package:path_provider/path_provider.dart';

class ScreenService {
  Process? _desktopRecorderProcess;
  String? _desktopFilePath;

  // ➕ Track current mobile execution state path
  String? _mobileRecordingPath;

  Future<Map<String, String>> _getWindowsAudioDevices() async {
    String micDevice = "";
    String stereoMixDevice = "";

    try {
      final ProcessResult result = await Process.run('ffmpeg', [
        '-list_devices', 'true',
        '-f', 'dshow',
        '-i', 'dummy'
      ]);

      final String output = result.stderr.toString();
      final List<String> lines = const LineSplitter().convert(output);

      for (int i = 0; i < lines.length; i++) {
        final String line = lines[i];
        if (line.contains('[dshow @')) {
          final RegExp matchQuotes = RegExp(r'"([^"]*)"');
          final Match? match = matchQuotes.firstMatch(line);

          if (match != null) {
            final String deviceName = match.group(1)!;
            final String lowerName = deviceName.toLowerCase();

            if (lowerName.contains('mic') || lowerName.contains('audio input')) {
              micDevice = deviceName;
            } else if (lowerName.contains('stereo mix') || lowerName.contains('wave out') || lowerName.contains('what u hear')) {
              stereoMixDevice = deviceName;
            }
          }
        }
      }
    } catch (e) {
      logD("⚠️ Windows audio auto-discovery failure: $e");
    }

    return {
      'microphone': micDevice,
      'systemAudio': stereoMixDevice,
    };
  }

  Future<Map<String, String>> _getLinuxAudioDevices() async {
    String micDevice = "";
    String systemAudioDevice = "";

    try {
      final ProcessResult sinkResult = await Process.run('pactl', ['get-default-sink']);
      if (sinkResult.exitCode == 0) {
        final String activeSink = sinkResult.stdout.toString().trim();
        systemAudioDevice = "$activeSink.monitor";
      }

      final ProcessResult sourceResult = await Process.run('pactl', ['get-default-source']);
      if (sourceResult.exitCode == 0) {
        micDevice = sourceResult.stdout.toString().trim();
      }
    } catch (e) {
      logD("⚠️ Linux audio auto-discovery failure: $e");
    }

    return {
      'microphone': micDevice,
      'systemAudio': systemAudioDevice,
    };
  }

  /// Returns true only when a recorder actually started, so the UI never shows
  /// a "recording" state for a session that silently failed to launch.
  /// When [includeMic] is false, microphone audio is excluded from the
  /// recording (system/loopback audio is still captured when available).
  Future<bool> startRecording({bool includeMic = true}) async {
    final Directory documentsDir = await getApplicationDocumentsDirectory();
    final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    _desktopFilePath = "${documentsDir.path}/meeting_capture_$timestamp.mp4";

    File oldFile = File(_desktopFilePath!);
    if (await oldFile.exists()) {
      await oldFile.delete();
    }

    // ==========================================
    // 🪟 DYNAMIC WINDOWS EXECUTION PIPELINE
    // ==========================================
    if (Platform.isWindows) {
      await Process.run('taskkill', ['/F', '/IM', 'ffmpeg.exe']);

      final Map<String, String> devices = await _getWindowsAudioDevices();
      final String mic = includeMic ? (devices['microphone'] ?? "") : "";
      final String loopback = devices['systemAudio'] ?? "";

      List<String> ffmpegArgs = [
        '-y',
        '-f', 'gdigrab', '-framerate', '15', '-i', 'desktop',
      ];

      if (loopback.isNotEmpty && mic.isNotEmpty) {
        ffmpegArgs.addAll([
          '-f', 'dshow', '-i', 'audio=$loopback',
          '-f', 'dshow', '-i', 'audio=$mic',
          '-filter_complex', 'amix=inputs=2:duration=first',
        ]);
      } else if (loopback.isNotEmpty) {
        ffmpegArgs.addAll(['-f', 'dshow', '-i', 'audio=$loopback']);
      } else if (mic.isNotEmpty) {
        ffmpegArgs.addAll(['-f', 'dshow', '-i', 'audio=$mic']);
      }

      ffmpegArgs.addAll([
        '-s', '1280x720',
        '-c:v', 'libx264', '-c:a', 'aac', '-pix_fmt', 'yuv420p',
        _desktopFilePath!
      ]);

      try {
        _desktopRecorderProcess = await Process.start('ffmpeg', ffmpegArgs);
        logD("🪟 Windows: Live dynamic FFmpeg recording session initialized.");
        return true;
      } catch (e) {
        logD("❌ Dynamic Windows process failure: $e");
        return false;
      }
    }

    // ==========================================
    // 🐧 DYNAMIC LINUX EXECUTION PIPELINE
    // ==========================================
    if (Platform.isLinux) {
      try {
        await Process.run('killall', ['-9', 'ffmpeg']);
        await Process.run('killall', ['-9', 'wf-recorder']);

        final Map<String, String> devices = await _getLinuxAudioDevices();
        final String mic = includeMic ? (devices['microphone'] ?? "") : "";
        final String loopback = devices['systemAudio'] ?? "";

        final bool isWayland = Platform.environment['XDG_SESSION_TYPE']?.toLowerCase() == 'wayland';

        if (isWayland) {
          logD("🌐 Detected Wayland Environment. Wiring wf-recorder with audio loopbacks...");

          List<String> wfArgs = [
            '-f', _desktopFilePath!,
            '-p', 'yuv420p',
          ];

          if (mic.isNotEmpty && loopback.isNotEmpty) {
            wfArgs.addAll(['-a', mic, '-a', loopback]);
          } else if (loopback.isNotEmpty) {
            wfArgs.addAll(['-a', loopback]);
          } else if (mic.isNotEmpty) {
            wfArgs.addAll(['-a', mic]);
          }

          _desktopRecorderProcess = await Process.start('wf-recorder', wfArgs);
        } else {
          logD("🖥️ Detected X11/KDE Environment. Using FFmpeg x11grab...");

          List<String> ffmpegArgs = [
            '-y',
            '-f', 'x11grab',
            '-video_size', '1920x1200',
            '-framerate', '15',
            '-i', ':0.0',
          ];

          if (mic.isNotEmpty && loopback.isNotEmpty) {
            ffmpegArgs.addAll([
              '-f', 'pulse', '-i', mic,
              '-f', 'pulse', '-i', loopback,
              '-filter_complex', 'amix=inputs=2:duration=first',
            ]);
          } else if (loopback.isNotEmpty) {
            ffmpegArgs.addAll(['-f', 'pulse', '-i', loopback]);
          } else if (mic.isNotEmpty) {
            ffmpegArgs.addAll(['-f', 'pulse', '-i', mic]);
          }

          ffmpegArgs.addAll([
            '-c:v', 'libx264', '-c:a', 'aac', '-pix_fmt', 'yuv420p',
            _desktopFilePath!
          ]);

          _desktopRecorderProcess = await Process.start('ffmpeg', ffmpegArgs);
        }

        _desktopRecorderProcess!.stderr.transform(utf8.decoder).listen((data) {
          logD("🎥 Recorder Engine Output: $data");
        });

        return _desktopRecorderProcess != null;
      } catch (e) {
        logD("❌ Linux Dynamic Spawn failure: $e");
        return false;
      }
    }

    // ==========================================
    // 📱 NEW MOBILE FALLBACK (Android / iOS)
    // ==========================================
    logD("📱 Mobile Platform Detected. Initializing flutter_screen_recording...");
    try {
      // Clean unique tracking label for the session
      final String videoName = "meeting_capture_$timestamp";

      // Since you want both microphone and system mixed audio, we use the specific sub-method
      final bool startSuccess = await FlutterScreenRecording.startRecordScreenAndAudio(
        videoName,
        titleNotification: 'Meeting Recording',
        messageNotification: 'Your video stream session is currently active.',
      );

      logD("📱 Mobile Recorder Handshake Status: $startSuccess");
      return startSuccess;
    } catch (e) {
      logD("❌ Mobile internal recorder start failure: $e");
      return false;
    }
  }

  /// Last captured local file path (desktop ffmpeg / mobile plugin output).
  String? get lastRecordingPath => _mobileRecordingPath ?? _desktopFilePath;

  /// Stop the recorder and return the LOCAL file path (no base64). Used by the
  /// pausable local-recording flow so the file can be saved to the gallery /
  /// Library instead of (or in addition to) being shipped to the server.
  Future<String?> stopAndGetFilePath() async {
    if (Platform.isWindows || Platform.isLinux) {
      if (_desktopRecorderProcess != null && _desktopFilePath != null) {
        if (Platform.isWindows) {
          _desktopRecorderProcess!.stdin.write('q');
        } else {
          _desktopRecorderProcess!.kill(ProcessSignal.sigint);
        }
        await _desktopRecorderProcess!.exitCode;
        _desktopRecorderProcess = null;
        if (await File(_desktopFilePath!).exists()) return _desktopFilePath;
      }
      return null;
    }
    try {
      final String outputPath = await FlutterScreenRecording.stopRecordScreen;
      if (outputPath.isNotEmpty && await File(outputPath).exists()) {
        _mobileRecordingPath = outputPath;
        return outputPath;
      }
    } catch (e) {
      logD("❌ stopAndGetFilePath crash: $e");
    }
    return null;
  }

  Future<String?> stopAndGetBase64() async {
    // DESKTOP CLEANUP (Windows & Linux remains identical)
    if (Platform.isWindows || Platform.isLinux) {
      if (_desktopRecorderProcess != null && _desktopFilePath != null) {
        if (Platform.isWindows) {
          _desktopRecorderProcess!.stdin.write('q');
        } else {
          _desktopRecorderProcess!.kill(ProcessSignal.sigint);
        }

        await _desktopRecorderProcess!.exitCode;
        _desktopRecorderProcess = null;

        File file = File(_desktopFilePath!);
        if (await file.exists()) {
          await _copyToPublicDownloads(file);
          Uint8List bytes = await file.readAsBytes();
          return base64Encode(bytes);
        }
      }
      return null;
    }

    // ==========================================
    // 📱 NEW MOBILE CLEANUP TERMINATION PIPELINE
    // ==========================================
    try {
      logD("📱 Stopping Mobile Screen Capture...");
      // The plugin returns the string output path directly when called
      final String outputPath = await FlutterScreenRecording.stopRecordScreen;

      if (outputPath.isNotEmpty) {
        logD("📁 Mobile video file finalized at: $outputPath");
        File sandboxedFile = File(outputPath);

        if (await sandboxedFile.exists()) {
          // Send a copy to the user's phone downloads storage folder
          await _copyToPublicDownloads(sandboxedFile);

          // Encode to pass back up through the socket service structure
          Uint8List bytes = await sandboxedFile.readAsBytes();
          return base64Encode(bytes);
        }
      }
    } catch (e) {
      logD("❌ Mobile termination/encoding pipeline crash: $e");
    }
    return null;
  }

  Future<void> _copyToPublicDownloads(File sandboxedFile) async {
    try {
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();

      if (Platform.isWindows) {
        final String? userProfile = Platform.environment['USERPROFILE'];
        if (userProfile != null) {
          final String publicPath = "$userProfile\\Downloads\\Meeting_Record_$timestamp.mp4";
          await sandboxedFile.copy(publicPath);
          logD("🪟 Windows: File successfully copied to Downloads folder: $publicPath");
        }
      } else if (Platform.isAndroid) {
        final Directory downloadsDir = Directory('/storage/emulated/0/Download');
        if (await downloadsDir.exists()) {
          final String publicPath = "${downloadsDir.path}/Meeting_Record_$timestamp.mp4";
          await sandboxedFile.copy(publicPath);
          logD("🤖 Android: Exported to Public Downloads directory: $publicPath");
        }
      } else if (Platform.isLinux) {
        final String? home = Platform.environment['HOME'];
        if (home != null) {
          final String publicPath = "$home/Downloads/Meeting_Record_$timestamp.mp4";
          await sandboxedFile.copy(publicPath);
          logD("🐧 Linux: File successfully copied to Downloads folder: $publicPath");
        }
      }
    } catch (e) {
      logD("⚠️ Public directory mapping failed: $e");
    }
  }
}