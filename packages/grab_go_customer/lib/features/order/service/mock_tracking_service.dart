import 'dart:async';
import 'dart:math';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/tracking_models.dart';

/// Mock tracking service for testing without a real rider
class MockTrackingService {
  Timer? _simulationTimer;
  final Function(TrackingData) onUpdate;

  // Rider's starting location (3km away from restaurant)
  final LatLng _riderStart = const LatLng(5.5800, -0.2100);

  // Simulated rider location (starts away from restaurant)
  LatLng _currentLocation = const LatLng(5.5800, -0.2100);

  // Location history to simulate breadcrumbs/trail
  final List<LocationHistory> _locationHistory = [];

  // Restaurant location
  final LatLng _restaurant = const LatLng(5.6037, -0.1870);

  // Destination (customer location) - ~5km from restaurant
  final LatLng _destination = const LatLng(5.6450, -0.2150);

  int _currentStep = 0;
  String _currentStatus = 'preparing';

  // Phase 1: Rider → Restaurant
  int _phase1Steps = 25;
  int _phase1Count = 0;
  final List<LatLng> _phase1Path = [];

  // Phase 2: Restaurant → Customer
  int _phase2Steps = 45;
  int _phase2Count = 0;
  final List<LatLng> _phase2Path = [];

  bool _isPhase1Complete = false;

  MockTrackingService({required this.onUpdate});

  /// Start simulating tracking
  TrackingData startSimulation(String orderId) {
    print('🧪 Starting FULL JOURNEY mock tracking simulation: $orderId');
    print('📍 Phase 1: Rider (3km away) → Restaurant');
    print('📍 Phase 2: Restaurant → Customer (5km)');

    // Pre-calculate both journey phases
    _generatePhase1Path(); // Rider → Restaurant
    _generatePhase2Path(); // Restaurant → Customer

    // Start with initial data
    final initialData = _generateTrackingData(orderId);

    // Simulate status changes and movement
    _simulateOrderProgress(orderId);

    return initialData;
  }

  void _generatePhase1Path() {
    _phase1Path.clear();
    for (int i = 0; i <= _phase1Steps; i++) {
      final double progress = i / _phase1Steps;

      // Linear interpolation from rider start to restaurant
      final double targetLat = _riderStart.latitude + (_restaurant.latitude - _riderStart.latitude) * progress;
      final double targetLng = _riderStart.longitude + (_restaurant.longitude - _riderStart.longitude) * progress;

      // Add Curve
      final double curveOffset = sin(progress * pi) * 0.004;

      // Add Wiggle
      final double wiggle = (Random().nextDouble() - 0.5) * 0.0002;

      _phase1Path.add(LatLng(targetLat + curveOffset + wiggle, targetLng - curveOffset + wiggle));
    }
  }

  void _generatePhase2Path() {
    _phase2Path.clear();
    for (int i = 0; i <= _phase2Steps; i++) {
      final double progress = i / _phase2Steps;

      // Linear interpolation from restaurant to customer
      final double targetLat = _restaurant.latitude + (_destination.latitude - _restaurant.latitude) * progress;
      final double targetLng = _restaurant.longitude + (_destination.longitude - _restaurant.longitude) * progress;

      // Add Curve
      final double curveOffset = sin(progress * pi) * 0.005;

      // Add Wiggle
      final double wiggle = (Random().nextDouble() - 0.5) * 0.0002;

      _phase2Path.add(LatLng(targetLat + curveOffset + wiggle, targetLng - curveOffset + wiggle));
    }
  }

  void _simulateOrderProgress(String orderId) {
    var secondsElapsed = 0;

    _simulationTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      secondsElapsed += 3;

      // Phase 1: Rider traveling to restaurant
      if (secondsElapsed <= 9) {
        _currentStatus = 'preparing';
        _currentStep = 0;
        print('📦 Order being prepared, rider en route to restaurant...');
      } else if (secondsElapsed > 9 && !_isPhase1Complete) {
        // Rider moving to restaurant
        if (_phase1Count < _phase1Steps) {
          _locationHistory.add(
            LocationHistory(
              location: LocationData(latitude: _currentLocation.latitude, longitude: _currentLocation.longitude),
              timestamp: DateTime.now(),
            ),
          );

          _phase1Count++;
          _currentLocation = _phase1Path[_phase1Count];
          print('🛵 Phase 1: Moving to restaurant... $_phase1Count/$_phase1Steps');
        } else {
          // Arrived at restaurant
          _isPhase1Complete = true;
          _currentLocation = _restaurant;
          _currentStatus = 'picked_up';
          _currentStep = 2;
          print('🏪 Arrived at restaurant! Picking up order...');
        }
      } else if (_isPhase1Complete && _phase2Count < _phase2Steps) {
        // Phase 2: Rider moving to customer
        _locationHistory.add(
          LocationHistory(
            location: LocationData(latitude: _currentLocation.latitude, longitude: _currentLocation.longitude),
            timestamp: DateTime.now(),
          ),
        );

        _phase2Count++;
        _currentLocation = _phase2Path[_phase2Count];
        print('🚴 Phase 2: Delivering to customer... $_phase2Count/$_phase2Steps');
      } else if (_phase2Count >= _phase2Steps) {
        // Delivered
        _locationHistory.add(
          LocationHistory(
            location: LocationData(latitude: _currentLocation.latitude, longitude: _currentLocation.longitude),
            timestamp: DateTime.now(),
          ),
        );

        _currentStatus = 'delivered';
        _currentStep = 3;
        _currentLocation = _destination;
        print('✅ Delivered!');
        timer.cancel();
      }

      onUpdate(_generateTrackingData(orderId));
    });
  }

  TrackingData _generateTrackingData(String orderId) {
    final distanceRemaining = _calculateDistance(_currentLocation, _destination);
    final etaMinutes = _calculateETA(distanceRemaining);

    // Generate polyline based on current phase
    String polylineString;
    if (!_isPhase1Complete) {
      // Phase 1: Show remaining path to restaurant
      final remainingPath = _phase1Path.skip(_phase1Count).toList();
      polylineString = _encodeMockPath(remainingPath);
    } else {
      // Phase 2: Show remaining path to customer
      final remainingPath = _phase2Path.skip(_phase2Count).toList();
      polylineString = _encodeMockPath(remainingPath);
    }

    return TrackingData(
      orderId: orderId,
      currentLocation: LocationData(latitude: _currentLocation.latitude, longitude: _currentLocation.longitude),
      destination: LocationData(latitude: _destination.latitude, longitude: _destination.longitude),
      pickupLocation: LocationData(latitude: _restaurant.latitude, longitude: _restaurant.longitude),
      status: _currentStatus,
      distanceRemaining: (distanceRemaining * 1000).toInt(),
      estimatedArrival: DateTime.now().add(Duration(minutes: etaMinutes)),
      route: RouteData(
        polyline: polylineString,
        duration: etaMinutes * 60,
        distance: (distanceRemaining * 1000).toInt(),
      ),
      rider: RiderInfo(
        id: 'mock_rider_123',
        name: 'Albert',
        phone: '+233123456789',
        rating: 4.8,
        profileImage: 'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?auto=format&fit=crop&q=80&w=200',
      ),
      locationHistory: List.from(_locationHistory),
    );
  }

  /// Simple serializer to pass points through the polyline string field
  String _encodeMockPath(List<LatLng> points) {
    if (points.isEmpty) return '';
    return 'COORD_LIST|' + points.map((p) => '${p.latitude},${p.longitude}').join('|');
  }

  double _calculateDistance(LatLng from, LatLng to) {
    // Simple distance calculation (Haversine formula)
    const earthRadius = 6371; // km

    final lat1 = from.latitude * pi / 180;
    final lat2 = to.latitude * pi / 180;
    final dLat = (to.latitude - from.latitude) * pi / 180;
    final dLng = (to.longitude - from.longitude) * pi / 180;

    final a = sin(dLat / 2) * sin(dLat / 2) + cos(lat1) * cos(lat2) * sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  int _calculateETA(double distanceKm) {
    // Assume average speed of 20 km/h
    const averageSpeed = 20.0;
    final hours = distanceKm / averageSpeed;
    return (hours * 60).ceil();
  }

  String _generateMockPolyline() {
    // Simple encoded polyline from current location to destination
    // In a real app, this would come from Google Directions API
    return 'mock_polyline_${_currentLocation.latitude}_${_destination.latitude}';
  }

  void dispose() {
    _simulationTimer?.cancel();
    print('🛑 Mock tracking simulation stopped');
  }
}
