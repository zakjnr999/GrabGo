import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_shared/shared/utils/tracking_telemetry.dart';
import 'package:grab_go_shared/shared/widgets/custom_map_markers.dart';
import '../models/tracking_models.dart';
import '../service/tracking_api_service.dart';
import '../service/tracking_socket_service.dart';
import 'base_tracking_provider.dart';

enum TrackingConnectionHealth { live, degraded, offline }

/// Provider for managing tracking state and real-time updates
class TrackingProvider extends BaseTrackingProvider {
  final TrackingApiService _apiService;
  final TrackingSocketService _socketService;
  static const String _markerStyleVersion = 'v2';

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
  static const Duration _fallbackPollingInterval = Duration(seconds: 8);
  static const Duration _fallbackPollingMaxInterval = Duration(seconds: 45);
  static const Duration _liveFreshnessWindow = Duration(seconds: 25);
  static const Duration _degradedFreshnessWindow = Duration(seconds: 60);
  static const bool _trackingDemoMode = AppConfig.trackingDemoMode;
  static const Duration _demoTickInterval = Duration(seconds: 2);
  static const int _demoRoutePointCount = 28;
  static const double _demoArrivalThresholdMeters = 70.0;
  static const double _incomingSmoothingResetDistanceMeters = 260.0;
  static const double _incomingSmoothingMinAlpha = 0.22;
  static const double _incomingSmoothingMaxAlpha = 0.84;

  // Subscriptions
  StreamSubscription? _locationSubscription;
  StreamSubscription? _statusSubscription;
  StreamSubscription? _connectionSubscription;
  Timer? _animationTimer;
  Timer? _waitingForRiderTimer;
  Timer? _fallbackPollingTimer;
  Timer? _connectionHealthTimer;
  Timer? _demoSimulationTimer;
  LatLng? _lastKnownPosition;
  LatLng? _smoothedRealtimePosition;
  double _currentBearing = 0;
  List<LocationData> _demoRoute = const [];
  int _demoRouteIndex = 0;
  final Map<String, BitmapDescriptor> _markerIconCache = {};
  TrackingConnectionHealth _connectionHealth =
      TrackingConnectionHealth.degraded;
  DateTime? _lastRealtimeUpdateAt;
  DateTime? _lastSuccessfulApiSyncAt;
  int _consecutiveFallbackFailures = 0;
  bool _isFallbackRequestInFlight = false;
  int _fallbackPollingAttempt = 0;
  bool _hasEstablishedSocketConnectionForSession = false;
  final Random _fallbackJitterRandom = Random();
  final TrackingTelemetryCollector _telemetry = TrackingTelemetryCollector(
    scope: 'customer_tracking',
  );

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
  TrackingConnectionHealth get connectionHealth => _connectionHealth;
  bool get isFallbackPollingActive => _fallbackPollingTimer != null;
  TrackingTelemetrySnapshot get telemetrySnapshot =>
      _telemetry.snapshot(staleThreshold: _degradedFreshnessWindow);
  Map<String, dynamic> get telemetryDebugData => telemetrySnapshot.toJson();

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
        if (_hasEstablishedSocketConnectionForSession) {
          _telemetry.recordSocketReconnect();
        } else {
          _hasEstablishedSocketConnectionForSession = true;
        }
      }
      if (isConnected && _activeOrderId != null) {
        _socketService.joinOrderRoom(_activeOrderId!);
        _stopFallbackPolling();
      } else {
        _startFallbackPolling();
      }
      _syncConnectionHealth();
      notifyListeners();
    });

    _startConnectionHealthMonitor();
  }

  /// Initialize tracking for an order
  @override
  Future<void> initializeTracking(String orderId) async {
    _telemetry.startSession(sessionId: orderId);
    _activeOrderId = orderId;
    _lastKnownPosition = null;
    _smoothedRealtimePosition = null;
    _currentBearing = 0;
    _hasEstablishedSocketConnectionForSession = false;
    _stopFallbackPolling();
    _stopWaitingForRiderPolling();
    _stopDemoSimulation();
    _isWaitingForRider = false;
    _isLoading = true;
    _error = null;
    _markers = {};
    _polylines = {};
    _circles = {};
    notifyListeners();

    if (_trackingDemoMode) {
      await _initializeDemoTracking(orderId);
      return;
    }

    try {
      // 1. Get initial tracking data from API
      print('📡 Fetching tracking data for order: $orderId');
      _trackingData = _withSmoothedCurrentLocation(
        await _apiService.getTrackingInfo(orderId),
        resetFilter: true,
      );
      _trackingData = _withInitialRenderableLocation(_trackingData!);
      if (_trackingData?.currentLocation != null) {
        _telemetry.recordLocationSample();
      }
      _lastSuccessfulApiSyncAt = DateTime.now();
      _consecutiveFallbackFailures = 0;
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
      _syncConnectionHealth();

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
      _syncConnectionHealth();
      notifyListeners();
      print('❌ Failed to initialize tracking: $e');
    } catch (e) {
      _error = e.toString();
      _isWaitingForRider = false;
      _stopWaitingForRiderPolling();
      _isLoading = false;
      _syncConnectionHealth();
      notifyListeners();
      print('❌ Failed to initialize tracking: $e');
    }
  }

  Future<void> _initializeDemoTracking(String orderId) async {
    final pickup = LocationData(latitude: 5.60372, longitude: -0.18700);
    final destination = LocationData(latitude: 5.57458, longitude: -0.21516);
    final start = LocationData(latitude: 5.60790, longitude: -0.18250);

    _demoRoute = _buildDemoRoute(
      start: start,
      pickup: pickup,
      destination: destination,
      totalPoints: _demoRoutePointCount,
    );
    _demoRouteIndex = 0;

    final initialLocation = _demoRoute.first;
    final initialDistance = _calculateDistance(
      initialLocation.toLatLng(),
      destination.toLatLng(),
    ).round();

    _trackingData = TrackingData(
      orderId: orderId,
      currentLocation: initialLocation,
      destination: destination,
      pickupLocation: pickup,
      status: 'preparing',
      distanceRemaining: initialDistance,
      estimatedArrival: DateTime.now().add(
        Duration(minutes: max((initialDistance / 220).ceil(), 3)),
      ),
      rider: RiderInfo(
        id: 'demo-rider',
        name: 'Demo Rider',
        phone: '+233000000000',
        rating: 4.9,
      ),
      locationHistory: const [],
    );

    _lastKnownPosition = initialLocation.toLatLng();
    _smoothedRealtimePosition = _lastKnownPosition;
    _currentBearing = 0;
    _isWaitingForRider = false;
    _error = null;
    _isLoading = false;
    _lastRealtimeUpdateAt = DateTime.now();
    _telemetry.recordLocationSample(at: _lastRealtimeUpdateAt);
    _lastSuccessfulApiSyncAt = DateTime.now();

    await _setupMapElements();
    _syncConnectionHealth();
    notifyListeners();

    _demoSimulationTimer = Timer.periodic(_demoTickInterval, (_) {
      _advanceDemoTracking(orderId);
    });
  }

  List<LocationData> _buildDemoRoute({
    required LocationData start,
    required LocationData pickup,
    required LocationData destination,
    required int totalPoints,
  }) {
    final toPickupSegments = max((totalPoints * 0.25).round(), 5);
    final toDestinationSegments = max(totalPoints - toPickupSegments, 12);

    final toPickup = _interpolateSegment(
      start: start,
      end: pickup,
      segments: toPickupSegments,
    );
    final toDestination = _interpolateSegment(
      start: pickup,
      end: destination,
      segments: toDestinationSegments,
    );

    return [...toPickup, ...toDestination.skip(1)];
  }

  List<LocationData> _interpolateSegment({
    required LocationData start,
    required LocationData end,
    required int segments,
  }) {
    final safeSegments = max(segments, 2);
    return List<LocationData>.generate(safeSegments + 1, (index) {
      final t = index / safeSegments;
      return LocationData(
        latitude: start.latitude + (end.latitude - start.latitude) * t,
        longitude: start.longitude + (end.longitude - start.longitude) * t,
      );
    });
  }

  void _advanceDemoTracking(String orderId) {
    if (_trackingData == null || _trackingData!.orderId != orderId) {
      _stopDemoSimulation();
      return;
    }

    if (_demoRoute.isEmpty) return;

    if (_demoRouteIndex >= _demoRoute.length - 1) {
      _completeDemoTracking(orderId);
      return;
    }

    _demoRouteIndex += 1;
    final nextLocation = _demoRoute[_demoRouteIndex];
    final destination = _trackingData!.destination;

    final remainingDistance = _calculateDistance(
      nextLocation.toLatLng(),
      destination.toLatLng(),
    ).round();

    final progress = _demoRouteIndex / (_demoRoute.length - 1);
    final status = _demoStatusForProgress(
      progress: progress,
      remainingMeters: remainingDistance,
    );

    _lastSuccessfulApiSyncAt = DateTime.now();

    _handleLocationUpdate(
      LocationUpdateEvent(
        orderId: orderId,
        location: nextLocation,
        distance: remainingDistance,
        eta: DateTime.now().add(
          Duration(minutes: max((remainingDistance / 240).ceil(), 1)),
        ),
        status: status,
      ),
    );

    if (progress >= 0.98 || remainingDistance <= _demoArrivalThresholdMeters) {
      _completeDemoTracking(orderId);
    }
  }

  String _demoStatusForProgress({
    required double progress,
    required int remainingMeters,
  }) {
    if (progress < 0.28) return 'preparing';
    if (remainingMeters <= 450) return 'nearby';
    if (progress < 0.4) return 'picked_up';
    return 'in_transit';
  }

  void _completeDemoTracking(String orderId) {
    if (_trackingData == null) return;

    final destination = _trackingData!.destination;

    _handleLocationUpdate(
      LocationUpdateEvent(
        orderId: orderId,
        location: destination,
        distance: 0,
        eta: DateTime.now(),
        status: 'delivered',
      ),
    );

    _handleStatusUpdate(
      StatusUpdateEvent(
        orderId: orderId,
        status: 'delivered',
        message: 'Delivered (demo mode)',
      ),
    );

    _stopDemoSimulation();
  }

  void _stopDemoSimulation() {
    _demoSimulationTimer?.cancel();
    _demoSimulationTimer = null;
    _demoRoute = const [];
    _demoRouteIndex = 0;
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
        _trackingData = _withSmoothedCurrentLocation(data, resetFilter: true);
        _trackingData = _withInitialRenderableLocation(_trackingData!);
        if (_trackingData?.currentLocation != null) {
          _telemetry.recordLocationSample();
        }
        _lastSuccessfulApiSyncAt = DateTime.now();
        _consecutiveFallbackFailures = 0;
        _isWaitingForRider = false;
        _error = null;
        _isLoading = false;
        _stopWaitingForRiderPolling();

        if (!_socketService.isConnected) {
          _socketService.connect();
        }
        _waitForSocketAndJoinRoom(orderId);
        await _setupMapElements();
        _syncConnectionHealth();
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

  void _startFallbackPolling() {
    if (_activeOrderId == null || _fallbackPollingTimer != null) {
      return;
    }
    _fallbackPollingAttempt = 0;
    _scheduleNextFallbackPoll(const Duration(seconds: 1));
  }

  void _scheduleNextFallbackPoll(Duration delay) {
    if (_activeOrderId == null || _socketService.isConnected) {
      _stopFallbackPolling();
      return;
    }
    _fallbackPollingTimer?.cancel();
    _fallbackPollingTimer = Timer(delay, () {
      _runFallbackPoll();
    });
  }

  Future<void> _runFallbackPoll() async {
    if (_activeOrderId == null || _socketService.isConnected) {
      _stopFallbackPolling();
      _syncConnectionHealth();
      notifyListeners();
      return;
    }

    if (_isFallbackRequestInFlight) {
      _scheduleNextFallbackPoll(_nextFallbackPollDelay());
      return;
    }

    _isFallbackRequestInFlight = true;
    final pollStopwatch = Stopwatch()..start();
    bool pollSuccess = false;
    try {
      final snapshot = await _apiService.getTrackingInfo(_activeOrderId!);
      _trackingData = _withSmoothedCurrentLocation(snapshot);
      _trackingData = _withInitialRenderableLocation(_trackingData!);
      if (_trackingData?.currentLocation != null) {
        _telemetry.recordLocationSample();
      }
      _lastSuccessfulApiSyncAt = DateTime.now();
      _consecutiveFallbackFailures = 0;
      _fallbackPollingAttempt = 0;
      _error = null;
      await _setupMapElements(animateCamera: false);
      pollSuccess = true;
    } on TrackingException catch (e) {
      if (e.statusCode != 404) {
        _consecutiveFallbackFailures += 1;
        _error = e.message;
      }
      _fallbackPollingAttempt = min(_fallbackPollingAttempt + 1, 4);
    } catch (_) {
      _consecutiveFallbackFailures += 1;
      _fallbackPollingAttempt = min(_fallbackPollingAttempt + 1, 4);
    } finally {
      _isFallbackRequestInFlight = false;
      _telemetry.recordFallbackPollResult(
        success: pollSuccess,
        latency: pollStopwatch.elapsed,
      );
      _syncConnectionHealth();
      notifyListeners();

      if (_activeOrderId != null && !_socketService.isConnected) {
        _scheduleNextFallbackPoll(_nextFallbackPollDelay());
      }
    }
  }

  Duration _nextFallbackPollDelay() {
    final backoffMultiplier = 1 << _fallbackPollingAttempt;
    final baseDelayMs =
        _fallbackPollingInterval.inMilliseconds * backoffMultiplier;
    final cappedDelayMs = min(
      baseDelayMs,
      _fallbackPollingMaxInterval.inMilliseconds,
    );

    // Add 15% jitter to avoid synchronized retries under outages.
    final jitterFactor = 0.85 + (_fallbackJitterRandom.nextDouble() * 0.3);
    final delayMs = (cappedDelayMs * jitterFactor).round();
    return Duration(milliseconds: max(delayMs, 1000));
  }

  void _stopFallbackPolling() {
    _fallbackPollingTimer?.cancel();
    _fallbackPollingTimer = null;
    _isFallbackRequestInFlight = false;
    _fallbackPollingAttempt = 0;
  }

  void _startConnectionHealthMonitor() {
    _connectionHealthTimer?.cancel();
    _connectionHealthTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _syncConnectionHealth();
    });
  }

  void _stopConnectionHealthMonitor() {
    _connectionHealthTimer?.cancel();
    _connectionHealthTimer = null;
  }

  void _syncConnectionHealth() {
    final previous = _connectionHealth;

    if (_trackingDemoMode) {
      _connectionHealth = _trackingData == null
          ? TrackingConnectionHealth.offline
          : TrackingConnectionHealth.live;
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
    final hasFreshRealtime =
        _lastRealtimeUpdateAt != null &&
        now.difference(_lastRealtimeUpdateAt!) <= _liveFreshnessWindow;
    final hasRecentApiSync =
        _lastSuccessfulApiSyncAt != null &&
        now.difference(_lastSuccessfulApiSyncAt!) <= _degradedFreshnessWindow;

    if (_socketService.isConnected && hasFreshRealtime) {
      _connectionHealth = TrackingConnectionHealth.live;
    } else if ((_socketService.isConnected || isFallbackPollingActive) &&
        hasRecentApiSync &&
        _consecutiveFallbackFailures < 3) {
      _connectionHealth = TrackingConnectionHealth.degraded;
    } else if (hasRecentApiSync && _consecutiveFallbackFailures < 5) {
      _connectionHealth = TrackingConnectionHealth.degraded;
    } else {
      _connectionHealth = TrackingConnectionHealth.offline;
    }

    _telemetry.recordHealthTransition(
      from: previous.name,
      to: _connectionHealth.name,
    );

    if (previous != _connectionHealth) {
      notifyListeners();
    }
  }

  /// Wait for socket connection and then join the order room
  void _waitForSocketAndJoinRoom(String orderId) {
    // If already connected, join immediately
    if (_socketService.isConnected) {
      print('🚪 Socket already connected, joining order room: $orderId');
      _hasEstablishedSocketConnectionForSession = true;
      _socketService.joinOrderRoom(orderId);
      _stopFallbackPolling();
      _syncConnectionHealth();
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
  Future<void> _setupMapElements({bool animateCamera = true}) async {
    if (_trackingData == null) return;

    final markers = <Marker>{};
    _polylines.removeWhere((polyline) => polyline.polylineId.value != 'trail');

    // Add rider marker if location available
    if (_trackingData!.currentLocation != null) {
      const cacheKey = 'rider_vehicle';
      if (!_markerIconCache.containsKey(cacheKey)) {
        _markerIconCache[cacheKey] =
            await CustomMapMarkers.createRiderVehicleMarker(size: 58);
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
        flat: true,
        rotation: _currentBearing,
        zIndexInt: 10, // Bring rider to the very top
      );
      markers.add(riderMarker);
    }

    // Add destination marker (customer's home) with home icon
    final destinationMarkerKey = 'destination_tap_pin_$_markerStyleVersion';
    if (!_markerIconCache.containsKey(destinationMarkerKey)) {
      _markerIconCache[destinationMarkerKey] =
          await CustomMapMarkers.createHomeTapPinMarker(
            primaryColor: AppColors.accentOrange,
          );
    }

    markers.add(
      Marker(
        markerId: const MarkerId('destination'),
        position: _trackingData!.destination.toLatLng(),
        icon: _markerIconCache[destinationMarkerKey]!,
        infoWindow: const InfoWindow(title: 'You', snippet: 'Delivery Address'),
        anchor: const Offset(0.5, 0.8),
        zIndexInt: 5, // Below rider, above vendor
      ),
    );

    // Add pickup location marker if available
    if (_trackingData!.pickupLocation != null) {
      final vendorMarkerKey = 'vendor_tap_pin_$_markerStyleVersion';
      if (!_markerIconCache.containsKey(vendorMarkerKey)) {
        _markerIconCache[vendorMarkerKey] =
            await CustomMapMarkers.createStoreTapPinMarker(
              primaryColor: AppColors.accentOrange,
            );
      }

      markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: _trackingData!.pickupLocation!.toLatLng(),
          icon: _markerIconCache[vendorMarkerKey]!,
          infoWindow: const InfoWindow(
            title: 'Restaurant',
            snippet: 'Pickup location',
          ),
          anchor: const Offset(0.5, 0.8),
          zIndexInt: 1, // Bottom layer
        ),
      );
    }

    _markers = markers;

    // Setup geofence circles
    _setupGeofenceCircles();

    final status = _trackingData!.status.toLowerCase();
    final shouldForcePickupPreview =
        status == 'preparing' || status == 'confirmed' || status == 'ready';

    bool routeRendered = false;
    if (!shouldForcePickupPreview &&
        _trackingData!.route != null &&
        _trackingData!.route!.polyline.isNotEmpty) {
      routeRendered = await _createPolyline(_trackingData!.route!.polyline);
    }

    if (!routeRendered) {
      _createFallbackRoutePolylines();
    }

    // Animate camera to show all markers
    if (animateCamera) {
      _animateCameraToFitMarkers();
    }

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

  /// Create polyline from encoded string
  Future<bool> _createPolyline(String encodedPolyline) async {
    try {
      final polylinePoints = PolylinePoints();
      final decoded = polylinePoints.decodePolyline(encodedPolyline);

      final polylineCoordinates = decoded
          .map((point) => LatLng(point.latitude, point.longitude))
          .toList();
      if (polylineCoordinates.length < 2) return false;

      final routePolyline = Polyline(
        polylineId: const PolylineId('route'),
        points: polylineCoordinates,
        color: AppColors.accentOrange.withValues(alpha: 0.92),
        width: 6,
      );

      _polylines.removeWhere((p) => p.polylineId.value == 'route');
      _polylines.add(routePolyline);
      return true;
    } catch (e) {
      print('❌ Error creating polyline: $e');
      return false;
    }
  }

  void _createFallbackRoutePolylines() {
    if (_trackingData == null) return;

    _polylines.removeWhere(
      (polyline) => polyline.polylineId.value.startsWith('route_'),
    );

    final status = _trackingData!.status.toLowerCase();
    final isHeadingToPickup =
        status == 'preparing' || status == 'confirmed' || status == 'ready';

    final current = _trackingData!.currentLocation?.toLatLng();
    final pickup = _trackingData!.pickupLocation?.toLatLng();
    final destination = _trackingData!.destination.toLatLng();

    if (isHeadingToPickup && pickup != null) {
      if (current != null && _calculateDistance(current, pickup) > 5) {
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('route_to_pickup'),
            points: [current, pickup],
            color: AppColors.accentOrange.withValues(alpha: 0.94),
            width: 6,
          ),
        );
      }

      if (_calculateDistance(pickup, destination) > 5) {
        _polylines.add(
          Polyline(
            polylineId: const PolylineId('route_pickup_to_destination'),
            points: [pickup, destination],
            color: AppColors.accentOrange.withValues(alpha: 0.35),
            width: 5,
          ),
        );
      }
      return;
    }

    final routeStart = current ?? pickup;
    if (routeStart != null && _calculateDistance(routeStart, destination) > 5) {
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('route_fallback'),
          points: [routeStart, destination],
          color: AppColors.accentOrange.withValues(alpha: 0.94),
          width: 6,
        ),
      );
    }
  }

  bool _isValidCoordinate(double latitude, double longitude) {
    return latitude.isFinite &&
        longitude.isFinite &&
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }

  TrackingData _copyTrackingDataWithCurrentLocation(
    TrackingData data,
    LocationData? currentLocation,
  ) {
    return TrackingData(
      orderId: data.orderId,
      currentLocation: currentLocation,
      destination: data.destination,
      pickupLocation: data.pickupLocation,
      status: data.status,
      distanceRemaining: data.distanceRemaining,
      estimatedArrival: data.estimatedArrival,
      route: data.route,
      rider: data.rider,
      locationHistory: data.locationHistory,
    );
  }

  TrackingData _withInitialRenderableLocation(TrackingData data) {
    if (data.currentLocation != null) return data;
    final fallback = data.pickupLocation ?? data.destination;
    return _copyTrackingDataWithCurrentLocation(data, fallback);
  }

  TrackingData _withSmoothedCurrentLocation(
    TrackingData data, {
    bool resetFilter = false,
  }) {
    final currentLocation = data.currentLocation;
    if (currentLocation == null) {
      return data;
    }

    if (!_isValidCoordinate(
      currentLocation.latitude,
      currentLocation.longitude,
    )) {
      _telemetry.recordInvalidCoordinateDrop();
      final fallback = _trackingData?.currentLocation;
      if (fallback != null &&
          _isValidCoordinate(fallback.latitude, fallback.longitude)) {
        return _copyTrackingDataWithCurrentLocation(data, fallback);
      }
      return _copyTrackingDataWithCurrentLocation(data, null);
    }

    final smoothedLocation = _smoothIncomingLocation(
      currentLocation,
      reset: resetFilter,
    );

    if (smoothedLocation.latitude == currentLocation.latitude &&
        smoothedLocation.longitude == currentLocation.longitude) {
      return data;
    }

    return _copyTrackingDataWithCurrentLocation(data, smoothedLocation);
  }

  LocationData _smoothIncomingLocation(
    LocationData incoming, {
    bool reset = false,
  }) {
    if (!_isValidCoordinate(incoming.latitude, incoming.longitude)) {
      if (_smoothedRealtimePosition != null) {
        return LocationData(
          latitude: _smoothedRealtimePosition!.latitude,
          longitude: _smoothedRealtimePosition!.longitude,
        );
      }
      return incoming;
    }

    final rawPosition = incoming.toLatLng();
    if (reset || _smoothedRealtimePosition == null) {
      _smoothedRealtimePosition = rawPosition;
      return incoming;
    }

    final previous = _smoothedRealtimePosition!;
    final jumpDistance = _calculateDistance(previous, rawPosition);
    if (jumpDistance >= _incomingSmoothingResetDistanceMeters) {
      _smoothedRealtimePosition = rawPosition;
      return incoming;
    }

    if (jumpDistance <= 1.2) {
      return LocationData(
        latitude: previous.latitude,
        longitude: previous.longitude,
      );
    }

    final normalizedStep = (jumpDistance / 45.0).clamp(0.0, 1.0).toDouble();
    final alpha =
        (_incomingSmoothingMinAlpha +
                ((_incomingSmoothingMaxAlpha - _incomingSmoothingMinAlpha) *
                    normalizedStep))
            .clamp(_incomingSmoothingMinAlpha, _incomingSmoothingMaxAlpha)
            .toDouble();

    final smoothed = LatLng(
      previous.latitude + ((rawPosition.latitude - previous.latitude) * alpha),
      previous.longitude +
          ((rawPosition.longitude - previous.longitude) * alpha),
    );
    _smoothedRealtimePosition = smoothed;

    return LocationData(
      latitude: smoothed.latitude,
      longitude: smoothed.longitude,
    );
  }

  /// Handle real-time location updates from socket
  void _handleLocationUpdate(LocationUpdateEvent event) {
    if (_trackingData == null || event.orderId != _trackingData!.orderId) {
      return;
    }
    _lastRealtimeUpdateAt = DateTime.now();
    _telemetry.recordLocationSample(at: _lastRealtimeUpdateAt);
    _consecutiveFallbackFailures = 0;

    var incomingLocation = event.location;
    if (!_isValidCoordinate(
      incomingLocation.latitude,
      incomingLocation.longitude,
    )) {
      _telemetry.recordInvalidCoordinateDrop();
      final fallback = _trackingData!.currentLocation;
      if (fallback == null ||
          !_isValidCoordinate(fallback.latitude, fallback.longitude)) {
        debugPrint(
          '⚠️ Ignoring invalid rider location update: '
          'lat=${incomingLocation.latitude}, lon=${incomingLocation.longitude}',
        );
        return;
      }
      incomingLocation = fallback;
    }

    print(
      '📍 Updating rider location: ${incomingLocation.latitude}, ${incomingLocation.longitude}',
    );
    final smoothedLocation = _smoothIncomingLocation(incomingLocation);

    // Add current location to history for the trail
    final updatedHistory = List<LocationHistory>.from(
      _trackingData!.locationHistory,
    );
    updatedHistory.add(
      LocationHistory(location: smoothedLocation, timestamp: DateTime.now()),
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
      currentLocation: smoothedLocation,
      destination: _trackingData!.destination,
      pickupLocation: _trackingData!.pickupLocation,
      status: event.status,
      distanceRemaining: event.distance,
      estimatedArrival: event.eta,
      route: _trackingData!.route,
      rider: _trackingData!.rider,
      locationHistory: updatedHistory,
    );

    final newPosition = smoothedLocation.toLatLng();

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

    final normalizedStatus = _trackingData!.status.toLowerCase();
    final shouldForcePickupPreview =
        normalizedStatus == 'preparing' ||
        normalizedStatus == 'confirmed' ||
        normalizedStatus == 'ready';
    final hasEncodedRoute = _trackingData!.route?.polyline.isNotEmpty ?? false;
    if (shouldForcePickupPreview || !hasEncodedRoute) {
      _createFallbackRoutePolylines();
    }

    // Only animate camera if not already following (to avoid jerky movement)
    // Camera will follow naturally during marker animation
    _syncConnectionHealth();
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
    _lastRealtimeUpdateAt = DateTime.now();
    _consecutiveFallbackFailures = 0;

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

    _syncConnectionHealth();
    notifyListeners();
  }

  /// Update rider marker position
  void _updateRiderMarker(LatLng newPosition, double rotation) {
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
    if (_markers.isNotEmpty) {
      Future<void>.delayed(const Duration(milliseconds: 180), () {
        _animateCameraToFitMarkers();
      });
    }
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
    _stopDemoSimulation();
    final orderId = _trackingData?.orderId ?? _activeOrderId;
    if (!_trackingDemoMode && orderId != null) {
      _socketService.leaveOrderRoom(orderId);
    }
    if (!_trackingDemoMode) {
      _socketService.disconnect();
    }
    _stopFallbackPolling();
    _activeOrderId = null;
    _trackingData = null;
    _lastKnownPosition = null;
    _smoothedRealtimePosition = null;
    _currentBearing = 0;
    _hasEstablishedSocketConnectionForSession = false;
    _isWaitingForRider = false;
    _stopWaitingForRiderPolling();
    _lastRealtimeUpdateAt = null;
    _lastSuccessfulApiSyncAt = null;
    _consecutiveFallbackFailures = 0;
    _connectionHealth = TrackingConnectionHealth.offline;
    _markers = {};
    _polylines = {};
    _circles = {};
    _markerIconCache.clear();
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _stopDemoSimulation();
    _animationTimer?.cancel();
    _stopWaitingForRiderPolling();
    _stopFallbackPolling();
    _stopConnectionHealthMonitor();
    _locationSubscription?.cancel();
    _statusSubscription?.cancel();
    _connectionSubscription?.cancel();
    _smoothedRealtimePosition = null;
    _markerIconCache.clear();
    if (!_trackingDemoMode) {
      _socketService.disconnect();
    }
    _mapController?.dispose();
    super.dispose();
  }
}
