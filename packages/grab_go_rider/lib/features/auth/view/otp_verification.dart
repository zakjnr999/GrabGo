import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_otp_text_field/flutter_otp_text_field.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_rider/core/api/api_client.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_rider/features/auth/service/firebase_phone_auth_service.dart';

class OtpVerification extends StatefulWidget {
  const OtpVerification({super.key});

  @override
  State<OtpVerification> createState() => _VerifyPhoneState();
}

class _VerifyPhoneState extends State<OtpVerification> with SingleTickerProviderStateMixin {
  final TextEditingController phoneController = TextEditingController();
  String? phoneNumber;
  String? verificationCode;
  bool isLoading = false;
  int countdown = 60;
  bool canResend = false;

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

    phoneNumber = FirebasePhoneAuthService().phoneNumber;

    _startCountdown();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animationController.forward();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          countdown--;
          if (countdown <= 0) {
            canResend = true;
          }
        });
        if (countdown > 0) {
          _startCountdown();
        }
      }
    });
  }

  Future<void> _verifyOTP(String otp) async {
    FocusManager.instance.primaryFocus?.unfocus();
    LoadingDialog.instance().show(context: context, text: "Verifying OTP...");

    setState(() {
      isLoading = true;
    });

    debugPrint('🔐 Verifying OTP: $otp');

    final userCredential = await FirebasePhoneAuthService().verifyOTP(
      otpCode: otp,
      onError: (error) {
        debugPrint('❌ Error verifying OTP: $error');
        if (mounted) {
          LoadingDialog.instance().hide();
          setState(() {
            isLoading = false;
          });
          AppToastMessage.show(
            context: context,
            icon: Icons.error_outline,
            message: "Invalid OTP. Please try again.",
            backgroundColor: context.appColors.error,
          );
        }
      },
    );

    if (userCredential != null && mounted) {
      debugPrint('✅ Firebase verification successful, updating API...');

      LoadingDialog.instance().show(context: context, text: "Updating phone verification...");

      try {
        final userId = FirebasePhoneAuthService().userId;
        if (userId == null) {
          debugPrint('❌ User ID not found. Cannot update phone verification.');
          if (mounted) {
            LoadingDialog.instance().hide();
            AppToastMessage.show(
              context: context,
              icon: Icons.error_outline,
              message: "User ID not found. Please restart the registration process.",
              backgroundColor: context.appColors.error,
            );
          }
          return;
        }

        // Check if auth token exists - CRITICAL: Token must be saved during registration
        final token = await CacheService.getAuthToken();
        debugPrint('🔍 ========== TOKEN CHECK BEFORE PHONE VERIFICATION ==========');
        debugPrint('   Token exists: ${token != null}');
        debugPrint('   Token length: ${token?.length ?? 0}');
        if (token != null) {
          debugPrint('   Token preview: ${token.substring(0, token.length > 30 ? 30 : token.length)}...');
        }
        debugPrint('   User ID from Firebase: ${FirebasePhoneAuthService().userId}');
        debugPrint('==============================================================');

        if (token == null || token.isEmpty) {
          debugPrint('❌ CRITICAL ERROR: No auth token found!');
          debugPrint('   This means registration did not save the token.');
          debugPrint('   Please register/login again to get a token.');
          if (mounted) {
            LoadingDialog.instance().hide();
            AppToastMessage.show(
              context: context,
              icon: Icons.error_outline,
              message: "Authentication token missing. Please register or login again.",
              backgroundColor: context.appColors.error,
            );
          }
          return;
        }

        final request = PhoneVerificationRequest(
          phoneNumber: FirebasePhoneAuthService().phoneNumber ?? '',
          isPhoneVerified: true,
        );

        debugPrint('🚀 Sending phone verification update:');
        debugPrint('   User ID: $userId');
        debugPrint('   Phone: ${request.phoneNumber}');
        debugPrint('   Is Phone Verified: ${request.isPhoneVerified}');
        debugPrint('   Request JSON: ${request.toJson()}');

        // Log token info for debugging
        final tokenForLog = await CacheService.getAuthToken();
        if (tokenForLog != null) {
          debugPrint(
            '   Token preview: ${tokenForLog.substring(0, tokenForLog.length > 20 ? 20 : tokenForLog.length)}...',
          );
        } else {
          debugPrint('   ⚠️ WARNING: No token found in cache!');
        }

        // Make the request - the converter should add the token, but if it doesn't work,
        // we'll need to manually add it via an interceptor or modify the request
        final response = await authService
            .verifyPhone(userId, request)
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () {
                throw TimeoutException('Server is taking too long to respond.');
              },
            );

        debugPrint('📡 API Response:');
        debugPrint('   Status Code: ${response.statusCode}');
        debugPrint('   Is Successful: ${response.isSuccessful}');
        debugPrint('   Response Body: ${response.body}');
        debugPrint('   Response Error: ${response.error}');

        if (response.isSuccessful && response.body != null) {
          final message = response.body!.message;
          final user = response.body!.user;

          debugPrint('✅ Phone verification updated successfully!');
          debugPrint('Message: $message');
          debugPrint('User: ${user?.username} (${user?.email})');
          debugPrint('Phone Verified: ${user?.isPhoneVerified}');

          if (mounted) {
            LoadingDialog.instance().hide();
            AppToastMessage.show(
              context: context,
              icon: Icons.check_circle,
              message: "Phone verified successfully!",
              backgroundColor: Colors.green,
            );

            // TODO: Navigate to next screen
          }
        } else {
          String errorMessage = "Failed to update phone verification. Please try again.";

          if (response.error != null) {
            errorMessage = response.error.toString();
          } else if (response.statusCode == 400) {
            errorMessage = "Invalid verification data.";
          } else if (response.statusCode == 404) {
            errorMessage = "User not found.";
          } else if (response.statusCode == 500) {
            errorMessage = "Server error. Please try again later.";
          }

          debugPrint('❌ API Error - Status: ${response.statusCode}, Error: ${response.error}');

          if (mounted) {
            LoadingDialog.instance().hide();
            AppToastMessage.show(
              context: context,
              icon: Icons.error_outline,
              message: errorMessage,
              backgroundColor: context.appColors.error,
            );
          }
        }
      } catch (e) {
        debugPrint('❌ Error updating phone verification: $e');
        if (mounted) {
          LoadingDialog.instance().hide();
          AppToastMessage.show(
            context: context,
            icon: Icons.error,
            message: "Failed to update phone verification. Please try again.",
            backgroundColor: context.appColors.error,
          );
        }
      }
    }

    setState(() {
      isLoading = false;
    });
  }

  Future<void> _resendOTP() async {
    final storedPhoneNumber = FirebasePhoneAuthService().phoneNumber;
    if (storedPhoneNumber == null) {
      AppToastMessage.show(
        context: context,
        icon: Icons.error_outline,
        message: "Phone number not found. Please restart verification.",
        backgroundColor: context.appColors.error,
      );
      return;
    }

    LoadingDialog.instance().show(context: context, text: "Resending OTP...");

    setState(() {
      isLoading = true;
      canResend = false;
      countdown = 60;
    });

    await FirebasePhoneAuthService().resendOTP(
      phoneNumber: storedPhoneNumber,
      onCodeSent: (verificationId) {
        debugPrint('✅ OTP resent successfully');
        if (mounted) {
          LoadingDialog.instance().hide();
          AppToastMessage.show(
            context: context,
            icon: Icons.check_circle,
            message: "OTP resent successfully!",
            backgroundColor: Colors.green,
          );
          _startCountdown();
        }
      },
      onError: (error) {
        debugPrint('❌ Error resending OTP: $error');
        if (mounted) {
          LoadingDialog.instance().hide();
          AppToastMessage.show(
            context: context,
            icon: Icons.error_outline,
            message: "Failed to resend OTP: $error",
            backgroundColor: context.appColors.error,
          );
          setState(() {
            canResend = true;
          });
        }
      },
    );

    setState(() {
      isLoading = false;
    });
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
                          gradient: LinearGradient(
                            colors: [
                              colors.accentViolet.withValues(alpha: 0.15),
                              colors.accentGreen.withValues(alpha: 0.15),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: colors.accentViolet.withValues(alpha: 0.15),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Center(
                          child: SvgPicture.asset(
                            Assets.icons.shieldCheck,
                            package: 'grab_go_shared',
                            height: 48.h,
                            width: 48.h,
                            colorFilter: ColorFilter.mode(colors.accentViolet, BlendMode.srcIn),
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
                    child: Text(
                      AppStrings.otpSub,
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
                          onSubmit: (String verificationCode) {
                            _verifyOTP(verificationCode);
                            setState(() {
                              verificationCode = verificationCode;
                            });
                          },
                        ),
                        SizedBox(height: KSpacing.lg25.h),

                        GestureDetector(
                          onTap: verificationCode != null && verificationCode!.length == 6 && !isLoading
                              ? () {
                                  _verifyOTP(verificationCode!);
                                  debugPrint('Verification Code: $verificationCode');
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
                              child: Text(
                                isLoading ? "Verifying..." : "Verify Code",
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

                        Row(
                          mainAxisAlignment: MainAxisAlignment.start,
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
