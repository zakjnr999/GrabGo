import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_rider/features/chat/service/chat_service.dart';
import 'package:grab_go_rider/shared/service/user_service.dart';
import 'package:grab_go_rider/shared/service/chat_socket_service.dart';
import 'package:grab_go_rider/shared/service/cache_service.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class ChatMessage {
  final String id;
  final MessageType messageType;
  final String text;
  final String? audioUrl;
  final double audioDuration;
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
    this.messageType = MessageType.text,
    required this.text,
    this.audioUrl,
    this.audioDuration = 0,
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

  bool get isVoiceMessage => messageType == MessageType.voice;
  bool get isImageMessage => messageType == MessageType.image;
  bool get isTextMessage => messageType == MessageType.text;
}

class ChatDetailPage extends StatefulWidget {
  final String chatId;
  final String senderName;
  final String? orderId;
  final bool isSupport;

  const ChatDetailPage({
    super.key,
    required this.chatId,
    required this.senderName,
    this.orderId,
    this.isSupport = false,
  });

  @override
  State<ChatDetailPage> createState() => _ChatDetailPageState();
}

class _ChatDetailPageState extends State<ChatDetailPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();
  List<ChatMessage> _messages = [];
  final ChatService _chatService = ChatService();
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
  ChatSocketConnectionState _connectionState = ChatSocketConnectionState.disconnected;
  String? _orderId;
  String? _orderNumber;
  String? _currentOrderStatus;
  int? _firstUnreadIndex;
  bool _showScrollToBottomButton = false;
  int _pendingNewMessages = 0;
  final GlobalKey _firstUnreadKey = GlobalKey();
  final List<String> _quickIssueTemplates = const [
    "I'm at your location, please come outside.",
    'Restaurant is delaying your order a bit.',
    "I'm having trouble finding your address, please share a nearby landmark.",
    'One item is unavailable, can we replace it?',
  ];
  DateTime? _peerLastSeenAt;
  ChatMessage? _replyingTo;

  // Pagination state
  bool _hasMoreMessages = false;
  bool _isLoadingMore = false;

  // Voice recording state
  final VoiceRecorderService _voiceRecorder = VoiceRecorderService();
  bool _isRecording = false;
  Duration _recordingDuration = Duration.zero;

  void _loadCachedMessages() {
    final cached = CacheService.getChatMessages(widget.chatId);
    if (cached.isEmpty) return;

    final messages = cached
        .map((m) {
          final id = m['id']?.toString() ?? '';
          if (id.isEmpty) return null;

          final messageTypeStr = m['messageType']?.toString();
          final messageType = MessageType.fromString(messageTypeStr);
          final text = m['text']?.toString() ?? '';
          final audioUrl = m['audioUrl']?.toString();
          final audioDuration = (m['audioDuration'] as num?)?.toDouble() ?? 0;
          final tsStr = m['timestamp']?.toString();
          final timestamp = DateTime.tryParse(tsStr ?? '') ?? DateTime.now();
          final isSentByMe = m['isSentByMe'] == true;
          final isRead = m['isRead'] == true;
          final isSystem = m['isSystem'] == true;
          final replyToId = m['replyToId']?.toString();
          final replyToText = m['replyToText']?.toString();
          final replyToIsSentByMe = m['replyToIsSentByMe'] == true
              ? true
              : (m['replyToIsSentByMe'] == false ? false : null);

          return ChatMessage(
            id: id,
            messageType: messageType,
            text: text,
            audioUrl: audioUrl,
            audioDuration: audioDuration,
            timestamp: timestamp,
            isSentByMe: isSentByMe,
            isRead: isRead,
            isSystem: isSystem,
            replyToId: replyToId,
            replyToText: replyToText,
            replyToIsSentByMe: replyToIsSentByMe,
          );
        })
        .whereType<ChatMessage>()
        .toList();

    if (messages.isEmpty) return;

    int? firstUnreadIndex;
    final lastSeen = CacheService.getChatLastSeen(widget.chatId);
    if (lastSeen != null) {
      for (var i = 0; i < messages.length; i++) {
        // Only show "new messages" chip for messages from others, not your own
        if (!messages[i].isSentByMe && messages[i].timestamp.isAfter(lastSeen)) {
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
        // Jump immediately to bottom, then ensure we're at the actual bottom after layout
        _scrollToBottom(force: true, immediate: true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _scrollToBottom(force: true, immediate: true);
        });
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
            'messageType': m.messageType.name,
            'text': m.text,
            if (m.audioUrl != null) 'audioUrl': m.audioUrl,
            'audioDuration': m.audioDuration,
            'timestamp': m.timestamp.toIso8601String(),
            'isSentByMe': m.isSentByMe,
            'isRead': m.isRead,
            'isSystem': m.isSystem,
            if (m.replyToId != null) 'replyToId': m.replyToId,
            if (m.replyToText != null) 'replyToText': m.replyToText,
            if (m.replyToIsSentByMe != null) 'replyToIsSentByMe': m.replyToIsSentByMe,
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
    final chatSocket = ChatSocketService();
    chatSocket.addConnectionListener(_handleConnectionStateChanged);
    if (!widget.isSupport) {
      chatSocket.addNewMessageListener(_handleIncomingSocketMessage);
      chatSocket.addPresenceListener(_handlePresenceEvent);
      chatSocket.addTypingListener(_handleTypingEvent);
      chatSocket.addReadListener(_handleReadEvent);
      chatSocket.addRetryListener(_handleQueuedMessageRetry);
      chatSocket.addDeleteListener(_handleMessageDeleted);
      // Force rejoin to get fresh presence status of the other participant
      chatSocket.joinChat(widget.chatId, forceRejoin: true);
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

    final chatSocket = ChatSocketService();
    chatSocket.removeConnectionListener(_handleConnectionStateChanged);
    if (!widget.isSupport) {
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
      _currentUserId = _userService.currentUser?.id;
      final chatDetail = await _chatService.getChat(widget.chatId);

      if (!mounted) return;

      if (chatDetail == null) {
        // Only show error if we have no cached messages
        if (_messages.isEmpty) {
          setState(() {
            _error = 'Unable to load conversation.';
          });
        }
        // Otherwise keep showing cached messages
        return;
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

          // Determine if the replied message was sent by current user
          bool? replyToIsSentByMe;
          if (m.replyToSenderId != null && currentUserId != null) {
            replyToIsSentByMe = m.replyToSenderId == currentUserId;
          }

          return ChatMessage(
            id: m.id,
            messageType: m.messageType,
            text: m.text ?? '',
            audioUrl: m.audioUrl,
            audioDuration: m.audioDuration,
            timestamp: m.sentAt,
            isSentByMe: isSentByMe,
            isRead: isReadByOther,
            isSystem: false,
            replyToId: m.replyToId,
            replyToText: m.replyToText,
            replyToIsSentByMe: replyToIsSentByMe,
          );
        }).toList();

        final lastSeen = CacheService.getChatLastSeen(widget.chatId);
        int? firstUnreadIndex;
        if (lastSeen != null) {
          for (var i = 0; i < loadedMessages.length; i++) {
            // Only show "new messages" chip for messages from others, not your own
            if (!loadedMessages[i].isSentByMe && loadedMessages[i].timestamp.isAfter(lastSeen)) {
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
            // Jump immediately to bottom, then ensure we're at the actual bottom after layout
            _scrollToBottom(force: true, immediate: true);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _scrollToBottom(force: true, immediate: true);
            });
          }
        });

        if (!widget.isSupport) {
          unawaited(_syncOrderStatus());
          _orderStatusTimer ??= Timer.periodic(const Duration(seconds: 30), (_) {
            _syncOrderStatus();
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      // Only show error if we have no cached messages
      if (_messages.isEmpty) {
        setState(() {
          _error = 'Failed to load messages. Please try again.';
        });
      }
      // Otherwise keep showing cached messages silently
    } finally {}
  }

  Widget _buildScrollToBottomButton(AppColorsExtension colors) {
    final hasCount = _pendingNewMessages > 0;

    return GestureDetector(
      onTap: () {
        // Jump immediately, then ensure we're at the actual bottom after layout
        _scrollToBottom(force: true, immediate: true);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _scrollToBottom(force: true, immediate: true);
        });
        // Mark messages as read when user taps to scroll to bottom
        if (_pendingNewMessages > 0 && !widget.isSupport) {
          ChatSocketService().markAsRead(widget.chatId);
        }
        setState(() {
          _showScrollToBottomButton = false;
          _pendingNewMessages = 0;
          // Don't clear _firstUnreadIndex here - keep the chip visible until user replies or leaves
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

  void _handleConnectionStateChanged(ChatSocketConnectionState state) {
    if (!mounted) return;
    setState(() {
      _connectionState = state;
    });
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
          replyToId: existing.replyToId,
          replyToText: existing.replyToText,
          replyToIsSentByMe: existing.replyToIsSentByMe,
        );
        HapticFeedback.lightImpact();
      } else {
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
          replyToId: existing.replyToId,
          replyToText: existing.replyToText,
          replyToIsSentByMe: existing.replyToIsSentByMe,
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

    _currentUserId ??= _userService.currentUser?.id;
    final senderId = messageMap['senderId']?.toString() ?? '';

    if (_currentUserId != null && senderId == _currentUserId) {
      return;
    }

    final exists = _messages.any((m) => m.id == id);
    if (exists) return;

    // Parse reply data from socket message
    final replyTo = messageMap['replyTo'] as Map<String, dynamic>?;
    String? replyToId;
    String? replyToText;
    bool? replyToIsSentByMe;
    if (replyTo != null) {
      replyToId = replyTo['id']?.toString();
      replyToText = replyTo['text']?.toString();
      final replyToSenderId = replyTo['senderId']?.toString();
      if (replyToSenderId != null && _currentUserId != null) {
        replyToIsSentByMe = replyToSenderId == _currentUserId;
      }
    }

    final msg = ChatMessage(
      id: id,
      messageType: MessageType.fromString(messageMap['messageType']?.toString()),
      text: messageMap['text']?.toString() ?? '',
      audioUrl: messageMap['audioUrl']?.toString(),
      audioDuration: (messageMap['audioDuration'] as num?)?.toDouble() ?? 0,
      timestamp: DateTime.tryParse(messageMap['sentAt']?.toString() ?? '') ?? DateTime.now(),
      isSentByMe: _currentUserId != null && senderId == _currentUserId,
      isRead: _currentUserId != null && senderId == _currentUserId,
      isSystem: false,
      replyToId: replyToId,
      replyToText: replyToText,
      replyToIsSentByMe: replyToIsSentByMe,
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

    // Only auto-scroll if user is near bottom, otherwise show the button
    if (isNearBottom) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _scrollToBottom(force: true);
      });
      // Only mark as read if user is near bottom (actually seeing the message)
      ChatSocketService().markAsRead(widget.chatId);
    }
    // If user is scrolled up, don't mark as read - they haven't seen it yet
  }

  void _handlePresenceEvent(dynamic data) {
    if (!mounted || widget.isSupport) return;
    if (data is! Map) return;

    final map = Map<String, dynamic>.from(data);
    final payloadChatId = map['chatId']?.toString();
    if (payloadChatId != widget.chatId) return;

    // Ignore our own presence events
    final eventUserId = map['userId']?.toString();
    _currentUserId ??= _userService.currentUser?.id;
    if (eventUserId == _currentUserId) return;

    final online = map['online'] == true;

    setState(() {
      _isPeerOnline = online;
      if (!online) {
        _isPeerTyping = false;
        _peerLastSeenAt = DateTime.now();
      }
    });
  }

  void _handleTypingEvent(dynamic data) {
    if (!mounted || widget.isSupport) return;
    if (data is! Map) return;

    final map = Map<String, dynamic>.from(data);
    final payloadChatId = map['chatId']?.toString();
    if (payloadChatId != widget.chatId) return;

    // Ignore our own typing events
    final eventUserId = map['userId']?.toString();
    _currentUserId ??= _userService.currentUser?.id;
    if (eventUserId == _currentUserId) return;

    final isTyping = map['isTyping'] == true;

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

    _currentUserId ??= _userService.currentUser?.id;
    final currentUserId = _currentUserId;
    if (currentUserId == null || currentUserId.isEmpty) return;

    if (readerId == currentUserId) return;

    // Parse readAt timestamp from event, or use current time
    final readAtStr = map['readAt']?.toString();
    final readAt = readAtStr != null ? DateTime.tryParse(readAtStr) : DateTime.now();

    // When the other user reads the chat, all our sent messages in this
    // conversation become "read" from our perspective.
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
                    replyToId: m.replyToId,
                    replyToText: m.replyToText,
                    replyToIsSentByMe: m.replyToIsSentByMe,
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

    final userId = _userService.currentUser?.id;
    if (userId == null || userId.isEmpty) return;

    if (!_isTyping) {
      _isTyping = true;
      ChatSocketService().setTyping(widget.chatId, true);
    }

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      if (!_isTyping) return;
      _isTyping = false;
      ChatSocketService().setTyping(widget.chatId, false);
    });
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    _typingTimer?.cancel();
    if (_isTyping) {
      final userId = _userService.currentUser?.id;
      if (userId != null && userId.isNotEmpty) {
        ChatSocketService().setTyping(widget.chatId, false);
      }
      _isTyping = false;
    }

    final text = _messageController.text.trim();
    _messageController.clear();
    unawaited(CacheService.saveChatDraft(widget.chatId, ''));

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
      isSystem: false,
      replyToId: replyTo?.id,
      replyToText: replyTo?.text,
      replyToIsSentByMe: replyTo?.isSentByMe,
    );

    setState(() {
      _messages.add(optimisticMessage);
      _firstUnreadIndex = null; // Clear "new messages" chip when user sends a reply
    });

    _cacheMessages();
    // Force scroll to show the sent message even when keyboard is up
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollToBottom(force: true);
    });

    _hasPendingSend = true;
    try {
      final sent = await _chatService.sendMessage(widget.chatId, trimmed, replyToId: replyTo?.id);
      if (!mounted || sent == null) return;

      final index = _messages.indexWhere((m) => m.id == tempId);
      if (index != -1) {
        final existing = _messages[index];
        final updated = ChatMessage(
          id: sent.id,
          messageType: sent.messageType,
          text: sent.text ?? '',
          audioUrl: sent.audioUrl,
          audioDuration: sent.audioDuration,
          timestamp: sent.sentAt,
          isSentByMe: true,
          isRead: false,
          isPending: false,
          isFailed: false,
          isSystem: false,
          replyToId: existing.replyToId,
          replyToText: existing.replyToText,
          replyToIsSentByMe: existing.replyToIsSentByMe,
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
            replyToId: existing.replyToId,
            replyToText: existing.replyToText,
            replyToIsSentByMe: existing.replyToIsSentByMe,
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
        replyToId: message.replyToId,
        replyToText: message.replyToText,
        replyToIsSentByMe: message.replyToIsSentByMe,
      );
    });

    _scrollToBottom();

    try {
      final sent = await _chatService.sendMessage(widget.chatId, message.text);
      if (!mounted || sent == null) return;

      final newIndex = _messages.indexWhere((m) => m.id == message.id);
      if (newIndex != -1) {
        final existing = _messages[newIndex];
        final updated = ChatMessage(
          id: sent.id,
          messageType: sent.messageType,
          text: sent.text ?? '',
          audioUrl: sent.audioUrl,
          audioDuration: sent.audioDuration,
          timestamp: sent.sentAt,
          isSentByMe: true,
          isRead: false,
          isPending: false,
          isFailed: false,
          isSystem: false,
          replyToId: existing.replyToId,
          replyToText: existing.replyToText,
          replyToIsSentByMe: existing.replyToIsSentByMe,
        );

        setState(() {
          _messages[newIndex] = updated;
        });
        HapticFeedback.lightImpact();
      }
    } catch (_) {
      if (!mounted) return;

      final newIndex = _messages.indexWhere((m) => m.id == message.id);
      if (newIndex != -1) {
        final existing = _messages[newIndex];
        setState(() {
          _messages[newIndex] = ChatMessage(
            id: existing.id,
            text: existing.text,
            timestamp: existing.timestamp,
            isSentByMe: existing.isSentByMe,
            isRead: existing.isRead,
            isPending: false,
            isFailed: true,
            isSystem: existing.isSystem,
            replyToId: existing.replyToId,
            replyToText: existing.replyToText,
            replyToIsSentByMe: existing.replyToIsSentByMe,
          );
        });
      }
      HapticFeedback.mediumImpact();
    }
  }

  void _scrollToBottom({bool force = false, bool immediate = false}) {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;
    final isNearBottom = (position.maxScrollExtent - position.pixels) < 100;

    if (!force && !isNearBottom) return;

    if (immediate) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    } else {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  // Voice recording methods
  Future<void> _startRecording() async {
    if (_isRecording) return;

    _voiceRecorder.onDurationChanged = (duration) {
      if (mounted) {
        setState(() {
          _recordingDuration = duration;
        });
      }
    };

    _voiceRecorder.onError = (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
        _cancelRecording();
      }
    };

    final started = await _voiceRecorder.startRecording();
    if (started && mounted) {
      setState(() {
        _isRecording = true;
        _recordingDuration = Duration.zero;
      });
      HapticFeedback.mediumImpact();
    }
  }

  Future<void> _stopAndSendRecording() async {
    if (!_isRecording) return;

    final result = await _voiceRecorder.stopRecording();
    if (result == null || !mounted) {
      _cancelRecording();
      return;
    }

    final (filePath, duration) = result;

    setState(() {
      _isRecording = false;
      _recordingDuration = Duration.zero;
    });

    if (filePath == null || filePath.isEmpty) return;

    // Don't send very short recordings (less than 1 second)
    if (duration.inMilliseconds < 1000) {
      _voiceRecorder.deleteRecording(filePath);
      return;
    }

    await _sendVoiceMessage(filePath, duration.inSeconds.toDouble());
  }

  void _cancelRecording() {
    if (!_isRecording) return;

    _voiceRecorder.cancelRecording();
    setState(() {
      _isRecording = false;
      _recordingDuration = Duration.zero;
    });
    HapticFeedback.lightImpact();
  }

  Future<void> _sendVoiceMessage(String audioPath, double duration) async {
    final tempId = DateTime.now().millisecondsSinceEpoch.toString();

    // Add optimistic message
    final optimisticMessage = ChatMessage(
      id: tempId,
      messageType: MessageType.voice,
      text: '',
      audioUrl: audioPath,
      audioDuration: duration,
      timestamp: DateTime.now(),
      isSentByMe: true,
      isRead: false,
      isPending: true,
      isFailed: false,
    );

    setState(() {
      _messages.add(optimisticMessage);
    });

    _cacheMessages();
    _scrollToBottom(force: true);

    try {
      final sent = await _chatService.sendVoiceMessage(widget.chatId, audioPath, duration: duration);

      _voiceRecorder.deleteRecording(audioPath);

      if (!mounted || sent == null) {
        _markVoiceMessageFailed(tempId);
        return;
      }

      final index = _messages.indexWhere((m) => m.id == tempId);
      if (index != -1) {
        setState(() {
          _messages[index] = ChatMessage(
            id: sent.id,
            messageType: sent.messageType,
            text: sent.text ?? '',
            audioUrl: sent.audioUrl,
            audioDuration: sent.audioDuration,
            timestamp: sent.sentAt,
            isSentByMe: true,
            isRead: false,
            isPending: false,
            isFailed: false,
          );
        });
        _cacheMessages();
        HapticFeedback.lightImpact();
      }
    } catch (e) {
      _markVoiceMessageFailed(tempId);
    }
  }

  void _markVoiceMessageFailed(String messageId) {
    if (!mounted) return;
    final index = _messages.indexWhere((m) => m.id == messageId);
    if (index != -1) {
      final existing = _messages[index];
      setState(() {
        _messages[index] = ChatMessage(
          id: existing.id,
          messageType: existing.messageType,
          text: existing.text,
          audioUrl: existing.audioUrl,
          audioDuration: existing.audioDuration,
          timestamp: existing.timestamp,
          isSentByMe: existing.isSentByMe,
          isRead: existing.isRead,
          isPending: false,
          isFailed: true,
        );
      });
      _cacheMessages();
      HapticFeedback.mediumImpact();
    }
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
        // User scrolled to bottom - mark messages as read now
        if (_pendingNewMessages > 0 && !widget.isSupport) {
          ChatSocketService().markAsRead(widget.chatId);
        }
        setState(() {
          _showScrollToBottomButton = false;
          _pendingNewMessages = 0;
          // Don't clear _firstUnreadIndex here - keep the chip visible until user replies or leaves
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

        return ChatMessage(id: m.id, text: m.text!, timestamp: m.sentAt, isSentByMe: isSentByMe, isRead: isReadByOther);
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

  Future<void> _syncOrderStatus() async {
    final id = _orderId ?? widget.orderId;
    if (id == null || id.isEmpty) return;

    try {
      final baseUrl = AppConfig.apiBaseUrl;
      final uri = Uri.parse('$baseUrl/orders/$id');

      final headers = <String, String>{'Content-Type': 'application/json'};
      try {
        final token = CacheService.getAuthToken();
        if (token != null && token.isNotEmpty) {
          headers['Authorization'] = 'Bearer $token';
        }
      } catch (_) {}

      final response = await http.get(uri, headers: headers);
      if (response.statusCode != 200) return;

      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) return;
      final data = decoded['data'];
      if (data is! Map<String, dynamic>) return;

      final status = data['status']?.toString();
      if (status == null || status.isEmpty) return;

      if (!mounted) return;
      if (_currentOrderStatus != status) {
        setState(() {
          _currentOrderStatus = status;
        });
      }
    } catch (_) {}
  }

  ({String text, Color color})? _getOrderStatusInfo(String status, AppColorsExtension colors) {
    switch (status) {
      case 'pending':
        return (text: 'Awaiting confirmation', color: colors.textSecondary);
      case 'confirmed':
        return (text: 'Order confirmed', color: colors.accentGreen);
      case 'preparing':
        return (text: 'Preparing order', color: colors.accentGreen);
      case 'ready':
        return (text: 'Ready for pickup', color: colors.accentGreen);
      case 'picked_up':
        return (text: 'Picked up', color: colors.accentGreen);
      case 'on_the_way':
        return (text: 'On the way', color: colors.accentGreen);
      case 'delivered':
        return (text: 'Delivered', color: colors.accentGreen);
      case 'cancelled':
        return (text: 'Cancelled', color: colors.error);
      default:
        return null;
    }
  }

  Widget _buildOrderStatusBanner(AppColorsExtension colors) {
    final status = _currentOrderStatus;
    if (status == null) return const SizedBox.shrink();

    final info = _getOrderStatusInfo(status, colors);
    if (info == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      color: info.color.withValues(alpha: 0.1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 8.w,
            height: 8.w,
            decoration: BoxDecoration(color: info.color, shape: BoxShape.circle),
          ),
          SizedBox(width: 8.w),
          Text(
            info.text,
            style: TextStyle(color: info.color, fontSize: 13.sp, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
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
                          : colors.accentGreen.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: SvgPicture.asset(
                        widget.isSupport ? Assets.icons.headsetHelp : Assets.icons.user,
                        package: 'grab_go_shared',
                        width: 20.w,
                        height: 20.w,
                        colorFilter: ColorFilter.mode(
                          widget.isSupport ? colors.accentViolet : colors.accentGreen,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                  if (_isPeerOnline)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 12.w,
                        height: 12.w,
                        decoration: BoxDecoration(
                          color: colors.accentGreen,
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
            if (!widget.isSupport && (_orderId ?? widget.orderId) != null)
              IconButton(
                icon: SvgPicture.asset(
                  Assets.icons.mapPin,
                  package: 'grab_go_shared',
                  width: 22.w,
                  height: 22.w,
                  colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
                ),
                onPressed: _openDeliveryTracking,
              ),
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
            if (!widget.isSupport) _buildOrderStatusBanner(colors),
            if (!widget.isSupport)
              if (_connectionState == ChatSocketConnectionState.reconnecting ||
                  _connectionState == ChatSocketConnectionState.connecting)
                _buildConnectionBanner('Reconnecting to chat…', colors, isWarning: false)
              else if (_connectionState == ChatSocketConnectionState.disconnected)
                _buildConnectionBanner('Offline. Messages may be delayed.', colors, isWarning: true),

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
                            // Show loading indicator at the top when loading more
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
                                            color: colors.accentGreen.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            'New messages',
                                            style: TextStyle(
                                              color: colors.accentGreen,
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
                                          color: colors.accentGreen.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          'New messages',
                                          style: TextStyle(
                                            color: colors.accentGreen,
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

            _buildInputArea(colors),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea(AppColorsExtension colors) {
    final hasText = _messageController.text.trim().isNotEmpty;

    return Container(
      padding: EdgeInsets.only(
        left: 20.w,
        right: 20.w,
        top: 12.h,
        bottom: MediaQuery.of(context).padding.bottom + 12.h,
      ),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        border: Border(top: BorderSide(color: colors.border, width: 1)),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(KBorderSize.borderRadius4),
          topRight: Radius.circular(KBorderSize.borderRadius4),
        ),
      ),
      child: _isRecording ? _buildRecordingUI(colors) : _buildTextInputUI(colors, hasText),
    );
  }

  Widget _buildTextInputUI(AppColorsExtension colors, bool hasText) {
    return Row(
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
        if (hasText)
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 48.w,
              height: 48.w,
              decoration: BoxDecoration(
                color: colors.accentGreen,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: colors.accentGreen.withValues(alpha: 0.3),
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
          )
        else
          GestureDetector(
            onLongPressStart: (_) => _startRecording(),
            onLongPressEnd: (_) => _stopAndSendRecording(),
            onLongPressCancel: () => _cancelRecording(),
            child: Container(
              width: 48.w,
              height: 48.w,
              decoration: BoxDecoration(
                color: colors.accentGreen,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: colors.accentGreen.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: Icon(Icons.mic, color: Colors.white, size: 24.w),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRecordingUI(AppColorsExtension colors) {
    return Row(
      children: [
        GestureDetector(
          onTap: _cancelRecording,
          child: Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(color: colors.error.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(Icons.delete_outline, color: colors.error, size: 22.w),
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
            decoration: BoxDecoration(
              color: colors.backgroundSecondary,
              borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
              border: Border.all(color: colors.error.withValues(alpha: 0.3), width: 1),
            ),
            child: Row(
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.5, end: 1.0),
                  duration: const Duration(milliseconds: 500),
                  builder: (context, value, child) {
                    return Container(
                      width: 10.w,
                      height: 10.w,
                      decoration: BoxDecoration(
                        color: colors.error.withValues(alpha: value),
                        shape: BoxShape.circle,
                      ),
                    );
                  },
                ),
                SizedBox(width: 12.w),
                Text(
                  VoiceRecorderService.formatDuration(_recordingDuration),
                  style: TextStyle(color: colors.textPrimary, fontSize: 16.sp, fontWeight: FontWeight.w500),
                ),
                const Spacer(),
                Text(
                  'Recording...',
                  style: TextStyle(color: colors.textSecondary, fontSize: 12.sp),
                ),
              ],
            ),
          ),
        ),
        SizedBox(width: 12.w),
        GestureDetector(
          onTap: _stopAndSendRecording,
          child: Container(
            width: 48.w,
            height: 48.w,
            decoration: BoxDecoration(
              color: colors.accentGreen,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: colors.accentGreen.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2)),
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
            decoration: BoxDecoration(color: colors.accentGreen, borderRadius: BorderRadius.circular(2.w)),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  replyTo.isSentByMe ? 'You' : widget.senderName,
                  style: TextStyle(color: colors.accentGreen, fontSize: 12.sp, fontWeight: FontWeight.w600),
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
        return ['Restaurant is delaying your order a bit.', 'One item is unavailable, can we replace it?'];
      case 'ready':
        return ['I am at the restaurant waiting for your order.', 'Restaurant is delaying your order a bit.'];
      case 'picked_up':
        return ["I've picked up your order.", "I'm on the way to your location."];
      case 'on_the_way':
        return [
          "I'm at your location, please come outside.",
          "I'm having trouble finding your address, please share a nearby landmark.",
          'Restaurant is delaying your order a bit.',
        ];
      case 'delivered':
        return ['I have delivered your order.', 'Please check your order and let me know if everything is okay.'];
      case 'cancelled':
        return ['Your order was cancelled. Please contact support if you have questions.'];
      default:
        return _quickIssueTemplates;
    }
  }

  void _openDeliveryTracking() {
    final id = _orderId ?? widget.orderId;
    if (id == null || id.isEmpty) return;

    context.push('/delivery-tracking', extra: {'orderId': id});
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

    final radiusBig = Radius.circular(KBorderSize.borderRadius12);
    const radiusSmall = Radius.circular(4);

    // Sent messages (right side): right edge gets small radius for consecutive messages
    // Received messages (left side): left edge gets small radius for consecutive messages
    final Radius topLeft;
    final Radius topRight;
    final Radius bottomLeft;
    final Radius bottomRight;

    if (isSent) {
      // Sent: left side always big, right side small for consecutive
      topLeft = radiusBig;
      topRight = isFirstInGroup ? radiusBig : radiusSmall;
      bottomLeft = radiusBig;
      bottomRight = isLastInGroup ? radiusBig : radiusSmall;
    } else {
      // Received: right side always big, left side small for consecutive
      topLeft = isFirstInGroup ? radiusBig : radiusSmall;
      topRight = radiusBig;
      bottomLeft = isLastInGroup ? radiusBig : radiusSmall;
      bottomRight = radiusBig;
    }

    final statusText = isSent && message.isFailed ? 'Tap to retry' : null;

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
                color: isSent ? colors.accentGreen : colors.backgroundPrimary,
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
                      width: double.maxFinite,
                      margin: EdgeInsets.only(bottom: 8.h),
                      padding: EdgeInsets.all(8.w),
                      decoration: BoxDecoration(
                        color: isSent
                            ? Colors.white.withValues(alpha: 0.15)
                            : colors.accentGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8.w),
                        border: Border(
                          left: BorderSide(
                            color: isSent ? Colors.white.withValues(alpha: 0.5) : colors.accentGreen,
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
                              color: isSent ? Colors.white.withValues(alpha: 0.9) : colors.accentGreen,
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
                  // Message content based on type
                  if (message.isVoiceMessage && message.audioUrl != null)
                    VoiceMessageBubble(
                      audioUrl: message.audioUrl!,
                      duration: message.audioDuration,
                      isSentByMe: isSent,
                      isRead: message.isRead,
                      timestamp: message.timestamp,
                      bubbleColor: Colors.transparent,
                      iconColor: isSent ? Colors.white : colors.accentGreen,
                      textColor: isSent ? Colors.white70 : colors.textSecondary,
                      progressColor: isSent ? Colors.white : colors.accentGreen,
                      progressBackgroundColor: isSent ? Colors.white24 : colors.border,
                    )
                  else
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
                  // Show spinner only while pending, no time
                  if (isSent && message.isPending)
                    SizedBox(
                      width: 12.w,
                      height: 12.w,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(colors.textSecondary),
                      ),
                    )
                  else ...[
                    // Show time after message is sent
                    Text(
                      _formatMessageTime(message.timestamp),
                      style: TextStyle(color: colors.textSecondary, fontSize: 11.sp, fontWeight: FontWeight.w400),
                    ),
                    if (isSent) ...[
                      SizedBox(width: 4.w),
                      if (message.isFailed)
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
                          color: message.isRead ? colors.accentGreen : colors.textSecondary,
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
      shape: RoundedRectangleBorder(
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
    // Store message index for potential restoration
    final messageIndex = _messages.indexWhere((m) => m.id == message.id);
    if (messageIndex == -1) return;

    // Optimistically remove from UI
    setState(() {
      _messages.removeAt(messageIndex);
    });
    _cacheMessages();

    // Also remove from queue if it was a failed message
    ChatSocketService().removeFromQueue(message.id);

    // Call backend to delete
    final success = await _chatService.deleteMessage(widget.chatId, message.id);

    if (!success && mounted) {
      // Restore the message if delete failed
      setState(() {
        _messages.insert(messageIndex.clamp(0, _messages.length), message);
      });
      _cacheMessages();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to delete message'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildConnectionBanner(String text, AppColorsExtension colors, {required bool isWarning}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 6.h),
      color: colors.backgroundPrimary,
      child: Row(
        children: [
          if (!isWarning)
            SizedBox(
              width: 14.w,
              height: 14.w,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(colors.accentGreen),
              ),
            )
          else
            Icon(Icons.wifi_off, size: 16.w, color: colors.textSecondary),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: colors.textSecondary, fontSize: 12.sp, fontWeight: FontWeight.w400),
            ),
          ),
        ],
      ),
    );
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
    final delta = details.primaryDelta ?? 0;

    if (widget.isSentByMe) {
      _dragExtent = (_dragExtent + delta).clamp(-_swipeThreshold * 1.5, 0);
    } else {
      _dragExtent = (_dragExtent + delta).clamp(0, _swipeThreshold * 1.5);
    }

    setState(() {});

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
          Positioned(
            left: widget.isSentByMe ? null : 8.w,
            right: widget.isSentByMe ? 8.w : null,
            child: Opacity(
              opacity: progress,
              child: Transform.scale(
                scale: 0.5 + (progress * 0.5),
                child: Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(color: colors.accentGreen.withValues(alpha: 0.2), shape: BoxShape.circle),
                  child: Icon(Icons.reply, size: 20.w, color: colors.accentGreen),
                ),
              ),
            ),
          ),
          Transform.translate(offset: Offset(_dragExtent, 0), child: widget.child),
        ],
      ),
    );
  }
}
