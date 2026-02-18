import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_vendor/features/auth/viewmodel/otp_verification_viewmodel.dart';
import 'package:provider/provider.dart';

class OtpVerification extends StatelessWidget {
  final String channel;
  final String destination;

  const OtpVerification({super.key, required this.channel, required this.destination});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => OtpVerificationViewModel(),
      child: _OtpVerificationView(channel: channel, destination: destination),
    );
  }
}

class _OtpVerificationView extends StatelessWidget {
  final String channel;
  final String destination;

  const _OtpVerificationView({required this.channel, required this.destination});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: colors.backgroundPrimary,
        body: SafeArea(
          child: Consumer<OtpVerificationViewModel>(
            builder: (context, viewModel, child) {
              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextButton.icon(
                      onPressed: () => context.go('/register'),
                      style: TextButton.styleFrom(padding: EdgeInsets.zero, foregroundColor: colors.textSecondary),
                      icon: Icon(Icons.arrow_back_rounded, size: 18.sp),
                      label: Text(
                        'Back',
                        style: TextStyle(color: colors.textSecondary, fontSize: 14.sp, fontWeight: FontWeight.w600),
                      ),
                    ),
                    SizedBox(height: 10.h),
                    Center(
                      child: Container(
                        width: 92.w,
                        height: 92.w,
                        decoration: BoxDecoration(
                          color: colors.vendorPrimaryBlue.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(28.r),
                        ),
                        child: Icon(Icons.verified_user_outlined, size: 44.sp, color: colors.vendorPrimaryBlue),
                      ),
                    ),
                    SizedBox(height: 20.h),
                    Text(
                      'Verify $channel',
                      style: TextStyle(
                        fontSize: 30.sp,
                        fontWeight: FontWeight.w900,
                        color: colors.textPrimary,
                        height: 1.15,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'Enter the 6-digit code sent to $destination',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                        color: colors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    SizedBox(height: 24.h),
                    AppTextInput(
                      controller: viewModel.codeController,
                      label: 'Verification Code',
                      hintText: 'Enter 6-digit code',
                      keyboardType: TextInputType.number,
                      errorText: viewModel.codeError,
                      fillColor: colors.backgroundSecondary,
                      borderColor: colors.inputBorder,
                      borderActiveColor: colors.vendorPrimaryBlue,
                      borderRadius: KBorderSize.borderRadius12,
                      cursorColor: colors.vendorPrimaryBlue,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
                    ),
                    SizedBox(height: 10.h),
                    Row(
                      children: [
                        Text(
                          viewModel.canResend
                              ? 'Didn\'t receive code?'
                              : 'Resend available in ${viewModel.secondsRemaining}s',
                          style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.w500, color: colors.textSecondary),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: viewModel.canResend
                              ? () {
                                  HapticFeedback.selectionClick();
                                  viewModel.resendCode();
                                  ScaffoldMessenger.of(
                                    context,
                                  ).showSnackBar(SnackBar(content: Text('$channel code resent')));
                                }
                              : null,
                          child: Text(
                            'Resend',
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.w700,
                              color: viewModel.canResend
                                  ? colors.vendorPrimaryBlue
                                  : colors.textSecondary.withValues(alpha: 0.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 18.h),
                    SizedBox(
                      width: double.infinity,
                      child: AppButton(
                        buttonText: 'Verify Code',
                        onPressed: () => _handleVerify(context, viewModel),
                        backgroundColor: colors.vendorPrimaryBlue,
                        borderRadius: KBorderSize.borderRadius12,
                        textStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15.sp),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _handleVerify(BuildContext context, OtpVerificationViewModel viewModel) {
    HapticFeedback.selectionClick();
    if (!viewModel.validateCode()) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('OTP verified. Next step: business setup screen.')));
  }
}
