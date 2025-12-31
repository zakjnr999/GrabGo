// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:grab_go_customer/shared/utils/image_optimizer.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:intl/intl.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_customer/features/order/viewmodel/order_provider.dart';
import 'package:provider/provider.dart';

class OrderModel {
  final String id;
  final String orderNumber;
  final String restaurantName;
  final String? restaurantLogo;
  final List<OrderItem> items;
  final double totalAmount;
  final DateTime orderDate;
  final DateTime? expectedDelivery;
  final DateTime? deliveredDate;
  final DateTime? cancelledDate;
  final OrderStatus status;

  OrderModel({
    required this.id,
    required this.orderNumber,
    required this.restaurantName,
    this.restaurantLogo,
    required this.items,
    required this.totalAmount,
    required this.orderDate,
    this.expectedDelivery,
    this.deliveredDate,
    this.cancelledDate,
    required this.status,
  });

  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);
}

class OrderItem {
  final String name;
  final int quantity;
  final double price;
  final String? image;

  OrderItem({required this.name, required this.quantity, required this.price, this.image});
}

enum OrderStatus { pending, ongoing, completed, cancelled }

class Orders extends StatefulWidget {
  const Orders({super.key});

  @override
  State<Orders> createState() => _OrdersState();
}

class _OrdersState extends State<Orders> {
  int selectedTabIndex = 0;
  final List<String> orderTabs = [
    "Pending",
    AppStrings.ordersOngoing,
    AppStrings.ordersCompleted,
    AppStrings.ordersCancelled,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<OrderProvider>(context, listen: false).fetchOrders();
    });
  }

  OrderModel _convertAPIOrderToOrderModel(Map<String, dynamic> apiOrder) {
    // Convert API order to OrderModel
    final items = (apiOrder['items'] as List? ?? []).map((item) {
      // Items have name, quantity, price, and image stored directly
      // Also may have food populated with name, price, image
      final itemName = item['name'] ?? item['food']?['name'] ?? 'Unknown Item';
      final itemPrice = (item['price'] ?? item['food']?['price'] ?? 0.0).toDouble();
      final itemImage = item['image'] ?? item['food']?['image'];

      return OrderItem(name: itemName, quantity: item['quantity'] ?? 1, price: itemPrice, image: itemImage);
    }).toList();

    // Determine order status
    OrderStatus status;
    final orderStatus = (apiOrder['status'] as String? ?? '').toLowerCase();
    switch (orderStatus) {
      case 'pending':
        status = OrderStatus.pending;
        break;
      case 'confirmed':
      case 'preparing':
      case 'ready':
      case 'picked_up':
      case 'on_the_way':
        status = OrderStatus.ongoing;
        break;
      case 'delivered':
        status = OrderStatus.completed;
        break;
      case 'cancelled':
        status = OrderStatus.cancelled;
        break;
      default:
        status = OrderStatus.pending;
    }

    // Extract restaurant name and logo - handle both populated object and ID
    String restaurantName = 'Unknown Restaurant';
    String? restaurantLogo;
    if (apiOrder['restaurant'] != null) {
      if (apiOrder['restaurant'] is Map) {
        restaurantName = apiOrder['restaurant']?['restaurant_name'] ?? 'Unknown Restaurant';
        restaurantLogo = apiOrder['restaurant']?['logo'];
      } else if (apiOrder['restaurant'] is String) {
        restaurantName = 'Restaurant ${apiOrder['restaurant'].substring(0, 8)}...';
      }
    }

    // Parse dates - handle both ISO strings and Date objects
    DateTime? parseDate(dynamic dateValue) {
      if (dateValue == null) return null;
      if (dateValue is String) {
        return DateTime.tryParse(dateValue);
      }
      if (dateValue is int) {
        return DateTime.fromMillisecondsSinceEpoch(dateValue);
      }
      return null;
    }

    final orderDate = parseDate(apiOrder['orderDate'] ?? apiOrder['createdAt']) ?? DateTime.now();
    final expectedDelivery = parseDate(apiOrder['expectedDelivery']);
    final deliveredDate = parseDate(apiOrder['deliveredDate']);
    final cancelledDate = parseDate(apiOrder['cancelledDate']);

    return OrderModel(
      id: apiOrder['_id']?.toString() ?? '',
      orderNumber: apiOrder['orderNumber']?.toString() ?? '',
      restaurantName: restaurantName,
      restaurantLogo: restaurantLogo,
      items: items,
      totalAmount: (apiOrder['totalAmount'] ?? 0.0).toDouble(),
      orderDate: orderDate,
      expectedDelivery: expectedDelivery,
      status: status,
      deliveredDate: deliveredDate,
      cancelledDate: cancelledDate,
    );
  }

  List<OrderModel> _getFilteredOrders(List<Map<String, dynamic>> allOrders) {
    final convertedOrders = allOrders.map((orderData) => _convertAPIOrderToOrderModel(orderData)).toList();

    switch (selectedTabIndex) {
      case 0:
        return convertedOrders.where((order) => order.status == OrderStatus.pending).toList();
      case 1:
        return convertedOrders.where((order) => order.status == OrderStatus.ongoing).toList();
      case 2:
        return convertedOrders.where((order) => order.status == OrderStatus.completed).toList();
      case 3:
        return convertedOrders.where((order) => order.status == OrderStatus.cancelled).toList();
      default:
        return convertedOrders;
    }
  }

  String _getTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d, yyyy').format(timestamp);
    }
  }

  String _formatTime(DateTime dateTime) {
    return DateFormat('h:mm a').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: colors.backgroundSecondary,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: colors.backgroundSecondary,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: colors.backgroundSecondary,
          title: Row(
            children: [
              Container(
                height: 44.h,
                width: 44.w,
                decoration: BoxDecoration(
                  color: colors.backgroundPrimary,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.inputBorder.withOpacity(0.3), width: 0.5),
                  boxShadow: [
                    BoxShadow(
                      color: isDark ? Colors.black.withAlpha(20) : Colors.black.withAlpha(5),
                      spreadRadius: 0,
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => context.pop(),
                    customBorder: const CircleBorder(),
                    child: Padding(
                      padding: EdgeInsets.all(10.r),
                      child: SvgPicture.asset(
                        Assets.icons.navArrowLeft,
                        package: 'grab_go_shared',
                        colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
                      ),
                    ),
                  ),
                ),
              ),

              const Spacer(),

              Container(
                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: colors.backgroundPrimary,
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(color: colors.inputBorder.withOpacity(0.3), width: 0.5),
                  boxShadow: [
                    BoxShadow(
                      color: isDark ? Colors.black.withAlpha(20) : Colors.black.withAlpha(5),
                      spreadRadius: 0,
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: EdgeInsets.all(6.r),
                      decoration: BoxDecoration(color: colors.accentViolet.withOpacity(0.1), shape: BoxShape.circle),
                      child: SvgPicture.asset(
                        Assets.icons.cart,
                        package: 'grab_go_shared',
                        height: 16.h,
                        width: 16.w,
                        colorFilter: ColorFilter.mode(colors.accentViolet, BlendMode.srcIn),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      AppStrings.ordersMyOrders,
                      style: TextStyle(
                        fontFamily: "Lato",
                        package: 'grab_go_shared',
                        color: colors.textPrimary,
                        fontSize: 17.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              Container(
                height: 44.h,
                width: 44.w,
                decoration: BoxDecoration(
                  color: colors.backgroundPrimary,
                  shape: BoxShape.circle,
                  border: Border.all(color: colors.inputBorder.withOpacity(0.3), width: 0.5),
                  boxShadow: [
                    BoxShadow(
                      color: isDark ? Colors.black.withAlpha(20) : Colors.black.withAlpha(5),
                      spreadRadius: 0,
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {},
                    customBorder: const CircleBorder(),
                    child: Padding(
                      padding: EdgeInsets.all(10.r),
                      child: Icon(Icons.more_vert, size: 20.sp, color: colors.textPrimary),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: colors.backgroundSecondary,
        body: Column(
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
              child: AnimatedTabBar(
                tabs: orderTabs,
                padding: EdgeInsets.zero,
                selectedIndex: selectedTabIndex,
                onTabChanged: (index) {
                  setState(() {
                    selectedTabIndex = index;
                  });
                },
              ),
            ),
            Expanded(
              child: Consumer<OrderProvider>(
                builder: (context, orderProvider, _) {
                  if (orderProvider.isLoading && orderProvider.orders.isEmpty) {
                    //when orders are loading..
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(color: colors.accentViolet),
                          SizedBox(height: 16.h),
                          Text(
                            "Loading your orders...",
                            style: TextStyle(fontSize: 16.sp, color: colors.textSecondary, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    );
                  }

                  if (orderProvider.error != null && orderProvider.orders.isEmpty) {
                    //when orders fail to load..
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: EdgeInsets.all(20.r),
                            decoration: BoxDecoration(color: colors.error.withOpacity(0.1), shape: BoxShape.circle),
                            child: Icon(Icons.error_outline, size: 48.sp, color: colors.error),
                          ),
                          SizedBox(height: 16.h),
                          Text(
                            "Failed to load orders",
                            style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
                          ),
                          SizedBox(height: 8.h),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 40.w),
                            child: Text(
                              orderProvider.error!,
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 14.sp, color: colors.textSecondary),
                            ),
                          ),
                          SizedBox(height: 24.h),
                          ElevatedButton(
                            onPressed: () => orderProvider.refreshOrders(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colors.accentViolet,
                              padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                            ),
                            child: Text(
                              "Try Again",
                              style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final filteredOrders = _getFilteredOrders(orderProvider.orders);

                  if (filteredOrders.isEmpty) {
                    return _buildEmptyState(colors);
                  }

                  return RefreshIndicator(
                    color: colors.accentViolet,
                    onRefresh: () => orderProvider.refreshOrders(),
                    child: ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
                      itemCount: filteredOrders.length,
                      separatorBuilder: (context, index) => SizedBox(height: 16.h),
                      itemBuilder: (context, index) {
                        final order = filteredOrders[index];
                        return _buildOrderCard(order, colors, isDark);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(AppColorsExtension colors) {
    String title;
    String message;

    switch (selectedTabIndex) {
      case 0:
        title = "No Pending Orders";
        message = "You don't have any orders waiting for payment.";
        break;
      case 1:
        title = AppStrings.ordersNoOrders;
        message = AppStrings.ordersNoOngoingOrders;
        break;
      case 2:
        title = AppStrings.ordersNoOrders;
        message = AppStrings.ordersNoCompletedOrders;
        break;
      case 3:
        title = AppStrings.ordersNoOrders;
        message = AppStrings.ordersNoCancelledOrders;
        break;
      default:
        title = AppStrings.ordersNoOrders;
        message = '';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(30.r),
            decoration: BoxDecoration(color: colors.accentViolet.withOpacity(0.1), shape: BoxShape.circle),
            child: SvgPicture.asset(
              Assets.icons.cart,
              package: 'grab_go_shared',
              height: 80.h,
              width: 80.w,
              colorFilter: ColorFilter.mode(colors.accentViolet.withOpacity(0.5), BlendMode.srcIn),
            ),
          ),
          SizedBox(height: 24.h),
          Text(
            title,
            style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w800, color: colors.textPrimary),
          ),
          SizedBox(height: 8.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 40.w),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w500, color: colors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(OrderModel order, AppColorsExtension colors, bool isDark) {
    final isCancelled = order.status == OrderStatus.cancelled;
    final isOngoing = order.status == OrderStatus.ongoing;
    final isPending = order.status == OrderStatus.pending;

    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withAlpha(30) : Colors.black.withAlpha(8),
            spreadRadius: 0,
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          AppStrings.ordersOrderNumber,
                          style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w500, color: colors.textSecondary),
                        ),
                        Flexible(
                          child: Padding(
                            padding: EdgeInsets.only(right: 12.w),
                            child: Text(
                              order.orderNumber,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      _getTimeAgo(order.orderDate),
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w500,
                        color: colors.textSecondary.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: isCancelled
                      ? colors.error.withOpacity(0.15)
                      : isPending
                      ? colors.accentViolet.withOpacity(0.15)
                      : isOngoing
                      ? colors.accentOrange.withOpacity(0.15)
                      : colors.accentGreen.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(
                  order.status == OrderStatus.pending
                      ? "Pending Payment"
                      : order.status == OrderStatus.ongoing
                      ? AppStrings.ordersOngoing
                      : order.status == OrderStatus.completed
                      ? AppStrings.ordersCompleted
                      : AppStrings.ordersCancelled,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: isCancelled
                        ? colors.error
                        : isPending
                        ? colors.accentViolet
                        : isOngoing
                        ? colors.accentOrange
                        : colors.accentGreen,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              CachedNetworkImage(
                imageUrl: ImageOptimizer.getPreviewUrl(order.restaurantLogo ?? '', width: 200),
                width: 60.w,
                height: 60.h,
                fit: BoxFit.cover,
                memCacheWidth: 200,
                maxHeightDiskCache: 200,
                imageBuilder: (context, imageProvider) => Container(
                  width: 60.w,
                  height: 60.h,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12.r),
                    image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
                  ),
                ),
                placeholder: (context, url) => Container(
                  width: 60.w,
                  height: 60.h,
                  padding: EdgeInsets.all(10.r),
                  decoration: BoxDecoration(
                    color: colors.backgroundSecondary,
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: SvgPicture.asset(
                    Assets.icons.chefHat,
                    package: "grab_go_shared",
                    colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
                  ),
                ),
                errorWidget: (context, url, error) => ClipRRect(
                  borderRadius: BorderRadius.circular(12.r),
                  child: Assets.images.sampleOne.image(
                    width: 60.w,
                    height: 60.h,
                    fit: BoxFit.cover,
                    package: 'grab_go_shared',
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.restaurantName,
                      style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      '${order.itemCount} ${order.itemCount == 1 ? AppStrings.ordersItem : AppStrings.ordersItems} ${AppStrings.ordersFrom} ${order.restaurantName.split(' - ')[0]}',
                      style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w500, color: colors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          ...order.items
              .take(2)
              .map(
                (item) => Padding(
                  padding: EdgeInsets.only(bottom: 8.h),
                  child: Row(
                    children: [
                      Container(
                        width: 6.w,
                        height: 6.h,
                        decoration: BoxDecoration(color: colors.accentOrange, shape: BoxShape.circle),
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          '${item.quantity}x ${item.name}',
                          style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w500, color: colors.textSecondary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${AppStrings.currencySymbol} ${item.price.toStringAsFixed(2)}',
                        style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: colors.textPrimary),
                      ),
                    ],
                  ),
                ),
              ),
          if (order.items.length > 2)
            Padding(
              padding: EdgeInsets.only(left: 14.w, top: 4.h),
              child: Text(
                '+ ${order.items.length - 2} more ${order.items.length - 2 == 1 ? AppStrings.ordersItem : AppStrings.ordersItems}',
                style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w500, color: colors.accentOrange),
              ),
            ),
          SizedBox(height: 16.h),
          Container(
            padding: EdgeInsets.all(12.r),
            decoration: BoxDecoration(color: colors.backgroundSecondary, borderRadius: BorderRadius.circular(12.r)),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.r),
                  decoration: BoxDecoration(
                    color: isCancelled
                        ? colors.error.withOpacity(0.1)
                        : isPending
                        ? colors.accentViolet.withOpacity(0.1)
                        : isOngoing
                        ? colors.accentOrange.withOpacity(0.1)
                        : colors.accentGreen.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: SvgPicture.asset(
                    isCancelled
                        ? Assets.icons.binMinusIn
                        : isPending
                        ? Assets.icons.creditCard
                        : isOngoing
                        ? Assets.icons.deliveryTruck
                        : Assets.icons.check,
                    package: 'grab_go_shared',
                    height: 16.h,
                    width: 16.w,
                    colorFilter: ColorFilter.mode(
                      isCancelled
                          ? colors.error
                          : isPending
                          ? colors.accentViolet
                          : isOngoing
                          ? colors.accentOrange
                          : colors.accentGreen,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isCancelled
                            ? AppStrings.ordersCancelledOn
                            : isPending
                            ? "Awaiting Payment"
                            : isOngoing
                            ? AppStrings.ordersExpectedDelivery
                            : AppStrings.ordersDeliveredOn,
                        style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w500, color: colors.textSecondary),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        isCancelled
                            ? (order.cancelledDate != null
                                  ? '${_getTimeAgo(order.cancelledDate!)} at ${_formatTime(order.cancelledDate!)}'
                                  : 'N/A')
                            : isPending
                            ? "Complete payment to proceed"
                            : isOngoing
                            ? (order.expectedDelivery != null ? _formatTime(order.expectedDelivery!) : 'N/A')
                            : (order.deliveredDate != null
                                  ? '${_getTimeAgo(order.deliveredDate!)} at ${_formatTime(order.deliveredDate!)}'
                                  : 'N/A'),
                        style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${AppStrings.currencySymbol} ${order.totalAmount.toStringAsFixed(2)}',
                  style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800, color: colors.accentOrange),
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),
          if (isPending)
            GestureDetector(
              onTap: () {
                // Navigate back to payment for this order
                context.push("/checkout", extra: order);
              },
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 14.h),
                decoration: BoxDecoration(color: colors.accentViolet, borderRadius: BorderRadius.circular(12.r)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SvgPicture.asset(
                      Assets.icons.creditCard,
                      package: 'grab_go_shared',
                      height: 16.h,
                      width: 16.w,
                      colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      "Complete Payment",
                      style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ],
                ),
              ),
            )
          else if (isOngoing)
            GestureDetector(
              onTap: () {
                context.push("/mapTracking");
              },
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 14.h),
                decoration: BoxDecoration(color: colors.accentOrange, borderRadius: BorderRadius.circular(12.r)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SvgPicture.asset(
                      Assets.icons.deliveryTruck,
                      package: 'grab_go_shared',
                      height: 16.h,
                      width: 16.w,
                      colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                    ),
                    SizedBox(width: 8.w),
                    Text(
                      AppStrings.ordersTrackOrder,
                      style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ],
                ),
              ),
            )
          else
            GestureDetector(
              onTap: () {
                // View order details
                // context.push("/orderDetails", extra: order);
              },
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 14.h),
                decoration: BoxDecoration(
                  color: colors.backgroundSecondary,
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: colors.inputBorder.withOpacity(0.3), width: 0.5),
                ),
                child: Text(
                  AppStrings.ordersViewDetails,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
