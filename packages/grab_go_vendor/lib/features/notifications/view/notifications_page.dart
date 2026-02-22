import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_vendor/features/notifications/view/notification_card.dart';
import 'package:grab_go_vendor/shared/widgets/app_filter_chip.dart';
import 'package:grab_go_vendor/features/notifications/view/notification_settings_page.dart';
import 'package:grab_go_vendor/features/notifications/viewmodel/notification_settings_viewmodel.dart';
import 'package:provider/provider.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => NotificationSettingsViewModel(),
      child: const _NotificationsView(),
    );
  }
}

class _NotificationsView extends StatefulWidget {
  const _NotificationsView();

  @override
  State<_NotificationsView> createState() => _NotificationsViewState();
}

class _NotificationsViewState extends State<_NotificationsView> {
  bool _showUnreadOnly = false;
  final ScrollController _historyScrollController = ScrollController();
  bool _showTopDivider = false;

  @override
  void initState() {
    super.initState();
    _historyScrollController.addListener(_handleScroll);
  }

  void _handleScroll() {
    if (!_historyScrollController.hasClients) return;
    final shouldShow = _historyScrollController.offset > 0.5;
    if (shouldShow == _showTopDivider) return;
    setState(() => _showTopDivider = shouldShow);
  }

  void _setUnreadOnly(bool value) {
    if (_showUnreadOnly == value) return;
    _showUnreadOnly = value;
    _showTopDivider = false;
    if (_historyScrollController.hasClients) {
      _historyScrollController.jumpTo(0);
    }
    setState(() {});
  }

  @override
  void dispose() {
    _historyScrollController.removeListener(_handleScroll);
    _historyScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Consumer<NotificationSettingsViewModel>(
      builder: (context, viewModel, _) {
        final entries = _showUnreadOnly
            ? viewModel.history.where((entry) => !entry.isRead).toList()
            : viewModel.history;

        return Scaffold(
          backgroundColor: colors.backgroundPrimary,
          body: SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(20.w, 6.h, 20.w, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      TextButton.icon(
                        onPressed: () => Navigator.of(context).maybePop(),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          foregroundColor: colors.textSecondary,
                        ),
                        icon: SvgPicture.asset(
                          Assets.icons.navArrowLeft,
                          package: 'grab_go_shared',
                          width: 18.w,
                          height: 18.w,
                          colorFilter: ColorFilter.mode(
                            colors.textSecondary,
                            BlendMode.srcIn,
                          ),
                        ),
                        label: Text(
                          'Back',
                          style: TextStyle(
                            color: colors.textSecondary,
                            fontSize: 14.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          TextButton(
                            onPressed: viewModel.unreadCount == 0
                                ? null
                                : viewModel.markAllHistoryRead,
                            child: Text(
                              'Mark all read',
                              style: TextStyle(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w700,
                                color: colors.vendorPrimaryBlue,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                CupertinoPageRoute(
                                  builder: (_) =>
                                      const NotificationSettingsPage(),
                                ),
                              );
                            },
                            child: Text(
                              'Settings',
                              style: TextStyle(
                                fontSize: 11.sp,
                                fontWeight: FontWeight.w700,
                                color: colors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  SizedBox(height: 6.h),
                  Text(
                    'Notifications',
                    style: TextStyle(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.w900,
                      color: colors.textPrimary,
                      height: 1.15,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Track operational alerts, customer updates, and critical events.',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500,
                      color: colors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Row(
                    children: [
                      AppFilterChip(
                        label: 'All',
                        selected: !_showUnreadOnly,
                        onTap: () => _setUnreadOnly(false),
                      ),
                      SizedBox(width: 8.w),
                      AppFilterChip(
                        label: 'Unread',
                        selected: _showUnreadOnly,
                        onTap: () => _setUnreadOnly(true),
                      ),
                    ],
                  ),
                  SizedBox(height: 10.h),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    height: _showTopDivider ? 1.h : 0,
                    color: colors.divider,
                  ),
                  SizedBox(height: 10.h),
                  Expanded(
                    child: entries.isEmpty
                        ? Center(
                            child: Text(
                              _showUnreadOnly
                                  ? 'No unread notifications.'
                                  : 'No notifications available.',
                              style: TextStyle(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w600,
                                color: colors.textSecondary,
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: _historyScrollController,
                            padding: EdgeInsets.only(bottom: 20.h),
                            itemCount: entries.length,
                            itemBuilder: (context, index) {
                              final entry = entries[index];
                              return NotificationCard(
                                entry: entry,
                                onTap: () => context
                                    .read<NotificationSettingsViewModel>()
                                    .markHistoryRead(entry.id),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
