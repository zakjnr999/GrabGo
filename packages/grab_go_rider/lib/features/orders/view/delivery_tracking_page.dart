import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:grab_go_rider/features/chat/view/chat_detail_page.dart';
import 'package:grab_go_rider/features/orders/service/available_orders_service.dart';
import 'package:grab_go_rider/features/orders/viewmodel/rider_tracking_provider.dart';
import 'package:grab_go_rider/features/orders/widgets/cancel_order_dialog.dart';
import 'package:grab_go_rider/features/orders/widgets/photo_proof_capture.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:provider/provider.dart';

class DeliveryTrackingPage extends StatefulWidget {
  final String orderId;
  final String customerName;
  final String customerAddress;
  final String customerPhone;
  final String? customerPhoto;
  final String restaurantName;
  final String restaurantAddress;
  final String? restaurantLogo;
  final String orderTotal;
  final List<String> orderItems;
  final String? specialInstructions;
  final String? phase;
  final bool? hasPickedUp;

  final String? customerId;
  final String? riderId;
  final double? pickupLatitude;
  final double? pickupLongitude;
  final double? destinationLatitude;
  final double? destinationLongitude;
  final bool isGiftOrder;
  final bool deliveryVerificationRequired;
  final String? giftRecipientName;
  final String? giftRecipientPhone;
  final String? deliveryVerificationMethod;
  final bool testTrigger;

  const DeliveryTrackingPage({
    super.key,
    required this.orderId,
    required this.customerName,
    required this.customerAddress,
    required this.customerPhone,
    this.customerPhoto,
    required this.restaurantName,
    required this.restaurantAddress,
    this.restaurantLogo,
    required this.orderTotal,
    required this.orderItems,
    this.specialInstructions,
    this.phase,
    this.hasPickedUp,
    this.customerId,
    this.riderId,
    this.pickupLatitude,
    this.pickupLongitude,
    this.destinationLatitude,
    this.destinationLongitude,
    this.isGiftOrder = false,
    this.deliveryVerificationRequired = false,
    this.giftRecipientName,
    this.giftRecipientPhone,
    this.deliveryVerificationMethod,
    this.testTrigger = false,
  });

  @override
  State<DeliveryTrackingPage> createState() => _DeliveryTrackingPageState();
}

class _DeliveryTrackingPageState extends State<DeliveryTrackingPage> {
  static const Duration _sheetAnimationDuration = Duration(milliseconds: 280);
  static const Curve _sheetAnimationCurve = Curves.easeOutCubic;

  RiderTrackingProvider? _trackingProvider;
  late String _currentPhase;
  bool _showBottomSheet = false;
  double _bottomSheetDragDistance = 0;
  bool _isInitializing = true;
  String? _initError;

  // Production features state
  bool _hasArrivedAtPickup = false;
  bool _hasArrivedAtCustomer = false;
  bool _isCompletingDelivery = false;
  bool _isProcessingStageAction = false;

  @override
  void initState() {
    super.initState();
    _currentPhase = _deriveInitialPhaseFromRoute();
    _hasArrivedAtPickup =
        widget.hasPickedUp == true || _currentPhase == "delivery";
    // Initialize tracking when page loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _trackingProvider = context.read<RiderTrackingProvider>();
      _trackingProvider?.addListener(_onTrackingProviderChanged);
      _initializeTracking();
    });
  }

  @override
  void dispose() {
    _trackingProvider?.removeListener(_onTrackingProviderChanged);
    _trackingProvider = null;
    super.dispose();
  }

  String _deriveInitialPhaseFromRoute() {
    if (widget.hasPickedUp == true) return "delivery";
    if ((widget.phase ?? "").toLowerCase() == "delivery") return "delivery";
    return "pickup";
  }

  String _phaseFromTrackingStatus(String statusName) {
    switch (statusName) {
      case 'preparing':
        return "pickup";
      case 'pickedUp':
      case 'inTransit':
      case 'nearby':
      case 'delivered':
      case 'cancelled':
        return "delivery";
      default:
        return "pickup";
    }
  }

  bool _arrivedAtPickupFromStatus(String statusName) {
    return statusName != 'preparing';
  }

  bool _arrivedAtCustomerFromStatus(String statusName) {
    return statusName == 'nearby' || statusName == 'delivered';
  }

  void _onTrackingProviderChanged() {
    final provider = _trackingProvider;
    if (!mounted || provider == null || !provider.hasActiveSession) return;
    _syncUiStateFromProvider(provider);
  }

  void _syncUiStateFromProvider(
    RiderTrackingProvider provider, {
    bool force = false,
  }) {
    if (!provider.hasActiveSession && !force) return;

    final statusName = provider.currentStatus.name;
    final nextPhase = _phaseFromTrackingStatus(statusName);
    final nextHasArrivedAtPickup =
        _arrivedAtPickupFromStatus(statusName) || _hasArrivedAtPickup;
    final nextHasArrivedAtCustomer = _arrivedAtCustomerFromStatus(statusName);

    if (!force &&
        nextPhase == _currentPhase &&
        nextHasArrivedAtPickup == _hasArrivedAtPickup &&
        nextHasArrivedAtCustomer == _hasArrivedAtCustomer) {
      return;
    }

    if (!mounted) return;
    setState(() {
      _currentPhase = nextPhase;
      _hasArrivedAtPickup = nextHasArrivedAtPickup;
      _hasArrivedAtCustomer = nextHasArrivedAtCustomer;
    });
  }

  Future<void> _initializeTracking() async {
    final trackingProvider = context.read<RiderTrackingProvider>();

    // Debug: Log all received values
    debugPrint('🔍 DeliveryTrackingPage received:');
    debugPrint('   orderId: ${widget.orderId}');
    debugPrint('   customerId: ${widget.customerId}');
    debugPrint('   riderId: ${widget.riderId}');
    debugPrint('   pickupLatitude: ${widget.pickupLatitude}');
    debugPrint('   pickupLongitude: ${widget.pickupLongitude}');
    debugPrint('   destinationLatitude: ${widget.destinationLatitude}');
    debugPrint('   destinationLongitude: ${widget.destinationLongitude}');
    debugPrint(
      '   deliveryVerificationRequired: ${widget.deliveryVerificationRequired}',
    );
    debugPrint('   testTrigger: ${widget.testTrigger}');

    if (widget.testTrigger) {
      debugPrint(
        '🧪 Test trigger active: starting local demo tracking session',
      );
      final initialized = await trackingProvider.initializeTracking(
        orderId: widget.orderId,
        riderId: widget.riderId ?? "demo-rider",
        customerId: widget.customerId ?? "demo-customer",
        pickupLatitude: widget.pickupLatitude ?? 5.60372,
        pickupLongitude: widget.pickupLongitude ?? -0.18700,
        destinationLatitude: widget.destinationLatitude ?? 5.57458,
        destinationLongitude: widget.destinationLongitude ?? -0.21516,
        useDemoSimulation: true,
      );

      setState(() {
        _currentPhase = "pickup";
        _hasArrivedAtPickup = false;
        _isInitializing = false;
        if (!initialized) {
          _initError =
              trackingProvider.lastError ??
              'Failed to initialize demo tracking';
        }
      });
      _syncUiStateFromProvider(trackingProvider, force: true);
      return;
    }

    // Check if we have the required data for tracking initialization
    if (widget.customerId == null ||
        widget.riderId == null ||
        widget.pickupLatitude == null ||
        widget.pickupLongitude == null ||
        widget.destinationLatitude == null ||
        widget.destinationLongitude == null) {
      debugPrint(
        '⚠️ Missing tracking data, attempting to resume existing tracking',
      );
      debugPrint(
        '   → This usually means you used the test button instead of accepting a real order',
      );

      // Try to resume existing tracking for this order
      final success = await trackingProvider.resumeTracking(widget.orderId);

      setState(() {
        _isInitializing = false;
        if (!success && trackingProvider.lastError != null) {
          _initError = 'Could not initialize tracking. Using offline mode.';
        }
      });
      if (success) {
        _syncUiStateFromProvider(trackingProvider, force: true);
      }
      return;
    }

    // First, try to resume existing tracking (in case we're returning to this page)
    debugPrint('🔄 Checking for existing tracking...');
    final resumed = await trackingProvider.resumeTracking(widget.orderId);

    if (resumed) {
      debugPrint('✅ Resumed existing tracking');
      setState(() {
        _isInitializing = false;
      });
      _syncUiStateFromProvider(trackingProvider, force: true);
      return;
    }

    // No existing tracking found, initialize fresh tracking
    debugPrint('📝 No existing tracking, initializing new...');
    final success = await trackingProvider.initializeTracking(
      orderId: widget.orderId,
      riderId: widget.riderId!,
      customerId: widget.customerId!,
      pickupLatitude: widget.pickupLatitude!,
      pickupLongitude: widget.pickupLongitude!,
      destinationLatitude: widget.destinationLatitude!,
      destinationLongitude: widget.destinationLongitude!,
    );

    setState(() {
      _isInitializing = false;
      if (!success) {
        _initError =
            trackingProvider.lastError ?? 'Failed to initialize tracking';
      }
    });
    if (success) {
      _syncUiStateFromProvider(trackingProvider, force: true);
    }
  }

  void _expandBottomSheet() {
    if (_showBottomSheet) return;
    setState(() {
      _showBottomSheet = true;
    });
  }

  void _collapseBottomSheet() {
    if (!_showBottomSheet) return;
    setState(() {
      _showBottomSheet = false;
    });
  }

  Future<void> _refreshTrackingData(AppColorsExtension colors) async {
    final trackingProvider = context.read<RiderTrackingProvider>();
    final refreshed = await _runWithLoadingDialog(
      colors: colors,
      message: "Refreshing tracking...",
      task: () => trackingProvider.resumeTracking(
        widget.orderId,
        useDemoSimulation: widget.testTrigger,
      ),
    );

    if (!mounted) return;
    if (refreshed) {
      _syncUiStateFromProvider(trackingProvider, force: true);
      _showToast(
        colors: colors,
        message: "Tracking refreshed",
        backgroundColor: colors.accentGreen,
      );
      return;
    }

    _showToast(
      colors: colors,
      message:
          trackingProvider.lastError ??
          "Could not refresh tracking. Please try again.",
      backgroundColor: colors.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final mediaQuery = MediaQuery.of(context);
    final size = mediaQuery.size;
    final bottomSafeArea = mediaQuery.padding.bottom;
    final collapsedPreviewHeight = bottomSafeArea + 72.h;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: colors.backgroundPrimary,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: colors.backgroundSecondary,
        body: Stack(
          children: [
            // Google Maps
            Positioned.fill(
              child: Consumer<RiderTrackingProvider>(
                builder: (context, trackingProvider, child) {
                  // Default camera position (Accra, Ghana)
                  final initialPosition =
                      trackingProvider.currentLatLng ??
                      trackingProvider.pickupLatLng ??
                      const LatLng(5.6037, -0.1870);

                  return GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: initialPosition,
                      zoom: 15,
                    ),
                    markers: trackingProvider.markers,
                    polylines: trackingProvider.polylines,
                    circles: trackingProvider.circles,
                    // Disable all default Google Maps UI
                    myLocationEnabled: false,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                    compassEnabled: false,
                    rotateGesturesEnabled: true,
                    scrollGesturesEnabled: true,
                    zoomGesturesEnabled: true,
                    tiltGesturesEnabled: false,
                    indoorViewEnabled: false,
                    trafficEnabled: false,
                    buildingsEnabled: false,
                    liteModeEnabled: false,
                    // Apply custom GrabGo branded style from shared package
                    style: GrabGoMapStyles.forBrightness(
                      Theme.of(context).brightness,
                    ),
                    padding: EdgeInsets.only(
                      bottom: _showBottomSheet
                          ? size.height * 0.45
                          : collapsedPreviewHeight,
                    ),
                    onMapCreated: (GoogleMapController controller) {
                      trackingProvider.setMapController(controller);
                    },
                    onCameraMoveStarted:
                        trackingProvider.onMapCameraMoveStarted,
                    onCameraIdle: trackingProvider.onMapCameraIdle,
                    onTap: (_) {
                      if (_showBottomSheet) {
                        _collapseBottomSheet();
                      } else {
                        _expandBottomSheet();
                      }
                    },
                  );
                },
              ),
            ),

            Positioned(
              top: MediaQuery.of(context).padding.top + 8.h,
              left: 16.w,
              right: 16.w,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    height: 48,
                    width: 48,
                    decoration: BoxDecoration(
                      color: colors.backgroundPrimary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                              ? Colors.black.withAlpha(30)
                              : Colors.black.withAlpha(30),
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
                            colorFilter: ColorFilter.mode(
                              colors.textPrimary,
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    height: 48,
                    width: 48,
                    decoration: BoxDecoration(
                      color: colors.backgroundPrimary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                              ? Colors.black.withAlpha(30)
                              : Colors.black.withAlpha(30),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => {},
                        customBorder: const CircleBorder(),
                        child: Padding(
                          padding: EdgeInsets.all(11.r),
                          child: SvgPicture.asset(
                            Assets.icons.headsetHelp,
                            package: 'grab_go_shared',
                            colorFilter: ColorFilter.mode(
                              colors.textPrimary,
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Positioned(
              top: MediaQuery.of(context).padding.top + 12.h,
              left: 0,
              right: 0,
              child: Consumer<RiderTrackingProvider>(
                builder: (context, trackingProvider, child) {
                  return IgnorePointer(
                    child: Center(
                      child: _buildMapStatusPill(
                        isDark: isDark,
                        colors: colors,
                        connectionHealth: trackingProvider.connectionHealth,
                        pendingUpdates: trackingProvider.pendingLocationUpdates,
                      ),
                    ),
                  );
                },
              ),
            ),

            Positioned(
              right: 16.w,
              top: MediaQuery.of(context).padding.top + 58.h,
              child: _buildMapControlButton(
                icon: Assets.icons.expand,
                onTap: () {
                  final provider = context.read<RiderTrackingProvider>();
                  provider.animateCameraToFitMarkers();
                },
                colors: colors,
                isDark: isDark,
              ),

              // child: _buildMapControlButton(
              //   icon: Assets.icons.sendDiagonal,
              //   onTap: () {
              //     final provider = context.read<RiderTrackingProvider>();
              //     provider.animateCameraToFitMarkers();
              //   },
              //   colors: colors,
              //   isDark: isDark,
              // ),
            ),

            Positioned(
              left: 16.w,
              top: MediaQuery.of(context).padding.top + 58.h,
              child: _buildMapControlButton(
                icon: Assets.icons.refresh,
                onTap: () => _refreshTrackingData(colors),
                colors: colors,
                isDark: isDark,
              ),
            ),

            AnimatedPositioned(
              duration: _sheetAnimationDuration,
              curve: _sheetAnimationCurve,
              right: 16.w,
              bottom: _showBottomSheet
                  ? (size.height * 0.45) + 14.h
                  : collapsedPreviewHeight + 10.h,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildMapControlButton(
                    icon: Assets.icons.crosshair,
                    onTap: () {
                      final provider = context.read<RiderTrackingProvider>();
                      provider.centerOnRider();
                    },
                    colors: colors,
                    isDark: isDark,
                  ),
                  SizedBox(height: 10.h),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 10.h,
                    ),
                    decoration: BoxDecoration(
                      color: colors.accentGreen,
                      borderRadius: BorderRadius.circular(999.r),
                    ),
                    child: Row(
                      children: [
                        SvgPicture.asset(
                          Assets.icons.sendDiagonal,
                          package: 'grab_go_shared',
                          width: 16.w,
                          height: 16.h,
                          colorFilter: ColorFilter.mode(
                            Colors.white,
                            BlendMode.srcIn,
                          ),
                        ),
                        SizedBox(width: 6.w),

                        Text(
                          "Navigate",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                ignoring: !_showBottomSheet,
                child: AnimatedSlide(
                  duration: _sheetAnimationDuration,
                  curve: _sheetAnimationCurve,
                  offset: _showBottomSheet ? Offset.zero : const Offset(0, 1),
                  child: Consumer<RiderTrackingProvider>(
                    builder: (context, trackingProvider, child) {
                      // Get ETA and distance from provider, with fallbacks
                      final etaMinutes =
                          trackingProvider.etaMinutes ??
                          (_currentPhase == "pickup" ? 12.0 : 15.0);
                      final distanceKm =
                          trackingProvider.distanceKm ??
                          (_currentPhase == "pickup" ? 4.5 : 5.2);
                      final connectionHealth =
                          trackingProvider.connectionHealth;
                      final bottomSafeArea = MediaQuery.of(
                        context,
                      ).padding.bottom;

                      return Container(
                        height: size.height * 0.45,
                        decoration: BoxDecoration(
                          color: colors.backgroundPrimary,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(
                              KBorderSize.borderRadius20,
                            ),
                            topRight: Radius.circular(
                              KBorderSize.borderRadius20,
                            ),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isDark
                                  ? Colors.black.withAlpha(30)
                                  : Colors.black.withAlpha(8),
                              spreadRadius: 0,
                              blurRadius: 12,
                              offset: const Offset(0, -2),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onVerticalDragStart: (_) {
                                _bottomSheetDragDistance = 0;
                              },
                              onVerticalDragUpdate: (details) {
                                _bottomSheetDragDistance += details.delta.dy;
                              },
                              onVerticalDragEnd: (details) {
                                final velocity = details.primaryVelocity ?? 0;
                                if (_bottomSheetDragDistance > 28 ||
                                    velocity > 500) {
                                  _collapseBottomSheet();
                                }
                                _bottomSheetDragDistance = 0;
                              },
                              child: Padding(
                                padding: EdgeInsets.only(
                                  top: 10.h,
                                  bottom: 8.h,
                                ),
                                child: Center(
                                  child: Container(
                                    width: 40.w,
                                    height: 4.h,
                                    decoration: BoxDecoration(
                                      color: colors.textSecondary.withValues(
                                        alpha: 0.3,
                                      ),
                                      borderRadius: BorderRadius.circular(2.r),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: SingleChildScrollView(
                                physics: const ClampingScrollPhysics(),
                                padding: EdgeInsets.fromLTRB(
                                  20.w,
                                  4.h,
                                  20.w,
                                  12.h,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildSectionLabel("NEXT STOP", colors),
                                    SizedBox(height: 8.h),
                                    _buildDestinationInfo(colors),
                                    SizedBox(height: 14.h),
                                    _buildSectionLabel("LIVE METRICS", colors),
                                    SizedBox(height: 8.h),
                                    Row(
                                      children: [
                                        _buildMetricCard(
                                          label: "ETA",
                                          value: "${etaMinutes.toInt()} min",
                                          accent: colors.accentOrange,
                                          colors: colors,
                                        ),
                                        SizedBox(width: 10.w),
                                        _buildMetricCard(
                                          label: "DISTANCE",
                                          value:
                                              "${distanceKm.toStringAsFixed(1)} km",
                                          accent: colors.accentBlue,
                                          colors: colors,
                                        ),
                                        SizedBox(width: 10.w),
                                        _buildMetricCard(
                                          label: "SIGNAL",
                                          value:
                                              connectionHealth ==
                                                  RiderTrackingConnectionHealth
                                                      .live
                                              ? "Live"
                                              : connectionHealth ==
                                                    RiderTrackingConnectionHealth
                                                        .degraded
                                              ? "Retrying"
                                              : "Offline",
                                          accent:
                                              _bannerColorForConnectionHealth(
                                                colors,
                                                connectionHealth,
                                              ),
                                          colors: colors,
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 8.h),
                                  ],
                                ),
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.fromLTRB(
                                20.w,
                                12.h,
                                20.w,
                                bottomSafeArea + 12.h,
                              ),
                              decoration: BoxDecoration(
                                color: colors.backgroundPrimary,
                                boxShadow: [
                                  BoxShadow(
                                    color: colors.shadow.withValues(
                                      alpha: 0.08,
                                    ),
                                    blurRadius: 8,
                                    offset: const Offset(0, -2),
                                  ),
                                ],
                              ),
                              child: _buildActionButtons(colors),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: IgnorePointer(
                ignoring: _showBottomSheet,
                child: AnimatedSlide(
                  duration: _sheetAnimationDuration,
                  curve: _sheetAnimationCurve,
                  offset: _showBottomSheet ? const Offset(0, 1) : Offset.zero,
                  child: Consumer<RiderTrackingProvider>(
                    builder: (context, trackingProvider, child) {
                      return _buildBottomSheetPreview(
                        colors: colors,
                        isDark: isDark,
                        provider: trackingProvider,
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _bannerColorForConnectionHealth(
    AppColorsExtension colors,
    RiderTrackingConnectionHealth health,
  ) {
    switch (health) {
      case RiderTrackingConnectionHealth.live:
        return colors.accentGreen;
      case RiderTrackingConnectionHealth.degraded:
        return colors.accentOrange;
      case RiderTrackingConnectionHealth.offline:
        return colors.error;
    }
  }

  Widget _buildMapStatusPill({
    required bool isDark,
    required AppColorsExtension colors,
    required RiderTrackingConnectionHealth connectionHealth,
    required int pendingUpdates,
  }) {
    final phaseLabel = _currentPhase == "pickup" ? "PICKUP" : "IN TRANSIT";
    final statusAccent = _isInitializing
        ? colors.accentBlue
        : _initError != null
        ? colors.accentOrange
        : _bannerColorForConnectionHealth(colors, connectionHealth);
    final statusLabel = _isInitializing
        ? "INITIALIZING"
        : _initError != null
        ? "OFFLINE MODE"
        : connectionHealth == RiderTrackingConnectionHealth.live
        ? "LIVE TRACKING"
        : connectionHealth == RiderTrackingConnectionHealth.degraded
        ? (pendingUpdates > 0 ? "SYNCING" : "RECONNECTING")
        : "OFFLINE";
    final chipLabel = "$statusLabel • $phaseLabel";

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(999.r),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withAlpha(30)
                : Colors.black.withAlpha(30),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'STATUS',
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 8.sp,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 2.h),
          Text(
            chipLabel,
            style: TextStyle(
              color: statusAccent,
              fontSize: 10.sp,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionLabel(String text, AppColorsExtension colors) {
    return Text(
      text,
      style: TextStyle(
        color: colors.textSecondary,
        fontSize: 11.sp,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildBottomSheetPreview({
    required AppColorsExtension colors,
    required bool isDark,
    required RiderTrackingProvider provider,
  }) {
    final bottomSafeArea = MediaQuery.of(context).padding.bottom;
    final isPickup = _currentPhase == "pickup";
    final destinationName = isPickup
        ? widget.restaurantName
        : widget.customerName;
    final etaMinutes = provider.etaMinutes ?? (isPickup ? 12.0 : 15.0);
    final distanceKm = provider.distanceKm ?? (isPickup ? 4.5 : 5.2);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(KBorderSize.borderRadius20),
          topRight: Radius.circular(KBorderSize.borderRadius20),
        ),
        onTap: _expandBottomSheet,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(18.w, 12.h, 18.w, bottomSafeArea + 12.h),
          decoration: BoxDecoration(
            color: colors.backgroundPrimary,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(KBorderSize.borderRadius20),
              topRight: Radius.circular(KBorderSize.borderRadius20),
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withAlpha(30)
                    : Colors.black.withAlpha(12),
                blurRadius: 12,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      "Next stop: $destinationName",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 13.5.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      "${etaMinutes.toInt()} min • ${distanceKm.toStringAsFixed(1)} km",
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 11.5.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8.w),
              IconButton(
                onPressed: _expandBottomSheet,
                icon: SvgPicture.asset(
                  Assets.icons.navArrowUp,
                  package: 'grab_go_shared',
                  width: 20.w,
                  height: 20.w,
                  colorFilter: ColorFilter.mode(
                    colors.textSecondary,
                    BlendMode.srcIn,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDestinationInfo(AppColorsExtension colors) {
    final isPickup = _currentPhase == "pickup";
    final destinationName = isPickup
        ? widget.restaurantName
        : widget.customerName;
    final destinationAddress = isPickup
        ? widget.restaurantAddress
        : widget.customerAddress;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: colors.backgroundSecondary,
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPickup ? "Pickup location" : "Delivery location",
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  destinationName,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  destinationAddress,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 11.5.sp,
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () => _openCustomerChat(colors),
                child: Container(
                  width: 40.w,
                  height: 40.w,
                  decoration: BoxDecoration(
                    color: colors.accentGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(
                      KBorderSize.borderRadius4,
                    ),
                  ),
                  child: Center(
                    child: SvgPicture.asset(
                      Assets.icons.chatBubble,
                      package: 'grab_go_shared',
                      width: 18.w,
                      height: 18.w,
                      colorFilter: ColorFilter.mode(
                        colors.accentGreen,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8.w),
              GestureDetector(
                onTap: () => {},
                child: Container(
                  width: 40.w,
                  height: 40.w,
                  decoration: BoxDecoration(
                    color: colors.accentGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(
                      KBorderSize.borderRadius4,
                    ),
                  ),
                  child: Center(
                    child: SvgPicture.asset(
                      Assets.icons.phone,
                      package: 'grab_go_shared',
                      width: 18.w,
                      height: 18.w,
                      colorFilter: ColorFilter.mode(
                        colors.accentGreen,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String label,
    required String value,
    required Color accent,
    required AppColorsExtension colors,
  }) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: colors.backgroundSecondary,
          borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
            SizedBox(height: 2.h),
            Text(
              value,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 14.sp,
                fontWeight: FontWeight.w700,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(AppColorsExtension colors) {
    final isPickup = _currentPhase == "pickup";
    final isStageBusy = _isProcessingStageAction;
    final isStageLoading = isStageBusy || _isCompletingDelivery;
    final canShowCancel = isPickup;

    final stageLabel = isStageBusy
        ? "Processing..."
        : isPickup
        ? (!_hasArrivedAtPickup ? "I've Arrived" : "Confirm Pickup")
        : (!_hasArrivedAtCustomer
              ? "I've Arrived"
              : (_isCompletingDelivery
                    ? "Completing..."
                    : "Complete Delivery"));
    final stageAction = isStageBusy
        ? () {}
        : isPickup
        ? (!_hasArrivedAtPickup
              ? () => _confirmArrivalAtPickup(colors)
              : () => _showPickupConfirmDialog(colors))
        : (!_hasArrivedAtCustomer
              ? () => _confirmArrivalAtCustomer(colors)
              : (_isCompletingDelivery
                    ? () {}
                    : () => _startDeliveryCompletion(colors)));

    if (!canShowCancel) {
      return AppButton(
        onPressed: stageAction,
        buttonText: stageLabel,
        isLoading: isStageLoading,
        backgroundColor: colors.accentGreen,
        width: double.infinity,
        borderRadius: KBorderSize.borderRadius4,
        height: 60.h,
        textStyle: TextStyle(
          color: Colors.white,
          fontSize: 15.sp,
          fontWeight: FontWeight.w700,
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: AppButton(
            onPressed: isStageLoading
                ? () {}
                : () => _showCancelOrderDialog(colors),
            buttonText: "Cancel",
            backgroundColor: colors.backgroundSecondary,
            borderRadius: KBorderSize.borderRadius4,
            height: 56.h,
            textStyle: TextStyle(
              color: colors.textSecondary,
              fontSize: 13.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        SizedBox(width: 10.w),
        Expanded(
          flex: 2,
          child: AppButton(
            onPressed: stageAction,
            buttonText: stageLabel,
            isLoading: isStageLoading,
            backgroundColor: colors.accentGreen,
            borderRadius: KBorderSize.borderRadius4,
            height: 56.h,
            textStyle: TextStyle(
              color: Colors.white,
              fontSize: 15.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showPickupConfirmDialog(AppColorsExtension colors) async {
    final confirmed = await AppDialog.show(
      context: context,
      title: "Confirm Pickup?",
      message: "Have you picked up the order from the restaurant?",
      type: AppDialogType.question,
      primaryButtonText: "Confirm",
      secondaryButtonText: "Cancel",
      primaryButtonColor: colors.accentGreen,
      borderRadius: KBorderSize.borderRadius4,
      buttonBorderRadius: KBorderSize.borderRadius4,
    );

    if (!mounted || confirmed != true) return;
    await _confirmPickup(colors);
  }

  Future<void> _confirmPickup(AppColorsExtension colors) async {
    // Update tracking status via provider
    final trackingProvider = context.read<RiderTrackingProvider>();

    // Mark as picked up
    final pickedUpSuccess = await trackingProvider.markAsPickedUp();
    if (!mounted) return;

    if (!pickedUpSuccess) {
      _showToast(
        colors: colors,
        message:
            trackingProvider.lastError ??
            "Failed to update order status. Please try again.",
        backgroundColor: colors.error,
      );
      return;
    }

    debugPrint('✅ Order marked as picked up');

    // Mark as in transit (starts high-frequency location updates)
    final inTransitSuccess = await trackingProvider.markAsInTransit();
    if (!mounted) return;

    if (!inTransitSuccess) {
      _showToast(
        colors: colors,
        message:
            trackingProvider.lastError ??
            "Failed to update order status. Please try again.",
        backgroundColor: colors.error,
      );
      return;
    }

    debugPrint('✅ Order marked as in transit');

    setState(() {
      _currentPhase = "delivery";
    });

    _showToast(
      colors: colors,
      message: "Pickup confirmed! You can now navigate to customer.",
      backgroundColor: colors.accentGreen,
    );
  }

  Future<void> _confirmDelivery(
    AppColorsExtension colors, {
    File? proofPhoto,
    String? deliveryCode,
    String? fallbackReason,
    String? authorizedRecipientName,
  }) async {
    if (_isCompletingDelivery) return;

    setState(() {
      _isCompletingDelivery = true;
    });

    // Update tracking status via provider
    final trackingProvider = context.read<RiderTrackingProvider>();
    Map<String, dynamic>? deliveryVerification;

    try {
      final riderLat = trackingProvider.latitude;
      final riderLng = trackingProvider.longitude;

      if (widget.deliveryVerificationRequired) {
        final normalizedCode = deliveryCode?.trim();
        if (normalizedCode != null && normalizedCode.isNotEmpty) {
          deliveryVerification = {
            'method': 'code',
            'code': normalizedCode,
            if (riderLat != null) 'riderLat': riderLat,
            if (riderLng != null) 'riderLng': riderLng,
          };
        } else {
          final reason = fallbackReason?.trim() ?? '';
          if (proofPhoto == null || reason.isEmpty) {
            _showToast(
              colors: colors,
              message:
                  "Photo and fallback reason are required to complete this delivery.",
              backgroundColor: colors.error,
            );
            return;
          }

          final uploadResult = await trackingProvider.uploadDeliveryProofPhoto(
            proofPhoto,
          );
          if (!mounted) return;

          if (!uploadResult.success ||
              uploadResult.photoUrl == null ||
              uploadResult.photoUrl!.isEmpty) {
            _showToast(
              colors: colors,
              message:
                  uploadResult.message ??
                  "Failed to upload delivery proof photo.",
              backgroundColor: colors.error,
            );
            return;
          }

          deliveryVerification = {
            'method': 'authorized_photo',
            'photoUrl': uploadResult.photoUrl,
            'reason': reason,
            'contactAttempted': true,
            if ((authorizedRecipientName ?? '').trim().isNotEmpty)
              'authorizedRecipientName': authorizedRecipientName!.trim(),
            if (riderLat != null) 'riderLat': riderLat,
            if (riderLng != null) 'riderLng': riderLng,
          };
        }
      } else if (proofPhoto != null) {
        // Best-effort local capture for non-verified orders.
        debugPrint('📸 Delivery proof photo captured: ${proofPhoto.path}');
      }

      final success = await trackingProvider.markAsDelivered(
        deliveryVerification: deliveryVerification,
      );

      if (success) {
        debugPrint('✅ Order marked as delivered');
      }

      if (!mounted) return;

      if (!success) {
        _showToast(
          colors: colors,
          message:
              trackingProvider.lastError ??
              "Failed to complete delivery. Please try again.",
          backgroundColor: colors.error,
        );
        return;
      }

      _showToast(
        colors: colors,
        message: "Order delivered successfully!",
        backgroundColor: colors.accentGreen,
      );

      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        context.go(
          "/delivery-success",
          extra: {
            'orderId': widget.orderId,
            'vendorName': widget.restaurantName,
            'vendorLogo': widget.restaurantLogo,
            'customerName': widget.customerName,
            'customerPhoto': widget.customerPhoto,
          },
        );
      });
    } finally {
      if (mounted) {
        setState(() {
          _isCompletingDelivery = false;
        });
      }
    }
  }

  void _startDeliveryCompletion(AppColorsExtension colors) {
    if (widget.deliveryVerificationRequired) {
      _showDeliveryVerificationDialog(colors);
      return;
    }
    _showPhotoProofDialog(colors);
  }

  Future<void> _showDeliveryVerificationDialog(
    AppColorsExtension colors,
  ) async {
    final recipientLabel = widget.giftRecipientName?.trim().isNotEmpty == true
        ? widget.giftRecipientName!.trim()
        : "recipient";

    final useCode = await AppDialog.show(
      context: context,
      title: "Delivery Verification Required",
      message:
          "This gift order requires verification before completion. Use the 4-digit code from the $recipientLabel, or use authorized photo fallback.",
      type: AppDialogType.info,
      primaryButtonText: "Enter Code",
      secondaryButtonText: "Use Photo Fallback",
      primaryButtonColor: colors.accentGreen,
      borderRadius: KBorderSize.borderRadius4,
      buttonBorderRadius: KBorderSize.borderRadius4,
    );

    if (!mounted) return;
    if (useCode == true) {
      _showDeliveryCodeDialog(colors);
    } else if (useCode == false) {
      _showFallbackPhotoCaptureDialog(colors);
    }
  }

  void _showDeliveryCodeDialog(AppColorsExtension colors) {
    final codeController = TextEditingController();
    bool isSubmitting = false;
    bool isResending = false;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: colors.backgroundPrimary,
            title: Text(
              "Enter Delivery Code",
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 18.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Ask the recipient for the 4-digit delivery code.",
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                SizedBox(height: 12.h),
                TextField(
                  controller: codeController,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  enabled: !isSubmitting && !isResending,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '0000',
                    hintStyle: TextStyle(color: colors.textSecondary),
                    filled: true,
                    fillColor: colors.backgroundSecondary,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        KBorderSize.borderRadius4,
                      ),
                      borderSide: BorderSide(color: colors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        KBorderSize.borderRadius4,
                      ),
                      borderSide: BorderSide(color: colors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                        KBorderSize.borderRadius4,
                      ),
                      borderSide: BorderSide(
                        color: colors.accentGreen,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 8.h),
                TextButton(
                  onPressed: (isSubmitting || isResending)
                      ? null
                      : () async {
                          setDialogState(() => isResending = true);
                          final result = await context
                              .read<RiderTrackingProvider>()
                              .resendDeliveryCodeToRecipient();
                          if (!mounted) return;

                          setDialogState(() => isResending = false);

                          _showToast(
                            colors: colors,
                            message: result.success
                                ? (result.message ??
                                      "Delivery code resent to recipient.")
                                : (result.message ??
                                      "Failed to resend delivery code."),
                            backgroundColor: result.success
                                ? colors.accentGreen
                                : colors.error,
                          );
                        },
                  child: Text(
                    isResending ? "Resending..." : "Resend code to recipient",
                    style: TextStyle(
                      color: colors.accentBlue,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: (isSubmitting || isResending)
                    ? null
                    : () {
                        Navigator.pop(dialogContext);
                        _showFallbackPhotoCaptureDialog(colors);
                      },
                child: Text(
                  "Use Fallback",
                  style: TextStyle(color: colors.accentOrange),
                ),
              ),
              TextButton(
                onPressed: (isSubmitting || isResending)
                    ? null
                    : () => Navigator.pop(dialogContext),
                child: Text(
                  "Cancel",
                  style: TextStyle(color: colors.textSecondary),
                ),
              ),
              ElevatedButton(
                onPressed: (isSubmitting || isResending)
                    ? null
                    : () async {
                        final code = codeController.text.trim();
                        if (code.length != 4 || int.tryParse(code) == null) {
                          _showToast(
                            colors: colors,
                            message: "Delivery code must be exactly 4 digits.",
                            backgroundColor: colors.error,
                          );
                          return;
                        }

                        setDialogState(() => isSubmitting = true);
                        Navigator.pop(dialogContext);
                        await _confirmDelivery(colors, deliveryCode: code);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: colors.accentGreen,
                  foregroundColor: Colors.white,
                ),
                child: const Text("Confirm"),
              ),
            ],
          );
        },
      ),
    ).whenComplete(codeController.dispose);
  }

  void _showFallbackPhotoCaptureDialog(AppColorsExtension colors) {
    PhotoProofCapture.show(
      context: context,
      orderId: widget.orderId,
      orderNumber: 'Order ${widget.orderId}',
      title: 'Authorized Photo Fallback',
      description:
          'Take a clear photo proving delivery to an authorized recipient at the address.',
      onPhotoCapture: (photo) {
        _showFallbackReasonDialog(colors, proofPhoto: photo);
      },
      onSkip: () {
        if (!mounted) return;
        _showToast(
          colors: colors,
          message: "Photo proof is required for fallback verification.",
          backgroundColor: colors.error,
        );
        _showDeliveryVerificationDialog(colors);
      },
    );
  }

  void _showFallbackReasonDialog(
    AppColorsExtension colors, {
    required File proofPhoto,
  }) {
    final reasonController = TextEditingController();
    final authorizedNameController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: colors.backgroundPrimary,
        title: Text(
          "Fallback Details",
          style: TextStyle(
            color: colors.textPrimary,
            fontSize: 18.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Provide a short reason and who received the order (if known).",
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w400,
                ),
              ),
              SizedBox(height: 12.h),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Reason',
                  hintText:
                      'Recipient unavailable, handed to authorized person',
                  filled: true,
                  fillColor: colors.backgroundSecondary,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      KBorderSize.borderRadius4,
                    ),
                    borderSide: BorderSide(color: colors.border),
                  ),
                ),
              ),
              SizedBox(height: 12.h),
              TextField(
                controller: authorizedNameController,
                decoration: InputDecoration(
                  labelText: 'Authorized recipient name (optional)',
                  filled: true,
                  fillColor: colors.backgroundSecondary,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      KBorderSize.borderRadius4,
                    ),
                    borderSide: BorderSide(color: colors.border),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              "Cancel",
              style: TextStyle(color: colors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) {
                _showToast(
                  colors: colors,
                  message: "Please provide a fallback reason.",
                  backgroundColor: colors.error,
                );
                return;
              }

              Navigator.pop(dialogContext);
              _confirmDelivery(
                colors,
                proofPhoto: proofPhoto,
                fallbackReason: reason,
                authorizedRecipientName: authorizedNameController.text.trim(),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.accentGreen,
              foregroundColor: Colors.white,
            ),
            child: const Text("Complete Delivery"),
          ),
        ],
      ),
    ).whenComplete(() {
      reasonController.dispose();
      authorizedNameController.dispose();
    });
  }

  Future<void> _confirmArrivalAtPickup(AppColorsExtension colors) async {
    if (_isProcessingStageAction) return;

    final confirmed = await AppDialog.show(
      context: context,
      title: "Arrived at Vendor?",
      message: "Confirm that you have arrived at ${widget.restaurantName}",
      type: AppDialogType.question,
      primaryButtonText: "Yes, I've Arrived",
      secondaryButtonText: "Not Yet",
      primaryButtonColor: colors.accentGreen,
      borderRadius: KBorderSize.borderRadius4,
      buttonBorderRadius: KBorderSize.borderRadius4,
    );

    if (!mounted || confirmed != true) return;

    setState(() {
      _isProcessingStageAction = true;
    });

    final trackingProvider = context.read<RiderTrackingProvider>();
    final syncSuccess = await _runWithLoadingDialog(
      colors: colors,
      message: "Updating arrival status...",
      task: () => trackingProvider.markAsPreparing(),
    );

    if (!mounted) return;

    setState(() {
      if (syncSuccess) {
        _hasArrivedAtPickup = true;
      }
      _isProcessingStageAction = false;
    });

    _showToast(
      colors: colors,
      message: syncSuccess
          ? "Great! Collect the order and confirm pickup."
          : (trackingProvider.lastError ??
                "Failed to update arrival. Please try again."),
      backgroundColor: syncSuccess ? colors.accentGreen : colors.error,
    );
  }

  /// Confirm arrival at customer location
  Future<void> _confirmArrivalAtCustomer(AppColorsExtension colors) async {
    if (_isProcessingStageAction) return;

    final trackingProvider = context.read<RiderTrackingProvider>();

    final confirmed = await AppDialog.show(
      context: context,
      title: "Arrived at Customer?",
      message: "Confirm that you have arrived at the delivery location",
      type: AppDialogType.question,
      primaryButtonText: "Yes, I've Arrived",
      secondaryButtonText: "Not Yet",
      primaryButtonColor: colors.accentGreen,
      borderRadius: KBorderSize.borderRadius4,
      buttonBorderRadius: KBorderSize.borderRadius4,
    );

    if (!mounted || confirmed != true) return;

    setState(() {
      _isProcessingStageAction = true;
    });

    final syncSuccess = await _runWithLoadingDialog(
      colors: colors,
      message: "Notifying customer of arrival...",
      task: () => trackingProvider.markAsNearby(),
    );

    if (!mounted) return;

    setState(() {
      _isProcessingStageAction = false;
      _hasArrivedAtCustomer = syncSuccess;
    });

    AppToastMessage.show(
      context: context,
      showIcon: false,
      backgroundColor: syncSuccess ? colors.accentGreen : colors.error,
      maxLines: 2,
      radius: KBorderSize.borderRadius4,
      message: syncSuccess
          ? "Customer notified of your arrival!"
          : (trackingProvider.lastError ??
                "Failed to notify customer. Please try again."),
    );
  }

  void _showPhotoProofDialog(AppColorsExtension colors) {
    PhotoProofCapture.show(
      context: context,
      orderId: widget.orderId,
      orderNumber: 'Order ${widget.orderId}',
      title: 'Photo Proof of Delivery',
      description:
          'Take a photo showing the order has been delivered to the customer',
      onPhotoCapture: (photo) {
        _confirmDelivery(colors, proofPhoto: photo);
      },
      onSkip: () async {
        final shouldSkip = await AppDialog.show(
          context: context,
          title: "Skip Photo Proof?",
          message:
              "Without a photo, you may not be protected in case of a delivery dispute. Are you sure?",
          type: AppDialogType.warning,
          primaryButtonText: "Skip Anyway",
          secondaryButtonText: "Take Photo",
          primaryButtonColor: colors.accentGreen,
          borderRadius: KBorderSize.borderRadius4,
          buttonBorderRadius: KBorderSize.borderRadius4,
        );

        if (!mounted) return;
        if (shouldSkip == true) {
          _confirmDelivery(colors);
        } else if (shouldSkip == false) {
          _showPhotoProofDialog(colors);
        }
      },
    );
  }

  void _showCancelOrderDialog(AppColorsExtension colors) {
    final trackingProvider = context.read<RiderTrackingProvider>();
    final orderService = AvailableOrdersService();

    CancelOrderDialog.show(
      context: context,
      orderId: widget.orderId,
      orderNumber: 'Order ${widget.orderId}',
      onConfirm: (reason, notes) async {
        debugPrint(
          'Cancelling order: ${reason.apiValue}${notes != null ? " - $notes" : ""}',
        );

        final success = await orderService.cancelOrder(
          widget.orderId,
          reason: reason.apiValue,
          notes: notes,
        );

        if (!mounted) return;

        if (success) {
          await trackingProvider.stopTracking();
          if (!mounted) return;
          _showToast(
            colors: colors,
            message: 'Order cancelled and released for other riders.',
            backgroundColor: colors.accentGreen,
          );
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) context.pop();
          });
        } else {
          _showToast(
            colors: colors,
            message: 'Failed to cancel order. Please try again.',
            backgroundColor: colors.error,
          );
        }
      },
    );
  }

  Future<void> _openCustomerChat(AppColorsExtension colors) async {
    try {
      final chats = await ChatService().getChats();
      if (!mounted) return;

      ChatConversationDto? matchedChat;
      for (final chat in chats) {
        final matchesOrderId =
            chat.orderId != null && chat.orderId == widget.orderId;
        final matchesOrderNumber =
            chat.orderNumber != null && chat.orderNumber == widget.orderId;
        final matchesCustomerId =
            widget.customerId != null && chat.otherUserId == widget.customerId;

        if (matchesOrderId || matchesOrderNumber || matchesCustomerId) {
          matchedChat = chat;
          break;
        }
      }

      if (matchedChat == null) {
        _showToast(
          colors: colors,
          message: "Customer chat is not ready yet. Please try again shortly.",
          backgroundColor: colors.accentOrange,
        );
        return;
      }

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatDetailPage(
            chatId: matchedChat!.id,
            senderName: matchedChat.otherUserName ?? "Customer",
            profilePicture: matchedChat.otherUserProfilePicture,
            orderId:
                matchedChat.orderNumber ??
                matchedChat.orderId ??
                widget.orderId,
            isSupport: false,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      _showToast(
        colors: colors,
        message: "Could not open customer chat right now.",
        backgroundColor: colors.error,
      );
    }
  }

  void _showToast({
    required AppColorsExtension colors,
    required String message,
    required Color backgroundColor,
    int maxLines = 2,
  }) {
    if (!mounted) return;
    AppToastMessage.show(
      context: context,
      showIcon: false,
      backgroundColor: backgroundColor,
      maxLines: maxLines,
      radius: KBorderSize.borderRadius4,
      message: message,
    );
  }

  Future<T> _runWithLoadingDialog<T>({
    required AppColorsExtension colors,
    required String message,
    required Future<T> Function() task,
  }) async {
    final visibleStopwatch = Stopwatch()..start();
    const minVisibleDuration = Duration(milliseconds: 320);

    if (mounted) {
      // Reset any stale singleton state before showing a new loading overlay.
      LoadingDialog.instance().hide();
      LoadingDialog.instance().show(
        context: context,
        text: message,
        spinColor: colors.accentGreen,
      );
      // Give the overlay one frame to render before running work.
      await Future<void>.delayed(const Duration(milliseconds: 16));
    }

    try {
      return await task();
    } finally {
      final remaining = minVisibleDuration - visibleStopwatch.elapsed;
      if (remaining > Duration.zero) {
        await Future<void>.delayed(remaining);
      }
      if (mounted) {
        LoadingDialog.instance().hide();
      }
    }
  }

  Widget _buildMapControlButton({
    required String icon,
    required VoidCallback onTap,
    required AppColorsExtension colors,
    required bool isDark,
  }) {
    return Container(
      width: 48,
      height: 48,
      padding: EdgeInsets.all(10.w),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withAlpha(30)
                : Colors.black.withAlpha(30),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SvgPicture.asset(
            icon,
            package: 'grab_go_shared',
            width: 22.w,
            height: 22.w,
            colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
          ),
        ),
      ),
    );
  }
}
