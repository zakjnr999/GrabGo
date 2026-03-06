class SubscriptionPlan {
  final String tier;
  final String name;
  final double price;
  final String currency;
  final String interval;
  final String description;
  final String freeDeliveryText;
  final String serviceFeeDiscountText;
  final bool prioritySupport;
  final bool exclusiveDeals;

  SubscriptionPlan({
    required this.tier,
    required this.name,
    required this.price,
    required this.currency,
    required this.interval,
    required this.description,
    required this.freeDeliveryText,
    required this.serviceFeeDiscountText,
    required this.prioritySupport,
    required this.exclusiveDeals,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    final benefits = (json['benefits'] as Map?)?.cast<String, dynamic>() ?? {};
    return SubscriptionPlan(
      tier: (json['tier'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      price: (json['price'] as num?)?.toDouble() ?? 0,
      currency: (json['currency'] ?? 'GHS').toString(),
      interval: (json['interval'] ?? 'monthly').toString(),
      description: (json['description'] ?? '').toString(),
      freeDeliveryText: (benefits['freeDelivery'] ?? '').toString(),
      serviceFeeDiscountText: (benefits['serviceFeeDiscount'] ?? '').toString(),
      prioritySupport: benefits['prioritySupport'] == true,
      exclusiveDeals: benefits['exclusiveDeals'] == true,
    );
  }
}

class UserSubscription {
  final String id;
  final String tier;
  final String tierName;
  final String status;
  final String? pendingPaymentReference;
  final DateTime? currentPeriodStart;
  final DateTime? currentPeriodEnd;
  final DateTime? cancelledAt;

  UserSubscription({
    required this.id,
    required this.tier,
    required this.tierName,
    required this.status,
    this.pendingPaymentReference,
    required this.currentPeriodStart,
    required this.currentPeriodEnd,
    required this.cancelledAt,
  });

  bool get isActive => status == 'active' || status == 'past_due';

  factory UserSubscription.fromJson(Map<String, dynamic> json) {
    return UserSubscription(
      id: (json['id'] ?? '').toString(),
      tier: (json['tier'] ?? '').toString(),
      tierName: (json['tierName'] ?? json['tier'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      pendingPaymentReference: json['pendingPaymentReference']?.toString(),
      currentPeriodStart: DateTime.tryParse((json['currentPeriodStart'] ?? '').toString()),
      currentPeriodEnd: DateTime.tryParse((json['currentPeriodEnd'] ?? '').toString()),
      cancelledAt: DateTime.tryParse((json['cancelledAt'] ?? '').toString()),
    );
  }
}

class SubscriptionStartResponse {
  final String subscriptionId;
  final String authorizationUrl;
  final String reference;

  SubscriptionStartResponse({required this.subscriptionId, required this.authorizationUrl, required this.reference});

  factory SubscriptionStartResponse.fromJson(Map<String, dynamic> json) {
    return SubscriptionStartResponse(
      subscriptionId: (json['subscriptionId'] ?? '').toString(),
      authorizationUrl: (json['authorizationUrl'] ?? '').toString(),
      reference: (json['reference'] ?? '').toString(),
    );
  }
}

class SubscriptionPaymentConfirmation {
  final bool confirmed;
  final bool alreadyConfirmed;
  final String status;
  final String reference;
  final String? message;

  SubscriptionPaymentConfirmation({
    required this.confirmed,
    required this.alreadyConfirmed,
    required this.status,
    required this.reference,
    this.message,
  });

  factory SubscriptionPaymentConfirmation.fromJson(Map<String, dynamic> json) {
    return SubscriptionPaymentConfirmation(
      confirmed: json['confirmed'] == true,
      alreadyConfirmed: json['alreadyConfirmed'] == true,
      status: (json['status'] ?? '').toString(),
      reference: (json['reference'] ?? '').toString(),
      message: json['message']?.toString(),
    );
  }
}
