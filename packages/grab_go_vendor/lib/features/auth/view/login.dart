import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_vendor/features/auth/view/widgets/auth_entrance.dart';
import 'package:grab_go_vendor/features/auth/viewmodel/login_viewmodel.dart';
import 'package:grab_go_vendor/features/onboarding/viewmodel/onboarding_setup_viewmodel.dart';
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
              return LayoutBuilder(
                builder: (context, constraints) {
                  return Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: 430.w),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20.w),
                        child: Column(
                          children: [
                            Expanded(
                              child: SingleChildScrollView(
                                padding: EdgeInsets.only(
                                  top: 18.h,
                                  bottom: 12.h,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    AuthEntrance(
                                      delay: const Duration(milliseconds: 40),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
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
                                        ],
                                      ),
                                    ),
                                    SizedBox(height: 20.h),
                                    AuthEntrance(
                                      delay: const Duration(milliseconds: 110),
                                      child: AppTextInput(
                                        controller: viewModel.emailController,
                                        label: 'Business Email',
                                        hintText: 'vendor@example.com',
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        errorText: viewModel.emailError,
                                        fillColor: colors.backgroundSecondary,
                                        borderColor: colors.inputBorder,
                                        borderActiveColor:
                                            colors.vendorPrimaryBlue,
                                        borderRadius: KBorderSize.border,
                                        cursorColor: colors.vendorPrimaryBlue,
                                      ),
                                    ),
                                    SizedBox(height: 14.h),
                                    AuthEntrance(
                                      delay: const Duration(milliseconds: 160),
                                      child: AppTextInput(
                                        controller:
                                            viewModel.passwordController,
                                        label: 'Password',
                                        hintText: 'Minimum 8 characters',
                                        obscureText:
                                            !viewModel.isPasswordVisible,
                                        errorText: viewModel.passwordError,
                                        fillColor: colors.backgroundSecondary,
                                        borderColor: colors.inputBorder,
                                        borderActiveColor:
                                            colors.vendorPrimaryBlue,
                                        borderRadius: KBorderSize.border,
                                        cursorColor: colors.vendorPrimaryBlue,
                                        suffixIcon: IconButton(
                                          onPressed: viewModel
                                              .togglePasswordVisibility,
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
                                    ),
                                    SizedBox(height: 8.h),
                                    AuthEntrance(
                                      delay: const Duration(milliseconds: 210),
                                      child: Column(
                                        children: [
                                          Row(
                                            children: [
                                              Transform.scale(
                                                scale: 0.92,
                                                child: Checkbox(
                                                  value: viewModel.rememberMe,
                                                  onChanged: viewModel
                                                      .toggleRememberMe,
                                                  activeColor:
                                                      colors.vendorPrimaryBlue,
                                                  side: BorderSide(
                                                    color: colors.inputBorder,
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                'Remember me',
                                                style: TextStyle(
                                                  fontSize: 13.sp,
                                                  color: colors.textSecondary,
                                                ),
                                              ),
                                              const Spacer(),
                                              TextButton(
                                                onPressed: () => context.go(
                                                  '/forgotPassword',
                                                ),
                                                child: Text(
                                                  'Forgot Password?',
                                                  style: TextStyle(
                                                    decoration: TextDecoration
                                                        .underline,
                                                    decorationColor: colors
                                                        .vendorPrimaryBlue,
                                                    decorationThickness: 1.5,
                                                    fontSize: 13.sp,
                                                    package: 'grab_go_shared',
                                                    fontFamily: 'Lato',
                                                    fontWeight: FontWeight.w500,
                                                    color: colors
                                                        .vendorPrimaryBlue,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: TextButton(
                                              onPressed: () => context.push(
                                                '/sessionRecovery',
                                              ),
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
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.only(bottom: 12.h),
                              child: Column(
                                children: [
                                  AuthEntrance(
                                    delay: const Duration(milliseconds: 260),
                                    child: SizedBox(
                                      width: double.infinity,
                                      child: AppButton(
                                        buttonText: 'Login',
                                        onPressed: () =>
                                            _handleLogin(context, viewModel),
                                        backgroundColor:
                                            colors.vendorPrimaryBlue,
                                        borderRadius: KBorderSize.border,
                                        textStyle: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15.sp,
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 14.h),
                                  AuthEntrance(
                                    delay: const Duration(milliseconds: 320),
                                    child: RichText(
                                      text: TextSpan(
                                        text: 'Don\'t have an account? ',
                                        style: TextStyle(
                                          fontSize: 13.sp,
                                          package: 'grab_go_shared',
                                          fontFamily: 'Lato',
                                          fontWeight: FontWeight.w500,
                                          color: colors.textSecondary,
                                        ),
                                        children: [
                                          TextSpan(
                                            text: ' Join GrabGo Now',
                                            style: TextStyle(
                                              decoration:
                                                  TextDecoration.underline,
                                              decorationColor:
                                                  colors.vendorPrimaryBlue,
                                              decorationThickness: 1.5,
                                              fontSize: 13.sp,
                                              package: 'grab_go_shared',
                                              fontFamily: 'Lato',
                                              fontWeight: FontWeight.w500,
                                              color: colors.vendorPrimaryBlue,
                                            ),
                                            recognizer: TapGestureRecognizer()
                                              ..onTap = () =>
                                                  context.go('/webPortalInfo'),
                                          ),
                                        ],
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
                  );
                },
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

    final onboardingSetup = context.read<OnboardingSetupViewModel>();
    if (!onboardingSetup.allRequiredCompleted) {
      context.go('/onboardingGuide');
      return;
    }
    context.go('/vendorPreview');
  }
}
