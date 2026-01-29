import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:grab_go_rider/features/orders/service/available_order_dto.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

/// Bottom sheet widget for displaying order details when a map pin is tapped
class OrderDetailBottomSheet extends StatefulWidget {
  final AvailableOrderDto order;
  final VoidCallback onAccept;
  final VoidCallback onViewDetails;
  final VoidCallback? onClose;
  final bool isClosest;

  const OrderDetailBottomSheet({
    super.key,
    required this.order,
    required this.onAccept,
    required this.onViewDetails,
    this.onClose,
    this.isClosest = false,
  });

  /// Show the bottom sheet
  static void show({
    required BuildContext context,
    required AvailableOrderDto order,
    required VoidCallback onAccept,
    required VoidCallback onViewDetails,
    bool isClosest = false,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: false,
      builder: (context) => OrderDetailBottomSheet(
        order: order,
        onAccept: onAccept,
        onViewDetails: onViewDetails,
        onClose: () => Navigator.of(context).pop(),
        isClosest: isClosest,
      ),
    );
  }

  @override
  State<OrderDetailBottomSheet> createState() => _OrderDetailBottomSheetState();
}

class _OrderDetailBottomSheetState extends State<OrderDetailBottomSheet> {
  bool _isAccepting = false;

  void _handleAccept() {
    if (_isAccepting) return;

    setState(() {
      _isAccepting = true;
    });

    widget.onAccept();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return WillPopScope(
      onWillPop: () async => !_isAccepting,
      child: Container(
        decoration: BoxDecoration(
          color: colors.backgroundPrimary,
          borderRadius: BorderRadius.only(topLeft: Radius.circular(20.r), topRight: Radius.circular(20.r)),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withAlpha(40) : Colors.black.withAlpha(15),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            GestureDetector(
              onVerticalDragUpdate: _isAccepting ? null : (_) {},
              child: Container(
                margin: EdgeInsets.only(top: 12.h),
                width: 40.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: colors.textSecondary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2.r),
                ),
              ),
            ),

            Padding(
              padding: EdgeInsets.all(20.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          if (widget.isClosest) ...[
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                              decoration: BoxDecoration(
                                color: colors.accentOrange.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SvgPicture.asset(
                                    Assets.icons.starSolid,
                                    package: 'grab_go_shared',
                                    width: 14.w,
                                    height: 14.w,
                                    colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                                  ),
                                  SizedBox(width: 4.w),
                                  Text(
                                    'Closest',
                                    style: TextStyle(
                                      color: colors.accentOrange,
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 8.w),
                          ],
                          Text(
                            widget.order.orderNumber,
                            style: TextStyle(color: colors.textSecondary, fontSize: 12.sp, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      _buildTimeSinceOrder(colors),
                    ],
                  ),

                  SizedBox(height: 16.h),

                  _buildRouteVisualization(colors),

                  SizedBox(height: 16.h),

                  DottedLine(
                    direction: Axis.horizontal,
                    lineLength: double.infinity,
                    lineThickness: 1.5,
                    dashLength: 6,
                    dashColor: colors.inputBorder.withValues(alpha: 0.5),
                    dashGapLength: 4,
                  ),

                  SizedBox(height: 16.h),

                  // Stats row: Distance, ETA, Items
                  _buildStatsRow(colors),

                  SizedBox(height: 16.h),

                  // Earnings section
                  _buildEarningsSection(colors),

                  SizedBox(height: 20.h),

                  // Action buttons
                  Row(
                    children: [
                      // View Details button
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isAccepting ? null : widget.onViewDetails,
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: 14.h),
                            side: BorderSide(color: colors.border, width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                            ),
                          ),
                          child: Text(
                            'View Details',
                            style: TextStyle(color: colors.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      // Accept Order button
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _isAccepting ? null : _handleAccept,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: colors.accentGreen,
                            disabledBackgroundColor: colors.accentGreen.withValues(alpha: 0.7),
                            padding: EdgeInsets.symmetric(vertical: 14.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                            ),
                            elevation: 0,
                          ),
                          child: _isAccepting
                              ? Text(
                                  'Accepting order...',
                                  style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w700),
                                )
                              : Text(
                                  'Accept Order',
                                  style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w700),
                                ),
                        ),
                      ),
                    ],
                  ),

                  // Safe area padding
                  SizedBox(height: MediaQuery.of(context).padding.bottom > 0 ? 8.h : 0),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteVisualization(AppColorsExtension colors) {
    return Row(
      children: [
        Column(
          children: [
            Container(
              padding: EdgeInsets.all(8.r),
              decoration: BoxDecoration(
                color: colors.accentOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
              ),
              child: SvgPicture.asset(
                Assets.icons.store,
                package: 'grab_go_shared',
                width: 18.w,
                height: 18.w,
                colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
              ),
            ),
            Container(
              height: 24.h,
              width: 2.w,
              margin: EdgeInsets.symmetric(vertical: 4.h),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [colors.accentOrange, colors.accentGreen],
                ),
                borderRadius: BorderRadius.circular(1.r),
              ),
            ),
            Container(
              padding: EdgeInsets.all(8.r),
              decoration: BoxDecoration(
                color: colors.accentGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
              ),
              child: SvgPicture.asset(
                Assets.icons.mapPin,
                package: 'grab_go_shared',
                width: 18.w,
                height: 18.w,
                colorFilter: ColorFilter.mode(colors.accentGreen, BlendMode.srcIn),
              ),
            ),
          ],
        ),

        SizedBox(width: 12.w),

        // Route details column
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pickup (Restaurant)
              Text(
                'PICKUP',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                widget.order.restaurantName,
                style: TextStyle(color: colors.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              SizedBox(height: 16.h),

              // Dropoff (Customer)
              Text(
                'DROP-OFF',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: 2.h),
              Text(
                widget.order.customerArea,
                style: TextStyle(color: colors.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow(AppColorsExtension colors) {
    // Calculate ETA estimate (rough: 3 min per km)
    final distanceKm = widget.order.distance ?? widget.order.distanceToPickup ?? 0;
    final etaMinutes = (distanceKm * 3).round();

    return Row(
      children: [
        // Distance
        Expanded(
          child: _buildStatItem(
            colors: colors,
            icon: Assets.icons.mapPin,
            label: 'Distance',
            value: distanceKm > 0 ? '${distanceKm.toStringAsFixed(1)} km' : '-- km',
          ),
        ),
        Container(width: 1, height: 36.h, color: colors.border.withValues(alpha: 0.5)),
        // ETA
        Expanded(
          child: _buildStatItem(
            colors: colors,
            icon: Assets.icons.timer,
            label: 'ETA',
            value: etaMinutes > 0 ? '~$etaMinutes min' : '-- min',
          ),
        ),
        Container(width: 1, height: 36.h, color: colors.border.withValues(alpha: 0.5)),
        // Items
        Expanded(
          child: _buildStatItem(
            colors: colors,
            icon: Assets.icons.cart,
            label: 'Items',
            value: '${widget.order.itemCount}',
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem({
    required AppColorsExtension colors,
    required String icon,
    required String label,
    required String value,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              icon,
              package: 'grab_go_shared',
              width: 14.w,
              height: 14.w,
              colorFilter: ColorFilter.mode(colors.accentGreen, BlendMode.srcIn),
            ),
            SizedBox(width: 4.w),
            Text(
              label,
              style: TextStyle(color: colors.textSecondary, fontSize: 10.sp, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        SizedBox(height: 4.h),
        Text(
          value,
          style: TextStyle(color: colors.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }

  Widget _buildEarningsSection(AppColorsExtension colors) {
    return Container(
      padding: EdgeInsets.all(14.w),

      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(
                'YOUR EARNINGS :',
                style: TextStyle(color: colors.textPrimary, fontSize: 12.sp, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          Text(
            widget.order.riderEarnings != null && widget.order.riderEarnings! > 0
                ? 'GHS ${widget.order.riderEarnings!.toStringAsFixed(2)}'
                : 'Not set',
            style: TextStyle(color: colors.accentGreen, fontSize: 18.sp, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSinceOrder(AppColorsExtension colors) {
    if (widget.order.createdAt == null) return const SizedBox.shrink();

    final duration = DateTime.now().difference(widget.order.createdAt!);
    final minutes = duration.inMinutes;

    String timeText;
    Color timeColor;

    if (minutes < 1) {
      timeText = 'Just now';
      timeColor = colors.accentGreen;
    } else if (minutes < 5) {
      timeText = '${minutes}m ago';
      timeColor = colors.accentGreen;
    } else if (minutes < 15) {
      timeText = '${minutes}m ago';
      timeColor = colors.accentOrange;
    } else if (minutes < 60) {
      timeText = '${minutes}m ago';
      timeColor = colors.error;
    } else {
      final hours = duration.inHours;
      timeText = '${hours}h ago';
      timeColor = colors.error;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: timeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            Assets.icons.timer,
            package: 'grab_go_shared',
            width: 13.w,
            height: 13.w,
            colorFilter: ColorFilter.mode(timeColor, BlendMode.srcIn),
          ),
          SizedBox(width: 4.w),
          Text(
            timeText,
            style: TextStyle(color: timeColor, fontSize: 11.sp, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
