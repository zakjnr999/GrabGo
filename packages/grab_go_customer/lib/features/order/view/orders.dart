import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:grab_go_customer/shared/widgets/order_skeleton.dart';
import 'package:grab_go_customer/shared/widgets/umbrella_header.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:intl/intl.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_customer/features/order/viewmodel/order_provider.dart';
import 'package:grab_go_customer/features/cart/viewmodel/cart_provider.dart';
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
  final String? paymentStatus;
  final Map<String, dynamic> rawOrder;

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
    this.paymentStatus,
    required this.rawOrder,
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

class _OrdersState extends State<Orders> with SingleTickerProviderStateMixin {
  int selectedTabIndex = 0;
  late TabController _tabController;

  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _scrollOffsetNotifier = ValueNotifier<double>(0.0);
  static const double _collapsedHeight = 70.0;
  static const double _scrollThreshold = 150.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          selectedTabIndex = _tabController.index;
        });
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<OrderProvider>(context, listen: false).fetchOrders();
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _scrollOffsetNotifier.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    _scrollOffsetNotifier.value = _scrollController.offset;
  }

  OrderModel _convertAPIOrderToOrderModel(Map<String, dynamic> apiOrder) {
    final items = (apiOrder['items'] as List? ?? []).map((item) {
      final itemName = item['name'] ?? item['food']?['name'] ?? 'Unknown Item';
      final itemPrice = (item['price'] ?? item['food']?['price'] ?? 0.0).toDouble();
      final itemImage = item['image'] ?? item['food']?['image'];

      return OrderItem(name: itemName, quantity: item['quantity'] ?? 1, price: itemPrice, image: itemImage);
    }).toList();

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

    String restaurantName = 'Unknown Restaurant';
    String? restaurantLogo;
    if (apiOrder['restaurant'] != null && apiOrder['restaurant'] is Map) {
      restaurantName = apiOrder['restaurant']?['restaurantName'] ?? 'Unknown Restaurant';
      restaurantLogo = apiOrder['restaurant']?['logo'];
    } else if (apiOrder['groceryStore'] != null && apiOrder['groceryStore'] is Map) {
      restaurantName = apiOrder['groceryStore']?['storeName'] ?? 'Unknown Store';
      restaurantLogo = apiOrder['groceryStore']?['logo'];
    } else if (apiOrder['pharmacyStore'] != null && apiOrder['pharmacyStore'] is Map) {
      restaurantName = apiOrder['pharmacyStore']?['storeName'] ?? 'Unknown Store';
      restaurantLogo = apiOrder['pharmacyStore']?['logo'];
    } else if (apiOrder['restaurant'] is String) {
      restaurantName = 'Restaurant ${apiOrder['restaurant'].substring(0, 8)}...';
    }

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

    final paymentStatus = (apiOrder['paymentStatus'] as String?)?.toLowerCase();

    return OrderModel(
      id: apiOrder['id']?.toString() ?? apiOrder['_id']?.toString() ?? '',
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
      paymentStatus: paymentStatus,
      rawOrder: apiOrder,
    );
  }

  List<OrderModel> _getFilteredOrders(List<Map<String, dynamic>> allOrders) {
    final convertedOrders = allOrders.map((orderData) => _convertAPIOrderToOrderModel(orderData)).toList();

    switch (selectedTabIndex) {
      case 0:
        return convertedOrders
            .where((order) => order.status == OrderStatus.pending || order.status == OrderStatus.ongoing)
            .toList();
      case 1:
        return convertedOrders
            .where((order) => order.status == OrderStatus.completed || order.status == OrderStatus.cancelled)
            .toList();
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

  bool _isVendorOpen(OrderModel order) {
    final raw = order.rawOrder;
    final orderType = raw['orderType']?.toString().toLowerCase();

    Map<String, dynamic>? vendor;
    if (orderType == 'food' || raw['restaurant'] is Map) {
      vendor = (raw['restaurant'] as Map?)?.cast<String, dynamic>();
    } else if (orderType == 'grocery' || raw['groceryStore'] is Map) {
      vendor = (raw['groceryStore'] as Map?)?.cast<String, dynamic>();
    } else if (orderType == 'pharmacy' || raw['pharmacyStore'] is Map) {
      vendor = (raw['pharmacyStore'] as Map?)?.cast<String, dynamic>();
    }

    if (vendor == null) return true;

    final isOpen = vendor['isOpen'];
    if (isOpen is bool && !isOpen) return false;

    final isAcceptingOrders = vendor['isAcceptingOrders'];
    if (isAcceptingOrders is bool && !isAcceptingOrders) return false;

    final status = vendor['status']?.toString().toLowerCase();
    if (status != null && status.isNotEmpty && status != 'approved') return false;

    return true;
  }

  String _vendorClosedTitle(OrderModel order) {
    final orderType = order.rawOrder['orderType']?.toString().toLowerCase();
    if (orderType == 'grocery') return 'Store Closed';
    if (orderType == 'pharmacy') return 'Pharmacy Closed';
    return 'Restaurant Closed';
  }

  String _vendorClosedMessage(OrderModel order) {
    final orderType = order.rawOrder['orderType']?.toString().toLowerCase();
    if (orderType == 'grocery') {
      return 'This store is currently closed or not accepting orders. Please try again later.';
    }
    if (orderType == 'pharmacy') {
      return 'This pharmacy is currently closed or not accepting orders. Please try again later.';
    }
    return 'This restaurant is currently closed or not accepting orders. Please try again later.';
  }

  Future<void> _retryPayment(BuildContext context, OrderModel order) async {
    LoadingDialog.instance().show(context: context, text: 'Preparing checkout...');
    final cartProvider = context.read<CartProvider>();

    try {
      final success = await cartProvider.replaceCartWithOrder(order.rawOrder);
      LoadingDialog.instance().hide();

      if (!success) {
        AppDialog.show(
          context: context,
          type: AppDialogType.error,
          title: 'Unable to retry payment',
          message: 'We could not rebuild your cart for this order. Please contact support.',
          primaryButtonText: 'OK',
        );
        return;
      }

      if (!context.mounted) return;
      context.push('/checkout');
    } catch (e) {
      LoadingDialog.instance().hide();
      AppDialog.show(
        context: context,
        type: AppDialogType.error,
        title: 'Retry failed',
        message: 'Something went wrong while preparing your order. Please try again.',
        primaryButtonText: 'OK',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final padding = MediaQuery.paddingOf(context);
    final size = MediaQuery.sizeOf(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: colors.accentOrange,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: colors.backgroundPrimary,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: colors.backgroundPrimary,
        body: SafeArea(
          top: false,
          child: ClipRect(
            child: Stack(
              children: [
                Column(
                  children: [
                    ValueListenableBuilder<double>(
                      valueListenable: _scrollOffsetNotifier,
                      builder: (context, scrollOffset, _) {
                        final currentHeight = _currentHeaderHeight(size, scrollOffset);
                        return SizedBox(height: currentHeight);
                      },
                    ),
                    _buildTabs(colors),
                    Expanded(
                      child: Consumer<OrderProvider>(
                        builder: (context, orderProvider, _) {
                          if (orderProvider.isLoading && orderProvider.orders.isEmpty) {
                            return OrderSkeleton(colors: colors, isDark: isDark);
                          }

                          final filteredOrders = _getFilteredOrders(orderProvider.orders);

                          if (filteredOrders.isEmpty) {
                            return _buildEmptyState(colors);
                          }

                          return AppRefreshIndicator(
                            iconPath: Assets.icons.boxIso,
                            bgColor: colors.accentOrange,
                            onRefresh: () => orderProvider.refreshOrders(),
                            child: ListView.separated(
                              controller: _scrollController,
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
                              itemCount: filteredOrders.length,
                              separatorBuilder: (context, index) {
                                return Column(
                                  children: [
                                    SizedBox(height: 16.h),
                                    DottedLine(
                                      dashLength: 6,
                                      dashGapLength: 4,
                                      lineThickness: 1,
                                      dashColor: colors.textSecondary.withAlpha(50),
                                    ),
                                    SizedBox(height: 16.h),
                                  ],
                                );
                              },
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
                Positioned(top: 0, left: 0, right: 0, child: _buildCollapsibleUmbrellaHeader(colors, size, padding)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabs(AppColorsExtension colors) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, -0.1), end: Offset.zero).animate(animation),
            child: child,
          ),
        );
      },
      child: Container(
        key: const ValueKey('tabs'),
        margin: EdgeInsets.symmetric(horizontal: 20.w),
        padding: EdgeInsets.all(4.r),
        decoration: BoxDecoration(
          color: colors.backgroundSecondary,
          borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
        ),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            color: colors.accentOrange,
            borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          labelColor: Colors.white,
          unselectedLabelColor: colors.textSecondary,
          labelStyle: TextStyle(
            fontFamily: "Lato",
            package: "grab_go_shared",
            fontSize: 13.sp,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelStyle: TextStyle(
            fontFamily: "Lato",
            package: 'grab_go_shared',
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
          ),
          tabs: const [
            Tab(text: AppStrings.ordersOngoing),
            Tab(text: AppStrings.ordersCompleted),
          ],
        ),
      ),
    );
  }

  Widget _buildCollapsibleUmbrellaHeader(AppColorsExtension colors, Size size, EdgeInsets padding) {
    return ValueListenableBuilder<double>(
      valueListenable: _scrollOffsetNotifier,
      builder: (context, scrollOffset, _) {
        final collapseProgress = (scrollOffset / _scrollThreshold).clamp(0.0, 1.0);
        final currentHeight = _currentHeaderHeight(size, scrollOffset);
        final contentOpacity = (1.0 - collapseProgress).clamp(0.0, 1.0);

        return SizedBox(
          width: size.width,
          height: currentHeight,
          child: UmbrellaHeaderWithShadow(
            curveDepth: 25.h,
            numberOfCurves: 10,
            height: currentHeight,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 100),
              opacity: contentOpacity,
              child: _buildUmbrellaContent(colors, padding),
            ),
          ),
        );
      },
    );
  }

  double _currentHeaderHeight(Size size, double scrollOffset) {
    final collapseProgress = (scrollOffset / _scrollThreshold).clamp(0.0, 1.0);
    final expandedHeight = size.height * 0.20;
    return expandedHeight - ((expandedHeight - _collapsedHeight) * collapseProgress);
  }

  Widget _buildUmbrellaContent(AppColorsExtension colors, EdgeInsets padding) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20.w, padding.top + 12.h, 10.w, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "My Orders",
                  style: TextStyle(
                    fontFamily: "Lato",
                    package: 'grab_go_shared',
                    color: Colors.white,
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              CustomPopupMenu(
                menuWidth: 280.w,
                showArrow: false,
                items: [
                  CustomPopupMenuItem(
                    value: 'sort',
                    label: 'Sort Favorites',
                    icon: Assets.icons.sort,
                    iconColor: colors.textSecondary,
                  ),
                  CustomPopupMenuItem(
                    value: 'clear',
                    label: 'Clear All Favorites',
                    icon: Assets.icons.brushCleaning,
                    iconColor: colors.textSecondary,
                  ),
                ],
                onSelected: (value) {
                  switch (value) {
                    case "sort":
                      debugPrint("sort");
                    case "clear":
                  }
                },
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      context.push("/notification");
                    },
                    customBorder: const CircleBorder(),
                    child: Padding(
                      padding: EdgeInsets.all(10.r),
                      child: SvgPicture.asset(
                        Assets.icons.moreVertical,
                        package: 'grab_go_shared',
                        colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Text(
            "Track ongoing, completed, and cancelled orders",
            style: TextStyle(
              fontFamily: "Lato",
              package: 'grab_go_shared',
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 14.sp,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
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
        message = "You don't have any completed or cancelled orders yet.";
        break;
      default:
        title = AppStrings.ordersNoOrders;
        message = '';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
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
    final isPaymentPending = order.paymentStatus == 'pending' || order.paymentStatus == 'processing';
    final isVendorOpen = _isVendorOpen(order);

    return Container(
      color: colors.backgroundPrimary,
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
                    Text(
                      _getTimeAgo(order.orderDate),
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w500,
                        color: colors.textSecondary.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: isCancelled
                      ? colors.error.withValues(alpha: 0.15)
                      : isPending
                      ? colors.accentOrange.withValues(alpha: 0.15)
                      : isOngoing
                      ? colors.accentOrange.withValues(alpha: 0.15)
                      : colors.accentGreen.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(
                  order.status == OrderStatus.pending
                      ? (isPaymentPending ? "Pending Payment" : "Awaiting Confirmation")
                      : order.status == OrderStatus.ongoing
                      ? AppStrings.ordersOngoing
                      : order.status == OrderStatus.completed
                      ? AppStrings.ordersCompleted
                      : AppStrings.ordersCancelled,
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w700,
                    color: isCancelled
                        ? colors.error
                        : isPending
                        ? colors.accentOrange
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
                    borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
                    image: DecorationImage(image: imageProvider, fit: BoxFit.cover),
                  ),
                ),
                placeholder: (context, url) => Container(
                  width: 60.w,
                  height: 60.h,
                  padding: EdgeInsets.all(10.r),
                  decoration: BoxDecoration(
                    color: colors.backgroundSecondary,
                    borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
                  ),
                  child: SvgPicture.asset(
                    Assets.icons.chefHat,
                    package: "grab_go_shared",
                    colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
                  ),
                ),
                errorWidget: (context, url, error) => ClipRRect(
                  borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
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
            decoration: BoxDecoration(
              color: colors.backgroundSecondary,
              borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isCancelled
                            ? AppStrings.ordersCancelledOn
                            : isPending
                            ? (isPaymentPending ? "Awaiting Payment" : "Awaiting Confirmation")
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
                            ? (isPaymentPending ? "Complete payment to proceed" : "Waiting for the vendor to accept")
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

                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Total Amount",
                      style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w500, color: colors.textSecondary),
                    ),
                    Text(
                      '${AppStrings.currencySymbol} ${order.totalAmount.toStringAsFixed(2)}',
                      style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w800, color: colors.accentOrange),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 16.h),
          if (isPending && isPaymentPending)
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    onPressed: () => context.push("/checkout", extra: order),
                    buttonText: "Cancel Order",
                    backgroundColor: colors.backgroundSecondary,
                    height: KWidgetSize.buttonHeight.h,
                    borderRadius: KBorderSize.borderMedium,
                    textStyle: TextStyle(color: colors.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w700),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: AppButton(
                    onPressed: () {
                      if (isVendorOpen) {
                        _retryPayment(context, order);
                        return;
                      }
                      AppDialog.show(
                        context: context,
                        type: AppDialogType.warning,
                        title: _vendorClosedTitle(order),
                        message: _vendorClosedMessage(order),
                        primaryButtonText: 'OK',
                      );
                    },
                    buttonText: isVendorOpen ? "Complete Payment" : "Vendor Closed",
                    backgroundColor: isVendorOpen ? colors.accentOrange : colors.backgroundSecondary,
                    height: KWidgetSize.buttonHeight.h,
                    borderRadius: KBorderSize.borderMedium,
                    borderColor: isVendorOpen ? null : colors.border,
                    textStyle: TextStyle(
                      color: isVendorOpen ? Colors.white : colors.textSecondary,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            )
          else if (isOngoing)
            AppButton(
              onPressed: () => context.push("/mapTracking?orderId=${order.id}"),
              buttonText: "Track Order",
              backgroundColor: colors.accentOrange,
              width: double.infinity,
              height: KWidgetSize.buttonHeight.h,
              borderRadius: KBorderSize.borderMedium,
              textStyle: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w700),
            ),
        ],
      ),
    );
  }
}
