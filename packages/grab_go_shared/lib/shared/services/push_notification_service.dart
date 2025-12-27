import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_app_badge_control/flutter_app_badge_control.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint('Background message: ${message.messageId}');

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
  String? _currentChatId; // Track which chat user is currently viewing
  int _badgeCount = 0; // Track unread notification count

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
  /// IMPORTANT: Permission must be granted before calling this method
  Future<void> initialize({NotificationTapCallback? onNotificationTap, Function(String token)? onTokenRefresh}) async {
    if (_isInitialized) return;

    _onNotificationTap = onNotificationTap;
    _onTokenRefresh = onTokenRefresh;

    try {
      // Check permission first
      final settings = await _messaging.getNotificationSettings();
      if (settings.authorizationStatus != AuthorizationStatus.authorized) {
        debugPrint('Notification permission not granted, skipping FCM initialization');
        return;
      }

      // Initialize local notifications
      await _initializeLocalNotifications();

      // Get FCM token with retry
      _fcmToken = await _getTokenWithRetry();
      if (_fcmToken != null) {
        debugPrint('FCM Token: $_fcmToken');
      } else {
        debugPrint('Could not get FCM token - notifications may not work');
      }

      // Listen for token refresh
      _messaging.onTokenRefresh.listen((token) {
        _fcmToken = token;
        debugPrint('FCM Token refreshed: $token');
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
      debugPrint('Push notification service initialized');
    } catch (e) {
      debugPrint('Failed to initialize push notifications: $e');
    }
  }

  /// Get FCM token with retry logic
  Future<String?> _getTokenWithRetry({int maxRetries = 3}) async {
    for (int i = 0; i < maxRetries; i++) {
      try {
        final token = await _messaging.getToken();
        if (token != null) return token;
      } catch (e) {
        debugPrint('FCM token attempt ${i + 1}/$maxRetries failed: $e');
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

      // Chat messages channel
      await androidPlugin?.createNotificationChannel(_chatChannel);

      // Order updates channel
      await androidPlugin?.createNotificationChannel(_orderChannel);

      // Social notifications (comments, reactions)
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          'social',
          'Social Notifications',
          description: 'Notifications for comments and reactions',
          importance: Importance.high,
          playSound: true,
        ),
      );

      // Promotions channel
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          'promotions',
          'Promotions',
          description: 'Promotional offers and discounts',
          importance: Importance.defaultImportance,
          playSound: true,
        ),
      );

      // Referrals channel
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          'referrals',
          'Referrals',
          description: 'Referral rewards and milestones',
          importance: Importance.high,
          playSound: true,
        ),
      );

      // Payments channel
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          'payments',
          'Payments',
          description: 'Payment confirmations',
          importance: Importance.high,
          playSound: true,
        ),
      );

      // System updates channel
      await androidPlugin?.createNotificationChannel(
        const AndroidNotificationChannel(
          'system_updates',
          'System Updates',
          description: 'App updates and system notifications',
          importance: Importance.defaultImportance,
          playSound: false,
        ),
      );
    }
  }

  /// Set the current chat ID when user opens a chat
  /// This prevents notifications from showing for the chat user is viewing
  void setCurrentChatId(String? chatId) {
    _currentChatId = chatId;
    debugPrint('Current chat set to: $chatId');
  }

  /// Get the current chat ID
  String? get currentChatId => _currentChatId;

  /// Get appropriate notification channel for a notification type
  String _getNotificationChannel(String? type) {
    const channelMap = {
      'chat_message': 'chat_messages',
      'order': 'order_updates',
      'order_update': 'order_updates',
      'delivery_arriving': 'order_updates',
      'comment_reply': 'social',
      'comment_reaction': 'social',
      'promo': 'promotions',
      'referral_completed': 'referrals',
      'milestone_bonus': 'referrals',
      'payment_confirmed': 'payments',
      'system': 'system_updates',
      'update': 'system_updates',
    };
    return channelMap[type] ?? 'default';
  }

  /// Get user-friendly channel name
  String _getChannelName(String channelId) {
    const channelNames = {
      'chat_messages': 'Chat Messages',
      'order_updates': 'Order Updates',
      'social': 'Social Notifications',
      'promotions': 'Promotions',
      'referrals': 'Referrals',
      'payments': 'Payments',
      'system_updates': 'System Updates',
      'default': 'Notifications',
    };
    return channelNames[channelId] ?? 'Notifications';
  }

  /// Handle foreground messages - show local notification
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    debugPrint('Foreground message: ${message.messageId}');

    final notification = message.notification;
    final data = message.data;

    // Skip notification if user is currently viewing this chat
    if (data['type'] == 'chat_message' && data['chatId'] == _currentChatId) {
      debugPrint('Skipping notification - user is viewing this chat');
      return;
    }

    if (notification != null) {
      // Increment badge count
      await incrementBadge();

      // Get appropriate channel for this notification type
      final channelId = _getNotificationChannel(data['type']);

      await _localNotifications.show(
        message.hashCode,
        notification.title,
        notification.body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            _getChannelName(channelId),
            importance: Importance.high,
            priority: Priority.high,
            showWhen: true,
            icon: '@mipmap/ic_launcher',
            number: _badgeCount,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            badgeNumber: _badgeCount,
          ),
        ),
        payload: jsonEncode(data),
      );
    }
  }

  /// Handle notification tap from local notification
  void _onLocalNotificationTap(NotificationResponse response) {
    // Clear badge when notification is tapped
    clearBadge();

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
    // Clear badge when notification is tapped
    clearBadge();
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
    debugPrint('FCM token deleted');
  }

  /// Subscribe to a topic
  Future<void> subscribeToTopic(String topic) async {
    await _messaging.subscribeToTopic(topic);
    debugPrint('Subscribed to topic: $topic');
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    await _messaging.unsubscribeFromTopic(topic);
    debugPrint('Unsubscribed from topic: $topic');
  }

  /// Set the notification tap callback
  void setOnNotificationTap(NotificationTapCallback callback) {
    _onNotificationTap = callback;
  }

  /// Set the token refresh callback
  void setOnTokenRefresh(Function(String token) callback) {
    _onTokenRefresh = callback;
  }

  /// Get current badge count
  int get badgeCount => _badgeCount;

  /// Update the app icon badge count
  Future<void> updateBadgeCount(int count) async {
    try {
      _badgeCount = count;
      if (count > 0) {
        await FlutterAppBadgeControl.updateBadgeCount(count);
        debugPrint('Badge count updated to: $count');
      } else {
        await FlutterAppBadgeControl.removeBadge();
        debugPrint('Badge removed');
      }
    } catch (e) {
      debugPrint('Error updating badge: $e');
    }
  }

  /// Increment badge count by 1
  Future<void> incrementBadge() async {
    await updateBadgeCount(_badgeCount + 1);
  }

  /// Clear the badge count (call when user opens app or reads notifications)
  Future<void> clearBadge() async {
    await updateBadgeCount(0);
  }

  /// Check if badge is supported on this device
  Future<bool> isBadgeSupported() async {
    try {
      return await FlutterAppBadgeControl.isAppBadgeSupported();
    } catch (e) {
      return false;
    }
  }
}
