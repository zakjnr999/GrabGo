import 'package:flutter/material.dart';
import 'package:grab_go_customer/features/chat/view/chats_details.dart';
import 'package:grab_go_customer/main.dart';

void handleNotificationTap(Map<String, dynamic> data) {
  final type = data['type'];
  final chatId = data['chatId'];
  final orderId = data['orderId'];

  debugPrint('📲 Notification tapped: type=$type, chatId=$chatId, orderId=$orderId');

  Future.delayed(const Duration(milliseconds: 500), () {
    final context = navigatorKey.currentContext;
    if (context == null) {
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
    }
  });
}
