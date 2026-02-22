import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_vendor/features/analytics/view/basic_analytics_page.dart';
import 'package:grab_go_vendor/features/finance/view/finance_center_page.dart';
import 'package:grab_go_vendor/features/growth/view/growth_center_page.dart';
import 'package:grab_go_vendor/features/help/view/help_center_page.dart';
import 'package:grab_go_vendor/features/integrations/view/integrations_center_page.dart';
import 'package:grab_go_vendor/features/onboarding/viewmodel/onboarding_setup_viewmodel.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_vendor/features/notifications/view/notification_settings_page.dart';
import 'package:grab_go_vendor/features/profile/view/profile_security_page.dart';
import 'package:grab_go_vendor/features/scheduling/view/scheduling_center_page.dart';
import 'package:grab_go_vendor/features/staff/view/staff_management_page.dart';
import 'package:grab_go_vendor/features/store_operations/view/store_operations_page.dart';
import 'package:grab_go_vendor/features/store_operations/viewmodel/store_operations_viewmodel.dart';
import 'package:grab_go_vendor/shared/viewmodel/vendor_preview_session_viewmodel.dart';
import 'package:provider/provider.dart';

class MoreTab extends StatelessWidget {
  const MoreTab({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final previewSession = context.watch<VendorPreviewSessionViewModel>();
    final onboardingSetup = context.watch<OnboardingSetupViewModel>();

    return SafeArea(
      child: ListView(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
        children: [
          Text(
            'More',
            style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.w900, color: colors.textPrimary),
          ),
          Text(
            'Operations tools, team settings and account controls.',
            style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w500, color: colors.textSecondary),
          ),
          SizedBox(height: 14.h),
          _MoreOptionTile(
            icon: Icons.switch_account_outlined,
            title: 'Switch Preview Vendor',
            subtitle: '${previewSession.activeProfile.title} • ${previewSession.allowedServicesLabel}',
            onTap: () => context.push('/vendorPreview', extra: {'returnToPrevious': true}),
          ),
          _MoreOptionTile(
            icon: Icons.school_outlined,
            title: 'Training & Setup',
            subtitle:
                'Required: ${onboardingSetup.requiredCompleted}/${onboardingSetup.requiredTotal} • Optional pending: ${onboardingSetup.optionalPendingOrSkipped}',
            onTap: () => context.push('/onboardingGuide', extra: {'replayMode': true}),
          ),
          _MoreOptionTile(
            icon: Icons.store_mall_directory_outlined,
            title: 'Store Operations',
            subtitle: 'Open/close, accepting orders, outage controls',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChangeNotifierProvider.value(
                  value: context.read<VendorStoreOperationsViewModel>(),
                  child: const StoreOperationsPage(),
                ),
              ),
            ),
          ),
          _MoreOptionTile(
            icon: Icons.groups_2_outlined,
            title: 'Staff Management',
            subtitle: 'Invite members and update role permissions',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StaffManagementPage())),
          ),
          _MoreOptionTile(
            icon: Icons.analytics_outlined,
            title: 'Basic Analytics',
            subtitle: 'Today, 7-day and 30-day performance',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BasicAnalyticsPage())),
          ),
          _MoreOptionTile(
            icon: Icons.campaign_outlined,
            title: 'Growth & Campaigns',
            subtitle: 'Promotions, campaign builder, and promo performance',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GrowthCenterPage())),
          ),
          _MoreOptionTile(
            icon: Icons.schedule_outlined,
            title: 'Scheduling & Capacity',
            subtitle: 'Scheduled orders, slot capacity, and cutoff rules',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SchedulingCenterPage())),
          ),
          _MoreOptionTile(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Settlements & Finance',
            subtitle: 'Payout history, statements, and export center',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceCenterPage())),
          ),
          _MoreOptionTile(
            icon: Icons.print_outlined,
            title: 'Integrations',
            subtitle: 'Printer setup, KDS routing, and test print logs',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const IntegrationsCenterPage())),
          ),
          _MoreOptionTile(
            icon: Icons.person_outline_rounded,
            title: 'Profile & Security',
            subtitle: 'Business profile, password, session controls',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileSecurityPage())),
          ),
          _MoreOptionTile(
            icon: Icons.notifications_none_rounded,
            title: 'Notifications',
            subtitle: 'Alerts, chat notifications, reminder settings',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationSettingsPage())),
          ),
          _MoreOptionTile(
            icon: Icons.help_outline_rounded,
            title: 'Help & Onboarding Replay',
            subtitle: 'Training flow, support and policy information',
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpCenterPage())),
          ),
        ],
      ),
    );
  }
}

class _MoreOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _MoreOptionTile({required this.icon, required this.title, required this.subtitle, this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14.r),
      child: Container(
        margin: EdgeInsets.only(bottom: 10.h),
        padding: EdgeInsets.all(12.r),
        decoration: BoxDecoration(
          color: colors.backgroundPrimary,
          borderRadius: BorderRadius.circular(14.r),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 42.w,
              height: 42.w,
              decoration: BoxDecoration(
                color: colors.vendorPrimaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(icon, color: colors.vendorPrimaryBlue, size: 21.sp),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w800, color: colors.textPrimary),
                  ),
                  SizedBox(height: 3.h),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w500, color: colors.textSecondary),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: colors.textSecondary),
          ],
        ),
      ),
    );
  }
}
