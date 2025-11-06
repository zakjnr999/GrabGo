import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_rider/shared/viewmodel/bottom_nav_provider.dart';
import 'package:grab_go_rider/shared/viewmodel/theme_provider.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:provider/provider.dart';

class HomeDrawer extends StatefulWidget {
  const HomeDrawer({super.key});

  @override
  State<HomeDrawer> createState() => _HomeDrawerState();
}

class _HomeDrawerState extends State<HomeDrawer> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    _animationController = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));
    super.initState();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Drawer(
          backgroundColor: colors.backgroundSecondary,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                Container(
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + 20.h,
                    bottom: 20.h,
                    left: 20.w,
                    right: 20.w,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [colors.accentGreen, colors.accentGreen.withValues(alpha: 0.85)],
                    ),
                    borderRadius: BorderRadius.only(bottomRight: Radius.circular(KBorderSize.borderRadius20)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: SvgPicture.asset(
                              Assets.icons.deliveryGuyIcon,
                              package: 'grab_go_shared',
                              width: 46.w,
                              height: 46.w,
                              colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                            ),
                            onPressed: () => Navigator.pop(context),
                          ),

                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                _animationController.forward().then((_) {
                                  _animationController.reset();
                                });
                                themeProvider.toggleTheme();
                              },
                              customBorder: const CircleBorder(),
                              child: Padding(
                                padding: EdgeInsets.all(10.r),
                                child: AnimatedBuilder(
                                  animation: _rotationAnimation,
                                  builder: (context, child) {
                                    return Transform.rotate(
                                      angle: _rotationAnimation.value * 2 * 3.14159,
                                      child: AnimatedSwitcher(
                                        duration: const Duration(milliseconds: 300),
                                        transitionBuilder: (child, animation) {
                                          return ScaleTransition(scale: animation, child: child);
                                        },
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.white.withValues(alpha: 0.2),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Padding(
                                            padding: EdgeInsets.all(8.r),
                                            child: SvgPicture.asset(
                                              themeProvider.themeMode == ThemeMode.light
                                                  ? Assets.icons.sunLight
                                                  : themeProvider.themeMode == ThemeMode.dark
                                                  ? Assets.icons.halfMoon
                                                  : Assets.icons.sunMoon,
                                              key: ValueKey(themeProvider.themeMode),
                                              package: "grab_go_shared",
                                              colorFilter: ColorFilter.mode(Colors.white, BlendMode.srcIn),
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20.h),
                      Text(
                        "John Mensah",
                        style: TextStyle(color: Colors.white, fontSize: 20.sp, fontWeight: FontWeight.w700),
                      ),
                      SizedBox(height: 12.h),
                      Row(
                        children: [
                          SvgPicture.asset(
                            Assets.icons.shieldCheck,
                            package: 'grab_go_shared',
                            width: 18.w,
                            height: 18.w,
                            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                          ),
                          SizedBox(width: 6.w),
                          Text(
                            "Verified Rider",
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.95),
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Container(
                            width: 6.w,
                            height: 6.w,
                            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                          ),
                          SizedBox(width: 6.w),
                          Text(
                            "Online",
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.95),
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    child: Column(
                      children: [
                        _buildDrawerItem("Wallet", Assets.icons.creditCard, colors.textPrimary, colors, () {
                          Navigator.pop(context);
                          Provider.of<BottomNavProvider>(context, listen: false).setIndex(1);
                        }),
                        _buildDrawerItem("Earnings History", Assets.icons.dollar, colors.textPrimary, colors, () {
                          Navigator.pop(context);
                          context.push("/earnings-history");
                        }),
                        _buildDrawerItem("My Orders", Assets.icons.deliveryTruck, colors.textPrimary, colors, () {
                          Navigator.pop(context);
                          context.push("/orders");
                        }),
                        _buildDrawerItem("Performance", Assets.icons.star, colors.textPrimary, colors, () {
                          Navigator.pop(context);
                          context.push("/performance");
                        }),
                        _buildDrawerItem("Bonuses", Assets.icons.gift, colors.textPrimary, colors, () {
                          Navigator.pop(context);
                          context.push("/bonuses");
                        }),
                        SizedBox(height: 8.h),
                        Divider(color: colors.border, thickness: 1, height: 1, indent: 20.w, endIndent: 20.w),
                        SizedBox(height: 8.h),
                        _buildDrawerItem("Profile", Assets.icons.user, colors.textPrimary, colors, () {
                          Navigator.pop(context);
                          Provider.of<BottomNavProvider>(context, listen: false).setIndex(3);
                        }),
                        _buildDrawerItem("Settings", Assets.icons.slidersHorizontal, colors.textPrimary, colors, () {
                          Navigator.pop(context);
                          context.push("/settings");
                        }),
                        _buildDrawerItem("Support", Assets.icons.headsetHelp, colors.textPrimary, colors, () {
                          Navigator.pop(context);
                          context.push("/support");
                        }),
                        _buildDrawerItem("Terms & Policies", Assets.icons.infoCircle, colors.textPrimary, colors, () {
                          Navigator.pop(context);
                        }),
                        _buildDrawerItem("Logout", Assets.icons.logOut, colors.error, colors, () {
                          Navigator.pop(context);
                          _showLogoutDialog(context, colors);
                        }),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDrawerItem(String title, String icon, Color iconColor, AppColorsExtension colors, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
        child: Row(
          children: [
            Container(
              width: 36.w,
              height: 36.w,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
              ),
              child: Center(
                child: SvgPicture.asset(
                  icon,
                  package: 'grab_go_shared',
                  width: 18.w,
                  height: 18.w,
                  colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
                ),
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Text(
                title,
                style: TextStyle(color: colors.textPrimary, fontSize: 15.sp, fontWeight: FontWeight.w600),
              ),
            ),
            SvgPicture.asset(
              Assets.icons.navArrowRight,
              package: 'grab_go_shared',
              width: 18.w,
              height: 18.w,
              colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, AppColorsExtension colors) {
    AppDialog.show(
      context: context,
      title: "Logout",
      message: "Are you sure you want to logout?",
      type: AppDialogType.logout,
      primaryButtonText: "Logout",
      secondaryButtonText: "Cancel",
      borderRadius: KBorderSize.borderRadius4,
      buttonBorderRadius: KBorderSize.borderRadius4,
      onPrimaryPressed: () {
        Navigator.pop(context);
      },
      onSecondaryPressed: () => Navigator.pop(context),
    );
  }
}
