import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/features/chat/service/chat_service.dart';
import 'package:grab_go_customer/features/order/service/order_service_wrapper.dart';
import 'package:grab_go_customer/shared/services/user_service.dart';
import 'package:grab_go_customer/shared/services/cache_service.dart';
import 'package:grab_go_customer/shared/services/chat_socket_service.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:intl/intl.dart';

class ChatMessage {
  final String id;
  final String text;
  final DateTime timestamp;
  final bool isSentByMe;
  final bool isRead;
  final DateTime? readAt;
  final bool isPending;
  final bool isFailed;
  final bool isSystem;
  final String? replyToId;
  final String? replyToText;
  final bool? replyToIsSentByMe;

  ChatMessage({
    required this.id,
    required this.text,
    required this.timestamp,
    required this.isSentByMe,
    this.isRead = false,
    this.readAt,
    this.isPending = false,
    this.isFailed = false,
    this.isSystem = false,
    this.replyToId,
    this.replyToText,
    this.replyToIsSentByMe,
  });
}

class ChatDetail extends StatefulWidget {
  final String chatId;
  final String senderName;
  final String? orderId;
  final bool isSupport;

  const ChatDetail({super.key, required this.chatId, required this.senderName, this.orderId, this.isSupport = false});

  @override
  State<ChatDetail> createState() => _ChatDetailState();
}

class _ChatDetailState extends State<ChatDetail> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();
  List<ChatMessage> _messages = [];
  final ChatService _chatService = ChatService();
  final OrderServiceWrapper _orderService = OrderServiceWrapper();
  final UserService _userService = UserService();
  static const int _maxCachedMessages = 200;
  String? _error;
  String? _currentUserId;
  bool _hasPendingSend = false;
  bool _isPeerOnline = false;
  bool _isPeerTyping = false;
  bool _isTyping = false;
  Timer? _typingTimer;
  Timer? _orderStatusTimer;
  String? _orderId;
  String? _orderNumber;
  DateTime? _peerLastSeenAt;
  final List<String> _quickIssueTemplates = const [
    'Where is my order right now?',
    'Please call me when you arrive.',
    'Can you come to the main gate?',
    'I want to update my delivery instructions.',
  ];
  int? _firstUnreadIndex;
  bool _showScrollToBottomButton = false;
  ChatMessage? _replyingTo;
  int _pendingNewMessages = 0;
  final GlobalKey _firstUnreadKey = GlobalKey();

  // Pagination state
  bool _hasMoreMessages = false;
  bool _isLoadingMore = false;

  void _loadCachedMessages() {
    final cached = CacheService.getChatMessages(widget.chatId);
    if (cached.isEmpty) return;

    final messages = cached
        .map((m) {
          final id = m['id']?.toString() ?? '';
          if (id.isEmpty) return null;

          final text = m['text']?.toString() ?? '';
          final tsStr = m['timestamp']?.toString();
          final timestamp = DateTime.tryParse(tsStr ?? '') ?? DateTime.now();
          final isSentByMe = m['isSentByMe'] == true;
          final isRead = m['isRead'] == true;
          final isSystem = m['isSystem'] == true;

          return ChatMessage(
            id: id,
            text: text,
            timestamp: timestamp,
            isSentByMe: isSentByMe,
            isRead: isRead,
            isSystem: isSystem,
          );
        })
        .whereType<ChatMessage>()
        .toList();

    if (messages.isEmpty) return;

    int? firstUnreadIndex;
    final lastSeen = CacheService.getChatLastSeen(widget.chatId);
    if (lastSeen != null) {
      for (var i = 0; i < messages.length; i++) {
        if (messages[i].timestamp.isAfter(lastSeen)) {
          firstUnreadIndex = i;
          break;
        }
      }
    }

    setState(() {
      _messages = messages;
      _firstUnreadIndex = firstUnreadIndex;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_firstUnreadIndex != null && _firstUnreadKey.currentContext != null) {
        Scrollable.ensureVisible(
          _firstUnreadKey.currentContext!,
          duration: const Duration(milliseconds: 300),
          alignment: 0.1,
        );
      } else {
        _scrollToBottom(force: true);
      }
    });
  }

  void _cacheMessages() {
    final source = _messages.length > _maxCachedMessages
        ? _messages.sublist(_messages.length - _maxCachedMessages)
        : _messages;

    final serialized = source
        .map(
          (m) => {
            'id': m.id,
            'text': m.text,
            'timestamp': m.timestamp.toIso8601String(),
            'isSentByMe': m.isSentByMe,
            'isRead': m.isRead,
            'isSystem': m.isSystem,
          },
        )
        .toList();

    unawaited(CacheService.saveChatMessages(widget.chatId, serialized));
  }

  @override
  void initState() {
    super.initState();
    _loadCachedMessages();
    _initAndLoadMessages();
    if (!widget.isSupport) {
      _setupSocketListeners();
    }
    final initialDraft = CacheService.getChatDraft(widget.chatId);
    if (initialDraft.isNotEmpty) {
      _messageController.text = initialDraft;
    }
    _scrollController.addListener(_handleScrollPositionChanged);
    _messageFocusNode.addListener(() {
      if (_messageFocusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 300), () {
          _scrollToBottom(force: true);
        });
      }
    });
  }

  @override
  void dispose() {
    _orderStatusTimer?.cancel();
    _typingTimer?.cancel();

    // Send typing stopped if we were typing
    if (_isTyping && !widget.isSupport) {
      ChatSocketService().setTyping(widget.chatId, false);
    }

    // Remove socket listeners
    if (!widget.isSupport) {
      final chatSocket = ChatSocketService();
      chatSocket.removeNewMessageListener(_handleIncomingSocketMessage);
      chatSocket.removePresenceListener(_handlePresenceEvent);
      chatSocket.removeTypingListener(_handleTypingEvent);
      chatSocket.removeReadListener(_handleReadEvent);
      chatSocket.removeRetryListener(_handleQueuedMessageRetry);
      chatSocket.removeDeleteListener(_handleMessageDeleted);
    }

    _scrollController.removeListener(_handleScrollPositionChanged);
    unawaited(CacheService.saveChatDraft(widget.chatId, _messageController.text));
    final lastSeen = _messages.isNotEmpty ? _messages.last.timestamp : DateTime.now();
    unawaited(CacheService.saveChatLastSeen(widget.chatId, lastSeen));
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  Future<void> _initAndLoadMessages() async {
    setState(() {
      _error = null;
    });

    try {
      if (widget.isSupport) {
        _loadSupportMessages();
      } else {
        _currentUserId = _userService.getUserId();
        final chatDetail = await _chatService.getChat(widget.chatId);

        if (!mounted) return;

        if (chatDetail == null) {
          setState(() {
            _messages = [];
            _error = 'Unable to load conversation.';
          });
        } else {
          final currentUserId = _currentUserId;

          String? otherUserId;
          if (currentUserId != null) {
            if (chatDetail.customerId == currentUserId) {
              otherUserId = chatDetail.riderId;
            } else if (chatDetail.riderId == currentUserId) {
              otherUserId = chatDetail.customerId;
            }
          }

          final loadedMessages = chatDetail.messages.map((m) {
            final isSentByMe = currentUserId != null && m.senderId == currentUserId;

            bool isReadByOther = false;
            if (isSentByMe && otherUserId != null) {
              isReadByOther = m.readBy.contains(otherUserId);
            }

            return ChatMessage(
              id: m.id,
              text: m.text,
              timestamp: m.sentAt,
              isSentByMe: isSentByMe,
              isRead: isReadByOther,
            );
          }).toList();

          final lastSeen = CacheService.getChatLastSeen(widget.chatId);
          int? firstUnreadIndex;
          if (lastSeen != null) {
            for (var i = 0; i < loadedMessages.length; i++) {
              if (loadedMessages[i].timestamp.isAfter(lastSeen)) {
                firstUnreadIndex = i;
                break;
              }
            }
          }

          setState(() {
            _messages = loadedMessages;
            _orderId = chatDetail.orderId ?? widget.orderId;
            _orderNumber = chatDetail.orderNumber;
            _firstUnreadIndex = firstUnreadIndex;
            _hasMoreMessages = chatDetail.pagination?.hasMore ?? false;
          });

          _cacheMessages();

          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            if (_firstUnreadIndex != null && _firstUnreadKey.currentContext != null) {
              Scrollable.ensureVisible(
                _firstUnreadKey.currentContext!,
                duration: const Duration(milliseconds: 300),
                alignment: 0.1,
              );
            } else {
              _scrollToBottom(force: true);
            }
          });

          if (!widget.isSupport) {
            unawaited(_syncOrderStatusSystemMessage());
            _orderStatusTimer ??= Timer.periodic(const Duration(seconds: 30), (_) {
              _syncOrderStatusSystemMessage();
            });
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load messages. Please try again.';
        _messages = [];
      });
    } finally {}
  }

  void _setupSocketListeners() {
    debugPrint('[ChatDetail] _setupSocketListeners called, isSupport: ${widget.isSupport}, chatId: ${widget.chatId}');
    if (widget.isSupport) return;

    final chatSocket = ChatSocketService();
    chatSocket.addNewMessageListener(_handleIncomingSocketMessage);
    chatSocket.addPresenceListener(_handlePresenceEvent);
    chatSocket.addTypingListener(_handleTypingEvent);
    chatSocket.addReadListener(_handleReadEvent);
    chatSocket.addRetryListener(_handleQueuedMessageRetry);
    chatSocket.addDeleteListener(_handleMessageDeleted);

    // Ensure we're joined to this chat
    debugPrint('[ChatDetail] Calling joinChat with chatId: ${widget.chatId}');
    chatSocket.joinChat(widget.chatId);
  }

  void _handleMessageDeleted(dynamic data) {
    if (!mounted || widget.isSupport) return;
    if (data is! Map) return;

    final map = Map<String, dynamic>.from(data);
    final payloadChatId = map['chatId']?.toString();
    if (payloadChatId != widget.chatId) return;

    final messageId = map['messageId']?.toString();
    if (messageId == null) return;

    setState(() {
      _messages.removeWhere((m) => m.id == messageId);
    });
    _cacheMessages();
  }

  void _handleQueuedMessageRetry(String chatId, String tempId, bool success, String? newId) {
    if (!mounted || chatId != widget.chatId) return;

    final index = _messages.indexWhere((m) => m.id == tempId);
    if (index == -1) return;

    setState(() {
      if (success && newId != null) {
        // Update the message with the real ID and mark as sent
        final existing = _messages[index];
        _messages[index] = ChatMessage(
          id: newId,
          text: existing.text,
          timestamp: existing.timestamp,
          isSentByMe: true,
          isRead: false,
          isPending: false,
          isFailed: false,
          isSystem: false,
        );
        HapticFeedback.lightImpact();
      } else {
        // Mark as permanently failed after max retries
        final existing = _messages[index];
        _messages[index] = ChatMessage(
          id: existing.id,
          text: existing.text,
          timestamp: existing.timestamp,
          isSentByMe: existing.isSentByMe,
          isRead: existing.isRead,
          isPending: false,
          isFailed: true,
          isSystem: existing.isSystem,
        );
      }
    });
    _cacheMessages();
  }

  void _handleIncomingSocketMessage(dynamic data) {
    if (!mounted || widget.isSupport) return;
    if (data is! Map) return;

    final map = Map<String, dynamic>.from(data);
    final payloadChatId = map['chatId']?.toString();
    if (payloadChatId != widget.chatId) return;

    final messageJson = map['message'];
    if (messageJson is! Map) return;

    final messageMap = Map<String, dynamic>.from(messageJson);
    final id = messageMap['id']?.toString() ?? '';
    if (id.isEmpty) return;

    _currentUserId ??= _userService.getUserId();
    final senderId = messageMap['senderId']?.toString() ?? '';

    // Ignore messages that we ourselves sent. These are already shown via the
    // optimistic message in _sendMessage, and updated when the HTTP call
    // returns, so processing the socket echo would create duplicates.
    if (_currentUserId != null && senderId == _currentUserId) {
      return;
    }

    final exists = _messages.any((m) => m.id == id);
    if (exists) return;

    final msg = ChatMessage(
      id: id,
      text: messageMap['text']?.toString() ?? '',
      timestamp: DateTime.tryParse(messageMap['sentAt']?.toString() ?? '') ?? DateTime.now(),
      isSentByMe: _currentUserId != null && senderId == _currentUserId,
      isRead: _currentUserId != null && senderId == _currentUserId,
      isSystem: false,
    );

    final isNearBottom =
        _scrollController.hasClients &&
        (_scrollController.position.maxScrollExtent - _scrollController.position.pixels) < 100;

    setState(() {
      _messages.add(msg);
      if (!isNearBottom) {
        _pendingNewMessages += 1;
        _showScrollToBottomButton = true;
      }
    });

    _cacheMessages();
    if (isNearBottom) {
      _scrollToBottom();
    }
  }

  void _handlePresenceEvent(dynamic data) {
    debugPrint('[ChatDetail] Presence event received: $data');
    if (!mounted || widget.isSupport) return;
    if (data is! Map) return;

    final map = Map<String, dynamic>.from(data);
    final payloadChatId = map['chatId']?.toString();
    debugPrint('[ChatDetail] Presence chatId: $payloadChatId, widget.chatId: ${widget.chatId}');
    if (payloadChatId != widget.chatId) return;

    // Ignore our own presence events
    final eventUserId = map['userId']?.toString();
    _currentUserId ??= _userService.getUserId();
    debugPrint('[ChatDetail] Presence eventUserId: $eventUserId, currentUserId: $_currentUserId');
    if (eventUserId == _currentUserId) return;

    final online = map['online'] == true;
    debugPrint('[ChatDetail] Setting _isPeerOnline to: $online');

    setState(() {
      _isPeerOnline = online;
      if (!online) {
        _isPeerTyping = false;
        _peerLastSeenAt = DateTime.now();
      }
    });
  }

  void _handleTypingEvent(dynamic data) {
    debugPrint('[ChatDetail] Typing event received: $data');
    if (!mounted || widget.isSupport) return;
    if (data is! Map) return;

    final map = Map<String, dynamic>.from(data);
    final payloadChatId = map['chatId']?.toString();
    debugPrint('[ChatDetail] Typing chatId: $payloadChatId, widget.chatId: ${widget.chatId}');
    if (payloadChatId != widget.chatId) return;

    // Ignore our own typing events
    final eventUserId = map['userId']?.toString();
    _currentUserId ??= _userService.getUserId();
    debugPrint('[ChatDetail] Typing eventUserId: $eventUserId, currentUserId: $_currentUserId');
    if (eventUserId == _currentUserId) return;

    final isTyping = map['isTyping'] == true;
    debugPrint('[ChatDetail] Setting _isPeerTyping to: $isTyping');

    setState(() {
      _isPeerTyping = isTyping;
      if (isTyping) {
        _isPeerOnline = true;
      }
    });
  }

  void _handleReadEvent(dynamic data) {
    if (!mounted || widget.isSupport) return;
    if (data is! Map) return;

    final map = Map<String, dynamic>.from(data);
    final payloadChatId = map['chatId']?.toString();
    if (payloadChatId != widget.chatId) return;

    final readerId = map['userId']?.toString();
    if (readerId == null || readerId.isEmpty) return;

    _currentUserId ??= _userService.getUserId();
    final currentUserId = _currentUserId;
    if (currentUserId == null || currentUserId.isEmpty) return;

    if (readerId == currentUserId) return;

    // Parse readAt timestamp from event, or use current time
    final readAtStr = map['readAt']?.toString();
    final readAt = readAtStr != null ? DateTime.tryParse(readAtStr) : DateTime.now();

    setState(() {
      _messages = _messages
          .map(
            (m) => m.isSentByMe && !m.isRead
                ? ChatMessage(
                    id: m.id,
                    text: m.text,
                    timestamp: m.timestamp,
                    isSentByMe: m.isSentByMe,
                    isRead: true,
                    readAt: readAt,
                    isPending: m.isPending,
                    isFailed: m.isFailed,
                    isSystem: m.isSystem,
                  )
                : m,
          )
          .toList();
    });
    _cacheMessages();
  }

  void _handleMessageChanged(String value) {
    CacheService.saveChatDraft(widget.chatId, value);
    if (widget.isSupport) return;

    final userId = _userService.getUserId();
    if (userId == null || userId.isEmpty) return;

    final chatSocket = ChatSocketService();
    if (!chatSocket.isConnected) return;

    if (!_isTyping) {
      _isTyping = true;
      chatSocket.setTyping(widget.chatId, true);
    }

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      if (!_isTyping) return;
      _isTyping = false;
      ChatSocketService().setTyping(widget.chatId, false);
    });
  }

  void _loadSupportMessages() {
    final now = DateTime.now();
    setState(() {
      _messages = [
        ChatMessage(
          id: '1',
          text: 'Hello, how can we help you today?',
          timestamp: now.subtract(const Duration(minutes: 5)),
          isSentByMe: false,
          isRead: true,
        ),
        ChatMessage(
          id: '2',
          text: 'You can ask about orders, payments, or general support.',
          timestamp: now.subtract(const Duration(minutes: 4)),
          isSentByMe: false,
          isRead: true,
        ),
      ];
    });
    _cacheMessages();
  }

  void _appendLocalSupportMessage() {
    final text = _messageController.text.trim();
    _messageController.clear();

    if (text.isEmpty) return;

    final userMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: text,
      timestamp: DateTime.now(),
      isSentByMe: true,
      isRead: true,
    );

    setState(() {
      _messages.add(userMessage);
    });

    _cacheMessages();
    _scrollToBottom();
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    if (widget.isSupport) {
      _appendLocalSupportMessage();
      return;
    }

    _typingTimer?.cancel();
    if (_isTyping) {
      final userId = _userService.getUserId();
      if (userId != null && userId.isNotEmpty) {
        ChatSocketService().setTyping(widget.chatId, false);
      }
      _isTyping = false;
    }

    final text = _messageController.text.trim();
    _messageController.clear();

    // Capture reply before clearing
    final replyTo = _replyingTo;
    _cancelReply();

    await _sendQuickMessage(text, replyTo: replyTo);
  }

  Future<void> _sendQuickMessage(String text, {ChatMessage? replyTo}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final tempId = DateTime.now().millisecondsSinceEpoch.toString();
    final optimisticMessage = ChatMessage(
      id: tempId,
      text: trimmed,
      timestamp: DateTime.now(),
      isSentByMe: true,
      isRead: false,
      isPending: true,
      isFailed: false,
      replyToId: replyTo?.id,
      replyToText: replyTo?.text,
      replyToIsSentByMe: replyTo?.isSentByMe,
    );

    setState(() {
      _messages.add(optimisticMessage);
    });

    _cacheMessages();
    _scrollToBottom();

    _hasPendingSend = true;
    try {
      final sent = await _chatService.sendMessage(widget.chatId, trimmed);
      if (!mounted || sent == null) return;

      final index = _messages.indexWhere((m) => m.id == tempId);
      if (index != -1) {
        final updated = ChatMessage(
          id: sent.id,
          text: sent.text,
          timestamp: sent.sentAt,
          isSentByMe: true,
          isRead: false,
          isPending: false,
          isFailed: false,
          isSystem: false,
        );

        setState(() {
          _messages[index] = updated;
        });

        _cacheMessages();
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        final index = _messages.indexWhere((m) => m.id == tempId);
        if (index != -1) {
          final existing = _messages[index];
          _messages[index] = ChatMessage(
            id: existing.id,
            text: existing.text,
            timestamp: existing.timestamp,
            isSentByMe: existing.isSentByMe,
            isRead: existing.isRead,
            isPending: false,
            isFailed: true,
            isSystem: existing.isSystem,
          );
          // Queue for automatic retry when connection is restored
          if (!widget.isSupport) {
            ChatSocketService().queueFailedMessage(widget.chatId, tempId, trimmed);
          }
        }
      });
      _cacheMessages();
      HapticFeedback.mediumImpact();
    } finally {
      _hasPendingSend = false;
    }
  }

  Future<void> _retrySendMessage(ChatMessage message) async {
    if (!message.isSentByMe || !message.isFailed) return;

    final index = _messages.indexWhere((m) => m.id == message.id);
    if (index == -1) return;

    // Remove from queue since we're manually retrying
    ChatSocketService().removeFromQueue(message.id);

    setState(() {
      _messages[index] = ChatMessage(
        id: message.id,
        text: message.text,
        timestamp: message.timestamp,
        isSentByMe: message.isSentByMe,
        isRead: message.isRead,
        isPending: true,
        isFailed: false,
        isSystem: message.isSystem,
      );
    });

    _scrollToBottom();

    try {
      final sent = await _chatService.sendMessage(widget.chatId, message.text);
      if (!mounted || sent == null) return;

      final newIndex = _messages.indexWhere((m) => m.id == message.id);
      if (newIndex != -1) {
        final updated = ChatMessage(
          id: sent.id,
          text: sent.text,
          timestamp: sent.sentAt,
          isSentByMe: true,
          isRead: false,
          isPending: false,
          isFailed: false,
          isSystem: false,
        );

        setState(() {
          _messages[newIndex] = updated;
        });
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        final index = _messages.indexWhere((m) => m.id == message.id);
        if (index != -1) {
          final existing = _messages[index];
          _messages[index] = ChatMessage(
            id: existing.id,
            text: existing.text,
            timestamp: existing.timestamp,
            isSentByMe: existing.isSentByMe,
            isRead: existing.isRead,
            isPending: false,
            isFailed: true,
            isSystem: existing.isSystem,
          );
        }
      });
      HapticFeedback.mediumImpact();
    }
  }

  void _scrollToBottom({bool force = false}) {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    final isNearBottom = (position.maxScrollExtent - position.pixels) < 100;

    if (!force && !isNearBottom) return;

    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _handleScrollPositionChanged() {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    final isNearBottom = (position.maxScrollExtent - position.pixels) < 100;
    final isNearTop = position.pixels < 100;

    // Load more messages when scrolling near the top
    if (isNearTop && _hasMoreMessages && !_isLoadingMore && !widget.isSupport) {
      _loadMoreMessages();
    }

    if (isNearBottom) {
      if (_showScrollToBottomButton || _pendingNewMessages != 0) {
        setState(() {
          _showScrollToBottomButton = false;
          _pendingNewMessages = 0;
        });
      }
    } else {
      if (!_showScrollToBottomButton) {
        setState(() {
          _showScrollToBottomButton = true;
        });
      }
    }
  }

  Future<void> _loadMoreMessages() async {
    if (_isLoadingMore || !_hasMoreMessages || _messages.isEmpty) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final oldestMessageId = _messages.first.id;
      final chatDetail = await _chatService.getChat(widget.chatId, limit: 50, beforeMessageId: oldestMessageId);

      if (!mounted || chatDetail == null) return;

      final currentUserId = _currentUserId;
      String? otherUserId;
      if (currentUserId != null) {
        if (chatDetail.customerId == currentUserId) {
          otherUserId = chatDetail.riderId;
        } else if (chatDetail.riderId == currentUserId) {
          otherUserId = chatDetail.customerId;
        }
      }

      final olderMessages = chatDetail.messages.map((m) {
        final isSentByMe = currentUserId != null && m.senderId == currentUserId;
        bool isReadByOther = false;
        if (isSentByMe && otherUserId != null) {
          isReadByOther = m.readBy.contains(otherUserId);
        }

        return ChatMessage(id: m.id, text: m.text, timestamp: m.sentAt, isSentByMe: isSentByMe, isRead: isReadByOther);
      }).toList();

      if (olderMessages.isNotEmpty) {
        // Remember scroll position before adding messages
        final scrollOffset = _scrollController.position.pixels;
        final oldMaxExtent = _scrollController.position.maxScrollExtent;

        setState(() {
          _messages = [...olderMessages, ..._messages];
          _hasMoreMessages = chatDetail.pagination?.hasMore ?? false;
        });

        // Restore scroll position after messages are added
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_scrollController.hasClients) return;
          final newMaxExtent = _scrollController.position.maxScrollExtent;
          final addedHeight = newMaxExtent - oldMaxExtent;
          _scrollController.jumpTo(scrollOffset + addedHeight);
        });

        _cacheMessages();
      } else {
        setState(() {
          _hasMoreMessages = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading more messages: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  String _formatMessageTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return DateFormat('hh:mm a').format(timestamp);
    } else if (difference.inDays < 1) {
      return DateFormat('hh:mm a').format(timestamp);
    } else {
      return DateFormat('MMM dd, hh:mm a').format(timestamp);
    }
  }

  String _formatReadTime(DateTime readAt) {
    final now = DateTime.now();
    final timePart = DateFormat('h:mm a').format(readAt);

    if (now.difference(readAt).inMinutes < 1) {
      return 'just now';
    }

    if (DateUtils.isSameDay(now, readAt)) {
      return 'at $timePart';
    }

    final yesterday = now.subtract(const Duration(days: 1));
    if (DateUtils.isSameDay(yesterday, readAt)) {
      return 'yesterday at $timePart';
    }

    return 'on ${DateFormat('MMM d').format(readAt)} at $timePart';
  }

  String _formatLastSeenText(DateTime timestamp) {
    final now = DateTime.now();
    final timePart = DateFormat('hh:mm a').format(timestamp);

    if (now.difference(timestamp).inMinutes < 1) {
      return 'Last seen just now';
    }

    if (DateUtils.isSameDay(now, timestamp)) {
      return 'Last seen today at $timePart';
    }

    if (DateUtils.isSameDay(now.subtract(const Duration(days: 1)), timestamp)) {
      return 'Last seen yesterday at $timePart';
    }

    final dayPart = DateFormat('MMM dd').format(timestamp);
    return 'Last seen $dayPart at $timePart';
  }

  bool _shouldShowDateDivider(int index) {
    if (index == 0) return true;
    final currentDate = _messages[index].timestamp;
    final previousDate = _messages[index - 1].timestamp;
    return !DateUtils.isSameDay(currentDate, previousDate);
  }

  Future<void> _syncOrderStatusSystemMessage() async {
    final id = _orderId ?? widget.orderId;
    if (id == null || id.isEmpty) return;

    try {
      final order = await _orderService.getOrder(id);
      final status = order['status']?.toString();
      if (status == null || status.isEmpty) return;
      final text = _buildOrderStatusSystemText(status);
      if (text == null || text.isEmpty) return;

      // Avoid spamming: if we already have a system message with this text
      // and the cached status matches, skip creating another chip.
      final lastStatus = CacheService.getOrderLastStatus(id);
      final hasExistingForStatus = _messages.any((m) => m.isSystem && m.text == text);
      if (lastStatus == status && hasExistingForStatus) {
        return;
      }

      await CacheService.saveOrderLastStatus(id, status);

      final systemMessage = ChatMessage(
        id: 'system_${id}_${status}_${DateTime.now().millisecondsSinceEpoch}',
        text: text,
        timestamp: DateTime.now(),
        isSentByMe: false,
        isRead: true,
        isPending: false,
        isFailed: false,
        isSystem: true,
      );

      if (!mounted) return;
      setState(() {
        _messages.add(systemMessage);
      });

      _cacheMessages();
      _scrollToBottom(force: true);
    } catch (_) {
      // Ignore errors; system messages are best-effort only.
    }
  }

  String? _buildOrderStatusSystemText(String status) {
    switch (status) {
      case 'pending':
        return 'Your order has been placed.';
      case 'confirmed':
        return 'Restaurant confirmed your order.';
      case 'preparing':
        return 'Restaurant is preparing your order.';
      case 'ready':
        return 'Your order is ready for pickup.';
      case 'picked_up':
        return 'Your rider has picked up your order.';
      case 'on_the_way':
        return 'Your order is on the way.';
      case 'delivered':
        return 'Your order has been delivered.';
      case 'cancelled':
        return 'Your order was cancelled.';
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.sizeOf(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: colors.backgroundPrimary,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: colors.backgroundSecondary,
        appBar: AppBar(
          backgroundColor: colors.backgroundPrimary,
          elevation: 0,
          leading: IconButton(
            icon: SvgPicture.asset(
              Assets.icons.navArrowLeft,
              package: 'grab_go_shared',
              width: 24.w,
              height: 24.w,
              colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
            ),
            onPressed: () => context.pop(),
          ),
          title: Row(
            children: [
              Stack(
                children: [
                  Container(
                    width: 40.w,
                    height: 40.w,
                    decoration: BoxDecoration(
                      color: widget.isSupport
                          ? colors.accentViolet.withValues(alpha: 0.1)
                          : colors.accentOrange.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: SvgPicture.asset(
                        widget.isSupport ? Assets.icons.headsetHelp : Assets.icons.user,
                        package: 'grab_go_shared',
                        width: 20.w,
                        height: 20.w,
                        colorFilter: ColorFilter.mode(
                          widget.isSupport ? colors.accentViolet : colors.accentOrange,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 12.w,
                      height: 12.w,
                      decoration: BoxDecoration(
                        color: colors.accentOrange,
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.backgroundPrimary, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.senderName,
                      style: TextStyle(color: colors.textPrimary, fontSize: 16.sp, fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_isPeerTyping)
                      Text(
                        'Typing...',
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w400,
                          fontStyle: FontStyle.italic,
                        ),
                      )
                    else if (_isPeerOnline)
                      Text(
                        'Online',
                        style: TextStyle(color: colors.textSecondary, fontSize: 12.sp, fontWeight: FontWeight.w400),
                      )
                    else if (_peerLastSeenAt != null)
                      Text(
                        _formatLastSeenText(_peerLastSeenAt!),
                        style: TextStyle(color: colors.textSecondary, fontSize: 12.sp, fontWeight: FontWeight.w400),
                      ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: SvgPicture.asset(
                Assets.icons.phone,
                package: 'grab_go_shared',
                width: 22.w,
                height: 22.w,
                colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
              ),
              onPressed: () {},
            ),
            SizedBox(width: 8.w),
          ],
        ),
        body: Column(
          children: [
            if (!widget.isSupport && (_orderId ?? widget.orderId) != null) _buildOrderSummary(colors),

            Expanded(
              child: Stack(
                children: [
                  _error != null
                      ? _buildErrorState(colors)
                      : ListView.builder(
                          controller: _scrollController,
                          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
                          physics: const BouncingScrollPhysics(),
                          itemCount: _messages.length + (_isLoadingMore ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (_isLoadingMore && index == 0) {
                              return Padding(
                                padding: EdgeInsets.symmetric(vertical: 16.h),
                                child: Center(
                                  child: SizedBox(
                                    width: 24.w,
                                    height: 24.w,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(colors.accentOrange),
                                    ),
                                  ),
                                ),
                              );
                            }

                            final messageIndex = _isLoadingMore ? index - 1 : index;
                            final message = _messages[messageIndex];
                            final previous = messageIndex > 0 ? _messages[messageIndex - 1] : null;
                            final next = messageIndex < _messages.length - 1 ? _messages[messageIndex + 1] : null;
                            final showDateDivider = _shouldShowDateDivider(messageIndex);
                            final isFirstUnreadMessage = _firstUnreadIndex != null && messageIndex == _firstUnreadIndex;

                            if (message.isSystem) {
                              final content = Column(
                                children: [
                                  if (showDateDivider)
                                    Padding(
                                      padding: EdgeInsets.symmetric(vertical: 16.h),
                                      child: Center(
                                        child: Container(
                                          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                                          decoration: BoxDecoration(
                                            color: colors.backgroundPrimary,
                                            borderRadius: BorderRadius.circular(KBorderSize.borderRadius12),
                                            border: Border.all(color: colors.border, width: 1),
                                          ),
                                          child: Text(
                                            DateFormat('MMM dd, yyyy').format(message.timestamp),
                                            style: TextStyle(
                                              color: colors.textSecondary,
                                              fontSize: 11.sp,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (isFirstUnreadMessage)
                                    Padding(
                                      padding: EdgeInsets.only(bottom: 8.h),
                                      child: Center(
                                        child: Container(
                                          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                                          decoration: BoxDecoration(
                                            color: colors.accentOrange.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            'New messages',
                                            style: TextStyle(
                                              color: colors.accentOrange,
                                              fontSize: 11.sp,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  Padding(
                                    padding: EdgeInsets.symmetric(vertical: 8.h),
                                    child: Center(
                                      child: Container(
                                        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                                        decoration: BoxDecoration(
                                          color: colors.backgroundPrimary,
                                          borderRadius: BorderRadius.circular(999),
                                          border: Border.all(color: colors.border, width: 1),
                                        ),
                                        child: Text(
                                          message.text,
                                          style: TextStyle(
                                            color: colors.textSecondary,
                                            fontSize: 11.sp,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );

                              if (isFirstUnreadMessage) {
                                return KeyedSubtree(key: _firstUnreadKey, child: content);
                              }

                              return content;
                            }

                            final sameDayAsPrevious =
                                previous != null && DateUtils.isSameDay(previous.timestamp, message.timestamp);
                            final sameDayAsNext =
                                next != null && DateUtils.isSameDay(next.timestamp, message.timestamp);

                            final isFirstInGroup =
                                previous == null ||
                                !sameDayAsPrevious ||
                                previous.isSentByMe != message.isSentByMe ||
                                (previous.isSystem != message.isSystem);
                            final isLastInGroup =
                                next == null ||
                                !sameDayAsNext ||
                                next.isSentByMe != message.isSentByMe ||
                                (next.isSystem != message.isSystem);

                            final content = Column(
                              children: [
                                if (showDateDivider)
                                  Padding(
                                    padding: EdgeInsets.symmetric(vertical: 16.h),
                                    child: Center(
                                      child: Container(
                                        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                                        decoration: BoxDecoration(
                                          color: colors.backgroundPrimary,
                                          borderRadius: BorderRadius.circular(KBorderSize.borderRadius12),
                                          border: Border.all(color: colors.border, width: 1),
                                        ),
                                        child: Text(
                                          DateFormat('MMM dd, yyyy').format(message.timestamp),
                                          style: TextStyle(
                                            color: colors.textSecondary,
                                            fontSize: 11.sp,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                if (isFirstUnreadMessage)
                                  Padding(
                                    padding: EdgeInsets.only(bottom: 8.h),
                                    child: Center(
                                      child: Container(
                                        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                                        decoration: BoxDecoration(
                                          color: colors.accentOrange.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          'New messages',
                                          style: TextStyle(
                                            color: colors.accentOrange,
                                            fontSize: 11.sp,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                _buildMessageBubble(
                                  message,
                                  colors,
                                  size,
                                  isFirstInGroup: isFirstInGroup,
                                  isLastInGroup: isLastInGroup,
                                ),
                                SizedBox(height: isLastInGroup ? 8.h : 4.h),
                              ],
                            );

                            if (isFirstUnreadMessage) {
                              return KeyedSubtree(key: _firstUnreadKey, child: content);
                            }

                            return content;
                          },
                        ),
                  if (_showScrollToBottomButton)
                    Positioned(right: 16.w, bottom: 16.h, child: _buildScrollToBottomButton(colors)),
                ],
              ),
            ),

            if (!widget.isSupport && _quickIssueTemplates.isNotEmpty) _buildQuickIssueChips(colors),

            // Reply preview
            if (_replyingTo != null) _buildReplyPreview(colors),

            Container(
              padding: EdgeInsets.only(
                left: 20.w,
                right: 20.w,
                top: 12.h,
                bottom: MediaQuery.of(context).padding.bottom + 12.h,
              ),
              decoration: BoxDecoration(
                color: colors.backgroundPrimary,
                border: Border(top: BorderSide(color: colors.border, width: 1)),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(KBorderSize.borderRadius4),
                  topRight: Radius.circular(KBorderSize.borderRadius4),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      constraints: BoxConstraints(maxHeight: 120.h),
                      decoration: BoxDecoration(
                        color: colors.backgroundSecondary,
                        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                        border: Border.all(color: colors.border, width: 1),
                      ),
                      child: TextField(
                        controller: _messageController,
                        focusNode: _messageFocusNode,
                        maxLines: null,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: "Type a message...",
                          hintStyle: TextStyle(color: colors.textSecondary.withValues(alpha: 0.6), fontSize: 14.sp),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                        ),
                        style: TextStyle(color: colors.textPrimary, fontSize: 14.sp),
                        onChanged: _handleMessageChanged,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  GestureDetector(
                    onTap: _sendMessage,
                    child: Container(
                      width: 48.w,
                      height: 48.w,
                      decoration: BoxDecoration(
                        color: colors.accentOrange,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: colors.accentOrange.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: SvgPicture.asset(
                          Assets.icons.sendDiagonal,
                          package: 'grab_go_shared',
                          width: 20.w,
                          height: 20.w,
                          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScrollToBottomButton(AppColorsExtension colors) {
    final hasCount = _pendingNewMessages > 0;

    return GestureDetector(
      onTap: () {
        _scrollToBottom(force: true);
        setState(() {
          _showScrollToBottomButton = false;
          _pendingNewMessages = 0;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: colors.backgroundPrimary,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 6, offset: const Offset(0, 2))],
          border: Border.all(color: colors.border, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              Assets.icons.fastArrowDown,
              package: "grab_go_shared",
              height: 18.h,
              width: 18.w,
              colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
            ),
            if (hasCount) ...[
              SizedBox(width: 6.w),
              Text(
                _pendingNewMessages.toString(),
                style: TextStyle(color: colors.textPrimary, fontSize: 12.sp, fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummary(AppColorsExtension colors) {
    final id = _orderId ?? widget.orderId;
    if (id == null || id.isEmpty) {
      return const SizedBox.shrink();
    }

    final display = (_orderNumber != null && _orderNumber!.isNotEmpty)
        ? _orderNumber!
        : (id.length > 8 ? id.substring(0, 8) : id);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
        border: Border.all(color: colors.border, width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.r),
            decoration: BoxDecoration(
              color: colors.accentOrange.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
            ),
            child: SvgPicture.asset(
              Assets.icons.deliveryTruck,
              package: 'grab_go_shared',
              width: 20.w,
              height: 20.w,
              colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order $display',
                  style: TextStyle(color: colors.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 2.h),
                Text(
                  'Linked to this chat',
                  style: TextStyle(color: colors.textSecondary, fontSize: 12.sp, fontWeight: FontWeight.w400),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _openOrderTracking,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: colors.accentOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(KBorderSize.borderRadius20),
              ),
              child: Row(
                children: [
                  SvgPicture.asset(
                    Assets.icons.mapPin,
                    package: 'grab_go_shared',
                    width: 16.w,
                    height: 16.w,
                    colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    'Track',
                    style: TextStyle(color: colors.accentOrange, fontSize: 12.sp, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyPreview(AppColorsExtension colors) {
    final replyTo = _replyingTo;
    if (replyTo == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        border: Border(top: BorderSide(color: colors.border, width: 1)),
      ),
      child: Row(
        children: [
          Container(
            width: 4.w,
            height: 40.h,
            decoration: BoxDecoration(color: colors.accentOrange, borderRadius: BorderRadius.circular(2.w)),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  replyTo.isSentByMe ? 'You' : widget.senderName,
                  style: TextStyle(color: colors.accentOrange, fontSize: 12.sp, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 2.h),
                Text(
                  replyTo.text,
                  style: TextStyle(color: colors.textSecondary, fontSize: 13.sp, fontWeight: FontWeight.w400),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          GestureDetector(
            onTap: _cancelReply,
            child: Container(
              padding: EdgeInsets.all(4.w),
              child: Icon(Icons.close, size: 20.w, color: colors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickIssueChips(AppColorsExtension colors) {
    final templates = _getQuickIssueTemplates();
    if (templates.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      color: colors.backgroundPrimary,
      padding: EdgeInsets.only(left: 20.w, right: 20.w, top: 8.h, bottom: 4.h),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: templates
              .map(
                (text) => Padding(
                  padding: EdgeInsets.only(right: 8.w),
                  child: ActionChip(
                    label: Text(
                      text,
                      style: TextStyle(color: colors.textPrimary, fontSize: 12.sp, fontWeight: FontWeight.w400),
                    ),
                    backgroundColor: colors.backgroundSecondary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(KBorderSize.borderRadius20),
                      side: BorderSide(color: colors.border, width: 1),
                    ),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      _sendQuickMessage(text);
                    },
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  List<String> _getQuickIssueTemplates() {
    if (widget.isSupport) return const [];

    final id = _orderId ?? widget.orderId;
    if (id == null || id.isEmpty) return _quickIssueTemplates;

    final status = CacheService.getOrderLastStatus(id);
    if (status == null || status.isEmpty) {
      return _quickIssueTemplates;
    }

    switch (status) {
      case 'pending':
      case 'confirmed':
      case 'preparing':
        return [
          'Where is my order right now? ',
          'Can you give me an updated ETA? ',
          'I want to update my delivery instructions.',
        ];
      case 'ready':
        return [
          'Is my order still ready for pickup? ',
          'Can you call me when you arrive? ',
          'Can you come to the main gate? ',
        ];
      case 'picked_up':
      case 'on_the_way':
        return ['Please call me when you arrive.', 'Can you come to the main gate?', 'Where is my order right now?'];
      case 'delivered':
        return ['Thank you!', 'There is an issue with my order.'];
      case 'cancelled':
        return ['Why was my order cancelled?', 'Can I place the order again?'];
      default:
        return _quickIssueTemplates;
    }
  }

  void _openOrderTracking() {
    final id = _orderId ?? widget.orderId;
    if (id == null || id.isEmpty) return;

    context.push('/orderTracking');
  }

  Widget _buildMessageBubble(
    ChatMessage message,
    AppColorsExtension colors,
    Size size, {
    required bool isFirstInGroup,
    required bool isLastInGroup,
  }) {
    final isSent = message.isSentByMe;
    final canRetry = isSent && message.isFailed;

    final radiusBig = const Radius.circular(KBorderSize.borderRadius12);
    const radiusSmall = Radius.circular(4);

    final topLeft = isSent ? (isFirstInGroup ? radiusSmall : radiusBig) : (isFirstInGroup ? radiusBig : radiusSmall);
    final topRight = isSent ? (isFirstInGroup ? radiusBig : radiusBig) : (isFirstInGroup ? radiusSmall : radiusBig);
    final bottomLeft = isSent ? (isLastInGroup ? radiusBig : radiusBig) : (isLastInGroup ? radiusSmall : radiusBig);
    final bottomRight = isSent ? (isLastInGroup ? radiusSmall : radiusBig) : (isLastInGroup ? radiusBig : radiusSmall);

    final statusText = isSent
        ? (message.isPending
              ? 'Sending…'
              : message.isFailed
              ? 'Failed. Tap to retry.'
              : message.isRead
              ? (message.readAt != null ? 'Seen ${_formatReadTime(message.readAt!)}' : 'Seen')
              : 'Sent')
        : null;

    final bubble = Align(
      alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: size.width * 0.75),
        child: Column(
          crossAxisAlignment: isSent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: isSent ? colors.accentOrange : colors.backgroundPrimary,
                borderRadius: BorderRadius.only(
                  topLeft: topLeft,
                  topRight: topRight,
                  bottomLeft: bottomLeft,
                  bottomRight: bottomRight,
                ),
                border: isSent ? null : Border.all(color: colors.border, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Reply preview in bubble
                  if (message.replyToId != null && message.replyToText != null)
                    Container(
                      margin: EdgeInsets.only(bottom: 8.h),
                      padding: EdgeInsets.all(8.w),
                      decoration: BoxDecoration(
                        color: isSent
                            ? Colors.white.withValues(alpha: 0.15)
                            : colors.accentOrange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8.w),
                        border: Border(
                          left: BorderSide(
                            color: isSent ? Colors.white.withValues(alpha: 0.5) : colors.accentOrange,
                            width: 3.w,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            message.replyToIsSentByMe == true ? 'You' : widget.senderName,
                            style: TextStyle(
                              color: isSent ? Colors.white.withValues(alpha: 0.9) : colors.accentOrange,
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            message.replyToText!,
                            style: TextStyle(
                              color: isSent ? Colors.white.withValues(alpha: 0.7) : colors.textSecondary,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w400,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  Text(
                    message.text,
                    style: TextStyle(
                      color: isSent ? Colors.white : colors.textPrimary,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
            if (isLastInGroup) ...[
              SizedBox(height: 4.h),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _formatMessageTime(message.timestamp),
                    style: TextStyle(color: colors.textSecondary, fontSize: 11.sp, fontWeight: FontWeight.w400),
                  ),
                  if (isSent) ...[
                    SizedBox(width: 4.w),
                    if (message.isPending)
                      SizedBox(
                        width: 12.w,
                        height: 12.w,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(colors.textSecondary),
                        ),
                      )
                    else if (message.isFailed)
                      SvgPicture.asset(
                        Assets.icons.warningCircle,
                        package: "grab_go_shared",
                        height: 14.h,
                        width: 14.w,
                        colorFilter: ColorFilter.mode(colors.error, BlendMode.srcIn),
                      )
                    else
                      Icon(
                        message.isRead ? Icons.done_all : Icons.done,
                        size: 14.w,
                        color: message.isRead ? colors.accentOrange : colors.textSecondary,
                      ),
                    if (statusText != null) ...[
                      SizedBox(width: 4.w),
                      Text(
                        statusText,
                        style: TextStyle(color: colors.textSecondary, fontSize: 11.sp, fontWeight: FontWeight.w400),
                      ),
                    ],
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );

    final canSwipeToReply = !message.isSystem && !widget.isSupport && !message.isPending;

    if (canSwipeToReply) {
      return _SwipeToReply(
        onSwipe: () => _setReplyingTo(message),
        isSentByMe: isSent,
        child: GestureDetector(
          onTap: canRetry ? () => _retrySendMessage(message) : null,
          onLongPress: () => _showMessageActions(message, colors),
          behavior: HitTestBehavior.translucent,
          child: bubble,
        ),
      );
    }

    return GestureDetector(
      onTap: canRetry ? () => _retrySendMessage(message) : null,
      onLongPress: () => _showMessageActions(message, colors),
      behavior: HitTestBehavior.translucent,
      child: bubble,
    );
  }

  void _setReplyingTo(ChatMessage message) {
    setState(() {
      _replyingTo = message;
    });
    _messageFocusNode.requestFocus();
    HapticFeedback.selectionClick();
  }

  void _cancelReply() {
    setState(() {
      _replyingTo = null;
    });
  }

  void _showMessageActions(ChatMessage message, AppColorsExtension colors) {
    HapticFeedback.selectionClick();

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.backgroundPrimary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(KBorderSize.borderRadius12)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: SvgPicture.asset(
                  Assets.icons.edit,
                  package: "grab_go_shared",
                  height: 20.h,
                  width: 20.w,
                  colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
                ),
                title: Text(
                  'Copy',
                  style: TextStyle(color: colors.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w500),
                ),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: message.text));
                  Navigator.of(context).pop();
                },
              ),
              if (message.isSentByMe && message.isFailed)
                ListTile(
                  leading: SvgPicture.asset(
                    Assets.icons.refresh,
                    package: "grab_go_shared",
                    height: 20.h,
                    width: 20.w,
                    colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
                  ),
                  title: Text(
                    'Resend',
                    style: TextStyle(color: colors.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w500),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    _retrySendMessage(message);
                  },
                ),
              if (message.isSentByMe && !message.isPending && !widget.isSupport)
                ListTile(
                  leading: SvgPicture.asset(
                    Assets.icons.binMinusIn,
                    package: "grab_go_shared",
                    height: 20.h,
                    width: 20.w,
                    colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
                  ),
                  title: Text(
                    'Delete for everyone',
                    style: TextStyle(color: colors.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w500),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    _deleteMessageForEveryone(message);
                  },
                ),
              ListTile(
                leading: SvgPicture.asset(
                  Assets.icons.binMinusIn,
                  package: "grab_go_shared",
                  height: 20.h,
                  width: 20.w,
                  colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
                ),
                title: Text(
                  'Delete for me',
                  style: TextStyle(color: colors.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w500),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  _deleteMessageLocally(message);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _deleteMessageLocally(ChatMessage message) {
    setState(() {
      _messages.removeWhere((m) => m.id == message.id);
    });
    _cacheMessages();
  }

  Future<void> _deleteMessageForEveryone(ChatMessage message) async {
    // Optimistically remove from UI
    setState(() {
      _messages.removeWhere((m) => m.id == message.id);
    });
    _cacheMessages();

    // Also remove from queue if it was a failed message
    ChatSocketService().removeFromQueue(message.id);

    // Call backend to delete
    final success = await _chatService.deleteMessage(widget.chatId, message.id);

    if (!success && mounted) {
      // If delete failed, show error (message is already removed from UI)
      AppToastMessage.show(context: context, icon: Icons.error_outline, message: "Failed to delete message");
    }
  }

  Widget _buildErrorState(AppColorsExtension colors) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(40.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Unable to load messages',
              style: TextStyle(color: colors.textPrimary, fontSize: 18.sp, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8.h),
            Text(
              _error ?? 'Please check your connection and try again.',
              style: TextStyle(color: colors.textSecondary, fontSize: 14.sp, fontWeight: FontWeight.w400),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16.h),
            SizedBox(
              height: 40.h,
              child: AppButton(onPressed: _initAndLoadMessages, buttonText: 'Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Swipe-to-reply widget for message bubbles
class _SwipeToReply extends StatefulWidget {
  final Widget child;
  final VoidCallback onSwipe;
  final bool isSentByMe;

  const _SwipeToReply({required this.child, required this.onSwipe, required this.isSentByMe});

  @override
  State<_SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<_SwipeToReply> {
  double _dragExtent = 0;
  static const double _swipeThreshold = 60.0;
  bool _hasTriggered = false;

  void _handleDragUpdate(DragUpdateDetails details) {
    // For sent messages (right side), swipe left (negative)
    // For received messages (left side), swipe right (positive)
    final delta = details.primaryDelta ?? 0;

    if (widget.isSentByMe) {
      // Sent messages: only allow swipe left (negative delta)
      _dragExtent = (_dragExtent + delta).clamp(-_swipeThreshold * 1.5, 0);
    } else {
      // Received messages: only allow swipe right (positive delta)
      _dragExtent = (_dragExtent + delta).clamp(0, _swipeThreshold * 1.5);
    }

    setState(() {});

    // Trigger haptic when threshold is reached
    if (_dragExtent.abs() >= _swipeThreshold && !_hasTriggered) {
      _hasTriggered = true;
      HapticFeedback.mediumImpact();
    } else if (_dragExtent.abs() < _swipeThreshold) {
      _hasTriggered = false;
    }
  }

  void _handleDragEnd(DragEndDetails details) {
    if (_dragExtent.abs() >= _swipeThreshold) {
      widget.onSwipe();
    }

    // Animate back to original position
    _dragExtent = 0;
    _hasTriggered = false;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColorsExtension>()!;
    final progress = (_dragExtent.abs() / _swipeThreshold).clamp(0.0, 1.0);

    return GestureDetector(
      onHorizontalDragUpdate: _handleDragUpdate,
      onHorizontalDragEnd: _handleDragEnd,
      child: Stack(
        alignment: widget.isSentByMe ? Alignment.centerRight : Alignment.centerLeft,
        children: [
          // Reply icon that appears during swipe
          Positioned(
            left: widget.isSentByMe ? null : 8.w,
            right: widget.isSentByMe ? 8.w : null,
            child: Opacity(
              opacity: progress,
              child: Transform.scale(
                scale: 0.5 + (progress * 0.5),
                child: Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(color: colors.accentOrange.withValues(alpha: 0.2), shape: BoxShape.circle),
                  child: Icon(Icons.reply, size: 20.w, color: colors.accentOrange),
                ),
              ),
            ),
          ),
          // The message bubble
          Transform.translate(offset: Offset(_dragExtent, 0), child: widget.child),
        ],
      ),
    );
  }
}
