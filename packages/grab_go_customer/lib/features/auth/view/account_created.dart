import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/shared/services/location_service.dart';
import 'package:grab_go_customer/shared/services/storage_service.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class AccountCreated extends StatefulWidget {
  const AccountCreated({super.key});

  @override
  State<AccountCreated> createState() => _AccountCreatedState();
}

class _AccountCreatedState extends State<AccountCreated> with SingleTickerProviderStateMixin {
  final TextEditingController phoneController = TextEditingController();
  late AnimationController animationController;
  late Animation<double> scaleAnimation;
  late Animation<double> fadeAnimation;
  late Animation<Offset> slideAnimation;

  @override
  void initState() {
    super.initState();

    animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));

    scaleAnimation = CurvedAnimation(
      parent: animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
    );

    fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: animationController,
        curve: const Interval(0.4, 0.9, curve: Curves.easeIn),
      ),
    );

    slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(
        parent: animationController,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      animationController.forward();
    });
  }

  @override
  void dispose() {
    animationController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  /// Navigate after account created - check location permission if first time
  Future<void> _navigateAfterRegistration(BuildContext context) async {
    // Check if location permission screen has been shown before
    final hasShownLocationScreen = StorageService.hasLocationPermissionScreenShown();

    if (!hasShownLocationScreen) {
      // First time registration - check location permission
      final hasPermission = await LocationService.hasPermission();
      if (!hasPermission) {
        // Show location permission screen
        if (context.mounted) {
          context.go("/locationPermission");
        }
        return;
      } else {
        // Permission already granted, mark screen as shown and go to homepage
        await StorageService.setLocationPermissionScreenShown();
      }
    }

    // Navigate to homepage
    if (context.mounted) {
      context.push("/homepage");
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    Size size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: colors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: colors.backgroundPrimary,
        automaticallyImplyLeading: false,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
          systemNavigationBarColor: colors.backgroundPrimary,
          systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: KSpacing.lg.w, vertical: KSpacing.xl40.h),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: 180.h),
                  FadeTransition(
                    opacity: fadeAnimation,
                    child: SlideTransition(
                      position: slideAnimation,
                      child: Text(
                        AppStrings.accountCreatedMain,
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
                  SizedBox(height: KSpacing.lg.h),

                  FadeTransition(
                    opacity: fadeAnimation,
                    child: SlideTransition(
                      position: slideAnimation,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: KSpacing.lg25.w),
                        child: Text(
                          AppStrings.accountCreatedSub,
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
                  ),
                  SizedBox(height: KSpacing.xl40.h),

                  FadeTransition(
                    opacity: fadeAnimation,
                    child: SlideTransition(
                      position: slideAnimation,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: KSpacing.lg.w),
                        child: GestureDetector(
                          onTap: () async {
                            FocusManager.instance.primaryFocus?.unfocus();
                            LoadingDialog.instance().show(context: context);
                            await Future.delayed(const Duration(seconds: 1));
                            if (mounted) {
                              LoadingDialog.instance().show(context: context, text: "Almost done..");
                            }
                            await Future.delayed(const Duration(seconds: 1));
                            LoadingDialog.instance().hide();

                            // Check if location permission screen should be shown (first time registration)
                            await _navigateAfterRegistration(context);
                          },
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
                                "Continue to Home",
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
                  ),
                ],
              ),
            ),
          ),
        ),
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.centerTop,
      floatingActionButton: Container(
        margin: EdgeInsets.only(top: size.height * 0.22),
        child: ScaleTransition(
          scale: scaleAnimation,
          child: Container(
            height: 140.h,
            width: 140.h,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [colors.accentGreen.withValues(alpha: 0.2), colors.accentGreen.withValues(alpha: 0.1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(color: colors.accentGreen.withValues(alpha: 0.3), blurRadius: 40, spreadRadius: 10),
              ],
            ),
            child: Center(
              child: Container(
                height: 120.h,
                width: 120.h,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [colors.accentGreen, colors.accentGreen.withValues(alpha: 0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: colors.accentGreen.withValues(alpha: 0.5),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Center(
                  child: SvgPicture.asset(
                    Assets.icons.checkBig,
                    package: 'grab_go_shared',
                    height: 60.h,
                    width: 60.h,
                    colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
