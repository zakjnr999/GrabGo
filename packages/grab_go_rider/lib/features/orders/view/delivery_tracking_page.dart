import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:grab_go_rider/features/orders/service/available_orders_service.dart';
import 'package:grab_go_rider/features/orders/viewmodel/rider_tracking_provider.dart';
import 'package:grab_go_rider/features/orders/widgets/cancel_order_dialog.dart';
import 'package:grab_go_rider/features/orders/widgets/external_navigation_helper.dart';
import 'package:grab_go_rider/features/orders/widgets/photo_proof_capture.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:provider/provider.dart';

class DeliveryTrackingPage extends StatefulWidget {
  final String orderId;
  final String customerName;
  final String customerAddress;
  final String customerPhone;
  final String restaurantName;
  final String restaurantAddress;
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

  const DeliveryTrackingPage({
    super.key,
    required this.orderId,
    required this.customerName,
    required this.customerAddress,
    required this.customerPhone,
    required this.restaurantName,
    required this.restaurantAddress,
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
  });

  @override
  State<DeliveryTrackingPage> createState() => _DeliveryTrackingPageState();
}

class _DeliveryTrackingPageState extends State<DeliveryTrackingPage> {
  late String _currentPhase;
  bool _showBottomSheet = true;
  bool _isInitializing = true;
  String? _initError;

  // Production features state
  bool _hasArrivedAtPickup = false;
  bool _hasArrivedAtCustomer = false;
  bool _isCompletingDelivery = false;

  @override
  void initState() {
    super.initState();
    _currentPhase = widget.phase ?? "pickup";
    // Initialize tracking when page loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeTracking();
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
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: colors.backgroundSecondary,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: Container(
            margin: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: colors.backgroundPrimary.withValues(alpha: 0.9),
              shape: BoxShape.circle,
              border: Border.all(
                color: colors.border.withValues(alpha: 0.3),
                width: 1,
              ),
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
          actions: [
            Container(
              margin: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: colors.backgroundPrimary.withValues(alpha: 0.9),
                shape: BoxShape.circle,
                border: Border.all(
                  color: colors.border.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    _showCallOptions(context, colors);
                  },
                  customBorder: const CircleBorder(),
                  child: Padding(
                    padding: EdgeInsets.all(10.r),
                    child: SvgPicture.asset(
                      Assets.icons.phone,
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
                      bottom: _showBottomSheet ? size.height * 0.45 : 80.h,
                    ),
                    onMapCreated: (GoogleMapController controller) {
                      trackingProvider.setMapController(controller);
                    },
                    onTap: (_) {
                      setState(() {
                        _showBottomSheet = !_showBottomSheet;
                      });
                    },
                  );
                },
              ),
            ),

            // Map control buttons (recenter)
            Positioned(
              right: 16.w,
              bottom: _showBottomSheet ? size.height * 0.52 : 100.h,
              child: Column(
                children: [
                  _buildMapControlButton(
                    icon: Icons.my_location,
                    onTap: () {
                      final provider = context.read<RiderTrackingProvider>();
                      provider.centerOnRider();
                    },
                    colors: colors,
                    isDark: isDark,
                  ),
                  SizedBox(height: 8.h),
                  _buildMapControlButton(
                    icon: Icons.zoom_out_map,
                    onTap: () {
                      final provider = context.read<RiderTrackingProvider>();
                      provider.animateCameraToFitMarkers();
                    },
                    colors: colors,
                    isDark: isDark,
                  ),
                ],
              ),
            ),

            if (_showBottomSheet)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Consumer<RiderTrackingProvider>(
                  builder: (context, trackingProvider, child) {
                    // Get ETA and distance from provider, with fallbacks
                    final etaMinutes =
                        trackingProvider.etaMinutes ??
                        (_currentPhase == "pickup" ? 12.0 : 15.0);
                    final distanceKm =
                        trackingProvider.distanceKm ??
                        (_currentPhase == "pickup" ? 4.5 : 5.2);
                    final isTracking = trackingProvider.isTracking;

                    return Container(
                      height: size.height * 0.50,
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
                                : Colors.black.withAlpha(8),
                            spreadRadius: 0,
                            blurRadius: 12,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              margin: EdgeInsets.only(top: 12.h),
                              width: 40.w,
                              height: 4.h,
                              decoration: BoxDecoration(
                                color: colors.textSecondary.withValues(
                                  alpha: 0.3,
                                ),
                                borderRadius: BorderRadius.circular(2.r),
                              ),
                            ),

                            Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 20.w,
                                vertical: 16.h,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Tracking status indicator
                                  if (_isInitializing)
                                    _buildTrackingStatusBanner(
                                      colors: colors,
                                      icon: Icons.sync,
                                      message: 'Initializing tracking...',
                                      color: colors.accentBlue,
                                    )
                                  else if (_initError != null)
                                    _buildTrackingStatusBanner(
                                      colors: colors,
                                      icon: Icons.warning_amber_rounded,
                                      message: _initError!,
                                      color: colors.accentOrange,
                                    )
                                  else if (isTracking)
                                    _buildTrackingStatusBanner(
                                      colors: colors,
                                      icon: Icons.gps_fixed,
                                      message: 'Live tracking active',
                                      color: colors.accentGreen,
                                    ),

                                  if (_isInitializing ||
                                      _initError != null ||
                                      isTracking)
                                    SizedBox(height: 12.h),

                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        widget.orderId,
                                        style: TextStyle(
                                          color: colors.textPrimary,
                                          fontSize: 16.sp,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 12.w,
                                          vertical: 6.h,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              (_currentPhase == "pickup"
                                                      ? colors.accentOrange
                                                      : colors.accentGreen)
                                                  .withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(
                                            KBorderSize.borderRadius4,
                                          ),
                                        ),
                                        child: Text(
                                          _currentPhase == "pickup"
                                              ? "Pickup"
                                              : "In Transit",
                                          style: TextStyle(
                                            color: _currentPhase == "pickup"
                                                ? colors.accentOrange
                                                : colors.accentGreen,
                                            fontSize: 12.sp,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  SizedBox(height: 16.h),

                                  _buildDestinationInfo(colors),

                                  SizedBox(height: 16.h),

                                  Container(
                                    padding: EdgeInsets.all(16.w),
                                    decoration: BoxDecoration(
                                      color: colors.backgroundSecondary,
                                      borderRadius: BorderRadius.circular(
                                        KBorderSize.borderRadius4,
                                      ),
                                      border: Border.all(
                                        color: colors.border.withValues(
                                          alpha: 0.3,
                                        ),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        _buildInfoItem(
                                          icon: Assets.icons.timer,
                                          label: "ETA",
                                          value: "${etaMinutes.toInt()} min",
                                          iconColor: colors.accentOrange,
                                          colors: colors,
                                        ),
                                        Container(
                                          width: 1,
                                          height: 40.h,
                                          color: colors.border,
                                          margin: EdgeInsets.symmetric(
                                            horizontal: 16.w,
                                          ),
                                        ),
                                        _buildInfoItem(
                                          icon: Assets.icons.mapPin,
                                          label: "Distance",
                                          value:
                                              "${distanceKm.toStringAsFixed(1)} km",
                                          iconColor: colors.accentBlue,
                                          colors: colors,
                                        ),
                                      ],
                                    ),
                                  ),

                                  SizedBox(height: 20.h),

                                  _buildActionButtons(colors),

                                  SizedBox(height: 20.h),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

            if (!_showBottomSheet)
              Positioned(
                bottom: 20.h,
                left: 0,
                right: 0,
                child: Center(
                  child: FloatingActionButton.extended(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        KBorderSize.borderRadius4,
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        _showBottomSheet = true;
                      });
                    },
                    backgroundColor: colors.backgroundPrimary,
                    icon: SvgPicture.asset(
                      Assets.icons.mapPin,
                      package: 'grab_go_shared',
                      width: 20.w,
                      height: 20.w,
                      colorFilter: ColorFilter.mode(
                        colors.textPrimary,
                        BlendMode.srcIn,
                      ),
                    ),
                    label: Text(
                      "Show Details",
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackingStatusBanner({
    required AppColorsExtension colors,
    required IconData icon,
    required String message,
    required Color color,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16.w),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 12.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
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
        border: Border.all(color: colors.border, width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.r),
            decoration: BoxDecoration(
              color: (isPickup ? colors.accentOrange : colors.accentViolet)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
            ),
            child: SvgPicture.asset(
              isPickup ? Assets.icons.chefHat : Assets.icons.user,
              package: 'grab_go_shared',
              width: 20.w,
              height: 20.w,
              colorFilter: ColorFilter.mode(
                isPickup ? colors.accentOrange : colors.accentViolet,
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
                  isPickup ? "Restaurant" : "Customer",
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w400,
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
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: SvgPicture.asset(
              Assets.icons.phone,
              package: 'grab_go_shared',
              width: 20.w,
              height: 20.w,
              colorFilter: ColorFilter.mode(
                colors.accentGreen,
                BlendMode.srcIn,
              ),
            ),
            onPressed: () {},
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required String icon,
    required String label,
    required String value,
    required Color iconColor,
    required AppColorsExtension colors,
  }) {
    return Expanded(
      child: Row(
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
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: colors.textSecondary,
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  value,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 16.sp,
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

  Widget _buildActionButtons(AppColorsExtension colors) {
    if (_currentPhase == "pickup") {
      return Column(
        children: [
          // External navigation button
          _buildActionButton(
            icon: Assets.icons.deliveryTruck,
            label: "Open in Maps App",
            onPressed: () => _openExternalNavigation(isPickup: true),
            backgroundColor: colors.accentBlue,
            colors: colors,
          ),
          SizedBox(height: 12.h),
          // Arrival confirmation or pickup confirmation
          if (!_hasArrivedAtPickup)
            _buildActionButton(
              icon: Assets.icons.mapPin,
              label: "I've Arrived at Restaurant",
              onPressed: () => _confirmArrivalAtPickup(colors),
              backgroundColor: colors.accentOrange,
              colors: colors,
            )
          else
            _buildActionButton(
              icon: Assets.icons.check,
              label: "Confirm Pickup",
              onPressed: () => _showPickupConfirmDialog(colors),
              backgroundColor: colors.accentGreen,
              colors: colors,
            ),
          SizedBox(height: 12.h),
          // Cancel order button
          _buildActionButton(
            icon: Assets.icons.xmark,
            label: "Cancel Order",
            onPressed: () => _showCancelOrderDialog(colors),
            backgroundColor: colors.error.withValues(alpha: 0.8),
            colors: colors,
          ),
        ],
      );
    } else {
      return Column(
        children: [
          // External navigation button
          _buildActionButton(
            icon: Assets.icons.navArrowRight,
            label: "Open in Maps App",
            onPressed: () => _openExternalNavigation(isPickup: false),
            backgroundColor: colors.accentBlue,
            colors: colors,
          ),
          SizedBox(height: 12.h),
          // Arrival confirmation or delivery confirmation
          Row(
            children: [
              if (!_hasArrivedAtCustomer)
                Expanded(
                  child: _buildActionButton(
                    icon: Assets.icons.mapPin,
                    label: "I've Arrived",
                    onPressed: () => _confirmArrivalAtCustomer(colors),
                    backgroundColor: colors.accentOrange,
                    colors: colors,
                  ),
                )
              else
                Expanded(
                  child: _buildActionButton(
                    icon: Assets.icons.check,
                    label: _isCompletingDelivery
                        ? "Completing..."
                        : "Complete Delivery",
                    onPressed: _isCompletingDelivery
                        ? () {}
                        : () => _startDeliveryCompletion(colors),
                    backgroundColor: colors.accentGreen,
                    colors: colors,
                  ),
                ),
              SizedBox(width: 8.w),
              // Cancel order button (smaller)
              SizedBox(
                width: 56.w,
                child: _buildActionButton(
                  icon: Assets.icons.xmark,
                  label: "",
                  onPressed: () => _showCancelOrderDialog(colors),
                  backgroundColor: colors.error.withValues(alpha: 0.8),
                  colors: colors,
                  showLabel: false,
                ),
              ),
            ],
          ),
        ],
      );
    }
  }

  Widget _buildActionButton({
    required String icon,
    required String label,
    required VoidCallback onPressed,
    required Color backgroundColor,
    required AppColorsExtension colors,
    bool showLabel = true,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
        child: Container(
          padding: EdgeInsets.symmetric(
            vertical: 14.h,
            horizontal: showLabel ? 0 : 8.w,
          ),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(
                icon,
                package: 'grab_go_shared',
                width: 18.w,
                height: 18.w,
                colorFilter: const ColorFilter.mode(
                  Colors.white,
                  BlendMode.srcIn,
                ),
              ),
              if (showLabel && label.isNotEmpty) ...[
                SizedBox(width: 8.w),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showPickupConfirmDialog(AppColorsExtension colors) {
    AppDialog.show(
      context: context,
      title: "Confirm Pickup?",
      message: "Have you picked up the order from the restaurant?",
      type: AppDialogType.question,
      primaryButtonText: "Confirm",
      secondaryButtonText: "Cancel",
      primaryButtonColor: colors.accentGreen,
      borderRadius: KBorderSize.borderRadius4,
      buttonBorderRadius: KBorderSize.borderRadius4,
      onPrimaryPressed: () {
        Navigator.pop(context);
        _confirmPickup(colors);
      },
      onSecondaryPressed: () => Navigator.pop(context),
    );
  }

  Future<void> _confirmPickup(AppColorsExtension colors) async {
    // Update tracking status via provider
    final trackingProvider = context.read<RiderTrackingProvider>();

    // Mark as picked up
    final pickedUpSuccess = await trackingProvider.markAsPickedUp();
    if (pickedUpSuccess) {
      debugPrint('✅ Order marked as picked up');
    }

    // Mark as in transit (starts high-frequency location updates)
    final inTransitSuccess = await trackingProvider.markAsInTransit();
    if (inTransitSuccess) {
      debugPrint('✅ Order marked as in transit');
    }

    if (!mounted) return;

    if (!pickedUpSuccess || !inTransitSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            trackingProvider.lastError ??
                "Failed to update order status. Please try again.",
          ),
          backgroundColor: colors.error,
        ),
      );
      return;
    }

    setState(() {
      _currentPhase = "delivery";
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          "Pickup confirmed! You can now navigate to customer.",
        ),
        backgroundColor: colors.accentGreen,
      ),
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
    final messenger = ScaffoldMessenger.of(context);
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
            messenger.showSnackBar(
              SnackBar(
                content: const Text(
                  "Photo and fallback reason are required to complete this delivery.",
                ),
                backgroundColor: colors.error,
              ),
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
            messenger.showSnackBar(
              SnackBar(
                content: Text(
                  uploadResult.message ??
                      "Failed to upload delivery proof photo.",
                ),
                backgroundColor: colors.error,
              ),
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
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              trackingProvider.lastError ??
                  "Failed to complete delivery. Please try again.",
            ),
            backgroundColor: colors.error,
          ),
        );
        return;
      }

      messenger.showSnackBar(
        SnackBar(
          content: const Text("Order delivered successfully!"),
          backgroundColor: colors.accentGreen,
        ),
      );

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) context.pop();
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

  void _showDeliveryVerificationDialog(AppColorsExtension colors) {
    final recipientLabel = widget.giftRecipientName?.trim().isNotEmpty == true
        ? widget.giftRecipientName!.trim()
        : "recipient";

    AppDialog.show(
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
      onPrimaryPressed: () {
        Navigator.pop(context);
        _showDeliveryCodeDialog(colors);
      },
      onSecondaryPressed: () {
        Navigator.pop(context);
        _showFallbackPhotoCaptureDialog(colors);
      },
    );
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

                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: Text(
                                result.success
                                    ? (result.message ??
                                          "Delivery code resent to recipient.")
                                    : (result.message ??
                                          "Failed to resend delivery code."),
                              ),
                              backgroundColor: result.success
                                  ? colors.accentGreen
                                  : colors.error,
                            ),
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
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                "Delivery code must be exactly 4 digits.",
                              ),
                              backgroundColor: colors.error,
                            ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              "Photo proof is required for fallback verification.",
            ),
            backgroundColor: colors.error,
          ),
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
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text("Please provide a fallback reason."),
                    backgroundColor: colors.error,
                  ),
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

  // ============== PRODUCTION FEATURES ==============

  /// Confirm arrival at restaurant (pickup location)
  void _confirmArrivalAtPickup(AppColorsExtension colors) {
    AppDialog.show(
      context: context,
      title: "Arrived at Restaurant?",
      message: "Confirm that you have arrived at ${widget.restaurantName}",
      type: AppDialogType.question,
      primaryButtonText: "Yes, I've Arrived",
      secondaryButtonText: "Not Yet",
      primaryButtonColor: colors.accentOrange,
      borderRadius: KBorderSize.borderRadius4,
      buttonBorderRadius: KBorderSize.borderRadius4,
      onPrimaryPressed: () {
        Navigator.pop(context);
        setState(() {
          _hasArrivedAtPickup = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("Great! Collect the order and confirm pickup."),
            backgroundColor: colors.accentOrange,
          ),
        );
      },
      onSecondaryPressed: () => Navigator.pop(context),
    );
  }

  /// Confirm arrival at customer location
  void _confirmArrivalAtCustomer(AppColorsExtension colors) {
    // Capture provider before showing dialog
    final trackingProvider = context.read<RiderTrackingProvider>();
    final messenger = ScaffoldMessenger.of(context);

    AppDialog.show(
      context: context,
      title: "Arrived at Customer?",
      message: "Confirm that you have arrived at the delivery location",
      type: AppDialogType.question,
      primaryButtonText: "Yes, I've Arrived",
      secondaryButtonText: "Not Yet",
      primaryButtonColor: colors.accentOrange,
      borderRadius: KBorderSize.borderRadius4,
      buttonBorderRadius: KBorderSize.borderRadius4,
      onPrimaryPressed: () {
        Navigator.pop(context);
        setState(() {
          _hasArrivedAtCustomer = true;
        });
        // Notify backend that rider has arrived nearby
        trackingProvider.markAsNearby();

        messenger.showSnackBar(
          SnackBar(
            content: const Text("Customer notified of your arrival!"),
            backgroundColor: colors.accentOrange,
          ),
        );
      },
      onSecondaryPressed: () => Navigator.pop(context),
    );
  }

  /// Show photo proof capture dialog before completing delivery
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
      onSkip: () {
        // Show warning about skipping photo
        AppDialog.show(
          context: context,
          title: "Skip Photo Proof?",
          message:
              "Without a photo, you may not be protected in case of a delivery dispute. Are you sure?",
          type: AppDialogType.warning,
          primaryButtonText: "Skip Anyway",
          secondaryButtonText: "Take Photo",
          primaryButtonColor: colors.accentOrange,
          borderRadius: KBorderSize.borderRadius4,
          buttonBorderRadius: KBorderSize.borderRadius4,
          onPrimaryPressed: () {
            Navigator.pop(context);
            _confirmDelivery(colors);
          },
          onSecondaryPressed: () {
            Navigator.pop(context);
            _showPhotoProofDialog(colors);
          },
        );
      },
    );
  }

  /// Show cancel order dialog with reason selection
  void _showCancelOrderDialog(AppColorsExtension colors) {
    // Capture provider reference before showing dialog
    final trackingProvider = context.read<RiderTrackingProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final orderService = AvailableOrdersService();

    CancelOrderDialog.show(
      context: context,
      orderId: widget.orderId,
      orderNumber: 'Order ${widget.orderId}',
      onConfirm: (reason, notes) async {
        debugPrint(
          '🚫 Cancelling order: ${reason.apiValue}${notes != null ? " - $notes" : ""}',
        );

        // Call the backend to properly cancel and release the order
        final success = await orderService.cancelOrder(
          widget.orderId,
          reason: reason.apiValue,
          notes: notes,
        );

        if (!mounted) return;

        if (success) {
          // Stop tracking after successful cancellation
          await trackingProvider.stopTracking();

          messenger.showSnackBar(
            SnackBar(
              content: const Text(
                "Order cancelled and released for other riders.",
              ),
              backgroundColor: colors.error,
            ),
          );
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) context.pop();
          });
        } else {
          messenger.showSnackBar(
            SnackBar(
              content: const Text("Failed to cancel order. Please try again."),
              backgroundColor: colors.error,
            ),
          );
        }
      },
    );
  }

  /// Open external navigation app (Google Maps or Waze)
  void _openExternalNavigation({required bool isPickup}) {
    final trackingProvider = context.read<RiderTrackingProvider>();

    double? destLat;
    double? destLng;
    String destName;

    if (isPickup) {
      destLat = trackingProvider.pickupLatitude ?? widget.pickupLatitude;
      destLng = trackingProvider.pickupLongitude ?? widget.pickupLongitude;
      destName = widget.restaurantName;
    } else {
      destLat =
          trackingProvider.destinationLatitude ?? widget.destinationLatitude;
      destLng =
          trackingProvider.destinationLongitude ?? widget.destinationLongitude;
      destName = widget.customerAddress;
    }

    if (destLat != null && destLng != null) {
      ExternalNavigationHelper.showNavigationOptions(
        context: context,
        destinationLat: destLat,
        destinationLng: destLng,
        destinationName: destName,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Location coordinates not available"),
          backgroundColor: context.appColors.error,
        ),
      );
    }
  }

  void _showCallOptions(BuildContext context, AppColorsExtension colors) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: colors.backgroundPrimary,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(KBorderSize.borderRadius4),
            topRight: Radius.circular(KBorderSize.borderRadius4),
          ),
        ),
        padding: EdgeInsets.all(20.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40.w,
              height: 4.h,
              margin: EdgeInsets.only(bottom: 20.h),
              decoration: BoxDecoration(
                color: colors.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2.r),
              ),
            ),
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(10.r),
                decoration: BoxDecoration(
                  color: colors.accentOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(
                    KBorderSize.borderRadius4,
                  ),
                ),
                child: SvgPicture.asset(
                  Assets.icons.chefHat,
                  package: 'grab_go_shared',
                  width: 20.w,
                  height: 20.w,
                  colorFilter: ColorFilter.mode(
                    colors.accentOrange,
                    BlendMode.srcIn,
                  ),
                ),
              ),
              title: Text(
                "Call Restaurant",
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                "Contact restaurant for order details",
                style: TextStyle(color: colors.textSecondary, fontSize: 12.sp),
              ),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            Divider(color: colors.border),
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(10.r),
                decoration: BoxDecoration(
                  color: colors.accentViolet.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(
                    KBorderSize.borderRadius4,
                  ),
                ),
                child: SvgPicture.asset(
                  Assets.icons.user,
                  package: 'grab_go_shared',
                  width: 20.w,
                  height: 20.w,
                  colorFilter: ColorFilter.mode(
                    colors.accentViolet,
                    BlendMode.srcIn,
                  ),
                ),
              ),
              title: Text(
                "Call Customer",
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                widget.customerPhone,
                style: TextStyle(color: colors.textSecondary, fontSize: 12.sp),
              ),
              onTap: () {
                Navigator.pop(context);
              },
            ),
            SizedBox(height: 20.h),
          ],
        ),
      ),
    );
  }

  Widget _buildMapControlButton({
    required IconData icon,
    required VoidCallback onTap,
    required AppColorsExtension colors,
    required bool isDark,
  }) {
    return Container(
      width: 44.w,
      height: 44.w,
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withAlpha(30)
                : Colors.black.withAlpha(15),
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
          child: Icon(icon, color: colors.textPrimary, size: 22.sp),
        ),
      ),
    );
  }
}
