// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class AccountCreated extends StatefulWidget {
  const AccountCreated({super.key});

  @override
  State<AccountCreated> createState() => _AccountCreatedState();
}

class _AccountCreatedState extends State<AccountCreated> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));

    _scaleAnimation = CurvedAnimation(
      parent: _animationController,
      curve: const Interval(0.0, 0.6, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.4, 0.9, curve: Curves.easeIn),
      ),
    );

    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animationController.forward();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: KSpacing.lg.w, vertical: KSpacing.xl40.h),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(height: 180.h),
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Text(
                          "Your Account Is Under Review",
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
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: KSpacing.lg25.w),
                          child: Text(
                            "We've received your verification details. Our team is reviewing your information to ensure everything checks out. \nYou'll be notified once your account has been approved. This process usually takes 24-48 hours. You can check your application status anytime from the app.",
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
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: KSpacing.lg.w),
                          child: GestureDetector(
                            onTap: () {
                              context.go("/home");
                            },
                            child: Container(
                              height: 56.h,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [colors.accentOrange, colors.accentOrange.withOpacity(0.8)],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                                boxShadow: [
                                  BoxShadow(
                                    color: colors.accentOrange.withOpacity(0.4),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  "Go to Dashboard",
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
                    SizedBox(height: KSpacing.lg.h),

                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: KSpacing.lg.w),
                          child: GestureDetector(
                            onTap: () {
                              context.go("/riderAccountTracking");
                            },
                            child: Container(
                              height: 56.h,
                              decoration: BoxDecoration(
                                border: BoxBorder.all(color: colors.inputBorder, width: 1),
                                gradient: LinearGradient(
                                  colors: [colors.backgroundSecondary, colors.backgroundSecondary.withOpacity(0.8)],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                                boxShadow: [
                                  BoxShadow(
                                    color: colors.backgroundSecondary.withOpacity(0.4),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  "Track Application Status",
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
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.centerTop,
      floatingActionButton: Container(
        margin: EdgeInsets.only(top: size.height * 0.22),
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Container(
            height: 120.h,
            width: 120.h,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
              gradient: LinearGradient(
                colors: [colors.accentOrange.withOpacity(0.2), colors.accentOrange.withOpacity(0.1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [BoxShadow(color: colors.accentOrange.withOpacity(0.3), blurRadius: 40, spreadRadius: 10)],
            ),
            child: Center(
              child: Container(
                height: 100.h,
                width: 100.h,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [colors.accentOrange, colors.accentOrange.withOpacity(0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                  boxShadow: [
                    BoxShadow(color: colors.accentOrange.withOpacity(0.5), blurRadius: 30, offset: const Offset(0, 10)),
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
