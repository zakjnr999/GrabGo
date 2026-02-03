import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_rider/features/orders/service/available_order_dto.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class OngoingOrders extends StatelessWidget {
  const OngoingOrders({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    // Dummy data for design
    final List<AvailableOrderDto> ongoingOrders = [
      AvailableOrderDto(
        id: 'ongoing-1',
        orderNumber: 'ORD-884233223234-123',
        customerName: 'Akosua Serwaa',
        customerId: 'cust-101',
        customerAddress: 'Apt 4B, East Legon, Accra',
        customerArea: 'East Legon',
        customerPhone: '+233 24 123 4567',
        restaurantName: 'Pizza Palace',
        restaurantAddress: 'Boundary Road, East Legon',
        totalAmount: 145.50,
        orderItems: ['Large Meat Lovers Pizza x1', 'Coca Cola 500ml x2'],
        itemCount: 2,
        orderStatus: 'picked_up',
        paymentMethod: 'card',
        riderEarnings: 15.50,
        distance: 3.2,
        createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
        notes: 'Please call when you reach the gate.',
      ),
      AvailableOrderDto(
        id: 'ongoing-2',
        orderNumber: 'ORD-901222334443-455',
        customerName: 'John Mahama',
        customerId: 'cust-102',
        customerAddress: 'Oxford Street, Osu',
        customerArea: 'Osu',
        customerPhone: '+233 50 987 6543',
        restaurantName: 'Starbite Food',
        restaurantAddress: 'Osu Avenue, Accra',
        totalAmount: 85.00,
        orderItems: ['Jollof Rice with Grilled Chicken x1'],
        itemCount: 1,
        orderStatus: 'confirmed',
        paymentMethod: 'cash',
        riderEarnings: 12.00,
        distance: 5.8,
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
        notes: 'No spicy sauce please.',
      ),
    ];

    if (ongoingOrders.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              Assets.icons.deliveryTruck,
              package: 'grab_go_shared',
              width: 80.w,
              height: 80.w,
              colorFilter: ColorFilter.mode(colors.textSecondary.withValues(alpha: 0.2), BlendMode.srcIn),
            ),
            SizedBox(height: 16.h),
            Text(
              "No ongoing orders",
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
        padding: EdgeInsets.fromLTRB(0, 0, 0, 20.h),
        itemCount: ongoingOrders.length,
        separatorBuilder: (context, index) => SizedBox(height: 16.h),
        itemBuilder: (context, index) {
          final order = ongoingOrders[index];
          return _buildOngoingCard(context, order, colors);
        },
      ),
    );
  }

  Widget _buildOngoingCard(BuildContext context, AvailableOrderDto order, AppColorsExtension colors) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: colors.accentGreen.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8.w,
                      height: 8.w,
                      decoration: BoxDecoration(color: colors.accentGreen, shape: BoxShape.circle),
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      order.orderStatus.replaceAll('_', ' ').toUpperCase(),
                      style: TextStyle(color: colors.accentGreen, fontSize: 11.sp, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              Text(
                "#${order.orderNumber}",
                style: TextStyle(color: colors.textSecondary, fontSize: 12.sp, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.restaurantName,
                    style: TextStyle(color: colors.textPrimary, fontSize: 15.sp, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    order.restaurantAddress,
                    style: TextStyle(color: colors.textSecondary, fontSize: 12.sp),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    order.customerName,
                    style: TextStyle(color: colors.textPrimary, fontSize: 15.sp, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    order.customerAddress,
                    style: TextStyle(color: colors.textSecondary, fontSize: 12.sp),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "EARNINGS :",
                style: TextStyle(color: colors.textSecondary, fontSize: 10.sp, fontWeight: FontWeight.w600),
              ),
              Text(
                "GHS ${order.riderEarnings?.toStringAsFixed(2)}",
                style: TextStyle(color: colors.accentGreen, fontSize: 18.sp, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  onPressed: () {
                    context.push('/order-confirmation');
                  },
                  buttonText: "Cancel Order",
                  backgroundColor: colors.inputBorder,
                  borderRadius: KBorderSize.borderRadius4,
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                  textStyle: TextStyle(color: colors.textSecondary, fontSize: 12.sp, fontWeight: FontWeight.w700),
                  width: 120.w,
                  height: 40.h,
                ),
              ),

              SizedBox(width: 12.w),
              Expanded(
                child: AppButton(
                  onPressed: () {
                    context.push(
                      '/order-confirmation',
                      extra: {
                        'orderId': order.id,
                        'orderNumber': order.orderNumber,
                        'customerName': order.customerName,
                        'customerAddress': order.customerAddress,
                        'customerPhone': order.customerPhone,
                        'restaurantName': order.restaurantName,
                        'restaurantAddress': order.restaurantAddress,
                        'orderTotal': 'GHS ${order.totalAmount.toStringAsFixed(2)}',
                        'orderItems': order.orderItems,
                        'orderStatus': order.orderStatus,
                        'riderEarnings': order.riderEarnings ?? 0.0,
                        'orderInstructions': order.notes ?? '',
                        'specialInstructions': order.notes,
                      },
                    );
                  },
                  buttonText: order.orderStatus == "confirmed" ? "Go to Pickup" : "Track Order",
                  backgroundColor: colors.accentGreen,
                  borderRadius: KBorderSize.borderRadius4,
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                  textStyle: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.w700),
                  width: 120.w,
                  height: 40.h,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
