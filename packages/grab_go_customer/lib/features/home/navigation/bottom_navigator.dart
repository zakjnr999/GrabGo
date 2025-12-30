import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:grab_go_customer/features/browse/view/browse_page.dart';
import 'package:grab_go_customer/features/chat/view/chats.dart';
import 'package:grab_go_customer/features/home/view/home_page.dart';
import 'package:grab_go_customer/features/profile/view/account.dart';
import 'package:grab_go_customer/features/restaurant/view/restaurants.dart';
import 'package:grab_go_customer/shared/viewmodels/navigation_provider.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:provider/provider.dart';

class BottomNavigator extends StatefulWidget {
  const BottomNavigator({super.key});

  @override
  State<BottomNavigator> createState() => _BottomNavigatorState();
}

class _BottomNavigatorState extends State<BottomNavigator> {
  void _onItemSelected(int index) {
    Provider.of<NavigationProvider>(context, listen: false).setIndex(index);
  }

  final List<Widget> _screens = [
    const HomePage(),
    const BrowsePage(),
    const Chats(),
    const Restaurants(),
    const Account(),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navigationProvider = Provider.of<NavigationProvider>(context);
    final selectedIndex = navigationProvider.selectedIndex;
    Size size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Theme.of(context).scaffoldBackgroundColor,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          systemNavigationBarColor: colors.backgroundPrimary,
          systemNavigationBarDividerColor: Colors.transparent,
          systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        ),
        child: IndexedStack(index: selectedIndex, children: _screens),
      ),
      bottomNavigationBar: Container(
        height: size.height * 0.16,
        decoration: BoxDecoration(
          color: colors.backgroundPrimary,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(KBorderSize.border),
            topRight: Radius.circular(KBorderSize.border),
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(25), spreadRadius: 1, blurRadius: 20, offset: const Offset(0, -3)),
          ],
        ),
        child: BottomAppBar(
          color: Colors.transparent,
          elevation: 0,
          child: Row(
            children: [
              Expanded(child: _buildNavItem(Assets.icons.home, "Home", 0, context)),
              Expanded(child: _buildNavItem(Assets.icons.search, "Browse", 1, context)),
              Expanded(child: _buildNavItem(Assets.icons.chatBubble, "chats", 2, context)),
              Expanded(child: _buildNavItem(Assets.icons.store, "Vendors", 3, context)),
              Expanded(child: _buildNavItem(Assets.icons.user, "Account", 4, context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(String icon, String label, int index, BuildContext context) {
    final navigationProvider = Provider.of<NavigationProvider>(context);
    final bool selected = navigationProvider.selectedIndex == index;
    final colors = context.appColors;
    final int unread = navigationProvider.chatUnreadCount;

    Widget iconWidget = AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
      padding: EdgeInsets.all(selected ? 6.0 : 0),
      decoration: BoxDecoration(shape: BoxShape.circle, color: selected ? colors.accentOrange : Colors.transparent),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
        scale: selected ? 1.0 : 0.95,
        child: SvgPicture.asset(
          icon,
          package: 'grab_go_shared',
          height: KIconSize.lg,
          width: KIconSize.lg,
          colorFilter: ColorFilter.mode(selected ? colors.backgroundPrimary : colors.textPrimary, BlendMode.srcIn),
        ),
      ),
    );

    if (index == 2 && unread > 0) {
      iconWidget = Stack(
        clipBehavior: Clip.none,
        children: [
          iconWidget,
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: colors.accentOrange,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: colors.backgroundPrimary, width: 2),
              ),
              child: Text(
                unread > 9 ? '9+' : unread.toString(),
                style: TextStyle(
                  fontFamily: 'Lato',
                  package: 'grab_go_shared',
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: colors.backgroundPrimary,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return GestureDetector(
      onTap: () => _onItemSelected(index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          iconWidget,
          const SizedBox(height: 4),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
            style: TextStyle(
              fontFamily: "Lato",
              package: 'grab_go_shared',
              fontSize: 12,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: colors.textPrimary,
            ),
            child: Text(label),
          ),
        ],
      ),
    );
  }
}
