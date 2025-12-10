import 'dart:async';
import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_rider/shared/service/user_service.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_shared/shared/widgets/swipe_to_reply.dart';
import 'package:grab_go_shared/shared/widgets/recording_lock_button.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

class ChatMessage {
  final String id;
  final MessageType messageType;
  final String text;
  final String? audioUrl;
  final double audioDuration;
  final List<String> imageUrls; // URLs or local paths for image messages
  final List<String> blurHashes; // BlurHash for instant image previews
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
  final Map<String, List<String>> reactions; // emoji -> list of user IDs
  final bool isEdited;

  ChatMessage({
    required this.id,
    this.messageType = MessageType.text,
    required this.text,
    this.audioUrl,
    this.audioDuration = 0,
    this.imageUrls = const [],
    this.blurHashes = const [],
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
    this.reactions = const {},
    this.isEdited = false,
  });

  bool get isVoiceMessage => messageType == MessageType.voice;
  bool get isImageMessage => messageType == MessageType.image;
  bool get isTextMessage => messageType == MessageType.text;
  bool get hasReactions => reactions.isNotEmpty;
  bool get hasImages => imageUrls.isNotEmpty;
}

class ChatDetailPage extends StatefulWidget {
  final String chatId;
  final String senderName;
  final String? profilePicture;
  final String? orderId;
  final bool isSupport;

  const ChatDetailPage({
    super.key,
    required this.chatId,
    required this.senderName,
    this.profilePicture,
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
  bool hasPendingSend = false;
  bool _isPeerOnline = false;
  bool _isPeerTyping = false;
  bool _isTyping = false;
  Timer? _typingTimer;
  Timer? _orderStatusTimer;
  SocketConnectionState _connectionState = SocketConnectionState.disconnected;
  String? _orderId;
  String? orderNumber;
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
  ChatMessage? _editingMessage;

  // Pagination state
  bool _hasMoreMessages = false;
  bool _isLoadingMore = false;

  // Upload progress tracking (messageId -> progress 0.0-1.0)
  final Map<String, double> _uploadProgress = {};

  // Upload cancel tokens (messageId -> CancelToken)
  final Map<String, CancelToken> _uploadCancelTokens = {};

  // Voice recording state
  final VoiceRecorderService _voiceRecorder = VoiceRecorderService();
  bool _isRecording = false;
  bool _isRecordingLocked = false;
  Duration _recordingDuration = Duration.zero;

  // Mic button drag state
  double _micDragOffsetX = 0;
  double _micDragOffsetY = 0;
  int _redDotAnimationKey = 0;
  int _arrowAnimationKey = 0;

  // Message keys for scroll-to-reply
  final Map<String, GlobalKey> _messageKeys = {};
  String? _highlightedMessageId;

  // Emoji picker state
  bool _showEmojiPicker = false;

  // Quick reaction emojis
  static const List<String> _quickReactions = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

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
          final isEdited = m['isEdited'] == true;
          final replyToId = m['replyToId']?.toString();
          final replyToText = m['replyToText']?.toString();
          final replyToIsSentByMe = m['replyToIsSentByMe'] == true
              ? true
              : (m['replyToIsSentByMe'] == false ? false : null);

          // Parse reactions map
          Map<String, List<String>> reactions = {};
          if (m['reactions'] != null && m['reactions'] is Map) {
            final reactionsMap = m['reactions'] as Map;
            for (final entry in reactionsMap.entries) {
              final emoji = entry.key.toString();
              final users = (entry.value as List?)?.map((e) => e.toString()).toList() ?? [];
              if (users.isNotEmpty) {
                reactions[emoji] = users;
              }
            }
          }

          // Parse imageUrls and blurHashes
          final imageUrls = (m['imageUrls'] as List?)?.map((e) => e.toString()).toList() ?? [];
          final blurHashes = (m['blurHashes'] as List?)?.map((e) => e.toString()).toList() ?? [];

          return ChatMessage(
            id: id,
            messageType: messageType,
            text: text,
            audioUrl: audioUrl,
            audioDuration: audioDuration,
            imageUrls: imageUrls,
            blurHashes: blurHashes,
            timestamp: timestamp,
            isSentByMe: isSentByMe,
            isRead: isRead,
            isSystem: isSystem,
            replyToId: replyToId,
            replyToText: replyToText,
            replyToIsSentByMe: replyToIsSentByMe,
            reactions: reactions,
            isEdited: isEdited,
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
            if (m.imageUrls.isNotEmpty) 'imageUrls': m.imageUrls,
            if (m.blurHashes.isNotEmpty) 'blurHashes': m.blurHashes,
            'timestamp': m.timestamp.toIso8601String(),
            'isSentByMe': m.isSentByMe,
            'isRead': m.isRead,
            'isSystem': m.isSystem,
            if (m.replyToId != null) 'replyToId': m.replyToId,
            if (m.replyToText != null) 'replyToText': m.replyToText,
            if (m.replyToIsSentByMe != null) 'replyToIsSentByMe': m.replyToIsSentByMe,
            if (m.reactions.isNotEmpty) 'reactions': m.reactions,
            if (m.isEdited) 'isEdited': m.isEdited,
          },
        )
        .toList();

    unawaited(CacheService.saveChatMessages(widget.chatId, serialized));
  }

  @override
  void initState() {
    super.initState();
    // Set current chat to suppress notifications while viewing this chat
    PushNotificationService().setCurrentChatId(widget.chatId);
    _loadCachedMessages();
    _initAndLoadMessages();
    final chatSocket = SocketService();
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
        // Close emoji picker when keyboard opens
        if (_showEmojiPicker) {
          setState(() => _showEmojiPicker = false);
        }
        Future.delayed(const Duration(milliseconds: 300), () {
          _scrollToBottom(force: true);
        });
      }
    });
  }

  @override
  void dispose() {
    // Clear current chat so notifications can show again
    PushNotificationService().setCurrentChatId(null);
    _orderStatusTimer?.cancel();
    _typingTimer?.cancel();

    // Send typing stopped if we were typing
    if (_isTyping && !widget.isSupport) {
      SocketService().setTyping(widget.chatId, false);
    }

    final chatSocket = SocketService();
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

        // Build a map of existing reactions by message ID to preserve them
        final existingReactions = <String, Map<String, List<String>>>{};
        for (final msg in _messages) {
          if (msg.reactions.isNotEmpty) {
            existingReactions[msg.id] = msg.reactions;
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

          // Preserve existing reactions for this message
          final reactions = existingReactions[m.id] ?? {};

          return ChatMessage(
            id: m.id,
            messageType: m.messageType,
            text: m.text ?? '',
            audioUrl: m.audioUrl,
            audioDuration: m.audioDuration,
            imageUrls: m.imageUrls,
            blurHashes: m.blurHashes,
            timestamp: m.sentAt,
            isSentByMe: isSentByMe,
            isRead: isReadByOther,
            isSystem: false,
            replyToId: m.replyToId,
            replyToText: m.replyToText,
            replyToIsSentByMe: replyToIsSentByMe,
            reactions: reactions,
            isEdited: m.isEdited,
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

        // Initialize lastSeen from the last message sent by the peer (if not online)
        DateTime? peerLastMessage;
        for (var i = loadedMessages.length - 1; i >= 0; i--) {
          if (!loadedMessages[i].isSentByMe) {
            peerLastMessage = loadedMessages[i].timestamp;
            break;
          }
        }

        setState(() {
          _messages = loadedMessages;
          _orderId = chatDetail.orderId ?? widget.orderId;
          orderNumber = chatDetail.orderNumber;
          _firstUnreadIndex = firstUnreadIndex;
          _hasMoreMessages = chatDetail.pagination?.hasMore ?? false;
          // Set initial lastSeen from peer's last message if we don't have one yet
          if (_peerLastSeenAt == null && peerLastMessage != null && !_isPeerOnline) {
            _peerLastSeenAt = peerLastMessage;
          }
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
          SocketService().markAsRead(widget.chatId);
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

  void _handleConnectionStateChanged(SocketConnectionState state) {
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
          messageType: existing.messageType,
          text: existing.text,
          audioUrl: existing.audioUrl,
          audioDuration: existing.audioDuration,
          imageUrls: existing.imageUrls,
          blurHashes: existing.blurHashes,
          timestamp: existing.timestamp,
          isSentByMe: true,
          isRead: false,
          isPending: false,
          isFailed: false,
          isSystem: false,
          replyToId: existing.replyToId,
          replyToText: existing.replyToText,
          replyToIsSentByMe: existing.replyToIsSentByMe,
          reactions: existing.reactions,
        );
        HapticFeedback.lightImpact();
      } else {
        final existing = _messages[index];
        _messages[index] = ChatMessage(
          id: existing.id,
          messageType: existing.messageType,
          text: existing.text,
          audioUrl: existing.audioUrl,
          audioDuration: existing.audioDuration,
          imageUrls: existing.imageUrls,
          blurHashes: existing.blurHashes,
          timestamp: existing.timestamp,
          isSentByMe: existing.isSentByMe,
          isRead: existing.isRead,
          isPending: false,
          isFailed: true,
          isSystem: existing.isSystem,
          replyToId: existing.replyToId,
          replyToText: existing.replyToText,
          replyToIsSentByMe: existing.replyToIsSentByMe,
          reactions: existing.reactions,
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
      final replyToMessageType = replyTo['messageType']?.toString();
      // Show "🎤 Voice message" for voice message replies
      if (replyToMessageType == 'voice') {
        replyToText = '🎤 Voice message';
      } else {
        replyToText = replyTo['text']?.toString();
      }
      final replyToSenderId = replyTo['senderId']?.toString();
      if (replyToSenderId != null && _currentUserId != null) {
        replyToIsSentByMe = replyToSenderId == _currentUserId;
      }
    }

    // Parse imageUrls and blurHashes from socket message
    final imageUrlsList = messageMap['imageUrls'] as List<dynamic>?;
    final imageUrls = imageUrlsList?.map((e) => e.toString()).toList() ?? [];
    final blurHashesList = messageMap['blurHashes'] as List<dynamic>?;
    final blurHashes = blurHashesList?.map((e) => e.toString()).toList() ?? [];

    final msg = ChatMessage(
      id: id,
      messageType: MessageType.fromString(messageMap['messageType']?.toString()),
      text: messageMap['text']?.toString() ?? '',
      audioUrl: messageMap['audioUrl']?.toString(),
      audioDuration: (messageMap['audioDuration'] as num?)?.toDouble() ?? 0,
      imageUrls: imageUrls,
      blurHashes: blurHashes,
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
      SocketService().markAsRead(widget.chatId);
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

    // Parse lastSeenAt from server if available
    DateTime? lastSeenAt;
    final lastSeenStr = map['lastSeenAt']?.toString();
    if (lastSeenStr != null) {
      lastSeenAt = DateTime.tryParse(lastSeenStr);
    }

    debugPrint('Presence event: online=$online, lastSeenAt=$lastSeenAt, raw=$map');

    setState(() {
      _isPeerOnline = online;
      if (!online) {
        _isPeerTyping = false;
        // Use server-provided lastSeenAt, or fallback to now
        _peerLastSeenAt = lastSeenAt ?? DateTime.now();
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
                    messageType: m.messageType,
                    text: m.text,
                    audioUrl: m.audioUrl,
                    audioDuration: m.audioDuration,
                    imageUrls: m.imageUrls,
                    blurHashes: m.blurHashes,
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
                    reactions: m.reactions,
                  )
                : m,
          )
          .toList();
    });
    _cacheMessages();
  }

  void _handleMessageChanged(String value) {
    // Trigger rebuild to switch between mic/send button
    setState(() {});

    CacheService.saveChatDraft(widget.chatId, value);
    if (widget.isSupport) return;

    final userId = _userService.currentUser?.id;
    if (userId == null || userId.isEmpty) return;

    if (!_isTyping) {
      _isTyping = true;
      SocketService().setTyping(widget.chatId, true);
    }

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      if (!_isTyping) return;
      _isTyping = false;
      SocketService().setTyping(widget.chatId, false);
    });
  }

  void _toggleEmojiPicker() {
    if (_showEmojiPicker) {
      // Hide emoji picker and show keyboard
      setState(() => _showEmojiPicker = false);
      _messageFocusNode.requestFocus();
    } else {
      // Hide keyboard and show emoji picker
      _messageFocusNode.unfocus();
      setState(() => _showEmojiPicker = true);
    }
  }

  void _onEmojiSelected(Category? category, Emoji emoji) {
    final text = _messageController.text;
    final selection = _messageController.selection;

    // Handle invalid selection (cursor not in text field)
    final start = selection.start >= 0 ? selection.start : text.length;
    final end = selection.end >= 0 ? selection.end : text.length;

    final newText = text.replaceRange(start, end, emoji.emoji);
    _messageController.text = newText;
    _messageController.selection = TextSelection.collapsed(offset: start + emoji.emoji.length);
    _handleMessageChanged(newText);
  }

  void _onBackspacePressed() {
    final text = _messageController.text;
    final selection = _messageController.selection;

    // Handle invalid selection - default to end of text
    final cursorPos = selection.start >= 0 ? selection.start : text.length;

    if (text.isNotEmpty && cursorPos > 0) {
      final newText = text.replaceRange(cursorPos - 1, cursorPos, '');
      _messageController.text = newText;
      _messageController.selection = TextSelection.collapsed(offset: cursorPos - 1);
      _handleMessageChanged(newText);
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    _typingTimer?.cancel();
    if (_isTyping) {
      final userId = _userService.currentUser?.id;
      if (userId != null && userId.isNotEmpty) {
        SocketService().setTyping(widget.chatId, false);
      }
      _isTyping = false;
    }

    final text = _messageController.text.trim();
    _messageController.clear();
    unawaited(CacheService.saveChatDraft(widget.chatId, ''));

    // Check if we're editing a message
    if (_editingMessage != null) {
      final messageToEdit = _editingMessage!;
      _cancelEdit();
      if (text.isNotEmpty && text != messageToEdit.text) {
        await _editMessage(messageToEdit, text);
      }
      return;
    }

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
      replyToText: replyTo?.isVoiceMessage == true ? '🎤 Voice message' : replyTo?.text,
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

    hasPendingSend = true;
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
            messageType: existing.messageType,
            text: existing.text,
            audioUrl: existing.audioUrl,
            audioDuration: existing.audioDuration,
            imageUrls: existing.imageUrls,
            blurHashes: existing.blurHashes,
            timestamp: existing.timestamp,
            isSentByMe: existing.isSentByMe,
            isRead: existing.isRead,
            isPending: false,
            isFailed: true,
            isSystem: existing.isSystem,
            replyToId: existing.replyToId,
            replyToText: existing.replyToText,
            replyToIsSentByMe: existing.replyToIsSentByMe,
            reactions: existing.reactions,
          );
          // Queue for automatic retry when connection is restored
          if (!widget.isSupport) {
            SocketService().queueFailedMessage(widget.chatId, tempId, trimmed);
          }
        }
      });
      _cacheMessages();
      HapticFeedback.mediumImpact();
    } finally {
      hasPendingSend = false;
    }
  }

  Future<void> _retrySendMessage(ChatMessage message) async {
    if (!message.isSentByMe || !message.isFailed) return;

    final index = _messages.indexWhere((m) => m.id == message.id);
    if (index == -1) return;

    // Remove from queue since we're manually retrying
    SocketService().removeFromQueue(message.id);

    setState(() {
      _messages[index] = ChatMessage(
        id: message.id,
        messageType: message.messageType,
        text: message.text,
        audioUrl: message.audioUrl,
        audioDuration: message.audioDuration,
        imageUrls: message.imageUrls,
        blurHashes: message.blurHashes,
        timestamp: message.timestamp,
        isSentByMe: message.isSentByMe,
        isRead: message.isRead,
        isPending: true,
        isFailed: false,
        isSystem: message.isSystem,
        replyToId: message.replyToId,
        replyToText: message.replyToText,
        replyToIsSentByMe: message.replyToIsSentByMe,
        reactions: message.reactions,
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
            messageType: existing.messageType,
            text: existing.text,
            audioUrl: existing.audioUrl,
            audioDuration: existing.audioDuration,
            imageUrls: existing.imageUrls,
            blurHashes: existing.blurHashes,
            timestamp: existing.timestamp,
            isSentByMe: existing.isSentByMe,
            isRead: existing.isRead,
            isPending: false,
            isFailed: true,
            isSystem: existing.isSystem,
            replyToId: existing.replyToId,
            replyToText: existing.replyToText,
            replyToIsSentByMe: existing.replyToIsSentByMe,
            reactions: existing.reactions,
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
      _isRecordingLocked = false;
      _recordingDuration = Duration.zero;
      _micDragOffsetX = 0;
      _micDragOffsetY = 0;
    });

    if (filePath == null || filePath.isEmpty) return;

    // Don't send very short recordings (less than 1 second)
    if (duration.inMilliseconds < 1000) {
      _voiceRecorder.deleteRecording(filePath);
      return;
    }

    await _sendVoiceMessage(filePath, duration.inMilliseconds / 1000.0);
  }

  void _cancelRecording() {
    if (!_isRecording) return;

    _voiceRecorder.cancelRecording();
    setState(() {
      _isRecording = false;
      _isRecordingLocked = false;
      _recordingDuration = Duration.zero;
      _micDragOffsetX = 0;
      _micDragOffsetY = 0;
    });
    HapticFeedback.lightImpact();
  }

  void _lockRecording() {
    if (!_isRecording) return;

    setState(() {
      _isRecordingLocked = true;
      _micDragOffsetX = 0;
      _micDragOffsetY = 0;
    });
    HapticFeedback.mediumImpact();
  }

  void _handleMicDragUpdate(DragUpdateDetails details) {
    if (!_isRecording || _isRecordingLocked) return;

    setState(() {
      _micDragOffsetX += details.delta.dx;
      _micDragOffsetY += details.delta.dy;

      // Clamp to prevent dragging right or down
      if (_micDragOffsetX > 0) _micDragOffsetX = 0;
      if (_micDragOffsetY > 0) _micDragOffsetY = 0;
    });

    // Check for lock threshold (slide up -80px)
    if (_micDragOffsetY < -80) {
      _lockRecording();
    }

    // Check for cancel threshold (slide left -120px)
    if (_micDragOffsetX < -120) {
      _cancelRecording();
    }
  }

  void _handleMicDragEnd(DragEndDetails details) {
    if (!_isRecording || _isRecordingLocked) return;

    // If not locked and released, send the recording
    _stopAndSendRecording();
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
    // Force scroll to show the sent message even when keyboard is up
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollToBottom(force: true);
    });

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

  void _showImagePicker(AppColorsExtension colors) {
    HapticFeedback.selectionClick();
    _messageFocusNode.unfocus();
    ImagePickerSheet.show(
      context,
      maxImages: 10,
      onImagesSelected: (imagePaths) {
        if (imagePaths.isNotEmpty) {
          _sendImageMessage(imagePaths);
        }
      },
    );
  }

  Future<void> _sendImageMessage(List<String> imagePaths) async {
    if (imagePaths.isEmpty) return;

    final tempId = DateTime.now().millisecondsSinceEpoch.toString();

    // Compress images before upload
    final compressedPaths = await ImageCompressService.instance.compressImages(
      imagePaths,
      quality: 70,
      maxWidth: 1080,
      maxHeight: 1920,
    );

    if (compressedPaths.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to process images')));
      }
      return;
    }

    // Capture reply before clearing
    final replyTo = _replyingTo;
    _cancelReply();

    // Add optimistic message with local paths
    final optimisticMessage = ChatMessage(
      id: tempId,
      messageType: MessageType.image,
      text: '',
      imageUrls: compressedPaths,
      timestamp: DateTime.now(),
      isSentByMe: true,
      isRead: false,
      isPending: true,
      isFailed: false,
      isSystem: false,
      replyToId: replyTo?.id,
      replyToText: replyTo?.isVoiceMessage == true ? '🎤 Voice message' : replyTo?.text,
      replyToIsSentByMe: replyTo?.isSentByMe,
    );

    setState(() {
      _messages.add(optimisticMessage);
      _firstUnreadIndex = null;
    });

    _cacheMessages();
    // Force scroll to show the sent message even when keyboard is up
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _scrollToBottom(force: true);
    });

    // Create cancel token for this upload
    final cancelToken = CancelToken();
    _uploadCancelTokens[tempId] = cancelToken;

    try {
      final sent = await _chatService.sendImageMessage(
        widget.chatId,
        compressedPaths,
        replyToId: replyTo?.id,
        cancelToken: cancelToken,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _uploadProgress[tempId] = progress;
            });
          }
        },
      );

      // Check if cancelled before processing result
      final wasCancelled = cancelToken.isCancelled;

      // Clean up progress and cancel token tracking
      _uploadProgress.remove(tempId);
      _uploadCancelTokens.remove(tempId);

      // If cancelled, the message was already removed by _cancelImageUpload
      if (wasCancelled) return;

      if (sent != null && mounted) {
        final index = _messages.indexWhere((m) => m.id == tempId);
        if (index != -1) {
          setState(() {
            _messages[index] = ChatMessage(
              id: sent.id,
              messageType: sent.messageType,
              text: sent.text ?? '',
              imageUrls: sent.imageUrls,
              timestamp: sent.sentAt,
              isSentByMe: true,
              isRead: false,
              isPending: false,
              isFailed: false,
              isSystem: false,
              replyToId: replyTo?.id,
              replyToText: replyTo?.isVoiceMessage == true ? '🎤 Voice message' : replyTo?.text,
              replyToIsSentByMe: replyTo?.isSentByMe,
            );
          });
          _cacheMessages();
          HapticFeedback.lightImpact();
        }
      } else if (mounted) {
        // Upload failed (not cancelled) - mark as failed
        final index = _messages.indexWhere((m) => m.id == tempId);
        if (index != -1) {
          final existing = _messages[index];
          setState(() {
            _messages[index] = ChatMessage(
              id: existing.id,
              messageType: existing.messageType,
              text: existing.text,
              imageUrls: existing.imageUrls,
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
    } catch (e) {
      debugPrint('Error sending image message: $e');

      // Clean up on error
      _uploadProgress.remove(tempId);
      _uploadCancelTokens.remove(tempId);

      final index = _messages.indexWhere((m) => m.id == tempId);
      if (index != -1 && mounted) {
        final existing = _messages[index];
        setState(() {
          _messages[index] = ChatMessage(
            id: existing.id,
            messageType: existing.messageType,
            text: existing.text,
            imageUrls: existing.imageUrls,
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
  }

  Future<void> _retryImageMessage(ChatMessage message) async {
    if (!message.isFailed || !message.hasImages) return;

    // Re-send the image message
    _sendImageMessage(message.imageUrls);

    // Remove the failed message
    setState(() {
      _messages.removeWhere((m) => m.id == message.id);
    });
    _cacheMessages();
  }

  void _cancelImageUpload(String messageId) {
    // Cancel the upload
    final cancelToken = _uploadCancelTokens[messageId];
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel('User cancelled upload');
    }

    // Clean up tracking
    _uploadProgress.remove(messageId);
    _uploadCancelTokens.remove(messageId);

    // Remove the message from the list
    setState(() {
      _messages.removeWhere((m) => m.id == messageId);
    });
    _cacheMessages();
    HapticFeedback.mediumImpact();
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
          SocketService().markAsRead(widget.chatId);
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
        final token = await CacheService.getAuthToken();
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
                    child: ClipOval(
                      child: widget.profilePicture != null && widget.profilePicture!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: widget.profilePicture!,
                              width: 40.w,
                              height: 40.w,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Center(
                                child: SvgPicture.asset(
                                  Assets.icons.user,
                                  package: 'grab_go_shared',
                                  width: 20.w,
                                  height: 20.w,
                                  colorFilter: ColorFilter.mode(colors.accentGreen, BlendMode.srcIn),
                                ),
                              ),
                              errorWidget: (context, url, error) => Center(
                                child: SvgPicture.asset(
                                  Assets.icons.user,
                                  package: 'grab_go_shared',
                                  width: 20.w,
                                  height: 20.w,
                                  colorFilter: ColorFilter.mode(colors.accentGreen, BlendMode.srcIn),
                                ),
                              ),
                            )
                          : Center(
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
                      style: TextStyle(
                        fontFamily: "Lato",
                        package: "grab_go_shared",
                        color: colors.textPrimary,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_isPeerTyping)
                      Text(
                        'Typing...',
                        style: TextStyle(
                          fontFamily: "Lato",
                          package: "grab_go_shared",
                          color: colors.textSecondary,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w400,
                        ),
                      )
                    else if (_isPeerOnline)
                      Text(
                        'Online',
                        style: TextStyle(
                          fontFamily: "Lato",
                          package: "grab_go_shared",
                          color: colors.textSecondary,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w400,
                        ),
                      )
                    else if (_peerLastSeenAt != null)
                      AnimatedLastSeenText(
                        timestamp: _peerLastSeenAt!,
                        textColor: colors.textSecondary,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w400,
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
              if (_connectionState == SocketConnectionState.reconnecting ||
                  _connectionState == SocketConnectionState.connecting)
                _buildConnectionBanner('Reconnecting to chat…', colors, isWarning: false)
              else if (_connectionState == SocketConnectionState.disconnected)
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
                                      valueColor: AlwaysStoppedAnimation<Color>(colors.accentGreen),
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
                                      padding: EdgeInsets.symmetric(vertical: 16.h),
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
                                    padding: EdgeInsets.symmetric(vertical: 16.h),
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

            // Edit preview
            if (_editingMessage != null) _buildEditPreview(colors),

            _buildInputArea(colors),
          ],
        ),
      ),
    );
  }

  Widget _buildInputArea(AppColorsExtension colors) {
    final hasText = _messageController.text.trim().isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: EdgeInsets.only(
            left: 20.w,
            right: 20.w,
            top: 12.h,
            bottom: _showEmojiPicker ? 12.h : MediaQuery.of(context).padding.bottom + 12.h,
          ),
          decoration: BoxDecoration(
            color: colors.backgroundPrimary,
            border: Border(top: BorderSide(color: colors.border, width: 1)),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(KBorderSize.borderRadius4),
              topRight: Radius.circular(KBorderSize.borderRadius4),
            ),
          ),
          child: _buildTextInputUI(colors, hasText),
        ),
        // Emoji picker
        if (_showEmojiPicker)
          SizedBox(
            height: 250.h,
            child: EmojiPicker(
              onEmojiSelected: _onEmojiSelected,
              onBackspacePressed: _onBackspacePressed,
              config: Config(
                height: 250.h,
                checkPlatformCompatibility: false,
                emojiViewConfig: EmojiViewConfig(
                  emojiSizeMax: 28,
                  backgroundColor: colors.backgroundPrimary,
                  columns: 8,
                  noRecents: const Text('No Recents', style: TextStyle(fontSize: 16, color: Colors.grey)),
                ),
                categoryViewConfig: CategoryViewConfig(
                  backgroundColor: colors.backgroundPrimary,
                  indicatorColor: colors.accentGreen,
                  iconColorSelected: colors.accentGreen,
                  iconColor: colors.textSecondary,
                ),
                bottomActionBarConfig: const BottomActionBarConfig(enabled: false),
                searchViewConfig: SearchViewConfig(
                  backgroundColor: colors.backgroundPrimary,
                  buttonIconColor: colors.textSecondary,
                  hintText: 'Search emoji...',
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildTextInputUI(AppColorsExtension colors, bool hasText) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Main input row
        Row(
          children: [
            // Hide emoji and camera buttons when recording
            if (!_isRecording) ...[
              // Emoji button
              GestureDetector(
                onTap: _toggleEmojiPicker,
                child: SvgPicture.asset(
                  _showEmojiPicker ? Assets.icons.keyboard : Assets.icons.emoji,
                  package: 'grab_go_shared',
                  width: 24.w,
                  height: 24.w,
                  colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                ),
              ),
              SizedBox(width: 8.w),
              // Image attachment button
              GestureDetector(
                onTap: () => _showImagePicker(colors),
                child: SvgPicture.asset(
                  Assets.icons.camera,
                  package: 'grab_go_shared',
                  width: 24.w,
                  height: 24.w,
                  colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                ),
              ),
              SizedBox(width: 10.w),
            ],
            // Show recording UI when recording, otherwise show text input
            if (_isRecording)
              // Recording UI (timer, animated dot, slide to cancel)
              Expanded(
                child: Row(
                  children: [
                    // Animated recording indicator (pulsing red dot)
                    TweenAnimationBuilder<double>(
                      key: ValueKey('red_dot_$_redDotAnimationKey'),
                      tween: Tween(begin: 0.8, end: 1.0),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeInOut,
                      builder: (context, scale, child) {
                        return Transform.scale(
                          scale: scale,
                          child: Container(
                            width: 12.w,
                            height: 12.w,
                            decoration: BoxDecoration(
                              color: colors.error,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: colors.error.withValues(alpha: 0.5),
                                  blurRadius: 4,
                                  spreadRadius: scale * 2,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                      onEnd: () {
                        // Restart animation by incrementing counter
                        if (mounted && _isRecording) {
                          setState(() {
                            _redDotAnimationKey++;
                          });
                        }
                      },
                    ),
                    SizedBox(width: 12.w),
                    // Timer
                    Text(
                      VoiceRecorderService.formatDuration(_recordingDuration),
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const Spacer(),
                    // Slide to cancel OR cancel button when locked
                    if (!_isRecordingLocked)
                      // Animated arrow with slide to cancel
                      TweenAnimationBuilder<double>(
                        key: ValueKey('arrow_$_arrowAnimationKey'),
                        tween: Tween(begin: 0.0, end: -8.0),
                        duration: const Duration(milliseconds: 1000),
                        curve: Curves.easeInOut,
                        builder: (context, offset, child) {
                          return Transform.translate(
                            offset: Offset(offset, 0),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.chevron_left, color: colors.textSecondary, size: 20.sp),
                                SizedBox(width: 4.w),
                                Text(
                                  'Slide to cancel',
                                  style: TextStyle(
                                    color: colors.textSecondary,
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        onEnd: () {
                          // Restart animation by incrementing counter
                          if (mounted && _isRecording && !_isRecordingLocked) {
                            setState(() {
                              _arrowAnimationKey++;
                            });
                          }
                        },
                      )
                    else
                      // Cancel button when locked (centered)
                      GestureDetector(
                        onTap: _cancelRecording,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 10.h),
                          decoration: BoxDecoration(
                            color: colors.error.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: colors.error.withValues(alpha: 0.3), width: 1.5),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.close, color: colors.error, size: 20.sp),
                              SizedBox(width: 6.w),
                              Text(
                                'Cancel',
                                style: TextStyle(color: colors.error, fontSize: 14.sp, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              )
            else
              // Text input (when not recording)
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
                    onTap: () {
                      if (_showEmojiPicker) {
                        setState(() => _showEmojiPicker = false);
                      }
                    },
                  ),
                ),
              ),
            SizedBox(width: 12.w),
            // Show send button when recording is locked OR when there's text
            if (_isRecordingLocked || hasText)
              GestureDetector(
                onTap: _isRecordingLocked ? _stopAndSendRecording : _sendMessage,
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
              // Mic button with drag gestures
              GestureDetector(
                onPanDown: (_) => _startRecording(),
                onPanUpdate: _handleMicDragUpdate,
                onPanEnd: _handleMicDragEnd,
                child: Transform.translate(
                  offset: Offset(_micDragOffsetX, _micDragOffsetY),
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 150),
                    opacity: _micDragOffsetX < -60 ? 0.5 : 1.0,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeOut,
                      width: _isRecording ? 56.w : 48.w,
                      height: _isRecording ? 56.w : 48.w,
                      decoration: BoxDecoration(
                        color: colors.accentGreen,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: colors.accentGreen.withValues(alpha: 0.3),
                            blurRadius: _isRecording ? 12 : 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: SvgPicture.asset(
                          Assets.icons.microphone,
                          package: 'grab_go_shared',
                          width: _isRecording ? 24.w : 20.w,
                          height: _isRecording ? 24.w : 20.w,
                          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        // Floating lock button above mic
        if (_isRecording && !_isRecordingLocked)
          Positioned(
            bottom: 70.h,
            right: 0,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(0, 30 * (1 - value)),
                  child: Opacity(opacity: value, child: child),
                );
              },
              child: RecordingLockButton(
                color: colors.accentGreen,
                backgroundColor: colors.backgroundSecondary,
                isLocked: false,
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
                  replyTo.isVoiceMessage
                      ? '🎤 Voice message'
                      : replyTo.isImageMessage
                      ? '📷 Image'
                      : replyTo.text,
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
              child: SvgPicture.asset(
                Assets.icons.xmark,
                package: "grab_go_shared",
                colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                height: 20.h,
                width: 20.w,
              ),
              // child: Icon(Icons.close, size: 20.w, color: colors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditPreview(AppColorsExtension colors) {
    final editMsg = _editingMessage;
    if (editMsg == null) return const SizedBox.shrink();

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
            decoration: BoxDecoration(color: colors.accentBlue, borderRadius: BorderRadius.circular(2.w)),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Editing message',
                  style: TextStyle(color: colors.accentBlue, fontSize: 12.sp, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 2.h),
                Text(
                  editMsg.text,
                  style: TextStyle(color: colors.textSecondary, fontSize: 13.sp, fontWeight: FontWeight.w400),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          GestureDetector(
            onTap: _cancelEdit,
            child: Container(
              padding: EdgeInsets.all(4.w),
              child: SvgPicture.asset(
                Assets.icons.xmark,
                package: "grab_go_shared",
                colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                height: 20.h,
                width: 20.w,
              ),
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
                      final replyTo = _replyingTo;
                      _cancelReply();
                      _sendQuickMessage(text, replyTo: replyTo);
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

    // Get or create a GlobalKey for this message
    _messageKeys.putIfAbsent(message.id, () => GlobalKey());
    final isHighlighted = _highlightedMessageId == message.id;

    final bubble = Align(
      key: _messageKeys[message.id],
      alignment: isSent ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: size.width * 0.75),
        child: Column(
          crossAxisAlignment: isSent ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: message.isImageMessage && message.hasImages
                      ? EdgeInsets.all(4.w) // Thin padding for image messages
                      : EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                  margin: message.hasReactions ? EdgeInsets.only(bottom: 16.h) : EdgeInsets.zero,
                  decoration: BoxDecoration(
                    color: isHighlighted
                        ? (isSent
                              ? colors.accentGreen.withValues(alpha: 0.7)
                              : colors.accentGreen.withValues(alpha: 0.15))
                        : (isSent ? colors.accentGreen : colors.backgroundPrimary),
                    borderRadius: BorderRadius.only(
                      topLeft: topLeft,
                      topRight: topRight,
                      bottomLeft: bottomLeft,
                      bottomRight: bottomRight,
                    ),
                    border: isSent
                        ? null
                        : Border.all(color: isHighlighted ? colors.accentGreen : colors.border, width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Reply preview in bubble (tappable to scroll to original message)
                      if (message.replyToId != null && message.replyToText != null)
                        GestureDetector(
                          onTap: () => _scrollToMessage(message.replyToId!),
                          child: Container(
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
                        ),
                      // Message content based on type
                      if (message.isVoiceMessage && message.audioUrl != null)
                        VoiceMessageBubble(
                          key: ValueKey('voice_${message.id}_${message.audioUrl}'),
                          audioUrl: message.audioUrl!,
                          duration: message.audioDuration,
                          isSentByMe: isSent,
                          isRead: message.isRead,
                          timestamp: message.timestamp,
                          accentColor: isSent ? Colors.white : colors.accentGreen,
                          playButtonIconColor: isSent ? colors.accentGreen : Colors.white,
                          textColor: isSent ? Colors.white70 : colors.textSecondary,
                          waveActiveColor: isSent ? Colors.white : colors.accentGreen,
                          waveInactiveColor: isSent ? Colors.white38 : colors.border,
                        )
                      else if (message.isImageMessage && message.hasImages)
                        ImageMessageBubble(
                          key: ValueKey('image_${message.id}_${message.imageUrls.join("_")}'),
                          imageUrls: message.imageUrls,
                          blurHashes: message.blurHashes,
                          isSent: isSent,
                          isPending: message.isPending,
                          isFailed: message.isFailed,
                          uploadProgress: _uploadProgress[message.id],
                          onRetry: canRetry ? () => _retryImageMessage(message) : null,
                          onCancelUpload: message.isPending ? () => _cancelImageUpload(message.id) : null,
                          onImageTap: (index) =>
                              ImageViewerScreen.show(context, message.imageUrls, initialIndex: index),
                        )
                      else if (message.isImageMessage && !message.hasImages)
                        // Fallback for image messages without URLs (backend didn't return them)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SvgPicture.asset(
                              Assets.icons.camera,
                              package: 'grab_go_shared',
                              width: 16.w,
                              height: 16.w,
                              colorFilter: ColorFilter.mode(
                                isSent ? Colors.white70 : colors.textSecondary,
                                BlendMode.srcIn,
                              ),
                            ),
                            SizedBox(width: 6.w),
                            Text(
                              'Photo',
                              style: TextStyle(
                                color: isSent ? Colors.white70 : colors.textSecondary,
                                fontSize: 14.sp,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
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
                // Reactions display (positioned at bottom of bubble)
                if (message.hasReactions)
                  Positioned(
                    bottom: -4.h,
                    right: isSent ? 8.w : null,
                    left: isSent ? null : 8.w,
                    child: _buildReactionsDisplay(message, colors),
                  ),
              ],
            ),
            if (isLastInGroup) ...[
              SizedBox(height: 4.h),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Show spinner only while pending, no time (skip for image/voice messages - they have their own spinner)
                  if (isSent && message.isPending && !message.isImageMessage && !message.isVoiceMessage)
                    SizedBox(
                      width: 12.w,
                      height: 12.w,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(colors.textSecondary),
                      ),
                    )
                  // Hide timestamp/status for pending image/voice messages
                  else if (!message.isPending) ...[
                    // Show "Edited" indicator if message was edited
                    if (message.isEdited) ...[
                      Text(
                        'Edited',
                        style: TextStyle(color: colors.textSecondary, fontSize: 11.sp, fontWeight: FontWeight.w400),
                      ),
                      SizedBox(width: 4.w),
                    ],
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
    final canReact = !message.isSystem && !message.isPending && !message.isFailed;

    if (canSwipeToReply) {
      return SwipeToReply(
        onSwipe: () => _setReplyingTo(message),
        isSentByMe: isSent,
        kColor: colors.accentGreen,
        child: GestureDetector(
          onTap: canRetry ? () => _retrySendMessage(message) : null,
          onDoubleTap: canReact ? () => _showQuickReactions(message, colors) : null,
          onLongPress: () => _showMessageActions(message, colors),
          behavior: HitTestBehavior.translucent,
          child: bubble,
        ),
      );
    }

    return GestureDetector(
      onTap: canRetry ? () => _retrySendMessage(message) : null,
      onDoubleTap: canReact ? () => _showQuickReactions(message, colors) : null,
      onLongPress: () => _showMessageActions(message, colors),
      behavior: HitTestBehavior.translucent,
      child: bubble,
    );
  }

  void _setReplyingTo(ChatMessage message) {
    setState(() {
      _replyingTo = message;
      _showEmojiPicker = false; // Close emoji picker when replying
    });
    // Show keyboard
    _messageFocusNode.requestFocus();
    HapticFeedback.selectionClick();
  }

  void _cancelReply() {
    setState(() {
      _replyingTo = null;
    });
  }

  void _startEditingMessage(ChatMessage message) {
    setState(() {
      _editingMessage = message;
      _replyingTo = null; // Cancel any reply when editing
      _showEmojiPicker = false;
    });
    // Set the text field to the message text
    _messageController.text = message.text;
    _messageController.selection = TextSelection.fromPosition(TextPosition(offset: message.text.length));
    // Show keyboard
    _messageFocusNode.requestFocus();
    HapticFeedback.selectionClick();
  }

  void _cancelEdit() {
    setState(() {
      _editingMessage = null;
    });
    _messageController.clear();
  }

  void _scrollToMessage(String messageId) {
    final key = _messageKeys[messageId];
    if (key == null || key.currentContext == null) {
      // Message might not be loaded yet (pagination)
      return;
    }

    // Scroll to the message
    Scrollable.ensureVisible(
      key.currentContext!,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      alignment: 0.5, // Center the message in the viewport
    );

    // Highlight the message briefly
    setState(() {
      _highlightedMessageId = messageId;
    });

    // Remove highlight after animation
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _highlightedMessageId = null;
        });
      }
    });

    HapticFeedback.selectionClick();
  }

  Widget _buildReactionsDisplay(ChatMessage message, AppColorsExtension colors) {
    final reactions = message.reactions;
    if (reactions.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(12.w),
        border: Border.all(color: colors.border, width: 1),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: reactions.entries.map((entry) {
          final emoji = entry.key;
          final count = entry.value.length;
          return Padding(
            padding: EdgeInsets.symmetric(horizontal: 2.w),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(emoji, style: TextStyle(fontSize: 14.sp)),
                if (count > 1) ...[
                  SizedBox(width: 2.w),
                  Text(
                    count.toString(),
                    style: TextStyle(color: colors.textSecondary, fontSize: 11.sp, fontWeight: FontWeight.w500),
                  ),
                ],
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showQuickReactions(ChatMessage message, AppColorsExtension colors) {
    HapticFeedback.selectionClick();
    _messageFocusNode.unfocus();
    final messageId = message.id; // Capture ID to find fresh message later

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (context) {
        return Center(
          child: Container(
            margin: EdgeInsets.all(16.w),
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: colors.backgroundPrimary,
              borderRadius: BorderRadius.circular(24.w),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: _quickReactions.map((emoji) {
                final hasReacted = message.reactions[emoji]?.contains(_userService.currentUser?.id ?? '') ?? false;
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _toggleReactionById(messageId, emoji);
                  },
                  child: Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: hasReacted ? colors.accentGreen.withValues(alpha: 0.2) : Colors.transparent,
                      borderRadius: BorderRadius.circular(12.w),
                    ),
                    child: Text(emoji, style: TextStyle(fontSize: 28.sp)),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  void _toggleReactionById(String messageId, String emoji) {
    final userId = _userService.currentUser?.id ?? '';
    if (userId.isEmpty) return;

    // Prevent keyboard from popping up after reaction
    _messageFocusNode.unfocus();

    setState(() {
      final messageIndex = _messages.indexWhere((m) => m.id == messageId);
      if (messageIndex == -1) return;

      final message = _messages[messageIndex];

      final currentReactions = Map<String, List<String>>.from(message.reactions);
      final emojiReactions = List<String>.from(currentReactions[emoji] ?? []);

      if (emojiReactions.contains(userId)) {
        // Remove reaction
        emojiReactions.remove(userId);
        if (emojiReactions.isEmpty) {
          currentReactions.remove(emoji);
        } else {
          currentReactions[emoji] = emojiReactions;
        }
      } else {
        // Add reaction
        emojiReactions.add(userId);
        currentReactions[emoji] = emojiReactions;
      }

      _messages[messageIndex] = ChatMessage(
        id: message.id,
        messageType: message.messageType,
        text: message.text,
        audioUrl: message.audioUrl,
        audioDuration: message.audioDuration,
        imageUrls: message.imageUrls,
        blurHashes: message.blurHashes,
        timestamp: message.timestamp,
        isSentByMe: message.isSentByMe,
        isRead: message.isRead,
        readAt: message.readAt,
        isPending: message.isPending,
        isFailed: message.isFailed,
        isSystem: message.isSystem,
        replyToId: message.replyToId,
        replyToText: message.replyToText,
        replyToIsSentByMe: message.replyToIsSentByMe,
        reactions: currentReactions,
      );
    });

    _cacheMessages();

    // TODO: Send reaction to backend via socket
    // ChatSocketService().sendReaction(widget.chatId, message.id, emoji);

    HapticFeedback.lightImpact();
  }

  void _showMessageActions(ChatMessage message, AppColorsExtension colors) {
    HapticFeedback.selectionClick();
    _messageFocusNode.unfocus();

    // Determine message preview text based on type
    final String previewLabel;
    final String previewText;
    final bool canCopy;

    if (message.isImageMessage) {
      previewLabel = "Photo:";
      final imageCount = message.imageUrls.length;
      previewText = imageCount == 1 ? "1 photo" : "$imageCount photos";
      canCopy = false;
    } else if (message.isVoiceMessage) {
      previewLabel = "Voice message:";
      final duration = Duration(seconds: message.audioDuration.toInt());
      final minutes = duration.inMinutes;
      final seconds = duration.inSeconds % 60;
      previewText = "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
      canCopy = false;
    } else {
      previewLabel = "Message:";
      previewText = message.text;
      canCopy = message.text.isNotEmpty;
    }

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.backgroundPrimary,
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.96),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(KBorderSize.borderRadius12)),
      ),
      builder: (context) {
        return SafeArea(
          minimum: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom + 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(20.r),
                decoration: BoxDecoration(
                  color: colors.accentGreen.withValues(alpha: 0.2),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(KBorderSize.borderRadius12),
                    topRight: Radius.circular(KBorderSize.borderRadius12),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      previewLabel,
                      style: TextStyle(fontSize: 12.sp, color: colors.accentGreen, fontWeight: FontWeight.w900),
                    ),
                    Row(
                      children: [
                        if (message.isImageMessage)
                          Padding(
                            padding: EdgeInsets.only(right: 6.w),
                            child: SvgPicture.asset(
                              Assets.icons.mediaImage,
                              package: 'grab_go_shared',
                              width: 16.w,
                              height: 16.w,
                              colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
                            ),
                          ),
                        if (message.isVoiceMessage)
                          Padding(
                            padding: EdgeInsets.only(right: 6.w),
                            child: SvgPicture.asset(
                              Assets.icons.microphone,
                              package: 'grab_go_shared',
                              width: 16.w,
                              height: 16.w,
                              colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
                            ),
                          ),
                        Expanded(
                          child: Text(
                            previewText,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 14.sp, color: colors.textPrimary, fontWeight: FontWeight.w500),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (canCopy)
                ListTile(
                  title: Center(
                    child: Text(
                      'Copy',
                      style: TextStyle(color: colors.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w500),
                    ),
                  ),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: message.text));
                    Navigator.of(context).pop();
                  },
                ),
              // Edit option for text messages sent by me
              if (message.isSentByMe &&
                  message.isTextMessage &&
                  !message.isPending &&
                  !message.isFailed &&
                  !widget.isSupport)
                ListTile(
                  title: Center(
                    child: Text(
                      'Edit',
                      style: TextStyle(color: colors.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w500),
                    ),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    _startEditingMessage(message);
                  },
                ),
              if (message.isSentByMe && message.isFailed && message.isTextMessage)
                ListTile(
                  title: Center(
                    child: Text(
                      'Resend',
                      style: TextStyle(color: colors.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w500),
                    ),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    _retrySendMessage(message);
                  },
                ),
              if (message.isSentByMe && message.isFailed && message.isImageMessage)
                ListTile(
                  title: Center(
                    child: Text(
                      'Retry',
                      style: TextStyle(color: colors.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w500),
                    ),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    _retryImageMessage(message);
                  },
                ),
              // Show "Select photos to delete" for multi-image messages sent by me
              if (message.isSentByMe &&
                  message.isImageMessage &&
                  message.imageUrls.length > 1 &&
                  !message.isPending &&
                  !widget.isSupport)
                ListTile(
                  title: Center(
                    child: Text(
                      'Select photos to delete',
                      style: TextStyle(color: colors.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w500),
                    ),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    _showSelectPhotosToDelete(message, colors);
                  },
                ),
              if (message.isSentByMe && !message.isPending && !widget.isSupport)
                ListTile(
                  title: Center(
                    child: Text(
                      'Delete for everyone',
                      style: TextStyle(color: colors.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w500),
                    ),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    _deleteMessageForEveryone(message);
                  },
                ),
              ListTile(
                title: Center(
                  child: Text(
                    'Delete for me',
                    style: TextStyle(color: colors.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w500),
                  ),
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
    SocketService().removeFromQueue(message.id);

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

  /// Edit a text message
  Future<void> _editMessage(ChatMessage message, String newText) async {
    final messageIndex = _messages.indexWhere((m) => m.id == message.id);
    if (messageIndex == -1) return;

    // Create updated message
    final updatedMessage = ChatMessage(
      id: message.id,
      messageType: message.messageType,
      text: newText,
      audioUrl: message.audioUrl,
      audioDuration: message.audioDuration,
      imageUrls: message.imageUrls,
      blurHashes: message.blurHashes,
      timestamp: message.timestamp,
      isSentByMe: message.isSentByMe,
      isRead: message.isRead,
      isPending: message.isPending,
      isFailed: message.isFailed,
      isSystem: message.isSystem,
      replyToId: message.replyToId,
      replyToText: message.replyToText,
      replyToIsSentByMe: message.replyToIsSentByMe,
      reactions: message.reactions,
      isEdited: true,
    );

    // Optimistically update UI
    setState(() {
      _messages[messageIndex] = updatedMessage;
    });
    _cacheMessages();

    // Call backend to update message
    final success = await _chatService.editMessage(widget.chatId, message.id, newText);

    if (!success && mounted) {
      // Restore original message if update failed
      setState(() {
        _messages[messageIndex] = message;
      });
      _cacheMessages();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Failed to edit message'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Show a bottom sheet to select which photos to delete from a multi-image message
  void _showSelectPhotosToDelete(ChatMessage message, AppColorsExtension colors) {
    final selectedIndices = <int>{};

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: colors.backgroundPrimary,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20.w))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Container(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle bar
                    Container(
                      margin: EdgeInsets.symmetric(vertical: 12.h),
                      width: 40.w,
                      height: 4.h,
                      decoration: BoxDecoration(color: colors.border, borderRadius: BorderRadius.circular(2.w)),
                    ),
                    // Header
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Select photos to delete',
                            style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
                          ),
                          if (selectedIndices.isNotEmpty)
                            GestureDetector(
                              onTap: () {
                                Navigator.pop(context);
                                _deleteSelectedPhotos(message, selectedIndices.toList());
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                                decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(20.w)),
                                child: Text(
                                  'Delete (${selectedIndices.length})',
                                  style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: Colors.white),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.w),
                      child: Text(
                        'Tap photos to select them for deletion',
                        style: TextStyle(fontSize: 13.sp, color: colors.textSecondary),
                      ),
                    ),
                    SizedBox(height: 16.h),
                    // Image grid
                    Flexible(
                      child: GridView.builder(
                        shrinkWrap: true,
                        padding: EdgeInsets.all(8.w),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 8.w,
                          mainAxisSpacing: 8.w,
                        ),
                        itemCount: message.imageUrls.length,
                        itemBuilder: (context, index) {
                          final imageUrl = message.imageUrls[index];
                          final isSelected = selectedIndices.contains(index);

                          return GestureDetector(
                            onTap: () {
                              setModalState(() {
                                if (isSelected) {
                                  selectedIndices.remove(index);
                                } else {
                                  selectedIndices.add(index);
                                }
                              });
                              HapticFeedback.selectionClick();
                            },
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                // Image
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8.w),
                                  child: Image.network(
                                    imageUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: colors.backgroundSecondary,
                                        child: SvgPicture.asset(
                                          Assets.icons.mediaImage,
                                          package: 'grab_go_shared',
                                          width: 16.w,
                                          height: 16.w,
                                          colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                // Selection overlay
                                if (isSelected)
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.red.withValues(alpha: 0.4),
                                      borderRadius: BorderRadius.circular(8.w),
                                    ),
                                  ),
                                // Selection indicator
                                Positioned(
                                  top: 6.w,
                                  right: 6.w,
                                  child: Container(
                                    width: 24.w,
                                    height: 24.w,
                                    decoration: BoxDecoration(
                                      color: isSelected ? Colors.red : Colors.black.withValues(alpha: 0.5),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                    child: isSelected
                                        ? SvgPicture.asset(
                                            Assets.icons.check,
                                            package: 'grab_go_shared',
                                            width: 16.w,
                                            height: 16.w,
                                            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                                          )
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(height: 16.h),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Delete selected photos from a multi-image message
  Future<void> _deleteSelectedPhotos(ChatMessage message, List<int> indicesToDelete) async {
    if (indicesToDelete.isEmpty) return;

    // Sort indices in descending order to remove from end first
    indicesToDelete.sort((a, b) => b.compareTo(a));

    // Get remaining image URLs
    final remainingUrls = List<String>.from(message.imageUrls);
    final remainingBlurHashes = List<String>.from(message.blurHashes);

    for (final index in indicesToDelete) {
      if (index < remainingUrls.length) {
        remainingUrls.removeAt(index);
      }
      if (index < remainingBlurHashes.length) {
        remainingBlurHashes.removeAt(index);
      }
    }

    // If all images are deleted, delete the entire message
    if (remainingUrls.isEmpty) {
      _deleteMessageForEveryone(message);
      return;
    }

    // Find message index
    final messageIndex = _messages.indexWhere((m) => m.id == message.id);
    if (messageIndex == -1) return;

    // Create updated message with remaining images
    final updatedMessage = ChatMessage(
      id: message.id,
      messageType: message.messageType,
      text: message.text,
      audioUrl: message.audioUrl,
      audioDuration: message.audioDuration,
      imageUrls: remainingUrls,
      blurHashes: remainingBlurHashes,
      timestamp: message.timestamp,
      isSentByMe: message.isSentByMe,
      isRead: message.isRead,
      isPending: message.isPending,
      isFailed: message.isFailed,
      isSystem: message.isSystem,
      replyToId: message.replyToId,
      replyToText: message.replyToText,
      replyToIsSentByMe: message.replyToIsSentByMe,
    );

    // Optimistically update UI
    setState(() {
      _messages[messageIndex] = updatedMessage;
    });
    _cacheMessages();

    // Call backend to update message images
    final success = await _chatService.deleteMessageImages(widget.chatId, message.id, indicesToDelete);
    if (!success && mounted) {
      // Restore original message if update failed
      setState(() {
        _messages[messageIndex] = message;
      });
      _cacheMessages();

      AppToastMessage.show(context: context, icon: Icons.error_outline, message: "Failed to delete photos");
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
            SvgPicture.asset(
              Assets.icons.wifiOff,
              package: 'grab_go_shared',
              width: 16.w,
              height: 16.w,
              colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
            ),
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
              height: 46.h,
              child: AppButton(onPressed: _initAndLoadMessages, buttonText: 'Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
