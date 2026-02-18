import 'package:grab_go_vendor/features/auth/model/vendor_service_option.dart';

enum VendorPromotionType { percentage, amount, bogo, freeDelivery }

enum VendorPromotionStatus { draft, scheduled, active, paused, ended }

class VendorPromotionCampaign {
  final String id;
  final String name;
  final VendorPromotionType type;
  final VendorPromotionStatus status;
  final VendorServiceType serviceType;
  final String audienceLabel;
  final String startLabel;
  final String endLabel;
  final double budget;
  final int redemptions;
  final double revenueLiftPercent;

  const VendorPromotionCampaign({
    required this.id,
    required this.name,
    required this.type,
    required this.status,
    required this.serviceType,
    required this.audienceLabel,
    required this.startLabel,
    required this.endLabel,
    required this.budget,
    required this.redemptions,
    required this.revenueLiftPercent,
  });

  VendorPromotionCampaign copyWith({
    VendorPromotionStatus? status,
    int? redemptions,
    double? revenueLiftPercent,
  }) {
    return VendorPromotionCampaign(
      id: id,
      name: name,
      type: type,
      status: status ?? this.status,
      serviceType: serviceType,
      audienceLabel: audienceLabel,
      startLabel: startLabel,
      endLabel: endLabel,
      budget: budget,
      redemptions: redemptions ?? this.redemptions,
      revenueLiftPercent: revenueLiftPercent ?? this.revenueLiftPercent,
    );
  }
}

class VendorCampaignTemplate {
  final String id;
  final String title;
  final String description;
  final VendorServiceType? recommendedService;

  const VendorCampaignTemplate({
    required this.id,
    required this.title,
    required this.description,
    this.recommendedService,
  });
}

extension VendorPromotionTypeX on VendorPromotionType {
  String get label {
    return switch (this) {
      VendorPromotionType.percentage => '% Discount',
      VendorPromotionType.amount => 'Amount Off',
      VendorPromotionType.bogo => 'BOGO',
      VendorPromotionType.freeDelivery => 'Free Delivery',
    };
  }
}

extension VendorPromotionStatusX on VendorPromotionStatus {
  String get label {
    return switch (this) {
      VendorPromotionStatus.draft => 'Draft',
      VendorPromotionStatus.scheduled => 'Scheduled',
      VendorPromotionStatus.active => 'Active',
      VendorPromotionStatus.paused => 'Paused',
      VendorPromotionStatus.ended => 'Ended',
    };
  }
}

List<VendorPromotionCampaign> mockPromotionCampaigns() {
  return const [
    VendorPromotionCampaign(
      id: 'promo_001',
      name: 'Lunch Rush Booster',
      type: VendorPromotionType.percentage,
      status: VendorPromotionStatus.active,
      serviceType: VendorServiceType.food,
      audienceLabel: 'New + Returning',
      startLabel: 'Mon 11:00 AM',
      endLabel: 'Fri 2:00 PM',
      budget: 1200,
      redemptions: 146,
      revenueLiftPercent: 18.4,
    ),
    VendorPromotionCampaign(
      id: 'promo_002',
      name: 'Weekend Basket Saver',
      type: VendorPromotionType.amount,
      status: VendorPromotionStatus.scheduled,
      serviceType: VendorServiceType.grocery,
      audienceLabel: 'High-value buyers',
      startLabel: 'Sat 8:00 AM',
      endLabel: 'Sun 8:00 PM',
      budget: 900,
      redemptions: 0,
      revenueLiftPercent: 0,
    ),
    VendorPromotionCampaign(
      id: 'promo_003',
      name: 'OTC Bundle Bonus',
      type: VendorPromotionType.bogo,
      status: VendorPromotionStatus.paused,
      serviceType: VendorServiceType.pharmacy,
      audienceLabel: 'Repeat customers',
      startLabel: 'Daily 7:00 AM',
      endLabel: 'Daily 10:00 PM',
      budget: 600,
      redemptions: 52,
      revenueLiftPercent: 9.1,
    ),
    VendorPromotionCampaign(
      id: 'promo_004',
      name: 'GrabMart Night Free Delivery',
      type: VendorPromotionType.freeDelivery,
      status: VendorPromotionStatus.draft,
      serviceType: VendorServiceType.grabMart,
      audienceLabel: 'All users',
      startLabel: 'Not set',
      endLabel: 'Not set',
      budget: 500,
      redemptions: 0,
      revenueLiftPercent: 0,
    ),
  ];
}

List<VendorCampaignTemplate> mockCampaignTemplates() {
  return const [
    VendorCampaignTemplate(
      id: 'tpl_001',
      title: 'Slow Hour Recovery',
      description: 'Auto-boost low-volume windows with short % offers.',
    ),
    VendorCampaignTemplate(
      id: 'tpl_002',
      title: 'First Order Welcome',
      description: 'Discount for first-time buyers to improve acquisition.',
      recommendedService: VendorServiceType.food,
    ),
    VendorCampaignTemplate(
      id: 'tpl_003',
      title: 'Basket Threshold Reward',
      description: 'Unlock amount-off once cart reaches threshold.',
      recommendedService: VendorServiceType.grocery,
    ),
    VendorCampaignTemplate(
      id: 'tpl_004',
      title: 'Compliance-safe OTC Push',
      description: 'Pharmacy-friendly campaign excluding restricted items.',
      recommendedService: VendorServiceType.pharmacy,
    ),
  ];
}
