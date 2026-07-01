// Program chat models — hand-written (no codegen). Mirror the backend
// ChatService.shape() payload exactly.

class ChatSender {
  final String? id;
  final String name;
  final String? avatar;

  ChatSender({this.id, required this.name, this.avatar});

  factory ChatSender.fromJson(Map<String, dynamic> json) => ChatSender(
        id: json['id'] as String?,
        name: (json['name'] ?? 'Unknown') as String,
        avatar: json['avatar'] as String?,
      );
}

class ChatReplyTo {
  final String id;
  final String? senderId;
  final String content;

  ChatReplyTo({required this.id, this.senderId, required this.content});

  factory ChatReplyTo.fromJson(Map<String, dynamic> json) => ChatReplyTo(
        id: json['id'] as String,
        senderId: json['senderId'] as String?,
        content: (json['content'] ?? '') as String,
      );
}

class ChatMessage {
  final String id;
  final String senderId;
  final ChatSender? sender;
  final String type; // TEXT | SYSTEM | FILE | IMAGE | VOICE
  final String content;
  final String? attachmentUrl;
  // { name, size, mime, durationMs?, width?, height? } for FILE/IMAGE/VOICE.
  final Map<String, dynamic>? attachmentMeta;
  final ChatReplyTo? replyTo;
  final bool isDeleted;
  final DateTime? editedAt;
  final DateTime? createdAt;

  // Client-only: set on optimistic sends so the socket echo can reconcile.
  final String? tempId;
  final bool pending;

  ChatMessage({
    required this.id,
    required this.senderId,
    this.sender,
    this.type = 'TEXT',
    this.content = '',
    this.attachmentUrl,
    this.attachmentMeta,
    this.replyTo,
    this.isDeleted = false,
    this.editedAt,
    this.createdAt,
    this.tempId,
    this.pending = false,
  });

  bool get isEdited => editedAt != null && !isDeleted;

  bool get isImage => type == 'IMAGE';
  bool get isVoice => type == 'VOICE';
  bool get isFile => type == 'FILE';
  bool get isAttachment => isImage || isVoice || isFile;

  String? get attachmentName => attachmentMeta?['name'] as String?;
  int? get attachmentSize => (attachmentMeta?['size'] as num?)?.toInt();
  int? get attachmentDurationMs => (attachmentMeta?['durationMs'] as num?)?.toInt();
  double? get attachmentWidth => (attachmentMeta?['width'] as num?)?.toDouble();
  double? get attachmentHeight => (attachmentMeta?['height'] as num?)?.toDouble();

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String,
        senderId: (json['senderId'] ?? '') as String,
        sender: json['sender'] != null
            ? ChatSender.fromJson(json['sender'] as Map<String, dynamic>)
            : null,
        type: (json['type'] ?? 'TEXT') as String,
        content: (json['content'] ?? '') as String,
        attachmentUrl: json['attachmentUrl'] as String?,
        attachmentMeta: json['attachmentMeta'] != null
            ? (json['attachmentMeta'] as Map).cast<String, dynamic>()
            : null,
        replyTo: json['replyTo'] != null
            ? ChatReplyTo.fromJson(json['replyTo'] as Map<String, dynamic>)
            : null,
        isDeleted: (json['isDeleted'] ?? false) as bool,
        editedAt: json['editedAt'] != null
            ? DateTime.tryParse(json['editedAt'].toString())
            : null,
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'].toString())
            : null,
      );

  ChatMessage copyWith({
    String? id,
    String? content,
    bool? isDeleted,
    DateTime? editedAt,
    bool? pending,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      senderId: senderId,
      sender: sender,
      type: type,
      content: content ?? this.content,
      attachmentUrl: attachmentUrl,
      attachmentMeta: attachmentMeta,
      replyTo: replyTo,
      isDeleted: isDeleted ?? this.isDeleted,
      editedAt: editedAt ?? this.editedAt,
      createdAt: createdAt,
      tempId: tempId,
      pending: pending ?? this.pending,
    );
  }
}
