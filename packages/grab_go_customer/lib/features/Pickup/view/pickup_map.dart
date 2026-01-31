import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_svg/svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:grab_go_customer/features/Pickup/widgets/vendor_details_bottom_sheet.dart';
import 'package:grab_go_customer/features/vendors/model/vendor_model.dart';
import 'package:grab_go_customer/features/vendors/model/vendor_type.dart';
import 'package:grab_go_customer/features/vendors/viewmodel/vendor_provider.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/shared/utils/app_colors_extension.dart';
import 'package:grab_go_shared/shared/utils/map_styles.dart';
import 'package:grab_go_shared/shared/widgets/custom_map_markers.dart';
import 'package:provider/provider.dart';

class PickupMap extends StatefulWidget {
  const PickupMap({super.key});

  @override
  State<PickupMap> createState() => _PickupMapState();
}

class _PickupMapState extends State<PickupMap> {
  GoogleMapController? _mapController;
  List<VendorModel> _vendors = [];
  List<VendorCluster> _clusters = [];
  bool _isLoading = true;
  String? _errorMessage;
  Position? _currentPosition;
  StreamSubscription<Position>? _positionSubscription;
  Set<Marker> _markers = {};
  BitmapDescriptor? _userLocationMarker;
  final Map<String, BitmapDescriptor> _markerCache = {};
  Timer? _debounceTimer;
  LatLngBounds? _lastLoadedBounds;
  double _currentZoom = 14;
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
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeMap() async {
    await _loadUserMarker();
    await _getCurrentLocation();
    await _loadVendors();
    _startLocationUpdates();
  }

  Future<void> _loadUserMarker() async {
    try {
      _userLocationMarker = await CustomMapMarkers.createRiderLocationMarker(primaryColor: const Color(0xFF10B981));
    } catch (e) {
      debugPrint('Error loading user marker: $e');
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
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (!mounted) return;
      setState(() {
        _currentPosition = position;
      });
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(position.latitude, position.longitude), 14));
    } catch (e) {
      debugPrint('Error getting current location: $e');
    }
  }

  void _startLocationUpdates() {
    _positionSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 20),
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

  Future<void> _loadVendors() async {
    if (!mounted) return;
    final vendorProvider = Provider.of<VendorProvider>(context, listen: false);
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      debugPrint('📍 Current position: ${_currentPosition?.latitude}, ${_currentPosition?.longitude}');

      if (_currentPosition != null) {
        debugPrint('🔍 Fetching nearby vendors within 10km...');
        // Set vendor type first - VendorProvider requires this!
        await vendorProvider.fetchVendors(VendorType.food, forceRefresh: false);
        await vendorProvider.getNearbyVendors(_currentPosition!.latitude, _currentPosition!.longitude, radius: 10);
      } else {
        debugPrint('🔍 No position, fetching all food vendors...');
        await vendorProvider.fetchVendors(VendorType.food, forceRefresh: true);
      }

      debugPrint('📦 VendorProvider.filteredVendors length: ${vendorProvider.filteredVendors.length}');
      debugPrint('📦 VendorProvider.vendors length: ${vendorProvider.vendors.length}');
      debugPrint('📦 VendorProvider.isLoading: ${vendorProvider.isLoading}');
      debugPrint('📦 VendorProvider.errorMessage: ${vendorProvider.error}');
      if (!mounted) return;
      setState(() {
        _vendors = vendorProvider.filteredVendors;
        _isLoading = false;
      });

      // Debug logging
      debugPrint('🗺️ Loaded ${_vendors.length} vendors');
      for (var vendor in _vendors) {
        debugPrint('  - ${vendor.displayName}: location=${vendor.location?.lat},${vendor.location?.lng}');
      }

      await _updateMarkers();
      _fitCameraToMarkers();
    } catch (e, stackTrace) {
      if (!mounted) return;
      debugPrint('❌ Error loading vendors: $e');
      debugPrint('Stack trace: $stackTrace');
      setState(() {
        _errorMessage = 'Failed to load vendors: $e';
        _isLoading = false;
      });
    }
  }

  void _onCameraMove(CameraPosition position) {
    _currentZoom = position.zoom;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _loadVendorsInBounds(position);
    });
  }

  Future<void> _loadVendorsInBounds(CameraPosition position) async {
    if (_mapController == null) return;
    try {
      final bounds = await _mapController!.getVisibleRegion();

      if (_lastLoadedBounds != null && !_boundsChangedSignificantly(bounds, _lastLoadedBounds!)) {
        return;
      }
      _lastLoadedBounds = bounds;
      final center = LatLng(
        (bounds.northeast.latitude + bounds.southwest.latitude) / 2,
        (bounds.northeast.longitude + bounds.southwest.longitude) / 2,
      );
      final radius = _calculateRadius(bounds);
      if (!mounted) return;
      final vendorProvider = Provider.of<VendorProvider>(context, listen: false);

      // Ensure vendor type is set before fetching nearby vendors
      if (vendorProvider.selectedType == null) {
        await vendorProvider.fetchVendors(VendorType.food, forceRefresh: false);
      }

      await vendorProvider.getNearbyVendors(center.latitude, center.longitude, radius: radius);
      if (!mounted) return;
      setState(() {
        _vendors = vendorProvider.filteredVendors;
      });
      await _updateMarkers();
    } catch (e) {
      debugPrint('Error loading vendors in bounds: $e');
    }
  }

  bool _boundsChangedSignificantly(LatLngBounds newBounds, LatLngBounds oldBounds) {
    const threshold = 0.01;

    final latDiff = (newBounds.northeast.latitude - oldBounds.northeast.latitude).abs();
    final lngDiff = (newBounds.northeast.longitude - oldBounds.northeast.longitude).abs();

    return latDiff > threshold || lngDiff > threshold;
  }

  double _calculateRadius(LatLngBounds bounds) {
    final lat1 = bounds.southwest.latitude;
    final lon1 = bounds.southwest.longitude;
    final lat2 = bounds.northeast.latitude;
    final lon2 = bounds.northeast.longitude;
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 2000;
  }

  Future<void> _updateMarkers() async {
    if (!mounted) return;

    debugPrint('🎯 _updateMarkers called with ${_vendors.length} vendors, zoom: $_currentZoom');

    final Set<Marker> markers = {};
    final colors = context.appColors;
    if (_currentPosition != null && _userLocationMarker != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('user_location'),
          position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          icon: _userLocationMarker!,
          anchor: const Offset(0.5, 0.5),
          zIndexInt: 100,
        ),
      );
    }
    if (_currentZoom < 14) {
      _clusters = _clusterVendors(_vendors, _currentZoom);

      for (final cluster in _clusters) {
        if (cluster.vendors.length > 1) {
          final cacheKey = 'cluster_${cluster.vendors.length}_${cluster.center.latitude}_${cluster.center.longitude}';

          BitmapDescriptor markerIcon;
          if (_markerCache.containsKey(cacheKey)) {
            markerIcon = _markerCache[cacheKey]!;
          } else {
            markerIcon = await _createClusterMarker(cluster.vendors.length, colors.accentGreen);
            _markerCache[cacheKey] = markerIcon;
          }
          markers.add(
            Marker(
              markerId: MarkerId(cacheKey),
              position: cluster.center,
              icon: markerIcon,
              anchor: const Offset(0.5, 0.5),
              zIndexInt: 50,
              onTap: () => _onClusterTapped(cluster),
            ),
          );
        } else {
          await _addVendorMarker(markers, cluster.vendors.first, colors);
        }
      }
    } else {
      for (final vendor in _vendors) {
        await _addVendorMarker(markers, vendor, colors);
      }
    }
    if (!mounted) return;

    debugPrint('✅ Created ${markers.length} markers total');

    setState(() {
      _markers = markers;
    });
  }

  Future<void> _addVendorMarker(Set<Marker> markers, VendorModel vendor, AppColorsExtension colors) async {
    if (vendor.location == null) return;
    final cacheKey = 'vendor_${vendor.id}';

    BitmapDescriptor markerIcon;
    if (_markerCache.containsKey(cacheKey)) {
      markerIcon = _markerCache[cacheKey]!;
    } else {
      try {
        markerIcon = await CustomMapMarkers.createStoreMarker(
          name: vendor.displayName,
          primaryColor: _getVendorColor(vendor.vendorType),
        );
        _markerCache[cacheKey] = markerIcon;
      } catch (e) {
        debugPrint('Error creating marker for vendor ${vendor.id}: $e');
        markerIcon = BitmapDescriptor.defaultMarker;
      }
    }

    debugPrint('  ➕ Added vendor marker: ${vendor.displayName} at ${vendor.location!.lat},${vendor.location!.lng}');

    markers.add(
      Marker(
        markerId: MarkerId('vendor_${vendor.id}'),
        position: LatLng(vendor.location!.lat, vendor.location!.lng),
        icon: markerIcon,
        anchor: const Offset(0.5, 1.0),
        zIndexInt: 10,
        onTap: () => _onVendorMarkerTapped(vendor),
      ),
    );
  }

  Color _getVendorColor(String? vendorType) {
    switch (vendorType?.toLowerCase()) {
      case 'restaurant':
      case 'food':
        return const Color(0xFFEF4444);
      case 'pharmacy':
        return const Color(0xFF10B981);
      case 'grocery':
        return const Color(0xFF3B82F6);
      case 'grabmart':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF6B7280);
    }
  }

  List<VendorCluster> _clusterVendors(List<VendorModel> vendors, double zoomLevel) {
    final clusterDistance = _getClusterDistance(zoomLevel);

    final List<VendorCluster> clusters = [];
    final List<VendorModel> unclustered = List.from(vendors);
    while (unclustered.isNotEmpty) {
      final vendor = unclustered.removeAt(0);
      if (vendor.location == null) continue;
      final cluster = VendorCluster(center: LatLng(vendor.location!.lat, vendor.location!.lng), vendors: [vendor]);
      unclustered.removeWhere((other) {
        if (other.location == null) return false;

        final distance = Geolocator.distanceBetween(
          vendor.location!.lat,
          vendor.location!.lng,
          other.location!.lat,
          other.location!.lng,
        );
        if (distance <= clusterDistance) {
          cluster.vendors.add(other);
          return true;
        }
        return false;
      });
      if (cluster.vendors.length > 1) {
        double totalLat = 0;
        double totalLng = 0;
        for (final v in cluster.vendors) {
          totalLat += v.location!.lat;
          totalLng += v.location!.lng;
        }
        cluster.center = LatLng(totalLat / cluster.vendors.length, totalLng / cluster.vendors.length);
      }
      clusters.add(cluster);
    }
    return clusters;
  }

  double _getClusterDistance(double zoomLevel) {
    if (zoomLevel >= 14) return 0;
    if (zoomLevel >= 12) return 100;
    if (zoomLevel >= 10) return 500;
    return 1000;
  }

  Future<BitmapDescriptor> _createClusterMarker(int count, Color color) async {
    final pictureRecorder = ui.PictureRecorder();
    final canvas = Canvas(pictureRecorder);
    final paint = Paint();
    const size = 120.0;
    const radius = 50.0;
    final center = const Offset(size / 2, size / 2);
    paint.color = color.withValues(alpha: 0.3);
    canvas.drawCircle(center, radius, paint);
    paint.color = color;
    canvas.drawCircle(center, radius * 0.7, paint);
    paint.color = Colors.white;
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 4;
    canvas.drawCircle(center, radius * 0.7, paint);
    paint.style = PaintingStyle.fill;
    final textPainter = TextPainter(
      text: TextSpan(
        text: count > 99 ? '99+' : '$count',
        style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height / 2));
    final image = await pictureRecorder.endRecording().toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.bytes(byteData!.buffer.asUint8List());
  }

  void _onClusterTapped(VendorCluster cluster) {
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(cluster.center, _currentZoom + 2));
  }

  void _onVendorMarkerTapped(VendorModel vendor) {
    VendorDetailBottomSheet.show(context: context, vendor: vendor);
  }

  void _fitCameraToMarkers() {
    if (_markers.isEmpty || _mapController == null) return;
    if (_markers.length == 1) {
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_markers.first.position, 15));
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
      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(LatLng(minLat, minLng), 15));
      return;
    }
    const padding = 0.002;
    final bounds = LatLngBounds(
      southwest: LatLng(minLat - padding, minLng - padding),
      northeast: LatLng(maxLat + padding, maxLng + padding),
    );
    _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80.w));
  }

  void _centerOnUser() {
    if (_currentPosition == null || _mapController == null) return;
    _mapController!.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(_currentPosition!.latitude, _currentPosition!.longitude), 15),
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
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
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
                  height: 44.h,
                  width: 44.w,
                  decoration: BoxDecoration(
                    color: colors.backgroundPrimary,
                    shape: BoxShape.circle,
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
                      onTap: () => Navigator.of(context).pop(),
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
        ),
        body: Stack(
          children: [
            Positioned.fill(
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: _currentPosition != null
                      ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
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
                style: GrabGoMapStyles.forBrightness(Theme.of(context).brightness),
                padding: EdgeInsets.only(bottom: 100.h),
                onMapCreated: (controller) {
                  _mapController = controller;
                  Future.delayed(const Duration(milliseconds: 500), _fitCameraToMarkers);
                },
                onCameraMove: _onCameraMove,
              ),
            ),

            // Loading overlay
            if (_isLoading)
              Positioned.fill(
                child: Container(
                  color: colors.backgroundPrimary.withValues(alpha: 0.7),
                  child: Column(
                    children: [SpinKitCubeGrid(color: colors.accentOrange, size: 35.r)],
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
                    border: Border.all(color: colors.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: colors.error),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: colors.textPrimary, fontSize: 13.sp),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.refresh, color: colors.accentGreen),
                        onPressed: _loadVendors,
                      ),
                    ],
                  ),
                ),
              ),

            // Map Controls
            Positioned(
              right: 16.w,
              bottom: 120.h,
              child: Column(
                children: [
                  _buildMapControlButton(
                    icon: Assets.icons.position,
                    onTap: _centerOnUser,
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
          ],
        ),
      ),
    );
  }
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
          color: isDark ? Colors.black.withAlpha(30) : Colors.black.withAlpha(15),
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
            colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
            width: 22.w,
            height: 22.w,
          ),
        ),
      ),
    ),
  );
}

// Helper class for vendor clustering
class VendorCluster {
  LatLng center;
  List<VendorModel> vendors;
  VendorCluster({required this.center, required this.vendors});
}
