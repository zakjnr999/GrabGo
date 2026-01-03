import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/features/order/service/order_service_wrapper.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:intl/intl.dart';

class WaitingForRiderScreen extends StatefulWidget {
  final String orderId;
  final String orderNumber;
  final String restaurantName;
  final double totalAmount;
  final DateTime orderDate;
  final VoidCallback? onRiderAccepted;

  const WaitingForRiderScreen({
    super.key,
    required this.orderId,
    required this.orderNumber,
    required this.restaurantName,
    required this.totalAmount,
    required this.orderDate,
    this.onRiderAccepted,
  });

  @override
  State<WaitingForRiderScreen> createState() => _WaitingForRiderScreenState();
}

class _WaitingForRiderScreenState extends State<WaitingForRiderScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Timer? _pollingTimer;
  final OrderServiceWrapper _orderService = OrderServiceWrapper();
  bool _isCheckingStatus = false;

  @override
  void initState() {
    super.initState();
    _setupAnimation();
    _startPolling();
  }

  void _setupAnimation() {
    _pulseController = AnimationController(duration: const Duration(milliseconds: 1500), vsync: this)
      ..repeat(reverse: true);

    _pulseAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
  }

  void _startPolling() {
    // Check order status every 5 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkOrderStatus();
    });
  }

  Future<void> _checkOrderStatus() async {
    if (_isCheckingStatus) return;
    _isCheckingStatus = true;

    try {
      final orders = await _orderService.getUserOrders();
      final order = orders.firstWhere((o) => o['_id'] == widget.orderId, orElse: () => <String, dynamic>{});

      if (order.isEmpty) return;

      final status = (order['status'] as String? ?? '').toLowerCase();
      // If order has progressed past pending/confirmed, rider has accepted
      if (!['pending', 'confirmed'].contains(status)) {
        if (mounted) {
          widget.onRiderAccepted?.call();
          context.pop();
          AppToastMessage.show(
            context: context,
            icon: Icons.check,
            message: "A rider has accepted your order! You can now chat with them.",
            maxLines: 2,
            backgroundColor: AppColors.accentGreen,
          );
        }
      }
    } catch (e) {
      debugPrint('Error checking order status: $e');
    } finally {
      _isCheckingStatus = false;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _pollingTimer?.cancel();
    super.dispose();
  }

  String _formatOrderDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return DateFormat('MMM d, h:mm a').format(date);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: colors.backgroundSecondary,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: colors.backgroundSecondary,
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: colors.backgroundSecondary,
          leadingWidth: 60,
          leading: Padding(
            padding: EdgeInsets.only(left: 16.w),
            child: Container(
              height: 44.h,
              width: 44.w,
              decoration: BoxDecoration(
                color: colors.backgroundPrimary,
                shape: BoxShape.circle,
                border: Border.all(color: colors.inputBorder.withValues(alpha: 0.3), width: 0.5),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => context.pop(),
                  customBorder: const CircleBorder(),
                  child: Padding(
                    padding: EdgeInsets.all(8.r),
                    child: SvgPicture.asset(
                      Assets.icons.navArrowLeft,
                      package: 'grab_go_shared',
                      colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
                    ),
                  ),
                ),
              ),
            ),
          ),
          title: Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: colors.backgroundPrimary,
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(color: colors.inputBorder.withValues(alpha: 0.3), width: 0.5),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(6.r),
                  decoration: BoxDecoration(color: colors.accentViolet.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: SvgPicture.asset(
                    Assets.icons.deliveryTruck,
                    package: 'grab_go_shared',
                    height: 16.h,
                    width: 16.w,
                    colorFilter: ColorFilter.mode(colors.accentViolet, BlendMode.srcIn),
                  ),
                ),
                SizedBox(width: 8.w),
                Text(
                  'Order #${widget.orderNumber.substring(0, 8)}',
                  style: TextStyle(
                    fontFamily: "Lato",
                    package: 'grab_go_shared',
                    color: colors.textPrimary,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(24.w),
            child: Column(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Animated waiting illustration
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _pulseAnimation.value,
                            child: Container(
                              width: 160.w,
                              height: 160.w,
                              decoration: BoxDecoration(
                                color: colors.accentViolet.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Container(
                                  width: 120.w,
                                  height: 120.w,
                                  decoration: BoxDecoration(
                                    color: colors.accentViolet.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Container(
                                      width: 80.w,
                                      height: 80.w,
                                      decoration: BoxDecoration(
                                        color: colors.accentViolet.withValues(alpha: 0.2),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Center(
                                        child: SvgPicture.asset(
                                          Assets.icons.deliveryGuyIcon,
                                          package: 'grab_go_shared',
                                          width: 40.w,
                                          height: 40.w,
                                          colorFilter: ColorFilter.mode(colors.accentViolet, BlendMode.srcIn),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      SizedBox(height: 40.h),

                      // Title
                      Text(
                        'Waiting for Rider',
                        style: TextStyle(color: colors.textPrimary, fontSize: 24.sp, fontWeight: FontWeight.w800),
                      ),
                      SizedBox(height: 12.h),

                      // Subtitle
                      Text(
                        'Your order is being matched with a nearby rider.\nYou\'ll be able to chat once they accept.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w400,
                          height: 1.5,
                        ),
                      ),
                      SizedBox(height: 32.h),

                      // Loading dots
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(3, (index) {
                          return TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0.0, end: 1.0),
                            duration: Duration(milliseconds: 600 + (index * 200)),
                            curve: Curves.easeInOut,
                            builder: (context, value, child) {
                              return AnimatedBuilder(
                                animation: _pulseController,
                                builder: (context, child) {
                                  final delay = index * 0.2;
                                  final animValue = ((_pulseController.value + delay) % 1.0);
                                  final opacity = 0.3 + (0.7 * (animValue < 0.5 ? animValue * 2 : (1 - animValue) * 2));
                                  return Container(
                                    margin: EdgeInsets.symmetric(horizontal: 4.w),
                                    width: 10.w,
                                    height: 10.w,
                                    decoration: BoxDecoration(
                                      color: colors.accentViolet.withValues(alpha: opacity),
                                      shape: BoxShape.circle,
                                    ),
                                  );
                                },
                              );
                            },
                          );
                        }),
                      ),
                    ],
                  ),
                ),

                Container(
                  padding: EdgeInsets.all(20.w),
                  decoration: BoxDecoration(
                    color: colors.backgroundPrimary,
                    borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
                    border: Border.all(color: colors.border, width: 1),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 48.w,
                            height: 48.w,
                            decoration: BoxDecoration(
                              color: colors.accentOrange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: Center(
                              child: SvgPicture.asset(
                                Assets.icons.utensilsCrossed,
                                package: 'grab_go_shared',
                                width: 24.w,
                                height: 24.w,
                                colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                              ),
                            ),
                          ),
                          SizedBox(width: 16.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.restaurantName,
                                  style: TextStyle(
                                    color: colors.textPrimary,
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  'Ordered ${_formatOrderDate(widget.orderDate)}',
                                  style: TextStyle(
                                    color: colors.textSecondary,
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'GHC ${widget.totalAmount.toStringAsFixed(0)}',
                                style: TextStyle(
                                  color: colors.accentOrange,
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                decoration: BoxDecoration(
                                  color: colors.accentViolet.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8.r),
                                ),
                                child: Text(
                                  'Pending',
                                  style: TextStyle(
                                    color: colors.accentViolet,
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: 16.h),
                      Container(
                        padding: EdgeInsets.all(12.w),
                        decoration: BoxDecoration(
                          color: colors.accentViolet.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(color: colors.accentViolet.withValues(alpha: 0.2), width: 1),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, size: 18.w, color: colors.accentViolet),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Text(
                                'Chat will be available once a rider accepts your order',
                                style: TextStyle(
                                  color: colors.accentViolet,
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
