import 'package:flutter/material.dart';
import 'package:grab_go_vendor/features/auth/model/vendor_service_option.dart';
import 'package:grab_go_vendor/features/growth/model/vendor_growth_models.dart';

class GrowthCenterViewModel extends ChangeNotifier {
  GrowthCenterViewModel() {
    searchController.addListener(_handleSearchChanged);
  }

  final TextEditingController searchController = TextEditingController();

  final List<VendorPromotionCampaign> _campaigns = mockPromotionCampaigns();
  final List<VendorCampaignTemplate> templates = mockCampaignTemplates();

  VendorPromotionStatus? _statusFilter;
  VendorServiceType? _serviceFilter;

  VendorPromotionStatus? get statusFilter => _statusFilter;
  VendorServiceType? get serviceFilter => _serviceFilter;

  List<VendorPromotionCampaign> filteredCampaigns(
    Set<VendorServiceType> visibleServices,
  ) {
    final query = searchController.text.trim().toLowerCase();
    return _campaigns.where((campaign) {
      if (!visibleServices.contains(campaign.serviceType)) {
        return false;
      }
      if (_statusFilter != null && campaign.status != _statusFilter) {
        return false;
      }
      if (_serviceFilter != null && campaign.serviceType != _serviceFilter) {
        return false;
      }
      if (query.isNotEmpty) {
        final haystack =
            '${campaign.name} ${campaign.audienceLabel} ${campaign.type.label}'
                .toLowerCase();
        if (!haystack.contains(query)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  int activeCount(Set<VendorServiceType> visibleServices) {
    return _campaigns
        .where(
          (campaign) =>
              visibleServices.contains(campaign.serviceType) &&
              campaign.status == VendorPromotionStatus.active,
        )
        .length;
  }

  int totalRedemptions(Set<VendorServiceType> visibleServices) {
    return _campaigns
        .where((campaign) => visibleServices.contains(campaign.serviceType))
        .fold<int>(0, (sum, campaign) => sum + campaign.redemptions);
  }

  double averageLift(Set<VendorServiceType> visibleServices) {
    final scoped = _campaigns
        .where(
          (campaign) =>
              visibleServices.contains(campaign.serviceType) &&
              campaign.revenueLiftPercent > 0,
        )
        .toList();
    if (scoped.isEmpty) {
      return 0;
    }
    final total = scoped.fold<double>(
      0,
      (sum, campaign) => sum + campaign.revenueLiftPercent,
    );
    return total / scoped.length;
  }

  void setStatusFilter(VendorPromotionStatus? status) {
    if (_statusFilter == status) {
      return;
    }
    _statusFilter = status;
    notifyListeners();
  }

  void setServiceFilter(VendorServiceType? service) {
    if (_serviceFilter == service) {
      return;
    }
    _serviceFilter = service;
    notifyListeners();
  }

  void advanceCampaignStatus(String id) {
    final index = _campaigns.indexWhere((campaign) => campaign.id == id);
    if (index < 0) {
      return;
    }

    final current = _campaigns[index];
    final nextStatus = switch (current.status) {
      VendorPromotionStatus.draft => VendorPromotionStatus.scheduled,
      VendorPromotionStatus.scheduled => VendorPromotionStatus.active,
      VendorPromotionStatus.active => VendorPromotionStatus.paused,
      VendorPromotionStatus.paused => VendorPromotionStatus.ended,
      VendorPromotionStatus.ended => VendorPromotionStatus.ended,
    };

    final nextRedemptions = nextStatus == VendorPromotionStatus.active
        ? current.redemptions + 8
        : current.redemptions;
    final nextLift = nextStatus == VendorPromotionStatus.active
        ? current.revenueLiftPercent + 1.2
        : current.revenueLiftPercent;

    _campaigns[index] = current.copyWith(
      status: nextStatus,
      redemptions: nextRedemptions,
      revenueLiftPercent: nextLift,
    );
    notifyListeners();
  }

  void createDraftCampaign({
    required String name,
    required VendorServiceType serviceType,
    required VendorPromotionType promotionType,
    required double budget,
  }) {
    final campaign = VendorPromotionCampaign(
      id: 'promo_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      type: promotionType,
      status: VendorPromotionStatus.draft,
      serviceType: serviceType,
      audienceLabel: 'Custom audience',
      startLabel: 'Not set',
      endLabel: 'Not set',
      budget: budget,
      redemptions: 0,
      revenueLiftPercent: 0,
    );
    _campaigns.insert(0, campaign);
    notifyListeners();
  }

  void _handleSearchChanged() => notifyListeners();

  @override
  void dispose() {
    searchController.removeListener(_handleSearchChanged);
    searchController.dispose();
    super.dispose();
  }
}
