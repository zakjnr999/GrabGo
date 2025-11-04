import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class HomeDrawer extends StatelessWidget {
  const HomeDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

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
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "GrabGo Rider",
                        style: TextStyle(
                          fontFamily: "Lato",
                          package: "grab_go_shared",
                          color: Colors.white,
                          fontSize: 18.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
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
                    _buildDrawerItem("Home", Assets.icons.home, colors.textPrimary, colors, () {
                      Navigator.pop(context);
                    }),
                    _buildDrawerItem("Wallet", Assets.icons.creditCard, colors.textPrimary, colors, () {
                      Navigator.pop(context);
                    }),
                    _buildDrawerItem("Earnings History", Assets.icons.dollar, colors.textPrimary, colors, () {
                      Navigator.pop(context);
                      context.push("/earnings-history");
                    }),
                    _buildDrawerItem("My Deliveries", Assets.icons.deliveryTruck, colors.textPrimary, colors, () {
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
                    }),
                    _buildDrawerItem("Settings", Assets.icons.slidersHorizontal, colors.textPrimary, colors, () {
                      Navigator.pop(context);
                      context.push("/settings");
                    }),
                    _buildDrawerItem("Support", Assets.icons.headsetHelp, colors.textPrimary, colors, () {
                      Navigator.pop(context);
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KBorderSize.borderRadius12)),
        backgroundColor: colors.backgroundPrimary,
        title: Text(
          "Logout",
          style: TextStyle(color: colors.textPrimary, fontSize: 20.sp, fontWeight: FontWeight.w700),
        ),
        content: Text(
          "Are you sure you want to logout?",
          style: TextStyle(color: colors.textSecondary, fontSize: 14.sp, fontWeight: FontWeight.w400),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              "Cancel",
              style: TextStyle(color: colors.textSecondary, fontSize: 14.sp, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text(
              "Logout",
              style: TextStyle(color: colors.error, fontSize: 14.sp, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
