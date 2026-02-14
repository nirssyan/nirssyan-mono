/// Subscription plan type enum
enum SubscriptionPlanType {
  FREE,
  PRO;

  static SubscriptionPlanType fromString(String value) {
    switch (value.toUpperCase()) {
      case 'PRO':
        return SubscriptionPlanType.PRO;
      case 'FREE':
      default:
        return SubscriptionPlanType.FREE;
    }
  }
}

/// Type of limit being checked
enum LimitType {
  sources,
  filters,
  styles,
  feeds;
}

/// Subscription plan with limits
class SubscriptionPlan {
  final SubscriptionPlanType type;
  final int maxSources;
  final int maxFeeds;

  // Hardcoded limits
  static const int maxFilters = 5;
  static const int maxStyles = 5;

  const SubscriptionPlan({
    required this.type,
    required this.maxSources,
    required this.maxFeeds,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    print('SubscriptionPlan.fromJson: Parsing JSON: $json');
    final plan = SubscriptionPlan(
      type: SubscriptionPlanType.fromString(json['plan_type'] as String? ?? 'FREE'),
      maxSources: json['sources_per_feed_limit'] as int? ?? 3,
      maxFeeds: json['feeds_limit'] as int? ?? 10,
    );
    print('SubscriptionPlan.fromJson: Result - type=${plan.type}, maxSources=${plan.maxSources}, maxFeeds=${plan.maxFeeds}');
    return plan;
  }

  /// Get limit for a specific type
  int getLimit(LimitType limitType) {
    switch (limitType) {
      case LimitType.sources:
        return maxSources;
      case LimitType.filters:
        return maxFilters;
      case LimitType.styles:
        return maxStyles;
      case LimitType.feeds:
        return maxFeeds;
    }
  }

  /// Default FREE plan
  static const SubscriptionPlan free = SubscriptionPlan(
    type: SubscriptionPlanType.FREE,
    maxSources: 3,
    maxFeeds: 10,
  );

  /// Default PRO plan
  static const SubscriptionPlan pro = SubscriptionPlan(
    type: SubscriptionPlanType.PRO,
    maxSources: 10,
    maxFeeds: 10,
  );
}

/// Subscription status including active feeds count
class SubscriptionStatus {
  final SubscriptionPlan plan;
  final int activeFeedsCount;

  const SubscriptionStatus({
    required this.plan,
    required this.activeFeedsCount,
  });

  factory SubscriptionStatus.fromJson(Map<String, dynamic> json) {
    print('SubscriptionStatus.fromJson: Parsing JSON: $json');
    final planJson = json['plan'] as Map<String, dynamic>? ?? {};
    return SubscriptionStatus(
      plan: SubscriptionPlan.fromJson(planJson),
      activeFeedsCount: json['active_feeds_count'] as int? ?? 0,
    );
  }

  /// Check if user can add more of a specific limit type
  bool canAddMore(LimitType limitType, int currentCount) {
    final limit = plan.getLimit(limitType);
    return currentCount < limit;
  }

  /// Check if user can create a new feed
  bool get canCreateFeed => activeFeedsCount < plan.maxFeeds;

  /// Default status with FREE plan
  static const SubscriptionStatus defaultStatus = SubscriptionStatus(
    plan: SubscriptionPlan.free,
    activeFeedsCount: 0,
  );
}
