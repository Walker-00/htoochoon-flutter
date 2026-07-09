import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:htoochoon_flutter/core/token_manager.dart';
import 'package:htoochoon_flutter/core/case_convert.dart';

/// Dedicated socket to the rust backend's feature namespaces (/chat, /whiteboard),
/// served at the `/rtsocket` engine.io path. The video/SFU socket stays on the
/// nest `/socket.io/` connection (SocketService) — this is separate so chat and
/// whiteboard can connect/disconnect independently and their data lands in the
/// rust DB (matching the REST reads).
///
/// rust authenticates the handshake from the `?token=` query (not the auth
/// payload), so the JWT is passed via setQuery.
class RustSocket {
  RustSocket(this.namespace, {this.host = 'https://backend.htoochoon.com'});

  final String namespace; // e.g. '/chat', '/whiteboard'
  final String host;
  IO.Socket? _socket;

  IO.Socket? get raw => _socket;
  bool get isConnected => _socket?.connected == true;

  Future<bool> connect() async {
    if (_socket?.connected == true) return true;
    final token = await TokenManager().getToken();

    _socket?.dispose();
    _socket = IO.io(
      '$host$namespace',
      IO.OptionBuilder()
          .setPath('/rtsocket') // nginx: /rtsocket -> rust :3001/socket.io
          .setTransports(['websocket'])
          .setQuery({'token': token ?? ''})
          .setAuth({'token': token ?? ''}) // belt-and-suspenders
          .enableForceNew()
          .build(),
    );

    final done = Completer<bool>();
    _socket!.onConnect((_) {
      if (!done.isCompleted) done.complete(true);
    });
    _socket!.onConnectError((_) {
      if (!done.isCompleted) done.complete(false);
    });
    _socket!.connect();
    return done.future.timeout(const Duration(seconds: 8), onTimeout: () => false);
  }

  // Socket payloads bypass the Dio interceptor, so bridge casing here too:
  // outgoing camelCase -> snake_case, incoming snake_case -> camelCase.
  void emit(String event, dynamic data) => _socket?.emit(event, keysToSnake(data));

  /// Emit + await the server ack. The ack payload is camelized, passed to the
  /// optional [ack] callback, and also completes the returned future. Throws on
  /// timeout.
  Future<dynamic> emitWithAck(
    String event,
    dynamic data, {
    Duration timeout = const Duration(seconds: 8),
    Function? ack,
  }) {
    final c = Completer<dynamic>();
    final s = _socket;
    if (s == null) return Future.error(StateError('socket not connected'));
    s.emitWithAck(event, keysToSnake(data), ack: (d) {
      final camel = keysToCamel(d);
      if (ack != null) ack(camel);
      if (!c.isCompleted) c.complete(camel);
    });
    return c.future.timeout(timeout,
        onTimeout: () => throw TimeoutException('ack timeout for $event'));
  }

  void on(String event, void Function(dynamic) cb) =>
      _socket?.on(event, (data) => cb(keysToCamel(data)));

  // Handler arg accepted for call-site compatibility; removes all listeners for
  // the event (our on() wraps callbacks, so identity-based removal wouldn't match).
  void off(String event, [Function? _]) => _socket?.off(event);

  void disconnect() {
    _socket?.offAny();
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }
}
