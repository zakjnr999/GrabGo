import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/features/chat/service/chat_service.dart';
import 'package:grab_go_customer/shared/services/user_service.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:intl/intl.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

class ChatMessage {
  final String id;
  final String text;
  final DateTime timestamp;
  final bool isSentByMe;
  final bool isRead;

  ChatMessage({
    required this.id,
    required this.text,
    required this.timestamp,
    required this.isSentByMe,
    this.isRead = false,
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
  final UserService _userService = UserService();
  bool _isLoading = false;
  String? _error;
  String? _currentUserId;
  Timer? _pollingTimer;
  bool _hasPendingSend = false;
  IO.Socket? _socket;

  @override
  void initState() {
    super.initState();
    _initAndLoadMessages();
    if (!widget.isSupport) {
      _startPolling();
      _setupSocket();
    }
    _messageFocusNode.addListener(() {
      if (_messageFocusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 300), () {
          _scrollToBottom();
        });
      }
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _socket?.dispose();
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  Future<void> _initAndLoadMessages() async {
    setState(() {
      _isLoading = true;
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
          final loadedMessages = chatDetail.messages.map((m) {
            final isSentByMe = currentUserId != null && m.senderId == currentUserId;
            final isRead = currentUserId != null && m.readBy.contains(currentUserId);

            return ChatMessage(id: m.id, text: m.text, timestamp: m.sentAt, isSentByMe: isSentByMe, isRead: isRead);
          }).toList();

          setState(() {
            _messages = loadedMessages;
          });

          _scrollToBottom();
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load messages. Please try again.';
        _messages = [];
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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

  void _setupSocket() {
    if (widget.isSupport) return;

    final socketUrl = _buildSocketUrl();

    _socket = IO.io(socketUrl, IO.OptionBuilder().setTransports(['websocket']).disableAutoConnect().build());

    _socket!.onConnect((_) {
      _socket!.emit('chat:join', {'chatId': widget.chatId});
    });

    _socket!.on('chat:new_message', (data) {
      _handleIncomingSocketMessage(data);
    });

    _socket!.connect();
  }

  void _handleIncomingSocketMessage(dynamic data) {
    if (!mounted || widget.isSupport) return;
    if (data is! Map) return;

    final map = Map<String, dynamic>.from(data as Map);
    final payloadChatId = map['chatId']?.toString();
    if (payloadChatId != widget.chatId) return;

    final messageJson = map['message'];
    if (messageJson is! Map) return;

    final messageMap = Map<String, dynamic>.from(messageJson as Map);
    final id = messageMap['id']?.toString() ?? '';
    if (id.isEmpty) return;

    final exists = _messages.any((m) => m.id == id);
    if (exists) return;

    _currentUserId ??= _userService.getUserId();
    final senderId = messageMap['senderId']?.toString() ?? '';

    final msg = ChatMessage(
      id: id,
      text: messageMap['text']?.toString() ?? '',
      timestamp: DateTime.tryParse(messageMap['sentAt']?.toString() ?? '') ?? DateTime.now(),
      isSentByMe: _currentUserId != null && senderId == _currentUserId,
      isRead: _currentUserId != null && senderId == _currentUserId,
    );

    setState(() {
      _messages.add(msg);
    });

    _scrollToBottom();
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_isLoading && !_hasPendingSend && !widget.isSupport) {
        _refreshMessagesSilently();
      }
    });
  }

  Future<void> _refreshMessagesSilently() async {
    try {
      _currentUserId ??= _userService.getUserId();
      final chatDetail = await _chatService.getChat(widget.chatId);
      if (!mounted || chatDetail == null) return;

      final currentUserId = _currentUserId;
      final loadedMessages = chatDetail.messages.map((m) {
        final isSentByMe = currentUserId != null && m.senderId == currentUserId;
        final isRead = currentUserId != null && m.readBy.contains(currentUserId);

        return ChatMessage(id: m.id, text: m.text, timestamp: m.sentAt, isSentByMe: isSentByMe, isRead: isRead);
      }).toList();

      setState(() {
        _messages = loadedMessages;
        _error = null;
      });
    } catch (e) {
      // Silent fail during polling; keep current messages
    }
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

    _scrollToBottom();
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    if (widget.isSupport) {
      _appendLocalSupportMessage();
      return;
    }

    final text = _messageController.text.trim();
    _messageController.clear();

    final tempId = DateTime.now().millisecondsSinceEpoch.toString();
    final optimisticMessage = ChatMessage(
      id: tempId,
      text: text,
      timestamp: DateTime.now(),
      isSentByMe: true,
      isRead: false,
    );

    setState(() {
      _messages.add(optimisticMessage);
    });

    _scrollToBottom();

    _hasPendingSend = true;
    try {
      final sent = await _chatService.sendMessage(widget.chatId, text);
      if (!mounted || sent == null) return;

      final index = _messages.indexWhere((m) => m.id == tempId);
      if (index != -1) {
        final updated = ChatMessage(
          id: sent.id,
          text: sent.text,
          timestamp: sent.sentAt,
          isSentByMe: true,
          isRead: false,
        );

        setState(() {
          _messages[index] = updated;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _messages.removeWhere((m) => m.id == tempId);
      });
    } finally {
      _hasPendingSend = false;
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
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
                    if (widget.orderId != null)
                      Text(
                        widget.orderId!,
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
            Expanded(
              child: _isLoading
                  ? Center(
                      child: SizedBox(
                        width: 24.w,
                        height: 24.w,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(colors.accentOrange),
                        ),
                      ),
                    )
                  : _error != null
                  ? _buildErrorState(colors)
                  : ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
                      physics: const BouncingScrollPhysics(),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        final showDateDivider = _shouldShowDateDivider(index);

                        return Column(
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
                            _buildMessageBubble(message, colors, size),
                            SizedBox(height: 8.h),
                          ],
                        );
                      },
                    ),
            ),

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

  Widget _buildMessageBubble(ChatMessage message, AppColorsExtension colors, Size size) {
    final isSent = message.isSentByMe;

    return Align(
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
                  topLeft: Radius.circular(isSent ? 4 : KBorderSize.borderRadius12),
                  topRight: Radius.circular(isSent ? KBorderSize.borderRadius12 : 4),
                  bottomLeft: Radius.circular(isSent ? KBorderSize.borderRadius12 : 4),
                  bottomRight: Radius.circular(isSent ? 4 : KBorderSize.borderRadius12),
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
                  Icon(
                    message.isRead ? Icons.done_all : Icons.done,
                    size: 14.w,
                    color: message.isRead ? colors.accentOrange : colors.textSecondary,
                  ),
                ],
              ],
            ),
          ],
        ),
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
