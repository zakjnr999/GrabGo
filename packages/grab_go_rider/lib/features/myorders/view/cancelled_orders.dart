import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:grab_go_rider/features/orders/service/available_order_dto.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:intl/intl.dart';

class CancelledOrders extends StatelessWidget {
  const CancelledOrders({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    final List<AvailableOrderDto> cancelledOrders = [
      AvailableOrderDto(
        id: 'canc-1',
        orderNumber: 'ORD-66102323234-789',
        customerName: 'Ama Boateng',
        customerId: 'cust-301',
        customerAddress: 'Cantonments, Accra',
        customerArea: 'Cantonments',
        customerPhone: '+233 20 111 2222',
        restaurantName: 'Burger King',
        restaurantAddress: 'Shell Cantonments',
        totalAmount: 95.00,
        orderItems: ['Whopper Junior x3'],
        itemCount: 1,
        orderStatus: 'cancelled',
        paymentMethod: 'card',
        riderEarnings: 0.00,
        distance: 2.1,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        notes: 'Restuarant reached full capacity.',
      ),
    ];

    if (cancelledOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              Assets.icons.circleAlert,
              package: 'grab_go_shared',
              width: 80.w,
              height: 80.w,
              colorFilter: ColorFilter.mode(colors.textSecondary.withValues(alpha: 0.2), BlendMode.srcIn),
            ),
            SizedBox(height: 16.h),
            Text(
              "No cancelled orders",
              style: TextStyle(color: colors.textSecondary, fontSize: 16.sp, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: EdgeInsets.only(bottom: 20.h),
      itemCount: cancelledOrders.length,
      separatorBuilder: (context, index) => SizedBox(height: 12.h),
      itemBuilder: (context, index) {
        final order = cancelledOrders[index];
        return Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: colors.backgroundPrimary,
            borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
          ),
          child: Opacity(
            opacity: 0.7,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "#${order.orderNumber}",
                      style: TextStyle(color: colors.textPrimary, fontSize: 12.sp, fontWeight: FontWeight.w700),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                      decoration: BoxDecoration(
                        color: colors.error.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        "CANCELLED",
                        style: TextStyle(color: colors.error, fontSize: 9.sp, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                Text(
                  order.restaurantName,
                  style: TextStyle(color: colors.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 4.h),
                Text(
                  order.notes ?? "No reason provided",
                  style: TextStyle(color: colors.error, fontSize: 12.sp, fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 8.h),
                Text(
                  DateFormat('MMM dd, yyyy  •  hh:mm a').format(order.createdAt!),
                  style: TextStyle(color: colors.textSecondary, fontSize: 11.sp),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
