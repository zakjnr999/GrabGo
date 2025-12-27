import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/features/status/view/story_viewer.dart';
import 'package:grab_go_customer/shared/services/notification_service.dart';
import 'package:grab_go_customer/shared/widgets/app_refresh_indicator.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:intl/intl.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_customer/shared/widgets/notification_skeleton.dart';
import 'dart:async';

class Actor {
  final String actorId;
  final String actorName;
  final String? actorAvatar;
  final DateTime reactedAt;

  Actor({required this.actorId, required this.actorName, this.actorAvatar, required this.reactedAt});

  factory Actor.fromJson(Map<String, dynamic> json) {
    return Actor(
      actorId: json['actorId'] ?? '',
      actorName: json['actorName'] ?? '',
      actorAvatar: json['actorAvatar'],
      reactedAt: json['reactedAt'] != null ? DateTime.parse(json['reactedAt']) : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'actorId': actorId,
      'actorName': actorName,
      'actorAvatar': actorAvatar,
      'reactedAt': reactedAt.toIso8601String(),
    };
  }
}

class NotificationModel {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final NotificationType type;
  final bool isRead;
  final Map<String, dynamic>? data;
  final List<Actor>? actors;
  final int actorCount;

  NotificationModel({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.type,
    this.isRead = false,
    this.data,
    this.actors,
    this.actorCount = 1,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    // Validate required fields
    final id = json['_id']?.toString() ?? json['id']?.toString() ?? '';
    if (id.isEmpty) {
      throw const FormatException('Notification ID cannot be empty');
    }

    final title = json['title']?.toString() ?? '';
    if (title.isEmpty) {
      throw const FormatException('Notification title cannot be empty');
    }

    final message = json['message']?.toString() ?? '';
    if (message.isEmpty) {
      throw const FormatException('Notification message cannot be empty');
    }

    return NotificationModel(
      id: id,
      title: title,
      message: message,
      timestamp: json['createdAt'] != null ? DateTime.parse(json['createdAt']) : DateTime.now(),
      type: _parseNotificationType(json['type']),
      isRead: json['isRead'] ?? false,
      data: json['data'],
      actors: json['actors'] != null ? (json['actors'] as List).map((a) => Actor.fromJson(a)).toList() : null,
      actorCount: json['actorCount'] ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'createdAt': timestamp.toIso8601String(),
      'type': type.toString().split('.').last,
      'isRead': isRead,
      'data': data,
      'actors': actors?.map((a) => a.toJson()).toList(),
      'actorCount': actorCount,
    };
  }

  /// Create a copy of this notification with updated fields
  NotificationModel copyWith({
    String? id,
    String? title,
    String? message,
    DateTime? timestamp,
    NotificationType? type,
    bool? isRead,
    Map<String, dynamic>? data,
    List<Actor>? actors,
    int? actorCount,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      isRead: isRead ?? this.isRead,
      data: data ?? this.data,
      actors: actors ?? this.actors,
      actorCount: actorCount ?? this.actorCount,
    );
  }

  static NotificationType _parseNotificationType(String? type) {
    if (type == null) {
      debugPrint('⚠️ Null notification type, defaulting to system');
      return NotificationType.system;
    }

    // Backend sends snake_case only
    switch (type) {
      case 'order':
        return NotificationType.order;
      case 'promo':
        return NotificationType.promo;
      case 'update':
        return NotificationType.update;
      case 'system':
        return NotificationType.system;
      case 'comment_reply':
        return NotificationType.commentReply;
      case 'comment_reaction':
        return NotificationType.commentReaction;
      default:
        debugPrint('⚠️ Unknown notification type: $type, defaulting to system');
        // TODO: Add crash reporting (Sentry/Firebase Crashlytics) for production
        // FirebaseCrashlytics.instance.log('Unknown notification type: $type');
        return NotificationType.system;
    }
  }
}

enum NotificationType { order, promo, update, system, commentReply, commentReaction }

class Notification extends StatefulWidget {
  const Notification({super.key});

  @override
  State<Notification> createState() => _NotificationState();
}

class _NotificationState extends State<Notification> {
  List<NotificationModel> _notifications = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  final int _pageSize = 20;
  String? _error;
  final ScrollController _scrollController = ScrollController();
  bool isSocketConnected = false;
  late final void Function(dynamic) _notificationListener;

  @override
  void initState() {
    super.initState();
    _notificationListener = _handleNewNotification;
    _loadInitialData();
    _scrollController.addListener(_onScroll);
    _setupSocketListener();
  }

  Future<void> _loadInitialData() async {
    try {
      final cached = await NotificationService().getLocalNotifications();
      if (cached.isNotEmpty && mounted) {
        setState(() {
          _notifications = cached;
        });
      }
    } catch (e) {
      debugPrint('Error loading cached notifications: $e');
    }
    _loadNotifications();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    SocketService().removeNotificationListener(_notificationListener);
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.8) {
      if (!_isLoadingMore && _hasMore) {
        _loadMoreNotifications();
      }
    }
  }

  void _setupSocketListener() {
    final socketService = SocketService();

    // Add the notification listener using the late final field
    socketService.addNotificationListener(_notificationListener);

    socketService.addConnectionListener((state) {
      if (!mounted) return;
      setState(() {
        isSocketConnected = state == SocketConnectionState.connected;
      });
    });
  }

  void _handleNewNotification(dynamic data) {
    if (!mounted) return;

    try {
      if (data is Map) {
        final notification = NotificationModel.fromJson(Map<String, dynamic>.from(data));

        setState(() {
          // Check if notification already exists (prevent duplicates)
          final exists = _notifications.any((n) => n.id == notification.id);
          if (!exists) {
            _notifications.insert(0, notification);
          }
        });
      }
    } catch (e) {
      debugPrint('Error processing new notification: $e');
    }
  }

  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _currentPage = 1;
    });

    try {
      final result = await NotificationService().getNotifications(limit: _pageSize, page: 1);
      if (mounted) {
        setState(() {
          // Backend now handles sorting (unread first, newest first)
          _notifications = result['notifications'] as List<NotificationModel>;
          _hasMore = result['hasMore'] as bool;
          _isLoading = false;
          _currentPage = 1;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = _notifications.isEmpty ? 'Failed to load notifications' : null;
        });
      }
    }
  }

  Future<void> _loadMoreNotifications() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final nextPage = _currentPage + 1;
      final result = await NotificationService().getNotifications(limit: _pageSize, page: nextPage);

      if (mounted) {
        setState(() {
          // Backend returns sorted data, just append
          _notifications.addAll(result['notifications'] as List<NotificationModel>);
          _hasMore = result['hasMore'] as bool;
          _currentPage = nextPage;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  Future<void> _markAsRead(String id) async {
    final success = await NotificationService().markAsRead(id);
    if (success) {
      setState(() {
        final index = _notifications.indexWhere((n) => n.id == id);
        if (index != -1) {
          _notifications[index] = _notifications[index].copyWith(isRead: true);
        }
      });
    }
  }

  Future<void> _markAllAsRead() async {
    final success = await NotificationService().markAllAsRead();
    if (success) {
      setState(() {
        _notifications = _notifications.map((notification) => notification.copyWith(isRead: true)).toList();
      });
    }
  }

  Future<void> _clearAll() async {
    final success = await NotificationService().clearAll();
    if (success) {
      setState(() {
        _notifications.clear();
      });
    }
  }

  String _getTimeAgo(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d').format(timestamp);
    }
  }

  void _showNavigationError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Unable to open notification: $message')));
  }

  Widget _buildNotificationIcon(NotificationType type, AppColorsExtension colors) {
    switch (type) {
      case NotificationType.order:
        return Container(
          padding: EdgeInsets.all(8.r),
          decoration: BoxDecoration(color: colors.accentOrange.withValues(alpha: 0.15), shape: BoxShape.circle),
          child: SvgPicture.asset(
            Assets.icons.cart,
            package: 'grab_go_shared',
            height: 20.h,
            width: 20.w,
            colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
          ),
        );
      case NotificationType.promo:
        return Container(
          padding: EdgeInsets.all(8.r),
          decoration: BoxDecoration(color: colors.accentViolet.withValues(alpha: 0.15), shape: BoxShape.circle),
          child: SvgPicture.asset(
            Assets.icons.badgePercent,
            package: 'grab_go_shared',
            height: 20.h,
            width: 20.w,
            colorFilter: ColorFilter.mode(colors.accentViolet, BlendMode.srcIn),
          ),
        );
      case NotificationType.update:
        return Container(
          padding: EdgeInsets.all(8.r),
          decoration: BoxDecoration(color: colors.accentBlue.withValues(alpha: 0.15), shape: BoxShape.circle),
          child: SvgPicture.asset(
            Assets.icons.bell,
            package: 'grab_go_shared',
            height: 20.h,
            width: 20.w,
            colorFilter: ColorFilter.mode(colors.accentBlue, BlendMode.srcIn),
          ),
        );
      case NotificationType.system:
        return Container(
          padding: EdgeInsets.all(8.r),
          decoration: BoxDecoration(color: colors.accentGreen.withValues(alpha: 0.15), shape: BoxShape.circle),
          child: SvgPicture.asset(
            Assets.icons.infoCircle,
            package: 'grab_go_shared',
            height: 20.h,
            width: 20.w,
            colorFilter: ColorFilter.mode(colors.accentGreen, BlendMode.srcIn),
          ),
        );
      case NotificationType.commentReply:
        return Container(
          padding: EdgeInsets.all(8.r),
          decoration: BoxDecoration(color: colors.accentBlue.withValues(alpha: 0.15), shape: BoxShape.circle),
          child: Icon(Icons.reply, size: 20.r, color: colors.accentBlue),
        );
      case NotificationType.commentReaction:
        return Container(
          padding: EdgeInsets.all(8.r),
          decoration: BoxDecoration(color: Colors.pink.withValues(alpha: 0.15), shape: BoxShape.circle),
          child: SvgPicture.asset(
            Assets.icons.emoji,
            package: 'grab_go_shared',
            height: 20.h,
            width: 20.w,
            colorFilter: const ColorFilter.mode(Colors.pink, BlendMode.srcIn),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: colors.backgroundSecondary,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: colors.backgroundPrimary,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: SafeArea(
        child: Scaffold(
          appBar: AppBar(
            elevation: 0,
            scrolledUnderElevation: 0,
            automaticallyImplyLeading: false,
            backgroundColor: colors.backgroundSecondary,
            title: Row(
              children: [
                Container(
                  height: 44.h,
                  width: 44.w,
                  decoration: BoxDecoration(
                    color: colors.backgroundPrimary,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.inputBorder.withValues(alpha: 0.3), width: 0.5),
                    boxShadow: [
                      BoxShadow(
                        color: isDark ? Colors.black.withAlpha(20) : Colors.black.withAlpha(5),
                        spreadRadius: 0,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => context.pop(),
                      customBorder: const CircleBorder(),
                      child: Padding(
                        padding: EdgeInsets.all(10.r),
                        child: SvgPicture.asset(
                          Assets.icons.navArrowLeft,
                          package: 'grab_go_shared',
                          colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
                        ),
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    color: colors.backgroundPrimary,
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(color: colors.inputBorder.withValues(alpha: 0.3), width: 0.5),
                    boxShadow: [
                      BoxShadow(
                        color: isDark ? Colors.black.withAlpha(20) : Colors.black.withAlpha(5),
                        spreadRadius: 0,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: EdgeInsets.all(6.r),
                        decoration: BoxDecoration(
                          color: colors.accentViolet.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: SvgPicture.asset(
                          Assets.icons.bell,
                          package: 'grab_go_shared',
                          height: 16.h,
                          width: 16.w,
                          colorFilter: ColorFilter.mode(colors.accentViolet, BlendMode.srcIn),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        AppStrings.notificationsTitle,
                        style: TextStyle(
                          fontFamily: "Lato",
                          package: 'grab_go_shared',
                          color: colors.textPrimary,
                          fontSize: 17.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                PopupMenuButton<String>(
                  icon: Container(
                    height: 44.h,
                    width: 44.w,
                    decoration: BoxDecoration(
                      color: colors.backgroundPrimary,
                      shape: BoxShape.circle,
                      border: Border.all(color: colors.inputBorder.withValues(alpha: 0.3), width: 0.5),
                      boxShadow: [
                        BoxShadow(
                          color: isDark ? Colors.black.withAlpha(20) : Colors.black.withAlpha(5),
                          spreadRadius: 0,
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(Icons.more_vert, size: 20, color: colors.textPrimary),
                  ),
                  onSelected: (value) {
                    if (value == 'mark_all_read') {
                      _markAllAsRead();
                    } else if (value == 'clear_all') {
                      _clearAll();
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'mark_all_read',
                      child: Text(
                        AppStrings.notificationsMarkAllRead,
                        style: TextStyle(fontSize: 14.sp, color: colors.textPrimary),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'clear_all',
                      child: Text(
                        AppStrings.notificationsClearAll,
                        style: TextStyle(fontSize: 14.sp, color: colors.error),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          backgroundColor: colors.backgroundSecondary,
          body: _isLoading && _notifications.isEmpty
              ? ListView.separated(
                  padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
                  itemCount: 8,
                  separatorBuilder: (context, index) => SizedBox(height: 12.h),
                  itemBuilder: (context, index) => NotificationSkeleton(colors: colors, isDark: isDark),
                )
              : _error != null
              ? NotificationSkeleton(colors: colors, isDark: isDark)
              : _notifications.isEmpty
              ? _buildEmptyState(colors)
              : AppRefreshIndicator(
                  onRefresh: _loadNotifications,
                  bgColor: colors.accentOrange,
                  iconPath: Assets.icons.bellNotification,
                  child: ListView.separated(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
                    itemCount: _notifications.length + (_isLoadingMore ? 1 : 0),
                    separatorBuilder: (context, index) => SizedBox(height: 12.h),
                    itemBuilder: (context, index) {
                      if (index == _notifications.length) {
                        return LoadingMore(
                          colors: colors,
                          spinnerColor: colors.accentOrange,
                          borderColor: colors.accentOrange,
                        );
                      }
                      final notification = _notifications[index];
                      return _buildNotificationCard(notification, colors, isDark);
                    },
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(AppColorsExtension colors) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(30.r),
            decoration: BoxDecoration(color: colors.accentViolet.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: SvgPicture.asset(
              Assets.icons.bell,
              package: 'grab_go_shared',
              height: 80.h,
              width: 80.w,
              colorFilter: ColorFilter.mode(colors.accentViolet.withValues(alpha: 0.5), BlendMode.srcIn),
            ),
          ),
          SizedBox(height: 24.h),
          Text(
            AppStrings.notificationsEmpty,
            style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w800, color: colors.textPrimary),
          ),
          SizedBox(height: 8.h),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 40.w),
            child: Text(
              AppStrings.notificationsEmptyMessage,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w500, color: colors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(NotificationModel notification, AppColorsExtension colors, bool isDark) {
    return GestureDetector(
      onTap: () {
        _markAsRead(notification.id);

        try {
          if (notification.type == NotificationType.commentReply ||
              notification.type == NotificationType.commentReaction) {
            final data = notification.data;
            if (data != null && data['restaurantId'] != null) {
              // Safe type conversion with validation
              final restaurantId = data['restaurantId']?.toString();
              final statusId = data['statusId']?.toString();

              if (restaurantId == null || restaurantId.isEmpty) {
                debugPrint('Invalid restaurantId in notification');
                _showNavigationError(context, 'Invalid restaurant ID');
                return;
              }

              if (statusId == null || statusId.isEmpty) {
                debugPrint('Invalid statusId in notification');
                _showNavigationError(context, 'Invalid status ID');
                return;
              }

              final restaurantName = data['restaurantName']?.toString() ?? 'Restaurant';
              final commentId = data['commentId']?.toString();
              final parentCommentId = data['parentCommentId']?.toString();
              final isReply = data['isReply'] == 'true' || data['isReply'] == true;

              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => StoryViewer(
                    restaurantId: restaurantId,
                    restaurantName: restaurantName,
                    targetCommentId: commentId,
                    targetStatusId: statusId,
                    parentCommentId: parentCommentId,
                    isReply: isReply,
                    highlightComment: true,
                  ),
                ),
              );
            }
          } else if (notification.type == NotificationType.order) {
            final data = notification.data;
            if (data != null && data['orderId'] != null) {
              final orderId = data['orderId']?.toString();
              if (orderId != null && orderId.isNotEmpty) {
                context.push('/order-tracking/$orderId');
              }
            }
          }
        } catch (e, stackTrace) {
          debugPrint('Error handling notification tap: $e');
          debugPrint('Stack trace: $stackTrace');
          _showNavigationError(context, 'Failed to open notification');
        }
      },
      child: Container(
        padding: EdgeInsets.all(16.r),
        decoration: BoxDecoration(
          color: notification.isRead ? colors.backgroundPrimary : colors.accentViolet.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
          border: Border.all(
            color: notification.isRead
                ? colors.inputBorder.withValues(alpha: 0.3)
                : colors.accentViolet.withValues(alpha: 0.2),
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withAlpha(30) : Colors.black.withAlpha(8),
              spreadRadius: 0,
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildNotificationIcon(notification.type, colors),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
                        ),
                      ),
                      if (!notification.isRead)
                        Container(
                          width: 8.w,
                          height: 8.h,
                          decoration: BoxDecoration(color: colors.accentViolet, shape: BoxShape.circle),
                        ),
                    ],
                  ),
                  SizedBox(height: 6.h),
                  // Show actor avatars for grouped notifications
                  if (notification.actorCount > 1 &&
                      notification.actors != null &&
                      notification.actors!.isNotEmpty) ...[
                    Row(
                      children: [
                        ...notification.actors!.take(3).map((actor) {
                          return Padding(
                            padding: EdgeInsets.only(right: 4.w),
                            child: CircleAvatar(
                              radius: 12.r,
                              backgroundImage: actor.actorAvatar != null && actor.actorAvatar!.isNotEmpty
                                  ? NetworkImage(actor.actorAvatar!)
                                  : null,
                              backgroundColor: colors.accentViolet.withValues(alpha: 0.2),
                              child: actor.actorAvatar == null || actor.actorAvatar!.isEmpty
                                  ? Text(
                                      actor.actorName.isNotEmpty ? actor.actorName[0].toUpperCase() : '?',
                                      style: TextStyle(
                                        fontSize: 10.sp,
                                        fontWeight: FontWeight.w600,
                                        color: colors.accentViolet,
                                      ),
                                    )
                                  : null,
                            ),
                          );
                        }),
                        if (notification.actorCount > 3)
                          Text(
                            '+${notification.actorCount - 3}',
                            style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w600, color: colors.textSecondary),
                          ),
                      ],
                    ),
                    SizedBox(height: 6.h),
                  ],
                  Text(
                    notification.message,
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500,
                      color: colors.textSecondary,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    _getTimeAgo(notification.timestamp),
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w500,
                      color: colors.textSecondary.withValues(alpha: 0.7),
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
}
