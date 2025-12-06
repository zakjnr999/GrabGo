import 'package:flutter/foundation.dart';
import 'package:grab_go_customer/core/api/api_client.dart';
import 'package:grab_go_customer/features/home/view/notification.dart';
import 'package:grab_go_customer/shared/services/notification_service_chopper.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final NotificationServiceChopper _service = chopperClient.getService<NotificationServiceChopper>();

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
