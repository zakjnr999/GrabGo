import 'package:flutter/material.dart';
import 'package:grab_go_customer/features/chat/view/chats_details.dart';
import 'package:grab_go_customer/features/status/view/story_viewer.dart';
import 'package:grab_go_customer/main.dart';

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
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ChatDetail(chatId: chatId, senderName: data['senderName'] ?? 'Chat'),
          ),
        );
      } else if (type == 'order_update' && orderId != null) {
        debugPrint('Navigate to order: $orderId');
      } else if ((type == 'comment_reply' || type == 'comment_reaction') && statusId != null && restaurantId != null) {
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
              isReply: data['isReply'] ?? false,
              highlightComment: true,
            ),
          ),
        );
      } else if (type == 'referral_completed' || type == 'milestone_bonus') {
        // Navigate to referral page
        debugPrint('Navigate to referral page');
        Navigator.of(context).pushNamed('/referral');
      } else if (type == 'payment_confirmed' && orderId != null) {
        // Navigate to order details
        debugPrint('Navigate to order: $orderId');
        Navigator.of(context).pushNamed('/orders/$orderId');
      } else if (type == 'delivery_arriving' && orderId != null) {
        // Navigate to order tracking
        debugPrint('Navigate to order tracking: $orderId');
        Navigator.of(context).pushNamed('/orders/$orderId');
      } else if (type == 'promo') {
        // Navigate to promos page
        debugPrint('Navigate to promos');
        Navigator.of(context).pushNamed('/promos');
      } else if (type == 'system' || type == 'update') {
        // Navigate to notifications page
        debugPrint('Navigate to notifications');
        Navigator.of(context).pushNamed('/notifications');
      }
    } catch (e) {
      debugPrint('❌ Error handling notification tap: $e');
    }
  });
}
