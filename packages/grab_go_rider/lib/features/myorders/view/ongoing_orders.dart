import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_rider/features/myorders/service/my_orders_service.dart';
import 'package:grab_go_rider/features/orders/service/available_order_dto.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class OngoingOrders extends StatefulWidget {
  const OngoingOrders({super.key});

  @override
  State<OngoingOrders> createState() => _OngoingOrdersState();
}

class _OngoingOrdersState extends State<OngoingOrders> {
  final MyOrdersService _service = MyOrdersService();
  List<AvailableOrderDto> _orders = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final orders = await _service.getOngoingOrders();
      if (!mounted) return;
      setState(() {
        _orders = orders;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load orders';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    if (_isLoading) {
      return _buildOngoingOrdersSkeleton(colors);
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              Assets.icons.circleAlert,
              package: 'grab_go_shared',
              width: 60.w,
              height: 60.w,
              colorFilter: ColorFilter.mode(colors.error, BlendMode.srcIn),
            ),
            SizedBox(height: 16.h),
            Text(
              _error!,
              style: TextStyle(color: colors.textSecondary, fontSize: 14.sp),
            ),
            SizedBox(height: 16.h),
            AppButton(
              onPressed: _loadOrders,
              buttonText: "Retry",
              backgroundColor: colors.accentGreen,
              borderRadius: KBorderSize.borderRadius4,
              width: 120.w,
              height: 40.h,
            ),
          ],
        ),
      );
    }

    if (_orders.isEmpty) {
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
            SizedBox(height: 8.h),
            Text(
              "Accept orders to see them here",
              style: TextStyle(color: colors.textSecondary.withValues(alpha: 0.7), fontSize: 13.sp),
            ),
          ],
        ),
      );
    }

    return AppRefreshIndicator(
      onRefresh: _loadOrders,
      iconPath: Assets.icons.deliveryTruck,
      bgColor: colors.accentGreen,
      child: ListView.separated(
        padding: EdgeInsets.fromLTRB(0, 0, 0, 20.h),
        itemCount: _orders.length,
        separatorBuilder: (context, index) => SizedBox(height: 16.h),
        itemBuilder: (context, index) {
          final order = _orders[index];
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
                  color: _getStatusColor(order.orderStatus, colors).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8.w,
                      height: 8.w,
                      decoration: BoxDecoration(
                        color: _getStatusColor(order.orderStatus, colors),
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      _formatStatus(order.orderStatus),
                      style: TextStyle(
                        color: _getStatusColor(order.orderStatus, colors),
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w700,
                      ),
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
              if (order.restaurantLogo != null && order.restaurantLogo!.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8.r),
                  child: Image.network(
                    order.restaurantLogo!,
                    width: 40.w,
                    height: 40.w,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 40.w,
                      height: 40.w,
                      color: colors.backgroundSecondary,
                      child: Icon(Icons.store, color: colors.textSecondary, size: 20.w),
                    ),
                  ),
                )
              else
                Container(
                  width: 40.w,
                  height: 40.w,
                  decoration: BoxDecoration(
                    color: colors.backgroundSecondary,
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Icon(Icons.store, color: colors.textSecondary, size: 20.w),
                ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
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
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Icon(Icons.person_outline, size: 16.w, color: colors.textSecondary),
              SizedBox(width: 8.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.customerName,
                      style: TextStyle(color: colors.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w600),
                    ),
                    Text(
                      order.customerAddress,
                      style: TextStyle(color: colors.textSecondary, fontSize: 12.sp),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "EARNINGS",
                    style: TextStyle(color: colors.textSecondary, fontSize: 10.sp, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    "GHS ${order.riderEarnings?.toStringAsFixed(2) ?? '0.00'}",
                    style: TextStyle(color: colors.accentGreen, fontSize: 18.sp, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              Text(
                "${order.itemCount} item${order.itemCount > 1 ? 's' : ''}",
                style: TextStyle(color: colors.textSecondary, fontSize: 12.sp),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  onPressed: () {
                    // TODO: Implement cancel order
                  },
                  buttonText: "Cancel Order",
                  backgroundColor: colors.inputBorder,
                  borderRadius: KBorderSize.borderRadius4,
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                  textStyle: TextStyle(color: colors.textSecondary, fontSize: 12.sp, fontWeight: FontWeight.w700),
                  height: 40.h,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: AppButton(
                  onPressed: () {
                    context.push(
                      '/orderConfirmation',
                      extra: {
                        'orderId': order.id,
                        'orderNumber': order.orderNumber,
                        'orderStatus': order.orderStatus,
                        'orderInstructions': order.notes ?? '',
                        'customerName': order.customerName,
                        'customerAddress': order.customerAddress,
                        'customerPhone': order.customerPhone,
                        'profilePhoto': order.customerPhoto,
                        'restaurantName': order.restaurantName,
                        'restaurantAddress': order.restaurantAddress,
                        'restaurantLogo': order.restaurantLogo,
                        'orderTotal': 'GHS ${order.totalAmount.toStringAsFixed(2)}',
                        'orderItems': order.orderItems,
                        'specialInstructions': order.notes,
                        'customerId': order.customerId,
                        'riderEarnings': order.riderEarnings,
                        'pickupLatitude': order.pickupLatitude,
                        'pickupLongitude': order.pickupLongitude,
                        'destinationLatitude': order.destinationLatitude,
                        'destinationLongitude': order.destinationLongitude,
                      },
                    );
                  },
                  buttonText: _getActionButtonText(order.orderStatus),
                  backgroundColor: colors.accentGreen,
                  borderRadius: KBorderSize.borderRadius4,
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                  textStyle: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.w700),
                  height: 40.h,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  _buildOngoingOrdersSkeleton(AppColorsExtension colors) {
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 20.h),
      itemCount: 3,
      separatorBuilder: (context, index) => SizedBox(height: 16.h),
      itemBuilder: (context, index) {
        // return SkeletonCard(
        //   height: 180.h,
        //   borderRadius: KBorderSize.borderRadius4,
        //   baseColor: colors.backgroundSecondary,
        //   highlightColor: colors.backgroundPrimary,
        // );
      },
    );
  }

  Color _getStatusColor(String status, AppColorsExtension colors) {
    switch (status.toLowerCase()) {
      case 'confirmed':
      case 'preparing':
        return colors.warning;
      case 'ready':
        return colors.info;
      case 'picked_up':
      case 'on_the_way':
        return colors.accentGreen;
      default:
        return colors.textSecondary;
    }
  }

  String _formatStatus(String status) {
    return status.replaceAll('_', ' ').toUpperCase();
  }

  String _getActionButtonText(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
      case 'preparing':
        return 'View Details';
      case 'ready':
        return 'Go to Pickup';
      case 'picked_up':
      case 'on_the_way':
        return 'Track Delivery';
      default:
        return 'View Order';
    }
  }
}
