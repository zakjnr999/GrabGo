import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_shared/shared/widgets/custom_map_markers.dart';
import '../models/tracking_models.dart';
import '../service/tracking_api_service.dart';
import '../service/tracking_socket_service.dart';
import 'base_tracking_provider.dart';

/// Provider for managing tracking state and real-time updates
class TrackingProvider extends BaseTrackingProvider {
  final TrackingApiService _apiService;
  final TrackingSocketService _socketService;

  // State
  TrackingData? _trackingData;
  String? _activeOrderId;
  bool _isLoading = false;
  String? _error;
  bool _isWaitingForRider = false;

  // Map elements
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  Set<Circle> _circles = {};
  GoogleMapController? _mapController;

  // Geofence radius in meters
  static const double _geofenceRadius = 50.0;

  // Animation constants for smooth movement
  static const int _animationDurationMs = 1500; // Total animation duration
  static const int _animationFrameMs = 16; // ~60fps
  static const int _animationSteps = _animationDurationMs ~/ _animationFrameMs;
  static const int _maxLocationHistoryPoints = 300;

  // Subscriptions
  StreamSubscription? _locationSubscription;
  StreamSubscription? _statusSubscription;
  StreamSubscription? _connectionSubscription;
  Timer? _animationTimer;
  Timer? _waitingForRiderTimer;
  LatLng? _lastKnownPosition;
  double _currentBearing = 0;
  final Map<String, BitmapDescriptor> _markerIconCache = {};

  // Getters
  @override
  TrackingData? get trackingData => _trackingData;
  @override
  bool get isLoading => _isLoading;
  @override
  String? get error => _error;
  bool get isWaitingForRider => _isWaitingForRider;
  @override
  Set<Marker> get markers => _markers;
  @override
  Set<Polyline> get polylines => _polylines;
  @override
  Set<Circle> get circles => _circles;
  @override
  bool get isSocketConnected => _socketService.isConnected;

  TrackingProvider({
    required TrackingApiService apiService,
    required TrackingSocketService socketService,
  }) : _apiService = apiService,
       _socketService = socketService {
    _initializeSocketListeners();
  }

  /// Initialize socket event listeners
  void _initializeSocketListeners() {
    _locationSubscription = _socketService.locationUpdates.listen(
      _handleLocationUpdate,
      onError: (error) {
        print('❌ Location update error: $error');
      },
    );

    _statusSubscription = _socketService.statusUpdates.listen(
      _handleStatusUpdate,
      onError: (error) {
        print('❌ Status update error: $error');
      },
    );

    _connectionSubscription = _socketService.connectionStatus.listen((
      isConnected,
    ) {
      print(isConnected ? '✅ Socket connected' : '❌ Socket disconnected');
      if (isConnected && _activeOrderId != null) {
        _socketService.joinOrderRoom(_activeOrderId!);
      }
    });
  }

  /// Initialize tracking for an order
  @override
  Future<void> initializeTracking(String orderId) async {
    _activeOrderId = orderId;
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // 1. Get initial tracking data from API
      print('📡 Fetching tracking data for order: $orderId');
      _trackingData = await _apiService.getTrackingInfo(orderId);
      print(
        '✅ Got tracking data: status=${_trackingData?.status}, rider=${_trackingData?.rider?.name}',
      );
      _isWaitingForRider = false;
      _stopWaitingForRiderPolling();

      // 2. Connect to socket for real-time updates
      print('🔌 Connecting to socket');
      _socketService.connect();

      // 3. Wait for socket to connect, then join order room
      _waitForSocketAndJoinRoom(orderId);

      // 4. Setup map elements
      await _setupMapElements();

      _isLoading = false;
      _error = null;
      notifyListeners();

      print('✅ Tracking initialized successfully');
    } on TrackingException catch (e) {
      // Handle specific tracking errors
      if (e.statusCode == 404) {
        // Tracking not initialized yet - rider hasn't accepted the order
        _error = 'Waiting for a rider to accept your order...';
        _isWaitingForRider = true;
        _startWaitingForRiderPolling(orderId);
      } else {
        _error = e.message;
        _isWaitingForRider = false;
        _stopWaitingForRiderPolling();
      }
      _isLoading = false;
      notifyListeners();
      print('❌ Failed to initialize tracking: $e');
    } catch (e) {
      _error = e.toString();
      _isWaitingForRider = false;
      _stopWaitingForRiderPolling();
      _isLoading = false;
      notifyListeners();
      print('❌ Failed to initialize tracking: $e');
    }
  }

  void _startWaitingForRiderPolling(String orderId) {
    _waitingForRiderTimer?.cancel();
    _waitingForRiderTimer = Timer.periodic(const Duration(seconds: 8), (
      _,
    ) async {
      if (!_isWaitingForRider || _trackingData != null) {
        _stopWaitingForRiderPolling();
        return;
      }

      try {
        final data = await _apiService.getTrackingInfo(orderId);
        _trackingData = data;
        _isWaitingForRider = false;
        _error = null;
        _isLoading = false;
        _stopWaitingForRiderPolling();

        if (!_socketService.isConnected) {
          _socketService.connect();
        }
        _waitForSocketAndJoinRoom(orderId);
        await _setupMapElements();
        notifyListeners();
      } on TrackingException catch (e) {
        // Keep polling while tracking is not available yet.
        if (e.statusCode != 404) {
          _error = e.message;
          notifyListeners();
        }
      } catch (_) {
        // Ignore transient polling errors and retry on next cycle.
      }
    });
  }

  void _stopWaitingForRiderPolling() {
    _waitingForRiderTimer?.cancel();
    _waitingForRiderTimer = null;
  }

  /// Wait for socket connection and then join the order room
  void _waitForSocketAndJoinRoom(String orderId) {
    // If already connected, join immediately
    if (_socketService.isConnected) {
      print('🚪 Socket already connected, joining order room: $orderId');
      _socketService.joinOrderRoom(orderId);
      return;
    }

    // Otherwise wait for connection
    print('⏳ Waiting for socket connection...');
    StreamSubscription<bool>? subscription;
    subscription = _socketService.connectionStatus.listen((isConnected) {
      if (isConnected) {
        print('🚪 Socket connected, joining order room: $orderId');
        _socketService.joinOrderRoom(orderId);
        subscription?.cancel();
      }
    });

    // Cancel subscription after 10 seconds to avoid memory leak
    Future.delayed(const Duration(seconds: 10), () {
      subscription?.cancel();
    });
  }

  /// Setup markers and polylines on the map
  Future<void> _setupMapElements() async {
    if (_trackingData == null) return;

    final markers = <Marker>{};

    // Add rider marker if location available
    if (_trackingData!.currentLocation != null) {
      final cacheKey =
          'rider_${_trackingData!.rider?.id}_${_trackingData!.rider?.profileImage}';
      if (!_markerIconCache.containsKey(cacheKey)) {
        _markerIconCache[cacheKey] = await CustomMapMarkers.createRiderMarker(
          imageUrl: _trackingData!.rider?.profileImage,
          name: _trackingData!.rider?.name ?? 'Rider',
          primaryColor: AppColors.serviceFood,
        );
      }

      final riderMarker = Marker(
        markerId: const MarkerId('rider'),
        position: _trackingData!.currentLocation!.toLatLng(),
        icon: _markerIconCache[cacheKey]!,
        infoWindow: InfoWindow(
          title: _trackingData!.rider?.name ?? 'Your Rider',
          snippet: _trackingData!.statusText,
        ),
        anchor: const Offset(0.5, 0.5),
        zIndexInt: 10, // Bring rider to the very top
      );
      markers.add(riderMarker);
    }

    // Add destination marker (customer's home) with home icon
    if (!_markerIconCache.containsKey('destination')) {
      _markerIconCache['destination'] =
          await CustomMapMarkers.createDestinationMarker(
            name: 'You',
            primaryColor: AppColors.serviceGrocery,
          );
    }

    markers.add(
      Marker(
        markerId: const MarkerId('destination'),
        position: _trackingData!.destination.toLatLng(),
        icon: _markerIconCache['destination']!,
        infoWindow: const InfoWindow(title: 'You', snippet: 'Delivery Address'),
        anchor: const Offset(0.5, 0.5),
        zIndexInt: 5, // Below rider, above vendor
      ),
    );

    // Add pickup location marker if available
    if (_trackingData!.pickupLocation != null) {
      if (!_markerIconCache.containsKey('vendor')) {
        _markerIconCache['vendor'] = await CustomMapMarkers.createStoreMarker(
          name: 'Vendor',
          primaryColor: AppColors.serviceFood,
        );
      }

      markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: _trackingData!.pickupLocation!.toLatLng(),
          icon: _markerIconCache['vendor']!,
          infoWindow: const InfoWindow(
            title: 'Restaurant',
            snippet: 'Pickup location',
          ),
          anchor: const Offset(0.5, 0.5),
          zIndexInt: 1, // Bottom layer
        ),
      );
    }

    _markers = markers;

    // Setup geofence circles
    _setupGeofenceCircles();

    // Create polyline from route if available
    if (_trackingData!.route != null &&
        _trackingData!.route!.polyline.isNotEmpty) {
      await _createPolyline(_trackingData!.route!.polyline);
    }

    // Animate camera to show all markers
    _animateCameraToFitMarkers();

    notifyListeners();
  }

  /// Setup geofence circles around pickup and destination
  void _setupGeofenceCircles() {
    if (_trackingData == null) return;

    final circles = <Circle>{};
    const pickupColor = AppColors.serviceFood;
    const deliveryColor = AppColors.serviceGrocery;

    // Pickup geofence circle
    if (_trackingData!.pickupLocation != null) {
      circles.add(
        Circle(
          circleId: const CircleId('pickup_geofence'),
          center: _trackingData!.pickupLocation!.toLatLng(),
          radius: _geofenceRadius,
          fillColor: pickupColor.withValues(alpha: 0.15),
          strokeColor: pickupColor.withValues(alpha: 0.5),
          strokeWidth: 2,
        ),
      );
    }

    // Destination geofence circle (customer's home)
    circles.add(
      Circle(
        circleId: const CircleId('destination_geofence'),
        center: _trackingData!.destination.toLatLng(),
        radius: _geofenceRadius,
        fillColor: deliveryColor.withValues(alpha: 0.15),
        strokeColor: deliveryColor.withValues(alpha: 0.5),
        strokeWidth: 2,
      ),
    );

    _circles = circles;
  }

  /// Get custom rider marker icon with caching
  Future<BitmapDescriptor> _getRiderMarkerIcon() async {
    final cacheKey =
        'rider_${_trackingData?.rider?.id}_${_trackingData?.rider?.profileImage}';
    if (_markerIconCache.containsKey(cacheKey)) {
      return _markerIconCache[cacheKey]!;
    }

    final icon = await CustomMapMarkers.createRiderMarker(
      imageUrl: _trackingData?.rider?.profileImage,
      name: _trackingData?.rider?.name ?? 'Rider',
      primaryColor: AppColors.serviceFood,
    );

    _markerIconCache[cacheKey] = icon;
    return icon;
  }

  /// Create polyline from encoded string
  Future<void> _createPolyline(String encodedPolyline) async {
    try {
      final polylinePoints = PolylinePoints();
      final decoded = polylinePoints.decodePolyline(encodedPolyline);

      final polylineCoordinates = decoded
          .map((point) => LatLng(point.latitude, point.longitude))
          .toList();

      final routePolyline = Polyline(
        polylineId: const PolylineId('route'),
        points: polylineCoordinates,
        color: AppColors.serviceFood.withValues(alpha: 0.3),
        width: 4,
        patterns: [PatternItem.dash(15), PatternItem.gap(10)],
      );

      _polylines.removeWhere((p) => p.polylineId.value == 'route');
      _polylines.add(routePolyline);
    } catch (e) {
      print('❌ Error creating polyline: $e');
    }
  }

  /// Handle real-time location updates from socket
  void _handleLocationUpdate(LocationUpdateEvent event) {
    if (_trackingData == null || event.orderId != _trackingData!.orderId) {
      return;
    }

    print(
      '📍 Updating rider location: ${event.location.latitude}, ${event.location.longitude}',
    );

    // Add current location to history for the trail
    final updatedHistory = List<LocationHistory>.from(
      _trackingData!.locationHistory,
    );
    updatedHistory.add(
      LocationHistory(location: event.location, timestamp: DateTime.now()),
    );
    if (updatedHistory.length > _maxLocationHistoryPoints) {
      updatedHistory.removeRange(
        0,
        updatedHistory.length - _maxLocationHistoryPoints,
      );
    }

    // Update tracking data
    _trackingData = TrackingData(
      orderId: _trackingData!.orderId,
      currentLocation: event.location,
      destination: _trackingData!.destination,
      pickupLocation: _trackingData!.pickupLocation,
      status: event.status,
      distanceRemaining: event.distance,
      estimatedArrival: event.eta,
      route: _trackingData!.route,
      rider: _trackingData!.rider,
      locationHistory: updatedHistory,
    );

    final newPosition = event.location.toLatLng();

    // Start smooth animation from old to new position
    if (_lastKnownPosition != null) {
      // Calculate distance between last and new position
      final distance = _calculateDistance(_lastKnownPosition!, newPosition);

      // If distance is too large (>500m), jump directly (could be GPS error or teleport)
      if (distance > 500) {
        print(
          '📍 Large position jump detected (${distance.toStringAsFixed(0)}m), jumping directly',
        );
        _updateRiderMarker(newPosition, _currentBearing);
        _lastKnownPosition = newPosition;
        notifyListeners();
        return;
      }

      // Calculate bearing from last position to new one
      double bearing = _calculateBearing(_lastKnownPosition!, newPosition);
      _animateMarkerMovement(_lastKnownPosition!, newPosition, bearing);
    } else {
      _updateRiderMarker(newPosition, 0);
      notifyListeners();
    }

    _lastKnownPosition = newPosition;

    // Update trail
    _updateLocationHistoryPolyline();

    // Only animate camera if not already following (to avoid jerky movement)
    // Camera will follow naturally during marker animation
  }

  /// Smoothly animate marker from one position to another with easing
  void _animateMarkerMovement(LatLng start, LatLng end, double targetBearing) {
    _animationTimer?.cancel();

    int currentStep = 0;
    final double startBearing = _currentBearing;

    // Calculate the shortest rotation path
    double bearingDiff = targetBearing - startBearing;
    if (bearingDiff > 180) bearingDiff -= 360;
    if (bearingDiff < -180) bearingDiff += 360;

    _animationTimer = Timer.periodic(
      const Duration(milliseconds: _animationFrameMs),
      (timer) {
        if (currentStep >= _animationSteps) {
          timer.cancel();
          // Ensure we end exactly at the target position
          _updateRiderMarker(end, targetBearing);
          _currentBearing = targetBearing;
          // Smoothly move camera to final position
          _animateCameraToRider(end);
          notifyListeners();
          return;
        }

        currentStep++;

        // Use ease-out cubic for smooth deceleration: 1 - (1 - t)^3
        double t = currentStep / _animationSteps;
        double easedT = 1 - pow(1 - t, 3).toDouble();

        // Interpolate position
        double lat = start.latitude + (end.latitude - start.latitude) * easedT;
        double lng =
            start.longitude + (end.longitude - start.longitude) * easedT;

        // Interpolate bearing smoothly
        double currentBearingAnimated = startBearing + bearingDiff * easedT;
        _currentBearing = currentBearingAnimated;

        _updateRiderMarker(LatLng(lat, lng), currentBearingAnimated);

        // Only notify every 3rd frame to reduce UI rebuilds while maintaining visual smoothness
        if (currentStep % 3 == 0 || currentStep == _animationSteps) {
          notifyListeners();
        }
      },
    );
  }

  /// Calculate bearing between two points
  double _calculateBearing(LatLng start, LatLng end) {
    double lat1 = start.latitude * pi / 180;
    double lng1 = start.longitude * pi / 180;
    double lat2 = end.latitude * pi / 180;
    double lng2 = end.longitude * pi / 180;

    double dLng = lng2 - lng1;
    double y = sin(dLng) * cos(lat2);
    double x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLng);

    double bearing = atan2(y, x) * 180 / pi;
    return (bearing + 360) % 360;
  }

  /// Calculate distance between two points in meters (Haversine formula)
  double _calculateDistance(LatLng start, LatLng end) {
    const double earthRadius = 6371000; // meters

    double lat1 = start.latitude * pi / 180;
    double lat2 = end.latitude * pi / 180;
    double dLat = (end.latitude - start.latitude) * pi / 180;
    double dLng = (end.longitude - start.longitude) * pi / 180;

    double a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLng / 2) * sin(dLng / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  /// Update location history (trail) on the map
  void _updateLocationHistoryPolyline() {
    if (_trackingData == null) return;

    final history = _trackingData!.locationHistory;
    if (history.isEmpty) return;

    final points = history.map((e) => e.location.toLatLng()).toList();
    if (_trackingData!.currentLocation != null) {
      points.add(_trackingData!.currentLocation!.toLatLng());
    }

    _polylines = _polylines
        .map((p) {
          if (p.polylineId.value == 'trail') return null;
          return p;
        })
        .whereType<Polyline>()
        .toSet();

    _polylines.add(
      Polyline(
        polylineId: const PolylineId('trail'),
        points: points,
        color: AppColors.serviceFood,
        width: 5,
      ),
    );
  }

  /// Handle status updates from socket
  void _handleStatusUpdate(StatusUpdateEvent event) {
    if (_trackingData == null || event.orderId != _trackingData!.orderId) {
      return;
    }

    print('📊 Status updated to: ${event.status}');

    _trackingData = TrackingData(
      orderId: _trackingData!.orderId,
      currentLocation: _trackingData!.currentLocation,
      destination: _trackingData!.destination,
      pickupLocation: _trackingData!.pickupLocation,
      status: event.status,
      distanceRemaining: _trackingData!.distanceRemaining,
      estimatedArrival: _trackingData!.estimatedArrival,
      route: _trackingData!.route,
      rider: _trackingData!.rider,
      locationHistory: _trackingData!.locationHistory,
    );

    notifyListeners();
  }

  /// Update rider marker position
  void _updateRiderMarker(LatLng newPosition, double rotation) {
    _markers = _markers.map((marker) {
      if (marker.markerId.value == 'rider') {
        return marker.copyWith(
          positionParam: newPosition,
          rotationParam: rotation,
        );
      }
      return marker;
    }).toSet();
  }

  @override
  void reCenterCamera() {
    _animateCameraToFitMarkers();
  }

  /// Animate camera to show all markers
  void _animateCameraToFitMarkers() {
    if (_mapController == null || _markers.isEmpty) return;

    final positions = _markers.map((m) => m.position).toList();
    if (positions.isEmpty) return;

    double minLat = positions.first.latitude;
    double maxLat = positions.first.latitude;
    double minLng = positions.first.longitude;
    double maxLng = positions.first.longitude;

    for (final pos in positions) {
      if (pos.latitude < minLat) minLat = pos.latitude;
      if (pos.latitude > maxLat) maxLat = pos.latitude;
      if (pos.longitude < minLng) minLng = pos.longitude;
      if (pos.longitude > maxLng) maxLng = pos.longitude;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
  }

  /// Animate camera to rider location smoothly
  void _animateCameraToRider(LatLng position) {
    // Use a gentler zoom level and smooth animation
    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: position,
          zoom: 16.0, // Closer zoom for better detail
          tilt: 45.0, // Slight tilt for 3D effect
          bearing: _currentBearing, // Rotate map to rider's direction
        ),
      ),
    );
  }

  /// Set map controller
  @override
  void setMapController(GoogleMapController controller) {
    _mapController = controller;
  }

  /// Refresh tracking data
  @override
  Future<void> refreshTracking() async {
    if (_trackingData == null) return;
    await initializeTracking(_trackingData!.orderId);
  }

  /// Stop tracking and cleanup
  @override
  void stopTracking() {
    final orderId = _trackingData?.orderId ?? _activeOrderId;
    if (orderId != null) {
      _socketService.leaveOrderRoom(orderId);
    }
    _socketService.disconnect();
    _activeOrderId = null;
    _trackingData = null;
    _isWaitingForRider = false;
    _stopWaitingForRiderPolling();
    _markers = {};
    _polylines = {};
    _markerIconCache.clear();
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _animationTimer?.cancel();
    _stopWaitingForRiderPolling();
    _locationSubscription?.cancel();
    _statusSubscription?.cancel();
    _connectionSubscription?.cancel();
    _markerIconCache.clear();
    _socketService.disconnect();
    _mapController?.dispose();
    super.dispose();
  }
}
