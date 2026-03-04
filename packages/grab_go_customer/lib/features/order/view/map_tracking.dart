import 'package:dotted_line/dotted_line.dart';
import 'package:easy_stepper/easy_stepper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:grab_go_customer/features/order/service/order_service_wrapper.dart';
import 'package:grab_go_customer/features/order/view/rating_onboarding.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:provider/provider.dart';
import '../providers/tracking_provider.dart';
import '../config/tracking_service_locator.dart';
import 'delivery_success_screen.dart';
import 'call_screen.dart';

class MapTracking extends StatefulWidget {
  final String orderId;
  final bool testTrigger;

  const MapTracking({super.key, required this.orderId, this.testTrigger = false});

  @override
  State<MapTracking> createState() => _MapTrackingState();
}

class _MapTrackingState extends State<MapTracking> {
  bool _hasShownSuccessScreen = false;
  String? _previousStatus;
  bool _isSheetCollapsed = true;
  TrackingProvider? _trackingProvider;
  Future<TrackingProvider>? _initFuture;
  List<_TrackedOrderItem> _orderItems = const [];
  String? _vendorName;
  String? _vendorLogo;

  @override
  void initState() {
    super.initState();
    _initFuture = _initializeTrackingServices();
  }

  Future<TrackingProvider> _initializeTrackingServices() async {
    final token = await CacheService.getAuthToken();
    final isDemoOrderId = widget.orderId.toUpperCase().startsWith('DEMO-');
    final shouldUseDemoMode = AppConfig.trackingDemoMode || widget.testTrigger || isDemoOrderId;

    if (!shouldUseDemoMode && (token == null || token.isEmpty)) {
      throw Exception('Auth token not found');
    }

    // Recreate tracking services for each page session to avoid stale/disposed singletons.
    disposeTrackingServices();

    // Setup services first
    setupTrackingServices(
      baseUrl: AppConfig.apiBaseUrl,
      token: (token == null || token.isEmpty) ? 'demo-token' : token,
    );

    // Now get the provider from GetIt
    final provider = trackingLocator<TrackingProvider>();
    provider.setLocalDemoSession(shouldUseDemoMode);
    _trackingProvider = provider;

    // Initialize tracking for this order
    await provider.initializeTracking(widget.orderId);
    _loadOrderDetails();

    return provider;
  }

  Future<void> _loadOrderDetails() async {
    try {
      final orderData = await OrderServiceWrapper().getOrder(widget.orderId);
      final vendorMeta = _extractVendorMeta(orderData);
      if (!mounted) return;
      setState(() {
        _orderItems = _parseTrackedOrderItems(orderData['items']);
        _vendorName = vendorMeta.name;
        _vendorLogo = vendorMeta.logo;
      });
    } catch (_) {
      // Keep tracking available even if order-details fetch fails.
    }
  }

  _VendorMeta _extractVendorMeta(Map<String, dynamic> rawOrder) {
    String? name;
    String? logo;

    final restaurant = rawOrder['restaurant'];
    final groceryStore = rawOrder['groceryStore'];
    final pharmacyStore = rawOrder['pharmacyStore'];
    final grabMartStore = rawOrder['grabMartStore'];

    if (restaurant is Map) {
      final data = Map<String, dynamic>.from(restaurant);
      name = data['restaurantName']?.toString();
      logo = data['logo']?.toString();
    } else if (groceryStore is Map) {
      final data = Map<String, dynamic>.from(groceryStore);
      name = data['storeName']?.toString();
      logo = data['logo']?.toString();
    } else if (pharmacyStore is Map) {
      final data = Map<String, dynamic>.from(pharmacyStore);
      name = data['storeName']?.toString();
      logo = data['logo']?.toString();
    } else if (grabMartStore is Map) {
      final data = Map<String, dynamic>.from(grabMartStore);
      name = data['storeName']?.toString();
      logo = data['logo']?.toString();
    }

    final cleanedName = name?.trim();
    final cleanedLogo = logo?.trim();
    return _VendorMeta(
      name: (cleanedName != null && cleanedName.isNotEmpty) ? cleanedName : null,
      logo: (cleanedLogo != null && cleanedLogo.isNotEmpty) ? cleanedLogo : null,
    );
  }

  List<_TrackedOrderItem> _parseTrackedOrderItems(dynamic rawItems) {
    if (rawItems is! List) return const [];
    final parsed = <_TrackedOrderItem>[];

    for (final raw in rawItems) {
      if (raw is! Map) continue;
      final item = Map<String, dynamic>.from(raw);
      final itemName = item['name']?.toString().trim().isNotEmpty == true
          ? item['name'].toString().trim()
          : item['food'] is Map
          ? (item['food']['name']?.toString().trim().isNotEmpty == true
                ? item['food']['name'].toString().trim()
                : 'Item')
          : 'Item';

      parsed.add(
        _TrackedOrderItem(
          name: itemName,
          quantity: _toInt(item['quantity'], fallback: 1),
          priceLabel: _formatCurrency(_toDouble(item['price']) ?? 0.0),
          customizationSummary: _buildCustomizationSummary(item),
        ),
      );
    }
    return parsed;
  }

  String? _buildCustomizationSummary(Map<String, dynamic> item) {
    final parts = <String>[];

    final selectedPortion = item['selectedPortion'];
    final portionLabel = selectedPortion is Map ? selectedPortion['label']?.toString().trim() : null;
    if (portionLabel != null && portionLabel.isNotEmpty) {
      parts.add('Portion: $portionLabel');
    }

    final selectedPreferences = item['selectedPreferences'];
    if (selectedPreferences is List) {
      final labels = selectedPreferences
          .whereType<Map>()
          .map((entry) => entry['optionLabel']?.toString().trim() ?? entry['label']?.toString().trim() ?? '')
          .where((entry) => entry.isNotEmpty)
          .toList(growable: false);

      if (labels.isNotEmpty) {
        if (labels.length > 2) {
          final visible = labels.take(2).join(', ');
          final remaining = labels.length - 2;
          parts.add('Prefs: $visible +$remaining');
        } else {
          parts.add('Prefs: ${labels.join(', ')}');
        }
      }
    }

    final note = item['itemNote']?.toString().trim();
    if (note != null && note.isNotEmpty) {
      parts.add('Note');
    }

    if (parts.isEmpty) return null;
    return parts.join(' • ');
  }

  double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  int _toInt(dynamic value, {int fallback = 0}) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  String _formatCurrency(double value) => 'GHS ${value.toStringAsFixed(2)}';

  void _checkDeliveryStatus(TrackingProvider provider) {
    final currentStatus = provider.trackingData?.status;

    if (currentStatus == 'delivered' && _previousStatus != 'delivered' && !_hasShownSuccessScreen) {
      _hasShownSuccessScreen = true;

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => DeliverySuccessScreen(
            orderId: widget.orderId,
            onComplete: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => RatingOnboarding(
                    orderId: widget.orderId,
                    riderName: provider.trackingData?.rider?.name,
                    riderImage: provider.trackingData?.rider?.profileImage,
                    vendorName: _vendorName,
                    vendorLogo: _vendorLogo,
                  ),
                ),
              );
            },
          ),
        ),
      );
    }

    _previousStatus = currentStatus;
  }

  @override
  void dispose() {
    _trackingProvider?.dispose();
    disposeTrackingServices();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final Size size = MediaQuery.sizeOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FutureBuilder<TrackingProvider>(
      future: _initFuture,
      builder: (context, snapshot) {
        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            backgroundColor: colors.backgroundPrimary,
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SpinKitCubeGrid(color: colors.accentOrange, size: 35),
                  SizedBox(height: 16.h),
                  Text(
                    'Connecting to tracking...',
                    style: TextStyle(color: colors.textPrimary, fontSize: 16.sp),
                  ),
                ],
              ),
            ),
          );
        }

        // Error state
        if (snapshot.hasError) {
          return Scaffold(
            backgroundColor: colors.backgroundPrimary,
            appBar: AppBar(
              backgroundColor: colors.backgroundPrimary,
              leading: IconButton(
                icon: Icon(Icons.arrow_back, color: colors.textPrimary),
                onPressed: () => context.pop(),
              ),
            ),
            body: Center(
              child: Padding(
                padding: EdgeInsets.all(20.w),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 64.sp, color: colors.error),
                    SizedBox(height: 16.h),
                    Text(
                      'Failed to initialize tracking',
                      style: TextStyle(color: colors.textPrimary, fontSize: 18.sp, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      snapshot.error.toString(),
                      style: TextStyle(color: colors.textSecondary, fontSize: 14.sp),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 24.h),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _initFuture = _initializeTrackingServices();
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors.accentOrange,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // Success - provider is ready
        final provider = snapshot.data!;

        return ChangeNotifierProvider<TrackingProvider>.value(
          value: provider,
          child: Consumer<TrackingProvider>(
            builder: (context, provider, child) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _checkDeliveryStatus(provider);
              });

              // Waiting for rider state
              if (provider.isWaitingForRider && provider.trackingData == null) {
                return Scaffold(
                  backgroundColor: colors.backgroundPrimary,
                  appBar: AppBar(
                    backgroundColor: colors.backgroundPrimary,
                    leading: IconButton(
                      icon: Icon(Icons.arrow_back, color: colors.textPrimary),
                      onPressed: () => context.pop(),
                    ),
                    title: Text(
                      'Order Tracking',
                      style: TextStyle(color: colors.textPrimary, fontSize: 18.sp, fontWeight: FontWeight.w600),
                    ),
                  ),
                  body: Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.w),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Animated searching icon
                          Container(
                            width: 100.w,
                            height: 100.w,
                            decoration: BoxDecoration(
                              color: colors.accentOrange.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.delivery_dining_outlined, size: 50.sp, color: colors.accentOrange),
                          ),
                          SizedBox(height: 24.h),
                          Text(
                            'Looking for a rider',
                            style: TextStyle(color: colors.textPrimary, fontSize: 22.sp, fontWeight: FontWeight.w700),
                          ),
                          SizedBox(height: 12.h),
                          Text(
                            'We\'re finding the best available rider for your order. This usually takes 1-3 minutes.',
                            style: TextStyle(color: colors.textSecondary, fontSize: 14.sp),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 32.h),
                          // Progress indicator
                          SizedBox(
                            width: 200.w,
                            child: LinearProgressIndicator(
                              backgroundColor: colors.border,
                              valueColor: AlwaysStoppedAnimation<Color>(colors.accentOrange),
                            ),
                          ),
                          SizedBox(height: 32.h),
                          TextButton.icon(
                            onPressed: () => provider.refreshTracking(),
                            icon: Icon(Icons.refresh, color: colors.accentOrange),
                            label: Text(
                              'Refresh',
                              style: TextStyle(color: colors.accentOrange, fontSize: 16.sp),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              // Error state from provider (runtime errors)
              if (provider.error != null && provider.trackingData == null) {
                return Scaffold(
                  backgroundColor: colors.backgroundPrimary,
                  appBar: AppBar(
                    backgroundColor: colors.backgroundPrimary,
                    leading: IconButton(
                      icon: Icon(Icons.arrow_back, color: colors.textPrimary),
                      onPressed: () => context.pop(),
                    ),
                  ),
                  body: Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.w),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline, size: 64.sp, color: colors.error),
                          SizedBox(height: 16.h),
                          Text(
                            'Failed to load tracking',
                            style: TextStyle(color: colors.textPrimary, fontSize: 18.sp, fontWeight: FontWeight.w700),
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            provider.error!,
                            style: TextStyle(color: colors.textSecondary, fontSize: 14.sp),
                            textAlign: TextAlign.center,
                          ),
                          SizedBox(height: 24.h),
                          ElevatedButton(
                            onPressed: () => provider.refreshTracking(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colors.accentOrange,
                              padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 12.h),
                            ),
                            child: Text(
                              'Retry',
                              style: TextStyle(color: Colors.white, fontSize: 16.sp),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              // Main tracking UI
              final activeStep = provider.trackingData?.activeStep ?? 0;

              return _buildTrackingUI(context, provider, colors, size, isDark, activeStep);
            },
          ),
        );
      },
    );
  }

  Widget _buildTrackingUI(
    BuildContext context,
    TrackingProvider provider,
    AppColorsExtension colors,
    Size size,
    bool isDark,
    int activeStep,
  ) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      extendBody: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.light : Brightness.dark,
          systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        ),
        automaticallyImplyLeading: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        leadingWidth: 72,
        centerTitle: true,
        title: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8.w),
          child: Row(
            children: [
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: colors.backgroundPrimary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: isDark ? Colors.black.withAlpha(20) : Colors.black.withAlpha(35),
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
            ],
          ),
        ),
        actionsPadding: EdgeInsets.only(right: 18.w),
        actions: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: colors.backgroundPrimary,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.black.withAlpha(20) : Colors.black.withAlpha(35),
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
                    Assets.icons.headsetHelp,
                    package: 'grab_go_shared',
                    colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Google Map
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: provider.trackingData?.currentLocation?.toLatLng() ?? const LatLng(5.6037, -0.1870),
                zoom: 14,
              ),
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
              markers: provider.markers,
              polylines: provider.polylines,
              circles: provider.circles,
              onMapCreated: (GoogleMapController controller) {
                provider.setMapController(controller);
              },
              onCameraMoveStarted: provider.onMapCameraMoveStarted,
              onCameraIdle: provider.onMapCameraIdle,
              style: GrabGoMapStyles.forBrightness(Theme.of(context).brightness),
            ),
          ),

          Positioned(
            top: MediaQuery.of(context).padding.top + 12.h,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: _buildTrackingHealthBanner(colors: colors, provider: provider, isDark: isDark),
              ),
            ),
          ),

          // Draggable Bottom Sheet
          DraggableScrollableSheet(
            initialChildSize: 0.38,
            minChildSize: 0.38,
            maxChildSize: 0.85,
            snap: true,
            snapSizes: const [0.38, 0.6, 0.85],
            builder: (BuildContext context, ScrollController scrollController) {
              return NotificationListener<DraggableScrollableNotification>(
                onNotification: (notification) {
                  setState(() {
                    _isSheetCollapsed = notification.extent <= 0.4;
                  });
                  return true;
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: colors.accentOrange,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(KBorderSize.border),
                      topRight: Radius.circular(KBorderSize.border),
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: colors.accentOrange,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(KBorderSize.border),
                            topRight: Radius.circular(KBorderSize.border),
                          ),
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              ClipOval(
                                child: Container(
                                  height: 50.h,
                                  width: 50.w,
                                  decoration: BoxDecoration(shape: BoxShape.circle, color: colors.backgroundPrimary),
                                  child: provider.trackingData?.rider?.profileImage != null
                                      ? Image.network(
                                          provider.trackingData!.rider!.profileImage!,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => Padding(
                                            padding: EdgeInsets.all(12.r),
                                            child: SvgPicture.asset(
                                              Assets.icons.user,
                                              package: "grab_go_shared",
                                              colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                                            ),
                                          ),
                                        )
                                      : Padding(
                                          padding: EdgeInsets.all(12.r),
                                          child: SvgPicture.asset(
                                            Assets.icons.user,
                                            package: "grab_go_shared",
                                            colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                                          ),
                                        ),
                                ),
                              ),
                              SizedBox(width: 16.w),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      provider.trackingData?.rider?.name ?? "Rider",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.w700,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    SizedBox(height: 2.h),
                                    Row(
                                      children: [
                                        SvgPicture.asset(
                                          Assets.icons.starSolid,
                                          package: "grab_go_shared",
                                          height: 14.h,
                                          width: 14.w,
                                          colorFilter: const ColorFilter.mode(Colors.yellow, BlendMode.srcIn),
                                        ),
                                        SizedBox(width: 6.w),
                                        Text(
                                          "${provider.trackingData?.rider?.formattedRating ?? "N/A"} rated rider",
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 13.sp,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Row(
                                children: [
                                  _buildActionButton(
                                    icon: Assets.icons.chatBubbleSolid,
                                    colors: colors,
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (context) => DeliverySuccessScreen(
                                            orderId: widget.orderId,
                                            onComplete: () {
                                              Navigator.of(context).pushReplacement(
                                                MaterialPageRoute(
                                                  builder: (context) => RatingOnboarding(
                                                    orderId: widget.orderId,
                                                    riderName: provider.trackingData?.rider?.name,
                                                    riderImage: provider.trackingData?.rider?.profileImage,
                                                    vendorName: _vendorName,
                                                    vendorLogo: _vendorLogo,
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                  SizedBox(width: 12.w),
                                  _buildActionButton(
                                    icon: Assets.icons.phoneSolid,
                                    colors: colors,
                                    onTap: () async {
                                      final riderId = provider.trackingData?.rider?.id;
                                      if (riderId == null || riderId.isEmpty) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: const Text('Rider information not available'),
                                            backgroundColor: colors.error,
                                          ),
                                        );
                                        return;
                                      }

                                      // Navigate to call screen
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (context) => CallScreen(
                                            otherUserId: riderId,
                                            otherUserName: provider.trackingData?.rider?.name ?? 'Rider',
                                            otherUserAvatar: provider.trackingData?.rider?.profileImage,
                                            orderId: widget.orderId,
                                            isIncoming: false,
                                          ),
                                          fullscreenDialog: true,
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Scrollable White Section
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: colors.backgroundPrimary,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(KBorderSize.border),
                              topRight: Radius.circular(KBorderSize.border),
                            ),
                          ),
                          child: SafeArea(
                            top: false,
                            child: ListView(
                              controller: scrollController,
                              padding: EdgeInsets.zero,
                              children: [
                                // Drag Handle on White Background
                                Center(
                                  child: Container(
                                    width: 40.w,
                                    height: 4.h,
                                    margin: EdgeInsets.only(top: 12.h, bottom: 12.h),
                                    decoration: BoxDecoration(
                                      color: colors.textSecondary.withValues(alpha: 0.3),
                                      borderRadius: BorderRadius.circular(2.r),
                                    ),
                                  ),
                                ),

                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 20.w),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Status Text
                                      Text(
                                        provider.trackingData?.statusText ?? "Preparing Order",
                                        style: TextStyle(
                                          color: colors.textPrimary,
                                          fontSize: 20.sp,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      SizedBox(height: 4.h),
                                      Text(
                                        _getStatusDescription(provider.trackingData?.status),
                                        style: TextStyle(
                                          color: colors.textSecondary,
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.w400,
                                        ),
                                      ),
                                      SizedBox(height: 20.h),

                                      // Stepper
                                      EasyStepper(
                                        activeStep: activeStep,
                                        stepRadius: 25.r,
                                        enableStepTapping: false,
                                        showTitle: true,
                                        disableScroll: true,
                                        lineStyle: LineStyle(
                                          lineLength: 60.w,
                                          lineSpace: 0,
                                          lineThickness: 4,
                                          lineType: LineType.normal,
                                          defaultLineColor: colors.inputBorder,
                                          finishedLineColor: colors.accentOrange,
                                        ),
                                        showStepBorder: false,
                                        unreachedStepBackgroundColor: colors.inputBorder,
                                        activeStepBackgroundColor: colors.accentOrange,
                                        finishedStepBackgroundColor: colors.accentOrange,
                                        stepShape: StepShape.circle,
                                        showLoadingAnimation: false,
                                        steps: [
                                          EasyStep(
                                            customTitle: Text(
                                              "Accepted",
                                              style: TextStyle(
                                                color: colors.textPrimary,
                                                fontSize: 14.sp,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            customStep: Container(
                                              width: 50.w,
                                              height: 50.h,
                                              decoration: BoxDecoration(
                                                color: activeStep >= 0 ? colors.accentOrange : colors.inputBorder,
                                                shape: BoxShape.circle,
                                              ),
                                              child: Center(
                                                child: SvgPicture.asset(
                                                  Assets.icons.check,
                                                  package: 'grab_go_shared',
                                                  width: 24.w,
                                                  height: 24.h,
                                                  colorFilter: ColorFilter.mode(
                                                    activeStep >= 0 ? Colors.white : colors.textSecondary,
                                                    BlendMode.srcIn,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          EasyStep(
                                            customTitle: Text(
                                              "Preparing",
                                              style: TextStyle(
                                                color: colors.textPrimary,
                                                fontSize: 14.sp,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            customStep: Container(
                                              width: 50.w,
                                              height: 50.h,
                                              decoration: BoxDecoration(
                                                color: activeStep >= 1 ? colors.accentOrange : colors.inputBorder,
                                                shape: BoxShape.circle,
                                              ),
                                              child: Center(
                                                child: SvgPicture.asset(
                                                  Assets.icons.store,
                                                  package: 'grab_go_shared',
                                                  width: 24.w,
                                                  height: 24.h,
                                                  colorFilter: ColorFilter.mode(
                                                    activeStep >= 1 ? Colors.white : colors.textSecondary,
                                                    BlendMode.srcIn,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          EasyStep(
                                            customTitle: Text(
                                              "On The Way",
                                              style: TextStyle(
                                                color: colors.textPrimary,
                                                fontSize: 14.sp,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            customStep: Container(
                                              width: 50.w,
                                              height: 50.h,
                                              decoration: BoxDecoration(
                                                color: activeStep >= 2 ? colors.accentOrange : colors.inputBorder,
                                                shape: BoxShape.circle,
                                              ),
                                              child: Center(
                                                child: SvgPicture.asset(
                                                  Assets.icons.deliveryTruck,
                                                  package: 'grab_go_shared',
                                                  height: 24.h,
                                                  width: 24.w,
                                                  colorFilter: ColorFilter.mode(
                                                    activeStep >= 2 ? Colors.white : colors.textSecondary,
                                                    BlendMode.srcIn,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          EasyStep(
                                            customTitle: Text(
                                              "Delivered",
                                              style: TextStyle(
                                                color: colors.textPrimary,
                                                fontSize: 14.sp,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            customStep: Container(
                                              width: 50.w,
                                              height: 50.h,
                                              decoration: BoxDecoration(
                                                color: activeStep >= 3 ? colors.accentOrange : colors.inputBorder,
                                                shape: BoxShape.circle,
                                              ),
                                              child: Center(
                                                child: Icon(
                                                  Icons.handshake,
                                                  color: activeStep >= 3 ? Colors.white : colors.textSecondary,
                                                  size: 24.sp,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 20.h),

                                      // ETA and Distance Row
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Row(
                                              children: [
                                                SvgPicture.asset(
                                                  Assets.icons.timer,
                                                  package: 'grab_go_shared',
                                                  width: 18.w,
                                                  height: 18.h,
                                                  colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                                                ),
                                                SizedBox(width: 6.w),
                                                Flexible(
                                                  child: RichText(
                                                    text: TextSpan(
                                                      text: "Delivery:  ",
                                                      style: TextStyle(
                                                        fontFamily: "Lato",
                                                        package: 'grab_go_shared',
                                                        color: colors.textSecondary,
                                                        fontSize: 12.sp,
                                                      ),
                                                      children: [
                                                        TextSpan(
                                                          text: provider.trackingData?.formattedEta ?? "Calculating...",
                                                          style: TextStyle(
                                                            fontFamily: "Lato",
                                                            package: 'grab_go_shared',
                                                            fontWeight: FontWeight.w800,
                                                            color: colors.textPrimary,
                                                            fontSize: 13.sp,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Expanded(
                                            child: Row(
                                              children: [
                                                SvgPicture.asset(
                                                  Assets.icons.mapPin,
                                                  package: 'grab_go_shared',
                                                  width: 18.w,
                                                  height: 18.h,
                                                  colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                                                ),
                                                SizedBox(width: 6.w),
                                                Flexible(
                                                  child: RichText(
                                                    text: TextSpan(
                                                      text: "Distance:  ",
                                                      style: TextStyle(
                                                        fontFamily: "Lato",
                                                        package: 'grab_go_shared',
                                                        color: colors.textSecondary,
                                                        fontSize: 12.sp,
                                                      ),
                                                      children: [
                                                        TextSpan(
                                                          text: "${provider.trackingData?.distanceInKm ?? '0.0'} km",
                                                          style: TextStyle(
                                                            fontFamily: "Lato",
                                                            package: 'grab_go_shared',
                                                            fontWeight: FontWeight.w800,
                                                            color: colors.textPrimary,
                                                            fontSize: 13.sp,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),

                                      SizedBox(height: 24.h),
                                      DottedLine(
                                        dashLength: 6,
                                        dashGapLength: 4,
                                        lineThickness: 1,
                                        dashColor: colors.textSecondary.withAlpha(50),
                                      ),
                                      SizedBox(height: 20.h),

                                      // Order Details Section
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            "Order Details",
                                            style: TextStyle(
                                              color: colors.textPrimary,
                                              fontSize: 18.sp,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          Container(
                                            height: 38.h,
                                            width: 38.w,
                                            decoration: BoxDecoration(
                                              color: colors.backgroundSecondary,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                onTap: () {},
                                                customBorder: const CircleBorder(),
                                                child: Padding(
                                                  padding: EdgeInsets.all(10.r),
                                                  child: SvgPicture.asset(
                                                    Assets.icons.headsetHelp,
                                                    package: 'grab_go_shared',
                                                    colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        "Order #${widget.orderId}",
                                        style: TextStyle(
                                          color: colors.textSecondary,
                                          fontSize: 12.sp,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      SizedBox(height: 16.h),

                                      // Items Section
                                      Row(
                                        children: [
                                          SvgPicture.asset(
                                            Assets.icons.squareMenu,
                                            package: 'grab_go_shared',
                                            height: 18.h,
                                            width: 18.w,
                                            colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                                          ),
                                          SizedBox(width: 12.w),
                                          Text(
                                            "Items",
                                            style: TextStyle(
                                              color: colors.textPrimary,
                                              fontSize: 16.sp,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 12.h),

                                      Container(
                                        padding: EdgeInsets.all(16.r),
                                        decoration: BoxDecoration(
                                          color: colors.backgroundSecondary,
                                          borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
                                        ),
                                        child: Column(
                                          children: _orderItems.isEmpty
                                              ? [
                                                  Text(
                                                    "Item details unavailable right now.",
                                                    style: TextStyle(
                                                      color: colors.textSecondary,
                                                      fontSize: 12.sp,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ]
                                              : [
                                                  for (int index = 0; index < _orderItems.length; index++) ...[
                                                    _buildOrderItem(
                                                      colors: colors,
                                                      itemName: _orderItems[index].name,
                                                      quantity: _orderItems[index].quantity,
                                                      price: _orderItems[index].priceLabel,
                                                      customizationSummary: _orderItems[index].customizationSummary,
                                                    ),
                                                    if (index < _orderItems.length - 1)
                                                      Divider(
                                                        color: colors.inputBorder.withValues(alpha: 0.3),
                                                        height: 24.h,
                                                      ),
                                                  ],
                                                ],
                                        ),
                                      ),

                                      SizedBox(height: 20.h),

                                      // Delivery location section
                                      Row(
                                        children: [
                                          SvgPicture.asset(
                                            Assets.icons.mapPin,
                                            package: 'grab_go_shared',
                                            height: 18.h,
                                            width: 18.w,
                                            colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                                          ),
                                          SizedBox(width: 12.w),
                                          Text(
                                            "Delivery Location",
                                            style: TextStyle(
                                              color: colors.textPrimary,
                                              fontSize: 16.sp,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 12.h),

                                      Container(
                                        padding: EdgeInsets.all(16.r),
                                        decoration: BoxDecoration(
                                          color: colors.backgroundSecondary,
                                          borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
                                        ),
                                        child: Column(
                                          children: [
                                            Row(
                                              children: [
                                                Container(
                                                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                                  decoration: BoxDecoration(
                                                    color: colors.accentOrange.withValues(alpha: 0.15),
                                                    borderRadius: BorderRadius.circular(6.r),
                                                  ),
                                                  child: Text(
                                                    "Home",
                                                    style: TextStyle(
                                                      fontSize: 12.sp,
                                                      fontWeight: FontWeight.w700,
                                                      color: colors.accentOrange,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            SizedBox(height: 8.h),
                                            Row(
                                              children: [
                                                SvgPicture.asset(
                                                  Assets.icons.phone,
                                                  package: 'grab_go_shared',
                                                  height: 12.h,
                                                  width: 12.w,
                                                  colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                                                ),
                                                SizedBox(width: 6.w),
                                                Text(
                                                  "+233 53 369 97662",
                                                  style: TextStyle(
                                                    fontSize: 13.sp,
                                                    color: colors.textPrimary,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            SizedBox(height: 4.h),
                                            Row(
                                              children: [
                                                SvgPicture.asset(
                                                  Assets.icons.mapPin,
                                                  package: 'grab_go_shared',
                                                  height: 12.h,
                                                  width: 12.w,
                                                  colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                                                ),
                                                SizedBox(width: 6.w),
                                                Expanded(
                                                  child: Text(
                                                    "Madina, Adenta",
                                                    style: TextStyle(
                                                      fontSize: 13.sp,
                                                      color: colors.textPrimary,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),

                                      SizedBox(height: 20.h),

                                      // Delivery instructions
                                      Row(
                                        children: [
                                          SvgPicture.asset(
                                            Assets.icons.deliveryTruck,
                                            package: 'grab_go_shared',
                                            height: 18.h,
                                            width: 18.w,
                                            colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                                          ),
                                          SizedBox(width: 12.w),
                                          Text(
                                            "Delivery Instructions",
                                            style: TextStyle(
                                              color: colors.textPrimary,
                                              fontSize: 16.sp,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 12.h),

                                      Container(
                                        width: double.infinity,
                                        padding: EdgeInsets.all(16.r),
                                        decoration: BoxDecoration(
                                          color: colors.backgroundSecondary,
                                          borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
                                        ),
                                        child: Text(
                                          "Call me when you arrive.",
                                          style: TextStyle(
                                            fontSize: 13.sp,
                                            color: colors.textPrimary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      SizedBox(height: 20.h),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          Positioned(
            bottom: size.height * 0.40,
            right: 20.w,
            child: AnimatedOpacity(
              opacity: _isSheetCollapsed ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: IgnorePointer(
                ignoring: !_isSheetCollapsed,
                child: Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: colors.backgroundPrimary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: isDark ? Colors.black.withAlpha(20) : Colors.black.withAlpha(35),
                        spreadRadius: 0,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => provider.reCenterCamera(),
                      customBorder: const CircleBorder(),
                      child: Padding(
                        padding: EdgeInsets.all(8.r),
                        child: SvgPicture.asset(
                          Assets.icons.crosshair,
                          package: 'grab_go_shared',
                          colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackingHealthBanner({
    required AppColorsExtension colors,
    required TrackingProvider provider,
    required bool isDark,
  }) {
    final health = provider.connectionHealth;
    final color = _trackingHealthColor(colors, health);
    final phaseLabel = _mapPhaseLabel(provider.trackingData?.status);
    final statusLabel = _trackingHealthStatusLabel(provider);
    final maxWidth = MediaQuery.of(context).size.width * 0.84;

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
        decoration: BoxDecoration(
          color: colors.backgroundPrimary,
          borderRadius: BorderRadius.circular(999.r),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withAlpha(30) : Colors.black.withAlpha(35),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '$statusLabel • $phaseLabel',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: color, fontSize: 10.sp, fontWeight: FontWeight.w700, letterSpacing: 0.3),
            ),
          ],
        ),
      ),
    );
  }

  Color _trackingHealthColor(AppColorsExtension colors, TrackingConnectionHealth health) {
    switch (health) {
      case TrackingConnectionHealth.live:
        return colors.accentGreen;
      case TrackingConnectionHealth.degraded:
        return colors.accentOrange;
      case TrackingConnectionHealth.offline:
        return colors.error;
    }
  }

  String _trackingHealthStatusLabel(TrackingProvider provider) {
    switch (provider.connectionHealth) {
      case TrackingConnectionHealth.live:
        return 'LIVE UPDATES';
      case TrackingConnectionHealth.degraded:
        if (provider.isFallbackPollingActive) {
          return 'SYNCING';
        }
        return 'RECONNECTING';
      case TrackingConnectionHealth.offline:
        return 'OFFLINE';
    }
  }

  String _mapPhaseLabel(String? status) {
    switch (status?.toLowerCase()) {
      case 'preparing':
      case 'confirmed':
      case 'ready':
        return 'PREPARING';
      case 'picked_up':
      case 'in_transit':
      case 'nearby':
        return 'ON THE WAY';
      case 'delivered':
        return 'DELIVERED';
      default:
        return 'TRACKING';
    }
  }

  /// Get dynamic status description based on order status
  String _getStatusDescription(String? status) {
    switch (status?.toLowerCase()) {
      case 'preparing':
        return 'Your order is being prepared at the store.';
      case 'picked_up':
        return 'The rider has picked up your order and is heading to you.';
      case 'in_transit':
        return 'The rider is on the way to your location.';
      case 'nearby':
        return 'The rider is almost at your location!';
      case 'delivered':
        return 'Your order has been delivered. Enjoy!';
      default:
        return 'Your order is being processed.';
    }
  }

  Widget _buildActionButton({required String icon, required AppColorsExtension colors, required VoidCallback onTap}) {
    return Container(
      height: 40.h,
      width: 40.w,
      decoration: BoxDecoration(color: colors.backgroundPrimary.withValues(alpha: 0.2), shape: BoxShape.circle),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: EdgeInsets.all(10.r),
            child: SvgPicture.asset(
              icon,
              package: 'grab_go_shared',
              colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOrderItem({
    required AppColorsExtension colors,
    required String itemName,
    required int quantity,
    required String price,
    String? customizationSummary,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: colors.accentOrange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6.r),
          ),
          child: Text(
            "${quantity}x",
            style: TextStyle(color: colors.accentOrange, fontSize: 12.sp, fontWeight: FontWeight.w700),
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                itemName,
                style: TextStyle(color: colors.textPrimary, fontSize: 13.sp, fontWeight: FontWeight.w500),
              ),
              if (customizationSummary != null && customizationSummary.trim().isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(top: 2.h),
                  child: Text(
                    customizationSummary,
                    style: TextStyle(color: colors.textSecondary, fontSize: 11.sp, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
        Text(
          price,
          style: TextStyle(color: colors.textPrimary, fontSize: 13.sp, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _TrackedOrderItem {
  final String name;
  final int quantity;
  final String priceLabel;
  final String? customizationSummary;

  const _TrackedOrderItem({
    required this.name,
    required this.quantity,
    required this.priceLabel,
    this.customizationSummary,
  });
}

class _VendorMeta {
  final String? name;
  final String? logo;

  const _VendorMeta({this.name, this.logo});
}
