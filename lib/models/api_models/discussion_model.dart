/// Codegen-free models for per-assignment Q&A discussions + DM (backend
/// `discussions` / `discussion_messages` / `direct_messages`).

class Discussion {
  final String id;
  final String title;
  final String? body;
  final bool isPrivate;
  final DateTime? solvedAt;
  final DateTime createdAt;
  final String authorId;
  final String? authorName;
  final String? authorAvatar;
  final int replyCount;

  Discussion({
    required this.id,
    required this.title,
    this.body,
    required this.isPrivate,
    this.solvedAt,
    required this.createdAt,
    required this.authorId,
    this.authorName,
    this.authorAvatar,
    this.replyCount = 0,
  });

  bool get isSolved => solvedAt != null;

  factory Discussion.fromJson(Map<String, dynamic> j) => Discussion(
        id: '${j['id']}',
        title: (j['title'] as String?) ?? '',
        body: j['body'] as String?,
        isPrivate: (j['isPrivate'] as bool?) ?? false,
        solvedAt: DateTime.tryParse('${j['solvedAt']}'),
        createdAt: DateTime.tryParse('${j['createdAt']}') ?? DateTime.now(),
        authorId: '${j['authorId']}',
        authorName: j['authorName'] as String?,
        authorAvatar: j['authorAvatar'] as String?,
        replyCount: (j['replyCount'] as num?)?.toInt() ?? 0,
      );
}

class DiscussionMessage {
  final String id;
  final String? parentId;
  final String body;
  final bool isBestAnswer;
  final DateTime createdAt;
  final String authorId;
  final String? authorName;
  final String? authorAvatar;

  DiscussionMessage({
    required this.id,
    this.parentId,
    required this.body,
    required this.isBestAnswer,
    required this.createdAt,
    required this.authorId,
    this.authorName,
    this.authorAvatar,
  });

  factory DiscussionMessage.fromJson(Map<String, dynamic> j) => DiscussionMessage(
        id: '${j['id']}',
        parentId: j['parentId'] == null ? null : '${j['parentId']}',
        body: (j['body'] as String?) ?? '',
        isBestAnswer: (j['isBestAnswer'] as bool?) ?? false,
        createdAt: DateTime.tryParse('${j['createdAt']}') ?? DateTime.now(),
        authorId: '${j['authorId']}',
        authorName: j['authorName'] as String?,
        authorAvatar: j['authorAvatar'] as String?,
      );
}

class DiscussionThread {
  final Discussion discussion;
  final List<DiscussionMessage> messages;
  DiscussionThread({required this.discussion, required this.messages});

  factory DiscussionThread.fromJson(Map<String, dynamic> j) => DiscussionThread(
        discussion: Discussion.fromJson(j),
        messages: ((j['messages'] as List?) ?? [])
            .map((m) => DiscussionMessage.fromJson(Map<String, dynamic>.from(m)))
            .toList(),
      );
}

class DmConversation {
  final String peerId;
  final String? peerName;
  final String? peerAvatar;
  final String lastMessage;
  final DateTime lastAt;
  final int unread;

  DmConversation({
    required this.peerId,
    this.peerName,
    this.peerAvatar,
    required this.lastMessage,
    required this.lastAt,
    this.unread = 0,
  });

  factory DmConversation.fromJson(Map<String, dynamic> j) => DmConversation(
        peerId: '${j['peerId']}',
        peerName: j['peerName'] as String?,
        peerAvatar: j['peerAvatar'] as String?,
        lastMessage: (j['lastMessage'] as String?) ?? '',
        lastAt: DateTime.tryParse('${j['lastAt']}') ?? DateTime.now(),
        unread: (j['unread'] as num?)?.toInt() ?? 0,
      );
}

class DmMessage {
  final String id;
  final String senderId;
  final String receiverId;
  final String body;
  final bool isRead;
  final String? assignmentId;
  final DateTime createdAt;

  DmMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.body,
    required this.isRead,
    this.assignmentId,
    required this.createdAt,
  });

  factory DmMessage.fromJson(Map<String, dynamic> j) => DmMessage(
        id: '${j['id']}',
        senderId: '${j['senderId']}',
        receiverId: '${j['receiverId']}',
        body: (j['body'] as String?) ?? '',
        isRead: (j['isRead'] as bool?) ?? false,
        assignmentId: j['assignmentId'] == null ? null : '${j['assignmentId']}',
        createdAt: DateTime.tryParse('${j['createdAt']}') ?? DateTime.now(),
      );
}
