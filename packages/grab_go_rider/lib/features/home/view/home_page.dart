import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_rider/features/home/models/transaction_model.dart';
import 'package:grab_go_rider/features/orders/service/available_order_dto.dart';
import 'package:grab_go_rider/features/orders/service/available_orders_service.dart';
import 'package:grab_go_rider/features/orders/service/order_reservation_service.dart';
import 'package:grab_go_rider/features/orders/service/order_statistics_service.dart';
import 'package:grab_go_rider/features/orders/widgets/delay_reason_dialog.dart';
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

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  List<TransactionModel> _recentTransactions = [];
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rippleAnimation;
  bool onlineStatus = false;
  bool _isCheckingStatus = true;
  bool _isTogglingStatus = false;
  bool _isAppInForeground = true;

  double? _currentLat;
  double? _currentLon;
  bool isLoadingOrders = true;
  String? ordersError;
  List<AvailableOrderDto> _availableOrders = [];
  final AvailableOrdersService _availableOrdersService = AvailableOrdersService();
  final OrderReservationService _reservationService = OrderReservationService();

  Timer? _locationUpdateTimer;
  final Battery _battery = Battery();

  OrderStatistics? _statistics;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSampleTransactions();
    _setupAnimations();
    _initializeLocation();
    _initializeReservationService();
    _checkOnlineStatus();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      _isAppInForeground = true;
      if (onlineStatus) {
        _startLocationBatteryUpdates();
        _updateLocationAndBattery();
      }
      debugPrint('App resumed - location updates active');
    } else if (state == AppLifecycleState.paused) {
      _isAppInForeground = false;
      _locationUpdateTimer?.cancel();
      debugPrint('📱 App paused - location updates paused');
    }
  }

  Future<void> _checkOnlineStatus() async {
    try {
      final result = await _reservationService.checkOnlineStatus();

      if (!mounted) return;

      setState(() {
        onlineStatus = result['isOnline'] ?? false;
        _isCheckingStatus = false;
      });

      if (result['autoOfflineInfo'] != null) {
        final info = result['autoOfflineInfo'] as Map<String, dynamic>;
        _showAutoOfflineMessage(info['reason'] as String?, context.appColors);
      }

      if (onlineStatus) {
        _startLocationBatteryUpdates();
        _loadAvailableOrders();
      }

      debugPrint('Online status from server: $onlineStatus');
    } catch (e) {
      debugPrint('Error checking online status: $e');
      if (mounted) {
        setState(() {
          onlineStatus = false;
          _isCheckingStatus = false;
        });
      }
    }
  }

  void _showAutoOfflineMessage(String? reason, AppColorsExtension colors) {
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

    AppToastMessage.show(
      context: context,
      showIcon: false,
      backgroundColor: colors.accentGreen,
      gravity: ToastGravity.CENTER,
      radius: KBorderSize.borderRadius4,
      duration: const Duration(seconds: 5),
      message: message,
    );
  }

  void _handleOnlineStatusToggle(bool value, AppColorsExtension colors) async {
    if (_isCheckingStatus || _isTogglingStatus) return;

    setState(() {
      _isTogglingStatus = true;
    });

    bool success;
    if (value) {
      success = await _reservationService.goOnline();
      if (success) {
        _startLocationBatteryUpdates();
      }
    } else {
      success = await _reservationService.goOffline();
      if (success) {
        _locationUpdateTimer?.cancel();
      }
    }

    if (!mounted) return;

    setState(() {
      _isTogglingStatus = false;
      if (success) {
        onlineStatus = value;
        // Clear orders when going offline, load when going online
        if (value) {
          _loadAvailableOrders();
        } else {
          _availableOrders = [];
          _statistics = null;
          ordersError = null;
          isLoadingOrders = false;
        }
      }
    });

    if (!success) {
      AppToastMessage.show(
        context: context,
        backgroundColor: colors.error,
        gravity: ToastGravity.CENTER,
        radius: KBorderSize.borderRadius4,
        message: 'Failed to ${value ? "go online" : "go offline"}. Please try again.',
      );
    }
  }

  void _startLocationBatteryUpdates() {
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (onlineStatus && _isAppInForeground) {
        _updateLocationAndBattery();
      }
    });
  }

  Future<void> _updateLocationAndBattery() async {
    try {
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 10)),
        );
      } catch (e) {
        debugPrint('Error getting location for update: $e');
      }

      int batteryLevel = 100;
      bool isCharging = false;
      try {
        batteryLevel = await _battery.batteryLevel;
        final batteryState = await _battery.batteryState;
        isCharging = batteryState == BatteryState.charging || batteryState == BatteryState.full;
      } catch (e) {
        debugPrint('Error getting battery for update: $e');
      }

      if (position != null) {
        await _reservationService.updateLocation(
          position.latitude,
          position.longitude,
          batteryLevel: batteryLevel,
          isCharging: isCharging,
        );
        debugPrint('Location & battery updated: (${position.latitude}, ${position.longitude}), $batteryLevel%');
      }
    } catch (e) {
      debugPrint('Error in periodic update: $e');
    }
  }

  void _initializeReservationService() {
    SocketService().initialize();
    _reservationService.initialize();

    _reservationService.onReservationReceived = (reservation) {
      if (mounted) {
        OrderReservationModal.show(
          context,
          reservation,
          onAccepted: () {
            _loadAvailableOrders();
            AppToastMessage.show(
              context: context,
              gravity: ToastGravity.CENTER,
              radius: KBorderSize.borderRadius4,
              message: 'Order accepted! Navigate to pickup location.',
              backgroundColor: AppColors.accentGreen,
            );
            context.push('/orderConfirmation/${reservation.orderId}');
          },
          onDeclined: () {
            AppToastMessage.show(
              context: context,
              gravity: ToastGravity.CENTER,
              radius: KBorderSize.borderRadius4,
              message: 'Order declined. Waiting for new orders...',
              backgroundColor: AppColors.errorRed,
            );
          },
          onExpired: () {
            AppToastMessage.show(
              context: context,
              message: 'Order reservation expired.',
              backgroundColor: AppColors.errorRed,
              gravity: ToastGravity.CENTER,
              radius: KBorderSize.borderRadius4,
            );
          },
        );
      }
    };

    _reservationService.onReservationCancelled = (orderId, reason) {
      if (mounted) {
        AppToastMessage.show(
          context: context,
          message: 'Order was cancelled: $reason',
          backgroundColor: AppColors.errorRed,
          gravity: ToastGravity.CENTER,
          radius: KBorderSize.borderRadius4,
        );
      }
    };

    _reservationService.onDeliveryWarning = (warning) {
      if (mounted) {
        _showDeliveryWarningDialog(warning);
      }
    };

    _reservationService.onDeliveryLate = (lateInfo) {
      if (mounted) {
        _showDelayReasonDialog(lateInfo);
      }
    };

    _setupAutoOfflineListener();

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
    WidgetsBinding.instance.removeObserver(this);
    _pulseController.dispose();
    _locationUpdateTimer?.cancel();
    _removeAutoOfflineListener();
    super.dispose();
  }

  void _setupAutoOfflineListener() {
    final socket = SocketService().socket;
    socket?.on('rider:auto_offline', (data) {
      if (!mounted) return;

      final reason = data['reason'] as String?;
      final message = data['message'] as String?;

      debugPrint('Auto-offlined by server: $reason - $message');

      setState(() {
        onlineStatus = false;
      });
      _locationUpdateTimer?.cancel();

      _showAutoOfflineMessage(reason, context.appColors);
    });
  }

  void _removeAutoOfflineListener() {
    final socket = SocketService().socket;
    socket?.off('rider:auto_offline');
  }

  void _showDeliveryWarningDialog(DeliveryWarning warning) {
    final colors = context.appColors;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: colors.backgroundPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KBorderSize.borderRadius4)),
        title: Text(
          'Delivery Window Ending!',
          style: TextStyle(fontSize: 18.sp, color: colors.textPrimary, fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(20.w),
              decoration: BoxDecoration(
                color: colors.accentGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
              ),
              child: SvgPicture.asset(
                Assets.icons.timer,
                package: 'grab_go_shared',
                colorFilter: ColorFilter.mode(colors.accentGreen, BlendMode.srcIn),
                width: 40.w,
                height: 40.h,
              ),
            ),
            SizedBox(height: 24.h),
            Text(
              'Order #${warning.orderNumber}',
              style: TextStyle(color: colors.textPrimary, fontSize: 16.sp, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 12.h),
            Text(
              '${warning.minutesRemaining} minutes remaining to complete this delivery. Please hurry!',
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textSecondary, fontSize: 14.sp, height: 1.5),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          AppButton(
            onPressed: () => Navigator.of(context).pop(),
            buttonText: "Got it!",
            width: double.infinity,
            height: 46.h,
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
            backgroundColor: colors.accentGreen,
            borderRadius: KBorderSize.borderRadius4,
            textStyle: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  void _showDelayReasonDialog(DeliveryLate lateInfo) {
    DelayReasonDialog.show(
      context,
      orderId: lateInfo.orderId,
      orderNumber: lateInfo.orderNumber,
      onSubmitted: () {
        AppToastMessage.show(
          context: context,
          message: 'Thank you for letting us know!',
          backgroundColor: context.appColors.accentGreen,
          gravity: ToastGravity.CENTER,
          radius: KBorderSize.borderRadius4,
          showIcon: false,
        );
      },
    );
  }

  Future<void> _initializeLocation() async {
    await _getCurrentLocation();
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
                                _isCheckingStatus || _isTogglingStatus
                                    ? Text(
                                        _isCheckingStatus
                                            ? "Checking status..."
                                            : (onlineStatus ? "Going offline..." : "Going online..."),
                                        style: TextStyle(
                                          color: colors.textSecondary,
                                          fontSize: 16.sp,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      )
                                    : Text(
                                        onlineStatus ? "You're Online" : "You're Offline",
                                        style: TextStyle(
                                          color: colors.textPrimary,
                                          fontSize: 16.sp,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                SizedBox(height: 4.h),
                                Text(
                                  _isCheckingStatus
                                      ? "Please wait..."
                                      : _isTogglingStatus
                                      ? (onlineStatus ? "Stopping order alerts..." : "Preparing to receive orders...")
                                      : onlineStatus
                                      ? "Ready to accept deliveries"
                                      : "You won't receive new orders",
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
                            onChanged: (_isCheckingStatus || _isTogglingStatus)
                                ? (_) {}
                                : (value) => _handleOnlineStatusToggle(value, colors),
                            activeColor: (_isCheckingStatus || _isTogglingStatus)
                                ? colors.accentGreen.withValues(alpha: 0.5)
                                : colors.accentGreen,
                            inactiveColor: (_isCheckingStatus || _isTogglingStatus)
                                ? colors.border.withValues(alpha: 0.5)
                                : colors.border,
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
                      onTap: onlineStatus
                          ? () {
                              ordersError != null ? _loadAvailableOrders() : context.push("/orders");
                            }
                          : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        padding: EdgeInsets.all(20.w),
                        decoration: BoxDecoration(
                          color: !onlineStatus
                              ? colors.backgroundPrimary
                              : ordersError != null
                              ? colors.error.withValues(alpha: 0.09)
                              : colors.accentGreen.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                        ),
                        child: Row(
                          children: [
                            !onlineStatus
                                ? const SizedBox.shrink()
                                : ordersError != null
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
                            SizedBox(
                              width: !onlineStatus
                                  ? 16.w
                                  : ordersError != null
                                  ? 20.w
                                  : 10.w,
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (onlineStatus)
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
                                  if (onlineStatus) SizedBox(height: 8.h),
                                  Text(
                                    !onlineStatus
                                        ? "No Orders Available"
                                        : isLoadingOrders
                                        ? "..."
                                        : ordersError != null
                                        ? "Failed to load orders..."
                                        : _statistics != null
                                        ? "${_statistics!.totalOrders} orders available"
                                        : "You have no available orders",
                                    style: TextStyle(
                                      color: !onlineStatus
                                          ? colors.textPrimary
                                          : ordersError == null
                                          ? colors.textPrimary
                                          : colors.error,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 18.sp,
                                    ),
                                  ),
                                  SizedBox(height: 4.h),
                                  Text(
                                    !onlineStatus
                                        ? "Go online to see available orders"
                                        : ordersError == null
                                        ? "Tap to view and accept"
                                        : "Tap to try again",
                                    style: TextStyle(
                                      color: colors.textSecondary,
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (onlineStatus && ordersError == null)
                              SvgPicture.asset(
                                Assets.icons.navArrowRight,
                                package: "grab_go_shared",
                                width: 24.w,
                                height: 24.w,
                                colorFilter: ColorFilter.mode(colors.accentGreen, BlendMode.srcIn),
                              ),
                            if (!onlineStatus)
                              SvgPicture.asset(
                                Assets.icons.lock,
                                package: "grab_go_shared",
                                width: 50.w,
                                height: 50.w,
                                colorFilter: ColorFilter.mode(
                                  colors.textSecondary.withValues(alpha: 0.4),
                                  BlendMode.srcIn,
                                ),
                              ),
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
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                              decoration: BoxDecoration(
                                color: colors.backgroundPrimary,
                                borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    "This Week",
                                    style: TextStyle(
                                      color: colors.textPrimary,
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                  SizedBox(width: 10.w),
                                  SvgPicture.asset(
                                    Assets.icons.navArrowDown,
                                    package: 'grab_go_shared',
                                    width: 14.w,
                                    height: 14.h,
                                    colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
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

        floatingActionButton: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(KBorderSize.border),
            boxShadow: [
              BoxShadow(
                color: colors.accentGreen.withValues(alpha: 0.4),
                blurRadius: 10,
                spreadRadius: 0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: FloatingActionButton.extended(
            onPressed: () => context.push("/chatlist"),
            extendedPadding: EdgeInsets.all(10.r),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KBorderSize.borderRadius4)),
            backgroundColor: colors.accentGreen,
            elevation: 0,
            label: Text(
              "Messages",
              style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: colors.backgroundPrimary),
            ),
            icon: Badge(
              backgroundColor: colors.error,
              label: Text(
                '2',
                style: TextStyle(color: Colors.white, fontSize: 10.sp, fontWeight: FontWeight.w600),
              ),
              child: Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                ),
                child: SvgPicture.asset(
                  Assets.icons.chatBubble,
                  height: 20.h,
                  width: 20.w,
                  package: 'grab_go_shared',
                  colorFilter: ColorFilter.mode(Colors.white, BlendMode.srcIn),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
