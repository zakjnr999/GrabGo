import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:grab_go_shared/gen/assets.gen.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final Animation<double> _fade;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fade = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _fadeController.forward();
    _goToInitialRoute();
  }

  Future<void> _goToInitialRoute() async {
    await Future.delayed(const Duration(seconds: 3));
    if (!mounted || _hasNavigated) return;

    final router = GoRouter.of(context);
    final currentPath = router.routerDelegate.currentConfiguration.uri.path;
    if (currentPath != '/' && currentPath.isNotEmpty) return;

    final isFirstLaunch = CacheService.isFirstLaunch();
    final token = await CacheService.getAuthToken();
    if (!mounted || _hasNavigated) return;

    _hasNavigated = true;
    if (isFirstLaunch) {
      router.go('/onboarding');
      return;
    }
    if (token != null && token.isNotEmpty) {
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
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: FadeTransition(
          opacity: _fade,
          child: Stack(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      color: colors.vendorPrimaryBlue,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: EdgeInsets.only(right: 2.w),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              'Grab',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 64.sp,
                                height: 1.0,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          color: Colors.white,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: EdgeInsets.only(left: 2.w),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'GO',
                                  style: TextStyle(
                                    color: colors.vendorPrimaryBlue,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 64.sp,
                                    height: 1.0,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 10.w),
                        SvgPicture.asset(
                          Assets.icons.store,
                          package: 'grab_go_shared',
                          width: 64.w,
                          height: 64.w,
                          colorFilter: ColorFilter.mode(
                            colors.vendorPrimaryBlue,
                            BlendMode.srcIn,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: MediaQuery.paddingOf(context).bottom + 8.h,
                child: SizedBox(
                  height: 6.h,
                  child: Row(
                    children: [
                      Expanded(child: ColoredBox(color: colors.serviceFood)),
                      Expanded(child: ColoredBox(color: colors.serviceGrocery)),
                      Expanded(
                        child: ColoredBox(color: colors.servicePharmacy),
                      ),
                      Expanded(
                        child: ColoredBox(color: colors.serviceGrabMart),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
