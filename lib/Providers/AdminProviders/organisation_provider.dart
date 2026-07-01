import 'package:htoochoon_flutter/core/log/app_logger.dart';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:htoochoon_flutter/api/api_service.dart';
import 'package:htoochoon_flutter/core/userorgrole_manager.dart';
import 'package:htoochoon_flutter/models/api_models/enums.dart';
import 'package:htoochoon_flutter/models/api_models/subscription_model.dart';
import 'package:htoochoon_flutter/models/auth/auth_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../models/api_models/organization_model.dart';

enum OrgAction { none, switched, exited }

class OrganizationProvider extends ChangeNotifier {
  final ApiService _api;

  OrganizationResponse? _organisation;

  OrganizationResponse? get organisation => _organisation;
  OrganizationProvider(this._api);

  List<OrganizationResponse> _organisations = [];
  OrganizationResponse? _selected;

  List<OrganisationMember> _members = [];
  List<OrganisationMember> _students = [];
  List<OrganisationMember> _teachers = [];

  bool _isLoading = false;
  bool _isMutating = false;
  String? _error;
  UsageCheckResponse? _usageStats;
  UsageCheckResponse? get usageStats => _usageStats;
  String? _currentUserId;
  String? get currentUserId => _currentUserId;
  bool _justSwitched = false;
  Map<String, User> userCache = {};
  OrgAction _lastAction = OrgAction.none;
  bool get justSwitched => _justSwitched;

  OrgAction get lastAction => _lastAction;
  void _setError(String? e) {
    _error = e;
    notifyListeners();
  }

  Future<List<User>> getUsers(String search) async {
    _error = null;
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _api.getUsers(search.toLowerCase());

      return response;
    } catch (e) {
      _error = e.toString();

      return [];
    } finally {
      _error = null;
      _isLoading = false;
      notifyListeners();
    }
  }

  Role getRoleForOrganization(String orgId) {
    final role = UserSessionManager.orgRole(orgId);

    logD("ORG ROLE CHECK FOR: $orgId");
    logD("ROLE FOUND = $role");

    return role;
  }

  Future<void> preloadMembers(List<OrganisationMember> members) async {
    final users = await Future.wait(members.map((m) => _api.getUser(m.userId)));

    for (int i = 0; i < members.length; i++) {
      userCache[members[i].userId] = users[i];
    }

    notifyListeners();
  }

  void setSelected(OrganizationResponse org) {
    _selected = org;
    _error = null;
    notifyListeners();
  }

  Future<void> selectOrganisation(String id) async {
    _error = null;
    _isLoading = true;
    _justSwitched = false;
    _lastAction = OrgAction.none;

    try {
      _selected = await _api.getOrganization(id);
      logD("selected ${_selected!.id.toString()}");
      // ✅ Load members
      await fetchMembers(id, currentOrgRole);

      // ✅ Mark switch success
      _justSwitched = true;

      _lastAction = OrgAction.switched;
      logD("done selecting org");
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> leaveOrganisation() async {
    _selected = null;
    _members = [];

    _justSwitched = false;
    _lastAction = OrgAction.exited;

    notifyListeners();
  }

  void clearSwitchFlag() {
    _justSwitched = false;
    notifyListeners();
  }

  // organisation role not yet fetching
  // to bind with subscription and let the user get into admin screens
  // // to fetch courses, programs
  Role getOrgRole(String orgId) {
    return UserSessionManager.orgRole(orgId);
  }

  Role get currentOrgRole {
    if (_selected == null) return Role.STUDENT;
    return UserSessionManager.orgRole(_selected!.id);
  }

  // ── GETTERS ─────────────────────────────────────
  List<OrganizationResponse> get organisations => _organisations;
  OrganizationResponse? get selected => _selected;
  bool get isLoading => _isLoading;
  bool get isMutating => _isMutating;
  String? get error => _error;
  List<OrganisationMember> get members => _members;
  List<OrganisationMember> get students => _students;
  List<OrganisationMember> get teachers => _teachers;
  Future<void> initUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString("user_id");

    if (userId != null) {
      _currentUserId = userId;
    }

    notifyListeners();
  }

  // ── LOAD ORGANISATIONS ──────────────────────────
  Future<void> loadOrganisations() async {
    logD("🔥 loadOrganisations CALLED");

    _isLoading = true;
    _error = null;
    notifyListeners();

    await initUser();

    logD("USER ID: $_currentUserId");

    try {
      logD("Im trying my best.. ");
      // The first call right after login can race the auth token and come back
      // 401 (it succeeds on a manual reload). Retry transient failures a few
      // times before surfacing an error the user is told to report.
      _organisations = await _fetchOrganisationsWithRetry();
      final userId = _currentUserId;
      if (userId != null) {
        final ownedIds = _organisations
            .where((o) => o.ownerId == userId)
            .map((o) => o.id)
            .toList();
        UserSessionManager.setOwnedOrgs(ownedIds);
      }
      logD("org length ${_organisations.length}");

      if (_selected == null && _organisations.isNotEmpty) {
        _selected = _organisations.first;
        await fetchMembers(_selected!.id, null);
      }
    } catch (e) {
      _error = "from load org ${e.toString()}";
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Calls `getOrganizations` with up to 3 attempts, retrying only on transient
  /// failures (401/403 token race, timeouts, connection drops) with a short
  /// backoff. This avoids flashing an error the user has to report when a simple
  /// reload would have fixed it. Non-transient errors throw immediately.
  Future<List<OrganizationResponse>> _fetchOrganisationsWithRetry() async {
    const maxAttempts = 3;
    Object? lastError;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        return await _api.getOrganizations();
      } catch (e) {
        lastError = e;
        if (attempt == maxAttempts || !_isTransient(e)) rethrow;
        logD("load org attempt $attempt failed (transient), retrying: $e");
        await Future.delayed(Duration(milliseconds: 400 * attempt));
      }
    }
    // Unreachable (loop either returns or rethrows), but keeps the analyzer happy.
    throw lastError ?? Exception('Failed to load organisations');
  }

  bool _isTransient(Object e) {
    if (e is DioException) {
      final code = e.response?.statusCode;
      if (code == 401 || code == 403 || code == 408 || code == 429 ||
          (code != null && code >= 500)) {
        return true;
      }
      switch (e.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.connectionError:
          return true;
        default:
          return false;
      }
    }
    return false;
  }

  // // ── SELECT ORGANISATION ─────────────────────────
  // Future<void> selectOrganisation(String id) async {
  //   _isLoading = true;
  //   notifyListeners();
  //
  //   try {
  //     _selected = await _api.getOrganization(id);
  //
  //     // ✅ Load members when switching org
  //     await fetchMembers(id);
  //   } catch (e) {
  //     _error = e.toString();
  //   } finally {
  //     _isLoading = false;
  //     notifyListeners();
  //   }
  // }
  Future<User?> getMemberInfo(String userId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final userInfo = await _api.getUser(userId);
      return userInfo;
    } catch (e) {
      _error = e.toString();
      logD("❌ getMemberInfo error: $e");
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── FETCH MEMBERS (IMPORTANT) ───────────────────
  Future<void> fetchMembers(String organisationId, Role? filter_role) async {
    _error = null;
    _isLoading = true;
    notifyListeners();

    try {
      _members = await _api.getMembers(organisationId, null, null);

      logD(
        "fetched members from org provider members count: ${members.length}",
      );
    } catch (e) {
      _error = e.toString();
      logD(e);
      _members = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  //Search Students
  Future<void> searchStudent(String organisationId, String search) async {
    _error = null;
    _isLoading = true;
    notifyListeners();
    logD("OrgID : ${organisationId}");
    try {
      _students = await _api.getMembers(organisationId, "STUDENT", search);

      logD(
        "fetched members from org provider members count: ${members.length}",
      );
    } catch (e) {
      _error = e.toString();
      logD(e);
      _students = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Search Teachers (IMPORTANT) ───────────────────
  Future<void> searchTeachers(String organisationId, String search) async {
    _error = null;
    _isLoading = true;
    notifyListeners();
    logD("OrgID : ${organisationId}");
    try {
      _teachers = await _api.getMembers(organisationId, "TEACHER", search);

      logD(
        "fetched members from org provider members count: ${members.length}",
      );
    } catch (e) {
      _error = e.toString();
      logD(e);
      _teachers = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  bool _isUploadingLogo = false;
  bool get isUploadingLogo => _isUploadingLogo;

  Future<bool> uploadLogo(String organizationId, File imageFile) async {
    try {
      _isUploadingLogo = true;
      notifyListeners();

      final fileName = imageFile.path.split('/').last;
      final fileBytes = await imageFile.readAsBytes();

      final multipartFile = MultipartFile.fromBytes(
        fileBytes,
        filename: fileName,
      );
      await _api.uploadOrganizationLogo(organizationId, multipartFile);

      await fetchOrganisation(organizationId);

      return true;
    } catch (e) {
      debugPrint("❌ Error uploading logo to backend: $e");
      return false;
    } finally {
      _isUploadingLogo = false;
      notifyListeners();
    }
  }

  Future<bool> removeMember(String orgId, String userId) async {
    _isLoading = true;
    notifyListeners();

    _setError(null);

    try {
      await _api.removeMember(orgId, userId);

      _members.removeWhere((m) => m.userId == userId);

      // if self removed -> remove org locally
      if (_currentUserId == userId) {
        _organisations.removeWhere((o) => o.id == orgId);

        if (_selected?.id == orgId) {
          _selected = _organisations.isNotEmpty ? _organisations.first : null;
        }
      }

      notifyListeners();

      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> userLeaveOrganisation(String orgId) async {
    _isLoading = true;
    notifyListeners();

    _setError(null);

    try {
      await _api.userLeaveOrg(orgId);

      _organisations.removeWhere((o) => o.id == orgId);

      // fix selected org
      if (selected?.id == orgId) {
        _selected = _organisations.isNotEmpty ? _organisations.first : null;
      }

      notifyListeners();

      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── CREATE ──────────────────────────────────────
  Future<OrganizationResponse?> createOrganisation(
    OrganizationRequest request,
    String ownerEmail,
  ) async {
    _isMutating = true;
    _error = null;
    notifyListeners();

    try {
      final created = await _api.createOrganisation(request);
      _organisations = [..._organisations, created];
      _selected ??= created;

      // ✅ Load members for new org
      await fetchMembers(created.id, null);

      return created;
    } on DioException catch (e) {
      throw Exception(e.response?.toString() ?? e.message);
    } finally {
      _isMutating = false;
      notifyListeners();
    }
  }

  // ── fetch org ──────────────────────────────────────────
  Future<void> fetchOrganisation(String id) async {
    _isLoading = true;
    notifyListeners();
    _setError(null);
    try {
      _organisation = await _api.getOrganization(id);
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateOrganisation(
    String id,
    OrganizationRequest request,
  ) async {
    _isLoading = true;
    notifyListeners();
    _setError(null);
    try {
      _organisation = await _api.updateOrganization(id, request);
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // // ── DELETE ──────────────────────────────────────
  // Future<bool> deleteOrganisation(String id) async {
  //   _isMutating = true;
  //   _error = null;
  //   notifyListeners();
  //
  //   try {
  //     await _api.deleteOrganization(id);
  //
  //     _organisations = _organisations.where((o) => o.id != id).toList();
  //
  //     if (_selected?.id == id) {
  //       _selected = _organisations.isNotEmpty ? _organisations.first : null;
  //
  //       if (_selected != null) {
  //         await fetchMembers(_selected!.id);
  //       }
  //     }
  //
  //     return true;
  //   } catch (e) {
  //     _error = e.toString();
  //     return false;
  //   } finally {
  //     _isMutating = false;
  //     notifyListeners();
  //   }
  // }

  // ── DELETE ──────────────────────────────────────
  Future<bool> deleteOrganisation(String id) async {
    _isMutating = true;
    _error = null;
    notifyListeners();

    try {
      await _api.deleteOrganization(id);

      _organisations = _organisations.where((o) => o.id != id).toList();

      if (_selected?.id == id) {
        _selected = _organisations.isNotEmpty ? _organisations.first : null;

        if (_selected != null) {
          await fetchMembers(_selected!.id, null);
        }
      }

      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isMutating = false;
      notifyListeners();
    }
  }

  // ── ADD MEMBER ──────────────────────────────────
  Future<void> addMember(
    String organisationId,
    OrganisationMemberRequest request,
  ) async {
    _isMutating = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final access_token = prefs.getString("access_token");
      logD(access_token);
      await _api.addMember(organisationId, request);

      // ✅ Refresh members after adding
      await fetchMembers(organisationId, null);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isMutating = false;
      notifyListeners();
    }
  }

  Future<void> checkResourceLimit(String orgId, String resourceType) async {
    _isLoading = true;
    _setError(null);
    try {
      _usageStats = await _api.checkResourceLimit(orgId, {
        'resourceType': resourceType,
      });

      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _isLoading = false;
    }
  }

  // ── CLEAR ERROR ─────────────────────────────────
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
