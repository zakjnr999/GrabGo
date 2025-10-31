// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:grab_go_restaurant/features/dashboard/view/restaurant_dashboard.dart';
import 'package:grab_go_restaurant/features/setup/view/restaurant_setup_screen.dart';
import 'package:grab_go_shared/shared/utils/app_colors_extension.dart';
import 'package:grab_go_shared/shared/utils/colors.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/shared/widgets/responsive.dart';
import '../../../shared/widgets/svg_icon.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/text_input.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  String? emailError;
  String? passwordError;
  bool isPasswordVisible = true;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = context.appColors;
    final isMobile = Responsive.isMobile(context);
    final isTablet = Responsive.isTablet(context);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.accentOrange.withValues(alpha: 0.05),
      body: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : (isTablet ? 400 : 500)),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: Responsive.getScreenPadding(context),
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : AppColors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: isDark ? Colors.black.withValues(alpha: 0.3) : AppColors.accentOrange.withValues(alpha: 0.1),
                    blurRadius: 15,
                    offset: const Offset(0, 6),
                  ),
                  BoxShadow(
                    color: isDark ? Colors.black.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: EdgeInsets.all(isMobile ? 28 : 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo and Title
                  Center(
                    child: Image.asset(
                      Assets.icons.appIcon.path,
                      width: isMobile ? 60 : (isTablet ? 70 : 80),
                      height: isMobile ? 60 : (isTablet ? 70 : 80),
                      color: AppColors.accentOrange,
                    ),
                  ),
                  SizedBox(height: isMobile ? 20 : 28),
                  Text(
                    'Welcome Back to GrabGo!',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.lato(
                      fontSize: Responsive.getFontSize(context, isMobile ? 20 : 24),
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.white : AppColors.primary,
                    ),
                  ),
                  SizedBox(height: isMobile ? 10 : 12),
                  Text(
                    'Access your dashboard to manage orders, menus, and performance — all in one place.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.lato(
                      fontSize: Responsive.getFontSize(context, isMobile ? 10 : 12),
                      fontWeight: FontWeight.w500,
                      color: AppColors.grey,
                    ),
                  ),
                  SizedBox(height: isMobile ? 24 : 32),

                  TextInput(
                    controller: emailController,
                    label: 'Your Email Address',
                    hintText: 'example@email.com',
                    borderColor: colors.border,
                    fillColor: isDark ? AppColors.darkBackground : AppColors.white,
                    borderRadius: isMobile ? 40.0 : 50.0,
                    contentPadding: EdgeInsets.all(isMobile ? 12 : 15),
                    keyboardType: TextInputType.emailAddress,
                    errorText: emailError,
                    prefixIcon: Padding(
                      padding: EdgeInsets.all(isMobile ? 10 : 12),
                      child: SvgIcon(
                        svgImage: Assets.icons.mail,
                        width: Responsive.getIconSize(context),
                        height: Responsive.getIconSize(context),
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                  SizedBox(height: isMobile ? 16 : 20),
                  // Password Field - Custom TextField
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Your Password',
                        style: GoogleFonts.lato(
                          fontSize: Responsive.getFontSize(context, isMobile ? 10 : 12),
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                      SizedBox(height: isMobile ? 6 : 8),
                      TextField(
                        controller: passwordController,
                        keyboardType: TextInputType.visiblePassword,
                        obscureText: isPasswordVisible,
                        cursorColor: AppColors.accentOrange,
                        style: GoogleFonts.lato(
                          fontSize: Responsive.getFontSize(context, isMobile ? 13 : 14),
                          color: colors.textPrimary,
                          fontWeight: FontWeight.w500,
                        ),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: isDark ? AppColors.darkBackground : AppColors.white,
                          hintText: 'Minimum 8 characters',
                          hintStyle: GoogleFonts.lato(
                            fontSize: Responsive.getFontSize(context, isMobile ? 12 : 13),
                            color: colors.textSecondary.withValues(alpha: 0.7),
                          ),
                          errorText: passwordError,
                          errorStyle: GoogleFonts.lato(
                            fontSize: Responsive.getFontSize(context, 10),
                            color: colors.error,
                            fontWeight: FontWeight.w500,
                          ),
                          errorMaxLines: 2,
                          contentPadding: EdgeInsets.all(isMobile ? 12 : 15),
                          prefixIcon: Padding(
                            padding: EdgeInsets.all(isMobile ? 10 : 12),
                            child: SvgIcon(
                              svgImage: Assets.icons.lock,
                              width: Responsive.getIconSize(context),
                              height: Responsive.getIconSize(context),
                              color: colors.textSecondary,
                            ),
                          ),
                          suffixIcon: GestureDetector(
                            onTap: () {
                              setState(() {
                                isPasswordVisible = !isPasswordVisible;
                              });
                            },
                            child: Padding(
                              padding: EdgeInsets.all(isMobile ? 10 : 12),
                              child: SvgIcon(
                                svgImage: isPasswordVisible ? Assets.icons.eyeClosed : Assets.icons.eye,
                                width: Responsive.getIconSize(context),
                                height: Responsive.getIconSize(context),
                                color: colors.textSecondary,
                              ),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(isMobile ? 40.0 : 50.0),
                            borderSide: BorderSide(
                              color: passwordError != null ? colors.error : colors.border,
                              width: 1,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(isMobile ? 40.0 : 50.0),
                            borderSide: BorderSide(
                              color: passwordError != null ? colors.error : AppColors.accentOrange,
                              width: 1,
                            ),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(isMobile ? 40.0 : 50.0),
                            borderSide: BorderSide(color: colors.error, width: 1),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(isMobile ? 40.0 : 50.0),
                            borderSide: BorderSide(color: colors.error, width: 1),
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: isMobile ? 28 : 36),
                  // Login Button
                  AppButton(
                    buttonText: 'LOGIN',
                    onPressed: () {
                      // Handle login logic here
                      _handleLogin();
                    },
                    width: double.infinity,
                    borderRadius: isMobile ? 40.0 : 50.0,
                    padding: EdgeInsets.symmetric(vertical: isMobile ? 18 : 20),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _handleLogin() {
    // Basic validation
    setState(() {
      emailError = null;
      passwordError = null;
    });

    bool hasErrors = false;

    if (emailController.text.isEmpty) {
      setState(() {
        emailError = 'Email is required';
      });
      hasErrors = true;
    } else if (!_isValidEmail(emailController.text)) {
      setState(() {
        emailError = 'Please enter a valid email address';
      });
      hasErrors = true;
    }

    if (passwordController.text.isEmpty) {
      setState(() {
        passwordError = 'Password is required';
      });
      hasErrors = true;
    } else if (passwordController.text.length < 8) {
      setState(() {
        passwordError = 'Password must be at least 8 characters';
      });
      hasErrors = true;
    }

    if (hasErrors) {
      return;
    }

    bool isSetupComplete = _checkRestaurantSetupStatus(emailController.text);

    if (isSetupComplete) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const RestaurantDashboard()));
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const RestaurantSetupScreen()));
    }
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  bool _checkRestaurantSetupStatus(String email) {
    return false;
  }
}
