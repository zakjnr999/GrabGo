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

/// Message types supported in chat
enum MessageType {
  text,
  voice,
  image;

  static MessageType fromString(String? value) {
    switch (value) {
      case 'voice':
        return MessageType.voice;
      case 'image':
        return MessageType.image;
      default:
        return MessageType.text;
    }
  }
}

class ChatMessageDto {
  final String id;
  final MessageType messageType;
  final String? text;
  final String? audioUrl;
  final double audioDuration; // Duration in seconds
  final String senderId;
  final String? senderName;
  final DateTime sentAt;
  final List<String> readBy;
  final String? replyToId;
  final String? replyToText;
  final String? replyToSenderId;

  ChatMessageDto({
    required this.id,
    this.messageType = MessageType.text,
    this.text,
    this.audioUrl,
    this.audioDuration = 0,
    required this.senderId,
    required this.senderName,
    required this.sentAt,
    required this.readBy,
    this.replyToId,
    this.replyToText,
    this.replyToSenderId,
  });

  bool get isVoiceMessage => messageType == MessageType.voice;
  bool get isImageMessage => messageType == MessageType.image;
  bool get isTextMessage => messageType == MessageType.text;

  factory ChatMessageDto.fromJson(Map<String, dynamic> json) {
    final replyTo = json['replyTo'] as Map<String, dynamic>?;
    // Check if reply is to a voice message
    final replyToMessageType = replyTo?['messageType'] as String?;
    final replyToText = replyToMessageType == 'voice' ? '🎤 Voice message' : replyTo?['text'] as String?;

    return ChatMessageDto(
      id: json['id'] as String,
      messageType: MessageType.fromString(json['messageType'] as String?),
      text: json['text'] as String?,
      audioUrl: json['audioUrl'] as String?,
      audioDuration: (json['audioDuration'] as num?)?.toDouble() ?? 0,
      senderId: json['senderId'] as String? ?? '',
      senderName: json['senderName'] as String?,
      sentAt: DateTime.tryParse(json['sentAt']?.toString() ?? '') ?? DateTime.now(),
      readBy: (json['readBy'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      replyToId: replyTo?['id'] as String?,
      replyToText: replyToText,
      replyToSenderId: replyTo?['senderId'] as String?,
    );
  }
}

class ChatPaginationDto {
  final bool hasMore;
  final int totalCount;
  final int returnedCount;

  ChatPaginationDto({required this.hasMore, required this.totalCount, required this.returnedCount});

  factory ChatPaginationDto.fromJson(Map<String, dynamic> json) {
    return ChatPaginationDto(
      hasMore: json['hasMore'] as bool? ?? false,
      totalCount: (json['totalCount'] as num?)?.toInt() ?? 0,
      returnedCount: (json['returnedCount'] as num?)?.toInt() ?? 0,
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
  final ChatPaginationDto? pagination;

  ChatDetailDto({
    required this.id,
    required this.orderId,
    required this.orderNumber,
    required this.customerId,
    required this.customerName,
    required this.riderId,
    required this.riderName,
    required this.messages,
    this.pagination,
  });

  factory ChatDetailDto.fromJson(Map<String, dynamic> json) {
    final customer = json['customer'] as Map<String, dynamic>?;
    final rider = json['rider'] as Map<String, dynamic>?;
    final paginationJson = json['pagination'] as Map<String, dynamic>?;

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
      pagination: paginationJson != null ? ChatPaginationDto.fromJson(paginationJson) : null,
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

  /// Fetches chat details with messages.
  /// [limit] - Maximum number of messages to fetch (default 50, max 100)
  /// [beforeMessageId] - Fetch messages before this message ID (for pagination)
  Future<ChatDetailDto?> getChat(String chatId, {int? limit, String? beforeMessageId}) async {
    final queryParams = <String, String>{};
    if (limit != null) queryParams['limit'] = limit.toString();
    if (beforeMessageId != null) queryParams['before'] = beforeMessageId;

    final uri = Uri.parse(
      '$_baseUrl/chats/$chatId',
    ).replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);

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

  Future<ChatMessageDto?> sendMessage(String chatId, String text, {String? replyToId}) async {
    final uri = Uri.parse('$_baseUrl/chats/$chatId/messages');

    try {
      final body = <String, dynamic>{'text': text};
      if (replyToId != null) {
        body['replyToId'] = replyToId;
      }
      final response = await _client.post(uri, headers: _buildHeaders(), body: jsonEncode(body));

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

  /// Send a voice message by uploading audio file
  /// [audioFilePath] - Path to the local audio file
  /// [duration] - Duration of the audio in seconds
  Future<ChatMessageDto?> sendVoiceMessage(String chatId, String audioFilePath, {double? duration}) async {
    final uri = Uri.parse('$_baseUrl/chats/$chatId/voice-message');

    try {
      final request = http.MultipartRequest('POST', uri);

      // Add auth header
      final token = CacheService.getAuthToken();
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      // Add audio file
      request.files.add(await http.MultipartFile.fromPath('audio', audioFilePath));

      // Add duration if provided
      if (duration != null) {
        request.fields['duration'] = duration.toString();
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201 || response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final data = decoded['data'];
        if (data is Map<String, dynamic> && data['message'] is Map<String, dynamic>) {
          final messageJson = data['message'] as Map<String, dynamic>;
          return ChatMessageDto.fromJson(messageJson);
        }
        return null;
      } else {
        debugPrint('ChatService.sendVoiceMessage failed: ${response.statusCode} ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('ChatService.sendVoiceMessage error: $e');
      return null;
    }
  }

  /// Delete a message from a chat
  Future<bool> deleteMessage(String chatId, String messageId) async {
    final uri = Uri.parse('$_baseUrl/chats/$chatId/messages/$messageId');

    try {
      final response = await _client.delete(uri, headers: _buildHeaders());

      if (response.statusCode == 200) {
        return true;
      } else {
        debugPrint('ChatService.deleteMessage failed: ${response.statusCode} ${response.body}');
        return false;
      }
    } catch (e) {
      debugPrint('ChatService.deleteMessage error: $e');
      return false;
    }
  }
}
