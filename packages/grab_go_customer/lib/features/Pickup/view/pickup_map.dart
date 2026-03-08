import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:grab_go_customer/features/Pickup/model/pickup_route_data.dart';
import 'package:grab_go_customer/features/Pickup/service/pickup_route_service.dart';
import 'package:grab_go_customer/features/Pickup/widgets/vendor_details_bottom_sheet.dart';
import 'package:grab_go_customer/features/vendors/model/vendor_model.dart';
import 'package:grab_go_customer/features/vendors/model/vendor_type.dart';
import 'package:grab_go_customer/features/vendors/viewmodel/vendor_provider.dart';
import 'package:grab_go_customer/shared/services/connectivity_service.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_shared/shared/widgets/custom_map_markers.dart';
import 'package:grab_go_customer/shared/viewmodels/native_location_provider.dart';
import 'package:grab_go_customer/shared/widgets/no_internet_screen.dart';
import 'package:grab_go_customer/shared/widgets/pickup_map_skeleton.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:url_launcher/url_launcher.dart';

class PickupMap extends StatefulWidget {
  const PickupMap({super.key});

  @override
  State<PickupMap> createState() => _PickupMapState();
}

class _PickupMapState extends State<PickupMap> {
  static const String _markerStyleVersion = 'v3';
  static const double _routeRefreshDistanceMeters = 30;
  static const int _nearbyRouteDistanceThresholdMeters = 120;
  static const Duration _routeRefreshMinInterval = Duration(seconds: 8);
  static const int _maxMarkerCacheEntries = 96;
  GoogleMapController? _mapController;
  List<VendorModel> _vendors = [];
  List<VendorCluster> _clusters = [];
  bool _isLoading = true;
  PersistentBottomSheetController? _sheetController;
  String? _selectedVendorId;
  String? _errorMessage;
  bool _hasAttemptedVendorFetch = false;
  bool _hasNoInternet = false;
  Position? _currentPosition;
  StreamSubscription<Position>? _positionSubscription;
  Set<Marker> _vendorMarkers = {};
  Marker? _userMarker;
  Set<Polyline> _polylines = {};
  final Map<String, BitmapDescriptor> _markerCache = {};
  final PickupRouteService _pickupRouteService = PickupRouteService();
  Timer? _debounceTimer;
  Timer? _cameraMoveDebounce;
  CameraPosition? _lastCameraPosition;
  LatLngBounds? _lastLoadedBounds;
  double _currentZoom = 14;
  double? _lastLat;
  double? _lastLng;
  LatLng? _lastUserMarkerPosition;
  bool _pendingLocationUpdate = false;
  PickupRouteData? _activeRouteData;
  List<LatLng> _activeRoutePoints = const [];
  bool _isRouteLoading = false;
  String? _routeStatusMessage;
  DateTime? _lastRouteRequestStartedAt;
  LatLng? _lastRouteOrigin;
  int _routeRequestSerial = 0;

  void _putMarkerInCache(String key, BitmapDescriptor icon) {
    if (_markerCache.length >= _maxMarkerCacheEntries &&
        !_markerCache.containsKey(key)) {
      _markerCache.remove(_markerCache.keys.first);
    }
    _markerCache[key] = icon;
  }

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

  bool _looksLikeConnectivityFailure(String? message) {
    final value = (message ?? '').toLowerCase();
    return value.contains('socketexception') ||
        value.contains('failed host lookup') ||
        value.contains('connection refused') ||
        value.contains('network is unreachable') ||
        value.contains('timed out') ||
        value.contains('connection reset');
  }

  Future<void> _handleVendorLoadFailure(Object error) async {
    final message = error.toString();
    final looksOffline = _looksLikeConnectivityFailure(message);
    final hasInternet = looksOffline
        ? false
        : await ConnectivityService.hasInternetConnection();

    if (!mounted) return;

    setState(() {
      _hasNoInternet = !hasInternet;
      _errorMessage = hasInternet
          ? 'Unable to load pickup vendors right now.'
          : null;
      _isLoading = false;
      _hasAttemptedVendorFetch = true;
    });
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

        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (!mounted) {
            _pendingLocationUpdate = false;
            return;
          }
          setState(() {
            _currentPosition = nextPosition;
          });
          if (oldLat != null && oldLng != null) {
            _clearActiveRoute(closeSheet: true);
          }
          if (oldLat != null && oldLng != null && _mapController != null) {
            _mapController!.animateCamera(
              CameraUpdate.newLatLngZoom(LatLng(_lastLat!, _lastLng!), 14),
            );
          }
          await _updateUserMarker();
          await _loadVendors();
          _pendingLocationUpdate = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        await _initPosition();
        await _loadVendors();
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
      final position = await Geolocator.getCurrentPosition(
        locationSettings: AndroidSettings(
          accuracy: LocationAccuracy.medium,
          intervalDuration: const Duration(seconds: 5),
          distanceFilter: 20,
        ),
      );

      if (mounted) {
        setState(() => _currentPosition = position);
        _mapController?.animateCamera(
          CameraUpdate.newLatLng(LatLng(position.latitude, position.longitude)),
        );
        await _updateUserMarker();
      }
    } catch (e) {
      // Handle error quietly
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
            _maybeRefreshActiveRouteForLocationChange();
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
      _hasNoInternet = false;
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
        await _handleVendorLoadFailure(vendorProvider.error!);
        return;
      }

      setState(() {
        _vendors = vendorProvider.filteredVendors
            .where((v) => _isValidLatLng(v.location?.lat, v.location?.lng))
            .toList();
        _isLoading = false;
      });

      _syncSelectionWithVisibleVendors();
      await _updateMarkers();
      _fitCameraToMarkers();
    } catch (e) {
      await _handleVendorLoadFailure(e);
    }
  }

  void _onCameraMove(CameraPosition position) {
    final oldZoom = _currentZoom;
    _currentZoom = position.zoom;

    if (_currentZoom < 14.0 &&
        _userMarker != null &&
        _selectedVendorId == null) {
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
      _syncSelectionWithVisibleVendors();
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
              'cluster_tap_pin_${_markerStyleVersion}_${dominantType.name}';

          BitmapDescriptor markerIcon;
          if (_markerCache.containsKey(cacheKey)) {
            markerIcon = _markerCache[cacheKey]!;
          } else {
            markerIcon = await CustomMapMarkers.createTapPinMarker(
              primaryColor: clusterColor,
              iconAsset: clusterIconAsset,
              fallbackIcon: clusterFallbackIcon,
            );
            _putMarkerInCache(cacheKey, markerIcon);
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
    if (_activeRoutePoints.length >= 2) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('selected_vendor_route'),
          points: _activeRoutePoints,
          color: colors.accentOrange.withValues(alpha: 0.94),
          width: 6,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
        ),
      );
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

  Future<void> _updateUserMarker({bool force = false}) async {
    if (!mounted || _currentPosition == null) return;
    final LatLng newPosition = LatLng(
      _currentPosition!.latitude,
      _currentPosition!.longitude,
    );

    if (!force && _userMarker != null && _lastUserMarkerPosition != null) {
      final distance = Geolocator.distanceBetween(
        _lastUserMarkerPosition!.latitude,
        _lastUserMarkerPosition!.longitude,
        newPosition.latitude,
        newPosition.longitude,
      );
      if (distance < 10) return;
    }

    _lastUserMarkerPosition = newPosition;

    final String userCacheKey = 'user_location_marker_$_markerStyleVersion';
    final colors = context.appColors;
    BitmapDescriptor userIcon;
    if (_markerCache.containsKey(userCacheKey)) {
      userIcon = _markerCache[userCacheKey]!;
    } else {
      userIcon = await CustomMapMarkers.createPersonLocationMarker(
        size: 120,
        primaryColor: colors.accentOrange,
      );
      _putMarkerInCache(userCacheKey, userIcon);
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
        _putMarkerInCache(cacheKey, markerIcon);
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

  Future<void> _onVendorMarkerTapped(VendorModel vendor) async {
    final isSameVendor = _selectedVendorId == vendor.id;

    if (isSameVendor &&
        _sheetController != null &&
        (_isRouteLoading || _activeRouteData != null)) {
      return;
    }

    if (isSameVendor && _activeRouteData != null) {
      _showVendorSheet(vendor);
      return;
    }

    setState(() {
      _selectedVendorId = vendor.id;
      if (!isSameVendor) {
        _activeRouteData = null;
        _activeRoutePoints = const [];
      }
    });
    _updateMarkers();

    if (_sheetController == null || !isSameVendor) {
      _showVendorSheet(vendor);
    }

    final origin = _resolveCurrentLatLng();
    if (origin == null) {
      if (mounted) {
        setState(() {
          _isRouteLoading = false;
        });
      }
      AppToastMessage.show(
        context: context,
        message: 'Enable location to preview a walking route.',
        backgroundColor: context.appColors.error,
      );
      return;
    }

    await _updateUserMarker(force: true);

    await _requestWalkingRoute(
      vendor: vendor,
      origin: origin,
      showLoading: !isSameVendor || _activeRoutePoints.isEmpty,
      clearExistingRoute: !isSameVendor,
      fitCamera: true,
    );
  }

  void _showVendorSheet(VendorModel vendor) {
    if (_sheetController != null) {
      _sheetController?.close();
      _sheetController = null;
    }
    final controller = VendorDetailBottomSheet.show(
      context: context,
      vendor: vendor,
    );
    _sheetController = controller;
    controller.closed.then((_) {
      if (mounted) {
        if (identical(_sheetController, controller)) {
          setState(() {
            _sheetController = null;
          });
        }
      }
    });
  }

  VendorModel? _findVendorById(String? vendorId) {
    if (vendorId == null) return null;
    return _vendors.cast<VendorModel?>().firstWhere(
      (vendor) => vendor?.id == vendorId,
      orElse: () => null,
    );
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
    _centerOnUserAndShowMarker();
  }

  Future<void> _centerOnUserAndShowMarker() async {
    final locationProvider = context.read<NativeLocationProvider>();

    Position? resolvedPosition = _currentPosition;
    if (resolvedPosition == null &&
        _isValidLatLng(locationProvider.latitude, locationProvider.longitude)) {
      resolvedPosition = Position(
        latitude: locationProvider.latitude!,
        longitude: locationProvider.longitude!,
        timestamp: DateTime.now(),
        accuracy: locationProvider.accuracy ?? 0,
        altitude: 0,
        heading: locationProvider.bearing ?? 0,
        speed: locationProvider.speed ?? 0,
        speedAccuracy: 0,
        altitudeAccuracy: 0,
        headingAccuracy: 0,
      );
    }

    resolvedPosition ??= await (() async {
      final nativeLocation = await locationProvider.getCurrentLocation();
      if (nativeLocation == null) return null;
      return Position(
        latitude: nativeLocation.latitude,
        longitude: nativeLocation.longitude,
        timestamp: nativeLocation.timestamp,
        accuracy: nativeLocation.accuracy,
        altitude: nativeLocation.altitude,
        heading: nativeLocation.bearing,
        speed: nativeLocation.speed,
        speedAccuracy: 0,
        altitudeAccuracy: 0,
        headingAccuracy: 0,
      );
    })();

    if (!mounted || resolvedPosition == null) return;

    setState(() {
      _currentPosition = resolvedPosition;
      _lastLat = resolvedPosition!.latitude;
      _lastLng = resolvedPosition.longitude;
    });

    await _updateUserMarker(force: true);
    _maybeRefreshActiveRouteForLocationChange(force: true);

    if (!mounted || _mapController == null) return;
    _mapController!.animateCamera(
      CameraUpdate.newLatLngZoom(
        LatLng(resolvedPosition.latitude, resolvedPosition.longitude),
        15,
      ),
    );
  }

  LatLng? _resolveCurrentLatLng() {
    if (_currentPosition != null) {
      return LatLng(_currentPosition!.latitude, _currentPosition!.longitude);
    }

    final locationProvider = context.read<NativeLocationProvider>();
    if (_isValidLatLng(locationProvider.latitude, locationProvider.longitude)) {
      return LatLng(locationProvider.latitude!, locationProvider.longitude!);
    }

    return null;
  }

  Future<void> _requestWalkingRoute({
    required VendorModel vendor,
    required LatLng origin,
    required bool showLoading,
    required bool clearExistingRoute,
    required bool fitCamera,
  }) async {
    if (vendor.location == null) return;

    final requestSerial = ++_routeRequestSerial;
    _lastRouteRequestStartedAt = DateTime.now();
    _lastRouteOrigin = origin;

    if (mounted) {
      setState(() {
        _selectedVendorId = vendor.id;
        if (clearExistingRoute) {
          _activeRouteData = null;
          _activeRoutePoints = const [];
        }
        _routeStatusMessage = null;
        _isRouteLoading = showLoading;
      });
    }
    if (clearExistingRoute) {
      _updateMarkers();
    }

    try {
      final route = await _pickupRouteService.fetchWalkingRoute(
        originLat: origin.latitude,
        originLng: origin.longitude,
        destinationLat: vendor.location!.lat,
        destinationLng: vendor.location!.lng,
      );

      if (!mounted ||
          requestSerial != _routeRequestSerial ||
          _selectedVendorId != vendor.id) {
        return;
      }

      final routePoints = _decodeRoutePoints(route.polyline);
      if (routePoints.length < 2) {
        throw Exception('Walking route was empty');
      }

      setState(() {
        _activeRouteData = route;
        _activeRoutePoints = routePoints;
        _routeStatusMessage = null;
        _isRouteLoading = false;
      });
      await _updateMarkers();

      if (fitCamera) {
        _fitCameraToRoute(routePoints);
      }
    } catch (error) {
      if (!mounted ||
          requestSerial != _routeRequestSerial ||
          _selectedVendorId != vendor.id) {
        return;
      }

      final message = _normalizeRouteError(error);
      setState(() {
        _activeRouteData = null;
        _activeRoutePoints = const [];
        _routeStatusMessage = message;
        _isRouteLoading = false;
      });
      await _updateMarkers();

      AppToastMessage.show(
        context: context,
        message: message,
        backgroundColor: context.appColors.error,
      );
    }
  }

  List<LatLng> _decodeRoutePoints(String encodedPolyline) {
    final polylinePoints = PolylinePoints();
    final decoded = polylinePoints.decodePolyline(encodedPolyline);
    return decoded
        .map((point) => LatLng(point.latitude, point.longitude))
        .toList();
  }

  void _fitCameraToRoute(List<LatLng> points) {
    if (_mapController == null || points.isEmpty) return;

    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLng = double.infinity;
    double maxLng = -double.infinity;

    for (final point in points) {
      minLat = point.latitude < minLat ? point.latitude : minLat;
      maxLat = point.latitude > maxLat ? point.latitude : maxLat;
      minLng = point.longitude < minLng ? point.longitude : minLng;
      maxLng = point.longitude > maxLng ? point.longitude : maxLng;
    }

    if (minLat == maxLat && minLng == maxLng) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(points.first, 16),
      );
      return;
    }

    const padding = 0.0012;
    final bounds = LatLngBounds(
      southwest: LatLng(minLat - padding, minLng - padding),
      northeast: LatLng(maxLat + padding, maxLng + padding),
    );
    _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80.w));
  }

  void _maybeRefreshActiveRouteForLocationChange({bool force = false}) {
    final selectedVendor = _findVendorById(_selectedVendorId);
    final origin = _resolveCurrentLatLng();

    if (selectedVendor == null ||
        selectedVendor.location == null ||
        origin == null) {
      return;
    }

    if (!force) {
      if (_lastRouteOrigin == null || _lastRouteRequestStartedAt == null) {
        return;
      }

      final movedDistance = Geolocator.distanceBetween(
        _lastRouteOrigin!.latitude,
        _lastRouteOrigin!.longitude,
        origin.latitude,
        origin.longitude,
      );

      if (movedDistance < _routeRefreshDistanceMeters) {
        return;
      }

      final elapsed = DateTime.now().difference(_lastRouteRequestStartedAt!);
      if (elapsed < _routeRefreshMinInterval) {
        return;
      }
    }

    _requestWalkingRoute(
      vendor: selectedVendor,
      origin: origin,
      showLoading: false,
      clearExistingRoute: false,
      fitCamera: false,
    );
  }

  void _clearActiveRoute({bool closeSheet = false}) {
    final hadSelection =
        _selectedVendorId != null ||
        _activeRoutePoints.isNotEmpty ||
        _isRouteLoading;
    _routeRequestSerial++;
    if (!mounted || !hadSelection) return;

    setState(() {
      _selectedVendorId = null;
      _activeRouteData = null;
      _activeRoutePoints = const [];
      _routeStatusMessage = null;
      _isRouteLoading = false;
      _lastRouteOrigin = null;
      _lastRouteRequestStartedAt = null;
    });

    if (closeSheet && _sheetController != null) {
      _sheetController?.close();
      _sheetController = null;
    }

    _updateMarkers();
  }

  void _syncSelectionWithVisibleVendors() {
    if (_selectedVendorId == null) return;
    final stillVisible = _vendors.any(
      (vendor) => vendor.id == _selectedVendorId,
    );
    if (!stillVisible) {
      _clearActiveRoute(closeSheet: true);
    }
  }

  String _formatRouteDistance(int distanceMeters) {
    if (distanceMeters >= 1000) {
      return '${(distanceMeters / 1000).toStringAsFixed(distanceMeters >= 10000 ? 0 : 1)} km';
    }
    return '$distanceMeters m';
  }

  String _formatRouteDuration(int durationSeconds) {
    final totalMinutes = (durationSeconds / 60).ceil();
    if (totalMinutes < 60) {
      return '$totalMinutes min';
    }

    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    if (minutes == 0) {
      return '$hours hr';
    }
    return '$hours hr $minutes min';
  }

  String _normalizeRouteError(Object error) {
    var message = error.toString().trim();
    const exceptionPrefix = 'Exception: ';
    const routePrefix = 'Failed to load walking route: ';

    if (message.startsWith(exceptionPrefix)) {
      message = message.substring(exceptionPrefix.length).trim();
    }
    if (message.startsWith(routePrefix)) {
      message = message.substring(routePrefix.length).trim();
    }
    if (message.isEmpty) {
      return 'Unable to load walking route right now.';
    }
    return message;
  }

  bool get _hasNearbyRoute =>
      _activeRouteData != null &&
      _activeRouteData!.distanceMeters <= _nearbyRouteDistanceThresholdMeters;

  bool get _shouldShowRouteChip =>
      _isRouteLoading ||
      _activeRouteData != null ||
      (_routeStatusMessage != null && _routeStatusMessage!.trim().isNotEmpty);

  Future<void> _openExternalMaps() async {
    final selectedVendor = _findVendorById(_selectedVendorId);
    if (selectedVendor?.location == null) return;

    final origin = _resolveCurrentLatLng();
    final query = <String, String>{
      'api': '1',
      'destination':
          '${selectedVendor!.location!.lat},${selectedVendor.location!.lng}',
      'travelmode': 'walking',
    };
    if (origin != null) {
      query['origin'] = '${origin.latitude},${origin.longitude}';
    }

    final url = Uri.https('www.google.com', '/maps/dir/', query);

    try {
      final launched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && mounted) {
        AppToastMessage.show(
          context: context,
          message: 'Unable to open maps right now. Please try again.',
          backgroundColor: context.appColors.error,
        );
      }
    } catch (_) {
      if (!mounted) return;
      AppToastMessage.show(
        context: context,
        message: 'Unable to open maps right now. Please try again.',
        backgroundColor: context.appColors.error,
      );
    }
  }

  Widget _buildRouteChip(AppColorsExtension colors, bool isDark) {
    final hasRoute = _activeRouteData != null;
    final hasIssue =
        !hasRoute &&
        !_isRouteLoading &&
        _routeStatusMessage != null &&
        _routeStatusMessage!.trim().isNotEmpty;
    final title = _isRouteLoading
        ? 'Finding walking route'
        : hasRoute
        ? (_hasNearbyRoute ? 'Vendor nearby' : 'Walking route')
        : 'Walking route unavailable';
    final label = _isRouteLoading
        ? null
        : hasRoute
        ? (_hasNearbyRoute
              ? 'About ${_formatRouteDistance(_activeRouteData!.distanceMeters)} away'
              : '${_formatRouteDuration(_activeRouteData!.durationSeconds)} • ${_formatRouteDistance(_activeRouteData!.distanceMeters)}')
        : _routeStatusMessage!;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 11.h),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withAlpha(35)
                : Colors.black.withAlpha(12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 30.w,
            height: 30.w,
            padding: EdgeInsets.all(6.w),
            decoration: BoxDecoration(
              color: hasIssue
                  ? colors.error.withValues(alpha: 0.12)
                  : colors.accentOrange.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: SvgPicture.asset(
              Assets.icons.running,
              package: 'grab_go_shared',
              height: 18.h,
              width: 18.h,
              colorFilter: ColorFilter.mode(
                hasIssue ? colors.error : colors.accentOrange,
                BlendMode.srcIn,
              ),
            ),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: _isRouteLoading
                ? Shimmer.fromColors(
                    baseColor: colors.border.withValues(alpha: 0.6),
                    highlightColor: colors.backgroundSecondary,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 118.w,
                          height: 11.h,
                          decoration: BoxDecoration(
                            color: colors.backgroundSecondary,
                            borderRadius: BorderRadius.circular(999.r),
                          ),
                        ),
                        SizedBox(height: 6.h),
                        Container(
                          width: 172.w,
                          height: 10.h,
                          decoration: BoxDecoration(
                            color: colors.backgroundSecondary,
                            borderRadius: BorderRadius.circular(999.r),
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        label!,
                        style: TextStyle(
                          fontSize: 11.5.sp,
                          fontWeight: FontWeight.w500,
                          color: hasIssue ? colors.error : colors.textSecondary,
                        ),
                      ),
                    ],
                  ),
          ),
          if (!_isRouteLoading)
            IconButton(
              onPressed: _openExternalMaps,
              icon: SvgPicture.asset(
                Assets.icons.map,
                package: 'grab_go_shared',
                height: 18.h,
                width: 18.h,
                colorFilter: ColorFilter.mode(
                  colors.textSecondary,
                  BlendMode.srcIn,
                ),
              ),
            ),
          if (!_isRouteLoading)
            IconButton(
              onPressed: _clearActiveRoute,
              icon: SvgPicture.asset(
                Assets.icons.xmark,
                package: 'grab_go_shared',
                height: 18.h,
                width: 18.h,
                colorFilter: ColorFilter.mode(
                  colors.textSecondary,
                  BlendMode.srcIn,
                ),
              ),
            ),
        ],
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

    if (_hasNoInternet && !_isLoading) {
      return Scaffold(
        backgroundColor: colors.backgroundPrimary,
        body: NoInternetScreen(onRetry: _loadVendors),
      );
    }

    if (vendorProvider.filteredVendors != _vendors) {
      _vendors = vendorProvider.filteredVendors;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _syncSelectionWithVisibleVendors();
          _updateMarkers();
        }
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
              onTap: (_) => _clearActiveRoute(closeSheet: true),
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
              myLocationEnabled: false,
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

                if (_shouldShowRouteChip)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.w),
                    child: _buildRouteChip(colors, isDark),
                  ),

                if (_shouldShowRouteChip) SizedBox(height: 12.h),

                Padding(
                  padding: EdgeInsets.only(right: 16.w),
                  child: _buildMapControlButton(
                    icon: Assets.icons.crosshair,
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
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
