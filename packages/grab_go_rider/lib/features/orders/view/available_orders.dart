import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import '../service/available_orders_service.dart';

class AvailableOrders extends StatefulWidget {
  const AvailableOrders({super.key});

  @override
  State<AvailableOrders> createState() => _AvailableOrdersState();
}

class _AvailableOrdersState extends State<AvailableOrders> {
  final AvailableOrdersService _service = AvailableOrdersService();
  List<AvailableOrderDto> _availableOrders = [];
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final orders = await _service.getAvailableOrders();
      if (!mounted) return;
      setState(() {
        _availableOrders = orders;
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
    setState(() => _isRefreshing = true);

    try {
      final orders = await _service.getAvailableOrders();
      if (!mounted) return;
      setState(() {
        _availableOrders = orders;
        _isRefreshing = false;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to refresh orders: $e';
        _isRefreshing = false;
      });
    }
  }

  Future<void> _acceptOrder(AvailableOrderDto order) async {
    final colors = context.appColors;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: EdgeInsets.all(24.w),
          decoration: BoxDecoration(color: colors.backgroundPrimary, borderRadius: BorderRadius.circular(12.r)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: colors.accentGreen),
              SizedBox(height: 16.h),
              Text(
                'Accepting order...',
                style: TextStyle(color: colors.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final acceptedOrder = await _service.acceptOrder(order.id);
      if (!mounted) return;

      // Close loading dialog
      Navigator.of(context).pop();

      if (acceptedOrder != null) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Order accepted successfully!'),
            backgroundColor: colors.accentGreen,
            duration: const Duration(seconds: 2),
          ),
        );

        // Refresh the list
        await _refreshOrders();

        // Navigate to active orders or order details
        // context.go('/rider/active-orders');
      } else {
        _showErrorDialog('Failed to accept order. Please try again.');
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog
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
                Assets.icons.filterList,
                package: 'grab_go_shared',
                width: 24.w,
                height: 24.w,
                colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
              ),
              onPressed: _isLoading ? null : _refreshOrders,
            ),
          ],
        ),
        body: _buildBody(colors),
      ),
    );
  }

  Widget _buildBody(AppColorsExtension colors) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: colors.accentGreen));
    }

    if (_errorMessage != null) {
      return _buildErrorState(colors);
    }

    if (_availableOrders.isEmpty) {
      return _buildEmptyState(colors);
    }

    return RefreshIndicator(onRefresh: _refreshOrders, color: colors.accentGreen, child: _buildOrdersList(colors));
  }

  Widget _buildErrorState(AppColorsExtension colors) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64.w, color: colors.textSecondary),
            SizedBox(height: 16.h),
            Text(
              _errorMessage ?? 'Something went wrong',
              style: TextStyle(color: colors.textPrimary, fontSize: 16.sp, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24.h),
            SizedBox(
              height: 48.h,
              child: AppButton(onPressed: _loadOrders, buttonText: 'Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(AppColorsExtension colors) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SvgPicture.asset(
              Assets.icons.alarm,
              package: 'grab_go_shared',
              width: 120.w,
              height: 120.w,
              colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
            ),
            SizedBox(height: 24.h),
            Text(
              'No Available Orders',
              style: TextStyle(color: colors.textPrimary, fontSize: 18.sp, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 8.h),
            Text(
              'Check back soon for new delivery opportunities',
              style: TextStyle(color: colors.textSecondary, fontSize: 14.sp, fontWeight: FontWeight.w400),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24.h),
            SizedBox(
              height: 48.h,
              child: AppButton(onPressed: _refreshOrders, buttonText: 'Refresh'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersList(AppColorsExtension colors) {
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
    Color statusColor = colors.accentGreen;
    switch (order.orderStatus.toLowerCase()) {
      case 'ready':
        statusText = 'Ready';
        statusColor = colors.accentGreen;
        break;
      case 'preparing':
        statusText = 'Preparing';
        statusColor = Colors.orange;
        break;
      case 'confirmed':
        statusText = 'Confirmed';
        statusColor = Colors.blue;
        break;
      default:
        statusText = order.orderStatus;
    }

    // Payment method display
    String paymentIcon = '';
    switch (order.paymentMethod.toLowerCase()) {
      case 'cash':
        paymentIcon = 'Cash';
        break;
      case 'card':
        paymentIcon = 'Card';
        break;
      case 'mobile_money':
      case 'mobilemoney':
        paymentIcon = 'MoMo';
        break;
      default:
        paymentIcon = order.paymentMethod;
    }

    return InkWell(
      onTap: () => _showOrderDetails(order, colors),
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
                SvgPicture.asset(
                  Assets.icons.dotArrowRight,
                  package: 'grab_go_shared',
                  width: 16.w,
                  height: 16.w,
                  colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
                ),
                Text(
                  order.customerArea,
                  style: TextStyle(color: colors.textPrimary, fontSize: 16.sp, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                ),
              ],
            ),

            SizedBox(height: 12.h),

            // Distance & Status Row
            Row(
              children: [
                // Distance (placeholder - will calculate with rider's location)
                Icon(Icons.location_on, size: 14.w, color: colors.accentGreen),
                SizedBox(width: 4.w),
                Text(
                  '-- km to pickup', // TODO: Calculate with rider location
                  style: TextStyle(color: colors.textSecondary, fontSize: 12.sp, fontWeight: FontWeight.w500),
                ),
                SizedBox(width: 16.w),
                // Status
                Text(
                  statusText,
                  style: TextStyle(color: statusColor, fontSize: 12.sp, fontWeight: FontWeight.w600),
                ),
              ],
            ),

            SizedBox(height: 12.h),

            // Earnings & Payment Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Earnings (prominent)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: colors.accentGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Text(
                    'GHS ${order.totalAmount.toStringAsFixed(2)}',
                    style: TextStyle(color: colors.accentGreen, fontSize: 18.sp, fontWeight: FontWeight.w700),
                  ),
                ),

                // Payment method & item count
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: colors.backgroundPrimary,
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                      child: Text(
                        paymentIcon,
                        style: TextStyle(color: colors.textPrimary, fontSize: 11.sp, fontWeight: FontWeight.w600),
                      ),
                    ),
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

            // Time since order (optional)
            if (timeSince.isNotEmpty) ...[
              SizedBox(height: 8.h),
              Text(
                timeSince,
                style: TextStyle(
                  color: colors.textSecondary.withOpacity(0.7),
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showOrderDetails(AvailableOrderDto order, AppColorsExtension colors) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: colors.backgroundPrimary,
          borderRadius: BorderRadius.only(topLeft: Radius.circular(20.r), topRight: Radius.circular(20.r)),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: EdgeInsets.only(top: 12.h),
              width: 40.w,
              height: 4.h,
              decoration: BoxDecoration(
                color: colors.textSecondary.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            SizedBox(height: 20.h),

            // Header
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Order Details',
                    style: TextStyle(color: colors.textPrimary, fontSize: 20.sp, fontWeight: FontWeight.w700),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: colors.textPrimary),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            Divider(color: colors.border, height: 1),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(20.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Order number and amount
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          order.orderNumber,
                          style: TextStyle(color: colors.textSecondary, fontSize: 14.sp, fontWeight: FontWeight.w500),
                        ),
                        Text(
                          'GHS ${order.totalAmount.toStringAsFixed(2)}',
                          style: TextStyle(color: colors.accentGreen, fontSize: 20.sp, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    SizedBox(height: 24.h),

                    // Restaurant info
                    _buildDetailSection(
                      colors,
                      'Restaurant',
                      order.restaurantName,
                      order.restaurantAddress,
                      Icons.restaurant,
                    ),
                    SizedBox(height: 20.h),

                    // Customer info
                    _buildDetailSection(
                      colors,
                      'Customer',
                      order.customerName,
                      order.customerAddress,
                      Icons.person,
                      subtitle2: order.customerPhone,
                    ),
                    SizedBox(height: 20.h),

                    // Order items
                    Text(
                      'Order Items',
                      style: TextStyle(color: colors.textPrimary, fontSize: 16.sp, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 12.h),
                    ...order.orderItems.map(
                      (item) => Padding(
                        padding: EdgeInsets.only(bottom: 8.h),
                        child: Row(
                          children: [
                            Container(
                              width: 6.w,
                              height: 6.w,
                              decoration: BoxDecoration(color: colors.accentGreen, shape: BoxShape.circle),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Text(
                                item,
                                style: TextStyle(
                                  color: colors.textSecondary,
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    if (order.notes != null && order.notes!.isNotEmpty) ...[
                      SizedBox(height: 20.h),
                      Text(
                        'Special Instructions',
                        style: TextStyle(color: colors.textPrimary, fontSize: 16.sp, fontWeight: FontWeight.w600),
                      ),
                      SizedBox(height: 8.h),
                      Container(
                        padding: EdgeInsets.all(12.w),
                        decoration: BoxDecoration(
                          color: colors.backgroundSecondary,
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Text(
                          order.notes!,
                          style: TextStyle(color: colors.textSecondary, fontSize: 14.sp, fontWeight: FontWeight.w400),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Accept button
            Container(
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                color: colors.backgroundPrimary,
                border: Border(top: BorderSide(color: colors.border, width: 1)),
              ),
              child: SafeArea(
                child: SizedBox(
                  height: 48.h,
                  width: double.infinity,
                  child: AppButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _acceptOrder(order);
                    },
                    buttonText: 'Accept Order',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSection(
    AppColorsExtension colors,
    String title,
    String mainText,
    String? subtitle,
    IconData icon, {
    String? subtitle2,
  }) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(color: colors.backgroundSecondary, borderRadius: BorderRadius.circular(12.r)),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: colors.accentGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(icon, color: colors.accentGreen, size: 24.w),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: colors.textSecondary, fontSize: 12.sp, fontWeight: FontWeight.w500),
                ),
                SizedBox(height: 4.h),
                Text(
                  mainText,
                  style: TextStyle(color: colors.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w600),
                ),
                if (subtitle != null && subtitle.isNotEmpty) ...[
                  SizedBox(height: 4.h),
                  Text(
                    subtitle,
                    style: TextStyle(color: colors.textSecondary, fontSize: 12.sp, fontWeight: FontWeight.w400),
                  ),
                ],
                if (subtitle2 != null && subtitle2.isNotEmpty) ...[
                  SizedBox(height: 2.h),
                  Text(
                    subtitle2,
                    style: TextStyle(color: colors.textSecondary, fontSize: 12.sp, fontWeight: FontWeight.w400),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
