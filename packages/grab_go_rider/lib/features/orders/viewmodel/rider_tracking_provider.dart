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
import 'package:grab_go_shared/shared/utils/colors.dart';
import 'package:grab_go_shared/shared/widgets/custom_map_markers.dart';

/// State for the rider tracking provider
enum RiderTrackingState { idle, initializing, active, paused, error }

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
  double? _speed;
  double? _accuracy;
  double? _distanceRemaining;
  double? _etaMinutes;

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
  LatLng? _lastAnimatedPosition;
  Timer? _markerAnimationTimer;

  // Geofence radius in meters
  static const double _geofenceRadius = 50.0;

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
  DateTime? _lastLocationUpdateTime;

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

    _latitude = data['latitude'] as double?;
    _longitude = data['longitude'] as double?;
    _speed = data['speed'] as double?;
    _accuracy = data['accuracy'] as double?;
    _distanceRemaining = data['distanceRemaining'] as double?;
    _etaMinutes = data['etaMinutes'] as double?;

    notifyListeners();
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
  }) async {
    if (_activeOrderId != null && _activeOrderId != orderId) {
      debugPrint('⚠️ Already tracking order $_activeOrderId, stopping first');
      await stopTracking();
    }

    _setState(RiderTrackingState.initializing);
    _activeOrderId = orderId;
    _activeCustomerId = customerId;
    _activeRiderId = riderId;

    // Store coordinates for map
    _pickupLatitude = pickupLatitude;
    _pickupLongitude = pickupLongitude;
    _destinationLatitude = destinationLatitude;
    _destinationLongitude = destinationLongitude;

    try {
      debugPrint('🚀 Initializing tracking for order: $orderId');

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

  /// Start the foreground service for background location tracking
  Future<void> _startForegroundService() async {
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
    try {
      await _foregroundService.stopService();
      debugPrint('✅ Foreground service stopped');
    } catch (e) {
      debugPrint('⚠️ Error stopping foreground service: $e');
    }
  }

  /// Resume tracking for an existing order (e.g., after app restart)
  Future<bool> resumeTracking(String orderId) async {
    _setState(RiderTrackingState.initializing);

    try {
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

  /// Mark that rider is now in transit to customer
  Future<bool> markAsInTransit() async {
    final success = await _updateStatus(TrackingStatus.inTransit);
    if (success) {
      // Switch to high-frequency updates for active delivery
      _config = TrackingConfig.activeDelivery;
      await _restartLocationUpdates();
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

      final trackingSyncSuccess = await _trackingService.updateStatus(
        orderId: _activeOrderId!,
        status: newStatus,
      );

      _currentStatus = newStatus;

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

    // Also use a timer to ensure regular updates to backend
    _locationUpdateTimer = Timer.periodic(
      Duration(milliseconds: _config.updateIntervalMs),
      (_) => _sendLocationToBackend(),
    );

    debugPrint(
      '✅ Location updates started (interval: ${_config.updateIntervalMs}ms)',
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
    _latitude = position.latitude;
    _longitude = position.longitude;
    _speed = position.speed;
    _accuracy = position.accuracy;

    // Clear errors on successful location
    _consecutiveErrors = 0;
    _lastError = null;

    // Update rider marker on map
    _updateRiderMarker();

    notifyListeners();

    // Send to backend (throttled by timer, but can send immediately on significant movement)
    final shouldSendImmediately =
        _lastLocationUpdateTime == null ||
        DateTime.now().difference(_lastLocationUpdateTime!).inMilliseconds >
            (_config.updateIntervalMs ~/ 2);

    if (shouldSendImmediately && position.accuracy < 50) {
      // Only send if accuracy is reasonable
      _sendLocationToBackend();
    }
  }

  Future<void> _sendLocationToBackend() async {
    if (_activeOrderId == null || _latitude == null || _longitude == null)
      return;

    // Don't send if status is delivered or cancelled
    if (_currentStatus == TrackingStatus.delivered ||
        _currentStatus == TrackingStatus.cancelled)
      return;

    try {
      final response = await _trackingService.updateLocation(
        orderId: _activeOrderId!,
        latitude: _latitude!,
        longitude: _longitude!,
        speed: _speed ?? 0,
        accuracy: _accuracy ?? 0,
      );

      if (response != null) {
        _distanceRemaining = response.distanceRemaining;
        _etaMinutes = response.etaMinutes;
        _lastLocationUpdateTime = DateTime.now();

        // Update status if backend changed it (e.g., nearby detection)
        final newStatus = TrackingStatus.fromString(response.status);
        if (newStatus != _currentStatus) {
          _currentStatus = newStatus;
          debugPrint('📍 Status changed by backend: ${newStatus.name}');
        }

        notifyListeners();
      }
    } catch (e) {
      debugPrint('❌ Error sending location to backend: $e');
      _handleLocationError();
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

      _latitude = position.latitude;
      _longitude = position.longitude;
      _speed = position.speed;
      _accuracy = position.accuracy;
      debugPrint('📍 Got current position: $_latitude, $_longitude');
      notifyListeners();
    } catch (e) {
      debugPrint('⚠️ Error getting current position: $e');
      // Try to get last known position as fallback
      try {
        final lastPosition = await Geolocator.getLastKnownPosition();
        if (lastPosition != null) {
          _latitude = lastPosition.latitude;
          _longitude = lastPosition.longitude;
          debugPrint('📍 Using last known position: $_latitude, $_longitude');
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
    _lastError = message;
    _lastErrorTime = DateTime.now();
    _setState(RiderTrackingState.error);
    debugPrint('❌ RiderTrackingProvider: $message');
    notifyListeners();
  }

  void _resetState() {
    _activeOrderId = null;
    _activeCustomerId = null;
    _activeRiderId = null;
    _currentStatus = TrackingStatus.preparing;
    _trackingInfo = null;
    _distanceRemaining = null;
    _etaMinutes = null;
    _lastError = null;
    _consecutiveErrors = 0;
    _lastLocationUpdateTime = null;
    _config = TrackingConfig.waitingAtPickup;
    _pickupLatitude = null;
    _pickupLongitude = null;
    _destinationLatitude = null;
    _destinationLongitude = null;
    _markers = {};
    _polylines = {};
    _circles = {};
    _lastAnimatedPosition = null;
    _setState(RiderTrackingState.idle);
  }

  /// Clear error state and retry
  void clearError() {
    _lastError = null;
    _lastErrorTime = null;
    _consecutiveErrors = 0;
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
    });
  }

  /// Setup markers and polylines on the map
  Future<void> _setupMapElements() async {
    final markers = <Marker>{};
    const primaryColor = AppColors.serviceFood;

    // 1. Add Rider marker (current location - "You")
    if (_latitude != null && _longitude != null) {
      if (!_markerIconCache.containsKey('rider')) {
        _markerIconCache['rider'] = await CustomMapMarkers.createRiderMarker(
          name: 'You',
          primaryColor: primaryColor,
        );
      }

      markers.add(
        Marker(
          markerId: const MarkerId('rider'),
          position: LatLng(_latitude!, _longitude!),
          icon: _markerIconCache['rider']!,
          infoWindow: const InfoWindow(title: 'You', snippet: 'Your location'),
          anchor: const Offset(0.5, 0.5),
          zIndexInt: 10,
        ),
      );
      _lastAnimatedPosition = LatLng(_latitude!, _longitude!);
    }

    // 2. Add Restaurant/Pickup marker
    if (_pickupLatitude != null && _pickupLongitude != null) {
      if (!_markerIconCache.containsKey('pickup')) {
        _markerIconCache['pickup'] = await CustomMapMarkers.createStoreMarker(
          name: 'Pickup',
          primaryColor: primaryColor,
        );
      }

      markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: LatLng(_pickupLatitude!, _pickupLongitude!),
          icon: _markerIconCache['pickup']!,
          infoWindow: const InfoWindow(
            title: 'Restaurant',
            snippet: 'Pickup location',
          ),
          anchor: const Offset(0.5, 0.5),
          zIndexInt: 5,
        ),
      );
    }

    // 3. Add Customer/Destination marker with home icon
    if (_destinationLatitude != null && _destinationLongitude != null) {
      if (!_markerIconCache.containsKey('destination')) {
        _markerIconCache['destination'] =
            await CustomMapMarkers.createDestinationMarker(
              name: 'Delivery',
              primaryColor: AppColors.serviceGrocery,
            );
      }

      markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: LatLng(_destinationLatitude!, _destinationLongitude!),
          icon: _markerIconCache['destination']!,
          infoWindow: const InfoWindow(
            title: 'Customer',
            snippet: 'Delivery address',
          ),
          anchor: const Offset(0.5, 0.5),
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
    const pickupColor = AppColors.serviceFood;
    const deliveryColor = AppColors.serviceGrocery;

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

      final routePolyline = Polyline(
        polylineId: const PolylineId('route'),
        points: polylineCoordinates,
        color: AppColors.serviceFood.withValues(alpha: 0.7),
        width: 4,
        patterns: [PatternItem.dash(15), PatternItem.gap(10)],
      );

      _polylines = {routePolyline};
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error creating polyline: $e');
      _createSimplePolyline();
    }
  }

  /// Create a simple polyline connecting rider -> pickup -> destination
  void _createSimplePolyline() {
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
      _polylines = {
        Polyline(
          polylineId: const PolylineId('route'),
          points: points,
          color: AppColors.serviceFood.withValues(alpha: 0.5),
          width: 4,
          patterns: [PatternItem.dash(15), PatternItem.gap(10)],
        ),
      };
    }
  }

  /// Update rider marker position with smooth animation
  void _updateRiderMarker() async {
    if (_latitude == null || _longitude == null) return;

    final newPosition = LatLng(_latitude!, _longitude!);

    // Check if rider marker exists, if not create it
    final hasRiderMarker = _markers.any((m) => m.markerId.value == 'rider');
    if (!hasRiderMarker) {
      // Create rider marker if it doesn't exist
      const primaryColor = AppColors.serviceFood;
      if (!_markerIconCache.containsKey('rider')) {
        _markerIconCache['rider'] = await CustomMapMarkers.createRiderMarker(
          name: 'You',
          primaryColor: primaryColor,
        );
      }

      _markers = {
        ..._markers,
        Marker(
          markerId: const MarkerId('rider'),
          position: newPosition,
          icon: _markerIconCache['rider']!,
          infoWindow: const InfoWindow(title: 'You', snippet: 'Your location'),
          anchor: const Offset(0.5, 0.5),
          zIndexInt: 10,
        ),
      };
      _lastAnimatedPosition = newPosition;
      notifyListeners();
      return;
    }

    if (_lastAnimatedPosition != null) {
      // Calculate bearing for rotation
      final bearing = _calculateBearing(_lastAnimatedPosition!, newPosition);
      _animateMarkerMovement(_lastAnimatedPosition!, newPosition, bearing);
    } else {
      _updateRiderMarkerPosition(newPosition, 0);
    }

    _lastAnimatedPosition = newPosition;
  }

  /// Smoothly animate marker from one position to another
  void _animateMarkerMovement(LatLng start, LatLng end, double bearing) {
    _markerAnimationTimer?.cancel();

    int steps = 15;
    int currentStep = 0;

    _markerAnimationTimer = Timer.periodic(const Duration(milliseconds: 50), (
      timer,
    ) {
      if (currentStep >= steps || _isDisposed) {
        timer.cancel();
        return;
      }

      currentStep++;
      double fraction = currentStep / steps;

      double lat = start.latitude + (end.latitude - start.latitude) * fraction;
      double lng =
          start.longitude + (end.longitude - start.longitude) * fraction;

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

  /// Update rider marker position
  void _updateRiderMarkerPosition(LatLng newPosition, double rotation) {
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

    _mapController?.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  /// Center camera on rider's current location
  void centerOnRider() {
    if (_mapController == null || _latitude == null || _longitude == null)
      return;
    _mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(LatLng(_latitude!, _longitude!), 16),
    );
  }

  // ============================================
  // Cleanup
  // ============================================

  @override
  void dispose() {
    _isDisposed = true;
    _stopLocationUpdates();
    _backgroundServiceSubscription?.cancel();
    _backgroundServiceSubscription = null;
    _markerAnimationTimer?.cancel();
    _markerAnimationTimer = null;
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
