import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_svg/svg.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:grab_go_rider/features/orders/service/available_order_dto.dart';
import 'package:grab_go_rider/features/orders/service/available_orders_service.dart';
import 'package:grab_go_rider/features/orders/widgets/available_order_details_bottom_sheet.dart';
import 'package:grab_go_rider/features/orders/widgets/order_detail_bottom_sheet.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_shared/shared/widgets/custom_map_markers.dart';

class AvailableOrdersMap extends StatefulWidget {
  const AvailableOrdersMap({super.key});

  @override
  State<AvailableOrdersMap> createState() => _AvailableOrdersMapState();
}

class _AvailableOrdersMapState extends State<AvailableOrdersMap> {
  final AvailableOrdersService _service = AvailableOrdersService();

  GoogleMapController? _mapController;

  List<AvailableOrderDto> _availableOrders = [];
  bool _isLoading = true;
  String? _errorMessage;

  Position? _currentPosition;
  StreamSubscription<Position>? _positionSubscription;

  Set<Marker> _markers = {};
  BitmapDescriptor? _riderLocationMarker;
  final Map<String, BitmapDescriptor> _orderMarkerCache = {};

  String? _closestOrderId;

  static const LatLng _defaultPosition = LatLng(5.6037, -0.1870);

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _initializeMap() async {
    await _loadRiderMarker();

    await _getCurrentLocation();

    await _loadOrders();

    _startLocationUpdates();
  }

  Future<void> _loadRiderMarker() async {
    try {
      _riderLocationMarker = await CustomMapMarkers.createRiderLocationMarker(
        primaryColor: const Color(0xFF10B981),
      );
    } catch (e) {
      debugPrint('Error loading rider marker: $e');
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
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
        debugPrint('Location permission permanently denied');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;
      setState(() {
        _currentPosition = position;
      });

      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(position.latitude, position.longitude),
          14,
        ),
      );
    } catch (e) {
      debugPrint('Error getting current location: $e');
    }
  }

  void _startLocationUpdates() {
    _positionSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 20,
          ),
        ).listen(
          (Position position) {
            if (!mounted) return;
            setState(() {
              _currentPosition = position;
            });
            _updateMarkers();
          },
          onError: (error) {
            debugPrint('Location stream error: $error');
          },
        );
  }

  Future<void> _loadOrders() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await _service.getAvailableOrders(
        lat: _currentPosition?.latitude,
        lon: _currentPosition?.longitude,
      );

      if (!mounted) return;

      final orders = result['orders'] as List<AvailableOrderDto>;

      String? closestId;
      double minDistance = double.infinity;
      for (final order in orders) {
        final dist =
            order.distanceToPickup ?? order.distance ?? double.infinity;
        if (dist < minDistance) {
          minDistance = dist;
          closestId = order.id;
        }
      }

      setState(() {
        _availableOrders = orders;
        _closestOrderId = closestId;
        _isLoading = false;
      });

      await _updateMarkers();

      _fitCameraToMarkers();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load orders: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _updateMarkers() async {
    if (!mounted) return;

    final Set<Marker> markers = {};
    final colors = context.appColors;

    if (_currentPosition != null && _riderLocationMarker != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('rider_location'),
          position: LatLng(
            _currentPosition!.latitude,
            _currentPosition!.longitude,
          ),
          icon: _riderLocationMarker!,
          anchor: const Offset(0.5, 0.5),
          zIndexInt: 100,
        ),
      );
    }

    for (final order in _availableOrders) {
      if (order.pickupLatitude == null || order.pickupLongitude == null)
        continue;

      final isClosest = order.id == _closestOrderId;
      final cacheKey = '${order.id}_${isClosest}_${order.itemCount}';

      BitmapDescriptor markerIcon;
      if (_orderMarkerCache.containsKey(cacheKey)) {
        markerIcon = _orderMarkerCache[cacheKey]!;
      } else {
        try {
          markerIcon = await CustomMapMarkers.createOrderPinMarker(
            primaryColor: const Color(0xFF6B7280),
            highlightColor: colors.accentGreen,
            isHighlighted: isClosest,
            itemCount: order.itemCount,
          );
          _orderMarkerCache[cacheKey] = markerIcon;
        } catch (e) {
          debugPrint('Error creating marker for order ${order.id}: $e');
          markerIcon = BitmapDescriptor.defaultMarker;
        }
      }

      markers.add(
        Marker(
          markerId: MarkerId('order_${order.id}'),
          position: LatLng(order.pickupLatitude!, order.pickupLongitude!),
          icon: markerIcon,
          anchor: const Offset(0.5, 1.0),
          zIndexInt: isClosest ? 50 : 10,
          onTap: () => _onOrderMarkerTapped(order),
        ),
      );
    }

    if (!mounted) return;
    setState(() {
      _markers = markers;
    });
  }

  void _fitCameraToMarkers() {
    if (_markers.isEmpty || _mapController == null) return;

    if (_markers.length == 1) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_markers.first.position, 15),
      );
      return;
    }

    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLng = double.infinity;
    double maxLng = -double.infinity;

    for (final marker in _markers) {
      final lat = marker.position.latitude;
      final lng = marker.position.longitude;
      minLat = lat < minLat ? lat : minLat;
      maxLat = lat > maxLat ? lat : maxLat;
      minLng = lng < minLng ? lng : minLng;
      maxLng = lng > maxLng ? lng : maxLng;
    }

    if (minLat == maxLat && minLng == maxLng) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(minLat, minLng), 15),
      );
      return;
    }

    const padding = 0.002;
    final bounds = LatLngBounds(
      southwest: LatLng(minLat - padding, minLng - padding),
      northeast: LatLng(maxLat + padding, maxLng + padding),
    );

    _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80.w));
  }

  void _onOrderMarkerTapped(AvailableOrderDto order) {
    final isClosest = order.id == _closestOrderId;

    OrderDetailBottomSheet.show(
      context: context,
      order: order,
      isClosest: isClosest,
      onAccept: () {
        _acceptOrder(order);
      },
      onViewDetails: () {
        AvailableOrderDetailsBottomSheet.show(
          context: context,
          order: order,
          onAccept: () => _acceptOrder(order),
        );
      },
    );
  }

  Future<void> _acceptOrder(AvailableOrderDto order) async {
    final colors = context.appColors;
    try {
      final result = await _service.acceptOrder(order.id);
      if (!mounted) return;

      if (result.isSuccess && result.order != null) {
        final acceptedOrder = result.order!;
        Navigator.of(context).pop();
        context.push(
          '/orderConfirmation',
          extra: {
            'orderId': acceptedOrder.id,
            'orderNumber': acceptedOrder.orderNumber,
            'orderStatus': acceptedOrder.orderStatus,
            'orderInstructions': acceptedOrder.notes,
            'customerName': acceptedOrder.customerName,
            'customerAddress': acceptedOrder.customerAddress,
            'customerPhone': acceptedOrder.customerPhone,
            'customerPhoto': acceptedOrder.customerPhoto,
            'restaurantName': acceptedOrder.restaurantName,
            'restaurantAddress': acceptedOrder.restaurantAddress,
            'restaurantLogo': acceptedOrder.restaurantLogo,
            'orderTotal': 'GHS ${acceptedOrder.totalAmount.toStringAsFixed(2)}',
            'orderItems': acceptedOrder.orderItems,
            'specialInstructions': acceptedOrder.notes,
            'customerId': acceptedOrder.customerId,
            'riderId': acceptedOrder.riderId,
            'riderEarnings': acceptedOrder.riderEarnings,
            'pickupLatitude': acceptedOrder.pickupLatitude,
            'pickupLongitude': acceptedOrder.pickupLongitude,
            'destinationLatitude': acceptedOrder.destinationLatitude,
            'destinationLongitude': acceptedOrder.destinationLongitude,
            'isGiftOrder': acceptedOrder.isGiftOrder,
            'deliveryVerificationRequired':
                acceptedOrder.deliveryVerificationRequired,
            'giftRecipientName': acceptedOrder.giftRecipientName,
            'giftRecipientPhone': acceptedOrder.giftRecipientPhone,
            'deliveryVerificationMethod':
                acceptedOrder.deliveryVerificationMethod,
          },
        );

        await _loadOrders();
      } else if (result.isReserved) {
        Navigator.of(context).pop();
        await _loadOrders();
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: colors.backgroundPrimary,
            title: Row(
              children: [
                Icon(Icons.schedule, color: colors.accentOrange),
                SizedBox(width: 8),
                Text(
                  'Order Reserved',
                  style: TextStyle(color: colors.textPrimary),
                ),
              ],
            ),
            content: Text(
              '${result.errorMessage}\n\nThe order has been removed from your map. New orders will appear shortly.',
              style: TextStyle(color: colors.textSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('OK', style: TextStyle(color: colors.accentGreen)),
              ),
            ],
          ),
        );
      } else {
        Navigator.of(context).pop();
        AppToastMessage.show(
          context: context,
          showIcon: false,
          backgroundColor: colors.accentGreen,
          gravity: ToastGravity.CENTER,
          radius: KBorderSize.borderRadius4,
          message: result.errorMessage ?? "Order is no longer available.",
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      AppToastMessage.show(
        context: context,
        showIcon: false,
        backgroundColor: colors.error,
        gravity: ToastGravity.CENTER,
        radius: KBorderSize.borderRadius4,
        message: "Failed to accept order: $e",
      );
    }
  }

  void _centerOnRider() {
    if (_currentPosition == null || _mapController == null) return;
    _mapController!.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        15,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
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
        extendBodyBehindAppBar: true,
        extendBody: true,
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: Colors.transparent,
            statusBarIconBrightness: isDark
                ? Brightness.light
                : Brightness.dark,
            statusBarBrightness: isDark ? Brightness.light : Brightness.dark,
            systemNavigationBarIconBrightness: isDark
                ? Brightness.light
                : Brightness.dark,
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
                  height: 44.h,
                  width: 44.w,
                  decoration: BoxDecoration(
                    color: colors.backgroundPrimary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: isDark
                            ? Colors.black.withAlpha(20)
                            : Colors.black.withAlpha(5),
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
        ),
        body: Stack(
          children: [
            // Google Map
            Positioned.fill(
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _currentPosition != null
                      ? LatLng(
                          _currentPosition!.latitude,
                          _currentPosition!.longitude,
                        )
                      : _defaultPosition,
                  zoom: 14,
                ),
                markers: _markers,
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
                style: GrabGoMapStyles.forBrightness(
                  Theme.of(context).brightness,
                ),
                padding: EdgeInsets.only(bottom: 100.h),
                onMapCreated: (controller) {
                  _mapController = controller;
                  Future.delayed(
                    const Duration(milliseconds: 500),
                    _fitCameraToMarkers,
                  );
                },
              ),
            ),

            if (_isLoading)
              Positioned.fill(
                child: Container(
                  color: colors.backgroundPrimary.withValues(alpha: 0.7),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SpinKitCubeGrid(color: colors.accentGreen, size: 35),
                      ],
                    ),
                  ),
                ),
              ),

            // Error state
            if (_errorMessage != null && !_isLoading)
              Positioned(
                left: 16.w,
                right: 16.w,
                top: 100.h,
                child: Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: colors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(
                      color: colors.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: colors.error),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 13.sp,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.refresh, color: colors.accentGreen),
                        onPressed: _loadOrders,
                      ),
                    ],
                  ),
                ),
              ),

            // Map control buttons
            Positioned(
              right: 16.w,
              bottom: 120.h,
              child: Column(
                children: [
                  _buildMapControlButton(
                    icon: Assets.icons.position,
                    onTap: _centerOnRider,
                    colors: colors,
                    isDark: isDark,
                  ),
                  SizedBox(height: 8.h),
                  _buildMapControlButton(
                    icon: Assets.icons.expand,
                    onTap: _fitCameraToMarkers,
                    colors: colors,
                    isDark: isDark,
                  ),
                ],
              ),
            ),

            // Bottom info card
            Positioned(
              left: 16.w,
              right: 16.w,
              bottom: 32.h,
              child: Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: colors.backgroundPrimary,
                  borderRadius: BorderRadius.circular(
                    KBorderSize.borderRadius4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withAlpha(30)
                          : Colors.black.withAlpha(10),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8.r),
                      decoration: BoxDecoration(
                        color: colors.accentGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(
                          KBorderSize.borderRadius4,
                        ),
                      ),
                      child: SvgPicture.asset(
                        Assets.icons.deliveryTruck,
                        package: 'grab_go_shared',
                        width: 24.w,
                        height: 24.w,
                        colorFilter: ColorFilter.mode(
                          colors.accentGreen,
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
                            '${_isLoading ? "..." : _availableOrders.length} orders available',
                            style: TextStyle(
                              color: colors.textPrimary,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (_closestOrderId != null) ...[
                            SizedBox(height: 2.h),
                            Text(
                              'Tap a pin to view order details',
                              style: TextStyle(
                                color: colors.textSecondary,
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          context.push(
                            '/availableOrders',
                            extra: {
                              'orders': _availableOrders,
                              'statistics': null,
                            },
                          );
                        },
                        borderRadius: BorderRadius.circular(
                          KBorderSize.borderRadius4,
                        ),
                        child: Container(
                          padding: EdgeInsets.all(8.r),
                          decoration: BoxDecoration(
                            color: colors.backgroundSecondary,
                            borderRadius: BorderRadius.circular(
                              KBorderSize.borderRadius4,
                            ),
                          ),
                          child: Icon(
                            Icons.list_rounded,
                            color: colors.textPrimary,
                            size: 24.sp,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapControlButton({
    required String icon,
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
          child: Padding(
            padding: EdgeInsets.all(10.r),
            child: SvgPicture.asset(
              icon,
              package: 'grab_go_shared',
              colorFilter: ColorFilter.mode(
                colors.textPrimary,
                BlendMode.srcIn,
              ),
              width: 22.w,
              height: 22.w,
            ),
          ),
        ),
      ),
    );
  }
}
