import 'dart:async';

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_rider/features/home/models/transaction_model.dart';
import 'package:grab_go_rider/features/orders/service/available_order_dto.dart';
import 'package:grab_go_rider/features/orders/service/available_orders_service.dart';
import 'package:grab_go_rider/features/orders/service/order_reservation_service.dart';
import 'package:grab_go_rider/features/orders/service/order_statistics_service.dart';
import 'package:grab_go_rider/features/orders/widgets/order_reservation_modal.dart';
import 'package:grab_go_rider/shared/widgets/home_drawer.dart';
import 'package:grab_go_rider/shared/widgets/home_sliver_appbar.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:intl/intl.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  List<TransactionModel> _recentTransactions = [];
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rippleAnimation;
  bool onlineStatus = false; // Default to OFFLINE on app launch
  bool _isCheckingStatus = true; // Loading state while checking server status

  double? _currentLat;
  double? _currentLon;
  bool isLoadingOrders = true;
  String? ordersError;
  List<AvailableOrderDto> _availableOrders = [];
  final AvailableOrdersService _availableOrdersService = AvailableOrdersService();
  final OrderReservationService _reservationService = OrderReservationService();

  // Periodic location + battery update timer
  Timer? _locationUpdateTimer;
  final Battery _battery = Battery();

  OrderStatistics? _statistics;

  @override
  void initState() {
    super.initState();
    _loadSampleTransactions();
    _setupAnimations();
    _initializeLocation();
    _initializeReservationService();
    _checkOnlineStatus(); // Check server status on launch
  }

  /// Check rider's online status from server on app launch
  Future<void> _checkOnlineStatus() async {
    try {
      final result = await _reservationService.checkOnlineStatus();

      if (!mounted) return;

      setState(() {
        onlineStatus = result['isOnline'] ?? false;
        _isCheckingStatus = false;
      });

      // Show message if rider was auto-offlined
      if (result['autoOfflineInfo'] != null) {
        final info = result['autoOfflineInfo'] as Map<String, dynamic>;
        _showAutoOfflineMessage(info['reason'] as String?);
      }

      // Start location updates only if online
      if (onlineStatus) {
        _startLocationBatteryUpdates();
      }

      debugPrint('📊 Online status from server: $onlineStatus');
    } catch (e) {
      debugPrint('⚠️ Error checking online status: $e');
      if (mounted) {
        setState(() {
          onlineStatus = false; // Default to offline on error
          _isCheckingStatus = false;
        });
      }
    }
  }

  /// Show message explaining why rider was auto-offlined
  void _showAutoOfflineMessage(String? reason) {
    if (!mounted) return;

    String message;
    switch (reason) {
      case 'inactivity':
        message = 'You were set offline due to inactivity. Go online when ready!';
        break;
      case 'low_battery':
        message = 'You were set offline because your battery was critically low.';
        break;
      case 'unresponsive':
        message = 'You were set offline after missing multiple order requests.';
        break;
      default:
        message = 'You were set offline automatically. Go online when ready!';
    }

    // Show snackbar after build completes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Go Online',
              onPressed: () async {
                final success = await _reservationService.goOnline();
                if (success && mounted) {
                  setState(() => onlineStatus = true);
                  _startLocationBatteryUpdates();
                }
              },
            ),
          ),
        );
      }
    });
  }

  /// Handle online/offline toggle switch
  void _handleOnlineStatusToggle(bool value) async {
    if (_isCheckingStatus) return;

    // Optimistically update UI
    setState(() {
      onlineStatus = value;
    });

    // Call API
    bool success;
    if (value) {
      success = await _reservationService.goOnline();
      if (success) {
        _startLocationBatteryUpdates(); // Start updates when going online
      }
    } else {
      success = await _reservationService.goOffline();
      if (success) {
        _locationUpdateTimer?.cancel(); // Stop updates when going offline
      }
    }

    // Revert if failed
    if (!success && mounted) {
      setState(() {
        onlineStatus = !value;
      });
      AppToastMessage.show(
        context: context,
        message: 'Failed to ${value ? "go online" : "go offline"}. Please try again.',
        backgroundColor: Colors.red,
      );
    }
  }

  /// Start periodic location and battery updates (every 60 seconds)
  void _startLocationBatteryUpdates() {
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (onlineStatus) {
        _updateLocationAndBattery();
      }
    });
  }

  /// Update location and battery level on server
  Future<void> _updateLocationAndBattery() async {
    try {
      // Get current position
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 10)),
        );
      } catch (e) {
        debugPrint('⚠️ Error getting location for update: $e');
      }

      // Get battery info
      int batteryLevel = 100;
      bool isCharging = false;
      try {
        batteryLevel = await _battery.batteryLevel;
        final batteryState = await _battery.batteryState;
        isCharging = batteryState == BatteryState.charging || batteryState == BatteryState.full;
      } catch (e) {
        debugPrint('⚠️ Error getting battery for update: $e');
      }

      // Update server with location + battery
      if (position != null) {
        await _reservationService.updateLocation(
          position.latitude,
          position.longitude,
          batteryLevel: batteryLevel,
          isCharging: isCharging,
        );
        debugPrint('📍🔋 Location & battery updated: (${position.latitude}, ${position.longitude}), $batteryLevel%');
      }
    } catch (e) {
      debugPrint('Error in periodic update: $e');
    }
  }

  void _initializeReservationService() {
    // Re-initialize socket now that user is logged in
    // (SocketService may have been initialized before user data was loaded)
    SocketService().initialize();

    // Initialize the reservation service to listen for incoming orders
    _reservationService.initialize();

    // Set up callbacks
    _reservationService.onReservationReceived = (reservation) {
      // Show the reservation modal when a new order is reserved for this rider
      if (mounted) {
        OrderReservationModal.show(
          context,
          reservation,
          onAccepted: () {
            // Refresh orders and navigate to active order
            _loadAvailableOrders();
            AppToastMessage.show(
              context: context,
              message: 'Order accepted! Navigate to pickup location.',
              backgroundColor: AppColors.accentGreen,
            );
            // Navigate to the order tracking/delivery page
            context.push('/orderConfirmation/${reservation.orderId}');
          },
          onDeclined: () {
            AppToastMessage.show(
              context: context,
              message: 'Order declined. Waiting for new orders...',
              backgroundColor: Colors.orange,
            );
          },
          onExpired: () {
            AppToastMessage.show(context: context, message: 'Order reservation expired.', backgroundColor: Colors.grey);
          },
        );
      }
    };

    _reservationService.onReservationCancelled = (orderId, reason) {
      if (mounted) {
        AppToastMessage.show(context: context, message: 'Order was cancelled: $reason', backgroundColor: Colors.red);
      }
    };

    // Listen for auto-offline events from server
    _setupAutoOfflineListener();

    // Don't auto-go-online here - we check status from server in _checkOnlineStatus()
    // The rider's saved status will be restored from the server

    // Check for any existing active reservation (e.g., if app was backgrounded)
    _reservationService.fetchActiveReservation().then((reservation) {
      if (reservation != null && mounted) {
        OrderReservationModal.show(
          context,
          reservation,
          onAccepted: () {
            _loadAvailableOrders();
            context.push('/orderConfirmation/${reservation.orderId}');
          },
          onDeclined: () {},
          onExpired: () {},
        );
      }
    });
  }

  void _setupAnimations() {
    _pulseController = AnimationController(duration: const Duration(milliseconds: 2000), vsync: this)
      ..repeat(reverse: false);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeInOut),
      ),
    );

    _rippleAnimation = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _locationUpdateTimer?.cancel();
    _removeAutoOfflineListener();
    super.dispose();
  }

  /// Set up listener for auto-offline events from server
  void _setupAutoOfflineListener() {
    final socket = SocketService().socket;
    socket?.on('rider:auto_offline', (data) {
      if (!mounted) return;

      final reason = data['reason'] as String?;
      final message = data['message'] as String?;

      debugPrint('🔴 Auto-offlined by server: $reason - $message');

      setState(() {
        onlineStatus = false;
      });
      _locationUpdateTimer?.cancel();

      // Show notification to user
      _showAutoOfflineMessage(reason);
    });
  }

  /// Remove auto-offline listener
  void _removeAutoOfflineListener() {
    final socket = SocketService().socket;
    socket?.off('rider:auto_offline');
  }

  Future<void> _initializeLocation() async {
    await _getCurrentLocation();
    await _loadAvailableOrders();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint('Location services are disabled');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint('Location permission denied');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugPrint('Location permission denied forever');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 100),
      );

      if (!mounted) return;
      setState(() {
        _currentLat = position.latitude;
        _currentLon = position.longitude;
      });

      // Update location on server for dispatch service
      _reservationService.updateLocation(position.latitude, position.longitude);

      debugPrint('Location obtained: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  Future<void> _loadAvailableOrders() async {
    if (!mounted) return;
    setState(() {
      isLoadingOrders = true;
      ordersError = null;
    });

    try {
      final result = await _availableOrdersService.getAvailableOrders(lat: _currentLat, lon: _currentLon);

      if (!mounted) return;
      setState(() {
        _availableOrders = result['orders'] as List<AvailableOrderDto>;
        _statistics = result['statistics'] as OrderStatistics?;

        if (_availableOrders.isEmpty) {
          ordersError = 'No available orders at the moment.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        ordersError = 'Failed to load available orders. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoadingOrders = false;
        });
      }
    }
  }

  void _loadSampleTransactions() {
    final now = DateTime.now();
    _recentTransactions = [
      TransactionModel(
        id: '1',
        amount: 25.50,
        type: TransactionType.delivery,
        description: 'Delivery to East Legon',
        dateTime: now.subtract(const Duration(hours: 2)),
        status: TransactionStatus.completed,
      ),
      TransactionModel(
        id: '2',
        amount: 10.00,
        type: TransactionType.tip,
        description: 'Tip from customer',
        dateTime: now.subtract(const Duration(hours: 3)),
        status: TransactionStatus.completed,
      ),
      TransactionModel(
        id: '3',
        amount: 38.00,
        type: TransactionType.delivery,
        description: 'Delivery to Cantonments',
        dateTime: now.subtract(const Duration(hours: 5)),
        status: TransactionStatus.completed,
      ),
      TransactionModel(
        id: '4',
        amount: 50.00,
        type: TransactionType.bonus,
        description: 'Weekend bonus',
        dateTime: now.subtract(const Duration(days: 1)),
        status: TransactionStatus.completed,
      ),
      TransactionModel(
        id: '5',
        amount: 42.00,
        type: TransactionType.delivery,
        description: 'Delivery to Labone',
        dateTime: now.subtract(const Duration(days: 1, hours: 3)),
        status: TransactionStatus.completed,
      ),
      TransactionModel(
        id: '6',
        amount: 5.00,
        type: TransactionType.tip,
        description: 'Tip from customer',
        dateTime: now.subtract(const Duration(days: 1, hours: 5)),
        status: TransactionStatus.completed,
      ),
    ];
  }

  String _getTransactionIcon(TransactionType type) {
    switch (type) {
      case TransactionType.delivery:
        return Assets.icons.deliveryTruck;
      case TransactionType.tip:
        return Assets.icons.gift;
      case TransactionType.bonus:
        return Assets.icons.star;
      case TransactionType.withdrawal:
        return Assets.icons.creditCard;
      case TransactionType.penalty:
        return Assets.icons.warningCircle;
    }
  }

  String _getTransactionTypeLabel(TransactionType type) {
    switch (type) {
      case TransactionType.delivery:
        return 'Delivery';
      case TransactionType.tip:
        return 'Tip';
      case TransactionType.bonus:
        return 'Bonus';
      case TransactionType.withdrawal:
        return 'Withdrawal';
      case TransactionType.penalty:
        return 'Penalty';
    }
  }

  Color _getTransactionTypeColor(TransactionType type, AppColorsExtension colors) {
    switch (type) {
      case TransactionType.delivery:
        return colors.accentGreen;
      case TransactionType.tip:
        return colors.accentOrange;
      case TransactionType.bonus:
        return colors.accentViolet;
      case TransactionType.withdrawal:
        return colors.error;
      case TransactionType.penalty:
        return colors.error;
    }
  }

  Widget _buildStatCard({
    required AppColorsExtension colors,
    required String icon,
    required Color iconColor,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                ),
                child: SvgPicture.asset(
                  icon,
                  package: 'grab_go_shared',
                  width: 20.w,
                  height: 20.w,
                  colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
                ),
              ),
              Text(
                title,
                style: TextStyle(color: colors.textSecondary, fontSize: 11.sp, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            value,
            style: TextStyle(color: colors.textPrimary, fontSize: 20.sp, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 2.h),
          Text(
            subtitle,
            style: TextStyle(color: colors.textSecondary, fontSize: 11.sp, fontWeight: FontWeight.w400),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDart = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: isDart ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: colors.backgroundSecondary,
      ),
      child: Scaffold(
        drawer: HomeDrawer(),
        backgroundColor: colors.backgroundSecondary,
        body: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: <Widget>[
            HomeSliverAppbar(),
            SliverToBoxAdapter(
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
                    child: Container(
                      padding: EdgeInsets.all(16.w),
                      decoration: BoxDecoration(
                        color: colors.backgroundPrimary,
                        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                      ),
                      child: Row(
                        children: [
                          onlineStatus
                              ? AnimatedBuilder(
                                  animation: _pulseController,
                                  builder: (context, child) {
                                    return Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Container(
                                          width: 48.w * _rippleAnimation.value,
                                          height: 48.w * _rippleAnimation.value,
                                          decoration: BoxDecoration(
                                            color: colors.accentGreen.withValues(
                                              alpha: 0.15 * (1 - _rippleAnimation.value),
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        Container(
                                          width: 48.w,
                                          height: 48.w,
                                          decoration: BoxDecoration(
                                            color: colors.accentGreen.withValues(alpha: 0.1),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        Transform.scale(
                                          scale: _pulseAnimation.value,
                                          child: Container(
                                            width: 12.w,
                                            height: 12.w,
                                            decoration: BoxDecoration(
                                              color: colors.accentGreen,
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: colors.accentGreen.withValues(alpha: 0.3),
                                                  blurRadius: 8 * _pulseAnimation.value,
                                                  spreadRadius: 2 * _pulseAnimation.value,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                )
                              : Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Container(
                                      width: 48.w,
                                      height: 48.w,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: colors.textSecondary.withValues(alpha: 0.1),
                                          width: 2,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      width: 40.w,
                                      height: 40.w,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: colors.textSecondary.withValues(alpha: 0.1),
                                      ),
                                      child: Center(
                                        child: SvgPicture.asset(
                                          Assets.icons.wifiOff,
                                          package: 'grab_go_shared',
                                          width: 20.w,
                                          height: 20.w,
                                          colorFilter: ColorFilter.mode(
                                            colors.textSecondary.withValues(alpha: 0.6),
                                            BlendMode.srcIn,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                          SizedBox(width: 16.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  onlineStatus ? "You're Online" : "You're Offline",
                                  style: TextStyle(
                                    color: colors.textPrimary,
                                    fontSize: 16.sp,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  onlineStatus ? "Ready to accept deliveries" : "You won't receive new orders",
                                  style: TextStyle(
                                    color: colors.textSecondary,
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          CustomSwitch(
                            value: onlineStatus,
                            onChanged: _isCheckingStatus
                                ? (_) {} // Disabled state - do nothing
                                : _handleOnlineStatusToggle,
                            activeColor: colors.accentGreen,
                            inactiveColor: colors.border,
                            thumbColor: colors.backgroundPrimary,
                          ),
                        ],
                      ),
                    ),
                  ),

                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildStatCard(
                            colors: colors,
                            icon: Assets.icons.deliveryTruck,
                            iconColor: colors.accentGreen,
                            title: "Today",
                            value: "12",
                            subtitle: "Deliveries",
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: _buildStatCard(
                            colors: colors,
                            icon: Assets.icons.creditCard,
                            iconColor: colors.accentGreen,
                            title: "Earnings",
                            value: "GHC 285",
                            subtitle: "This week",
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 20.h),

                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: GestureDetector(
                      onTap: () {
                        ordersError != null ? _loadAvailableOrders() : context.push("/orders");
                      },
                      child: Container(
                        padding: EdgeInsets.all(20.w),
                        decoration: BoxDecoration(
                          color: ordersError != null
                              ? colors.error.withValues(alpha: 0.09)
                              : colors.accentGreen.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                        ),
                        child: Row(
                          children: [
                            ordersError != null
                                ? SvgPicture.asset(
                                    Assets.icons.wifiOff,
                                    package: "grab_go_shared",
                                    height: 40.h,
                                    width: 40.w,
                                    colorFilter: ColorFilter.mode(colors.error, BlendMode.srcIn),
                                  )
                                : Assets.images.deliveryPackage.image(
                                    height: 100.h,
                                    width: 100.w,
                                    package: 'grab_go_shared',
                                  ),
                            SizedBox(width: ordersError != null ? 20.w : 10.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      (_statistics != null && _statistics!.totalOrders > 5)
                                          ? Container(
                                              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                              decoration: BoxDecoration(
                                                color: colors.accentOrange.withValues(alpha: 0.2),
                                                borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                                              ),
                                              child: Text(
                                                "Rush Hour",
                                                style: TextStyle(
                                                  fontSize: 10.sp,
                                                  fontWeight: FontWeight.w600,
                                                  color: colors.accentOrange,
                                                ),
                                              ),
                                            )
                                          : SizedBox.shrink(),
                                    ],
                                  ),
                                  SizedBox(height: 8.h),
                                  Text(
                                    isLoadingOrders
                                        ? "..."
                                        : ordersError != null
                                        ? "Failed to load orders..."
                                        : _statistics != null
                                        ? "${_statistics!.totalOrders} orders available"
                                        : "You have no available orders",
                                    style: TextStyle(
                                      color: ordersError == null ? colors.textPrimary : colors.error,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 18.sp,
                                    ),
                                  ),
                                  SizedBox(height: 4.h),
                                  Text(
                                    ordersError == null ? "Tap to view and accept" : "Tap to try again",
                                    style: TextStyle(
                                      color: colors.textSecondary,
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ordersError == null
                                ? SvgPicture.asset(
                                    Assets.icons.navArrowRight,
                                    package: "grab_go_shared",
                                    width: 24.w,
                                    height: 24.w,
                                    colorFilter: ColorFilter.mode(colors.accentGreen, BlendMode.srcIn),
                                  )
                                : const SizedBox.shrink(),
                          ],
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: 24.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              "Recent Transactions",
                              style: TextStyle(color: colors.textPrimary, fontSize: 18.sp, fontWeight: FontWeight.w700),
                            ),
                            TextButton(
                              onPressed: () {},
                              child: Row(
                                children: [
                                  Text(
                                    "All",
                                    style: TextStyle(
                                      color: colors.accentGreen,
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(width: 4.w),
                                  SvgPicture.asset(
                                    Assets.icons.navArrowRight,
                                    package: 'grab_go_shared',
                                    width: 16.w,
                                    height: 16.w,
                                    colorFilter: ColorFilter.mode(colors.accentGreen, BlendMode.srcIn),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 6.h),
                        ListView.separated(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _recentTransactions.length,
                          separatorBuilder: (context, index) => SizedBox(height: 12.h),
                          itemBuilder: (context, index) {
                            final transaction = _recentTransactions[index];
                            final typeColor = _getTransactionTypeColor(transaction.type, colors);
                            final iconPath = _getTransactionIcon(transaction.type);
                            final typeLabel = _getTransactionTypeLabel(transaction.type);

                            final timeFormat = DateFormat('MMM dd, hh:mm a');
                            final timeString = timeFormat.format(transaction.dateTime);

                            return Container(
                              padding: EdgeInsets.all(14.w),
                              decoration: BoxDecoration(
                                color: colors.backgroundPrimary,
                                borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                                border: Border.all(color: colors.border, width: 1),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 48.w,
                                    height: 48.w,
                                    decoration: BoxDecoration(
                                      color: typeColor.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                                    ),
                                    child: Center(
                                      child: SvgPicture.asset(
                                        iconPath,
                                        package: 'grab_go_shared',
                                        width: 24.w,
                                        height: 24.w,
                                        colorFilter: ColorFilter.mode(typeColor, BlendMode.srcIn),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 16.w),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          transaction.description,
                                          style: TextStyle(
                                            color: colors.textPrimary,
                                            fontSize: 14.sp,
                                            fontWeight: FontWeight.w600,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        SizedBox(height: 4.h),
                                        Row(
                                          children: [
                                            Text(
                                              typeLabel,
                                              style: TextStyle(
                                                color: typeColor,
                                                fontSize: 12.sp,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            SizedBox(width: 8.w),
                                            Text(
                                              timeString,
                                              style: TextStyle(
                                                color: colors.textSecondary,
                                                fontSize: 12.sp,
                                                fontWeight: FontWeight.w400,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        "GHC ${transaction.amount.toStringAsFixed(2)}",
                                        style: TextStyle(
                                          color: colors.textPrimary,
                                          fontSize: 16.sp,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      SizedBox(height: 2.h),
                                      Container(
                                        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                                        decoration: BoxDecoration(
                                          color: colors.success.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          transaction.status.name.toUpperCase(),
                                          style: TextStyle(
                                            color: colors.success,
                                            fontSize: 9.sp,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        SizedBox(height: 32.h),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
