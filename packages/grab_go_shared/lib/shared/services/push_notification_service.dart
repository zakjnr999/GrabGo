import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('📩 Background message: ${message.messageId}');

  // Handle background message
  await PushNotificationService._handleBackgroundMessage(message);
}

/// Callback type for handling notification taps
typedef NotificationTapCallback = void Function(Map<String, dynamic> data);

/// Service for handling FCM push notifications
class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService _instance = PushNotificationService._();
  factory PushNotificationService() => _instance;

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  String? _fcmToken;
  bool _isInitialized = false;

  // Callbacks
  NotificationTapCallback? _onNotificationTap;
  Function(String token)? _onTokenRefresh;

  /// Get the current FCM token
  String? get fcmToken => _fcmToken;

  /// Check if service is initialized
  bool get isInitialized => _isInitialized;

  /// Android notification channel for chat messages
  static const AndroidNotificationChannel _chatChannel = AndroidNotificationChannel(
    'chat_messages',
    'Chat Messages',
    description: 'Notifications for new chat messages',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  /// Android notification channel for order updates
  static const AndroidNotificationChannel _orderChannel = AndroidNotificationChannel(
    'order_updates',
    'Order Updates',
    description: 'Notifications for order status updates',
    importance: Importance.high,
    playSound: true,
  );

  /// Initialize the push notification service
  Future<void> initialize({NotificationTapCallback? onNotificationTap, Function(String token)? onTokenRefresh}) async {
    if (_isInitialized) return;

    _onNotificationTap = onNotificationTap;
    _onTokenRefresh = onTokenRefresh;

    try {
      // Request permission
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
        announcement: false,
        carPlay: false,
        criticalAlert: false,
      );

      debugPrint('🔔 Notification permission: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        // Initialize local notifications
        await _initializeLocalNotifications();

        // Get FCM token with retry
        _fcmToken = await _getTokenWithRetry();
        if (_fcmToken != null) {
          debugPrint('🔑 FCM Token: $_fcmToken');
        } else {
          debugPrint('⚠️ Could not get FCM token - notifications may not work');
        }

        // Listen for token refresh
        _messaging.onTokenRefresh.listen((token) {
          _fcmToken = token;
          debugPrint('🔄 FCM Token refreshed: $token');
          _onTokenRefresh?.call(token);
        });

        // Handle foreground messages
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

        // Handle notification tap when app is in background
        FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

        // Check if app was opened from a notification
        final initialMessage = await _messaging.getInitialMessage();
        if (initialMessage != null) {
          _handleNotificationTap(initialMessage);
        }

        _isInitialized = true;
        debugPrint('✅ Push notification service initialized');
      } else {
        debugPrint('⚠️ Notification permission denied');
      }
    } catch (e) {
      debugPrint('❌ Failed to initialize push notifications: $e');
    }
  }

  /// Get FCM token with retry logic
  Future<String?> _getTokenWithRetry({int maxRetries = 3}) async {
    for (int i = 0; i < maxRetries; i++) {
      try {
        final token = await _messaging.getToken();
        if (token != null) return token;
      } catch (e) {
        debugPrint('⚠️ FCM token attempt ${i + 1}/$maxRetries failed: $e');
        if (i < maxRetries - 1) {
          await Future.delayed(Duration(seconds: 2 * (i + 1)));
        }
      }
    }
    return null;
  }

  /// Initialize local notifications for foreground display
  Future<void> _initializeLocalNotifications() async {
    // Android initialization
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const initSettings = InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _localNotifications.initialize(initSettings, onDidReceiveNotificationResponse: _onLocalNotificationTap);

    // Create notification channels for Android
    if (Platform.isAndroid) {
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

      await androidPlugin?.createNotificationChannel(_chatChannel);
      await androidPlugin?.createNotificationChannel(_orderChannel);
    }
  }

  /// Handle foreground messages - show local notification
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('📩 Foreground message: ${message.messageId}');

    final notification = message.notification;
    final data = message.data;

    if (notification != null) {
      // Determine which channel to use
      final channelId = data['type'] == 'chat_message' ? 'chat_messages' : 'order_updates';

      await _localNotifications.show(
        message.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            channelId == 'chat_messages' ? 'Chat Messages' : 'Order Updates',
            importance: Importance.high,
            priority: Priority.high,
            showWhen: true,
            icon: '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
        ),
        payload: jsonEncode(data),
      );
    }
  }

  /// Handle notification tap from local notification
  void _onLocalNotificationTap(NotificationResponse response) {
    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!) as Map<String, dynamic>;
        _onNotificationTap?.call(data);
      } catch (e) {
        debugPrint('Error parsing notification payload: $e');
      }
    }
  }

  /// Handle notification tap from FCM
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('📲 Notification tapped: ${message.messageId}');
    _onNotificationTap?.call(message.data);
  }

  /// Handle background message (static for top-level handler)
  static Future<void> _handleBackgroundMessage(RemoteMessage message) async {
    // Background messages are automatically shown by FCM
    // This handler is for any additional processing needed
    debugPrint('Processing background message: ${message.data}');
  }

  /// Get the current FCM token (refreshes if needed)
  Future<String?> getToken() async {
    _fcmToken ??= await _messaging.getToken();
    return _fcmToken;
  }

  /// Delete the FCM token (for logout)
  Future<void> deleteToken() async {
    await _messaging.deleteToken();
    _fcmToken = null;
    debugPrint('🗑️ FCM token deleted');
  }

  /// Subscribe to a topic
  Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
    debugPrint('📌 Subscribed to topic: $topic');
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
    debugPrint('📌 Unsubscribed from topic: $topic');
  }

  /// Set the notification tap callback
  void setOnNotificationTap(NotificationTapCallback callback) {
    _onNotificationTap = callback;
  }

  /// Set the token refresh callback
  void setOnTokenRefresh(Function(String token) callback) {
    _onTokenRefresh = callback;
  }
}
