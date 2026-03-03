import 'dart:async';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/widgets.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:grab_go_rider/features/orders/service/rider_tracking_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _PrefsKeys {
  static const String orderId = 'fg_service_order_id';
  static const String riderId = 'fg_service_rider_id';
  static const String customerId = 'fg_service_customer_id';
  static const String authToken = 'fg_service_auth_token';
  static const String currentStatus = 'fg_service_current_status';
  static const String isActive = 'fg_service_is_active';
}

/// Foreground service for rider location tracking
/// Keeps location updates running even when app is in background
class RiderForegroundService {
  static final RiderForegroundService _instance =
      RiderForegroundService._internal();
  factory RiderForegroundService() => _instance;
  RiderForegroundService._internal();

  final FlutterBackgroundService _service = FlutterBackgroundService();
  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    if (Platform.isAndroid) {
      await _createNotificationChannel();
    }

    await _service.configure(
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: _onStart,
        onBackground: _onIosBackground,
      ),
      androidConfiguration: AndroidConfiguration(
        onStart: _onStart,
        autoStart: false,
        isForegroundMode: true,
        autoStartOnBoot: false,
        notificationChannelId: 'grabgo_rider_tracking',
        initialNotificationTitle: 'GrabGo Rider',
        initialNotificationContent: 'Location tracking is active',
        foregroundServiceNotificationId: 888,
        foregroundServiceTypes: [AndroidForegroundType.location],
      ),
    );

    _isInitialized = true;
    debugPrint('✅ Foreground service initialized');
  }

  /// Create the notification channel for Android 13+
  Future<void> _createNotificationChannel() async {
    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    const channel = AndroidNotificationChannel(
      'grabgo_rider_tracking',
      'Rider Location Tracking',
      description: 'Shows when GrabGo is tracking your location for deliveries',
      importance: Importance.low,
      playSound: false,
      enableVibration: false,
      showBadge: false,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    debugPrint('✅ Rider tracking notification channel created');
  }

  Future<bool> startService({
    required String orderId,
    required String riderId,
    required String customerId,
    required String authToken,
    required String currentStatus,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    // Store tracking data for background access
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_PrefsKeys.orderId, orderId);
    await prefs.setString(_PrefsKeys.riderId, riderId);
    await prefs.setString(_PrefsKeys.customerId, customerId);
    await prefs.setString(_PrefsKeys.authToken, authToken);
    await prefs.setString(_PrefsKeys.currentStatus, currentStatus);
    await prefs.setBool(_PrefsKeys.isActive, true);

    final success = await _service.startService();
    debugPrint('🚀 Foreground service started: $success');
    return success;
  }

  Future<void> stopService() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_PrefsKeys.isActive, false);

    _service.invoke('stopService');
    debugPrint('🛑 Foreground service stopped');
  }

  void updateNotification({required String title, required String content}) {
    _service.invoke('updateNotification', {'title': title, 'content': content});
  }

  Future<void> updateStatus(String status) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_PrefsKeys.currentStatus, status);
    _service.invoke('statusUpdated', {'status': status});
  }

  Future<bool> isRunning() async {
    return await _service.isRunning();
  }

  /// Listen to service events from the UI
  Stream<Map<String, dynamic>?> get onEvent => _service.on('locationUpdate');
}

/// iOS background handler
@pragma('vm:entry-point')
Future<bool> _onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

/// Main service handler (runs in background isolate)
@pragma('vm:entry-point')
void _onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  debugPrint('🔧 Background service started');

  // Load tracking data from shared preferences
  final prefs = await SharedPreferences.getInstance();
  String? orderId = prefs.getString(_PrefsKeys.orderId);
  String? riderId = prefs.getString(_PrefsKeys.riderId);
  String? authToken = prefs.getString(_PrefsKeys.authToken);
  String currentStatus =
      prefs.getString(_PrefsKeys.currentStatus) ?? 'preparing';

  if (orderId == null || riderId == null || authToken == null) {
    debugPrint('❌ Missing tracking data, stopping service');
    service.stopSelf();
    return;
  }

  final trackingService = RiderTrackingService(authToken: authToken);

  // Track consecutive errors
  int consecutiveErrors = 0;
  const maxErrors = 10;
  double lastObservedSpeedMps = 0;

  bool isValidCoordinate(double latitude, double longitude) {
    return latitude.isFinite &&
        longitude.isFinite &&
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }

  // Calculate update interval based on status, speed and connectivity pressure.
  int getUpdateInterval() {
    final status = prefs.getString(_PrefsKeys.currentStatus) ?? currentStatus;
    final speedMps = lastObservedSpeedMps.clamp(0.0, 30.0).toDouble();
    final isActiveLeg =
        status == 'in_transit' || status == 'inTransit' || status == 'nearby';

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
        intervalMs = 7800;
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

    if (consecutiveErrors >= 6) {
      intervalMs = (intervalMs * 1.8).round();
    } else if (consecutiveErrors >= 3) {
      intervalMs = (intervalMs * 1.35).round();
    }

    final minIntervalMs = isActiveLeg ? 3000 : 7000;
    final maxIntervalMs = isActiveLeg ? 14000 : 30000;
    return intervalMs.clamp(minIntervalMs, maxIntervalMs).toInt();
  }

  // Listen for stop command
  service.on('stopService').listen((event) {
    debugPrint('🛑 Stop command received');
    service.stopSelf();
  });

  // Listen for notification update
  service.on('updateNotification').listen((event) {
    if (event != null && service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: event['title'] ?? 'GrabGo Rider',
        content: event['content'] ?? 'Tracking active',
      );
    }
  });

  // Listen for status updates
  service.on('statusUpdated').listen((event) {
    if (event != null) {
      currentStatus = event['status'] ?? currentStatus;
      debugPrint('📍 Status updated: $currentStatus');
    }
  });

  // Android specific setup
  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });

    // Set initial foreground notification
    service.setForegroundNotificationInfo(
      title: 'GrabGo Rider',
      content: 'Tracking delivery for order #${orderId.substring(0, 8)}...',
    );
  }

  // Use a recursive delayed call instead of Timer.periodic to allow dynamic intervals
  Future<void> runLocationUpdate() async {
    // Reload shared preferences to get latest values
    await prefs.reload();

    // Check if still active
    final isActive = prefs.getBool(_PrefsKeys.isActive) ?? false;
    if (!isActive) {
      debugPrint('🛑 Service marked inactive, stopping');
      service.stopSelf();
      return;
    }

    // Reload order ID in case it changed
    final currentOrderId = prefs.getString(_PrefsKeys.orderId);
    if (currentOrderId == null) {
      debugPrint('❌ Order ID missing, stopping service');
      service.stopSelf();
      return;
    }
    orderId = currentOrderId;

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: Platform.isAndroid
            ? AndroidSettings(
                accuracy: LocationAccuracy.high,
                distanceFilter: 5,
                forceLocationManager: false,
                intervalDuration: Duration(milliseconds: getUpdateInterval()),
              )
            : AppleSettings(
                accuracy: LocationAccuracy.high,
                distanceFilter: 5,
                activityType: ActivityType.automotiveNavigation,
                allowBackgroundLocationUpdates: true,
                showBackgroundLocationIndicator: true,
              ),
      );

      if (!isValidCoordinate(position.latitude, position.longitude)) {
        consecutiveErrors++;
        debugPrint(
          '⚠️ Invalid background GPS coordinate (error $consecutiveErrors/$maxErrors)',
        );
      } else {
        if (position.speed.isFinite && position.speed >= 0) {
          lastObservedSpeedMps = position.speed;
        }

        debugPrint(
          '📍 Background location: ${position.latitude}, ${position.longitude}',
        );

        final response = await trackingService.updateLocation(
          orderId: orderId!,
          latitude: position.latitude,
          longitude: position.longitude,
          speed: position.speed,
          accuracy: position.accuracy,
        );

        if (response != null) {
          consecutiveErrors = 0;

          // Update notification with ETA
          if (service is AndroidServiceInstance) {
            String notificationContent;
            if (response.distanceRemaining > 0) {
              final distanceKm = response.distanceKm.toStringAsFixed(1);
              final eta = response.etaMinutes.round();
              notificationContent = '$distanceKm km away • ETA: $eta min';
            } else {
              notificationContent = 'Tracking active';
            }

            service.setForegroundNotificationInfo(
              title: 'Delivering Order',
              content: notificationContent,
            );
          }

          // Send location data to UI if listening
          service.invoke('locationUpdate', {
            'latitude': position.latitude,
            'longitude': position.longitude,
            'speed': position.speed,
            'accuracy': position.accuracy,
            'distanceRemaining': response.distanceRemaining,
            'etaMinutes': response.etaMinutes,
            'timestamp': DateTime.now().toIso8601String(),
          });
        } else {
          consecutiveErrors++;
          debugPrint(
            '⚠️ Location update failed (error $consecutiveErrors/$maxErrors)',
          );
        }
      }
    } catch (e) {
      consecutiveErrors++;
      debugPrint('❌ Background location error: $e');
    }

    // Stop if too many errors
    if (consecutiveErrors >= maxErrors) {
      debugPrint('❌ Too many errors, stopping service');
      service.stopSelf();
      return;
    }

    // Schedule next update with adaptive interval based on status/speed/network pressure.
    final nextIntervalMs = getUpdateInterval();
    Future.delayed(Duration(milliseconds: nextIntervalMs), runLocationUpdate);
  }

  // Start the location update loop
  runLocationUpdate();
}

/// Extension to help manage foreground service from the tracking provider
extension ForegroundServiceExtensions on RiderTrackingService {
  /// Create a service with a specific auth token for background use
  static RiderTrackingService withToken(String token) {
    return RiderTrackingService(authToken: token);
  }
}
