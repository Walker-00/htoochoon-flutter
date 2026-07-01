import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/userorgrole_manager.dart';
import '../models/api_models/chat_model.dart';
import '../Live-Session/core/services/socket_service.dart';

/// Drives a single active Program Chat room.
///
/// - History + room state: REST via the shared authenticated [Dio].
/// - Realtime send/receive/edit/delete: the shared [SocketService] socket
///   (namespace '/', the same JWT-authed connection the live meeting uses).
/// - Resilience: a lightweight connection watcher flips a "reconnecting" flag
///   and re-joins + refreshes when the socket comes back.
class ChatProvider extends ChangeNotifier {
  final Dio _dio;
  ChatProvider(this._dio);

  SocketService? _socket;
  String? _programId;

  // Messages are kept NEWEST-FIRST (index 0 = latest) to pair with a
  // reverse:true ListView (index 0 renders at the bottom).
  final List<ChatMessage> _messages = [];
  final Set<String> _ids = {};

  bool _isEnabled = true;
  bool _loading = false;
  bool _loadingMore = false;
  bool _hasMore = false;
  String? _nextCursor;
  String? _error;
  bool _connected = false;
  bool _uploading = false;
  final Set<String> _typingUserIds = {};

  // Members of this chat — for @mention autocomplete + highlighting.
  final List<ChatSender> _members = [];

  Timer? _connWatcher;

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isEnabled => _isEnabled;
  bool get loading => _loading;
  bool get loadingMore => _loadingMore;
  bool get hasMore => _hasMore;
  String? get error => _error;
  bool get connected => _connected;
  bool get reconnecting => !_connected;
  bool get uploading => _uploading;
  List<ChatSender> get members => List.unmodifiable(_members);
  Set<String> get typingUserIds => _typingUserIds;

  String? get myUserId => UserSessionManager.userId;

  // Lightweight per-program "is chat enabled" cache, used by dashboards to
  // decide whether to surface the chat entry point — without opening the room.
  final Map<String, bool> _enabledPeek = {};
  bool? peekedEnabled(String programId) => _enabledPeek[programId];

  Future<void> peekRoom(String programId) async {
    try {
      final res = await _dio.get('/programs/$programId/chat');
      _enabledPeek[programId] =
          ((res.data as Map)['isEnabled'] ?? false) as bool;
    } catch (_) {
      // 403 (no access) or any error → treat as unavailable for this user.
      _enabledPeek[programId] = false;
    }
    notifyListeners();
  }

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  Future<void> open(String programId, SocketService socket) async {
    _programId = programId;
    _socket = socket;
    _messages.clear();
    _ids.clear();
    _typingUserIds.clear();
    _nextCursor = null;
    _hasMore = false;
    _error = null;
    _loading = true;
    notifyListeners();

    // Make sure the shared socket is up (idempotent). Don't trust connect()'s
    // return code — it can be `false` purely because the socket was already up
    // or mid-reconnect. Reconcile to the real engine state afterward.
    try {
      await socket.connect();
    } catch (_) {/* ignore — reconcile below */}
    _connected = socket.isConnected;

    _attachListeners();
    _startConnWatcher();

    await _fetchInitial();
    await _fetchMembers();

    // Join the server-side room so we receive broadcasts.
    _joinRoom();

    _loading = false;
    notifyListeners();
  }

  Future<void> _fetchMembers() async {
    final pid = _programId;
    if (pid == null) return;
    try {
      final res = await _dio.get('/programs/$pid/chat/members');
      final list = (res.data as List? ?? [])
          .map((e) => ChatSender.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
      _members
        ..clear()
        ..addAll(list);
    } catch (e) {
      debugPrint('chat _fetchMembers: $e');
    }
  }

  void close() {
    _connWatcher?.cancel();
    _connWatcher = null;
    final pid = _programId;
    final s = _socket;
    if (s != null && pid != null) {
      try {
        s.emit('chat:leave', {'programId': pid});
      } catch (_) {}
    }
    _detachListeners();
    _programId = null;
    _socket = null;
    _messages.clear();
    _ids.clear();
    _typingUserIds.clear();
    _members.clear();
  }

  // ── REST: state + history ────────────────────────────────────────────────

  Future<void> _fetchInitial() async {
    final pid = _programId;
    if (pid == null) return;
    try {
      final res = await _dio.get('/programs/$pid/chat/messages',
          queryParameters: {'limit': 30});
      _ingestHistory(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      _error = _msg(e);
    } catch (e) {
      _error = 'Could not load messages';
      debugPrint('chat _fetchInitial: $e');
    }
  }

  Future<void> loadMore() async {
    final pid = _programId;
    if (pid == null || !_hasMore || _loadingMore || _nextCursor == null) return;
    _loadingMore = true;
    notifyListeners();
    try {
      final res = await _dio.get('/programs/$pid/chat/messages',
          queryParameters: {'limit': 30, 'cursor': _nextCursor});
      _ingestHistory(res.data as Map<String, dynamic>, append: true);
    } on DioException catch (e) {
      _error = _msg(e);
    } catch (e) {
      debugPrint('chat loadMore: $e');
    } finally {
      _loadingMore = false;
      notifyListeners();
    }
  }

  void _ingestHistory(Map<String, dynamic> data, {bool append = false}) {
    _isEnabled = (data['isEnabled'] ?? _isEnabled) as bool;
    _nextCursor = data['nextCursor'] as String?;
    _hasMore = _nextCursor != null;
    final list = (data['data'] as List? ?? [])
        .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .where((m) => !_ids.contains(m.id))
        .toList();
    for (final m in list) {
      _ids.add(m.id);
    }
    if (append) {
      // Older page → goes after the current tail (newest-first ordering).
      _messages.addAll(list);
    } else {
      _messages
        ..clear()
        ..addAll(list);
      _ids
        ..clear()
        ..addAll(list.map((m) => m.id));
    }
  }

  // ── Sending / editing / deleting ─────────────────────────────────────────

  Future<void> sendMessage(String text) async {
    final content = text.trim();
    if (content.isEmpty) return;
    await _sendCore(content: content, type: 'TEXT');
  }

  /// Upload a file then send it as an IMAGE / FILE / VOICE message.
  /// [kind] must be 'IMAGE', 'FILE', or 'VOICE'. [durationMs] is for voice clips.
  Future<void> sendAttachment({
    required String filePath,
    required String kind,
    String caption = '',
    int? durationMs,
  }) async {
    final pid = _programId;
    if (pid == null || _socket == null) return;
    _uploading = true;
    _error = null;
    notifyListeners();
    try {
      final form = FormData.fromMap({
        'kind': kind,
        'file': await MultipartFile.fromFile(
            filePath, filename: filePath.split(RegExp(r'[\\/]')).last),
      });
      final res = await _dio.post('/chat/upload', data: form);
      final data = (res.data as Map).cast<String, dynamic>();
      final meta = <String, dynamic>{
        'name': data['name'],
        'size': data['size'],
        'mime': data['mime'],
        if (data['width'] != null) 'width': data['width'],
        if (data['height'] != null) 'height': data['height'],
        if (durationMs != null) 'durationMs': durationMs,
      };
      await _sendCore(
        content: caption.trim(),
        type: (data['type'] as String?) ?? kind,
        attachmentUrl: data['url'] as String?,
        attachmentMeta: meta,
      );
    } on DioException catch (e) {
      _error = _msg(e);
    } catch (e) {
      _error = 'Upload failed';
      debugPrint('chat sendAttachment: $e');
    } finally {
      _uploading = false;
      notifyListeners();
    }
  }

  Future<void> _sendCore({
    required String content,
    required String type,
    String? attachmentUrl,
    Map<String, dynamic>? attachmentMeta,
  }) async {
    final pid = _programId;
    final s = _socket;
    if (pid == null || s == null) return;

    final tempId = 't-${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(9999)}';
    final optimistic = ChatMessage(
      id: tempId,
      tempId: tempId,
      senderId: myUserId ?? '',
      type: type,
      content: content,
      attachmentUrl: attachmentUrl,
      attachmentMeta: attachmentMeta,
      createdAt: DateTime.now(),
      pending: true,
    );
    _messages.insert(0, optimistic);
    _ids.add(tempId);
    notifyListeners();

    final payload = <String, dynamic>{
      'programId': pid,
      'content': content,
      'tempId': tempId,
      if (type != 'TEXT') 'type': type,
      if (attachmentUrl != null) 'attachmentUrl': attachmentUrl,
      if (attachmentMeta != null) 'attachmentMeta': attachmentMeta,
    };

    // Prefer the socket (realtime fan-out); fall back to REST when offline.
    if (s.isConnected) {
      try {
        await s.emitWithAck(
          'chat:send',
          payload,
          timeout: const Duration(seconds: 8),
          ack: (resp) {
            if (resp is Map && resp['error'] != null) {
              _failOptimistic(tempId, resp['error'].toString());
            } else if (resp is Map && resp['message'] != null) {
              _reconcile(
                ChatMessage.fromJson(
                    (resp['message'] as Map).cast<String, dynamic>()),
                tempId,
              );
            }
          },
        );
      } catch (e) {
        await _sendViaRest(pid, payload, tempId);
      }
    } else {
      await _sendViaRest(pid, payload, tempId);
    }
  }

  Future<void> _sendViaRest(
      String pid, Map<String, dynamic> payload, String tempId) async {
    try {
      final body = Map<String, dynamic>.from(payload)
        ..remove('programId')
        ..remove('tempId');
      final res =
          await _dio.post('/programs/$pid/chat/messages', data: body);
      _reconcile(
          ChatMessage.fromJson((res.data as Map).cast<String, dynamic>()), tempId);
    } on DioException catch (e) {
      _failOptimistic(tempId, _msg(e));
    } catch (e) {
      _failOptimistic(tempId, 'Failed to send');
    }
  }

  Future<void> editMessage(ChatMessage m, String content) async {
    final pid = _programId;
    final s = _socket;
    final body = content.trim();
    if (pid == null || body.isEmpty || m.id.startsWith('t-')) return;
    if (s != null && s.isConnected) {
      try {
        await s.emitWithAck('chat:edit',
            {'programId': pid, 'messageId': m.id, 'content': body},
            timeout: const Duration(seconds: 8));
        return;
      } catch (_) {/* fall through to REST */}
    }
    try {
      await _dio.patch('/chat/messages/${m.id}', data: {'content': body});
      _applyEdit(m.id, body, DateTime.now());
    } catch (e) {
      _error = 'Could not edit message';
      notifyListeners();
    }
  }

  Future<void> deleteMessage(ChatMessage m) async {
    final pid = _programId;
    final s = _socket;
    if (pid == null || m.id.startsWith('t-')) return;
    if (s != null && s.isConnected) {
      try {
        await s.emitWithAck(
            'chat:delete', {'programId': pid, 'messageId': m.id},
            timeout: const Duration(seconds: 8));
        return;
      } catch (_) {/* fall through to REST */}
    }
    try {
      await _dio.delete('/chat/messages/${m.id}');
      _applyDelete(m.id);
    } catch (e) {
      _error = 'Could not delete message';
      notifyListeners();
    }
  }

  void sendTyping(bool isTyping) {
    final pid = _programId;
    final s = _socket;
    if (pid == null || s == null || !s.isConnected) return;
    try {
      s.emit('chat:typing', {'programId': pid, 'isTyping': isTyping});
    } catch (_) {}
  }

  // ── Socket listeners ───────────────────────────────────────────────────────

  void _attachListeners() {
    final s = _socket;
    if (s == null) return;
    s.on('chat:new-message', _onNewMessage);
    s.on('chat:message-edited', _onEdited);
    s.on('chat:message-deleted', _onDeleted);
    s.on('chat:room-state', _onRoomState);
    s.on('chat:typing-update', _onTyping);
  }

  void _detachListeners() {
    final s = _socket;
    if (s == null) return;
    s.off('chat:new-message', _onNewMessage);
    s.off('chat:message-edited', _onEdited);
    s.off('chat:message-deleted', _onDeleted);
    s.off('chat:room-state', _onRoomState);
    s.off('chat:typing-update', _onTyping);
  }

  void _onNewMessage(dynamic data) {
    if (data is! Map) return;
    final raw = data['message'];
    if (raw is! Map) return;
    final msg = ChatMessage.fromJson(raw.cast<String, dynamic>());
    final tempId = data['tempId'] as String?;
    if (tempId != null && _ids.contains(tempId)) {
      _reconcile(msg, tempId);
      return;
    }
    if (_ids.contains(msg.id)) return; // already have it
    _ids.add(msg.id);
    _messages.insert(0, msg);
    notifyListeners();
  }

  void _onEdited(dynamic data) {
    if (data is! Map) return;
    final id = data['messageId'] as String?;
    final content = (data['content'] ?? '') as String;
    if (id == null) return;
    _applyEdit(id, content,
        DateTime.tryParse('${data['editedAt']}') ?? DateTime.now());
  }

  void _onDeleted(dynamic data) {
    if (data is! Map) return;
    final id = data['messageId'] as String?;
    if (id != null) _applyDelete(id);
  }

  void _onRoomState(dynamic data) {
    if (data is! Map) return;
    if (data['programId'] != _programId) return;
    _isEnabled = (data['isEnabled'] ?? _isEnabled) as bool;
    notifyListeners();
  }

  void _onTyping(dynamic data) {
    if (data is! Map) return;
    final uid = data['userId'] as String?;
    final typing = (data['isTyping'] ?? false) as bool;
    if (uid == null || uid == myUserId) return;
    if (typing) {
      _typingUserIds.add(uid);
    } else {
      _typingUserIds.remove(uid);
    }
    notifyListeners();
  }

  // ── Local mutations ─────────────────────────────────────────────────────────

  void _reconcile(ChatMessage real, String tempId) {
    final i = _messages.indexWhere((m) => m.id == tempId);
    _ids.remove(tempId);
    if (_ids.contains(real.id)) {
      // Server echo already added the real one → just drop the temp.
      if (i != -1) _messages.removeAt(i);
    } else {
      _ids.add(real.id);
      if (i != -1) {
        _messages[i] = real;
      } else {
        _messages.insert(0, real);
      }
    }
    notifyListeners();
  }

  void _failOptimistic(String tempId, String reason) {
    final i = _messages.indexWhere((m) => m.id == tempId);
    if (i != -1) {
      _messages.removeAt(i);
      _ids.remove(tempId);
    }
    _error = reason;
    notifyListeners();
  }

  void _applyEdit(String id, String content, DateTime editedAt) {
    final i = _messages.indexWhere((m) => m.id == id);
    if (i != -1) {
      _messages[i] = _messages[i].copyWith(content: content, editedAt: editedAt);
      notifyListeners();
    }
  }

  void _applyDelete(String id) {
    final i = _messages.indexWhere((m) => m.id == id);
    if (i != -1) {
      _messages[i] =
          _messages[i].copyWith(isDeleted: true, content: '');
      notifyListeners();
    }
  }

  // ── Connection resilience ────────────────────────────────────────────────

  void _joinRoom() {
    final pid = _programId;
    final s = _socket;
    if (pid == null || s == null || !s.isConnected) return;
    try {
      s.emit('chat:join', {'programId': pid});
    } catch (_) {}
  }

  void _startConnWatcher() {
    _connWatcher?.cancel();
    _connWatcher = Timer.periodic(const Duration(seconds: 2), (_) async {
      final s = _socket;
      if (s == null) return;
      final now = s.isConnected;
      if (now != _connected) {
        final wasDisconnected = !_connected;
        _connected = now;
        notifyListeners();
        if (now && wasDisconnected) {
          // Reconnected: SocketService.connect() rebuilds the underlying
          // IO.Socket, so our event handlers were bound to the *old* instance.
          // Re-bind them to the live socket, then re-join + pull what we missed.
          _detachListeners();
          _attachListeners();
          _joinRoom();
          await _refreshLatest();
        }
      }
      // Self-heal: the watcher must do more than observe. If the socket is down
      // (e.g. it never came up after an account switch, or the gateway dropped
      // it), actively (re)connect. SocketService.connect() is idempotent — a
      // no-op when already up — and rebuilds the socket with the FRESHEST token
      // from TokenManager, so a stale-auth drop can't wedge us in "Reconnecting…"
      // while messages silently fall back to REST.
      if (!now) {
        try {
          await s.connect();
        } catch (_) {/* next tick retries */}
      }
    });
  }

  /// Pull the newest page and merge any messages that arrived while offline.
  Future<void> _refreshLatest() async {
    final pid = _programId;
    if (pid == null) return;
    try {
      final res = await _dio
          .get('/programs/$pid/chat/messages', queryParameters: {'limit': 30});
      final data = res.data as Map<String, dynamic>;
      _isEnabled = (data['isEnabled'] ?? _isEnabled) as bool;
      final fresh = (data['data'] as List? ?? [])
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .where((m) => !_ids.contains(m.id))
          .toList();
      for (final m in fresh) {
        _ids.add(m.id);
        _messages.insert(0, m);
      }
      if (fresh.isNotEmpty) notifyListeners();
    } catch (e) {
      debugPrint('chat _refreshLatest: $e');
    }
  }

  String _msg(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      final m = data['message'];
      return m is List ? m.join(', ') : m.toString();
    }
    return e.message ?? 'Request failed';
  }

  @override
  void dispose() {
    _connWatcher?.cancel();
    _detachListeners();
    super.dispose();
  }
}
