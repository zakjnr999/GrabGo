import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:http/http.dart' as http;
import 'package:grab_go_rider/shared/service/cache_service.dart';

class ChatConversationDto {
  final String id;
  final String? orderId;
  final String? orderNumber;
  final String? otherUserId;
  final String? otherUserName;
  final String? otherUserRole;
  final String lastMessage;
  final DateTime lastMessageAt;
  final int unreadCount;

  ChatConversationDto({
    required this.id,
    required this.orderId,
    required this.orderNumber,
    required this.otherUserId,
    required this.otherUserName,
    required this.otherUserRole,
    required this.lastMessage,
    required this.lastMessageAt,
    required this.unreadCount,
  });

  factory ChatConversationDto.fromJson(Map<String, dynamic> json) {
    return ChatConversationDto(
      id: json['id'] as String,
      orderId: json['orderId'] as String?,
      orderNumber: json['orderNumber'] as String?,
      otherUserId: json['otherUser'] != null ? json['otherUser']['id'] as String? : null,
      otherUserName: json['otherUser'] != null ? json['otherUser']['username'] as String? : null,
      otherUserRole: json['otherUser'] != null ? json['otherUser']['role'] as String? : null,
      lastMessage: (json['lastMessage'] as String?) ?? '',
      lastMessageAt: DateTime.tryParse(json['lastMessageAt']?.toString() ?? '') ?? DateTime.now(),
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
    );
  }
}

class ChatMessageDto {
  final String id;
  final String text;
  final String senderId;
  final String? senderName;
  final DateTime sentAt;
  final List<String> readBy;

  ChatMessageDto({
    required this.id,
    required this.text,
    required this.senderId,
    required this.senderName,
    required this.sentAt,
    required this.readBy,
  });

  factory ChatMessageDto.fromJson(Map<String, dynamic> json) {
    return ChatMessageDto(
      id: json['id'] as String,
      text: json['text'] as String? ?? '',
      senderId: json['senderId'] as String? ?? '',
      senderName: json['senderName'] as String?,
      sentAt: DateTime.tryParse(json['sentAt']?.toString() ?? '') ?? DateTime.now(),
      readBy: (json['readBy'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
    );
  }
}

class ChatDetailDto {
  final String id;
  final String? orderId;
  final String? orderNumber;
  final String? customerId;
  final String? customerName;
  final String? riderId;
  final String? riderName;
  final List<ChatMessageDto> messages;

  ChatDetailDto({
    required this.id,
    required this.orderId,
    required this.orderNumber,
    required this.customerId,
    required this.customerName,
    required this.riderId,
    required this.riderName,
    required this.messages,
  });

  factory ChatDetailDto.fromJson(Map<String, dynamic> json) {
    final customer = json['customer'] as Map<String, dynamic>?;
    final rider = json['rider'] as Map<String, dynamic>?;

    return ChatDetailDto(
      id: json['id'] as String,
      orderId: json['orderId'] as String?,
      orderNumber: json['orderNumber'] as String?,
      customerId: customer != null ? customer['id'] as String? : null,
      customerName: customer != null ? customer['username'] as String? : null,
      riderId: rider != null ? rider['id'] as String? : null,
      riderName: rider != null ? rider['username'] as String? : null,
      messages: (json['messages'] as List<dynamic>? ?? [])
          .map((e) => ChatMessageDto.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ChatService {
  ChatService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  String get _baseUrl => AppConfig.apiBaseUrl; // e.g. https://grabgo.onrender.com/api

  Map<String, String> _buildHeaders() {
    final headers = <String, String>{'Content-Type': 'application/json'};

    try {
      final token = CacheService.getAuthToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    } catch (e) {
      debugPrint('Error getting auth token for chat requests: $e');
    }

    return headers;
  }

  Future<List<ChatConversationDto>> getChats() async {
    final uri = Uri.parse('$_baseUrl/chats');

    try {
      final response = await _client.get(uri, headers: _buildHeaders());
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final data = decoded['data'];
        if (data is List) {
          return data.map((e) => ChatConversationDto.fromJson(e as Map<String, dynamic>)).toList();
        }
        return [];
      } else {
        debugPrint('ChatService.getChats failed: ${response.statusCode} ${response.body}');
        return [];
      }
    } catch (e) {
      debugPrint('ChatService.getChats error: $e');
      return [];
    }
  }

  Future<ChatDetailDto?> getChat(String chatId) async {
    final uri = Uri.parse('$_baseUrl/chats/$chatId');

    try {
      final response = await _client.get(uri, headers: _buildHeaders());
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final data = decoded['data'];
        if (data is Map<String, dynamic>) {
          return ChatDetailDto.fromJson(data);
        }
        return null;
      } else {
        debugPrint('ChatService.getChat failed: ${response.statusCode} ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('ChatService.getChat error: $e');
      return null;
    }
  }

  Future<ChatMessageDto?> sendMessage(String chatId, String text) async {
    final uri = Uri.parse('$_baseUrl/chats/$chatId/messages');

    try {
      final response = await _client.post(uri, headers: _buildHeaders(), body: jsonEncode({'text': text}));

      if (response.statusCode == 201 || response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final data = decoded['data'];
        if (data is Map<String, dynamic> && data['message'] is Map<String, dynamic>) {
          final messageJson = data['message'] as Map<String, dynamic>;
          return ChatMessageDto.fromJson(messageJson);
        }
        return null;
      } else {
        debugPrint('ChatService.sendMessage failed: ${response.statusCode} ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('ChatService.sendMessage error: $e');
      return null;
    }
  }
}
