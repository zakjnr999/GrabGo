import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/core/api/api_client.dart';
import 'package:grab_go_customer/shared/services/user_service.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_customer/features/auth/service/phone_auth_service.dart';
import 'package:intl/intl.dart';

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
  final TextEditingController promoCodeController = TextEditingController();
  final TextEditingController bdayController = TextEditingController();
  bool isChecked = false;

  String? usernameError;
  String? emailError;
  String? birthdayError;
  String? passwordError;
  String? confirmPasswordError;
  String? promoCodeError;
  bool isPromoCodeValid = false;
  bool isValidatingPromoCode = false;

  bool isPasswordVisible = false;
  bool isConfirmPasswordVisible = false;
  bool agreedToTerms = false;

  int _registrationAttempts = 0;
  DateTime? _lastRegistrationAttempt;

  DateTime? _lastInternetCheck;
  bool? _lastInternetResult;

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

    promoCodeController.addListener(() {
      setState(() {});
    });

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
    promoCodeController.dispose();
    super.dispose();
  }

  Future<bool> _checkInternetConnection() async {
    if (_lastInternetCheck != null && DateTime.now().difference(_lastInternetCheck!) < const Duration(seconds: 5)) {
      return _lastInternetResult!;
    }

    try {
      final result = await InternetAddress.lookup('google.com');
      _lastInternetResult = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      _lastInternetCheck = DateTime.now();
      return _lastInternetResult!;
    } on SocketException {
      _lastInternetResult = false;
      _lastInternetCheck = DateTime.now();
      return false;
    }
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
      } else if (!RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(emailController.text.trim())) {
        emailError = "Please enter a valid email address";
      }

      if (bdayController.text.trim().isEmpty) {
        birthdayError = "Please select your birthday";
      } else {
        try {
          final selectedDate = DateFormat('MMM d, yyyy').parse(bdayController.text.trim());
          final today = DateTime.now();
          final age =
              today.year -
              selectedDate.year -
              ((today.month < selectedDate.month || (today.month == selectedDate.month && today.day < selectedDate.day))
                  ? 1
                  : 0);
          if (age < 13) {
            birthdayError = "You must be at least 13 years old to register";
          }
        } catch (e) {
          birthdayError = "Invalid date format";
        }
      }

      if (passwordController.text.isEmpty) {
        passwordError = "Please enter a password";
      } else if (passwordController.text.length < 8) {
        passwordError = "Password must be at least 8 characters";
      } else if (!RegExp(r'^(?=.*[A-Za-z])(?=.*\d)[A-Za-z\d@$!%*#?&]{8,}$').hasMatch(passwordController.text)) {
        passwordError = "Password must contain letters and numbers";
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

  Future<void> _navigateAfterRegistration(BuildContext context) async {
    if (context.mounted) {
      context.go("/confirm-address");
    }
  }

  Future<void> handleRegister() async {
    if (!_validateFields()) {
      return;
    }

    if (!agreedToTerms) {
      if (mounted) {
        AppToastMessage.show(
          context: context,
          message: "Please agree to the Terms & Conditions to continue",
          backgroundColor: context.appColors.error,
        );
      }
      return;
    }

    if (_registrationAttempts >= 5) {
      final timeSinceLastAttempt = DateTime.now().difference(_lastRegistrationAttempt!);
      if (timeSinceLastAttempt < const Duration(minutes: 5)) {
        final remainingSeconds = 300 - timeSinceLastAttempt.inSeconds;
        final remainingMinutes = (remainingSeconds / 60).ceil();
        if (mounted) {
          AppToastMessage.show(
            context: context,
            message: "Too many registration attempts. Please wait $remainingMinutes minute(s) before trying again.",
            backgroundColor: context.appColors.error,
          );
        }
        return;
      } else {
        _registrationAttempts = 0;
      }
    }

    _registrationAttempts++;
    _lastRegistrationAttempt = DateTime.now();

    FocusManager.instance.primaryFocus?.unfocus();
    LoadingDialog.instance().show(context: context, text: "Checking connection...");

    final hasInternet = await _checkInternetConnection();
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

    final serverReachable = await _checkServerConnection();
    if (!serverReachable) {
      if (mounted) {
        LoadingDialog.instance().hide();
        AppToastMessage.show(
          context: context,
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
        promoCode: promoCodeController.text.trim().isNotEmpty ? promoCodeController.text.trim() : null,
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

        _registrationAttempts = 0;
        _lastRegistrationAttempt = null;

        if (mounted) {
          AppToastMessage.show(context: context, message: message, backgroundColor: Colors.green);

          context.go("/verifyPhone");
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
          AppToastMessage.show(context: context, message: errorMessage, backgroundColor: context.appColors.error);
        }
      }
    } on SocketException {
      if (mounted) {
        LoadingDialog.instance().hide();
      }
      final hasInternet = await _checkInternetConnection();

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

  Future<void> _validateAndApplyPromoCode() async {
    final code = promoCodeController.text.trim();

    if (code.isEmpty) {
      setState(() {
        promoCodeError = null;
        isPromoCodeValid = false;
      });
      return;
    }

    setState(() {
      promoCodeError = null;
      isValidatingPromoCode = true;
    });

    try {
      final baseUri = Uri.parse(AppConfig.apiBaseUrl);
      final basePath = baseUri.path;
      final hasApiPrefix = basePath == '/api' || basePath.endsWith('/api') || basePath.endsWith('/api/');
      final endpoint = hasApiPrefix ? '/promo/validate-public' : '/api/promo/validate-public';

      final response = await chopperClient
          .post(Uri.parse(endpoint), body: {'code': code})
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException('Request timeout');
            },
          );

      Map<String, dynamic>? data;
      if (response.body is Map) {
        data = Map<String, dynamic>.from(response.body as Map);
      } else if ((response.bodyString).isNotEmpty) {
        final decoded = jsonDecode(response.bodyString);
        if (decoded is Map) {
          data = Map<String, dynamic>.from(decoded);
        }
      }

      if (data == null) {
        throw Exception('Empty response from server');
      }

      if (response.isSuccessful && data['valid'] == true) {
        setState(() {
          isPromoCodeValid = true;
          promoCodeError = null;
          isValidatingPromoCode = false;
        });

        if (mounted) {
          AppToastMessage.show(
            context: context,
            message: data['message']?.toString() ?? "Promo code applied. It will be used at checkout.",
            backgroundColor: Colors.green,
          );
        }
      } else {
        final message = data['error']?.toString() ?? data['message']?.toString();
        setState(() {
          isPromoCodeValid = false;
          promoCodeError = message?.isNotEmpty == true ? message : "Invalid promo code";
          isValidatingPromoCode = false;
        });
      }
    } on SocketException {
      setState(() {
        isPromoCodeValid = false;
        promoCodeError = "No internet connection. Check your network.";
        isValidatingPromoCode = false;
      });
    } on TimeoutException {
      setState(() {
        isPromoCodeValid = false;
        promoCodeError = "Request timeout. Please try again.";
        isValidatingPromoCode = false;
      });
    } catch (e) {
      print('❌ Promo validation error: $e');
      print('Error type: ${e.runtimeType}');
      setState(() {
        isPromoCodeValid = false;
        promoCodeError = "Could not validate code. Please try again.";
        isValidatingPromoCode = false;
      });
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
          AppToastMessage.show(context: context, message: errorMessage, backgroundColor: context.appColors.error);
        }
      }
    } on SocketException {
      if (mounted) {
        LoadingDialog.instance().hide();
      }

      final hasInternet = await _checkInternetConnection();
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
              physics: const AlwaysScrollableScrollPhysics(),
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
                          color: colors.accentGreen.withValues(alpha: 0.2),
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
                            cursorColor: colors.accentGreen,
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
                            cursorColor: colors.accentGreen,
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
                            cursorColor: colors.accentGreen,
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
                            cursorColor: colors.accentGreen,
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
                            cursorColor: colors.accentGreen,
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

                          SizedBox(height: KSpacing.lg.h),

                          AppTextInput(
                            controller: promoCodeController,
                            label: "Have a promo code?",
                            hintText: "Enter promo code (optional)",
                            fillColor: colors.backgroundSecondary,
                            borderColor: colors.inputBorder,
                            borderActiveColor: colors.accentGreen,
                            cursorColor: colors.accentGreen,
                            borderRadius: KBorderSize.borderRadius15,
                            contentPadding: EdgeInsets.all(KSpacing.md15.r),
                            errorText: promoCodeError,
                            textCapitalization: TextCapitalization.characters,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                              LengthLimitingTextInputFormatter(10),
                            ],
                            onChanged: (value) {
                              // Clear validation when user types
                              if (promoCodeError != null || isPromoCodeValid) {
                                setState(() {
                                  promoCodeError = null;
                                  isPromoCodeValid = false;
                                });
                              }
                            },
                            prefixIcon: Padding(
                              padding: EdgeInsets.all(KSpacing.md12.r),
                              child: SvgPicture.asset(
                                Assets.icons.badgePercent,
                                package: 'grab_go_shared',
                                width: KIconSize.md,
                                height: KIconSize.md,
                                colorFilter: ColorFilter.mode(colors.iconSecondary, BlendMode.srcIn),
                              ),
                            ),
                            suffixIcon: promoCodeController.text.isEmpty
                                ? null
                                : isPromoCodeValid
                                ? Padding(
                                    padding: EdgeInsets.all(KSpacing.md12.r),
                                    child: SvgPicture.asset(
                                      Assets.icons.check,
                                      package: 'grab_go_shared',
                                      width: KIconSize.md,
                                      height: KIconSize.md,
                                      colorFilter: ColorFilter.mode(colors.iconSecondary, BlendMode.srcIn),
                                    ),
                                  )
                                : isValidatingPromoCode
                                ? Padding(
                                    padding: EdgeInsets.all(KSpacing.md12.r),
                                    child: SizedBox(
                                      width: 20.r,
                                      height: 20.r,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(colors.accentGreen),
                                      ),
                                    ),
                                  )
                                : Padding(
                                    padding: EdgeInsets.all(4.r),
                                    child: Container(
                                      constraints: BoxConstraints(maxWidth: 80.w),
                                      decoration: BoxDecoration(
                                        color: colors.accentGreen,
                                        borderRadius: BorderRadius.circular(12.r),
                                      ),
                                      child: Material(
                                        color: Colors.transparent,
                                          child: InkWell(
                                          onTap: _validateAndApplyPromoCode,
                                          borderRadius: BorderRadius.circular(12.r),
                                          child: Padding(
                                            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                                            child: Center(
                                              child: Text(
                                                "Apply",
                                                style: TextStyle(
                                                  fontSize: KTextSize.small.sp,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.white,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                          ),

                          SizedBox(height: KSpacing.sm.h),

                          if (!isPromoCodeValid || promoCodeController.text.toUpperCase() != 'GRABGO10')
                            GestureDetector(
                              onTap: () {
                                promoCodeController.text = 'GRABGO10';
                                _validateAndApplyPromoCode();
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                                decoration: BoxDecoration(
                                  color: colors.accentGreen.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(6.r),
                                      decoration: BoxDecoration(
                                        color: colors.accentGreen.withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(8.r),
                                      ),
                                      child: SvgPicture.asset(
                                        Assets.icons.partyPopper,
                                        package: 'grab_go_shared',
                                        width: 18.r,
                                        height: 18.r,
                                        colorFilter: ColorFilter.mode(colors.accentGreen, BlendMode.srcIn),
                                      ),
                                    ),
                                    SizedBox(width: 12.w),
                                    Expanded(
                                      child: RichText(
                                        text: TextSpan(
                                          style: TextStyle(
                                            fontSize: KTextSize.extraSmall.sp,
                                            color: colors.textSecondary,
                                            height: 1.4,
                                          ),
                                          children: [
                                            TextSpan(
                                              text: "New user? Tap to use  ",
                                              style: TextStyle(
                                                fontFamily: "Lato",
                                                package: "grab_go_shared",
                                                fontSize: KTextSize.extraSmall.sp,
                                                color: colors.textSecondary,
                                                fontWeight: FontWeight.normal,
                                              ),
                                            ),
                                            TextSpan(
                                              text: "GRABGO10",
                                              style: TextStyle(
                                                fontFamily: "Lato",
                                                package: "grab_go_shared",
                                                fontWeight: FontWeight.w800,
                                                color: colors.accentGreen,
                                                fontSize: (KTextSize.extraSmall + 1).sp,
                                              ),
                                            ),
                                            TextSpan(
                                              text: "  for  ",
                                              style: TextStyle(
                                                fontFamily: "Lato",
                                                package: "grab_go_shared",
                                                fontSize: KTextSize.extraSmall.sp,
                                                color: colors.textSecondary,
                                                fontWeight: FontWeight.normal,
                                              ),
                                            ),
                                            TextSpan(
                                              text: "GHS 10 credits",
                                              style: TextStyle(fontWeight: FontWeight.w700, color: colors.accentGreen),
                                            ),
                                            TextSpan(
                                              text: "  after signup!",
                                              style: TextStyle(
                                                fontFamily: "Lato",
                                                package: "grab_go_shared",
                                                fontSize: KTextSize.extraSmall.sp,
                                                color: colors.textSecondary,
                                                fontWeight: FontWeight.normal,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    SvgPicture.asset(
                                      Assets.icons.navArrowRight,
                                      package: "grab_go_shared",
                                      width: 16.r,
                                      height: 16.r,
                                      colorFilter: ColorFilter.mode(
                                        colors.accentGreen.withValues(alpha: 0.5),
                                        BlendMode.srcIn,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          SizedBox(height: KSpacing.lg.h),

                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Checkbox(
                                value: agreedToTerms,
                                onChanged: (value) {
                                  setState(() {
                                    agreedToTerms = value ?? false;
                                  });
                                },
                                activeColor: colors.accentGreen,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(KBorderSize.borderRadius4),
                                ),
                                side: BorderSide(color: colors.border, width: KBorderWidth.thick),
                              ),
                              Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(top: 12.h),
                                  child: RichText(
                                    text: TextSpan(
                                      text: "I agree to the ",
                                      style: TextStyle(
                                        fontFamily: "Lato",
                                        package: 'grab_go_shared',
                                        color: colors.textSecondary,
                                        fontSize: KTextSize.small.sp,
                                      ),
                                      children: [
                                        TextSpan(
                                          text: "Terms & Conditions",
                                          style: TextStyle(
                                            fontFamily: "Lato",
                                            package: 'grab_go_shared',
                                            fontWeight: FontWeight.w600,
                                            color: colors.accentGreen,
                                            fontSize: KTextSize.small.sp,
                                          ),
                                          recognizer: TapGestureRecognizer()
                                            ..onTap = () {
                                              // context.push("/terms");
                                            },
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
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
                              onPressed: handleRegister,
                              backgroundColor: colors.accentGreen,
                              borderRadius: KBorderSize.borderRadius15,
                              buttonText: AppStrings.register,
                              textStyle: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15.sp),
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
                                message: "Facebook sign-up coming soon!",
                                backgroundColor: context.appColors.accentOrange,
                              );
                            },
                            child: Container(
                              height: 56.h,
                              decoration: BoxDecoration(
                                color: colors.backgroundSecondary,
                                borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
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
