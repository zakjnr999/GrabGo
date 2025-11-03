import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:grab_go_restaurant/features/setup/view/restaurant_setup_screen.dart';
import 'package:grab_go_restaurant/shared/widgets/app_button.dart';
import 'package:grab_go_restaurant/shared/app_colors.dart';
import 'package:grab_go_shared/shared/utils/constants.dart';
import 'package:grab_go_shared/shared/utils/responsive.dart';
import 'package:grab_go_shared/shared/utils/strings.dart';
import 'package:grab_go_shared/shared/widgets/app_text_input_panels.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_restaurant/shared/app_colors_extension.dart';

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
                borderRadius: BorderRadius.circular(KBorderSize.borderRadius15),
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
                  Center(
                    child: SvgPicture.asset(
                      Assets.icons.chefHat,
                      package: 'grab_go_shared',
                      width: isMobile ? 60 : (isTablet ? 70 : 80),
                      height: isMobile ? 60 : (isTablet ? 70 : 80),
                      colorFilter: ColorFilter.mode(AppColors.accentOrange, BlendMode.srcIn),
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
                  SizedBox(height: Responsive.getCardSpacing(context)),

                  AppTextInputPanels(
                    controller: emailController,
                    label: AppStrings.loginEmailLabel,
                    hintText: AppStrings.loginEmailHint,
                    borderColor: colors.border,
                    fillColor: isDark ? AppColors.darkBackground : AppColors.secondaryBackground,
                    borderRadius: KBorderSize.borderRadius15,
                    contentPadding: EdgeInsets.all(KSpacing.md15),
                    keyboardType: TextInputType.emailAddress,
                    errorText: emailError,
                    prefixIcon: Padding(
                      padding: EdgeInsets.all(KSpacing.md12),
                      child: SvgPicture.asset(
                        Assets.icons.mail,
                        package: 'grab_go_shared',
                        width: KIconSize.md,
                        height: KIconSize.md,
                        colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                      ),
                    ),
                  ),
                  SizedBox(height: isMobile ? 16 : 20),
                  AppTextInputPanels(
                    controller: passwordController,
                    label: AppStrings.loginPasswordLabel,
                    hintText: AppStrings.loginPasswordHint,
                    borderColor: colors.border,
                    fillColor: isDark ? AppColors.darkBackground : AppColors.secondaryBackground,
                    borderRadius: KBorderSize.borderRadius15,
                    contentPadding: EdgeInsets.all(KSpacing.md15),
                    keyboardType: TextInputType.text,
                    obscureText: isPasswordVisible,
                    errorText: passwordError,
                    prefixIcon: Padding(
                      padding: EdgeInsets.all(KSpacing.md12),
                      child: SvgPicture.asset(
                        Assets.icons.lock,
                        package: 'grab_go_shared',
                        width: KIconSize.md,
                        height: KIconSize.md,
                        colorFilter: ColorFilter.mode(colors.textSecondary, BlendMode.srcIn),
                      ),
                    ),
                    suffixIcon: GestureDetector(
                      onTap: () {
                        setState(() {
                          isPasswordVisible = !isPasswordVisible;
                        });
                      },
                      child: Padding(
                        padding: EdgeInsets.all(KSpacing.md12),
                        child: SvgPicture.asset(
                          isPasswordVisible ? Assets.icons.eyeClosed : Assets.icons.eye,
                          package: 'grab_go_shared',
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: isMobile ? 28 : 36),
                  AppButton(
                    buttonText: 'LOGIN',
                    onPressed: () {
                      _handleLogin();
                    },
                    width: double.infinity,
                    borderRadius: KBorderSize.borderRadius15,
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
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const RestaurantSetupScreen()));
    }
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }
}
