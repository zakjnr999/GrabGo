import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:grab_go_customer/core/native/native_location_service.dart';
import 'package:grab_go_customer/shared/services/location_service.dart';
import 'package:grab_go_shared/shared/services/cache_service.dart';

/// Enhanced Location Provider with Native Code Integration
///
/// This provider uses platform-native location services (FusedLocationProvider on Android,
/// CLLocationManager on iOS) for:
/// - Better battery optimization
/// - More accurate location tracking
/// - Geofencing support for delivery zones
/// - Background location updates
///
/// Falls back to geolocator package if native service is unavailable.
class NativeLocationProvider with ChangeNotifier {
  // ============================================
  // State
  // ============================================

  String _address = "";
  double? _latitude;
  double? _longitude;
  double? _accuracy;
  double? _speed;
  double? _bearing;

  bool _isFetching = false;
  bool _isTracking = false;
  bool _isNativeServiceAvailable = false;
  LocationTrackingMode _currentTrackingMode = LocationTrackingMode.balanced;

  // Location accuracy tracking (for popup)
  double? _currentGPSLatitude;
  double? _currentGPSLongitude;
  bool _hasCheckedAccuracy = false;
  bool _popupDismissed = false;

  // Error handling
  String? _lastError;
  DateTime? _lastErrorTime;

  // Subscriptions
  StreamSubscription<NativeLocation>? _locationSubscription;
  StreamSubscription<GeofenceEvent>? _geofenceSubscription;

  // Geofence tracking
  final Map<String, GeofenceConfig> _activeGeofences = {};
  final List<GeofenceEvent> _recentGeofenceEvents = [];
  static const int _maxRecentEvents = 50;

  // Native service
  final NativeLocationService _nativeService = NativeLocationService();

  // ============================================
  // Getters
  // ============================================

  String get address => _address;
  double? get latitude => _latitude;
  double? get longitude => _longitude;
  double? get accuracy => _accuracy;
  double? get speed => _speed;
  double? get bearing => _bearing;

  bool get isFetching => _isFetching;
  bool get isTracking => _isTracking;
  bool get isNativeServiceAvailable => _isNativeServiceAvailable;
  LocationTrackingMode get currentTrackingMode => _currentTrackingMode;

  String? get lastError => _lastError;
  DateTime? get lastErrorTime => _lastErrorTime;

  /// Distance from saved location to current GPS location (for accuracy popup)
  double? get distanceFromSavedLocation => _calculateDistance();

  /// Whether to show the location accuracy popup
  bool get shouldShowAccuracyPopup => !_popupDismissed && _hasCheckedAccuracy && (distanceFromSavedLocation ?? 0) > 500;

  /// Active geofence IDs
  List<String> get activeGeofenceIds => _activeGeofences.keys.toList();

  /// Recent geofence events
  List<GeofenceEvent> get recentGeofenceEvents => List.unmodifiable(_recentGeofenceEvents);

  /// Whether location has been obtained
  bool get hasLocation => _latitude != null && _longitude != null;

  // ============================================
  // Constructor & Initialization
  // ============================================

  NativeLocationProvider() {
    // Load cached location and initialize native service
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialize();
    });
  }

  Future<void> _initialize() async {
    // Load cached location first for immediate display
    await _loadCachedLocation();

    // Try to initialize native location service
    _isNativeServiceAvailable = await _nativeService.initialize();

    if (_isNativeServiceAvailable) {
      debugPrint('✅ NativeLocationProvider: Using native location service');
      _setupNativeListeners();
    } else {
      debugPrint('⚠️ NativeLocationProvider: Falling back to geolocator');
    }

    // Check location accuracy in background
    _checkLocationAccuracy();

    notifyListeners();
  }

  void _setupNativeListeners() {
    // Cancel existing subscriptions
    _locationSubscription?.cancel();
    _geofenceSubscription?.cancel();

    // Listen to location updates
    _locationSubscription = _nativeService.locationStream.listen(
      _onNativeLocationUpdate,
      onError: (error) {
        _setError('Location stream error: $error');
      },
    );

    // Listen to geofence events
    _geofenceSubscription = _nativeService.geofenceStream.listen(
      _onGeofenceEvent,
      onError: (error) {
        _setError('Geofence stream error: $error');
      },
    );
  }

  void _onNativeLocationUpdate(NativeLocation location) {
    _latitude = location.latitude;
    _longitude = location.longitude;
    _accuracy = location.accuracy;
    _speed = location.speed;
    _bearing = location.bearing;

    // Update address if provided
    if (location.address != null && location.address!.isNotEmpty) {
      _address = location.address!;
    }

    // Also update current GPS location for accuracy checking
    _currentGPSLatitude = location.latitude;
    _currentGPSLongitude = location.longitude;
    _hasCheckedAccuracy = true;

    // Clear any previous error
    _lastError = null;

    notifyListeners();

    if (kDebugMode) {
      debugPrint(
        '📍 Location update: ${location.latitude}, ${location.longitude} '
        '(accuracy: ${location.accuracy.toStringAsFixed(1)}m)',
      );
    }
  }

  void _onGeofenceEvent(GeofenceEvent event) {
    // Add to recent events (keep last N)
    _recentGeofenceEvents.insert(0, event);
    if (_recentGeofenceEvents.length > _maxRecentEvents) {
      _recentGeofenceEvents.removeLast();
    }

    notifyListeners();

    if (kDebugMode) {
      debugPrint('🎯 Geofence: ${event.geofenceId} - ${event.transition.name}');
    }
  }

  // ============================================
  // Permission Handling
  // ============================================

  /// Check location permission status
  Future<String> checkPermission() async {
    if (_isNativeServiceAvailable) {
      return await _nativeService.checkPermission();
    }
    // Fallback to geolocator-based check
    final status = await LocationService.checkPermissionStatus();
    return _mapGeolocatorPermission(status);
  }

  /// Request location permission
  Future<String> requestPermission() async {
    if (_isNativeServiceAvailable) {
      return await _nativeService.requestPermission();
    }
    // Fallback
    return 'denied';
  }

  /// Request background location permission (needed for geofencing)
  Future<String> requestBackgroundPermission() async {
    if (_isNativeServiceAvailable) {
      return await _nativeService.requestBackgroundPermission();
    }
    return 'denied';
  }

  /// Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    if (_isNativeServiceAvailable) {
      return await _nativeService.isLocationServiceEnabled();
    }
    return await LocationService.isServiceEnabled();
  }

  /// Open location settings
  Future<bool> openLocationSettings() async {
    if (_isNativeServiceAvailable) {
      return await _nativeService.openLocationSettings();
    }
    return false;
  }

  /// Open app settings
  Future<bool> openAppSettings() async {
    if (_isNativeServiceAvailable) {
      return await _nativeService.openAppSettings();
    }
    return false;
  }

  String _mapGeolocatorPermission(dynamic status) {
    final statusStr = status.toString().toLowerCase();
    if (statusStr.contains('always') || statusStr.contains('whileinuse')) {
      return 'granted';
    } else if (statusStr.contains('deniedforever')) {
      return 'deniedForever';
    }
    return 'denied';
  }

  // ============================================
  // Location Fetching
  // ============================================

  /// Fetch current location and address
  Future<void> fetchAddress() async {
    if (_isFetching) return;

    // Try to use cached location if valid
    if (CacheService.isLocationCacheValid()) {
      await _loadCachedLocation();
      if (_address.isNotEmpty) {
        return;
      }
    }

    _isFetching = true;
    notifyListeners();

    try {
      if (_isNativeServiceAvailable) {
        await _fetchAddressNative();
      } else {
        await _fetchAddressFallback();
      }
    } catch (e) {
      _setError('Error fetching address: $e');
    } finally {
      _isFetching = false;
      notifyListeners();
    }
  }

  Future<void> _fetchAddressNative() async {
    final location = await _nativeService.getCurrentLocation(mode: LocationTrackingMode.highAccuracy, timeoutMs: 15000);

    if (location != null) {
      _latitude = location.latitude;
      _longitude = location.longitude;
      _accuracy = location.accuracy;

      // Get address via native reverse geocoding
      final address = await _nativeService.reverseGeocode(location.latitude, location.longitude);

      _address = address ?? 'Location obtained';

      // Update GPS tracking for accuracy popup
      _currentGPSLatitude = location.latitude;
      _currentGPSLongitude = location.longitude;
      _hasCheckedAccuracy = true;

      // Cache the location
      await CacheService.saveUserLocation(latitude: _latitude!, longitude: _longitude!, address: _address);
    }
  }

  Future<void> _fetchAddressFallback() async {
    _address = await LocationService.getCurrentAddress();

    final position = await LocationService.getCurrentPosition();
    if (position != null) {
      _latitude = position.latitude;
      _longitude = position.longitude;

      await CacheService.saveUserLocation(latitude: _latitude!, longitude: _longitude!, address: _address);
    }
  }

  /// Get current location (one-shot)
  Future<NativeLocation?> getCurrentLocation({
    LocationTrackingMode mode = LocationTrackingMode.highAccuracy,
    int timeoutMs = 15000,
  }) async {
    if (_isNativeServiceAvailable) {
      return await _nativeService.getCurrentLocation(mode: mode, timeoutMs: timeoutMs);
    }

    // Fallback to geolocator
    final position = await LocationService.getCurrentPosition();
    if (position != null) {
      return NativeLocation(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        altitude: position.altitude,
        speed: position.speed,
        bearing: position.heading,
        timestamp: position.timestamp,
      );
    }

    return null;
  }

  // ============================================
  // Continuous Location Tracking
  // ============================================

  /// Start continuous location tracking
  Future<bool> startTracking({
    LocationTrackingMode mode = LocationTrackingMode.balanced,
    double smallestDisplacement = 10.0,
  }) async {
    if (_isTracking) return true;

    if (_isNativeServiceAvailable) {
      final success = await _nativeService.startLocationTracking(
        mode: mode,
        smallestDisplacementMeters: smallestDisplacement,
        intervalMs: _getIntervalForMode(mode),
      );

      if (success) {
        _isTracking = true;
        _currentTrackingMode = mode;
        notifyListeners();
        debugPrint('✅ Location tracking started (mode: ${mode.name})');
      }

      return success;
    }

    debugPrint('⚠️ Native tracking not available');
    return false;
  }

  /// Stop location tracking
  Future<bool> stopTracking() async {
    if (!_isTracking) return true;

    if (_isNativeServiceAvailable) {
      final success = await _nativeService.stopLocationTracking();

      if (success) {
        _isTracking = false;
        notifyListeners();
        debugPrint('✅ Location tracking stopped');
      }

      return success;
    }

    return true;
  }

  /// Change tracking mode while tracking
  Future<bool> changeTrackingMode(LocationTrackingMode mode) async {
    if (!_isTracking) return false;

    // Stop and restart with new mode
    await stopTracking();
    return await startTracking(mode: mode);
  }

  int _getIntervalForMode(LocationTrackingMode mode) {
    switch (mode) {
      case LocationTrackingMode.highAccuracy:
        return 5000; // 5 seconds
      case LocationTrackingMode.balanced:
        return 15000; // 15 seconds
      case LocationTrackingMode.lowPower:
        return 60000; // 1 minute
      case LocationTrackingMode.passive:
        return 300000; // 5 minutes
    }
  }

  // ============================================
  // Geofencing
  // ============================================

  /// Add a geofence for delivery zone monitoring
  Future<bool> addDeliveryGeofence({
    required String orderId,
    required double latitude,
    required double longitude,
    double radiusMeters = 200.0,
  }) async {
    final config = GeofenceConfig(
      id: 'delivery_$orderId',
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters,
      notifyOnEnter: true,
      notifyOnExit: false,
      notifyOnDwell: false,
    );

    return await addGeofence(config);
  }

  /// Add a restaurant proximity geofence
  Future<bool> addRestaurantGeofence({
    required String restaurantId,
    required double latitude,
    required double longitude,
    double radiusMeters = 500.0,
  }) async {
    final config = GeofenceConfig(
      id: 'restaurant_$restaurantId',
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters,
      notifyOnEnter: true,
      notifyOnExit: true,
    );

    return await addGeofence(config);
  }

  /// Add a custom geofence
  Future<bool> addGeofence(GeofenceConfig config) async {
    if (!_isNativeServiceAvailable) {
      debugPrint('⚠️ Geofencing requires native service');
      return false;
    }

    // Check permissions first
    final hasPermissions = await _nativeService.hasGeofencingPermissions();
    if (!hasPermissions) {
      _setError('Background location permission required for geofencing');
      return false;
    }

    final success = await _nativeService.addGeofence(config);

    if (success) {
      _activeGeofences[config.id] = config;
      notifyListeners();
      debugPrint('✅ Geofence added: ${config.id}');
    }

    return success;
  }

  /// Add multiple geofences at once
  Future<int> addGeofences(List<GeofenceConfig> configs) async {
    if (!_isNativeServiceAvailable) return 0;

    final hasPermissions = await _nativeService.hasGeofencingPermissions();
    if (!hasPermissions) {
      _setError('Background location permission required for geofencing');
      return 0;
    }

    final count = await _nativeService.addGeofences(configs);

    // Track added geofences
    for (var i = 0; i < min(count, configs.length); i++) {
      _activeGeofences[configs[i].id] = configs[i];
    }

    notifyListeners();
    return count;
  }

  /// Remove a geofence
  Future<bool> removeGeofence(String geofenceId) async {
    if (!_isNativeServiceAvailable) return false;

    final success = await _nativeService.removeGeofence(geofenceId);

    if (success) {
      _activeGeofences.remove(geofenceId);
      notifyListeners();
    }

    return success;
  }

  /// Remove all geofences
  Future<bool> removeAllGeofences() async {
    if (!_isNativeServiceAvailable) return false;

    final success = await _nativeService.removeAllGeofences();

    if (success) {
      _activeGeofences.clear();
      notifyListeners();
    }

    return success;
  }

  // ============================================
  // Location Update (Manual)
  // ============================================

  /// Update location manually (from place picker, etc.)
  Future<void> updateLocation({required double latitude, required double longitude, required String address}) async {
    _latitude = latitude;
    _longitude = longitude;
    _address = address;

    // Save to cache
    await CacheService.saveUserLocation(latitude: latitude, longitude: longitude, address: address);

    notifyListeners();
  }

  /// Clear location data
  void clearAddress() {
    _address = "";
    _latitude = null;
    _longitude = null;
    _accuracy = null;
    notifyListeners();
    LocationService.clearCache();
  }

  // ============================================
  // Location Accuracy Popup
  // ============================================

  /// Dismiss the accuracy popup
  void dismissAccuracyPopup() {
    _popupDismissed = true;
    notifyListeners();
  }

  /// Update to current GPS location
  Future<void> updateToCurrentLocation() async {
    if (_currentGPSLatitude == null || _currentGPSLongitude == null) return;

    try {
      String? address;

      if (_isNativeServiceAvailable) {
        address = await _nativeService.reverseGeocode(_currentGPSLatitude!, _currentGPSLongitude!);
      } else {
        address = await LocationService.getAddressFromCoordinates(_currentGPSLatitude!, _currentGPSLongitude!);
      }

      await updateLocation(
        latitude: _currentGPSLatitude!,
        longitude: _currentGPSLongitude!,
        address: address ?? 'Current location',
      );

      _popupDismissed = true;
      notifyListeners();
    } catch (e) {
      _setError('Error updating to current location: $e');
    }
  }

  // ============================================
  // Utility Methods
  // ============================================

  /// Calculate distance between two points (in meters)
  Future<double> getDistance(double startLat, double startLng, double endLat, double endLng) async {
    if (_isNativeServiceAvailable) {
      return await _nativeService.getDistance(startLat: startLat, startLng: startLng, endLat: endLat, endLng: endLng);
    }

    // Fallback Haversine calculation
    return _haversineDistance(startLat, startLng, endLat, endLng);
  }

  /// Get distance from current location to a point
  Future<double?> getDistanceFromCurrent(double lat, double lng) async {
    if (_latitude == null || _longitude == null) return null;
    return await getDistance(_latitude!, _longitude!, lat, lng);
  }

  double _haversineDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // meters

    final lat1Rad = lat1 * (pi / 180);
    final lat2Rad = lat2 * (pi / 180);
    final deltaLat = (lat2 - lat1) * (pi / 180);
    final deltaLon = (lon2 - lon1) * (pi / 180);

    final a =
        sin(deltaLat / 2) * sin(deltaLat / 2) + cos(lat1Rad) * cos(lat2Rad) * sin(deltaLon / 2) * sin(deltaLon / 2);

    final c = 2 * asin(sqrt(a));

    return earthRadius * c;
  }

  // ============================================
  // Private Helpers
  // ============================================

  Future<void> _loadCachedLocation() async {
    try {
      final locationData = CacheService.getUserLocation();
      if (locationData != null && CacheService.isLocationCacheValid()) {
        _address = locationData['address'] ?? '';
        _latitude = locationData['latitude']?.toDouble();
        _longitude = locationData['longitude']?.toDouble();
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading cached location: $e');
      }
    }
  }

  Future<void> _checkLocationAccuracy() async {
    try {
      NativeLocation? location;

      if (_isNativeServiceAvailable) {
        location = await _nativeService.getCurrentLocation(mode: LocationTrackingMode.balanced, timeoutMs: 10000);
      } else {
        final position = await LocationService.getCurrentPosition();
        if (position != null) {
          location = NativeLocation(
            latitude: position.latitude,
            longitude: position.longitude,
            accuracy: position.accuracy,
            timestamp: position.timestamp,
          );
        }
      }

      if (location != null) {
        _currentGPSLatitude = location.latitude;
        _currentGPSLongitude = location.longitude;
        _hasCheckedAccuracy = true;
        notifyListeners();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error checking location accuracy: $e');
      }
    }
  }

  double? _calculateDistance() {
    if (_latitude == null || _longitude == null || _currentGPSLatitude == null || _currentGPSLongitude == null) {
      return null;
    }

    return _haversineDistance(_latitude!, _longitude!, _currentGPSLatitude!, _currentGPSLongitude!);
  }

  void _setError(String message) {
    _lastError = message;
    _lastErrorTime = DateTime.now();
    if (kDebugMode) {
      debugPrint('❌ NativeLocationProvider: $message');
    }
    notifyListeners();
  }

  // ============================================
  // Cleanup
  // ============================================

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _geofenceSubscription?.cancel();

    // Stop tracking if active
    if (_isTracking) {
      _nativeService.stopLocationTracking();
    }

    // Remove all geofences
    _nativeService.removeAllGeofences();

    // Dispose native service
    _nativeService.dispose();

    super.dispose();
  }
}
