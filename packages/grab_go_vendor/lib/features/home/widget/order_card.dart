import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/shared/utils/app_colors_extension.dart';
import 'package:grab_go_shared/shared/utils/constants.dart';
import 'package:grab_go_shared/shared/widgets/app_button.dart';
import 'package:grab_go_vendor/features/home/widget/order_meta_chip.dart';
import 'package:grab_go_vendor/features/orders/model/vendor_order_summary.dart';

class OrderCard extends StatelessWidget {
  final VendorOrderSummary order;
  final bool showServiceChip;
  final VoidCallback onView;
  final VoidCallback onTap;

  const OrderCard({
    super.key,
    required this.order,
    required this.showServiceChip,
    required this.onView,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final serviceColor = _orderServiceColor(colors, order.serviceType);
    final statusColor = _orderStatusColor(colors, order.status);
    final previewItems = order.items.take(2).toList();
    final remainingItems = order.items.length - previewItems.length;
    final note = order.customerNote?.trim();
    final hasNote = note != null && note.isNotEmpty;

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
                if (showServiceChip) ...[
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: serviceColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999.r),
                    ),
                    child: Text(
                      order.serviceType.label,
                      style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w700, color: serviceColor),
                    ),
                  ),
                  SizedBox(width: 8.w),
                ],
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(999.r),
                  ),
                  child: Text(
                    order.status.label,
                    style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w700, color: statusColor),
                  ),
                ),
                if (order.isAtRisk)
                  Padding(
                    padding: EdgeInsets.only(left: 8.w),
                    child: Icon(Icons.warning_amber_rounded, size: 16.sp, color: colors.warning),
                  ),
                const Spacer(),
                Text(
                  order.elapsedLabel,
                  style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w700, color: colors.textSecondary),
                ),
              ],
            ),
            SizedBox(height: 10.h),
            Row(
              children: [
                Expanded(
                  child: Text(
                    order.id,
                    style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w800, color: colors.textPrimary),
                  ),
                ),
                Text(
                  'GHS ${order.total.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w800, color: colors.textPrimary),
                ),
              ],
            ),
            SizedBox(height: 3.h),
            Text(
              '${order.customerName} • ${order.customerPhone}',
              style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: colors.textSecondary),
            ),
            SizedBox(height: 10.h),
            ...previewItems.map((item) {
              return Padding(
                padding: EdgeInsets.only(bottom: 4.h),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${item.quantity}x',
                      style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w800, color: colors.textPrimary),
                    ),
                    SizedBox(width: 6.w),
                    Expanded(
                      child: Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600, color: colors.textSecondary),
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (remainingItems > 0)
              Padding(
                padding: EdgeInsets.only(top: 2.h),
                child: InkWell(
                  onTap: onView,
                  borderRadius: BorderRadius.circular(999.r),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 2.h),
                    child: Text(
                      '+$remainingItems more items • View all',
                      style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w700, color: colors.vendorPrimaryBlue),
                    ),
                  ),
                ),
              ),
            if (hasNote)
              Padding(
                padding: EdgeInsets.only(top: 8.h),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SvgPicture.asset(
                      Assets.icons.squareMenu,
                      package: 'grab_go_shared',
                      width: 14.w,
                      height: 14.h,
                      colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                    ),
                    SizedBox(width: 6.w),
                    Expanded(
                      child: Text(
                        note,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600, color: colors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            if (order.isPickupOrder || order.requiresPrescription)
              Padding(
                padding: EdgeInsets.only(top: 8.h),
                child: Wrap(
                  spacing: 8.w,
                  runSpacing: 6.h,
                  children: [
                    if (order.isPickupOrder) OrderMetaChip(label: 'Pickup', color: colors.vendorPrimaryBlue),
                    if (order.requiresPrescription) OrderMetaChip(label: 'Prescription', color: colors.servicePharmacy),
                  ],
                ),
              ),
            SizedBox(height: 10.h),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    buttonText: 'Preview',
                    onPressed: onView,
                    height: 36.h,
                    padding: EdgeInsets.zero,
                    backgroundColor: colors.vendorPrimaryBlue.withValues(alpha: 0.12),
                    borderRadius: KBorderSize.border,
                    textStyle: TextStyle(color: colors.vendorPrimaryBlue, fontSize: 13.sp, fontWeight: FontWeight.w700),
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: AppButton(
                    buttonText: 'Details',
                    onPressed: onTap,
                    height: 36.h,
                    padding: EdgeInsets.zero,
                    backgroundColor: colors.vendorPrimaryBlue,
                    borderRadius: KBorderSize.border,
                    textStyle: TextStyle(color: Colors.white, fontSize: 13.sp, fontWeight: FontWeight.w700),
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

Color _orderServiceColor(AppColorsExtension colors, OrderServiceType service) {
  return switch (service) {
    OrderServiceType.food => colors.serviceFood,
    OrderServiceType.grocery => colors.serviceGrocery,
    OrderServiceType.pharmacy => colors.servicePharmacy,
    OrderServiceType.grabmart => colors.serviceGrabMart,
  };
}
