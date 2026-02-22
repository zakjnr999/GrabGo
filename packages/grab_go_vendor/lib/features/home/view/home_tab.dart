import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_vendor/features/auth/model/vendor_service_option.dart';
import 'package:grab_go_vendor/features/home/view/home_alerts_page.dart';
import 'package:grab_go_vendor/features/home/widget/action_row.dart';
import 'package:grab_go_vendor/features/home/widget/checklist_row.dart';
import 'package:grab_go_vendor/features/home/widget/kpi_card.dart';
import 'package:grab_go_vendor/features/home/widget/section_card.dart';
import 'package:grab_go_vendor/features/notifications/view/notifications_page.dart';
import 'package:grab_go_vendor/features/onboarding/model/onboarding_setup_step.dart';
import 'package:grab_go_vendor/features/onboarding/viewmodel/onboarding_setup_viewmodel.dart';
import 'package:grab_go_vendor/features/store_context/viewmodel/store_context_viewmodel.dart';
import 'package:grab_go_vendor/features/store_operations/view/store_operations_page.dart';
import 'package:grab_go_vendor/features/store_operations/viewmodel/store_operations_viewmodel.dart';
import 'package:grab_go_vendor/shared/widgets/vendor_outage_banner.dart';
import 'package:provider/provider.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Consumer2<VendorStoreContextViewModel, OnboardingSetupViewModel>(
      builder: (context, storeContext, onboardingSetup, _) {
        final visibleServices = _visibleVendorServices(storeContext);
        final selectedBranch = storeContext.selectedBranch;
        final serviceScope = storeContext.serviceScopeLabel();

        final visibleAlerts =
            <HomeActionItem>[
                HomeActionItem(
                  priority: 0,
                  color: colors.error,
                  title: '2 orders at SLA risk',
                  subtitle: 'Average prep is above target',
                  action: HomeAlertAction.orders,
                ),
                HomeActionItem(
                  priority: 1,
                  color: colors.warning,
                  title: '3 new orders waiting for acceptance',
                  subtitle: 'Oldest pending: 1m ago',
                  action: HomeAlertAction.orders,
                ),
                HomeActionItem(
                  priority: 2,
                  color: colors.servicePharmacy,
                  title: '1 unresolved customer issue',
                  subtitle: 'Customer requested support on active order',
                  action: HomeAlertAction.orders,
                ),
                HomeActionItem(
                  priority: 3,
                  color: colors.serviceGrocery,
                  title: '5 low-stock items need update',
                  subtitle: 'Top risk: Fresh produce category',
                  serviceType: VendorServiceType.grocery,
                  action: HomeAlertAction.catalog,
                ),
              ].where((item) {
                final serviceType = item.serviceType;
                return serviceType == null || visibleServices.contains(serviceType);
              }).toList()
              ..sort((a, b) => a.priority.compareTo(b.priority));

        final actionItems = visibleAlerts.take(3).toList();

        final hasPendingOptionalChecklist = onboardingSetup.optionalPendingOrSkipped > 0;
        final checklistItems = onboardingSetup.steps
            .where((step) {
              if (!step.isOptional || step.status == VendorGuidedStepStatus.completed) {
                return false;
              }
              final serviceType = step.serviceHint;
              return serviceType == null || visibleServices.contains(serviceType);
            })
            .map((step) {
              return _HomeChecklistItem(
                label: step.title,
                done: false,
                statusLabel: onboardingStepStatusLabel(step.status),
              );
            })
            .toList();

        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Home',
                      style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.w900, color: colors.textPrimary),
                    ),
                    const Spacer(),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsPage()));
                        },
                        customBorder: const CircleBorder(),
                        child: Padding(
                          padding: EdgeInsets.all(10.r),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              SvgPicture.asset(
                                Assets.icons.bell,
                                package: 'grab_go_shared',
                                colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                              ),
                              Positioned(
                                right: -8.w,
                                top: -8.h,
                                child: Container(
                                  constraints: BoxConstraints(minWidth: 16.w, minHeight: 16.h),
                                  padding: EdgeInsets.symmetric(horizontal: 4.w),
                                  decoration: BoxDecoration(
                                    color: colors.vendorPrimaryBlue,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  alignment: Alignment.center,
                                  child: Text(
                                    '99+',
                                    style: TextStyle(color: Colors.white, fontSize: 9.sp, fontWeight: FontWeight.w800),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  visibleServices.isEmpty
                      ? 'No services are active for this profile and store context.'
                      : '${selectedBranch.name}  •  $serviceScope',
                  style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600, color: colors.textSecondary),
                ),
                SizedBox(height: 14.h),
                VendorOutageBanner(
                  onManageTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChangeNotifierProvider.value(
                        value: context.read<VendorStoreOperationsViewModel>(),
                        child: const StoreOperationsPage(),
                      ),
                    ),
                  ),
                ),
                Consumer<VendorStoreOperationsViewModel>(
                  builder: (context, operations, _) {
                    final activeServicesCount = visibleServices
                        .where((service) => operations.isServiceEnabled(service))
                        .length;
                    final snapshotTiles = <Widget>[
                      _SnapshotMetricTile(
                        label: 'Store',
                        value: operations.isStoreOpen ? 'Open' : 'Closed',
                        color: operations.isStoreOpen ? colors.success : colors.error,
                      ),
                      _SnapshotMetricTile(
                        label: 'Orders',
                        value: operations.acceptsOrders ? 'Accepting' : 'Paused',
                        color: operations.acceptsOrders ? colors.success : colors.warning,
                      ),
                      _SnapshotMetricTile(
                        label: 'Prep Time',
                        value: '${operations.prepTimeMinutes} min',
                        color: colors.vendorPrimaryBlue,
                      ),
                      _SnapshotMetricTile(
                        label: 'Services',
                        value: '$activeServicesCount/${visibleServices.length} active',
                        color: colors.vendorPrimaryBlue,
                      ),
                    ];

                    return SectionCard(
                      title: 'Operations Snapshot',
                      trailing: TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChangeNotifierProvider.value(
                              value: context.read<VendorStoreOperationsViewModel>(),
                              child: const StoreOperationsPage(),
                            ),
                          ),
                        ),
                        child: Text(
                          'Manage Store',
                          style: TextStyle(
                            decoration: TextDecoration.underline,
                            color: colors.textSecondary,
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: snapshotTiles.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 8.h,
                          crossAxisSpacing: 4.w,
                          mainAxisExtent: 54.h,
                        ),
                        itemBuilder: (_, index) => snapshotTiles[index],
                      ),
                    );
                  },
                ),
                SizedBox(height: 14.h),
                SectionCard(
                  title: 'Action Inbox',
                  trailing: visibleAlerts.isEmpty
                      ? null
                      : TextButton(
                          onPressed: () => _openAlerts(context, visibleAlerts),
                          child: Text(
                            'View All (${visibleAlerts.length})',
                            style: TextStyle(
                              decoration: TextDecoration.underline,
                              color: colors.textSecondary,
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                  child: actionItems.isEmpty
                      ? Text(
                          'No action items for the selected service scope.',
                          style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: colors.textSecondary),
                        )
                      : Column(
                          children: actionItems.map((item) {
                            return ActionRow(
                              color: item.color,
                              title: item.title,
                              subtitle: item.subtitle,
                              showChevron: true,
                              onTap: () => _openAlerts(context, visibleAlerts),
                            );
                          }).toList(),
                        ),
                ),
                SizedBox(height: 14.h),
                Text(
                  'Today KPIs',
                  style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w800, color: colors.textPrimary),
                ),
                SizedBox(height: 10.h),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 10.h,
                  crossAxisSpacing: 10.w,
                  childAspectRatio: 1.75,
                  children: const [
                    KpiCard(label: 'New Orders', value: '28'),
                    KpiCard(label: 'In Progress', value: '11'),
                    KpiCard(label: 'Avg Prep Time', value: '17m'),
                    KpiCard(label: 'Cancel Rate', value: '1.2%'),
                  ],
                ),
                if (hasPendingOptionalChecklist) ...[
                  SizedBox(height: 14.h),
                  SectionCard(
                    title: 'Onboarding Checklist',
                    child: checklistItems.isEmpty
                        ? Text(
                            'No pending optional setup items for this service scope.',
                            style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w600, color: colors.textSecondary),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: checklistItems.map((item) {
                              return ChecklistRow(label: item.label, done: item.done, statusLabel: item.statusLabel);
                            }).toList(),
                          ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  void _openAlerts(BuildContext context, List<HomeActionItem> alerts) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => HomeAlertsPage(alerts: alerts)));
  }
}

Set<VendorServiceType> _visibleVendorServices(VendorStoreContextViewModel storeContext) {
  final scope = storeContext.serviceScope;
  if (scope != null) return {scope};
  return storeContext.availableServicesForSelectedBranch.toSet();
}

class _HomeChecklistItem {
  final String label;
  final bool done;
  final String? statusLabel;

  const _HomeChecklistItem({required this.label, required this.done, this.statusLabel});
}

class _SnapshotMetricTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SnapshotMetricTile({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 9.h),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12.r)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 10.sp, fontWeight: FontWeight.w700, color: colors.textSecondary),
          ),
          SizedBox(height: 3.h),
          Text(
            value,
            style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }
}
