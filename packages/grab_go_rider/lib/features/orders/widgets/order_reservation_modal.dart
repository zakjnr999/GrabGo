import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:grab_go_rider/features/orders/service/order_reservation_service.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class OrderReservationModal extends StatefulWidget {
  final OrderReservation reservation;
  final VoidCallback? onAccepted;
  final VoidCallback? onDeclined;
  final VoidCallback? onExpired;

  const OrderReservationModal({
    super.key,
    required this.reservation,
    this.onAccepted,
    this.onDeclined,
    this.onExpired,
  });

  static Future<void> show(
    BuildContext context,
    OrderReservation reservation, {
    VoidCallback? onAccepted,
    VoidCallback? onDeclined,
    VoidCallback? onExpired,
  }) {
    HapticFeedback.heavyImpact();

    return showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => OrderReservationModal(
        reservation: reservation,
        onAccepted: onAccepted,
        onDeclined: onDeclined,
        onExpired: onExpired,
      ),
    );
  }

  @override
  State<OrderReservationModal> createState() => _OrderReservationModalState();
}

class _OrderReservationModalState extends State<OrderReservationModal>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Timer? _countdownTimer;
  int _remainingSeconds = 0;
  bool _isAccepting = false;
  bool _isDeclining = false;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = (widget.reservation.remainingMs / 1000).ceil();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Start countdown
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _remainingSeconds--;
        });

        if (_remainingSeconds <= 0) {
          timer.cancel();
          _handleExpired();
        } else if (_remainingSeconds <= 3) {
          HapticFeedback.lightImpact();
        }
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _handleExpired() {
    Navigator.of(context).pop();
    widget.onExpired?.call();
  }

  Future<void> _handleAccept() async {
    if (_isAccepting || _isDeclining) return;

    setState(() => _isAccepting = true);
    HapticFeedback.mediumImpact();

    final service = OrderReservationService();
    final success = await service.acceptReservation();

    if (!mounted) return;

    Navigator.of(context).pop();

    if (success) {
      // Let the bottom sheet dismissal finish before triggering navigation callbacks.
      Future.delayed(const Duration(milliseconds: 150), () {
        widget.onAccepted?.call();
      });
    }
  }

  Future<void> _handleDecline() async {
    if (_isAccepting || _isDeclining) return;

    setState(() => _isDeclining = true);
    HapticFeedback.lightImpact();

    final service = OrderReservationService();
    final success = await service.declineReservation();

    if (!mounted) return;

    Navigator.of(context).pop();

    if (success) {
      Future.delayed(const Duration(milliseconds: 100), () {
        widget.onDeclined?.call();
      });
    }
  }

  Color _getTimerColor() {
    if (_remainingSeconds <= 3) return Colors.red;
    if (_remainingSeconds <= 5) return Colors.orange;
    return Colors.green;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final order = widget.reservation.order;
    final padding = MediaQuery.paddingOf(context);
    final size = MediaQuery.sizeOf(context);
    final screenHeight = MediaQuery.sizeOf(context).height;

    return Container(
      constraints: BoxConstraints(maxHeight: screenHeight * 0.85),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(KBorderSize.borderRadius20),
          topRight: Radius.circular(KBorderSize.borderRadius20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: EdgeInsets.only(left: 20.w, right: 20.w, top: 16.h),
            child: Column(
              children: [
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'New Order Available!',
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 18.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          order.storeName,
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) => Transform.scale(
                        scale: _remainingSeconds <= 5
                            ? _pulseAnimation.value
                            : 1.0,
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12.w,
                            vertical: 8.h,
                          ),
                          decoration: BoxDecoration(
                            color: _getTimerColor(),
                            borderRadius: BorderRadius.circular(
                              KBorderSize.borderRadius4,
                            ),
                          ),
                          child: Text(
                            '${_remainingSeconds}s',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12.h),
                _buildProgressBar(colors),
                SizedBox(height: 16.h),
              ],
            ),
          ),

          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(
                          KBorderSize.borderRadius4,
                        ),
                        child: CachedNetworkImage(
                          height: size.width * 0.12,
                          width: size.width * 0.12,
                          fit: BoxFit.cover,
                          imageUrl: ImageOptimizer.getPreviewUrl(
                            order.storeLogo!,
                            width: 200,
                          ),
                          memCacheWidth: 200,
                          maxHeightDiskCache: 200,
                          placeholder: (context, url) => Container(
                            height: size.width * 0.12,
                            width: size.width * 0.12,
                            padding: EdgeInsets.all(12.r),
                            decoration: BoxDecoration(
                              color: colors.accentGreen.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(
                                KBorderSize.borderRadius4,
                              ),
                            ),
                            child: SvgPicture.asset(
                              Assets.icons.store,
                              package: 'grab_go_shared',
                              width: 24.w,
                              height: 24.w,
                              colorFilter: ColorFilter.mode(
                                colors.accentGreen,
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            height: size.width * 0.12,
                            width: size.width * 0.12,
                            padding: EdgeInsets.all(12.r),
                            decoration: BoxDecoration(
                              color: colors.accentGreen.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(
                                KBorderSize.borderRadius4,
                              ),
                            ),
                            child: SvgPicture.asset(
                              Assets.icons.store,
                              package: 'grab_go_shared',
                              width: 24.w,
                              height: 24.w,
                              colorFilter: ColorFilter.mode(
                                colors.accentGreen,
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              order.storeName,
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
                              '${order.itemCount} item${order.itemCount > 1 ? 's' : ''}  •  ${order.orderType}',
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 13.sp,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: 24.h),

                  _buildAddressRow(
                    iconColor: colors.accentGreen,
                    label: 'PICKUP',
                    address: order.pickupAddress,
                    colors: colors,
                  ),
                  SizedBox(height: 12.h),
                  Container(
                    height: 24.h,
                    width: 2.w,
                    margin: EdgeInsets.symmetric(
                      vertical: 4.h,
                      horizontal: 8.w,
                    ),
                    decoration: BoxDecoration(
                      color: colors.textSecondary.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(1.r),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  _buildAddressRow(
                    iconColor: colors.error,
                    label: 'DELIVER TO',
                    address: order.deliveryAddress,
                    colors: colors,
                  ),

                  SizedBox(height: 24.h),

                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          label: 'EARNINGS',
                          value:
                              'GHS ${widget.reservation.estimatedEarnings.toStringAsFixed(2)}',
                          colors: colors,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: _buildStatCard(
                          label: 'DISTANCE',
                          value: '${order.distance.toStringAsFixed(1)} km',
                          colors: colors,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: _buildStatCard(
                          label: 'TO PICKUP',
                          value:
                              '${widget.reservation.distanceToPickup.toStringAsFixed(1)} km',
                          colors: colors,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 24.h),
                ],
              ),
            ),
          ),

          Container(
            padding: EdgeInsets.only(
              left: 20.w,
              right: 20.w,
              top: 16.h,
              bottom: padding.bottom + 20.h,
            ),
            decoration: BoxDecoration(
              color: colors.backgroundPrimary,
              boxShadow: [
                BoxShadow(
                  color: colors.shadow.withValues(alpha: 0.1),
                  blurRadius: 5,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: AppButton(
                    onPressed: _handleDecline,
                    buttonText: _isDeclining ? "Please wait..." : "Decline",
                    backgroundColor: _isDeclining || _isAccepting
                        ? colors.inputBorder.withValues(alpha: 0.5)
                        : colors.inputBorder,
                    borderRadius: KBorderSize.borderRadius4,
                    textStyle: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                    ),
                    height: 56.h,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  flex: 2,
                  child: AppButton(
                    onPressed: _handleAccept,
                    buttonText: _isAccepting
                        ? "Please wait..."
                        : "Accept Order",
                    backgroundColor: _isAccepting || _isDeclining
                        ? colors.accentGreen.withValues(alpha: 0.5)
                        : colors.accentGreen,
                    borderRadius: KBorderSize.borderRadius4,
                    textStyle: TextStyle(
                      color: Colors.white,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                    ),
                    height: 56.h,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressRow({
    required Color iconColor,
    required String label,
    required String address,
    required AppColorsExtension colors,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                address,
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required AppColorsExtension colors,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: colors.backgroundSecondary,
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 9.sp,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            value,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(AppColorsExtension colors) {
    final totalSeconds = widget.reservation.timeoutMs / 1000;
    final progress = (_remainingSeconds / totalSeconds).clamp(0.0, 1.0);
    final timerColor = _getTimerColor();

    return ClipRRect(
      borderRadius: BorderRadius.circular(4.r),
      child: LinearProgressIndicator(
        value: progress,
        backgroundColor: colors.backgroundSecondary,
        valueColor: AlwaysStoppedAnimation<Color>(timerColor),
        minHeight: 8.h,
      ),
    );
  }
}
