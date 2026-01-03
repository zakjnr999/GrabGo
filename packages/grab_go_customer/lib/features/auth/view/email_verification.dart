import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class EmailVerification extends StatefulWidget {
  const EmailVerification({super.key});

  @override
  State<EmailVerification> createState() => _EmailVerificationState();
}

class _EmailVerificationState extends State<EmailVerification> with SingleTickerProviderStateMixin {
  final TextEditingController emailController = TextEditingController();
  String? emailError;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
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
    super.initState();
  }

  @override
  void dispose() {
    _animationController.dispose();
    emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: colors.backgroundPrimary,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: colors.backgroundPrimary,
        appBar: AppBar(
          backgroundColor: colors.backgroundPrimary,
          automaticallyImplyLeading: false,
          elevation: 0,
          scrolledUnderElevation: 0,
          leadingWidth: 72,
          leading: SizedBox(
            height: KWidgetSize.buttonHeightSmall.h,
            width: KWidgetSize.buttonHeightSmall.w,
            child: Material(
              color: colors.backgroundPrimary,
              shape: const CircleBorder(),
              child: InkWell(
                onTap: () => context.pop(),
                customBorder: const CircleBorder(),
                splashColor: colors.iconSecondary.withAlpha(50),
                child: Padding(
                  padding: EdgeInsets.all(KSpacing.md12.r),
                  child: SvgPicture.asset(
                    Assets.icons.navArrowLeft,
                    package: 'grab_go_shared',
                    colorFilter: ColorFilter.mode(colors.iconPrimary, BlendMode.srcIn),
                  ),
                ),
              ),
            ),
          ),
        ),
        body: GestureDetector(
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: KSpacing.lg.w, vertical: KSpacing.xl40.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Container(
                        height: 100.h,
                        width: 100.w,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              colors.accentViolet.withValues(alpha: 0.2),
                              colors.accentViolet.withValues(alpha: 0.2),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: colors.accentViolet.withValues(alpha: 0.2),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Center(
                          child: SvgPicture.asset(
                            Assets.icons.shieldCheck,
                            package: 'grab_go_shared',
                            height: 50.h,
                            width: 50.h,
                            colorFilter: ColorFilter.mode(colors.accentViolet, BlendMode.srcIn),
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
                        "Let’s Get You Verified!",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28.sp,
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
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: KSpacing.sm.w),
                        child: Text(
                          "Type in your email so we can send you a verification link. Verify it to unlock your verified badge and access all features.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14.sp,
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
                      child: AppTextInput(
                        controller: emailController,
                        label: AppStrings.loginEmailLabel,
                        hintText: AppStrings.loginEmailHint,
                        borderColor: colors.inputBorder,
                        fillColor: colors.backgroundSecondary,
                        borderActiveColor: colors.accentViolet,
                        borderRadius: KBorderSize.borderRadius15,
                        contentPadding: EdgeInsets.all(KSpacing.md15.r),
                        keyboardType: TextInputType.emailAddress,
                        errorText: emailError,
                        prefixIcon: Padding(
                          padding: EdgeInsets.all(KSpacing.md12.r),
                          child: SvgPicture.asset(
                            Assets.icons.mail,
                            package: 'grab_go_shared',
                            width: KIconSize.md,
                            height: KIconSize.md,
                            colorFilter: ColorFilter.mode(colors.iconSecondary, BlendMode.srcIn),
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
                      child: GestureDetector(
                        onTap: () {},
                        child: Container(
                          height: 50.h,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [colors.accentViolet, colors.accentViolet.withValues(alpha: 0.8)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
                            boxShadow: [
                              BoxShadow(
                                color: colors.accentViolet.withValues(alpha: 0.4),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              "Send Verification Link",
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
