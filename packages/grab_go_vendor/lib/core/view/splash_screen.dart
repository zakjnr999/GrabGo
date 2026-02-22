import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_vendor/features/onboarding/viewmodel/onboarding_setup_viewmodel.dart';
import 'package:provider/provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fade;
  late final Animation<Offset> _grabSlide;
  late final Animation<Offset> _vendorSlide;
  late final Animation<double> _grabOpacity;
  late final Animation<double> _vendorOpacity;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fade = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _grabSlide = Tween<Offset>(begin: const Offset(-0.22, 0), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _fadeController,
            curve: const Interval(0.0, 0.65, curve: Curves.easeOutCubic),
          ),
        );
    _vendorSlide = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _fadeController,
            curve: const Interval(0.22, 1.0, curve: Curves.easeOutCubic),
          ),
        );
    _grabOpacity = CurvedAnimation(
      parent: _fadeController,
      curve: const Interval(0.0, 0.72, curve: Curves.easeOut),
    );
    _vendorOpacity = CurvedAnimation(
      parent: _fadeController,
      curve: const Interval(0.24, 1.0, curve: Curves.easeOut),
    );
    _fadeController.forward();
    _goToInitialRoute();
  }

  Future<void> _goToInitialRoute() async {
    final router = GoRouter.of(context);
    final onboardingSetup = context.read<OnboardingSetupViewModel>();

    await Future.delayed(const Duration(seconds: 3));
    if (!mounted || _hasNavigated) return;

    final currentPath = router.routerDelegate.currentConfiguration.uri.path;
    if (currentPath != '/' && currentPath.isNotEmpty) return;

    final isFirstLaunch = CacheService.isFirstLaunch();
    final token = await CacheService.getAuthToken();
    if (!onboardingSetup.isHydrated) {
      for (var attempt = 0; attempt < 15; attempt++) {
        if (!mounted || onboardingSetup.isHydrated) break;
        await Future.delayed(const Duration(milliseconds: 120));
      }
    }
    if (!mounted || _hasNavigated) return;

    _hasNavigated = true;
    if (isFirstLaunch) {
      router.go('/onboarding');
      return;
    }
    if (token != null && token.isNotEmpty) {
      if (!onboardingSetup.allRequiredCompleted) {
        router.go('/onboardingGuide');
        return;
      }
      router.go('/home');
      return;
    }
    router.go('/login');
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: colors.vendorPrimaryBlue,
        body: FadeTransition(
          opacity: _fade,
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 0.78.sw,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: SlideTransition(
                        position: _grabSlide,
                        child: FadeTransition(
                          opacity: _grabOpacity,
                          child: Text(
                            'GrabGO',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontWeight: FontWeight.w700,
                              fontSize: 21.sp,
                              letterSpacing: 2.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 9.h),
                  Container(
                    width: 68.w,
                    height: 2.2.h,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(100.r),
                    ),
                  ),
                  SizedBox(height: 10.h),
                  SizedBox(
                    width: 0.9.sw,
                    child: SlideTransition(
                      position: _vendorSlide,
                      child: FadeTransition(
                        opacity: _vendorOpacity,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Vendor',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 68.sp,
                              height: 0.95,
                              letterSpacing: 0.7,
                            ),
                          ),
                        ),
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
