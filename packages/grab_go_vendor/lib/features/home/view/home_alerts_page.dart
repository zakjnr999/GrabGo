import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/shared/utils/app_colors_extension.dart';
import 'package:grab_go_vendor/features/auth/model/vendor_service_option.dart';
import 'package:grab_go_vendor/features/store_operations/view/store_operations_page.dart';
import 'package:grab_go_vendor/features/store_operations/viewmodel/store_operations_viewmodel.dart';
import 'package:grab_go_vendor/shared/viewmodel/bottom_nav_provider.dart';
import 'package:provider/provider.dart';

class HomeAlertsPage extends StatelessWidget {
  final List<HomeActionItem> alerts;

  const HomeAlertsPage({super.key, required this.alerts});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.backgroundPrimary,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.w, 6.h, 20.w, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextButton.icon(
                onPressed: () => Navigator.of(context).maybePop(),
                style: TextButton.styleFrom(padding: EdgeInsets.zero, foregroundColor: colors.textSecondary),
                icon: SvgPicture.asset(
                  Assets.icons.navArrowLeft,
                  package: 'grab_go_shared',
                  width: 18.w,
                  height: 18.w,
                  colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                ),
                label: Text(
                  'Back',
                  style: TextStyle(color: colors.textSecondary, fontSize: 14.sp, fontWeight: FontWeight.w500),
                ),
              ),
              SizedBox(height: 6.h),
              Text(
                'Alerts',
                style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.w900, color: colors.textPrimary, height: 1.15),
              ),
              SizedBox(height: 8.h),
              Text(
                'Prioritized operational alerts for this branch and service scope.',
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.w500,
                  color: colors.textSecondary,
                  height: 1.4,
                ),
              ),
              SizedBox(height: 12.h),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.only(bottom: 20.h),
                  children: [
                    ...alerts.map((alert) {
                      return Container(
                        width: double.infinity,
                        margin: EdgeInsets.only(bottom: 10.h),
                        padding: EdgeInsets.all(12.r),
                        decoration: BoxDecoration(
                          color: colors.backgroundPrimary,
                          borderRadius: BorderRadius.circular(14.r),
                          border: Border.all(color: colors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 10.w,
                                  height: 10.w,
                                  decoration: BoxDecoration(color: alert.color, shape: BoxShape.circle),
                                ),
                                SizedBox(width: 8.w),
                                Expanded(
                                  child: Text(
                                    alert.title,
                                    style: TextStyle(
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w800,
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 6.h),
                            Text(
                              alert.subtitle,
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w500,
                                color: colors.textSecondary,
                              ),
                            ),
                            SizedBox(height: 8.h),
                            Row(
                              children: [
                                if (alert.serviceType != null)
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                                    decoration: BoxDecoration(
                                      color: alert.color.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(999.r),
                                    ),
                                    child: Text(
                                      _serviceLabel(alert.serviceType!),
                                      style: TextStyle(
                                        fontSize: 10.sp,
                                        fontWeight: FontWeight.w700,
                                        color: alert.color,
                                      ),
                                    ),
                                  ),
                                const Spacer(),
                                TextButton(
                                  onPressed: () => _handleAlertAction(context, alert),
                                  child: Text(
                                    _alertActionLabel(alert.action),
                                    style: TextStyle(
                                      decoration: TextDecoration.underline,
                                      decorationColor: colors.vendorPrimaryBlue,
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w700,
                                      color: colors.vendorPrimaryBlue,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleAlertAction(BuildContext context, HomeActionItem alert) {
    switch (alert.action) {
      case HomeAlertAction.orders:
        context.read<VendorBottomNavProvider>().navigateToOrders();
        Navigator.of(context).pop();
        break;
      case HomeAlertAction.catalog:
        context.read<VendorBottomNavProvider>().navigateToCatalog();
        Navigator.of(context).pop();
        break;
      case HomeAlertAction.storeOperations:
        Navigator.push(
          context,
          CupertinoPageRoute(
            builder: (_) => ChangeNotifierProvider.value(
              value: context.read<VendorStoreOperationsViewModel>(),
              child: const StoreOperationsPage(),
            ),
          ),
        );
        break;
    }
  }
}

enum HomeAlertAction { orders, catalog, storeOperations }

String _alertActionLabel(HomeAlertAction action) {
  return switch (action) {
    HomeAlertAction.orders => 'Open Orders',
    HomeAlertAction.catalog => 'Open Catalog',
    HomeAlertAction.storeOperations => 'Open Store Ops',
  };
}

String _serviceLabel(VendorServiceType serviceType) {
  return switch (serviceType) {
    VendorServiceType.food => 'Food',
    VendorServiceType.grocery => 'Grocery',
    VendorServiceType.pharmacy => 'Pharmacy',
    VendorServiceType.grabMart => 'GrabMart',
  };
}

class HomeActionItem {
  final int priority;
  final Color color;
  final String title;
  final String subtitle;
  final VendorServiceType? serviceType;
  final HomeAlertAction action;

  const HomeActionItem({
    required this.priority,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.action,
    this.serviceType,
  });
}
