import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/core/api/api_client.dart';
import 'package:grab_go_customer/shared/services/user_service.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_customer/shared/services/storage_service.dart';
import 'package:grab_go_customer/shared/viewmodels/native_location_provider.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:provider/provider.dart';

class Login extends StatefulWidget {
  final String? returnTo;

  const Login({super.key, this.returnTo});

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
  bool hasRestaurantApplication = false;

  int _loginAttempts = 0;
  DateTime? _lastLoginAttempt;

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
    checkRestaurantApplicationStatus();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusManager.instance.primaryFocus?.unfocus();
      animationController.forward();
    });
  }

  Future<void> loadSavedCredentials() async {
    final credentials = await StorageService.loadCredentials();
    if (mounted && credentials['rememberMe'] == true) {
      setState(() {
        emailController.text = credentials['email'] ?? '';
        isChecked = credentials['rememberMe'] ?? false;
      });
    }
  }

  Future<void> checkRestaurantApplicationStatus() async {
    final hasApplication = await StorageService.hasRestaurantApplicationSubmitted();
    final isCompleted = await StorageService.isRestaurantApplicationCompleted();

    if (mounted) {
      setState(() {
        hasRestaurantApplication = hasApplication && !isCompleted;
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
      } else if (!RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(emailController.text.trim())) {
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

  Future<void> _navigateAfterLogin(BuildContext context) async {
    final directReturnTo = widget.returnTo?.trim();
    if (directReturnTo != null && directReturnTo.isNotEmpty) {
      context.go(directReturnTo);
      return;
    }

    final locationProvider = Provider.of<NativeLocationProvider>(context, listen: false);

    bool hasChange = false;
    try {
      hasChange = await locationProvider.hasSignificantLocationChange().timeout(const Duration(seconds: 5));
    } catch (_) {
      hasChange = false;
    }

    if (context.mounted) {
      if (hasChange) {
        context.go("/confirm-address");
      } else {
        context.go("/homepage");
      }
    }
  }

  void _continueAsGuest() {
    FocusManager.instance.primaryFocus?.unfocus();
    context.go("/homepage");
  }

  Future<void> _handleLogin() async {
    if (!validateFields()) {
      return;
    }

    if (_loginAttempts >= 5) {
      final timeSinceLastAttempt = DateTime.now().difference(_lastLoginAttempt!);
      if (timeSinceLastAttempt < const Duration(minutes: 5)) {
        final remainingSeconds = 300 - timeSinceLastAttempt.inSeconds;
        final remainingMinutes = (remainingSeconds / 60).ceil();
        if (mounted) {
          AppToastMessage.show(
            context: context,
            message: "Too many login attempts. Please wait $remainingMinutes minute(s) before trying again.",
            backgroundColor: context.appColors.error,
          );
        }
        return;
      } else {
        _loginAttempts = 0;
      }
    }

    _loginAttempts++;
    _lastLoginAttempt = DateTime.now();

    FocusManager.instance.primaryFocus?.unfocus();
    LoadingDialog.instance().show(context: context, text: "Checking connection...");

    final hasInternet = await checkInternetConnection();
    if (!hasInternet) {
      if (mounted) {
        LoadingDialog.instance().hide();
        AppToastMessage.show(
          context: context,
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

      UserResponse? parsedResponse;
      if (response.body == null && response.bodyString.isNotEmpty) {
        try {
          final decoded = jsonDecode(response.bodyString);
          if (decoded is Map<String, dynamic>) {
            parsedResponse = UserResponse.fromJson(decoded);
          } else if (decoded is Map) {
            parsedResponse = UserResponse.fromJson(Map<String, dynamic>.from(decoded));
          }
        } catch (_) {}
      }

      final responseData = response.body ?? parsedResponse;

      if (response.isSuccessful && responseData != null) {
        final token = responseData.token;
        User? user = responseData.userData;

        if (user == null) {
          if (responseData.user != null) {
            user = responseData.user;
          } else if (responseData.data != null) {
            user = responseData.data;
          }
        }

        if (token != null && token.isNotEmpty) {
          await CacheService.saveAuthToken(token);
        }

        if (user != null) {
          await UserService().setCurrentUser(user);
        } else {
          if (emailController.text.isNotEmpty) {
            final fallbackUser = User(
              id: "temp_${DateTime.now().millisecondsSinceEpoch}",
              username: emailController.text.split('@')[0],
              email: emailController.text,
              phone: null,
              isPhoneVerified: false,
              profilePicture: null,
              role: "user",
              permissions: null,
              dateOfBirth: null,
            );

            await UserService().setCurrentUser(fallbackUser);
          }
        }
        await StorageService.saveCredentials(email: emailController.text.trim(), rememberMe: isChecked);

        _loginAttempts = 0;
        _lastLoginAttempt = null;

        if (mounted) {
          await _navigateAfterLogin(context);
        }
      } else {
        String? errorMessage = response.body?.message;
        if (errorMessage == null || errorMessage.isEmpty) {
          final error = response.error;
          if (error is Map && error['message'] != null) {
            errorMessage = error['message']?.toString();
          } else if (error != null) {
            errorMessage = error.toString();
          }
        }

        errorMessage ??= "Login failed. Please try again.";

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
          AppToastMessage.show(context: context, message: errorMessage, backgroundColor: context.appColors.error);
        }
      }
    } on SocketException {
      if (mounted) {
        LoadingDialog.instance().hide();
      }

      final hasInternet = await checkInternetConnection();

      String message;

      if (!hasInternet) {
        message = "No internet connection detected. Please check your network.";
      } else {
        message = "Cannot connect to server. Please try again.";
      }

      if (mounted) {
        AppToastMessage.show(context: context, message: message, backgroundColor: context.appColors.error);
      }
    } on TimeoutException {
      if (mounted) {
        LoadingDialog.instance().hide();
      }

      if (mounted) {
        AppToastMessage.show(
          context: context,
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
      appBar: hasRestaurantApplication
          ? AppBar(
              backgroundColor: colors.backgroundPrimary,
              automaticallyImplyLeading: false,
              elevation: 0,
              scrolledUnderElevation: 0,
              actionsPadding: EdgeInsets.only(right: 10.w),
              actions: [
                TextButton(
                  onPressed: () => context.push("/restaurantAccountCreationTracking"),
                  child: Text(
                    "Track Application",
                    style: TextStyle(
                      fontSize: KTextSize.medium.sp,
                      fontWeight: FontWeight.w600,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
              ],
            )
          : null,
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
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: KSpacing.lg.w, vertical: KSpacing.xl40.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ScaleTransition(
                    scale: scaleAnimation,
                    child: FadeTransition(
                      opacity: fadeAnimation,
                      child: Container(
                        height: 100.h,
                        width: 100.h,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colors.accentOrange.withValues(alpha: 0.2),
                        ),
                        child: Center(
                          child: Assets.icons.appIconCustomer.image(
                            height: 60.h,
                            width: 60.h,
                            color: colors.accentOrange,
                            package: 'grab_go_shared',
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
                        AppStrings.loginMain,
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
                    opacity: fadeAnimation,
                    child: SlideTransition(
                      position: slideAnimation,
                      child: Text(
                        AppStrings.loginSub,
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
                            borderActiveColor: colors.accentOrange,
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
                            controller: passwordController,
                            label: AppStrings.loginPasswordLabel,
                            hintText: AppStrings.loginPasswordHint,
                            fillColor: colors.backgroundSecondary,
                            borderActiveColor: colors.accentOrange,
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
                            await StorageService.clearCredentials();
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
                        onTap: () => context.push("/forgotPassword"),
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
                      child: Container(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: colors.accentOrange.withValues(alpha: 0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: AppButton(
                          onPressed: _handleLogin,
                          backgroundColor: colors.accentOrange,
                          borderRadius: KBorderSize.borderRadius15,
                          buttonText: AppStrings.login,
                          textStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15.sp),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: KSpacing.md.h),

                  FadeTransition(
                    opacity: fadeAnimation,
                    child: TextButton.icon(
                      onPressed: _continueAsGuest,
                      style: TextButton.styleFrom(
                        foregroundColor: colors.textPrimary,
                        padding: EdgeInsets.symmetric(horizontal: KSpacing.md15.w, vertical: KSpacing.sm.h),
                      ),
                      icon: SvgPicture.asset(
                        Assets.icons.user,
                        package: 'grab_go_shared',
                        width: 16.w,
                        height: 16.h,
                        colorFilter: ColorFilter.mode(colors.textPrimary, BlendMode.srcIn),
                      ),
                      label: Text(
                        "Continue as guest",
                        style: TextStyle(
                          fontFamily: "Lato",
                          package: 'grab_go_shared',
                          color: colors.textPrimary,
                          fontSize: KTextSize.small.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: KSpacing.xs.h),

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
                                  context.push("/verifyPhone");
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

                      // SizedBox(height: KSpacing.sm.h),

                      // RichText(
                      //   textAlign: TextAlign.center,
                      //   text: TextSpan(
                      //     text: "Want to partner with us? ",
                      //     style: TextStyle(
                      //       fontFamily: "Lato",
                      //       package: 'grab_go_shared',
                      //       color: colors.textSecondary,
                      //       fontSize: KTextSize.small.sp,
                      //       height: 1.4,
                      //     ),
                      //     children: [
                      //       TextSpan(
                      //         recognizer: TapGestureRecognizer()
                      //           ..onTap = () {
                      //             context.push("/restaurantRegistration");
                      //           },
                      //         text: " Join as a restaurant",
                      //         style: TextStyle(
                      //           fontFamily: "Lato",
                      //           package: 'grab_go_shared',
                      //           fontWeight: FontWeight.w600,
                      //           color: colors.textPrimary,
                      //           fontSize: KTextSize.small.sp,
                      //         ),
                      //       ),
                      //     ],
                      //   ),
                      // ),
                    ],
                  ),

                  SizedBox(height: KSpacing.lg25.h),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
