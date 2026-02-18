import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_vendor/features/auth/viewmodel/forgot_password_viewmodel.dart';
import 'package:provider/provider.dart';

class ForgotPassword extends StatelessWidget {
  const ForgotPassword({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ForgotPasswordViewModel(),
      child: const _ForgotPasswordView(),
    );
  }
}

class _ForgotPasswordView extends StatelessWidget {
  const _ForgotPasswordView();

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
          child: Consumer<ForgotPasswordViewModel>(
            builder: (context, viewModel, child) {
              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextButton.icon(
                      onPressed: () => context.go('/login'),
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        foregroundColor: colors.textSecondary,
                      ),
                      icon: Icon(Icons.arrow_back_rounded, size: 18.sp),
                      label: Text(
                        'Back',
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(height: 12.h),
                    Center(
                      child: Container(
                        width: 92.w,
                        height: 92.w,
                        decoration: BoxDecoration(
                          color: colors.vendorPrimaryBlue.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(28.r),
                        ),
                        child: Icon(
                          Icons.lock_reset_rounded,
                          size: 42.sp,
                          color: colors.vendorPrimaryBlue,
                        ),
                      ),
                    ),
                    SizedBox(height: 22.h),
                    Text(
                      'Forgot your password?',
                      style: TextStyle(
                        fontSize: 30.sp,
                        fontWeight: FontWeight.w900,
                        color: colors.textPrimary,
                        height: 1.15,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'Enter your business email and we’ll continue with password reset.',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                        color: colors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    SizedBox(height: 24.h),
                    AppTextInput(
                      controller: viewModel.emailController,
                      label: 'Business Email',
                      hintText: 'vendor@example.com',
                      keyboardType: TextInputType.emailAddress,
                      errorText: viewModel.emailError,
                      fillColor: colors.backgroundSecondary,
                      borderColor: colors.inputBorder,
                      borderActiveColor: colors.vendorPrimaryBlue,
                      borderRadius: KBorderSize.borderRadius12,
                      cursorColor: colors.vendorPrimaryBlue,
                      prefixIcon: const Icon(Icons.mail_outline_rounded),
                    ),
                    SizedBox(height: 18.h),
                    SizedBox(
                      width: double.infinity,
                      child: AppButton(
                        buttonText: 'Continue',
                        onPressed: () => _handleContinue(context, viewModel),
                        backgroundColor: colors.vendorPrimaryBlue,
                        borderRadius: KBorderSize.borderRadius12,
                        textStyle: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15.sp,
                        ),
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

  void _handleContinue(BuildContext context, ForgotPasswordViewModel viewModel) {
    HapticFeedback.selectionClick();
    if (!viewModel.validate()) return;

    context.go(
      '/resetPassword',
      extra: {'email': viewModel.emailController.text.trim()},
    );
  }
}
