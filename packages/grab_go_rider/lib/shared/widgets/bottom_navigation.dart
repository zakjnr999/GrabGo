import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:grab_go_rider/features/chat/view/chat_page.dart';
import 'package:grab_go_rider/features/home/view/home_page.dart';
import 'package:grab_go_rider/features/home/view/profile_page.dart';
import 'package:grab_go_rider/features/home/view/wallet_page.dart';
import 'package:grab_go_rider/shared/viewmodel/bottom_nav_provider.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:provider/provider.dart';

class BottomNavigator extends StatefulWidget {
  const BottomNavigator({super.key});

  @override
  State<BottomNavigator> createState() => _BottomNavigatorState();
}

class _BottomNavigatorState extends State<BottomNavigator> {
  final List<Widget> _screens = [const HomePage(), const WalletPage(), const ChatPage(), const ProfilePage()];

  void _onItemSelected(int index) {
    setState(() {
      Provider.of<BottomNavProvider>(context, listen: false).setIndex(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomNavProvider = Provider.of<BottomNavProvider>(context);
    final selectedIndex = bottomNavProvider.selectedIndex;
    final size = MediaQuery.sizeOf(context);

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
            topLeft: Radius.circular(KBorderSize.borderRadius20),
            topRight: Radius.circular(KBorderSize.borderRadius20),
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
              Expanded(child: _buildNavItem(Assets.icons.creditCard, "Wallet", 1, context)),
              Expanded(child: _buildNavItem(Assets.icons.chatBubble, "Chat", 2, context)),
              Expanded(child: _buildNavItem(Assets.icons.user, "Profile", 3, context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(String icon, String label, int index, BuildContext context) {
    final bottomNavProvider = Provider.of<BottomNavProvider>(context);
    final bool selected = bottomNavProvider.selectedIndex == index;
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
              color: selected ? colors.accentGreen : Colors.transparent,
            ),
            child: AnimatedScale(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOutCubic,
              scale: selected ? 1.0 : 0.95,
              child: TweenAnimationBuilder<Color?>(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOutCubic,
                tween: ColorTween(
                  begin: selected ? colors.backgroundPrimary : colors.textPrimary,
                  end: selected ? colors.backgroundPrimary : colors.textPrimary,
                ),
                builder: (context, color, child) {
                  return SvgPicture.asset(
                    icon,
                    package: 'grab_go_shared',
                    height: KIconSize.lg,
                    width: KIconSize.lg,
                    colorFilter: ColorFilter.mode(color ?? colors.textPrimary, BlendMode.srcIn),
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
              color: selected ? colors.accentGreen : colors.textPrimary,
            ),
            child: Text(label),
          ),
        ],
      ),
    );
  }
}
