import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:grab_go_customer/features/order/service/order_service_wrapper.dart';
import 'package:grab_go_customer/features/order/view/vendor_rating.dart';
import 'package:grab_go_customer/shared/services/paystack_service.dart'
    as paystack;
import 'package:grab_go_customer/shared/services/user_service.dart';
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
  final String? groupOrderNumber;
  final String? groupId;
  final String? checkoutSessionId;
  final bool isGroupedOrder;
  final int? groupVendorCount;
  final double? groupTotalAmount;
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
  final bool canRateVendor;
  final bool vendorRatingSubmitted;
  final int? vendorRatingValue;
  final DateTime? vendorRatedAt;
  final Map<String, dynamic> rawOrder;

  OrderModel({
    required this.id,
    required this.orderNumber,
    this.groupOrderNumber,
    this.groupId,
    this.checkoutSessionId,
    this.isGroupedOrder = false,
    this.groupVendorCount,
    this.groupTotalAmount,
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
    this.canRateVendor = false,
    this.vendorRatingSubmitted = false,
    this.vendorRatingValue,
    this.vendorRatedAt,
    required this.rawOrder,
  });

  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);
}

class OrderItem {
  final String name;
  final int quantity;
  final double price;
  final String? image;
  final Map<String, dynamic>? selectedPortion;
  final List<Map<String, dynamic>> selectedPreferences;
  final String? itemNote;

  OrderItem({
    required this.name,
    required this.quantity,
    required this.price,
    this.image,
    this.selectedPortion,
    this.selectedPreferences = const [],
    this.itemNote,
  });
}

enum OrderStatus { pending, ongoing, completed, cancelled }

class Orders extends StatefulWidget {
  const Orders({super.key});

  @override
  State<Orders> createState() => _OrdersState();
}

class _OrdersState extends State<Orders> {
  int selectedTabIndex = 0;
  final List<String> _orderTabs = [
    AppStrings.ordersOngoing,
    AppStrings.ordersCompleted,
  ];
  bool? _wasLoggedIn;

  final ScrollController _scrollController = ScrollController();
  final ValueNotifier<double> _scrollOffsetNotifier = ValueNotifier<double>(
    0.0,
  );
  static const double _collapsedHeight = 70.0;
  static const double _scrollThreshold = 150.0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _wasLoggedIn = UserService().isLoggedIn;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final orderProvider = Provider.of<OrderProvider>(context, listen: false);
      if (UserService().isLoggedIn) {
        orderProvider.fetchOrders();
      } else {
        orderProvider.clearOrders();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _scrollOffsetNotifier.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    _scrollOffsetNotifier.value = _scrollController.offset;
  }

  void _syncAuthState() {
    final isLoggedIn = UserService().isLoggedIn;
    if (_wasLoggedIn == isLoggedIn) return;

    _wasLoggedIn = isLoggedIn;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final orderProvider = context.read<OrderProvider>();
      if (isLoggedIn) {
        orderProvider.fetchOrders();
      } else {
        orderProvider.clearOrders();
      }
    });
  }

  OrderModel _convertAPIOrderToOrderModel(Map<String, dynamic> apiOrder) {
    final items = (apiOrder['items'] as List? ?? []).map((item) {
      final itemName = item['name'] ?? item['food']?['name'] ?? 'Unknown Item';
      final itemPrice = _toDouble(item['price'] ?? item['food']?['price']);
      final itemImage = item['image'] ?? item['food']?['image'];
      final selectedPortion = item['selectedPortion'] is Map
          ? Map<String, dynamic>.from(item['selectedPortion'])
          : null;
      final selectedPreferences = item['selectedPreferences'] is List
          ? (item['selectedPreferences'] as List)
                .whereType<Map>()
                .map((entry) => Map<String, dynamic>.from(entry))
                .toList(growable: false)
          : const <Map<String, dynamic>>[];
      final itemNote = item['itemNote']?.toString();

      return OrderItem(
        name: itemName,
        quantity: _toInt(item['quantity'], fallback: 1),
        price: itemPrice,
        image: itemImage,
        selectedPortion: selectedPortion,
        selectedPreferences: selectedPreferences,
        itemNote: itemNote,
      );
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
      restaurantName =
          apiOrder['restaurant']?['restaurantName'] ?? 'Unknown Restaurant';
      restaurantLogo = apiOrder['restaurant']?['logo'];
    } else if (apiOrder['groceryStore'] != null &&
        apiOrder['groceryStore'] is Map) {
      restaurantName =
          apiOrder['groceryStore']?['storeName'] ?? 'Unknown Store';
      restaurantLogo = apiOrder['groceryStore']?['logo'];
    } else if (apiOrder['pharmacyStore'] != null &&
        apiOrder['pharmacyStore'] is Map) {
      restaurantName =
          apiOrder['pharmacyStore']?['storeName'] ?? 'Unknown Store';
      restaurantLogo = apiOrder['pharmacyStore']?['logo'];
    } else if (apiOrder['grabMartStore'] != null &&
        apiOrder['grabMartStore'] is Map) {
      restaurantName =
          apiOrder['grabMartStore']?['storeName'] ?? 'Unknown Store';
      restaurantLogo = apiOrder['grabMartStore']?['logo'];
    } else if (apiOrder['restaurant'] is String) {
      restaurantName =
          'Restaurant ${apiOrder['restaurant'].substring(0, 8)}...';
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

    final orderDate =
        parseDate(apiOrder['orderDate'] ?? apiOrder['createdAt']) ??
        DateTime.now();
    final expectedDelivery = parseDate(apiOrder['expectedDelivery']);
    final deliveredDate = parseDate(apiOrder['deliveredDate']);
    final cancelledDate = parseDate(apiOrder['cancelledDate']);

    final paymentStatus = (apiOrder['paymentStatus'] as String?)?.toLowerCase();
    final canRateVendor = apiOrder['canRateVendor'] == true;
    final vendorRatingSubmitted = apiOrder['vendorRatingSubmitted'] == true;
    final vendorRatingValueRaw = apiOrder['vendorRatingValue'];
    final vendorRatingValue = vendorRatingValueRaw is num
        ? vendorRatingValueRaw.toInt()
        : int.tryParse(vendorRatingValueRaw?.toString() ?? '');
    final vendorRatedAt = parseDate(apiOrder['vendorRatedAt']);
    final groupMeta = apiOrder['groupMeta'] is Map
        ? Map<String, dynamic>.from(apiOrder['groupMeta'])
        : null;
    final groupId = apiOrder['groupId']?.toString();
    final isGroupedOrder =
        (apiOrder['isGroupedOrder'] == true) ||
        (groupId != null && groupId.isNotEmpty);

    return OrderModel(
      id: apiOrder['id']?.toString() ?? apiOrder['_id']?.toString() ?? '',
      orderNumber: apiOrder['orderNumber']?.toString() ?? '',
      groupOrderNumber: apiOrder['groupOrderNumber']?.toString(),
      groupId: groupId,
      checkoutSessionId: apiOrder['checkoutSessionId']?.toString(),
      isGroupedOrder: isGroupedOrder,
      groupVendorCount: _toNullableInt(groupMeta?['vendorCount']),
      groupTotalAmount: _toNullableDouble(groupMeta?['groupTotal']),
      restaurantName: restaurantName,
      restaurantLogo: restaurantLogo,
      items: items,
      totalAmount: _toDouble(apiOrder['totalAmount']),
      orderDate: orderDate,
      expectedDelivery: expectedDelivery,
      status: status,
      deliveredDate: deliveredDate,
      cancelledDate: cancelledDate,
      paymentStatus: paymentStatus,
      canRateVendor: canRateVendor,
      vendorRatingSubmitted: vendorRatingSubmitted,
      vendorRatingValue: vendorRatingValue,
      vendorRatedAt: vendorRatedAt,
      rawOrder: apiOrder,
    );
  }

  double _toDouble(dynamic value, {double fallback = 0.0}) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  double? _toNullableDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  int _toInt(dynamic value, {int fallback = 0}) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  int? _toNullableInt(dynamic value) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  String? _buildCustomizationSummary(OrderItem item) {
    final parts = <String>[];
    final portionLabel = item.selectedPortion?['label']?.toString().trim();
    if (portionLabel != null && portionLabel.isNotEmpty) {
      parts.add('Portion: $portionLabel');
    }

    final prefLabels = item.selectedPreferences
        .map(
          (entry) =>
              entry['optionLabel']?.toString().trim() ??
              entry['label']?.toString().trim() ??
              '',
        )
        .where((label) => label.isNotEmpty)
        .toList(growable: false);
    if (prefLabels.isNotEmpty) {
      if (prefLabels.length > 2) {
        final visible = prefLabels.take(2).join(', ');
        final extra = prefLabels.length - 2;
        parts.add('Prefs: $visible +$extra');
      } else {
        parts.add('Prefs: ${prefLabels.join(', ')}');
      }
    }

    final note = item.itemNote?.trim();
    if (note != null && note.isNotEmpty) {
      parts.add('Note');
    }

    if (parts.isEmpty) return null;
    return parts.join(' • ');
  }

  List<OrderModel> _filterOrdersByTab(List<OrderModel> convertedOrders) {
    switch (selectedTabIndex) {
      case 0:
        return convertedOrders
            .where(
              (order) =>
                  order.status == OrderStatus.pending ||
                  order.status == OrderStatus.ongoing,
            )
            .toList();
      case 1:
        return convertedOrders
            .where(
              (order) =>
                  order.status == OrderStatus.completed ||
                  order.status == OrderStatus.cancelled,
            )
            .toList();
      default:
        return convertedOrders;
    }
  }

  List<OrderModel> _getGroupOrders(
    OrderModel order,
    List<OrderModel> allOrders,
  ) {
    final groupId = order.groupId?.trim();
    if (!order.isGroupedOrder || groupId == null || groupId.isEmpty) {
      return const [];
    }

    final children =
        allOrders.where((entry) => entry.groupId == groupId).toList()
          ..sort((a, b) => a.orderDate.compareTo(b.orderDate));
    return children;
  }

  List<_GroupedVendorSummary> _buildGroupedVendorSummaries(
    List<OrderModel> groupOrders,
  ) {
    final grouped = <String, _GroupedVendorSummaryMutable>{};
    for (final child in groupOrders) {
      final vendorName = child.restaurantName.trim().isNotEmpty
          ? child.restaurantName.trim()
          : 'Vendor';
      grouped.putIfAbsent(
        vendorName,
        () => _GroupedVendorSummaryMutable(vendorName: vendorName),
      );
      grouped[vendorName]!.orderCount += 1;
      grouped[vendorName]!.itemCount += child.itemCount;
      grouped[vendorName]!.totalAmount += child.totalAmount;
    }

    return grouped.values
        .map(
          (value) => _GroupedVendorSummary(
            vendorName: value.vendorName,
            orderCount: value.orderCount,
            itemCount: value.itemCount,
            totalAmount: value.totalAmount,
          ),
        )
        .toList(growable: false);
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
    } else if (orderType == 'grabmart' || raw['grabMartStore'] is Map) {
      vendor = (raw['grabMartStore'] as Map?)?.cast<String, dynamic>();
    }

    if (vendor == null) return true;

    final isOpen = vendor['isOpen'];
    if (isOpen is bool && !isOpen) return false;

    final isAcceptingOrders = vendor['isAcceptingOrders'];
    if (isAcceptingOrders is bool && !isAcceptingOrders) return false;

    final status = vendor['status']?.toString().toLowerCase();
    if (status != null && status.isNotEmpty && status != 'approved') {
      return false;
    }

    return true;
  }

  String _vendorClosedTitle(OrderModel order) {
    final orderType = order.rawOrder['orderType']?.toString().toLowerCase();
    if (orderType == 'grocery') return 'Store Closed';
    if (orderType == 'pharmacy') return 'Pharmacy Closed';
    if (orderType == 'grabmart') return 'Store Closed';
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
    if (orderType == 'grabmart') {
      return 'This store is currently closed or not accepting orders. Please try again later.';
    }
    return 'This restaurant is currently closed or not accepting orders. Please try again later.';
  }

  Future<void> _retryPayment(BuildContext context, OrderModel order) async {
    if (order.isGroupedOrder &&
        order.checkoutSessionId != null &&
        order.checkoutSessionId!.isNotEmpty) {
      await _retryGroupedPayment(context, order);
      return;
    }

    LoadingDialog.instance().show(
      context: context,
      text: 'Preparing checkout...',
    );
    final cartProvider = context.read<CartProvider>();

    try {
      final success = await cartProvider.replaceCartWithOrder(order.rawOrder);
      LoadingDialog.instance().hide();

      if (!success) {
        AppDialog.show(
          context: context,
          type: AppDialogType.error,
          title: 'Unable to retry payment',
          message:
              'We could not rebuild your cart for this order. Please contact support.',
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
        message:
            'Something went wrong while preparing your order. Please try again.',
        primaryButtonText: 'OK',
      );
    }
  }

  Future<void> _retryGroupedPayment(
    BuildContext context,
    OrderModel order,
  ) async {
    final sessionId = order.checkoutSessionId;
    if (sessionId == null || sessionId.isEmpty) {
      AppDialog.show(
        context: context,
        type: AppDialogType.error,
        title: 'Unable to retry payment',
        message: 'Missing checkout session reference for this grouped order.',
        primaryButtonText: 'OK',
      );
      return;
    }

    LoadingDialog.instance().show(
      context: context,
      text: 'Preparing payment...',
    );
    final orderService = OrderServiceWrapper();

    try {
      final init = await orderService.initializeCheckoutSessionPaystackPayment(
        sessionId: sessionId,
      );
      LoadingDialog.instance().hide();

      final result = await paystack.PaystackService.instance.launchPayment(
        context: context,
        authorizationUrl: init.authorizationUrl,
        reference: init.reference,
      );

      if (!context.mounted) return;

      if (result.status == paystack.PaystackPaymentStatus.success ||
          result.status == paystack.PaystackPaymentStatus.unknown) {
        context.go(
          '/paymentConfirming',
          extra: {
            'orderId': null,
            'sessionId': sessionId,
            'reference': result.reference ?? init.reference,
            'paymentData': _buildGroupedRetryPaymentData(order, init),
          },
        );
        return;
      }

      await orderService.releaseCheckoutSessionCreditHold(sessionId: sessionId);
      if (!context.mounted) return;
      AppDialog.show(
        context: context,
        type: AppDialogType.warning,
        title: 'Payment not completed',
        message: 'You can retry payment for this grouped order anytime.',
        primaryButtonText: 'OK',
      );
    } catch (_) {
      LoadingDialog.instance().hide();
      try {
        await orderService.releaseCheckoutSessionCreditHold(
          sessionId: sessionId,
        );
      } catch (_) {}

      if (!context.mounted) return;
      AppDialog.show(
        context: context,
        type: AppDialogType.error,
        title: 'Retry failed',
        message: 'Unable to initialize payment right now. Please try again.',
        primaryButtonText: 'OK',
      );
    }
  }

  Future<void> _openVendorRatingFlow(
    BuildContext context,
    OrderModel order,
  ) async {
    await Navigator.of(context).push<int?>(
      MaterialPageRoute(
        builder: (context) => VendorRating(
          orderId: order.id,
          vendorName: order.restaurantName,
          vendorImage: order.restaurantLogo,
        ),
      ),
    );
  }

  Map<String, dynamic> _buildGroupedRetryPaymentData(
    OrderModel order,
    InitializePaymentResult init,
  ) {
    final raw = order.rawOrder;
    final paymentAmount =
        init.paymentAmount ??
        order.groupTotalAmount ??
        _toDouble(raw['totalAmount'], fallback: order.totalAmount);

    return {
      'orderId': null,
      'checkoutSessionId': order.checkoutSessionId,
      'isGroupedOrder': true,
      'method': 'Paystack',
      'paymentMethod': 'card',
      'paymentScope': init.paymentScope,
      'total': paymentAmount,
      'orderGrandTotal': paymentAmount,
      'codRemainingCashAmount': null,
      'subTotal': _toDouble(raw['subtotal'], fallback: paymentAmount),
      'deliveryFee': _toDouble(raw['deliveryFee'], fallback: 0.0),
      'serviceFee': _toDouble(raw['serviceFee'], fallback: 0.0),
      'rainFee': _toDouble(raw['rainFee'], fallback: 0.0),
      'tax': _toDouble(raw['tax'], fallback: 0.0),
      'tip': _toDouble(raw['tip'], fallback: 0.0),
      'orderNumber': order.groupOrderNumber ?? order.orderNumber,
      'timestamp': DateTime.now().toIso8601String(),
      'isGiftOrder': false,
      'giftRecipientName': null,
      'giftRecipientPhone': null,
      'giftDeliveryCode': null,
    };
  }

  @override
  Widget build(BuildContext context) {
    _syncAuthState();

    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final padding = MediaQuery.paddingOf(context);
    final size = MediaQuery.sizeOf(context);
    final isGuest = !UserService().isLoggedIn;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: colors.accentOrange,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: colors.backgroundPrimary,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
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
                        final currentHeight = _currentHeaderHeight(
                          size,
                          scrollOffset,
                        );
                        return SizedBox(height: currentHeight);
                      },
                    ),
                    Expanded(
                      child: isGuest
                          ? SingleChildScrollView(
                              controller: _scrollController,
                              physics: const AlwaysScrollableScrollPhysics(),
                              padding: EdgeInsets.symmetric(
                                horizontal: 20.w,
                                vertical: 20.h,
                              ),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: size.height * 0.58,
                                ),
                                child: _buildGuestOrdersState(colors),
                              ),
                            )
                          : Consumer<OrderProvider>(
                              builder: (context, orderProvider, _) {
                                final hasAnyOrders =
                                    orderProvider.orders.isNotEmpty;

                                if (orderProvider.isLoading &&
                                    orderProvider.orders.isEmpty) {
                                  return OrderSkeleton(
                                    colors: colors,
                                    isDark: isDark,
                                  );
                                }

                                final convertedOrders = orderProvider.orders
                                    .map(
                                      (orderData) =>
                                          _convertAPIOrderToOrderModel(
                                            orderData,
                                          ),
                                    )
                                    .toList(growable: false);
                                final hasOngoingOrders = convertedOrders.any(
                                  (order) =>
                                      order.status == OrderStatus.pending ||
                                      order.status == OrderStatus.ongoing,
                                );
                                final hasCompletedOrders = convertedOrders.any(
                                  (order) =>
                                      order.status == OrderStatus.completed ||
                                      order.status == OrderStatus.cancelled,
                                );
                                final filteredOrders = _filterOrdersByTab(
                                  convertedOrders,
                                );

                                return Column(
                                  children: [
                                    if (hasAnyOrders) _buildTabs(colors),
                                    Expanded(
                                      child: filteredOrders.isEmpty
                                          ? _buildEmptyState(
                                              colors,
                                              hasAnyOrders: hasAnyOrders,
                                              hasOngoingOrders:
                                                  hasOngoingOrders,
                                              hasCompletedOrders:
                                                  hasCompletedOrders,
                                            )
                                          : AppRefreshIndicator(
                                              iconPath: Assets.icons.boxIso,
                                              bgColor: colors.accentOrange,
                                              onRefresh: () =>
                                                  orderProvider.refreshOrders(),
                                              child: ListView.separated(
                                                controller: _scrollController,
                                                physics:
                                                    const AlwaysScrollableScrollPhysics(),
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 20.w,
                                                  vertical: 16.h,
                                                ),
                                                itemCount:
                                                    filteredOrders.length,
                                                separatorBuilder:
                                                    (context, index) {
                                                      return Column(
                                                        children: [
                                                          SizedBox(
                                                            height: 16.h,
                                                          ),
                                                          DottedLine(
                                                            dashLength: 6,
                                                            dashGapLength: 4,
                                                            lineThickness: 1,
                                                            dashColor: colors
                                                                .textSecondary
                                                                .withAlpha(50),
                                                          ),
                                                          SizedBox(
                                                            height: 16.h,
                                                          ),
                                                        ],
                                                      );
                                                    },
                                                itemBuilder: (context, index) {
                                                  final order =
                                                      filteredOrders[index];
                                                  return _buildOrderCard(
                                                    order,
                                                    colors,
                                                    isDark,
                                                    convertedOrders,
                                                  );
                                                },
                                              ),
                                            ),
                                    ),
                                  ],
                                );
                              },
                            ),
                    ),
                  ],
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: _buildCollapsibleUmbrellaHeader(colors, size, padding),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabs(AppColorsExtension colors) {
    final totalTabs = _orderTabs.length;
    final selectedIndex = selectedTabIndex.clamp(0, totalTabs - 1);

    return Container(
      key: const ValueKey('tabs'),
      margin: EdgeInsets.symmetric(horizontal: 20.w),
      padding: EdgeInsets.all(3.r),
      decoration: BoxDecoration(
        color: colors.backgroundSecondary,
        borderRadius: BorderRadius.circular(999.r),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth = constraints.maxWidth / totalTabs;
          return Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                left: tabWidth * selectedIndex,
                top: 0,
                bottom: 0,
                width: tabWidth,
                child: Container(
                  decoration: BoxDecoration(
                    color: colors.accentOrange,
                    borderRadius: BorderRadius.circular(999.r),
                  ),
                ),
              ),
              Row(
                children: List.generate(totalTabs, (index) {
                  final selected = selectedIndex == index;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        if (selectedTabIndex == index) return;
                        setState(() {
                          selectedTabIndex = index;
                        });
                      },
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          vertical: 12.h,
                          horizontal: 6.w,
                        ),
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          style: TextStyle(
                            color: selected
                                ? Colors.white
                                : colors.textSecondary,
                            fontSize: 11.sp,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w600,
                            fontFamily: 'Lato',
                            package: 'grab_go_shared',
                          ),
                          child: Text(
                            _orderTabs[index],
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.fade,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCollapsibleUmbrellaHeader(
    AppColorsExtension colors,
    Size size,
    EdgeInsets padding,
  ) {
    return ValueListenableBuilder<double>(
      valueListenable: _scrollOffsetNotifier,
      builder: (context, scrollOffset, _) {
        final collapseProgress = (scrollOffset / _scrollThreshold).clamp(
          0.0,
          1.0,
        );
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
    final expandedHeight = UmbrellaHeaderMetrics.expandedHeightFor(size);
    return expandedHeight -
        ((expandedHeight - _collapsedHeight) * collapseProgress);
  }

  Widget _buildUmbrellaContent(AppColorsExtension colors, EdgeInsets padding) {
    final isGuest = !UserService().isLoggedIn;

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
              // CustomPopupMenu(
              //   menuWidth: 280.w,
              //   showArrow: false,
              //   items: [
              //     CustomPopupMenuItem(
              //       value: 'sort',
              //       label: 'Sort Favorites',
              //       icon: Assets.icons.sort,
              //       iconColor: colors.textSecondary,
              //     ),
              //     CustomPopupMenuItem(
              //       value: 'clear',
              //       label: 'Clear All Favorites',
              //       icon: Assets.icons.brushCleaning,
              //       iconColor: colors.textSecondary,
              //     ),
              //   ],
              //   onSelected: (value) {
              //     switch (value) {
              //       case "sort":
              //         debugPrint("sort");
              //       case "clear":
              //     }
              //   },
              //   child: Material(
              //     color: Colors.transparent,
              //     child: InkWell(
              //       onTap: () {
              //         // context.push("/notification");
              //       },
              //       customBorder: const CircleBorder(),
              //       child: Padding(
              //         padding: EdgeInsets.all(10.r),
              //         child: SvgPicture.asset(
              //           Assets.icons.moreVertical,
              //           package: 'grab_go_shared',
              //           colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
              //         ),
              //       ),
              //     ),
              //   ),
              // ),
            ],
          ),
          SizedBox(height: 6.h),
          Text(
            isGuest
                ? "Sign in to view your orders"
                : "Track ongoing, completed, and cancelled orders",
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

  Widget _buildGuestOrdersState(AppColorsExtension colors) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            Assets.icons.emptyOrdersScreen,
            package: 'grab_go_shared',
            width: 160.w,
            height: 160.h,
          ),
          SizedBox(height: 10.h),
          Text(
            "Sign in to view your orders",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            "Track current deliveries, check past receipts, and reorder your favorites once you have an account.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.sp,
              fontWeight: FontWeight.w500,
              color: colors.textSecondary,
              height: 1.5,
            ),
          ),
          SizedBox(height: 24.h),
          AppButton(
            width: double.infinity,
            height: 50.h,
            buttonText: "Sign in",
            onPressed: () => context.push('/login'),
            backgroundColor: colors.accentOrange,
            borderRadius: KBorderSize.borderMedium,
            textStyle: TextStyle(
              color: Colors.white,
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 12.h),
          AppButton(
            width: double.infinity,
            height: 50.h,
            buttonText: "Create account",
            onPressed: () => context.push('/verifyPhone'),
            backgroundColor: colors.backgroundPrimary,
            textColor: colors.textPrimary,
            borderRadius: KBorderSize.borderMedium,
            textStyle: TextStyle(
              color: colors.textPrimary,
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(
    AppColorsExtension colors, {
    required bool hasAnyOrders,
    required bool hasOngoingOrders,
    required bool hasCompletedOrders,
  }) {
    String title = AppStrings.ordersNoOrders;
    String subtitle =
        "You don't have any orders yet. Place an order to track it from here.";

    if (hasAnyOrders) {
      if (selectedTabIndex == 0 && !hasOngoingOrders) {
        title = "No ongoing orders";
        subtitle =
            "Your active orders will appear here when a new order is in progress.";
      } else if (selectedTabIndex == 1 && !hasCompletedOrders) {
        title = "No completed orders yet";
        subtitle =
            "Completed and cancelled orders will appear here after your deliveries are done.";
      }
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SvgPicture.asset(
            Assets.icons.emptyOrdersScreen,
            package: 'grab_go_shared',
            width: 180.w,
            height: 180.h,
          ),
          SizedBox(height: 12.h),
          Text(
            title,
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
            ),
          ),
          SizedBox(height: 8.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 40.w),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w500,
                color: colors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(
    OrderModel order,
    AppColorsExtension colors,
    bool isDark,
    List<OrderModel> allOrders,
  ) {
    final isCancelled = order.status == OrderStatus.cancelled;
    final isOngoing = order.status == OrderStatus.ongoing;
    final isPending = order.status == OrderStatus.pending;
    final isPaymentPending =
        order.paymentStatus == 'pending' || order.paymentStatus == 'processing';
    final isVendorOpen = _isVendorOpen(order);
    final hasGroupOrder = order.isGroupedOrder;
    final groupOrderRef = order.groupOrderNumber?.trim();
    final hasGroupOrderRef = groupOrderRef != null && groupOrderRef.isNotEmpty;
    final primaryOrderRef = hasGroupOrderRef
        ? groupOrderRef
        : order.orderNumber;
    final groupOrders = _getGroupOrders(order, allOrders);
    final vendorBreakdown = _buildGroupedVendorSummaries(groupOrders);
    final canShowGroupDetails = hasGroupOrder && groupOrders.isNotEmpty;

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
                        Flexible(
                          child: Padding(
                            padding: EdgeInsets.only(right: 12.w),
                            child: Text(
                              primaryOrderRef,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w700,
                                color: colors.textPrimary,
                              ),
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
                    if (hasGroupOrder &&
                        hasGroupOrderRef &&
                        groupOrderRef != order.orderNumber)
                      Padding(
                        padding: EdgeInsets.only(top: 2.h),
                        child: Text(
                          'Child order: ${order.orderNumber}',
                          style: TextStyle(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w600,
                            color: colors.textSecondary.withValues(alpha: 0.8),
                          ),
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
                      ? (isPaymentPending
                            ? "Pending Payment"
                            : "Awaiting Confirmation")
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
              if (hasGroupOrder) ...[
                SizedBox(width: 6.w),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: colors.backgroundSecondary,
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Text(
                    order.groupVendorCount != null
                        ? '${order.groupVendorCount} vendors'
                        : 'Grouped',
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w700,
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              CachedNetworkImage(
                imageUrl: ImageOptimizer.getPreviewUrl(
                  order.restaurantLogo ?? '',
                  width: 200,
                ),
                width: 60.w,
                height: 60.h,
                fit: BoxFit.cover,
                memCacheWidth: 200,
                maxHeightDiskCache: 200,
                imageBuilder: (context, imageProvider) => Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(
                      KBorderSize.borderMedium,
                    ),
                    image: DecorationImage(
                      image: imageProvider,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                placeholder: (context, url) => Container(
                  width: 60,
                  height: 60,
                  padding: EdgeInsets.all(10.r),
                  decoration: BoxDecoration(
                    color: colors.backgroundSecondary,
                    borderRadius: BorderRadius.circular(
                      KBorderSize.borderMedium,
                    ),
                  ),
                  child: SvgPicture.asset(
                    Assets.icons.chefHat,
                    package: "grab_go_shared",
                    colorFilter: ColorFilter.mode(
                      colors.textPrimary,
                      BlendMode.srcIn,
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => ClipRRect(
                  borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
                  child: Assets.images.sampleOne.image(
                    width: 60,
                    height: 60,
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
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      '${order.itemCount} ${order.itemCount == 1 ? AppStrings.ordersItem : AppStrings.ordersItems} ${AppStrings.ordersFrom} ${order.restaurantName.split(' - ')[0]}',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                        color: colors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (hasGroupOrder && hasGroupOrderRef)
                      Padding(
                        padding: EdgeInsets.only(top: 2.h),
                        child: Text(
                          'Part of $groupOrderRef',
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                            color: colors.accentOrange,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          ...order.items.take(2).map((item) {
            final customizationSummary = _buildCustomizationSummary(item);
            return Padding(
              padding: EdgeInsets.only(bottom: 8.h),
              child: Row(
                children: [
                  Container(
                    width: 6.w,
                    height: 6.h,
                    decoration: BoxDecoration(
                      color: colors.accentOrange,
                      shape: BoxShape.circle,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item.quantity}x ${item.name}',
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w500,
                            color: colors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (customizationSummary != null)
                          Padding(
                            padding: EdgeInsets.only(top: 2.h),
                            child: Text(
                              customizationSummary,
                              style: TextStyle(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w500,
                                color: colors.textSecondary.withValues(
                                  alpha: 0.85,
                                ),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Text(
                    '${AppStrings.currencySymbol} ${item.price.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
            );
          }),
          if (order.items.length > 2)
            Padding(
              padding: EdgeInsets.only(left: 14.w, top: 4.h),
              child: Text(
                '+ ${order.items.length - 2} more ${order.items.length - 2 == 1 ? AppStrings.ordersItem : AppStrings.ordersItems}',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  color: colors.accentOrange,
                ),
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
                            ? (isPaymentPending
                                  ? "Awaiting Payment"
                                  : "Awaiting Confirmation")
                            : isOngoing
                            ? AppStrings.ordersExpectedDelivery
                            : AppStrings.ordersDeliveredOn,
                        style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w500,
                          color: colors.textSecondary,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        isCancelled
                            ? (order.cancelledDate != null
                                  ? '${_getTimeAgo(order.cancelledDate!)} at ${_formatTime(order.cancelledDate!)}'
                                  : 'N/A')
                            : isPending
                            ? (isPaymentPending
                                  ? "Complete payment to proceed"
                                  : "Waiting for the vendor to accept")
                            : isOngoing
                            ? (order.expectedDelivery != null
                                  ? _formatTime(order.expectedDelivery!)
                                  : 'N/A')
                            : (order.deliveredDate != null
                                  ? '${_getTimeAgo(order.deliveredDate!)} at ${_formatTime(order.deliveredDate!)}'
                                  : 'N/A'),
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      "Total Amount",
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w500,
                        color: colors.textSecondary,
                      ),
                    ),
                    Text(
                      '${AppStrings.currencySymbol} ${order.totalAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w800,
                        color: colors.accentOrange,
                      ),
                    ),
                    if (hasGroupOrder && order.groupTotalAmount != null)
                      Text(
                        'Group: ${AppStrings.currencySymbol} ${order.groupTotalAmount!.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 10.sp,
                          fontWeight: FontWeight.w600,
                          color: colors.textSecondary,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (canShowGroupDetails) ...[
            SizedBox(height: 10.h),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _showGroupedOrderDetailsSheet(
                  context: context,
                  order: order,
                  groupOrders: groupOrders,
                  vendorBreakdown: vendorBreakdown,
                  colors: colors,
                ),
                icon: SvgPicture.asset(
                  Assets.icons.navArrowRight,
                  package: 'grab_go_shared',
                  height: 12.h,
                  width: 12.w,
                  colorFilter: ColorFilter.mode(
                    colors.accentOrange,
                    BlendMode.srcIn,
                  ),
                ),
                label: Text(
                  "View grouped order details",
                  style: TextStyle(
                    color: colors.accentOrange,
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          ],
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
                    textStyle: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                    ),
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
                    buttonText: isVendorOpen
                        ? "Complete Payment"
                        : "Vendor Closed",
                    backgroundColor: isVendorOpen
                        ? colors.accentOrange
                        : colors.backgroundSecondary,
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
              buttonText: _ongoingActionLabel(order),
              backgroundColor: colors.accentOrange,
              width: double.infinity,
              height: KWidgetSize.buttonHeight.h,
              borderRadius: KBorderSize.borderMedium,
              textStyle: TextStyle(
                color: Colors.white,
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
              ),
            )
          else if (order.status == OrderStatus.completed && order.canRateVendor)
            AppButton(
              onPressed: () => _openVendorRatingFlow(context, order),
              buttonText: "Rate Vendor",
              backgroundColor: colors.accentOrange,
              width: double.infinity,
              height: KWidgetSize.buttonHeight.h,
              borderRadius: KBorderSize.borderMedium,
              textStyle: TextStyle(
                color: Colors.white,
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
              ),
            )
          else if (order.status == OrderStatus.completed &&
              order.vendorRatingSubmitted)
            Container(
              width: double.infinity,
              height: KWidgetSize.buttonHeight.h,
              decoration: BoxDecoration(
                color: colors.backgroundSecondary,
                borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
                border: Border.all(color: colors.border.withValues(alpha: 0.7)),
              ),
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SvgPicture.asset(
                    Assets.icons.starSolid,
                    package: 'grab_go_shared',
                    width: 16.w,
                    height: 16.h,
                    colorFilter: ColorFilter.mode(
                      colors.accentOrange,
                      BlendMode.srcIn,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    order.vendorRatingValue != null
                        ? 'Rated ${order.vendorRatingValue}\u2605'
                        : 'Rated',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _statusLabel(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.ongoing:
        return 'Ongoing';
      case OrderStatus.completed:
        return 'Completed';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  String _ongoingActionLabel(OrderModel order) {
    final rawStatus = (order.rawOrder['status'] as String? ?? '').toLowerCase();
    if (rawStatus == 'confirmed') {
      return 'View Status';
    }
    return 'Track Order';
  }

  Color _statusColor(OrderStatus status, AppColorsExtension colors) {
    switch (status) {
      case OrderStatus.pending:
      case OrderStatus.ongoing:
        return colors.accentOrange;
      case OrderStatus.completed:
        return colors.accentGreen;
      case OrderStatus.cancelled:
        return colors.error;
    }
  }

  void _showGroupedOrderDetailsSheet({
    required BuildContext context,
    required OrderModel order,
    required List<OrderModel> groupOrders,
    required List<_GroupedVendorSummary> vendorBreakdown,
    required AppColorsExtension colors,
  }) {
    final groupReference = order.groupOrderNumber?.trim().isNotEmpty == true
        ? order.groupOrderNumber!.trim()
        : order.orderNumber;
    final computedGroupTotal = groupOrders.fold<double>(
      0,
      (sum, child) => sum + child.totalAmount,
    );

    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.86,
          ),
          padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 20.h),
          decoration: BoxDecoration(
            color: colors.backgroundPrimary,
            borderRadius: BorderRadius.vertical(top: Radius.circular(22.r)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36.w,
                  height: 4.h,
                  decoration: BoxDecoration(
                    color: colors.divider,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              SizedBox(height: 14.h),
              Text(
                "Grouped Order Details",
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                groupReference,
                style: TextStyle(
                  color: colors.accentOrange,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 10.h),
              Row(
                children: [
                  Text(
                    '${vendorBreakdown.length} vendors',
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Group total: ${AppStrings.currencySymbol} ${computedGroupTotal.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 14.h),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12.r),
                decoration: BoxDecoration(
                  color: colors.backgroundSecondary,
                  borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Per-vendor totals",
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    for (int i = 0; i < vendorBreakdown.length; i++) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              vendorBreakdown[i].vendorName,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Text(
                            '${vendorBreakdown[i].itemCount} items',
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 10.w),
                          Text(
                            '${AppStrings.currencySymbol} ${vendorBreakdown[i].totalAmount.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      if (i < vendorBreakdown.length - 1) SizedBox(height: 6.h),
                    ],
                  ],
                ),
              ),
              SizedBox(height: 14.h),
              Text(
                "Child Orders",
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 8.h),
              Expanded(
                child: ListView.separated(
                  itemCount: groupOrders.length,
                  separatorBuilder: (context, index) => SizedBox(height: 8.h),
                  itemBuilder: (context, index) {
                    final child = groupOrders[index];
                    final statusColor = _statusColor(child.status, colors);
                    return Container(
                      padding: EdgeInsets.all(12.r),
                      decoration: BoxDecoration(
                        color: colors.backgroundSecondary,
                        borderRadius: BorderRadius.circular(
                          KBorderSize.borderMedium,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  child.restaurantName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: colors.textPrimary,
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 7.w,
                                  vertical: 2.h,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20.r),
                                ),
                                child: Text(
                                  _statusLabel(child.status),
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 10.sp,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            child.orderNumber,
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 6.h),
                          Row(
                            children: [
                              Text(
                                '${child.itemCount} ${child.itemCount == 1 ? 'item' : 'items'}',
                                style: TextStyle(
                                  color: colors.textSecondary,
                                  fontSize: 11.sp,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${AppStrings.currencySymbol} ${child.totalAmount.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GroupedVendorSummary {
  final String vendorName;
  final int orderCount;
  final int itemCount;
  final double totalAmount;

  const _GroupedVendorSummary({
    required this.vendorName,
    required this.orderCount,
    required this.itemCount,
    required this.totalAmount,
  });
}

class _GroupedVendorSummaryMutable {
  final String vendorName;
  int orderCount;
  int itemCount;
  double totalAmount;

  _GroupedVendorSummaryMutable({required this.vendorName})
    : orderCount = 0,
      itemCount = 0,
      totalAmount = 0;
}
