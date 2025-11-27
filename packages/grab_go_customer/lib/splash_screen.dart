import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_customer/shared/services/storage_service.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_customer/shared/services/auth_guard.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _scaleController;
  late AnimationController _floatingController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _floatingAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _initializeApp();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);

    _scaleController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _scaleAnimation = CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut);

    _floatingController = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat(reverse: true);
    _floatingAnimation = Tween<double>(
      begin: -10,
      end: 10,
    ).animate(CurvedAnimation(parent: _floatingController, curve: Curves.easeInOut));

    _fadeController.forward();
    _scaleController.forward();
  }

  Future<void> _initializeApp() async {
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted) return;

    final router = GoRouter.of(context);
    final currentLocation = router.routerDelegate.currentConfiguration.uri.path;

    if (currentLocation != '/' && currentLocation != '') {
      return;
    }

    final isFirst = await StorageService.isFirstLaunch();

    if (isFirst) {
      context.go("/onboarding");
    } else {
      await AuthGuard.checkAuthAndRedirect(context);
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    _floatingController.dispose();
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
        extendBodyBehindAppBar: true,
        extendBody: true,
        body: SafeArea(
          top: false,
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Stack(
                children: [
                  Container(
                    width: double.infinity,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          colors.accentOrange,
                          colors.accentOrange.withValues(alpha: 0.8),
                          colors.accentViolet.withValues(alpha: 0.3),
                        ],
                      ),
                    ),
                    child: ImageFiltered(
                      imageFilter: ImageFilter.blur(sigmaX: 3.0, sigmaY: 3.0),
                      child: Opacity(
                        opacity: 0.3,
                        child: Image(
                          image: Assets.images.splashImage.provider(package: 'grab_go_shared'),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),

                  AnimatedBuilder(
                    animation: _floatingAnimation,
                    builder: (context, child) {
                      return Stack(
                        children: [
                          Positioned(
                            top: 100.h + _floatingAnimation.value,
                            left: 30.w,
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.0, end: 1.0),
                              duration: const Duration(milliseconds: 800),
                              curve: Curves.easeOut,
                              builder: (context, value, child) {
                                return Transform.scale(
                                  scale: value,
                                  child: Transform.rotate(
                                    angle: value * 0.1,
                                    child: Opacity(
                                      opacity: value * 0.7,
                                      child: Assets.images.ingredientTwo.image(
                                        height: 100.h,
                                        width: 100.w,
                                        package: 'grab_go_shared',
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          Positioned(
                            top: 200.h - _floatingAnimation.value,
                            right: 40.w,
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.0, end: 1.0),
                              duration: const Duration(milliseconds: 1000),
                              curve: Curves.easeOut,
                              builder: (context, value, child) {
                                return Transform.scale(
                                  scale: value,
                                  child: Transform.rotate(
                                    angle: -value * 0.1,
                                    child: Opacity(
                                      opacity: value * 0.7,
                                      child: Assets.images.ingredientOne.image(
                                        height: 90.h,
                                        width: 90.w,
                                        package: 'grab_go_shared',
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          Positioned(
                            bottom: 150.h + _floatingAnimation.value,
                            left: 50.w,
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.0, end: 1.0),
                              duration: const Duration(milliseconds: 1200),
                              curve: Curves.easeOut,
                              builder: (context, value, child) {
                                return Transform.scale(
                                  scale: value,
                                  child: Transform.rotate(
                                    angle: value * 0.15,
                                    child: Opacity(
                                      opacity: value * 0.7,
                                      child: Assets.images.ingredientThree.image(
                                        height: 100.h,
                                        width: 100.w,
                                        package: 'grab_go_shared',
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          Positioned(
                            bottom: 100.h - _floatingAnimation.value,
                            right: 50.w,
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0.0, end: 1.0),
                              duration: const Duration(milliseconds: 1400),
                              curve: Curves.easeOut,
                              builder: (context, value, child) {
                                return Transform.scale(
                                  scale: value,
                                  child: Transform.rotate(
                                    angle: -value * 0.15,
                                    child: Opacity(
                                      opacity: value * 0.7,
                                      child: Assets.images.ingredientFour.image(
                                        height: 80.h,
                                        width: 80.w,
                                        package: 'grab_go_shared',
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  Container(
                    width: double.infinity,
                    height: double.infinity,
                    color: Colors.transparent,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ScaleTransition(
                          scale: _scaleAnimation,
                          child: FadeTransition(
                            opacity: _fadeAnimation,
                            child: Container(
                              padding: EdgeInsets.all(20.r),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 30,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: Image(
                                image: Assets.icons.appIconCustomer.provider(package: 'grab_go_shared'),
                                height: 100.h,
                                width: 100.w,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 15.h),

                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: Column(
                            children: [
                              Text(
                                AppStrings.appName,
                                style: TextStyle(
                                  letterSpacing: 3.0,
                                  color: Colors.white,
                                  fontFamily: "Lobster",
                                  package: "grab_go_shared",
                                  fontWeight: FontWeight.w900,
                                  fontSize: 38.sp,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withValues(alpha: 0.3),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(height: 10.h),
                              Text(
                                "Your Food, Delivered Fast",
                                style: TextStyle(
                                  letterSpacing: 1.5,
                                  color: Colors.white.withValues(alpha: 0.9),
                                  fontFamily: "Lato",
                                  package: "grab_go_shared",
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14.sp,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withValues(alpha: 0.2),
                                      blurRadius: 5,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
