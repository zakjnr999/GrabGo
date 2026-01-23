import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:grab_go_rider/features/orders/service/available_orders_service.dart';
import 'package:grab_go_rider/features/orders/widgets/accept_countdown_timer.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

/// A bottom sheet dialog for accepting an order with a countdown timer
class OrderAcceptDialog extends StatelessWidget {
  final AvailableOrderDto order;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onExpired;
  final int countdownSeconds;

  const OrderAcceptDialog({
    super.key,
    required this.order,
    required this.onAccept,
    required this.onDecline,
    required this.onExpired,
    this.countdownSeconds = 30,
  });

  static Future<void> show({
    required BuildContext context,
    required AvailableOrderDto order,
    required VoidCallback onAccept,
    required VoidCallback onDecline,
    required VoidCallback onExpired,
    int countdownSeconds = 30,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      builder: (context) => OrderAcceptDialog(
        order: order,
        onAccept: onAccept,
        onDecline: onDecline,
        onExpired: onExpired,
        countdownSeconds: countdownSeconds,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Container(
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(KBorderSize.borderRadius20),
          topRight: Radius.circular(KBorderSize.borderRadius20),
        ),
      ),
      padding: EdgeInsets.only(
        left: 20.w,
        right: 20.w,
        top: 16.h,
        bottom: MediaQuery.of(context).padding.bottom + 20.h,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40.w,
              height: 4.h,
              margin: EdgeInsets.only(bottom: 20.h),
              decoration: BoxDecoration(
                color: colors.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            // Header with "New Order" badge
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: colors.accentGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(color: colors.accentGreen, width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_active, color: colors.accentGreen, size: 16.w),
                  SizedBox(width: 6.w),
                  Text(
                    'NEW ORDER REQUEST',
                    style: TextStyle(
                      color: colors.accentGreen,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20.h),
            // Order details card
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: colors.backgroundSecondary,
                borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                border: Border.all(color: colors.border, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Restaurant info
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8.r),
                        decoration: BoxDecoration(
                          color: colors.accentOrange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                        ),
                        child: SvgPicture.asset(
                          Assets.icons.chefHat,
                          package: 'grab_go_shared',
                          width: 20.w,
                          height: 20.w,
                          colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pickup',
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            Text(
                              order.restaurantName,
                              style: TextStyle(color: colors.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  // Dotted line connector
                  Padding(
                    padding: EdgeInsets.only(left: 18.w),
                    child: Column(
                      children: List.generate(
                        3,
                        (index) => Container(
                          width: 2.w,
                          height: 6.h,
                          margin: EdgeInsets.symmetric(vertical: 2.h),
                          decoration: BoxDecoration(color: colors.border, borderRadius: BorderRadius.circular(1.r)),
                        ),
                      ),
                    ),
                  ),
                  // Customer info
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8.r),
                        decoration: BoxDecoration(
                          color: colors.accentViolet.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                        ),
                        child: SvgPicture.asset(
                          Assets.icons.mapPin,
                          package: 'grab_go_shared',
                          width: 20.w,
                          height: 20.w,
                          colorFilter: ColorFilter.mode(colors.accentViolet, BlendMode.srcIn),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Deliver to',
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            Text(
                              order.customerAddress,
                              style: TextStyle(color: colors.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w600),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 16.h),
            // Order items and earnings
            Row(
              children: [
                Expanded(
                  child: _buildInfoCard(
                    icon: Icons.shopping_bag_outlined,
                    label: 'Items',
                    value: '${order.orderItems.length}',
                    colors: colors,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: _buildInfoCard(
                    icon: Icons.payments_outlined,
                    label: 'Earnings',
                    value: 'GHS ${order.totalAmount.toStringAsFixed(2)}',
                    colors: colors,
                    valueColor: colors.accentGreen,
                  ),
                ),
              ],
            ),
            SizedBox(height: 24.h),
            // Countdown timer with action buttons
            AcceptCountdownTimer(
              duration: countdownSeconds,
              onExpired: () {
                Navigator.pop(context);
                onExpired();
              },
              onAccept: () {
                Navigator.pop(context);
                onAccept();
              },
              onDecline: () {
                Navigator.pop(context);
                onDecline();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    required AppColorsExtension colors,
    Color? valueColor,
  }) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: colors.backgroundSecondary,
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
        border: Border.all(color: colors.border, width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: colors.textSecondary, size: 20.w),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: colors.textSecondary, fontSize: 11.sp, fontWeight: FontWeight.w400),
                ),
                Text(
                  value,
                  style: TextStyle(
                    color: valueColor ?? colors.textPrimary,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w700,
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
