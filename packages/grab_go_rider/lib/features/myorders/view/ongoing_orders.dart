import 'package:cached_network_image/cached_network_image.dart';
import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_rider/features/myorders/service/my_orders_service.dart';
import 'package:grab_go_rider/features/orders/service/available_order_dto.dart';
import 'package:grab_go_rider/features/orders/service/available_orders_service.dart';
import 'package:grab_go_rider/features/orders/widgets/cancel_order_dialog.dart';
import 'package:grab_go_rider/features/orders/widgets/ongoing_orders_skeleton.dart';
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
    bool isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return _buildOngoingOrdersSkeleton(colors, isDark);
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
          final size = MediaQuery.of(context).size;
          return _buildOngoingCard(context, order, colors, size);
        },
      ),
    );
  }

  Widget _buildOngoingCard(BuildContext context, AvailableOrderDto order, AppColorsExtension colors, Size size) {
    final statusColor = _getStatusColor(order.orderStatus, colors);
    final statusText = _statusContextLabel(order.orderStatus);
    final timeSince = _formatTimeSince(order.createdAt);

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6.w,
                      height: 6.w,
                      decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      _formatStatus(order.orderStatus),
                      style: TextStyle(color: statusColor, fontSize: 10.sp, fontWeight: FontWeight.w700),
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

          SizedBox(height: 14.h),

          // Route header (available-orders style)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  order.restaurantName,
                  style: TextStyle(color: colors.textPrimary, fontSize: 16.sp, fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              SizedBox(width: 8.w),
              SvgPicture.asset(
                Assets.icons.dotArrowRight,
                package: 'grab_go_shared',
                width: 16.w,
                height: 16.w,
                colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
              ),
              SizedBox(width: 8.w),
              Flexible(
                child: Text(
                  order.customerArea,
                  style: TextStyle(color: colors.textPrimary, fontSize: 15.sp, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),

          SizedBox(height: 10.h),

          // Distance + phase context
          Row(
            children: [
              SvgPicture.asset(
                Assets.icons.mapPin,
                package: 'grab_go_shared',
                width: 14.w,
                height: 14.w,
                colorFilter: ColorFilter.mode(colors.accentGreen, BlendMode.srcIn),
              ),
              SizedBox(width: 4.w),
              Text(
                order.distance != null ? '${order.distance!.toStringAsFixed(1)} km' : '-- km',
                style: TextStyle(color: colors.textSecondary, fontSize: 12.sp, fontWeight: FontWeight.w500),
              ),
              SizedBox(width: 10.w),
              Container(
                width: 4.w,
                height: 4.w,
                decoration: BoxDecoration(color: colors.textSecondary, shape: BoxShape.circle),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Text(
                  statusText,
                  style: TextStyle(color: colors.textSecondary, fontSize: 12.sp, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),

          SizedBox(height: 12.h),

          DottedLine(
            direction: Axis.horizontal,
            lineLength: double.infinity,
            lineThickness: 1.4,
            dashLength: 6,
            dashGapLength: 4,
            dashColor: colors.inputBorder.withValues(alpha: 0.65),
          ),

          SizedBox(height: 12.h),

          _buildCounterpartyRow(
            colors: colors,
            size: size,
            title: order.restaurantName,
            subtitle: order.restaurantAddress,
            imageUrl: order.restaurantLogo,
            fallbackIcon: Assets.icons.store,
          ),

          SizedBox(height: 10.h),

          _buildCounterpartyRow(
            colors: colors,
            size: size,
            title: order.customerName,
            subtitle: order.customerAddress,
            imageUrl: order.customerPhoto,
            fallbackIcon: Assets.icons.user,
          ),

          SizedBox(height: 14.h),

          Row(
            children: [
              _buildSummaryMetric(
                colors: colors,
                label: "EARNINGS",
                value: "GHS ${order.riderEarnings?.toStringAsFixed(2) ?? '0.00'}",
                valueColor: colors.accentGreen,
              ),
              SizedBox(width: 10.w),
              _buildSummaryMetric(
                colors: colors,
                label: "ITEMS",
                value: "${order.itemCount} item${order.itemCount > 1 ? 's' : ''}",
                valueColor: colors.textPrimary,
              ),
              SizedBox(width: 10.w),
              _buildSummaryMetric(colors: colors, label: "UPDATED", value: timeSince, valueColor: colors.textPrimary),
            ],
          ),

          if (order.deliveryWindowText != null) ...[
            SizedBox(height: 10.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: colors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
              ),
              child: Row(
                children: [
                  Icon(Icons.timer_outlined, color: colors.warning, size: 16.sp),
                  SizedBox(width: 6.w),
                  Expanded(
                    child: Text(
                      "Delivery window: ${order.deliveryWindowText}",
                      style: TextStyle(color: colors.warning, fontSize: 12.sp, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ],

          SizedBox(height: 14.h),

          // Actions
          Row(
            children: [
              Expanded(
                child: AppButton(
                  onPressed: () => _showCancelOrderDialog(context, order, colors),
                  buttonText: "Cancel Order",
                  backgroundColor: colors.backgroundSecondary,
                  borderRadius: KBorderSize.borderRadius4,
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                  textStyle: TextStyle(color: colors.textSecondary, fontSize: 12.sp, fontWeight: FontWeight.w700),
                  height: 56.h,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: AppButton(
                  onPressed: () => _handleActionButton(context, order),
                  buttonText: _getActionButtonText(order.orderStatus),
                  backgroundColor: colors.accentGreen,
                  borderRadius: KBorderSize.borderRadius4,
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
                  textStyle: TextStyle(color: Colors.white, fontSize: 12.sp, fontWeight: FontWeight.w700),
                  height: 56.h,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCounterpartyRow({
    required AppColorsExtension colors,
    required Size size,
    required String title,
    required String subtitle,
    required String? imageUrl,
    required String fallbackIcon,
  }) {
    final normalizedUrl = imageUrl?.trim();
    final hasImage = normalizedUrl != null && normalizedUrl.isNotEmpty;

    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
          child: hasImage
              ? CachedNetworkImage(
                  height: size.width * 0.12,
                  width: size.width * 0.12,
                  fit: BoxFit.cover,
                  imageUrl: ImageOptimizer.getPreviewUrl(normalizedUrl, width: 200),
                  memCacheWidth: 200,
                  maxHeightDiskCache: 200,
                  placeholder: (_, __) => _buildCounterpartyFallback(colors, size, fallbackIcon),
                  errorWidget: (_, __, ___) => _buildCounterpartyFallback(colors, size, fallbackIcon),
                )
              : _buildCounterpartyFallback(colors, size, fallbackIcon),
        ),
        SizedBox(width: 10.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(color: colors.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                subtitle,
                style: TextStyle(color: colors.textSecondary, fontSize: 12.sp),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCounterpartyFallback(AppColorsExtension colors, Size size, String fallbackIcon) {
    return Container(
      height: size.width * 0.12,
      width: size.width * 0.12,
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: colors.accentGreen.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
      ),
      child: SvgPicture.asset(
        fallbackIcon,
        package: 'grab_go_shared',
        colorFilter: ColorFilter.mode(colors.accentGreen, BlendMode.srcIn),
      ),
    );
  }

  Widget _buildSummaryMetric({
    required AppColorsExtension colors,
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 10.h),
        decoration: BoxDecoration(
          color: colors.backgroundSecondary,
          borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(color: colors.textSecondary, fontSize: 10.sp, fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 4.h),
            Text(
              value,
              style: TextStyle(color: valueColor, fontSize: 13.sp, fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOngoingOrdersSkeleton(AppColorsExtension colors, bool isDark) {
    return ListView.separated(
      itemCount: 10,
      separatorBuilder: (context, index) => SizedBox(height: 16.h),
      itemBuilder: (context, index) {
        return OngoingOrdersSkeleton(colors: colors, isDark: isDark);
      },
    );
  }

  Color _getStatusColor(String status, AppColorsExtension colors) {
    switch (status.toLowerCase()) {
      case 'confirmed':
      case 'preparing':
        return colors.error;
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

  String _statusContextLabel(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return 'Order confirmed';
      case 'preparing':
        return 'Preparing at vendor';
      case 'ready':
        return 'Ready for pickup';
      case 'picked_up':
        return 'Picked up';
      case 'on_the_way':
        return 'On the way';
      default:
        return 'In progress';
    }
  }

  String _formatTimeSince(DateTime? dateTime) {
    if (dateTime == null) return 'Now';
    final duration = DateTime.now().difference(dateTime);
    if (duration.inMinutes < 1) return 'Now';
    if (duration.inMinutes < 60) return '${duration.inMinutes}m ago';
    if (duration.inHours < 24) return '${duration.inHours}h ago';
    return '${duration.inDays}d ago';
  }

  void _handleActionButton(BuildContext context, AvailableOrderDto order) {
    final status = order.orderStatus.toLowerCase();

    if (status == 'ready' || status == 'picked_up' || status == 'on_the_way') {
      final isDeliveryPhase = status == 'picked_up' || status == 'on_the_way';

      context.push(
        '/delivery-tracking',
        extra: {
          'orderId': order.id,
          'customerName': order.customerName,
          'customerAddress': order.customerAddress,
          'customerPhone': order.customerPhone,
          'restaurantName': order.restaurantName,
          'restaurantAddress': order.restaurantAddress,
          'orderTotal': 'GHS ${order.totalAmount.toStringAsFixed(2)}',
          'orderItems': order.orderItems,
          'specialInstructions': order.notes,
          'phase': isDeliveryPhase ? 'delivery' : 'pickup',
          'hasPickedUp': isDeliveryPhase,
          'customerId': order.customerId,
          'riderId': order.riderId,
          'pickupLatitude': order.pickupLatitude,
          'pickupLongitude': order.pickupLongitude,
          'destinationLatitude': order.destinationLatitude,
          'destinationLongitude': order.destinationLongitude,
          'isGiftOrder': order.isGiftOrder,
          'deliveryVerificationRequired': order.deliveryVerificationRequired,
          'giftRecipientName': order.giftRecipientName,
          'giftRecipientPhone': order.giftRecipientPhone,
          'deliveryVerificationMethod': order.deliveryVerificationMethod,
        },
      );
    } else {
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
          'riderId': order.riderId,
          'riderEarnings': order.riderEarnings,
          'pickupLatitude': order.pickupLatitude,
          'pickupLongitude': order.pickupLongitude,
          'destinationLatitude': order.destinationLatitude,
          'destinationLongitude': order.destinationLongitude,
          'isGiftOrder': order.isGiftOrder,
          'deliveryVerificationRequired': order.deliveryVerificationRequired,
          'giftRecipientName': order.giftRecipientName,
          'giftRecipientPhone': order.giftRecipientPhone,
          'deliveryVerificationMethod': order.deliveryVerificationMethod,
        },
      );
    }
  }

  void _showCancelOrderDialog(BuildContext context, AvailableOrderDto order, AppColorsExtension colors) {
    final orderService = AvailableOrdersService();

    CancelOrderDialog.show(
      context: context,
      orderId: order.id,
      orderNumber: '#${order.orderNumber}',
      onConfirm: (reason, notes) async {
        debugPrint('🚫 Cancelling order: ${reason.apiValue}${notes != null ? " - $notes" : ""}');
        debugPrint('🚫 Cancelling order: ${order.id}');

        final success = await orderService.cancelOrder(order.id, reason: reason.apiValue, notes: notes);

        if (!mounted) return;

        if (success) {
          AppToastMessage.show(
            context: context,
            showIcon: false,
            backgroundColor: colors.accentGreen,
            gravity: ToastGravity.CENTER,
            radius: KBorderSize.borderRadius4,
            maxLines: 2,
            message: "Order cancelled and released for other riders.",
          );

          _loadOrders();
        } else {
          AppToastMessage.show(
            context: context,
            showIcon: false,
            backgroundColor: colors.error,
            gravity: ToastGravity.CENTER,
            radius: KBorderSize.borderRadius4,
            maxLines: 2,
            message: "Failed to cancel order. Please try again.",
          );
        }
      },
    );
  }
}
