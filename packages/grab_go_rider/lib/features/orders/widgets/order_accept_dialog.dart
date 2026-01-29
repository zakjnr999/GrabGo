import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:grab_go_rider/features/orders/service/available_order_dto.dart';
import 'package:grab_go_rider/features/orders/widgets/accept_countdown_timer.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

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
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: colors.accentGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SvgPicture.asset(
                    Assets.icons.bell,
                    package: 'grab_go_shared',
                    width: 16.w,
                    height: 16.w,
                    colorFilter: ColorFilter.mode(colors.accentGreen, BlendMode.srcIn),
                  ),
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
            Container(
              padding: EdgeInsets.all(16.w),
              decoration: BoxDecoration(
                color: colors.backgroundSecondary,
                borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8.r),
                        decoration: BoxDecoration(
                          color: colors.accentGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                        ),
                        child: SvgPicture.asset(
                          Assets.icons.chefHat,
                          package: 'grab_go_shared',
                          width: 20.w,
                          height: 20.w,
                          colorFilter: ColorFilter.mode(colors.accentGreen, BlendMode.srcIn),
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
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8.r),
                        decoration: BoxDecoration(
                          color: colors.accentGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                        ),
                        child: SvgPicture.asset(
                          Assets.icons.mapPin,
                          package: 'grab_go_shared',
                          width: 20.w,
                          height: 20.w,
                          colorFilter: ColorFilter.mode(colors.accentGreen, BlendMode.srcIn),
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
            Row(
              children: [
                Expanded(
                  child: _buildInfoCard(
                    icon: Assets.icons.cart,
                    label: 'Items',
                    value: '${order.orderItems.length}',
                    colors: colors,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: _buildInfoCard(
                    icon: Assets.icons.cash,
                    label: 'Earnings',
                    value: 'GHS ${order.totalAmount.toStringAsFixed(2)}',
                    colors: colors,
                    valueColor: colors.accentGreen,
                  ),
                ),
              ],
            ),
            SizedBox(height: 24.h),
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
    required String icon,
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
      ),
      child: Row(
        children: [
          SvgPicture.asset(
            icon,
            package: 'grab_go_shared',
            width: 20.w,
            height: 20.w,
            colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
          ),
          SizedBox(width: 10.w),
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
