import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_vendor/features/auth/model/vendor_service_option.dart';
import 'package:grab_go_vendor/features/orders/model/vendor_order_summary.dart';
import 'package:grab_go_vendor/features/orders/view/order_detail_page.dart';
import 'package:grab_go_vendor/features/orders/viewmodel/orders_tab_viewmodel.dart';
import 'package:grab_go_vendor/features/store_context/viewmodel/store_context_viewmodel.dart';
import 'package:grab_go_vendor/features/store_operations/view/store_operations_page.dart';
import 'package:grab_go_vendor/features/store_operations/viewmodel/store_operations_viewmodel.dart';
import 'package:grab_go_vendor/shared/viewmodel/vendor_preview_session_viewmodel.dart';
import 'package:grab_go_vendor/shared/widgets/vendor_outage_banner.dart';
import 'package:grab_go_vendor/shared/widgets/vendor_store_context_chip.dart';
import 'package:provider/provider.dart';

class OrdersTab extends StatelessWidget {
  const OrdersTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => OrdersTabViewModel(),
      child: const _OrdersTabView(),
    );
  }
}

class _OrdersTabView extends StatelessWidget {
  const _OrdersTabView();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Consumer3<
      OrdersTabViewModel,
      VendorStoreContextViewModel,
      VendorPreviewSessionViewModel
    >(
      builder: (context, viewModel, storeContext, previewSession, _) {
        final visibleVendorServices = _visibleVendorServices(storeContext);
        final visibleOrderServices = visibleVendorServices
            .map(previewSession.mapToOrderService)
            .toSet();
        final serviceFilter = viewModel.selectedServiceFilter;
        if (serviceFilter != null &&
            !visibleOrderServices.contains(serviceFilter)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            viewModel.setServiceFilter(null);
          });
        }

        final orderedServices = visibleOrderServices.toList()
          ..sort((a, b) => a.index.compareTo(b.index));
        final orders = viewModel.orders
            .where((order) => visibleOrderServices.contains(order.serviceType))
            .toList();

        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Live Orders',
                      style: TextStyle(
                        fontSize: 28.sp,
                        fontWeight: FontWeight.w900,
                        color: colors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    const VendorStoreContextChip(),
                  ],
                ),
                SizedBox(height: 6.h),
                Text(
                  visibleVendorServices.isEmpty
                      ? 'No services are active for this profile and store context.'
                      : 'Showing ${previewSession.servicesLabel(visibleVendorServices)} queue.',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w500,
                    color: colors.textSecondary,
                  ),
                ),
                SizedBox(height: 14.h),
                VendorOutageBanner(
                  onManageTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChangeNotifierProvider.value(
                        value: context.read<VendorStoreOperationsViewModel>(),
                        child: const StoreOperationsPage(),
                      ),
                    ),
                  ),
                ),
                TextField(
                  controller: viewModel.searchController,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search by order ID or customer',
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
                        label: 'All',
                        color: colors.vendorPrimaryBlue,
                        selected: viewModel.selectedServiceFilter == null,
                        onTap: () => viewModel.setServiceFilter(null),
                      ),
                      ...orderedServices.map((service) {
                        return _FilterChip(
                          label: service.label,
                          color: _orderServiceColor(colors, service),
                          selected: viewModel.selectedServiceFilter == service,
                          onTap: () => viewModel.setServiceFilter(service),
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
                        label: 'All Status',
                        color: colors.vendorPrimaryBlue,
                        selected: viewModel.selectedStatusFilter == null,
                        onTap: () => viewModel.setStatusFilter(null),
                      ),
                      _FilterChip(
                        label: 'New',
                        color: colors.vendorPrimaryBlue,
                        selected:
                            viewModel.selectedStatusFilter ==
                            VendorOrderStatus.newOrder,
                        onTap: () => viewModel.setStatusFilter(
                          VendorOrderStatus.newOrder,
                        ),
                      ),
                      _FilterChip(
                        label: 'Preparing',
                        color: colors.vendorPrimaryBlue,
                        selected:
                            viewModel.selectedStatusFilter ==
                            VendorOrderStatus.preparing,
                        onTap: () => viewModel.setStatusFilter(
                          VendorOrderStatus.preparing,
                        ),
                      ),
                      _FilterChip(
                        label: 'Ready',
                        color: colors.vendorPrimaryBlue,
                        selected:
                            viewModel.selectedStatusFilter ==
                            VendorOrderStatus.ready,
                        onTap: () =>
                            viewModel.setStatusFilter(VendorOrderStatus.ready),
                      ),
                      _FilterChip(
                        label: 'At Risk',
                        color: colors.warning,
                        selected: viewModel.atRiskOnly,
                        onTap: viewModel.toggleAtRiskOnly,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 14.h),
                if (visibleOrderServices.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(18.r),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(color: colors.border),
                      color: colors.backgroundPrimary,
                    ),
                    child: Text(
                      'No services are active for this vendor profile on the selected branch.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: colors.textSecondary,
                      ),
                    ),
                  )
                else if (orders.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(18.r),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14.r),
                      border: Border.all(color: colors.border),
                      color: colors.backgroundPrimary,
                    ),
                    child: Text(
                      'No orders match the selected filters.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: colors.textSecondary,
                      ),
                    ),
                  )
                else
                  ...orders.map((order) {
                    return _OrderCard(
                      order: order,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OrderDetailPage(order: order),
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.color,
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

class _OrderCard extends StatelessWidget {
  final VendorOrderSummary order;
  final VoidCallback onTap;

  const _OrderCard({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final serviceColor = _orderServiceColor(colors, order.serviceType);
    final statusColor = switch (order.status) {
      VendorOrderStatus.newOrder => colors.vendorPrimaryBlue,
      VendorOrderStatus.accepted => colors.info,
      VendorOrderStatus.preparing => colors.warning,
      VendorOrderStatus.ready => colors.success,
      VendorOrderStatus.handover => colors.accentGreen,
      VendorOrderStatus.cancelled => colors.error,
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14.r),
      child: Container(
        width: double.infinity,
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.all(12.r),
        decoration: BoxDecoration(
          color: colors.backgroundPrimary,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: colors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: serviceColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999.r),
                  ),
                  child: Text(
                    order.serviceType.label,
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w700,
                      color: serviceColor,
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999.r),
                  ),
                  child: Text(
                    order.status.label,
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
                if (order.isAtRisk)
                  Padding(
                    padding: EdgeInsets.only(left: 8.w),
                    child: Icon(
                      Icons.warning_amber_rounded,
                      size: 16.sp,
                      color: colors.warning,
                    ),
                  ),
                const Spacer(),
                Text(
                  order.elapsedLabel,
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w700,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
            SizedBox(height: 10.h),
            Text(
              order.id,
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w800,
                color: colors.textPrimary,
              ),
            ),
            SizedBox(height: 3.h),
            Text(
              '${order.customerName} • ${order.itemCount} items',
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: colors.textSecondary,
              ),
            ),
            SizedBox(height: 10.h),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onTap,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: colors.inputBorder),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 10.h),
                    ),
                    child: Text(
                      'View',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colors.vendorPrimaryBlue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.r),
                      ),
                      padding: EdgeInsets.symmetric(vertical: 10.h),
                      elevation: 0,
                    ),
                    child: Text(
                      order.status == VendorOrderStatus.newOrder
                          ? 'Review'
                          : 'Open',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
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

Color _orderServiceColor(AppColorsExtension colors, OrderServiceType service) {
  return switch (service) {
    OrderServiceType.food => colors.serviceFood,
    OrderServiceType.grocery => colors.serviceGrocery,
    OrderServiceType.pharmacy => colors.servicePharmacy,
    OrderServiceType.grabmart => colors.serviceGrabMart,
  };
}
