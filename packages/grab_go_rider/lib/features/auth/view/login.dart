import 'dart:async';
import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_rider/shared/service/user_service.dart';
import 'package:grab_go_rider/core/api/api_client.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> with SingleTickerProviderStateMixin {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isChecked = false;

  String? emailError;
  String? passwordError;

  bool isPasswordVisible = false;

  late AnimationController animationController;
  late Animation<double> fadeAnimation;
  late Animation<Offset> slideAnimation;
  late Animation<double> scaleAnimation;

  @override
  void initState() {
    super.initState();

    animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));

    fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
      ),
    );

    slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(
        parent: animationController,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: animationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    loadSavedCredentials();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusManager.instance.primaryFocus?.unfocus();
      animationController.forward();
    });
  }

  Future<void> loadSavedCredentials() async {
    final credentials = await CacheService.getCredentials();
    if (mounted && credentials['rememberMe'] == true) {
      setState(() {
        emailController.text = credentials['email'] ?? '';
        passwordController.text = credentials['password'] ?? '';
        isChecked = credentials['rememberMe'] ?? false;
      });
    }
  }

  @override
  void dispose() {
    animationController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  bool validateFields() {
    setState(() {
      emailError = null;
      passwordError = null;

      if (emailController.text.trim().isEmpty) {
        emailError = "Please enter your email address";
      } else if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(emailController.text.trim())) {
        emailError = "Please enter a valid email address";
      }

      if (passwordController.text.isEmpty) {
        passwordError = "Please enter your password";
      }
    });

    return emailError == null && passwordError == null;
  }

  Future<bool> checkInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        return true;
      }
    } on SocketException {
      return false;
    }
    return false;
  }

  Future<void> handleGoogleSignIn() async {
    FocusManager.instance.primaryFocus?.unfocus();
    LoadingDialog.instance().show(context: context, text: "Checking connection...");

    final hasInternet = await checkInternetConnection();
    if (!hasInternet) {
      if (mounted) {
        LoadingDialog.instance().hide();
        AppToastMessage.show(
          context: context,
          icon: Icons.wifi_off,
          message: "No internet connection. Please check your network settings.",
          backgroundColor: context.appColors.error,
        );
      }
      return;
    }

    LoadingDialog.instance().show(context: context, text: "Signing in with Google...");

    try {
      final googleUserData = await GoogleSignInService().signInWithGoogle();

      if (googleUserData == null) {
        if (mounted) {
          LoadingDialog.instance().hide();
        }
        return;
      }

      if (!mounted) return;

      LoadingDialog.instance().show(context: context, text: "Authenticating with server...");

      final request = GoogleSignInRequest(
        googleId: googleUserData['googleId'],
        email: googleUserData['email'],
        displayName: googleUserData['displayName'],
        photoUrl: googleUserData['photoUrl'],
        idToken: googleUserData['idToken'],
      );

      final response = await authService
          .googleSignIn(request)
          .timeout(
            const Duration(seconds: 60),
            onTimeout: () {
              throw TimeoutException(
                'Server is taking too long to respond. '
                'This might be because the free server is waking up. Please try again.',
              );
            },
          );

      if (!mounted) return;

      LoadingDialog.instance().show(context: context, text: "Almost done..");

      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;
      LoadingDialog.instance().hide();

      if (response.isSuccessful && response.body != null) {
        final token = response.body!.token;
        User? user = response.body!.userData;

        if (user != null && user.role != null && user.role!.toLowerCase() != 'rider') {
          if (mounted) {
            AppToastMessage.show(
              context: context,
              icon: Icons.error_outline,
              message: "User not found",
              backgroundColor: context.appColors.error,
            );
          }
          return;
        }

        if (token != null && token.isNotEmpty) {
          await CacheService.saveAuthToken(token);
        }

        if (user != null) {
          await UserService().setCurrentUser(user);
          await SocketService().initialize();
        }

        if (mounted) {
          context.go("/home");
        }
      } else {
        String errorMessage = "Google Sign-In failed. Please try again.";

        if (response.statusCode == 400) {
          errorMessage = "Invalid Google account data.";
        } else if (response.statusCode == 409) {
          errorMessage = "Email already exists with a different login method.";
        } else if (response.statusCode == 500) {
          errorMessage = "Server error. Please try again later.";
        }

        if (mounted) {
          AppToastMessage.show(
            context: context,
            icon: Icons.error_outline,
            message: errorMessage,
            backgroundColor: context.appColors.error,
          );
        }
      }
    } on SocketException {
      if (mounted) {
        LoadingDialog.instance().hide();
      }

      final hasInternet = await checkInternetConnection();
      String message;
      IconData icon;

      if (!hasInternet) {
        message = "No internet connection detected. Please check your network.";
        icon = Icons.wifi_off;
      } else {
        message = "Cannot connect to server. Please try again.";
        icon = Icons.cloud_off;
      }

      if (mounted) {
        AppToastMessage.show(context: context, icon: icon, message: message, backgroundColor: context.appColors.error);
      }
    } on TimeoutException {
      if (mounted) {
        LoadingDialog.instance().hide();
      }

      if (mounted) {
        AppToastMessage.show(
          context: context,
          icon: Icons.timer_off,
          message: "Request timeout. Server is taking too long. Please try again.",
          backgroundColor: context.appColors.error,
        );
      }
    } catch (e) {
      if (mounted) {
        LoadingDialog.instance().hide();
      }

      if (mounted) {
        AppToastMessage.show(
          context: context,
          icon: Icons.error,
          message: "An unexpected error occurred. Please try again.",
          backgroundColor: context.appColors.error,
        );
      }
    }
  }

  Future<void> _handleLogin() async {
    if (!validateFields()) {
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    LoadingDialog.instance().show(context: context, text: "Checking connection...");

    final hasInternet = await checkInternetConnection();
    if (!hasInternet) {
      if (mounted) {
        LoadingDialog.instance().hide();
        AppToastMessage.show(
          context: context,
          icon: Icons.wifi_off,
          message: "No internet connection. Please check your network settings.",
          backgroundColor: context.appColors.error,
        );
      }
      return;
    }

    LoadingDialog.instance().show(context: context, text: "Signing you in...\nThis may take up to a minute.");

    try {
      final request = LoginRequest(email: emailController.text.trim(), password: passwordController.text);

      final response = await authService
          .loginUser(request)
          .timeout(
            const Duration(seconds: 60),
            onTimeout: () {
              throw TimeoutException(
                'Server is taking too long to respond. '
                'This might be because the free server is waking up. Please try again.',
              );
            },
          );

      if (!mounted) return;

      LoadingDialog.instance().show(context: context, text: "Almost done..");

      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;
      LoadingDialog.instance().hide();

      if (response.isSuccessful && response.body != null) {
        final token = response.body!.token;
        User? user = response.body!.userData;

        // Validate that the user has the "rider" role
        if (user != null && user.role != null && user.role!.toLowerCase() != 'rider') {
          if (mounted) {
            AppToastMessage.show(
              context: context,
              icon: Icons.error_outline,
              message: "User not found",
              backgroundColor: context.appColors.error,
            );
          }
          return;
        }

        if (token != null && token.isNotEmpty) {
          await CacheService.saveAuthToken(token);
        }

        if (user != null) {
          await UserService().setCurrentUser(user);
          await SocketService().initialize();
        }

        await CacheService.saveCredentials(
          email: emailController.text.trim(),
          password: passwordController.text,
          rememberMe: isChecked,
        );

        if (mounted) {
          context.go("/home");
        }
      } else {
        String errorMessage = "Login failed. Please try again.";

        if (response.statusCode == 400) {
          errorMessage = "Invalid email or password.";
        } else if (response.statusCode == 401) {
          errorMessage = "Invalid credentials. Please check your email and password.";
        } else if (response.statusCode == 404) {
          errorMessage = "User not found. Please check your email or create an account.";
        } else if (response.statusCode == 500) {
          errorMessage = "Server error. Please try again later.";
        }

        if (mounted) {
          AppToastMessage.show(
            context: context,
            icon: Icons.error_outline,
            message: errorMessage,
            backgroundColor: context.appColors.error,
          );
        }
      }
    } on SocketException {
      if (mounted) {
        LoadingDialog.instance().hide();
      }

      final hasInternet = await checkInternetConnection();

      String message;
      IconData icon;

      if (!hasInternet) {
        message = "No internet connection detected. Please check your network.";
        icon = Icons.wifi_off;
      } else {
        message = "Cannot connect to server. Please try again.";
        icon = Icons.cloud_off;
      }

      if (mounted) {
        AppToastMessage.show(context: context, icon: icon, message: message, backgroundColor: context.appColors.error);
      }
    } on TimeoutException {
      if (mounted) {
        LoadingDialog.instance().hide();
      }

      if (mounted) {
        AppToastMessage.show(
          context: context,
          icon: Icons.timer_off,
          message: "Request timeout. Server is taking too long. Please try again.",
          backgroundColor: context.appColors.error,
        );
      }
    } catch (e) {
      if (mounted) {
        LoadingDialog.instance().hide();
      }

      if (mounted) {
        AppToastMessage.show(
          context: context,
          icon: Icons.error,
          message: "An unexpected error occurred. Please try again.",
          backgroundColor: context.appColors.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: colors.backgroundPrimary,
      body: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: AnnotatedRegion<SystemUiOverlayStyle>(
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
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ScaleTransition(
                      scale: scaleAnimation,
                      child: FadeTransition(
                        opacity: fadeAnimation,
                        child: Container(
                          height: 80.h,
                          width: 80.h,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                            color: colors.accentOrange.withValues(alpha: 0.15),
                          ),
                          child: Center(
                            child: SvgPicture.asset(
                              Assets.icons.deliveryGuyIcon,
                              package: "grab_go_shared",
                              height: 50.h,
                              width: 50.w,
                              colorFilter: ColorFilter.mode(colors.accentOrange, BlendMode.srcIn),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: KSpacing.lg25.h),

                  FadeTransition(
                    opacity: fadeAnimation,
                    child: SlideTransition(
                      position: slideAnimation,
                      child: Text(
                        AppStrings.riderLoginMain,
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
                    opacity: fadeAnimation,
                    child: SlideTransition(
                      position: slideAnimation,
                      child: Text(
                        AppStrings.riderLoginSub,
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
                    opacity: fadeAnimation,
                    child: SlideTransition(
                      position: slideAnimation,
                      child: Column(
                        children: [
                          AppTextInput(
                            controller: emailController,
                            label: AppStrings.loginEmailLabel,
                            hintText: AppStrings.loginEmailHint,
                            borderColor: colors.inputBorder,
                            fillColor: colors.backgroundSecondary,
                            borderRadius: KBorderSize.borderRadius4,
                            contentPadding: EdgeInsets.all(KSpacing.md15.r),
                            keyboardType: TextInputType.emailAddress,
                            errorText: emailError,
                            prefixIcon: Padding(
                              padding: EdgeInsets.all(KSpacing.md12.r),
                              child: SvgPicture.asset(
                                Assets.icons.mail,
                                package: 'grab_go_shared',
                                width: KIconSize.md,
                                height: KIconSize.md,
                                colorFilter: ColorFilter.mode(colors.iconSecondary, BlendMode.srcIn),
                              ),
                            ),
                          ),

                          SizedBox(height: KSpacing.lg.h),

                          AppTextInput(
                            controller: passwordController,
                            label: AppStrings.loginPasswordLabel,
                            hintText: AppStrings.loginPasswordHint,
                            fillColor: colors.backgroundSecondary,
                            borderColor: colors.inputBorder,
                            borderRadius: KBorderSize.borderRadius4,
                            contentPadding: EdgeInsets.all(KSpacing.md15.r),
                            obscureText: !isPasswordVisible,
                            errorText: passwordError,
                            prefixIcon: Padding(
                              padding: EdgeInsets.all(KSpacing.md12.r),
                              child: SvgPicture.asset(
                                Assets.icons.lock,
                                package: 'grab_go_shared',
                                width: KIconSize.md,
                                height: KIconSize.md,
                                colorFilter: ColorFilter.mode(colors.iconSecondary, BlendMode.srcIn),
                              ),
                            ),
                            suffixIcon: GestureDetector(
                              onTap: () {
                                setState(() {
                                  isPasswordVisible = !isPasswordVisible;
                                });
                              },
                              child: Padding(
                                padding: EdgeInsets.all(KSpacing.md12.r),
                                child: SvgPicture.asset(
                                  isPasswordVisible ? Assets.icons.eye : Assets.icons.eyeClosed,
                                  package: 'grab_go_shared',
                                  width: KIconSize.md,
                                  height: KIconSize.md,
                                  colorFilter: ColorFilter.mode(colors.iconSecondary, BlendMode.srcIn),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: KSpacing.md15.h),

                  Row(
                    children: [
                      Checkbox(
                        value: isChecked,
                        onChanged: (value) async {
                          setState(() {
                            isChecked = value ?? false;
                          });
                          if (!(value ?? false)) {
                            await CacheService.clearCredentials();
                          }
                        },
                        activeColor: colors.accentOrange,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KBorderSize.borderRadius4)),
                        side: BorderSide(color: colors.border, width: KBorderWidth.thick),
                      ),
                      Text(
                        AppStrings.loginCheckboxLabel,
                        style: TextStyle(
                          fontSize: KTextSize.small.sp,
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      GestureDetector(
                        onTap: () {
                          context.push("/forgotPassword");
                        },
                        child: Text(
                          AppStrings.loginForgotPassword,
                          style: TextStyle(
                            fontSize: KTextSize.small.sp,
                            fontWeight: FontWeight.w600,
                            color: colors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: KSpacing.lg25.h),

                  FadeTransition(
                    opacity: fadeAnimation,
                    child: SlideTransition(
                      position: slideAnimation,
                      child: GestureDetector(
                        onTap: _handleLogin,
                        child: Container(
                          height: 56.h,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [colors.accentOrange, colors.accentOrange.withValues(alpha: 0.8)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                            boxShadow: [
                              BoxShadow(
                                color: colors.accentOrange.withValues(alpha: 0.4),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              AppStrings.login,
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
                    ),
                  ),

                  SizedBox(height: KSpacing.lg.h),

                  Column(
                    children: [
                      RichText(
                        textAlign: TextAlign.center,
                        text: TextSpan(
                          text: "Don't have an account? ",
                          style: TextStyle(
                            fontFamily: "Lato",
                            package: 'grab_go_shared',
                            color: colors.textSecondary,
                            fontSize: KTextSize.small.sp,
                            height: 1.4,
                          ),
                          children: [
                            TextSpan(
                              recognizer: TapGestureRecognizer()
                                ..onTap = () {
                                  context.push("/register");
                                },
                              text: " Create Now",
                              style: TextStyle(
                                fontFamily: "Lato",
                                package: 'grab_go_shared',
                                fontWeight: FontWeight.w600,
                                color: colors.textPrimary,
                                fontSize: KTextSize.small.sp,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: KSpacing.lg25.h),

                  Row(
                    children: [
                      Expanded(
                        child: Divider(color: colors.divider, thickness: KBorderWidth.normal, endIndent: KSpacing.md),
                      ),
                      Text(
                        "or continue with",
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: KTextSize.small,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Expanded(
                        child: Divider(color: colors.divider, thickness: KBorderWidth.normal, indent: KSpacing.md),
                      ),
                    ],
                  ),

                  SizedBox(height: KSpacing.lg25.h),

                  FadeTransition(
                    opacity: fadeAnimation,
                    child: SlideTransition(
                      position: slideAnimation,
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: handleGoogleSignIn,
                            child: Container(
                              height: 56.h,
                              decoration: BoxDecoration(
                                color: colors.backgroundSecondary,
                                borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                                border: Border.all(color: colors.border, width: 1.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: colors.shadow.withValues(alpha: 0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image(
                                    image: Assets.icons.google.provider(package: 'grab_go_shared'),
                                    height: 24.r,
                                    width: 24.r,
                                  ),
                                  SizedBox(width: KSpacing.md.w),
                                  Text(
                                    "Login with Google",
                                    style: TextStyle(
                                      color: colors.textPrimary,
                                      fontSize: 15.sp,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          SizedBox(height: KSpacing.md.h),
                          GestureDetector(
                            onTap: () {
                              // TODO: Implement Facebook Sign-In
                            },
                            child: Container(
                              height: 56.h,
                              decoration: BoxDecoration(
                                color: colors.backgroundSecondary,
                                borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                                border: Border.all(color: colors.border, width: 1.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: colors.shadow.withValues(alpha: 0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Image(
                                    image: Assets.icons.facebook.provider(package: 'grab_go_shared'),
                                    height: 24.r,
                                    width: 24.r,
                                  ),
                                  SizedBox(width: KSpacing.md.w),
                                  Text(
                                    "Login with Facebook",
                                    style: TextStyle(
                                      color: colors.textPrimary,
                                      fontSize: 15.sp,
                                      fontWeight: FontWeight.w600,
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
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
