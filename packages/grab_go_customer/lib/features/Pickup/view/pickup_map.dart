import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:grab_go_customer/features/Pickup/widgets/vendor_details_bottom_sheet.dart';
import 'package:grab_go_customer/features/vendors/model/vendor_model.dart';
import 'package:grab_go_customer/features/vendors/model/vendor_type.dart';
import 'package:grab_go_customer/features/vendors/viewmodel/vendor_provider.dart';
import 'package:grab_go_customer/shared/viewmodels/navigation_provider.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/shared/utils/app_colors_extension.dart';
import 'package:grab_go_shared/shared/utils/constants.dart';
import 'package:grab_go_shared/shared/utils/map_styles.dart';
import 'package:grab_go_customer/features/home/viewmodel/food_provider.dart';
import 'package:grab_go_customer/shared/widgets/pickup_map_skeleton.dart';
import 'package:grab_go_shared/shared/widgets/app_button.dart';
import 'package:grab_go_shared/shared/widgets/custom_map_markers.dart';
import 'package:grab_go_customer/shared/viewmodels/native_location_provider.dart';
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
  PersistentBottomSheetController? _sheetController;
  String? _selectedVendorId;
  String? _errorMessage;
  Position? _currentPosition;
  StreamSubscription<Position>? _positionSubscription;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  final Map<String, BitmapDescriptor> _markerCache = {};
  Timer? _debounceTimer;
  LatLngBounds? _lastLoadedBounds;
  double _currentZoom = 14;
  static const LatLng _defaultPosition = LatLng(5.6037, -0.1870);

  double? _lastLat;
  double? _lastLng;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locationProvider = Provider.of<NativeLocationProvider>(context);

    // If location changed in the global provider (e.g. via Address Picker), refresh the map
    if (locationProvider.latitude != _lastLat || locationProvider.longitude != _lastLng) {
      final oldLat = _lastLat;
      final oldLng = _lastLng;

      _lastLat = locationProvider.latitude;
      _lastLng = locationProvider.longitude;

      if (_lastLat != null && _lastLng != null) {
        // Update current position for UI
        _currentPosition = Position(
          latitude: _lastLat!,
          longitude: _lastLng!,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          heading: 0,
          speed: 0,
          speedAccuracy: 0,
          altitudeAccuracy: 0,
          headingAccuracy: 0,
        );

        if (oldLat != null && oldLng != null && _mapController != null) {
          _mapController!.animateCamera(CameraUpdate.newLatLngZoom(LatLng(_lastLat!, _lastLng!), 14));
        }
        _loadVendors();
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  @override
  void deactivate() {
    _sheetController?.close();
    super.deactivate();
  }

  @override
  void dispose() {
    _sheetController?.close();
    _markerCache.clear();
    _positionSubscription?.cancel();
    _mapController?.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeMap() async {
    await _getCurrentLocation();
    await _loadVendors();
    _startLocationUpdates();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final locationProvider = Provider.of<NativeLocationProvider>(context, listen: false);

      if (locationProvider.hasLocation) {
        _lastLat = locationProvider.latitude;
        _lastLng = locationProvider.longitude;

        _currentPosition = Position(
          latitude: _lastLat!,
          longitude: _lastLng!,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          heading: 0,
          speed: 0,
          speedAccuracy: 0,
          altitudeAccuracy: 0,
          headingAccuracy: 0,
        );

        if (mounted) setState(() {});
        return;
      }

      // Fallback to direct GPS if provider has no location
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) return;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      if (!mounted) return;
      setState(() {
        _currentPosition = position;
        _lastLat = position.latitude;
        _lastLng = position.longitude;
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
      if (_currentPosition != null) {
        await vendorProvider.getAllNearbyVendors(_currentPosition!.latitude, _currentPosition!.longitude, radius: 10);
      } else {
        await vendorProvider.fetchVendors(VendorType.food, forceRefresh: true);
      }

      if (!mounted) return;
      setState(() {
        _vendors = vendorProvider.filteredVendors;
        _isLoading = false;
      });

      for (var vendor in _vendors) {
        debugPrint('  - ${vendor.displayName}: location=${vendor.location?.lat},${vendor.location?.lng}');
      }

      await _updateMarkers();
      _fitCameraToMarkers();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load vendors: $e';
        _isLoading = false;
      });
    }
  }

  void _onCameraMove(CameraPosition position) {
    final oldZoom = _currentZoom;
    _currentZoom = position.zoom;

    const labelThreshold = 14.5;
    const clusterThreshold = 14.0;

    final bool crossedLabel =
        (oldZoom < labelThreshold && _currentZoom >= labelThreshold) ||
        (oldZoom >= labelThreshold && _currentZoom < labelThreshold);
    final bool crossedCluster =
        (oldZoom < clusterThreshold && _currentZoom >= clusterThreshold) ||
        (oldZoom >= clusterThreshold && _currentZoom < clusterThreshold);

    if (crossedLabel || crossedCluster) {
      _updateMarkers();
    }

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

      await vendorProvider.getAllNearbyVendors(center.latitude, center.longitude, radius: radius);
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
    final Set<Marker> markers = {};
    final colors = context.appColors;

    final foodProvider = Provider.of<FoodProvider>(context, listen: false);
    final bool isFoodUnavailable = foodProvider.categories.isEmpty && foodProvider.hasAttemptedFetch;

    // Only show vendor markers if the area is available
    if (!isFoodUnavailable) {
      if (_currentZoom < 14) {
        _clusters = _clusterVendors(_vendors, _currentZoom);

        for (final cluster in _clusters) {
          if (cluster.vendors.length > 1) {
            final cacheKey = 'cluster_${cluster.vendors.length}_${cluster.center.latitude}_${cluster.center.longitude}';

            BitmapDescriptor markerIcon;
            if (_markerCache.containsKey(cacheKey)) {
              markerIcon = _markerCache[cacheKey]!;
            } else {
              markerIcon = await CustomMapMarkers.createStandardMarker(
                primaryColor: colors.accentOrange,
                iconAsset: 'packages/grab_go_shared/lib/assets/icons/store.svg',
                clusterCount: cluster.vendors.length,
              );
              _markerCache[cacheKey] = markerIcon;
            }
            markers.add(
              Marker(
                markerId: MarkerId(cacheKey),
                position: cluster.center,
                icon: markerIcon,
                anchor: const Offset(0.5, 1.0),
                zIndexInt: 50,
                onTap: () => _onClusterTapped(cluster),
              ),
            );
          } else {
            await _addVendorMarker(markers, cluster.vendors.first, colors, showLabel: false);
          }
        }
        for (final vendor in _vendors) {
          await _addVendorMarker(markers, vendor, colors, showLabel: _currentZoom >= 14.5);
        }
      }
    }

    if (_currentPosition != null && _currentZoom >= 14.0) {
      const String userCacheKey = 'user_location_marker';
      BitmapDescriptor userIcon;
      if (_markerCache.containsKey(userCacheKey)) {
        userIcon = _markerCache[userCacheKey]!;
      } else {
        userIcon = await CustomMapMarkers.createRiderLocationMarker(primaryColor: colors.accentOrange);
        _markerCache[userCacheKey] = userIcon;
      }

      markers.add(
        Marker(
          markerId: const MarkerId('user_location'),
          position: LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
          icon: userIcon,
          anchor: const Offset(0.5, 0.5),
          zIndexInt: 110,
        ),
      );
    }

    final Set<Polyline> polylines = {};
    if (_selectedVendorId != null && _currentPosition != null) {
      final selectedVendor = _vendors.firstWhere((v) => v.id == _selectedVendorId);
      if (selectedVendor.location != null) {
        polylines.add(
          Polyline(
            polylineId: const PolylineId('selected_vendor_route'),
            points: [
              LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
              LatLng(selectedVendor.location!.lat, selectedVendor.location!.lng),
            ],
            color: colors.accentOrange.withValues(alpha: 0.6),
            width: 3,
            patterns: [PatternItem.dash(15), PatternItem.gap(10)],
          ),
        );
      }
    }

    if (!mounted) return;

    setState(() {
      _markers = markers;
      _polylines = polylines;
    });
  }

  Future<void> _addVendorMarker(
    Set<Marker> markers,
    VendorModel vendor,
    AppColorsExtension colors, {
    bool showLabel = true,
  }) async {
    if (vendor.location == null) return;

    final bool isSelected = vendor.id == _selectedVendorId;
    // Always show label if selected, otherwise honor the passed flag
    final bool effectiveShowLabel = isSelected || showLabel;
    final cacheKey = 'vendor_${vendor.id}${isSelected ? '_selected' : ''}${effectiveShowLabel ? '_labelled' : ''}';

    BitmapDescriptor markerIcon;
    if (_markerCache.containsKey(cacheKey)) {
      markerIcon = _markerCache[cacheKey]!;
    } else {
      try {
        String iconAsset = 'packages/grab_go_shared/lib/assets/icons/store.svg';
        switch (vendor.vendorTypeEnum) {
          case VendorType.food:
            iconAsset = 'packages/grab_go_shared/lib/assets/icons/chef-hat.svg';
            break;
          case VendorType.grocery:
            iconAsset = 'packages/grab_go_shared/lib/assets/icons/cart.svg';
            break;
          case VendorType.grabmart:
            iconAsset = 'packages/grab_go_shared/lib/assets/icons/store.svg';
            break;
          case VendorType.pharmacy:
            iconAsset = 'packages/grab_go_shared/lib/assets/icons/pharmacy-cross-circle.svg';
            break;
        }

        markerIcon = await CustomMapMarkers.createStandardMarker(
          name: vendor.displayName,
          primaryColor: colors.accentOrange,
          iconAsset: iconAsset,
          isSelected: isSelected,
          showLabel: effectiveShowLabel,
        );
        _markerCache[cacheKey] = markerIcon;
      } catch (e) {
        debugPrint('Error creating marker for vendor ${vendor.id}: $e');
        markerIcon = BitmapDescriptor.defaultMarker;
      }
    }

    markers.add(
      Marker(
        markerId: MarkerId('vendor_${vendor.id}'),
        position: LatLng(vendor.location!.lat, vendor.location!.lng),
        icon: markerIcon,
        anchor: const Offset(0.5, 1.0),
        zIndexInt: isSelected ? 100 : 10,
        onTap: () => _onVendorMarkerTapped(vendor),
      ),
    );
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

  void _onClusterTapped(VendorCluster cluster) {
    _mapController?.animateCamera(CameraUpdate.newLatLngZoom(cluster.center, _currentZoom + 2));
  }

  void _onVendorMarkerTapped(VendorModel vendor) {
    if (_selectedVendorId == vendor.id) return;

    setState(() {
      _selectedVendorId = vendor.id;
    });
    _updateMarkers();

    if (_sheetController != null) {
      _sheetController?.close();
      _sheetController = null;
    }
    _sheetController = VendorDetailBottomSheet.show(context: context, vendor: vendor);
    _sheetController?.closed.then((_) {
      if (mounted) {
        setState(() {
          _sheetController = null;
          _selectedVendorId = null;
        });
        _updateMarkers();
      }
    });
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

  Widget _buildFilterChips(VendorProvider provider, AppColorsExtension colors, bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Row(
        children: [
          _buildFilterChip(
            label: 'All',
            isSelected: provider.mapCategoryFilter == null,
            onTap: () => provider.setMapCategoryFilter(null),
            colors: colors,
            isDark: isDark,
          ),
          _buildFilterChip(
            label: 'Food',
            isSelected: provider.mapCategoryFilter == VendorType.food,
            onTap: () => provider.setMapCategoryFilter(VendorType.food),
            colors: colors,
            isDark: isDark,
          ),
          _buildFilterChip(
            label: 'Grocery',
            isSelected: provider.mapCategoryFilter == VendorType.grocery,
            onTap: () => provider.setMapCategoryFilter(VendorType.grocery),
            colors: colors,
            isDark: isDark,
          ),
          _buildFilterChip(
            label: 'Pharmacy',
            isSelected: provider.mapCategoryFilter == VendorType.pharmacy,
            onTap: () => provider.setMapCategoryFilter(VendorType.pharmacy),
            colors: colors,
            isDark: isDark,
          ),
          _buildFilterChip(
            label: 'GrabMart',
            isSelected: provider.mapCategoryFilter == VendorType.grabmart,
            onTap: () => provider.setMapCategoryFilter(VendorType.grabmart),
            colors: colors,
            isDark: isDark,
          ),
          _buildFilterChip(
            label: 'Open Now',
            isSelected: provider.openNowOnly,
            onTap: () => provider.setOpenNowFilter(!provider.openNowOnly),
            colors: colors,
            isDark: isDark,
          ),
          _buildFilterChip(
            label: 'Near Me',
            isSelected: provider.maxDistance != null,
            onTap: () => provider.setMaxDistance(provider.maxDistance == null ? 5.0 : null),
            colors: colors,
            isDark: isDark,
          ),
          _buildFilterChip(
            label: 'Top Rated',
            isSelected: provider.minRating != null,
            onTap: () => provider.setMinRating(provider.minRating == null ? 4.5 : null),
            colors: colors,
            isDark: isDark,
          ),
          _buildFilterChip(
            label: 'Fast Delivery',
            isSelected: provider.fastDeliveryOnly,
            onTap: () => provider.setFastDelivery(!provider.fastDeliveryOnly),
            colors: colors,
            isDark: isDark,
          ),
          _buildFilterChip(
            label: 'Budget',
            isSelected: provider.priceRange == 1,
            onTap: () => provider.setPriceRange(provider.priceRange == 1 ? null : 1),
            colors: colors,
            isDark: isDark,
          ),
          _buildFilterChip(
            label: 'Mid',
            isSelected: provider.priceRange == 2,
            onTap: () => provider.setPriceRange(provider.priceRange == 2 ? null : 2),
            colors: colors,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required AppColorsExtension colors,
    required bool isDark,
  }) {
    return Padding(
      padding: EdgeInsets.only(right: 8.w),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: isSelected ? colors.accentOrange : colors.backgroundPrimary,
            borderRadius: BorderRadius.circular(20.r),
            boxShadow: [
              BoxShadow(
                color: isDark ? Colors.black.withAlpha(30) : Colors.black.withAlpha(15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : colors.textPrimary,
              fontSize: 13.sp,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vendorProvider = Provider.of<VendorProvider>(context);
    final navigationProvider = Provider.of<NavigationProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = context.appColors;

    // Sync vendors from provider if changed
    if (vendorProvider.filteredVendors != _vendors) {
      _vendors = vendorProvider.filteredVendors;
      // Schedule an update for the next frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _updateMarkers();
      });
    }

    if (navigationProvider.selectedIndex != 1 && _sheetController != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_sheetController != null) {
          _sheetController?.close();
          _sheetController = null;
          if (mounted) {
            setState(() {
              _selectedVendorId = null;
            });
            _updateMarkers();
          }
        }
      });
    }

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
        appBar: null,
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
                polylines: _polylines,
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
                onTap: (_) {
                  if (_sheetController != null) {
                    _sheetController?.close();
                    _sheetController = null;
                  }
                  if (_selectedVendorId != null) {
                    setState(() {
                      _selectedVendorId = null;
                    });
                    _updateMarkers();
                  }
                },
              ),
            ),

            if (_isLoading) const Positioned.fill(child: PickupMapSkeleton()),

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

            Positioned(
              top: MediaQuery.of(context).padding.top + 10.h,
              left: 0,
              right: 0,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: Container(
                      height: 48.h,
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      decoration: BoxDecoration(
                        color: colors.backgroundPrimary,
                        borderRadius: BorderRadius.circular(30.r),
                        boxShadow: [
                          BoxShadow(
                            color: isDark ? Colors.black.withAlpha(30) : Colors.black.withAlpha(15),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          SvgPicture.asset(
                            Assets.icons.search,
                            package: 'grab_go_shared',
                            width: 20.w,
                            height: 20.w,
                            colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
                          ),
                          SizedBox(width: 12.w),
                          Text(
                            'Search',
                            style: TextStyle(color: colors.textSecondary, fontSize: 15.sp, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  _buildFilterChips(vendorProvider, colors, isDark),

                  SizedBox(height: 16.h),

                  Padding(
                    padding: EdgeInsets.only(right: 16.w),
                    child: _buildMapControlButton(
                      icon: Assets.icons.position,
                      onTap: _centerOnUser,
                      colors: colors,
                      isDark: isDark,
                    ),
                  ),

                  SizedBox(height: 12.h),

                  Padding(
                    padding: EdgeInsets.only(right: 16.w),
                    child: _buildMapControlButton(
                      icon: Assets.icons.expand,
                      onTap: _fitCameraToMarkers,
                      colors: colors,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
            ),

            Consumer<FoodProvider>(
              builder: (context, foodProvider, child) {
                final bool isFoodUnavailable = foodProvider.categories.isEmpty && foodProvider.hasAttemptedFetch;

                if (!isFoodUnavailable || _isLoading) return const SizedBox.shrink();

                return Positioned(
                  bottom: 120.h,
                  left: 20.w,
                  right: 20.w,
                  child: Container(
                    padding: EdgeInsets.all(20.r),
                    decoration: BoxDecoration(
                      color: colors.backgroundPrimary,
                      borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(isDark ? 50 : 20),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(12.r),
                              decoration: BoxDecoration(
                                color: colors.accentOrange.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.map_outlined, color: colors.accentOrange, size: 24.r),
                            ),
                            SizedBox(width: 16.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "GrabGo is Not Here Yet",
                                    style: TextStyle(
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w700,
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                  SizedBox(height: 4.h),
                                  Text(
                                    "We haven't launched in this area yet.",
                                    style: TextStyle(fontSize: 13.sp, color: colors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16.h),
                        AppButton(
                          width: double.infinity,
                          onPressed: () => context.push('/address_picker'),
                          backgroundColor: colors.accentOrange,
                          borderRadius: KBorderSize.borderMedium,
                          buttonText: "Change Location",
                          textStyle: TextStyle(fontSize: 15.sp, color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                );
              },
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

class VendorCluster {
  LatLng center;
  List<VendorModel> vendors;
  VendorCluster({required this.center, required this.vendors});
}
