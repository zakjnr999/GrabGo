import 'dart:io';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';

/// Service for high-priority order alert notifications
/// Designed to get rider's attention even when phone is in pocket
class OrderAlertService {
  OrderAlertService._();
  static final OrderAlertService _instance = OrderAlertService._();
  factory OrderAlertService() => _instance;

  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  /// High-priority order alerts channel - maximum attention
  /// NOTE: Changed channel ID to force Android to use new settings (sound, etc.)
  static const AndroidNotificationChannel orderAlertsChannel = AndroidNotificationChannel(
    'order_alerts_v2', // New ID to reset cached channel settings
    'Order Alerts',
    description: 'High-priority notifications for new order reservations',
    importance: Importance.max,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('rider_alert'), // Custom sound in res/raw/
    enableVibration: true,
    enableLights: true,
    ledColor: Color.fromARGB(255, 255, 165, 0), // Orange LED
    showBadge: true,
  );

  /// Vibration pattern: Long-Short-Long-Short-Long (attention-grabbing)
  static const List<int> vibrationPattern = [0, 500, 200, 500, 200, 500, 200, 500];

  /// Initialize the order alert service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      if (Platform.isAndroid) {
        final androidPlugin = _localNotifications
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

        // Create the high-priority order alerts channel
        await androidPlugin?.createNotificationChannel(orderAlertsChannel);

        debugPrint('✅ Order Alerts notification channel created (MAX priority)');
      }

      _isInitialized = true;
    } catch (e) {
      debugPrint('❌ Error initializing OrderAlertService: $e');
    }
  }

  /// Show a high-priority order alert notification with full-screen intent
  Future<void> showOrderAlert({
    required String title,
    required String body,
    required String orderId,
    required String reservationId,
    required int timeoutSeconds,
    required double earnings,
    Map<String, dynamic>? payload,
  }) async {
    if (!_isInitialized) await initialize();

    try {
      // Start strong vibration pattern
      _startAlertVibration();

      // Android notification details with full-screen intent
      final androidDetails = AndroidNotificationDetails(
        orderAlertsChannel.id,
        orderAlertsChannel.name,
        channelDescription: orderAlertsChannel.description,
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('rider_alert'), // Custom alert sound
        enableVibration: true,
        vibrationPattern: Int64List.fromList(vibrationPattern),
        enableLights: true,
        ledColor: const Color.fromARGB(255, 255, 165, 0),
        ledOnMs: 500,
        ledOffMs: 500,
        fullScreenIntent: true, // Shows over lock screen like incoming call
        category: AndroidNotificationCategory.call, // Treat like call for priority
        visibility: NotificationVisibility.public,
        ticker: 'New Order Available!',
        ongoing: true, // Cannot be swiped away
        autoCancel: false,
        timeoutAfter: timeoutSeconds * 1000, // Auto-dismiss after timeout
        actions: [
          const AndroidNotificationAction('accept', '✓ ACCEPT', showsUserInterface: true, cancelNotification: true),
          const AndroidNotificationAction('decline', '✗ DECLINE', showsUserInterface: true, cancelNotification: true),
        ],
        styleInformation: BigTextStyleInformation(
          body,
          htmlFormatBigText: false,
          contentTitle: title,
          htmlFormatContentTitle: false,
          summaryText: 'Earn GHS ${earnings.toStringAsFixed(2)}',
          htmlFormatSummaryText: false,
        ),
      );

      // iOS notification details
      const iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
        interruptionLevel: InterruptionLevel.timeSensitive,
      );

      final notificationDetails = NotificationDetails(android: androidDetails, iOS: iosDetails);

      // Show the notification
      await _localNotifications.show(
        orderId.hashCode, // Unique ID based on order
        title,
        body,
        notificationDetails,
        payload: payload != null ? payload.toString() : orderId,
      );

      debugPrint('🔔 Order alert notification shown (full-screen intent)');
    } catch (e) {
      debugPrint('❌ Error showing order alert: $e');
    }
  }

  /// Start a strong, attention-grabbing vibration pattern
  Future<void> _startAlertVibration() async {
    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        // Vibrate with pattern: wait 0ms, vibrate 500ms, wait 200ms, vibrate 500ms...
        // Repeat 3 times for attention
        await Vibration.vibrate(pattern: vibrationPattern, repeat: 3);
      }
    } catch (e) {
      debugPrint('Error starting vibration: $e');
    }
  }

  /// Stop the vibration
  Future<void> stopAlertVibration() async {
    try {
      await Vibration.cancel();
    } catch (e) {
      debugPrint('Error stopping vibration: $e');
    }
  }

  /// Cancel the order alert notification
  Future<void> cancelOrderAlert(String orderId) async {
    try {
      await _localNotifications.cancel(orderId.hashCode);
      await stopAlertVibration();
      debugPrint('🔕 Order alert cancelled for: $orderId');
    } catch (e) {
      debugPrint('Error cancelling order alert: $e');
    }
  }

  /// Cancel all order alerts
  Future<void> cancelAllOrderAlerts() async {
    try {
      await _localNotifications.cancelAll();
      await stopAlertVibration();
    } catch (e) {
      debugPrint('Error cancelling all alerts: $e');
    }
  }
}
