import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'package:dotted_line/dotted_line.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_rider/features/orders/service/available_order_dto.dart';
import 'package:grab_go_rider/features/orders/service/order_statistics_service.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_rider/features/orders/service/available_orders_service.dart';
import 'package:geolocator/geolocator.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  bool _routeOptimizationEnabled = true;
  bool _showDropPoints = false;

  final AvailableOrdersService _availableOrdersService = AvailableOrdersService();
  final battery = Battery();
  List<AvailableOrderDto> _availableOrders = [];
  OrderStatistics? _statistics;
  bool _isLoadingOrders = true;
  bool _isBatteryLow = false;
  bool _isCharging = false;
  StreamSubscription<BatteryState>? _batterySubscription;
  String? ordersError;
  double? _currentLat;
  double? _currentLon;

  bool get _showBatteryWarning => _isBatteryLow && !_isCharging;

  String get _farthestDropAddress {
    if (_isLoadingOrders) return "...";
    if (_availableOrders.isEmpty) return "No drops found nearby";
    return _availableOrders.last.customerAddress;
  }

  @override
  void initState() {
    super.initState();
    _initializeLocation();
    _initializeBattery();
  }

  Future<void> _initializeBattery() async {
    try {
      final level = await battery.batteryLevel;
      final state = await battery.batteryState;

      if (!mounted) return;
      setState(() {
        _isBatteryLow = level < 20;
        _isCharging = state == BatteryState.charging || state == BatteryState.full;
      });

      _batterySubscription = battery.onBatteryStateChanged.listen((state) {
        debugPrint('🔋 Battery state changed to: $state');
        if (!mounted) return;
        setState(() {
          _isCharging = state == BatteryState.charging || state == BatteryState.full;
        });
      });
    } catch (e) {
      debugPrint('Error initializing battery info: $e');
    }
  }

  @override
  void dispose() {
    _batterySubscription?.cancel();
    super.dispose();
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

      debugPrint('Location obtained: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  Future<void> _loadAvailableOrders() async {
    setState(() {
      _isLoadingOrders = true;
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
          _isLoadingOrders = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.dark : Brightness.light,
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
            "Orders",
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
              onPressed: () {
                context.push('/availableOrdersMap');
              },
            ),
          ],
          bottom: PreferredSize(
            preferredSize: _showBatteryWarning ? const Size.fromHeight(40) : Size.zero,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              height: _showBatteryWarning ? 40 : 0,
              child: ClipRect(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: _showBatteryWarning ? 1.0 : 0.0,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: colors.warning,
                    child: Row(
                      children: [
                        SvgPicture.asset(
                          Assets.icons.battery25,
                          package: 'grab_go_shared',
                          width: 16.w,
                          height: 16.w,
                          colorFilter: ColorFilter.mode(Colors.white, BlendMode.srcIn),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Low battery. Consider charging before accepting new orders.',
                            style: TextStyle(fontSize: 11.sp, color: Colors.white, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        body: _isLoadingOrders || _availableOrders.isNotEmpty
            ? _buildOrdersContent(colors)
            : _buildNoOrdersState(colors),
      ),
    );
  }

  Widget _buildNoOrdersState(AppColorsExtension colors) {
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 40.w),
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
                onPressed: _loadAvailableOrders,
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

  Widget _buildOrdersContent(AppColorsExtension colors) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: 20.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(height: 20.h),
          Container(
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: colors.backgroundPrimary,
              borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 20.w,
                      height: 20.w,
                      decoration: BoxDecoration(
                        color: colors.accentGreen,
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.backgroundSecondary, width: 3),
                      ),
                      child: Center(
                        child: Container(
                          width: 8.w,
                          height: 8.w,
                          decoration: BoxDecoration(color: colors.backgroundSecondary, shape: BoxShape.circle),
                        ),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Text(
                      "From your location",
                      style: TextStyle(color: colors.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),

                SizedBox(height: 16.h),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          Container(
                            height: 40.h,
                            width: 2.w,
                            decoration: BoxDecoration(color: colors.border, borderRadius: BorderRadius.circular(2)),
                          ),
                          SizedBox(height: 4.h),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: List.generate(3, (index) {
                              return Container(
                                width: 6.w,
                                height: 6.w,
                                decoration: BoxDecoration(color: colors.accentGreen, shape: BoxShape.circle),
                              );
                            }),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      flex: 4,
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _showDropPoints = !_showDropPoints;
                          });
                        },
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                          decoration: BoxDecoration(
                            color: colors.backgroundSecondary,
                            borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _isLoadingOrders
                                    ? "... DROP POINTS"
                                    : "${_statistics?.totalDropPoints ?? 0} DROP POINTS",
                                style: TextStyle(
                                  color: colors.textSecondary,
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(width: 6.w),
                              Icon(
                                _showDropPoints ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                                size: 16.w,
                                color: colors.textSecondary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: _showDropPoints && _availableOrders.isNotEmpty
                      ? Column(
                          children: [
                            SizedBox(height: 12.h),
                            ...List.generate(_availableOrders.length, (index) {
                              final order = _availableOrders[index];
                              return Padding(
                                padding: EdgeInsets.only(bottom: 12.h),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      margin: EdgeInsets.only(top: 6.h),
                                      width: 8.w,
                                      height: 8.w,
                                      decoration: BoxDecoration(color: colors.accentGreen, shape: BoxShape.circle),
                                    ),
                                    SizedBox(width: 12.w),
                                    Expanded(
                                      child: Text(
                                        "${index + 1}. ${order.customerAddress}",
                                        style: TextStyle(
                                          color: colors.textSecondary,
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),

                SizedBox(height: 16.h),

                Row(
                  children: [
                    Container(
                      margin: EdgeInsets.only(top: 4.h),
                      child: SvgPicture.asset(
                        Assets.icons.mapPin,
                        package: 'grab_go_shared',
                        width: 20.w,
                        height: 20.w,
                        colorFilter: ColorFilter.mode(colors.error, BlendMode.srcIn),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Text(
                        _farthestDropAddress,
                        style: TextStyle(color: colors.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          SizedBox(height: 24.h),

          Container(
            padding: EdgeInsets.all(20.w),
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "DELIVERY EARNINGS",
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(height: 6.h),
                        Text(
                          _isLoadingOrders
                              ? "GHC ..."
                              : "GHC ${_statistics?.totalEarnings.toStringAsFixed(2) ?? '0.00'}",
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 28.sp,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),

                SizedBox(height: 24.h),

                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "TOTAL TIPS",
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(height: 6.h),
                          Text(
                            _isLoadingOrders ? "GHC ..." : "GHC ${_statistics?.totalTips.toStringAsFixed(2) ?? '0.00'}",
                            style: TextStyle(color: colors.textPrimary, fontSize: 22.sp, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 20.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "TOTAL DISTANCE",
                            style: TextStyle(
                              color: colors.textSecondary,
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(height: 6.h),
                          Text(
                            _isLoadingOrders
                                ? "... km"
                                : "${_statistics?.totalDistance.toStringAsFixed(1) ?? '0.0'} km",
                            style: TextStyle(color: colors.textPrimary, fontSize: 22.sp, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 24.h),
                DottedLine(
                  direction: Axis.horizontal,
                  lineLength: double.infinity,
                  lineThickness: 1.5,
                  dashLength: 6,
                  dashColor: colors.inputBorder.withValues(alpha: 0.65),
                  dashGapLength: 4,
                ),
                SizedBox(height: 12.h),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "TOTAL EST. EARNINGS",
                      style: TextStyle(
                        color: colors.accentGreen,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(width: 2.w),
                    Text(
                      _isLoadingOrders
                          ? "GHC ..."
                          : "GHC ${((_statistics?.totalEarnings ?? 0) + (_statistics?.totalTips ?? 0)).toStringAsFixed(2)}",
                      style: TextStyle(
                        color: colors.accentGreen,
                        fontSize: 24.sp,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          SizedBox(height: 24.h),

          Container(
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: colors.backgroundPrimary,
              borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
            ),
            child: Row(
              children: [
                CustomSwitch(
                  value: _routeOptimizationEnabled,
                  onChanged: (value) {
                    setState(() {
                      _routeOptimizationEnabled = value;
                    });
                  },
                  activeColor: colors.accentGreen,
                  inactiveColor: colors.border,
                  thumbColor: colors.backgroundPrimary,
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    "Use traffic-aware route optimization to plan my deliveries",
                    style: TextStyle(color: colors.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: 32.h),

          Column(
            children: [
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [colors.accentGreen, colors.accentGreen.withValues(alpha: 0.85)]),
                  borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      context.push(
                        '/order-confirmation',
                        extra: {
                          'orderId': 'ORD-12345',
                          'restaurantName': 'Pizza Palace',
                          'restaurantAddress': '456 Food Street, Accra',
                          'customerName': 'John Doe',
                          'customerAddress': '123 Main Street, Accra',
                          'customerPhone': '+233 123 456 789',
                          'orderTotal': 'GHS 45.00',
                          'orderItems': ['Pizza Margherita x1', 'Coca Cola x2'],
                          'specialInstructions': 'Ring doorbell twice',
                          'customerId': 'test-customer-123',
                          'riderId': 'test-rider-456',
                          'pickupLatitude': 5.6037,
                          'pickupLongitude': -0.1870,
                          'destinationLatitude': 5.6145,
                          'destinationLongitude': -0.2056,
                        },
                      );
                    },
                    borderRadius: BorderRadius.circular(KBorderSize.borderRadius8),
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 18.h, horizontal: 20.w),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SvgPicture.asset(
                            Assets.icons.deliveryTruck,
                            package: 'grab_go_shared',
                            width: 24.w,
                            height: 24.w,
                            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                          ),
                          SizedBox(width: 12.w),
                          Text(
                            "Accept ${_isLoadingOrders ? "..." : _availableOrders.length} Available Orders",
                            style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              SizedBox(height: 16.h),

              GestureDetector(
                onTap: () {
                  context.push('/availableOrders');
                },
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.symmetric(vertical: 18.h, horizontal: 20.w),
                  decoration: BoxDecoration(
                    color: colors.inputBorder,
                    borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                  ),
                  child: Center(
                    child: Text(
                      "No, I'll custom select orders",
                      style: TextStyle(color: colors.textSecondary, fontSize: 14.sp, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ),

              SizedBox(height: KSpacing.lg.h),
            ],
          ),

          SizedBox(height: 32.h),
        ],
      ),
    );
  }
}
