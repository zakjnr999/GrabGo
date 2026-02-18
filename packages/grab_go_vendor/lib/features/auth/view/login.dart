import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_vendor/features/auth/viewmodel/login_viewmodel.dart';
import 'package:provider/provider.dart';

class Login extends StatelessWidget {
  const Login({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => LoginViewModel(),
      child: const _LoginView(),
    );
  }
}

class _LoginView extends StatelessWidget {
  const _LoginView();

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
          child: Consumer<LoginViewModel>(
            builder: (context, viewModel, child) {
              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 18.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 16.h,
                      ),
                      decoration: BoxDecoration(
                        color: colors.backgroundPrimary,
                        borderRadius: BorderRadius.circular(18.r),
                        border: Border.all(color: colors.inputBorder),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 46.w,
                            height: 46.w,
                            decoration: BoxDecoration(
                              color: colors.vendorPrimaryBlue.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: Center(
                              child: SvgPicture.asset(
                                Assets.icons.store,
                                package: 'grab_go_shared',
                                width: 24.w,
                                height: 24.w,
                                colorFilter: ColorFilter.mode(
                                  colors.vendorPrimaryBlue,
                                  BlendMode.srcIn,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Vendor Login',
                                  style: TextStyle(
                                    fontSize: 18.sp,
                                    fontWeight: FontWeight.w800,
                                    color: colors.textPrimary,
                                  ),
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  'Access your operations dashboard',
                                  style: TextStyle(
                                    fontSize: 12.sp,
                                    fontWeight: FontWeight.w500,
                                    color: colors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 22.h),
                    Text(
                      'Welcome back',
                      style: TextStyle(
                        fontSize: 30.sp,
                        fontWeight: FontWeight.w900,
                        color: colors.textPrimary,
                        height: 1.15,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'Sign in to manage food, grocery, pharmacy, and GrabMart services.',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                        color: colors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    SizedBox(height: 20.h),
                    AppTextInput(
                      controller: viewModel.emailController,
                      label: 'Business Email',
                      hintText: 'vendor@example.com',
                      keyboardType: TextInputType.emailAddress,
                      errorText: viewModel.emailError,
                      fillColor: colors.backgroundPrimary,
                      borderColor: colors.inputBorder,
                      borderActiveColor: colors.vendorPrimaryBlue,
                      borderRadius: KBorderSize.borderRadius12,
                      cursorColor: colors.vendorPrimaryBlue,
                    ),
                    SizedBox(height: 14.h),
                    AppTextInput(
                      controller: viewModel.passwordController,
                      label: 'Password',
                      hintText: 'Minimum 8 characters',
                      obscureText: !viewModel.isPasswordVisible,
                      errorText: viewModel.passwordError,
                      fillColor: colors.backgroundPrimary,
                      borderColor: colors.inputBorder,
                      borderActiveColor: colors.vendorPrimaryBlue,
                      borderRadius: KBorderSize.borderRadius12,
                      cursorColor: colors.vendorPrimaryBlue,
                      suffixIcon: IconButton(
                        onPressed: viewModel.togglePasswordVisibility,
                        icon: SvgPicture.asset(
                          viewModel.isPasswordVisible
                              ? Assets.icons.eye
                              : Assets.icons.eyeClosed,
                          package: 'grab_go_shared',
                          width: KIconSize.md,
                          height: KIconSize.md,
                          colorFilter: ColorFilter.mode(
                            colors.iconSecondary,
                            BlendMode.srcIn,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Row(
                      children: [
                        Transform.scale(
                          scale: 0.92,
                          child: Checkbox(
                            value: viewModel.rememberMe,
                            onChanged: viewModel.toggleRememberMe,
                            activeColor: colors.vendorPrimaryBlue,
                            side: BorderSide(color: colors.inputBorder),
                          ),
                        ),
                        Text(
                          'Remember me',
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.w600,
                            color: colors.textSecondary,
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => context.go('/forgotPassword'),
                          child: Text(
                            'Forgot Password?',
                            style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w700,
                              color: colors.vendorPrimaryBlue,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => context.go('/sessionRecovery'),
                        child: Text(
                          'Need Session Recovery?',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w700,
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 16.h),
                    SizedBox(
                      width: double.infinity,
                      child: AppButton(
                        buttonText: 'Login',
                        onPressed: () => _handleLogin(context, viewModel),
                        backgroundColor: colors.vendorPrimaryBlue,
                        borderRadius: KBorderSize.borderRadius12,
                        textStyle: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 15.sp,
                        ),
                      ),
                    ),
                    SizedBox(height: 14.h),
                    Center(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'New vendor on GrabGo? ',
                            style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.w500,
                              color: colors.textSecondary,
                            ),
                          ),
                          TextButton(
                            onPressed: () => context.go('/register'),
                            style: TextButton.styleFrom(
                              foregroundColor: colors.vendorPrimaryBlue,
                              padding: EdgeInsets.symmetric(horizontal: 4.w),
                              minimumSize: Size(0, 24.h),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'Create account',
                              style: TextStyle(
                                fontSize: 13.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
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

  void _handleLogin(BuildContext context, LoginViewModel viewModel) {
    HapticFeedback.selectionClick();
    final isValid = viewModel.validate();
    if (!isValid) return;

    context.go('/vendorPreview');
  }
}
