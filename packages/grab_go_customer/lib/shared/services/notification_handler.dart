import 'package:flutter/material.dart';
import 'package:grab_go_customer/features/chat/view/chats_details.dart';
import 'package:grab_go_customer/features/status/view/story_viewer.dart';
import 'package:grab_go_customer/main.dart';

/// Parse boolean value from dynamic data (handles both string and boolean)
bool _parseBool(dynamic value) {
  if (value == null) return false;
  if (value is bool) return value;
  if (value is String) return value.toLowerCase() == 'true';
  return false;
}

/// Validate required deep link data fields
bool _validateDeepLinkData(Map<String, dynamic> data, List<String> requiredFields) {
  for (final field in requiredFields) {
    final value = data[field]?.toString();
    if (value == null || value.isEmpty) {
      debugPrint('❌ Missing or empty required field: $field');
      return false;
    }
  }
  return true;
}

/// Navigate to a route with error handling
void _navigateToRoute(BuildContext context, String route) {
  try {
    Navigator.of(context).pushNamed(route);
  } catch (e) {
    debugPrint('❌ Navigation failed for route $route: $e');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Unable to open this notification'),
        action: SnackBarAction(label: 'Dismiss', onPressed: () {}),
      ),
    );
  }
}

void handleNotificationTap(Map<String, dynamic> data) {
  final type = data['type'];
  final chatId = data['chatId'];
  final orderId = data['orderId'];
  final statusId = data['statusId'];
  final restaurantId = data['restaurantId'];
  final restaurantName = data['restaurantName'];

  debugPrint('📲 Notification tapped: type=$type');

  Future.delayed(const Duration(milliseconds: 500), () {
    try {
      final context = navigatorKey.currentContext;
      if (context == null) {
        debugPrint('⚠️ Navigation context is null');
        return;
      }

      if (type == 'chat_message' && chatId != null) {
        // Validate chat data
        if (!_validateDeepLinkData(data, ['chatId', 'senderName'])) return;

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ChatDetail(chatId: chatId, senderName: data['senderName'] ?? 'Chat'),
          ),
        );
      } else if (type == 'order_update' && orderId != null) {
        // Validate order data
        if (!_validateDeepLinkData(data, ['orderId'])) return;

        debugPrint('Navigate to order: $orderId');
        _navigateToRoute(context, '/orders/$orderId');
      } else if ((type == 'comment_reply' || type == 'comment_reaction') && statusId != null && restaurantId != null) {
        // Validate comment data
        if (!_validateDeepLinkData(data, ['restaurantId', 'statusId'])) return;

        // Navigate to status viewer for comment notifications
        debugPrint('📲 Comment notification data:');
        debugPrint('   - type: $type');
        debugPrint('   - restaurantId: $restaurantId');
        debugPrint('   - restaurantName: $restaurantName');
        debugPrint('   - statusId: $statusId');
        debugPrint('   - commentId: ${data['commentId']}');
        debugPrint('   - parentCommentId: ${data['parentCommentId']}');
        debugPrint('   - isReply: ${data['isReply']}');

        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => StoryViewer(
              restaurantId: restaurantId,
              restaurantName: restaurantName ?? 'Restaurant',
              targetCommentId: data['commentId'],
              targetStatusId: statusId,
              parentCommentId: data['parentCommentId'],
              isReply: _parseBool(data['isReply']),
              highlightComment: true,
            ),
          ),
        );
      } else if (type == 'referral_completed' || type == 'milestone_bonus') {
        debugPrint('Navigate to referral page');
        _navigateToRoute(context, '/referral');
      } else if (type == 'payment_confirmed' && orderId != null) {
        debugPrint('Navigate to order: $orderId');
        _navigateToRoute(context, '/orders/$orderId');
      } else if (type == 'delivery_arriving' && orderId != null) {
        debugPrint('Navigate to order tracking: $orderId');
        _navigateToRoute(context, '/orders/$orderId');
      } else if (type == 'promo') {
        debugPrint('Navigate to promos');
        _navigateToRoute(context, '/promos');
      } else if (type == 'system' || type == 'update') {
        debugPrint('Navigate to notifications');
        _navigateToRoute(context, '/notifications');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Error handling notification tap: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  });
}
