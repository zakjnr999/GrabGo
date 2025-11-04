import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _progressController;
  late Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _progressController = AnimationController(vsync: this, duration: const Duration(seconds: 4));
    _fade = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _fadeController.forward();
    _initialize();
  }

  Future<void> _initialize() async {
    await _progressController.forward();
    if (!mounted) return;
    context.go('/onboarding');
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: const Color(0xFF1A1F2E),
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: const Color(0xFF1A1F2E),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [const Color(0xFF1A1F2E), const Color(0xFF252B3D), const Color(0xFF1E2435)],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
          child: Center(
            child: FadeTransition(
              opacity: _fade,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo/Title
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 16.h),
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: 48.sp, height: 1.0, letterSpacing: 0.5),
                        children: [
                          TextSpan(
                            text: 'Grab',
                            style: TextStyle(color: Colors.white),
                          ),
                          TextSpan(
                            text: 'Go',
                            style: TextStyle(color: colors.accentGreen),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 8.h),
                  // Rider subtitle
                  Text(
                    'Rider',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontWeight: FontWeight.w600,
                      fontSize: 20.sp,
                      letterSpacing: 2,
                      height: 1.2,
                    ),
                  ),
                  SizedBox(height: KSpacing.xl.r),
                  // Tagline with improved styling
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 32.w),
                    child: Text(
                      AppStrings.riderSplashTagline,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontWeight: FontWeight.w500,
                        fontSize: 17.sp,
                        height: 1.5,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  SizedBox(height: KSpacing.xl.r),
                  // Progress bar
                  Container(
                    width: 240.w,
                    height: 8.r,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    alignment: Alignment.centerLeft,
                    child: AnimatedBuilder(
                      animation: _progressController,
                      builder: (context, _) {
                        return FractionallySizedBox(
                          widthFactor: _progressController.value.clamp(0.0, 1.0).toDouble(),
                          child: Container(
                            height: 8.h,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [Colors.white, Colors.white.withValues(alpha: 0.9)]),
                              borderRadius: BorderRadius.circular(20.r),
                            ),
                          ),
                        );
                      },
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
