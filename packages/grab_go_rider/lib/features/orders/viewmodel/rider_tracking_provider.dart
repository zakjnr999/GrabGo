import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:grab_go_rider/features/orders/service/rider_foreground_service.dart';
import 'package:grab_go_rider/features/orders/service/rider_tracking_service.dart';
import 'package:grab_go_shared/shared/services/cache_service.dart';
import 'package:grab_go_shared/shared/utils/config.dart';
import 'package:grab_go_shared/shared/utils/colors.dart';
import 'package:grab_go_shared/shared/utils/tracking_telemetry.dart';
import 'package:grab_go_shared/shared/widgets/custom_map_markers.dart';

/// State for the rider tracking provider
enum RiderTrackingState { idle, initializing, active, paused, error }

/// Health of live tracking transport from rider -> backend.
enum RiderTrackingConnectionHealth { live, degraded, offline }

/// Configuration for location updates
class TrackingConfig {
  final int updateIntervalMs;
  final double smallestDisplacementMeters;
  final bool highAccuracy;

  const TrackingConfig({
    this.updateIntervalMs = 5000,
    this.smallestDisplacementMeters = 10.0,
    this.highAccuracy = true,
  });

  /// High frequency updates for active delivery
  static const activeDelivery = TrackingConfig(
    updateIntervalMs: 5000,
    smallestDisplacementMeters: 5.0,
    highAccuracy: true,
  );

  /// Lower frequency updates for waiting at restaurant
  static const waitingAtPickup = TrackingConfig(
    updateIntervalMs: 15000,
    smallestDisplacementMeters: 20.0,
    highAccuracy: false,
  );
}

/// Rider tracking provider - manages live location updates to backend
class RiderTrackingProvider with ChangeNotifier {
  final RiderTrackingService _trackingService;
  final RiderForegroundService _foregroundService;
  bool _isDisposed = false;

  // Tracking state
  RiderTrackingState _state = RiderTrackingState.idle;
  String? _activeOrderId;
  String? _activeCustomerId;
  String? _activeRiderId;
  TrackingStatus _currentStatus = TrackingStatus.preparing;
  TrackingConfig _config = TrackingConfig.waitingAtPickup;

  // Location data
  double? _latitude;
  double? _longitude;
  double? _rawLatitude;
  double? _rawLongitude;
  double? _speed;
  double? _accuracy;
  double? _distanceRemaining;
  double? _etaMinutes;
  LatLng? _smoothedLivePosition;

  // Pickup and destination coordinates
  double? _pickupLatitude;
  double? _pickupLongitude;
  double? _destinationLatitude;
  double? _destinationLongitude;

  // Google Maps elements
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  Set<Circle> _circles = {};
  GoogleMapController? _mapController;
  final Map<String, BitmapDescriptor> _markerIconCache = {};
  List<LatLng> _routeCoordinates = const [];
  int _routeProgressIndex = 0;
  LatLng? _lastAnimatedPosition;
  Timer? _markerAnimationTimer;
  DateTime? _lastAutoFollowAt;
  LatLng? _lastAutoFollowPosition;
  Timer? _programmaticCameraGuardTimer;
  bool _isAutoFollowEnabled = true;
  bool _isProgrammaticCameraMove = false;

  // Geofence radius in meters
  static const double _geofenceRadius = 50.0;
  static const bool _trackingDemoMode = AppConfig.trackingDemoMode;
  static const Duration _demoTickInterval = Duration(seconds: 2);
  static const int _demoRoutePoints = 36;
  static const double _demoNearbyThresholdMeters = 350.0;
  static const double _demoSpeedMetersPerMinute = 260.0;
  static const double _gpsSmoothingResetDistanceMeters = 120.0;
  static const double _gpsSmoothingMinAlpha = 0.22;
  static const double _gpsSmoothingMaxAlpha = 0.86;
  static const Duration _autoFollowThrottle = Duration(milliseconds: 900);
  static const double _autoFollowMinDistanceMeters = 10.0;
  static const Duration _programmaticCameraGuardDuration = Duration(
    milliseconds: 900,
  );

  // Background service listener
  StreamSubscription<Map<String, dynamic>?>? _backgroundServiceSubscription;

  // Tracking info from backend
  TrackingInfo? _trackingInfo;

  // Error handling
  String? _lastError;
  DateTime? _lastErrorTime;
  int _consecutiveErrors = 0;
  static const int _maxConsecutiveErrors = 5;

  // Geolocator subscription
  StreamSubscription<Position>? _positionSubscription;
  Timer? _locationUpdateTimer;
  Timer? _demoSimulationTimer;
  DateTime? _lastLocationUpdateTime;
  bool _isSendingLocation = false;
  RiderTrackingConnectionHealth _connectionHealth =
      RiderTrackingConnectionHealth.degraded;
  DateTime? _lastBackendSuccessAt;
  DateTime? _lastBackendFailureAt;
  int _consecutiveBackendFailures = 0;
  final Random _adaptiveIntervalRandom = Random();
  List<LatLng> _demoRoute = const [];
  int _demoRouteIndex = 0;
  bool _isLocalDemoSession = false;
  final TrackingTelemetryCollector _telemetry = TrackingTelemetryCollector(
    scope: 'rider_tracking',
  );

  bool get _useDemoMode => _isLocalDemoSession || _trackingDemoMode;

  // ============================================
  // Getters
  // ============================================

  RiderTrackingState get state => _state;
  String? get activeOrderId => _activeOrderId;
  String? get activeCustomerId => _activeCustomerId;
  TrackingStatus get currentStatus => _currentStatus;

  double? get latitude => _latitude;
  double? get longitude => _longitude;
  double? get speed => _speed;
  double? get accuracy => _accuracy;

  // Coordinate getters for external navigation
  double? get pickupLatitude => _pickupLatitude;
  double? get pickupLongitude => _pickupLongitude;
  double? get destinationLatitude => _destinationLatitude;
  double? get destinationLongitude => _destinationLongitude;

  /// Distance remaining to destination in kilometers
  double? get distanceKm =>
      _distanceRemaining != null ? _distanceRemaining! / 1000.0 : null;

  /// ETA in minutes
  double? get etaMinutes => _etaMinutes;

  /// Whether tracking is actively sending updates
  bool get isTracking => _state == RiderTrackingState.active;

  /// Whether there's an active tracking session
  bool get hasActiveSession => _activeOrderId != null;
  RiderTrackingConnectionHealth get connectionHealth => _connectionHealth;
  bool get isAutoFollowEnabled => _isAutoFollowEnabled;
  int get pendingLocationUpdates => _trackingService.pendingLocationCount;
  bool get hasPendingLocationUpdates =>
      _trackingService.hasPendingLocationUpdates;
  DateTime? get lastBackendSuccessAt => _lastBackendSuccessAt;
  DateTime? get lastBackendFailureAt => _lastBackendFailureAt;
  TrackingTelemetrySnapshot get telemetrySnapshot =>
      _telemetry.snapshot(staleThreshold: const Duration(seconds: 35));
  Map<String, dynamic> get telemetryDebugData => telemetrySnapshot.toJson();

  String? get lastError => _lastError;
  DateTime? get lastErrorTime => _lastErrorTime;

  // Map getters
  Set<Marker> get markers => _markers;
  Set<Polyline> get polylines => _polylines;
  Set<Circle> get circles => _circles;

  /// Get the pickup location as LatLng
  LatLng? get pickupLatLng =>
      _pickupLatitude != null && _pickupLongitude != null
      ? LatLng(_pickupLatitude!, _pickupLongitude!)
      : null;

  /// Get the destination location as LatLng
  LatLng? get destinationLatLng =>
      _destinationLatitude != null && _destinationLongitude != null
      ? LatLng(_destinationLatitude!, _destinationLongitude!)
      : null;

  /// Get current rider location as LatLng
  LatLng? get currentLatLng => _latitude != null && _longitude != null
      ? LatLng(_latitude!, _longitude!)
      : null;
  TrackingInfo? get trackingInfo => _trackingInfo;

  // ============================================
  // Constructor
  // ============================================

  RiderTrackingProvider({
    RiderTrackingService? service,
    RiderForegroundService? foregroundService,
  }) : _trackingService = service ?? RiderTrackingService(),
       _foregroundService = foregroundService ?? RiderForegroundService();

  /// Initialize the foreground service (call once at app startup)
  Future<void> initializeForegroundService() async {
    await _foregroundService.initialize();

    // Listen for location updates from background service
    _backgroundServiceSubscription = _foregroundService.onEvent.listen(
      _onBackgroundLocationUpdate,
    );
  }

  /// Handle location updates from background service
  void _onBackgroundLocationUpdate(Map<String, dynamic>? data) {
    if (data == null || _isDisposed) return;

    final latitude = (data['latitude'] as num?)?.toDouble();
    final longitude = (data['longitude'] as num?)?.toDouble();
    final speed = (data['speed'] as num?)?.toDouble();
    final accuracy = (data['accuracy'] as num?)?.toDouble();

    if (latitude != null && longitude != null) {
      _setLivePosition(
        latitude: latitude,
        longitude: longitude,
        speed: speed,
        accuracy: accuracy,
      );
      _updateRiderMarker();
      _autoFollowRiderCamera();
    }

    _distanceRemaining = (data['distanceRemaining'] as num?)?.toDouble();
    _etaMinutes = (data['etaMinutes'] as num?)?.toDouble();
    _markBackendSendSuccess();

    notifyListeners();
  }

  void _setLivePosition({
    required double latitude,
    required double longitude,
    double? speed,
    double? accuracy,
    bool applySmoothing = true,
    bool resetSmoothing = false,
  }) {
    if (!_isValidCoordinate(latitude, longitude)) {
      _telemetry.recordInvalidCoordinateDrop();
      debugPrint(
        '⚠️ Ignoring invalid location update: lat=$latitude, lon=$longitude',
      );
      return;
    }

    _telemetry.recordLocationSample();

    _rawLatitude = latitude;
    _rawLongitude = longitude;
    _speed = speed;
    _accuracy = accuracy;

    final rawPosition = LatLng(latitude, longitude);
    final targetPosition = applySmoothing
        ? _smoothLivePosition(
            rawPosition: rawPosition,
            speed: speed,
            accuracy: accuracy,
            reset: resetSmoothing,
          )
        : rawPosition;

    if (!applySmoothing || resetSmoothing) {
      _smoothedLivePosition = targetPosition;
    }

    _latitude = targetPosition.latitude;
    _longitude = targetPosition.longitude;
  }

  bool _isValidCoordinate(double latitude, double longitude) {
    return latitude.isFinite &&
        longitude.isFinite &&
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }

  LatLng _smoothLivePosition({
    required LatLng rawPosition,
    double? speed,
    double? accuracy,
    bool reset = false,
  }) {
    if (reset || _smoothedLivePosition == null) {
      _smoothedLivePosition = rawPosition;
      return rawPosition;
    }

    final previous = _smoothedLivePosition!;
    final jumpDistance = _calculateDistanceMeters(previous, rawPosition);
    if (jumpDistance >= _gpsSmoothingResetDistanceMeters) {
      _smoothedLivePosition = rawPosition;
      return rawPosition;
    }

    // Adaptive low-pass filter:
    // - higher speed => less smoothing (higher alpha)
    // - better accuracy => less smoothing lag
    final speedFactor = ((speed ?? 0) / 16.0).clamp(0.0, 1.0).toDouble();
    final normalizedAccuracy =
        (((accuracy ?? 20).clamp(5.0, 80.0) - 5.0) / 75.0).toDouble();
    final accuracyFactor = (1.0 - normalizedAccuracy).clamp(0.0, 1.0);
    final blendFactor = ((speedFactor * 0.65) + (accuracyFactor * 0.35)).clamp(
      0.0,
      1.0,
    );
    final alpha =
        (_gpsSmoothingMinAlpha +
                ((_gpsSmoothingMaxAlpha - _gpsSmoothingMinAlpha) * blendFactor))
            .clamp(_gpsSmoothingMinAlpha, _gpsSmoothingMaxAlpha)
            .toDouble();

    final smoothed = LatLng(
      previous.latitude + ((rawPosition.latitude - previous.latitude) * alpha),
      previous.longitude +
          ((rawPosition.longitude - previous.longitude) * alpha),
    );
    _smoothedLivePosition = smoothed;
    return smoothed;
  }

  // ============================================
  // Tracking Session Management
  // ============================================

  /// Initialize tracking for a new order
  /// Call this when rider accepts an order
  Future<bool> initializeTracking({
    required String orderId,
    required String riderId,
    required String customerId,
    required double pickupLatitude,
    required double pickupLongitude,
    required double destinationLatitude,
    required double destinationLongitude,
    bool useDemoSimulation = false,
  }) async {
    if (_activeOrderId != null && _activeOrderId != orderId) {
      debugPrint('⚠️ Already tracking order $_activeOrderId, stopping first');
      await stopTracking();
    }

    _setState(RiderTrackingState.initializing);
    _stopDemoSimulation();
    _resetCameraFollowState();
    _activeOrderId = orderId;
    _activeCustomerId = customerId;
    _activeRiderId = riderId;
    _telemetry.startSession(sessionId: orderId);

    // Store coordinates for map
    _pickupLatitude = pickupLatitude;
    _pickupLongitude = pickupLongitude;
    _destinationLatitude = destinationLatitude;
    _destinationLongitude = destinationLongitude;

    _isLocalDemoSession = _trackingDemoMode || useDemoSimulation;

    if (_useDemoMode) {
      return _initializeDemoTracking(
        orderId: orderId,
        riderId: riderId,
        customerId: customerId,
        pickupLatitude: pickupLatitude,
        pickupLongitude: pickupLongitude,
        destinationLatitude: destinationLatitude,
        destinationLongitude: destinationLongitude,
      );
    }

    try {
      debugPrint('🚀 Initializing tracking for order: $orderId');
      await _trackingService.hydratePendingLocationQueue();

      final trackingInfo = await _trackingService.initializeTracking(
        TrackingInitDto(
          orderId: orderId,
          riderId: riderId,
          customerId: customerId,
          pickupLocation: LocationDto(
            latitude: pickupLatitude,
            longitude: pickupLongitude,
          ),
          destination: LocationDto(
            latitude: destinationLatitude,
            longitude: destinationLongitude,
          ),
        ),
      );

      if (trackingInfo != null) {
        _trackingInfo = trackingInfo;
        _currentStatus = TrackingStatus.fromString(trackingInfo.status);
        debugPrint('✅ Tracking initialized: ${trackingInfo.status}');

        // Get initial position
        await _getCurrentPosition();

        // Setup map elements (markers, polylines)
        await _setupMapElements();

        // Start with waiting config until pickup is confirmed
        _config = TrackingConfig.waitingAtPickup;
        await _startLocationUpdates();

        // Start foreground service for background tracking
        await _startForegroundService();

        _setState(RiderTrackingState.active);
        return true;
      } else {
        _setError('Failed to initialize tracking');
        return false;
      }
    } catch (e) {
      _setError('Error initializing tracking: $e');
      return false;
    }
  }

  Future<bool> _initializeDemoTracking({
    required String orderId,
    required String riderId,
    required String customerId,
    required double pickupLatitude,
    required double pickupLongitude,
    required double destinationLatitude,
    required double destinationLongitude,
  }) async {
    final pickup = LatLng(pickupLatitude, pickupLongitude);
    final destination = LatLng(destinationLatitude, destinationLongitude);
    final demoStart = _buildDemoRiderStartPosition(
      pickup: pickup,
      destination: destination,
    );

    _trackingInfo = TrackingInfo(
      orderId: orderId,
      riderId: riderId,
      customerId: customerId,
      status: TrackingStatus.preparing.toApiValue(),
      currentLocation: LocationDto(
        latitude: demoStart.latitude,
        longitude: demoStart.longitude,
      ),
      pickupLocation: LocationDto(
        latitude: pickup.latitude,
        longitude: pickup.longitude,
      ),
      destination: LocationDto(
        latitude: destination.latitude,
        longitude: destination.longitude,
      ),
      distanceRemaining: _calculateDistanceMeters(demoStart, pickup),
      estimatedArrival: DateTime.now().add(const Duration(minutes: 12)),
      route: null,
    );

    _currentStatus = TrackingStatus.preparing;
    _config = TrackingConfig.waitingAtPickup;
    _setLivePosition(
      latitude: demoStart.latitude,
      longitude: demoStart.longitude,
      applySmoothing: false,
      resetSmoothing: true,
    );
    _lastAnimatedPosition = demoStart;
    _syncDemoLegMetricsFromCurrentPosition(status: TrackingStatus.preparing);
    _markBackendSendSuccess();

    await _setupMapElements();
    _startDemoSimulation();
    _setState(RiderTrackingState.active);
    return true;
  }

  Future<bool> _resumeDemoTracking(String orderId) async {
    final pickupLat = _pickupLatitude ?? 5.60372;
    final pickupLng = _pickupLongitude ?? -0.18700;
    final destinationLat = _destinationLatitude ?? 5.57458;
    final destinationLng = _destinationLongitude ?? -0.21516;

    return _initializeDemoTracking(
      orderId: orderId,
      riderId: _activeRiderId ?? 'demo-rider',
      customerId: _activeCustomerId ?? 'demo-customer',
      pickupLatitude: pickupLat,
      pickupLongitude: pickupLng,
      destinationLatitude: destinationLat,
      destinationLongitude: destinationLng,
    );
  }

  List<LatLng> _buildDemoRoute(LatLng from, LatLng to, int points) {
    final safePoints = max(points, 36);
    final dLat = to.latitude - from.latitude;
    final dLng = to.longitude - from.longitude;
    final straightDistance = sqrt((dLat * dLat) + (dLng * dLng));
    if (straightDistance < 1e-10) {
      return [from, to];
    }

    final unitLat = dLat / straightDistance;
    final unitLng = dLng / straightDistance;
    final perpLat = -unitLng;
    final perpLng = unitLat;
    final totalMeters = _calculateDistanceMeters(from, to);
    final lateralMeters = min(max(totalMeters * 0.14, 220.0), 560.0);
    final branchLeadMeters = min(max(totalMeters * 0.06, 70.0), 210.0);

    LatLng corridorPoint(
      double t, {
      double lateralFactor = 0,
      double forwardMeters = 0,
    }) {
      final progress = t.clamp(0.0, 1.0);
      final base = LatLng(
        from.latitude + (dLat * progress),
        from.longitude + (dLng * progress),
      );
      return _offsetLatLng(
        base,
        northMeters:
            (perpLat * lateralMeters * lateralFactor) +
            (unitLat * forwardMeters),
        eastMeters:
            (perpLng * lateralMeters * lateralFactor) +
            (unitLng * forwardMeters),
      );
    }

    // Intentionally zig-zag through off-corridor waypoints so the demo route
    // looks like real urban navigation with branch turns and rejoins.
    final waypoints = <LatLng>[
      from,
      corridorPoint(0.08, lateralFactor: 0.22),
      corridorPoint(0.16, lateralFactor: 0.92, forwardMeters: branchLeadMeters),
      corridorPoint(0.24, lateralFactor: 0.18),
      corridorPoint(0.34, lateralFactor: -0.52),
      corridorPoint(
        0.44,
        lateralFactor: -1.15,
        forwardMeters: -branchLeadMeters * 0.4,
      ),
      corridorPoint(0.53, lateralFactor: -0.28),
      corridorPoint(0.62, lateralFactor: 0.55),
      corridorPoint(
        0.72,
        lateralFactor: 1.02,
        forwardMeters: branchLeadMeters * 0.3,
      ),
      corridorPoint(0.81, lateralFactor: 0.32),
      corridorPoint(0.9, lateralFactor: -0.4),
      to,
    ];

    final segments = waypoints.length - 1;
    final pointsPerSegment = max(4, safePoints ~/ segments);
    final route = <LatLng>[];

    for (int i = 0; i < segments; i++) {
      final segmentStart = waypoints[i];
      final segmentEnd = waypoints[i + 1];

      for (int step = 0; step <= pointsPerSegment; step++) {
        if (i > 0 && step == 0) continue;
        final t = step / pointsPerSegment;
        final easedT = t * t * (3 - (2 * t));
        route.add(
          LatLng(
            segmentStart.latitude +
                ((segmentEnd.latitude - segmentStart.latitude) * easedT),
            segmentStart.longitude +
                ((segmentEnd.longitude - segmentStart.longitude) * easedT),
          ),
        );
      }
    }

    if (route.isEmpty ||
        route.last.latitude != to.latitude ||
        route.last.longitude != to.longitude) {
      route.add(to);
    }

    return route;
  }

  LatLng _offsetLatLng(
    LatLng point, {
    required double northMeters,
    required double eastMeters,
  }) {
    const metersPerDegreeLat = 111320.0;
    final latRadians = point.latitude * pi / 180;
    final metersPerDegreeLng =
        metersPerDegreeLat * max(cos(latRadians).abs(), 0.2);

    final deltaLat = northMeters / metersPerDegreeLat;
    final deltaLng = eastMeters / metersPerDegreeLng;
    return LatLng(point.latitude + deltaLat, point.longitude + deltaLng);
  }

  LatLng _buildDemoRiderStartPosition({
    required LatLng pickup,
    required LatLng destination,
  }) {
    final dLat = pickup.latitude - destination.latitude;
    final dLng = pickup.longitude - destination.longitude;
    final magnitude = sqrt((dLat * dLat) + (dLng * dLng));
    final unitLat = magnitude < 1e-9 ? 1.0 : dLat / magnitude;
    final unitLng = magnitude < 1e-9 ? 0.0 : dLng / magnitude;
    final corridorDistance = _calculateDistanceMeters(pickup, destination);
    final offsetMeters = min(max(corridorDistance * 0.4, 1600.0), 3600.0);

    return _offsetLatLng(
      pickup,
      northMeters: unitLat * offsetMeters,
      eastMeters: unitLng * offsetMeters,
    );
  }

  LatLng? _demoTargetForStatus([TrackingStatus? status]) {
    final effectiveStatus = status ?? _currentStatus;

    if ((effectiveStatus == TrackingStatus.preparing ||
            effectiveStatus == TrackingStatus.pickedUp) &&
        _pickupLatitude != null &&
        _pickupLongitude != null) {
      return LatLng(_pickupLatitude!, _pickupLongitude!);
    }

    if (_destinationLatitude != null && _destinationLongitude != null) {
      return LatLng(_destinationLatitude!, _destinationLongitude!);
    }

    return null;
  }

  void _syncDemoLegMetricsFromCurrentPosition({TrackingStatus? status}) {
    if (_latitude == null || _longitude == null) {
      _distanceRemaining = null;
      _etaMinutes = null;
      return;
    }

    final target = _demoTargetForStatus(status);
    if (target == null) {
      _distanceRemaining = null;
      _etaMinutes = null;
      return;
    }

    final current = LatLng(_latitude!, _longitude!);
    final remaining = _calculateDistanceMeters(current, target);
    _distanceRemaining = remaining;
    _etaMinutes = max(remaining / _demoSpeedMetersPerMinute, 0.0);
  }

  void _startDemoSimulation() {
    if (!_useDemoMode ||
        _currentStatus == TrackingStatus.delivered ||
        _currentStatus == TrackingStatus.cancelled ||
        _activeOrderId == null ||
        _latitude == null ||
        _longitude == null) {
      return;
    }

    final target = _demoTargetForStatus();
    if (target == null) {
      return;
    }

    final currentPosition = LatLng(_latitude!, _longitude!);
    if (_routeCoordinates.length >= 2 &&
        _calculateDistanceMeters(_routeCoordinates.last, target) <= 40) {
      _demoRoute = List<LatLng>.from(_routeCoordinates);
    } else {
      _demoRoute = _buildDemoRoute(currentPosition, target, _demoRoutePoints);
      _routeCoordinates = List<LatLng>.from(_demoRoute);
      _routeProgressIndex = 0;
      _updateRouteProgressForPosition(currentPosition, forceRebuild: true);
    }

    if (_demoRoute.isNotEmpty &&
        _calculateDistanceMeters(_demoRoute.first, currentPosition) > 20) {
      _demoRoute = [currentPosition, ..._demoRoute];
    }

    _demoRouteIndex = 0;

    _demoSimulationTimer?.cancel();
    _demoSimulationTimer = Timer.periodic(_demoTickInterval, (_) {
      _advanceDemoSimulation();
    });
  }

  void _advanceDemoSimulation() {
    if (_activeOrderId == null || _demoRoute.isEmpty) {
      _stopDemoSimulation();
      return;
    }

    final target = _demoTargetForStatus();
    if (target == null) {
      _stopDemoSimulation();
      return;
    }

    if (_demoRouteIndex >= _demoRoute.length - 1) {
      _distanceRemaining = 0;
      _etaMinutes = 0;
      _markBackendSendSuccess();
      notifyListeners();
      _stopDemoSimulation();
      return;
    }

    _demoRouteIndex += 1;
    final point = _demoRoute[_demoRouteIndex];
    _setLivePosition(
      latitude: point.latitude,
      longitude: point.longitude,
      applySmoothing: false,
      resetSmoothing: true,
    );

    final remaining = _calculateDistanceMeters(point, target);
    _distanceRemaining = remaining;
    _etaMinutes = max(remaining / _demoSpeedMetersPerMinute, 0.0);

    if (_currentStatus == TrackingStatus.inTransit &&
        remaining <= _demoNearbyThresholdMeters) {
      _currentStatus = TrackingStatus.nearby;
    }

    _updateRiderMarker();
    _markBackendSendSuccess();
    notifyListeners();
  }

  void _stopDemoSimulation() {
    _demoSimulationTimer?.cancel();
    _demoSimulationTimer = null;
    _demoRoute = const [];
    _demoRouteIndex = 0;
  }

  /// Start the foreground service for background location tracking
  Future<void> _startForegroundService() async {
    if (_useDemoMode) {
      return;
    }
    try {
      final authToken = await CacheService.getAuthToken();
      if (authToken == null ||
          _activeOrderId == null ||
          _activeRiderId == null ||
          _activeCustomerId == null) {
        debugPrint('⚠️ Missing data for foreground service');
        return;
      }

      await _foregroundService.startService(
        orderId: _activeOrderId!,
        riderId: _activeRiderId!,
        customerId: _activeCustomerId!,
        authToken: authToken,
        currentStatus: _currentStatus.name,
      );
      debugPrint('✅ Foreground service started');
    } catch (e) {
      debugPrint('⚠️ Error starting foreground service: $e');
      // Don't fail tracking if foreground service fails
    }
  }

  /// Stop the foreground service
  Future<void> _stopForegroundService() async {
    if (_useDemoMode) {
      return;
    }
    try {
      await _foregroundService.stopService();
      debugPrint('✅ Foreground service stopped');
    } catch (e) {
      debugPrint('⚠️ Error stopping foreground service: $e');
    }
  }

  /// Resume tracking for an existing order (e.g., after app restart)
  Future<bool> resumeTracking(
    String orderId, {
    bool useDemoSimulation = false,
  }) async {
    _setState(RiderTrackingState.initializing);
    _stopDemoSimulation();
    _resetCameraFollowState();
    _telemetry.startSession(sessionId: orderId);

    _isLocalDemoSession =
        _trackingDemoMode || useDemoSimulation || _isLocalDemoSession;

    if (_useDemoMode) {
      return _resumeDemoTracking(orderId);
    }

    try {
      await _trackingService.hydratePendingLocationQueue();
      final trackingInfo = await _trackingService.getTrackingInfo(orderId);

      if (trackingInfo != null) {
        _activeOrderId = orderId;
        _activeCustomerId = trackingInfo.customerId;
        _activeRiderId = trackingInfo
            .riderId; // Important: set riderId for foreground service
        _trackingInfo = trackingInfo;
        _currentStatus = TrackingStatus.fromString(trackingInfo.status);

        // Restore coordinates for map from tracking info
        if (trackingInfo.pickupLocation != null) {
          _pickupLatitude = trackingInfo.pickupLocation!.latitude;
          _pickupLongitude = trackingInfo.pickupLocation!.longitude;
        }
        if (trackingInfo.destination != null) {
          _destinationLatitude = trackingInfo.destination!.latitude;
          _destinationLongitude = trackingInfo.destination!.longitude;
        }

        // Only resume if order is still active
        if (_currentStatus != TrackingStatus.delivered &&
            _currentStatus != TrackingStatus.cancelled) {
          // Set config based on status
          _config = _currentStatus == TrackingStatus.inTransit
              ? TrackingConfig.activeDelivery
              : TrackingConfig.waitingAtPickup;

          await _getCurrentPosition();

          // Setup map elements after getting position
          await _setupMapElements();

          await _startLocationUpdates();

          // Start foreground service for background tracking
          await _startForegroundService();

          _setState(RiderTrackingState.active);
          return true;
        } else {
          debugPrint('Order already completed: ${_currentStatus.name}');
          _resetState();
          return false;
        }
      } else {
        _setError('Tracking info not found');
        return false;
      }
    } catch (e) {
      _setError('Error resuming tracking: $e');
      return false;
    }
  }

  /// Stop tracking completely
  Future<void> stopTracking() async {
    debugPrint('🛑 Stopping tracking for order: $_activeOrderId');

    _stopDemoSimulation();
    _stopLocationUpdates();
    await _stopForegroundService();
    _resetState();
    notifyListeners();
  }

  /// Pause tracking temporarily (e.g., rider needs a break)
  void pauseTracking() {
    if (_state == RiderTrackingState.active) {
      _stopLocationUpdates();
      _setState(RiderTrackingState.paused);
    }
  }

  /// Resume paused tracking
  Future<void> resumePausedTracking() async {
    if (_state == RiderTrackingState.paused && _activeOrderId != null) {
      await _startLocationUpdates();
      _setState(RiderTrackingState.active);
    }
  }

  // ============================================
  // Status Updates
  // ============================================

  /// Mark order as picked up from restaurant
  Future<bool> markAsPickedUp() async {
    return await _updateStatus(TrackingStatus.pickedUp);
  }

  /// Re-sync preparing status while rider is still at pickup stage.
  Future<bool> markAsPreparing() async {
    return await _updateStatus(TrackingStatus.preparing);
  }

  /// Mark that rider is now in transit to customer
  Future<bool> markAsInTransit() async {
    final success = await _updateStatus(TrackingStatus.inTransit);
    if (success) {
      if (_useDemoMode) {
        _startDemoSimulation();
      } else {
        // Switch to high-frequency updates for active delivery
        _config = TrackingConfig.activeDelivery;
        await _restartLocationUpdates();
      }
    }
    return success;
  }

  /// Mark order as delivered
  Future<bool> markAsDelivered({
    Map<String, dynamic>? deliveryVerification,
  }) async {
    final success = await _updateStatus(
      TrackingStatus.delivered,
      deliveryVerification: deliveryVerification,
    );
    if (success) {
      await stopTracking();
    }
    return success;
  }

  /// Mark that rider is nearby the customer location
  Future<bool> markAsNearby() async {
    return await _updateStatus(TrackingStatus.nearby);
  }

  /// Mark order as cancelled
  Future<bool> markAsCancelled() async {
    final success = await _updateStatus(TrackingStatus.cancelled);
    if (success) {
      await stopTracking();
    }
    return success;
  }

  /// Upload fallback delivery proof photo for gift order verification.
  Future<DeliveryProofUploadResult> uploadDeliveryProofPhoto(File photo) async {
    if (_useDemoMode) {
      return DeliveryProofUploadResult(
        success: true,
        message: 'Demo mode: proof accepted',
        photoUrl: photo.path,
      );
    }

    if (_activeOrderId == null) {
      const result = DeliveryProofUploadResult(
        success: false,
        message: 'No active order to upload proof for',
      );
      _setError(result.message!);
      return result;
    }

    final result = await _trackingService.uploadDeliveryProofPhoto(
      orderId: _activeOrderId!,
      photo: photo,
    );

    if (!result.success) {
      _setError(result.message ?? 'Failed to upload delivery proof photo');
    }

    return result;
  }

  /// Ask backend to resend delivery verification code to recipient.
  Future<DeliveryCodeResendResult> resendDeliveryCodeToRecipient() async {
    if (_useDemoMode) {
      return DeliveryCodeResendResult(
        success: true,
        message: 'Demo mode: delivery code resent',
        resentAt: DateTime.now(),
      );
    }

    if (_activeOrderId == null) {
      const result = DeliveryCodeResendResult(
        success: false,
        message: 'No active order to resend delivery code for',
      );
      _setError(result.message!);
      return result;
    }

    final result = await _trackingService.resendDeliveryCodeToRecipient(
      orderId: _activeOrderId!,
    );

    if (!result.success) {
      _setError(result.message ?? 'Failed to resend delivery code');
    }

    return result;
  }

  Future<bool> _updateStatus(
    TrackingStatus newStatus, {
    Map<String, dynamic>? deliveryVerification,
  }) async {
    if (_activeOrderId == null) {
      debugPrint('⚠️ No active order to update status');
      return false;
    }

    if (_useDemoMode) {
      final previousStatus = _currentStatus;
      _currentStatus = newStatus;

      if (newStatus == TrackingStatus.inTransit &&
          previousStatus != TrackingStatus.inTransit &&
          _pickupLatitude != null &&
          _pickupLongitude != null) {
        // Start delivery leg from vendor once rider confirms pickup.
        _setLivePosition(
          latitude: _pickupLatitude!,
          longitude: _pickupLongitude!,
          applySmoothing: false,
          resetSmoothing: true,
        );
        _lastAnimatedPosition = LatLng(_latitude!, _longitude!);
      }

      _syncDemoLegMetricsFromCurrentPosition(status: newStatus);
      if (_trackingInfo != null) {
        _trackingInfo = TrackingInfo(
          orderId: _trackingInfo!.orderId,
          riderId: _trackingInfo!.riderId,
          customerId: _trackingInfo!.customerId,
          status: newStatus.toApiValue(),
          currentLocation: _trackingInfo!.currentLocation,
          pickupLocation: _trackingInfo!.pickupLocation,
          destination: _trackingInfo!.destination,
          distanceRemaining: _distanceRemaining,
          estimatedArrival: DateTime.now().add(
            Duration(minutes: (_etaMinutes ?? 0).ceil()),
          ),
          route: _trackingInfo!.route,
        );
      }

      _createSimplePolyline();
      _updateRiderMarker();

      if (newStatus == TrackingStatus.cancelled ||
          newStatus == TrackingStatus.delivered) {
        _stopDemoSimulation();
      } else {
        _startDemoSimulation();
      }

      _markBackendSendSuccess();
      notifyListeners();
      return true;
    }

    try {
      final lifecycleStatus = _mapLifecycleStatus(newStatus);
      if (lifecycleStatus != null) {
        final lifecycleResult = await _trackingService.updateLifecycleStatus(
          orderId: _activeOrderId!,
          status: lifecycleStatus,
          deliveryVerification: newStatus == TrackingStatus.delivered
              ? deliveryVerification
              : null,
        );

        if (!lifecycleResult.success) {
          _setError(
            lifecycleResult.message ??
                'Failed to update order lifecycle status',
          );
          return false;
        }
      }

      bool trackingSyncSuccess = true;
      final shouldSyncTracking =
          newStatus != TrackingStatus.delivered &&
          newStatus != TrackingStatus.cancelled;
      if (shouldSyncTracking) {
        trackingSyncSuccess = await _trackingService.updateStatus(
          orderId: _activeOrderId!,
          status: newStatus,
        );
      }

      _currentStatus = newStatus;

      if (newStatus == TrackingStatus.delivered ||
          newStatus == TrackingStatus.cancelled) {
        await _trackingService.clearPendingLocationUpdatesForOrder(
          _activeOrderId!,
        );
      }

      // Update foreground service with new status
      await _foregroundService.updateStatus(newStatus.name);

      // Update notification content based on status
      _updateNotificationForStatus(newStatus);

      if (!trackingSyncSuccess) {
        debugPrint(
          '⚠️ Lifecycle updated but tracking status sync failed for ${newStatus.name}',
        );
      }

      notifyListeners();
      debugPrint('✅ Status updated to: ${newStatus.name}');
      return true;
    } catch (e) {
      _setError('Error updating status: $e');
      return false;
    }
  }

  String? _mapLifecycleStatus(TrackingStatus status) {
    switch (status) {
      case TrackingStatus.pickedUp:
        return 'picked_up';
      case TrackingStatus.inTransit:
        return 'on_the_way';
      case TrackingStatus.delivered:
        return 'delivered';
      case TrackingStatus.cancelled:
        return 'cancelled';
      case TrackingStatus.preparing:
      case TrackingStatus.nearby:
        return null;
    }
  }

  void _updateNotificationForStatus(TrackingStatus status) {
    if (_useDemoMode) {
      return;
    }

    String title;
    String content;

    switch (status) {
      case TrackingStatus.preparing:
        title = 'Waiting at Restaurant';
        content = 'Order is being prepared';
      case TrackingStatus.pickedUp:
        title = 'Order Picked Up';
        content = 'Ready to start delivery';
      case TrackingStatus.inTransit:
        title = 'En Route to Customer';
        content = 'Delivering order...';
      case TrackingStatus.nearby:
        title = 'Almost There!';
        content = 'Approaching destination';
      case TrackingStatus.delivered:
        title = 'Delivered';
        content = 'Order completed';
      case TrackingStatus.cancelled:
        title = 'Order Cancelled';
        content = 'Tracking stopped';
    }

    _foregroundService.updateNotification(title: title, content: content);
  }

  // ============================================
  // Location Updates
  // ============================================

  Future<void> _startLocationUpdates() async {
    _stopLocationUpdates();

    // Check permissions first
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.deniedForever) {
      _setError(
        'Location permission permanently denied. Please enable in settings.',
      );
      return;
    }
    if (permission == LocationPermission.denied) {
      final requested = await Geolocator.requestPermission();
      if (requested == LocationPermission.denied) {
        _setError('Location permission denied');
        return;
      }
      if (requested == LocationPermission.deniedForever) {
        _setError(
          'Location permission permanently denied. Please enable in settings.',
        );
        return;
      }
      permission = requested;
    }

    // Check if location services are enabled
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _setError('Location services disabled');
      return;
    }

    // Start position stream
    _positionSubscription =
        Geolocator.getPositionStream(
          locationSettings: _buildLocationSettings(),
        ).listen(
          _onPositionUpdate,
          onError: (e) {
            debugPrint('❌ Location stream error: $e');
            _handleLocationError();
          },
        );

    // Start adaptive one-shot scheduling for backend sends.
    _scheduleNextLocationSend();

    debugPrint(
      '✅ Location updates started (adaptive interval: ${_computeAdaptiveLocationIntervalMs()}ms)',
    );
  }

  void _stopLocationUpdates() {
    _positionSubscription?.cancel();
    _positionSubscription = null;

    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = null;
  }

  Future<void> _restartLocationUpdates() async {
    _stopLocationUpdates();
    await _startLocationUpdates();
  }

  void _scheduleNextLocationSend({bool immediate = false}) {
    _locationUpdateTimer?.cancel();
    if (_activeOrderId == null ||
        _state != RiderTrackingState.active ||
        _currentStatus == TrackingStatus.delivered ||
        _currentStatus == TrackingStatus.cancelled) {
      _locationUpdateTimer = null;
      return;
    }

    final baseDelayMs = immediate ? 0 : _computeAdaptiveLocationIntervalMs();
    final delayMs = immediate
        ? 0
        : _withAdaptiveIntervalJitter(baseDelayMs).clamp(1000, 60000).toInt();
    _telemetry.recordScheduledInterval(delayMs);

    _locationUpdateTimer = Timer(Duration(milliseconds: delayMs), () async {
      if (_isDisposed ||
          _activeOrderId == null ||
          _state != RiderTrackingState.active) {
        _locationUpdateTimer = null;
        return;
      }
      await _sendLocationToBackend();
      if (_activeOrderId != null &&
          _state == RiderTrackingState.active &&
          _currentStatus != TrackingStatus.delivered &&
          _currentStatus != TrackingStatus.cancelled &&
          !_isDisposed) {
        _scheduleNextLocationSend();
      }
    });
  }

  int _computeAdaptiveLocationIntervalMs() {
    final speedMps = (_speed ?? 0).clamp(0.0, 30.0).toDouble();
    final isActiveLeg =
        _currentStatus == TrackingStatus.inTransit ||
        _currentStatus == TrackingStatus.nearby;

    int intervalMs;
    if (isActiveLeg) {
      if (speedMps >= 12.0) {
        intervalMs = 3500;
      } else if (speedMps >= 7.0) {
        intervalMs = 4300;
      } else if (speedMps >= 3.0) {
        intervalMs = 5200;
      } else if (speedMps >= 1.2) {
        intervalMs = 6200;
      } else {
        intervalMs = 7600;
      }
    } else {
      if (speedMps >= 5.0) {
        intervalMs = 9000;
      } else if (speedMps >= 2.0) {
        intervalMs = 11000;
      } else {
        intervalMs = 15000;
      }
    }

    final hasNetworkPressure =
        _trackingService.hasPendingLocationUpdates ||
        _consecutiveBackendFailures > 0 ||
        _connectionHealth != RiderTrackingConnectionHealth.live;

    if (hasNetworkPressure) {
      final pendingFactor = min(_trackingService.pendingLocationCount, 5);
      final failureFactor = min(_consecutiveBackendFailures, 5);
      final multiplier = 1.0 + (pendingFactor * 0.08) + (failureFactor * 0.15);
      intervalMs = (intervalMs * multiplier).round();
    }

    final minIntervalMs = isActiveLeg ? 3000 : 7000;
    final maxIntervalMs = isActiveLeg ? 12000 : 30000;
    return intervalMs.clamp(minIntervalMs, maxIntervalMs).toInt();
  }

  int _withAdaptiveIntervalJitter(int intervalMs) {
    final jitterFactor = 0.9 + (_adaptiveIntervalRandom.nextDouble() * 0.2);
    final jittered = (intervalMs * jitterFactor).round();
    return max(jittered, 1000);
  }

  LocationSettings _buildLocationSettings() {
    if (_config.highAccuracy) {
      return const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // meters
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.medium,
      distanceFilter: 15,
    );
  }

  void _onPositionUpdate(Position position) {
    if (!_isValidCoordinate(position.latitude, position.longitude)) {
      _telemetry.recordInvalidCoordinateDrop();
      _handleLocationError();
      return;
    }

    _setLivePosition(
      latitude: position.latitude,
      longitude: position.longitude,
      speed: position.speed,
      accuracy: position.accuracy,
    );

    // Clear errors on successful location
    _consecutiveErrors = 0;
    _lastError = null;

    // Update rider marker on map
    _updateRiderMarker();
    _autoFollowRiderCamera();

    notifyListeners();

    // Send to backend (throttled by timer, but can send immediately on significant movement)
    final adaptiveIntervalMs = _computeAdaptiveLocationIntervalMs();
    final shouldSendImmediately =
        _lastLocationUpdateTime == null ||
        DateTime.now().difference(_lastLocationUpdateTime!).inMilliseconds >
            (adaptiveIntervalMs ~/ 2);

    if (shouldSendImmediately && position.accuracy < 50) {
      // Only send if accuracy is reasonable
      _sendLocationToBackend();
      _scheduleNextLocationSend();
    }
  }

  Future<void> _sendLocationToBackend() async {
    if (_isSendingLocation) {
      return;
    }
    final latitudeForBackend = _rawLatitude ?? _latitude;
    final longitudeForBackend = _rawLongitude ?? _longitude;
    if (_activeOrderId == null ||
        latitudeForBackend == null ||
        longitudeForBackend == null) {
      return;
    }
    if (!_isValidCoordinate(latitudeForBackend, longitudeForBackend)) {
      return;
    }

    // Don't send if status is delivered or cancelled
    if (_currentStatus == TrackingStatus.delivered ||
        _currentStatus == TrackingStatus.cancelled) {
      return;
    }

    _isSendingLocation = true;
    final sendStopwatch = Stopwatch()..start();
    _telemetry.recordBackendSendAttempt(
      pendingQueueDepth: _trackingService.pendingLocationCount,
    );
    try {
      final response = await _trackingService.updateLocation(
        orderId: _activeOrderId!,
        latitude: latitudeForBackend,
        longitude: longitudeForBackend,
        speed: _speed ?? 0,
        accuracy: _accuracy ?? 0,
      );

      if (response != null) {
        _distanceRemaining = response.distanceRemaining;
        _etaMinutes = response.etaMinutes;
        _lastLocationUpdateTime = DateTime.now();
        _markBackendSendSuccess();
        _telemetry.recordBackendSendResult(
          success: true,
          latency: sendStopwatch.elapsed,
          pendingQueueDepth: _trackingService.pendingLocationCount,
        );

        // Update status if backend changed it (e.g., nearby detection)
        final newStatus = TrackingStatus.fromString(response.status);
        if (newStatus != _currentStatus) {
          _currentStatus = newStatus;
          debugPrint('📍 Status changed by backend: ${newStatus.name}');
        }

        notifyListeners();
      } else {
        _markBackendSendFailure();
        _telemetry.recordBackendSendResult(
          success: false,
          latency: sendStopwatch.elapsed,
          pendingQueueDepth: _trackingService.pendingLocationCount,
        );
        _handleLocationError();
      }
    } catch (e) {
      debugPrint('❌ Error sending location to backend: $e');
      _markBackendSendFailure();
      _telemetry.recordBackendSendResult(
        success: false,
        latency: sendStopwatch.elapsed,
        pendingQueueDepth: _trackingService.pendingLocationCount,
      );
      _handleLocationError();
    } finally {
      _isSendingLocation = false;
    }
  }

  Future<void> _getCurrentPosition() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      if (!_isValidCoordinate(position.latitude, position.longitude)) {
        throw Exception('Received invalid current GPS coordinates');
      }

      _setLivePosition(
        latitude: position.latitude,
        longitude: position.longitude,
        speed: position.speed,
        accuracy: position.accuracy,
        applySmoothing: false,
        resetSmoothing: true,
      );
      debugPrint('📍 Got current position: $_latitude, $_longitude');
      _updateRiderMarker();
      _autoFollowRiderCamera(force: true);
      notifyListeners();
    } catch (e) {
      debugPrint('⚠️ Error getting current position: $e');
      // Try to get last known position as fallback
      try {
        final lastPosition = await Geolocator.getLastKnownPosition();
        if (lastPosition != null) {
          if (!_isValidCoordinate(
            lastPosition.latitude,
            lastPosition.longitude,
          )) {
            return;
          }
          _setLivePosition(
            latitude: lastPosition.latitude,
            longitude: lastPosition.longitude,
            speed: lastPosition.speed,
            accuracy: lastPosition.accuracy,
            applySmoothing: false,
            resetSmoothing: true,
          );
          debugPrint('📍 Using last known position: $_latitude, $_longitude');
          _updateRiderMarker();
          _autoFollowRiderCamera(force: true);
          notifyListeners();
        }
      } catch (e2) {
        debugPrint('⚠️ Error getting last known position: $e2');
      }
    }
  }

  void _handleLocationError() {
    _consecutiveErrors++;

    if (_consecutiveErrors >= _maxConsecutiveErrors) {
      _setError('Too many consecutive location errors');
      pauseTracking();
    }
  }

  void _markBackendSendSuccess() {
    _consecutiveBackendFailures = 0;
    _lastBackendSuccessAt = DateTime.now();
    _syncConnectionHealth();
  }

  void _markBackendSendFailure() {
    _consecutiveBackendFailures += 1;
    _lastBackendFailureAt = DateTime.now();
    _syncConnectionHealth();
  }

  void _syncConnectionHealth() {
    final previous = _connectionHealth;

    if (_useDemoMode) {
      _connectionHealth = _activeOrderId == null
          ? RiderTrackingConnectionHealth.offline
          : RiderTrackingConnectionHealth.live;
      _telemetry.recordHealthTransition(
        from: previous.name,
        to: _connectionHealth.name,
      );
      if (previous != _connectionHealth) {
        notifyListeners();
      }
      return;
    }

    final now = DateTime.now();
    final recentSuccess =
        _lastBackendSuccessAt != null &&
        now.difference(_lastBackendSuccessAt!) <= const Duration(seconds: 35);

    if (_consecutiveBackendFailures >= 4 && !recentSuccess) {
      _connectionHealth = RiderTrackingConnectionHealth.offline;
    } else if (_trackingService.hasPendingLocationUpdates ||
        _consecutiveBackendFailures > 0 ||
        !recentSuccess) {
      _connectionHealth = RiderTrackingConnectionHealth.degraded;
    } else {
      _connectionHealth = RiderTrackingConnectionHealth.live;
    }

    _telemetry.recordHealthTransition(
      from: previous.name,
      to: _connectionHealth.name,
    );

    if (previous != _connectionHealth) {
      notifyListeners();
    }
  }

  // ============================================
  // State Management
  // ============================================

  void _setState(RiderTrackingState newState) {
    if (_state != newState) {
      _state = newState;
      notifyListeners();
    }
  }

  void _setError(String message) {
    final previousHealth = _connectionHealth;
    _lastError = message;
    _lastErrorTime = DateTime.now();
    _connectionHealth = RiderTrackingConnectionHealth.offline;
    _telemetry.recordHealthTransition(
      from: previousHealth.name,
      to: _connectionHealth.name,
    );
    _setState(RiderTrackingState.error);
    debugPrint('❌ RiderTrackingProvider: $message');
    notifyListeners();
  }

  void _resetState() {
    _stopDemoSimulation();
    _isLocalDemoSession = false;
    _activeOrderId = null;
    _activeCustomerId = null;
    _activeRiderId = null;
    _currentStatus = TrackingStatus.preparing;
    _trackingInfo = null;
    _latitude = null;
    _longitude = null;
    _rawLatitude = null;
    _rawLongitude = null;
    _speed = null;
    _accuracy = null;
    _smoothedLivePosition = null;
    _distanceRemaining = null;
    _etaMinutes = null;
    _lastError = null;
    _lastErrorTime = null;
    _consecutiveErrors = 0;
    _lastLocationUpdateTime = null;
    _isSendingLocation = false;
    _connectionHealth = RiderTrackingConnectionHealth.degraded;
    _lastBackendSuccessAt = null;
    _lastBackendFailureAt = null;
    _consecutiveBackendFailures = 0;
    _config = TrackingConfig.waitingAtPickup;
    _pickupLatitude = null;
    _pickupLongitude = null;
    _destinationLatitude = null;
    _destinationLongitude = null;
    _markers = {};
    _polylines = {};
    _circles = {};
    _routeCoordinates = const [];
    _routeProgressIndex = 0;
    _lastAnimatedPosition = null;
    _lastAutoFollowAt = null;
    _lastAutoFollowPosition = null;
    _programmaticCameraGuardTimer?.cancel();
    _programmaticCameraGuardTimer = null;
    _isAutoFollowEnabled = true;
    _isProgrammaticCameraMove = false;
    _setState(RiderTrackingState.idle);
  }

  /// Clear error state and retry
  void clearError() {
    _lastError = null;
    _lastErrorTime = null;
    _consecutiveErrors = 0;
    _consecutiveBackendFailures = 0;
    _syncConnectionHealth();
    if (_activeOrderId != null) {
      _setState(RiderTrackingState.paused);
    } else {
      _setState(RiderTrackingState.idle);
    }
    notifyListeners();
  }

  // ============================================
  // Map Management
  // ============================================

  /// Set map controller when map is created
  void setMapController(GoogleMapController controller) {
    _mapController = controller;
    // Animate camera to show all markers after map is ready
    Future.delayed(const Duration(milliseconds: 500), () {
      animateCameraToFitMarkers();
      Future.delayed(const Duration(milliseconds: 300), () {
        _autoFollowRiderCamera(force: true);
      });
    });
  }

  /// Setup markers and polylines on the map
  Future<void> _setupMapElements() async {
    final markers = <Marker>{};
    const primaryColor = AppColors.accentGreen;

    // 1. Add Rider marker (current location - "You")
    if (_latitude != null && _longitude != null) {
      if (!_markerIconCache.containsKey('rider')) {
        _markerIconCache['rider'] =
            await CustomMapMarkers.createRiderVehicleMarker(size: 58);
      }

      markers.add(
        Marker(
          markerId: const MarkerId('rider'),
          position: LatLng(_latitude!, _longitude!),
          icon: _markerIconCache['rider']!,
          infoWindow: const InfoWindow(title: 'You', snippet: 'Your location'),
          anchor: const Offset(0.5, 0.5),
          flat: true,
          rotation: 0,
          zIndexInt: 10,
        ),
      );
      _lastAnimatedPosition = LatLng(_latitude!, _longitude!);
    }

    // 2. Add Restaurant/Pickup marker
    if (_pickupLatitude != null && _pickupLongitude != null) {
      if (!_markerIconCache.containsKey('pickup_pin_v4')) {
        _markerIconCache['pickup_pin_v4'] =
            await CustomMapMarkers.createStoreTapPinMarker(
              primaryColor: primaryColor,
            );
      }

      markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: LatLng(_pickupLatitude!, _pickupLongitude!),
          icon: _markerIconCache['pickup_pin_v4']!,
          infoWindow: const InfoWindow(
            title: 'Restaurant',
            snippet: 'Pickup location',
          ),
          anchor: const Offset(0.5, 0.8),
          zIndexInt: 5,
        ),
      );
    }

    // 3. Add Customer/Destination marker with home icon
    if (_destinationLatitude != null && _destinationLongitude != null) {
      if (!_markerIconCache.containsKey('destination_pin_v4')) {
        _markerIconCache['destination_pin_v4'] =
            await CustomMapMarkers.createHomeTapPinMarker(
              primaryColor: AppColors.accentGreen,
            );
      }

      markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: LatLng(_destinationLatitude!, _destinationLongitude!),
          icon: _markerIconCache['destination_pin_v4']!,
          infoWindow: const InfoWindow(
            title: 'Customer',
            snippet: 'Delivery address',
          ),
          anchor: const Offset(0.5, 0.8),
          zIndexInt: 5,
        ),
      );
    }

    _markers = markers;

    // Create circle geofences around pickup and destination
    _setupGeofenceCircles();

    // Create polylines if we have route data
    if (_trackingInfo?.route?.polyline != null) {
      await _createPolyline(_trackingInfo!.route!.polyline!);
    } else if (_pickupLatitude != null && _destinationLatitude != null) {
      // Create a simple route polyline
      _createSimplePolyline();
    }

    notifyListeners();
  }

  /// Setup geofence circles around pickup and destination
  void _setupGeofenceCircles() {
    final circles = <Circle>{};
    const pickupColor = AppColors.accentGreen;
    const deliveryColor = AppColors.accentGreen;

    // Pickup geofence circle
    if (_pickupLatitude != null && _pickupLongitude != null) {
      circles.add(
        Circle(
          circleId: const CircleId('pickup_geofence'),
          center: LatLng(_pickupLatitude!, _pickupLongitude!),
          radius: _geofenceRadius,
          fillColor: pickupColor.withValues(alpha: 0.15),
          strokeColor: pickupColor.withValues(alpha: 0.5),
          strokeWidth: 2,
        ),
      );
    }

    // Destination geofence circle
    if (_destinationLatitude != null && _destinationLongitude != null) {
      circles.add(
        Circle(
          circleId: const CircleId('destination_geofence'),
          center: LatLng(_destinationLatitude!, _destinationLongitude!),
          radius: _geofenceRadius,
          fillColor: deliveryColor.withValues(alpha: 0.15),
          strokeColor: deliveryColor.withValues(alpha: 0.5),
          strokeWidth: 2,
        ),
      );
    }

    _circles = circles;
  }

  /// Create polyline from encoded string
  Future<void> _createPolyline(String encodedPolyline) async {
    try {
      final polylinePoints = PolylinePoints();
      final decoded = polylinePoints.decodePolyline(encodedPolyline);

      final polylineCoordinates = decoded
          .map((point) => LatLng(point.latitude, point.longitude))
          .toList();

      if (polylineCoordinates.length < 2) {
        _createSimplePolyline();
        return;
      }

      _routeCoordinates = polylineCoordinates;
      _routeProgressIndex = 0;
      _updateRouteProgressForPosition(
        _latitude != null && _longitude != null
            ? LatLng(_latitude!, _longitude!)
            : polylineCoordinates.first,
        forceRebuild: true,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error creating polyline: $e');
      _createSimplePolyline();
    }
  }

  /// Create a simple polyline connecting rider -> pickup -> destination
  void _createSimplePolyline() {
    if (_useDemoMode) {
      final current = currentLatLng;
      final target = _demoTargetForStatus();
      if (current == null || target == null) return;

      _routeCoordinates = _buildDemoRoute(current, target, _demoRoutePoints);
      _routeProgressIndex = 0;
      _updateRouteProgressForPosition(current, forceRebuild: true);
      notifyListeners();
      return;
    }

    final points = <LatLng>[];

    // Add rider position
    if (_latitude != null && _longitude != null) {
      points.add(LatLng(_latitude!, _longitude!));
    }

    // Add pickup location
    if (_pickupLatitude != null && _pickupLongitude != null) {
      points.add(LatLng(_pickupLatitude!, _pickupLongitude!));
    }

    // Add destination
    if (_destinationLatitude != null && _destinationLongitude != null) {
      points.add(LatLng(_destinationLatitude!, _destinationLongitude!));
    }

    if (points.length >= 2) {
      _routeCoordinates = points;
      _routeProgressIndex = 0;
      _updateRouteProgressForPosition(
        _routeCoordinates.first,
        forceRebuild: true,
      );
      notifyListeners();
    }
  }

  /// Update rider marker position with smooth animation
  void _updateRiderMarker() async {
    if (_latitude == null || _longitude == null) return;

    final newPosition = LatLng(_latitude!, _longitude!);
    _updateRouteProgressForPosition(newPosition);

    // Check if rider marker exists, if not create it
    final hasRiderMarker = _markers.any((m) => m.markerId.value == 'rider');
    if (!hasRiderMarker) {
      // Create rider marker if it doesn't exist
      if (!_markerIconCache.containsKey('rider')) {
        _markerIconCache['rider'] =
            await CustomMapMarkers.createRiderVehicleMarker(size: 58);
      }

      _markers = {
        ..._markers,
        Marker(
          markerId: const MarkerId('rider'),
          position: newPosition,
          icon: _markerIconCache['rider']!,
          infoWindow: const InfoWindow(title: 'You', snippet: 'Your location'),
          anchor: const Offset(0.5, 0.5),
          flat: true,
          rotation: 0,
          zIndexInt: 10,
        ),
      };
      _lastAnimatedPosition = newPosition;
      notifyListeners();
      return;
    }

    Marker? currentMarker;
    for (final marker in _markers) {
      if (marker.markerId.value == 'rider') {
        currentMarker = marker;
        break;
      }
    }
    final startPosition = currentMarker?.position ?? _lastAnimatedPosition;
    if (startPosition == null) {
      _updateRiderMarkerPosition(newPosition, 0);
      notifyListeners();
      return;
    }

    final movementMeters = _calculateDistanceMeters(startPosition, newPosition);
    if (movementMeters < 1.2) {
      _updateRiderMarkerPosition(newPosition, 0);
      notifyListeners();
      return;
    }

    // Calculate bearing for rotation and animate movement using distance-aware
    // interpolation to avoid visible "skip jumps" during GPX playback.
    final bearing = _calculateBearing(startPosition, newPosition);
    _animateMarkerMovement(startPosition, newPosition, bearing, movementMeters);
  }

  /// Smoothly animate marker from one position to another
  void _animateMarkerMovement(
    LatLng start,
    LatLng end,
    double bearing,
    double movementMeters,
  ) {
    _markerAnimationTimer?.cancel();

    final clampedDistance = movementMeters.clamp(1.0, 320.0);
    final steps = ((clampedDistance / 2.6).ceil()).clamp(14, 72);
    final totalDurationMs = (420 + (clampedDistance * 16)).round().clamp(
      620,
      3000,
    );
    final tickMs = (totalDurationMs / steps).round().clamp(16, 70);

    int currentStep = 0;

    _markerAnimationTimer = Timer.periodic(Duration(milliseconds: tickMs), (
      timer,
    ) {
      if (currentStep >= steps || _isDisposed) {
        _updateRiderMarkerPosition(end, bearing);
        _lastAnimatedPosition = end;
        notifyListeners();
        timer.cancel();
        return;
      }

      currentStep++;
      final linearT = currentStep / steps;
      final easedT = Curves.easeInOutCubic.transform(linearT);

      final lat = start.latitude + (end.latitude - start.latitude) * easedT;
      final lng = start.longitude + (end.longitude - start.longitude) * easedT;

      _updateRiderMarkerPosition(LatLng(lat, lng), bearing);
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

  double _calculateDistanceMeters(LatLng start, LatLng end) {
    const double earthRadius = 6371000;
    final lat1 = start.latitude * pi / 180;
    final lat2 = end.latitude * pi / 180;
    final dLat = (end.latitude - start.latitude) * pi / 180;
    final dLng = (end.longitude - start.longitude) * pi / 180;

    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  /// Update rider marker position
  void _updateRiderMarkerPosition(LatLng newPosition, double rotation) {
    _markers = _markers.map((marker) {
      if (marker.markerId.value == 'rider') {
        return marker.copyWith(
          positionParam: newPosition,
          rotationParam: rotation,
          flatParam: true,
        );
      }
      return marker;
    }).toSet();
    _lastAnimatedPosition = newPosition;
  }

  void _updateRouteProgressForPosition(
    LatLng position, {
    bool forceRebuild = false,
  }) {
    if (_routeCoordinates.length < 2) return;

    final int nearestIndex = _findNearestRouteIndex(position);
    if (nearestIndex <= _routeProgressIndex && !forceRebuild) {
      return;
    }

    if (nearestIndex > _routeProgressIndex) {
      _routeProgressIndex = nearestIndex;
    }

    final activePath = _routeCoordinates.skip(_routeProgressIndex).toList();
    final passedPath = _routeCoordinates.take(_routeProgressIndex + 1).toList();

    final nextPolylines = <Polyline>{};

    if (activePath.length >= 2) {
      nextPolylines.add(
        Polyline(
          polylineId: const PolylineId('route_active'),
          points: activePath,
          color: AppColors.accentGreen,
          width: 6,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
        ),
      );
    }

    if (passedPath.length >= 2) {
      nextPolylines.add(
        Polyline(
          polylineId: const PolylineId('route_passed'),
          points: passedPath,
          color: AppColors.accentGreen.withValues(alpha: 0.3),
          width: 6,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
        ),
      );
    }

    final showUpcomingDeliveryPreview =
        (_currentStatus == TrackingStatus.preparing ||
            _currentStatus == TrackingStatus.pickedUp) &&
        _pickupLatitude != null &&
        _pickupLongitude != null &&
        _destinationLatitude != null &&
        _destinationLongitude != null;

    if (showUpcomingDeliveryPreview) {
      nextPolylines.add(
        Polyline(
          polylineId: const PolylineId('route_upcoming'),
          points: [
            LatLng(_pickupLatitude!, _pickupLongitude!),
            LatLng(_destinationLatitude!, _destinationLongitude!),
          ],
          color: AppColors.accentGreen.withValues(alpha: 0.42),
          width: 5,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
        ),
      );
    }

    _polylines = nextPolylines;
  }

  int _findNearestRouteIndex(LatLng position) {
    if (_routeCoordinates.isEmpty) return 0;

    final int lowerBound = _routeProgressIndex == 0
        ? 0
        : max(0, _routeProgressIndex - 2);
    int nearestIndex = _routeProgressIndex;
    double nearestDistance = double.infinity;

    for (int i = lowerBound; i < _routeCoordinates.length; i++) {
      final distance = _calculateDistanceMeters(position, _routeCoordinates[i]);
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestIndex = i;
      }
    }

    return nearestIndex < _routeProgressIndex
        ? _routeProgressIndex
        : nearestIndex;
  }

  /// Animate camera to show all markers
  void animateCameraToFitMarkers() {
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

    // Add padding to bounds
    const padding = 0.005;
    minLat -= padding;
    maxLat += padding;
    minLng -= padding;
    maxLng += padding;

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    _animateCameraProgrammatically(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  /// Center camera on rider's current location
  void centerOnRider() {
    if (_mapController == null || _latitude == null || _longitude == null) {
      return;
    }
    _isAutoFollowEnabled = true;
    _autoFollowRiderCamera(force: true, zoom: 16);
    notifyListeners();
  }

  void _autoFollowRiderCamera({bool force = false, double? zoom}) {
    if (_mapController == null || _latitude == null || _longitude == null) {
      return;
    }
    if (!force && !_isAutoFollowEnabled) {
      return;
    }

    final now = DateTime.now();
    final riderPosition = LatLng(_latitude!, _longitude!);

    if (!force) {
      if (_lastAutoFollowAt != null &&
          now.difference(_lastAutoFollowAt!) < _autoFollowThrottle) {
        return;
      }

      if (_lastAutoFollowPosition != null) {
        final movement = _calculateDistanceMeters(
          _lastAutoFollowPosition!,
          riderPosition,
        );
        if (movement < _autoFollowMinDistanceMeters) {
          return;
        }
      }
    }

    _lastAutoFollowAt = now;
    _lastAutoFollowPosition = riderPosition;

    if (zoom != null) {
      _animateCameraProgrammatically(
        CameraUpdate.newLatLngZoom(riderPosition, zoom),
      );
      return;
    }

    _animateCameraProgrammatically(CameraUpdate.newLatLng(riderPosition));
  }

  void _animateCameraProgrammatically(CameraUpdate update) {
    if (_mapController == null) return;
    _isProgrammaticCameraMove = true;
    _programmaticCameraGuardTimer?.cancel();
    _programmaticCameraGuardTimer = Timer(_programmaticCameraGuardDuration, () {
      _isProgrammaticCameraMove = false;
    });
    _mapController?.animateCamera(update);
  }

  void onMapCameraMoveStarted() {
    if (_isProgrammaticCameraMove) return;
    if (_isAutoFollowEnabled) {
      _isAutoFollowEnabled = false;
      notifyListeners();
    }
  }

  void onMapCameraIdle() {
    _programmaticCameraGuardTimer?.cancel();
    _isProgrammaticCameraMove = false;
  }

  void _resetCameraFollowState() {
    _lastAutoFollowAt = null;
    _lastAutoFollowPosition = null;
    _isAutoFollowEnabled = true;
    _isProgrammaticCameraMove = false;
    _programmaticCameraGuardTimer?.cancel();
    _programmaticCameraGuardTimer = null;
  }

  // ============================================
  // Cleanup
  // ============================================

  @override
  void dispose() {
    _isDisposed = true;
    _stopDemoSimulation();
    _isLocalDemoSession = false;
    _stopLocationUpdates();
    _backgroundServiceSubscription?.cancel();
    _backgroundServiceSubscription = null;
    _markerAnimationTimer?.cancel();
    _markerAnimationTimer = null;
    _programmaticCameraGuardTimer?.cancel();
    _programmaticCameraGuardTimer = null;
    _markerIconCache.clear();
    _mapController?.dispose();
    _trackingService.dispose();
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }
}
