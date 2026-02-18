import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_vendor/features/auth/model/vendor_service_option.dart';
import 'package:grab_go_vendor/features/onboarding/model/onboarding_setup_step.dart';
import 'package:grab_go_vendor/features/onboarding/viewmodel/onboarding_setup_viewmodel.dart';
import 'package:grab_go_vendor/features/store_context/viewmodel/store_context_viewmodel.dart';
import 'package:grab_go_vendor/features/store_operations/view/store_operations_page.dart';
import 'package:grab_go_vendor/features/store_operations/viewmodel/store_operations_viewmodel.dart';
import 'package:grab_go_vendor/shared/viewmodel/vendor_preview_session_viewmodel.dart';
import 'package:grab_go_vendor/shared/widgets/vendor_outage_banner.dart';
import 'package:grab_go_vendor/shared/widgets/vendor_store_context_chip.dart';
import 'package:provider/provider.dart';

class HomeTab extends StatelessWidget {
  const HomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Consumer3<
      VendorStoreContextViewModel,
      VendorPreviewSessionViewModel,
      OnboardingSetupViewModel
    >(
      builder: (context, storeContext, previewSession, onboardingSetup, _) {
        final visibleServices = _visibleVendorServices(storeContext);
        final actionItems =
            [
              _HomeActionItem(
                color: colors.warning,
                title: '3 new orders waiting for acceptance',
                subtitle: 'Oldest pending: 1m ago',
              ),
              _HomeActionItem(
                color: colors.error,
                title: '2 orders at SLA risk',
                subtitle: 'Average prep is above target',
              ),
              _HomeActionItem(
                color: colors.serviceGrocery,
                title: '5 low-stock items need update',
                subtitle: 'Top risk: Fresh produce category',
                serviceType: VendorServiceType.grocery,
              ),
            ].where((item) {
              final serviceType = item.serviceType;
              return serviceType == null ||
                  visibleServices.contains(serviceType);
            }).toList();
        final checklistItems = onboardingSetup.steps
            .where((step) {
              final serviceType = step.serviceHint;
              return serviceType == null ||
                  visibleServices.contains(serviceType);
            })
            .map((step) {
              return _HomeChecklistItem(
                label: step.isOptional
                    ? '${step.title} (Optional)'
                    : step.title,
                done: step.status == VendorGuidedStepStatus.completed,
                statusLabel: onboardingStepStatusLabel(step.status),
                serviceType: step.serviceHint,
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
                      style: TextStyle(
                        fontSize: 28.sp,
                        fontWeight: FontWeight.w900,
                        color: colors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    const VendorStoreContextChip(),
                  ],
                ),
                SizedBox(height: 6.h),
                Text(
                  visibleServices.isEmpty
                      ? 'No services are active for this profile and store context.'
                      : 'Preview: ${previewSession.activeProfile.title} • Setup ${onboardingSetup.requiredCompleted}/${onboardingSetup.requiredTotal} required complete',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary,
                  ),
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
                _SectionCard(
                  title: 'Action Inbox',
                  child: actionItems.isEmpty
                      ? Text(
                          'No action items for the selected service scope.',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: colors.textSecondary,
                          ),
                        )
                      : Column(
                          children: actionItems.map((item) {
                            return _ActionRow(
                              color: item.color,
                              title: item.title,
                              subtitle: item.subtitle,
                            );
                          }).toList(),
                        ),
                ),
                SizedBox(height: 14.h),
                Text(
                  'Today KPIs',
                  style: TextStyle(
                    fontSize: 15.sp,
                    fontWeight: FontWeight.w800,
                    color: colors.textPrimary,
                  ),
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
                    _KpiCard(label: 'New Orders', value: '28'),
                    _KpiCard(label: 'In Progress', value: '11'),
                    _KpiCard(label: 'Avg Prep Time', value: '17m'),
                    _KpiCard(label: 'Cancel Rate', value: '1.2%'),
                  ],
                ),
                SizedBox(height: 14.h),
                _SectionCard(
                  title: 'Onboarding Checklist',
                  child: checklistItems.isEmpty
                      ? Text(
                          'No checklist items for the selected service scope.',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: colors.textSecondary,
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: checklistItems.map((item) {
                            return _ChecklistRow(
                              label: item.label,
                              done: item.done,
                              statusLabel: item.statusLabel,
                            );
                          }).toList(),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
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
        borderRadius: BorderRadius.circular(16.r),
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

class _ActionRow extends StatelessWidget {
  final Color color;
  final String title;
  final String subtitle;

  const _ActionRow({
    required this.color,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10.w,
            height: 10.w,
            margin: EdgeInsets.only(top: 4.h),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: 10.w),
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
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w500,
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

class _KpiCard extends StatelessWidget {
  final String label;
  final String value;

  const _KpiCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Container(
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 21.sp,
              fontWeight: FontWeight.w900,
              color: colors.textPrimary,
            ),
          ),
          SizedBox(height: 3.h),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w600,
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChecklistRow extends StatelessWidget {
  final String label;
  final bool done;
  final String? statusLabel;

  const _ChecklistRow({
    required this.label,
    required this.done,
    this.statusLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        children: [
          Icon(
            done
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 18.sp,
            color: done ? colors.success : colors.textSecondary,
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
          ),
          if (statusLabel != null)
            Text(
              statusLabel!,
              style: TextStyle(
                fontSize: 10.sp,
                fontWeight: FontWeight.w700,
                color: done ? colors.success : colors.textSecondary,
              ),
            ),
        ],
      ),
    );
  }
}

Set<VendorServiceType> _visibleVendorServices(
  VendorStoreContextViewModel storeContext,
) {
  final scope = storeContext.serviceScope;
  if (scope != null) return {scope};
  return storeContext.availableServicesForSelectedBranch.toSet();
}

class _HomeActionItem {
  final Color color;
  final String title;
  final String subtitle;
  final VendorServiceType? serviceType;

  const _HomeActionItem({
    required this.color,
    required this.title,
    required this.subtitle,
    this.serviceType,
  });
}

class _HomeChecklistItem {
  final String label;
  final bool done;
  final String? statusLabel;
  final VendorServiceType? serviceType;

  const _HomeChecklistItem({
    required this.label,
    required this.done,
    this.statusLabel,
    this.serviceType,
  });
}
