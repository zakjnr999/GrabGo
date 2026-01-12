import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:grab_go_shared/shared/widgets/custom_map_markers.dart';
import '../models/tracking_models.dart';
import '../service/mock_tracking_service.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'base_tracking_provider.dart';
import 'dart:async';
import 'dart:math';

/// Test provider that uses mock data instead of real API/Socket
class MockTrackingProvider extends BaseTrackingProvider {
  MockTrackingService? _mockService;
  final Map<String, BitmapDescriptor> _markerIconCache = {};

  TrackingData? _trackingData;
  bool _isLoading = false;
  String? _error;

  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  GoogleMapController? _mapController;
  Timer? _animationTimer;
  LatLng? _lastKnownPosition;

  // Getters
  @override
  TrackingData? get trackingData => _trackingData;
  @override
  bool get isLoading => _isLoading;
  @override
  String? get error => _error;
  @override
  Set<Marker> get markers => _markers;
  @override
  Set<Polyline> get polylines => _polylines;
  @override
  bool get isSocketConnected => true; // Always "connected" in test mode

  /// Initialize mock tracking
  @override
  Future<void> initializeTracking(String orderId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      print('🧪 Initializing MOCK tracking for order: $orderId');

      // Create mock service
      _mockService = MockTrackingService(
        onUpdate: (data) {
          _handleMockUpdate(data);
        },
      );

      // Start simulation
      _trackingData = _mockService!.startSimulation(orderId);

      // Setup map elements
      await _setupMapElements();

      _isLoading = false;
      notifyListeners();

      print('✅ Mock tracking initialized');
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      print('❌ Failed to initialize mock tracking: $e');
    }
  }

  void _handleMockUpdate(TrackingData data) {
    print('📡 Mock update received: ${data.status}, ${data.distanceInKm} km');
    _trackingData = data;

    _updateMapElements();

    // Start smooth animation
    if (_lastKnownPosition != null && data.currentLocation != null) {
      double bearing = _calculateBearing(_lastKnownPosition!, data.currentLocation!.toLatLng());
      _animateMarkerMovement(_lastKnownPosition!, data.currentLocation!.toLatLng(), bearing);
    }

    if (data.currentLocation != null) {
      _lastKnownPosition = data.currentLocation!.toLatLng();
    }

    // Update trail
    _updateLocationHistoryPolyline();

    notifyListeners();
  }

  /// Smoothly animate marker from one position to another
  void _animateMarkerMovement(LatLng start, LatLng end, double bearing) {
    _animationTimer?.cancel();

    int steps = 20;
    int currentStep = 0;

    _animationTimer = Timer.periodic(const Duration(milliseconds: 50), (timer) {
      if (currentStep >= steps) {
        timer.cancel();
        return;
      }

      currentStep++;
      double fraction = currentStep / steps;

      double lat = start.latitude + (end.latitude - start.latitude) * fraction;
      double lng = start.longitude + (end.longitude - start.longitude) * fraction;

      _updateRiderMarker(LatLng(lat, lng), bearing);
      notifyListeners();
    });
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

  void _updateRiderMarker(LatLng newPosition, double rotation) {
    _markers = _markers.map((marker) {
      if (marker.markerId.value == 'rider') {
        return marker.copyWith(positionParam: newPosition, rotationParam: rotation);
      }
      return marker;
    }).toSet();
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
        color: const Color(0xFFFE6132), // accentOrange
        width: 5,
      ),
    );
  }

  Future<void> _setupMapElements() async {
    if (_trackingData == null) return;

    await _updateMapElements();
  }

  Future<void> _updateMapElements() async {
    if (_trackingData == null) return;

    final markers = <Marker>{};

    // Add rider marker if location available
    if (_trackingData!.currentLocation != null) {
      final cacheKey = 'rider_${_trackingData!.rider?.id}_${_trackingData!.rider?.profileImage}';
      if (!_markerIconCache.containsKey(cacheKey)) {
        _markerIconCache[cacheKey] = await CustomMapMarkers.createRiderMarker(
          imageUrl: _trackingData!.rider?.profileImage,
          name: _trackingData!.rider?.name ?? 'Albert',
          primaryColor: const Color(0xFFFE6132),
        );
      }

      final riderMarker = Marker(
        markerId: const MarkerId('rider'),
        position: _trackingData!.currentLocation!.toLatLng(),
        icon: _markerIconCache[cacheKey]!,
        infoWindow: InfoWindow(title: _trackingData!.rider?.name ?? 'Albert', snippet: _trackingData!.statusText),
        anchor: const Offset(0.5, 0.5),
        zIndex: 10.0, // Bring rider to the very top
      );
      markers.add(riderMarker);
    }

    // Add destination marker (Labeled as 'You')
    if (!_markerIconCache.containsKey('destination')) {
      _markerIconCache['destination'] = await CustomMapMarkers.createRiderMarker(
        name: 'You',
        primaryColor: const Color(0xFFFE6132),
      );
    }

    markers.add(
      Marker(
        markerId: const MarkerId('destination'),
        position: _trackingData!.destination.toLatLng(),
        icon: _markerIconCache['destination']!,
        infoWindow: const InfoWindow(title: 'You', snippet: 'Delivery Address'),
        anchor: const Offset(0.5, 0.5),
        zIndex: 5.0, // Below rider, above vendor
      ),
    );

    // Add pickup location marker if available
    if (_trackingData!.pickupLocation != null) {
      if (!_markerIconCache.containsKey('vendor')) {
        _markerIconCache['vendor'] = await CustomMapMarkers.createStoreMarker(
          name: 'Vendor',
          primaryColor: const Color(0xFFFE6132),
        );
      }

      markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: _trackingData!.pickupLocation!.toLatLng(),
          icon: _markerIconCache['vendor']!,
          infoWindow: const InfoWindow(title: 'Restaurant', snippet: 'Pickup location'),
          anchor: const Offset(0.5, 0.5),
          zIndex: 1.0, // Bottom layer
        ),
      );
    }

    _markers = markers;

    // Create curved polyline from rider to destination (The "Future" path)
    if (_trackingData!.currentLocation != null && _trackingData!.route != null) {
      List<LatLng> routePoints = [];
      final polylineStr = _trackingData!.route!.polyline;

      if (polylineStr.startsWith('COORD_LIST|')) {
        // Decode our mock coordinate list
        final parts = polylineStr.split('|').sublist(1);
        for (var part in parts) {
          final latLng = part.split(',');
          if (latLng.length == 2) {
            routePoints.add(LatLng(double.parse(latLng[0]), double.parse(latLng[1])));
          }
        }
      } else {
        // Fallback to straight line
        routePoints = [_trackingData!.currentLocation!.toLatLng(), _trackingData!.destination.toLatLng()];
      }

      final routePolyline = Polyline(
        polylineId: const PolylineId('route'),
        points: routePoints,
        color: const Color(0xFFFE6132).withOpacity(0.3), // accentOrange with low alpha
        width: 4,
        patterns: [PatternItem.dash(15), PatternItem.gap(10)],
      );

      // We maintain the set instead of overwriting it
      _polylines.removeWhere((p) => p.polylineId.value == 'route');
      _polylines.add(routePolyline);
    }

    // Animate camera to show rider
    if (_mapController != null && _trackingData!.currentLocation != null) {
      _mapController!.animateCamera(CameraUpdate.newLatLng(_trackingData!.currentLocation!.toLatLng()));
    }
  }

  @override
  void setMapController(GoogleMapController controller) {
    _mapController = controller;
  }

  @override
  Future<void> refreshTracking() async {
    if (_trackingData == null) return;
    await initializeTracking(_trackingData!.orderId);
  }

  @override
  void reCenterCamera() {
    if (_mapController != null && _trackingData?.currentLocation != null) {
      _mapController!.animateCamera(CameraUpdate.newLatLng(_trackingData!.currentLocation!.toLatLng()));
    }
  }

  @override
  void stopTracking() {
    _mockService?.dispose();
    _trackingData = null;
    _markers = {};
    _polylines = {};
    _markerIconCache.clear();
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _animationTimer?.cancel();
    _mockService?.dispose();
    _mapController?.dispose();
    _markerIconCache.clear();
    super.dispose();
  }
}
