import 'package:htoochoon_flutter/core/log/app_logger.dart';
import 'package:htoochoon_flutter/models/api_models/enums.dart';
import 'package:htoochoon_flutter/models/auth/auth_model.dart';

class UserSessionManager {
  static User? _user;

  static User? get user => _user;

  static void setUser(User user) {
    _user = user;
  }

  static String? get userId => _user?.id;

  static Role get globalRole => _user?.role ?? Role.USER;

  // Add this — call it once after login alongside setUser()
  static List<String> _ownedOrgIds = [];

  static void setOwnedOrgs(List<String> orgIds) {
    _ownedOrgIds = orgIds;
  }

  static void clear() {
    _user = null;
    _ownedOrgIds = [];
  }

  static Role orgRole(String orgId) {
    logD("ORG ROLE CHECK FOR: $orgId");

    logD("_ownedOrgIds = $_ownedOrgIds");

    logD("memberships = ${_user?.memberships}");

    final membership = _user?.memberships?.firstWhere(
      (m) => m.organization.id == orgId,
      orElse: () {
        logD("NO MEMBERSHIP MATCH FOUND");
        return Membership(
          role: Role.STUDENT,
          organization: Organization(id: '', name: ''),
        );
      },
    );

    logD("FOUND ROLE = ${membership?.role}");

    if (_ownedOrgIds.contains(orgId)) {
      logD("MATCHED OWNER");
      return Role.ORG_ADMIN;
    }
    for (final m in _user?.memberships ?? []) {
      logD("MEMBERSHIP orgId = ${m.organization.id}, role = ${m.role}");
    }
    logD("LOOKING FOR orgId = $orgId");

    return membership?.role ?? Role.STUDENT;
  }

  /// True if the user owns or holds any membership row in [orgId]. Unlike
  /// [orgRole] (which defaults non-members to STUDENT), this actually
  /// distinguishes a member from a total outsider.
  static bool isMemberOf(String orgId) {
    if (_ownedOrgIds.contains(orgId)) return true;
    for (final m in _user?.memberships ?? const []) {
      if (m.organization.id == orgId) return true;
    }
    return false;
  }

  /// True if the user runs [orgId] (owner / admin / teacher / staff) and so
  /// must NOT be able to self-enrol as a student in its programs.
  static bool isOrgStaff(String orgId) {
    if (_ownedOrgIds.contains(orgId)) return true;
    final r = orgRole(orgId);
    return r == Role.ORG_ADMIN || r == Role.TEACHER || r == Role.STAFF;
  }

  /// True if the user is an ORG_ADMIN of (or owns) any organization. Used to
  /// gate admin-only actions client-side — the backend is the real authority.
  static bool get isAnyOrgAdmin {
    if (_ownedOrgIds.isNotEmpty) return true;
    for (final m in _user?.memberships ?? const []) {
      if (m.role == Role.ORG_ADMIN) return true;
    }
    return false;
  }

  // static Role orgRole(String orgId) {
  //   // ✅ 1. Owner check — highest priority
  //   if (_ownedOrgIds.contains(orgId)) return Role.ORG_ADMIN;
  //
  //   // ✅ 2. Fall back to membership role
  //   final membership = _user?.memberships?.firstWhere(
  //     (m) => m.organization.id == orgId,
  //     orElse: () => Membership(
  //       role: Role.STUDENT,
  //       organization: Organization(id: '', name: ''),
  //     ),
  //   );
  //   return membership?.role ?? Role.STUDENT;
  // }
}
