import 'package:htoochoon_flutter/core/log/app_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:htoochoon_flutter/api/api_service.dart';
import 'package:htoochoon_flutter/models/api_models/subscription_model.dart';
import 'package:flutter/foundation.dart';

class SubscriptionProvider extends ChangeNotifier {
  final ApiService _api;

  SubscriptionProvider(this._api);

  // ── State ────────────────────────────────────────
  SubscriptionPlan? _currentPlan;
  DashboardUsage? _usage;
  List<PlanTier> _availablePlans = [];
  bool _isLoading = false;
  String? _error;

  // ── Getters ──────────────────────────────────────
  SubscriptionPlan? get currentPlan => _currentPlan;
  DashboardUsage? get usage => _usage;
  List<PlanTier> get availablePlans => _availablePlans;
  bool get isLoading => _isLoading;
  String? get error => _error;
  Future<T?> _safe<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } catch (e) {
      logD("❌ API error: $e");
      return null;
    }
  }

  // ── Load everything for an org ───────────────────
  Future<void> loadForOrg(String orgId) async {
    logD(orgId);
    _isLoading = true;
    _error = null;
    notifyListeners();

    logD("load orgs ran");

    try {
      final plan = await _safe(() => _api.fetchCurrentPlan(orgId));
      final usage = await _safe(() => _api.fetchUsageDashboard(orgId));
      final plans = await _safe(() => _api.fetchAvailablePlans(orgId));
      logD("plan ${plan}");
      logD("usage : ${usage}");
      logD("plans : ${plans}");
      _currentPlan = plan;
      _usage = usage;
      _availablePlans = plans ?? [];

      logD("fetched load orgs");
    } catch (e) {
      logD("Unexpected failure: $e");
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refreshPlan(String orgId) async {
    _isLoading = true;
    _error = null;
    try {
      _currentPlan = await _api.fetchCurrentPlan(orgId);
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> refreshUsage(String orgId) async {
    try {
      _usage = await _api.fetchUsageDashboard(orgId);
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  // ── Update plan ──────────────────────────────────
  Future<bool> updatePlan(String orgId, Map<String, dynamic> body) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _currentPlan = await _api.updatePlan(orgId, body);
      // Refresh usage after plan change
      await refreshUsage(orgId);
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Check a single resource limit via API ────────
  Future<UsageCheckResponse?> checkLimit(
    String orgId,
    String resourceType,
  ) async {
    try {
      return await _api.checkResourceLimit(orgId, {
        'resourceType': resourceType,
      });
    } catch (e) {
      return null;
    }
  }

  // ── Local limit helpers (no network, use cached plan) ──

  /// Whether the plan is still active (not expired / cancelled).
  bool get isPlanActive {
    if (_currentPlan == null) return false;
    return _currentPlan!.status.toLowerCase() == 'active';
  }

  /// Whether a feature is unlocked in the current plan.
  bool hasFeature(String feature) {
    if (_currentPlan == null) return false;
    switch (feature.toLowerCase()) {
      case 'analytics':
        return _currentPlan!.features.analytics;
      case 'livesessions':
      case 'live_sessions':
        return _currentPlan!.features.liveSessions;
      case 'customdomain':
      case 'custom_domain':
        return _currentPlan!.features.customDomain;
      // case 'sso':
      //   return _currentPlan!.features.sso;
      case 'prioritysupport':
      case 'priority_support':
        return _currentPlan!.features.prioritySupport;
      default:
        return false;
    }
  }

  // ── Per-resource can-create checks ───────────────

  LimitCheckResult canAddStudent() => _checkLimit(
    'Students',
    _currentPlan?.usage.currentStudents,
    _currentPlan?.limits.maxStudents,
  );

  LimitCheckResult canAddTeacher() => _checkLimit(
    'Teachers',
    _currentPlan?.usage.currentTeachers,
    _currentPlan?.limits.maxTeachers,
  );

  LimitCheckResult canCreateProgram() => _checkLimit(
    'Programs',
    _currentPlan?.usage.currentPrograms,
    _currentPlan?.limits.maxPrograms,
  );

  LimitCheckResult canCreateCourse() => _checkLimit(
    'Courses',
    _currentPlan?.usage.currentCourses,
    _currentPlan?.limits.maxCourses,
  );

  LimitCheckResult canCreateClass() => _checkLimit(
    'Classes',
    _currentPlan?.usage.currentClasses,
    _currentPlan?.limits.maxClasses,
  );

  LimitCheckResult canAddMember() {
    // Members = students + teachers combined
    if (_currentPlan == null) return LimitCheckResult.noPlan();
    final currentStudents = _currentPlan!.usage.currentStudents;
    final currentTeachers = _currentPlan!.usage.currentTeachers;
    final maxStudents = _currentPlan!.limits.maxStudents;
    final maxTeachers = _currentPlan!.limits.maxTeachers;
    // At least one slot free in either students or teachers
    final studentOk = currentStudents < maxStudents;
    final teacherOk = currentTeachers < maxTeachers;
    if (!studentOk && !teacherOk) {
      return LimitCheckResult(
        allowed: false,
        resourceName: 'Members',
        current: currentStudents + currentTeachers,
        max: maxStudents + maxTeachers,
        reason: 'Member limit reached for your plan.',
      );
    }
    return LimitCheckResult(
      allowed: true,
      resourceName: 'Members',
      current: currentStudents + currentTeachers,
      max: maxStudents + maxTeachers,
    );
  }

  LimitCheckResult canCreateLiveSession() {
    if (!hasFeature('liveSessions')) {
      return LimitCheckResult(
        allowed: false,
        resourceName: 'Live Sessions',
        current: 0,
        max: 0,
        reason: 'Live sessions are not available on your current plan.',
      );
    }
    return LimitCheckResult(
      allowed: true,
      resourceName: 'Live Sessions',
      current: 0,
      max: -1,
    );
  }

  // ── Usage percentage helpers ─────────────────────

  /// Returns 0–100 percentage for a given resource, or null if no usage data.
  int? usagePercent(String resource) {
    if (_usage == null) return null;
    switch (resource.toLowerCase()) {
      case 'students':
        return _usage!.usagePercentage.students;
      case 'teachers':
        return _usage!.usagePercentage.teachers;
      case 'programs':
        return _usage!.usagePercentage.programs;
      case 'courses':
        return _usage!.usagePercentage.courses;
      case 'classes':
        return _usage!.usagePercentage.classes;
      case 'storage':
        return _usage!.usagePercentage.storage;
      default:
        return null;
    }
  }

  /// True when any resource is at or above [threshold] percent.
  bool isApproachingLimit({int threshold = 80}) {
    if (_usage == null) return false;
    final p = _usage!.usagePercentage;
    return p.students >= threshold ||
        p.teachers >= threshold ||
        p.programs >= threshold ||
        p.courses >= threshold ||
        p.classes >= threshold ||
        p.storage >= threshold;
  }

  // ── Internal helper ──────────────────────────────
  LimitCheckResult _checkLimit(String name, int? current, int? max) {
    if (_currentPlan == null) return LimitCheckResult.noPlan();
    final c = current ?? 0;
    final m = max ?? 0;
    if (c >= m) {
      return LimitCheckResult(
        allowed: false,
        resourceName: name,
        current: c,
        max: m,
        reason: '$name limit reached for your plan ($c / $m).',
      );
    }
    return LimitCheckResult(
      allowed: true,
      resourceName: name,
      current: c,
      max: m,
    );
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}

// ── Value object returned by all can* checks ────────
class LimitCheckResult {
  final bool allowed;
  final String resourceName;
  final int current;
  final int max;
  final String? reason;

  const LimitCheckResult({
    required this.allowed,
    required this.resourceName,
    required this.current,
    required this.max,
    this.reason,
  });

  factory LimitCheckResult.noPlan() => const LimitCheckResult(
    allowed: false,
    resourceName: 'Unknown',
    current: 0,
    max: 0,
    reason: 'Subscription plan not loaded yet.',
  );

  /// Convenience: remaining slots (-1 = unlimited).
  int get remaining => max == -1 ? -1 : (max - current).clamp(0, max);

  @override
  String toString() =>
      'LimitCheckResult($resourceName: allowed=$allowed, $current/$max)';
}
