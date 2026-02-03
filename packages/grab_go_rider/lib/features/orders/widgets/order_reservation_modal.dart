import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_rider/features/orders/service/order_reservation_service.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

/// A modal bottom sheet that displays an incoming order reservation
/// with a countdown timer for accepting or declining
class OrderReservationModal extends StatefulWidget {
  final OrderReservation reservation;
  final VoidCallback? onAccepted;
  final VoidCallback? onDeclined;
  final VoidCallback? onExpired;

  const OrderReservationModal({super.key, required this.reservation, this.onAccepted, this.onDeclined, this.onExpired});

  /// Show the modal as a bottom sheet
  static Future<void> show(
    BuildContext context,
    OrderReservation reservation, {
    VoidCallback? onAccepted,
    VoidCallback? onDeclined,
    VoidCallback? onExpired,
  }) {
    // Vibrate to get rider's attention
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

class _OrderReservationModalState extends State<OrderReservationModal> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  Timer? _countdownTimer;
  int _remainingSeconds = 0;
  bool _isAccepting = false;
  bool _isDeclining = false;

  @override
  void initState() {
    super.initState();

    // Initialize countdown
    _remainingSeconds = (widget.reservation.remainingMs / 1000).ceil();

    // Pulse animation for urgency
    _pulseController = AnimationController(duration: const Duration(milliseconds: 800), vsync: this)
      ..repeat(reverse: true);

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.1,
    ).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

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
          // Vibrate when running low on time
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

    if (mounted) {
      Navigator.of(context).pop();
      if (success) {
        widget.onAccepted?.call();
      }
    }
  }

  Future<void> _handleDecline() async {
    if (_isAccepting || _isDeclining) return;

    setState(() => _isDeclining = true);
    HapticFeedback.lightImpact();

    final service = OrderReservationService();
    final success = await service.declineReservation();

    if (mounted) {
      Navigator.of(context).pop();
      if (success) {
        widget.onDeclined?.call();
      }
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

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 24.h),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, -5))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with countdown
          Container(
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: AppColors.accentOrange,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24.r)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.delivery_dining, color: Colors.white, size: 28.sp),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Text(
                        'New Order Available!',
                        style: TextStyle(
                          fontFamily: 'Lato',
                          package: 'grab_go_shared',
                          color: Colors.white,
                          fontSize: 20.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    // Countdown timer
                    AnimatedBuilder(
                      animation: _pulseAnimation,
                      builder: (context, child) => Transform.scale(
                        scale: _remainingSeconds <= 5 ? _pulseAnimation.value : 1.0,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                          decoration: BoxDecoration(color: _getTimerColor(), borderRadius: BorderRadius.circular(20.r)),
                          child: Text(
                            '${_remainingSeconds}s',
                            style: TextStyle(
                              fontFamily: 'Lato',
                              package: 'grab_go_shared',
                              color: Colors.white,
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                // Progress bar
                ClipRRect(
                  borderRadius: BorderRadius.circular(4.r),
                  child: LinearProgressIndicator(
                    value: _remainingSeconds / (widget.reservation.timeoutMs / 1000),
                    backgroundColor: Colors.white.withOpacity(0.3),
                    valueColor: AlwaysStoppedAnimation<Color>(_getTimerColor()),
                    minHeight: 4.h,
                  ),
                ),
              ],
            ),
          ),

          // Order details
          Padding(
            padding: EdgeInsets.all(20.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Store info
                Row(
                  children: [
                    // Store logo
                    Container(
                      width: 56.w,
                      height: 56.w,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12.r),
                        color: colors.backgroundSecondary,
                      ),
                      child: order.storeLogo != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12.r),
                              child: Image.network(
                                order.storeLogo!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) =>
                                    Icon(Icons.store, color: colors.textSecondary, size: 28.sp),
                              ),
                            )
                          : Icon(Icons.store, color: colors.textSecondary, size: 28.sp),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.storeName,
                            style: TextStyle(
                              fontFamily: 'Lato',
                              package: 'grab_go_shared',
                              color: colors.textPrimary,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            '${order.itemCount} item${order.itemCount > 1 ? 's' : ''} • ${order.paymentMethod.toUpperCase()}',
                            style: TextStyle(
                              fontFamily: 'Lato',
                              package: 'grab_go_shared',
                              color: colors.textSecondary,
                              fontSize: 13.sp,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 16.h),
                Divider(color: colors.divider),
                SizedBox(height: 16.h),

                // Pickup & Delivery addresses
                _buildAddressRow(
                  icon: Icons.store_mall_directory,
                  iconColor: Colors.green,
                  label: 'PICKUP',
                  address: order.pickupAddress,
                  colors: colors,
                ),
                SizedBox(height: 12.h),
                _buildAddressRow(
                  icon: Icons.location_on,
                  iconColor: Colors.red,
                  label: 'DELIVER TO',
                  address: order.deliveryAddress,
                  colors: colors,
                ),

                SizedBox(height: 16.h),
                Divider(color: colors.divider),
                SizedBox(height: 16.h),

                // Earnings & Distance
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        icon: Icons.monetization_on,
                        iconColor: Colors.green,
                        label: 'EARNINGS',
                        value: 'GHS ${widget.reservation.estimatedEarnings.toStringAsFixed(2)}',
                        colors: colors,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: _buildStatCard(
                        icon: Icons.route,
                        iconColor: Colors.blue,
                        label: 'DISTANCE',
                        value: '${order.distance.toStringAsFixed(1)} km',
                        colors: colors,
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: _buildStatCard(
                        icon: Icons.directions_bike,
                        iconColor: Colors.orange,
                        label: 'TO PICKUP',
                        value: '${widget.reservation.distanceToPickup.toStringAsFixed(1)} km',
                        colors: colors,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 24.h),

                // Action buttons
                Row(
                  children: [
                    // Decline button
                    Expanded(
                      child: SizedBox(
                        height: 52.h,
                        child: OutlinedButton(
                          onPressed: _isDeclining || _isAccepting ? null : _handleDecline,
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Colors.red.shade400, width: 2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                          ),
                          child: _isDeclining
                              ? SizedBox(
                                  width: 20.w,
                                  height: 20.w,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red.shade400),
                                )
                              : Text(
                                  'Decline',
                                  style: TextStyle(
                                    fontFamily: 'Lato',
                                    package: 'grab_go_shared',
                                    color: Colors.red.shade400,
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    SizedBox(width: 16.w),
                    // Accept button
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 52.h,
                        child: ElevatedButton(
                          onPressed: _isAccepting || _isDeclining ? null : _handleAccept,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                          ),
                          child: _isAccepting
                              ? SizedBox(
                                  width: 20.w,
                                  height: 20.w,
                                  child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Text(
                                  'Accept Order',
                                  style: TextStyle(
                                    fontFamily: 'Lato',
                                    package: 'grab_go_shared',
                                    color: Colors.white,
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String address,
    required AppColorsExtension colors,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(8.w),
          decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8.r)),
          child: Icon(icon, color: iconColor, size: 20.sp),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'Lato',
                  package: 'grab_go_shared',
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
                  fontFamily: 'Lato',
                  package: 'grab_go_shared',
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
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required AppColorsExtension colors,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(color: colors.backgroundSecondary, borderRadius: BorderRadius.circular(10.r)),
      child: Column(
        children: [
          Icon(icon, color: iconColor, size: 22.sp),
          SizedBox(height: 6.h),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Lato',
              package: 'grab_go_shared',
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
              fontFamily: 'Lato',
              package: 'grab_go_shared',
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
}
