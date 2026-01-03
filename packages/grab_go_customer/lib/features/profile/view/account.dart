import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/shared/services/user_service.dart';
import 'package:grab_go_customer/features/auth/service/phone_auth_service.dart';
import 'package:grab_go_customer/shared/viewmodels/theme_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:grab_go_customer/shared/utils/image_optimizer.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_customer/shared/viewmodels/favorites_provider.dart';
import 'package:provider/provider.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class Account extends StatefulWidget {
  const Account({super.key});

  @override
  State<Account> createState() => _AccountState();
}

class _AccountState extends State<Account> with SingleTickerProviderStateMixin {
  User? _user;
  bool _isLoading = true;
  late AnimationController _animationController;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(duration: const Duration(milliseconds: 600), vsync: this);
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeInOut));
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      await Future.delayed(const Duration(milliseconds: 100));

      // Try to get user from cache first
      var user = await UserService().getCurrentUser();

      // If no user found, try to fetch from API using stored user ID
      if (user == null) {
        final userId = UserService().currentUser?.id ?? PhoneAuthService().userId;
        if (userId != null && userId.isNotEmpty) {
          user = await UserService().getUserById(userId);
          if (user != null) {
            await UserService().setCurrentUser(user);
          }
        }
      }

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

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleLogout() async {
    final shouldLogout = await AppDialog.show(
      context: context,
      title: 'Logout',
      message: 'Are you sure you want to logout? You will need to sign in again to access your account.',
      type: AppDialogType.logout,
      primaryButtonText: 'Logout',
      secondaryButtonText: 'Cancel',
      primaryButtonColor: Colors.red,
      onPrimaryPressed: () => Navigator.of(context).pop(true),
      onSecondaryPressed: () => Navigator.of(context).pop(false),
    );

    if (shouldLogout == true) {
      await UserService().logout();

      if (mounted) {
        context.go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        final colors = context.appColors;
        final Size size = MediaQuery.sizeOf(context);

        final isDark = Theme.of(context).brightness == Brightness.dark;
        final systemUiOverlayStyle = SystemUiOverlayStyle(
          statusBarColor: Theme.of(context).scaffoldBackgroundColor,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          systemNavigationBarColor: colors.backgroundPrimary,
          systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        );

        SystemChrome.setSystemUIOverlayStyle(systemUiOverlayStyle);

        return Scaffold(
          backgroundColor: colors.backgroundSecondary,
          body: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Account",
                    style: TextStyle(
                      fontFamily: "Lato",
                      package: 'grab_go_shared',
                      color: colors.textPrimary,
                      fontSize: 24.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    "Manage your profile, orders, and settings.",
                    style: TextStyle(
                      fontFamily: "Lato",
                      package: 'grab_go_shared',
                      color: colors.textSecondary,
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Container(
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(KBorderSize.borderRadius15)),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(02.r),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colors.textPrimary.withValues(alpha: 0.1),
                          ),
                          child: ClipOval(
                            child: GestureDetector(
                              onTap: () => context.push("/viewProfile", extra: _user),
                              child: Hero(
                                tag: _user?.profilePicture ?? "",
                                child: CachedNetworkImage(
                                  height: size.width * 0.15,
                                  width: size.width * 0.15,
                                  fit: BoxFit.cover,
                                  imageUrl: ImageOptimizer.getPreviewUrl(_user?.profilePicture ?? "", width: 200),
                                  memCacheWidth: 200,
                                  maxHeightDiskCache: 200,
                                  placeholder: (context, url) => Container(
                                    height: size.width * 0.15,
                                    width: size.width * 0.15,
                                    decoration: BoxDecoration(color: colors.backgroundPrimary, shape: BoxShape.circle),
                                  ),
                                  errorWidget: (context, url, error) => Container(
                                    height: size.width * 0.15,
                                    width: size.width * 0.15,
                                    padding: EdgeInsets.all(12.r),
                                    child: SvgPicture.asset(
                                      Assets.icons.user,
                                      package: "grab_go_shared",
                                      colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 16.w),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _isLoading ? "..." : (_user?.username ?? "Guest User"),
                                style: TextStyle(
                                  color: colors.textPrimary,
                                  fontSize: 18.sp,
                                  fontWeight: FontWeight.w800,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              SizedBox(height: 4.h),
                              Row(
                                children: [
                                  Text(
                                    _isLoading ? "..." : (_user?.email ?? "Please log in to continue"),
                                    style: TextStyle(
                                      color: colors.textPrimary.withValues(alpha: 0.9),
                                      fontSize: 13.sp,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
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
                                            colorFilter: ColorFilter.mode(
                                              colors.textPrimary.withValues(alpha: 0.9),
                                              BlendMode.srcIn,
                                            ),
                                          ),
                                        )
                                      : const SizedBox.shrink(),
                                ],
                              ),
                            ],
                          ),
                        ),

                        Container(
                          decoration: BoxDecoration(
                            color: colors.textPrimary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                context.push("/editProfile");
                              },
                              customBorder: const CircleBorder(),
                              child: Padding(
                                padding: EdgeInsets.all(10.r),

                                child: SvgPicture.asset(
                                  Assets.icons.editPencil,
                                  package: 'grab_go_shared',
                                  height: 20.h,
                                  width: 20.w,
                                  colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 24.h),

                  Text(
                    "General",
                    style: TextStyle(color: colors.textPrimary, fontSize: 16.sp, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 12.h),

                  Container(
                    padding: EdgeInsets.symmetric(vertical: 8.r),
                    decoration: BoxDecoration(
                      color: colors.backgroundPrimary,
                      borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
                      border: Border.all(color: colors.inputBorder.withValues(alpha: 0.3), width: 0.5),
                      boxShadow: [
                        BoxShadow(
                          color: isDark ? Colors.black.withAlpha(30) : Colors.black.withAlpha(8),
                          spreadRadius: 0,
                          blurRadius: 12,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        itemTile("Pickup Location", Assets.icons.sendDiagonal, context, () {
                          context.push("/mapTracking");
                        }),
                        _favoritesTile(context),
                        itemTile("My Orders", Assets.icons.boxIso, context, () {
                          context.push("/orders");
                        }),
                        itemTile("Payment Methods", Assets.icons.cash, context, () {
                          context.push("/paymentMethod");
                        }),
                        itemTile("Refer & Earn", Assets.icons.gift, context, () {
                          context.push("/referral");
                        }),
                        itemTile("Change Password", Assets.icons.lock, context, () {
                          context.push("/orderTracking");
                        }),
                      ],
                    ),
                  ),
                  SizedBox(height: 24.h),

                  Text(
                    "Other Information",
                    style: TextStyle(color: colors.textPrimary, fontSize: 16.sp, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 12.h),

                  Container(
                    padding: EdgeInsets.symmetric(vertical: 8.r),
                    decoration: BoxDecoration(
                      color: colors.backgroundPrimary,
                      borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
                      border: Border.all(color: colors.inputBorder.withValues(alpha: 0.3), width: 0.5),
                      boxShadow: [
                        BoxShadow(
                          color: isDark ? Colors.black.withAlpha(30) : Colors.black.withAlpha(8),
                          spreadRadius: 0,
                          blurRadius: 12,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        itemTile("Settings", Assets.icons.settings, context, () {
                          context.push("/settings");
                        }),
                        itemTile("Vender Registration", Assets.icons.store, context, () {
                          context.push("/restaurantRegistration");
                        }),
                        itemTile("Notifications", Assets.icons.bell, context, () {
                          context.push("/notification");
                        }),
                        itemTile("Help & Support", Assets.icons.headsetHelp, context, () {
                          //Do nothing for now
                        }),
                        itemTile("About App", Assets.icons.infoCircle, context, () {
                          //Do nothing for now
                        }),
                        itemTile("Logout", Assets.icons.logOut, context, () {
                          _handleLogout();
                        }),
                      ],
                    ),
                  ),
                  SizedBox(height: 24.h),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget itemTile(String title, String icon, BuildContext context, VoidCallback onTap) {
    final colors = context.appColors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        splashColor: colors.accentOrange.withValues(alpha: 0.1),
        highlightColor: colors.accentOrange.withValues(alpha: 0.05),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(color: colors.backgroundSecondary, borderRadius: BorderRadius.circular(10.r)),
                child: SvgPicture.asset(
                  icon,
                  package: 'grab_go_shared',
                  height: 18.h,
                  width: 18.w,
                  colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
                ),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 14.sp, color: colors.textPrimary, fontWeight: FontWeight.w600),
                ),
              ),
              SvgPicture.asset(
                Assets.icons.navArrowRight,
                package: 'grab_go_shared',
                height: 20.h,
                width: 20.w,
                colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _favoritesTile(BuildContext context) {
    final colors = context.appColors;

    return Consumer<FavoritesProvider>(
      builder: (context, favoritesProvider, child) {
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              context.push("/favorites");
            },
            splashColor: colors.accentOrange.withValues(alpha: 0.1),
            highlightColor: colors.accentOrange.withValues(alpha: 0.05),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8.r),
                        decoration: BoxDecoration(
                          color: colors.backgroundSecondary,
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: SvgPicture.asset(
                          Assets.icons.heart,
                          package: 'grab_go_shared',
                          height: 18.h,
                          width: 18.w,
                          colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
                        ),
                      ),
                      SizedBox(width: 14.w),
                      Expanded(
                        child: Text(
                          "Favorites",
                          style: TextStyle(fontSize: 14.sp, color: colors.textPrimary, fontWeight: FontWeight.w600),
                        ),
                      ),
                      // Favorites count badge
                      if (favoritesProvider.favoritesCount > 0)
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                          decoration: BoxDecoration(
                            color: colors.accentOrange,
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          child: Text(
                            "${favoritesProvider.favoritesCount}",
                            style: TextStyle(fontSize: 12.sp, color: Colors.white, fontWeight: FontWeight.w700),
                          ),
                        ),
                      SizedBox(width: 8.w),
                      SvgPicture.asset(
                        Assets.icons.navArrowRight,
                        package: 'grab_go_shared',
                        height: 20.h,
                        width: 20.w,
                        colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                      ),
                    ],
                  ),
                  if (favoritesProvider.hasFavorites) ...[
                    SizedBox(height: 14.h),
                    SizedBox(
                      height: 60.h,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: favoritesProvider.favoriteItems.length,
                        padding: EdgeInsets.zero,
                        itemBuilder: (context, index) {
                          final item = favoritesProvider.favoriteItems.toList()[index];
                          return Container(
                            margin: EdgeInsets.only(right: 8.w),
                            width: 60.w,
                            height: 60.h,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(KBorderSize.borderRadius12),
                              color: colors.inputBorder.withValues(alpha: 0.5),
                            ),
                            child: ClipRRect(
                              borderRadius: const BorderRadius.all(Radius.circular(KBorderSize.borderRadius12)),
                              child: CachedNetworkImage(
                                imageUrl: ImageOptimizer.getPreviewUrl(item.image, width: 100),
                                fit: BoxFit.cover,
                                memCacheWidth: 100,
                                maxHeightDiskCache: 100,
                                placeholder: (context, url) {
                                  return Container(
                                    color: colors.backgroundSecondary,
                                    child: Center(
                                      child: SvgPicture.asset(
                                        Assets.icons.utensilsCrossed,
                                        package: 'grab_go_shared',
                                        height: 24.h,
                                        width: 24.w,
                                        colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                                      ),
                                    ),
                                  );
                                },
                                errorWidget: (context, url, error) {
                                  return Container(
                                    color: colors.backgroundSecondary,
                                    child: Center(
                                      child: SvgPicture.asset(
                                        Assets.icons.utensilsCrossed,
                                        package: 'grab_go_shared',
                                        height: 24.h,
                                        width: 24.w,
                                        colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
