import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:grab_go_rider/features/myorders/service/my_orders_service.dart';
import 'package:grab_go_rider/features/orders/service/available_order_dto.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:intl/intl.dart';

class CancelledOrders extends StatefulWidget {
  const CancelledOrders({super.key});

  @override
  State<CancelledOrders> createState() => _CancelledOrdersState();
}

class _CancelledOrdersState extends State<CancelledOrders> {
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
      final orders = await _service.getCancelledOrders();
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
      return Center(child: CircularProgressIndicator(color: colors.accentGreen));
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
            SizedBox(height: 8.h),
            Text(
              "Great job keeping your cancellation rate low!",
              style: TextStyle(color: colors.textSecondary.withValues(alpha: 0.7), fontSize: 13.sp),
              textAlign: TextAlign.center,
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
        padding: EdgeInsets.only(bottom: 20.h),
        itemCount: _orders.length,
        separatorBuilder: (context, index) => SizedBox(height: 12.h),
        itemBuilder: (context, index) {
          final order = _orders[index];
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
                      Expanded(
                        child: Text(
                          "#${order.orderNumber}",
                          style: TextStyle(color: colors.textPrimary, fontSize: 12.sp, fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis,
                        ),
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
                  Row(
                    children: [
                      if (order.restaurantLogo != null && order.restaurantLogo!.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8.r),
                          child: Image.network(
                            order.restaurantLogo!,
                            width: 36.w,
                            height: 36.w,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              width: 36.w,
                              height: 36.w,
                              color: colors.backgroundSecondary,
                              child: Icon(Icons.store, color: colors.textSecondary, size: 18.w),
                            ),
                          ),
                        )
                      else
                        Container(
                          width: 36.w,
                          height: 36.w,
                          decoration: BoxDecoration(
                            color: colors.backgroundSecondary,
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Icon(Icons.store, color: colors.textSecondary, size: 18.w),
                        ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Text(
                          order.restaurantName,
                          style: TextStyle(color: colors.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  if (order.notes != null && order.notes!.isNotEmpty) ...[
                    SizedBox(height: 8.h),
                    Text(
                      order.notes!,
                      style: TextStyle(color: colors.error, fontSize: 12.sp, fontWeight: FontWeight.w500),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  SizedBox(height: 8.h),
                  Text(
                    order.createdAt != null
                        ? DateFormat('MMM dd, yyyy  •  hh:mm a').format(order.createdAt!)
                        : 'Unknown date',
                    style: TextStyle(color: colors.textSecondary, fontSize: 11.sp),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
