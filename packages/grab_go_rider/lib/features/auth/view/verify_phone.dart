// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_rider/features/auth/service/firebase_phone_auth_service.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class VerifyPhone extends StatefulWidget {
  const VerifyPhone({super.key});

  @override
  State<VerifyPhone> createState() => _VerifyPhoneState();
}

class _VerifyPhoneState extends State<VerifyPhone> with SingleTickerProviderStateMixin {
  final TextEditingController phoneController = TextEditingController();
  String? phoneError;
  bool isLoading = false;

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
      _animationController.forward();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  bool _validatePhoneNumber() {
    setState(() {
      phoneError = null;

      if (phoneController.text.trim().isEmpty) {
        phoneError = "Please enter your phone number";
      } else if (phoneController.text.trim().length < 10) {
        phoneError = "Please enter a valid phone number";
      }
    });

    return phoneError == null;
  }

  Future<void> _sendOTP() async {
    if (!_validatePhoneNumber()) {
      return;
    }

    setState(() {
      isLoading = true;
    });

    FocusManager.instance.primaryFocus?.unfocus();
    LoadingDialog.instance().show(context: context, text: "Sending OTP...\nThis may take a moment.");

    String phoneNumber = phoneController.text.trim();
    if (!phoneNumber.startsWith('+')) {
      phoneNumber = '+233$phoneNumber';
    }

    debugPrint('📱 Sending OTP to: $phoneNumber');
    debugPrint('📱 Phone number format: ${phoneNumber.length} digits');
    debugPrint('📱 Country code: ${phoneNumber.substring(0, 4)}');

    await FirebasePhoneAuthService().sendOTP(
      phoneNumber: phoneNumber,
      onCodeSent: (verificationId) {
        debugPrint('✅ OTP sent successfully');
        if (mounted) {
          LoadingDialog.instance().hide();
          AppToastMessage.show(
            context: context,
            icon: Icons.check_circle,
            message: "OTP sent successfully!",
            backgroundColor: Colors.green,
          );
          context.push("/otpVerification");
        }
      },
      onError: (error) {
        debugPrint('❌ Error sending OTP: $error');
        if (mounted) {
          LoadingDialog.instance().hide();
          AppToastMessage.show(
            context: context,
            icon: Icons.error_outline,
            message: "Failed to send OTP: $error",
            backgroundColor: context.appColors.error,
          );
        }
      },
      onTimeout: () {
        debugPrint('⏰ OTP sending timeout');
        if (mounted) {
          LoadingDialog.instance().hide();
          AppToastMessage.show(
            context: context,
            icon: Icons.timer_off,
            message: "Request timeout. Please try again.",
            backgroundColor: context.appColors.error,
          );
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
                          borderRadius: BorderRadius.circular(20.r),
                          gradient: LinearGradient(
                            colors: [
                              colors.accentGreen.withValues(alpha: 0.15),
                              colors.accentViolet.withValues(alpha: 0.15),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: colors.accentGreen.withValues(alpha: 0.15),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Center(
                          child: SvgPicture.asset(
                            Assets.icons.phone,
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
                      AppStrings.verifyPhoneMain,
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
                      padding: EdgeInsets.symmetric(horizontal: KSpacing.lg.w),
                      child: Text(
                        AppStrings.verifyPhoneSub,
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
                SizedBox(height: KSpacing.xl40.h),

                FadeTransition(
                  opacity: _fadeAnimation,
                  child: SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          "Your Phone Number",
                          style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: colors.textPrimary),
                        ),
                        SizedBox(height: KSpacing.md.h),
                        TextField(
                          controller: phoneController,
                          keyboardType: TextInputType.phone,
                          style: TextStyle(fontSize: 15.sp, color: colors.textPrimary, fontWeight: FontWeight.w500),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: colors.backgroundSecondary,
                            hintText: "23456789",
                            errorText: phoneError,
                            hintStyle: TextStyle(fontSize: 15.sp, color: colors.textSecondary.withOpacity(0.7)),
                            contentPadding: EdgeInsets.all(KSpacing.md15.r),
                            prefixIcon: Padding(
                              padding: EdgeInsets.only(left: 12.w, right: 8.w),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(width: 6.w),
                                  Text(
                                    "+233",
                                    style: TextStyle(
                                      fontSize: 15.sp,
                                      fontWeight: FontWeight.w600,
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                  SizedBox(width: KSpacing.sm.w),
                                  Container(width: 1.5, height: 24, color: colors.inputBorder),
                                  SizedBox(width: KSpacing.sm.w),
                                ],
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
                              borderSide: BorderSide(
                                color: phoneError != null ? colors.error : colors.inputBorder,
                                width: 1.5,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
                              borderSide: BorderSide(
                                color: phoneError != null ? colors.error : colors.accentGreen,
                                width: 2,
                              ),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
                              borderSide: BorderSide(color: colors.error, width: 1.5),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
                              borderSide: BorderSide(color: colors.error, width: 2),
                            ),
                          ),
                        ),

                        SizedBox(height: KSpacing.lg25.h),

                        GestureDetector(
                          onTap: isLoading ? null : () => _sendOTP(),
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
                                "Send Code",
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
                        SizedBox(height: KSpacing.lg.h),

                        RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: "By providing your phone number, you hereby agree and accept the ",
                                style: TextStyle(fontFamily: "Lato", fontSize: 12.sp, color: colors.textSecondary),
                              ),
                              TextSpan(
                                text: "Terms",
                                style: TextStyle(
                                  fontFamily: "Lato",
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w600,
                                  color: colors.accentGreen,
                                ),
                              ),
                              TextSpan(
                                text: " & ",
                                style: TextStyle(fontFamily: "Lato", fontSize: 12.sp, color: colors.textSecondary),
                              ),
                              TextSpan(
                                text: "Privacy Policy",
                                style: TextStyle(
                                  fontFamily: "Lato",
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w600,
                                  color: colors.accentGreen,
                                ),
                              ),
                              TextSpan(
                                text: " in the use of this App.",
                                style: TextStyle(fontSize: 12.sp, color: colors.textSecondary),
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
