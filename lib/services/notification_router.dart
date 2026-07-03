import 'package:flutter/material.dart';

import 'package:htoochoon_flutter/core/log/app_logger.dart';
import 'package:htoochoon_flutter/Notificaton/notification_center_screen.dart';
import 'package:htoochoon_flutter/Screens/AdminScreens/access_requests_screen.dart';
import 'package:htoochoon_flutter/Screens/Deatiled_Screens/course_chat_screen.dart';
import 'package:htoochoon_flutter/Screens/Deatiled_Screens/program_chat_screen.dart';
import 'package:htoochoon_flutter/Screens/Discussion/dm_thread_screen.dart';
import 'package:htoochoon_flutter/Screens/Discussion/discussion_thread_screen.dart';

/// Central dispatcher: turns a notification payload (FCM `data`, a local-notif
/// tap payload, or an in-app notification row) into a navigation.
///
/// Payload contract (all values may arrive as strings from FCM `data`):
/// ```json
/// { "type": "chat_mention", "screen": "chat",
///   "params": { "programId": "...", "programName": "..." } }
/// ```
/// `params` may also be flattened onto the top level (FCM `data` can't nest),
/// so both `data['params']['programId']` and `data['programId']` are accepted.
///
/// Unknown/[]missing types fall back to the Notification Center so a tap is
/// never a dead end.
class NotificationRouter {
  NotificationRouter._();
  static final NotificationRouter instance = NotificationRouter._();

  final _log = const AppLog('NotificationRouter');
  GlobalKey<NavigatorState>? _navKey;

  void attach(GlobalKey<NavigatorState> navKey) => _navKey = navKey;

  /// Route from any notification payload. Safe to call before the navigator is
  /// mounted — it defers to the next frame.
  void route(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _dispatch(data));
  }

  void _dispatch(Map<String, dynamic> data) {
    final nav = _navKey?.currentState;
    if (nav == null) {
      _log.w('navigator not ready, dropping notification route: $data');
      return;
    }

    // `type` may be a backend enum (NEW_MESSAGE, SESSION_LIVE …) OR a legacy
    // FCM literal (chat_mention, dm …). `scope` is the reliable router key the
    // backend now stamps on `data` (program | course | organization |
    // assessment). Route by scope + id keys first, fall back to type literals.
    final type = (data['type'] ?? data['screen'] ?? '').toString();
    final p = _params(data);
    final scope = _str(p, 'scope') ?? _str(data, 'scope');
    _log.i('routing notification type=$type scope=$scope');

    // 💬 Program chat — @mention, new message, enrollment confirmation.
    final programId = _str(p, 'programId');
    if (programId != null &&
        (scope == 'program' ||
            type == 'NEW_MESSAGE' ||
            type == 'chat_mention' ||
            type == 'chat' ||
            type == 'chat_message')) {
      nav.push(MaterialPageRoute(
        builder: (_) => ProgramChatScreen(
          programId: programId,
          programName: _str(p, 'programName') ?? 'Chat',
        ),
      ));
      return;
    }

    // ✉️ Direct message.
    final peerId = _str(p, 'peerId') ?? _str(p, 'senderId');
    if (peerId != null &&
        (scope == 'dm' || type == 'dm' || type == 'direct_message')) {
      nav.push(MaterialPageRoute(
        builder: (_) => DmThreadScreen(
          peerId: peerId,
          peerName: _str(p, 'peerName') ?? _str(p, 'senderName') ?? 'Message',
        ),
      ));
      return;
    }

    // 🧵 Discussion / Q&A.
    final discussionId = _str(p, 'discussionId');
    if (discussionId != null) {
      nav.push(MaterialPageRoute(
        builder: (_) => DiscussionThreadScreen(discussionId: discussionId),
      ));
      return;
    }

    // 📚 Course-scoped — materials publish, assessment/exam publish, exam-lock,
    // course-scope enrollment. None of the rich course/assessment screens can
    // be built from ids alone (they need name/orgId or full objects), so route
    // to the course chat/hub which only needs the courseId. This lands the user
    // in the right course context; the title fills in from the fetched chat.
    final courseId = _str(p, 'courseId');
    if (courseId != null) {
      nav.push(MaterialPageRoute(
        builder: (_) => CourseChatScreen(
          courseId: courseId,
          courseName: _str(p, 'courseName') ?? 'Course',
        ),
      ));
      return;
    }

    // 🏢 Organization-scoped — self-service access requests (approve/decline).
    // AccessRequestsScreen is the only org screen buildable from an id alone,
    // and it's the relevant target for access-request notifications.
    final organizationId =
        _str(p, 'organizationId') ?? _str(p, 'organisationId');
    if (organizationId != null &&
        (scope == 'organization' || _str(p, 'accessRequestId') != null)) {
      nav.push(MaterialPageRoute(
        builder: (_) => AccessRequestsScreen(organisationId: organizationId),
      ));
      return;
    }

    // Remaining scopes (live session, submission, assessment without a course)
    // land in the center until their target screens accept id-only
    // construction. Extend here as screens gain lightweight (id-based) ctors.
    nav.push(MaterialPageRoute(
      builder: (_) => const NotificationCenterScreen(),
    ));
  }

  /// Accept nested `params` or a flat payload.
  Map<String, dynamic> _params(Map<String, dynamic> data) {
    final raw = data['params'];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return data;
  }

  String? _str(Map<String, dynamic> m, String k) {
    final v = m[k];
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }
}
