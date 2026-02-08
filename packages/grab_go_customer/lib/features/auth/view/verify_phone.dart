import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_customer/features/auth/service/phone_auth_service.dart';
import 'package:grab_go_customer/shared/services/user_service.dart';
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
  bool useWhatsapp = false;

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

      final digits = phoneController.text.replaceAll(RegExp(r'\D'), '');

      if (digits.isEmpty) {
        phoneError = "Please enter your phone number";
      } else if (digits.length == 10 && digits.startsWith('0')) {
        phoneError = null;
      } else if (digits.length == 9) {
        phoneError = null;
      } else {
        phoneError = "Please enter a valid Ghana phone number";
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

    String digits = phoneController.text.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    final phoneNumber = '+233$digits';

    final userId = UserService().currentUser?.id;
    if (userId == null) {
      if (mounted) {
        LoadingDialog.instance().hide();
        AppToastMessage.show(
          context: context,
          message: "User ID not found. Please register again.",
          backgroundColor: context.appColors.error,
        );
      }
      setState(() {
        isLoading = false;
      });
      return;
    }

    await PhoneAuthService().sendOTP(
      phoneNumber: phoneNumber,
      userId: userId,
      channel: useWhatsapp ? 'whatsapp' : 'sms',
      onCodeSent: () {
        if (mounted) {
          LoadingDialog.instance().hide();
          context.push("/OTPVerification");
        }
      },
      onError: (error) {
        if (mounted) {
          LoadingDialog.instance().hide();
          AppToastMessage.show(
            context: context,
            message: "Failed to send OTP: $error",
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
                        color: colors.accentGreen.withValues(alpha: 0.2),
                      ),
                      child: Center(
                        child: SvgPicture.asset(
                          Assets.icons.phone,
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
                      AppStrings.verifyPhoneMain,
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
                        AppStrings.verifyPhoneSub,
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
                            hintStyle: TextStyle(fontSize: 15.sp, color: colors.textSecondary.withValues(alpha: 0.7)),
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

                        SizedBox(height: KSpacing.lg.h),

                        Container(
                          padding: EdgeInsets.symmetric(horizontal: KSpacing.md.w, vertical: KSpacing.sm.h),
                          decoration: BoxDecoration(
                            color: colors.backgroundSecondary,
                            borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
                            border: Border.all(color: colors.inputBorder),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    useWhatsapp ? "Send via WhatsApp" : "Send via SMS",
                                    style: TextStyle(
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.w600,
                                      color: colors.textPrimary,
                                    ),
                                  ),
                                  SizedBox(height: 4.h),
                                  Text(
                                    useWhatsapp ? "Preferred for WhatsApp users" : "Standard text message",
                                    style: TextStyle(fontSize: 12.sp, color: colors.textSecondary),
                                  ),
                                ],
                              ),
                              CustomSwitch(
                                value: useWhatsapp,
                                onChanged: (value) {
                                  setState(() {
                                    useWhatsapp = value;
                                  });
                                },
                                activeColor: colors.accentGreen,
                              ),
                            ],
                          ),
                        ),

                        SizedBox(height: KSpacing.lg25.h),

                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: colors.accentGreen.withValues(alpha: 0.4),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: AppButton(
                            onPressed: _sendOTP,
                            backgroundColor: colors.accentGreen,
                            borderRadius: KBorderSize.borderRadius15,
                            buttonText: AppStrings.register,
                            textStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15.sp),
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
