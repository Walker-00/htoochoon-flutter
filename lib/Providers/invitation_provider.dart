import 'dart:async';

import 'package:flutter/material.dart';
import 'package:htoochoon_flutter/models/api_models/enums.dart';
import '../api/api_service.dart';
import '../models/api_models/organization_model.dart';

class InvitationProvider extends ChangeNotifier {
  final ApiService _apiService;

  InvitationProvider(this._apiService);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _inviteIsLoading = false;
  bool get inviteIsLoading => _inviteIsLoading;

  String? _error;
  String? get error => _error;

  late TabController tabController;
  bool isDisposed = false;

  // Invitation data as raw maps for backward compatibility with existing UI
  List<Map<String, dynamic>> _invitations = [];
  List<Map<String, dynamic>> get invitations => _invitations;

  // Announcement data
  List<Map<String, dynamic>> _announcements = [];
  List<Map<String, dynamic>> get announcements => _announcements;

  List<OrganisationMember> _members = [];
  List<OrganisationMember> get members => _members;

  /// Initialize the provider (call from initState with vsync and email)
  void init({required TickerProvider vsync, required String email}) {
    tabController = TabController(length: 2, vsync: vsync);
    _loadInvitations(email);
    _loadAnnouncements();
  }

  /// Load invitations for a user email
  Future<void> _loadInvitations(String email) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      // Fetch from all organisations the user belongs to
      final orgs = await _apiService.getOrganizations();
      final allInvitations = <Map<String, dynamic>>[];

      for (final org in orgs) {
        final members = await _apiService.getMembers(org.id, null, null);
        // In a real backend, you'd have a dedicated invitations endpoint
        // For now, we use members as a placeholder
        // TODO: Replace with actual invitation API calls
      }

      _invitations = allInvitations;
    } catch (e) {
      _error = e.toString();
      debugPrint("Error loading invitations: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Load announcements
  Future<void> _loadAnnouncements() async {
    try {
      // TODO: Replace with actual announcement API calls
      _announcements = [];
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      debugPrint("Error loading announcements: $e");
    }
  }

  /// Fetch members for an organisation
  Future<void> fetchMembers(String organisationId, {String? role}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _members = await _apiService.getMembers(organisationId, role, null);
    } catch (e) {
      _error = e.toString();
      debugPrint("Error fetching members: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Add a member to an organisation
  Future<bool> addMember(
    String organisationId,
    OrganisationMemberRequest request,
  ) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _apiService.addMember(organisationId, request);
      return true;
    } catch (e) {
      _error = e.toString();
      debugPrint("Error adding member: $e");
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Accept an invitation
  Future<void> acceptInvitation({
    required String orgId,
    required String inviteId,
    required String userId,
    required String email,
  }) async {
    _inviteIsLoading = true;
    notifyListeners();
    try {
      // TODO: Replace with actual accept invitation API call
      // For now, simulate adding the member
      final request = OrganisationMemberRequest(userId: userId, role: 'member');
      await _apiService.addMember(orgId, request);

      // Remove from local invitations
      _invitations.removeWhere((inv) => inv['id'] == inviteId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      debugPrint("Error accepting invitation: $e");
      rethrow;
    } finally {
      _inviteIsLoading = false;
      notifyListeners();
    }
  }

  /// Reject an invitation
  Future<void> rejectInvitation({
    required String orgId,
    required String inviteId,
  }) async {
    _inviteIsLoading = true;
    notifyListeners();
    try {
      // TODO: Replace with actual reject invitation API call
      _invitations.removeWhere((inv) => inv['id'] == inviteId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      debugPrint("Error rejecting invitation: $e");
      rethrow;
    } finally {
      _inviteIsLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    isDisposed = true;
    tabController.dispose();
    super.dispose();
  }

  void safeChangeNotifier() {
    if (!isDisposed) {
      notifyListeners();
    }
  }
}
