import 'package:flutter/material.dart';
import 'package:htoochoon_flutter/api/api_service.dart';
import 'package:htoochoon_flutter/models/api_models/live_session_model.dart';
import 'package:htoochoon_flutter/models/api_models/subscription_model.dart';
import 'package:flutter/foundation.dart';

class DashboardProvider extends ChangeNotifier {
  final ApiService _api;

  DashboardProvider(this._api);

  SubscriptionPlan? _currentPlan;
  DashboardUsage? _usage;
  List<LiveSession> _upcomingSessions = [];
  bool _isLoading = false;
  String? _error;

  SubscriptionPlan? get currentPlan => _currentPlan;
  DashboardUsage? get usage => _usage;
  List<LiveSession> get upcomingSessions => _upcomingSessions;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadDashboard(String orgId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _api.fetchCurrentPlan(orgId),
        _api.fetchUsageDashboard(orgId),
        _api.getLiveSession(orgId),
      ]);

      _currentPlan = results[0] as SubscriptionPlan;
      _usage = results[1] as DashboardUsage;
      _upcomingSessions = results[2] as List<LiveSession>;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
