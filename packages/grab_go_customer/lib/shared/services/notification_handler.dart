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
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => StoryViewer(
              restaurantId: restaurantId,
              restaurantName: restaurantName ?? 'Restaurant',
              targetCommentId: data['commentId'],
              highlightComment: true,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error handling notification tap: $e');
    }
  });
}
