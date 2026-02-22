import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:grab_go_shared/grub_go_shared.dart';
import 'package:grab_go_rider/shared/service/storage_service.dart';
import 'package:grab_go_rider/shared/service/auth_guard.dart';
import 'package:grab_go_rider/shared/service/user_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fade;
  late final Animation<Offset> _grabSlide;
  late final Animation<Offset> _riderSlide;
  late final Animation<double> _grabOpacity;
  late final Animation<double> _riderOpacity;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _fade = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _grabSlide = Tween<Offset>(begin: const Offset(-0.22, 0), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOutCubic),
      ),
    );
    _riderSlide = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _fadeController,
        curve: const Interval(0.22, 1.0, curve: Curves.easeOutCubic),
      ),
    );
    _grabOpacity = CurvedAnimation(
      parent: _fadeController,
      curve: const Interval(0.0, 0.72, curve: Curves.easeOut),
    );
    _riderOpacity = CurvedAnimation(
      parent: _fadeController,
      curve: const Interval(0.24, 1.0, curve: Curves.easeOut),
    );
    _fadeController.forward();
    _initialize();
  }

  Future<void> _initialize() async {
    await UserService().initialize();
    await SocketService().initialize();

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
        backgroundColor: colors.accentGreen,
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
                      position: _riderSlide,
                      child: FadeTransition(
                        opacity: _riderOpacity,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            'Rider',
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
