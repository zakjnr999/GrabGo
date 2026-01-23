import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Data class for location updates
class NativeLocation {
  final double latitude;
  final double longitude;
  final double accuracy;
  final double altitude;
  final double speed;
  final double bearing;
  final DateTime timestamp;
  final String? address;

  NativeLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    this.altitude = 0.0,
    this.speed = 0.0,
    this.bearing = 0.0,
    required this.timestamp,
    this.address,
  });

  factory NativeLocation.fromMap(Map<dynamic, dynamic> map) {
    return NativeLocation(
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      accuracy: (map['accuracy'] as num?)?.toDouble() ?? 0.0,
      altitude: (map['altitude'] as num?)?.toDouble() ?? 0.0,
      speed: (map['speed'] as num?)?.toDouble() ?? 0.0,
      bearing: (map['bearing'] as num?)?.toDouble() ?? 0.0,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (map['timestamp'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      ),
      address: map['address'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'latitude': latitude,
    'longitude': longitude,
    'accuracy': accuracy,
    'altitude': altitude,
    'speed': speed,
    'bearing': bearing,
    'timestamp': timestamp.millisecondsSinceEpoch,
    'address': address,
  };

  @override
  String toString() => 'NativeLocation(lat: $latitude, lng: $longitude, accuracy: ${accuracy.toStringAsFixed(1)}m)';
}

/// Geofence event data
class GeofenceEvent {
  final String geofenceId;
  final GeofenceTransition transition;
  final NativeLocation? location;
  final DateTime timestamp;

  GeofenceEvent({required this.geofenceId, required this.transition, this.location, required this.timestamp});

  factory GeofenceEvent.fromMap(Map<dynamic, dynamic> map) {
    final transitionStr = map['transition'] as String? ?? 'unknown';
    return GeofenceEvent(
      geofenceId: map['geofenceId'] as String? ?? '',
      transition: GeofenceTransition.values.firstWhere(
        (e) => e.name == transitionStr,
        orElse: () => GeofenceTransition.unknown,
      ),
      location: map['location'] != null ? NativeLocation.fromMap(map['location'] as Map<dynamic, dynamic>) : null,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (map['timestamp'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }
}

enum GeofenceTransition { enter, exit, dwell, unknown }

/// Location tracking mode for battery optimization
enum LocationTrackingMode {
  /// High accuracy, frequent updates (GPS + Network)
  highAccuracy,

  /// Balanced accuracy (Network + GPS occasionally)
  balanced,

  /// Low power, less frequent updates (Network only)
  lowPower,

  /// Passive - only receive updates from other apps
  passive,
}

/// Geofence configuration
class GeofenceConfig {
  final String id;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final int loiteringDelayMs;
  final int expirationDurationMs;
  final bool notifyOnEnter;
  final bool notifyOnExit;
  final bool notifyOnDwell;

  GeofenceConfig({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    this.loiteringDelayMs = 30000, // 30 seconds
    this.expirationDurationMs = -1, // Never expire
    this.notifyOnEnter = true,
    this.notifyOnExit = true,
    this.notifyOnDwell = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'latitude': latitude,
    'longitude': longitude,
    'radiusMeters': radiusMeters,
    'loiteringDelayMs': loiteringDelayMs,
    'expirationDurationMs': expirationDurationMs,
    'notifyOnEnter': notifyOnEnter,
    'notifyOnExit': notifyOnExit,
    'notifyOnDwell': notifyOnDwell,
  };
}

/// Native Location Service using Platform Channels
/// Provides battery-optimized location tracking and geofencing
class NativeLocationService {
  static const String _channelName = 'com.grabgo.customer/location';
  static const String _eventChannelName = 'com.grabgo.customer/location_events';
  static const String _geofenceEventChannelName = 'com.grabgo.customer/geofence_events';

  static final NativeLocationService _instance = NativeLocationService._internal();
  factory NativeLocationService() => _instance;
  NativeLocationService._internal();

  final MethodChannel _channel = const MethodChannel(_channelName);
  final EventChannel _locationEventChannel = const EventChannel(_eventChannelName);
  final EventChannel _geofenceEventChannel = const EventChannel(_geofenceEventChannelName);

  StreamSubscription<dynamic>? _locationSubscription;
  StreamSubscription<dynamic>? _geofenceSubscription;

  final _locationController = StreamController<NativeLocation>.broadcast();
  final _geofenceController = StreamController<GeofenceEvent>.broadcast();

  /// Stream of location updates
  Stream<NativeLocation> get locationStream => _locationController.stream;

  /// Stream of geofence events
  Stream<GeofenceEvent> get geofenceStream => _geofenceController.stream;

  bool _isInitialized = false;
  bool _isTracking = false;

  bool get isInitialized => _isInitialized;
  bool get isTracking => _isTracking;

  /// Initialize the native location service
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    try {
      final result = await _channel.invokeMethod<bool>('initialize');
      _isInitialized = result ?? false;

      if (_isInitialized) {
        // Cancel any existing subscriptions before setting up new ones
        await _locationSubscription?.cancel();
        await _geofenceSubscription?.cancel();
        _locationSubscription = null;
        _geofenceSubscription = null;

        _setupEventListeners();
        debugPrint('✅ NativeLocationService initialized');
      }

      return _isInitialized;
    } on PlatformException catch (e) {
      debugPrint('❌ Failed to initialize NativeLocationService: ${e.message}');
      return false;
    }
  }

  void _setupEventListeners() {
    // Location updates stream
    _locationSubscription = _locationEventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        if (event is Map) {
          try {
            final location = NativeLocation.fromMap(event);
            _locationController.add(location);
            debugPrint('📍 Native location update: $location');
          } catch (e) {
            debugPrint('❌ Error parsing location event: $e');
          }
        }
      },
      onError: (error) {
        debugPrint('❌ Location stream error: $error');
      },
    );

    // Geofence events stream
    _geofenceSubscription = _geofenceEventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        if (event is Map) {
          try {
            final geofenceEvent = GeofenceEvent.fromMap(event);
            _geofenceController.add(geofenceEvent);
            debugPrint('🎯 Geofence event: ${geofenceEvent.geofenceId} - ${geofenceEvent.transition}');
          } catch (e) {
            debugPrint('❌ Error parsing geofence event: $e');
          }
        }
      },
      onError: (error) {
        debugPrint('❌ Geofence stream error: $error');
      },
    );
  }

  /// Check if location services are enabled
  Future<bool> isLocationServiceEnabled() async {
    try {
      final result = await _channel.invokeMethod<bool>('isLocationServiceEnabled');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('❌ Error checking location service: ${e.message}');
      return false;
    }
  }

  /// Check location permission status
  /// Returns: 'granted', 'denied', 'deniedForever', 'restricted', or 'unknown'
  Future<String> checkPermission() async {
    try {
      final result = await _channel.invokeMethod<String>('checkPermission');
      return result ?? 'unknown';
    } on PlatformException catch (e) {
      debugPrint('❌ Error checking permission: ${e.message}');
      return 'unknown';
    }
  }

  /// Request location permission
  /// Returns: 'granted', 'denied', 'deniedForever', or 'restricted'
  Future<String> requestPermission() async {
    try {
      final result = await _channel.invokeMethod<String>('requestPermission');
      return result ?? 'denied';
    } on PlatformException catch (e) {
      debugPrint('❌ Error requesting permission: ${e.message}');
      return 'denied';
    }
  }

  /// Request background location permission (Android only)
  Future<String> requestBackgroundPermission() async {
    if (!Platform.isAndroid) return 'granted';

    try {
      final result = await _channel.invokeMethod<String>('requestBackgroundPermission');
      return result ?? 'denied';
    } on PlatformException catch (e) {
      debugPrint('❌ Error requesting background permission: ${e.message}');
      return 'denied';
    }
  }

  /// Check if all permissions required for geofencing are granted
  /// On Android Q+, this includes background location permission
  Future<bool> hasGeofencingPermissions() async {
    final foregroundPermission = await checkPermission();
    if (foregroundPermission != 'granted') return false;

    if (Platform.isAndroid) {
      final backgroundPermission = await requestBackgroundPermission();
      // If already granted, requestBackgroundPermission returns 'granted'
      // without showing a dialog
      return backgroundPermission == 'granted';
    }

    return true;
  }

  /// Request all permissions needed for geofencing
  /// Returns true if all permissions were granted
  Future<bool> requestGeofencingPermissions() async {
    // First request foreground permission
    final foregroundResult = await requestPermission();
    if (foregroundResult != 'granted') return false;

    // Then request background permission (Android only)
    if (Platform.isAndroid) {
      final backgroundResult = await requestBackgroundPermission();
      return backgroundResult == 'granted';
    }

    return true;
  }

  /// Get current location (one-shot)
  Future<NativeLocation?> getCurrentLocation({
    LocationTrackingMode mode = LocationTrackingMode.highAccuracy,
    int timeoutMs = 15000,
  }) async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('getCurrentLocation', {
        'mode': mode.name,
        'timeoutMs': timeoutMs,
      });

      if (result != null) {
        return NativeLocation.fromMap(result);
      }
      return null;
    } on PlatformException catch (e) {
      debugPrint('❌ Error getting current location: ${e.message}');
      return null;
    }
  }

  /// Start continuous location tracking
  Future<bool> startLocationTracking({
    LocationTrackingMode mode = LocationTrackingMode.balanced,
    int intervalMs = 10000,
    int fastestIntervalMs = 5000,
    double smallestDisplacementMeters = 10.0,
  }) async {
    if (_isTracking) {
      debugPrint('⚠️ Location tracking already active');
      return true;
    }

    try {
      final result = await _channel.invokeMethod<bool>('startLocationTracking', {
        'mode': mode.name,
        'intervalMs': intervalMs,
        'fastestIntervalMs': fastestIntervalMs,
        'smallestDisplacementMeters': smallestDisplacementMeters,
      });

      _isTracking = result ?? false;

      if (_isTracking) {
        debugPrint('✅ Location tracking started (mode: ${mode.name})');
      }

      return _isTracking;
    } on PlatformException catch (e) {
      debugPrint('❌ Error starting location tracking: ${e.message}');
      return false;
    }
  }

  /// Stop location tracking
  Future<bool> stopLocationTracking() async {
    if (!_isTracking) return true;

    try {
      final result = await _channel.invokeMethod<bool>('stopLocationTracking');
      _isTracking = !(result ?? true);

      if (!_isTracking) {
        debugPrint('✅ Location tracking stopped');
      }

      return !_isTracking;
    } on PlatformException catch (e) {
      debugPrint('❌ Error stopping location tracking: ${e.message}');
      return false;
    }
  }

  /// Add a geofence for delivery zone monitoring
  /// Note: On Android Q+, background location permission is required
  Future<bool> addGeofence(GeofenceConfig config) async {
    try {
      final result = await _channel.invokeMethod<bool>('addGeofence', config.toMap());

      if (result == true) {
        debugPrint('✅ Geofence added: ${config.id}');
      }

      return result ?? false;
    } on PlatformException catch (e) {
      if (e.code == 'BACKGROUND_PERMISSION_DENIED') {
        debugPrint('❌ Background location permission required for geofencing');
      } else {
        debugPrint('❌ Error adding geofence: ${e.message}');
      }
      return false;
    }
  }

  /// Add multiple geofences at once
  /// Note: On Android Q+, background location permission is required
  Future<int> addGeofences(List<GeofenceConfig> configs) async {
    try {
      final result = await _channel.invokeMethod<int>('addGeofences', {
        'geofences': configs.map((c) => c.toMap()).toList(),
      });

      debugPrint('✅ Added ${result ?? 0} geofences');
      return result ?? 0;
    } on PlatformException catch (e) {
      if (e.code == 'BACKGROUND_PERMISSION_DENIED') {
        debugPrint('❌ Background location permission required for geofencing');
      } else {
        debugPrint('❌ Error adding geofences: ${e.message}');
      }
      return 0;
    }
  }

  /// Remove a specific geofence
  Future<bool> removeGeofence(String geofenceId) async {
    try {
      final result = await _channel.invokeMethod<bool>('removeGeofence', {'geofenceId': geofenceId});

      if (result == true) {
        debugPrint('✅ Geofence removed: $geofenceId');
      }

      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('❌ Error removing geofence: ${e.message}');
      return false;
    }
  }

  /// Remove all geofences
  Future<bool> removeAllGeofences() async {
    try {
      final result = await _channel.invokeMethod<bool>('removeAllGeofences');

      if (result == true) {
        debugPrint('✅ All geofences removed');
      }

      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('❌ Error removing all geofences: ${e.message}');
      return false;
    }
  }

  /// Get distance between two points (native calculation)
  Future<double> getDistance({
    required double startLat,
    required double startLng,
    required double endLat,
    required double endLng,
  }) async {
    try {
      final result = await _channel.invokeMethod<double>('getDistance', {
        'startLat': startLat,
        'startLng': startLng,
        'endLat': endLat,
        'endLng': endLng,
      });
      return result ?? 0.0;
    } on PlatformException catch (e) {
      debugPrint('❌ Error calculating distance: ${e.message}');
      return 0.0;
    }
  }

  /// Reverse geocode a location to get address (native)
  Future<String?> reverseGeocode(double latitude, double longitude) async {
    try {
      final result = await _channel.invokeMethod<String>('reverseGeocode', {
        'latitude': latitude,
        'longitude': longitude,
      });
      return result;
    } on PlatformException catch (e) {
      debugPrint('❌ Error reverse geocoding: ${e.message}');
      return null;
    }
  }

  /// Open device location settings
  Future<bool> openLocationSettings() async {
    try {
      final result = await _channel.invokeMethod<bool>('openLocationSettings');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('❌ Error opening location settings: ${e.message}');
      return false;
    }
  }

  /// Open app settings (for permission management)
  Future<bool> openAppSettings() async {
    try {
      final result = await _channel.invokeMethod<bool>('openAppSettings');
      return result ?? false;
    } on PlatformException catch (e) {
      debugPrint('❌ Error opening app settings: ${e.message}');
      return false;
    }
  }

  /// Dispose resources
  void dispose() {
    _locationSubscription?.cancel();
    _geofenceSubscription?.cancel();
    _locationController.close();
    _geofenceController.close();
    _isInitialized = false;
    _isTracking = false;
  }
}
