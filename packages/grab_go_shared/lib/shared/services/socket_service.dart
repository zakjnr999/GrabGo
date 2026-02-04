import 'dart:async';
import 'dart:collection';

import 'package:flutter/widgets.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_shared/shared/services/user_service.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

enum SocketConnectionState { disconnected, connecting, connected, reconnecting }

/// Represents a message that failed to send and is queued for retry
class QueuedMessage {
  final String chatId;
  final String tempId;
  final String text;
  final DateTime queuedAt;
  int retryCount;

  QueuedMessage({
    required this.chatId,
    required this.tempId,
    required this.text,
    required this.queuedAt,
    this.retryCount = 0,
  });

  Map<String, dynamic> toJson() => {
    'chatId': chatId,
    'tempId': tempId,
    'text': text,
    'queuedAt': queuedAt.toIso8601String(),
    'retryCount': retryCount,
  };

  factory QueuedMessage.fromJson(Map<String, dynamic> json) => QueuedMessage(
    chatId: json['chatId'] as String,
    tempId: json['tempId'] as String,
    text: json['text'] as String,
    queuedAt: DateTime.parse(json['queuedAt'] as String),
    retryCount: (json['retryCount'] as int?) ?? 0,
  );
}

class SocketService {
  SocketService._();
  static final SocketService _instance = SocketService._();
  factory SocketService() => _instance;

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
  final List<void Function(dynamic)> _deleteListeners = [];
  final List<void Function(dynamic)> _notificationListeners = [];

  // Order reservation listeners (for rider dispatch system)
  final List<void Function(dynamic)> _orderReservedListeners = [];
  final List<void Function(dynamic)> _reservationCancelledListeners = [];
  final List<void Function(dynamic)> _reservationExpiredListeners = [];
  final List<void Function(dynamic)> _orderTakenListeners = [];

  // Delivery timing listeners (for rider warnings and customer updates)
  final List<void Function(dynamic)> _deliveryWarningListeners = [];
  final List<void Function(dynamic)> _deliveryLateListeners = [];

  final Set<String> _joinedChats = <String>{};
  final Set<String> _pendingJoinChats = <String>{};

  // Notification deduplication with proper FIFO ordering
  final Queue<String> _notificationIdQueue = Queue<String>();
  final Set<String> _notificationIdSet = <String>{};
  static const int _maxCachedNotificationIds = 1000;

  SocketConnectionState _connectionState = SocketConnectionState.disconnected;
  final List<void Function(SocketConnectionState)> _connectionListeners = [];

  // Offline message queue
  final List<QueuedMessage> _messageQueue = [];
  bool _isProcessingQueue = false;
  static const int _maxRetries = 3;

  // Callback for when a queued message is retried
  final List<void Function(String chatId, String tempId, bool success, String? newId)> _retryListeners = [];

  bool get isConnected => _socket != null && _socket!.connected;
  IO.Socket? get socket => _socket;

  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 10; // Increased from 5 for better reliability

  int get totalUnread => _totalUnread;
  SocketConnectionState get connectionState => _connectionState;

  Future<void> initialize() async {
    try {
      debugPrint('🔌 SocketService.initialize() called');
      _totalUnread = CacheService.getChatUnreadCount();
      _notifyUnreadChanged();

      // Try to get user ID from UserService first
      _currentUserId = UserService().currentUser?.id;

      // If UserService doesn't have the user, try loading from cache directly
      if (_currentUserId == null || _currentUserId!.isEmpty) {
        final userData = CacheService.getUserData();
        if (userData != null) {
          // Try both '_id' (MongoDB style) and 'id' field names
          _currentUserId = userData['_id']?.toString() ?? userData['id']?.toString();
          debugPrint('🔌 SocketService: Loaded userId from cache: $_currentUserId');
        }
      }

      debugPrint('🔌 SocketService: currentUserId = $_currentUserId');
      if (_currentUserId == null || _currentUserId!.isEmpty) {
        debugPrint('❌ SocketService: No user ID, skipping socket connection');
        return;
      }

      await _bootstrapChats();
      _connectIfNeeded();
    } catch (e) {
      debugPrint('Error initializing ChatSocketService: $e');
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

  void addDeleteListener(void Function(dynamic) listener) {
    _deleteListeners.add(listener);
  }

  void removeDeleteListener(void Function(dynamic) listener) {
    _deleteListeners.remove(listener);
  }

  void addNotificationListener(void Function(dynamic) listener) {
    _notificationListeners.add(listener);
  }

  void removeNotificationListener(void Function(dynamic) listener) {
    _notificationListeners.remove(listener);
  }

  // ==================== ORDER RESERVATION LISTENERS ====================

  void addOrderReservedListener(void Function(dynamic) listener) {
    _orderReservedListeners.add(listener);
  }

  void removeOrderReservedListener(void Function(dynamic) listener) {
    _orderReservedListeners.remove(listener);
  }

  void addReservationCancelledListener(void Function(dynamic) listener) {
    _reservationCancelledListeners.add(listener);
  }

  void removeReservationCancelledListener(void Function(dynamic) listener) {
    _reservationCancelledListeners.remove(listener);
  }

  void addReservationExpiredListener(void Function(dynamic) listener) {
    _reservationExpiredListeners.add(listener);
  }

  void removeReservationExpiredListener(void Function(dynamic) listener) {
    _reservationExpiredListeners.remove(listener);
  }

  void addOrderTakenListener(void Function(dynamic) listener) {
    _orderTakenListeners.add(listener);
  }

  void removeOrderTakenListener(void Function(dynamic) listener) {
    _orderTakenListeners.remove(listener);
  }

  // ==================== DELIVERY TIMING LISTENERS ====================

  void addDeliveryWarningListener(void Function(dynamic) listener) {
    _deliveryWarningListeners.add(listener);
  }

  void removeDeliveryWarningListener(void Function(dynamic) listener) {
    _deliveryWarningListeners.remove(listener);
  }

  void addDeliveryLateListener(void Function(dynamic) listener) {
    _deliveryLateListeners.add(listener);
  }

  void removeDeliveryLateListener(void Function(dynamic) listener) {
    _deliveryLateListeners.remove(listener);
  }

  void addRetryListener(void Function(String chatId, String tempId, bool success, String? newId) listener) {
    _retryListeners.add(listener);
  }

  void removeRetryListener(void Function(String chatId, String tempId, bool success, String? newId) listener) {
    _retryListeners.remove(listener);
  }

  void addConnectionListener(void Function(SocketConnectionState) listener) {
    _connectionListeners.add(listener);
    try {
      listener(_connectionState);
    } catch (e) {
      debugPrint('Error in SocketService connection listener (initial): $e');
    }
  }

  void removeConnectionListener(void Function(SocketConnectionState) listener) {
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

  void joinChat(String chatId, {bool forceRejoin = false}) {
    if (chatId.isEmpty) return;

    _connectIfNeeded();
    final socket = _socket;
    if (socket == null || !socket.connected) {
      // Add to pending chats to join when connected
      _pendingJoinChats.add(chatId);
      return;
    }

    if (_joinedChats.contains(chatId) && !forceRejoin) return;

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

  void markAsRead(String chatId) {
    if (chatId.isEmpty) return;
    _connectIfNeeded();
    final socket = _socket;
    if (socket == null || !socket.connected) return;
    socket.emit('chat:mark_read', {'chatId': chatId});
  }

  void _setConnectionState(SocketConnectionState state) {
    if (_connectionState == state) return;

    final previousState = _connectionState;
    _connectionState = state;

    // Log state transitions for debugging
    debugPrint('Socket state transition: ${previousState.name} -> ${state.name}');
    // TODO: Add analytics logging for production monitoring
    // FirebaseAnalytics.instance.logEvent(name: 'socket_state_change', parameters: {
    //   'from': previousState.name,
    //   'to': state.name,
    //   'timestamp': DateTime.now().toIso8601String(),
    // });

    for (final listener in _connectionListeners) {
      try {
        listener(state);
      } catch (e) {
        // Silent in production
      }
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();

    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _setConnectionState(SocketConnectionState.disconnected);
      return;
    }

    // Exponential backoff with cap: 2s, 4s, 8s, 16s, 30s (max)
    final delaySeconds = (2 << _reconnectAttempts).clamp(2, 30);
    _reconnectAttempts += 1;

    _setConnectionState(SocketConnectionState.reconnecting);

    debugPrint('Scheduling socket reconnect in ${delaySeconds}s (attempt $_reconnectAttempts/$_maxReconnectAttempts)');

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

  Future<void> _connectIfNeeded() async {
    if (_socket != null || _connecting) return;
    _connecting = true;
    _setConnectionState(_reconnectAttempts > 0 ? SocketConnectionState.reconnecting : SocketConnectionState.connecting);

    final socketUrl = _buildSocketUrl();
    debugPrint('🔌 Socket connecting to: $socketUrl');
    final token = await CacheService.getAuthToken();
    if (token == null || token.isEmpty) {
      debugPrint('❌ Socket: No auth token available');
      _connecting = false;
      _setConnectionState(SocketConnectionState.disconnected);
      return;
    }
    debugPrint('🔑 Socket: Auth token found (${token.substring(0, 20)}...)');

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
      _setConnectionState(SocketConnectionState.connected);
      _joinedChats.clear();
      _joinAllCachedChats();
      // Note: Backend automatically joins user to `user:${userId}` room on connection
      // No need to emit anything - see server.js socket authentication middleware
      debugPrint('🔌 Socket connected! User ID: $_currentUserId - user room joined automatically by backend');
      // Join any pending chats that were requested before connection
      _joinPendingChats();
      // Process any queued messages when connection is restored
      _processMessageQueue();
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
          // Silent in production
        }
      }
    });

    _socket!.on('chat:presence', (data) {
      for (final listener in _presenceListeners) {
        try {
          listener(data);
        } catch (e) {
          // Silent in production
        }
      }
    });

    _socket!.on('chat:typing', (data) {
      for (final listener in _typingListeners) {
        try {
          listener(data);
        } catch (e) {
          // Silent in production
        }
      }
    });

    _socket!.on('chat:read', (data) {
      _handleReadInternal(data);
      for (final listener in _readListeners) {
        try {
          listener(data);
        } catch (e) {
          // Silent in production
        }
      }
    });

    _socket!.on('chat:message_deleted', (data) {
      for (final listener in List.from(_deleteListeners)) {
        try {
          listener(data);
        } catch (e) {
          // Silent in production
        }
      }
    });

    _socket!.on('newNotification', (data) {
      if (data is Map) {
        final notificationId = data['_id']?.toString() ?? data['id']?.toString();
        if (notificationId != null) {
          // Check for duplicates using Set for O(1) lookup
          if (_notificationIdSet.contains(notificationId)) {
            debugPrint('Deduplicating notification: $notificationId');
            return;
          }

          // Add to both Queue and Set
          _notificationIdQueue.add(notificationId);
          _notificationIdSet.add(notificationId);

          // Remove oldest if exceeding limit (proper FIFO)
          while (_notificationIdQueue.length > _maxCachedNotificationIds) {
            final oldest = _notificationIdQueue.removeFirst();
            _notificationIdSet.remove(oldest);
          }
        }
      }

      for (final listener in List.from(_notificationListeners)) {
        try {
          listener(data);
        } catch (e) {
          // Silent in production
        }
      }
    });

    // ==================== ORDER RESERVATION EVENTS ====================

    _socket!.on('order_reserved', (data) {
      debugPrint('📦 Socket received order_reserved: $data');
      for (final listener in List.from(_orderReservedListeners)) {
        try {
          listener(data);
        } catch (e) {
          debugPrint('Error in order_reserved listener: $e');
        }
      }
    });

    _socket!.on('reservation_cancelled', (data) {
      debugPrint('❌ Socket received reservation_cancelled: $data');
      for (final listener in List.from(_reservationCancelledListeners)) {
        try {
          listener(data);
        } catch (e) {
          debugPrint('Error in reservation_cancelled listener: $e');
        }
      }
    });

    _socket!.on('reservation_expired', (data) {
      debugPrint('⏰ Socket received reservation_expired: $data');
      for (final listener in List.from(_reservationExpiredListeners)) {
        try {
          listener(data);
        } catch (e) {
          debugPrint('Error in reservation_expired listener: $e');
        }
      }
    });

    _socket!.on('order_taken', (data) {
      debugPrint('🚴 Socket received order_taken: $data');
      for (final listener in List.from(_orderTakenListeners)) {
        try {
          listener(data);
        } catch (e) {
          debugPrint('Error in order_taken listener: $e');
        }
      }
    });

    // ==================== DELIVERY TIMING EVENTS ====================

    _socket!.on('delivery_warning', (data) {
      debugPrint('⏰ Socket received delivery_warning: $data');
      for (final listener in List.from(_deliveryWarningListeners)) {
        try {
          listener(data);
        } catch (e) {
          debugPrint('Error in delivery_warning listener: $e');
        }
      }
    });

    _socket!.on('delivery_late', (data) {
      debugPrint('🕐 Socket received delivery_late: $data');
      for (final listener in List.from(_deliveryLateListeners)) {
        try {
          listener(data);
        } catch (e) {
          debugPrint('Error in delivery_late listener: $e');
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
      debugPrint('Error bootstrapping chats for ChatSocketService: $e');
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
      debugPrint('Error joining cached chats: $e');
    }
  }

  void _joinPendingChats() {
    if (_pendingJoinChats.isEmpty) return;
    final pending = List<String>.from(_pendingJoinChats);
    _pendingJoinChats.clear();
    for (final chatId in pending) {
      joinChat(chatId);
    }
  }

  void updateKnownChats(List<String> chatIds, {bool forceRejoin = false}) {
    _connectIfNeeded();

    for (final chatId in chatIds) {
      if (chatId == 'support') continue;
      // joinChat will queue the chat if socket isn't connected yet
      joinChat(chatId, forceRejoin: forceRejoin);
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

    final map = Map<String, dynamic>.from(data);
    final chatId = map['chatId']?.toString();
    final messageJson = map['message'];
    if (messageJson is! Map) return;

    final messageMap = Map<String, dynamic>.from(messageJson);
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

  /// Queue a failed message for retry when connection is restored
  void queueFailedMessage(String chatId, String tempId, String text) {
    if (_messageQueue.any((m) => m.tempId == tempId)) return;

    _messageQueue.add(QueuedMessage(chatId: chatId, tempId: tempId, text: text, queuedAt: DateTime.now()));
    // Silent in production
  }

  /// Remove a message from the queue
  void removeFromQueue(String tempId) {
    _messageQueue.removeWhere((m) => m.tempId == tempId);
  }

  /// Get queued messages for a specific chat
  List<QueuedMessage> getQueuedMessages(String chatId) {
    return _messageQueue.where((m) => m.chatId == chatId).toList();
  }

  /// Check if there are queued messages
  bool get hasQueuedMessages => _messageQueue.isNotEmpty;

  /// Process the message queue when connection is restored
  Future<void> _processMessageQueue() async {
    if (_isProcessingQueue || _messageQueue.isEmpty) return;
    if (!isConnected) return;

    _isProcessingQueue = true;
    // Silent in production

    final chatService = ChatService();
    final toRemove = <String>[];

    for (final queuedMsg in List.from(_messageQueue)) {
      if (!isConnected) break;

      try {
        final sent = await chatService.sendMessage(queuedMsg.chatId, queuedMsg.text);

        if (sent != null) {
          toRemove.add(queuedMsg.tempId);
          for (final listener in List.from(_retryListeners)) {
            try {
              listener(queuedMsg.chatId, queuedMsg.tempId, true, sent.id);
            } catch (e) {
              // Silent in production
            }
          }
          // Silent in production
        } else {
          queuedMsg.retryCount++;
          if (queuedMsg.retryCount >= _maxRetries) {
            toRemove.add(queuedMsg.tempId);
            for (final listener in List.from(_retryListeners)) {
              try {
                listener(queuedMsg.chatId, queuedMsg.tempId, false, null);
              } catch (e) {
                // Silent in production
              }
            }
          }
        }
      } catch (e) {
        // Silent in production
        queuedMsg.retryCount++;
        if (queuedMsg.retryCount >= _maxRetries) {
          toRemove.add(queuedMsg.tempId);
        }
      }
    }

    _messageQueue.removeWhere((m) => toRemove.contains(m.tempId));
    _isProcessingQueue = false;

    // Silent in production
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
      _messageQueue.clear();
      // Fix #4: Clear notification cache to prevent memory leak
      clearNotificationCache();
      _totalUnread = 0;
      _notifyUnreadChanged();
      _setConnectionState(SocketConnectionState.disconnected);
    } catch (_) {}
  }

  /// Clear notification cache (call on logout)
  void clearNotificationCache() {
    _notificationIdQueue.clear();
    _notificationIdSet.clear();
  }
}
