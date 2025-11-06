import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/features/home/view/home_page.dart';
import 'package:grab_go_customer/features/home/view/menu.dart';
import 'package:grab_go_customer/features/profile/view/account.dart';
import 'package:grab_go_customer/features/restaurant/view/restaurants.dart';
import 'package:grab_go_customer/shared/viewmodels/navigation_provider.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_customer/features/cart/viewmodel/cart_provider.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:provider/provider.dart';

class BottomNavigator extends StatefulWidget {
  const BottomNavigator({super.key});

  @override
  State<BottomNavigator> createState() => _BottomNavigatorState();
}

class _BottomNavigatorState extends State<BottomNavigator> {
  void _onItemSelected(int index) {
    if (index == 2) {
      context.push("/cart");
    } else {
      Provider.of<NavigationProvider>(context, listen: false).setIndex(index);
    }
  }

  final List<Widget> _screens = [const HomePage(), const Menu(), Container(), const Restaurants(), const Account()];

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
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeInOut,
          switchOutCurve: Curves.easeInOut,
          transitionBuilder: (child, animation) => FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.05, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: animation, curve: Curves.easeInOut)),
              child: child,
            ),
          ),
          child: _screens[selectedIndex],
        ),
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
              Expanded(child: _buildNavItem(Assets.icons.squareMenu, "Menu", 1, context)),
              Expanded(child: _buildNavItem(Assets.icons.cart, "Cart", 2, context)),
              Expanded(child: _buildNavItem(Assets.icons.chefHat, "Restaurants", 3, context)),
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

    return GestureDetector(
      onTap: () => _onItemSelected(index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
            padding: EdgeInsets.all(selected ? 6.0 : 0),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? colors.accentOrange : Colors.transparent,
            ),
            child: AnimatedScale(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOutCubic,
              scale: selected ? 1.0 : 0.95,
              child: Consumer<CartProvider>(
                builder: (context, provider, child) {
                  final int uniqueItemCount = provider.uniqueItemCount;
                  return TweenAnimationBuilder<Color?>(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOutCubic,
                    tween: ColorTween(
                      begin: selected ? colors.backgroundPrimary : colors.textPrimary,
                      end: selected ? colors.backgroundPrimary : colors.textPrimary,
                    ),
                    builder: (context, color, child) {
                      return index == 2
                          ? Badge(
                              backgroundColor: uniqueItemCount > 0 ? colors.accentViolet : Colors.transparent,
                              label: Text(
                                uniqueItemCount.toString(),
                                style: TextStyle(fontSize: 10.sp, color: Colors.white),
                              ),
                              child: SvgPicture.asset(
                                icon,
                                package: 'grab_go_shared',
                                height: KIconSize.lg,
                                width: KIconSize.lg,
                                colorFilter: ColorFilter.mode(color ?? colors.textPrimary, BlendMode.srcIn),
                              ),
                            )
                          : SvgPicture.asset(
                              icon,
                              package: 'grab_go_shared',
                              height: KIconSize.lg,
                              width: KIconSize.lg,
                              colorFilter: ColorFilter.mode(color ?? colors.textPrimary, BlendMode.srcIn),
                            );
                    },
                  );
                },
              ),
            ),
          ),
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
