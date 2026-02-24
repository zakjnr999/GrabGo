import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/shared/services/storage_service.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_shared/shared/services/device_id_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:grab_go_customer/shared/services/user_service.dart';
import 'package:grab_go_customer/shared/services/notification_handler.dart';

class NotificationPermission extends StatefulWidget {
  final String? nextRoute;
  final Object? nextExtra;

  const NotificationPermission({super.key, this.nextRoute, this.nextExtra});

  @override
  State<NotificationPermission> createState() => _NotificationPermissionState();
}

class _NotificationPermissionState extends State<NotificationPermission> with SingleTickerProviderStateMixin {
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

  Future<void> _initializePushNotifications() async {
    try {
      await PushNotificationService().initialize(
        onNotificationTap: handleNotificationTap,
        onTokenRefresh: (token) async {
          try {
            if (UserService().isLoggedIn) {
              final deviceId = await DeviceIdService().getDeviceId();
              await UserService().registerFcmToken(
                token,
                platform: Platform.isIOS ? 'ios' : 'android',
                deviceId: deviceId,
              );
            }
          } catch (_) {}
        },
      );

      final initialized = PushNotificationService().isInitialized;

      if (initialized) {
        final token = await PushNotificationService().getToken();
        if (token != null && UserService().isLoggedIn) {
          final deviceId = await DeviceIdService().getDeviceId();
          await UserService().registerFcmToken(token, platform: Platform.isIOS ? 'ios' : 'android', deviceId: deviceId);
        }
      }

      if (!mounted) return;
      await StorageService.setNotificationPermissionScreenShown();
      _navigateNext();
    } catch (e) {
      if (mounted) {
        await StorageService.setNotificationPermissionScreenShown();
        _navigateNext();
      }
    }
  }

  Future<void> _requestPermission() async {
    try {
      final currentStatus = await Permission.notification.status;
      if (currentStatus.isGranted) {
        await _initializePushNotifications();
        return;
      } else if (currentStatus.isPermanentlyDenied) {
        if (!mounted) return;
        await openAppSettings();
        return;
      } else {
        final permissionStatus = await Permission.notification.request();
        if (permissionStatus.isGranted) {
          await _initializePushNotifications();
          return;
        } else if (permissionStatus.isPermanentlyDenied) {
          if (!mounted) return;
          await openAppSettings();
          return;
        } else {
          if (!mounted) return;
          await StorageService.setNotificationPermissionScreenShown();
          _navigateNext();
          return;
        }
      }
    } catch (e) {
      if (mounted) {
        AppToastMessage.show(
          context: context,
          message: "An error occurred while requesting notication permission. Please try again.",
          backgroundColor: AppColors.errorRed,
          duration: const Duration(seconds: 3),
        );
      }
    }
  }

  void _skip() async {
    await StorageService.setNotificationPermissionScreenShown();
    if (mounted) {
      _navigateNext();
    }
  }

  void _navigateNext() {
    if (!mounted) return;
    if (widget.nextRoute != null) {
      context.go(widget.nextRoute!, extra: widget.nextExtra);
      return;
    }
    context.go("/location-picker", extra: {"goHomeOnComplete": true});
  }

  @override
  dispose() {
    _animationController.dispose();
    super.dispose();
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
                                decoration: BoxDecoration(shape: BoxShape.circle, color: colors.accentOrange),
                                child: Center(
                                  child: SvgPicture.asset(
                                    Assets.icons.bell,
                                    height: 40.h,
                                    width: 40.h,
                                    colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
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
                                AppStrings.notificationPermissionTitle,
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
                                AppStrings.notificationPermissionDescription,
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
                              child: AppButton(
                                width: double.infinity,
                                onPressed: () => _requestPermission(),
                                buttonText: "Allow Notifications",
                                textStyle: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                                backgroundColor: colors.accentOrange,
                                padding: EdgeInsets.symmetric(vertical: 16.h),
                                borderRadius: KBorderSize.borderMedium,
                              ),
                            ),
                          ),

                          SizedBox(height: KSpacing.lg.h),

                          FadeTransition(
                            opacity: _fadeAnimation,
                            child: SlideTransition(
                              position: _slideAnimation,
                              child: AppButton(
                                width: double.infinity,
                                onPressed: () => _skip(),
                                buttonText: "Skip",
                                textStyle: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w800,
                                  color: colors.textPrimary,
                                  letterSpacing: 0.5,
                                ),
                                backgroundColor: colors.backgroundSecondary,
                                padding: EdgeInsets.symmetric(vertical: 16.h),
                                borderRadius: KBorderSize.borderMedium,
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
