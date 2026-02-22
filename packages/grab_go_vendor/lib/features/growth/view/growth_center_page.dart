import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_vendor/features/auth/model/vendor_service_option.dart';
import 'package:grab_go_vendor/features/growth/model/vendor_growth_models.dart';
import 'package:grab_go_vendor/features/growth/viewmodel/growth_center_viewmodel.dart';
import 'package:grab_go_vendor/features/store_context/viewmodel/store_context_viewmodel.dart';
import 'package:grab_go_vendor/shared/viewmodel/vendor_preview_session_viewmodel.dart';
import 'package:grab_go_vendor/shared/widgets/vendor_store_context_chip.dart';
import 'package:provider/provider.dart';

class GrowthCenterPage extends StatelessWidget {
  const GrowthCenterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => GrowthCenterViewModel(),
      child: const _GrowthCenterView(),
    );
  }
}

class _GrowthCenterView extends StatelessWidget {
  const _GrowthCenterView();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Consumer3<
      GrowthCenterViewModel,
      VendorStoreContextViewModel,
      VendorPreviewSessionViewModel
    >(
      builder: (context, viewModel, storeContext, previewSession, _) {
        final visibleServices = _visibleVendorServices(storeContext);
        if (viewModel.serviceFilter != null &&
            !visibleServices.contains(viewModel.serviceFilter)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) {
              return;
            }
            viewModel.setServiceFilter(null);
          });
        }

        final orderedServices = visibleServices.toList()
          ..sort((a, b) => a.index.compareTo(b.index));
        final campaigns = viewModel.filteredCampaigns(visibleServices);

        return Scaffold(
          backgroundColor: colors.backgroundPrimary,
          appBar: AppBar(
            backgroundColor: colors.backgroundPrimary,
            elevation: 0,
            title: Text(
              'Growth & Campaigns',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w800,
                color: colors.textPrimary,
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: colors.vendorPrimaryBlue,
            foregroundColor: Colors.white,
            onPressed: visibleServices.isEmpty
                ? null
                : () => _showCreateCampaignSheet(context, orderedServices),
            icon: const Icon(Icons.campaign_outlined),
            label: const Text('New Campaign'),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 90.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    visibleServices.isEmpty
                        ? 'No services are active for this profile and store context.'
                        : 'Build promotions for ${previewSession.servicesLabel(visibleServices)}.',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500,
                      color: colors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  const Align(
                    alignment: Alignment.centerRight,
                    child: VendorStoreContextChip(compact: false),
                  ),
                  SizedBox(height: 12.h),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 3,
                    crossAxisSpacing: 8.w,
                    mainAxisSpacing: 8.h,
                    childAspectRatio: 1.05,
                    children: [
                      _MetricCard(
                        label: 'Active',
                        value: '${viewModel.activeCount(visibleServices)}',
                        color: colors.success,
                      ),
                      _MetricCard(
                        label: 'Redemptions',
                        value: '${viewModel.totalRedemptions(visibleServices)}',
                        color: colors.vendorPrimaryBlue,
                      ),
                      _MetricCard(
                        label: 'Avg Lift',
                        value:
                            '${viewModel.averageLift(visibleServices).toStringAsFixed(1)}%',
                        color: colors.warning,
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  TextField(
                    controller: viewModel.searchController,
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search campaigns and audience',
                      hintStyle: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                        color: colors.textSecondary,
                      ),
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        size: 18.sp,
                        color: colors.textSecondary,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide(color: colors.inputBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide(color: colors.vendorPrimaryBlue),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide(color: colors.inputBorder),
                      ),
                      filled: true,
                      fillColor: colors.backgroundPrimary,
                    ),
                  ),
                  SizedBox(height: 10.h),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterChip(
                          label: 'All Status',
                          selected: viewModel.statusFilter == null,
                          color: colors.vendorPrimaryBlue,
                          onTap: () => viewModel.setStatusFilter(null),
                        ),
                        ...VendorPromotionStatus.values.map((status) {
                          return _FilterChip(
                            label: status.label,
                            selected: viewModel.statusFilter == status,
                            color: _statusColor(colors, status),
                            onTap: () => viewModel.setStatusFilter(status),
                          );
                        }),
                      ],
                    ),
                  ),
                  SizedBox(height: 8.h),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterChip(
                          label: 'All Services',
                          selected: viewModel.serviceFilter == null,
                          color: colors.vendorPrimaryBlue,
                          onTap: () => viewModel.setServiceFilter(null),
                        ),
                        ...orderedServices.map((service) {
                          return _FilterChip(
                            label: _serviceLabel(service),
                            selected: viewModel.serviceFilter == service,
                            color: _serviceColor(colors, service),
                            onTap: () => viewModel.setServiceFilter(service),
                          );
                        }),
                      ],
                    ),
                  ),
                  SizedBox(height: 12.h),
                  _SectionCard(
                    title: 'Campaign Builder',
                    child: campaigns.isEmpty
                        ? Padding(
                            padding: EdgeInsets.symmetric(vertical: 8.h),
                            child: Text(
                              'No campaigns match current filters.',
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                                color: colors.textSecondary,
                              ),
                            ),
                          )
                        : Column(
                            children: campaigns.map((campaign) {
                              return _CampaignCard(
                                campaign: campaign,
                                onAdvance: () => viewModel
                                    .advanceCampaignStatus(campaign.id),
                              );
                            }).toList(),
                          ),
                  ),
                  SizedBox(height: 12.h),
                  _SectionCard(
                    title: 'Promo Performance Templates',
                    child: Column(
                      children: viewModel.templates.map((template) {
                        return Container(
                          width: double.infinity,
                          margin: EdgeInsets.only(bottom: 10.h),
                          padding: EdgeInsets.all(10.r),
                          decoration: BoxDecoration(
                            color: colors.backgroundPrimary,
                            borderRadius: BorderRadius.circular(12.r),
                            border: Border.all(color: colors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      template.title,
                                      style: TextStyle(
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w700,
                                        color: colors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => _showInfo(
                                      context,
                                      'Template applied in UI preview mode.',
                                    ),
                                    child: Text(
                                      'Use',
                                      style: TextStyle(
                                        fontSize: 11.sp,
                                        fontWeight: FontWeight.w700,
                                        color: colors.vendorPrimaryBlue,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                template.description,
                                style: TextStyle(
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w600,
                                  color: colors.textSecondary,
                                ),
                              ),
                              if (template.recommendedService != null)
                                Padding(
                                  padding: EdgeInsets.only(top: 6.h),
                                  child: Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8.w,
                                      vertical: 4.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _serviceColor(
                                        colors,
                                        template.recommendedService!,
                                      ).withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(
                                        999.r,
                                      ),
                                    ),
                                    child: Text(
                                      'Best for ${_serviceLabel(template.recommendedService!)}',
                                      style: TextStyle(
                                        fontSize: 10.sp,
                                        fontWeight: FontWeight.w700,
                                        color: _serviceColor(
                                          colors,
                                          template.recommendedService!,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showCreateCampaignSheet(
    BuildContext context,
    List<VendorServiceType> visibleServices,
  ) async {
    final colors = context.appColors;
    final viewModel = context.read<GrowthCenterViewModel>();
    final nameController = TextEditingController();
    final budgetController = TextEditingController(text: '500');
    var selectedService = visibleServices.first;
    var selectedType = VendorPromotionType.percentage;
    String? nameError;
    String? budgetError;

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: colors.backgroundPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18.r)),
        ),
        builder: (sheetContext) {
          return StatefulBuilder(
            builder: (sheetContext, setSheetState) {
              return Padding(
                padding: EdgeInsets.fromLTRB(
                  16.w,
                  12.h,
                  16.w,
                  20.h + MediaQuery.viewInsetsOf(sheetContext).bottom,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Create Campaign',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w800,
                          color: colors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 10.h),
                      TextField(
                        controller: nameController,
                        onChanged: (_) => setSheetState(() => nameError = null),
                        decoration: InputDecoration(
                          labelText: 'Campaign Name',
                          errorText: nameError,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      DropdownButtonFormField<VendorServiceType>(
                        initialValue: selectedService,
                        decoration: const InputDecoration(labelText: 'Service'),
                        items: visibleServices.map((service) {
                          return DropdownMenuItem(
                            value: service,
                            child: Text(_serviceLabel(service)),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          setSheetState(() => selectedService = value);
                        },
                      ),
                      SizedBox(height: 8.h),
                      DropdownButtonFormField<VendorPromotionType>(
                        initialValue: selectedType,
                        decoration: const InputDecoration(labelText: 'Type'),
                        items: VendorPromotionType.values.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(type.label),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value == null) {
                            return;
                          }
                          setSheetState(() => selectedType = value);
                        },
                      ),
                      SizedBox(height: 8.h),
                      TextField(
                        controller: budgetController,
                        keyboardType: TextInputType.number,
                        onChanged: (_) =>
                            setSheetState(() => budgetError = null),
                        decoration: InputDecoration(
                          labelText: 'Budget (GHS)',
                          errorText: budgetError,
                        ),
                      ),
                      SizedBox(height: 14.h),
                      SizedBox(
                        width: double.infinity,
                        child: AppButton(
                          buttonText: 'Save Draft',
                          onPressed: () {
                            final name = nameController.text.trim();
                            final budget = double.tryParse(
                              budgetController.text.trim(),
                            );
                            setSheetState(() {
                              nameError = name.isEmpty
                                  ? 'Campaign name is required'
                                  : null;
                              budgetError = budget == null || budget <= 0
                                  ? 'Enter valid budget'
                                  : null;
                            });
                            if (nameError != null || budgetError != null) {
                              return;
                            }
                            viewModel.createDraftCampaign(
                              name: name,
                              serviceType: selectedService,
                              promotionType: selectedType,
                              budget: budget!,
                            );
                            Navigator.pop(sheetContext);
                            _showInfo(
                              context,
                              'Draft campaign created in UI preview mode.',
                            );
                          },
                          backgroundColor: colors.vendorPrimaryBlue,
                          borderRadius: KBorderSize.borderRadius12,
                          textStyle: TextStyle(
                            color: Colors.white,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      nameController.dispose();
      budgetController.dispose();
    }
  }

  void _showInfo(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

Set<VendorServiceType> _visibleVendorServices(
  VendorStoreContextViewModel storeContext,
) {
  final scope = storeContext.serviceScope;
  if (scope != null) {
    return {scope};
  }
  return storeContext.availableServicesForSelectedBranch.toSet();
}

String _serviceLabel(VendorServiceType serviceType) {
  return switch (serviceType) {
    VendorServiceType.food => 'Food',
    VendorServiceType.grocery => 'Grocery',
    VendorServiceType.pharmacy => 'Pharmacy',
    VendorServiceType.grabMart => 'GrabMart',
  };
}

Color _serviceColor(AppColorsExtension colors, VendorServiceType serviceType) {
  return switch (serviceType) {
    VendorServiceType.food => colors.serviceFood,
    VendorServiceType.grocery => colors.serviceGrocery,
    VendorServiceType.pharmacy => colors.servicePharmacy,
    VendorServiceType.grabMart => colors.serviceGrabMart,
  };
}

Color _statusColor(AppColorsExtension colors, VendorPromotionStatus status) {
  return switch (status) {
    VendorPromotionStatus.draft => colors.textSecondary,
    VendorPromotionStatus.scheduled => colors.warning,
    VendorPromotionStatus.active => colors.success,
    VendorPromotionStatus.paused => colors.error,
    VendorPromotionStatus.ended => colors.textSecondary,
  };
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: EdgeInsets.all(10.r),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
            ),
          ),
          SizedBox(height: 10.h),
          child,
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999.r),
      child: Container(
        margin: EdgeInsets.only(right: 8.w),
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 7.h),
        decoration: BoxDecoration(
          color: selected ? color : color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999.r),
          border: Border.all(color: selected ? color : colors.border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.sp,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : colors.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _CampaignCard extends StatelessWidget {
  final VendorPromotionCampaign campaign;
  final VoidCallback onAdvance;

  const _CampaignCard({required this.campaign, required this.onAdvance});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final statusColor = _statusColor(colors, campaign.status);
    final serviceColor = _serviceColor(colors, campaign.serviceType);

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(10.r),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  campaign.name,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999.r),
                ),
                child: Text(
                  campaign.status.label,
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 6.h,
            children: [
              _MetaTag(
                label: campaign.type.label,
                color: colors.vendorPrimaryBlue,
              ),
              _MetaTag(
                label: _serviceLabel(campaign.serviceType),
                color: serviceColor,
              ),
              _MetaTag(
                label: campaign.audienceLabel,
                color: colors.textSecondary,
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            'Window: ${campaign.startLabel} → ${campaign.endLabel}',
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            'Budget: GHS ${campaign.budget.toStringAsFixed(0)} • Redemptions: ${campaign.redemptions} • Lift: ${campaign.revenueLiftPercent.toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
            ),
          ),
          SizedBox(height: 8.h),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: campaign.status == VendorPromotionStatus.ended
                  ? null
                  : onAdvance,
              icon: Icon(Icons.skip_next_rounded, size: 16.sp),
              label: Text(
                campaign.status == VendorPromotionStatus.ended
                    ? 'Completed'
                    : 'Advance Status',
                style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaTag extends StatelessWidget {
  final String label;
  final Color color;

  const _MetaTag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10.sp,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
