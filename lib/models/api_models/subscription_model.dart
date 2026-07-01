import 'package:json_annotation/json_annotation.dart';

part 'subscription_model.g.dart';

@JsonSerializable(explicitToJson: true)
class SubscriptionPlan {
  final String id;
  final String organizationId;
  final String planType;
  final String planPeriod;
  final Limits limits;
  final Usage usage;
  final Features features;
  final String status;
  final DateTime startDate;
  final DateTime? endDate;
  final bool autoRenew;
  final DateTime? updatedAt;

  SubscriptionPlan({
    required this.id,
    required this.organizationId,
    required this.planType,
    required this.planPeriod,
    required this.limits,
    required this.usage,
    required this.features,
    required this.status,
    required this.startDate,
    this.endDate,
    required this.autoRenew,
    this.updatedAt,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) =>
      _$SubscriptionPlanFromJson(json);
  Map<String, dynamic> toJson() => _$SubscriptionPlanToJson(this);
}

@JsonSerializable()
class Limits {
  @JsonKey(fromJson: _parseIntLimit, defaultValue: 0)
  final int maxStudents;

  @JsonKey(fromJson: _parseIntLimit, defaultValue: 0)
  final int maxTeachers;

  @JsonKey(fromJson: _parseIntLimit, defaultValue: 0)
  final int maxPrograms;

  @JsonKey(fromJson: _parseIntLimit, defaultValue: 0)
  final int maxCourses;

  @JsonKey(fromJson: _parseIntLimit, defaultValue: 0)
  final int maxClasses;

  @JsonKey(fromJson: _parseDoubleLimit, defaultValue: 0.0)
  final double maxStorageGB;

  Limits({
    required this.maxStudents,
    required this.maxTeachers,
    required this.maxPrograms,
    required this.maxCourses,
    required this.maxClasses,
    required this.maxStorageGB,
  });

  static int _parseIntLimit(dynamic value) {
    if (value == null) return 0;

    if (value is int) return value;

    if (value is String) {
      if (value.toLowerCase() == 'unlimited') {
        return -1;
      }

      return int.tryParse(value) ?? 0;
    }

    return 0;
  }

  static double _parseDoubleLimit(dynamic value) {
    if (value == null) return 0.0;

    if (value is double) return value;

    if (value is int) return value.toDouble();

    if (value is String) {
      if (value.toLowerCase() == 'unlimited') {
        return -1;
      }

      return double.tryParse(value) ?? 0.0;
    }

    return 0.0;
  }

  factory Limits.fromJson(Map<String, dynamic> json) => _$LimitsFromJson(json);

  Map<String, dynamic> toJson() => _$LimitsToJson(this);
}

@JsonSerializable()
class Usage {
  @JsonKey(defaultValue: 0)
  final int currentStudents;
  @JsonKey(defaultValue: 0)
  final int currentTeachers;
  @JsonKey(defaultValue: 0)
  final int currentPrograms;
  @JsonKey(defaultValue: 0)
  final int currentCourses;
  @JsonKey(defaultValue: 0)
  final int currentClasses;
  @JsonKey(defaultValue: 0.0)
  final double currentStorageGB;

  Usage({
    required this.currentStudents,
    required this.currentTeachers,
    required this.currentPrograms,
    required this.currentCourses,
    required this.currentClasses,
    required this.currentStorageGB,
  });

  factory Usage.fromJson(Map<String, dynamic> json) => _$UsageFromJson(json);
  Map<String, dynamic> toJson() => _$UsageToJson(this);
}

@JsonSerializable()
class Features {
  @JsonKey(defaultValue: false)
  final bool analytics;
  @JsonKey(defaultValue: false)
  final bool liveSessions;
  @JsonKey(defaultValue: false)
  final bool customDomain;
  @JsonKey(defaultValue: false)
  final bool apiAccess; // ← renamed from prioritySupport, matches API
  @JsonKey(defaultValue: false)
  final bool prioritySupport; // ← keep but default false so missing = no crash

  Features({
    required this.analytics,
    required this.liveSessions,
    required this.customDomain,
    required this.apiAccess,
    required this.prioritySupport,
  });

  factory Features.fromJson(Map<String, dynamic> json) =>
      _$FeaturesFromJson(json);
  Map<String, dynamic> toJson() => _$FeaturesToJson(this);
}

@JsonSerializable(explicitToJson: true)
class PlanTier {
  final String planType;
  final String name;
  final String? description;
  final PlanPrice? price; // ← nullable, API may omit for free tier
  final List<String> features;
  final Limits? limits;
  @JsonKey(defaultValue: false)
  final bool isCurrent;
  @JsonKey(defaultValue: false)
  final bool canUpgrade;

  PlanTier({
    required this.planType,
    required this.name,
    this.description,
    this.price,
    required this.features,
    this.limits,
    required this.isCurrent,
    required this.canUpgrade,
  });

  factory PlanTier.fromJson(Map<String, dynamic> json) =>
      _$PlanTierFromJson(json);
  Map<String, dynamic> toJson() => _$PlanTierToJson(this);
}

@JsonSerializable()
class PlanPrice {
  @JsonKey(defaultValue: 0.0)
  final double monthly;
  @JsonKey(defaultValue: 0.0)
  final double yearly;

  PlanPrice({required this.monthly, required this.yearly});

  factory PlanPrice.fromJson(Map<String, dynamic> json) =>
      _$PlanPriceFromJson(json);
  Map<String, dynamic> toJson() => _$PlanPriceToJson(this);
}

@JsonSerializable()
class UsageCheckResponse {
  @JsonKey(defaultValue: false)
  final bool allowed;
  @JsonKey(defaultValue: '')
  final String reason;
  @JsonKey(defaultValue: 0)
  final int current;
  @JsonKey(defaultValue: 0)
  final int max;

  UsageCheckResponse({
    required this.allowed,
    required this.reason,
    required this.current,
    required this.max,
  });

  factory UsageCheckResponse.fromJson(Map<String, dynamic> json) =>
      _$UsageCheckResponseFromJson(json);
  Map<String, dynamic> toJson() => _$UsageCheckResponseToJson(this);
}

@JsonSerializable(explicitToJson: true)
class DashboardUsage {
  final String planType;
  final UsagePercentage usagePercentage;
  final RemainingResources remaining;
  final DateTime lastUpdated;

  DashboardUsage({
    required this.planType,
    required this.usagePercentage,
    required this.remaining,
    required this.lastUpdated,
  });

  factory DashboardUsage.fromJson(Map<String, dynamic> json) =>
      _$DashboardUsageFromJson(json);
  Map<String, dynamic> toJson() => _$DashboardUsageToJson(this);
}

@JsonSerializable()
class UsagePercentage {
  @JsonKey(defaultValue: 0)
  final int students;
  @JsonKey(defaultValue: 0)
  final int teachers;
  @JsonKey(defaultValue: 0)
  final int programs;
  @JsonKey(defaultValue: 0)
  final int courses;
  @JsonKey(defaultValue: 0)
  final int classes;
  @JsonKey(defaultValue: 0)
  final int storage;

  UsagePercentage({
    required this.students,
    required this.teachers,
    required this.programs,
    required this.courses,
    required this.classes,
    required this.storage,
  });

  factory UsagePercentage.fromJson(Map<String, dynamic> json) =>
      _$UsagePercentageFromJson(json);
  Map<String, dynamic> toJson() => _$UsagePercentageToJson(this);
}

@JsonSerializable()
class RemainingResources {
  @JsonKey(defaultValue: 0)
  final int students;
  @JsonKey(defaultValue: 0)
  final int teachers;
  @JsonKey(defaultValue: 0)
  final int programs;
  @JsonKey(defaultValue: 0)
  final int courses;
  @JsonKey(defaultValue: 0)
  final int classes;
  @JsonKey(defaultValue: '0')
  final String storageGB;

  RemainingResources({
    required this.students,
    required this.teachers,
    required this.programs,
    required this.courses,
    required this.classes,
    required this.storageGB,
  });

  factory RemainingResources.fromJson(Map<String, dynamic> json) =>
      _$RemainingResourcesFromJson(json);
  Map<String, dynamic> toJson() => _$RemainingResourcesToJson(this);
}
