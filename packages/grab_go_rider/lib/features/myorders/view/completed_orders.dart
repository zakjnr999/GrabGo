import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:grab_go_rider/features/myorders/service/my_orders_service.dart';
import 'package:grab_go_rider/features/orders/service/available_order_dto.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:intl/intl.dart';

class CompletedOrders extends StatefulWidget {
  const CompletedOrders({super.key});

  @override
  State<CompletedOrders> createState() => _CompletedOrdersState();
}

class _CompletedOrdersState extends State<CompletedOrders> {
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
      final orders = await _service.getCompletedOrders();
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
            SizedBox(height: 8.h),
            Text(
              "Complete deliveries to see them here",
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
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      order.createdAt != null
                          ? DateFormat('MMM dd, yyyy  •  hh:mm a').format(order.createdAt!)
                          : 'Unknown date',
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
                              Expanded(
                                child: Text(
                                  order.customerName,
                                  style: TextStyle(color: colors.textSecondary, fontSize: 12.sp),
                                  overflow: TextOverflow.ellipsis,
                                ),
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
                          "GHS ${order.riderEarnings?.toStringAsFixed(2) ?? '0.00'}",
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
