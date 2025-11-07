import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:grab_go_shared/shared/utils/constants.dart';
import 'package:grab_go_shared/shared/utils/strings.dart';
import 'package:grab_go_shared/shared/widgets/app_text_input_panels.dart';
import '../../dashboard/view/admin_dashboard.dart';
import '../../../shared/app_colors.dart';
import '../../../shared/app_colors_extension.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/utils/responsive.dart';
import '../../../core/api/api_client.dart';
import '../../../shared/services/token_service.dart';

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
                  GestureDetector(
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminDashboard()));
                    },
                    child: Center(
                      child: SvgPicture.asset(
                        Assets.icons.user,
                        package: 'grab_go_shared',
                        width: isMobile ? 60 : (isTablet ? 70 : 80),
                        height: isMobile ? 60 : (isTablet ? 70 : 80),
                        colorFilter: ColorFilter.mode(AppColors.accentOrange, BlendMode.srcIn),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  SizedBox(height: isMobile ? 20 : 28),
                  Text(
                    'Welcome Back, Admin!',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.lato(
                      fontSize: Responsive.getFontSize(context, isMobile ? 20 : 24),
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.white : AppColors.primary,
                    ),
                  ),
                  SizedBox(height: isMobile ? 10 : 12),
                  Text(
                    'Manage orders, track deliveries, and keep GrabGo running smoothly.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.lato(
                      fontSize: Responsive.getFontSize(context, isMobile ? 10 : 12),
                      fontWeight: FontWeight.w500,
                      color: AppColors.grey,
                    ),
                  ),
                  SizedBox(height: isMobile ? 24 : 32),

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

  Future<void> _handleLogin() async {
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
    }

    if (hasErrors) {
      return;
    }

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      if (kDebugMode) {
        debugPrint('🔐 Attempting login for: ${emailController.text.trim()}');
      }

      // Use the same login endpoint as customer app: /api/users/login
      final response = await authService.login(
        credentials: {'email': emailController.text.trim(), 'password': passwordController.text},
      );

      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (kDebugMode) {
        debugPrint('📥 Login Response Status: ${response.statusCode}');
        debugPrint('📥 Login Response Body: ${response.body}');
      }

      if (response.isSuccessful && response.body != null) {
        final responseData = response.body!;

        final token = responseData['token'] as String?;
        final user = responseData['user'] as Map<String, dynamic>?;
        final message = responseData['message'] as String?;

        if (kDebugMode) {
          debugPrint('🔑 Token received: ${token != null ? 'Yes' : 'No'}');
          debugPrint('👤 User data: ${user != null ? 'Yes' : 'No'}');
          if (user != null) {
            debugPrint('👤 isAdmin: ${user['isAdmin']}');
            debugPrint('👤 role: ${user['role']}');
          }
        }

        if (token != null && token.isNotEmpty) {
          // Save token
          await TokenService().saveToken(token);

          // Check if user is admin - REQUIRED for admin panel access
          // Uses same login route as customer app (/api/users/login), but validates admin privileges
          final isAdmin = user?['isAdmin'] == true;

          if (kDebugMode) {
            debugPrint('🔒 Admin check - isAdmin: $isAdmin');
          }

          if (!isAdmin) {
            if (!mounted) return;
            if (kDebugMode) {
              debugPrint('❌ Access denied - User is not admin');
            }
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Access denied. This account does not have admin privileges.'),
                backgroundColor: AppColors.errorRed,
                duration: Duration(seconds: 4),
              ),
            );
            // Clear token if not admin
            await TokenService().clearToken();
            return;
          }

          // Success - user is admin, navigate to dashboard
          if (kDebugMode) {
            debugPrint('✅ Admin login successful - Navigating to dashboard');
          }
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message ?? 'Login successful'),
              backgroundColor: AppColors.successGreen,
              duration: const Duration(seconds: 2),
            ),
          );
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AdminDashboard()));
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(responseData['message'] ?? 'Login failed: No token received'),
              backgroundColor: AppColors.errorRed,
            ),
          );
        }
      } else {
        if (!mounted) return;
        // Parse error message from response
        String errorMsg = 'Login failed. Please check your credentials.';
        if (response.body != null) {
          if (response.body is Map<String, dynamic>) {
            final errorBody = response.body as Map<String, dynamic>;
            errorMsg = errorBody['message'] ?? errorBody['error'] ?? errorMsg;
          } else {
            errorMsg = response.body.toString();
          }
        } else if (response.error != null) {
          errorMsg = response.error.toString();
        }

        if (kDebugMode) {
          debugPrint('❌ Login failed: $errorMsg');
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: AppColors.errorRed, duration: const Duration(seconds: 4)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading dialog
      if (kDebugMode) {
        debugPrint('❌ Login exception: $e');
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: AppColors.errorRed));
    }
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }
}
