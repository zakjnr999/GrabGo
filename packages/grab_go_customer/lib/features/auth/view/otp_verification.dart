import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_otp_text_field/flutter_otp_text_field.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_customer/features/auth/service/phone_auth_service.dart';
import 'package:grab_go_customer/shared/services/user_service.dart';

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
  Timer? _countdownTimer;

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

    phoneNumber = PhoneAuthService().phoneNumber;

    _startCountdown();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animationController.forward();
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _animationController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() {
      countdown = 60;
      canResend = false;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        countdown--;
        if (countdown <= 0) {
          canResend = true;
          timer.cancel();
        }
      });
    });
  }

  Future<void> _verifyOTP(String otp) async {
    FocusManager.instance.primaryFocus?.unfocus();
    LoadingDialog.instance().show(context: context, text: "Verifying OTP...");

    setState(() {
      isLoading = true;
    });

    final result = await PhoneAuthService().verifyOTP(
      otpCode: otp,
      onError: (error) {
        if (mounted) {
          LoadingDialog.instance().hide();
          setState(() {
            isLoading = false;
          });
          AppToastMessage.show(
            context: context,
            message: error.isNotEmpty ? error : "Invalid OTP. Please try again.",
            backgroundColor: context.appColors.error,
          );
        }
      },
    );

    if (result != null && mounted) {
      final verificationToken = result['verificationToken'] as String?;
      if (verificationToken != null && verificationToken.isNotEmpty) {
        PhoneAuthService().setVerificationToken(verificationToken);
        LoadingDialog.instance().hide();
        await Future.delayed(const Duration(milliseconds: 300));
        if (mounted) {
          context.go("/register");
        }
        return;
      }

      final userData = result['user'];

      if (userData != null) {
        final user = User.fromJson(userData);
        await UserService().setCurrentUser(user);

        if (mounted) {
          LoadingDialog.instance().hide();
          await Future.delayed(const Duration(milliseconds: 500));
          if (mounted) {
            context.go("/profileUpload");
          }
        }
      } else {
        if (mounted) {
          LoadingDialog.instance().hide();
          AppToastMessage.show(
            context: context,
            message: "Failed to verify phone. Please try again.",
            backgroundColor: context.appColors.error,
          );
        }
      }
    }

    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _resendOTP() async {
    final storedPhoneNumber = PhoneAuthService().phoneNumber;
    final userId = UserService().currentUser?.id ?? PhoneAuthService().userId;
    final channel = PhoneAuthService().channel;

    if (storedPhoneNumber == null || userId == null) {
      if (mounted) {
        AppToastMessage.show(
          context: context,
          message: "Phone number or user ID not found. Please restart verification.",
          backgroundColor: context.appColors.error,
        );
      }
      return;
    }

    LoadingDialog.instance().show(context: context, text: "Resending OTP...");

    setState(() {
      isLoading = true;
      canResend = false;
      countdown = 60;
    });

    await PhoneAuthService().resendOTP(
      phoneNumber: storedPhoneNumber,
      userId: userId,
      channel: channel,
      onCodeSent: () {
        if (mounted) {
          LoadingDialog.instance().hide();
          _startCountdown();
        }
      },
      onError: (error) {
        if (mounted) {
          LoadingDialog.instance().hide();
          AppToastMessage.show(
            context: context,
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
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: KSpacing.xl40.h),
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Container(
                      height: 100.h,
                      width: 100.h,
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
                      AppStrings.otpMain,
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
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: KSpacing.lg.w),
                      child: Text(
                        AppStrings.otpSub,
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
                          borderRadius: BorderRadius.circular(KBorderSize.borderMedium),
                          contentPadding: EdgeInsets.symmetric(vertical: 16.h),
                          cursorColor: colors.accentOrange,
                          focusedBorderColor: colors.accentOrange,
                          borderWidth: 1.5,
                          fieldWidth: 45.w,
                          keyboardType: TextInputType.number,
                          textStyle: TextStyle(color: colors.textPrimary, fontSize: 20.sp, fontWeight: FontWeight.w600),
                          onCodeChanged: (String code) {
                            setState(() {
                              verificationCode = code;
                            });
                          },
                          onSubmit: (String verificationCode) {
                            if (verificationCode.length == 6 && RegExp(r'^\d{6}$').hasMatch(verificationCode)) {
                              _verifyOTP(verificationCode);
                            } else {
                              AppToastMessage.show(
                                context: context,
                                message: "Please enter a valid 6-digit code",
                                backgroundColor: context.appColors.error,
                              );
                            }
                          },
                        ),
                        SizedBox(height: KSpacing.lg25.h),

                        AppButton(
                          onPressed: () {
                            verificationCode != null && verificationCode!.length == 6 && !isLoading
                                ? () {
                                    _verifyOTP(verificationCode!);
                                  }
                                : null;
                          },
                          backgroundColor: verificationCode != null && verificationCode!.length == 6 && !isLoading
                              ? null
                              : colors.inputBorder,
                          borderRadius: KBorderSize.borderRadius15,
                          buttonText: isLoading ? "Verifying..." : "Verify Code",
                          textStyle: TextStyle(
                            color: verificationCode != null && verificationCode!.length == 6 && !isLoading
                                ? Colors.white
                                : colors.textSecondary,
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
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
                                      color: isLoading ? colors.textSecondary : colors.accentOrange,
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
