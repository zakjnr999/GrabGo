import 'package:flutter/foundation.dart';
import 'package:grab_go_customer/core/api/api_client.dart';
import 'package:grab_go_customer/features/home/view/notification.dart';
import 'package:grab_go_customer/shared/services/notification_service_chopper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final NotificationServiceChopper _service = chopperClient.getService<NotificationServiceChopper>();
  static const String _cacheKey = 'cached_notifications';

  /// Save notifications to local storage
  Future<void> saveNotificationsLocally(List<NotificationModel> notifications) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String encodedData = jsonEncode(notifications.map((n) => n.toJson()).toList());
      await prefs.setString(_cacheKey, encodedData);
      debugPrint('💾 Saved ${notifications.length} notifications locally');
    } catch (e) {
      debugPrint('❌ Error saving local notifications: $e');
    }
  }

  /// Get locally cached notifications
  Future<List<NotificationModel>> getLocalNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonString = prefs.getString(_cacheKey);

      if (jsonString != null) {
        final List<dynamic> jsonList = jsonDecode(jsonString);
        final notifications = jsonList.map((json) => NotificationModel.fromJson(json)).toList();
        debugPrint('💾 Loaded ${notifications.length} notifications from cache');
        return notifications;
      }
    } catch (e) {
      debugPrint('❌ Error loading local notifications: $e');
    }
    return [];
  }

  /// Fetch notifications for the current user with pagination
  Future<Map<String, dynamic>> getNotifications({int limit = 20, int page = 1}) async {
    try {
      final response = await _service.getNotifications(limit, page);

      if (response.isSuccessful && response.body != null) {
        final data = response.body as Map<String, dynamic>;
        if (data['success'] == true && data['notifications'] != null) {
          final notificationsList = data['notifications'] as List;
          final notifications = notificationsList.map((json) => NotificationModel.fromJson(json)).toList();

          final pagination = data['pagination'] as Map<String, dynamic>?;

          // Save to local cache if it's the first page
          if (page == 1) {
            saveNotificationsLocally(notifications);
          }

          return {
            'notifications': notifications,
            'hasMore': pagination?['hasMore'] ?? false,
            'total': pagination?['total'] ?? 0,
          };
        }
      }

      debugPrint('❌ Failed to fetch notifications: ${response.error}');
      return {'notifications': <NotificationModel>[], 'hasMore': false, 'total': 0};
    } catch (e) {
      debugPrint('❌ Error fetching notifications: $e');
      return {'notifications': <NotificationModel>[], 'hasMore': false, 'total': 0};
    }
  }

  /// Get unread notification count
  Future<int> getUnreadCount() async {
    try {
      final response = await _service.getUnreadCount();

      if (response.isSuccessful && response.body != null) {
        final data = response.body as Map<String, dynamic>;
        if (data['success'] == true) {
          return data['count'] ?? 0;
        }
      }

      return 0;
    } catch (e) {
      debugPrint('❌ Error fetching unread count: $e');
      return 0;
    }
  }

  /// Mark a notification as read
  Future<bool> markAsRead(String notificationId) async {
    try {
      final response = await _service.markAsRead(notificationId);

      if (response.isSuccessful) {
        debugPrint('✅ Notification marked as read');
        return true;
      }

      debugPrint('❌ Failed to mark notification as read: ${response.error}');
      return false;
    } catch (e) {
      debugPrint('❌ Error marking notification as read: $e');
      return false;
    }
  }

  /// Mark all notifications as read
  Future<bool> markAllAsRead() async {
    try {
      final response = await _service.markAllAsRead();

      if (response.isSuccessful) {
        debugPrint('✅ All notifications marked as read');
        return true;
      }

      debugPrint('❌ Failed to mark all as read: ${response.error}');
      return false;
    } catch (e) {
      debugPrint('❌ Error marking all as read: $e');
      return false;
    }
  }

  /// Clear all notifications
  Future<bool> clearAll() async {
    try {
      final response = await _service.clearAll();

      if (response.isSuccessful) {
        debugPrint('✅ All notifications cleared');
        return true;
      }

      debugPrint('❌ Failed to clear notifications: ${response.error}');
      return false;
    } catch (e) {
      debugPrint('❌ Error clearing notifications: $e');
      return false;
    }
  }
}
