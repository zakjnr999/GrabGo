// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/shared/viewmodels/navigation_provider.dart';
import 'package:grab_go_customer/shared/viewmodels/theme_provider.dart';
import 'package:grab_go_customer/shared/widgets/cached_image_widget.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_customer/shared/viewmodels/favorites_provider.dart';
import 'package:grab_go_customer/shared/services/user_service.dart';
import 'package:provider/provider.dart';

class AppDrawer extends StatefulWidget {
  final DrawerController controller;
  const AppDrawer({super.key, required this.controller});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  User? _user;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      await Future.delayed(const Duration(milliseconds: 100));

      final user = UserService().currentUser;

      if (mounted) {
        setState(() {
          _user = user;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handleLogout() async {
    final shouldLogout = await AppDialog.show(
      context: context,
      title: 'Logout',
      message: 'Are you sure you want to logout? You will need to sign in again to access your account.',
      type: AppDialogType.warning,
      icon: Assets.icons.logOut,
      primaryButtonText: 'Logout',
      secondaryButtonText: 'Cancel',
      primaryButtonColor: Colors.red,
      onPrimaryPressed: () => Navigator.of(context).pop(true),
      onSecondaryPressed: () => Navigator.of(context).pop(false),
    );

    if (shouldLogout == true) {
      await UserService().logout();

      if (mounted) {
        context.go("/login");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final size = MediaQuery.sizeOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Drawer(
      backgroundColor: colors.backgroundSecondary,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(20.r),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [colors.accentOrange, colors.accentOrange.withOpacity(0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(30.r), bottomRight: Radius.circular(30.r)),
              ),
              child: Consumer<FavoritesProvider>(
                builder: (context, favoritesProvider, child) {
                  return Column(
                    children: [
                      SizedBox(height: 40.h),
                      Container(
                        padding: EdgeInsets.all(size.width * 0.008),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.2),
                          border: Border.all(color: Colors.white.withOpacity(0.3), width: size.width * 0.004),
                        ),
                        child: ClipOval(
                          child: GestureDetector(
                            onTap: () => context.push("/viewProfile", extra: _user),
                            child: Hero(
                              tag: _user?.profilePicture ?? "",
                              child: CachedImageWidget(
                                height: size.width * 0.2,
                                width: size.width * 0.2,
                                imageUrl: _user?.profilePicture ?? "",
                                placeholder: Assets.icons.noProfile.image(
                                  height: size.width * 0.2,
                                  width: size.width * 0.2,
                                  fit: BoxFit.cover,
                                  package: 'grab_go_shared',
                                ),
                                errorWidget: Assets.icons.noProfile.image(
                                  height: size.width * 0.2,
                                  width: size.width * 0.2,
                                  fit: BoxFit.cover,
                                  package: 'grab_go_shared',
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 12.h),
                      Text(
                        _isLoading ? "..." : (_user?.username ?? "Guest User"),
                        style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.w800, color: Colors.white),
                      ),
                      SizedBox(height: 4.h),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _isLoading ? "..." : (_user?.email ?? "Please log in to continue"),
                            style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                          SizedBox(width: 4.w),

                          _user?.isEmailVerified == false
                              ? GestureDetector(
                                  onTap: () {
                                    context.push("/emailVerification");
                                  },
                                  child: SvgPicture.asset(
                                    Assets.icons.infoCircle,
                                    package: 'grab_go_shared',
                                    height: 16.h,
                                    width: 16.w,
                                    colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ],
                      ),
                      SizedBox(height: 16.h),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildStatItem(icon: Assets.icons.cart, label: "Orders", value: "12", colors: colors),
                          Container(width: 1, height: 30.h, color: Colors.white.withOpacity(0.3)),
                          _buildStatItem(
                            icon: Assets.icons.heartSolid,
                            label: "Favorites",
                            value: favoritesProvider.favoriteItems.length.toDouble() > 0
                                ? favoritesProvider.favoriteItems.length.toString()
                                : "-",
                            colors: colors,
                          ),
                          Container(width: 1, height: 30.h, color: Colors.white.withOpacity(0.3)),
                          _buildStatItem(icon: Assets.icons.star, label: "Points", value: "450", colors: colors),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),

            SizedBox(height: 20.h),

            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildSectionHeader("Quick Access", colors),
                  _buildMenuItem(
                    context: context,
                    icon: Assets.icons.user,
                    title: "My Account",
                    subtitle: "Profile, addresses & more",
                    colors: colors,
                    iconColor: colors.accentViolet,
                    onTap: () {
                      context.pop();
                      Provider.of<NavigationProvider>(context, listen: false).navigateToAccount();
                    },
                  ),
                  _buildMenuItem(
                    context: context,
                    icon: Assets.icons.boxIso,
                    title: "My Orders",
                    subtitle: "Track and view your orders",
                    colors: colors,
                    iconColor: colors.accentOrange,
                    onTap: () {
                      context.pop();
                      context.push("/orders");
                    },
                  ),
                  _buildMenuItem(
                    context: context,
                    icon: Assets.icons.heart,
                    title: "Favorites",
                    subtitle: "Your favorite foods",
                    colors: colors,
                    iconColor: Colors.red,
                    onTap: () {
                      context.pop();
                      context.push("/favorites");
                    },
                  ),

                  SizedBox(height: 16.h),

                  _buildSectionHeader("Explore", colors),
                  _buildMenuItem(
                    context: context,
                    icon: Assets.icons.chefHat,
                    title: "All Restaurants",
                    subtitle: "Browse all available restaurants",
                    colors: colors,
                    iconColor: colors.accentViolet,
                    onTap: () {
                      context.pop();
                    },
                  ),
                  _buildMenuItem(
                    context: context,
                    icon: Assets.icons.flame,
                    title: "Popular Dishes",
                    subtitle: "Most ordered food items",
                    colors: colors,
                    iconColor: colors.accentOrange,
                    onTap: () {
                      context.pop();
                    },
                  ),
                  _buildMenuItem(
                    context: context,
                    icon: Assets.icons.gift,
                    title: "Offers & Deals",
                    subtitle: "Special discounts for you",
                    colors: colors,
                    iconColor: colors.accentGreen,
                    onTap: () {
                      context.pop();
                    },
                  ),

                  SizedBox(height: 16.h),

                  _buildSectionHeader("Support", colors),
                  _buildMenuItem(
                    context: context,
                    icon: Assets.icons.bell,
                    title: "Notifications",
                    subtitle: "View all notifications",
                    colors: colors,
                    iconColor: colors.accentViolet,
                    onTap: () {
                      context.pop();
                      context.push("/notification");
                    },
                  ),
                  _buildMenuItem(
                    context: context,
                    icon: Assets.icons.headsetHelp,
                    title: "Help & Support",
                    subtitle: "Get help with your orders",
                    colors: colors,
                    iconColor: colors.accentGreen,
                    onTap: () {
                      context.pop();
                    },
                  ),
                  _buildMenuItem(
                    context: context,
                    icon: Assets.icons.chatBubble,
                    title: "Chat with Us",
                    subtitle: "Live support available",
                    colors: colors,
                    iconColor: colors.accentOrange,
                    onTap: () {
                      context.pop();
                    },
                  ),

                  SizedBox(height: 16.h),

                  _buildSectionHeader("About", colors),
                  _buildMenuItem(
                    context: context,
                    icon: Assets.icons.shieldCheck,
                    title: "Privacy Policy",
                    subtitle: "Your privacy matters to us",
                    colors: colors,
                    iconColor: colors.accentViolet,
                    onTap: () {
                      context.pop();
                    },
                  ),
                  _buildMenuItem(
                    context: context,
                    icon: Assets.icons.scale,
                    title: "Terms & Conditions",
                    subtitle: "Read our terms of service",
                    colors: colors,
                    iconColor: colors.accentOrange,
                    onTap: () {
                      context.pop();
                    },
                  ),
                  _buildMenuItem(
                    context: context,
                    icon: Assets.icons.infoCircle,
                    title: "About GrabGo",
                    subtitle: "Version 1.0.0",
                    colors: colors,
                    iconColor: colors.accentGreen,
                    onTap: () {
                      context.pop();
                    },
                  ),

                  SizedBox(height: 20.h),

                  Container(
                    margin: EdgeInsets.symmetric(horizontal: 20.w),
                    padding: EdgeInsets.all(16.r),
                    decoration: BoxDecoration(
                      color: colors.backgroundPrimary,
                      borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
                      border: Border.all(color: colors.inputBorder.withOpacity(0.3), width: 0.5),
                      boxShadow: [
                        BoxShadow(
                          color: isDark ? Colors.black.withAlpha(30) : Colors.black.withAlpha(8),
                          spreadRadius: 0,
                          blurRadius: 12,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(10.r),
                          decoration: BoxDecoration(
                            color: colors.accentOrange.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: SvgPicture.asset(
                            themeProvider.themeMode == ThemeMode.light
                                ? Assets.icons.sunLight
                                : themeProvider.themeMode == ThemeMode.dark
                                ? Assets.icons.halfMoon
                                : Assets.icons.sunMoon,
                            package: "grab_go_shared",
                            height: 20.h,
                            width: 20.w,
                            colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Theme Mode",
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w700,
                                  color: colors.textPrimary,
                                ),
                              ),
                              SizedBox(height: 2.h),
                              Text(
                                themeProvider.themeMode == ThemeMode.light
                                    ? "Light Mode"
                                    : themeProvider.themeMode == ThemeMode.dark
                                    ? "Dark Mode"
                                    : "System Default",
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: colors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            themeProvider.toggleTheme();
                          },
                          child: Container(
                            padding: EdgeInsets.all(8.r),
                            decoration: BoxDecoration(color: colors.accentOrange, shape: BoxShape.circle),
                            child: Icon(Icons.brightness_6_rounded, color: Colors.white, size: 20.sp),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: 30.h),
                ],
              ),
            ),

            Container(
              margin: EdgeInsets.all(20.r),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    context.pop();
                    _handleLogout();
                  },
                  borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 16.h),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
                      border: Border.all(color: Colors.red.withOpacity(0.3), width: 1),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SvgPicture.asset(
                          Assets.icons.logOut,
                          package: 'grab_go_shared',
                          height: 20.h,
                          width: 20.w,
                          colorFilter: const ColorFilter.mode(Colors.red, BlendMode.srcIn),
                        ),
                        SizedBox(width: 10.w),
                        Text(
                          "Logout",
                          style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w700, color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({required String icon, required String label, required String value, required dynamic colors}) {
    return Column(
      children: [
        Row(
          children: [
            SvgPicture.asset(
              icon,
              package: "grab_go_shared",
              height: 16.h,
              width: 16.w,
              colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
            ),
            SizedBox(width: 6.w),
            Text(
              value,
              style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.w800, color: Colors.white),
            ),
          ],
        ),
        SizedBox(height: 4.h),
        Text(
          label,
          style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.w500, color: Colors.white.withOpacity(0.8)),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title, dynamic colors) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
      child: Text(
        title,
        style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w700, color: colors.textSecondary, letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required String icon,
    required String title,
    required String subtitle,
    required dynamic colors,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
        border: Border.all(color: colors.inputBorder.withOpacity(0.3), width: 0.5),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withAlpha(20) : Colors.black.withAlpha(5),
            spreadRadius: 0,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
          splashColor: iconColor.withOpacity(0.1),
          highlightColor: iconColor.withOpacity(0.05),
          child: Padding(
            padding: EdgeInsets.all(14.r),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10.r),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  child: SvgPicture.asset(
                    icon,
                    package: "grab_go_shared",
                    height: 20.h,
                    width: 20.w,
                    colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
                  ),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w700, color: colors.textPrimary),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 11.sp, color: colors.textSecondary, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, size: 16.sp, color: colors.textSecondary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
