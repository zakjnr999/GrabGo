import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:grab_go_customer/features/Pickup/widgets/vendor_details_bottom_sheet.dart';
import 'package:grab_go_customer/features/vendors/model/vendor_model.dart';
import 'package:grab_go_customer/features/vendors/model/vendor_type.dart';
import 'package:grab_go_customer/features/vendors/viewmodel/vendor_provider.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_shared/shared/widgets/custom_map_markers.dart';
import 'package:grab_go_customer/shared/viewmodels/native_location_provider.dart';
import 'package:grab_go_customer/shared/widgets/pickup_map_skeleton.dart';
import 'package:provider/provider.dart';

class PickupMap extends StatefulWidget {
  const PickupMap({super.key});

  @override
  State<PickupMap> createState() => _PickupMapState();
}

class _PickupMapState extends State<PickupMap> {
  static const String _markerStyleVersion = 'v2';
  GoogleMapController? _mapController;
  List<VendorModel> _vendors = [];
  List<VendorCluster> _clusters = [];
  bool _isLoading = true;
  PersistentBottomSheetController? _sheetController;
  String? _selectedVendorId;
  String? _errorMessage;
  bool _hasAttemptedVendorFetch = false;
  Position? _currentPosition;
  StreamSubscription<Position>? _positionSubscription;
  Set<Marker> _vendorMarkers = {};
  Marker? _userMarker;
  Set<Polyline> _polylines = {};
  final Map<String, BitmapDescriptor> _markerCache = {};
  Timer? _debounceTimer;
  Timer? _cameraMoveDebounce;
  CameraPosition? _lastCameraPosition;
  LatLngBounds? _lastLoadedBounds;
  double _currentZoom = 14;
  static const LatLng _defaultPosition = LatLng(5.6037, -0.1870);

  double? _lastLat;
  double? _lastLng;
  LatLng? _lastUserMarkerPosition;
  bool _pendingLocationUpdate = false;

  Color _colorForVendorType(VendorType type, AppColorsExtension colors) {
    switch (type) {
      case VendorType.food:
        return colors.serviceFood;
      case VendorType.grocery:
        return colors.serviceGrocery;
      case VendorType.pharmacy:
        return colors.servicePharmacy;
      case VendorType.grabmart:
        return colors.serviceGrabMart;
    }
  }

  String _iconAssetForVendorType(VendorType type) {
    switch (type) {
      case VendorType.food:
        return 'packages/grab_go_shared/lib/assets/icons/chef-hat.svg';
      case VendorType.grocery:
        return 'packages/grab_go_shared/lib/assets/icons/cart.svg';
      case VendorType.pharmacy:
        return 'packages/grab_go_shared/lib/assets/icons/pharmacy-cross-circle.svg';
      case VendorType.grabmart:
        return 'packages/grab_go_shared/lib/assets/icons/store.svg';
    }
  }

  IconData _fallbackIconForVendorType(VendorType type) {
    switch (type) {
      case VendorType.food:
        return Icons.restaurant_rounded;
      case VendorType.grocery:
        return Icons.shopping_cart_rounded;
      case VendorType.pharmacy:
        return Icons.local_pharmacy_rounded;
      case VendorType.grabmart:
        return Icons.storefront_rounded;
    }
  }

  VendorType _dominantVendorType(List<VendorModel> vendors) {
    final counts = <VendorType, int>{};
    for (final vendor in vendors) {
      counts[vendor.vendorTypeEnum] = (counts[vendor.vendorTypeEnum] ?? 0) + 1;
    }

    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }

  bool _isValidLatLng(double? lat, double? lng) {
    if (lat == null || lng == null) return false;
    if (lat.isNaN || lng.isNaN) return false;
    if (lat.abs() > 90 || lng.abs() > 180) return false;
    return true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locationProvider = Provider.of<NativeLocationProvider>(context);

    if (locationProvider.latitude != _lastLat ||
        locationProvider.longitude != _lastLng) {
      final oldLat = _lastLat;
      final oldLng = _lastLng;

      _lastLat = locationProvider.latitude;
      _lastLng = locationProvider.longitude;

      if (_isValidLatLng(_lastLat, _lastLng) && !_pendingLocationUpdate) {
        _pendingLocationUpdate = true;
        final nextPosition = Position(
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

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            _pendingLocationUpdate = false;
            return;
          }
          setState(() {
            _currentPosition = nextPosition;
          });
          if (oldLat != null && oldLng != null && _mapController != null) {
            _mapController!.animateCamera(
              CameraUpdate.newLatLngZoom(LatLng(_lastLat!, _lastLng!), 14),
            );
          }
          _updateUserMarker();
          _loadVendors();
          _pendingLocationUpdate = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _initPosition();
        _loadVendors();
      }
    });
    _startLocationUpdates();
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
    _cameraMoveDebounce?.cancel();
    super.dispose();
  }

  Future<void> _initializeMap() async {
    await _getCurrentLocation();
    await _updateUserMarker();
    await _loadVendors();
    _startLocationUpdates();
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (mounted) {
      _updateMarkers();
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) _fitCameraToMarkers();
      });
    }
  }

  Future<void> _initPosition() async {
    try {
      Position? position =
          await Geolocator.getCurrentPosition(
                locationSettings: AndroidSettings(
                  accuracy: LocationAccuracy.medium,
                  intervalDuration: const Duration(seconds: 5),
                  distanceFilter: 20,
                ),
              )
              .catchError((Object e) {
                return null;
              })
              .then((value) => value as Position?);

      if (position != null && mounted) {
        setState(() => _currentPosition = position);
        _mapController?.animateCamera(
          CameraUpdate.newLatLng(LatLng(position.latitude, position.longitude)),
        );
      }
    } catch (e) {
      // Handle error quietly
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      final locationProvider = Provider.of<NativeLocationProvider>(
        context,
        listen: false,
      );

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

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever)
        return;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;
      setState(() {
        _currentPosition = position;
        _lastLat = position.latitude;
        _lastLng = position.longitude;
      });
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(
          LatLng(position.latitude, position.longitude),
          14,
        ),
      );
    } catch (e) {
      // Error getting current location
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
            _updateUserMarker();
          },
          onError: (error) {
            // Location stream error
          },
        );
  }

  Future<void> _loadVendors() async {
    if (!mounted) return;
    final vendorProvider = Provider.of<VendorProvider>(context, listen: false);
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _hasAttemptedVendorFetch = true;
    });
    try {
      if (_currentPosition != null) {
        await vendorProvider.getAllNearbyVendors(
          _currentPosition!.latitude,
          _currentPosition!.longitude,
          radius: 10,
        );
      } else {
        await vendorProvider.fetchVendors(VendorType.food, forceRefresh: true);
      }

      if (!mounted) return;

      if (vendorProvider.error != null) {
        setState(() {
          _errorMessage = vendorProvider.error;
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _vendors = vendorProvider.filteredVendors
            .where((v) => _isValidLatLng(v.location?.lat, v.location?.lng))
            .toList();
        _isLoading = false;
      });

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

    if (_currentZoom < 14.0 && _userMarker != null) {
      setState(() {
        _userMarker = null;
      });
    } else if (_currentZoom >= 14.0 &&
        _userMarker == null &&
        _currentPosition != null) {
      _updateUserMarker();
    }

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

  void _onCameraMoveDebounced(CameraPosition position) {
    _lastCameraPosition = position;
    _cameraMoveDebounce?.cancel();
    _cameraMoveDebounce = Timer(const Duration(milliseconds: 120), () {
      final last = _lastCameraPosition;
      if (last != null) {
        _onCameraMove(last);
      }
    });
  }

  Future<void> _loadVendorsInBounds(CameraPosition position) async {
    if (_mapController == null) return;
    try {
      final bounds = await _mapController!.getVisibleRegion();

      if (_lastLoadedBounds != null &&
          !_boundsChangedSignificantly(bounds, _lastLoadedBounds!)) {
        return;
      }
      _lastLoadedBounds = bounds;
      final center = LatLng(
        (bounds.northeast.latitude + bounds.southwest.latitude) / 2,
        (bounds.northeast.longitude + bounds.southwest.longitude) / 2,
      );
      final radius = _calculateRadius(bounds);
      if (!mounted) return;
      final vendorProvider = Provider.of<VendorProvider>(
        context,
        listen: false,
      );

      await vendorProvider.getAllNearbyVendors(
        center.latitude,
        center.longitude,
        radius: radius,
      );
      if (!mounted) return;
      setState(() {
        _hasAttemptedVendorFetch = true;
        _vendors = vendorProvider.filteredVendors
            .where((v) => _isValidLatLng(v.location?.lat, v.location?.lng))
            .toList();
      });
      await _updateMarkers();
    } catch (e) {
      // Error loading vendors in bounds
    }
  }

  bool _boundsChangedSignificantly(
    LatLngBounds newBounds,
    LatLngBounds oldBounds,
  ) {
    const threshold = 0.01;

    final latDiff =
        (newBounds.northeast.latitude - oldBounds.northeast.latitude).abs();
    final lngDiff =
        (newBounds.northeast.longitude - oldBounds.northeast.longitude).abs();

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
    final Set<Marker> vendorMarkers = {};
    final colors = context.appColors;

    if (_currentZoom < 14) {
      _clusters = _clusterVendors(_vendors, _currentZoom);

      for (final cluster in _clusters) {
        if (cluster.vendors.length > 1) {
          final dominantType = _dominantVendorType(cluster.vendors);
          final clusterColor = _colorForVendorType(dominantType, colors);
          final clusterIconAsset = _iconAssetForVendorType(dominantType);
          final clusterFallbackIcon = _fallbackIconForVendorType(dominantType);
          final cacheKey =
              'cluster_tap_pin_${_markerStyleVersion}_${cluster.vendors.length}_${dominantType.name}_${cluster.center.latitude}_${cluster.center.longitude}';

          BitmapDescriptor markerIcon;
          if (_markerCache.containsKey(cacheKey)) {
            markerIcon = _markerCache[cacheKey]!;
          } else {
            markerIcon = await CustomMapMarkers.createTapPinMarker(
              primaryColor: clusterColor,
              iconAsset: clusterIconAsset,
              fallbackIcon: clusterFallbackIcon,
            );
            _markerCache[cacheKey] = markerIcon;
          }
          vendorMarkers.add(
            Marker(
              markerId: MarkerId(cacheKey),
              position: cluster.center,
              icon: markerIcon,
              anchor: const Offset(0.5, 0.8),
              zIndexInt: 50,
              infoWindow: InfoWindow(
                title: '${cluster.vendors.length} vendors',
                snippet: '${dominantType.displayName} • Tap to zoom in',
              ),
              onTap: () => _onClusterTapped(cluster),
            ),
          );
        } else {
          await _addVendorMarker(vendorMarkers, cluster.vendors.first, colors);
        }
      }
    } else {
      for (final vendor in _vendors) {
        await _addVendorMarker(vendorMarkers, vendor, colors);
      }
    }

    final Set<Polyline> polylines = {};
    if (_selectedVendorId != null && _currentPosition != null) {
      final vendor = _vendors.cast<VendorModel?>().firstWhere(
        (v) => v?.id == _selectedVendorId,
        orElse: () => null,
      );

      if (vendor != null && vendor.location != null) {
        polylines.add(
          Polyline(
            polylineId: const PolylineId('selected_vendor_route'),
            points: [
              LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
              LatLng(vendor.location!.lat, vendor.location!.lng),
            ],
            color: colors.accentOrange.withValues(alpha: 0.6),
            width: 3,
            patterns: [PatternItem.dash(15), PatternItem.gap(10)],
          ),
        );
      }
    }

    if (!mounted) return;

    final bool markersChanged = !setEquals(_vendorMarkers, vendorMarkers);
    final bool polylinesChanged = !setEquals(_polylines, polylines);
    if (markersChanged || polylinesChanged) {
      setState(() {
        _vendorMarkers = vendorMarkers;
        _polylines = polylines;
      });
    }
  }

  Future<void> _updateUserMarker() async {
    if (!mounted || _currentPosition == null || _currentZoom < 14.0) return;
    final LatLng newPosition = LatLng(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
    );

    if (_lastUserMarkerPosition != null) {
      final distance = Geolocator.distanceBetween(
        _lastUserMarkerPosition!.latitude,
        _lastUserMarkerPosition!.longitude,
        newPosition.latitude,
        newPosition.longitude,
      );
      if (distance < 10) return;
    }

    _lastUserMarkerPosition = newPosition;

    const String userCacheKey = 'user_location_marker';
    final colors = context.appColors;
    BitmapDescriptor userIcon;
    if (_markerCache.containsKey(userCacheKey)) {
      userIcon = _markerCache[userCacheKey]!;
    } else {
      userIcon = await CustomMapMarkers.createRiderLocationMarker(
        primaryColor: colors.accentOrange,
      );
      _markerCache[userCacheKey] = userIcon;
    }

    if (!mounted) return;
    setState(() {
      _userMarker = Marker(
        markerId: const MarkerId('user_location'),
        position: newPosition,
        icon: userIcon,
        anchor: const Offset(0.5, 0.5),
        zIndexInt: 110,
      );
    });
  }

  Future<void> _addVendorMarker(
    Set<Marker> markers,
    VendorModel vendor,
    AppColorsExtension colors,
  ) async {
    if (vendor.location == null) return;

    final bool isSelected = vendor.id == _selectedVendorId;
    final cacheKey =
        'vendor_tap_pin_${_markerStyleVersion}_${vendor.id}_${vendor.vendorTypeEnum.name}';

    BitmapDescriptor markerIcon;
    if (_markerCache.containsKey(cacheKey)) {
      markerIcon = _markerCache[cacheKey]!;
    } else {
      try {
        final markerColor = _colorForVendorType(vendor.vendorTypeEnum, colors);
        final iconAsset = _iconAssetForVendorType(vendor.vendorTypeEnum);
        final fallbackIcon = _fallbackIconForVendorType(vendor.vendorTypeEnum);

        markerIcon = await CustomMapMarkers.createTapPinMarker(
          primaryColor: markerColor,
          iconAsset: iconAsset,
          fallbackIcon: fallbackIcon,
        );
        _markerCache[cacheKey] = markerIcon;
      } catch (e) {
        // Error creating marker for vendor
        markerIcon = BitmapDescriptor.defaultMarker;
      }
    }

    markers.add(
      Marker(
        markerId: MarkerId('vendor_${vendor.id}'),
        position: LatLng(vendor.location!.lat, vendor.location!.lng),
        icon: markerIcon,
        anchor: const Offset(0.5, 0.8),
        zIndexInt: isSelected ? 100 : 10,
        onTap: () => _onVendorMarkerTapped(vendor),
      ),
    );
  }

  List<VendorCluster> _clusterVendors(
    List<VendorModel> vendors,
    double zoomLevel,
  ) {
    final clusterDistance = _getClusterDistance(zoomLevel);

    final List<VendorCluster> clusters = [];
    final List<VendorModel> unclustered = List.from(vendors);
    while (unclustered.isNotEmpty) {
      final vendor = unclustered.removeAt(0);
      if (vendor.location == null) continue;
      final cluster = VendorCluster(
        center: LatLng(vendor.location!.lat, vendor.location!.lng),
        vendors: [vendor],
      );
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
        cluster.center = LatLng(
          totalLat / cluster.vendors.length,
          totalLng / cluster.vendors.length,
        );
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
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(cluster.center, _currentZoom + 2),
    );
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
    _sheetController = VendorDetailBottomSheet.show(
      context: context,
      vendor: vendor,
    );
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
    final Set<Marker> markers = _userMarker == null
        ? _vendorMarkers
        : <Marker>{..._vendorMarkers, _userMarker!};
    if (_mapController == null || markers.isEmpty) {
      return;
    }
    if (markers.length == 1) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(markers.first.position, 15),
      );
      return;
    }
    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLng = double.infinity;
    double maxLng = -double.infinity;
    for (final marker in markers) {
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

  void _centerOnUser() {
    if (_currentPosition == null || _mapController == null) return;
    _mapController!.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
        15,
      ),
    );
  }

  Widget _buildFilterChips(
    VendorProvider provider,
    AppColorsExtension colors,
    bool isDark,
  ) {
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
            onTap: () => provider.setMaxDistance(
              provider.maxDistance == null ? 5.0 : null,
            ),
            colors: colors,
            isDark: isDark,
          ),
          _buildFilterChip(
            label: 'Top Rated',
            isSelected: provider.minRating != null,
            onTap: () =>
                provider.setMinRating(provider.minRating == null ? 4.5 : null),
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
            onTap: () =>
                provider.setPriceRange(provider.priceRange == 1 ? null : 1),
            colors: colors,
            isDark: isDark,
          ),
          _buildFilterChip(
            label: 'Mid',
            isSelected: provider.priceRange == 2,
            onTap: () =>
                provider.setPriceRange(provider.priceRange == 2 ? null : 2),
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
                color: Colors.black.withAlpha(10),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = context.appColors;

    if (vendorProvider.filteredVendors != _vendors) {
      _vendors = vendorProvider.filteredVendors;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _updateMarkers();
      });
    }

    return Scaffold(
      backgroundColor: colors.backgroundPrimary,
      body: Stack(
        children: [
          Positioned.fill(
            child: GoogleMap(
              onMapCreated: _onMapCreated,
              onCameraMove: _onCameraMoveDebounced,
              initialCameraPosition: CameraPosition(
                target: _currentPosition != null
                    ? LatLng(
                        _currentPosition!.latitude,
                        _currentPosition!.longitude,
                      )
                    : const LatLng(5.6037, -0.1870),
                zoom: 13,
              ),
              markers: _userMarker == null
                  ? _vendorMarkers
                  : <Marker>{..._vendorMarkers, _userMarker!},
              rotateGesturesEnabled: false,
              scrollGesturesEnabled: true,
              zoomGesturesEnabled: true,
              tiltGesturesEnabled: false,
              indoorViewEnabled: false,
              trafficEnabled: false,
              buildingsEnabled: false,
              liteModeEnabled: false,
              polylines: _polylines,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              compassEnabled: false,
              mapType: MapType.normal,
              style: GrabGoMapStyles.forBrightness(
                Theme.of(context).brightness,
              ),
            ),
          ),

          if (_isLoading)
            const Positioned.fill(
              child: IgnorePointer(child: PickupMapSkeleton()),
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
                    width: double.infinity,
                    height: 48.h,
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    decoration: BoxDecoration(
                      color: colors.backgroundPrimary,
                      borderRadius: BorderRadius.circular(30.r),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(10),
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
                          colorFilter: ColorFilter.mode(
                            colors.textPrimary,
                            BlendMode.srcIn,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Text(
                          'Search stores and restaurants',
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 12.h),

                _buildFilterChips(vendorProvider, colors, isDark),

                SizedBox(height: 12.h),

                Padding(
                  padding: EdgeInsets.only(right: 16.w),
                  child: _buildMapControlButton(
                    icon: Assets.icons.sendDiagonal,
                    onTap: _centerOnUser,
                    colors: colors,
                    isDark: isDark,
                  ),
                ),
                SizedBox(height: 8.h),
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

          if (_hasAttemptedVendorFetch &&
              !_isLoading &&
              _errorMessage == null &&
              _vendors.isEmpty)
            Positioned(
              left: 20.w,
              right: 20.w,
              bottom: 120.h,
              child: Container(
                padding: EdgeInsets.all(18.r),
                decoration: BoxDecoration(
                  color: colors.backgroundPrimary,
                  borderRadius: BorderRadius.circular(16.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(isDark ? 45 : 18),
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
                          padding: EdgeInsets.all(10.r),
                          decoration: BoxDecoration(
                            color: colors.accentOrange.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.map_outlined,
                            color: colors.accentOrange,
                            size: 22.r,
                          ),
                        ),
                        SizedBox(width: 14.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'GrabGo is Not Here Yet',
                                style: TextStyle(
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w700,
                                  color: colors.textPrimary,
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                "We haven't launched in this area yet.",
                                style: TextStyle(
                                  fontSize: 12.5.sp,
                                  color: colors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 14.h),
                    AppButton(
                      width: double.infinity,
                      onPressed: () => context.push('/confirm-address'),
                      backgroundColor: colors.accentOrange,
                      borderRadius: KBorderSize.borderMedium,
                      buttonText: 'Change Location',
                      textStyle: TextStyle(
                        fontSize: 14.5.sp,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          if (_errorMessage != null && !_isLoading)
            Center(
              child: Container(
                margin: EdgeInsets.symmetric(horizontal: 32.w),
                padding: EdgeInsets.all(16.r),
                decoration: BoxDecoration(
                  color: colors.backgroundPrimary,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_errorMessage!, textAlign: TextAlign.center),
                    TextButton(
                      onPressed: _loadVendors,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
        ],
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
