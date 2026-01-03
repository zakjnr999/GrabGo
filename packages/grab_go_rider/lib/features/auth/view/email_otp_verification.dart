import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_otp_text_field/flutter_otp_text_field.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_rider/core/api/api_client.dart';
import 'package:grab_go_rider/shared/service/user_service.dart';

class EmailOtpVerification extends StatefulWidget {
  const EmailOtpVerification({super.key, required this.email});

  final String email;

  @override
  State<EmailOtpVerification> createState() => _EmailOtpVerificationState();
}

class _EmailOtpVerificationState extends State<EmailOtpVerification> with SingleTickerProviderStateMixin {
  String? verificationCode;
  bool isLoading = false;
  int countdown = 60;
  bool canResend = false;
  Timer? _countdownTimer;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // Setup animations
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

    _startCountdown();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animationController.forward();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    countdown = 60;
    canResend = false;

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          countdown--;
          if (countdown <= 0) {
            canResend = true;
            timer.cancel();
          }
        });
      } else {
        timer.cancel();
      }
    });
  }

  Future<bool> _checkInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _verifyOTP(String otp) async {
    FocusManager.instance.primaryFocus?.unfocus();

    final hasInternet = await _checkInternetConnection();
    if (!hasInternet) {
      if (mounted) {
        AppToastMessage.show(
          context: context,
          icon: Icons.wifi_off,
          message: "No internet connection. Please check your network settings.",
          backgroundColor: context.appColors.error,
        );
      }
      return;
    }

    LoadingDialog.instance().show(context: context, text: "Verifying code...");

    setState(() {
      isLoading = true;
    });

    try {
      final response = await authService
          .verifyEmail({'email': widget.email, 'otp': otp})
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw TimeoutException('Request timeout. Please try again.');
            },
          );

      if (!mounted) return;

      LoadingDialog.instance().hide();

      if (response.isSuccessful && response.body != null) {
        final success = response.body!['success'] as bool? ?? false;
        if (success) {
          // Email verified successfully - use the user data from the response
          final responseUser = response.body!['user'];
          final responseToken = response.body!['token'];

          if (responseUser != null) {
            // Update token if provided
            if (responseToken != null && responseToken.toString().isNotEmpty) {
              await CacheService.saveAuthToken(responseToken.toString());
            }

            // Update user data with verified status
            await UserService().setCurrentUser(User.fromJson(responseUser));

            if (mounted) {
              await Future.delayed(const Duration(milliseconds: 200));
              if (mounted) {
                context.push("/riderVerification");
              }
            }
          } else {
            // Fallback: refresh user data if response doesn't include user
            final userData = CacheService.getUserData();
            if (userData != null && userData['_id'] != null) {
              final userId = userData['_id'];
              final userResponse = await authService
                  .getUser(userId)
                  .timeout(const Duration(seconds: 10), onTimeout: () => throw TimeoutException('Request timeout'));

              if (userResponse.isSuccessful && userResponse.body != null) {
                final user = userResponse.body!.userData ?? userResponse.body!.user;
                if (user != null) {
                  await UserService().setCurrentUser(user);
                  if (mounted) {
                    await Future.delayed(const Duration(milliseconds: 200));
                    if (mounted) {
                      context.push("/riderVerification");
                    }
                  }
                }
              }
            }
          }
        } else {
          String errorMessage = response.body!['message'] as String? ?? "Invalid verification code. Please try again.";
          AppToastMessage.show(
            context: context,
            icon: Icons.error_outline,
            message: errorMessage,
            backgroundColor: context.appColors.error,
          );
        }
      } else {
        String errorMessage = "Invalid verification code. Please try again.";
        if (response.statusCode == 400) {
          errorMessage = "Invalid or expired verification code.";
        } else if (response.statusCode == 500) {
          errorMessage = "Server error. Please try again later.";
        }

        AppToastMessage.show(
          context: context,
          icon: Icons.error_outline,
          message: errorMessage,
          backgroundColor: context.appColors.error,
        );
      }
    } on SocketException {
      if (mounted) {
        AppToastMessage.show(
          context: context,
          icon: Icons.cloud_off,
          message: "Cannot connect to server. Please try again.",
          backgroundColor: context.appColors.error,
        );
      }
    } on TimeoutException {
      if (mounted) {
        AppToastMessage.show(
          context: context,
          icon: Icons.timer_off,
          message: "Request timeout. Please try again.",
          backgroundColor: context.appColors.error,
        );
      }
    } catch (e) {
      if (mounted) {
        AppToastMessage.show(
          context: context,
          icon: Icons.error,
          message: "An unexpected error occurred. Please try again.",
          backgroundColor: context.appColors.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> _resendOTP() async {
    if (isLoading) return;

    final hasInternet = await _checkInternetConnection();
    if (!hasInternet) {
      if (mounted) {
        AppToastMessage.show(
          context: context,
          icon: Icons.wifi_off,
          message: "No internet connection. Please check your network settings.",
          backgroundColor: context.appColors.error,
        );
      }
      return;
    }

    LoadingDialog.instance().show(context: context, text: "Resending code...");

    setState(() {
      isLoading = true;
      canResend = false;
    });

    try {
      final response = await authService
          .resendVerification({'email': widget.email})
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw TimeoutException('Request timeout. Please try again.');
            },
          );

      if (!mounted) return;

      LoadingDialog.instance().hide();

      if (response.isSuccessful && response.body != null) {
        _startCountdown();
      } else {
        String errorMessage = "Failed to resend code. Please try again.";
        if (response.statusCode == 400) {
          errorMessage = "Invalid email address.";
        } else if (response.statusCode == 500) {
          errorMessage = "Server error. Please try again later.";
        }

        AppToastMessage.show(
          context: context,
          icon: Icons.error_outline,
          message: errorMessage,
          backgroundColor: context.appColors.error,
        );
        setState(() {
          canResend = true;
        });
      }
    } on SocketException {
      if (mounted) {
        AppToastMessage.show(
          context: context,
          icon: Icons.cloud_off,
          message: "Cannot connect to server. Please try again.",
          backgroundColor: context.appColors.error,
        );
        setState(() {
          canResend = true;
        });
      }
    } on TimeoutException {
      if (mounted) {
        AppToastMessage.show(
          context: context,
          icon: Icons.timer_off,
          message: "Request timeout. Please try again.",
          backgroundColor: context.appColors.error,
        );
        setState(() {
          canResend = true;
        });
      }
    } catch (e) {
      if (mounted) {
        AppToastMessage.show(
          context: context,
          icon: Icons.error,
          message: "An unexpected error occurred. Please try again.",
          backgroundColor: context.appColors.error,
        );
        setState(() {
          canResend = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
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
            padding: EdgeInsets.symmetric(horizontal: KSpacing.lg.w, vertical: KSpacing.xl40.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: KSpacing.xl40.h),

                ScaleTransition(
                  scale: _scaleAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Container(
                      height: 80.h,
                      width: 80.w,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                        color: colors.accentViolet.withValues(alpha: 0.15),
                      ),
                      child: Center(
                        child: SvgPicture.asset(
                          Assets.icons.shieldCheck,
                          package: 'grab_go_shared',
                          height: 50.h,
                          width: 50.w,
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
                      AppStrings.otpMain,
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
                    child: Padding(
                      padding: EdgeInsets.zero,
                      child: Text(
                        "Enter the 6-digit code sent to ${widget.email}. \n If you didn't receive the code, please check your spam folder or request a new code.",
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
                ),
                SizedBox(height: KSpacing.xl.h),

                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        OtpTextField(
                          numberOfFields: 6,
                          borderColor: colors.inputBorder,
                          enabledBorderColor: colors.inputBorder,
                          disabledBorderColor: colors.inputBorder,
                          fillColor: colors.backgroundSecondary,
                          filled: true,
                          showFieldAsBox: true,
                          borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                          contentPadding: EdgeInsets.symmetric(vertical: 16.h),
                          cursorColor: colors.accentViolet,
                          focusedBorderColor: colors.accentViolet,
                          borderWidth: 1.5,
                          keyboardType: TextInputType.number,
                          textStyle: TextStyle(color: colors.textPrimary, fontSize: 20.sp, fontWeight: FontWeight.w600),
                          onCodeChanged: (String code) {
                            setState(() {
                              verificationCode = code;
                            });
                          },
                          onSubmit: (String code) {
                            if (code.length == 6) {
                              _verifyOTP(code);
                            }
                          },
                        ),
                        SizedBox(height: KSpacing.lg25.h),

                        GestureDetector(
                          onTap: verificationCode != null && verificationCode!.length == 6 && !isLoading
                              ? () {
                                  _verifyOTP(verificationCode!);
                                }
                              : null,
                          child: Container(
                            height: 56.h,
                            decoration: BoxDecoration(
                              gradient: verificationCode != null && verificationCode!.length == 6 && !isLoading
                                  ? LinearGradient(
                                      colors: [colors.accentViolet, colors.accentViolet.withValues(alpha: 0.8)],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    )
                                  : null,
                              color: verificationCode != null && verificationCode!.length == 6 && !isLoading
                                  ? null
                                  : colors.inputBorder,
                              borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                              boxShadow: verificationCode != null && verificationCode!.length == 6 && !isLoading
                                  ? [
                                      BoxShadow(
                                        color: colors.accentViolet.withValues(alpha: 0.4),
                                        blurRadius: 20,
                                        offset: const Offset(0, 8),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Center(
                              child: isLoading
                                  ? SizedBox(
                                      height: 20.h,
                                      width: 20.w,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                    )
                                  : Text(
                                      "Verify Code",
                                      style: TextStyle(
                                        color: verificationCode != null && verificationCode!.length == 6 && !isLoading
                                            ? Colors.white
                                            : colors.textSecondary,
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        SizedBox(height: KSpacing.lg.h),

                        Align(
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                canResend ? "Didn't receive the code?" : "Resend code in ${countdown}s",
                                style: TextStyle(
                                  color: colors.textSecondary,
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              if (canResend)
                                GestureDetector(
                                  onTap: isLoading ? null : _resendOTP,
                                  child: Text(
                                    "  Resend",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: isLoading ? colors.textSecondary : colors.accentViolet,
                                      fontSize: 14.sp,
                                    ),
                                  ),
                                ),
                            ],
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
    );
  }
}
