import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_rider/core/api/api_client.dart';

class VerifyEmail extends StatefulWidget {
  const VerifyEmail({super.key});

  @override
  State<VerifyEmail> createState() => _VerifyEmailState();
}

class _VerifyEmailState extends State<VerifyEmail> with SingleTickerProviderStateMixin {
  final TextEditingController emailController = TextEditingController();
  String? emailError;
  bool isLoading = false;
  bool isResending = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _loadUserEmail();

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

  Future<void> _loadUserEmail() async {
    try {
      final userData = CacheService.getUserData();
      if (userData != null && userData['email'] != null) {
        emailController.text = userData['email'];
      }
    } catch (e) {
      // Continue without email
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    emailController.dispose();
    super.dispose();
  }

  Future<bool> _checkInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
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

  Future<void> _sendVerificationEmail() async {
    if (!_validateEmail()) {
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();

    final hasInternet = await _checkInternetConnection();
    if (!hasInternet) {
      if (mounted) {
        AppToastMessage.show(
          context: context,
          message: "No internet connection. Please check your network settings.",
          backgroundColor: context.appColors.error,
        );
      }
      return;
    }

    setState(() {
      isResending = true;
    });

    try {
      final response = await authService
          .resendVerification({'email': emailController.text.trim()})
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw TimeoutException('Request timeout. Please try again.');
            },
          );

      if (!mounted) return;

      if (response.isSuccessful && response.body != null) {
        if (mounted) {
          context.push("/emailOtpVerification", extra: emailController.text.trim());
        }
      } else {
        String errorMessage = "Failed to send verification email. Please try again.";
        if (response.statusCode == 400) {
          errorMessage = "Invalid email address.";
        } else if (response.statusCode == 500) {
          errorMessage = "Server error. Please try again later.";
        }

        AppToastMessage.show(context: context, message: errorMessage, backgroundColor: context.appColors.error);
      }
    } on SocketException {
      AppToastMessage.show(
        context: context,
        message: "Cannot connect to server. Please try again.",
        backgroundColor: context.appColors.error,
      );
    } on TimeoutException {
      AppToastMessage.show(
        context: context,
        message: "Request timeout. Please try again.",
        backgroundColor: context.appColors.error,
      );
    } catch (e) {
      AppToastMessage.show(
        context: context,
        message: "An unexpected error occurred. Please try again.",
        backgroundColor: context.appColors.error,
      );
    } finally {
      if (mounted) {
        setState(() {
          isResending = false;
        });
      }
    }
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
                onTap: () {
                  context.pop();
                },
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
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: KSpacing.lg.w, vertical: KSpacing.xl40.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Container(
                        height: 80.h,
                        width: 80.w,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                          color: colors.accentGreen.withValues(alpha: 0.15),
                        ),
                        child: Center(
                          child: SvgPicture.asset(
                            Assets.icons.shieldCheck,
                            package: 'grab_go_shared',
                            height: 50.h,
                            width: 50.h,
                            colorFilter: ColorFilter.mode(colors.accentGreen, BlendMode.srcIn),
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
                        "Let's Get You Verified!",
                        textAlign: TextAlign.left,
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
                        padding: EdgeInsets.zero,
                        child: Text(
                          "Enter your email address below and tap the button to receive a verification code. We'll send a 6-digit code to your email. After verification, you'll be able to complete your rider registration.",
                          textAlign: TextAlign.left,
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
                        borderActiveColor: colors.accentGreen,
                        borderRadius: KBorderSize.borderRadius4,
                        contentPadding: EdgeInsets.all(KSpacing.md15.r),
                        keyboardType: TextInputType.emailAddress,
                        errorText: emailError,
                        enabled: !isResending,
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
                      child: AppButton(
                        width: double.infinity,
                        height: 56.h,
                        buttonText: 'SEND CODE',
                        onPressed: () => isResending ? null : _sendVerificationEmail,
                        backgroundColor: colors.accentGreen,
                        borderRadius: KBorderSize.borderRadius4,
                        textStyle: TextStyle(
                          color: Colors.white,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: KSpacing.md.h),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
