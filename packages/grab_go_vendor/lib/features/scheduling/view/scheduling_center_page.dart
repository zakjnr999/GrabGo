import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_vendor/features/auth/model/vendor_service_option.dart';
import 'package:grab_go_vendor/features/scheduling/model/vendor_scheduling_models.dart';
import 'package:grab_go_vendor/features/scheduling/viewmodel/scheduling_center_viewmodel.dart';
import 'package:grab_go_vendor/features/store_context/viewmodel/store_context_viewmodel.dart';
import 'package:grab_go_vendor/shared/viewmodel/vendor_preview_session_viewmodel.dart';
import 'package:grab_go_vendor/shared/widgets/vendor_store_context_chip.dart';
import 'package:provider/provider.dart';

class SchedulingCenterPage extends StatelessWidget {
  const SchedulingCenterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SchedulingCenterViewModel(),
      child: const _SchedulingCenterView(),
    );
  }
}

class _SchedulingCenterView extends StatelessWidget {
  const _SchedulingCenterView();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Consumer3<
      SchedulingCenterViewModel,
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
        final orders = viewModel.filteredOrders(visibleServices);
        final cutoffRules = viewModel.cutoffRules(visibleServices);

        return Scaffold(
          backgroundColor: colors.backgroundPrimary,
          appBar: AppBar(
            backgroundColor: colors.backgroundPrimary,
            elevation: 0,
            title: Text(
              'Scheduling & Capacity',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w800,
                color: colors.textPrimary,
              ),
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    visibleServices.isEmpty
                        ? 'No services are active for this profile and store context.'
                        : 'Manage scheduled orders and slot capacity for ${previewSession.servicesLabel(visibleServices)}.',
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
                  TextField(
                    controller: viewModel.searchController,
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search scheduled orders',
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
                        _FilterChip(
                          label: 'Tomorrow',
                          selected: viewModel.tomorrowOnly,
                          color: colors.warning,
                          onTap: viewModel.toggleTomorrowOnly,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12.h),
                  _SectionCard(
                    title: 'Scheduled Orders',
                    child: orders.isEmpty
                        ? Text(
                            'No scheduled orders match current filters.',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: colors.textSecondary,
                            ),
                          )
                        : Column(
                            children: orders.map((order) {
                              return _ScheduledOrderCard(order: order);
                            }).toList(),
                          ),
                  ),
                  SizedBox(height: 12.h),
                  _SectionCard(
                    title: 'Time Slot Capacity',
                    child: Column(
                      children: viewModel.slotCapacities.map((slot) {
                        return _SlotCapacityCard(
                          slot: slot,
                          onIncrease: () => viewModel.updateSlotCapacity(
                            slot.id,
                            slot.capacity + 1,
                          ),
                          onDecrease: () => viewModel.updateSlotCapacity(
                            slot.id,
                            slot.capacity - 1,
                          ),
                          onTogglePause: () =>
                              viewModel.toggleSlotPause(slot.id),
                        );
                      }).toList(),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  _SectionCard(
                    title: 'Cutoff Rules',
                    child: cutoffRules.isEmpty
                        ? Text(
                            'No cutoff rules available for current service scope.',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: colors.textSecondary,
                            ),
                          )
                        : Column(
                            children: cutoffRules.map((rule) {
                              return _CutoffRuleCard(
                                rule: rule,
                                onMinutesChanged: (minutes) => viewModel
                                    .setCutoffMinutes(rule.id, minutes),
                                onSameDayChanged: (enabled) => viewModel
                                    .setSameDayEnabled(rule.id, enabled),
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

Color _capacityColor(AppColorsExtension colors, VendorCapacityStatus status) {
  return switch (status) {
    VendorCapacityStatus.available => colors.success,
    VendorCapacityStatus.nearCapacity => colors.warning,
    VendorCapacityStatus.full => colors.error,
    VendorCapacityStatus.paused => colors.textSecondary,
  };
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

class _ScheduledOrderCard extends StatelessWidget {
  final VendorScheduledOrder order;

  const _ScheduledOrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final serviceColor = _serviceColor(colors, order.serviceType);
    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(10.r),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: order.atRisk
              ? colors.error.withValues(alpha: 0.4)
              : colors.border,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34.w,
            height: 34.w,
            decoration: BoxDecoration(
              color: serviceColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(
              Icons.schedule_rounded,
              size: 18.sp,
              color: serviceColor,
            ),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${order.id} • ${order.customerName}',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                  ),
                ),
                SizedBox(height: 3.h),
                Text(
                  '${_serviceLabel(order.serviceType)} • ${order.fulfillmentLabel} • ${order.itemCount} items',
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  order.slotLabel,
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                    color: order.atRisk ? colors.error : colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SlotCapacityCard extends StatelessWidget {
  final VendorTimeSlotCapacity slot;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;
  final VoidCallback onTogglePause;

  const _SlotCapacityCard({
    required this.slot,
    required this.onIncrease,
    required this.onDecrease,
    required this.onTogglePause,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final statusColor = _capacityColor(colors, slot.status);
    final progress = slot.capacity == 0 ? 0.0 : (slot.booked / slot.capacity);

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
                  slot.slotLabel,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999.r),
                ),
                child: Text(
                  slot.status.label,
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
          LinearProgressIndicator(
            value: progress.clamp(0, 1),
            minHeight: 6.h,
            backgroundColor: statusColor.withValues(alpha: 0.14),
            color: statusColor,
            borderRadius: BorderRadius.circular(999.r),
          ),
          SizedBox(height: 6.h),
          Row(
            children: [
              Text(
                '${slot.booked}/${slot.capacity} booked',
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: onDecrease,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.remove_circle_outline_rounded),
              ),
              IconButton(
                onPressed: onIncrease,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.add_circle_outline_rounded),
              ),
              TextButton(
                onPressed: onTogglePause,
                child: Text(
                  slot.status == VendorCapacityStatus.paused
                      ? 'Resume'
                      : 'Pause',
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                    color: colors.vendorPrimaryBlue,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CutoffRuleCard extends StatelessWidget {
  final VendorCutoffRule rule;
  final ValueChanged<int> onMinutesChanged;
  final ValueChanged<bool> onSameDayChanged;

  const _CutoffRuleCard({
    required this.rule,
    required this.onMinutesChanged,
    required this.onSameDayChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final serviceColor = _serviceColor(colors, rule.serviceType);

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
          Text(
            _serviceLabel(rule.serviceType),
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w800,
              color: serviceColor,
            ),
          ),
          SizedBox(height: 6.h),
          Text(
            'Cutoff: ${rule.cutoffMinutes} mins before slot',
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
            ),
          ),
          Slider(
            value: rule.cutoffMinutes.toDouble(),
            min: 10,
            max: 180,
            divisions: 17,
            activeColor: serviceColor,
            label: '${rule.cutoffMinutes} mins',
            onChanged: (value) => onMinutesChanged(value.round()),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: rule.sameDayEnabled,
            activeThumbColor: serviceColor,
            title: Text(
              'Allow same-day slots',
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            subtitle: Text(
              'Disable to enforce next-day scheduling only',
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.w500,
                color: colors.textSecondary,
              ),
            ),
            onChanged: onSameDayChanged,
          ),
        ],
      ),
    );
  }
}
