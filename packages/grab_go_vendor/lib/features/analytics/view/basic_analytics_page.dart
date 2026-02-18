import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_vendor/features/auth/model/vendor_service_option.dart';
import 'package:grab_go_vendor/features/analytics/model/vendor_analytics_models.dart';
import 'package:grab_go_vendor/features/analytics/viewmodel/basic_analytics_viewmodel.dart';
import 'package:grab_go_vendor/features/orders/model/vendor_order_summary.dart';
import 'package:grab_go_vendor/features/store_context/viewmodel/store_context_viewmodel.dart';
import 'package:grab_go_vendor/shared/viewmodel/vendor_preview_session_viewmodel.dart';
import 'package:grab_go_vendor/shared/widgets/vendor_store_context_chip.dart';
import 'package:provider/provider.dart';

class BasicAnalyticsPage extends StatelessWidget {
  const BasicAnalyticsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => BasicAnalyticsViewModel(),
      child: const _BasicAnalyticsView(),
    );
  }
}

class _BasicAnalyticsView extends StatelessWidget {
  const _BasicAnalyticsView();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Consumer3<
      BasicAnalyticsViewModel,
      VendorStoreContextViewModel,
      VendorPreviewSessionViewModel
    >(
      builder: (context, viewModel, storeContext, previewSession, _) {
        final snapshot = viewModel.currentSnapshot;
        final visibleVendorServices = _visibleVendorServices(storeContext);
        final visibleOrderServices = visibleVendorServices
            .map(previewSession.mapToOrderService)
            .toSet();
        final visibleBreakdown = snapshot.serviceBreakdown
            .where((entry) => visibleOrderServices.contains(entry.serviceType))
            .toList();
        final visibleTopItems = snapshot.topItems
            .where((entry) => visibleOrderServices.contains(entry.serviceType))
            .toList();
        final visibleOrders = visibleBreakdown.fold<int>(
          0,
          (total, item) => total + item.orders,
        );
        final visibleRevenue = visibleBreakdown.fold<double>(
          0,
          (total, item) => total + item.revenue,
        );
        final hasVisibleServices = visibleOrderServices.isNotEmpty;

        return Scaffold(
          backgroundColor: colors.backgroundPrimary,
          appBar: AppBar(
            backgroundColor: colors.backgroundPrimary,
            elevation: 0,
            title: Text(
              'Basic Analytics',
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
                    hasVisibleServices
                        ? 'Showing ${previewSession.servicesLabel(visibleVendorServices)} analytics.'
                        : 'No services are active for this profile and store context.',
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
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: VendorAnalyticsRange.values.map((range) {
                        return _RangeChip(
                          label: viewModel.rangeLabel(range),
                          selected: viewModel.selectedRange == range,
                          onTap: () => viewModel.setRange(range),
                        );
                      }).toList(),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    mainAxisSpacing: 10.h,
                    crossAxisSpacing: 10.w,
                    childAspectRatio: 1.7,
                    children: [
                      _KpiCard(
                        label: 'Orders',
                        value: '${hasVisibleServices ? visibleOrders : 0}',
                        accentColor: colors.vendorPrimaryBlue,
                      ),
                      _KpiCard(
                        label: 'Revenue',
                        value: viewModel.revenueLabel(
                          hasVisibleServices ? visibleRevenue : 0,
                        ),
                        accentColor: colors.serviceGrocery,
                      ),
                      _KpiCard(
                        label: 'Avg Prep',
                        value: '${snapshot.avgPrepMinutes} mins',
                        accentColor: colors.warning,
                      ),
                      _KpiCard(
                        label: 'Cancel Rate',
                        value:
                            '${snapshot.cancelRatePercent.toStringAsFixed(1)}%',
                        accentColor: colors.error,
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  _SectionCard(
                    title: 'Orders Trend',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _MiniBarChart(values: snapshot.orderTrend),
                        SizedBox(height: 8.h),
                        Text(
                          '${snapshot.orderTrend.reduce((a, b) => a > b ? a : b)} peak orders in selected period',
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12.h),
                  _SectionCard(
                    title: 'Service Breakdown',
                    child: visibleBreakdown.isEmpty
                        ? Text(
                            'No service metrics for the selected scope.',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: colors.textSecondary,
                            ),
                          )
                        : Column(
                            children: visibleBreakdown.map((metric) {
                              final color = _serviceColor(
                                colors,
                                metric.serviceType,
                              );
                              return Padding(
                                padding: EdgeInsets.only(bottom: 10.h),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 10.w,
                                          height: 10.w,
                                          decoration: BoxDecoration(
                                            color: color,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        SizedBox(width: 8.w),
                                        Expanded(
                                          child: Text(
                                            metric.serviceType.label,
                                            style: TextStyle(
                                              fontSize: 12.sp,
                                              fontWeight: FontWeight.w700,
                                              color: colors.textPrimary,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '${metric.orders} orders',
                                          style: TextStyle(
                                            fontSize: 11.sp,
                                            fontWeight: FontWeight.w700,
                                            color: colors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 4.h),
                                    LinearProgressIndicator(
                                      value: metric.share.clamp(0, 1),
                                      backgroundColor: color.withValues(
                                        alpha: 0.12,
                                      ),
                                      color: color,
                                      minHeight: 6.h,
                                      borderRadius: BorderRadius.circular(
                                        999.r,
                                      ),
                                    ),
                                    SizedBox(height: 4.h),
                                    Text(
                                      'Revenue: GHS ${metric.revenue.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 10.sp,
                                        fontWeight: FontWeight.w600,
                                        color: colors.textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                  ),
                  SizedBox(height: 12.h),
                  _SectionCard(
                    title: 'Top Performing Items',
                    child: visibleTopItems.isEmpty
                        ? Text(
                            'No top items for the selected scope.',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                              color: colors.textSecondary,
                            ),
                          )
                        : Column(
                            children: visibleTopItems.map((item) {
                              return Container(
                                width: double.infinity,
                                margin: EdgeInsets.only(bottom: 10.h),
                                padding: EdgeInsets.all(10.r),
                                decoration: BoxDecoration(
                                  color: colors.backgroundPrimary,
                                  borderRadius: BorderRadius.circular(10.r),
                                  border: Border.all(color: colors.border),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.itemName,
                                            style: TextStyle(
                                              fontSize: 12.sp,
                                              fontWeight: FontWeight.w700,
                                              color: colors.textPrimary,
                                            ),
                                          ),
                                          SizedBox(height: 2.h),
                                          Text(
                                            '${item.quantity} sold',
                                            style: TextStyle(
                                              fontSize: 11.sp,
                                              fontWeight: FontWeight.w600,
                                              color: colors.textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      'GHS ${item.revenue.toStringAsFixed(2)}',
                                      style: TextStyle(
                                        fontSize: 12.sp,
                                        fontWeight: FontWeight.w700,
                                        color: colors.vendorPrimaryBlue,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                  ),
                  SizedBox(height: 12.h),
                  _SectionCard(
                    title: 'SLA Performance',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${snapshot.slaWithinTargetPercent.toStringAsFixed(1)}% within target',
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w800,
                            color: colors.textPrimary,
                          ),
                        ),
                        SizedBox(height: 8.h),
                        LinearProgressIndicator(
                          value: (snapshot.slaWithinTargetPercent / 100).clamp(
                            0,
                            1,
                          ),
                          backgroundColor: colors.vendorPrimaryBlue.withValues(
                            alpha: 0.12,
                          ),
                          color: colors.vendorPrimaryBlue,
                          minHeight: 8.h,
                          borderRadius: BorderRadius.circular(999.r),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          snapshot.slaWithinTargetPercent >= 90
                              ? 'Healthy SLA zone'
                              : 'SLA needs attention',
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w700,
                            color: snapshot.slaWithinTargetPercent >= 90
                                ? colors.success
                                : colors.error,
                          ),
                        ),
                      ],
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

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.r),
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
              fontSize: 14.sp,
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

class _RangeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _RangeChip({
    required this.label,
    required this.selected,
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
        padding: EdgeInsets.symmetric(horizontal: 11.w, vertical: 7.h),
        decoration: BoxDecoration(
          color: selected
              ? colors.vendorPrimaryBlue
              : colors.vendorPrimaryBlue.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999.r),
          border: Border.all(
            color: selected ? colors.vendorPrimaryBlue : colors.border,
          ),
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

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final Color accentColor;

  const _KpiCard({
    required this.label,
    required this.value,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 17.sp,
              fontWeight: FontWeight.w900,
              color: colors.textPrimary,
            ),
          ),
          SizedBox(height: 4.h),
          Row(
            children: [
              Container(
                width: 8.w,
                height: 8.w,
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                ),
              ),
              SizedBox(width: 6.w),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary,
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

class _MiniBarChart extends StatelessWidget {
  final List<int> values;

  const _MiniBarChart({required this.values});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    if (values.isEmpty) return const SizedBox.shrink();
    final maxValue = values.reduce((a, b) => a > b ? a : b).toDouble();
    return SizedBox(
      height: 90.h,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: values.map((value) {
          final ratio = maxValue == 0 ? 0.0 : (value / maxValue);
          return Expanded(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 2.w),
              decoration: BoxDecoration(
                color: colors.vendorPrimaryBlue.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6.r),
              ),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  height: (ratio * 86.h).clamp(4.h, 86.h),
                  decoration: BoxDecoration(
                    color: colors.vendorPrimaryBlue,
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

Set<VendorServiceType> _visibleVendorServices(
  VendorStoreContextViewModel storeContext,
) {
  final scope = storeContext.serviceScope;
  if (scope != null) return {scope};
  return storeContext.availableServicesForSelectedBranch.toSet();
}

Color _serviceColor(AppColorsExtension colors, OrderServiceType serviceType) {
  return switch (serviceType) {
    OrderServiceType.food => colors.serviceFood,
    OrderServiceType.grocery => colors.serviceGrocery,
    OrderServiceType.pharmacy => colors.servicePharmacy,
    OrderServiceType.grabmart => colors.serviceGrabMart,
  };
}
