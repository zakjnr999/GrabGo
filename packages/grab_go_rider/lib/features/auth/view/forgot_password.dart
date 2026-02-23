import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class ForgotPassword extends StatefulWidget {
  const ForgotPassword({super.key});

  @override
  State<ForgotPassword> createState() => _VerifyPhoneState();
}

class _VerifyPhoneState extends State<ForgotPassword> with SingleTickerProviderStateMixin {
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();

  String? emailError;

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
    phoneController.dispose();
    emailController.dispose();
    super.dispose();
  }

  bool _validateEmail() {
    setState(() {
      emailError = null;

      if (emailController.text.trim().isEmpty) {
        emailError = "Please enter your email address";
      } else if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(emailController.text.trim())) {
        emailError = "Please enter a valid email address";
      }
    });

    return emailError == null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
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
              onTap: () {
                context.pop();
              },
              customBorder: const CircleBorder(),
              splashColor: Colors.black.withAlpha(50),
              child: Padding(
                padding: EdgeInsets.all(KSpacing.md12.r),
                child: SvgPicture.asset(
                  Assets.icons.navArrowLeft,
                  package: 'grab_go_shared',
                  colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
                ),
              ),
            ),
          ),
        ),
      ),
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
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: KSpacing.lg.w, vertical: KSpacing.xl40.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: KSpacing.xl40.h),

                  Align(
                    alignment: Alignment.centerLeft,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: FadeTransition(
                        opacity: _fadeAnimation,
                        child: Container(
                          height: 80.h,
                          width: 80.h,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                            color: colors.accentGreen.withValues(alpha: 0.15),
                          ),
                          child: Center(
                            child: SvgPicture.asset(
                              Assets.icons.lock,
                              package: 'grab_go_shared',
                              height: 48.h,
                              width: 48.h,
                              colorFilter: ColorFilter.mode(colors.accentGreen, BlendMode.srcIn),
                            ),
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
                        AppStrings.forgotPasswordMain,
                        textAlign: TextAlign.left,
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
                        AppStrings.forgotPasswordSub,
                        textAlign: TextAlign.left,
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AppTextInput(
                            controller: emailController,
                            label: AppStrings.loginEmailLabel,
                            hintText: AppStrings.loginEmailHint,
                            fillColor: colors.backgroundSecondary,
                            borderActiveColor: colors.accentGreen,
                            borderRadius: KBorderSize.borderRadius4,
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

                          SizedBox(height: KSpacing.lg25.h),

                          AppButton(
                            width: double.infinity,
                            height: 56.h,
                            buttonText: 'Send Reset Link',
                            onPressed: () async {
                              if (!_validateEmail()) {
                                return;
                              }

                              FocusManager.instance.primaryFocus?.unfocus();
                              LoadingDialog.instance().show(
                                context: context,
                                text: "Checking connection...",
                                spinColor: colors.accentGreen,
                              );
                              await Future.delayed(const Duration(seconds: 1));
                              if (mounted) {
                                LoadingDialog.instance().show(context: context, text: "Almost done..");
                              }
                              await Future.delayed(const Duration(seconds: 1));
                              LoadingDialog.instance().hide();
                            },
                            backgroundColor: colors.accentGreen,
                            borderRadius: KBorderSize.borderRadius4,
                            textStyle: TextStyle(
                              color: Colors.white,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                          SizedBox(height: KSpacing.lg25.h),

                          GestureDetector(
                            onTap: () => context.pop(),
                            child: RichText(
                              text: TextSpan(
                                text: "Remember your password? ",
                                style: TextStyle(
                                  fontFamily: "Lato",
                                  package: 'grab_go_shared',
                                  color: colors.textSecondary,
                                  fontSize: KTextSize.small.sp,
                                  height: 1.4,
                                ),
                                children: [
                                  TextSpan(
                                    text: " Sign In",
                                    style: TextStyle(
                                      fontFamily: "Lato",
                                      package: 'grab_go_shared',
                                      fontWeight: FontWeight.w600,
                                      color: colors.accentGreen,
                                      fontSize: KTextSize.small.sp,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
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
