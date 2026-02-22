import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_vendor/features/notifications/model/vendor_notification_models.dart';
import 'package:grab_go_vendor/features/notifications/viewmodel/notification_settings_viewmodel.dart';
import 'package:provider/provider.dart';

class NotificationSettingsPage extends StatelessWidget {
  const NotificationSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => NotificationSettingsViewModel(),
      child: const _NotificationSettingsView(),
    );
  }
}

class _NotificationSettingsView extends StatelessWidget {
  const _NotificationSettingsView();

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Consumer<NotificationSettingsViewModel>(
      builder: (context, viewModel, _) {
        return Scaffold(
          backgroundColor: colors.backgroundPrimary,
          appBar: AppBar(
            backgroundColor: colors.backgroundPrimary,
            elevation: 0,
            title: Text(
              'Notifications',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w800,
                color: colors.textPrimary,
              ),
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20.w, 12.h, 20.w, 24.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Manage alert preferences, quiet-hour controls, and notification history.',
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w500,
                      color: colors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 12.h),
                  _SectionCard(
                    title: 'Delivery Preferences',
                    child: Column(
                      children: [
                        _SwitchRow(
                          title: 'Push Notifications',
                          subtitle: 'Receive alerts when app is backgrounded',
                          value: viewModel.pushEnabled,
                          onChanged: viewModel.setPushEnabled,
                        ),
                        _SwitchRow(
                          title: 'In-App Alerts',
                          subtitle: 'Show realtime alerts while app is open',
                          value: viewModel.inAppEnabled,
                          onChanged: viewModel.setInAppEnabled,
                        ),
                        _SwitchRow(
                          title: 'Sound',
                          subtitle: 'Play sound for incoming notifications',
                          value: viewModel.soundEnabled,
                          onChanged: viewModel.setSoundEnabled,
                        ),
                        _SwitchRow(
                          title: 'Vibration',
                          subtitle: 'Vibrate device for notification events',
                          value: viewModel.vibrationEnabled,
                          onChanged: viewModel.setVibrationEnabled,
                        ),
                        _SwitchRow(
                          title: 'Message Preview',
                          subtitle: 'Show chat preview in lock-screen alerts',
                          value: viewModel.showMessagePreview,
                          onChanged: viewModel.setShowMessagePreview,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12.h),
                  _SectionCard(
                    title: 'Alert Channels',
                    child: Column(
                      children: viewModel.channelSettings.map((entry) {
                        final isLocked = entry.isCritical;
                        return _SwitchRow(
                          title: entry.channel.label,
                          subtitle: isLocked
                              ? '${entry.channel.subtitle} (critical channel)'
                              : entry.channel.subtitle,
                          value: entry.enabled,
                          onChanged: isLocked
                              ? (_) => _showLockedInfo(context)
                              : (value) => viewModel.setChannelEnabled(
                                  entry.channel,
                                  value,
                                ),
                        );
                      }).toList(),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  _SectionCard(
                    title: 'Quiet Hours',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SwitchRow(
                          title: 'Enable Quiet Hours',
                          subtitle:
                              'Non-critical alerts are silenced during this period',
                          value: viewModel.quietHoursEnabled,
                          onChanged: viewModel.setQuietHoursEnabled,
                        ),
                        if (viewModel.quietHoursEnabled) ...[
                          SizedBox(height: 8.h),
                          Row(
                            children: [
                              Expanded(
                                child: _TimeAction(
                                  label: 'Start',
                                  value: viewModel.formatTime(
                                    viewModel.quietStart,
                                  ),
                                  onTap: () => _pickTime(
                                    context,
                                    initial: viewModel.quietStart,
                                    onSelect: viewModel.setQuietStart,
                                  ),
                                ),
                              ),
                              SizedBox(width: 8.w),
                              Expanded(
                                child: _TimeAction(
                                  label: 'End',
                                  value: viewModel.formatTime(
                                    viewModel.quietEnd,
                                  ),
                                  onTap: () => _pickTime(
                                    context,
                                    initial: viewModel.quietEnd,
                                    onSelect: viewModel.setQuietEnd,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(height: 12.h),
                  _SectionCard(
                    title: 'Escalation Routing',
                    child: Column(
                      children: [
                        _SwitchRow(
                          title: 'Escalate At-Risk Orders',
                          subtitle: 'Trigger high-priority alerts for SLA risk',
                          value: viewModel.escalateAtRiskOrders,
                          onChanged: viewModel.setEscalateAtRiskOrders,
                        ),
                        _SwitchRow(
                          title: 'Escalate Unaccepted Orders',
                          subtitle:
                              'Alert when orders stay too long in new state',
                          value: viewModel.escalateUnacceptedOrders,
                          onChanged: viewModel.setEscalateUnacceptedOrders,
                        ),
                        _SwitchRow(
                          title: 'Escalate Offline Events',
                          subtitle:
                              'Alert when device disconnects from updates',
                          value: viewModel.escalateOfflineEvents,
                          onChanged: viewModel.setEscalateOfflineEvents,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12.h),
                  _SectionCard(
                    title: 'Test Alerts',
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  viewModel.addTestAlert(
                                    VendorNotificationSeverity.info,
                                  );
                                  _showTestSnack(
                                    context,
                                    'Info alert simulated',
                                  );
                                },
                                icon: Icon(
                                  Icons.notifications_none_rounded,
                                  size: 16.sp,
                                ),
                                label: const Text('Info'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: colors.vendorPrimaryBlue,
                                  side: BorderSide(
                                    color: colors.vendorPrimaryBlue.withValues(
                                      alpha: 0.4,
                                    ),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10.r),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  viewModel.addTestAlert(
                                    VendorNotificationSeverity.warning,
                                  );
                                  _showTestSnack(
                                    context,
                                    'Warning alert simulated',
                                  );
                                },
                                icon: Icon(
                                  Icons.warning_amber_rounded,
                                  size: 16.sp,
                                ),
                                label: const Text('Warning'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: colors.warning,
                                  side: BorderSide(
                                    color: colors.warning.withValues(
                                      alpha: 0.4,
                                    ),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10.r),
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () {
                                  viewModel.addTestAlert(
                                    VendorNotificationSeverity.critical,
                                  );
                                  _showTestSnack(
                                    context,
                                    'Critical alert simulated',
                                  );
                                },
                                icon: Icon(
                                  Icons.error_outline_rounded,
                                  size: 16.sp,
                                ),
                                label: const Text('Critical'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: colors.error,
                                  side: BorderSide(
                                    color: colors.error.withValues(alpha: 0.4),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10.r),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12.h),
                  _SectionCard(
                    title: 'Recent History',
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Text(
                              '${viewModel.unreadCount} unread',
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w700,
                                color: colors.textSecondary,
                              ),
                            ),
                            const Spacer(),
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
                          ],
                        ),
                        SizedBox(height: 8.h),
                        ...viewModel.history.map((entry) {
                          return _HistoryCard(entry: entry);
                        }),
                      ],
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

  Future<void> _pickTime(
    BuildContext context, {
    required TimeOfDay initial,
    required ValueChanged<TimeOfDay> onSelect,
  }) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (selected == null) return;
    onSelect(selected);
  }

  void _showLockedInfo(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Critical notification channels cannot be disabled.'),
      ),
    );
  }

  void _showTestSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
            ),
          ),
          SizedBox(height: 10.h),
          child,
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w500,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          CustomSwitch(
            value: value,
            onChanged: onChanged,
            activeColor: colors.vendorPrimaryBlue,
            inactiveColor: colors.inputBorder,
            thumbColor: colors.backgroundPrimary,
          ),
        ],
      ),
    );
  }
}

class _TimeAction extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _TimeAction({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: colors.textPrimary,
        side: BorderSide(color: colors.inputBorder),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.r),
        ),
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 9.h),
      ),
      child: Row(
        children: [
          Icon(Icons.access_time_rounded, size: 16.sp),
          SizedBox(width: 6.w),
          Expanded(
            child: Text(
              '$label: $value',
              style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final VendorNotificationHistoryItem entry;

  const _HistoryCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final color = switch (entry.severity) {
      VendorNotificationSeverity.info => colors.vendorPrimaryBlue,
      VendorNotificationSeverity.warning => colors.warning,
      VendorNotificationSeverity.critical => colors.error,
    };

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(bottom: 10.h),
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: entry.isRead ? colors.border : color.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10.w,
            height: 10.w,
            margin: EdgeInsets.only(top: 5.h),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.title,
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    if (!entry.isRead)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6.w,
                          vertical: 2.h,
                        ),
                        decoration: BoxDecoration(
                          color: colors.vendorPrimaryBlue.withValues(
                            alpha: 0.14,
                          ),
                          borderRadius: BorderRadius.circular(999.r),
                        ),
                        child: Text(
                          'New',
                          style: TextStyle(
                            fontSize: 9.sp,
                            fontWeight: FontWeight.w700,
                            color: colors.vendorPrimaryBlue,
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 4.h),
                Text(
                  entry.body,
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w500,
                    color: colors.textSecondary,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  entry.timeLabel,
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w700,
                    color: colors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
