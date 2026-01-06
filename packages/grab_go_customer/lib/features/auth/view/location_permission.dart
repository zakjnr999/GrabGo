import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/shared/services/location_service.dart';
import 'package:grab_go_customer/shared/services/storage_service.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class LocationPermission extends StatefulWidget {
  const LocationPermission({super.key});

  @override
  State<LocationPermission> createState() => _LocationPermissionState();
}

class _LocationPermissionState extends State<LocationPermission> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusManager.instance.primaryFocus?.unfocus();
      _animationController.forward();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleAllowLocation() async {
    if (!mounted) return;

    final colors = context.appColors;

    try {
      final isServiceEnabled = await LocationService.isServiceEnabled();
      if (!isServiceEnabled) {
        await LocationService.openLocationSettings();
        return;
      }

      final hasPermission = await LocationService.hasPermission();
      if (hasPermission) {
        await StorageService.setLocationPermissionScreenShown();
        if (mounted) {
          context.go("/notificationPermission");
        }
        return;
      }

      final isDeniedForever = await LocationService.isPermissionDeniedForever();
      if (isDeniedForever) {
        await LocationService.openAppSettings();
        return;
      }

      final permissionResult = await LocationService.requestPermissionAndCheck();

      if (permissionResult == true) {
        // Mark location permission screen as shown
        await StorageService.setLocationPermissionScreenShown();
        if (mounted) {
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) {
            context.go("/notificationPermission");
          }
        }
      } else if (permissionResult == false) {
        if (mounted) {}
      } else if (permissionResult == null) {
        if (mounted) {
          await LocationService.openAppSettings();
        }
      }
    } catch (e) {
      if (mounted) {
        AppToastMessage.show(
          context: context,
          message: "An error occurred while requesting location permission. Please try again.",
          backgroundColor: colors.error,
          duration: const Duration(seconds: 3),
        );
      }
    }
  }

  void _handleSkip() async {
    // Mark location permission screen as shown (even if skipped)
    await StorageService.setLocationPermissionScreenShown();
    if (mounted) {
      context.go("/notificationPermission");
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colors.backgroundPrimary,
      body: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
            systemNavigationBarColor: colors.backgroundPrimary,
            systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: KSpacing.lg.w),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          ScaleTransition(
                            scale: _scaleAnimation,
                            child: FadeTransition(
                              opacity: _fadeAnimation,
                              child: Container(
                                height: 100.h,
                                width: 100.h,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [
                                      colors.accentGreen.withValues(alpha: 0.2),
                                      colors.accentViolet.withValues(alpha: 0.2),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: colors.accentGreen.withValues(alpha: 0.2),
                                      blurRadius: 30,
                                      spreadRadius: 5,
                                    ),
                                  ],
                                ),
                                child: Center(
                                  child: SvgPicture.asset(
                                    Assets.icons.mapPin,
                                    height: 60.h,
                                    width: 60.h,
                                    colorFilter: ColorFilter.mode(colors.accentGreen, BlendMode.srcIn),
                                    package: 'grab_go_shared',
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: KSpacing.lg25.h),

                          FadeTransition(
                            opacity: _fadeAnimation,
                            child: SlideTransition(
                              position: _slideAnimation,
                              child: Text(
                                AppStrings.locationPermissionTitle,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 32.sp,
                                  fontWeight: FontWeight.w900,
                                  color: colors.textPrimary,
                                  letterSpacing: -0.5,
                                  height: 1.2,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: KSpacing.md.h),

                          FadeTransition(
                            opacity: _fadeAnimation,
                            child: SlideTransition(
                              position: _slideAnimation,
                              child: Text(
                                AppStrings.locationPermissionDescription,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 15.sp,
                                  fontWeight: FontWeight.w500,
                                  color: colors.textSecondary,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: KSpacing.xl40.h),

                          FadeTransition(
                            opacity: _fadeAnimation,
                            child: SlideTransition(
                              position: _slideAnimation,
                              child: GestureDetector(
                                onTap: _handleAllowLocation,
                                child: Container(
                                  height: 56.h,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [colors.accentGreen, colors.accentGreen.withValues(alpha: 0.8)],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ),
                                    borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
                                    boxShadow: [
                                      BoxShadow(
                                        color: colors.accentGreen.withValues(alpha: 0.4),
                                        blurRadius: 20,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      AppStrings.locationPermissionAllow,
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          SizedBox(height: KSpacing.lg.h),

                          FadeTransition(
                            opacity: _fadeAnimation,
                            child: SlideTransition(
                              position: _slideAnimation,
                              child: GestureDetector(
                                onTap: _handleSkip,
                                child: Container(
                                  height: 56.h,
                                  decoration: BoxDecoration(
                                    color: colors.backgroundSecondary,
                                    borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
                                    border: Border.all(color: colors.inputBorder, width: 1.5),
                                  ),
                                  child: Center(
                                    child: Text(
                                      AppStrings.locationPermissionSkip,
                                      style: TextStyle(
                                        color: colors.textPrimary,
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
