import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_rider/core/api/api_client.dart';
import 'package:grab_go_rider/features/chat/view/chat_detail_page.dart';
import 'package:grab_go_rider/shared/service/user_service.dart';
import 'package:grab_go_rider/shared/widgets/profile_sliver_appbar.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  User? _user;
  Rider? _rider;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final cachedUser =
          UserService().currentUser ??
          (() {
            final raw = CacheService.getUserData();
            if (raw == null) return null;
            return User.fromJson(raw);
          })();
      if (cachedUser != null && mounted) {
        setState(() {
          _user = cachedUser;
        });
      }

      final response = await riderService.getVerification();
      if (!mounted) return;

      if (response.isSuccessful && response.body?.data != null) {
        setState(() {
          _rider = response.body!.data;
        });
      }
    } catch (_) {
      // Keep current values and avoid disrupting the page.
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _displayCount(int? value) {
    if (_isLoading) return "...";
    if (value == null) return "--";
    return value.toString();
  }

  String _displayRating(double? value) {
    if (_isLoading) return "...";
    if (value == null) return "--";
    return value.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: colors.backgroundPrimary,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: colors.backgroundSecondary,
        body: AppRefreshIndicator(
          onRefresh: _loadProfileData,
          bgColor: colors.accentGreen,
          iconPath: Assets.icons.user,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              ProfileSliverAppbar(
                riderName: _user?.username,
                riderEmail: _user?.email,
                isLoading: _isLoading,
              ),
              SliverToBoxAdapter(
                child: Column(
                  children: [
                    SizedBox(height: 24.h),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.w),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              "Deliveries",
                              _displayCount(_rider?.totalDeliveries),
                              Assets.icons.deliveryTruck,
                              colors.accentGreen,
                              colors,
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: _buildStatCard(
                              "Rating",
                              _displayRating(_rider?.rating),
                              Assets.icons.star,
                              colors.accentGreen,
                              colors,
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: _buildStatCard(
                              "Active Days",
                              _displayCount(_rider?.activeDays),
                              Assets.icons.calendar,
                              colors.accentGreen,
                              colors,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 24.h),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.w),
                      child: Column(
                        children: [
                          _buildMenuItem(
                            "Personal Information",
                            Assets.icons.user,
                            colors.textPrimary,
                            colors,
                            () {
                              context.push("/personal-information");
                            },
                          ),
                          SizedBox(height: 12.h),
                          _buildMenuItem(
                            "Vehicle Details",
                            Assets.icons.deliveryTruck,
                            colors.textPrimary,
                            colors,
                            () {
                              context.push("/vehicle-details");
                            },
                          ),
                          SizedBox(height: 12.h),
                          _buildMenuItem(
                            "Bank Account",
                            Assets.icons.creditCard,
                            colors.textPrimary,
                            colors,
                            () {
                              context.push("/bank-account");
                            },
                          ),
                          SizedBox(height: 12.h),
                          _buildMenuItem(
                            "Documents",
                            Assets.icons.idCard,
                            colors.textPrimary,
                            colors,
                            () {
                              context.push("/documents");
                            },
                          ),
                          SizedBox(height: 12.h),
                          _buildMenuItem(
                            "Notifications",
                            Assets.icons.bell,
                            colors.textPrimary,
                            colors,
                            () {
                              context.push("/notifications");
                            },
                          ),
                          SizedBox(height: 12.h),
                          _buildMenuItem(
                            "Help & Support",
                            Assets.icons.headsetHelp,
                            colors.textPrimary,
                            colors,
                            () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const ChatDetailPage(
                                    chatId: "support",
                                    senderName: "GrabGo Support",
                                    isSupport: true,
                                  ),
                                ),
                              );
                            },
                          ),
                          SizedBox(height: 12.h),
                          _buildMenuItem(
                            "Settings",
                            Assets.icons.slidersHorizontal,
                            colors.textPrimary,
                            colors,
                            () {
                              context.push("/settings");
                            },
                          ),
                          SizedBox(height: 12.h),
                          _buildMenuItem(
                            "About",
                            Assets.icons.infoCircle,
                            colors.textPrimary,
                            colors,
                            () {},
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 24.h),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20.w),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: colors.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(
                            KBorderSize.borderRadius4,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              _showLogoutDialog(context, colors);
                            },
                            borderRadius: BorderRadius.circular(
                              KBorderSize.borderRadius4,
                            ),
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: 16.h,
                                horizontal: 20.w,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SvgPicture.asset(
                                    Assets.icons.logOut,
                                    package: 'grab_go_shared',
                                    width: 20.w,
                                    height: 20.w,
                                    colorFilter: ColorFilter.mode(
                                      colors.error,
                                      BlendMode.srcIn,
                                    ),
                                  ),
                                  SizedBox(width: 12.w),
                                  Text(
                                    "Logout",
                                    style: TextStyle(
                                      color: colors.error,
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 32.h),
                    Text(
                      "Version 1.0.0",
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    SizedBox(height: 16.h),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    String icon,
    Color iconColor,
    AppColorsExtension colors,
  ) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
      ),
      child: Column(
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
            ),
            child: Center(
              child: SvgPicture.asset(
                icon,
                package: 'grab_go_shared',
                width: 20.w,
                height: 20.w,
                colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
              ),
            ),
          ),
          SizedBox(height: 12.h),
          Text(
            value,
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 18.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 11.sp,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    String title,
    String icon,
    Color iconColor,
    AppColorsExtension colors,
    VoidCallback onTap,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: colors.backgroundPrimary,
        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
            child: Row(
              children: [
                Container(
                  width: 40.w,
                  height: 40.w,
                  decoration: BoxDecoration(
                    color: colors.backgroundSecondary,
                    borderRadius: BorderRadius.circular(
                      KBorderSize.borderRadius4,
                    ),
                  ),
                  child: Center(
                    child: SvgPicture.asset(
                      icon,
                      package: 'grab_go_shared',
                      width: 20.w,
                      height: 20.w,
                      colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
                    ),
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SvgPicture.asset(
                  Assets.icons.navArrowRight,
                  package: 'grab_go_shared',
                  width: 20.w,
                  height: 20.w,
                  colorFilter: ColorFilter.mode(
                    colors.textSecondary,
                    BlendMode.srcIn,
                  ),
                ),
              ],
            ),
          ),
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
