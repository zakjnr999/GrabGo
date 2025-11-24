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
  final String text;
  final DateTime timestamp;
  final bool isSentByMe;
  final bool isRead;
  final bool isPending;
  final bool isFailed;
  final bool isSystem;

  ChatMessage({
    required this.id,
    required this.text,
    required this.timestamp,
    required this.isSentByMe,
    this.isRead = false,
    this.isPending = false,
    this.isFailed = false,
    this.isSystem = false,
  });
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
    final chatSocket = ChatSocketService();
    chatSocket.addConnectionListener(_handleConnectionStateChanged);
    if (!widget.isSupport) {
      chatSocket.joinChat(widget.chatId);
      chatSocket.addNewMessageListener(_handleIncomingSocketMessage);
      chatSocket.addPresenceListener(_handlePresenceEvent);
      chatSocket.addTypingListener(_handleTypingEvent);
      chatSocket.addReadListener(_handleReadEvent);
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
    final chatSocket = ChatSocketService();
    chatSocket.removeConnectionListener(_handleConnectionStateChanged);
    if (!widget.isSupport) {
      chatSocket.removeNewMessageListener(_handleIncomingSocketMessage);
      chatSocket.removePresenceListener(_handlePresenceEvent);
      chatSocket.removeTypingListener(_handleTypingEvent);
      chatSocket.removeReadListener(_handleReadEvent);
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
            isSystem: false,
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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load messages. Please try again.';
        _messages = [];
      });
    } finally {}
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
            Icon(Icons.arrow_downward, size: 18.w, color: colors.textPrimary),
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
    if (!mounted || widget.isSupport) return;
    if (data is! Map) return;

    final map = Map<String, dynamic>.from(data);
    final payloadChatId = map['chatId']?.toString();
    if (payloadChatId != widget.chatId) return;

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

    await _sendQuickMessage(text);
  }

  Future<void> _sendQuickMessage(String text) async {
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
          );
        });
      }
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

  Future<void> _syncOrderStatusSystemMessage() async {
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
    } catch (_) {}
  }

  String? _buildOrderStatusSystemText(String status) {
    switch (status) {
      case 'pending':
        return 'New order created. Awaiting restaurant confirmation.';
      case 'confirmed':
        return 'Restaurant confirmed the order.';
      case 'preparing':
        return 'Restaurant is preparing the order.';
      case 'ready':
        return 'Order is ready for pickup.';
      case 'picked_up':
        return 'You picked up the order.';
      case 'on_the_way':
        return 'You are on the way to the customer.';
      case 'delivered':
        return 'Order has been delivered.';
      case 'cancelled':
        return 'Order was cancelled.';
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
            if (!widget.isSupport)
              if (_connectionState == ChatSocketConnectionState.reconnecting ||
                  _connectionState == ChatSocketConnectionState.connecting)
                _buildConnectionBanner('Reconnecting to chat…', colors, isWarning: false)
              else if (_connectionState == ChatSocketConnectionState.disconnected)
                _buildConnectionBanner('Offline. Messages may be delayed.', colors, isWarning: true),

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
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final message = _messages[index];
                            final previous = index > 0 ? _messages[index - 1] : null;
                            final next = index < _messages.length - 1 ? _messages[index + 1] : null;
                            final showDateDivider = _shouldShowDateDivider(index);
                            final isFirstUnreadMessage = _firstUnreadIndex != null && index == _firstUnreadIndex;

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
                borderRadius: BorderRadius.only(
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
                  ),
                ],
              ),
            ),
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
              color: colors.accentGreen.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
            ),
            child: SvgPicture.asset(
              Assets.icons.deliveryTruck,
              package: 'grab_go_shared',
              width: 20.w,
              height: 20.w,
              colorFilter: ColorFilter.mode(colors.accentGreen, BlendMode.srcIn),
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
            onTap: _openDeliveryTracking,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: colors.accentGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(KBorderSize.borderRadius20),
              ),
              child: Row(
                children: [
                  SvgPicture.asset(
                    Assets.icons.mapPin,
                    package: 'grab_go_shared',
                    width: 16.w,
                    height: 16.w,
                    colorFilter: ColorFilter.mode(colors.accentGreen, BlendMode.srcIn),
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    'Track',
                    style: TextStyle(color: colors.accentGreen, fontSize: 12.sp, fontWeight: FontWeight.w600),
                  ),
                ],
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
              ? 'Read'
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
                color: isSent ? colors.accentGreen : colors.backgroundPrimary,
                borderRadius: BorderRadius.only(
                  topLeft: topLeft,
                  topRight: topRight,
                  bottomLeft: bottomLeft,
                  bottomRight: bottomRight,
                ),
                border: isSent ? null : Border.all(color: colors.border, width: 1),
              ),
              child: Text(
                message.text,
                style: TextStyle(
                  color: isSent ? Colors.white : colors.textPrimary,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w400,
                ),
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
                          valueColor: AlwaysStoppedAnimation<Color>(isSent ? Colors.white : colors.textSecondary),
                        ),
                      )
                    else if (message.isFailed)
                      Icon(Icons.error_outline, size: 14.w, color: isSent ? Colors.white : Colors.redAccent)
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
              ),
            ],
          ],
        ),
      ),
    );

    return GestureDetector(
      onTap: canRetry ? () => _retrySendMessage(message) : null,
      onLongPress: () => _showMessageActions(message, colors),
      behavior: HitTestBehavior.translucent,
      child: bubble,
    );
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
                leading: Icon(Icons.copy, color: colors.textPrimary, size: 20.w),
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
                  leading: Icon(Icons.refresh, color: colors.textPrimary, size: 20.w),
                  title: Text(
                    'Resend',
                    style: TextStyle(color: colors.textPrimary, fontSize: 14.sp, fontWeight: FontWeight.w500),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    _retrySendMessage(message);
                  },
                ),
              ListTile(
                leading: Icon(Icons.delete_outline, color: colors.textPrimary, size: 20.w),
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
