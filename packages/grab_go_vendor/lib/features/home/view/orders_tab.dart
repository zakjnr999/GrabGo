import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_vendor/features/auth/model/vendor_service_option.dart';
import 'package:grab_go_vendor/features/home/widget/order_card.dart';
import 'package:grab_go_vendor/features/home/widget/order_meta_chip.dart';
import 'package:grab_go_vendor/features/orders/model/vendor_order_summary.dart';
import 'package:grab_go_vendor/features/orders/view/order_detail_page.dart';
import 'package:grab_go_vendor/features/orders/viewmodel/orders_tab_viewmodel.dart';
import 'package:grab_go_vendor/features/store_context/viewmodel/store_context_viewmodel.dart';
import 'package:grab_go_vendor/features/store_operations/view/store_operations_page.dart';
import 'package:grab_go_vendor/features/store_operations/viewmodel/store_operations_viewmodel.dart';
import 'package:grab_go_vendor/shared/viewmodel/vendor_preview_session_viewmodel.dart';
import 'package:grab_go_vendor/shared/widgets/app_filter_chip.dart';
import 'package:grab_go_vendor/shared/widgets/vendor_outage_banner.dart';
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
        final hasMultipleServices = orderedServices.length > 1;
        final orders = viewModel.orders
            .where((order) => visibleOrderServices.contains(order.serviceType))
            .toList();

        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(vertical: 14.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: Text(
                    'Live Orders',
                    style: TextStyle(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.w900,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: Text(
                    visibleVendorServices.isEmpty
                        ? 'No services are active for this profile and store context.'
                        : 'Showing ${previewSession.servicesLabel(visibleVendorServices)} queue.',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
                SizedBox(height: 14.h),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: VendorOutageBanner(
                    onManageTap: () => Navigator.push(
                      context,
                      CupertinoPageRoute(
                        builder: (_) => ChangeNotifierProvider.value(
                          value: context.read<VendorStoreOperationsViewModel>(),
                          child: const StoreOperationsPage(),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  child: AppTextInput(
                    controller: viewModel.searchController,
                    prefixIcon: Padding(
                      padding: EdgeInsets.all(10.r),
                      child: SvgPicture.asset(
                        Assets.icons.search,
                        package: 'grab_go_shared',
                        width: 18.w,
                        height: 18.w,
                        colorFilter: ColorFilter.mode(
                          colors.textSecondary,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                    hintText: 'Search by order ID or customer',
                    fillColor: colors.backgroundSecondary,
                    borderActiveColor: colors.vendorPrimaryBlue,
                    borderRadius: KBorderSize.border,
                    cursorColor: colors.vendorPrimaryBlue,
                  ),
                ),

                SizedBox(height: 10.h),
                if (hasMultipleServices) ...[
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        AppFilterChip(
                          label: 'All',
                          selected: viewModel.selectedServiceFilter == null,
                          onTap: () => viewModel.setServiceFilter(null),
                        ),
                        ...orderedServices.map((service) {
                          return AppFilterChip(
                            label: service.label,
                            selected:
                                viewModel.selectedServiceFilter == service,
                            onTap: () => viewModel.setServiceFilter(service),
                          );
                        }),
                      ],
                    ),
                  ),
                  SizedBox(height: 8.h),
                ],
                SizedBox(height: 8.h),
                SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      AppFilterChip(
                        label: 'All Status',
                        selected: viewModel.selectedStatusFilter == null,
                        onTap: () => viewModel.setStatusFilter(null),
                      ),
                      SizedBox(width: 8.w),
                      AppFilterChip(
                        label: 'New',
                        selected:
                            viewModel.selectedStatusFilter ==
                            VendorOrderStatus.newOrder,
                        onTap: () => viewModel.setStatusFilter(
                          VendorOrderStatus.newOrder,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      AppFilterChip(
                        label: 'Preparing',
                        selected:
                            viewModel.selectedStatusFilter ==
                            VendorOrderStatus.preparing,
                        onTap: () => viewModel.setStatusFilter(
                          VendorOrderStatus.preparing,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      AppFilterChip(
                        label: 'Ready',
                        selected:
                            viewModel.selectedStatusFilter ==
                            VendorOrderStatus.ready,
                        onTap: () =>
                            viewModel.setStatusFilter(VendorOrderStatus.ready),
                      ),
                      SizedBox(width: 8.w),
                      AppFilterChip(
                        label: 'At Risk',
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
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(18.r),
                      child: Text(
                        'No orders match the selected filters.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  )
                else
                  ...orders.map((order) {
                    return Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.w),
                      child: OrderCard(
                        order: order,
                        showServiceChip: hasMultipleServices,
                        onTap: () => _openOrderDetail(context, order),
                        onView: () => _showOrderPreviewSheet(context, order),
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

  void _openOrderDetail(BuildContext context, VendorOrderSummary order) {
    Navigator.push(
      context,
      CupertinoPageRoute(builder: (_) => OrderDetailPage(order: order)),
    );
  }

  Future<void> _showOrderPreviewSheet(
    BuildContext context,
    VendorOrderSummary order,
  ) async {
    final colors = context.appColors;
    final statusColor = _orderStatusColor(colors, order.status);
    final customerNote = order.customerNote?.trim();
    final primaryAction = context.read<OrdersTabViewModel>().primaryActionFor(
      order,
    );
    final showProgressAction = primaryAction.isActionable;
    final showWaitingForRider =
        primaryAction == VendorOrderPreviewPrimaryAction.waitingForRider;
    final showAssignedRider =
        !order.isPickupOrder &&
        (order.status == VendorOrderStatus.ready ||
            order.status == VendorOrderStatus.pickedUp);
    final showRiderPending =
        !order.isPickupOrder &&
        (order.status == VendorOrderStatus.accepted ||
            order.status == VendorOrderStatus.preparing);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: colors.backgroundPrimary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(KBorderSize.borderRadius20),
        ),
      ),
      builder: (sheetContext) {
        final maxHeight = MediaQuery.sizeOf(sheetContext).height * 0.82;
        return SafeArea(
          top: false,
          child: SizedBox(
            height: maxHeight,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                16.w,
                12.h,
                16.w,
                16.h + MediaQuery.viewInsetsOf(sheetContext).bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.center,
                    child: Container(
                      width: 40.w,
                      height: 4.h,
                      margin: EdgeInsets.only(bottom: 12.h),
                      decoration: BoxDecoration(
                        color: colors.border,
                        borderRadius: BorderRadius.circular(KBorderSize.border),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Order Preview',
                          style: TextStyle(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w800,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                      OrderMetaChip(
                        label: order.status.label,
                        color: statusColor,
                      ),
                      if (order.isAtRisk)
                        OrderMetaChip(label: 'At Risk', color: colors.warning),
                    ],
                  ),
                  SizedBox(height: 10.h),
                  Text(
                    order.id,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w800,
                      color: colors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 10.h),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _PreviewSectionCard(
                            title: 'Customer Details',
                            child: Column(
                              children: [
                                _PreviewInfoRow(
                                  label: 'Customer',
                                  value:
                                      '${order.customerName} • ${order.customerPhone}',
                                  icon: Assets.icons.user,
                                ),
                                if (order.isPickupOrder) ...[
                                  SizedBox(height: 8.h),
                                  _PreviewInfoRow(
                                    label: 'Fulfillment',
                                    value: 'Customer pickup order',
                                    icon: Assets.icons.running,
                                  ),
                                ] else if (showAssignedRider) ...[
                                  SizedBox(height: 8.h),
                                  _PreviewInfoRow(
                                    label: 'Rider',
                                    value:
                                        '${order.riderName} • ${order.riderEtaLabel}',
                                    icon: Assets.icons.deliveryGuyIcon,
                                  ),
                                ] else if (showRiderPending) ...[
                                  SizedBox(height: 8.h),
                                  _PreviewInfoRow(
                                    label: 'Rider',
                                    value: 'Rider assignment pending',
                                    icon: Assets.icons.hourglass,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          SizedBox(height: 10.h),
                          _PreviewSectionCard(
                            title: 'Customer Note',
                            child: Text(
                              (customerNote != null && customerNote.isNotEmpty)
                                  ? customerNote
                                  : 'No customer note provided.',
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w500,
                                color: colors.textSecondary,
                              ),
                            ),
                          ),
                          SizedBox(height: 10.h),
                          _PreviewSectionCard(
                            title: 'Items (${order.items.length})',
                            child: Column(
                              children: order.items.map((item) {
                                return Padding(
                                  padding: EdgeInsets.only(bottom: 10.h),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 24.w,
                                        height: 24.w,
                                        decoration: BoxDecoration(
                                          color: colors.backgroundSecondary,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text(
                                            '${item.quantity}x',
                                            style: TextStyle(
                                              fontSize: 11.sp,
                                              fontWeight: FontWeight.w700,
                                              color: colors.textPrimary,
                                            ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 8.w),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.name,
                                              style: TextStyle(
                                                fontSize: 12.sp,
                                                fontWeight: FontWeight.w700,
                                                color: colors.textPrimary,
                                              ),
                                            ),
                                            if (item.note != null &&
                                                item.note!.trim().isNotEmpty)
                                              Padding(
                                                padding: EdgeInsets.only(
                                                  top: 2.h,
                                                ),
                                                child: Text(
                                                  'Note: ${item.note}',
                                                  style: TextStyle(
                                                    fontSize: 11.sp,
                                                    fontWeight: FontWeight.w600,
                                                    color: colors.textSecondary,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      Text(
                                        'GHS ${(item.unitPrice * item.quantity).toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontSize: 11.sp,
                                          fontWeight: FontWeight.w700,
                                          color: colors.textPrimary,
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
                  SizedBox(height: 10.h),
                  if (showProgressAction)
                    SizedBox(
                      width: double.infinity,
                      child: AppButton(
                        buttonText: primaryAction.label,
                        onPressed: () {
                          if (primaryAction ==
                              VendorOrderPreviewPrimaryAction
                                  .verifyPickupCode) {
                            Navigator.pop(sheetContext);
                            _openOrderDetail(context, order);
                            return;
                          }

                          final changed = context
                              .read<OrdersTabViewModel>()
                              .runPrimaryAction(order.id, primaryAction);
                          Navigator.pop(sheetContext);
                          if (changed) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${primaryAction.label} applied for ${order.id}.',
                                ),
                              ),
                            );
                          }
                        },
                        backgroundColor: colors.vendorPrimaryBlue,
                        borderRadius: KBorderSize.border,
                        textStyle: TextStyle(
                          color: Colors.white,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  if (showWaitingForRider)
                    Align(
                      alignment: Alignment.center,
                      child: Text(
                        'Order is ready. Waiting for rider pickup.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                  if (showProgressAction || showWaitingForRider)
                    SizedBox(height: 8.h),
                  SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      buttonText: 'Open Full Details',
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _openOrderDetail(context, order);
                      },
                      backgroundColor: colors.backgroundPrimary,
                      borderColor: colors.vendorPrimaryBlue,
                      borderRadius: KBorderSize.border,
                      textStyle: TextStyle(
                        color: colors.vendorPrimaryBlue,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                      ),
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
  if (scope != null) return {scope};
  return storeContext.availableServicesForSelectedBranch.toSet();
}

Color _orderStatusColor(AppColorsExtension colors, VendorOrderStatus status) {
  return switch (status) {
    VendorOrderStatus.newOrder => colors.vendorPrimaryBlue,
    VendorOrderStatus.accepted => colors.info,
    VendorOrderStatus.preparing => colors.warning,
    VendorOrderStatus.ready => colors.success,
    VendorOrderStatus.pickedUp => colors.accentGreen,
    VendorOrderStatus.cancelled => colors.error,
  };
}

class _PreviewSectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _PreviewSectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(12.r),
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
          SizedBox(height: 8.h),
          child,
        ],
      ),
    );
  }
}

class _PreviewInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final String icon;

  const _PreviewInfoRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SvgPicture.asset(
          icon,
          package: 'grab_go_shared',
          width: 14.w,
          height: 14.h,
          colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w700,
                  color: colors.textSecondary,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                value,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w700,
                  color: colors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
