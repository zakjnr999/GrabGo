import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_vendor/features/home/view/catalog_tab.dart';
import 'package:grab_go_vendor/features/home/view/chats_tab.dart';
import 'package:grab_go_vendor/features/home/view/home_tab.dart';
import 'package:grab_go_vendor/features/home/view/more_tab.dart';
import 'package:grab_go_vendor/features/home/view/orders_tab.dart';
import 'package:grab_go_vendor/features/store_operations/viewmodel/store_operations_viewmodel.dart';
import 'package:grab_go_vendor/shared/viewmodel/bottom_nav_provider.dart';
import 'package:provider/provider.dart';

class VendorBottomNavigator extends StatelessWidget {
  const VendorBottomNavigator({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => VendorBottomNavProvider()),
        ChangeNotifierProvider(create: (_) => VendorStoreOperationsViewModel()),
      ],
      child: const _VendorBottomNavigatorView(),
    );
  }
}

class _VendorBottomNavigatorView extends StatelessWidget {
  const _VendorBottomNavigatorView();

  static final List<Widget> _screens = <Widget>[
    const HomeTab(),
    const OrdersTab(),
    const CatalogTab(),
    const ChatsTab(),
    const MoreTab(),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedIndex = context.select<VendorBottomNavProvider, int>(
      (value) => value.selectedIndex,
    );
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: colors.backgroundPrimary,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
          systemNavigationBarColor: colors.backgroundPrimary,
          systemNavigationBarDividerColor: Colors.transparent,
          systemNavigationBarIconBrightness: isDark
              ? Brightness.light
              : Brightness.dark,
        ),
        child: IndexedStack(index: selectedIndex, children: _screens),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: colors.backgroundPrimary,
          border: Border(top: BorderSide(color: colors.divider)),
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        padding: EdgeInsets.fromLTRB(
          10.w,
          10.h,
          10.w,
          bottomInset > 0 ? bottomInset : 10.h,
        ),
        child: Row(
          children: [
            Expanded(
              child: _NavButton(
                icon: Assets.icons.home,
                label: 'Home',
                index: 0,
                selectedIndex: selectedIndex,
              ),
            ),
            Expanded(
              child: _NavButton(
                icon: Assets.icons.boxIso,
                label: 'Orders',
                index: 1,
                selectedIndex: selectedIndex,
              ),
            ),
            Expanded(
              child: _NavButton(
                icon: Assets.icons.viewGrid,
                label: 'Catalog',
                index: 2,
                selectedIndex: selectedIndex,
              ),
            ),
            Expanded(
              child: _NavButton(
                icon: Assets.icons.chatBubble,
                label: 'Chats',
                index: 3,
                selectedIndex: selectedIndex,
              ),
            ),
            Expanded(
              child: _NavButton(
                icon: Assets.icons.squareMenu,
                label: 'More',
                index: 4,
                selectedIndex: selectedIndex,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final String icon;
  final String label;
  final int index;
  final int selectedIndex;

  const _NavButton({
    required this.icon,
    required this.label,
    required this.index,
    required this.selectedIndex,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final selected = selectedIndex == index;

    return InkWell(
      onTap: () => context.read<VendorBottomNavProvider>().setIndex(index),
      borderRadius: BorderRadius.circular(14.r),
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 2.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.all(selected ? 8.r : 6.r),
              decoration: BoxDecoration(
                color: selected ? colors.vendorPrimaryBlue : Colors.transparent,
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: SvgPicture.asset(
                icon,
                package: 'grab_go_shared',
                width: 20.w,
                height: 20.w,
                colorFilter: ColorFilter.mode(
                  selected ? Colors.white : colors.iconSecondary,
                  BlendMode.srcIn,
                ),
              ),
            ),
            SizedBox(height: 4.h),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected
                    ? colors.vendorPrimaryBlue
                    : colors.textSecondary,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
