import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:grab_go_rider/features/chat/view/chat_detail_page.dart';
import 'package:grab_go_rider/shared/service/user_service.dart';
import 'package:grab_go_rider/shared/viewmodel/bottom_nav_provider.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String? profilePicture;
  final String lastMessage;
  final DateTime timestamp;
  final int unreadCount;
  final bool isOnline;
  final String? orderId;
  final bool isTyping;

  _ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.profilePicture,
    required this.lastMessage,
    required this.timestamp,
    this.unreadCount = 0,
    this.isOnline = false,
    this.orderId,
    this.isTyping = false,
  });
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _searchController = TextEditingController();
  List<_ChatMessage> _conversations = [];
  List<_ChatMessage> _filteredConversations = [];
  final ChatService _chatService = ChatService();
  final UserService _userService = UserService();
  bool _isLoading = true;
  bool _hasAttemptedLoad = false;
  Timer? _pollingTimer;
  String? _currentUserId;
  SocketConnectionState _connectionState = SocketConnectionState.disconnected;

  @override
  void initState() {
    super.initState();
    _loadCachedConversations();
    _loadConversations();
    _startPolling();
    _searchController.addListener(_filterConversations);

    final chatSocket = SocketService();
    chatSocket.addConnectionListener(_handleConnectionStateChanged);
    chatSocket.addNewMessageListener(_handleNewMessageEvent);
    chatSocket.addPresenceListener(_handlePresenceEvent);
    chatSocket.addTypingListener(_handleTypingEvent);
    chatSocket.addReadListener(_handleReadEvent);
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    final chatSocket = SocketService();
    chatSocket.removeConnectionListener(_handleConnectionStateChanged);
    chatSocket.removeNewMessageListener(_handleNewMessageEvent);
    chatSocket.removePresenceListener(_handlePresenceEvent);
    chatSocket.removeTypingListener(_handleTypingEvent);
    chatSocket.removeReadListener(_handleReadEvent);
    _searchController.dispose();
    super.dispose();
  }

  void _loadConversations() {
    final hasCached = _conversations.isNotEmpty;
    _fetchConversations(showLoader: !hasCached);
  }

  void _loadCachedConversations() {
    try {
      final cached = CacheService.getChatList();
      if (cached.isEmpty) return;

      final List<_ChatMessage> loaded = [];
      for (final chat in cached) {
        final id = chat['id']?.toString() ?? '';
        if (id.isEmpty) continue;
        // Skip support chat
        if (id == 'support') continue;
        final senderId = chat['senderId']?.toString() ?? 'unknown_user';
        // Skip support chat by senderId
        if (senderId == 'support') continue;
        final senderName = chat['senderName']?.toString() ?? 'User';
        final profilePicture = chat['profilePicture']?.toString();
        final lastMessage = chat['lastMessage']?.toString() ?? '';
        final tsStr = chat['timestamp']?.toString();
        final timestamp = DateTime.tryParse(tsStr ?? '') ?? DateTime.now();
        final unreadRaw = chat['unreadCount'];
        final unreadCount = unreadRaw is int ? unreadRaw : int.tryParse(unreadRaw?.toString() ?? '0') ?? 0;
        final isOnline = chat['isOnline'] == true;
        final orderId = chat['orderId']?.toString();
        final isTyping = chat['isTyping'] == true;

        loaded.add(
          _ChatMessage(
            id: id,
            senderId: senderId,
            senderName: senderName,
            profilePicture: profilePicture,
            lastMessage: lastMessage,
            timestamp: timestamp,
            unreadCount: unreadCount,
            isOnline: isOnline,
            orderId: orderId,
            isTyping: isTyping,
          ),
        );
      }

      if (loaded.isEmpty) return;

      _conversations = loaded;
      _filteredConversations = loaded;
      _isLoading = false;

      setState(() {});

      // Join all chat rooms to receive presence updates
      SocketService().updateKnownChats(loaded.map((c) => c.id).toList(), forceRejoin: true);

      _resortAndFilterConversations(applySearch: false);
    } catch (e) {
      // Silent fail - cache loading is optional
    }
  }

  void _cacheConversations() {
    final chatList = _conversations
        .where((c) => c.id.isNotEmpty)
        .map(
          (c) => {
            'id': c.id,
            'senderId': c.senderId,
            'senderName': c.senderName,
            'profilePicture': c.profilePicture,
            'lastMessage': c.lastMessage,
            'timestamp': c.timestamp.toIso8601String(),
            'unreadCount': c.unreadCount,
            'isOnline': c.isOnline,
            'orderId': c.orderId,
            'isTyping': c.isTyping,
          },
        )
        .toList();
    CacheService.saveChatList(chatList);
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (!_isLoading) {
        _refreshConversationsSilently();
      }
    });
  }

  void _handleConnectionStateChanged(SocketConnectionState state) {
    if (!mounted) return;
    setState(() {
      _connectionState = state;
    });
  }

  void _markChatAsRead(String chatId) {
    bool changed = false;
    int cleared = 0;
    _conversations = _conversations.map((c) {
      if (c.id != chatId) return c;
      if (c.unreadCount == 0 && !c.isTyping) return c;
      changed = true;
      cleared = c.unreadCount;
      return _ChatMessage(
        id: c.id,
        senderId: c.senderId,
        senderName: c.senderName,
        profilePicture: c.profilePicture,
        lastMessage: c.lastMessage,
        timestamp: c.timestamp,
        unreadCount: 0,
        isOnline: c.isOnline,
        orderId: c.orderId,
        isTyping: false,
      );
    }).toList();

    if (!changed) return;
    if (cleared > 0) {
      SocketService().markChatAsReadLocally(chatId, cleared);
    }
    _resortAndFilterConversations();
  }

  Future<void> _fetchConversations({bool showLoader = true}) async {
    if (showLoader) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final apiChats = await _chatService.getChats();

      // Build a map of existing online/typing status to preserve
      final existingStatus = <String, ({bool isOnline, bool isTyping})>{};
      for (final c in _conversations) {
        existingStatus[c.id] = (isOnline: c.isOnline, isTyping: c.isTyping);
      }

      final List<_ChatMessage> loaded = apiChats.map((chat) {
        final senderId = chat.otherUserId ?? 'unknown_user';
        final senderName = chat.otherUserName ?? (chat.otherUserRole == 'customer' ? 'Customer' : 'User');
        final existing = existingStatus[chat.id];

        return _ChatMessage(
          id: chat.id,
          senderId: senderId,
          senderName: senderName,
          profilePicture: chat.otherUserProfilePicture,
          lastMessage: chat.lastMessage,
          timestamp: chat.lastMessageAt,
          unreadCount: chat.unreadCount,
          isOnline: existing?.isOnline ?? false,
          orderId: chat.orderNumber,
          isTyping: existing?.isTyping ?? false,
        );
      }).toList();

      // Support chat removed - will be implemented separately
      _conversations = loaded;
      _filteredConversations = _conversations;
      _cacheConversations(); // Cache for offline access
      SocketService().updateKnownChats(_conversations.map((c) => c.id).toList(), forceRejoin: true);
    } catch (e) {
      // Silent fail - show cached data or empty state
    } finally {
      if (mounted) {
        setState(() {
          _hasAttemptedLoad = true;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshConversationsSilently() async {
    try {
      final apiChats = await _chatService.getChats();

      // Build a map of existing online/typing status to preserve
      final existingStatus = <String, ({bool isOnline, bool isTyping})>{};
      for (final c in _conversations) {
        existingStatus[c.id] = (isOnline: c.isOnline, isTyping: c.isTyping);
      }

      final List<_ChatMessage> loaded = apiChats.map((chat) {
        final senderId = chat.otherUserId ?? 'unknown_user';
        final senderName = chat.otherUserName ?? (chat.otherUserRole == 'customer' ? 'Customer' : 'User');
        final existing = existingStatus[chat.id];

        return _ChatMessage(
          id: chat.id,
          senderId: senderId,
          senderName: senderName,
          profilePicture: chat.otherUserProfilePicture,
          lastMessage: chat.lastMessage,
          timestamp: chat.lastMessageAt,
          unreadCount: chat.unreadCount,
          isOnline: existing?.isOnline ?? false,
          orderId: chat.orderNumber,
          isTyping: existing?.isTyping ?? false,
        );
      }).toList();

      // Support chat removed - will be implemented separately

      if (!mounted) return;

      final query = _searchController.text.toLowerCase();

      setState(() {
        _conversations = loaded;
        if (query.isEmpty) {
          _filteredConversations = loaded;
        } else {
          _filteredConversations = loaded
              .where(
                (chat) =>
                    chat.senderName.toLowerCase().contains(query) || chat.lastMessage.toLowerCase().contains(query),
              )
              .toList();
        }
      });
      _cacheConversations(); // Cache for offline access
      SocketService().updateKnownChats(loaded.map((c) => c.id).toList(), forceRejoin: true);
    } catch (e) {
      // Silent fail on polling; keep current cached data
    }
  }

  void _handleNewMessageEvent(dynamic data) {
    if (!mounted) return;
    final route = ModalRoute.of(context);
    if (route == null || !route.isCurrent) return;
    if (data is! Map) return;

    final map = Map<String, dynamic>.from(data as Map);
    final chatId = map['chatId']?.toString();
    if (chatId == null) return;

    final messageJson = map['message'];
    if (messageJson is! Map) return;

    final messageMap = Map<String, dynamic>.from(messageJson as Map);
    final text = messageMap['text']?.toString() ?? '';
    final sentAtStr = messageMap['sentAt']?.toString();
    final sentAt = DateTime.tryParse(sentAtStr ?? '') ?? DateTime.now();
    final senderId = messageMap['senderId']?.toString() ?? '';

    _currentUserId ??= _userService.currentUser?.id;
    final isFromMe = _currentUserId != null && senderId == _currentUserId;

    final index = _conversations.indexWhere((c) => c.id == chatId);
    if (index == -1) return;

    final convo = _conversations[index];
    final newUnread = isFromMe ? convo.unreadCount : convo.unreadCount + 1;

    _conversations[index] = _ChatMessage(
      id: convo.id,
      senderId: convo.senderId,
      senderName: convo.senderName,
      profilePicture: convo.profilePicture,
      lastMessage: text,
      timestamp: sentAt,
      unreadCount: newUnread,
      isOnline: !isFromMe ? true : convo.isOnline,
      orderId: convo.orderId,
      isTyping: false,
    );

    _resortAndFilterConversations();
  }

  void _handlePresenceEvent(dynamic data) {
    if (!mounted) return;
    if (data is! Map) return;

    final map = Map<String, dynamic>.from(data as Map);
    final chatId = map['chatId']?.toString();
    final userId = map['userId']?.toString();
    if (chatId == null || userId == null) return;

    _currentUserId ??= _userService.currentUser?.id;
    if (_currentUserId != null && userId == _currentUserId) return;

    final online = map['online'] == true;
    final index = _conversations.indexWhere((c) => c.id == chatId);
    if (index == -1) return;

    final convo = _conversations[index];
    _conversations[index] = _ChatMessage(
      id: convo.id,
      senderId: convo.senderId,
      senderName: convo.senderName,
      profilePicture: convo.profilePicture,
      lastMessage: convo.lastMessage,
      timestamp: convo.timestamp,
      unreadCount: convo.unreadCount,
      isOnline: online,
      orderId: convo.orderId,
      isTyping: online ? convo.isTyping : false,
    );

    _resortAndFilterConversations(applySearch: false);
  }

  void _handleReadEvent(dynamic data) {
    if (!mounted) return;
    if (data is! Map) return;

    final map = Map<String, dynamic>.from(data as Map);
    final chatId = map['chatId']?.toString();
    final userId = map['userId']?.toString();
    if (chatId == null || userId == null) return;

    _currentUserId ??= _userService.currentUser?.id;
    if (_currentUserId == null || userId != _currentUserId) return;

    final index = _conversations.indexWhere((c) => c.id == chatId);
    if (index == -1) return;

    final convo = _conversations[index];
    if (convo.unreadCount == 0 && !convo.isTyping) return;

    _conversations[index] = _ChatMessage(
      id: convo.id,
      senderId: convo.senderId,
      senderName: convo.senderName,
      profilePicture: convo.profilePicture,
      lastMessage: convo.lastMessage,
      timestamp: convo.timestamp,
      unreadCount: 0,
      isOnline: convo.isOnline,
      orderId: convo.orderId,
      isTyping: false,
    );

    _resortAndFilterConversations(applySearch: false);
  }

  void _handleTypingEvent(dynamic data) {
    if (!mounted) return;
    final route = ModalRoute.of(context);
    if (route == null || !route.isCurrent) return;
    if (data is! Map) return;

    final map = Map<String, dynamic>.from(data as Map);
    final chatId = map['chatId']?.toString();
    final userId = map['userId']?.toString();
    if (chatId == null || userId == null) return;

    _currentUserId ??= _userService.currentUser?.id;
    if (_currentUserId != null && userId == _currentUserId) return;

    final isTyping = map['isTyping'] == true;
    final index = _conversations.indexWhere((c) => c.id == chatId);
    if (index == -1) return;

    final convo = _conversations[index];
    _conversations[index] = _ChatMessage(
      id: convo.id,
      senderId: convo.senderId,
      senderName: convo.senderName,
      profilePicture: convo.profilePicture,
      lastMessage: convo.lastMessage,
      timestamp: convo.timestamp,
      unreadCount: convo.unreadCount,
      isOnline: isTyping ? true : convo.isOnline,
      orderId: convo.orderId,
      isTyping: isTyping,
    );

    _resortAndFilterConversations(applySearch: false);
  }

  void _resortAndFilterConversations({bool applySearch = true}) {
    if (_conversations.isEmpty) return;

    _conversations.sort((a, b) {
      return b.timestamp.compareTo(a.timestamp);
    });

    final query = _searchController.text.toLowerCase();

    setState(() {
      if (!applySearch || query.isEmpty) {
        _filteredConversations = List<_ChatMessage>.from(_conversations);
      } else {
        _filteredConversations = _conversations
            .where(
              (chat) => chat.senderName.toLowerCase().contains(query) || chat.lastMessage.toLowerCase().contains(query),
            )
            .toList();
      }
    });

    // Update global unread badge for Chats tab (deferred to avoid build-phase conflicts)
    final totalUnread = _conversations.fold<int>(0, (sum, c) => sum + (c.unreadCount > 0 ? c.unreadCount : 0));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Provider.of<BottomNavProvider>(context, listen: false).setChatUnreadCount(totalUnread);
    });

    final serialized = _conversations
        .map(
          (c) => {
            'id': c.id,
            'senderId': c.senderId,
            'senderName': c.senderName,
            'lastMessage': c.lastMessage,
            'timestamp': c.timestamp.toIso8601String(),
            'unreadCount': c.unreadCount,
            'isOnline': c.isOnline,
            'orderId': c.orderId,
            'isTyping': c.isTyping,
          },
        )
        .toList();
    unawaited(CacheService.saveChatList(serialized));
  }

  void _filterConversations() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredConversations = _conversations;
      } else {
        _filteredConversations = _conversations
            .where(
              (chat) => chat.senderName.toLowerCase().contains(query) || chat.lastMessage.toLowerCase().contains(query),
            )
            .toList();
      }
    });
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return DateFormat('EEE').format(timestamp);
    } else {
      return DateFormat('MMM dd').format(timestamp);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
          title: Text(
            "Messages",
            style: TextStyle(
              fontFamily: "Lato",
              package: "grab_go_shared",
              color: colors.textPrimary,
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          centerTitle: true,
        ),
        body: Column(
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
              color: colors.backgroundPrimary,
              child: Container(
                decoration: BoxDecoration(
                  color: colors.backgroundSecondary,
                  borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                  border: Border.all(color: colors.border, width: 1),
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: "Search conversations...",
                    hintStyle: TextStyle(color: colors.textSecondary.withValues(alpha: 0.6), fontSize: 14.sp),
                    prefixIcon: Padding(
                      padding: EdgeInsets.all(12.w),
                      child: SvgPicture.asset(
                        Assets.icons.search,
                        package: 'grab_go_shared',
                        width: 20.w,
                        height: 20.w,
                        colorFilter: ColorFilter.mode(colors.textSecondary.withValues(alpha: 0.6), BlendMode.srcIn),
                      ),
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, size: 20.w, color: colors.textSecondary),
                            onPressed: () {
                              _searchController.clear();
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
                  ),
                  style: TextStyle(color: colors.textPrimary, fontSize: 14.sp),
                ),
              ),
            ),

            if (_connectionState == SocketConnectionState.reconnecting ||
                _connectionState == SocketConnectionState.connecting)
              _buildConnectionBanner('Reconnecting to chat…', colors, isWarning: false)
            else if (_connectionState == SocketConnectionState.disconnected)
              _buildConnectionBanner('Offline. Messages may be delayed.', colors, isWarning: true),

            // Conversations List
            Expanded(
              child: _isLoading
                  ? Center(
                      child: SizedBox(
                        width: 24.w,
                        height: 24.w,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(colors.accentGreen),
                        ),
                      ),
                    )
                  : _filteredConversations.isEmpty && !_hasAttemptedLoad
                  ? const SizedBox.shrink()
                  : _filteredConversations.isEmpty
                  ? _buildEmptyState(colors)
                  : ListView.separated(
                      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                      physics: const BouncingScrollPhysics(),
                      itemCount: _filteredConversations.length,
                      separatorBuilder: (context, index) => SizedBox(height: 8.h),
                      itemBuilder: (context, index) {
                        final conversation = _filteredConversations[index];
                        return _buildConversationItem(conversation, colors);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
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

  Widget _buildConversationItem(_ChatMessage conversation, AppColorsExtension colors) {
    final isSupport = conversation.senderId == 'support';
    final hasUnread = conversation.unreadCount > 0;

    return GestureDetector(
      onTap: () {
        _markChatAsRead(conversation.id);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatDetailPage(
              chatId: conversation.id,
              senderName: conversation.senderName,
              profilePicture: conversation.profilePicture,
              orderId: conversation.orderId,
              isSupport: conversation.senderId == 'support',
            ),
          ),
        );
      },
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: colors.backgroundPrimary,
          borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
          border: Border.all(
            color: hasUnread ? colors.accentGreen.withValues(alpha: 0.3) : colors.border,
            width: hasUnread ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Avatar
            Stack(
              children: [
                Container(
                  width: 56.w,
                  height: 56.w,
                  decoration: BoxDecoration(
                    color: isSupport
                        ? colors.accentViolet.withValues(alpha: 0.1)
                        : colors.accentGreen.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: ClipOval(
                    child: conversation.profilePicture != null && conversation.profilePicture!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: conversation.profilePicture!,
                            width: 56.w,
                            height: 56.w,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Center(
                              child: SvgPicture.asset(
                                Assets.icons.user,
                                package: 'grab_go_shared',
                                width: 28.w,
                                height: 28.w,
                                colorFilter: ColorFilter.mode(colors.accentGreen, BlendMode.srcIn),
                              ),
                            ),
                            errorWidget: (context, url, error) => Center(
                              child: SvgPicture.asset(
                                Assets.icons.user,
                                package: 'grab_go_shared',
                                width: 28.w,
                                height: 28.w,
                                colorFilter: ColorFilter.mode(colors.accentGreen, BlendMode.srcIn),
                              ),
                            ),
                          )
                        : Center(
                            child: SvgPicture.asset(
                              isSupport ? Assets.icons.headsetHelp : Assets.icons.user,
                              package: 'grab_go_shared',
                              width: 28.w,
                              height: 28.w,
                              colorFilter: ColorFilter.mode(
                                isSupport ? colors.accentViolet : colors.accentGreen,
                                BlendMode.srcIn,
                              ),
                            ),
                          ),
                  ),
                ),
                if (conversation.isOnline)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 14.w,
                      height: 14.w,
                      decoration: BoxDecoration(
                        color: colors.accentGreen,
                        shape: BoxShape.circle,
                        border: Border.all(color: colors.backgroundPrimary, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversation.senderName,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 16.sp,
                            fontWeight: hasUnread ? FontWeight.w700 : FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (conversation.orderId != null) ...[
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                          decoration: BoxDecoration(
                            color: colors.accentGreen.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            conversation.orderId!.substring(0, 8),
                            style: TextStyle(color: colors.accentGreen, fontSize: 10.sp, fontWeight: FontWeight.w600),
                          ),
                        ),
                        SizedBox(width: 8.w),
                      ],
                      Text(
                        _formatTimestamp(conversation.timestamp),
                        style: TextStyle(color: colors.textSecondary, fontSize: 12.sp, fontWeight: FontWeight.w400),
                      ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversation.isTyping ? 'Typing...' : conversation.lastMessage,
                          style: TextStyle(
                            color: conversation.isTyping
                                ? colors.accentGreen
                                : (hasUnread ? colors.textPrimary : colors.textSecondary),
                            fontSize: 14.sp,
                            fontWeight: conversation.isTyping
                                ? FontWeight.w500
                                : (hasUnread ? FontWeight.w500 : FontWeight.w400),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hasUnread) ...[
                        SizedBox(width: 8.w),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                          decoration: BoxDecoration(color: colors.accentGreen, shape: BoxShape.circle),
                          child: Center(
                            child: Text(
                              conversation.unreadCount > 9 ? '9+' : conversation.unreadCount.toString(),
                              style: TextStyle(color: Colors.white, fontSize: 11.sp, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(AppColorsExtension colors) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(40.w),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120.w,
              height: 120.w,
              decoration: BoxDecoration(color: colors.backgroundPrimary, shape: BoxShape.circle),
              child: Center(
                child: SvgPicture.asset(
                  Assets.icons.chatBubble,
                  package: 'grab_go_shared',
                  width: 60.w,
                  height: 60.w,
                  colorFilter: ColorFilter.mode(colors.textSecondary.withValues(alpha: 0.5), BlendMode.srcIn),
                ),
              ),
            ),
            SizedBox(height: 24.h),
            Text(
              "No conversations found",
              style: TextStyle(color: colors.textPrimary, fontSize: 18.sp, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8.h),
            Text(
              "Start a conversation with customers or support",
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textSecondary, fontSize: 14.sp, fontWeight: FontWeight.w400),
            ),
          ],
        ),
      ),
    );
  }
}
