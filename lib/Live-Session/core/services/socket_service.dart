import 'package:htoochoon_flutter/core/log/app_logger.dart';
// lib/core/services/socket_service.dart

import 'package:htoochoon_flutter/core/token_manager.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'dart:developer' as developer;
import 'dart:async';

class SocketService {
  // ── Singleton ──────────────────────────────────────────────────────────
  // One shared socket for the whole app. Every `SocketService()` call (Provider
  // or direct) resolves to this instance, so we never open duplicate websockets
  // or stack duplicate listeners. Mirrors TokenManager's pattern.
  SocketService._internal();
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;

  IO.Socket? _socket;
  String? _userId;
  // The live transport state is read straight off `_socket.connected` (see the
  // `isConnected` getter). We deliberately don't cache it in a bool field —
  // that field used to drift stale and pin the chat "Reconnecting…" banner on.
  bool _isReconnecting = false;

  IO.Socket get socket {
    if (_socket == null) {
      developer.log(
        '⚠️ Socket accessed before connect() - auto-connecting!',
        name: 'SocketService',
      );
      connect();
    }
    return _socket!;
  }

  // Report the REAL engine state, not the manually-tracked `_isConnected` field.
  // Send/receive gate on `_socket.connected`, so the field can drift stale-false
  // (e.g. an `_isReconnecting` guard return, or socket.io's built-in auto-reconnect)
  // while the transport is genuinely up — which used to pin the chat
  // "Reconnecting…" banner on while messages flowed fine. The field is kept for
  // internal guards/logging; this getter is the single source of truth for callers.
  bool get isConnected => _socket?.connected == true;
  String? get userId => _userId;
  String? currentRoomId;

  Function()? onConnected;
  Function(String)? onConnectionError;
  Function()? onDisconnected;

  static const String _serverUrl = 'https://backend.htoochoon.com/';
  static const Duration _reconnectDelay = Duration(seconds: 2);

  // void connect({
  //   String? customUrl,
  //   String? accessToken,
  //   String? refreshToken,
  // }) async {
  //   // ✅ Prevent multiple simultaneous connections
  //   if (_isConnected && _socket?.connected == true) {
  //     developer.log('✅ Already connected, skipping~', name: 'SocketService');
  //     return;
  //   }
  //
  //   // ✅ Prevent reconnect loops
  //   if (_isReconnecting) {
  //     developer.log(
  //       '⏳ Reconnection in progress, skipping~',
  //       name: 'SocketService',
  //     );
  //     return;
  //   }
  //
  //   final url = customUrl ?? _serverUrl;
  //   final storage = const FlutterSecureStorage();
  //   String? token = accessToken ?? await storage.read(key: 'access_token');
  //   String? rToken = refreshToken ?? await storage.read(key: 'refresh_token');
  //
  //   // ✅ Clean up old socket BEFORE creating new one
  //   if (_socket != null) {
  //     _socket!.offAny();
  //     _socket!.disconnect();
  //     _socket!.dispose();
  //     _socket = null;
  //   }
  //
  //   _socket = IO.io(
  //     url,
  //     IO.OptionBuilder()
  //         .setTransports(['websocket'])
  //         .setAuth({'token': token, 'refreshToken': rToken})
  //         .enableForceNew()
  //         .build(),
  //   );
  //
  //   _setupSocketListeners(); // ✅ Extracted listener setup
  //   _socket!.connect();
  // }
  Future<bool> connect({
    String? customUrl,
    String? accessToken,
    String? refreshToken,
  }) async {
    // ✅ Already up — trust the REAL engine state.
    if (_socket?.connected == true) {
      developer.log('✅ Already connected, skipping~', name: 'SocketService');
      return true; // Already connected successfully
    }

    // ✅ A handshake is already in flight — don't stack a second one.
    // NOTE: this is an *in-flight* guard owned by connect() itself (set below
    // and ALWAYS cleared in the finally). Callers like initSocket() must NOT
    // pre-set `_isReconnecting`, or connect() would reject its own attempt and
    // the socket would never come up (this was the account-switch deadlock).
    if (_isReconnecting) {
      developer.log(
        '⏳ Reconnection in progress, skipping~',
        name: 'SocketService',
      );
      return false;
    }

    _isReconnecting = true;
    try {
      final url = customUrl ?? _serverUrl;
      // Tokens live in SharedPreferences via TokenManager — the SAME store the
      // REST Dio interceptor uses. The old code read FlutterSecureStorage here,
      // which is a different backend and always returned null, so the handshake
      // went out unauthenticated and the gateway disconnected the socket.
      final tokenManager = TokenManager();
      String? token = accessToken ?? await tokenManager.getToken();
      String? rToken = refreshToken ?? await tokenManager.getRefreshToken();

      // ✅ Clean up old socket BEFORE creating new one
      if (_socket != null) {
        _socket!.offAny();
        _socket!.disconnect();
        _socket!.dispose();
        _socket = null;
      }

      _socket = IO.io(
        url,
        IO.OptionBuilder()
            .setTransports(['websocket'])
            .setAuth({'token': token, 'refreshToken': rToken})
            .enableForceNew()
            .build(),
      );

      _setupSocketListeners(); // ✅ Extracted listener setup

      // Create the completer loop to monitor the connection event
      final completer = Completer<bool>();

      // Attach explicit single-use handlers onto the actual instance block
      _socket!.onConnect((_) {
        _isReconnecting = false;
        if (!completer.isCompleted) completer.complete(true);
      });

      _socket!.onConnectError((err) {
        developer.log('❌ Connection error: $err', name: 'SocketService');
        if (!completer.isCompleted) completer.complete(false);
      });

      // Fire the initial handshake command
      _socket!.connect();

      // Timeout fallback safeguard (5 seconds)
      Future.delayed(const Duration(seconds: 5), () {
        if (!completer.isCompleted) {
          developer.log(
            '⏰ Connection timeout limit reached',
            name: 'SocketService',
          );
          completer.complete(false);
        }
      });

      return await completer.future;
    } catch (e) {
      logD("Socket connection exception block: $e");
      return false;
    } finally {
      // Always release the in-flight guard so a later attempt can retry, even
      // if this handshake timed out (socket.io may still connect afterwards;
      // the onConnect listener and the chat watcher reconcile the banner).
      _isReconnecting = false;
    }
  }

  void _setupSocketListeners() {
    if (_socket == null) return;

    _socket!.onConnect((_) {
      developer.log('✨ Connected! ID: ${_socket!.id}', name: 'SocketService');
      _isReconnecting = false; // ✅ Reset reconnect flag
      _userId = _socket!.id;
      onConnected?.call();
    });

    // ✅ FIXED: Only register 'unauthorized' handler ONCE
    _socket!.on('unauthorized', (data) async {
      developer.log(
        '🚫 Socket Unauthorized! Data: $data',
        name: 'SocketService',
      );
      await _handleUnauthorized();
    });

    _socket!.onConnectError((data) => _handleError(data));
    _socket!.onDisconnect((_) {
      developer.log('💔 Disconnected', name: 'SocketService');
      _isReconnecting = false;
      onDisconnected?.call();
    });

    // ✅ FIXED: Register 'error:auth' ONCE here, NOT in emitWithAck!
    _socket!.on('error:auth', (_) async {
      developer.log(
        '🔐 Auth error received, will reconnect~',
        name: 'SocketService',
      );
      await _handleUnauthorized();
    });

    // ✅ Server rotated our access token (expired-but-refreshable path in the
    // gateway). Persist it so future REST calls and reconnects use the fresh one.
    _socket!.on('token:refreshed', (data) async {
      try {
        final newToken = (data is Map) ? data['token'] as String? : null;
        if (newToken != null && newToken.isNotEmpty) {
          await TokenManager().setToken(newToken);
          developer.log('🔑 Access token refreshed via socket',
              name: 'SocketService');
        }
      } catch (e) {
        developer.log('⚠️ token:refreshed handler error: $e',
            name: 'SocketService');
      }
    });
  }

  Future<void> _handleUnauthorized() async {
    if (_isReconnecting) return; // ✅ Prevent loop!
    _isReconnecting = true;

    try {
      // Token refresh is handled in two places already:
      //   1. the REST Dio interceptor (refreshes + writes to TokenManager), and
      //   2. the gateway server-side for expired-but-refreshable tokens, which
      //      emits 'token:refreshed' (persisted in _setupSocketListeners).
      // So here we just back off and reconnect — connect() re-reads the freshest
      // tokens from TokenManager.
      await Future.delayed(_reconnectDelay);
      await initSocket();
    } catch (e) {
      developer.log('❌ Reconnect failed: $e', name: 'SocketService');
      _isReconnecting = false;
      onConnectionError?.call('Reconnect failed: $e');
    }
  }

  void _handleError(dynamic data) {
    developer.log('❌ Connection error: $data', name: 'SocketService');
    onConnectionError?.call('$data');
  }

  Future<void> initSocket() async {
    developer.log('🔄 Re-initializing socket...', name: 'SocketService');

    // ✅ Tear down the old socket (e.g. the previous user's connection on an
    // account switch) so the next handshake authenticates as the current user.
    if (_socket != null) {
      _socket!.offAny();
      if (_socket!.connected) _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
    }
    // CRITICAL: clear the in-flight guard before reconnecting. connect() owns
    // and re-sets this flag itself; if we left it `true` here, connect() would
    // reject its own attempt and the socket would never come back up (the
    // "Connecting…" banner stuck on the 2nd logged-in account).
    _isReconnecting = false;

    // ✅ Reconnect — awaited so callers (login / 2FA / resume) know the outcome.
    await connect();
  }

  Future<dynamic> emitWithAck(
    String event,
    dynamic data, {
    Function(dynamic)? ack,
    Duration? timeout,
  }) async {
    // Gate on the REAL engine state — the `_isConnected` field can lag behind
    // the live transport and would otherwise force an unnecessary REST fallback.
    if (_socket?.connected != true) {
      throw Exception('Socket not connected. Call connect() first~ 💦');
    }

    final completer = Completer<dynamic>();

    try {
      developer.log('📡 Emitting with Ack: $event', name: 'SocketService');

      _socket!.emitWithAck(
        event,
        data,
        ack: (ackData) {
          // open in debugging
          // developer.log('📩 Received Ack for $event: $ackData', name: 'SocketService');
          if (ack != null) ack(ackData);
          if (!completer.isCompleted) {
            completer.complete(ackData);
          }
        },
      );
    } catch (e) {
      developer.log('❌ Emit failed: $e', name: 'SocketService');
      if (!completer.isCompleted) completer.completeError(e);
    }

    if (timeout != null) {
      return completer.future.timeout(
        timeout,
        onTimeout: () {
          if (!completer.isCompleted) {
            completer.completeError(
              TimeoutException('⏰ No ack received for "$event"'),
            );
          }
        },
      );
    }
    return completer.future;
  }

  void emit(String event, [dynamic data]) {
    if (_socket?.connected == true) {
      _socket!.emit(event, data);
    }
  }

  void on(String event, Function(dynamic) callback) {
    _socket?.on(event, callback);
  }

  void off(String event, [Function(dynamic)? callback]) {
    _socket?.off(event, callback);
  }

  void dispose() {
    if (_socket != null) {
      _socket!.offAny();
      if (_socket!.connected) _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
    }
    _isReconnecting = false;
    _userId = null;
    currentRoomId = null;
    // Drop stale callback hooks so a previous session's meeting/chat closures
    // don't fire against the next logged-in user.
    onConnected = null;
    onDisconnected = null;
    onConnectionError = null;
  }
}
