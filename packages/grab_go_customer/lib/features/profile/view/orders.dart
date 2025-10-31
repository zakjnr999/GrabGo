// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:intl/intl.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class OrderModel {
  final String id;
  final String orderNumber;
  final String restaurantName;
  final Image restaurantImage;
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
    required this.restaurantImage,
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

enum OrderStatus { ongoing, completed, cancelled }

class Orders extends StatefulWidget {
  const Orders({super.key});

  @override
  State<Orders> createState() => _OrdersState();
}

class _OrdersState extends State<Orders> {
  int selectedTabIndex = 0;
  final List<String> orderTabs = [AppStrings.ordersOngoing, AppStrings.ordersCompleted, AppStrings.ordersCancelled];

  List<OrderModel> _allOrders = [];
  List<OrderModel> _filteredOrders = [];

  @override
  void initState() {
    super.initState();
    _loadSampleOrders();
    _filterOrders();
  }

  void _loadSampleOrders() {
    final now = DateTime.now();

    _allOrders = [
      OrderModel(
        id: '1',
        orderNumber: '1234',
        restaurantName: 'KFC - Accra Mall',
        restaurantImage: Assets.images.sampleOne.image(package: 'grab_go_shared'),
        items: [
          OrderItem(name: 'Zinger Burger', quantity: 2, price: 45.00),
          OrderItem(name: 'French Fries', quantity: 1, price: 15.00),
          OrderItem(name: 'Coca Cola', quantity: 2, price: 10.00),
        ],
        totalAmount: 125.00,
        orderDate: now.subtract(const Duration(minutes: 30)),
        expectedDelivery: now.add(const Duration(minutes: 30)),
        status: OrderStatus.ongoing,
      ),
      OrderModel(
        id: '2',
        orderNumber: '1235',
        restaurantName: 'Papa\'s Pizza',
        restaurantImage: Assets.images.sampleTwo.image(package: 'grab_go_shared'),
        items: [
          OrderItem(name: 'Margherita Pizza (Large)', quantity: 1, price: 85.00),
          OrderItem(name: 'Garlic Bread', quantity: 2, price: 25.00),
        ],
        totalAmount: 135.00,
        orderDate: now.subtract(const Duration(hours: 1)),
        expectedDelivery: now.add(const Duration(hours: 1)),
        status: OrderStatus.ongoing,
      ),
      OrderModel(
        id: '3',
        orderNumber: '1233',
        restaurantName: 'Chicken Republic',
        restaurantImage: Assets.images.sampleThree.image(package: 'grab_go_shared'),
        items: [
          OrderItem(name: 'Grilled Chicken', quantity: 2, price: 60.00),
          OrderItem(name: 'Jollof Rice', quantity: 2, price: 30.00),
          OrderItem(name: 'Coleslaw', quantity: 2, price: 15.00),
        ],
        totalAmount: 210.00,
        orderDate: now.subtract(const Duration(days: 1)),
        deliveredDate: now.subtract(const Duration(hours: 23)),
        status: OrderStatus.completed,
      ),
      OrderModel(
        id: '4',
        orderNumber: '1232',
        restaurantName: 'Burger King',
        restaurantImage: Assets.images.sampleFour.image(package: 'grab_go_shared'),
        items: [
          OrderItem(name: 'Whopper Burger', quantity: 1, price: 50.00),
          OrderItem(name: 'Onion Rings', quantity: 1, price: 20.00),
          OrderItem(name: 'Milkshake', quantity: 1, price: 25.00),
        ],
        totalAmount: 95.00,
        orderDate: now.subtract(const Duration(days: 2)),
        deliveredDate: now.subtract(const Duration(days: 2, hours: -1)),
        status: OrderStatus.completed,
      ),
      OrderModel(
        id: '5',
        orderNumber: '1231',
        restaurantName: 'Subway',
        restaurantImage: Assets.images.sampleOne.image(package: 'grab_go_shared'),
        items: [
          OrderItem(name: 'Turkey Sub (12 inch)', quantity: 2, price: 70.00),
          OrderItem(name: 'Cookies', quantity: 4, price: 20.00),
        ],
        totalAmount: 160.00,
        orderDate: now.subtract(const Duration(days: 3)),
        deliveredDate: now.subtract(const Duration(days: 3, hours: -30, minutes: 30)),
        status: OrderStatus.completed,
      ),
      OrderModel(
        id: '6',
        orderNumber: '1230',
        restaurantName: 'Pizza Hut',
        restaurantImage: Assets.images.sampleTwo.image(package: 'grab_go_shared'),
        items: [
          OrderItem(name: 'Pepperoni Pizza (Large)', quantity: 1, price: 90.00),
          OrderItem(name: 'Chicken Wings', quantity: 1, price: 40.00),
        ],
        totalAmount: 130.00,
        orderDate: now.subtract(const Duration(days: 4)),
        cancelledDate: now.subtract(const Duration(days: 4, hours: -1)),
        status: OrderStatus.cancelled,
      ),
      OrderModel(
        id: '7',
        orderNumber: '1229',
        restaurantName: 'McDonald\'s',
        restaurantImage: Assets.images.sampleThree.image(package: 'grab_go_shared'),
        items: [
          OrderItem(name: 'Big Mac', quantity: 1, price: 45.00),
          OrderItem(name: 'McFlurry', quantity: 1, price: 18.00),
        ],
        totalAmount: 63.00,
        orderDate: now.subtract(const Duration(days: 5)),
        cancelledDate: now.subtract(const Duration(days: 5, hours: -30)),
        status: OrderStatus.cancelled,
      ),
    ];
  }

  void _filterOrders() {
    setState(() {
      switch (selectedTabIndex) {
        case 0:
          _filteredOrders = _allOrders.where((order) => order.status == OrderStatus.ongoing).toList();
          break;
        case 1:
          _filteredOrders = _allOrders.where((order) => order.status == OrderStatus.completed).toList();
          break;
        case 2:
          _filteredOrders = _allOrders.where((order) => order.status == OrderStatus.cancelled).toList();
          break;
      }
    });
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
          title: Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.w),
            child: Row(
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
                  _filterOrders();
                },
              ),
            ),
            Expanded(
              child: _filteredOrders.isEmpty
                  ? _buildEmptyState(colors)
                  : ListView.separated(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
                      itemCount: _filteredOrders.length,
                      separatorBuilder: (context, index) => SizedBox(height: 16.h),
                      itemBuilder: (context, index) {
                        final order = _filteredOrders[index];
                        return _buildOrderCard(order, colors, isDark);
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
        title = AppStrings.ordersNoOrders;
        message = AppStrings.ordersNoOngoingOrders;
        break;
      case 1:
        title = AppStrings.ordersNoOrders;
        message = AppStrings.ordersNoCompletedOrders;
        break;
      case 2:
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
                        Text(
                          order.orderNumber,
                          style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
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
                      : isOngoing
                      ? colors.accentOrange.withOpacity(0.15)
                      : colors.accentGreen.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(
                  order.status == OrderStatus.ongoing
                      ? AppStrings.ordersOngoing
                      : order.status == OrderStatus.completed
                      ? AppStrings.ordersCompleted
                      : AppStrings.ordersCancelled,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                    color: isCancelled
                        ? colors.error
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
              ClipRRect(
                borderRadius: BorderRadius.circular(12.r),
                child: Assets.images.sampleOne.image(
                  width: 60.w,
                  height: 60.h,
                  fit: BoxFit.cover,
                  package: 'grab_go_shared',
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
                        : isOngoing
                        ? colors.accentOrange.withOpacity(0.1)
                        : colors.accentGreen.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: SvgPicture.asset(
                    isCancelled
                        ? Assets.icons.binMinusIn
                        : isOngoing
                        ? Assets.icons.deliveryTruck
                        : Assets.icons.check,
                    package: 'grab_go_shared',
                    height: 16.h,
                    width: 16.w,
                    colorFilter: ColorFilter.mode(
                      isCancelled
                          ? colors.error
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
          if (isOngoing)
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
