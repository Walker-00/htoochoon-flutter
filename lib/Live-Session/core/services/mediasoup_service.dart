import 'package:htoochoon_flutter/core/log/app_logger.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:mediasfu_mediasoup_client/mediasfu_mediasoup_client.dart';
import 'package:htoochoon_flutter/Live-Session/core/services/socket_service.dart';
import 'package:path_provider/path_provider.dart';

class MediasoupService {
  Device? _device;
  Transport? _sendTransport;
  Transport? _recvTransport;
  MediaStream? _localStream;
  MediaStream? screenStream;

  bool _isSendTransportConnected = false;
  bool _isRecvTransportConnected = false;
  bool get isSendTRXConnected => _isSendTransportConnected;
  bool get isRecvTRXConnected => _isRecvTransportConnected;
  Completer<Producer>? _videoProductionCompleter;
  Consumer? getConsumer(String id) => _consumers[id];
  List<Consumer> get allConsumers => _consumers.values.toList();
  final Completer<void> _recvTransportReadyCompleter = Completer();

  MediaRecorder? _localRecorder;
  String? _recordingPath;
  bool get isRecording => _isRecording;
  String? get recordingPath => _recordingPath;
  bool _isRecording = false;
  bool _isDisposed = false;
  Producer? _videoProducer;
  Producer? _audioProducer;
  // Screen share is its OWN producer (source 'screen'), kept separate from the
  // camera producer so stopping a share never touches the webcam/mic pipeline.
  Producer? _screenProducer;
  Completer<Producer>? _screenProducerCompleter;
  bool _isScreenSharing = false;

  bool get isScreenSharing => _isScreenSharing;
  String? get screenProducerId => _screenProducer?.id;

  final Map<String, dynamic> _producers = {};
  final Map<String, Consumer> _consumers = {};
  final Map<String, RTCVideoRenderer> _remoteRenderers = {};

  bool _isRendererInitialized = false;
  bool _isCameraInitialized = false;
  final Set<String> _activeConsumers = {};

  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  // Local preview of OUR OWN shared screen. Kept separate from [localRenderer]
  // (the camera) so the sharer sees both their camera tile AND a screen tile.
  final RTCVideoRenderer screenRenderer = RTCVideoRenderer();
  bool _isScreenRendererInitialized = false;
  final SocketService socketService;

  Function(String consumerId, RTCVideoRenderer renderer)? onRemoteConsumerReady;
  Function(String consumerId)? onRemoteConsumerClosed;
  Function(String consumerId)? onRmoteConsumerScreenClosed;
  Function(String id, Consumer consumer)? onConsumerReady;

  MediasoupService(this.socketService);

  MediaStream? get localStream => _localStream;
  Transport? get sendTransport => _sendTransport;
  Transport? get recvTransport => _recvTransport;
  Map<String, Consumer> get consumers => _consumers;
  Map<String, RTCVideoRenderer> get remoteRenderers => _remoteRenderers;
  RtpCapabilities get deviceRtpCapabilities => _device!.rtpCapabilities;
  final Completer<void> _sendTransportReadyCompleter = Completer();
  bool get isDisposed => _isDisposed;

  Future<void> waitForSendTransportReady() async {
    if (_sendTransportReadyCompleter.isCompleted) return;

    return _sendTransportReadyCompleter.future.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        throw Exception("⏰ Transport connection timeout");
      },
    );
  }

  void _onRemoteConsumerScreenClosed(
    String consumerId,
    RTCVideoRenderer screenRenderer,
  ) {
    if (screenRenderer.srcObject != null &&
        screenRenderer.srcObject!.getVideoTracks().isEmpty) {
      screenRenderer.srcObject = null;
      screenRenderer.dispose();
    }
  }

  Future<void> init(RtpCapabilities routerRtpCapabilities) async {
    _device = Device();
    await _device!.load(routerRtpCapabilities: routerRtpCapabilities);
    logD(
      "✅ Device loaded. Can produce video: ${_device!.canProduce(RTCRtpMediaType.RTCRtpMediaTypeVideo)}",
    );
  }

  Future<void> waitForRecvTransportReady() async {
    if (_recvTransportReadyCompleter.isCompleted) return;
    return _recvTransportReadyCompleter.future.timeout(
      const Duration(seconds: 5),
    );
  }

  Future<void> initLocalStream({bool xiaomiWorkaround = false}) async {
    // await _releaseLocalStream();

    try {
      final Map<String, dynamic> mediaConstraints = {
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
        },
        'video': {
          'mandatory': {
            'minWidth': '1280', // 480p is the sweet spot for Redmi K30
            'minHeight': '720',
            'minFrameRate':
                '30', // Lowering to 24fps feels cinematic and saves 20% CPU
          },
          'facingMode': 'user',
          'optional': [
            {'googHardwareAcceleration': false},
          ],
        },
      };

      _localStream = await navigator.mediaDevices.getUserMedia(
        mediaConstraints,
      );

      if (!_isRendererInitialized) {
        await localRenderer.initialize();
        _isRendererInitialized = true;
      }

      // ✅ RE-ATTACH RENDERER
      if (localRenderer.srcObject != null) {
        localRenderer.srcObject = null; // Reset
      }
      localRenderer.srcObject = _localStream;

      logD("✨ Camera stream attached to renderer!");

      localRenderer.srcObject = _localStream;
      _isCameraInitialized = true;
      logD("✨ Camera initialized~! 📷");
    } catch (e) {
      logD("❌ Camera init failed: $e");
      if (xiaomiWorkaround) {
        // Retry once without the Xiaomi-specific constraints.
        await initLocalStream(xiaomiWorkaround: false);
        return;
      }
      // No camera (e.g. NotFoundError on desktop/macOS) or video failed → fall
      // back to audio-only so the user can still join with mic. If even that
      // fails, join view/listen-only instead of killing the whole meeting.
      try {
        _localStream = await navigator.mediaDevices.getUserMedia({
          'audio': {
            'echoCancellation': true,
            'noiseSuppression': true,
            'autoGainControl': true,
          },
          'video': false,
        });
        if (!_isRendererInitialized) {
          await localRenderer.initialize();
          _isRendererInitialized = true;
        }
        localRenderer.srcObject = _localStream;
        _isCameraInitialized = false;
        logD("🎤 Joined audio-only (no camera).");
      } catch (e2) {
        logD("⚠️ No camera/mic available — joining view-only: $e2");
        _localStream = null;
        _isCameraInitialized = false;
      }
    }
  }

  Future<void> _releaseLocalStream() async {
    // 1. ALWAYS null the srcObject BEFORE disposing of the renderer
    if (_isRendererInitialized) {
      try {
        localRenderer.srcObject = null;
      } catch (e) {
        logD("Renderer already gone, skipping nullify.");
      }
    }

    if (_localStream != null) {
      for (var track in _localStream!.getTracks()) {
        await track.stop();
        logD("🛑 Track stopped: ${track.kind}");
      }
      _localStream = null;
    }
  }

  // Inside MediasoupService class

  // Future<void> createSendTransport(Map<String, dynamic> params) async {
  //   try {
  //     logD("🛠️ Internal call to createSendTransportFromMap...");
  //
  //     _sendTransport = _device!.createSendTransportFromMap(
  //       params,
  //       producerCallback: (producer) => logD("Producer callback fired"),
  //     );
  //
  //     logD("✅ Send Transport object created in memory.");
  //   } catch (e) {
  //     logD("❌ CRITICAL: Library failed to create transport: $e");
  //     rethrow;
  //   }
  // }
  Future<void> createSendTransport(Map<String, dynamic> params) async {
    logD("🛠️ Creating Send Transport internally...");

    // 1. CREATE IT ONCE

    _sendTransport = _device!.createSendTransportFromMap(
      params,
      producerCallback: (Producer producer) {
        final type = producer.appData['type'];
        logD("🎨 ProducerCallback fired! Kind: ${producer.kind}, type: $type");
        if (producer.kind == 'video') {
          if (type == 'screen') {
            // Keep the screen producer separate so it never overwrites the
            // camera producer reference (the old bug that made stop-share
            // close the wrong/whole pipeline).
            _screenProducer = producer;
            if (_screenProducerCompleter != null &&
                !_screenProducerCompleter!.isCompleted) {
              _screenProducerCompleter!.complete(producer);
            }
          } else {
            _videoProducer = producer;
          }
        } else {
          _audioProducer = producer;
        }
      },
      dataProducerCallback: (dtlsParameters, callback, errback) async {
        try {
          logD("📡 CONNECT TRIGGERED");

          await socketService.emitWithAck('mediasoup:connect-transport', {
            'transportId': _sendTransport!.id,
            'dtlsParameters': dtlsParameters.toMap(),
          });

          callback();
        } catch (e) {
          errback(e);
        }
      },
    );

    if (_sendTransport == null) throw "Send transport failed to create!";
    _sendTransportReadyCompleter.complete();
    _isSendTransportConnected = true;
    _sendTransport!.on('connect', (dynamic args) async {
      logD("📡 SEND CONNECT EVENT");

      try {
        Map data;
        Function? callback;
        Function? errback;

        if (args is List) {
          data = args[0];
          callback = args[1];
          errback = args[2];
        } else {
          data = args['dtlsParameters'] != null ? args : args['data'];
          callback = args['callback'];
          errback = args['errback'];
        }

        final dtls = data['dtlsParameters'];

        await socketService.emitWithAck('mediasoup:connect-transport', {
          'transportId': _sendTransport!.id,
          'dtlsParameters': dtls.toMap(),
        });

        logD("✅ DTLS connected");

        callback!.call();
      } catch (e) {
        logD("❌ CONNECT ERROR: $e");
      }
    });

    _sendTransport!.on('connectionstatechange', (state) {
      logD('Send Transport State: $state');

      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        if (!_sendTransportReadyCompleter.isCompleted) {
          _sendTransportReadyCompleter.complete();
        }
        _isSendTransportConnected = true;
      }

      if (state == 'failed' || state == 'closed') {
        if (!_sendTransportReadyCompleter.isCompleted) {
          _sendTransportReadyCompleter.completeError("Transport failed");
        }
      }
    });

    // 3. ATTACH THE PRODUCE LISTENER
    _sendTransport!.on('produce', (dynamic args) async {
      try {
        Map data = (args is List) ? args[0] : args;
        Function? callback = (args is List) ? args[1] : args['callback'];

        logD("🛰️ [PRODUCE] Sending to backend via manual Ack...");
        logD(data);

        // Use manual emit with an acknowledgment function
        socketService.emitWithAck(
          'mediasoup:produce',
          {
            'transportId': _sendTransport!.id,
            'kind': data['kind'],
            'rtpParameters': data['rtpParameters'].toMap(),
            'appData': data['appData'],
          },
          ack: (response) {
            if (response != null && response['id'] != null) {
              if (callback != null) {
                // ✅ FIXED: Pass the ID directly as a String!
                // The library's internal Transport._produce expects a String.
                callback(response['id'].toString());

                logD("✅ [PRODUCE] Handshake fully complete!");
              }
            }
          },
        );
      } catch (e) {
        logD("❌ [PRODUCE] Crash in listener: $e");
      }
    });

    logD("✅ Listeners attached to Send Transport: ${_sendTransport!.id}");
  }

  Future<void> requestKeyframe(String consumerId, String roomId) async {
    try {
      logD("🔑 Requesting keyframe for consumer: $consumerId");
      await socketService.emitWithAck('mediasoup:consumer-request-keyframe', {
        'consumerId': consumerId,
        'roomId': roomId,
      });
    } catch (e) {
      logD("❌ Failed to request keyframe: $e");
    }
  }

  Future<void> createRecvTransport(Map<String, dynamic> params) async {
    try {
      _recvTransport = _device!.createRecvTransportFromMap(
        params,
        consumerCallback: (dynamic consumer, [dynamic accept]) async {
          // 1. Acknowledge immediately to complete the internal library handshake
          accept?.call({});

          final String consumerId = consumer.id;
          _consumers[consumerId] = consumer;

          logD("🎬 Consumer Callback: $consumerId, Kind: ${consumer.kind}");

          if (consumer.kind == 'video') {
            // If the track is already there, handle it
            if (consumer.track != null) {
              await _handleIncomingTrack(consumer);
            } else {
              // If track is null, wait for it
              consumer.on('track', (track) async {
                logD("🚀 Late track arrival for $consumerId");
                await _handleIncomingTrack(consumer);
              });
            }
          }
          if (consumer.kind == 'audio') {
            // For audio, we don't need a renderer, but we MUST attach it to a stream
            // to trigger the WebRTC audio playback engine.
            final stream = await createLocalMediaStream(
              'remote-audio-${consumer.id}',
            );
            stream.addTrack(consumer.track!);

            // IMPORTANT: On some platforms, you need a dummy renderer or
            // an Audio element to actually hear the sound.
            logD("🔊 Audio track attached for consumer: ${consumer.id}");
          }
        },
      );

      _recvTransport!.on('connectionstatechange', (state) {
        logD('Recv Transport State: $state');
        if (state == 'connected' || state == 'completed') {
          if (!_recvTransportReadyCompleter.isCompleted) {
            _recvTransportReadyCompleter.complete();
          }
        }
      });
      _recvTransport!.on('connect', (dynamic args) async {
        final data = (args is List) ? args[0] as Map : args as Map;
        final Function callback = data['callback'];
        final dynamic dtlsParameters = data['dtlsParameters'];

        try {
          await socketService.emitWithAck('mediasoup:connect-transport', {
            'transportId': _recvTransport!.id,
            'dtlsParameters': dtlsParameters.toMap(),
          });
          callback();
          _isRecvTransportConnected = true;
        } catch (error) {
          data['errback'](error);
        }
      });

      // Listen for 'track' events - this is where consumers arrive
      _recvTransport!.on('track', (dynamic args) async {
        logD("🔔 Transport 'track' event fired!");

        // Extract consumer from args
        Consumer? consumer;

        if (args is List && args.isNotEmpty) {
          // Sometimes it's [consumer, ...]
          if (args[0] is Consumer) {
            consumer = args[0] as Consumer;
          }
        } else if (args is Consumer) {
          consumer = args;
        } else if (args is Map && args['consumer'] != null) {
          consumer = args['consumer'] as Consumer?;
        }

        if (consumer == null) {
          logD("❌ Could not extract consumer from track event");
          logD("📦 Args type: ${args.runtimeType}");
          logD("📦 Args: $args");
          return;
        }

        final String consumerId = consumer.id;
        logD(
          "🎬 New consumer from track event: $consumerId, kind: ${consumer.kind}",
        );

        // Store the consumer
        _consumers[consumerId] = consumer;

        // Handle the incoming track
        if (consumer.kind == 'video' && consumer.track != null) {
          consumer.track!.enabled = true;
          await _handleIncomingTrack(consumer);
        } else {
          // For audio or when track arrives later
          logD(
            "⚠️ Consumer ${consumer.id} has kind ${consumer.kind} or no track yet",
          );

          // FIX: Create a local non-nullable reference
          final Consumer capturedConsumer = consumer;

          // Listen for track to arrive later
          capturedConsumer.on('track', (track) async {
            logD("🚀 Late track arrival for $consumerId");
            if (capturedConsumer.kind == 'video') {
              await _handleIncomingTrack(capturedConsumer);
            }
          });
        }
      });

      // Also listen for 'consumer' event as backup
      _recvTransport!.on('consumer', (dynamic args) async {
        logD("🔔 'consumer' event fired (legacy)");

        Consumer? consumer;
        if (args is List && args.isNotEmpty && args[0] is Consumer) {
          consumer = args[0] as Consumer;
        } else if (args is Consumer) {
          consumer = args;
        }

        if (consumer != null) {
          _consumers[consumer.id] = consumer;
          if (consumer.kind == 'video' && consumer.track != null) {
            await _handleIncomingTrack(consumer);
          }
        }
      });
      logD("✅ Recv Transport created, waiting for signaling...");
    } catch (e) {
      logD("❌ Recv Transport creation failed: $e");
      rethrow;
    }
  }

  // Future<void> consumeRemoteProducer(String producerId, String userId, String kind) async {
  //   try {
  //     logD("🎬 Requesting to consume producer: $producerId");
  //
  //     // 1. Tell server to create a server-side consumer
  //     final response = await socketService.socket.emitWithAck('mediasoup:consume', {
  //       'producerId': producerId,
  //       'rtpCapabilities': _device!.rtpCapabilities.toMap(),
  //     });
  //
  //     // 2. Response will contain parameters needed by your local RecvTransport
  //     // response = { id, producerId, kind, rtpParameters, appData }
  //
  //      _recvTransport!.consume(
  //       id: response['id'],
  //       producerId: response['producerId'],
  //        peerId: consumer.peerId,
  //       kind: RTCRtpMediaTypeExtension.fromString(response['kind']),
  //       rtpParameters: RtpParameters.fromMap(response['rtpParameters']),
  //       appData: response['appData'],
  //     );
  //
  //     logD("✅ Local consume call finished for $producerId");
  //   } catch (e) {
  //     logD("❌ Error consuming remote producer: $e");
  //   }
  // }

  // Future<void> produceVideo(String userId) async {
  //   if (_sendTransport == null || _localStream == null) return;
  //
  //   // Create a new completer for this specific call
  //   _videoProductionCompleter = Completer<Producer>();
  //
  //   final track = _localStream!.getVideoTracks().first;
  //
  //   try {
  //     await Future.delayed(const Duration(milliseconds: 100));
  //
  //     logD("🚀 Calling library produce (void)...");
  //     _sendTransport!.produce(
  //       track: track,
  //       stream: _localStream!,
  //       source: 'webcam',
  //       // encodings: [
  //       //   RtpEncodingParameters(rid: 'r0', maxBitrate: 1500000),
  //       // ],
  //       codecOptions: ProducerCodecOptions(videoGoogleStartBitrate: 1000),
  //       appData: {'userId': userId, 'type': "camera"},
  //     );
  //     logD("✅ Video Production finalized.");
  //   } catch (e) {
  //     logD("❌ Produce video failed: $e");
  //     rethrow;
  //   }
  // }
  //
  // Future<void> produceAudio() async {
  //   if (_isDisposed || _sendTransport == null) return;
  //   if (_localStream == null) return;
  //   if (_sendTransport == null) {
  //     logD("No send Transport Object Rejecting");
  //     return; // or handle the error
  //   }
  //   if (!_isSendTransportConnected || _sendTransport!.closed) {
  //     logD("⛔ Transport not ready for audio");
  //     return;
  //   }
  //
  //   final audioTracks = _localStream!.getAudioTracks();
  //   if (audioTracks.isEmpty) {
  //     logD("⚠️ No audio tracks found!");
  //     return;
  //   }
  //
  //   final track = audioTracks.first;
  //
  //   // Use .enabled and check if the track is not null
  //   if (!track.enabled) {
  //     logD("⚠️ Audio track is disabled, enabling now...");
  //     track.enabled = true;
  //   }
  //
  //   try {
  //     logD("🎤 Producing Audio with track ID: ${track.id}");
  //     _sendTransport!.produce(
  //       track: track,
  //       stream: _localStream!,
  //       source: 'microphone',
  //       // Adding explicit appData helps the UnifiedPlan handler map the transceiver
  //       appData: {'userId': socketService.userId},
  //     );
  //   } catch (e) {
  //     logD("❌ Audio production error: $e");
  //   }
  // }
  MediaStreamTrack? _localVideoTrack;
  MediaStreamTrack? get localVideoTrack => _localVideoTrack;

  MediaStreamTrack? _localAudioTrack;
  MediaStreamTrack? get localAudioTrack => _localAudioTrack;

  // ─────────────────────────────────────────────
  // PRODUCE VIDEO
  // ─────────────────────────────────────────────
  Future<void> produceVideo(String userId) async {
    if (_sendTransport == null || _localStream == null) {
      logD("⛔ Cannot produce video: Transport or LocalStream is null");
      return;
    }

    final videoTracks = _localStream!.getVideoTracks();
    if (videoTracks.isEmpty) {
      logD("⚠️ No video tracks found in local stream!");
      return;
    }

    // Save reference to track directly instead of the void production call
    _localVideoTrack = videoTracks.first;

    if (!_localVideoTrack!.enabled) {
      logD("🎥 Video track was disabled, turning on hardware interface...");
      _localVideoTrack!.enabled = true;
    }

    try {
      await Future.delayed(const Duration(milliseconds: 100));

      logD("🚀 Calling library produce for Video...");

      // ✅ FIX: Do not assign this call to a variable! It returns void.
      _sendTransport!.produce(
        track: _localVideoTrack!,
        stream: _localStream!,
        source: 'webcam',
        codecOptions: ProducerCodecOptions(videoGoogleStartBitrate: 1000),
        appData: {'userId': userId, 'type': "camera"},
      );

      logD("✅ Video Production finalized.");
    } catch (e) {
      logD("❌ Produce video failed: $e");
      rethrow;
    }
  }

  // ─────────────────────────────────────────────
  // PRODUCE AUDIO
  // ─────────────────────────────────────────────
  Future<void> produceAudio() async {
    if (_isDisposed || _sendTransport == null || _localStream == null) {
      logD("⛔ Cannot produce audio: Service state invalid");
      return;
    }

    final audioTracks = _localStream!.getAudioTracks();
    if (audioTracks.isEmpty) {
      logD("⚠️ No audio tracks found!");
      return;
    }

    _localAudioTrack = audioTracks.first;

    if (!_localAudioTrack!.enabled) {
      _localAudioTrack!.enabled = true;
    }

    try {
      logD("🎤 Producing Audio with track ID: ${_localAudioTrack!.id}");

      // ✅ FIX: Do not assign this call to a variable! It returns void.
      _sendTransport!.produce(
        track: _localAudioTrack!,
        stream: _localStream!,
        source: 'microphone',
        appData: {'userId': socketService.userId, 'type': 'audio'},
      );

      logD("✅ Audio Production finalized.");
    } catch (e) {
      logD("❌ Audio production error: $e");
    }
  }

  Future<void> switchCamera() async {
    if (!_isCameraInitialized) return;
    try {
      final videoTrack = _localStream?.getVideoTracks().firstOrNull;
      if (videoTrack != null) {
        await videoTrack.switchCamera();
        logD("✨ Camera switched~! 🔄");
      }
    } catch (e) {
      logD("❌ Camera switch failed: $e");
      await initLocalStream(xiaomiWorkaround: true);
    }
  }

  Future<String> _getRecordingPath(String prefix) async {
    final directory = Platform.isLinux || Platform.isWindows || Platform.isMacOS
        ? await getApplicationDocumentsDirectory()
        : await getExternalStorageDirectory(); // Android
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${directory?.path ?? '/tmp'}/$prefix-$timestamp.mp4';
  }

  // 🎀 Start recording - PLATFORM-AWARE VERSION
  Future<void> startLocalRecording() async {
    // ✅ Safety checks first, nya!
    if (_localStream == null) {
      throw Exception("No local stream available for recording~!");
    }
    if (_isRecording) {
      logD("⚠️ Already recording, nya~!");
      return;
    }

    // ❌ iOS check - recording not supported!
    if (Platform.isIOS) {
      throw Exception(
        "🍎 Recording not supported on iOS with flutter_webrtc. Use ffmpeg_kit_flutter instead, nya~!",
      );
    }

    try {
      _recordingPath = await _getRecordingPath('local');
      _localRecorder = MediaRecorder();

      final videoTrack = _localStream!.getVideoTracks().firstOrNull;

      if (videoTrack == null) {
        throw Exception("No video track found~! 😿");
      }

      // 🎀 Platform-specific start() call
      if (Platform.isAndroid) {
        await _localRecorder!.start(
          _recordingPath!,
          videoTrack: videoTrack,
          audioChannel: RecorderAudioChannel.INPUT, // 🎤 Android audio source
          rotationDegrees: 0,
        );
      } else {
        // Linux/Windows/macOS - simpler call, nya!
        await _localRecorder!.start(
          _recordingPath!,
          videoTrack: videoTrack,
          rotationDegrees: 0,
        );
      }

      _isRecording = true;
      logD("🎬 Recording started: $_recordingPath ✨");
    } catch (e) {
      logD("❌ Recording failed: $e");
      _localRecorder = null;
      _recordingPath = null;
      rethrow;
    }
  }

  // ⏹️ Stop recording - Simple and safe, nya~!
  Future<String?> stopLocalRecording() async {
    if (!_isRecording || _localRecorder == null) {
      logD("⚠️ Not recording, nya~!");
      return null;
    }

    try {
      await _localRecorder!.stop(); // ✅ Only method available!
      _isRecording = false;

      logD("✅ Recording saved: $_recordingPath 🎀");
      return _recordingPath;
    } catch (e) {
      logD("❌ Stop recording failed: $e");
      return null;
    } finally {
      _localRecorder = null;
      // Keep _recordingPath so UI can show it, nya~
    }
  }

  Future<void> startScreenShare(userId) async {
    if (WebRTC.platformIsDesktop) {
      List<DesktopCapturerSource> sources = [];
      try {
        sources = await desktopCapturer.getSources(
          types: [SourceType.Screen, SourceType.Window],
        );
      } catch (e) {
        if (Platform.isLinux) {
          throw Exception(
            'Screen sharing requires an X11 session on Linux. '
            'Wayland screen capture is not yet supported by the WebRTC backend.',
          );
        }
        rethrow;
      }

      if (sources.isEmpty) {
        throw Exception(
          Platform.isLinux
              ? 'No screen sources found. If you are on Wayland, screen sharing '
                'requires an X11 or XWayland session.'
              : 'No screen sources found',
        );
      }

      final source = sources.first;
      final bool includeAudio = !Platform.isLinux;

      try {
        screenStream = await navigator.mediaDevices.getDisplayMedia({
          'video': {
            'deviceId': {'exact': source.id},
            'mandatory': {'frameRate': 30.0, 'minFrameRate': 15.0},
          },
          'audio': includeAudio
              ? {'mandatory': {'echoCancellation': true}}
              : false,
        });
      } catch (e) {
        if (Platform.isLinux) {
          throw Exception(
            'Screen capture failed. If you are on Wayland, screen sharing '
            'requires an X11 or XWayland session. Error: $e',
          );
        }
        rethrow;
      }
    }
    // 🎀 Android: Handle MediaProjection permission + foreground service first
    else if (WebRTC.platformIsAndroid) {
      // Step 1 — ask the user to consent to screen capture (this caches the
      // MediaProjection token inside flutter_webrtc).
      final granted = await Helper.requestCapturePermission();
      if (!granted) throw Exception('Screen capture permission denied');

      // Step 2 — Android 14+ REQUIRES a running foreground service of type
      // `mediaProjection` before MediaProjection.start() (which getDisplayMedia
      // calls internally). flutter_webrtc does NOT start one itself, so without
      // this the native plugin throws:
      //   SecurityException: Media projections require a foreground service of
      //   type ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION
      // flutter_background's IsolateHolderService — declared in AndroidManifest
      // with foregroundServiceType="mediaProjection" — provides exactly that.
      await _startScreenShareService();

      await Future.delayed(const Duration(milliseconds: 300));

      // Step 3 — start the capture. On failure, tear the service back down so
      // we don't leave a dangling foreground notification.
      try {
        screenStream = await navigator.mediaDevices.getDisplayMedia({
          'video': {
            'mandatory': {'frameRate': 30.0},
          },
          'audio': {
            'mandatory': {'echoCancellation': true},
          },
        });
      } catch (e) {
        await _stopScreenShareService();
        rethrow;
      }
    }
    // 🎀 iOS: Not supported for screen capture with audio (yet!)
    else if (WebRTC.platformIsIOS) {
      throw Exception('Screen sharing not supported on iOS in this config');
    }
    // 🎀 macOS (non-desktop path fallback) & others
    else {
      // For macOS sandboxed apps, you might need to check permissions
      if (WebRTC.platformIsMacOS) {
        final hasPermission = await Helper.requestCapturePermission();
        if (!hasPermission)
          throw Exception('macOS Screen Recording permission denied');
      }

      screenStream = await navigator.mediaDevices.getDisplayMedia({
        'video': {
          'mandatory': {'frameRate': 30.0},
        },
        'audio': {
          'mandatory': {'echoCancellation': true},
        },
      });
    }

    if (screenStream == null) return;

    final screenTrack = screenStream!.getVideoTracks().first;

    // ⚖️ Produce the screen as its OWN dedicated producer (source 'screen',
    // appData type 'screen') — the camera producer keeps running untouched. This
    // is what lets every peer render TWO tiles for us: our camera AND our screen.
    // (The old code did replaceTrack() on the camera sender, which made the
    // screen REPLACE the camera everywhere — one view, not two.)
    if (_sendTransport == null) {
      for (final t in screenStream!.getTracks()) {
        try {
          t.stop();
        } catch (_) {}
      }
      try {
        await screenStream!.dispose();
      } catch (_) {}
      screenStream = null;
      throw Exception('Cannot share screen: no send transport.');
    }

    _screenProducerCompleter = Completer<Producer>();
    // produce() returns void; the producerCallback (set in createSendTransport)
    // routes type=='screen' into _screenProducer + completes the completer.
    _sendTransport!.produce(
      track: screenTrack,
      stream: screenStream!,
      source: 'screen',
      codecOptions: ProducerCodecOptions(videoGoogleStartBitrate: 1000),
      appData: {'userId': userId, 'type': 'screen'},
    );
    _isScreenSharing = true;

    // Local preview of our OWN screen in a separate renderer (the camera stays
    // in localRenderer), so the sharer also sees camera + screen as two tiles.
    if (!_isScreenRendererInitialized) {
      await screenRenderer.initialize();
      _isScreenRendererInitialized = true;
    }
    screenRenderer.srcObject = screenStream;

    // 🎀 If the OS-level share is stopped (system "Stop sharing" button), the
    // track ends → tear our screen producer down.
    screenTrack.onEnded = () {
      stopScreenShare();
    };
  }

  // Closes ONLY the screen producer + the ephemeral screen-capture stream and
  // tells the server so peers drop the screen tile. The camera producer and
  // _localStream are never touched. (producerId arg kept for backwards-compatible
  // call sites; unused — we use the tracked _screenProducer.)
  Future<void> stopScreenShare([String? producerId]) async {
    if (!_isScreenSharing && screenStream == null && _screenProducer == null) {
      return;
    }
    try {
      // 1. Tell the server to close the server-side screen producer so peers get
      //    'mediasoup:screenshare:stopped' and remove our screen tile.
      final sp = _screenProducer;
      if (sp != null) {
        try {
          await socketService.emitWithAck('mediasoup:screen:stop', {
            'roomId': socketService.currentRoomId,
            'producerId': sp.id,
          });
        } catch (_) {}
        try {
          sp.close();
        } catch (_) {}
      }
      _screenProducer = null;
      _screenProducerCompleter = null;

      // 2. Detach the local screen preview.
      try {
        screenRenderer.srcObject = null;
      } catch (_) {}

      // 3. Stop + dispose ONLY the screen-capture stream — the camera in
      //    _localStream is untouched.
      final stream = screenStream;
      if (stream != null) {
        for (final track in stream.getTracks()) {
          try {
            track.stop();
          } catch (_) {}
        }
        try {
          await stream.dispose();
        } catch (_) {}
      }
      screenStream = null;

      // Tear down the mediaProjection foreground service we started in
      // startScreenShare so its notification doesn't linger after we stop.
      await _stopScreenShareService();
    } catch (e) {
      logD("Stop screen share error: $e");
    } finally {
      _isScreenSharing = false;
    }
  }

  // ── Android screen-share foreground service ───────────────────────────────
  // Android 14+ won't let MediaProjection start unless a foreground service of
  // type `mediaProjection` is already running. We piggyback on flutter_background
  // (its IsolateHolderService is declared with that type in the manifest).

  Future<void> _startScreenShareService() async {
    if (!WebRTC.platformIsAndroid) return;
    try {
      if (FlutterBackground.isBackgroundExecutionEnabled) return;
      const config = FlutterBackgroundAndroidConfig(
        notificationTitle: 'Screen sharing',
        notificationText: 'HtooChoon is sharing your screen',
        notificationImportance: AndroidNotificationImportance.normal,
        notificationIcon:
            AndroidResource(name: 'launcher_icon', defType: 'mipmap'),
        // Keep it minimal — we only need the mediaProjection FGS, not wifi/
        // battery features (which would require extra permissions).
        enableWifiLock: false,
        shouldRequestBatteryOptimizationsOff: false,
      );
      final ok = await FlutterBackground.initialize(androidConfig: config);
      if (ok) {
        await FlutterBackground.enableBackgroundExecution();
      }
    } catch (e) {
      // Don't hard-fail the share on service hiccups — surface and continue;
      // getDisplayMedia will throw a clearer error if the FGS truly is required.
      logD('⚠️ Screen-share foreground service start failed: $e');
    }
  }

  Future<void> _stopScreenShareService() async {
    if (!WebRTC.platformIsAndroid) return;
    try {
      if (FlutterBackground.isBackgroundExecutionEnabled) {
        await FlutterBackground.disableBackgroundExecution();
      }
    } catch (e) {
      logD('⚠️ Screen-share foreground service stop failed: $e');
    }
  }

  // Mute/unmute = flip track.enabled (keeps the hardware/stream alive — never
  // stop()) AND mirror it on the mediasoup producer so its `paused` state stays
  // consistent. With this package's defaults (zeroRtpOnPause=false) producer
  // pause/resume simply toggles track.enabled too, so it's safe and idempotent.
  void pauseVideoTrack() {
    _localStream?.getVideoTracks().firstOrNull?.enabled = false;
    try {
      _videoProducer?.pause();
    } catch (_) {}
  }

  void resumeVideoTrack() {
    _localStream?.getVideoTracks().firstOrNull?.enabled = true;
    try {
      _videoProducer?.resume();
    } catch (_) {}
  }

  void pauseAudioTrack() {
    _localStream?.getAudioTracks().firstOrNull?.enabled = false;
    try {
      _audioProducer?.pause();
    } catch (_) {}
  }

  void resumeAudioTrack() {
    _localStream?.getAudioTracks().firstOrNull?.enabled = true;
    try {
      _audioProducer?.resume();
    } catch (_) {}
  }

  Future<void> _handleIncomingTrack(Consumer consumer) async {
    if (consumer.kind == 'video' && consumer.track != null) {
      if (_remoteRenderers.containsKey(consumer.id)) return;

      try {
        final renderer = RTCVideoRenderer();
        await renderer.initialize();

        // Create a stream and add the track from the consumer
        final stream = await createLocalMediaStream('remote-${consumer.id}');
        stream.addTrack(consumer.track!);
        renderer.srcObject = stream;

        _remoteRenderers[consumer.id] = renderer;
        onRemoteConsumerReady?.call(consumer.id, renderer);

        // --- CRITICAL FIX: The Order Matters ---
        // 1. Tell backend to resume the consumer first
        await socketService.emitWithAck('mediasoup:resume-consumer', {
          'consumerId': consumer.id,
          'roomId': socketService.currentRoomId,
        });

        // 2. Wait slightly for the server to transition state
        await Future.delayed(const Duration(milliseconds: 300));

        // 3. NOW request the Keyframe (I-Frame)
        await requestKeyframe(consumer.id, socketService.currentRoomId ?? "");

        logD("✅ Video initialized: Resume -> Keyframe sequence complete.");
      } catch (e) {
        logD("❌ Error handling track: $e");
      }
    }
  }

  // void _handleRemoteVideo(dynamic consumer) async {
  //   try {
  //     final renderer = RTCVideoRenderer();
  //     await renderer.initialize();
  //
  //     // In mediasfu, the consumer object is a wrapper.
  //     // It should contain the 'stream' property.
  //     if (consumer.stream != null) {
  //       renderer.srcObject = consumer.stream;
  //
  //       // Fix the String? to String error here
  //       String pId = consumer.peerId ?? 'unknown_peer';
  //       onRemoteConsumerReady?.call(pId, renderer);
  //     } else {
  //       logD("⚠️ Consumer stream is null!");
  //     }
  //   } catch (e) {
  //     logD("❌ Error setting up remote video: $e");
  //   }
  // }

  Future<void> consume({
    required String id,
    required String producerId,
    required String peerId,
    required RTCRtpMediaType kind,
    required RtpParameters rtpParameters,
    required Map<String, dynamic> appData,
    required roomId,
  }) async {
    try {
      logD("🎬 Triggering consume for $peerId");

      // This call triggers the 'consumerCallback' defined during transport creation
      recvTransport!.consume(
        id: id,
        producerId: producerId,
        peerId: peerId,
        kind: kind,
        rtpParameters: rtpParameters,
        appData: appData,
        accept: (dynamic data) {
          logD("✅ Transport handshake accepted for $id");
        },
      );
      // requestKeyframe(id, roomId);
    } catch (e) {
      logD("❌ Mediasoup Consumption Error: $e");
    }
  }

  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;

    logD("🧹 Starting Mediasoup cleanup...");

    try {
      // =========================
      // CLOSE PRODUCERS FIRST
      // =========================

      try {
        _videoProducer?.close();
        logD("✅ Video producer closed");
      } catch (e) {
        logD("⚠️ Video producer close failed: $e");
      }

      try {
        _audioProducer?.close();
        logD("✅ Audio producer closed");
      } catch (e) {
        logD("⚠️ Audio producer close failed: $e");
      }

      try {
        _screenProducer?.close();
        logD("✅ Screen producer closed");
      } catch (e) {
        logD("⚠️ Screen producer close failed: $e");
      }

      _videoProducer = null;
      _audioProducer = null;
      _screenProducer = null;

      // Give UnifiedPlan time to finish stopSending queue
      await Future.delayed(const Duration(milliseconds: 300));

      // =========================
      // DETACH RENDERERS
      // =========================

      for (final renderer in _remoteRenderers.values) {
        try {
          renderer.srcObject = null;
        } catch (_) {}
      }

      try {
        localRenderer.srcObject = null;
      } catch (_) {}

      try {
        screenRenderer.srcObject = null;
        screenStream?.getTracks().forEach((t) => t.stop());
        screenStream = null;
      } catch (_) {}

      // =========================
      // STOP LOCAL TRACKS
      // =========================

      if (_localStream != null) {
        for (final track in _localStream!.getTracks()) {
          try {
            await track.stop();
            logD("🛑 Track stopped: ${track.kind}");
          } catch (e) {
            logD("⚠️ Track stop failed: $e");
          }
        }
      }

      // Small delay helps Android native cleanup
      await Future.delayed(const Duration(milliseconds: 200));

      // =========================
      // DISPOSE STREAM SAFELY
      // =========================

      if (_localStream != null) {
        try {
          _localStream = null;
        } catch (e) {
          logD("⚠️ Stream already disposed: $e");
        }

        _localStream = null;
      }

      // =========================
      // DISPOSE RENDERERS
      // =========================

      for (final renderer in _remoteRenderers.values) {
        try {
          renderer.srcObject = null;
        } catch (_) {}
      }

      _remoteRenderers.clear();

      try {
        // await localRenderer.dispose();
      } catch (_) {}

      // =========================
      // CLOSE TRANSPORTS LAST
      // =========================

      try {
        localRenderer.srcObject = null;

        _sendTransport?.close();
        logD("✅ Send transport closed");
      } catch (e) {
        logD("⚠️ Send transport close failed: $e");
      }

      try {
        _recvTransport?.close();
        logD("✅ Recv transport closed");
      } catch (e) {
        logD("⚠️ Recv transport close failed: $e");
      }

      _sendTransport = null;
      _recvTransport = null;

      logD("✨ Cleanup completed safely");
    } catch (e, s) {
      logD("❌ Dispose crash: $e");
      logD(s);
    }
  }
}
