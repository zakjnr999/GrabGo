import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/shared/services/user_service.dart';
import 'package:grab_go_customer/features/auth/service/phone_auth_service.dart';
import 'package:grab_go_customer/shared/viewmodels/theme_provider.dart';
import 'package:grab_go_customer/shared/widgets/cached_image_widget.dart';
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
          appBar: AppBar(
            automaticallyImplyLeading: false,
            elevation: 0,
            scrolledUnderElevation: 0,
            backgroundColor: colors.backgroundSecondary,
            title: Row(
              children: [
                SizedBox(width: 44.w),
                const Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    color: colors.backgroundPrimary,
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(color: colors.inputBorder.withValues(alpha: 0.3), width: 0.5),
                    boxShadow: [
                      BoxShadow(
                        color: isDark ? Colors.black.withAlpha(20) : Colors.black.withAlpha(5),
                        spreadRadius: 0,
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: EdgeInsets.all(6.r),
                        decoration: BoxDecoration(
                          color: colors.accentViolet.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: SvgPicture.asset(
                          Assets.icons.user,
                          package: 'grab_go_shared',
                          height: 16.h,
                          width: 16.w,
                          colorFilter: ColorFilter.mode(colors.accentViolet, BlendMode.srcIn),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Text(
                        "My Account",
                        style: TextStyle(
                          fontFamily: "Lato",
                          package: 'grab_go_shared',
                          color: colors.textPrimary,
                          fontSize: 17.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                Container(
                  height: 44.h,
                  width: 44.w,
                  decoration: BoxDecoration(
                    color: colors.backgroundPrimary,
                    shape: BoxShape.circle,
                    border: Border.all(color: colors.inputBorder.withValues(alpha: 0.3), width: 0.5),
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
                                child: SvgPicture.asset(
                                  themeProvider.themeMode == ThemeMode.light
                                      ? Assets.icons.sunLight
                                      : themeProvider.themeMode == ThemeMode.dark
                                      ? Assets.icons.halfMoon
                                      : Assets.icons.sunMoon,
                                  key: ValueKey(themeProvider.themeMode),
                                  package: "grab_go_shared",
                                  colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          body: SafeArea(
            top: false,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: EdgeInsets.all(20.r),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [colors.accentViolet, colors.accentViolet.withValues(alpha: 0.8)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
                      boxShadow: [
                        BoxShadow(
                          color: colors.accentViolet.withValues(alpha: 0.3),
                          spreadRadius: 0,
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(4.r),
                          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.2)),
                          child: ClipOval(
                            child: GestureDetector(
                              onTap: () => context.push("/viewProfile", extra: _user),
                              child: Hero(
                                tag: _user?.profilePicture ?? "",
                                child: CachedImageWidget(
                                  height: size.width * 0.15,
                                  width: size.width * 0.15,
                                  imageUrl: _user?.profilePicture ?? "",
                                  placeholder: Container(
                                    height: size.width * 0.15,
                                    width: size.width * 0.15,
                                    decoration: BoxDecoration(color: colors.backgroundPrimary, shape: BoxShape.circle),
                                  ),
                                  errorWidget: Assets.icons.noProfile.image(
                                    height: size.width * 0.15,
                                    width: size.width * 0.15,
                                    fit: BoxFit.cover,
                                    package: 'grab_go_shared',
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
                                style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.w800),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              SizedBox(height: 4.h),
                              Row(
                                children: [
                                  Text(
                                    _isLoading ? "..." : (_user?.email ?? "Please log in to continue"),
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.9),
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
                                            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                                          ),
                                        )
                                      : const SizedBox.shrink(),
                                ],
                              ),
                            ],
                          ),
                        ),

                        Container(
                          padding: EdgeInsets.all(10.r),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                context.push("/editProfile");
                              },
                              customBorder: const CircleBorder(),
                              child: SvgPicture.asset(
                                Assets.icons.editPencil,
                                package: 'grab_go_shared',
                                height: 20.h,
                                width: 20.w,
                                colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
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
                        itemTile("Payment Methods", Assets.icons.creditCard, context, () {
                          context.push("/paymentMethod");
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
                        itemTile("Register Restaurant", Assets.icons.chefHat, context, () {
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
              Icon(Icons.arrow_forward_ios, size: 16.sp, color: colors.textSecondary),
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
              child: Row(
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
                      decoration: BoxDecoration(color: colors.accentOrange, borderRadius: BorderRadius.circular(12.r)),
                      child: Text(
                        "${favoritesProvider.favoritesCount}",
                        style: TextStyle(fontSize: 12.sp, color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                    ),
                  SizedBox(width: 8.w),
                  Icon(Icons.arrow_forward_ios, size: 16.sp, color: colors.textSecondary),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
