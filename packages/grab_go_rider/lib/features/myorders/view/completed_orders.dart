import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:grab_go_rider/features/orders/service/available_order_dto.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:intl/intl.dart';

class CompletedOrders extends StatelessWidget {
  const CompletedOrders({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    final List<AvailableOrderDto> completedOrders = [
      AvailableOrderDto(
        id: 'comp-1',
        orderNumber: 'GG-7721',
        customerName: 'Kofi Mensah',
        customerId: 'cust-201',
        customerAddress: 'Spintex Road, Batsona',
        customerArea: 'Spintex',
        customerPhone: '+233 24 444 5555',
        restaurantName: 'KFC Spintex',
        restaurantAddress: 'Shell Signboard, Spintex',
        totalAmount: 120.00,
        orderItems: ['Streetwise 3 x2', 'Krushers Strawberry x1'],
        itemCount: 3,
        orderStatus: 'delivered',
        paymentMethod: 'mobile_money',
        riderEarnings: 18.20,
        distance: 4.5,
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
        notes: '',
      ),
      AvailableOrderDto(
        id: 'comp-2',
        orderNumber: 'GG-7650',
        customerName: 'Evelyn Asare',
        customerId: 'cust-202',
        customerAddress: 'Airport Residential, Accra',
        customerArea: 'Airport',
        customerPhone: '+233 20 555 6666',
        restaurantName: 'Burger King',
        restaurantAddress: 'Airport Shell',
        totalAmount: 95.00,
        orderItems: ['Whopper x1', 'Fries Large x1'],
        itemCount: 2,
        orderStatus: 'delivered',
        paymentMethod: 'card',
        riderEarnings: 14.50,
        distance: 2.8,
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
        notes: '',
      ),
    ];

    if (completedOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              Assets.icons.check,
              package: 'grab_go_shared',
              width: 80.w,
              height: 80.w,
              colorFilter: ColorFilter.mode(colors.textSecondary.withValues(alpha: 0.2), BlendMode.srcIn),
            ),
            SizedBox(height: 16.h),
            Text(
              "No completed orders yet",
              style: TextStyle(color: colors.textSecondary, fontSize: 16.sp, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return AppRefreshIndicator(
      onRefresh: () {
        return Future.delayed(const Duration(seconds: 1));
      },
      iconPath: Assets.icons.deliveryTruck,
      bgColor: colors.accentGreen,
      child: ListView.separated(
        padding: EdgeInsets.only(bottom: 20.h),
        itemCount: completedOrders.length,
        separatorBuilder: (context, index) => SizedBox(height: 12.h),
        itemBuilder: (context, index) {
          final order = completedOrders[index];
          return Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: colors.backgroundPrimary,
              borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      DateFormat('MMM dd, yyyy  •  hh:mm a').format(order.createdAt!),
                      style: TextStyle(color: colors.textSecondary, fontSize: 11.sp, fontWeight: FontWeight.w500),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                      decoration: BoxDecoration(
                        color: colors.success.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        "DELIVERED",
                        style: TextStyle(color: colors.accentGreen, fontSize: 9.sp, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                DottedLine(
                  direction: Axis.horizontal,
                  lineLength: double.infinity,
                  lineThickness: 1.5,
                  dashLength: 6,
                  dashColor: colors.inputBorder.withValues(alpha: 0.65),
                  dashGapLength: 4,
                ),
                SizedBox(height: 12.h),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.restaurantName,
                            style: TextStyle(color: colors.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w700),
                          ),
                          SizedBox(height: 4.h),
                          Row(
                            children: [
                              SvgPicture.asset(
                                Assets.icons.user,
                                package: 'grab_go_shared',
                                width: 12.w,
                                height: 12.w,
                                colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                order.customerName,
                                style: TextStyle(color: colors.textSecondary, fontSize: 12.sp),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          "GHS ${order.riderEarnings?.toStringAsFixed(2)}",
                          style: TextStyle(color: colors.textPrimary, fontSize: 16.sp, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          "Earned",
                          style: TextStyle(color: colors.textSecondary, fontSize: 11.sp),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
