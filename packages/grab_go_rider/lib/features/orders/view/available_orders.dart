import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_rider/features/orders/service/available_order_dto.dart';
import 'package:grab_go_rider/features/orders/service/order_statistics_service.dart';
import 'package:grab_go_rider/features/orders/widgets/available_order_details_bottom_sheet.dart';
import 'package:grab_go_rider/features/orders/widgets/orders_list_skeleton.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import '../service/available_orders_service.dart';

class AvailableOrders extends StatefulWidget {
  final List<AvailableOrderDto>? preloadedOrders;
  final OrderStatistics? preloadedStatistics;

  const AvailableOrders({super.key, this.preloadedOrders, this.preloadedStatistics});

  @override
  State<AvailableOrders> createState() => _AvailableOrdersState();
}

class _AvailableOrdersState extends State<AvailableOrders> {
  final AvailableOrdersService _service = AvailableOrdersService();
  List<AvailableOrderDto> _availableOrders = [];
  OrderStatistics? statistics;
  bool _isLoading = true;
  bool isRefreshing = false;
  String? _errorMessage;
  double? _currentLat;
  double? _currentLon;

  @override
  void initState() {
    super.initState();
    if (widget.preloadedOrders != null) {
      _availableOrders = widget.preloadedOrders!;
      statistics = widget.preloadedStatistics;
      _isLoading = false;
    } else {
      _loadOrders();
    }
  }

  Future<void> _loadOrders() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _service.getAvailableOrders(lat: _currentLat, lon: _currentLon);

      if (!mounted) return;
      setState(() {
        _availableOrders = result['orders'] as List<AvailableOrderDto>;
        statistics = result['statistics'] as OrderStatistics?;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load orders: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _refreshOrders() async {
    if (!mounted) return;
    setState(() => isRefreshing = true);

    try {
      final orders = await _service.getAvailableOrders();
      if (!mounted) return;
      setState(() {
        _availableOrders = orders as List<AvailableOrderDto>;
        isRefreshing = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to refresh orders: $e';
        isRefreshing = false;
      });
    }
  }

  Future<void> _acceptOrder(AvailableOrderDto order) async {
    final colors = context.appColors;

    try {
      final acceptedOrder = await _service.acceptOrder(order.id);
      if (!mounted) return;

      if (acceptedOrder != null) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order accepted successfully!'),
            backgroundColor: colors.accentGreen,
            duration: const Duration(seconds: 2),
          ),
        );

        context.push(
          '/orderConfirmation',
          extra: {
            'orderId': acceptedOrder.id,
            'orderNumber': acceptedOrder.orderNumber,
            'orderStatus': acceptedOrder.orderStatus,
            'orderInstructions': acceptedOrder.notes,
            'customerName': acceptedOrder.customerName,
            'customerAddress': acceptedOrder.customerAddress,
            'customerPhone': acceptedOrder.customerPhone,
            'customerPhoto': acceptedOrder.customerPhoto,
            'restaurantName': acceptedOrder.restaurantName,
            'restaurantAddress': acceptedOrder.restaurantAddress,
            'restaurantLogo': acceptedOrder.restaurantLogo,
            'orderTotal': 'GHS ${acceptedOrder.totalAmount.toStringAsFixed(2)}',
            'orderItems': acceptedOrder.orderItems,
            'specialInstructions': acceptedOrder.notes,
            'customerId': acceptedOrder.customerId,
            'riderId': acceptedOrder.id,
            'riderEarnings': acceptedOrder.riderEarnings,
            'pickupLatitude': acceptedOrder.pickupLatitude,
            'pickupLongitude': acceptedOrder.pickupLongitude,
            'destinationLatitude': acceptedOrder.destinationLatitude,
            'destinationLongitude': acceptedOrder.destinationLongitude,
          },
        );

        await _refreshOrders();
      } else {
        _showErrorDialog('Failed to accept order. Please try again.');
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog('Error accepting order: $e');
    }
  }

  void _showErrorDialog(String message) {
    final colors = context.appColors;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colors.backgroundPrimary,
        title: Text('Error', style: TextStyle(color: colors.textPrimary)),
        content: Text(message, style: TextStyle(color: colors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK', style: TextStyle(color: colors.accentGreen)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final size = MediaQuery.of(context).size;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: colors.backgroundPrimary,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: colors.backgroundSecondary,
        appBar: AppBar(
          backgroundColor: colors.backgroundPrimary,
          elevation: 0,
          leading: IconButton(
            icon: SvgPicture.asset(
              Assets.icons.navArrowLeft,
              package: 'grab_go_shared',
              width: 24.w,
              height: 24.w,
              colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
            ),
            onPressed: () => context.pop(),
          ),
          title: Text(
            "Available Orders",
            style: TextStyle(
              fontFamily: "Lato",
              package: "grab_go_shared",
              color: colors.textPrimary,
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: SvgPicture.asset(
                Assets.icons.map,
                package: 'grab_go_shared',
                width: 22.w,
                height: 22.w,
                colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
              ),
              onPressed: _isLoading ? null : () => context.push('/availableOrdersMap'),
              tooltip: 'Map View',
            ),
            IconButton(
              icon: SvgPicture.asset(
                Assets.icons.filterList,
                package: 'grab_go_shared',
                width: 22.w,
                height: 22.w,
                colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
              ),
              onPressed: _isLoading ? null : _refreshOrders,
              tooltip: 'Refresh',
            ),
          ],
        ),
        body: _buildBody(colors, isDark, size),
      ),
    );
  }

  Widget _buildBody(AppColorsExtension colors, bool isDark, Size size) {
    if (_isLoading) {
      return SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
        child: Padding(
          padding: EdgeInsets.only(top: 6.h),
          child: Column(
            children: List.generate(10, (index) => OrdersListSkeleton(colors: colors, isDark: isDark)),
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorState(colors);
    }

    if (_availableOrders.isEmpty) {
      return _buildEmptyState(colors);
    }

    return AppRefreshIndicator(
      onRefresh: _refreshOrders,
      iconPath: Assets.icons.deliveryTruck,
      bgColor: colors.accentGreen,
      child: _buildOrdersList(colors, size),
    );
  }

  Widget _buildErrorState(AppColorsExtension colors) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(32.w),
              decoration: BoxDecoration(color: colors.error.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: SvgPicture.asset(
                Assets.icons.circleAlert,
                package: 'grab_go_shared',
                width: 64.w,
                height: 64.w,
                colorFilter: ColorFilter.mode(colors.error, BlendMode.srcIn),
              ),
            ),
            SizedBox(height: 32.h),
            Text(
              "Network Error",
              style: TextStyle(color: colors.textPrimary, fontSize: 20.sp, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12.h),
            Text(
              "An error occured while fetching available orders. Please check your connection and try again.",
              style: TextStyle(color: colors.textSecondary, fontSize: 14.sp, fontWeight: FontWeight.w400, height: 1.5),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 40.h),
            SizedBox(
              width: double.infinity,
              height: 56.h,
              child: AppButton(
                onPressed: _loadOrders,
                buttonText: "Try Again",
                backgroundColor: colors.error,
                textStyle: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(AppColorsExtension colors) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(32.w),
              decoration: BoxDecoration(color: colors.accentGreen.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: SvgPicture.asset(
                Assets.icons.search,
                package: 'grab_go_shared',
                width: 64.w,
                height: 64.w,
                colorFilter: ColorFilter.mode(colors.accentGreen, BlendMode.srcIn),
              ),
            ),
            SizedBox(height: 32.h),
            Text(
              "No Orders Nearby",
              style: TextStyle(color: colors.textPrimary, fontSize: 20.sp, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 12.h),
            Text(
              "We couldn't find any orders in your current area. Try moving to a busier location or refresh to check again.",
              style: TextStyle(color: colors.textSecondary, fontSize: 14.sp, fontWeight: FontWeight.w400, height: 1.5),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 40.h),
            SizedBox(
              width: double.infinity,
              height: 56.h,
              child: AppButton(
                onPressed: _refreshOrders,
                buttonText: "Refresh Range",
                backgroundColor: colors.accentGreen,
                textStyle: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersList(AppColorsExtension colors, Size size) {
    return ListView.separated(
      padding: EdgeInsets.all(16.w),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _availableOrders.length,
      separatorBuilder: (context, index) => SizedBox(height: 12.h),
      itemBuilder: (context, index) {
        final order = _availableOrders[index];
        return _buildOrderCard(order, colors);
      },
    );
  }

  Widget _buildOrderCard(AvailableOrderDto order, AppColorsExtension colors) {
    // Calculate time since order
    String timeSince = '';
    if (order.createdAt != null) {
      final duration = DateTime.now().difference(order.createdAt!);
      if (duration.inMinutes < 1) {
        timeSince = 'Just now';
      } else if (duration.inMinutes < 60) {
        timeSince = '${duration.inMinutes} min${duration.inMinutes > 1 ? 's' : ''} ago';
      } else {
        timeSince = '${duration.inHours}h ago';
      }
    }

    // Status display
    String statusText = '';
    switch (order.orderStatus.toLowerCase()) {
      case 'ready':
        statusText = 'Ready for pickup!';
        break;
      case 'preparing':
        statusText = 'Order is being prepared';
        break;
      case 'confirmed':
        statusText = 'Order confirmed!';
        break;
      case 'delivered':
        statusText = 'Order delivered!';
        break;
      case 'cancelled':
        statusText = 'Order was cancelled';
        break;
      default:
        statusText = 'Current status: ${order.orderStatus}';
    }

    return InkWell(
      onTap: () {
        _showOrderDetails(order, colors, MediaQuery.of(context).size);
        debugPrint('User image ${order.customerPhoto}');
        debugPrint('Restaurant logo ${order.restaurantLogo}');
      },
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: colors.backgroundPrimary,
          borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Restaurant → Customer Area
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  order.restaurantName,
                  style: TextStyle(color: colors.textPrimary, fontSize: 16.sp, fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(width: 5.w),
                SvgPicture.asset(
                  Assets.icons.dotArrowRight,
                  package: 'grab_go_shared',
                  width: 16.w,
                  height: 16.w,
                  colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
                ),
                SizedBox(width: 5.w),
                Flexible(
                  child: Text(
                    order.customerArea,
                    style: TextStyle(color: colors.textPrimary, fontSize: 16.sp, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),

            SizedBox(height: 12.h),

            // Distance & Status Row
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
                  height: 4.h,
                  width: 4.h,
                  decoration: BoxDecoration(color: colors.textSecondary, shape: BoxShape.circle),
                ),
                SizedBox(width: 10.w),
                Text(
                  statusText,
                  style: TextStyle(color: colors.textSecondary, fontSize: 12.sp, fontWeight: FontWeight.w400),
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

            // Earnings & Payment Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  children: [
                    Text(
                      "YOUR EARNINGS :",
                      style: TextStyle(fontSize: 10.sp, color: colors.textPrimary, fontWeight: FontWeight.w400),
                    ),
                    Text(
                      order.riderEarnings != null && order.riderEarnings! > 0
                          ? 'GHS ${order.riderEarnings!.toStringAsFixed(2)}'
                          : 'unavailable',
                      style: TextStyle(color: colors.accentGreen, fontSize: 18.sp, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),

                Row(
                  children: [
                    if (timeSince.isNotEmpty) ...[
                      SizedBox(height: 8.h),
                      Text(
                        timeSince,
                        style: TextStyle(
                          color: colors.textSecondary.withValues(alpha: 0.7),
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                    if (order.itemCount > 0) ...[
                      SizedBox(width: 8.w),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: colors.backgroundPrimary,
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Text(
                          '${order.itemCount} item${order.itemCount > 1 ? 's' : ''}',
                          style: TextStyle(color: colors.textSecondary, fontSize: 11.sp, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showOrderDetails(AvailableOrderDto order, AppColorsExtension colors, Size size) {
    AvailableOrderDetailsBottomSheet.show(context: context, order: order, onAccept: () => _acceptOrder(order));
  }
}
