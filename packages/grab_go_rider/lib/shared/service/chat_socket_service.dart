import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:grab_go_rider/features/chat/service/chat_service.dart';
import 'package:grab_go_rider/shared/service/cache_service.dart';
import 'package:grab_go_rider/shared/service/user_service.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

enum ChatSocketConnectionState { disconnected, connecting, connected, reconnecting }

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

  final List<void Function(dynamic)> _newMessageListeners = [];
  final List<void Function(dynamic)> _presenceListeners = [];
  final List<void Function(dynamic)> _typingListeners = [];
  final List<void Function(dynamic)> _readListeners = [];

  final Set<String> _joinedChats = <String>{};

  ChatSocketConnectionState _connectionState = ChatSocketConnectionState.disconnected;
  final List<void Function(ChatSocketConnectionState)> _connectionListeners = [];

  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;

  int get totalUnread => _totalUnread;
  ChatSocketConnectionState get connectionState => _connectionState;

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

  void addNewMessageListener(void Function(dynamic) listener) {
    _newMessageListeners.add(listener);
  }

  void removeNewMessageListener(void Function(dynamic) listener) {
    _newMessageListeners.remove(listener);
  }

  void addPresenceListener(void Function(dynamic) listener) {
    _presenceListeners.add(listener);
  }

  void removePresenceListener(void Function(dynamic) listener) {
    _presenceListeners.remove(listener);
  }

  void addTypingListener(void Function(dynamic) listener) {
    _typingListeners.add(listener);
  }

  void removeTypingListener(void Function(dynamic) listener) {
    _typingListeners.remove(listener);
  }

  void addReadListener(void Function(dynamic) listener) {
    _readListeners.add(listener);
  }

  void removeReadListener(void Function(dynamic) listener) {
    _readListeners.remove(listener);
  }

  void addConnectionListener(void Function(ChatSocketConnectionState) listener) {
    _connectionListeners.add(listener);
    try {
      listener(_connectionState);
    } catch (e) {
      debugPrint('Error in ChatSocketService connection listener (initial): $e');
    }
  }

  void removeConnectionListener(void Function(ChatSocketConnectionState) listener) {
    _connectionListeners.remove(listener);
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

  void joinChat(String chatId) {
    if (chatId.isEmpty) return;
    if (_joinedChats.contains(chatId)) return;

    _connectIfNeeded();
    final socket = _socket;
    if (socket == null || !socket.connected) return;

    socket.emit('chat:join', {'chatId': chatId});
    _joinedChats.add(chatId);
  }

  void setTyping(String chatId, bool isTyping) {
    if (chatId.isEmpty) return;
    _connectIfNeeded();
    final socket = _socket;
    if (socket == null || !socket.connected) return;
    socket.emit('chat:typing', {'chatId': chatId, 'isTyping': isTyping});
  }

  void _setConnectionState(ChatSocketConnectionState state) {
    if (_connectionState == state) return;
    _connectionState = state;
    for (final listener in _connectionListeners) {
      try {
        listener(state);
      } catch (e) {
        debugPrint('Error in ChatSocketService connection listener: $e');
      }
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();

    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _setConnectionState(ChatSocketConnectionState.disconnected);
      return;
    }

    final delaySeconds = 2 * (_reconnectAttempts + 1);
    _reconnectAttempts += 1;

    _setConnectionState(ChatSocketConnectionState.reconnecting);

    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      _connectIfNeeded();
    });
  }

  void _handleSocketDisconnectOrError() {
    _connecting = false;
    try {
      _socket?.dispose();
    } catch (_) {}
    _socket = null;
    _joinedChats.clear();
    _scheduleReconnect();
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
    _setConnectionState(
      _reconnectAttempts > 0 ? ChatSocketConnectionState.reconnecting : ChatSocketConnectionState.connecting,
    );

    final socketUrl = _buildSocketUrl();
    final token = CacheService.getAuthToken();
    if (token == null || token.isEmpty) {
      _connecting = false;
      _setConnectionState(ChatSocketConnectionState.disconnected);
      return;
    }

    _socket = IO.io(
      socketUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .disableAutoConnect()
          .disableReconnection()
          .build(),
    );

    _socket!.onConnect((_) {
      _currentUserId ??= UserService().currentUser?.id;
      _connecting = false;
      _reconnectAttempts = 0;
      _setConnectionState(ChatSocketConnectionState.connected);
      _joinedChats.clear();
      _joinAllCachedChats();
    });

    _socket!.onConnectError((error) {
      debugPrint('Chat socket connect error (rider): $error');
      _handleSocketDisconnectOrError();
    });

    _socket!.onError((error) {
      debugPrint('Chat socket error (rider): $error');
    });

    _socket!.on('chat:new_message', (data) {
      _handleNewMessageInternal(data);
      for (final listener in _newMessageListeners) {
        try {
          listener(data);
        } catch (e) {
          debugPrint('Error in chat:new_message listener: $e');
        }
      }
    });

    _socket!.on('chat:presence', (data) {
      for (final listener in _presenceListeners) {
        try {
          listener(data);
        } catch (e) {
          debugPrint('Error in chat:presence listener: $e');
        }
      }
    });

    _socket!.on('chat:typing', (data) {
      for (final listener in _typingListeners) {
        try {
          listener(data);
        } catch (e) {
          debugPrint('Error in chat:typing listener: $e');
        }
      }
    });

    _socket!.on('chat:read', (data) {
      _handleReadInternal(data);
      for (final listener in _readListeners) {
        try {
          listener(data);
        } catch (e) {
          debugPrint('Error in chat:read listener: $e');
        }
      }
    });

    _socket!.onDisconnect((_) {
      debugPrint('Chat socket disconnected (rider)');
      _handleSocketDisconnectOrError();
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

    try {
      final cached = CacheService.getChatList();
      for (final chat in cached) {
        final id = chat['id']?.toString();
        if (id == null || id.isEmpty || id == 'support') continue;
        joinChat(id);
      }
    } catch (e) {
      debugPrint('Error joining cached chats (rider): $e');
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
      joinChat(chatId);
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

    final map = Map<String, dynamic>.from(data);
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
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
      _joinedChats.clear();
      _unreadByChatId.clear();
      _totalUnread = 0;
      _notifyUnreadChanged();
      _setConnectionState(ChatSocketConnectionState.disconnected);
    } catch (_) {}
  }
}
