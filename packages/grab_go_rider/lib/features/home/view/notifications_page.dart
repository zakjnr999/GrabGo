import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_rider/features/home/models/notification_model.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:intl/intl.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  List<NotificationModel> _notifications = [];

  @override
  void initState() {
    super.initState();
    _loadSampleNotifications();
  }

  void _loadSampleNotifications() {
    final now = DateTime.now();
    _notifications = [
      NotificationModel(
        id: '1',
        title: 'New Delivery Request',
        message: 'You have a new delivery request to East Legon. Tap to view details.',
        timestamp: now.subtract(const Duration(minutes: 5)),
        type: NotificationType.delivery,
      ),
      NotificationModel(
        id: '2',
        title: 'Payment Received',
        message: 'GHC 25.50 has been added to your wallet from delivery #1234',
        timestamp: now.subtract(const Duration(hours: 1)),
        type: NotificationType.earnings,
      ),
      NotificationModel(
        id: '3',
        title: 'Delivery Completed',
        message: 'Your delivery to Cantonments has been completed successfully!',
        timestamp: now.subtract(const Duration(hours: 2)),
        type: NotificationType.delivery,
      ),
      NotificationModel(
        id: '4',
        title: 'Bonus Earned',
        message: 'You earned a weekend bonus of GHC 50.00! Keep up the great work.',
        timestamp: now.subtract(const Duration(hours: 5)),
        type: NotificationType.earnings,
      ),
      NotificationModel(
        id: '5',
        title: 'New Rating',
        message: 'You received a 5-star rating from a customer!',
        timestamp: now.subtract(const Duration(days: 1)),
        type: NotificationType.performance,
        isRead: true,
      ),
      NotificationModel(
        id: '6',
        title: 'System Update',
        message: 'We\'ve improved the app with new features! Update now to get the latest version.',
        timestamp: now.subtract(const Duration(days: 2)),
        type: NotificationType.system,
        isRead: true,
      ),
      NotificationModel(
        id: '7',
        title: 'Delivery Cancelled',
        message: 'Delivery #1232 has been cancelled by the customer.',
        timestamp: now.subtract(const Duration(days: 3)),
        type: NotificationType.delivery,
        isRead: true,
      ),
      NotificationModel(
        id: '8',
        title: 'Tip Received',
        message: 'You received a GHC 10.00 tip from a satisfied customer!',
        timestamp: now.subtract(const Duration(days: 4)),
        type: NotificationType.earnings,
        isRead: true,
      ),
      NotificationModel(
        id: '9',
        title: 'Milestone Achieved',
        message: 'Congratulations! You\'ve completed 100 deliveries. Keep it up!',
        timestamp: now.subtract(const Duration(days: 5)),
        type: NotificationType.performance,
        isRead: true,
      ),
    ];
  }

  void _markAsRead(String id) {
    setState(() {
      final index = _notifications.indexWhere((n) => n.id == id);
      if (index != -1) {
        _notifications[index] = NotificationModel(
          id: _notifications[index].id,
          title: _notifications[index].title,
          message: _notifications[index].message,
          timestamp: _notifications[index].timestamp,
          type: _notifications[index].type,
          isRead: true,
        );
      }
    });
  }

  void _markAllAsRead() {
    setState(() {
      _notifications = _notifications.map((notification) {
        return NotificationModel(
          id: notification.id,
          title: notification.title,
          message: notification.message,
          timestamp: notification.timestamp,
          type: notification.type,
          isRead: true,
        );
      }).toList();
    });
  }

  void _clearAll() {
    setState(() {
      _notifications.clear();
    });
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

  Widget _buildNotificationIcon(NotificationType type, AppColorsExtension colors) {
    switch (type) {
      case NotificationType.delivery:
        return Container(
          padding: EdgeInsets.all(8.r),
          decoration: BoxDecoration(color: colors.accentGreen.withValues(alpha: 0.15), shape: BoxShape.circle),
          child: SvgPicture.asset(
            Assets.icons.deliveryTruck,
            package: 'grab_go_shared',
            height: 20.h,
            width: 20.w,
            colorFilter: ColorFilter.mode(colors.accentGreen, BlendMode.srcIn),
          ),
        );
      case NotificationType.earnings:
        return Container(
          padding: EdgeInsets.all(8.r),
          decoration: BoxDecoration(color: colors.accentOrange.withValues(alpha: 0.15), shape: BoxShape.circle),
          child: SvgPicture.asset(
            Assets.icons.dollar,
            package: 'grab_go_shared',
            height: 20.h,
            width: 20.w,
            colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
          ),
        );
      case NotificationType.performance:
        return Container(
          padding: EdgeInsets.all(8.r),
          decoration: BoxDecoration(color: colors.accentViolet.withValues(alpha: 0.15), shape: BoxShape.circle),
          child: SvgPicture.asset(
            Assets.icons.star,
            package: 'grab_go_shared',
            height: 20.h,
            width: 20.w,
            colorFilter: ColorFilter.mode(colors.accentViolet, BlendMode.srcIn),
          ),
        );
      case NotificationType.system:
        return Container(
          padding: EdgeInsets.all(8.r),
          decoration: BoxDecoration(color: colors.accentBlue.withValues(alpha: 0.15), shape: BoxShape.circle),
          child: SvgPicture.asset(
            Assets.icons.infoCircle,
            package: 'grab_go_shared',
            height: 20.h,
            width: 20.w,
            colorFilter: ColorFilter.mode(colors.accentBlue, BlendMode.srcIn),
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
          scrolledUnderElevation: 0,
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
          title: Text(
            "Notifications",
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
            if (_notifications.isNotEmpty)
              PopupMenuButton<String>(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KBorderSize.borderRadius4)),
                popUpAnimationStyle: AnimationStyle(curve: Curves.easeIn),
                icon: Container(
                  padding: EdgeInsets.all(8.r),
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.border.withValues(alpha: 0.3), width: 1),
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
                    child: Row(
                      children: [
                        Icon(Icons.done_all, size: 18, color: colors.textPrimary),
                        SizedBox(width: 8.w),
                        Text(
                          "Mark all as read",
                          style: TextStyle(fontSize: 14.sp, color: colors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'clear_all',
                    child: Row(
                      children: [
                        SvgPicture.asset(Assets.icons.binMinusIn, package: "grab_go_shared", height: 22.h, width: 22.w),
                        SizedBox(width: 8.w),
                        Text(
                          "Clear all",
                          style: TextStyle(fontSize: 14.sp, color: colors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
        body: _notifications.isEmpty
            ? _buildEmptyState(colors)
            : ListView.separated(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
                itemCount: _notifications.length,
                separatorBuilder: (context, index) => SizedBox(height: 12.h),
                itemBuilder: (context, index) {
                  final notification = _notifications[index];
                  return _buildNotificationItem(notification, colors);
                },
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
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(color: colors.backgroundPrimary, shape: BoxShape.circle),
            child: SvgPicture.asset(
              Assets.icons.bell,
              package: 'grab_go_shared',
              width: 48.w,
              height: 48.w,
              colorFilter: ColorFilter.mode(colors.textSecondary.withValues(alpha: 0.5), BlendMode.srcIn),
            ),
          ),
          SizedBox(height: 24.h),
          Text(
            "No notifications",
            style: TextStyle(color: colors.textPrimary, fontSize: 18.sp, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 8.h),
          Text(
            "You're all caught up! Check back later for updates.",
            textAlign: TextAlign.center,
            style: TextStyle(color: colors.textSecondary, fontSize: 14.sp, fontWeight: FontWeight.w400),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(NotificationModel notification, AppColorsExtension colors) {
    return InkWell(
      onTap: () {
        if (!notification.isRead) {
          _markAsRead(notification.id);
        }
      },
      borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: notification.isRead ? colors.backgroundPrimary : colors.accentGreen.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
          border: Border.all(
            color: notification.isRead
                ? colors.border.withValues(alpha: 0.3)
                : colors.accentGreen.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildNotificationIcon(notification.type, colors),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          notification.title,
                          style: TextStyle(
                            color: colors.textPrimary,
                            fontSize: 15.sp,
                            fontWeight: notification.isRead ? FontWeight.w600 : FontWeight.w700,
                          ),
                        ),
                      ),
                      if (!notification.isRead)
                        Container(
                          width: 8.w,
                          height: 8.w,
                          decoration: BoxDecoration(color: colors.accentGreen, shape: BoxShape.circle),
                        ),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    notification.message,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w400,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    _getTimeAgo(notification.timestamp),
                    style: TextStyle(
                      color: colors.textSecondary.withValues(alpha: 0.7),
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w400,
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
