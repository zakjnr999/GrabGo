import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:grab_go_rider/features/chat/view/chat_detail_page.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:intl/intl.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String lastMessage;
  final DateTime timestamp;
  final int unreadCount;
  final bool isOnline;
  final String? orderId;

  _ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.lastMessage,
    required this.timestamp,
    this.unreadCount = 0,
    this.isOnline = false,
    this.orderId,
  });
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _searchController = TextEditingController();
  List<_ChatMessage> _conversations = [];
  List<_ChatMessage> _filteredConversations = [];

  @override
  void initState() {
    super.initState();
    _loadConversations();
    _searchController.addListener(_filterConversations);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadConversations() {
    final now = DateTime.now();
    _conversations = [
      _ChatMessage(
        id: '1',
        senderId: 'customer1',
        senderName: 'Sarah Mensah',
        lastMessage: 'Hello, I\'m waiting for my order. Can you give me an update?',
        timestamp: now.subtract(const Duration(minutes: 5)),
        unreadCount: 2,
        isOnline: true,
        orderId: 'ORD-1234',
      ),
      _ChatMessage(
        id: '2',
        senderId: 'customer2',
        senderName: 'Kwame Asante',
        lastMessage: 'Thank you for the quick delivery!',
        timestamp: now.subtract(const Duration(hours: 1)),
        unreadCount: 0,
        isOnline: false,
        orderId: 'ORD-1235',
      ),
      _ChatMessage(
        id: '3',
        senderId: 'support',
        senderName: 'GrabGo Support',
        lastMessage: 'Your payment has been processed successfully.',
        timestamp: now.subtract(const Duration(hours: 2)),
        unreadCount: 1,
        isOnline: true,
      ),
      _ChatMessage(
        id: '4',
        senderId: 'customer3',
        senderName: 'Ama Owusu',
        lastMessage: 'I\'m at the gate. Where are you?',
        timestamp: now.subtract(const Duration(hours: 3)),
        unreadCount: 0,
        isOnline: false,
        orderId: 'ORD-1236',
      ),
      _ChatMessage(
        id: '5',
        senderId: 'customer4',
        senderName: 'John Kofi',
        lastMessage: 'The food arrived cold. Can you help?',
        timestamp: now.subtract(const Duration(days: 1)),
        unreadCount: 0,
        isOnline: false,
        orderId: 'ORD-1237',
      ),
      _ChatMessage(
        id: '6',
        senderId: 'customer5',
        senderName: 'Mary Adjei',
        lastMessage: 'Thanks for the tip! Really appreciate it.',
        timestamp: now.subtract(const Duration(days: 1, hours: 5)),
        unreadCount: 0,
        isOnline: false,
        orderId: 'ORD-1238',
      ),
      _ChatMessage(
        id: '7',
        senderId: 'customer6',
        senderName: 'David Tetteh',
        lastMessage: 'Can you confirm the delivery address?',
        timestamp: now.subtract(const Duration(days: 2)),
        unreadCount: 0,
        isOnline: false,
        orderId: 'ORD-1239',
      ),
    ];
    _filteredConversations = _conversations;
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
          actions: [
            IconButton(
              icon: SvgPicture.asset(
                Assets.icons.search,
                package: 'grab_go_shared',
                width: 24.w,
                height: 24.w,
                colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
              ),
              onPressed: () {},
            ),
            SizedBox(width: 8.w),
          ],
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

            // Conversations List
            Expanded(
              child: _filteredConversations.isEmpty
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

  Widget _buildConversationItem(_ChatMessage conversation, AppColorsExtension colors) {
    final isSupport = conversation.senderId == 'support';
    final hasUnread = conversation.unreadCount > 0;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatDetailPage(
              chatId: conversation.id,
              senderName: conversation.senderName,
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
                  child: Center(
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
                            conversation.orderId!,
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
                          conversation.lastMessage,
                          style: TextStyle(
                            color: hasUnread ? colors.textPrimary : colors.textSecondary,
                            fontSize: 14.sp,
                            fontWeight: hasUnread ? FontWeight.w500 : FontWeight.w400,
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
