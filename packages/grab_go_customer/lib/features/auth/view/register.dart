// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/core/api/api_client.dart';
import 'package:grab_go_customer/shared/services/cache_service.dart';
import 'package:grab_go_customer/shared/services/location_service.dart';
import 'package:grab_go_customer/shared/services/storage_service.dart';
import 'package:grab_go_customer/shared/services/user_service.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_customer/features/auth/service/phone_auth_service.dart';

class Register extends StatefulWidget {
  const Register({super.key});

  @override
  State<Register> createState() => _RegisterState();
}

class _RegisterState extends State<Register> with SingleTickerProviderStateMixin {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  final TextEditingController bdayController = TextEditingController();
  bool isChecked = false;

  String? usernameError;
  String? emailError;
  String? birthdayError;
  String? passwordError;
  String? confirmPasswordError;

  bool isPasswordVisible = false;
  bool isConfirmPasswordVisible = false;

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
      FocusManager.instance.primaryFocus?.unfocus();
      _animationController.forward();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    usernameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    bdayController.dispose();
    super.dispose();
  }

  Future<bool> _checkInternetConnection() async {
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

  Future<bool> _checkServerConnection() async {
    try {
      final client = HttpClient();
      final request = await client.getUrl(Uri.parse(AppConfig.apiBaseUrl));
      final response = await request.close().timeout(const Duration(seconds: 10));
      client.close();
      return response.statusCode == 200 || response.statusCode == 404 || response.statusCode == 405;
    } catch (e) {
      return false;
    }
  }

  bool _validateFields() {
    setState(() {
      usernameError = null;
      emailError = null;
      birthdayError = null;
      passwordError = null;
      confirmPasswordError = null;

      if (usernameController.text.trim().isEmpty) {
        usernameError = "Please enter a username";
      } else if (usernameController.text.trim().length < 3) {
        usernameError = "Username must be at least 3 characters";
      } else if (usernameController.text.trim().length > 40) {
        usernameError = "Username must be at most 40 characters";
      }

      if (emailController.text.trim().isEmpty) {
        emailError = "Please enter an email address";
      } else if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(emailController.text.trim())) {
        emailError = "Please enter a valid email address";
      }

      if (bdayController.text.trim().isEmpty) {
        birthdayError = "Please select your birthday";
      }

      if (passwordController.text.isEmpty) {
        passwordError = "Please enter a password";
      } else if (passwordController.text.length < 8) {
        passwordError = "Password must be at least 8 characters";
      }

      if (confirmPasswordController.text.isEmpty) {
        confirmPasswordError = "Please confirm your password";
      } else if (passwordController.text != confirmPasswordController.text) {
        confirmPasswordError = "Passwords do not match";
      }
    });

    return usernameError == null &&
        emailError == null &&
        birthdayError == null &&
        passwordError == null &&
        confirmPasswordError == null;
  }

  /// Navigate after successful registration - check location permission if first time
  Future<void> _navigateAfterRegistration(BuildContext context) async {
    // Check if location permission screen has been shown before
    final hasShownLocationScreen = StorageService.hasLocationPermissionScreenShown();

    if (!hasShownLocationScreen) {
      // First time registration - check location permission
      final hasPermission = await LocationService.hasPermission();
      if (!hasPermission) {
        // Show location permission screen
        if (context.mounted) {
          context.go("/locationPermission");
        }
        return;
      } else {
        // Permission already granted, mark screen as shown and go to homepage
        await StorageService.setLocationPermissionScreenShown();
      }
    }

    // Navigate to homepage
    if (context.mounted) {
      context.go("/homepage");
    }
  }

  Future<void> handleRegister() async {
    if (!_validateFields()) {
      return;
    }

    FocusManager.instance.primaryFocus?.unfocus();
    LoadingDialog.instance().show(context: context, text: "Checking connection...");

    final hasInternet = await _checkInternetConnection();
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

    final serverReachable = await _checkServerConnection();
    if (!serverReachable) {
      if (mounted) {
        LoadingDialog.instance().hide();
        AppToastMessage.show(
          context: context,
          icon: Icons.cloud_off,
          message: "Cannot reach server. Please try again later.",
          backgroundColor: context.appColors.error,
        );
      }
      return;
    }

    LoadingDialog.instance().show(context: context, text: "Creating your account...\nThis may take up to a minute.");

    try {
      final request = RegisterRequest(
        username: usernameController.text.trim(),
        email: emailController.text.trim(),
        password: passwordController.text,
        dateOfBirth: bdayController.text.trim(),
      );
      final response = await authService
          .registerUser(request)
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
        final message = response.body!.message;
        final token = response.body!.token;
        User? user = response.body!.userData ?? response.body!.user;

        if (token != null && token.isNotEmpty) {
          await CacheService.saveAuthToken(token);
        }

        if (user != null) {
          await UserService().setCurrentUser(user);
          if (user.id != null) {
            PhoneAuthService().setUserId(user.id!);
          }
        }

        if (mounted) {
          AppToastMessage.show(
            context: context,
            icon: Icons.check_circle,
            message: message,
            backgroundColor: Colors.green,
          );

          context.push("/verifyPhone");
        }
      } else {
        String errorMessage = "Username already taken.";
        if (response.error != null) {
          errorMessage = "Registration failed. Please try again.";
        } else if (response.statusCode == 400) {
          errorMessage = "Invalid data. Please check your inputs.";
        } else if (response.statusCode == 409) {
          errorMessage = "Username or email already exists.";
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
      final hasInternet = await _checkInternetConnection();

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

  Future<void> _handleGoogleSignUp() async {
    FocusManager.instance.primaryFocus?.unfocus();
    LoadingDialog.instance().show(context: context, text: "Checking connection...");

    final hasInternet = await _checkInternetConnection();
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

    final serverReachable = await _checkServerConnection();
    if (!serverReachable) {
      if (mounted) {
        LoadingDialog.instance().hide();
        AppToastMessage.show(
          context: context,
          icon: Icons.cloud_off,
          message: "Cannot reach server. Please try again later.",
          backgroundColor: context.appColors.error,
        );
      }
      return;
    }

    LoadingDialog.instance().show(context: context, text: "Signing up with Google...\nThis may take up to a minute.");

    try {
      final googleUserData = await GoogleSignInService().signInWithGoogle();

      if (googleUserData == null) {
        if (mounted) {
          LoadingDialog.instance().hide();
        }
        return;
      }

      if (!mounted) return;

      LoadingDialog.instance().show(context: context, text: "Creating your account...");

      final request = GoogleSignInRequest(
        googleId: googleUserData['googleId'],
        email: googleUserData['email'],
        displayName: googleUserData['displayName'],
        photoUrl: googleUserData['photoUrl'],
        idToken: googleUserData['idToken'],
      );

      final response = await authService
          .googleSignUp(request)
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
        final user = response.body!.userData;

        if (token != null && token.isNotEmpty) {
          await CacheService.saveAuthToken(token);
        }

        if (user != null) {
          PhoneAuthService().setUserId(user.id ?? '');
        }

        if (mounted) {
          // Check if location permission screen should be shown (first time registration)
          await _navigateAfterRegistration(context);
        }
      } else {
        String errorMessage = "Google Sign-Up failed. Please try again.";

        if (response.error != null) {
          errorMessage = response.error.toString();
        } else if (response.statusCode == 400) {
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

      final hasInternet = await _checkInternetConnection();
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
              splashColor: colors.iconSecondary.withAlpha(50),
              child: Padding(
                padding: EdgeInsets.all(KSpacing.md12.r),
                child: SvgPicture.asset(
                  Assets.icons.navArrowLeft,
                  package: 'grab_go_shared',
                  colorFilter: ColorFilter.mode(colors.iconPrimary, BlendMode.srcIn),
                ),
              ),
            ),
          ),
        ),
      ),
      body: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: ThemeHelper.getSystemUiOverlayStyle(context),
          child: SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: KSpacing.lg.w, vertical: KSpacing.xl40.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Container(
                        height: 100.h,
                        width: 100.h,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [colors.accentGreen.withOpacity(0.2), colors.accentOrange.withOpacity(0.2)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(color: colors.accentGreen.withOpacity(0.2), blurRadius: 30, spreadRadius: 5),
                          ],
                        ),
                        child: Center(
                          child: SvgPicture.asset(
                            Assets.icons.user,
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
                        AppStrings.registerMain,
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
                      child: Text(
                        AppStrings.registerSub,
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
                  SizedBox(height: KSpacing.xl40.h),

                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Column(
                        children: [
                          AppTextInput(
                            controller: usernameController,
                            label: AppStrings.registerUsernameLabel,
                            hintText: AppStrings.registerUsernameHint,
                            borderColor: colors.inputBorder,
                            fillColor: colors.backgroundSecondary,
                            borderActiveColor: colors.accentGreen,
                            borderRadius: KBorderSize.borderRadius15,
                            contentPadding: EdgeInsets.all(KSpacing.md15.r),
                            keyboardType: TextInputType.text,
                            errorText: usernameError,
                            prefixIcon: Padding(
                              padding: EdgeInsets.all(KSpacing.md12.r),
                              child: SvgPicture.asset(
                                Assets.icons.user,
                                package: 'grab_go_shared',
                                width: KIconSize.md,
                                height: KIconSize.md,
                                colorFilter: ColorFilter.mode(colors.iconSecondary, BlendMode.srcIn),
                              ),
                            ),
                          ),

                          SizedBox(height: KSpacing.lg.h),

                          AppTextInput(
                            controller: emailController,
                            label: AppStrings.registerEmailLabel,
                            hintText: AppStrings.registerEmailHint,
                            borderColor: colors.inputBorder,
                            fillColor: colors.backgroundSecondary,
                            borderActiveColor: colors.accentGreen,
                            borderRadius: KBorderSize.borderRadius15,
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
                            controller: bdayController,
                            label: AppStrings.registerBdayLabel,
                            hintText: AppStrings.registerBdayHint,
                            fillColor: colors.backgroundSecondary,
                            borderActiveColor: colors.accentGreen,
                            borderColor: colors.inputBorder,
                            borderRadius: KBorderSize.borderRadius15,
                            contentPadding: EdgeInsets.all(KSpacing.md15.r),
                            keyboardType: TextInputType.datetime,
                            readOnly: true,
                            errorText: birthdayError,
                            prefixIcon: Padding(
                              padding: EdgeInsets.all(KSpacing.md12.r),
                              child: SvgPicture.asset(
                                Assets.icons.calendar,
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
                            label: AppStrings.registerPasswordLabel,
                            hintText: AppStrings.registerPasswordHint,
                            fillColor: colors.backgroundSecondary,
                            borderActiveColor: colors.accentGreen,
                            borderColor: colors.inputBorder,
                            borderRadius: KBorderSize.borderRadius15,
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

                          SizedBox(height: KSpacing.lg.h),

                          AppTextInput(
                            controller: confirmPasswordController,
                            label: AppStrings.registerConfirmPasswordLabel,
                            hintText: AppStrings.registerConfirmPasswordHint,
                            fillColor: colors.backgroundSecondary,
                            borderColor: colors.inputBorder,
                            borderActiveColor: colors.accentGreen,
                            borderRadius: KBorderSize.borderRadius15,
                            contentPadding: EdgeInsets.all(KSpacing.md15.r),
                            obscureText: !isConfirmPasswordVisible,
                            errorText: confirmPasswordError,
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
                                  isConfirmPasswordVisible = !isConfirmPasswordVisible;
                                });
                              },
                              child: Padding(
                                padding: EdgeInsets.all(KSpacing.md12.r),
                                child: SvgPicture.asset(
                                  isConfirmPasswordVisible ? Assets.icons.eye : Assets.icons.eyeClosed,
                                  package: 'grab_go_shared',
                                  width: KIconSize.md,
                                  height: KIconSize.md,
                                  colorFilter: ColorFilter.mode(colors.iconSecondary, BlendMode.srcIn),
                                ),
                              ),
                            ),
                          ),

                          SizedBox(height: KSpacing.lg25.h),

                          GestureDetector(
                            onTap: handleRegister,
                            child: Container(
                              height: 56.h,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [colors.accentGreen, colors.accentGreen.withOpacity(0.8)],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
                                boxShadow: [
                                  BoxShadow(
                                    color: colors.accentGreen.withOpacity(0.4),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Text(
                                  AppStrings.register,
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
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: KSpacing.lg.h),

                  Align(
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          "Already have an account?",
                          style: TextStyle(color: colors.textSecondary, fontSize: KTextSize.small.sp),
                        ),
                        GestureDetector(
                          onTap: () {
                            context.pop();
                          },
                          child: Text(
                            "  Login Now",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: colors.textPrimary,
                              fontSize: KTextSize.small.sp,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  SizedBox(height: KSpacing.lg25.h),

                  Row(
                    children: [
                      Expanded(
                        child: Divider(color: colors.divider, thickness: KBorderWidth.normal, endIndent: KSpacing.md),
                      ),
                      Text(
                        "or sign up with",
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
                    opacity: _fadeAnimation,
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: _handleGoogleSignUp,
                            child: Container(
                              height: 56.h,
                              decoration: BoxDecoration(
                                color: colors.backgroundSecondary,
                                borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
                                border: Border.all(color: colors.border, width: 1.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: colors.shadow.withOpacity(0.05),
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
                                    "Sign Up with Google",
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
                              AppToastMessage.show(
                                context: context,
                                icon: Icons.info,
                                message: "Facebook sign-up coming soon!",
                                backgroundColor: context.appColors.accentOrange,
                              );
                            },
                            child: Container(
                              height: 56.h,
                              decoration: BoxDecoration(
                                color: colors.backgroundSecondary,
                                borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
                                border: Border.all(color: colors.border, width: 1.5),
                                boxShadow: [
                                  BoxShadow(
                                    color: colors.shadow.withOpacity(0.05),
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
                                    "Sign Up with Facebook",
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
