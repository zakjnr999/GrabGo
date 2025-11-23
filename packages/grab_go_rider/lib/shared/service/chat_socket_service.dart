import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:grab_go_rider/features/chat/service/chat_service.dart';
import 'package:grab_go_rider/shared/service/cache_service.dart';
import 'package:grab_go_rider/shared/service/user_service.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class ChatSocketService {
  ChatSocketService._();
  static final ChatSocketService _instance = ChatSocketService._();
  factory ChatSocketService() => _instance;

  IO.Socket? _socket;
  String? _currentUserId;
  bool _connecting = false;

  int _totalUnread = 0;
  final Map<String, int> _unreadByChatId = {};
  void Function(int)? _onUnreadChanged;

  int get totalUnread => _totalUnread;

  Future<void> initialize() async {
    try {
      _totalUnread = CacheService.getChatUnreadCount();
      _notifyUnreadChanged();

      _currentUserId = UserService().currentUser?.id;
      if (_currentUserId == null || _currentUserId!.isEmpty) {
        return;
      }

      await _bootstrapChats();
      _connectIfNeeded();
    } catch (e) {
      debugPrint('Error initializing ChatSocketService (rider): $e');
    }
  }

  void registerUnreadListener(void Function(int) listener) {
    _onUnreadChanged = listener;
  }

  void overrideTotalUnread(int count) {
    final normalized = count < 0 ? 0 : count;
    if (normalized == _totalUnread) return;
    _totalUnread = normalized;
    _notifyUnreadChanged();
  }

  void applyLocalRead(int unreadCleared) {
    if (unreadCleared <= 0) return;
    _totalUnread = (_totalUnread - unreadCleared).clamp(0, 1 << 30);
    _notifyUnreadChanged();
  }

  void markChatAsReadLocally(String chatId, int cleared) {
    if (cleared <= 0) return;

    // Use the tracked per-chat value to avoid double-subtracting
    final previous = _unreadByChatId[chatId] ?? 0;
    if (previous <= 0) return;

    _unreadByChatId[chatId] = 0;
    _totalUnread -= previous;
    if (_totalUnread < 0) {
      _totalUnread = 0;
    }
    _notifyUnreadChanged();
    _updateCachedChatUnread(chatId, 0);
  }

  void _notifyUnreadChanged() {
    final listener = _onUnreadChanged;
    final currentTotal = _totalUnread;

    if (listener != null) {
      // Defer the notification to the next frame to avoid triggering provider rebuilds
      // during widget build, but explicitly schedule a frame so this still runs even
      // when the UI is otherwise idle.
      WidgetsBinding.instance.scheduleFrame();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        listener(currentTotal);
      });
    }

    unawaited(CacheService.saveChatUnreadCount(currentTotal));
  }

  void _connectIfNeeded() {
    if (_socket != null || _connecting) return;
    _connecting = true;

    final socketUrl = _buildSocketUrl();
    _socket = IO.io(socketUrl, IO.OptionBuilder().setTransports(['websocket']).disableAutoConnect().build());

    _socket!.onConnect((_) {
      _currentUserId ??= UserService().currentUser?.id;
      _joinAllCachedChats();
    });

    _socket!.on('chat:new_message', _handleNewMessageInternal);
    _socket!.on('chat:read', _handleReadInternal);

    _socket!.onDisconnect((_) {
      _connecting = false;
      // Allow a fresh connection to be created on next demand.
      _socket = null;
    });

    _socket!.connect();
  }

  String _buildSocketUrl() {
    final apiBase = AppConfig.apiBaseUrl;
    if (apiBase.endsWith('/api/')) {
      return apiBase.substring(0, apiBase.length - 5);
    }
    if (apiBase.endsWith('/api')) {
      return apiBase.substring(0, apiBase.length - 4);
    }
    return apiBase;
  }

  Future<void> _bootstrapChats() async {
    try {
      final chatService = ChatService();
      final apiChats = await chatService.getChats();
      final List<Map<String, dynamic>> serialized = [];
      int totalUnread = 0;
      _unreadByChatId.clear();

      for (final chat in apiChats) {
        final senderId = chat.otherUserId ?? 'unknown_user';
        final senderName = chat.otherUserName ?? (chat.otherUserRole == 'customer' ? 'Customer' : 'User');
        final unread = chat.unreadCount;

        if (unread > 0) {
          totalUnread += unread;
          _unreadByChatId[chat.id] = unread;
        } else {
          _unreadByChatId[chat.id] = 0;
        }

        serialized.add({
          'id': chat.id,
          'senderId': senderId,
          'senderName': senderName,
          'lastMessage': chat.lastMessage,
          'timestamp': chat.lastMessageAt.toIso8601String(),
          'unreadCount': unread,
          'isOnline': false,
          'orderId': chat.orderNumber,
          'isTyping': false,
        });
      }

      final now = DateTime.now();
      serialized.insert(0, {
        'id': 'support',
        'senderId': 'support',
        'senderName': 'GrabGo Support',
        'lastMessage': 'Chat with GrabGo Support',
        'timestamp': now.toIso8601String(),
        'unreadCount': 0,
        'isOnline': true,
        'orderId': null,
        'isTyping': false,
      });
      _unreadByChatId['support'] = 0;

      _totalUnread = totalUnread;
      _notifyUnreadChanged();
      unawaited(CacheService.saveChatList(serialized));
    } catch (e) {
      debugPrint('Error bootstrapping chats for ChatSocketService (rider): $e');
    }
  }

  void _joinAllCachedChats() {
    if (_socket == null || !_socket!.connected) return;
    _currentUserId ??= UserService().currentUser?.id;
    final userId = _currentUserId;
    if (userId == null || userId.isEmpty) return;

    final cached = CacheService.getChatList();
    for (final chat in cached) {
      final id = chat['id']?.toString();
      if (id == null || id.isEmpty || id == 'support') continue;
      _socket!.emit('chat:join', {'chatId': id, 'userId': userId});
    }
  }

  void updateKnownChats(List<String> chatIds) {
    if (_socket == null || !_socket!.connected) {
      _connectIfNeeded();
    }
    if (_socket == null || !_socket!.connected) return;
    _currentUserId ??= UserService().currentUser?.id;
    final userId = _currentUserId;
    if (userId == null || userId.isEmpty) return;

    for (final chatId in chatIds) {
      if (chatId == 'support') continue;
      _socket!.emit('chat:join', {'chatId': chatId, 'userId': userId});
    }
  }

  void _updateCachedChatListOnNewMessage(String chatId, String text, DateTime sentAt) {
    try {
      final cached = CacheService.getChatList();
      if (cached.isEmpty) return;

      bool updated = false;
      for (final chat in cached) {
        if (chat['id']?.toString() == chatId) {
          chat['lastMessage'] = text;
          chat['timestamp'] = sentAt.toIso8601String();

          final unreadRaw = chat['unreadCount'];
          final currentUnread = unreadRaw is int ? unreadRaw : int.tryParse(unreadRaw?.toString() ?? '0') ?? 0;
          chat['unreadCount'] = currentUnread + 1;
          updated = true;
          break;
        }
      }

      if (updated) {
        unawaited(CacheService.saveChatList(cached));
      }
    } catch (e) {
      debugPrint('Error updating cached chat list on new message (rider): $e');
    }
  }

  void _updateCachedChatUnread(String chatId, int unread) {
    try {
      final cached = CacheService.getChatList();
      if (cached.isEmpty) return;

      bool updated = false;
      for (final chat in cached) {
        if (chat['id']?.toString() == chatId) {
          chat['unreadCount'] = unread;
          updated = true;
          break;
        }
      }

      if (updated) {
        unawaited(CacheService.saveChatList(cached));
      }
    } catch (e) {
      debugPrint('Error updating cached chat list unread (rider): $e');
    }
  }

  void _handleNewMessageInternal(dynamic data) {
    if (data is! Map) return;

    final map = Map<String, dynamic>.from(data as Map);
    final chatId = map['chatId']?.toString();
    final messageJson = map['message'];
    if (messageJson is! Map) return;

    final messageMap = Map<String, dynamic>.from(messageJson as Map);
    final senderId = messageMap['senderId']?.toString() ?? '';

    _currentUserId ??= UserService().currentUser?.id;
    if (_currentUserId != null && senderId == _currentUserId) {
      return;
    }

    if (chatId != null && chatId.isNotEmpty) {
      final previous = _unreadByChatId[chatId] ?? 0;
      final newUnread = previous + 1;
      _unreadByChatId[chatId] = newUnread;

      _updateCachedChatListOnNewMessage(
        chatId,
        messageMap['text']?.toString() ?? '',
        DateTime.tryParse(messageMap['sentAt']?.toString() ?? '') ?? DateTime.now(),
      );
    }

    _totalUnread += 1;
    _notifyUnreadChanged();
  }

  void _handleReadInternal(dynamic data) {
    if (data is! Map) return;

    final map = Map<String, dynamic>.from(data as Map);
    final chatId = map['chatId']?.toString();
    final userId = map['userId']?.toString();
    if (chatId == null || userId == null) return;

    _currentUserId ??= UserService().currentUser?.id;
    if (_currentUserId == null || userId != _currentUserId) return;

    final previous = _unreadByChatId[chatId] ?? 0;
    if (previous <= 0) return;

    _unreadByChatId[chatId] = 0;
    _totalUnread -= previous;
    if (_totalUnread < 0) {
      _totalUnread = 0;
    }
    _notifyUnreadChanged();
    _updateCachedChatUnread(chatId, 0);
  }

  void dispose() {
    try {
      _socket?.dispose();
      _socket = null;
      _connecting = false;
      _unreadByChatId.clear();
      _totalUnread = 0;
      _notifyUnreadChanged();
    } catch (_) {}
  }
}
