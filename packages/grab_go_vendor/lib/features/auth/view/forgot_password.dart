import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_vendor/features/auth/view/widgets/auth_entrance.dart';
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
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: colors.backgroundPrimary,
        body: SafeArea(
          child: Consumer<ForgotPasswordViewModel>(
            builder: (context, viewModel, child) {
              return Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 430.w),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    child: Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            padding: EdgeInsets.only(top: 8.h, bottom: 12.h),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AuthEntrance(
                                  delay: const Duration(milliseconds: 40),
                                  child: TextButton.icon(
                                    onPressed: () => context.go('/login'),
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.zero,
                                      foregroundColor: colors.textSecondary,
                                    ),
                                    icon: SvgPicture.asset(
                                      Assets.icons.navArrowLeft,
                                      package: 'grab_go_shared',
                                      width: 18.w,
                                      height: 18.w,
                                      colorFilter: ColorFilter.mode(
                                        colors.textSecondary,
                                        BlendMode.srcIn,
                                      ),
                                    ),
                                    label: Text(
                                      'Back',
                                      style: TextStyle(
                                        color: colors.textSecondary,
                                        fontSize: 14.sp,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ),
                                AuthEntrance(
                                  delay: const Duration(milliseconds: 90),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
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
                                    ],
                                  ),
                                ),
                                SizedBox(height: 24.h),
                                AuthEntrance(
                                  delay: const Duration(milliseconds: 150),
                                  child: AppTextInput(
                                    controller: viewModel.emailController,
                                    label: 'Business Email',
                                    hintText: 'vendor@example.com',
                                    keyboardType: TextInputType.emailAddress,
                                    errorText: viewModel.emailError,
                                    fillColor: colors.backgroundSecondary,
                                    borderColor: colors.inputBorder,
                                    borderActiveColor: colors.vendorPrimaryBlue,
                                    borderRadius: KBorderSize.border,
                                    cursorColor: colors.vendorPrimaryBlue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.only(bottom: 12.h),
                          child: AuthEntrance(
                            delay: const Duration(milliseconds: 220),
                            child: SizedBox(
                              width: double.infinity,
                              child: AppButton(
                                buttonText: 'Continue',
                                onPressed: () =>
                                    _handleContinue(context, viewModel),
                                backgroundColor: colors.vendorPrimaryBlue,
                                borderRadius: KBorderSize.border,
                                textStyle: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15.sp,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _handleContinue(
    BuildContext context,
    ForgotPasswordViewModel viewModel,
  ) {
    HapticFeedback.selectionClick();
    if (!viewModel.validate()) return;

    context.go(
      '/resetPassword',
      extra: {'email': viewModel.emailController.text.trim()},
    );
  }
}
