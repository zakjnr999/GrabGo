import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/core/api/api_client.dart';
import 'package:grab_go_customer/shared/services/user_service.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class EmailVerification extends StatefulWidget {
  const EmailVerification({super.key});

  @override
  State<EmailVerification> createState() => _EmailVerificationState();
}

class _EmailVerificationState extends State<EmailVerification> with SingleTickerProviderStateMixin {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController otpController = TextEditingController();

  String? emailError;
  String? otpError;
  bool _isSending = false;
  bool _isVerifying = false;
  bool _codeSent = false;
  bool _isEmailLocked = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    final cachedUser = CacheService.getUserData();
    final cachedEmail = cachedUser?['email']?.toString();
    if (cachedEmail != null && cachedEmail.isNotEmpty) {
      emailController.text = cachedEmail;
      _isEmailLocked = true;
    }

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

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      FocusManager.instance.primaryFocus?.unfocus();
      _animationController.forward();

      final user = await UserService().getCurrentUser(forceRefresh: true);
      if (user?.email != null && user!.email!.isNotEmpty && mounted) {
        setState(() {
          if (emailController.text.trim() != user.email!.trim()) {
            emailController.text = user.email!;
          }
          _isEmailLocked = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    emailController.dispose();
    otpController.dispose();
    super.dispose();
  }

  bool _validateEmail() {
    final email = emailController.text.trim();
    if (email.isEmpty) {
      setState(() {
        emailError = "Email is required";
      });
      return false;
    }
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+');
    if (!emailRegex.hasMatch(email)) {
      setState(() {
        emailError = "Enter a valid email address";
      });
      return false;
    }
    setState(() {
      emailError = null;
    });
    return true;
  }

  bool _validateOtp() {
    final code = otpController.text.trim();
    if (code.isEmpty) {
      setState(() {
        otpError = "Verification code is required";
      });
      return false;
    }
    if (code.length != 6) {
      setState(() {
        otpError = "Enter the 6-digit code";
      });
      return false;
    }
    setState(() {
      otpError = null;
    });
    return true;
  }

  Future<void> _sendVerification() async {
    if (_isSending) return;
    if (!_validateEmail()) return;

    setState(() {
      _isSending = true;
    });
    LoadingDialog.instance().show(context: context, text: "Sending verification code...");

    try {
      final baseUri = Uri.parse(AppConfig.apiBaseUrl);
      final basePath = baseUri.path;
      final hasApiPrefix = basePath == '/api' || basePath.endsWith('/api') || basePath.endsWith('/api/');

      final user = UserService().currentUser;
      final email = emailController.text.trim();

      final endpoint = (user != null && user.email != null && user.email!.isNotEmpty)
          ? (hasApiPrefix ? '/users/send-verification' : '/api/users/send-verification')
          : (hasApiPrefix ? '/users/resend-verification' : '/api/users/resend-verification');

      final response = await chopperClient.post(
        Uri.parse(endpoint),
        body: (user != null && user.email != null && user.email!.isNotEmpty) ? null : {'email': email},
      );

      Map<String, dynamic>? data;
      if (response.body is Map) {
        data = Map<String, dynamic>.from(response.body as Map);
      } else if (response.bodyString.isNotEmpty) {
        final decoded = jsonDecode(response.bodyString);
        if (decoded is Map) {
          data = Map<String, dynamic>.from(decoded);
        }
      }

      if (!response.isSuccessful || (data != null && data['success'] == false)) {
        final message = data?['message']?.toString() ?? "Failed to send verification code.";
        throw Exception(message);
      }

      if (mounted) {
        LoadingDialog.instance().hide();
        AppToastMessage.show(
          context: context,
          message: "Verification code sent to your email.",
          backgroundColor: Colors.green,
        );
        setState(() {
          _codeSent = true;
        });
      }
    } catch (e) {
      if (mounted) {
        LoadingDialog.instance().hide();
        AppToastMessage.show(
          context: context,
          message: e.toString().replaceFirst('Exception:', '').trim(),
          backgroundColor: context.appColors.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _verifyEmail() async {
    if (_isVerifying) return;
    if (!_validateEmail() || !_validateOtp()) return;

    setState(() {
      _isVerifying = true;
    });
    LoadingDialog.instance().show(context: context, text: "Verifying email...");

    try {
      final baseUri = Uri.parse(AppConfig.apiBaseUrl);
      final basePath = baseUri.path;
      final hasApiPrefix = basePath == '/api' || basePath.endsWith('/api') || basePath.endsWith('/api/');
      final endpoint = hasApiPrefix ? '/users/verify-email' : '/api/users/verify-email';

      final response = await chopperClient.post(
        Uri.parse(endpoint),
        body: {'email': emailController.text.trim(), 'otp': otpController.text.trim()},
      );

      Map<String, dynamic>? data;
      if (response.body is Map) {
        data = Map<String, dynamic>.from(response.body as Map);
      } else if (response.bodyString.isNotEmpty) {
        final decoded = jsonDecode(response.bodyString);
        if (decoded is Map) {
          data = Map<String, dynamic>.from(decoded);
        }
      }

      if (!response.isSuccessful || (data != null && data['success'] == false)) {
        final message = data?['message']?.toString() ?? "Failed to verify email.";
        throw Exception(message);
      }

      final userData = data?['user'];
      final token = data?['token']?.toString();
      if (token != null && token.isNotEmpty) {
        await CacheService.saveAuthToken(token);
      }
      if (userData is Map) {
        final user = User.fromJson(Map<String, dynamic>.from(userData));
        await UserService().setCurrentUser(user);
      }

      if (mounted) {
        LoadingDialog.instance().hide();
        AppToastMessage.show(context: context, message: "Email verified successfully.", backgroundColor: Colors.green);
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        LoadingDialog.instance().hide();
        AppToastMessage.show(
          context: context,
          message: e.toString().replaceFirst('Exception:', '').trim(),
          backgroundColor: context.appColors.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isVerifying = false;
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
                          color: colors.accentOrange.withValues(alpha: 0.1),
                        ),
                        child: Center(
                          child: SvgPicture.asset(
                            Assets.icons.shieldCheck,
                            package: 'grab_go_shared',
                            height: 50.h,
                            width: 50.h,
                            colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
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
                        "Verify your email",
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
                          "We’ll send a 6-digit code to your email. Enter it below to verify.",
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
                        borderActiveColor: colors.accentOrange,
                        borderRadius: KBorderSize.borderRadius15,
                        contentPadding: EdgeInsets.all(KSpacing.md15.r),
                        keyboardType: TextInputType.emailAddress,
                        errorText: emailError,
                        readOnly: _isEmailLocked,
                        enabled: true,
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
                        onPressed: _sendVerification,
                        backgroundColor: colors.accentOrange,
                        borderRadius: KBorderSize.borderRadius15,
                        buttonText: _isSending ? "Sending..." : "Send Verification Code",
                        isLoading: _isSending,
                        textStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15.sp),
                      ),
                    ),
                  ),
                  SizedBox(height: KSpacing.lg25.h),
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: AppTextInput(
                        controller: otpController,
                        label: "Verification Code",
                        hintText: "Enter 6-digit code",
                        borderColor: colors.inputBorder,
                        fillColor: colors.backgroundSecondary,
                        borderActiveColor: colors.accentOrange,
                        borderRadius: KBorderSize.borderRadius15,
                        contentPadding: EdgeInsets.all(KSpacing.md15.r),
                        keyboardType: TextInputType.number,
                        errorText: otpError,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      ),
                    ),
                  ),
                  SizedBox(height: KSpacing.lg25.h),
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: AppButton(
                        onPressed: _codeSent
                            ? _verifyEmail
                            : () {
                                AppToastMessage.show(
                                  context: context,
                                  message: "Send the verification code first.",
                                  backgroundColor: context.appColors.warning,
                                );
                              },
                        backgroundColor: colors.backgroundSecondary,
                        borderColor: colors.border,
                        borderRadius: KBorderSize.borderRadius15,
                        buttonText: _isVerifying ? "Verifying..." : "Verify Email",
                        isLoading: _isVerifying,
                        textStyle: TextStyle(color: colors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15.sp),
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
